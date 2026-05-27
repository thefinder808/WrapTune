# WrapTune

A friendly GUI for Microsoft's `IntuneWinAppUtil.exe` — the Win32 Content Prep Tool used to package Windows apps for deployment via Microsoft Intune.

`IntuneWinAppUtil.exe` is a CLI tool. WrapTune wraps it in a small WPF window so picking the source folder, setup file, and output folder is a few clicks instead of remembering flag order.

![WrapTune](WrapTune_preview.png)

## Features

- Auto-detects `IntuneWinAppUtil.exe` (app directory → `PATH` → saved setting)
- Remembers last-used source / output folders between runs
- Native dark title bar on Windows 10/11
- Self-contained single-file `.exe` — no .NET runtime required on target machines
- MSI installer with optional desktop shortcut

## Requirements

- Windows 10 / 11 (x64)
- `IntuneWinAppUtil.exe` from Microsoft's [Microsoft-Win32-Content-Prep-Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool) repo
- For building from source: [.NET 8 SDK](https://dotnet.microsoft.com/download)

## Install

**Option A — Pre-built MSI** (from GitHub Releases, once published).

**Option B — Build from source** (see below).

## Build from source

1. Clone the repo.
2. Download `IntuneWinAppUtil.exe` from [microsoft/Microsoft-Win32-Content-Prep-Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool) and drop it into `Installer/Bundled/`.
3. Run the build script in PowerShell:
   ```powershell
   pwsh ./Build-Installer.ps1
   ```
   This will:
   - Publish `WrapTune.exe` as a self-contained single-file binary (`bin/Release/net8.0-windows/win-x64/publish/`)
   - Build the MSI via WiX (NuGet pulls the WiX SDK automatically)
   - Copy the resulting `WrapTune.msi` to the project root

## Usage

1. **IntuneWinAppUtil.exe** — point to your local copy (auto-detected if it's beside `WrapTune.exe` or on `PATH`).
2. **Source folder** — folder containing your installer + supporting files.
3. **Setup file** — the `.exe` or `.msi` inside the source folder that kicks off your install.
4. **Output folder** — where the resulting `.intunewin` will be written.
5. Click **Wrap**.

Settings persist between runs in `WrapTune.settings.json` next to the executable.

## Project layout

```
.
├── App.xaml / App.xaml.cs        WPF app entry
├── MainWindow.xaml / .cs         Main window + wrap logic
├── AppSettings.cs                JSON-backed settings
├── WrapTune.csproj               .NET 8 WPF project
├── Build-Installer.ps1           Publish + MSI build script
├── Generate-Icon.ps1             Icon generator
└── Installer/
    ├── Installer.wixproj         WiX MSI project
    ├── Package.wxs               MSI package definition
    ├── OptionsDlg.wxs            Custom installer dialog
    └── Bundled/                  IntuneWinAppUtil.exe goes here (gitignored)
```

## License

MIT — see [LICENSE](LICENSE).
