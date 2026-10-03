-- Base OS: ME system data
-- Advanced Peripherals me_bridge, 1.21.1 storage-system API:
-- https://docs.advanced-peripherals.de/0.7/guides/storage_system_functions/

local me = {}

local bridge = nil

-- Call a bridge method if it exists. Returns nil if it's missing or errors.
local function call(name, ...)
    if not bridge or type(bridge[name]) ~= "function" then
        return nil
    end

    local ok, result = pcall(bridge[name], ...)

    if ok then
        return result
    end

    return nil
end

-- First method that exists and returns a value (covers older AP method names).
local function callFirst(names, default)
    for _, name in ipairs(names) do
        local result = call(name)

        if result ~= nil then
            return result
        end
    end

    return default
end

-- Forget the bridge so the next read looks for it again (after attach/detach).
function me.reset()
    bridge = nil
end

function me.empty()
    return {
        present = false,
        connected = false,
        online = false,
        items = {},
        cells = {},
        tasks = {},
        cpus = {},
        totalItems = 0,
        busyCPUs = 0,
        energy = 0,
        energyMax = 0,
        energyUsage = 0,
        internalUsed = 0,
        internalMax = 0,
        externalUsed = 0,
        externalMax = 0
    }
end

function me.read()
    if not bridge then
        bridge = peripheral.find("me_bridge")
    end

    local s = me.empty()

    if not bridge then
        return s
    end

    s.present = true
    s.connected = call("isConnected") ~= false
    s.online = call("isOnline") ~= false

    s.items = call("getItems", {}) or call("listItems") or {}
    s.cells = call("getCells") or call("listCells") or {}
    s.tasks = call("getCraftingTasks") or {}
    s.cpus = call("getCraftingCPUs") or {}

    for _, item in ipairs(s.items) do
        s.totalItems = s.totalItems + (tonumber(item.count) or 0)
    end

    for _, cpu in ipairs(s.cpus) do
        if cpu.isBusy then
            s.busyCPUs = s.busyCPUs + 1
        end
    end

    s.energy = callFirst({ "getStoredEnergy", "getEnergyStorage" }, 0)
    s.energyMax = callFirst({ "getEnergyCapacity", "getMaxEnergyStorage" }, 0)
    s.energyUsage = callFirst({ "getEnergyUsage" }, 0)

    -- AE2 reports internal (cell) storage in bytes, external (storage bus) in items
    s.internalUsed = callFirst({ "getUsedItemStorage" }, 0)
    s.internalMax = callFirst({ "getTotalItemStorage" }, 0)
    s.externalUsed = callFirst({ "getUsedExternItemStorage" }, 0)
    s.externalMax = callFirst({ "getTotalExternItemStorage" }, 0)

    return s
end

function me.status(s)
    if s.loading then
        return "LOADING", colors.lightGray
    elseif not s.present then
        return "NO ME BRIDGE", colors.red
    elseif not s.connected then
        return "DISCONNECTED", colors.red
    elseif not s.online then
        return "OFFLINE", colors.red
    end

    return "ONLINE", colors.lime
end

function me.craftingStatus(s)
    if #s.tasks > 0 then
        return #s.tasks .. " active task(s)", colors.yellow
    elseif s.busyCPUs > 0 then
        return s.busyCPUs .. " CPU(s) busy", colors.yellow
    end

    return "IDLE", colors.lime
end

return me
