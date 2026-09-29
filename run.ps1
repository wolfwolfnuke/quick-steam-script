# One-liner: iwr -useb https://raw.githubusercontent.com/wolfwolfnuke/quick-steam-script/main/run.ps1 | iex
#
# Run this script in PowerShell

# Allow locally created scripts and scripts downloaded from the internet
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# ── Versions ──
$scriptVersion = "1.0.26"
$sniperVersion = "1.1.6 (custom: frag=1, verbose=on, auto-start, auto-tray)"
$pythonVersion  = "3.12.8"
$pyiVersion     = "6.x"
$scoopVersion   = "latest"
$gitVersion     = "latest"
$steamVersion   = "latest"

# Determine script directory (works both from file and iwr | iex)
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

Write-Host "=== Quick Steam Script v$scriptVersion ===" -ForegroundColor Cyan
Write-Host "  Running from: $scriptDir" -ForegroundColor Gray
Write-Host "  SNIper    : $sniperVersion" -ForegroundColor Gray
Write-Host "  Python    : $pythonVersion" -ForegroundColor Gray
Write-Host "  PyInstaller: $pyiVersion" -ForegroundColor Gray
Write-Host "  Scoop     : $scoopVersion" -ForegroundColor Gray
Write-Host "  Git       : $gitVersion" -ForegroundColor Gray
Write-Host "  Steam     : $steamVersion" -ForegroundColor Gray
Write-Host ""

# ── Install Scoop (skip if already installed) ──
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Scoop..." -ForegroundColor Cyan
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    irm get.scoop.sh | iex
} else {
    Write-Host "Scoop already installed, skipping." -ForegroundColor Green
}

# Make sure Scoop is available in this session
$env:Path += ";$env:USERPROFILE\scoop\shims"

# ── Install Git via Scoop ──
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Git..." -ForegroundColor Cyan
    scoop install git
} else {
    Write-Host "Git already installed, skipping." -ForegroundColor Green
}

# ── Install Python (skip if already installed) ──
$pythonExe = (Get-Command python -ErrorAction SilentlyContinue).Source
# Skip Windows Store stub
if ($pythonExe -and $pythonExe -like "*WindowsApps*") {
    $pythonExe = $null
}
if (-not $pythonExe) {
    Write-Host "Installing Python $pythonVersion..." -ForegroundColor Cyan
    $installerUrl = "https://www.python.org/ftp/python/3.12.8/python-3.12.8-amd64.exe"
    $installerPath = "$env:TEMP\python-installer.exe"
    
    $maxRetries = 3
    $retryCount = 0
    $downloaded = $false
    while (-not $downloaded -and $retryCount -lt $maxRetries) {
        try {
            Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
            $downloaded = $true
        } catch {
            $retryCount++
            Write-Host "Download failed (attempt $retryCount/$maxRetries): $_" -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
    if (-not $downloaded) {
        throw "Failed to download Python installer after $maxRetries attempts"
    }
    
    # Install Python silently (user scope, no admin needed, with tkinter)
    Start-Process -FilePath $installerPath -ArgumentList "/quiet", "InstallAllUsers=0", "PrependPath=1", "Include_test=0", "Include_tcltk=1" -Wait
    Remove-Item $installerPath -Force
    
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    $pythonExe = (Get-Command python -ErrorAction SilentlyContinue).Source
    if (-not $pythonExe) {
        throw "Python installation failed"
    }
    
    # Verify tkinter is available
    & $pythonExe -c "import tkinter"
    if ($LASTEXITCODE -ne 0) {
        throw "tkinter is not available after Python installation"
    }
}
Write-Host "Python: $pythonExe" -ForegroundColor Gray

# ── Build & launch custom SNIper (frag size 1, verbose, auto-background) ──
$sniperExe = "$scriptDir\sniper-src\SNIper_x64.exe"
$sniperSrc = "$scriptDir\sniper-src"

# Get SNIper source (copy from script dir or download from GitHub)
if (-not (Test-Path "$sniperSrc\src\run_sniper.py")) {
    if (Test-Path "$scriptDir\sniper-src\src\run_sniper.py") {
        Write-Host "Copying SNIper source from script directory..." -ForegroundColor Cyan
        Copy-Item -Path "$scriptDir\sniper-src" -Destination $sniperSrc -Recurse -Force
    } else {
        Write-Host "Downloading SNIper source from GitHub..." -ForegroundColor Cyan
        $zipUrl = "https://github.com/wolfwolfnuke/quick-steam-script/archive/refs/heads/main.zip"
        $zipPath = "$env:TEMP\sniper-src.zip"
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
        $extractPath = "$env:TEMP\sniper-extract"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        Copy-Item -Path "$extractPath\quick-steam-script-main\sniper-src" -Destination $sniperSrc -Recurse -Force
        Remove-Item $zipPath -Force
        Remove-Item $extractPath -Recurse -Force
    }
}

# Build the custom SNIper EXE if it doesn't exist
if (-not (Test-Path $sniperExe)) {
    Write-Host "Building custom SNIper (frag size 1, verbose, auto-background)..." -ForegroundColor Cyan

    # Install PyInstaller
    Write-Host "Installing PyInstaller..." -ForegroundColor Yellow
    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    & $pythonExe -m pip install "pyinstaller>=6.0,<7.0" 2>&1 | Out-Null
    $ErrorActionPreference = $oldEAP
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install PyInstaller"
    }

    # Build SNIper
    Write-Host "Building SNIper_x64.exe..." -ForegroundColor Cyan
    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    & $pythonExe -m PyInstaller `
        --onefile `
        --noconsole `
        --noupx `
        --clean `
        --noconfirm `
        --paths "$sniperSrc\src" `
        --name "SNIper_x64" `
        --distpath "$sniperSrc\packaging\dist" `
        --workpath "$sniperSrc\packaging\build" `
        --specpath "$sniperSrc\packaging" `
        --icon "$sniperSrc\packaging\SNIper.ico" `
        --add-data "$sniperSrc\packaging\SNIper.ico;." `
        "$sniperSrc\src\run_sniper.py" 2>&1 | Out-Null
    $ErrorActionPreference = $oldEAP

    if ($LASTEXITCODE -ne 0) {
        throw "PyInstaller build failed"
    }

    # Move to expected location
    $builtExe = "$sniperSrc\packaging\dist\SNIper_x64.exe"
    if (Test-Path $builtExe) {
        Move-Item $builtExe $sniperExe -Force
    } else {
        throw "Build reported success but EXE not found at $builtExe"
    }
    
    # Cleanup
    Remove-Item "$sniperSrc\packaging\build" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$sniperSrc\packaging\dist" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$sniperSrc\packaging\SNIper_x64.spec" -Force -ErrorAction SilentlyContinue
}

# Launch custom SNIper in the background (auto-starts proxy, minimizes to tray)
if (Test-Path $sniperExe) {
    Write-Host "Launching custom SNIper from $sniperExe" -ForegroundColor Green
    Start-Process -FilePath $sniperExe -WindowStyle Hidden
} else {
    Write-Warning "SNIper EXE not found. Skipping launch."
}

# ── Install Steam via Scoop ──
Write-Host "Installing Steam..." -ForegroundColor Cyan
$gamesBucket = scoop bucket list | Select-String "games"
if (-not $gamesBucket) {
    scoop bucket add games
}
scoop update
scoop install steam
