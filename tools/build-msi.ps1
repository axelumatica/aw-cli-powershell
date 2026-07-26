#Requires -Version 5.1
# build-msi.ps1 - Build MSI installer for aw-cli using WiX v5
# Run: .\tools\build-msi.ps1 -Version "1.0.0"

param(
    [string]$Version = "",
    [string]$ExePath = "",
    [string]$ModuleZipPath = "",
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'
$rootDir = Split-Path $PSScriptRoot -Parent
$distDir = Join-Path $rootDir "dist"

# ── Default paths ─────────────────────────────────────────────────────────
if (-not $ExePath) {
    $ExePath = Join-Path $distDir "aw-cli.exe"
}
if (-not $ModuleZipPath) {
    $ModuleZipPath = Join-Path $distDir "aw-cli-module.zip"
}
if (-not $Version) {
    # Extract from manifest
    $manifest = Import-PowerShellDataFile -Path (Join-Path $rootDir "src\aw-cli.psd1") -ErrorAction SilentlyContinue
    $Version = $manifest.ModuleVersion
}
if (-not $Version) {
    $Version = "1.0.0"
}

# ── Verify inputs exist ───────────────────────────────────────────────────
if (-not (Test-Path $ExePath)) {
    Write-Error "EXE not found: $ExePath`nRun build.ps1 first to create dist/aw-cli.exe"
}
if (-not (Test-Path $ModuleZipPath)) {
    Write-Error "Module zip not found: $ModuleZipPath`nRun build.ps1 first to create dist/aw-cli-module.zip"
}

# ── Ensure WiX is available ──────────────────────────────────────────────
$wixCmd = $null
$wixPaths = @(
    "$env:LOCALAPPDATA\.dotnet\tools\wix.exe",
    "$env:APPDATA\.dotnet\tools\wix.exe",
    "C:\ProgramData\chocolatey\bin\wix.exe"
)

foreach ($path in $wixPaths) {
    if (Test-Path $path) {
        $wixCmd = $path
        break
    }
}

# Check if wix is in PATH
$wixInPath = Get-Command wix -ErrorAction SilentlyContinue
if ($wixInPath) {
    $wixCmd = $wixInPath.Source
}

if (-not $wixCmd) {
    Write-Host "WiX not found. Installing via dotnet tool..." -ForegroundColor Yellow
    dotnet tool install --global wix --version 5.0.0 2>$null

    # Refresh PATH and find wix
    $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + $env:PATH
    $wixInPath = Get-Command wix -ErrorAction SilentlyContinue
    if ($wixInPath) {
        $wixCmd = $wixInPath.Source
    }

    if (-not $wixCmd) {
        # Try default dotnet tools location
        $defaultPath = "$env:LOCALAPPDATA\.dotnet\tools\wix.exe"
        if (Test-Path $defaultPath) {
            $wixCmd = $defaultPath
        }
    }

    if (-not $wixCmd) {
        Write-Error "Failed to install or locate WiX. Please install manually: dotnet tool install --global wix"
    }
}

Write-Host "WiX found: $wixCmd" -ForegroundColor DarkGray
$wixDir = Split-Path $wixCmd -Parent
$env:PATH = "$wixDir;$env:PATH"

# ── Build MSI ─────────────────────────────────────────────────────────────
$msiPath = Join-Path $distDir "aw-cli.msi"
$wxsPath = Join-Path $PSScriptRoot "aw-cli.wxs"

Write-Host "Building MSI: $msiPath" -ForegroundColor Cyan
Write-Host "  Version: $Version" -ForegroundColor DarkGray
Write-Host "  EXE: $ExePath" -ForegroundColor DarkGray
Write-Host "  Module: $ModuleZipPath" -ForegroundColor DarkGray

$absExe = (Resolve-Path $ExePath -ErrorAction Stop).Path
$absModule = (Resolve-Path $ModuleZipPath -ErrorAction Stop).Path
$absMsi = (Resolve-Path $distDir -ErrorAction Stop).Path

# Convert to absolute paths for WiX
$oldCwd = Get-Location
Set-Location $rootDir

try {
    & wix build $wxsPath `
        -d Version="$Version" `
        -d ExePath="$absExe" `
        -d ModuleZipPath="$absModule" `
        -o "$msiPath" `
        2>&1 | ForEach-Object { Write-Host $_ }

    if (-not (Test-Path $msiPath)) {
        Write-Error "MSI build failed - file not created"
    }

    $sizeMB = [math]::Round((Get-Item $msiPath).Length / 1MB, 2)
    Write-Host "MSI built: $msiPath ($sizeMB MB)" -ForegroundColor Green
} finally {
    Set-Location $oldCwd
}