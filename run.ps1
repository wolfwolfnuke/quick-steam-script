# Run this script in PowerShell

# Allow locally created scripts and scripts downloaded from the internet
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# ── Build & launch custom SNIper (frag size 1, verbose, auto-background) ──
$sniperExe = "$PSScriptRoot\sniper-src\SNIper_x64.exe"
$sniperSrc = "$PSScriptRoot\sniper-src"

# Build the custom SNIper EXE if it doesn't exist
if (-not (Test-Path $sniperExe)) {
    Write-Host "Building custom SNIper (frag size 1, verbose, auto-background)..." -ForegroundColor Cyan
    $buildScript = "$sniperSrc\packaging\build_exe.bat"
    if (Test-Path $buildScript) {
        cmd /c $buildScript
    } else {
        # Fallback: build directly with PyInstaller
        $env:PATH = "$env:USERPROFILE\scoop\shims;$env:PATH"
        $py = (Get-Command py -ErrorAction SilentlyContinue).Source
        if (-not $py) { $py = (Get-Command python -ErrorAction SilentlyContinue).Source }
        if ($py) {
            & $py -m pip install "pyinstaller>=6.0,<7.0" 2>$null
            & $py -m PyInstaller --onefile --noconsole --noupx --clean --noconfirm `
                --paths "$sniperSrc\src" `
                --name "SNIper_x64" `
                --distpath "$sniperSrc\packaging\dist" `
                --workpath "$sniperSrc\packaging\build" `
                --specpath "$sniperSrc\packaging" `
                --icon "$sniperSrc\packaging\SNIper.ico" `
                --add-data "$sniperSrc\packaging\SNIper.ico;." `
                "$sniperSrc\src\run_sniper.py"
            Move-Item "$sniperSrc\packaging\dist\SNIper_x64.exe" $sniperExe -Force
        }
    }
}

# Launch custom SNIper in the background (auto-starts proxy, minimizes to tray)
if (Test-Path $sniperExe) {
    Write-Host "Launching custom SNIper in background..." -ForegroundColor Green
    Start-Process -FilePath $sniperExe -WindowStyle Hidden
} else {
    Write-Warning "SNIper EXE not found. Skipping launch."
}

# Install Scoop
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
irm get.scoop.sh | iex
 
# Make sure Scoop is available in this session
$env:Path += ";$env:USERPROFILE\scoop\shims"
 
# Install Git using Scoop
scoop install git
 
# Install Steam using Scoop
scoop bucket add extras
scoop install steam
