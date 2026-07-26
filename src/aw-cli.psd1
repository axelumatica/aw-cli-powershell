@{
    RootModule = 'aw-cli.psm1'
    ModuleVersion = '1.0.0'
    CompatiblePSEditions = @('Desktop')
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'aw-cli Contributors'
    CompanyName = ''
    Copyright = '(c) aw-cli Contributors. All rights reserved.'
    Description = @'
aw-cli - Watch anime from the Windows terminal.

Native PowerShell CLI for browsing and streaming anime from Animeworld and Animeunity
providers. Integrates with MPV, VLC, Screenbox (UWP), and Photos App. Supports watch
history and optional AniList sync.

Requires: Windows PowerShell 5.1 or higher.
'@
    PowerShellVersion = '5.1'
    PowerShellHostName = ''
    PowerShellHostVersion = ''
    DotNetFrameworkVersion = ''
    CLRVersion = ''
    ProcessorArchitecture = 'None'
    RequiredModules = @()
    RequiredAssemblies = @()
    ScriptsToProcess = @()
    TypesToProcess = @()
    FormatsToProcess = @()
    NestedModules = @()

    FunctionsToExport = @(
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
        # UI (replaces fzf)
        'Show-Menu',
        'Show-YesNoPrompt',
        'Show-ListPrompt',
        # Console helpers
        'Write-OutputColor',
        'Clear-ConsoleScreen',
        # Provider factory
        'New-Provider',
        # AniList sync
        'Update-AniListEntry',
        'Get-AniListUserId',
        'Get-AnimeAniListRating',
        # Utils
        'Get-DownloadPath',
        'Set-AnimeConfig'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    ModuleList = @()
    FileList = @()

    PrivateData = @{
        PackageManagementProviders = @()
        PSData = @{
            Tags = @('anime', 'streaming', 'cli', 'animeworld', 'animeunity', 'mpv', 'vlc')
            LicenseUri = ''
            ProjectUri = 'https://github.com/axl74/aw-cli'
            IconUri = ''
            ReleaseNotes = @'
Initial PowerShell port.
- Animeworld and Animeunity providers
- Local/Offline anime browsing
- Player abstraction: MPV, VLC, Screenbox, Photos
- Watch history with JSON persistence
- Optional AniList sync
- Native console TUI (no external dependencies)
'@
        }
    }

    HelpInfoURI = ''
    DefaultCommandPrefix = ''
}