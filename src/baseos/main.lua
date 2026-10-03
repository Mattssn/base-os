-- Base OS
-- CC:Tweaked + Advanced Peripherals, Minecraft 1.21.1 (ATM10 To the Sky)
--
-- Runs on a monitor: a start screen with key stats, and apps you open by tapping.
-- Press Q on the computer to stop.

local root = fs.getDir(shell.getRunningProgram())
package.path = "/" .. fs.combine(root, "?.lua") .. ";" .. package.path

local ui = require("ui")
local me = require("me")
local home = require("home")

-- Apps shown on the start screen, in order. Add new ones here.
local apps = {
    require("apps.me")
}

local appsById = {}

for _, app in ipairs(apps) do
    appsById[app.id] = app
end

--------------------------------------------------
-- SETTINGS (change with e.g. `set baseos.text_scale 1`)
--------------------------------------------------

settings.define("baseos.text_scale", {
    description = "Base OS monitor text scale (0.5 - 5)",
    default = 0.5,
    type = "number"
})

settings.define("baseos.refresh", {
    description = "Base OS seconds between data refreshes",
    default = 1,
    type = "number"
})

local REFRESH = settings.get("baseos.refresh")

--------------------------------------------------
-- MONITOR
--------------------------------------------------

local monitor = peripheral.find("monitor")

if not monitor then
    error("Monitor not found!", 0)
end

local monitorName = peripheral.getName(monitor)

monitor.setTextScale(settings.get("baseos.text_scale"))

local screen = ui.new(monitor)

--------------------------------------------------
-- STATE
--------------------------------------------------

local current = "home"
local snapshot = me.empty()
snapshot.loading = true

local function draw()
    screen:resize()
    screen:clearButtons()

    if current == "home" then
        home.draw(screen, snapshot, apps)
    else
        appsById[current].draw(screen, snapshot)
    end
end

local function open(id)
    current = id
    screen:clear()
    draw()
end

--------------------------------------------------
-- LOOPS
--------------------------------------------------

-- Reads the ME system. Bridge calls take a few ticks, so this runs in its own
-- coroutine; otherwise taps made during a read would be lost.
local function poller()
    while true do
        snapshot = me.read()
        draw()
        sleep(REFRESH)
    end
end

local function input()
    while true do
        local event, a, b, c = os.pullEvent()

        if event == "monitor_touch" and a == monitorName then
            local id = screen:hit(b, c)

            if id == "home" then
                open("home")
            elseif id and appsById[id] then
                open(id)
            end
        elseif event == "monitor_resize" and a == monitorName then
            open(current)
        elseif event == "peripheral" or event == "peripheral_detach" then
            me.reset()
        elseif event == "key" and a == keys.q then
            return
        end
    end
end

term.clear()
term.setCursorPos(1, 1)
print("Base OS running on " .. monitorName)
print("Press Q to stop.")

open("home")
parallel.waitForAny(poller, input)

-- Clean exit
monitor.setBackgroundColor(colors.black)
monitor.clear()
monitor.setCursorPos(1, 1)
monitor.setTextColor(colors.gray)
monitor.write("Base OS stopped")

term.clear()
term.setCursorPos(1, 1)
print("Base OS stopped.")
