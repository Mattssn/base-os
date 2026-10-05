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
local restock = require("restock")
local home = require("home")

-- Apps shown on the start screen, in order. Add new ones here.
local apps = {
    require("apps.me"),
    require("apps.music"),
    require("apps.env"),
    require("apps.restock")
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
-- MONITORS (each one is an independent screen)
--------------------------------------------------

-- Optional per-monitor settings (use the name from `peripherals`, e.g. monitor_2):
--   set baseos.text_scale.monitor_2 1    text scale for just that monitor
--   set baseos.pin.monitor_2 me          always show one app (me, music, env), no HOME button
--   set baseos.pin.monitor_2 off         leave this monitor alone (e.g. it's a Base Signs sign)
local screens = {} -- monitor name -> { ui = screen, current = "home" or app id, pinned = app id or nil }

local function addMonitor(name)
    local mon = peripheral.wrap(name)
    local pinned = settings.get("baseos.pin." .. name)

    if pinned == "off" then
        return
    end

    if not appsById[pinned] then
        pinned = nil
    end

    mon.setTextScale(settings.get("baseos.text_scale." .. name) or settings.get("baseos.text_scale"))

    local screen = ui.new(mon)
    screen.pinned = pinned ~= nil
    screen:clear()

    screens[name] = { ui = screen, current = pinned or "home", pinned = pinned }
end

for _, name in ipairs(peripheral.getNames()) do
    if peripheral.hasType(name, "monitor") then
        addMonitor(name)
    end
end

--------------------------------------------------
-- STATE
--------------------------------------------------

local snapshot = me.empty()
snapshot.loading = true
snapshot.flow = flow.result

local envData = { detectors = {} }

local function drawScreen(s)
    s.ui:resize()
    s.ui:clearButtons()

    if s.current == "home" then
        home.draw(s.ui, snapshot, apps)
    else
        appsById[s.current].draw(s.ui, snapshot)
    end
end

local function draw()
    snapshot.env = envData

    for name, s in pairs(screens) do
        -- A monitor can disappear mid-draw; its peripheral_detach event removes it
        if not pcall(drawScreen, s) and not peripheral.isPresent(name) then
            screens[name] = nil
        end
    end
end

local function open(s, id)
    s.current = id
    s.ui:clear()
    drawScreen(s)
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

        local s = screens[a]

        if event == "monitor_touch" and s then
            local id = s.ui:hit(b, c)
            local app = appsById[s.current]

            if id == "home" and not s.pinned then
                open(s, "home")
            elseif id and appsById[id] then
                open(s, id)
            elseif id and app and app.touch then
                app.touch(id)
                draw() -- e.g. music controls change what every monitor shows
            end
        elseif event == "monitor_resize" and s then
            open(s, s.current)
        elseif event == "peripheral" then
            me.reset()

            if peripheral.hasType(a, "monitor") then
                addMonitor(a)

                if screens[a] then
                    pcall(drawScreen, screens[a])
                end
            end
        elseif event == "peripheral_detach" then
            me.reset()
            screens[a] = nil
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
    "restock        keep items in your inventory:",
    "  restock add <item> [count] / remove <n>",
    "  restock setup / on / off",
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

-- Items in the ME system matching `query` (display name or id), most plentiful first.
-- An exact name match wins outright.
local function findItems(query)
    local q = query:lower()
    local matches = {}

    for _, item in ipairs(snapshot.items) do
        local label = (item.displayName or item.name):lower()
        local name = item.name:lower()

        if label == q or name == q or name:match(":(.+)$") == q then
            return { item }
        end

        if label:find(q, 1, true) or name:find(q, 1, true) then
            table.insert(matches, item)
        end
    end

    table.sort(matches, function(a, b)
        return (tonumber(a.count) or 0) > (tonumber(b.count) or 0)
    end)

    return matches
end

local function restockCommand(arg)
    local sub, rest = arg:match("^(%S*)%s*(.-)$")

    sub = sub:lower()

    if sub == "" or sub == "list" then
        print("Restock: " .. restock.status)

        for i, rule in ipairs(restock.rules()) do
            print(("%d. %s  %d/%d"):format(i, rule.label, restock.have[rule.name] or 0, rule.keep))
        end

        if #restock.rules() == 0 then
            print("Nothing yet. Try: restock add torch 64")
        end
    elseif sub == "add" then
        local query, count = rest:match("^(.-)%s+(%d+)$")

        query = query or rest
        count = tonumber(count) or 64

        if query == "" then
            return print("Usage: restock add <item> [count]")
        end

        local matches = findItems(query)
        local item = matches[1]

        if not item then
            return print("No item matching '" .. query .. "' in the ME system.")
        end

        if #matches > 1 then
            for i = 1, math.min(9, #matches) do
                print(("%d. %s (%s)"):format(i, matches[i].displayName or matches[i].name, ui.fmt(matches[i].count)))
            end

            write("Which one? (number, Enter to cancel) ")
            item = matches[tonumber(read())]

            if not item then
                return
            end
        end

        restock.add(item.name, item.displayName or item.name, count)
        print("Keeping " .. count .. " " .. (item.displayName or item.name) .. " in your inventory.")
    elseif sub == "remove" then
        local removed = tonumber(rest) and restock.remove(tonumber(rest))

        print(removed and "Removed " .. removed.label .. "." or "Usage: restock remove <number from restock list>")
    elseif sub == "on" or sub == "off" then
        restock.setEnabled(sub == "on")
        print("Restock " .. sub .. ".")
    elseif sub == "setup" then
        restock.setup(print, snapshot.items)
    else
        print("restock [list] | add <item> [count] | remove <n> | setup | on | off")
    end
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
    elseif lower == "restock" then
        restockCommand(arg)
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
local names = {}

for name in pairs(screens) do
    table.insert(names, name)
end

table.sort(names)
print(#names > 0 and "Base OS on " .. table.concat(names, ", ") or "Base OS (no monitor yet, connect one any time)")
print("Type a song name to play it, or 'help'.")

draw()

-- Ctrl+T (terminate) counts as a clean stop, so startup.lua doesn't restart us
local ok, err = pcall(parallel.waitForAny, poller, envPoller, input, console, music.run, restock.run)

if not ok and err ~= "Terminated" then
    error(err, 0)
end

music.stop()

-- Clean exit
for _, s in pairs(screens) do
    pcall(function()
        s.ui:clear()
        s.ui:text(1, 1, "Base OS stopped", colors.gray)
    end)
end

term.clear()
term.setCursorPos(1, 1)
print("Base OS stopped.")
