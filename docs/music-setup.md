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

Edit `<world>/serverconfig/computercraft-server.toml` and add this rule **above** the existing
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
| `<YouTube link>` | play a video, or queue a whole playlist |
| `search <text>`, then `3` | pick from the results |
| `pause` / `skip` / `stop` | |
| `vol 150` | volume (0-300%) |
| `quit` | stop Base OS |

The MUSIC app on the monitor has the same controls as buttons, plus the queue.
