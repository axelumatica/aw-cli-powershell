#Requires -Version 5.1
# aw-cli PowerShell module entry point
# All classes and functions are defined in this single file for PS2EXE compatibility.
# This mimics the Python's __init__.py-style module.

param()

# ── Helper: Build path relative to script location ─────────────────────────
function Get-ScriptPath { if ($PSScriptRoot) { return $PSScriptRoot }; return Split-Path $PSCommandPath -Parent }

$script:RootPath = Get-ScriptPath
function Import-AwModule($relativePath) {
    $full = Join-Path $script:RootPath $relativePath
    if (Test-Path $full) { . $full }
}

# ── Layer 1: Enums and utility functions ─────────────────────────────────
Import-AwModule 'src\Classes\SharedTypes.ps1'
Import-AwModule 'src\Classes\Utils.ps1'

# ── Layer 2: Core data models ──────────────────────────────────────────────
Import-AwModule 'src\Classes\AnimeEpisode.ps1'
Import-AwModule 'src\Classes\Anime.ps1'

# ── Layer 3: HTTP / Network ───────────────────────────────────────────────
Import-AwModule 'src\Private\WebSessionCore.ps1'

# ── Layer 4: Local data (config, history) ───────────────────────────────────
Import-AwModule 'src\Private\Config.ps1'
Import-AwModule 'src\Private\History.ps1'

# ── Layer 5: Player ────────────────────────────────────────────────────────
Import-AwModule 'src\Private\Player.ps1'

# ── Layer 6: UI ─────────────────────────────────────────────────────────────
Import-AwModule 'src\Private\ConsoleUI.ps1'

# ── Layer 7: Providers (must load base Provider class first) ─────────────────
Import-AwModule 'src\Classes\Provider.ps1'    # Defines Provider base class + New-Provider
Import-AwModule 'src\Private\Providers\Animeworld.ps1'
Import-AwModule 'src\Private\Providers\Animeunity.ps1'
Import-AwModule 'src\Private\Providers\LocalProvider.ps1'

# ── Layer 8: AniList ───────────────────────────────────────────────────────
Import-AwModule 'src\Private\Anilist.ps1'

# ── Initialize ──────────────────────────────────────────────────────────────
Initialize-Config -ErrorAction SilentlyContinue

$script:ModuleVersion = '1.0.0'

Export-ModuleMember -Function @(
    # Providers
    'New-Provider',
    # Config
    'Get-ConfigValue', 'Set-ConfigValue', 'Import-Config', 'Export-Config', 'Initialize-Config', 'Get-ConfigPath',
    # History
    'Import-History', 'Export-History', 'Update-AnimeHistory', 'Remove-FromHistory',
    # Player
    'Find-AvailablePlayers', 'Get-DetectedPlayer', 'Invoke-MediaPlayer',
    # UI
    'Show-Menu', 'Show-YesNoPrompt', 'Show-ListPrompt',
    # Console
    'Write-OutputColor', 'Clear-Screen',
    # Utils
    'Get-DownloadPath',
    # Download
    'Save-AnimeDownload',
    # AniList
    'Update-AniListEntry', 'Get-AniListUserId', 'Get-AnimeAniListRating'
)

# ── Run CLI if called as script ───────────────────────────────────────────
# aw-cli.ps1 is the standalone CLI; this module is for Import-Module use