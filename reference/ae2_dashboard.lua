-- AE2 Dashboard
-- CC:Tweaked + Advanced Peripherals
-- Minecraft 1.21.1
--
-- Supports:
--   AE2 ME Cells
--   AE2 Storage Buses / Drawers
--   Top Items
--   Crafting
--   AE2 Energy
--
-- Flicker-free: does NOT clear the whole monitor every refresh

local bridge = peripheral.find("me_bridge")
local monitor = peripheral.find("monitor")

if not bridge then
    error("ME Bridge not found!")
end

if not monitor then
    error("Monitor not found!")
end

--------------------------------------------------
-- MONITOR SETUP
--------------------------------------------------

monitor.setTextScale(0.5)
monitor.setBackgroundColor(colors.black)
monitor.setTextColor(colors.white)
monitor.clear()

local w, h = monitor.getSize()

--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function formatNumber(n)
    n = tonumber(n) or 0

    if n >= 1000000000000 then
        return string.format("%.2fT", n / 1000000000000)
    elseif n >= 1000000000 then
        return string.format("%.2fB", n / 1000000000)
    elseif n >= 1000000 then
        return string.format("%.2fM", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.1fK", n / 1000)
    else
        return tostring(math.floor(n))
    end
end

local function safeCall(func, default)
    local ok, result = pcall(func)

    if ok and result ~= nil then
        return result
    end

    return default
end

local function hasMethod(methodName)
    return type(bridge[methodName]) == "function"
end

local function callFirst(methods, default)
    for _, methodName in ipairs(methods) do
        if hasMethod(methodName) then
            local ok, result = pcall(function()
                return bridge[methodName]()
            end)

            if ok and result ~= nil then
                return result
            end
        end
    end

    return default
end

local function writeAt(x, y, text, color, background)
    if y < 1 or y > h then
        return
    end

    monitor.setCursorPos(x, y)
    monitor.setTextColor(color or colors.white)
    monitor.setBackgroundColor(background or colors.black)
    monitor.write(tostring(text))
end

local function clearArea(x, y, width)
    if y < 1 or y > h then
        return
    end

    if width < 1 then
        return
    end

    monitor.setCursorPos(x, y)
    monitor.setBackgroundColor(colors.black)
    monitor.write(string.rep(" ", width))
end

local function updateText(x, y, width, text, color)
    clearArea(x, y, width)
    writeAt(x, y, text, color)
end

local function center(y, text, color)
    local x = math.floor((w - #text) / 2) + 1

    if x < 1 then
        x = 1
    end

    writeAt(x, y, text, color)
end

local function drawBar(x, y, width, percent, barColor)
    if width < 1 then
        return
    end

    percent = tonumber(percent) or 0
    percent = math.max(0, math.min(1, percent))

    local filled = math.floor(width * percent)

    monitor.setCursorPos(x, y)

    monitor.setBackgroundColor(colors.gray)
    monitor.write(string.rep(" ", width))

    if filled > 0 then
        monitor.setCursorPos(x, y)
        monitor.setBackgroundColor(barColor or colors.lime)
        monitor.write(string.rep(" ", filled))
    end

    monitor.setBackgroundColor(colors.black)
end

local function percent(used, total)
    used = tonumber(used) or 0
    total = tonumber(total) or 0

    if total <= 0 then
        return 0
    end

    return used / total
end

--------------------------------------------------
-- BRIDGE API HELPERS
--------------------------------------------------

local function getItems()
    if hasMethod("getItems") then
        return safeCall(function()
            return bridge.getItems({})
        end, {})
    elseif hasMethod("listItems") then
        return safeCall(function()
            return bridge.listItems()
        end, {})
    end

    return {}
end

local function getCells()
    if hasMethod("getCells") then
        return safeCall(function()
            return bridge.getCells()
        end, {})
    elseif hasMethod("listCells") then
        return safeCall(function()
            return bridge.listCells()
        end, {})
    end

    return {}
end

local function getCraftingTasks()
    if hasMethod("getCraftingTasks") then
        return safeCall(function()
            return bridge.getCraftingTasks()
        end, {})
    end

    return {}
end

local function getCraftingCPUs()
    if hasMethod("getCraftingCPUs") then
        return safeCall(function()
            return bridge.getCraftingCPUs()
        end, {})
    end

    return {}
end

local function getStoredEnergy()
    return callFirst({
        "getStoredEnergy",
        "getEnergyStorage"
    }, 0)
end

local function getEnergyCapacity()
    return callFirst({
        "getEnergyCapacity",
        "getMaxEnergyStorage"
    }, 0)
end

local function getEnergyUsage()
    return callFirst({
        "getEnergyUsage"
    }, 0)
end

local function getInternalUsed()
    return callFirst({
        "getUsedItemStorage"
    }, 0)
end

local function getInternalMax()
    return callFirst({
        "getMaxItemStorage",
        "getTotalItemStorage"
    }, 0)
end

local function getExternalUsed()
    return callFirst({
        "getUsedExternItemStorage"
    }, 0)
end

local function getExternalMax()
    return callFirst({
        "getMaxExternItemStorage",
        "getTotalExternItemStorage"
    }, 0)
end

--------------------------------------------------
-- STATIC UI
--------------------------------------------------

center(1, "AE2 NETWORK DASHBOARD", colors.cyan)

writeAt(2, 3, "GRID:", colors.lightGray)

writeAt(2, 5, "POWER", colors.yellow)

writeAt(2, 10, "STORAGE", colors.orange)

writeAt(2, 17, "NETWORK", colors.cyan)

if h >= 22 then
    writeAt(2, 21, "TOP ITEMS", colors.lightBlue)
end

--------------------------------------------------
-- MAIN LOOP
--------------------------------------------------

while true do

    --------------------------------------------------
    -- GET ITEMS
    --------------------------------------------------

    local items = getItems()
    local cells = getCells()
    local crafting = getCraftingTasks()
    local cpus = getCraftingCPUs()

    --------------------------------------------------
    -- GRID STATUS
    --------------------------------------------------

    local connected = true
    local online = true

    if hasMethod("isConnected") then
        connected = safeCall(function()
            return bridge.isConnected()
        end, true)
    end

    if hasMethod("isOnline") then
        online = safeCall(function()
            return bridge.isOnline()
        end, true)
    end

    if connected and online then
        updateText(
            8,
            3,
            14,
            "ONLINE",
            colors.lime
        )
    else
        updateText(
            8,
            3,
            14,
            "OFFLINE",
            colors.red
        )
    end

    --------------------------------------------------
    -- POWER
    --------------------------------------------------

    local energy = getStoredEnergy()
    local energyMax = getEnergyCapacity()
    local energyUsage = getEnergyUsage()

    local energyPct = percent(
        energy,
        energyMax
    )

    updateText(
        2,
        6,
        w - 2,
        formatNumber(energy)
            .. " / "
            .. formatNumber(energyMax)
            .. " AE",
        colors.white
    )

    drawBar(
        2,
        7,
        math.max(1, w - 3),
        energyPct,
        colors.lime
    )

    updateText(
        2,
        8,
        w - 2,
        string.format(
            "%.1f%%   Usage: %s AE/t",
            energyPct * 100,
            formatNumber(energyUsage)
        ),
        colors.lightGray
    )

    --------------------------------------------------
    -- TOTAL ITEM COUNT
    --------------------------------------------------

    local totalItems = 0

    for _, item in ipairs(items) do
        totalItems =
            totalItems
            + (tonumber(item.count) or 0)
    end

    --------------------------------------------------
    -- STORAGE
    --------------------------------------------------

    local internalUsed = getInternalUsed()
    local internalMax = getInternalMax()

    local externalUsed = getExternalUsed()
    local externalMax = getExternalMax()

    local internalPct = percent(
        internalUsed,
        internalMax
    )

    local externalPct = percent(
        externalUsed,
        externalMax
    )

    updateText(
        2,
        11,
        w - 2,
        "Items visible: "
            .. formatNumber(totalItems),
        colors.white
    )

    --------------------------------------------------
    -- INTERNAL CELL STORAGE
    --------------------------------------------------

    updateText(
        2,
        12,
        w - 2,
        "Cells: "
            .. tostring(#cells)
            .. "   "
            .. formatNumber(internalUsed)
            .. " / "
            .. formatNumber(internalMax)
            .. " bytes",
        colors.lightGray
    )

    drawBar(
        2,
        13,
        math.max(1, w - 3),
        internalPct,
        colors.cyan
    )

    --------------------------------------------------
    -- EXTERNAL / STORAGE BUS
    --------------------------------------------------

    updateText(
        2,
        14,
        w - 2,
        "Storage Bus: "
            .. formatNumber(externalUsed)
            .. " / "
            .. formatNumber(externalMax)
            .. " stacks",
        colors.lightGray
    )

    drawBar(
        2,
        15,
        math.max(1, w - 3),
        externalPct,
        colors.orange
    )

    --------------------------------------------------
    -- NETWORK STATS
    --------------------------------------------------

    updateText(
        2,
        18,
        w - 2,
        "Item Types: "
            .. tostring(#items),
        colors.white
    )

    local busyCPUs = 0

    for _, cpu in ipairs(cpus) do
        if cpu.isBusy then
            busyCPUs = busyCPUs + 1
        end
    end

    local craftingText

    if #crafting > 0 then
        craftingText =
            tostring(#crafting)
            .. " active task(s)"
    elseif busyCPUs > 0 then
        craftingText =
            tostring(busyCPUs)
            .. " CPU(s) busy"
    else
        craftingText = "IDLE"
    end

    local craftingColor =
        craftingText == "IDLE"
        and colors.lime
        or colors.yellow

    updateText(
        2,
        19,
        w - 2,
        "Crafting: " .. craftingText,
        craftingColor
    )

    --------------------------------------------------
    -- TOP ITEMS
    --------------------------------------------------

    if h >= 22 then

        table.sort(
            items,
            function(a, b)
                return
                    (tonumber(a.count) or 0)
                    >
                    (tonumber(b.count) or 0)
            end
        )

        local firstRow = 22
        local rowsAvailable =
            h - firstRow + 1

        local maxRows =
            math.min(
                6,
                rowsAvailable,
                #items
            )

        --------------------------------------------------
        -- CLEAR OLD ROWS
        --------------------------------------------------

        for row = firstRow, h do
            clearArea(
                2,
                row,
                math.max(1, w - 2)
            )
        end

        --------------------------------------------------
        -- DRAW ITEMS
        --------------------------------------------------

        for i = 1, maxRows do

            local item = items[i]

            local name =
                item.displayName
                or item.name
                or "Unknown"

            local count =
                tonumber(item.count) or 0

            local countText =
                formatNumber(count)

            local maxNameLength =
                w - #countText - 5

            if maxNameLength < 5 then
                maxNameLength = 5
            end

            if #name > maxNameLength then
                name =
                    name:sub(
                        1,
                        maxNameLength - 2
                    ) .. ".."
            end

            local row =
                firstRow + i - 1

            writeAt(
                2,
                row,
                name,
                colors.white
            )

            writeAt(
                math.max(
                    2,
                    w - #countText
                ),
                row,
                countText,
                colors.lightBlue
            )
        end
    end

    --------------------------------------------------
    -- REFRESH
    --------------------------------------------------

    sleep(1)
end
