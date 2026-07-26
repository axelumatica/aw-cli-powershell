#Requires -Version 5.1
# Shared types - enums and base type definitions.
# No dependencies.

. (Join-Path $PSScriptRoot 'Utils.ps1')

# ── Enums ─────────────────────────────────────────────────────────────────

enum AnimeStatus {
    Ongoing     = 0   # "In corso"
    Finished    = 1   # "Finito"
    NotReleased = 2   # "Non rilasciato"
    Unknown     = 3   # "Sconosciuto"
}

enum DownloadStatus {
    Pending    = 0
    InProgress = 1
    Completed  = 2
    Failed     = 3
    Paused     = 4
}

enum AniListStatus {
    Watching   = 1
    Completed = 2
    Paused    = 3
    Dropped   = 4
    Planning  = 5
}

# ── Helpers ───────────────────────────────────────────────────────────────

function Get-AnimeStatusName {
    param([AnimeStatus]$Status)
    switch ($Status) {
        ([AnimeStatus]::Ongoing)     { return "In corso" }
        ([AnimeStatus]::Finished)    { return "Finito" }
        ([AnimeStatus]::NotReleased) { return "Non rilasciato" }
        ([AnimeStatus]::Unknown)     { return "Sconosciuto" }
    }
    return "Sconosciuto"
}

function Get-DownloadStatusName {
    param([DownloadStatus]$Status)
    switch ($Status) {
        ([DownloadStatus]::Pending)    { return "In attesa" }
        ([DownloadStatus]::InProgress) { return "In download" }
        ([DownloadStatus]::Completed)  { return "Completato" }
        ([DownloadStatus]::Failed)     { return "Fallito" }
        ([DownloadStatus]::Paused)     { return "In pausa" }
    }
    return "Sconosciuto"
}

function Get-AniListStatusName {
    param([AniListStatus]$Status)
    switch ($Status) {
        ([AniListStatus]::Watching)   { return "In visione" }
        ([AniListStatus]::Completed)  { return "Completato" }
        ([AniListStatus]::Paused)     { return "In pausa" }
        ([AniListStatus]::Dropped)    { return "Abbandonato" }
        ([AniListStatus]::Planning)   { return "In programma" }
    }
    return "Sconosciuto"
}

# ── Status helpers for JSON serialization ─────────────────────────────────

function ConvertFrom-AnimeStatusString {
    param([string]$StatusStr)
    if (-not $StatusStr) { return [AnimeStatus]::Unknown }
    switch ($StatusStr.ToLower().Trim()) {
        { $_ -in @('ongoing', 'in corso', 'airing', 'current') } { return [AnimeStatus]::Ongoing }
        { $_ -in @('finished', 'finito', 'complete', 'completed') } { return [AnimeStatus]::Finished }
        { $_ -in @('not released', 'non rilasciato', 'upcoming', 'hiatus') } { return [AnimeStatus]::NotReleased }
        default { return [AnimeStatus]::Unknown }
    }
}

function ConvertTo-Hashtable {
    param([object]$InputObject)
    if ($null -eq $InputObject) { return @{ } }
    if ($InputObject -is [hashtable]) { return $InputObject }
    $ht = @{ }
    foreach ($prop in $InputObject.PSObject.Properties) {
        $ht[$prop.Name] = $prop.Value
    }
    return $ht
}

# ── String extensions ─────────────────────────────────────────────────────

function Get-SafeFileName {
    param([string]$Name)
    if (-not $Name) { return "" }
    $s = $Name.Trim()
    $s = $s -replace '[\\\/:*?"<>|]', '_'
    $s = $s -replace '\s+', ' '
    return $s.Trim()
}

 Export-ModuleMember -Function @(
    'Get-AnimeStatusName',
    'Get-DownloadStatusName',
    'Get-AniListStatusName',
    'ConvertFrom-AnimeStatusString',
    'ConvertTo-Hashtable',
    'Get-SafeFileName'
)