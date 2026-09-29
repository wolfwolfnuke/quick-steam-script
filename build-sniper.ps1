# build-sniper.ps1 — Build the custom SNIper EXE natively on Windows
# This is a fallback for when the Docker-based build is not available.

$ErrorActionPreference = "Stop"

$projectRoot = $PSScriptRoot
$sniperSrc   = Join-Path $projectRoot "sniper-src"
$entry       = Join-Path $sniperSrc "src\run_sniper.py"
$icon        = Join-Path $sniperSrc "packaging\SNIper.ico"
$distPath    = Join-Path $sniperSrc "packaging\dist"
$workPath    = Join-Path $sniperSrc "packaging\build"
$specPath    = Join-Path $sniperSrc "packaging"
$exeName     = "SNIper_x64"
$finalExe    = Join-Path $sniperSrc "$exeName.exe"

Write-Host "=== Custom SNIper Build ===" -ForegroundColor Cyan
Write-Host "  Fragment size : 1 (default is 2)"
Write-Host "  Verbose       : ON (default is OFF)"
Write-Host "  Auto-start    : ON (proxy starts automatically)"
Write-Host "  Auto-minimize : ON (goes to system tray on launch)"
Write-Host ""

# Find Python
$py = (Get-Command py -ErrorAction SilentlyContinue).Source
if (-not $py) { $py = (Get-Command python -ErrorAction SilentlyContinue).Source }
if (-not $py) {
    Write-Error "Python not found. Install from https://python.org/downloads/"
    exit 1
}

Write-Host "Python: $py" -ForegroundColor Gray

# Ensure PyInstaller
& $py -m PyInstaller --version 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Installing PyInstaller..." -ForegroundColor Yellow
    & $py -m pip install "pyinstaller>=6.0,<7.0"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install PyInstaller"
        exit 1
    }
}

# Clean previous build
if (Test-Path $finalExe) { Remove-Item $finalExe -Force }
if (Test-Path $distPath)  { Remove-Item $distPath -Recurse -Force }
if (Test-Path $workPath)  { Remove-Item $workPath -Recurse -Force }
if (Test-Path (Join-Path $specPath "$exeName.spec")) {
    Remove-Item (Join-Path $specPath "$exeName.spec") -Force
}

# Build
Write-Host "Building SNIper_x64.exe..." -ForegroundColor Cyan
& $py -m PyInstaller `
    --onefile `
    --noconsole `
    --noupx `
    --clean `
    --noconfirm `
    --paths (Join-Path $sniperSrc "src") `
    --name $exeName `
    --distpath $distPath `
    --workpath $workPath `
    --specpath $specPath `
    --icon $icon `
    --add-data "$icon;." `
    $entry

if ($LASTEXITCODE -ne 0) {
    Write-Error "PyInstaller build failed"
    exit 1
}

# Move to expected location
Move-Item (Join-Path $distPath "$exeName.exe") $finalExe -Force
Remove-Item $distPath -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $workPath -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $specPath "$exeName.spec") -Force -ErrorAction SilentlyContinue

# Verify
if (Test-Path $finalExe) {
    $size = (Get-Item $finalExe).Length / 1MB
    Write-Host ""
    Write-Host "Build successful!" -ForegroundColor Green
    Write-Host "  $finalExe ($([math]::Round($size, 1)) MB)"
} else {
    Write-Error "Build reported success but EXE not found"
    exit 1
}
