# Create server tool

> **Unofficial.** This is part of a personal, AI-assisted fork of
> [Create](https://github.com/Creators-of-Create/Create) by simibubi and the
> Creators of Create team (MIT licence). It is not made or supported by the
> Create team; please don't report problems with it to them.

Sets up and runs a dedicated Minecraft server with NeoForge and Create, so
friends can play on your world over your home network (LAN) or the internet (WAN).
You can run it in **Docker** or **directly on Windows**. Both read the same
settings file, `server.env`.

## 1. Settings

Open `server.env` in a text editor and:

1. Read the [Minecraft EULA](https://aka.ms/MinecraftEULA) and change `EULA=FALSE` to `EULA=TRUE`.
2. Check `MEMORY` (Create wants at least 4G; 6G-8G is better).
3. For internet play, put your players' usernames in `WHITELIST` and yours in `OPS`.

`server.env` has two presets. Keep one un-commented:

- **A (default):** official Create 6.0.10 on Minecraft 1.21.1 with NeoForge.
- **B:** [Create Fly](https://modrinth.com/mod/create-fly), a community Fabric
  port of Create, on Minecraft 26.1.2. Its authors warn that old saves may lose
  data, so test with a copy of your world.

Players need the same Minecraft version, loader and mod installed in their own
game. To use your own Create build, put the jar in `mods/` and remove
`create`/`create-fly` from `MODRINTH_PROJECTS`. Other mods can be added the same
way: a Modrinth slug in `MODRINTH_PROJECTS`, or a jar in `mods/`.

## 2a. Run in Docker

Needs [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Windows/macOS) or Docker Engine (Linux).

| | Windows | Linux / macOS |
|---|---|---|
| Start | double-click `docker-start.bat` | `./docker-start.sh` |
| Stop | `docker-stop.bat` | `./docker-stop.sh` |
| Log | `docker logs -f create-server` | same |
| Console | `docker attach create-server` (leave with Ctrl+P, Ctrl+Q) | same |

The world and all server files live in `data/`. The server restarts by
itself if the computer reboots, as long as Docker starts.

## 2b. Run directly on Windows (no Docker)

1. Double-click `setup-windows.bat`. It downloads Java, installs NeoForge into
   `server\`, downloads the mods, and writes the settings. Run it **as
   Administrator** once (right-click > Run as administrator) so it can open the
   port in Windows Firewall. Run it again any time you change `server.env`.
2. Double-click `start-windows.bat` to start the server. Type `stop` in its
   window to shut it down safely (closing the window can lose recent progress).

The world lives in `server\world\` (or whatever `LEVEL` is set to).

## 3. Connecting

Both start scripts print the addresses to use.

- **LAN (same Wi-Fi/network):** players use *Multiplayer > Add Server* with
  the address shown, for example `192.168.1.20:25565`.
- **WAN (over the internet):** on your router, forward **TCP port 25565**
  (or your `SERVER_PORT`) to the LAN address of the computer running the
  server. The setting is usually under *Port Forwarding*, *NAT* or *Virtual
  Servers*. Players then connect to your public address, shown by the start
  script. It's best to give the server PC a fixed (reserved) LAN address in
  the router so the forward keeps working.
  - If port forwarding doesn't work, your internet provider may be using
    CGNAT (common on 4G/5G and some NBN plans). Ask them for a public IP, or
    use a tunnel such as [playit.gg](https://playit.gg) or a VPN such as
    [Tailscale](https://tailscale.com) that every player joins.
  - Keep `ONLINE_MODE=true` and use `WHITELIST` when the server is reachable
    from the internet.
  - Your public IP can change. A free dynamic-DNS name (for example from your
    router or DuckDNS) gives players an address that keeps working.

## 4. Bringing in an existing world

Copy the world folder (the one containing `level.dat`) into `import-world/`,
then start (Docker) or run setup (Windows). It's copied into the server only
if the server doesn't have a world yet; your copy in `import-world/` is never
changed. Always keep your own backup too.

**Old worlds (for example from Minecraft 1.16):** Minecraft upgrades its own
blocks, but Create's blocks and contraptions changed a lot between versions.
Loading a 1.16 world straight into a much newer version will probably lose or
break Create machines. The safer route is to step the world up through each
major Create release (1.16.5 > 1.18.2 > 1.20.1 > 1.21.1 > newer), loading and
saving it at each step. A helper for that is planned; until it exists, test
with a copy of the world only.
