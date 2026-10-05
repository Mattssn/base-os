-- Base OS: environment detector data (Advanced Peripherals environment_detector, 1.21.1)
-- Every detector on the network is read, so you can put them wherever you want
-- (next to the base, at a mob farm, by a reactor...).
--
-- Notes from the AP 1.21.1 source:
--   * every call runs on the server thread (one tick each), so this is polled slowly
--   * scanEntities: living entities only, 2s cooldown, free up to radius 8 (max 16)
--   * moon functions only work in the overworld
--   * radiation needs Mekanism (included in ATM10)

local env = {}

settings.define("baseos.env_range", {
    description = "Base OS entity scan radius for environment detectors (1-16, above 8 may need energy)",
    default = 8,
    type = "number"
})

settings.define("baseos.env_radiation_alert", {
    description = "Base OS radiation alert level in Sv/h (Mekanism background is ~0.0000001)",
    default = 0.00001,
    type = "number"
})

local function call(detector, name, ...)
    if type(detector[name]) ~= "function" then
        return nil
    end

    local ok, result, err = pcall(detector[name], ...)

    if ok then
        return result, err
    end

    return nil, result
end

-- "minecraft:dark_forest" -> "Dark Forest"
local function pretty(id)
    if type(id) ~= "string" then
        return "?"
    end

    local name = id:match(":(.+)$") or id

    return (name:gsub("[_/]", " "):gsub("(%a)(%w*)", function(first, rest)
        return first:upper() .. rest
    end))
end

-- Minecraft day time (ticks) -> "8:15 PM"; 0 ticks is 6:00 AM, 1000 ticks per hour
local function timeOfDay(ticks)
    local h = (math.floor(ticks / 1000) + 6) % 24
    local minutes = math.floor((ticks % 1000) * 60 / 1000)
    local suffix = h >= 12 and "PM" or "AM"

    h = h % 12

    if h == 0 then
        h = 12
    end

    return ("%d:%02d %s"):format(h, minutes, suffix)
end

local function readEntities(detector, range)
    local list, err = call(detector, "scanEntities", range)

    if type(list) ~= "table" then
        return nil, err
    end

    local entities = {}

    for _, e in ipairs(list) do
        local x, y, z = tonumber(e.x) or 0, tonumber(e.y) or 0, tonumber(e.z) or 0

        table.insert(entities, {
            name = e.name or "?",
            health = tonumber(e.health),
            maxHealth = tonumber(e.maxHealth),
            baby = e.baby,
            distance = math.sqrt(x * x + y * y + z * z)
        })
    end

    table.sort(entities, function(a, b)
        return a.distance < b.distance
    end)

    return entities
end

-- Counts per name, most common first: { { name = "Cow", count = 5 }, ... }
function env.groups(entities)
    local counts = {}
    local groups = {}

    for _, e in ipairs(entities) do
        if not counts[e.name] then
            counts[e.name] = { name = e.name, count = 0 }
            table.insert(groups, counts[e.name])
        end

        counts[e.name].count = counts[e.name].count + 1
    end

    table.sort(groups, function(a, b)
        return a.count > b.count
    end)

    return groups
end

local previous = {} -- detector name -> last reading (entities are kept while on cooldown)

local function readDetector(name, detector, range)
    local r = { name = name }
    local ticks = tonumber(call(detector, "getTime")) or 0

    r.dimensionId = call(detector, "getDimension") or "?"
    r.dimension = pretty(r.dimensionId)
    r.biome = pretty(call(detector, "getBiome"))
    r.ticks = ticks % 24000
    r.time = timeOfDay(r.ticks)
    r.night = r.ticks >= 13000 and r.ticks < 23000

    r.thunder = call(detector, "isThunder") == true
    r.raining = call(detector, "isRaining") == true
    r.weather = r.thunder and "Storm" or r.raining and "Rain" or "Clear"

    if r.dimensionId == "minecraft:overworld" then
        r.moon = call(detector, "getMoonName")
    end

    r.blockLight = call(detector, "getBlockLightLevel")
    r.skyLight = call(detector, "getSkyLightLevel")
    r.dayLight = call(detector, "getDayLightLevel")
    r.slimeChunk = call(detector, "isSlimeChunk") == true

    -- Mekanism radiation (nil if Mekanism isn't installed)
    r.radiation = tonumber(call(detector, "getRadiationRaw"))

    local rad = call(detector, "getRadiation")

    if type(rad) == "table" and rad.radiation then
        r.radiationText = rad.radiation .. " " .. (rad.unit or "")
    end

    local entities, err = readEntities(detector, range)

    if entities then
        r.entities = entities
    else
        -- On cooldown or out of energy: keep the last list
        r.entities = previous[name] and previous[name].entities or {}
        r.scanError = err
    end

    previous[name] = r

    return r
end

-- Returns { detectors = { reading, ... }, radiation = highest Sv/h or nil, alert = text or nil }
function env.read()
    local range = math.max(1, math.min(16, settings.get("baseos.env_range")))
    local names = {}

    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "environment_detector") then
            table.insert(names, name)
        end
    end

    table.sort(names)

    local result = { detectors = {} }

    for _, name in ipairs(names) do
        local r = readDetector(name, peripheral.wrap(name), range)

        table.insert(result.detectors, r)

        if r.radiation and (not result.radiation or r.radiation > result.radiation) then
            result.radiation = r.radiation
            result.radiationText = r.radiationText
        end
    end

    if result.radiation and result.radiation >= settings.get("baseos.env_radiation_alert") then
        result.alert = { "RADIATION " .. (result.radiationText or ""), "RADIATION!", "RAD!" }
    end

    return result
end

-- Title bar text variants, longest first, e.g. { "Rain | Full moon", "Rain" }
function env.status(data)
    local r = data and data.detectors[1]

    if not r then
        return nil
    end

    if r.night and r.moon then
        return { r.weather .. " | " .. r.moon, r.weather }
    end

    return { r.weather }
end

return env
