-- Base OS app: Music
-- Now playing, controls and the queue. Songs are added by typing on the computer.

local ui = require("ui")
local music = require("music")

local app = {
    id = "music",
    title = "MUSIC",
    color = colors.purple
}

local STATUS = {
    loading = { "Loading...", colors.yellow },
    playing = { "Playing", colors.lime },
    paused = { "Paused", colors.orange },
    stopped = { "Stopped", colors.gray }
}

local function duration(seconds)
    seconds = math.floor(seconds or 0)
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

function app.draw(screen, s)
    local w, h = screen.w, screen.h
    local width = w - 2
    local track = music.current

    screen:titleBar("", ui.clock(), "MUSIC")
    screen:button("home", 1, 1, 8, 1, "< HOME", colors.white, colors.gray)

    --------------------------------------------------
    -- NOW PLAYING
    --------------------------------------------------

    screen:row(3, "NOW PLAYING", colors.magenta, nil, 2)
    screen:row(4, track and track.title or "Nothing playing", track and colors.white or colors.gray, nil, 2)

    local status = STATUS[music.state]
    local time = track and (duration(music.position()) .. " / " .. duration(track.duration)) or ""

    screen:text(2, 5, status[1], status[2], nil, width - #time)
    screen:text(w - #time, 5, time, colors.lightGray)

    local progress = track and track.duration > 0 and music.position() / track.duration or 0
    screen:bar(2, 6, width, progress, colors.magenta)

    --------------------------------------------------
    -- CONTROLS
    --------------------------------------------------

    local buttons = {
        { "music_pause", music.state == "paused" and "PLAY" or "PAUSE", colors.green },
        { "music_skip", "SKIP", colors.lightBlue },
        { "music_stop", "STOP", colors.red },
        { "music_voldown", "VOL -", colors.gray },
        { "music_volup", "VOL +", colors.gray }
    }

    local buttonW = math.max(4, math.floor((width + 1) / #buttons) - 1)

    for i, b in ipairs(buttons) do
        screen:button(b[1], 2 + (i - 1) * (buttonW + 1), 8, buttonW, 3, b[2], colors.white, b[3])
    end

    screen:row(11, ("Volume %d%%"):format(math.floor(music.volume * 100 + 0.5)), colors.lightGray, nil, 2)
    screen:row(12, music.message or "", colors.red, nil, 2)

    --------------------------------------------------
    -- QUEUE
    --------------------------------------------------

    screen:row(14, "UP NEXT (" .. #music.queue .. ")", colors.magenta, nil, 2)

    for row = 15, h - 1 do
        local i = row - 14
        local queued = music.queue[i]

        if queued then
            local length = " " .. duration(queued.duration)

            screen:text(2, row, i .. ". " .. queued.title, colors.white, nil, width - #length)
            screen:text(w - #length, row, length, colors.lightGray)
        else
            screen:row(row, "")
        end
    end

    if music.server() then
        screen:row(h, " Type a song name on the computer to add it", colors.gray)
    else
        screen:row(h, " Set the server: set baseos.music_server <url>", colors.red)
    end
end

function app.touch(id)
    if id == "music_pause" then
        music.togglePause()
    elseif id == "music_skip" then
        music.skip()
    elseif id == "music_stop" then
        music.stop()
    elseif id == "music_voldown" then
        music.setVolume(music.volume - 0.25)
    elseif id == "music_volup" then
        music.setVolume(music.volume + 0.25)
    end
end

return app
