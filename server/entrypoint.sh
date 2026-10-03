#!/bin/sh
# YouTube breaks old yt-dlp versions often, so update on every start (a restart fixes most failures).
pip install --quiet --disable-pip-version-check --root-user-action=ignore -U "yt-dlp[default]"
exec python -u /app/app.py
