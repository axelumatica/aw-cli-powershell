#Requires -Version 5.1
# install.ps1 - Bootstrap installer and first-run configuration wizard.
# Can be run standalone (no parameters) or imported with -SkipInstall.

[CmdletBinding()]
param(
    [switch]$SkipInstall,
    [switch]$Quiet
)

$ErrorActionPreference = 'Continue'
if (-not $PSScriptRoot) { $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }
$rootDir = Split-Path $PSScriptRoot -Parent

function Import-AwLayer {
    param([string]$RelativePath)
    $full = Join-Path $rootDir $RelativePath
    if (Test-Path $full) {
        try { . $full } catch { Write-Warning "Skipped: $RelativePath ($_)" }
    }
}

# ── Load layers in dependency order ─────────────────────────────────────
Import-AwLayer 'src\Classes\SharedTypes.ps1'
Import-AwLayer 'src\Classes\Utils.ps1'
Import-AwLayer 'src\Private\Config.ps1'
Import-AwLayer 'src\Private\Player.ps1'
Import-AwLayer 'src\Private\ConsoleUI.ps1'
Import-AwLayer 'src\Classes\Provider.ps1'
Import-AwLayer 'src\Private\Providers\Animeworld.ps1'
Import-AwLayer 'src\Private\Providers\Animeunity.ps1'

function Write-Step {
    param([string]$Message, [string]$Style = 'info')
    if (-not $Quiet) {
        switch ($Style) {
            'info'    { Write-Host "  $Message" -ForegroundColor Cyan }
            'ok'      { Write-Host "  [OK] $Message" -ForegroundColor Green }
            'warn'    { Write-Host "  [!] $Message" -ForegroundColor Yellow }
            'error'   { Write-Host "  [X] $Message" -ForegroundColor Red }
            'header'  { Write-Host ""; Write-Host "  $Message" -ForegroundColor Magenta; Write-Host "" }
        }
    }
}

function Install-AwCliConfig {
    Write-Host ""
    Write-Host "  AW-CLI CONFIGURAZIONE" -ForegroundColor Magenta
    Write-Host "  ======================" -ForegroundColor Magenta
    Write-Host ""

    # ── Player selection ──────────────────────────────────────────────────
    Write-Host "  Player video:" -ForegroundColor Gray
    Write-Host "    1) mpv (consigliato)" -ForegroundColor Cyan
    Write-Host "    2) vlc" -ForegroundColor Cyan
    Write-Host "    3) Screenbox (UWP)" -ForegroundColor Cyan
    Write-Host "    4) Foto / Photos (UWP)" -ForegroundColor Cyan
    $playerChoice = Read-Host "  Scelta [1]"

    $playerType = switch ($playerChoice) {
        "2" { "vlc" }
        "3" { "screenbox" }
        "4" { "photos" }
        default { "mpv" }
    }

    # Detect or use installed player
    $avail = Find-AvailablePlayers
    $detectedPath = ""
    if ($avail -and $avail.ContainsKey($playerType)) {
        $detectedPath = $avail[$playerType].Path
    }
    $playerPath = if (-not $detectedPath) {
        switch ($playerType) {
            'mpv' { "mpv" }
            'vlc' { "vlc" }
            'screenbox' { "Microsoft.Screenbox" }
            'photos' { "Microsoft.Windows.Photos" }
        }
    } else { $detectedPath }

    Set-ConfigValue -Key 'player.type' -Value $playerType
    Set-ConfigValue -Key 'player.path'  -Value $playerPath
    Write-Step "$playerType -> $playerPath" "ok"

    # ── Provider selection ───────────────────────────────────────────────
    Write-Host ""
    Write-Host "  Provider:" -ForegroundColor Gray
    Write-Host "    1) animeworld (consigliato)" -ForegroundColor Cyan
    Write-Host "    2) animeunity" -ForegroundColor Cyan
    $provChoice = Read-Host "  Scelta [1]"

    $providerName = if ($provChoice -eq "2") { "animeunity" } else { "animeworld" }
    Set-ConfigValue -Key 'provider.source' -Value $providerName
    Write-Step $providerName "ok"

    # ── Specials toggle ─────────────────────────────────────────────────
    Write-Host ""
    $specialsAns = Read-Host "  Mostrare episodi speciali? (s/n) [n]"
    Set-ConfigValue -Key 'general.specials' -Value ($specialsAns.ToLower() -eq 's')
    Write-Step "Speciali: $(($specialsAns.ToLower() -eq 's'))" "ok"

    # ── Parallel downloads ───────────────────────────────────────────────
    Write-Host ""
    $parallel = Read-Host "  Download paralleli [3]"
    if ($parallel -match '^\d+$' -and [int]$parallel -gt 0) {
        Set-ConfigValue -Key 'general.parallel-downloads' -Value ([int]$parallel)
    } else {
        Set-ConfigValue -Key 'general.parallel-downloads' -Value 3
    }

    # ── AniList sync (optional) ──────────────────────────────────────────
    Write-Host ""
    $alAns = Read-Host "  Aggiornare AniList automaticamente? (s/n) [n]"
    if ($alAns.ToLower() -eq 's') {
        Write-Host ""
        $token = Read-Host "  Token AniList (ottienilo da https://anilist.co/api/v2/oauth/authorize?client_id=11388)"
        if ($token -and $token.Trim()) {
            Set-ConfigValue -Key 'anilist.token'       -Value $token.Trim()
            Set-ConfigValue -Key 'anilist.rating'      -Value $false
            Set-ConfigValue -Key 'anilist.favorite'     -Value $false
            Set-ConfigValue -Key 'anilist.drop'         -Value $false
            Write-Step "AniList token salvato" "ok"
        }
    }

    # ── Save ────────────────────────────────────────────────────────────
    Export-Config
    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Green
    Write-Host "   Configurazione completata!" -ForegroundColor Green
    Write-Host "   Esegui '.\aw-cli.ps1' per iniziare." -ForegroundColor Cyan
    Write-Host ""
}

# ── Run config wizard ───────────────────────────────────────────────────
if (-not $SkipInstall) {
    Clear-Host
    Install-AwCliConfig
}