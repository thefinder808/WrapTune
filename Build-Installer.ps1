<#
.SYNOPSIS
    Builds the WrapTune app and MSI installer.
.DESCRIPTION
    1. Publishes the C# WPF app as a self-contained single-file exe
    2. Builds the WiX MSI installer (requires IntuneWinAppUtil.exe in Installer\Bundled\)
    3. Copies the final MSI to the project root
.NOTES
    Prerequisites:
      - .NET 8+ SDK
      - IntuneWinAppUtil.exe placed in Installer\Bundled\
    The WiX Toolset SDK is pulled automatically via NuGet (no separate install needed).
#>

param(
    [string]$Configuration = 'Release',
    # Four-part MSI version (Major.Minor.Build.Revision). Defaults to 0.0.0.0
    # for local builds so they're unambiguously NOT a release. CI passes the
    # real value derived from the git tag (e.g. v1.1.2 -> 1.1.2.0).
    [string]$Version = '0.0.0.0'
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = $PSScriptRoot

Write-Host "=== Step 1: Publish WrapTune (v$Version) ===" -ForegroundColor Cyan
dotnet publish "$ProjectRoot\WrapTune.csproj" -c $Configuration -p:Version=$Version
if ($LASTEXITCODE -ne 0) { throw 'App publish failed.' }

# Verify the published exe exists
$publishedExe = Join-Path $ProjectRoot "bin\$Configuration\net8.0-windows\win-x64\publish\WrapTune.exe"
if (-not (Test-Path $publishedExe)) { throw "Published exe not found at: $publishedExe" }
Write-Host "  Published exe: $publishedExe" -ForegroundColor Green

# Verify IntuneWinAppUtil.exe is in Bundled
$bundledExe = Join-Path $ProjectRoot 'Installer\Bundled\IntuneWinAppUtil.exe'
if (-not (Test-Path $bundledExe)) {
    throw "IntuneWinAppUtil.exe not found at: $bundledExe`nDownload from https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool and place it in Installer\Bundled\"
}

Write-Host ''
Write-Host '=== Step 2: Build MSI Installer ===' -ForegroundColor Cyan
dotnet build "$ProjectRoot\Installer\Installer.wixproj" -c $Configuration -p:Version=$Version
if ($LASTEXITCODE -ne 0) { throw 'MSI build failed.' }

# Find the output MSI
$msiPath = Get-ChildItem "$ProjectRoot\Installer\bin\$Configuration" -Filter '*.msi' -Recurse | Select-Object -First 1
if (-not $msiPath) { throw 'MSI not found in installer output.' }

# Copy to project root for convenience
$destMsi = Join-Path $ProjectRoot "WrapTune.msi"
Copy-Item $msiPath.FullName $destMsi -Force

Write-Host ''
Write-Host '=== Build Complete ===' -ForegroundColor Green
Write-Host "  MSI: $destMsi" -ForegroundColor Green
Write-Host "  Size: $([math]::Round((Get-Item $destMsi).Length / 1MB, 1)) MB" -ForegroundColor Green
