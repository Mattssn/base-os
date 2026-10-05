# Debian base: python:*-slim images fail to unpack on the home server's containerd
# ("archive/tar: invalid tar header"), and debian:bookworm-slim works.
FROM debian:bookworm-slim

# ffmpeg 5.1 (bookworm) has the dfpwm encoder. yt-dlp needs a JS runtime (deno) for YouTube.
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 python3-venv ffmpeg ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV PATH=/venv/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1

# Baked in, so a fresh container works even if the update at startup can't reach PyPI
RUN python3 -m venv /venv \
    && pip install --no-cache-dir deno "yt-dlp[default]"

WORKDIR /app
COPY app.py entrypoint.sh ./

ENTRYPOINT ["sh", "/app/entrypoint.sh"]
