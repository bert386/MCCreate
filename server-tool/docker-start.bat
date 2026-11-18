@echo off
rem Start the Create server in Docker Desktop using the settings in server.env.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows\Start-Docker.ps1"
pause
