@echo off
cd /d "%~dp0"
docker compose --env-file server.env stop
pause
