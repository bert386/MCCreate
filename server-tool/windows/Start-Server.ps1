# Starts the server installed by Setup-Server.ps1. Type "stop" in this window to shut it down safely.
. (Join-Path $PSScriptRoot 'Common.ps1')
$cfg = Read-ServerEnv
$serverDir = Join-Path $ToolRoot 'server'
$runBat = Join-Path $serverDir 'run.bat'
if (-not (Test-Path $runBat)) {
    Write-Host "The server is not set up yet. Run setup-windows.bat first." -ForegroundColor Yellow
    exit 1
}
# Use the Java that setup downloaded, not whatever else is installed.
$env:PATH = (Join-Path $ToolRoot 'runtime\bin') + ';' + $env:PATH
Show-ConnectInfo (Get-Setting $cfg 'SERVER_PORT' '25565')
Write-Host 'Starting server. Type "stop" and press Enter to shut it down safely.' -ForegroundColor Green
Push-Location $serverDir
try { & cmd /c run.bat nogui } finally { Pop-Location }
