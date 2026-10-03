"""Base OS music server.

Turns YouTube searches/links into DFPWM audio that CC:Tweaked speakers can play.

    GET /search?q=<text or YouTube URL>   -> JSON list of {id, title, duration}
    GET /audio/<id>?offset=N&length=M     -> raw DFPWM bytes (48 kHz mono)

Audio is converted once (yt-dlp | ffmpeg) into a cache file. Chunk requests are
answered as soon as enough of the file exists, so playback starts within seconds.
Response header X-Done is "1" once conversion has finished; X-Total is then the
full size in bytes. An empty body with X-Done: 1 means the end of the track.
"""

import json
import os
import re
import subprocess
import threading
import time
import unicodedata
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

CACHE = Path(os.environ.get("CACHE_DIR", "/cache"))
CACHE_LIMIT = int(os.environ.get("CACHE_LIMIT_MB", "500")) * 1024 * 1024
PORT = int(os.environ.get("PORT", "8096"))
SEARCH_RESULTS = 8
MAX_CHUNK = 1024 * 1024
MAX_SECONDS = 2 * 60 * 60  # longer videos are cut off (6 KB/s, so ~43 MB max per track)
WAIT_SECONDS = 20  # CC:Tweaked times out HTTP requests after 30s

VIDEO_ID = re.compile(r"^[A-Za-z0-9_-]{11}$")

CACHE.mkdir(parents=True, exist_ok=True)

jobs = {}  # video id -> {"proc": Popen, "error": str | None}
jobs_lock = threading.Lock()


def done_path(vid):
    return CACHE / f"{vid}.dfpwm"


def part_path(vid):
    return CACHE / f"{vid}.part"


def trim_cache():
    files = sorted(CACHE.glob("*.dfpwm"), key=lambda p: p.stat().st_mtime)
    total = sum(p.stat().st_size for p in files)

    while files and total > CACHE_LIMIT:
        oldest = files.pop(0)
        total -= oldest.stat().st_size
        oldest.unlink(missing_ok=True)


def convert(vid):
    part = part_path(vid)
    url = f"https://www.youtube.com/watch?v={vid}"

    ytdlp = subprocess.Popen(
        ["yt-dlp", "-q", "--no-playlist", "-f", "bestaudio/best", "-o", "-", url],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    ffmpeg = subprocess.Popen(
        ["ffmpeg", "-loglevel", "error", "-y", "-i", "pipe:0",
         "-t", str(MAX_SECONDS), "-ac", "1", "-ar", "48000", "-f", "dfpwm", str(part)],
        stdin=ytdlp.stdout,
        stderr=subprocess.PIPE,
    )
    ytdlp.stdout.close()

    ffmpeg_err = ffmpeg.communicate()[1].decode(errors="replace")
    ytdlp_err = ytdlp.communicate()[1].decode(errors="replace")

    with jobs_lock:
        if ffmpeg.returncode == 0 and ytdlp.returncode == 0 and part.exists():
            part.rename(done_path(vid))
            jobs.pop(vid, None)
            trim_cache()
        else:
            part.unlink(missing_ok=True)
            message = (ytdlp_err or ffmpeg_err).strip().splitlines()
            jobs[vid] = {"error": message[-1] if message else "conversion failed"}
            print(f"[{vid}] failed: {jobs[vid]['error']}", flush=True)


def ensure_converting(vid):
    """Start conversion unless it's cached or running. Retries a previous failure."""
    with jobs_lock:
        if done_path(vid).exists():
            return
        job = jobs.get(vid)
        if job and not job.get("error"):
            return
        jobs[vid] = {"error": None}

    print(f"[{vid}] converting", flush=True)
    threading.Thread(target=convert, args=(vid,), daemon=True).start()


def ascii_title(title):
    """CC monitors only draw ASCII well: fold fullwidth/accented letters, drop the rest."""
    folded = unicodedata.normalize("NFKD", title).encode("ascii", "ignore").decode()
    return re.sub(r"\s+", " ", folded).strip()


def search(query):
    query = query.strip()
    target = query if query.startswith(("http://", "https://")) else f"ytsearch{SEARCH_RESULTS}:{query}"

    out = subprocess.run(
        ["yt-dlp", "-J", "--flat-playlist", "--no-warnings", target],
        capture_output=True, timeout=60,
    )

    if out.returncode != 0:
        raise RuntimeError(out.stderr.decode(errors="replace").strip().splitlines()[-1])

    data = json.loads(out.stdout)
    entries = data.get("entries") or [data]  # a single video has no entries

    results = []
    for e in entries:
        if not e or not VIDEO_ID.match(e.get("id") or ""):
            continue
        if e.get("live_status") in ("is_live", "is_upcoming") or not e.get("duration"):
            continue  # live streams (no duration in search results) never finish converting

        results.append({
            "id": e["id"],
            "title": ascii_title(e.get("title") or "") or e["id"],
            "duration": int(e.get("duration") or 0),
        })

    return results


class Handler(BaseHTTPRequestHandler):
    def send(self, status, body, content_type="application/json", headers=None):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        for key, value in (headers or {}).items():
            self.send_header(key, value)
        self.end_headers()
        self.wfile.write(body)

    def error(self, status, message):
        self.send(status, json.dumps({"error": message}).encode())

    def do_GET(self):
        url = urlparse(self.path)
        query = parse_qs(url.query)

        if url.path == "/search":
            q = (query.get("q") or [""])[0]
            if not q.strip():
                return self.error(400, "missing q")
            try:
                return self.send(200, json.dumps(search(q)).encode())
            except Exception as exc:  # yt-dlp failures, timeouts
                return self.error(502, str(exc))

        if url.path.startswith("/audio/"):
            return self.audio(url.path[len("/audio/"):], query)

        if url.path == "/health":
            return self.send(200, b'{"ok":true}')

        self.error(404, "not found")

    def audio(self, vid, query):
        if not VIDEO_ID.match(vid):
            return self.error(400, "bad video id")

        try:
            offset = max(0, int((query.get("offset") or ["0"])[0]))
            length = min(MAX_CHUNK, max(1, int((query.get("length") or [str(MAX_CHUNK)])[0])))
        except ValueError:
            return self.error(400, "bad offset/length")

        ensure_converting(vid)

        deadline = time.time() + WAIT_SECONDS
        while True:
            done = done_path(vid)
            if done.exists():
                done.touch()  # keep recently played tracks in the cache
                with open(done, "rb") as f:
                    f.seek(offset)
                    body = f.read(length)
                size = str(done.stat().st_size)
                return self.send(200, body, "application/octet-stream", {"X-Done": "1", "X-Total": size})

            with jobs_lock:
                job = jobs.get(vid) or {}
            if job.get("error"):
                return self.error(502, job["error"])

            try:
                available = part_path(vid).stat().st_size - offset
            except FileNotFoundError:  # not started yet, or just renamed to .dfpwm
                available = 0

            if available >= length or time.time() > deadline:
                body = b""
                if available > 0:
                    try:
                        with open(part_path(vid), "rb") as f:
                            f.seek(offset)
                            body = f.read(min(length, available))
                    except FileNotFoundError:
                        continue  # finished in the meantime; serve from the done file
                return self.send(200, body, "application/octet-stream", {"X-Done": "0"})

            time.sleep(0.25)

    def log_message(self, fmt, *args):
        pass  # conversions are logged instead of every chunk request


if __name__ == "__main__":
    for stale in CACHE.glob("*.part"):
        stale.unlink()
    print(f"Base OS music server on :{PORT}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
