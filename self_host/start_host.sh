#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v python3 >/dev/null 2>&1; then
  echo "[ERROR] Python 3.10+ is required."
  exit 1
fi

if [ ! -x ".venv/bin/python" ]; then
  echo "Setting up isolated Python environment..."
  python3 -m venv .venv
fi

.venv/bin/python -m pip install --upgrade pip >/dev/null
.venv/bin/python -m pip install -r requirements.txt

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "[WARN] ffmpeg not found. Install ffmpeg with your package manager for Voice & PC Audio streaming."
fi

exec .venv/bin/python spy_bot_host.py
