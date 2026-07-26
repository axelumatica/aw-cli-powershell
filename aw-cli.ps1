#Requires -Version 5.1
<#
.SYNOPSIS
    aw-cli - Watch anime from the terminal (PowerShell, Windows-native)
.DESCRIPTION
    Main CLI entry point. Load order mirrors the module.
    Supports: animeworld, animeunity, local | mpv, vlc, screenbox, photos

.PARAMETER Latest
    Show latest releases.
.PARAMETER LatestFilter
    Filter: a (all), s (sub), d (dub), t (trending).
.PARAMETER History
    Show watch history.
.PARAMETER RemoveHistory
    Remove from history.
.PARAMETER Info
    Show anime info before watching.
.PARAMETER Download
    Download episodes.
.PARAMETER Offline
    Browse downloaded anime.
.PARAMETER Config
    Run config wizard.
.PARAMETER Version
    Show version.
.PARAMETER Private
    Private mode (no history/AniList update).

.EXAMPLE
    aw-cli.ps1
    aw-cli.ps1 -Latest
    aw-cli.ps1 -LatestFilter d
    aw-cli.ps1 -History
    aw-cli.ps1 -Download -Info

.NOTES
    This is the standalone script (aw-cli.ps1). The module is aw-cli.psm1 for Import-Module use.
    Both use the same load order - the module is preferred for PS2EXE compilation.
#>
[CmdletBinding()]
param(
    [switch]$Latest,
    [ValidateSet('', 'a', 's', 'd', 't')]
    [string]$LatestFilter = 'a',
    [switch]$History,
    [switch]$RemoveHistory,
    [switch]$Info,
    [switch]$Download,
    [switch]$Offline,
    [switch]$Private,
    [switch]$Syncplay,
    [switch]$Config,
    [switch]$Version,
    [string]$Update
)

$ErrorActionPreference = 'Stop'
if (-not $PSScriptRoot) { $PSScriptRoot = Split-Path $PSCommandPath -Parent }
$script:RootPath = Split-Path $PSScriptRoot -Parent

# Error log helper (called from anywhere)
function Write-AwErrorLog {
    param($Message)
    $logDir = Join-Path $env:LOCALAPPDATA 'aw-cli'
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $logFile = Join-Path $logDir 'error.log'
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message`n"
    $entry | Out-File -FilePath $logFile -Append -Encoding UTF8
}

# Show error to user and die (for early crashes before main error handler)
function Show-AwFatalError {
    param($ErrorRecord)
    $msg = "aw-cli ha riscontrato un errore.`n`n$ErrorRecord`n`nLog: $env:LOCALAPPDATA\aw-cli\error.log"
    Write-AwErrorLog $ErrorRecord
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show($msg, "Errore aw-cli", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    } catch {
        Write-Host $msg -ForegroundColor Red
    }
    exit 1
}

# Global handler for uncaught errors
$global:EventHandler = {
    param($sender, $event)
    Show-AwFatalError $event.Exception.Message
}
$host.UI.PromptForChoice = $host.UI.PromptForChoice  # ensure UI available

function Import-Aw($rel) {
    $p = Join-Path $script:RootPath $rel
    if (-not (Test-Path $p)) {
        Show-AwFatalError "File non trovato: $p`nVerifica l'installazione di aw-cli."
    }
    try {
        . $p
    } catch {
        Show-AwFatalError "Errore nel caricamento $p : $_"
    }
}

# Load all layers
Import-Aw 'src\Classes\SharedTypes.ps1'
Import-Aw 'src\Classes\Utils.ps1'
Import-Aw 'src\Classes\AnimeEpisode.ps1'
Import-Aw 'src\Classes\Anime.ps1'
Import-Aw 'src\Private\WebSessionCore.ps1'
Import-Aw 'src\Private\Config.ps1'
Import-Aw 'src\Private\History.ps1'
Import-Aw 'src\Private\Player.ps1'
Import-Aw 'src\Private\ConsoleUI.ps1'
Import-Aw 'src\Classes\Provider.ps1'
Import-Aw 'src\Private\Providers\Animeworld.ps1'
Import-Aw 'src\Private\Providers\Animeunity.ps1'
Import-Aw 'src\Private\Providers\LocalProvider.ps1'
Import-Aw 'src\Private\Anilist.ps1'
Import-Aw 'src\Private\DownloadManager.ps1'
Import-Aw 'src\Private\InteractiveSession.ps1'

# Self-update
if ($Update -ne '') {
    Write-OutputColor "Aggiorno aw-cli..." -Style info
    & (Get-Command git).Source pull 2>$null
    Write-OutputColor "Aggiornamento completato!" -Style success
    return
}

# Version
if ($Version) {
    Write-Host "aw-cli v$script:ModuleVersion"
    return
}

# Setup wizard
$configPath = Get-ConfigPath
if ($Config -or -not (Test-Path $configPath)) {
    . (Join-Path $script:RootPath 'tools\install.ps1') -SkipInstall
    if (-not $Config) { Import-Config }
}

# Load history
$watchHistory = @(Import-History)

# Provider setup
$providerName = if ($Offline) { 'local' } else { Get-ConfigValue -Key 'provider.source' -Default 'animeworld' }
$provider = New-Provider -Name $providerName
if ($providerName -eq 'local' -and $watchHistory.Count -gt 0 -and $provider.PSObject.TypeNames -contains 'LocalProvider') {
    $provider.SetHistory($watchHistory)
}

# ── Main ─────────────────────────────────────────────────────────────────
try {
if ($History -and $RemoveHistory) {
    _HandleHistoryRemoval $watchHistory
    return
}

# Build anime list
$animeList = @()
if ($Offline) {
    $animeList = $provider.Search("")
    if ($animeList.Count -eq 0) { Write-OutputColor "Nessun anime scaricato." -Style error; return }
} elseif ($History) {
    $animeList = @($watchHistory)
} elseif ($Latest) {
    $animeList = $provider.Latest($LatestFilter)
} else {
    $animeList = _InteractiveSearch $provider
}

if ($animeList.Count -eq 0) {
    $msg = if ($History) { "Cronologia vuota!" } else { "Nessun anime trovato!" }
    Write-OutputColor $msg -Style error; return
}

# Interactive session
_WriteHeader
_InteractiveSession -Provider $provider -AnimeList $animeList -WatchHistory $watchHistory -HistoryMode:$History -InfoMode:$Info -DownloadMode:$Download -OfflineMode:$Offline -PrivateMode:$Private

Write-Host ""
Write-Host "Arrivederci!" -ForegroundColor Cyan
} catch {
    throw $_
}

# ── Global error handler (for PS2EXE compiled EXE) ───────────────────────
$ErrorActionPreference = 'Continue'
trap {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $stack = if ($_.ScriptStackTrace) { "`nStack: $($_.ScriptStackTrace)" } else { "" }
    Write-AwErrorLog "FATAL: $($_) | Line: $($_.InvocationInfo?.ScriptLineNumber) | File: $($_.InvocationInfo?.ScriptName)$stack"
    Show-AwFatalError $_
}