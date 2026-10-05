#!/bin/sh
# YouTube breaks old yt-dlp versions often, so try to update on every start (a restart fixes most
# failures). If PyPI can't be reached (e.g. DNS still starting after a reboot), use the built-in one.
pip install --quiet --disable-pip-version-check -U "yt-dlp[default]" \
    || echo "yt-dlp update failed, using $(yt-dlp --version)"
exec python3 -u /app/app.py
