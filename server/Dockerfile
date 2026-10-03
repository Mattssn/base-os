FROM python:3.11-slim

# ffmpeg >= 5.1 has the dfpwm encoder. yt-dlp needs a JS runtime (deno) for YouTube.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir --root-user-action=ignore deno

WORKDIR /app
COPY app.py entrypoint.sh ./

ENTRYPOINT ["sh", "/app/entrypoint.sh"]
