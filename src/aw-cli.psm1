#Requires -Version 5.1
# aw-cli PowerShell module entry point.
# All layers are loaded via dot-sourcing for PS2EXE compatibility.

param()

# ── Module Root ─────────────────────────────────────────────────────────
if ($PSScriptRoot) { $script:ModuleRoot = $PSScriptRoot }
else { $script:ModuleRoot = $PWD.Path }

# ── Load order (no dependencies first) ─────────────────────────────────

# Layer 1: Utils + Types (no deps)
. (Join-Path $script:ModuleRoot 'Classes\Utils.ps1')
. (Join-Path $script:ModuleRoot 'Classes\SharedTypes.ps1')

# Layer 2: Core data models
. (Join-Path $script:ModuleRoot 'Classes\AnimeEpisode.ps1')
. (Join-Path $script:ModuleRoot 'Classes\Anime.ps1')

# Layer 3: HTTP / Network
. (Join-Path $script:ModuleRoot 'Private\WebSessionCore.ps1')

# Layer 4: Local data (config, history)
. (Join-Path $script:ModuleRoot 'Private\Config.ps1')
. (Join-Path $script:ModuleRoot 'Private\History.ps1')

# Layer 5: Player
. (Join-Path $script:ModuleRoot 'Private\Player.ps1')

# Layer 6: UI
. (Join-Path $script:ModuleRoot 'Private\ConsoleUI.ps1')

# Layer 7: Providers (base class first)
. (Join-Path $script:ModuleRoot 'Classes\Provider.ps1')
. (Join-Path $script:ModuleRoot 'Private\Providers\Animeworld.ps1')
. (Join-Path $script:ModuleRoot 'Private\Providers\Animeunity.ps1')
. (Join-Path $script:ModuleRoot 'Private\Providers\LocalProvider.ps1')

# Layer 8: AniList
. (Join-Path $script:ModuleRoot 'Private\Anilist.ps1')

# Layer 9: Interactive Session + Download
. (Join-Path $script:ModuleRoot 'Private\InteractiveSession.ps1')
. (Join-Path $script:ModuleRoot 'Private\DownloadManager.ps1')

# ── Module Version ──────────────────────────────────────────────────────
$script:ModuleVersion = '1.0.0'

# ── Initialize ────────────────────────────────────────────────────────────
try { Initialize-Config -ErrorAction SilentlyContinue } catch { }

# ── Public Functions (mirrors aw-cli.ps1's commands) ───────────────────

function Get-AnimeSearch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Query,

        [ValidateSet('animeworld', 'animeunity', 'local')]
        [string]$Provider = ''
    )
    if (-not $Provider) { $Provider = Get-ConfigValue -Key 'provider.source' -Default 'animeworld' }
    $prov = New-Provider -Name $Provider
    return $prov.Search($Query)
}

function Get-AnimeLatest {
    [CmdletBinding()]
    param(
        [ValidateSet('a', 's', 'd', 't')]
        [string]$Filter = 'a',
        [string]$Provider = ''
    )
    if (-not $Provider) { $Provider = Get-ConfigValue -Key 'provider.source' -Default 'animeworld' }
    $prov = New-Provider -Name $Provider
    return $prov.Latest($Filter)
}

function Get-AnimeEpisodes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$Anime,
        [string]$Provider = ''
    )
    process {
        if (-not $Anime.Ref) { return }
        if (-not $Provider) { $Provider = Get-ConfigValue -Key 'provider.source' -Default 'animeworld' }
        $prov = New-Provider -Name $Provider
        $prov.FetchEpisodes($Anime)
        $Anime
    }
}

function Get-AnimeEpisodeLink {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Anime,
        [Parameter(Mandatory)]
        [object]$Episode,
        [string]$Provider = ''
    )
    if (-not $Provider) { $Provider = Get-ConfigValue -Key 'provider.source' -Default 'animeworld' }
    $prov = New-Provider -Name $Provider
    return $prov.GetEpisodeLink($Anime, $Episode)
}

function Get-AnimeHistory {
    return @(Import-History)
}

function Save-AnimeDownloadEx {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Anime,
        [Parameter(Mandatory)]
        [object[]]$Episodes,
        [string]$OutputDir = ''
    )
    Save-AnimeDownload -Anime $Anime -Episodes $Episodes -OutputDir $OutputDir
}

function Set-AnimeConfig {
    [CmdletBinding()]
    param()
    # Kick off the install wizard
    $rootDir = Split-Path $script:ModuleRoot -Parent
    if (Test-Path (Join-Path $rootDir 'tools\install.ps1')) {
        . (Join-Path $rootDir 'tools\install.ps1') -SkipInstall
    }
}

# ── Export ──────────────────────────────────────────────────────────────
Export-ModuleMember -Function @(
    # Core search API
    'Get-AnimeSearch',
    'Get-AnimeLatest',
    'Get-AnimeEpisodes',
    'Get-AnimeEpisodeLink',
    'Get-AnimeHistory',
    'Save-AnimeDownloadEx',
    # Config
    'Get-ConfigValue',
    'Set-ConfigValue',
    'Import-Config',
    'Export-Config',
    'Initialize-Config',
    'Get-ConfigPath',
    # Player
    'Find-AvailablePlayers',
    'Get-DetectedPlayer',
    'Invoke-MediaPlayer',
    # UI
    'Show-Menu',
    'Show-YesNoPrompt',
    'Show-ListPrompt',
    # Console helpers
    'Write-OutputColor',
    'Clear-ConsoleScreen',
    # Provider factory
    'New-Provider',
    # AniList
    'Update-AniListEntry',
    'Get-AniListUserId',
    'Get-AnimeAniListRating',
    # Utils
    'Get-DownloadPath',
    'Set-AnimeConfig'
)