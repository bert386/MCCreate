# Shared helpers for the Windows scripts. Dot-sourced by the other .ps1 files.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # makes Invoke-WebRequest much faster
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ToolRoot = Split-Path -Parent $PSScriptRoot      # the server-tool folder

function Read-ServerEnv {
    $path = Join-Path $ToolRoot 'server.env'
    $cfg = @{}
    foreach ($line in Get-Content $path) {
        $t = $line.Trim()
        if ($t -eq '' -or $t.StartsWith('#')) { continue }
        $i = $t.IndexOf('=')
        if ($i -lt 1) { continue }
        $cfg[$t.Substring(0, $i).Trim()] = $t.Substring($i + 1).Trim()
    }
    return $cfg
}

function Get-Setting($cfg, $name, $default) {
    if ($cfg.ContainsKey($name) -and $cfg[$name] -ne '') { return $cfg[$name] }
    return $default
}

function Find-ImportWorld {
    # Returns the folder that holds level.dat inside import-world\, or $null.
    $dir = Join-Path $ToolRoot 'import-world'
    if (-not (Test-Path $dir)) { return $null }
    $hit = Get-ChildItem -Path $dir -Filter 'level.dat' -Recurse -Depth 2 -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($hit) { return $hit.Directory.FullName }
    return $null
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Add-FirewallRule($port) {
    $name = "Minecraft Create server (TCP $port)"
    if (Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue) {
        Write-Host "Windows Firewall already allows port $port."
        return
    }
    if (Test-IsAdmin) {
        New-NetFirewallRule -DisplayName $name -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow | Out-Null
        Write-Host "Added a Windows Firewall rule allowing TCP port $port."
    } else {
        Write-Host ""
        Write-Host "To let other computers connect, Windows Firewall must allow TCP port $port." -ForegroundColor Yellow
        Write-Host "Either run setup-windows.bat once as Administrator (right-click > Run as administrator)," -ForegroundColor Yellow
        Write-Host "or allow Java when Windows asks the first time the server starts." -ForegroundColor Yellow
    }
}

function Show-ConnectInfo($port) {
    Write-Host ""
    Write-Host "=== How players connect ===" -ForegroundColor Cyan
    $lan = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and $_.PrefixOrigin -ne 'WellKnown' } |
        Select-Object -ExpandProperty IPAddress
    foreach ($ip in $lan) { Write-Host "  LAN (same network):  ${ip}:$port" }
    try {
        $pub = (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 5).ToString().Trim()
    } catch { $pub = '<your public IP>' }
    Write-Host "  WAN (internet):      ${pub}:$port"
    Write-Host "    WAN needs TCP port $port forwarded on your router to this PC's LAN address."
    Write-Host "    See README.md for router steps and what to do if forwarding is not possible."
    Write-Host ""
}
