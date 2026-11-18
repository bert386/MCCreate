# Installs (or updates) a NeoForge + Create server in server-tool\server\
# using the settings in server.env. Safe to run again after changing settings.
. (Join-Path $PSScriptRoot 'Common.ps1')

$cfg        = Read-ServerEnv
$mcVersion  = Get-Setting $cfg 'VERSION' '1.21.1'
$neoVersion = Get-Setting $cfg 'NEOFORGE_VERSION' '21.1.267'
$javaMajor  = if ($cfg['JAVA_IMAGE_TAG'] -match 'java(\d+)') { [int]$Matches[1] } else { 21 }
$port       = Get-Setting $cfg 'SERVER_PORT' '25565'
$level      = Get-Setting $cfg 'LEVEL' 'world'
$memory     = Get-Setting $cfg 'MEMORY' '6G'

$serverDir   = Join-Path $ToolRoot 'server'
$runtimeDir  = Join-Path $ToolRoot 'runtime'
$downloadDir = Join-Path $ToolRoot 'downloads'
New-Item -ItemType Directory -Force -Path $serverDir, $downloadDir | Out-Null

Write-Host "Setting up a Create server: Minecraft $mcVersion, NeoForge $neoVersion, Java $javaMajor" -ForegroundColor Cyan

# --- 0. EULA ----------------------------------------------------------------
if ((Get-Setting $cfg 'EULA' 'FALSE') -ine 'TRUE') {
    Write-Host ""
    Write-Host "You must accept the Minecraft EULA to run a server: https://aka.ms/MinecraftEULA" -ForegroundColor Yellow
    Write-Host "Read it, then set EULA=TRUE in server.env and run this setup again." -ForegroundColor Yellow
    exit 1
}
Set-Content -Path (Join-Path $serverDir 'eula.txt') -Value 'eula=true'

# --- 1. Java ---------------------------------------------------------------
$javaExe = Join-Path $runtimeDir 'bin\java.exe'
$marker  = Join-Path $runtimeDir "java-$javaMajor.txt"
if (-not ((Test-Path $javaExe) -and (Test-Path $marker))) {
    Write-Host "Downloading Java $javaMajor (Eclipse Temurin JRE)..."
    $zip = Join-Path $downloadDir "temurin-$javaMajor.zip"
    $url = "https://api.adoptium.net/v3/binary/latest/$javaMajor/ga/windows/x64/jre/hotspot/normal/eclipse"
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip
    if (Test-Path $runtimeDir) { Remove-Item -Recurse -Force $runtimeDir }
    $tmp = Join-Path $downloadDir 'jre-extract'
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
    Expand-Archive -Path $zip -DestinationPath $tmp
    Move-Item -Path (Get-ChildItem $tmp -Directory | Select-Object -First 1).FullName -Destination $runtimeDir
    Remove-Item -Recurse -Force $tmp
    Set-Content -Path $marker -Value $javaMajor
}
Write-Host "Java ready: $javaExe"

# --- 2. NeoForge server -----------------------------------------------------
$neoMarker = Join-Path $serverDir '.neoforge-version'
if (-not ((Test-Path $neoMarker) -and ((Get-Content $neoMarker) -eq $neoVersion))) {
    Write-Host "Downloading and installing NeoForge $neoVersion..."
    $installer = Join-Path $downloadDir "neoforge-$neoVersion-installer.jar"
    $url = "https://maven.neoforged.net/releases/net/neoforged/neoforge/$neoVersion/neoforge-$neoVersion-installer.jar"
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $installer
    Push-Location $serverDir
    try {
        & $javaExe -jar $installer --installServer $serverDir
        if ($LASTEXITCODE -ne 0) { throw "NeoForge installer failed (exit code $LASTEXITCODE)" }
    } finally { Pop-Location }
    Set-Content -Path $neoMarker -Value $neoVersion
}

# --- 3. Mods ----------------------------------------------------------------
$modsDir = Join-Path $serverDir 'mods'
New-Item -ItemType Directory -Force -Path $modsDir | Out-Null
# Start clean so removed or updated mods don't linger.
Get-ChildItem $modsDir -Filter '*.jar' | Remove-Item -Force

$projects = (Get-Setting $cfg 'MODRINTH_PROJECTS' '') -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
foreach ($slug in $projects) {
    $loaders = [uri]::EscapeDataString('["neoforge"]')
    $games   = [uri]::EscapeDataString("[`"$mcVersion`"]")
    $api = "https://api.modrinth.com/v2/project/$slug/version?loaders=$loaders&game_versions=$games"
    $versions = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = 'create-server-tool' }
    $v = $versions | Where-Object { $_.version_type -eq 'release' } | Select-Object -First 1
    if (-not $v) { $v = $versions | Select-Object -First 1 }
    if (-not $v) { throw "Modrinth has no NeoForge $mcVersion build of '$slug'. Remove it from MODRINTH_PROJECTS or put the jar in mods\." }
    $file = $v.files | Where-Object { $_.primary } | Select-Object -First 1
    if (-not $file) { $file = $v.files | Select-Object -First 1 }
    Write-Host "Downloading $slug $($v.version_number)..."
    Invoke-WebRequest -UseBasicParsing -Uri $file.url -OutFile (Join-Path $modsDir $file.filename)
}
$localMods = Get-ChildItem (Join-Path $ToolRoot 'mods') -Filter '*.jar' -ErrorAction SilentlyContinue
foreach ($m in $localMods) {
    Write-Host "Adding local mod $($m.Name)"
    Copy-Item $m.FullName -Destination $modsDir -Force
}

# --- 4. server.properties --------------------------------------------------
$propsFile = Join-Path $serverDir 'server.properties'
$props = [ordered]@{}
if (Test-Path $propsFile) {
    foreach ($line in Get-Content $propsFile) {
        if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
        $i = $line.IndexOf('='); $props[$line.Substring(0, $i)] = $line.Substring($i + 1)
    }
}
$whitelist = (Get-Setting $cfg 'WHITELIST' '') -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
$props['server-port']       = $port
$props['level-name']        = $level
$props['motd']              = Get-Setting $cfg 'MOTD' 'Create server'
$props['max-players']       = Get-Setting $cfg 'MAX_PLAYERS' '10'
$props['difficulty']        = Get-Setting $cfg 'DIFFICULTY' 'normal'
$props['gamemode']          = Get-Setting $cfg 'MODE' 'survival'
$props['online-mode']       = (Get-Setting $cfg 'ONLINE_MODE' 'true').ToLower()
$props['white-list']        = if ($whitelist) { 'true' } else { 'false' }
$props['enforce-whitelist'] = $props['white-list']
$props.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" } | Set-Content -Path $propsFile -Encoding ASCII

# --- 5. Whitelist and operators (looked up by username) ---------------------
function Get-PlayerEntries($names) {
    $out = @()
    foreach ($n in $names) {
        try {
            $p = Invoke-RestMethod -Uri "https://api.mojang.com/users/profiles/minecraft/$n"
            $id = $p.id -replace '^(.{8})(.{4})(.{4})(.{4})(.{12})$', '$1-$2-$3-$4-$5'
            $out += [pscustomobject]@{ uuid = $id; name = $p.name }
        } catch { Write-Host "Could not find Minecraft account '$n', skipping." -ForegroundColor Yellow }
    }
    return ,$out
}
if ($whitelist) {
    ConvertTo-Json -InputObject (Get-PlayerEntries $whitelist) | Set-Content (Join-Path $serverDir 'whitelist.json')
}
$ops = (Get-Setting $cfg 'OPS' '') -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
if ($ops) {
    $entries = Get-PlayerEntries $ops | ForEach-Object {
        [pscustomobject]@{ uuid = $_.uuid; name = $_.name; level = 4; bypassesPlayerLimit = $false }
    }
    ConvertTo-Json -InputObject @($entries) | Set-Content (Join-Path $serverDir 'ops.json')
}

# --- 6. Memory ----------------------------------------------------------------
Set-Content -Path (Join-Path $serverDir 'user_jvm_args.txt') -Value "-Xms$memory`n-Xmx$memory"

# --- 7. Import an existing world ---------------------------------------------
$worldDir = Join-Path $serverDir $level
$import = Find-ImportWorld
if ($import) {
    if (Test-Path (Join-Path $worldDir 'level.dat')) {
        Write-Host "A world already exists in server\$level, so import-world\ was not copied." -ForegroundColor Yellow
        Write-Host "To replace it, move server\$level somewhere safe first, then run setup again."
    } else {
        Write-Host "Importing world from $import ..."
        Copy-Item -Path $import -Destination $worldDir -Recurse
        Write-Host "World copied (your original in import-world\ is untouched)."
    }
}

# --- 8. Firewall and connection info ----------------------------------------
Add-FirewallRule $port
Show-ConnectInfo $port
Write-Host "Setup complete. Run start-windows.bat to start the server." -ForegroundColor Green
