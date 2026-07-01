@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall.ps1" -GameDir "%~dp0\"
endlocal
