-- Base OS: start screen
-- Important stats at the top, app buttons along the bottom.

local ui = require("ui")
local me = require("me")
local fe = require("fe")
local music = require("music")
local env = require("env")
local restock = require("restock")

local home = {}

local LABEL = 11 -- width of the label column

local function stat(screen, y, label, value, color)
    screen:text(2, y, label, colors.lightGray, nil, LABEL)
    screen:row(y, value, color or colors.white, nil, 2 + LABEL)
end

local function statBar(screen, y, label, pct, color)
    local pctText = string.format(" %3d%%", math.floor(pct * 100 + 0.5))
    local barX = 2 + LABEL
    local barW = math.max(1, screen.w - barX - #pctText)

    screen:text(2, y, label, colors.lightGray, nil, LABEL)
    screen:bar(barX, y, barW, pct, color)
    screen:row(y, pctText, colors.white, nil, barX + barW)
end

local function storageColor(pct)
    if pct > 0.9 then
        return colors.red
    elseif pct > 0.75 then
        return colors.orange
    end

    return colors.cyan
end

function home.draw(screen, s, apps)
    screen:titleBar("BASE OS", ui.clock())

    --------------------------------------------------
    -- STATS
    --------------------------------------------------

    local y = 3

    screen:row(y, "OVERVIEW", colors.cyan, nil, 2)
    y = y + 1

    local status, statusColor = me.status(s)
    stat(screen, y, "ME Grid", status, statusColor)
    y = y + 1

    if s.present then
        local energyPct = ui.pct(s.energy, s.energyMax)
        statBar(screen, y, "Power", energyPct, energyPct < 0.2 and colors.red or colors.lime)
        y = y + 1

        if s.fe then
            local f = s.fe
            local text = ui.fmt(f.stored) .. (f.capacity and (" / " .. ui.fmt(f.capacity)) or "") .. " FE"
            local rate = fe.rateText(f, ui.fmt)

            stat(screen, y, "FE Stored", text .. (rate ~= "" and "   " .. rate or ""), colors.white)
            y = y + 1
        end

        local cellPct = ui.pct(s.internalUsed, s.internalMax)
        statBar(screen, y, "Cells", cellPct, storageColor(cellPct))
        y = y + 1

        if s.externalMax > 0 then
            local busPct = ui.pct(s.externalUsed, s.externalMax)
            statBar(screen, y, "Storage Bus", busPct, storageColor(busPct))
            y = y + 1
        end

        local craft, craftColor = me.craftingStatus(s)
        stat(screen, y, "Crafting", craft, craftColor)
        y = y + 1

        stat(screen, y, "Items", ui.fmt(s.totalItems) .. "  (" .. #s.items .. " types)")
        y = y + 1

        local inText = "+" .. ui.fmt(s.flow.totalIn) .. "/m in   "

        screen:text(2, y, "Flow", colors.lightGray, nil, LABEL)
        screen:text(2 + LABEL, y, inText, colors.lime)
        screen:row(y, "-" .. ui.fmt(s.flow.totalOut) .. "/m out", colors.red, nil, 2 + LABEL + #inText)
        y = y + 1
    end

    local e = s.env

    if e and #e.detectors > 0 then
        local r = e.detectors[1]

        stat(screen, y, "Weather", r.weather .. "  " .. r.time .. (r.night and " (night)" or ""), r.thunder and colors.yellow or colors.white)
        y = y + 1

        -- Entities near every detector together
        local all = {}

        for _, d in ipairs(e.detectors) do
            for _, entity in ipairs(d.entities) do
                table.insert(all, entity)
            end
        end

        local top = {}

        for i, g in ipairs(env.groups(all)) do
            if i > 3 then
                break
            end

            table.insert(top, g.count .. " " .. g.name)
        end

        stat(screen, y, "Nearby", #all .. (#top > 0 and "  (" .. table.concat(top, ", ") .. ")" or ""))
        y = y + 1

        if e.radiation then
            stat(screen, y, "Radiation", e.radiationText or tostring(e.radiation), e.alert and colors.red or colors.lime)
            y = y + 1
        end
    end

    if #restock.rules() > 0 then
        stat(screen, y, "Restock", restock.status, restock.ok and colors.lime or colors.orange)
        y = y + 1
    end

    if music.current then
        local state = music.state == "paused" and "|| " or "> "
        stat(screen, y, "Music", state .. music.current.title, colors.magenta)
        y = y + 1
    end

    --------------------------------------------------
    -- APPS (pinned to the bottom)
    --------------------------------------------------

    local appsHeader = screen.h - 4

    -- Wipe leftover rows if the stats list got shorter (e.g. bridge removed)
    screen:blank(y, appsHeader - 1)

    screen:row(appsHeader, "APPS", colors.cyan, nil, 2)

    local tileW = math.min(20, math.floor((screen.w - 1) / math.max(1, #apps)) - 1)
    local x = 2

    for _, app in ipairs(apps) do
        screen:button(app.id, x, screen.h - 3, tileW, 3, app.title, colors.white, app.color)
        x = x + tileW + 1
    end

    screen:row(screen.h, " Tap an app to open it", colors.gray)
end

return home
