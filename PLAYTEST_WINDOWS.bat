@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run_playtest_windows.ps1"
if errorlevel 1 (
  echo.
  echo Idle Rift could not start. See the message above.
  pause
)
