-- Base OS
-- CC:Tweaked + Advanced Peripherals, Minecraft 1.21.1 (ATM10 To the Sky)
--
-- Runs on a monitor: a start screen with key stats, and apps you open by tapping.
-- Type on the computer to control music; `quit` (or Ctrl+T) stops Base OS.

local root = fs.getDir(shell.getRunningProgram())
package.path = "/" .. fs.combine(root, "?.lua") .. ";" .. package.path

local ui = require("ui")
local me = require("me")
local flow = require("flow")
local music = require("music")
local env = require("env")
local home = require("home")

-- Apps shown on the start screen, in order. Add new ones here.
local apps = {
    require("apps.me"),
    require("apps.music"),
    require("apps.env")
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

settings.define("baseos.flow_window", {
    description = "Base OS seconds of history used for items per minute",
    default = 60,
    type = "number"
})

local REFRESH = settings.get("baseos.refresh")
local FLOW_WINDOW = settings.get("baseos.flow_window")

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
snapshot.flow = flow.result

local envData = { detectors = {} }

local function draw()
    screen:resize()
    screen:clearButtons()
    snapshot.env = envData

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
        snapshot.flow = flow.update(snapshot, FLOW_WINDOW)
        draw()
        sleep(REFRESH)
    end
end

-- Environment detectors: every call takes a server tick, so read them slowly and
-- separately from the ME system.
local ENV_REFRESH = 5

local function envPoller()
    while true do
        envData = env.read()
        ui.status = env.status(envData)
        ui.alert = envData.alert
        draw()
        sleep(ENV_REFRESH)
    end
end

local function input()
    while true do
        local event, a, b, c = os.pullEvent()

        if event == "monitor_touch" and a == monitorName then
            local id = screen:hit(b, c)
            local app = appsById[current]

            if id == "home" then
                open("home")
            elseif id and appsById[id] then
                open(id)
            elseif id and app and app.touch then
                app.touch(id)
                draw()
            end
        elseif event == "monitor_resize" and a == monitorName then
            open(current)
        elseif event == "peripheral" or event == "peripheral_detach" then
            me.reset()
        end
    end
end

--------------------------------------------------
-- CONSOLE (the computer's own screen)
--------------------------------------------------

local lastResults = {}

local HELP = {
    "<song name>    play the top YouTube result",
    "<YouTube link> play a video or a whole playlist",
    "search <text>  list results, then type a number",
    "pause / skip / stop",
    "vol <0-300>    volume in %",
    "stats [reset]  why is music skipping?",
    "quit           stop Base OS"
}

local function add(track)
    music.add(track)
    print("Added: " .. track.title)
end

local function search(query)
    print("Searching...")

    local results, err = music.search(query)

    if not results then
        printError(err)
    elseif #results == 0 then
        print("No results.")
    end

    return results or {}
end

-- Returns "quit" to stop Base OS
local function command(line)
    local cmd, arg = line:match("^%s*(%S+)%s*(.-)%s*$")

    if not cmd then
        return
    end

    local lower = cmd:lower()

    if lower == "quit" or lower == "exit" then
        return "quit"
    elseif lower == "help" then
        for _, text in ipairs(HELP) do
            print(text)
        end
    elseif lower == "pause" or lower == "resume" or lower == "play" and arg == "" then
        music.togglePause()
    elseif lower == "stats" then
        local st = music.stats

        if st.wall > 0 then
            print(("Measured %ds of playback"):format(math.floor(st.wall)))
            print(("Server TPS: %.1f"):format(math.min(20, st.ticks / st.wall * 20)))
            print(("Server freezes >0.4s: %d (worst %.1fs)"):format(st.freezes, st.worstFreeze))
            print(("Base OS late with audio: %d (worst %.1fs)"):format(st.late, st.worstLate))
        else
            print("Play some music first.")
        end

        if arg == "reset" then
            music.resetStats()
            print("Stats reset.")
        end
    elseif lower == "skip" then
        music.skip()
    elseif lower == "stop" then
        music.stop()
    elseif lower == "vol" or lower == "volume" then
        local volume = tonumber(arg)

        if volume then
            music.setVolume(volume / 100)
            print(("Volume %d%%"):format(music.volume * 100))
        else
            print("Usage: vol 0-300")
        end
    elseif lower == "search" and arg ~= "" then
        lastResults = search(arg)

        for i, r in ipairs(lastResults) do
            print(("%d. %s"):format(i, r.title))
        end
    elseif tonumber(cmd) and arg == "" and lastResults[tonumber(cmd)] then
        add(lastResults[tonumber(cmd)])
    else
        local query = lower == "play" and arg or line
        local results = search(query)

        if query:match("^https?://") and #results > 1 then
            for _, track in ipairs(results) do
                music.add(track)
            end

            print("Added " .. #results .. " songs.")
        elseif results[1] then
            add(results[1])
        end
    end
end

local function console()
    while true do
        term.setTextColor(colors.yellow)
        write("> ")
        term.setTextColor(colors.white)

        if command(read()) == "quit" then
            return
        end

        draw()
    end
end

term.clear()
term.setCursorPos(1, 1)
print("Base OS running on " .. monitorName)
print("Type a song name to play it, or 'help'.")

open("home")

-- Ctrl+T (terminate) counts as a clean stop, so startup.lua doesn't restart us
local ok, err = pcall(parallel.waitForAny, poller, envPoller, input, console, music.run)

if not ok and err ~= "Terminated" then
    error(err, 0)
end

music.stop()

-- Clean exit
monitor.setBackgroundColor(colors.black)
monitor.clear()
monitor.setCursorPos(1, 1)
monitor.setTextColor(colors.gray)
monitor.write("Base OS stopped")

term.clear()
term.setCursorPos(1, 1)
print("Base OS stopped.")
