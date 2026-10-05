-- Base OS app: Restock
-- What's kept stocked in your inventory from the ME system. Everything can be done by tapping:
--   list:   each item with -/+ (change the amount) and x (tap twice to remove), and + ADD
--   pick:   on-screen keyboard to search the ME system, tap an item
--   amount: choose how many to keep, then ADD
-- Each monitor has its own view state (screen.restock). The console `restock` command works too.

local ui = require("ui")
local restock = require("restock")

local app = {
    id = "restock",
    title = "RESTOCK",
    color = colors.orange
}

local STEP = 16 -- -/+ on the list
local KEYS = { "ABCDEFGHIJKLM", "NOPQRSTUVWXYZ" }

local function state(screen)
    screen.restock = screen.restock or { mode = "list", filter = "", page = 1, count = 64, visible = {} }
    return screen.restock
end

function app.open(screen)
    screen.restock = nil
end

--------------------------------------------------
-- LIST
--------------------------------------------------

local function drawList(screen, st)
    local w, h = screen.w, screen.h
    local width = w - 2
    local on = restock.enabled()

    screen:text(2, 3, "Status:", colors.lightGray)
    screen:text(10, 3, restock.status, restock.ok and colors.lime or colors.orange, nil, width - 16)
    screen:button("restock_toggle", w - 6, 3, 6, 1, on and "ON" or "OFF", colors.white, on and colors.green or colors.red)

    local rules = restock.rules()

    screen:text(2, 5, "KEEPING IN YOUR INVENTORY (" .. #rules .. ")", colors.orange, nil, width - 9)
    screen:button("restock_add", w - 8, 5, 8, 1, "+ ADD", colors.white, colors.green)

    local logRows = math.min(#restock.log, math.max(0, math.floor((h - 8 - #rules) / 2)))
    local listEnd = h - 1 - (logRows > 0 and logRows + 2 or 0)
    local y = 6

    -- Row: name | bar | have/keep | [-] [+] [x]
    local controls = 11

    for i, rule in ipairs(rules) do
        if y > listEnd then
            break
        end

        local have = restock.have[rule.name] or 0
        local count = (" %d/%d "):format(have, rule.keep)
        local nameW = math.min(20, math.floor((width - controls) / 2))
        local barW = width - controls - nameW - #count - 1
        local confirming = st.confirm == i

        screen:text(2, y, rule.label, colors.white, nil, nameW + 1)
        screen:bar(3 + nameW, y, barW, have / rule.keep, have >= rule.keep and colors.lime or colors.orange)
        screen:text(w - controls - #count, y, count, colors.lightGray)
        screen:button("restock_minus:" .. i, w - 11, y, 3, 1, "-", colors.white, colors.gray)
        screen:text(w - 8, y, " ")
        screen:button("restock_plus:" .. i, w - 7, y, 3, 1, "+", colors.white, colors.gray)
        screen:text(w - 4, y, " ")
        screen:button("restock_del:" .. i, w - 3, y, 3, 1, confirming and "?" or "x", colors.white, confirming and colors.orange or colors.red)
        y = y + 1
    end

    if #rules == 0 then
        screen:row(y, "Nothing yet. Tap + ADD to pick an item.", colors.gray, nil, 2)
        y = y + 1
    end

    screen:blank(y, listEnd)

    if logRows > 0 then
        screen:row(listEnd + 1, "")
        screen:row(listEnd + 2, "RECENT", colors.orange, nil, 2)

        for i = 1, logRows do
            local entry = restock.log[i]
            screen:row(listEnd + 2 + i, entry.time .. "  " .. entry.text, colors.lightGray, nil, 2)
        end
    end

    screen:row(h, st.confirm and " Tap ? again to remove it" or " -/+ change the amount, x removes", colors.gray)
end

--------------------------------------------------
-- PICK (search the ME system)
--------------------------------------------------

-- ME items matching the search (restock.search ranks them), cached until the search
-- or the ME item list changes
local function matches(st, items)
    if not (st.cache and st.cache.items == items and st.cache.filter == st.filter) then
        st.cache = { items = items, filter = st.filter, list = restock.search(items, st.filter) }
    end

    return st.cache.list
end

local function drawPick(screen, st, items)
    local w, h = screen.w, screen.h
    local width = w - 2

    screen:text(2, 3, "Search: ", colors.lightGray)
    screen:text(10, 3, st.filter:upper() .. "_", colors.white, nil, width - 18)
    screen:button("restock_cancel", w - 8, 3, 8, 1, "CANCEL", colors.white, colors.gray)

    -- Keyboard
    local keyW = math.max(2, math.min(4, math.floor((width + 1) / 13) - 1))

    for row, keys in ipairs(KEYS) do
        local x = 2

        for i = 1, #keys do
            local key = keys:sub(i, i)
            screen:button("restock_key:" .. key, x, 4 + row, keyW, 1, key, colors.white, colors.gray)
            screen:text(x + keyW, 4 + row, " ")
            x = x + keyW + 1
        end
    end

    screen:button("restock_space", 2, 7, 9, 1, "SPACE", colors.white, colors.gray)
    screen:text(11, 7, " ")
    screen:button("restock_back", 12, 7, 7, 1, "DEL", colors.white, colors.gray)
    screen:text(19, 7, " ")
    screen:button("restock_clear", 20, 7, 9, 1, "CLEAR", colors.white, colors.gray)

    -- Results
    local list = matches(st, items)
    local first, last = 9, h - 2
    local perPage = math.max(1, last - first + 1)
    local pages = math.max(1, math.ceil(#list / perPage))

    st.page = math.max(1, math.min(st.page, pages))
    st.visible = {}

    for row = first, last do
        local k = row - first + 1
        local item = list[(st.page - 1) * perPage + k]

        if item then
            local count = " " .. ui.fmt(item.count)

            st.visible[k] = item
            screen:text(2, row, item.displayName or item.name, colors.white, nil, width - #count)
            screen:text(w - #count, row, count, colors.lightBlue)
            screen:hotspot("restock_pick:" .. k, 1, row, w, 1)
        else
            screen:row(row, row == first and #list == 0 and " No matching items in the ME system" or "", colors.gray)
        end
    end

    local pageText = ("%d/%d"):format(st.page, pages)

    screen:row(h - 1, "")
    screen:button("restock_prev", 2, h, 8, 1, "< PREV", colors.white, st.page > 1 and colors.gray or colors.black)
    screen:text(10, h, "", nil, nil, width - 16)
    screen:center(h, pageText, colors.lightGray)
    screen:button("restock_next", w - 8, h, 8, 1, "NEXT >", colors.white, st.page < pages and colors.gray or colors.black)
end

--------------------------------------------------
-- AMOUNT
--------------------------------------------------

local function existing(name)
    for _, rule in ipairs(restock.rules()) do
        if rule.name == name then
            return rule
        end
    end
end

local function drawAmount(screen, st)
    local w, h = screen.w, screen.h
    local width = w - 2
    local item = st.item

    screen:row(3, "Keep how many in your inventory?", colors.orange, nil, 2)
    screen:row(5, item.displayName or item.name, colors.lime, nil, 2)
    screen:row(6, item.name, colors.gray, nil, 2)
    screen:row(8, "")
    screen:center(8, tostring(st.count), colors.white)

    local steps = { -64, -16, -1, 1, 16, 64 }
    local stepW = math.max(3, math.floor((width + 1) / #steps) - 1)

    for i, step in ipairs(steps) do
        local x = 2 + (i - 1) * (stepW + 1)

        screen:button("restock_count:" .. step, x, 10, stepW, 3, (step > 0 and "+" or "") .. step, colors.white, step > 0 and colors.green or colors.red)
        screen:text(x + stepW, 11, " ")
    end

    local half = math.floor((width - 1) / 2)

    screen:button("restock_confirm", 2, 14, half, 3, existing(item.name) and "UPDATE" or "ADD", colors.white, colors.green)
    screen:button("restock_cancel", 3 + half, 14, width - half - 1, 3, "CANCEL", colors.white, colors.gray)
    screen:blank(17, h)
end

--------------------------------------------------
-- APP
--------------------------------------------------

function app.draw(screen, s)
    local st = state(screen)

    screen:titleBar("", ui.clock(), "RESTOCK")

    if not screen.pinned then
        screen:button("home", 1, 1, 8, 1, "< HOME", colors.white, colors.gray)
    end

    if st.mode == "pick" then
        drawPick(screen, st, s.items or {})
    elseif st.mode == "amount" and st.item then
        drawAmount(screen, st)
    else
        drawList(screen, st)
    end
end

-- Returns true when the view changes (main.lua clears the monitor first)
function app.touch(id, screen)
    local st = state(screen)
    local action, arg = id:match("^restock_(%a+):?(.*)$")
    local n = tonumber(arg)
    local confirm = st.confirm

    st.confirm = nil

    if action == "toggle" then
        restock.setEnabled(not restock.enabled())
    elseif action == "add" then
        st.mode, st.filter, st.page = "pick", "", 1
        return true
    elseif action == "minus" or action == "plus" then
        local rule = restock.rules()[n]

        if rule then
            local keep = rule.keep + (action == "plus" and STEP or -STEP)
            restock.setKeep(n, math.max(1, keep))
        end
    elseif action == "del" then
        if confirm == n then
            restock.remove(n)
            return true
        end

        st.confirm = n
    elseif action == "key" then
        st.filter, st.page = st.filter .. arg:lower(), 1
    elseif action == "space" then
        st.filter, st.page = st.filter .. " ", 1
    elseif action == "back" then
        st.filter, st.page = st.filter:sub(1, -2), 1
    elseif action == "clear" then
        st.filter, st.page = "", 1
    elseif action == "prev" then
        st.page = st.page - 1
    elseif action == "next" then
        st.page = st.page + 1
    elseif action == "pick" and st.visible[n] then
        local rule = existing(st.visible[n].name)

        st.item = st.visible[n]
        st.count = rule and rule.keep or 64
        st.mode = "amount"
        return true
    elseif action == "count" then
        st.count = math.max(1, st.count + n)
    elseif action == "confirm" and st.item then
        restock.add(st.item.name, st.item.displayName or st.item.name, st.count)
        st.mode, st.item = "list", nil
        return true
    elseif action == "cancel" then
        st.mode = st.mode == "amount" and "pick" or "list"
        return true
    end
end

return app
