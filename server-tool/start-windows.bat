@echo off
rem Starts the server set up by setup-windows.bat.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows\Start-Server.ps1"
pause
