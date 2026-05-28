# CLAUDE.md — WrapTune project context

> Your global `~/.claude/CLAUDE.md` rules apply (think first, check in before
> major changes, keep it simple, etc.). This file is project-specific context
> on top of those.

## What WrapTune is

WPF / .NET 8 desktop app for Windows. A friendly GUI around Microsoft's
`IntuneWinAppUtil.exe` (Win32 Content Prep Tool) — wraps installers into
`.intunewin` packages for Microsoft Intune deployment.

Repo: https://github.com/thefinder808/WrapTune (public, MIT)

## Quick orientation

```
WrapTune/
├── App.xaml / App.xaml.cs        WPF entry. App.xaml preloads Daylight theme
├── MainWindow.xaml / .cs         Main window + wrap logic + theme handling
├── AppSettings.cs                JSON-backed settings (LOCALAPPDATA — see below)
├── Themes/
│   ├── Daylight.xaml             Light palette ResourceDictionary
│   └── Midnight.xaml             Dark palette ResourceDictionary
├── WrapTune.csproj               .NET 8 WPF project (single-file self-contained)
├── WrapTune.ico                  Committed but generated — see Icon section
├── Build-Installer.ps1           dotnet publish → WiX → WrapTune.msi
├── Generate-Icon.ps1             "Bicolor Stack" icon — System.Drawing/GDI+
├── Installer/
│   ├── Installer.wixproj         WiX MSI project (NuGet pulls WiX SDK)
│   ├── Package.wxs               MSI package definition. Manufacturer="thefinder808"
│   ├── OptionsDlg.wxs            Custom installer dialog (desktop-shortcut toggle)
│   └── Bundled/                  IntuneWinAppUtil.exe goes here (gitignored)
└── .github/workflows/release.yml CI: build → sign → publish on v* tag push
```

## Local development (Windows)

```powershell
# One-time: drop IntuneWinAppUtil.exe into Installer/Bundled/
# (download from https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool)

# Run for dev:
dotnet run --project WrapTune.csproj

# Full build + MSI:
pwsh ./Build-Installer.ps1
```

The CI workflow handles releases — you do not build MSIs locally to release.

## Release flow

```powershell
git tag v1.2.3
git push origin v1.2.3
```

That's it. CI:

1. Regenerates `WrapTune.ico` via `Generate-Icon.ps1`
2. `dotnet publish` → self-contained single-file `WrapTune.exe`
3. Builds MSI via WiX
4. Signs MSI with Azure Artifact Signing (OIDC, no client secret)
5. Creates GitHub Release with `WrapTune.msi` attached

Takes ~3 minutes. Watch via `gh run watch <id>` or the Actions tab.

**Versioning**: SemVer. Bug fixes = patch (v1.1.1), new features = minor
(v1.2.0), breaking changes = major (v2.0.0). The Package.wxs `Version="..."`
attribute is not currently synced with the tag — would need a workflow step
to template it if you care.

## Settings file location (important — easy to get wrong)

`%LOCALAPPDATA%\WrapTune\settings.json`

NOT next to the .exe. The app was migrated to this path in v1.0.2 so it can
run as a normal (non-admin) user even when installed per-machine in
Program Files. See `AppSettings.GetSettingsPath()`.

Schema:

```json
{
  "ExePath":      "C:\\...\\IntuneWinAppUtil.exe",
  "SourceFolder": "C:\\...",
  "OutputFolder": "C:\\...",
  "Theme":        "Daylight",
  "Overwrite":    true
}
```

`Save()` is wrapped in try/catch — silently swallows IO errors so the app
never crashes on exit. `Load()` is also robust (returns fresh defaults on
any parse/IO failure).

## Theme system (added in v1.1.0)

Two `ResourceDictionary`s in `Themes/`. Every control in `MainWindow.xaml`
binds via `{DynamicResource …}` to tokens like `Accent`, `Fg`, `WindowBg`,
`Success`, `Error`.

Switching happens in `MainWindow.xaml.cs:ApplyTheme(name)` — clears
`Application.Current.Resources.MergedDictionaries` and adds the new one.
All `DynamicResource` bindings refresh instantly.

Title bar chrome (light/dark) is keyed off the `DarkTitleBar` int resource
in each theme dictionary, read by `ApplyDarkTitleBar()` via DWM.

`App.xaml` preloads Daylight so there's no unstyled flash before the
constructor's `ApplyTheme(_theme)` call.

To add a new theme: copy `Daylight.xaml`, change the colors, save as
`Themes/Verdant.xaml` (or whatever), update `ApplyTheme()` to accept it,
update `BtnTheme_Click` to cycle through.

## Icon

The committed `WrapTune.ico` is the source of truth for **local Windows
builds** (`.csproj` references it as `ApplicationIcon` at compile time).

CI regenerates it from `Generate-Icon.ps1` on every release build, so the
shipped MSI always reflects the latest script. **The committed `.ico` can
drift from the script** if someone edits the script on macOS (where
System.Drawing/GDI+ is broken).

If you edit `Generate-Icon.ps1` on Windows, also run it and commit the
fresh `.ico`:

```powershell
pwsh ./Generate-Icon.ps1
git add WrapTune.ico
git commit -m "Refresh icon"
```

## Code signing — Azure Artifact Signing

Releases are signed via Microsoft's [Azure Artifact Signing](https://azure.microsoft.com/en-us/products/artifact-signing)
(~$10/mo). Setup is one-time and not in the repo — it's Azure-side. Key
facts for future-you / Claude:

| Resource | Value |
|---|---|
| Region | East US (`https://eus.codesigning.azure.net/`) |
| Account name | `thefinder808-signing` |
| Cert profile name | `public-signing` |
| App Registration | `github-actions-codesign` (Entra ID) |
| Federated credential subject | `repo:thefinder808/WrapTune:environment:release` |
| Role | `Artifact Signing Certificate Profile Signer` |
| GitHub Environment | `release` |
| GitHub Secrets (env-scoped) | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |

See the Obsidian "Azure Signing Setup" note for the full provisioning
walkthrough if any of this ever needs to be reconstituted.

## Setup file extensions (single source of truth)

`MainWindow.xaml.cs` line ~19:

```csharp
private static readonly string[] _installerExtensions =
    [".exe", ".msi", ".ps1", ".cmd", ".bat"];
```

Used by both the `OpenFileDialog` filter and the auto-detect that fires
when a source folder is picked. To add a new accepted extension (e.g.
`.msix`), edit this one array.

## Project-specific things to keep in mind

1. **`Installer/Bundled/IntuneWinAppUtil.exe` is gitignored.** You must
   drop it in manually for local Windows builds. CI clones Microsoft's
   repo at build time to fetch it.
2. **Settings location moved in v1.0.2** — if anyone reports stale
   ExePath / SourceFolder, ask whether they upgraded from v1.0.1 or
   earlier. Their old settings are orphaned in Program Files.
3. **MainWindow.xaml.cs uses `System.Windows.Media`** but no longer needs
   it after the v1.1.0 redesign swapped hardcoded brushes for resource
   references. Cleanup follow-up; not urgent.
4. **`Package.wxs` GUIDs are stable.** Don't change them — Windows uses
   them to recognize upgrades. Changing them breaks the upgrade path for
   existing installs.

## Where follow-ups live

- **In-repo**: `Todo.md` — short list of small known issues.
- **Obsidian vault**: `~/Documents/Obsidian/Development/Projects/WrapTune/`
  - `WrapTune.md` — project index (Dataview-driven)
  - `CI Maintenance Follow-Ups.md` — Node 20 deprecation, windows-latest redirect
  - `Azure Signing Setup.md` — Azure resource provisioning reference

## Currently open Todo.md items

- [ ] Wrap `Directory.CreateDirectory` in try/catch for invalid output paths
      (`MainWindow.xaml.cs:264`)
- [ ] Add tooltip to Catalog Folder field explaining what `-a` does
      (Windows 10 S mode catalog signing — niche)
