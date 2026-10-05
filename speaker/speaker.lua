-- Base OS speaker computer
-- Plays the Base OS music stream on this computer's speakers. The main Base OS computer
-- broadcasts the audio over a wireless or ender modem, so no cables back to it are needed.
--
-- Needs: a wireless or ender modem, and speakers (touching this computer or on wired modems).
-- `set speaker.volume 0.5` makes this spot quieter (1 = same as Base OS, up to 3).

local dfpwm = require("cc.audio.dfpwm")

local PROTOCOL = "baseos_music"
local MAX_QUEUE = 6 -- slices (~16s); older ones are dropped if this computer falls behind

settings.define("speaker.volume", {
    description = "Volume for this speaker computer (1 = same as Base OS, 0-3)",
    default = 1,
    type = "number"
})

local queue = {}    -- decoded slices waiting: { samples, volume, at, ms }
local accepted = {} -- speaker name -> true once it took queue[1]
local decoder, track
local title, status = nil, "Waiting for music..."
local modems = 0
local playingUntil = 0 -- epoch ms when this computer's speakers run out of audio

local function speakers()
    return { peripheral.find("speaker") }
end

local function openModems()
    modems = 0

    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "modem") and peripheral.call(name, "isWireless") then
            rednet.open(name)
            modems = modems + 1
        end
    end
end

local function stopAll()
    for _, speaker in ipairs(speakers()) do
        speaker.stop()
    end

    queue = {}
    accepted = {}
    playingUntil = 0
end

-- Hand queued slices to every speaker until they're full. When idle, wait until the moment
-- Base OS starts the slice (`at`, on the server's shared clock) so every speaker is in sync.
local function pump()
    local targets = speakers()

    while queue[1] and #targets > 0 do
        local slice = queue[1]
        local now = os.epoch("utc")

        if slice.at and slice.at + slice.ms < now then
            -- Already over on the other speakers: skip it to catch up
            table.remove(queue, 1)
            accepted = {}
        elseif slice.at and now >= playingUntil and now < slice.at - 25 then
            os.startTimer((slice.at - now) / 1000)
            return
        else
            local all = true

            for _, speaker in ipairs(targets) do
                local name = peripheral.getName(speaker)

                if not accepted[name] then
                    if speaker.playAudio(slice.samples, slice.volume) then
                        accepted[name] = true
                    else
                        all = false
                    end
                end
            end

            if not all then
                return -- wait for speaker_audio_empty
            end

            playingUntil = math.max(now, playingUntil) + slice.ms
            table.remove(queue, 1)
            accepted = {}
        end
    end
end

local function draw()
    local w = term.getSize()
    local count = #speakers()

    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.purple)
    term.setTextColor(colors.white)
    term.clearLine()
    write(" Base OS Speaker")
    term.setBackgroundColor(colors.black)

    term.setCursorPos(2, 3)
    term.setTextColor(status == "Playing" and colors.lime or colors.lightGray)
    write(status)

    term.setCursorPos(2, 4)
    term.setTextColor(colors.white)
    write((title or ""):sub(1, w - 2))

    term.setCursorPos(2, 6)
    term.setTextColor(count > 0 and colors.lightGray or colors.red)
    write(count .. " speaker(s)   volume x" .. settings.get("speaker.volume"))

    term.setCursorPos(2, 7)
    term.setTextColor(modems > 0 and colors.lightGray or colors.red)
    write(modems > 0 and "Listening on the wireless modem" or "No wireless or ender modem!")

    term.setCursorPos(2, 9)
    term.setTextColor(colors.gray)
    write("Ctrl+T to stop")
end

openModems()
draw()

local ok, err = pcall(function()
    while true do
        local event, a, b, c = os.pullEvent()

        if event == "rednet_message" and c == PROTOCOL and type(b) == "table" then
            if b.type == "audio" and type(b.data) == "string" then
                -- New track: fresh decoder, drop audio from the old one
                if b.track ~= track then
                    track = b.track
                    decoder = dfpwm.make_decoder()
                    queue = {}
                    accepted = {}
                end

                local volume = math.max(0, math.min(3, (tonumber(b.volume) or 1) * settings.get("speaker.volume")))

                table.insert(queue, {
                    samples = decoder(b.data),
                    volume = volume,
                    at = tonumber(b.at),
                    ms = #b.data / 6 -- 6000 bytes per second
                })

                while #queue > MAX_QUEUE do
                    table.remove(queue, 1)
                    accepted = {}
                end

                if status ~= "Playing" or title ~= b.title then
                    status, title = "Playing", b.title
                    draw()
                end
            elseif b.type == "stop" then
                stopAll()
                status = b.reason == "pause" and "Paused" or "Waiting for music..."

                if b.reason ~= "pause" and b.reason ~= "skip" then
                    title = nil
                end

                draw()
            end

            pump()
        elseif event == "speaker_audio_empty" or event == "timer" then
            pump()
        elseif event == "peripheral" or event == "peripheral_detach" then
            openModems()
            accepted = {}
            pump()
            draw()
        end
    end
end)

stopAll()
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)

if not ok and err ~= "Terminated" then
    error(err, 0)
end

print("Base OS Speaker stopped.")
