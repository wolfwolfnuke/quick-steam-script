# One-liner: iwr -useb https://raw.githubusercontent.com/wolfwolfnuke/quick-steam-script/main/run.ps1 | iex
#
# Run this script in PowerShell

# Allow locally created scripts and scripts downloaded from the internet
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# ── Versions ──
$scriptVersion = "1.0.6"
$sniperVersion = "1.1.6 (custom: frag=1, verbose=on, auto-start, auto-tray)"
$pythonVersion  = "3.12.8"
$pyiVersion     = "6.x"
$scoopVersion   = "latest"
$gitVersion     = "latest"
$steamVersion   = "latest"

Write-Host "=== Quick Steam Script v$scriptVersion ===" -ForegroundColor Cyan
Write-Host "  SNIper    : $sniperVersion" -ForegroundColor Gray
Write-Host "  Python    : $pythonVersion (embedded)" -ForegroundColor Gray
Write-Host "  PyInstaller: $pyiVersion" -ForegroundColor Gray
Write-Host "  Scoop     : $scoopVersion" -ForegroundColor Gray
Write-Host "  Git       : $gitVersion" -ForegroundColor Gray
Write-Host "  Steam     : $steamVersion" -ForegroundColor Gray
Write-Host ""

# ── Build & launch custom SNIper (frag size 1, verbose, auto-background) ──
$sniperExe = "$PSScriptRoot\sniper-src\SNIper_x64.exe"
$sniperSrc = "$PSScriptRoot\sniper-src"

# Build the custom SNIper EXE if it doesn't exist
if (-not (Test-Path $sniperExe)) {
    Write-Host "Building custom SNIper (frag size 1, verbose, auto-background)..." -ForegroundColor Cyan

    # Download Python 3.12 embedded for Windows (no installation needed)
    $pythonDir = "$env:TEMP\python-embed"
    $pythonExe = "$pythonDir\python.exe"
    if (-not (Test-Path $pythonExe)) {
        Write-Host "Downloading Python 3.12 embedded..." -ForegroundColor Yellow
        $zipUrl = "https://www.python.org/ftp/python/3.12.8/python-3.12.8-embed-amd64.zip"
        $zipPath = "$env:TEMP\python-embed.zip"
        
        # Download with retry
        $maxRetries = 3
        $retryCount = 0
        $downloaded = $false
        while (-not $downloaded -and $retryCount -lt $maxRetries) {
            try {
                Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
                $downloaded = $true
            } catch {
                $retryCount++
                Write-Host "Download failed (attempt $retryCount/$maxRetries): $_" -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
        if (-not $downloaded) {
            throw "Failed to download Python embedded after $maxRetries attempts"
        }
        
        # Extract
        Expand-Archive -Path $zipPath -DestinationPath $pythonDir -Force
        Remove-Item $zipPath -Force
        
        # Verify
        if (-not (Test-Path $pythonExe)) {
            throw "Python embedded extraction failed - $pythonExe not found"
        }
    }

    # Install pip using get-pip.py (official bootstrap method)
    Write-Host "Installing pip..." -ForegroundColor Yellow
    $getPipPath = "$env:TEMP\get-pip.py"
    
    # Download get-pip.py
    $maxRetries = 3
    $retryCount = 0
    $downloaded = $false
    while (-not $downloaded -and $retryCount -lt $maxRetries) {
        try {
            Invoke-WebRequest -Uri "https://bootstrap.pypa.io/get-pip.py" -OutFile $getPipPath -UseBasicParsing
            $downloaded = $true
        } catch {
            $retryCount++
            Write-Host "get-pip.py download failed (attempt $retryCount/$maxRetries): $_" -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
    
    if (-not $downloaded) {
        throw "Failed to download get-pip.py after $maxRetries attempts"
    }
    
    # Run get-pip.py
    & $pythonExe $getPipPath
    if ($LASTEXITCODE -ne 0) {
        throw "get-pip.py failed to install pip"
    }
    
    # Verify pip is working
    & $pythonExe -m pip --version
    if ($LASTEXITCODE -ne 0) {
        throw "pip installation verification failed"
    }
    
    Remove-Item $getPipPath -Force -ErrorAction SilentlyContinue

    # Add Python Scripts directory to PATH
    $scriptsDir = "$pythonDir\Scripts"
    if (-not (Test-Path $scriptsDir)) {
        New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
    }
    $env:Path = "$scriptsDir;$env:Path"

    # Verify pip is working
    Write-Host "Verifying pip..." -ForegroundColor Yellow
    & $pythonExe -m pip --version
    if ($LASTEXITCODE -ne 0) {
        throw "pip is not working. Cannot continue."
    }

    # Install PyInstaller
    Write-Host "Installing PyInstaller..." -ForegroundColor Yellow
    & $pythonExe -m pip install "pyinstaller>=6.0,<7.0"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install PyInstaller"
    }

    # Verify PyInstaller is installed
    Write-Host "Verifying PyInstaller..." -ForegroundColor Yellow
    & $pythonExe -m PyInstaller --version
    if ($LASTEXITCODE -ne 0) {
        throw "PyInstaller installation verification failed"
    }

    # Build SNIper
    Write-Host "Building SNIper_x64.exe..." -ForegroundColor Cyan
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
        "$sniperSrc\src\run_sniper.py"

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
    Write-Host "Launching custom SNIper in background..." -ForegroundColor Green
    Start-Process -FilePath $sniperExe -WindowStyle Hidden
} else {
    Write-Warning "SNIper EXE not found. Skipping launch."
}

# Install Scoop (skip if already installed)
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Scoop..." -ForegroundColor Cyan
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    irm get.scoop.sh | iex
} else {
    Write-Host "Scoop already installed, skipping." -ForegroundColor Green
}

# Make sure Scoop is available in this session
$env:Path += ";$env:USERPROFILE\scoop\shims"

# Install Git using Scoop
scoop install git

# Install Steam using Scoop
scoop bucket add extras
scoop install steam
