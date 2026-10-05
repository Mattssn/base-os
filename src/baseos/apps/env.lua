-- Base OS app: Environment
-- Everything each environment detector reports, plus the living entities near it.

local ui = require("ui")
local env = require("env")

local app = {
    id = "env",
    title = "ENVIRONMENT",
    color = colors.green
}

local function yesNo(value)
    return value and "yes" or "no"
end

-- Info rows for one detector. Returns the next free row.
local function drawInfo(screen, r, y, alert)
    local width = screen.w - 2

    screen:text(2, y, r.dimension .. " / " .. r.biome, colors.lime, nil, width - #r.name - 1)
    screen:text(screen.w - #r.name, y, r.name, colors.gray)
    y = y + 1

    local sky = r.night and "night" or "day"
    local moon = r.moon and ("   Moon: " .. r.moon) or ""

    screen:row(y, "Time: " .. r.time .. " (" .. sky .. ")   Weather: " .. r.weather .. moon, colors.white, nil, 2)
    y = y + 1

    screen:row(y, ("Light: block %s  sky %s  day %s   Slime chunk: %s"):format(
        r.blockLight or "?", r.skyLight or "?", r.dayLight or "?", yesNo(r.slimeChunk)), colors.lightGray, nil, 2)
    y = y + 1

    if r.radiation then
        local high = r.radiation >= settings.get("baseos.env_radiation_alert")

        screen:row(y, "Radiation: " .. (r.radiationText or tostring(r.radiation)) .. (high and "   ALERT" or "   ok"),
            high and colors.red or colors.lightGray, nil, 2)
        y = y + 1
    end

    return y
end

-- Entity list for one detector between rows y and last. Returns the next free row.
local function drawEntities(screen, r, y, last)
    local width = screen.w - 2
    local summary = {}

    for i, g in ipairs(env.groups(r.entities)) do
        if i > 4 then
            break
        end

        table.insert(summary, g.count .. " " .. g.name)
    end

    local header = "NEARBY (" .. #r.entities .. ")"

    if #summary > 0 then
        header = header .. "  " .. table.concat(summary, ", ")
    end

    screen:row(y, header, colors.green, nil, 2)
    y = y + 1

    if r.scanError and #r.entities == 0 then
        screen:row(y, "Scan: " .. tostring(r.scanError), colors.orange, nil, 2)
        return y + 1
    end

    for i = 1, last - y + 1 do
        local e = r.entities[i]

        if not e then
            break
        end

        local hp = e.health and e.maxHealth and ("%d/%d hp  "):format(math.ceil(e.health), math.ceil(e.maxHealth)) or ""
        local right = " " .. hp .. ("%.1fm"):format(e.distance)
        local name = (e.baby and "Baby " or "") .. e.name

        screen:text(2, y, name, colors.white, nil, width - #right)
        screen:text(screen.w - #right, y, right, colors.lightGray)
        y = y + 1
    end

    return y
end

function app.draw(screen, s)
    local h = screen.h
    local data = s.env

    screen:titleBar("", ui.clock(), "ENVIRONMENT")
    screen:button("home", 1, 1, 8, 1, "< HOME", colors.white, colors.gray)

    local y = 3

    if not data or #data.detectors == 0 then
        screen:row(y, "No environment detector found.", colors.orange, nil, 2)
        screen:row(y + 1, "Connect one with a wired modem (or place it", colors.lightGray, nil, 2)
        screen:row(y + 2, "next to the computer).", colors.lightGray, nil, 2)
        screen:blank(y + 3, h)
        return
    end

    -- Share the screen between detectors
    local per = math.floor((h - 2) / #data.detectors)

    for i, r in ipairs(data.detectors) do
        local last = i == #data.detectors and h or y + per - 2

        y = drawInfo(screen, r, y, data.alert)
        y = drawEntities(screen, r, y + 1, last)

        screen:blank(y, last)
        y = last + 2

        if i < #data.detectors then
            screen:blank(last + 1, last + 1)
        end
    end
end

return app
