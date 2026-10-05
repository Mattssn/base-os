-- Base OS: keep your inventory stocked from the ME system
--
-- The Inventory Manager (Advanced Peripherals) can only move items between your inventory and a
-- container touching it, so items go: ME Bridge -> buffer chest -> Inventory Manager -> you.
-- Anything that doesn't fit goes back into the ME system.
--
-- From the AP 1.21.1 source: exportItem/importItem/addItemToPlayer return the number of items
-- moved (count defaults to 64, more than a stack is fine); the bridge's target can be a side of
-- the bridge or the name of a chest on the computer's network. The Memory Card must be bound to
-- you, and you have to be online.

local restock = {}

local INTERVAL = 5
local SIDES = { "north", "south", "east", "west", "up", "down" }

settings.define("baseos.restock", {
    description = "Base OS restock list (edit with the restock command)",
    type = "table",
    default = {}
})

settings.define("baseos.restock_chest", {
    description = "Base OS restock buffer chest, as the ME Bridge reaches it (set by restock setup)",
    type = "string"
})

settings.define("baseos.restock_side", {
    description = "Side of the Inventory Manager the buffer chest is on (set by restock setup)",
    type = "string"
})

settings.define("baseos.restock_enabled", {
    description = "Base OS restock on/off",
    type = "boolean",
    default = true
})

restock.status = "Starting..."
restock.ok = false
restock.have = {} -- item name -> count in your inventory
restock.log = {}  -- recent deliveries, newest first: { time, text }

local function call(p, method, ...)
    if not p or type(p[method]) ~= "function" then
        return nil, "missing " .. method
    end

    local ok, a, b = pcall(p[method], ...)

    if ok then
        return a, b
    end

    return nil, a
end

local function log(text)
    table.insert(restock.log, 1, { time = textutils.formatTime(os.time(), false), text = text })

    while #restock.log > 20 do
        table.remove(restock.log)
    end
end

--------------------------------------------------
-- RULES
--------------------------------------------------

-- { { name = "minecraft:torch", label = "Torch", keep = 64 }, ... }
function restock.rules()
    local rules = {}

    for i, rule in ipairs(settings.get("baseos.restock") or {}) do
        rules[i] = { name = rule.name, label = rule.label, keep = rule.keep }
    end

    return rules
end

local function saveRules(rules)
    settings.set("baseos.restock", rules)
    settings.save()
    os.queueEvent("baseos_restock")
end

function restock.add(name, label, keep)
    local rules = restock.rules()

    for _, rule in ipairs(rules) do
        if rule.name == name then
            rule.keep = keep
            saveRules(rules)
            return
        end
    end

    table.insert(rules, { name = name, label = label, keep = keep })
    saveRules(rules)
end

function restock.remove(index)
    local rules = restock.rules()
    local removed = table.remove(rules, index)

    saveRules(rules)

    return removed
end

function restock.enabled()
    return settings.get("baseos.restock_enabled")
end

function restock.setEnabled(on)
    settings.set("baseos.restock_enabled", on)
    settings.save()
    os.queueEvent("baseos_restock")
end

--------------------------------------------------
-- ONE PASS
--------------------------------------------------

local function setStatus(text, ok)
    restock.status = text
    restock.ok = ok
end

local function cycle()
    local rules = restock.rules()

    if not restock.enabled() then
        return setStatus("Off", false)
    elseif #rules == 0 then
        return setStatus("Nothing to keep yet (restock add)", false)
    end

    local manager = peripheral.find("inventory_manager")
    local bridge = peripheral.find("me_bridge")
    local chest = settings.get("baseos.restock_chest")
    local side = settings.get("baseos.restock_side")

    if not manager then
        return setStatus("No Inventory Manager", false)
    elseif not bridge then
        return setStatus("No ME Bridge", false)
    elseif not chest or not side then
        return setStatus("Not set up (restock setup)", false)
    end

    local items = call(manager, "getItems")

    if type(items) ~= "table" then
        return setStatus("You're offline, or no Memory Card", false)
    end

    -- Anything left in the buffer chest (e.g. after a crash) goes back into the ME system
    local leftovers = call(manager, "listChest", side)

    if type(leftovers) == "table" then
        for _, item in ipairs(leftovers) do
            call(bridge, "importItem", { name = item.name, count = item.count }, chest)
        end
    end

    local have = {}

    for _, item in ipairs(items) do
        have[item.name] = (have[item.name] or 0) + (tonumber(item.count) or 0)
    end

    restock.have = have

    local full, short = false, 0

    for _, rule in ipairs(rules) do
        local need = rule.keep - (have[rule.name] or 0)

        if need > 0 then
            local moved = tonumber((call(bridge, "exportItem", { name = rule.name, count = need }, chest))) or 0

            if moved > 0 then
                local given = tonumber((call(manager, "addItemToPlayer", side, { name = rule.name, count = moved }))) or 0

                if given > 0 then
                    have[rule.name] = (have[rule.name] or 0) + given
                    log("+" .. given .. " " .. rule.label)
                end

                if given < moved then
                    full = true
                    call(bridge, "importItem", { name = rule.name, count = moved - given }, chest)
                end
            end

            if not full and moved < need then
                short = short + 1
            end
        end
    end

    if full then
        setStatus("Your inventory is full", false)
    elseif short > 0 then
        setStatus(short .. " item(s) ran out in the ME system", false)
    else
        setStatus("All stocked", true)
    end
end

function restock.run()
    while true do
        local ok, err = pcall(cycle)

        if not ok then
            setStatus("Error: " .. tostring(err), false)
        end

        -- Wake early when the list changes
        local timer = os.startTimer(INTERVAL)

        repeat
            local event, id = os.pullEvent()
        until (event == "timer" and id == timer) or event == "baseos_restock"
    end
end

--------------------------------------------------
-- SETUP: find the buffer chest automatically
--------------------------------------------------

-- Sends 1 of the most common ME item to each candidate chest and checks which side of the
-- Inventory Manager it shows up on, then takes it back. `items` = the ME item list.
function restock.setup(say, items)
    local manager = peripheral.find("inventory_manager")
    local bridge = peripheral.find("me_bridge")

    if not manager then
        return say("No Inventory Manager found. Connect it with a wired modem.")
    elseif not bridge then
        return say("No ME Bridge found.")
    end

    local sides = {}

    for _, side in ipairs(SIDES) do
        if type(call(manager, "listChest", side)) == "table" then
            table.insert(sides, side)
        end
    end

    if #sides == 0 then
        return say("Put an empty chest against the Inventory Manager first.")
    end

    local test

    for _, item in ipairs(items) do
        if (tonumber(item.count) or 0) > 0 and (not test or item.count > test.count) then
            test = item
        end
    end

    if not test then
        return say("The ME system looks empty; I need one item to test with.")
    end

    local function countOn(side)
        local n = 0

        for _, item in ipairs(call(manager, "listChest", side) or {}) do
            if item.name == test.name then
                n = n + (tonumber(item.count) or 0)
            end
        end

        return n
    end

    -- Chests on the network first (chest-like names before other inventories), then the
    -- sides of the ME Bridge in case the chest touches it directly
    local candidates = {}

    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "inventory") then
            local chestLike = name:find("chest") or name:find("barrel") or name:find("crate")
            table.insert(candidates, chestLike and 1 or #candidates + 1, name)
        end
    end

    for _, side in ipairs(SIDES) do
        table.insert(candidates, side)
    end

    say("Testing with 1 " .. (test.displayName or test.name) .. "...")

    for _, target in ipairs(candidates) do
        local before = {}

        for _, side in ipairs(sides) do
            before[side] = countOn(side)
        end

        local moved = tonumber((call(bridge, "exportItem", { name = test.name, count = 1 }, target))) or 0

        if moved > 0 then
            local found

            for _, side in ipairs(sides) do
                if countOn(side) > before[side] then
                    found = side
                    break
                end
            end

            call(bridge, "importItem", { name = test.name, count = 1 }, target)

            if found then
                settings.set("baseos.restock_chest", target)
                settings.set("baseos.restock_side", found)
                settings.save()
                os.queueEvent("baseos_restock")

                return say("Found it: ME Bridge -> " .. target .. ", Inventory Manager side: " .. found), true
            end
        end
    end

    say("Couldn't find a chest that both the ME Bridge and the Inventory Manager reach.")
    say("Put a chest against the Inventory Manager, and either connect the chest")
    say("to the network with a wired modem or put it against the ME Bridge too.")
end

return restock
