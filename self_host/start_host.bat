@echo off
title SPY MUSIC - Discord Bot & PC Audio Host
cd /d "%~dp0"

where python >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Python 3.10+ is required. Install from https://www.python.org/downloads/
  pause
  exit /b 1
)

if not exist ".venv\Scripts\python.exe" (
  echo Setting up isolated Python environment...
  python -m venv .venv
)

".venv\Scripts\python.exe" -m pip install --upgrade pip >nul
".venv\Scripts\python.exe" -m pip install -r requirements.txt

where ffmpeg >nul 2>nul
if errorlevel 1 (
  echo [WARN] ffmpeg not found on PATH. Install via: winget install Gyan.FFmpeg
)

".venv\Scripts\python.exe" spy_bot_host.py
pause
