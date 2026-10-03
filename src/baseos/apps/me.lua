-- Base OS app: ME System
-- Full AE2 dashboard (energy, cells, storage bus, crafting, top items).

local ui = require("ui")
local me = require("me")

local app = {
    id = "me",
    title = "ME SYSTEM",
    color = colors.cyan
}

local function drawTopItems(screen, s, firstRow)
    local items = {}

    for i, item in ipairs(s.items) do
        items[i] = item
    end

    table.sort(items, function(a, b)
        return (tonumber(a.count) or 0) > (tonumber(b.count) or 0)
    end)

    local width = screen.w - 2

    for row = firstRow, screen.h do
        local item = items[row - firstRow + 1]

        if item then
            local countText = " " .. ui.fmt(item.count)
            local name = item.displayName or item.name or "Unknown"

            screen:text(2, row, name, colors.white, nil, width - #countText)
            screen:text(2 + width - #countText, row, countText, colors.lightBlue)
        else
            screen:row(row, "")
        end
    end
end

function app.draw(screen, s)
    local w = screen.w

    screen:titleBar("", ui.clock())
    screen:button("home", 1, 1, 8, 1, "< HOME", colors.white, colors.gray)
    screen:center(1, "ME SYSTEM", colors.white, colors.blue)

    --------------------------------------------------
    -- GRID STATUS
    --------------------------------------------------

    local status, statusColor = me.status(s)

    screen:text(2, 3, "GRID:", colors.lightGray)
    screen:row(3, status, statusColor, nil, 8)

    --------------------------------------------------
    -- POWER
    --------------------------------------------------

    local energyPct = ui.pct(s.energy, s.energyMax)

    screen:row(5, "POWER", colors.yellow, nil, 2)
    screen:row(6, ui.fmt(s.energy) .. " / " .. ui.fmt(s.energyMax) .. " AE", colors.white, nil, 2)
    screen:bar(2, 7, w - 2, energyPct, colors.lime)
    screen:row(8, string.format("%.1f%%   Usage: %s AE/t", energyPct * 100, ui.fmt(s.energyUsage)), colors.lightGray, nil, 2)

    --------------------------------------------------
    -- STORAGE
    --------------------------------------------------

    screen:row(10, "STORAGE", colors.orange, nil, 2)
    screen:row(11, "Items visible: " .. ui.fmt(s.totalItems), colors.white, nil, 2)

    screen:row(12, "Cells: " .. #s.cells .. "   " .. ui.fmt(s.internalUsed) .. " / " .. ui.fmt(s.internalMax) .. " bytes", colors.lightGray, nil, 2)
    screen:bar(2, 13, w - 2, ui.pct(s.internalUsed, s.internalMax), colors.cyan)

    screen:row(14, "Storage Bus: " .. ui.fmt(s.externalUsed) .. " / " .. ui.fmt(s.externalMax) .. " items", colors.lightGray, nil, 2)
    screen:bar(2, 15, w - 2, ui.pct(s.externalUsed, s.externalMax), colors.orange)

    --------------------------------------------------
    -- NETWORK
    --------------------------------------------------

    local craft, craftColor = me.craftingStatus(s)

    screen:row(17, "NETWORK", colors.cyan, nil, 2)
    screen:row(18, "Item Types: " .. #s.items, colors.white, nil, 2)
    screen:row(19, "Crafting: " .. craft, craftColor, nil, 2)

    --------------------------------------------------
    -- TOP ITEMS
    --------------------------------------------------

    if screen.h >= 22 then
        screen:row(21, "TOP ITEMS", colors.lightBlue, nil, 2)
        drawTopItems(screen, s, 22)
    end
end

return app
