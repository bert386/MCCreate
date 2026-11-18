# Starts the server in Docker Desktop using server.env.
. (Join-Path $PSScriptRoot 'Common.ps1')
$cfg = Read-ServerEnv
if ((Get-Setting $cfg 'EULA' 'FALSE') -ine 'TRUE') {
    Write-Host "Read the Minecraft EULA (https://aka.ms/MinecraftEULA) and set EULA=TRUE in server.env first." -ForegroundColor Yellow
    exit 1
}
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Docker was not found. Install Docker Desktop (https://www.docker.com/products/docker-desktop/) and start it, or use setup-windows.bat instead." -ForegroundColor Yellow
    exit 1
}
$import = Find-ImportWorld
$env:IMPORT_WORLD = ''
if ($import) {
    $rel = $import.Substring((Join-Path $ToolRoot 'import-world').Length).Replace('\', '/')
    $env:IMPORT_WORLD = '/import-world' + $rel
    Write-Host "Found a world to import: $import (only used if the server has no world yet)"
}
Push-Location $ToolRoot
try {
    docker compose --env-file server.env up -d
    if ($LASTEXITCODE -ne 0) { throw "docker compose failed. Is Docker Desktop running?" }
} finally { Pop-Location }
$port = Get-Setting $cfg 'SERVER_PORT' '25565'
Add-FirewallRule $port
Show-ConnectInfo $port
Write-Host "Server starting in Docker. The first start downloads everything and takes a few minutes."
Write-Host "  Watch the log:        docker logs -f create-server"
Write-Host "  Server console:       docker attach create-server   (leave with Ctrl+P then Ctrl+Q)"
Write-Host "  Stop the server:      docker-stop.bat"
