-- Base OS app: ME System
-- Full AE2 dashboard (energy, cells, storage bus, crafting, top items) plus item flow.
-- Wide monitors get the flow in its own column on the right; narrow ones stack it below.

local ui = require("ui")
local me = require("me")

local app = {
    id = "me",
    title = "ME SYSTEM",
    color = colors.cyan
}

local WIDE = 56 -- monitors at least this many characters wide use two columns

--------------------------------------------------
-- COLUMN HELPERS (a column is { x = left edge, w = width })
--------------------------------------------------

local function line(screen, col, y, text, fg)
    screen:text(col.x, y, text, fg, nil, col.w)
end

-- Name on the left, value right-aligned
local function entry(screen, col, y, name, value, valueColor)
    value = " " .. value

    screen:text(col.x, y, name, colors.white, nil, col.w - #value)
    screen:text(col.x + col.w - #value, y, value, valueColor)
end

-- Split rows y1..y2 evenly between sections, each a header plus entries.
-- section = { title, color, entries = { { name, value } } }
local function lists(screen, col, y1, y2, sections)
    local per = math.floor((y2 - y1 + 1) / #sections)
    local y = y1

    for i, section in ipairs(sections) do
        local last = i == #sections and y2 or y + per - 1

        line(screen, col, y, section.title, section.color)

        for row = y + 1, last do
            local e = section.entries[row - y]

            if e and (row < last or i == #sections) then
                entry(screen, col, row, e.name, e.value, section.color)
            else
                line(screen, col, row, "")
            end
        end

        y = last + 1
    end
end

local function perMin(rate)
    return ui.fmt(rate) .. "/m"
end

--------------------------------------------------
-- LIST DATA
--------------------------------------------------

local function topItems(s)
    local items = {}

    for i, item in ipairs(s.items) do
        items[i] = item
    end

    table.sort(items, function(a, b)
        return (tonumber(a.count) or 0) > (tonumber(b.count) or 0)
    end)

    local entries = {}

    for i, item in ipairs(items) do
        entries[i] = {
            name = item.displayName or item.name or "Unknown",
            value = ui.fmt(item.count)
        }
    end

    return { title = "TOP ITEMS", color = colors.lightBlue, entries = entries }
end

local function flowList(title, color, sign, rates)
    local entries = {}

    for i, r in ipairs(rates) do
        entries[i] = { name = r.name, value = sign .. perMin(r.rate) }
    end

    return { title = title, color = color, entries = entries }
end

--------------------------------------------------
-- SECTIONS
--------------------------------------------------

-- Grid, power, storage, network: rows 3-19
local function drawDashboard(screen, s, col)
    local status, statusColor = me.status(s)

    screen:text(col.x, 3, "GRID:", colors.lightGray)
    screen:text(col.x + 6, 3, status, statusColor, nil, col.w - 6)

    local energyPct = ui.pct(s.energy, s.energyMax)

    line(screen, col, 5, "POWER", colors.yellow)
    line(screen, col, 6, ui.fmt(s.energy) .. " / " .. ui.fmt(s.energyMax) .. " AE", colors.white)
    screen:bar(col.x, 7, col.w, energyPct, colors.lime)
    line(screen, col, 8, string.format("%.1f%%   Usage: %s AE/t", energyPct * 100, ui.fmt(s.energyUsage)), colors.lightGray)

    line(screen, col, 10, "STORAGE", colors.orange)
    line(screen, col, 11, "Items visible: " .. ui.fmt(s.totalItems), colors.white)
    line(screen, col, 12, "Cells: " .. #s.cells .. "   " .. ui.fmt(s.internalUsed) .. " / " .. ui.fmt(s.internalMax) .. " bytes", colors.lightGray)
    screen:bar(col.x, 13, col.w, ui.pct(s.internalUsed, s.internalMax), colors.cyan)
    line(screen, col, 14, "Storage Bus: " .. ui.fmt(s.externalUsed) .. " / " .. ui.fmt(s.externalMax) .. " items", colors.lightGray)
    screen:bar(col.x, 15, col.w, ui.pct(s.externalUsed, s.externalMax), colors.orange)

    local craft, craftColor = me.craftingStatus(s)

    line(screen, col, 17, "NETWORK", colors.cyan)
    line(screen, col, 18, "Item Types: " .. #s.items, colors.white)
    line(screen, col, 19, "Crafting: " .. craft, craftColor)
end

-- Flow header + in/out totals + status: 3 rows starting at y
local function drawFlowSummary(screen, f, col, y)
    line(screen, col, y, "ITEM FLOW", colors.magenta)

    local inText = "IN +" .. perMin(f.totalIn) .. "   "

    screen:text(col.x, y + 1, inText, colors.lime)
    screen:text(col.x + #inText, y + 1, "OUT -" .. perMin(f.totalOut), colors.red, nil, col.w - #inText)

    if f.ready then
        local net = f.totalIn - f.totalOut
        local sign = net < 0 and "-" or "+"

        line(screen, col, y + 2, "Net " .. sign .. perMin(math.abs(net)) .. "  (last " .. f.window .. "s)", colors.lightGray)
    else
        line(screen, col, y + 2, "Measuring... " .. math.floor(f.elapsed) .. "/" .. f.window .. "s", colors.gray)
    end
end

--------------------------------------------------
-- DRAW
--------------------------------------------------

function app.draw(screen, s)
    local w, h = screen.w, screen.h
    local f = s.flow

    screen:titleBar("", ui.clock(), "ME SYSTEM")

    if not screen.pinned then
        screen:button("home", 1, 1, 8, 1, "< HOME", colors.white, colors.gray)
    end

    local incoming = flowList("TOP INCOMING", colors.lime, "+", f.incoming)
    local outgoing = flowList("TOP OUTGOING", colors.red, "-", f.outgoing)

    if w >= WIDE then
        local half = math.floor(w / 2)
        local left = { x = 2, w = half - 2 }
        local right = { x = half + 2, w = w - half - 2 }

        drawDashboard(screen, s, left)

        if h >= 23 then
            lists(screen, left, 21, h, { topItems(s) })
        end

        drawFlowSummary(screen, f, right, 3)

        if h >= 10 then
            lists(screen, right, 7, h, { incoming, outgoing })
        end
    else
        local col = { x = 2, w = w - 2 }

        drawDashboard(screen, s, col)
        drawFlowSummary(screen, f, col, 21)

        -- Only show the lists that get at least a few entries each
        if h >= 36 then
            lists(screen, col, 25, h, { topItems(s), incoming, outgoing })
        elseif h >= 30 then
            lists(screen, col, 25, h, { incoming, outgoing })
        end
    end
end

return app
