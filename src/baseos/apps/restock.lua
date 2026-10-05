-- Base OS app: Restock
-- Shows what's kept stocked in your inventory from the ME system. Items are added on the
-- computer with `restock add`.

local ui = require("ui")
local restock = require("restock")

local app = {
    id = "restock",
    title = "RESTOCK",
    color = colors.orange
}

function app.draw(screen, s)
    local w, h = screen.w, screen.h
    local width = w - 2

    screen:titleBar("", ui.clock(), "RESTOCK")

    if not screen.pinned then
        screen:button("home", 1, 1, 8, 1, "< HOME", colors.white, colors.gray)
    end

    --------------------------------------------------
    -- STATUS + ON/OFF
    --------------------------------------------------

    local on = restock.enabled()
    local label = on and "ON" or "OFF"

    screen:text(2, 3, "Status:", colors.lightGray)
    screen:text(10, 3, restock.status, restock.ok and colors.lime or colors.orange, nil, width - 16)
    screen:button("restock_toggle", w - 6, 3, 6, 1, label, colors.white, on and colors.green or colors.red)

    --------------------------------------------------
    -- ITEMS
    --------------------------------------------------

    local rules = restock.rules()

    screen:row(5, "KEEPING IN YOUR INVENTORY (" .. #rules .. ")", colors.orange, nil, 2)

    local logRows = math.min(#restock.log, math.max(0, math.floor((h - 8 - #rules) / 2)))
    local listEnd = h - 1 - (logRows > 0 and logRows + 2 or 0)
    local y = 6

    for _, rule in ipairs(rules) do
        if y > listEnd then
            break
        end

        local have = restock.have[rule.name] or 0
        local count = (" %d/%d"):format(have, rule.keep)
        local nameW = math.min(24, math.floor(width / 2))
        local barW = width - nameW - #count - 1

        screen:text(2, y, rule.label, colors.white, nil, nameW)
        screen:text(2 + nameW, y, " ", nil, nil, 1)
        screen:bar(3 + nameW, y, barW, have / rule.keep, have >= rule.keep and colors.lime or colors.orange)
        screen:text(w - #count, y, count, colors.lightGray)
        y = y + 1
    end

    if #rules == 0 then
        screen:row(y, "Nothing yet. On the computer: restock add torch 64", colors.gray, nil, 2)
        y = y + 1
    end

    screen:blank(y, listEnd)

    --------------------------------------------------
    -- RECENT DELIVERIES
    --------------------------------------------------

    if logRows > 0 then
        screen:row(listEnd + 1, "")
        screen:row(listEnd + 2, "RECENT", colors.orange, nil, 2)

        for i = 1, logRows do
            local entry = restock.log[i]
            screen:row(listEnd + 2 + i, entry.time .. "  " .. entry.text, colors.lightGray, nil, 2)
        end
    end

    screen:row(h, " On the computer: restock add <item> <count>", colors.gray)
end

function app.touch(id)
    if id == "restock_toggle" then
        restock.setEnabled(not restock.enabled())
    end
end

return app
