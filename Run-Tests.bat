@echo off
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0Tests\Invoke-PokeDebugTests.ps1" -RequireRuby
pause
