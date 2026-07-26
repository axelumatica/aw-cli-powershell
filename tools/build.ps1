#Requires -Version 5.1
# build.ps1 - PS2EXE compilation script for generating aw-cli.exe
# Run with: powershell -ExecutionPolicy Bypass -File tools\build.ps1

param(
    [string]$Configuration = "Release",
    [string]$IconFile = "",
    [string]$Version = "",
    [switch]$Verbose,
    [switch]$NoPackage
)

# IMPORTANT: Do NOT use -NoConsole flag - aw-cli must be a Console Application.
# PS2EXE with Windows PowerShell (5.1) is required for compatibility.

$ErrorActionPreference = 'Stop'
$rootDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MyInvocation.MyCommand.Path -Parent }
# When called as .\tools\build.ps1, PS_scriptRoot = tools\. Resolve to repo root:
$rootDir = Split-Path $rootDir -Parent
if (-not $rootDir) { $rootDir = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath('.\') }
$srcDir = Join-Path $rootDir "src"
$distDir = Join-Path $rootDir "dist"

Write-Host "aw-cli PS2EXE Build" -ForegroundColor Cyan
Write-Host "Root: $rootDir" -ForegroundColor DarkGray
Write-Host ""

# ── Ensure PS2EXE is available ───────────────────────────────────────────
$ps2exeAvailable = $false
try {
    $ps2exeCheck = Get-Module -ListAvailable PS2EXE -ErrorAction SilentlyContinue
    if ($ps2exeCheck) {
        Import-Module PS2EXE -ErrorAction Stop
        $ps2exeAvailable = $true
    }
} catch { }

if (-not $ps2exeAvailable) {
    Write-Host "PS2EXE not installed. Installing..." -ForegroundColor Yellow
    try {
        # Windows PowerShell 5.1: install to CurrentUser to avoid Admin requirement
        Install-Module -Name PS2EXE -Force -Scope CurrentUser -ErrorAction Stop
        Import-Module PS2EXE -ErrorAction Stop
        $ps2exeAvailable = $true
    } catch {
        Write-Host ""
        Write-Host "FATAL: Could not install PS2EXE." -ForegroundColor Red
        Write-Host "Try running PowerShell as Administrator, or install manually:" -ForegroundColor Yellow
        Write-Host "  Install-Module PS2EXE -Force" -ForegroundColor Yellow
        Write-Host "  OR download from: https://github.com/MScholtes/PS2EXE-GUI/releases" -ForegroundColor Yellow
        return
    }
}

Write-Host "PS2EXE loaded: $($((Get-Module PS2EXE | Select-Object -First 1).Version))" -ForegroundColor DarkGray

# ── Create dist directory ────────────────────────────────────────────────
if (-not (Test-Path $distDir)) {
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null
}

# ── Resolve input file ──────────────────────────────────────────────────
$inputFile = Join-Path $rootDir "aw-cli.ps1"
if (-not (Test-Path $inputFile)) {
    Write-Host "FATAL: aw-cli.ps1 not found at root: $inputFile" -ForegroundColor Red
    return
}

# ── Default version to module version ──────────────────────────────────
if (-not $Version) {
    $v = '1.0.0'
    $manifestPath = Join-Path $srcDir "aw-cli.psd1"
    if (Test-Path $manifestPath) {
        try {
            $manifest = Import-PowerShellDataFile -Path $manifestPath -ErrorAction SilentlyContinue
            if ($manifest -and $manifest.ModuleVersion) { $v = $manifest.ModuleVersion }
        } catch { }
    }
    $Version = $v
}

# ── Build EXE ───────────────────────────────────────────────────────────
$exePath = Join-Path $distDir "aw-cli.exe"
Write-Host "Compiling: aw-cli.ps1 -> aw-cli.exe" -ForegroundColor Yellow

$ps2exeParams = @{
    InputFile   = $inputFile
    OutputFile  = $exePath
    Verbose     = $Verbose.IsPresent
}

if ($IconFile -and (Test-Path $IconFile)) {
    $ps2exeParams['IconFile'] = $IconFile
}
if ($Version) {
    $ps2exeParams['Version'] = $Version
}

try {
    Invoke-PS2EXE @ps2exeParams
} catch {
    Write-Host "FATAL: PS2EXE compilation failed." -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Ensure you are running 'powershell' (v5.1), NOT 'pwsh' (v7+)." -ForegroundColor Yellow
    Write-Host "Correct command: powershell -ExecutionPolicy Bypass -File tools\build.ps1" -ForegroundColor Yellow
    return
}

# ── Verify output ───────────────────────────────────────────────────────
if (Test-Path $exePath) {
    $sizeMB = [math]::Round((Get-Item $exePath).Length / 1MB, 2)
    Write-Host "EXE built: $exePath ($sizeMB MB)" -ForegroundColor Green
} else {
    Write-Host "FATAL: EXE was not created." -ForegroundColor Red
    return
}

# ── Package module as ZIP ───────────────────────────────────────────────
if (-not $NoPackage) {
    $zipPath = Join-Path $distDir "aw-cli-module.zip"

    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

    try {
        # Include src/, tools/ (but exclude dist/)
        $publishPaths = @('src', 'tools', 'README.md')
        Compress-Archive -Path ($publishPaths | ForEach-Object { Join-Path $rootDir $_ }) `
                         -DestinationPath $zipPath -Force
        $sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
        Write-Host "Module zipped: $zipPath ($sizeMB MB)" -ForegroundColor Green
    } catch {
        Write-Warning "Module zip failed: $_"
    }
}

Write-Host ""
Write-Host "Build complete!" -ForegroundColor Green
Write-Host "Artifacts in: $distDir" -ForegroundColor DarkGray