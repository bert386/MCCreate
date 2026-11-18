@echo off
rem Installs Java, NeoForge and Create into the server\ folder (no Docker needed).
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows\Setup-Server.ps1"
pause
