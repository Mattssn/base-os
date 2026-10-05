# Base OS

An OS for CC: Tweaked computers in **All the Mods 10: To the Sky** (ATM10 TTS). It also uses **Advanced Peripherals**.
It runs on a monitor. The start screen shows the key stats, and you tap a button to open an app.

| | |
|---|---|
| Minecraft | 1.21.1 (NeoForge, Java 21) |
| Modpack | ATM10 To the Sky (2.0.x) |
| Mods | CC: Tweaked, Advanced Peripherals 0.7.x |

## Layout
```
install.lua              one-command installer/updater (downloads src/)
src/                     <- what ends up on the computer
  startup.lua            boot file: runs Base OS and restarts it if it crashes
  baseos/
    main.lua             event loop, screen switching, settings
    ui.lua               flicker-free drawing, bars, touch buttons
    me.lua               reads the ME Bridge (1.21.1 storage-system API)
    flow.lua             items/min in and out (compares item counts over time)
    home.lua             start screen (overview stats + app buttons)
    music.lua            music player (streams from the music server to every speaker)
    apps/me.lua          ME System app (AE2 dashboard + item flow)
    apps/music.lua       Music app (now playing, controls, queue)
    env.lua              reads every environment detector (weather, light, entities, radiation)
    apps/env.lua         Environment app (per detector info + nearby entities)
server/                       YouTube -> DFPWM music server (Docker, runs on the home server)
reference/ae2_dashboard.lua   the original standalone dashboard
docs/                         CC:T + Advanced Peripherals API notes for 1.21.1
```

## Setup in game
1. Build an **advanced** computer and an **advanced** monitor, and connect the ME Bridge. You can connect it directly or over wired modems.
2. On the computer, run:
   ```
   wget run https://raw.githubusercontent.com/Mattssn/base-os/main/install.lua
   ```
   This downloads everything in `src/` and reboots. Run the same command again to update.
   (It needs the server to have CC:T HTTP enabled. That's the default.)

Type `quit` on the computer (or hold Ctrl+T) to stop Base OS.

## Music
See [docs/music-setup.md](docs/music-setup.md). It needs a one-time CC:Tweaked config change on the Minecraft server, then `set baseos.music_server http://100.64.7.94:8096`.

## Settings
- `set baseos.text_scale 1`: monitor text scale (default 0.5)
- `set baseos.refresh 2`: seconds between refreshes (default 1)
- `set baseos.music_server <url>`: music server address (see Music)
- `set baseos.env_range 12`: entity scan radius for environment detectors (1-16, default 8; above 8 may need energy)
- `set baseos.env_radiation_alert 0.001`: radiation (Sv/h) that turns the title bar red (default 0.00001)
- `set baseos.flow_window 120`: seconds of history used for items per minute (default 60)

## Adding an app
Create `src/baseos/apps/<name>.lua` and return `{ id, title, color, draw = function(screen, snapshot) ... end }`. Then add `require("apps.<name>")` to the `apps` list in `main.lua`. For a back button, call `screen:button("home", ...)`.
