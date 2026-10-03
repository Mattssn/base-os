-- Base OS: music player service
-- Streams DFPWM audio from the Base OS music server (server/ in the repo) to every speaker.
-- Runs as its own coroutine (music.run) so music keeps playing on every screen.

local dfpwm = require("cc.audio.dfpwm")

local music = {}

local CHUNK = 256 * 1024    -- bytes per HTTP request (~43s of audio)
local SLICE = 16 * 1024     -- bytes per playAudio call (128K samples, ~2.7s)
local LOW_WATER = 64 * 1024 -- fetch the next chunk when less than this is waiting (~11s)
local BYTES_PER_SECOND = 6000 -- DFPWM at 48 kHz = 8 samples per byte

music.queue = {}      -- { id, title, duration }
music.current = nil
music.state = "stopped" -- "loading" | "playing" | "paused" | "stopped"
music.volume = 1.0
music.message = nil   -- last error, shown on the monitor

-- Per-track state
local decoder
local buffer = ""     -- downloaded, not yet decoded
local offset = 0      -- next byte to request from the server
local serverDone = false
local request = nil   -- URL of the in-flight chunk request
local pending = nil   -- decoded samples not yet accepted by every speaker
local pendingBytes = 0
local accepted = {}   -- speaker name -> true once it took `pending`
local played = 0      -- bytes played so far
local generation = 0  -- bumped on every track change so stale responses are ignored

-- Stutter diagnostics (the `stats` console command). Measured between each speaker's
-- speaker_audio_empty events, which arrive once per slice while playing:
--   real time running ahead of server ticks (os.clock) = the server froze/lagged
--   more ticks than one slice lasts                     = Base OS handed audio over late
local SLICE_SECONDS = SLICE * 8 / 48000
local lastEmpty = nil -- { wall = seconds, tick = seconds } at the last event
local statSpeaker = nil -- only one speaker is measured, so freezes aren't counted twice

local function newStats()
    return { wall = 0, ticks = 0, freezes = 0, worstFreeze = 0, late = 0, worstLate = 0 }
end

music.stats = newStats()

function music.resetStats()
    music.stats = newStats()
    lastEmpty = nil
    statSpeaker = nil
end

local function recordEmpty(name)
    statSpeaker = statSpeaker or name

    if name ~= statSpeaker then
        return
    end

    local now = { wall = os.epoch("utc") / 1000, tick = os.clock() }
    local last = lastEmpty
    local st = music.stats

    if last then
        local wall = now.wall - last.wall
        local ticks = now.tick - last.tick
        local freeze = wall - ticks
        local late = ticks - SLICE_SECONDS

        st.wall = st.wall + wall
        st.ticks = st.ticks + ticks

        if freeze > 0.4 then
            st.freezes = st.freezes + 1
            st.worstFreeze = math.max(st.worstFreeze, freeze)
        end

        if late > 0.3 then
            st.late = st.late + 1
            st.worstLate = math.max(st.worstLate, late)
        end
    end

    lastEmpty = now
end

settings.define("baseos.music_server", {
    description = "Base OS music server URL, e.g. http://100.64.7.94:8096",
    type = "string"
})

function music.server()
    local url = settings.get("baseos.music_server")

    if url and url ~= "" then
        return (url:gsub("/+$", ""))
    end
end

local function wake()
    os.queueEvent("baseos_music")
end

local function speakers()
    return { peripheral.find("speaker") }
end

local function stopSpeakers()
    for _, speaker in ipairs(speakers()) do
        speaker.stop()
    end
end

function music.position()
    return math.floor(played / BYTES_PER_SECOND)
end

--------------------------------------------------
-- TRACK CHANGES
--------------------------------------------------

local function nextTrack()
    generation = generation + 1
    buffer = ""
    offset = 0
    serverDone = false
    request = nil
    pending = nil
    accepted = {}
    played = 0
    lastEmpty = nil
    statSpeaker = nil

    music.current = table.remove(music.queue, 1)

    if music.current then
        decoder = dfpwm.make_decoder()
        music.state = "loading"
    else
        music.state = "stopped"
    end
end

function music.add(track)
    table.insert(music.queue, track)

    if music.state == "stopped" then
        nextTrack()
    end

    wake()
end

function music.skip()
    stopSpeakers()
    nextTrack()
    wake()
end

function music.stop()
    music.queue = {}
    stopSpeakers()
    nextTrack()
    wake()
end

function music.togglePause()
    if music.state == "paused" then
        music.state = "playing"
    elseif music.state == "playing" or music.state == "loading" then
        music.state = "paused"
        stopSpeakers()
        accepted = {} -- replay the current slice on resume
        lastEmpty = nil
    end

    wake()
end

function music.setVolume(volume)
    music.volume = math.max(0, math.min(3, volume))
end

--------------------------------------------------
-- SEARCH (blocking; call from the console, not the player)
--------------------------------------------------

local function urlEncode(text)
    return (text:gsub("[^%w%-_%.~]", function(c)
        return ("%%%02X"):format(c:byte())
    end))
end

local function errorText(handle, err)
    if handle then
        local body = handle.readAll()
        handle.close()

        local data = body and textutils.unserializeJSON(body)

        if type(data) == "table" and data.error then
            return data.error
        end
    end

    return err or "unknown error"
end

-- Returns a list of { id, title, duration }, or nil and an error message.
function music.search(query)
    local server = music.server()

    if not server then
        return nil, "Music server not set (set baseos.music_server <url>)"
    end

    local handle, err, failed = http.get(server .. "/search?q=" .. urlEncode(query))

    if not handle then
        return nil, errorText(failed, err)
    end

    local results = textutils.unserializeJSON(handle.readAll())
    handle.close()

    if type(results) ~= "table" then
        return nil, "Bad response from music server"
    end

    return results
end

--------------------------------------------------
-- STREAMING
--------------------------------------------------

local function fetch()
    local server = music.server()

    if not server then
        music.message = "Music server not set"
        music.queue = {}
        nextTrack()
        return
    end

    request = ("%s/audio/%s?offset=%d&length=%d&g=%d"):format(server, music.current.id, offset, CHUNK, generation)

    local ok, err = pcall(http.request, { url = request, binary = true })

    if not ok then
        music.message = tostring(err)
        request = nil
        nextTrack()
    end
end

local function onChunk(handle)
    local body = handle.readAll() or ""
    local headers = handle.getResponseHeaders() or {}
    handle.close()

    request = nil
    buffer = buffer .. body
    offset = offset + #body

    local done = headers["X-Done"] or headers["x-done"]
    local total = tonumber(headers["X-Total"] or headers["x-total"])

    if done == "1" and (#body == 0 or (total and offset >= total)) then
        serverDone = true
    end
end

-- Move audio along: fetch when low, decode, and hand slices to every speaker.
local function pump()
    if music.state ~= "loading" and music.state ~= "playing" then
        return
    end

    if not request and not serverDone and #buffer < LOW_WATER then
        fetch()

        if not music.current then
            return
        end
    end

    local targets = speakers()

    if #targets == 0 then
        music.message = "No speakers found"
        return
    end

    while true do
        if not pending then
            if #buffer < SLICE and not serverDone then
                return -- wait for more data
            end

            if #buffer == 0 then
                -- Track finished (the last slice is still playing out, the next track queues behind it)
                nextTrack()
                return pump()
            end

            local slice = buffer:sub(1, SLICE)
            buffer = buffer:sub(SLICE + 1)

            pending = decoder(slice)
            pendingBytes = #slice
            accepted = {}
            music.state = "playing"
            music.message = nil
        end

        local all = true

        for _, speaker in ipairs(targets) do
            local name = peripheral.getName(speaker)

            if not accepted[name] then
                if speaker.playAudio(pending, music.volume) then
                    accepted[name] = true
                else
                    all = false
                end
            end
        end

        if not all then
            return -- wait for speaker_audio_empty
        end

        played = played + pendingBytes
        pending = nil

        if not request and not serverDone and #buffer < LOW_WATER then
            fetch()
        end
    end
end

function music.run()
    while true do
        pump()

        local event, url, a, b = os.pullEvent()

        if event == "speaker_audio_empty" and music.state == "playing" then
            recordEmpty(url)
        end

        if event == "http_success" and url == request then
            onChunk(a)
        elseif event == "http_failure" and url == request then
            -- a = error message, b = response handle (if the server answered with an error)
            request = nil
            music.message = "Couldn't play " .. music.current.title .. ": " .. errorText(b, a)
            stopSpeakers()
            nextTrack()
        end
    end
end

return music
