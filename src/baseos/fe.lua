-- Base OS: FE stored in Applied Flux cells
--
-- The ME Bridge can't see Applied Flux power (AP only describes standard AE2 cells), and the
-- Flux Accessor's energy capability is capped at 2,147,483,647 FE. But each FE cell keeps its
-- exact energy in its item data (component appflux:fe_energy), and a Block Reader facing an
-- ME Drive returns the drive's saved data, cells included: inv.item0.components["appflux:fe_energy"].
--
-- Put a Block Reader against every ME Drive that holds FE cells. Readers facing anything
-- else are ignored. Values come from the drive's saved data, so they can lag behind a bit.

local fe = {}

settings.define("baseos.fe_per_byte", {
    description = "Applied Flux FE per byte (its config flux_cell.amount), for FE cell capacity",
    default = 1024 * 1024,
    type = "number"
})

local RATE_WINDOW = 60 -- seconds of history for FE/t

local samples = {} -- { t = seconds, stored = FE }

-- Capacity of an FE cell from its id: appflux:fe_4m_cell -> 4 * 1024 * 1024 bytes
local function capacity(id)
    local n, unit = id:lower():match("fe_(%d+)([km])_cell")

    if not n then
        return nil
    end

    local bytes = tonumber(n) * 1024 * (unit == "m" and 1024 or 1)

    return bytes * settings.get("baseos.fe_per_byte")
end

-- Find FE cells anywhere in a block's data (drive inventories are inv.item0 .. inv.item9)
local function scan(data, found)
    for _, value in pairs(data) do
        if type(value) == "table" then
            local id = type(value.id) == "string" and value.id or ""
            local energy

            if type(value.components) == "table" then
                for key, v in pairs(value.components) do
                    if type(key) == "string" and key:match(":fe_energy$") then
                        energy = tonumber(v)
                    end
                end
            end

            -- An empty FE cell has no fe_energy at all, so also go by its id
            if energy or id:match("^appflux:fe_%d+[km]_cell$") then
                table.insert(found, { id = id, stored = energy or 0, capacity = capacity(id) })
            else
                scan(value, found)
            end
        end
    end
end

-- Returns nil if no Block Reader sees any FE cells, otherwise
-- { stored, capacity (nil if unknown), cells, readers, rate (FE/t or nil) }
function fe.read()
    local result = { stored = 0, capacity = 0, cells = 0, readers = 0 }
    local unknown = false

    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "block_reader") then
            local ok, data = pcall(peripheral.call, name, "getBlockData")
            local cells = {}

            if ok and type(data) == "table" then
                scan(data, cells)
            end

            if #cells > 0 then
                result.readers = result.readers + 1

                for _, cell in ipairs(cells) do
                    result.cells = result.cells + 1
                    result.stored = result.stored + cell.stored

                    if cell.capacity then
                        result.capacity = result.capacity + cell.capacity
                    else
                        unknown = true
                    end
                end
            end
        end
    end

    if result.cells == 0 then
        samples = {}
        return nil
    end

    if unknown then
        result.capacity = nil
    end

    -- FE/t over about the last minute
    local now = os.clock()

    table.insert(samples, { t = now, stored = result.stored })

    while #samples > 2 and now - samples[2].t >= RATE_WINDOW do
        table.remove(samples, 1)
    end

    local first = samples[1]

    if now - first.t >= 10 then
        result.rate = (result.stored - first.stored) / ((now - first.t) * 20)
    end

    return result
end

-- "+1.2K FE/t" / "-300 FE/t" / "" (no rate yet)
function fe.rateText(data, fmt)
    if not data or not data.rate then
        return ""
    end

    local sign = data.rate < 0 and "-" or "+"

    return sign .. fmt(math.abs(data.rate)) .. " FE/t"
end

return fe
