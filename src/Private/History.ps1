#Requires -Version 5.1
# Watch history management - JSON persistence.
# Depends on: SharedTypes.ps1, Config.ps1

. (Join-Path $PSScriptRoot '..\Classes\SharedTypes.ps1')
. (Join-Path $PSScriptRoot 'Config.ps1')

function Get-HistoryPath {
    $moduleDir = Split-Path (Get-ConfigPath) -Parent
    return Join-Path $moduleDir "history.json"
}

function Import-History {
    $path = Get-HistoryPath
    if (-not (Test-Path $path)) { return @() }

    try {
        $json = Get-Content $path -Raw -ErrorAction SilentlyContinue
        if (-not $json) { return @() }
        $data = $json | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
        if (-not $data) { $data = @() }
        elseif ($data -isnot [array]) { $data = @($data) }

        $animes = @()
        foreach ($entry in $data) {
            try {
                $anime = [Anime]::new($entry)
                $animes += $anime
            } catch { Write-Warning "Skipped history entry: $_" }
        }
        return $animes
    } catch {
        Write-Warning "Failed to load history: $_"
        return @()
    }
}

function Export-History {
    param([object[]]$AnimeList)

    $path = Get-HistoryPath
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    if (-not $AnimeList) { $AnimeList = @() }
    $data = @($AnimeList | ForEach-Object { $_.ToDict() })
    $json = $data | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding $false))
}

function Update-AnimeHistory {
    param(
        [Parameter(Mandatory)]
        [object]$Anime,

        [Parameter(Mandatory)]
        [object]$Episode
    )
    $history = [System.Collections.ArrayList]::new((Import-History))

    # Remove existing (same anime)
    $existingIdx = -1
    for ($i = 0; $i -lt $history.Count; $i++) {
        if ($history[$i].Equals($Anime)) { $existingIdx = $i; break }
    }
    if ($existingIdx -ge 0) { $history.RemoveAt($existingIdx) }

    # Check if just completed
    $lastCompleted = $Episode.IsCompleted() -and $Episode.Num -eq $Anime.LastEp
    if ($Anime.Status -eq [AnimeStatus]::Finished -and $lastCompleted) {
        # Completed: append at end (don't put at top)
        Export-History ($history.ToArray())
        return
    }

    if ($lastCompleted) {
        [void]$history.Add($Anime)
    } else {
        [void]$history.Insert(0, $Anime)
    }
    Export-History ($history.ToArray())
}

function Remove-FromHistory {
    param([object]$Anime)
    $history = Import-History
    $updated = @($history | Where-Object { -not $_.Equals($Anime) })
    if ($updated.Count -ne $history.Count) { Export-History $updated }
}

function Get-OngoingAnimeCount {
    param([object[]]$History = $null)
    if (-not $History) { $History = Import-History }
    $count = 0
    foreach ($a in $History) {
        if ($a.Status -eq [AnimeStatus]::Ongoing) { $count++ }
    }
    return $count
}

 try {
     Export-ModuleMember -Function @(
         'Get-HistoryPath', 'Import-History', 'Export-History',
         'Update-AnimeHistory', 'Remove-FromHistory', 'Get-OngoingAnimeCount'
     )
 } catch { }