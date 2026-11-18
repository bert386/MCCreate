#!/usr/bin/env bash
# Start the Create server in Docker using the settings in server.env.
set -euo pipefail
cd "$(dirname "$0")"

if ! grep -qiE '^EULA=TRUE' server.env; then
  echo "Please read the Minecraft EULA (https://aka.ms/MinecraftEULA) and set EULA=TRUE in server.env first."
  exit 1
fi

# If an old world was dropped into import-world/, point the server at it.
IMPORT_WORLD=""
level_dat=$(find import-world -maxdepth 3 -name level.dat -print -quit || true)
if [[ -n "$level_dat" ]]; then
  IMPORT_WORLD="/$(dirname "$level_dat")"
  echo "Found a world to import: $(dirname "$level_dat") (only used if the server has no world yet)"
fi
export IMPORT_WORLD

docker compose --env-file server.env up -d
port=$(grep -E '^SERVER_PORT=' server.env | cut -d= -f2)
echo
echo "Server starting. Follow the log with:  docker logs -f create-server"
echo "Server console (type commands):       docker attach create-server   (detach: Ctrl+P then Ctrl+Q)"
echo
echo "LAN players connect to:  $(hostname -I 2>/dev/null | awk '{print $1}'):${port:-25565}"
echo "WAN players connect to:  $(curl -s --max-time 5 https://api.ipify.org || echo '<your public IP>'):${port:-25565}"
echo "  (WAN needs TCP port ${port:-25565} forwarded on your router to this machine. See README.md.)"
