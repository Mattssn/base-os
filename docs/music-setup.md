# Music setup

```
Base OS (Minecraft server, Hetzner)  --Tailscale-->  music server (home, 100.64.7.94:8096)
                                                      yt-dlp -> ffmpeg -> DFPWM
```

## 1. Music server (home server, already running)
```bash
cd ~/computercraft/base-os/server
docker compose up -d --build     # start / rebuild
docker compose restart           # if YouTube starts failing (updates yt-dlp)
docker logs baseos-music         # see conversions and errors
```
It's bound to the Tailscale IP only, so nothing on the LAN or the internet can reach it.
Converted songs are cached (max 500 MB). Live streams are skipped and tracks are cut off at 2 hours.

## 2. Allow it in CC:Tweaked (Minecraft server)
CC:Tweaked blocks private/Tailscale addresses (`100.64.0.0/10`) by default. Allow **only** the music server.

Edit `config/computercraft-server.toml` in the server folder and add this rule **above** the existing
(On some setups it's `<world>/serverconfig/computercraft-server.toml` instead. Use whichever one contains `[[http.rules]]`.)
`host = "$private"` deny rule (the first matching rule wins):

```toml
[[http.rules]]
	host = "100.64.7.94/32"
	port = 8096
	action = "allow"

[[http.rules]]
	host = "$private"
	action = "deny"
```
Restart the Minecraft server afterwards.

The Minecraft server's machine has to be on the tailnet. Check it with:
`curl http://100.64.7.94:8096/health`. You should get `{"ok":true}`.

## 3. In game
```
set baseos.music_server http://100.64.7.94:8096
```
Then reboot. Connect speakers to the computer, either directly or over wired modems. Every speaker plays.

Type on the computer:
| Command | |
|---|---|
| `<song name>` | play the top YouTube result |
| `<YouTube link>` | play that video (even if the link is from a playlist/mix) |
| `<playlist link>` | `youtube.com/playlist?list=...` queues the whole playlist (max 200) |
| `search <text>`, then `3` | pick from the results |
| `pause` / `skip` / `stop` | |
| `vol 150` | volume (0-300%) |
| `quit` | stop Base OS |

The MUSIC app on the monitor has the same controls as buttons, plus the queue.

## 4. Speakers around the base, no cables (speaker computers)
The Base OS computer broadcasts the music over a **wireless or ender modem**. Any other computer
with a wireless/ender modem and speakers can play it, in sync with the main speakers.

1. **Base OS computer:** attach a wireless modem or an ender modem and reboot. It says
   "Speaker computers: broadcasting music over the wireless modem."
2. **Each speaker spot:** place a computer with a wireless modem (or an ender modem) and speakers
   touching it, or on wired modems. Then run:
   ```
   wget run https://raw.githubusercontent.com/Mattssn/base-os/main/install.lua speaker
   ```
   Run the same command (with `speaker`) to update it later.
3. Play music as usual. Every speaker computer in range plays along. Pause, skip and stop apply everywhere.

- **Range:** wireless modems reach 64 blocks near the ground and up to 384 blocks high up. An **ender modem** has unlimited range, even across dimensions.
- **Volume per spot:** on a speaker computer, run `set speaker.volume 0.5` (1 = same as Base OS, up to 3).
- **Sync:** each slice of audio carries the time it starts on the server's clock, and speaker computers start on that time, so they stay together (within about a tick).
- **No speakers on the Base OS computer itself?** That's fine. It then paces the music by the clock.
