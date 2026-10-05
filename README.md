# Base OS

An OS for CC: Tweaked computers in **All the Mods 10: To the Sky** (ATM10 TTS). It also uses **Advanced Peripherals**.
It runs on one or more monitors. The start screen shows the key stats, and you tap a button to open an app.

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
    restock.lua          keeps items in your inventory via Inventory Manager + ME Bridge
    apps/restock.lua     Restock app (what's kept, recent deliveries, on/off)
server/                       YouTube -> DFPWM music server (Docker, runs on the home server)
speaker/                      speaker computer program (install.lua speaker): plays Base OS music over a wireless modem
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

**Speakers around the base without cables:** give the Base OS computer a wireless (or ender) modem. Then, on any
computer with a wireless modem and speakers, run
`wget run https://raw.githubusercontent.com/Mattssn/base-os/main/install.lua speaker`.
It plays the same music, in sync with the main speakers.

## Restock (keep your inventory full from the ME system)
Needs an **Inventory Manager** with a **Memory Card** bound to you (right-click the card, then put it in the
manager), plus an **empty chest touching the Inventory Manager**. The ME Bridge has to reach that chest:
connect the chest to the network with a wired modem, or place it against the ME Bridge as well.
Items go ME Bridge -> chest -> Inventory Manager -> you. Anything that doesn't fit goes back into ME.

On the computer:
| Command | |
|---|---|
| `restock setup` | finds the chest automatically (moves 1 item around to test, then puts it back) |
| `restock add torch 64` | keep 64 torches in your inventory (asks which one if several items match) |
| `restock` | list what's kept, with numbers |
| `restock remove 2` | stop keeping item 2 |
| `restock off` / `restock on` | pause / resume |

You can also do it all by tapping in the **RESTOCK** app: **+ ADD** opens an on-screen keyboard to search the
ME system, then pick an item and how many to keep. Each item has `-`/`+` and `x` (tap twice to remove);
the **STEP 16 / STEP 64** button switches how much `-`/`+` change the amount by.

It checks every 5 seconds while you're online. The RESTOCK app also shows recent deliveries
and an ON/OFF button. **Only use an empty chest just for this**, because anything in it gets put into the ME system.

## Multiple monitors
Connect as many monitors as you like (directly or over wired modems). Each one is an independent
screen with its own start screen and taps, and they all share one ME/detector read. Monitors can be
added or removed while Base OS is running. Find a monitor's name with `peripherals`.
- `set baseos.pin.monitor_2 me`: that monitor always shows one app (`me`, `music`, `env` or `restock`), with no HOME button.
- `set baseos.text_scale.monitor_2 1`: text scale for just that monitor.
- `set baseos.pin.monitor_2 off`: Base OS leaves that monitor alone, e.g. a [Base Signs](https://github.com/Mattssn/base-signs) sign on the same cable network.

Reboot after changing these. To unpin, run `set baseos.pin.monitor_2 none`.

## Settings
- `set baseos.text_scale 1`: monitor text scale (default 0.5)
- `set baseos.refresh 2`: seconds between refreshes (default 1)
- `set baseos.music_server <url>`: music server address (see Music)
- `set baseos.env_range 12`: entity scan radius for environment detectors (1-16, default 8; above 8 may need energy)
- `set baseos.env_radiation_alert 0.001`: radiation (Sv/h) that turns the title bar red (default 0.00001)
- `set baseos.flow_window 120`: seconds of history used for items per minute (default 60)

## Adding an app
Create `src/baseos/apps/<name>.lua` and return `{ id, title, color, draw = function(screen, snapshot) ... end }`. Then add `require("apps.<name>")` to the `apps` list in `main.lua`. For a back button, call `screen:button("home", ...)`.
