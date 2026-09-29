# One-liner: iwr -useb https://raw.githubusercontent.com/wolfwolfnuke/quick-steam-script/main/run.ps1 | iex
#
# Run this script in PowerShell

# Allow locally created scripts and scripts downloaded from the internet
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# ── Versions ──
$scriptVersion = "1.0.19"
$sniperVersion = "1.1.6 (custom: frag=1, verbose=on, auto-start, auto-tray)"
$pythonVersion  = "3.12.8"
$pyiVersion     = "6.x"
$scoopVersion   = "latest"
$gitVersion     = "latest"
$steamVersion   = "latest"

Write-Host "=== Quick Steam Script v$scriptVersion ===" -ForegroundColor Cyan
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
$sniperExe = "$PSScriptRoot\sniper-src\SNIper_x64.exe"
$sniperSrc = "$PSScriptRoot\sniper-src"

# Clone SNIper source if it doesn't exist
if (-not (Test-Path "$sniperSrc\src\run_sniper.py")) {
    Write-Host "Cloning SNIper source..." -ForegroundColor Cyan
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git not found. Please install Git first."
    }
    git clone https://github.com/Reuzola/SNIper.git $sniperSrc 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone SNIper repository"
    }
}

# Apply custom SNIper modifications (frag=1, verbose=on, auto-start, auto-tray)
$uiFile = "$sniperSrc\src\sniper\ui.py"
$configFile = "$sniperSrc\src\sniper\config.py"

if (Test-Path $uiFile) {
    $uiContent = Get-Content $uiFile -Raw
    # Set fragment size default to 1
    $uiContent = $uiContent -replace 'self\._frag_var\s*=\s*tk\.IntVar\(value=2\)', 'self._frag_var    = tk.IntVar(value=1)'
    # Set verbose default to True
    $uiContent = $uiContent -replace 'self\._verbose_var\s*=\s*tk\.BooleanVar\(value=False\)', 'self._verbose_var = tk.BooleanVar(value=True)'
    # Add auto-start and auto-minimize after tray start
    $uiContent = $uiContent -replace '(self\._tray\.start\(\))', "`$1`n`n        # Custom build: auto-start proxy and minimize to tray (background)`n        self._start()`n        self._hide_to_tray()"
    Set-Content -Path $uiFile -Value $uiContent -NoNewline
}

if (Test-Path $configFile) {
    $configContent = Get-Content $configFile -Raw
    # Set DoH fragment size to 1
    $configContent = $configContent -replace '_DOH_FRAGMENT_SIZE\s*=\s*2', '_DOH_FRAGMENT_SIZE = 1'
    Set-Content -Path $configFile -Value $configContent -NoNewline
}

# Build the custom SNIper EXE if it doesn't exist
if (-not (Test-Path $sniperExe)) {
    Write-Host "Building custom SNIper (frag size 1, verbose, auto-background)..." -ForegroundColor Cyan

    # Install PyInstaller
    Write-Host "Installing PyInstaller..." -ForegroundColor Yellow
    & $pythonExe -m pip install "pyinstaller>=6.0,<7.0"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install PyInstaller"
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
        "$sniperSrc\src\run_sniper.py" 2>&1 | Out-Null

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

# ── Install Steam via Scoop ──
Write-Host "Installing Steam..." -ForegroundColor Cyan
$extrasBucket = scoop bucket list | Select-String "extras"
if (-not $extrasBucket) {
    scoop bucket add extras
}
scoop update

# Try to find the correct Steam manifest
$steamManifest = scoop search steam | Select-String "steam" | Select-Object -First 5
Write-Host "Available Steam manifests:" -ForegroundColor Gray
$steamManifest | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

# Try common manifest names
$manifestNames = @("steam", "steam-client", "steam-original")
$installed = $false
foreach ($name in $manifestNames) {
    $result = scoop install $name 2>&1
    if ($result -match "already installed" -or $result -match "installed successfully") {
        $installed = $true
        break
    }
}
if (-not $installed) {
    Write-Warning "Could not find Steam manifest. Try: scoop search steam"
}
