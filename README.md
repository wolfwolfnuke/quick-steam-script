# Quick Steam Script

A PowerShell automation script that builds and launches a custom [SNIper](https://github.com/Reuzola/SNIper) DPI-bypass proxy, then installs [Scoop](https://scoop.sh), Git, and Steam — all in one go.

## What It Does

Running `run.ps1` performs two phases:

1. **Build & launch a custom SNIper** — compiles a portable `SNIper_x64.exe` from the bundled source (if not already built), then launches it in the background. The proxy starts automatically and minimizes to the system tray.
2. **Install packages via Scoop** — installs the Scoop package manager, then uses it to install Git and Steam.

## Prerequisites

- **Windows 10 (1607) or later** — 64-bit (x64 or ARM64)
- **PowerShell 5.1+** (included with Windows)
- **Python 3.10–3.12** — required only if the SNIper EXE needs to be built (i.e., `sniper-src/SNIper_x64.exe` does not already exist). Python 3.13+ raises the EXE's OS floor to Windows 10 1809.
- **Internet access** — for downloading Scoop, Git, Steam, and PyInstaller

## How to Run

Open PowerShell in the project directory and execute:

```powershell
.\run.ps1
```

The script will:

1. Set the execution policy to `RemoteSigned` for the current user (if not already set).
2. Build `SNIper_x64.exe` from `sniper-src\` using PyInstaller (skipped if the EXE already exists).
3. Launch SNIper hidden — the proxy starts and the window minimizes to the tray.
4. Install Scoop, then use it to install Git and Steam.

> **Note:** The first run will take longer because PyInstaller must compile the EXE. Subsequent runs skip the build step.

## Custom SNIper Build

The bundled source in `sniper-src\` is a fork of [Reuzola/SNIper](https://github.com/Reuzola/SNIper) with the following changes applied to `src/sniper/config.py` and `src/sniper/ui.py`:

| Setting | Default | Custom | Effect |
|---|---|---|---|
| Fragment size | `2` | `1` | Each TCP segment during the TLS handshake carries only 1 byte, making it harder for DPI to reassemble the SNI |
| Verbose logging | `off` | `on` | All internal events (including DEBUG and per-fragment notices) are shown in the log |
| Proxy start | Manual | Auto | The proxy starts automatically when the app launches |
| Window behavior | Visible | Minimized | The app hides to the system tray on launch |

These changes are baked into the source, so every build of `SNIper_x64.exe` from this repository includes them.

## Project Structure

```
quick-steam-script/
├── run.ps1                  # Main PowerShell automation script
├── README.md                # This file
└── sniper-src/              # Custom SNIper source (forked from GitHub)
    ├── src/
    │   ├── run_sniper.py    # PyInstaller entry point
    │   └── sniper/          # Application package
    │       ├── config.py    # Tunables (fragment size = 1)
    │       ├── ui.py        # Tk UI (verbose=True, auto-start, auto-tray)
    │       ├── server.py    # Proxy server logic
    │       ├── tray.py      # System tray integration
    │       ├── dns.py       # DoH / plain DNS resolution
    │       ├── proxy.py     # Connection handler
    │       ├── logformat.py # Log formatting
    │       ├── compat.py    # Platform detection
    │       └── resources.py # Icon path resolution
    ├── packaging/
    │   ├── build_exe.bat   # Windows build script (PyInstaller)
    │   ├── SNIper.ico      # Application icon
    │   ├── version_info.txt
    │   └── app.manifest
    ├── tests/               # Unit tests
    ├── CHANGELOG.md
    └── README.md            # Upstream SNIper documentation
```

## Building the EXE

### Native Windows Build (Recommended)

PyInstaller does **not** cross-compile — the EXE must be built on a machine of the target architecture. On Windows:

```powershell
cd sniper-src\packaging
.\build_exe.bat
```

The script will:

1. Detect your Python interpreter and architecture.
2. Install PyInstaller (if missing).
3. Compile a single-file, no-console EXE.
4. Verify the PE architecture matches the host.
5. Print a SHA-256 checksum.

The finished EXE is placed at `sniper-src\SNIper_x64.exe`.

### Cross-Compilation via Wine (Linux/macOS)

You can build the Windows EXE from Linux or macOS using Wine:

```bash
# Install Wine and Python for Windows
# Then run the build script through Wine:
wine cmd /c sniper-src\packaging\build_exe.bat
```

> **Caveat:** Wine-based builds may encounter edge cases with PyInstaller's binary analysis. A native Windows build is always more reliable.

## Notes

- **Execution policy:** The script sets `RemoteSigned` for the current user scope only — no system-wide changes.
- **Scoop installation:** The script uses the official `irm get.scoop.sh | iex` installer. Review the script at [get.scoop.sh](https://get.scoop.sh) if you have security concerns.
- **SNIper tray icon:** Once running, SNIper lives in the system tray. Right-click the tray icon to show/hide the window, toggle the proxy, or exit.
- **Port:** The proxy listens on port `8881` by default. Change it in the SNIper UI if needed.
- **Rebuilding:** Delete `sniper-src\SNIper_x64.exe` to force a fresh build on the next run.
