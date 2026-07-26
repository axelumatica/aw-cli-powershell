#Requires -Version 5.1
# Interactive CLI session - the main menu loop.
# Mirrors Python run.py main loop.

. (Join-Path $PSScriptRoot '..\Classes\SharedTypes.ps1')
. (Join-Path $PSScriptRoot '..\Classes\Anime.ps1')
. (Join-Path $PSScriptRoot 'Config.ps1')
. (Join-Path $PSScriptRoot 'History.ps1')

function _WriteHeader {
    Clear-ConsoleScreen
    Write-Host ""
    Write-Host "  aw-cli" -ForegroundColor Magenta -NoNewline
    Write-Host "  -  Anime dal terminale" -ForegroundColor Magenta
    Write-Host "  ─────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
}

function _InteractiveSearch([object]$Provider) {
    _WriteHeader
    Write-Host "  Ricerca anime" -ForegroundColor Cyan
    Write-Host ""

    $query = Read-Host "  Cerca (INVIO per i piu' recenti)"
    Write-Host ""

    if (-not $query) {
        Write-OutputColor "  Caricamento ultimi episodi..." -Style info
        return @( $Provider.Latest("a") )
    }

    $results = @( $Provider.Search($query) )
    if ($results.Count -eq 0) {
        Write-OutputColor "  Nessun risultato per: $query" -Style warning
        return @()
    }

    $selected = Show-Menu -Items $results `
        -Prompt "Risultati - seleziona anime" `
        -ItemDisplay {
            param($anime, $idx)
            $statusLabel = (Get-AnimeStatusName $anime.Status)
            return "$($anime.Name) [$statusLabel]"
        }

    if ($null -eq $selected) { return @() }
    return @($selected)
}

function _InteractiveSession {
    param(
        [object]$Provider,
        [object[]]$AnimeList,
        [object[]]$WatchHistory,
        [switch]$HistoryMode,
        [switch]$InfoMode,
        [switch]$DownloadMode,
        [switch]$OfflineMode,
        [switch]$PrivateMode
    )

    # Single anime path (e.g. from history or search)
    if ($AnimeList.Count -eq 1) {
        $anime = $AnimeList[0]
        return _PlayAnime -Anime $anime -Provider $Provider -WatchHistory $WatchHistory `
            -HistoryMode:$HistoryMode -InfoMode:$InfoMode -DownloadMode:$DownloadMode `
            -OfflineMode:$OfflineMode -PrivateMode:$PrivateMode
    }

    # Multi-anime: let user pick
    $selected = Show-Menu -Items $AnimeList `
        -Prompt "Seleziona anime" `
        -ItemDisplay {
            param($a, $idx)
            if ($a.PSObject.TypeNames -and $a.PSObject.TypeNames -contains 'Anime') {
                return "$($a.Name) [Ep $($a.CurrEp)/$($a.LastEp)]"
            }
            return $a.ToString()
        }

    if ($null -eq $selected) { return }
    return _PlayAnime -Anime $selected -Provider $Provider -WatchHistory $WatchHistory `
        -HistoryMode:$HistoryMode -InfoMode:$InfoMode -DownloadMode:$DownloadMode `
        -OfflineMode:$OfflineMode -PrivateMode:$PrivateMode
}

function _PlayAnime {
    param(
        [object]$Anime,
        [object]$Provider,
        [object[]]$WatchHistory,
        [switch]$HistoryMode,
        [switch]$InfoMode,
        [switch]$DownloadMode,
        [switch]$OfflineMode,
        [switch]$PrivateMode
    )

    # Load episodes
    if ($Anime.Episodes.Count -eq 0) {
        Write-OutputColor "  Caricamento episodi..." -Style info
        $Provider.FetchEpisodes($Anime)
        $Anime.Refresh = $true  # marker
    }

    # Show info if requested
    if ($InfoMode) {
        _ShowAnimeInfo -Anime $Anime -Provider $Provider
    }

    # Download mode
    if ($DownloadMode) {
        _HandleDownload -Anime $Anime -Provider $Provider
        return
    }

    # Episode selection loop
    $exitLoop = $false
    while (-not $exitLoop) {
        _WriteHeader
        Write-Host "  $($Anime.Name)" -ForegroundColor Cyan
        Write-Host "  Episodes: $($Anime.Episodes.Count)" -ForegroundColor Gray
        Write-Host "  Status: $(Get-AnimeStatusName $Anime.Status)" -ForegroundColor Gray
        if ($Anime.Genres) { Write-Host "  Genres: $($Anime.Genres)" -ForegroundColor Gray }
        Write-Host ""
        Write-Host "  1) Guarda episodio" -ForegroundColor White
        Write-Host "  2) Vedi informazioni" -ForegroundColor White
        Write-Host "  3) Download" -ForegroundColor White
        Write-Host "  4) Rimuovi dalla cronologia" -ForegroundColor White
        Write-Host "  0) Indietro" -ForegroundColor DarkGray
        Write-Host ""

        $choice = Read-Host "  Scelta [1]"

        switch ($choice) {
            "1" {
                $episode = _SelectEpisode -Anime $Anime
                if ($episode) {
                    _WatchEpisode -Episode $episode -Anime $Anime -Provider $Provider `
                        -WatchHistory $WatchHistory -HistoryMode:$HistoryMode -PrivateMode:$PrivateMode
                }
            }
            "2" {
                _ShowAnimeInfo -Anime $Anime -Provider $Provider
            }
            "3" {
                _HandleDownload -Anime $Anime -Provider $Provider
            }
            "4" {
                if (-not $PrivateMode -and (Show-YesNoPrompt "Rimuovere dalla cronologia?")) {
                    Remove-FromHistory -Anime $Anime
                    Write-OutputColor "  Rimosso!" -Style success
                    Start-Sleep 1
                    $exitLoop = $true
                }
            }
            default {
                $exitLoop = $true
            }
        }
    }
}

function _SelectEpisode([object]$Anime) {
    if ($Anime.Episodes.Count -eq 0) {
        Write-OutputColor "  Nessun episodio disponibile" -Style warning
        return $null
    }

    $ep = Show-Menu -Items $Anime.Episodes `
        -Prompt "Seleziona episodio" `
        -ItemDisplay {
            param($e, $idx)
            $epNum = $e.Num
            if ($e.Title) { "$epNum - $($e.Title)" } else { "Episode $epNum" }
        }

    return $ep
}

function _WatchEpisode {
    param(
        [object]$Episode,
        [object]$Anime,
        [object]$Provider,
        [object[]]$WatchHistory,
        [switch]$HistoryMode,
        [switch]$PrivateMode
    )

    # Get video URL
    $videoUrl = $null
    try {
        Write-OutputColor "  Caricamento video..." -Style info
        $videoUrl = $Provider.GetEpisodeLink($Anime, $Episode)
    } catch {
        Write-OutputColor "  Errore getting link: $_" -Style error
        Read-Host "  Premi INVIO per continuare"
        return
    }

    if (-not $videoUrl) {
        Write-OutputColor "  Nessun URL video trovato" -Style error
        Read-Host "  Premi INVIO per continuare"
        return
    }

    # Play
    $result = Invoke-MediaPlayer -MediaPath $videoUrl -Title "$($Anime.Name) Ep.$($Episode.Num)"

    # Post-watch menu
    $currentIdx = -1
    for ($i = 0; $i -lt $Anime.Episodes.Count; $i++) {
        if ($Anime.Episodes[$i].Equals($Episode)) { $currentIdx = $i; break }
    }

    $prevEp = if ($currentIdx -gt 0) { $Anime.Episodes[$currentIdx - 1] } else { $null }
    $nextEp = if ($currentIdx -ge 0 -and $currentIdx -lt $Anime.Episodes.Count - 1) { $Anime.Episodes[$currentIdx + 1] } else { $null }

    if ($result.Completed) {
        $Episode.MarkCompleted()
        $Anime.SetProgress($Episode.Num)
    } elseif ($result.Progress -gt 0) {
        $Episode.WatchedPos = $result.Progress
        $Anime.SetProgress($Episode.Num)
    }

    # Update history (non-private mode)
    if (-not $PrivateMode) {
        try {
            if (-not ($WatchHistory | Where-Object { $_.Equals($Anime) })) {
                $WatchHistory = @(Import-History)
            }
            Update-AnimeHistory -Anime $Anime -Episode $Episode
        } catch { }
    }

    # Post-watch menu
    Write-Host ""
    Write-Host "  Cosa vuoi fare?" -ForegroundColor Cyan
    if ($nextEp)     { Write-Host "    N) Prossimo ($($nextEp.Num))" -ForegroundColor White }
    if ($prevEp)     { Write-Host "    P) Precedente ($($prevEp.Num))" -ForegroundColor White }
    Write-Host "    R) Ripeti questo" -ForegroundColor White
    Write-Host "    M) Menu anime" -ForegroundColor White
    Write-Host "    Q) Esci" -ForegroundColor White
    Write-Host ""

    while ($true) {
        $action = Read-Host "  Scelta"
        switch ($action.ToUpper()) {
            "N" { if ($nextEp) { return _WatchEpisode -Episode $nextEp -Anime $Anime -Provider $Provider -WatchHistory $WatchHistory -HistoryMode:$HistoryMode -PrivateMode:$PrivateMode } }
            "P" { if ($prevEp) { return _WatchEpisode -Episode $prevEp -Anime $Anime -Provider $Provider -WatchHistory $WatchHistory -HistoryMode:$HistoryMode -PrivateMode:$PrivateMode } }
            "R" { return _WatchEpisode -Episode $Episode -Anime $Anime -Provider $Provider -WatchHistory $WatchHistory -HistoryMode:$HistoryMode -PrivateMode:$PrivateMode }
            "M" { return }
            "Q" { Write-Host "Arrivederci!" -ForegroundColor Cyan; exit }
            default { if (-not $action) { return } }
        }
    }
}

function _ShowAnimeInfo {
    param([object]$Anime, [object]$Provider)

    _WriteHeader
    Write-Host "  $($Anime.Name)" -ForegroundColor Cyan
    Write-Host "  Status: $(Get-AnimeStatusName $Anime.Status)" -ForegroundColor Gray
    if ($Anime.Genres)    { Write-Host "  Generi: $($Anime.Genres)" -ForegroundColor Gray }
    if ($Anime.Studio)    { Write-Host "  Studio: $($Anime.Studio)" -ForegroundColor Gray }
    if ($Anime.Score -gt 0) { Write-Host "  Voto: $($Anime.Score)/100" -ForegroundColor Gray }
    if ($Anime.DateAired) { Write-Host "  Data: $($Anime.DateAired)" -ForegroundColor Gray }
    Write-Host "  Episodi: $($Anime.Episodes.Count)" -ForegroundColor Gray
    Write-Host ""

    if ($Anime.Description) {
        $desc = $Anime.Description
        if ($desc.Length -gt 300) { $desc = $desc.Substring(0, 300) + "..." }
        Write-Host "  $($desc)" -ForegroundColor DarkGray
        Write-Host ""
    }

    Write-Host "  Premi INVIO per tornare al menu" -ForegroundColor DarkGray
    Read-Host
}

function _HandleDownload {
    param([object]$Anime, [object]$Provider)

    _WriteHeader
    Write-Host "  Download - $($Anime.Name)" -ForegroundColor Cyan
    Write-Host "  $($Anime.Episodes.Count) episodi disponibili" -ForegroundColor Gray
    Write-Host ""

    # Allow range selection
    Write-Host "  Download completi (1-$($Anime.Episodes.Count))" -ForegroundColor White
    Write-Host "  Oppure digita un range, es: 1-5" -ForegroundColor DarkGray
    Write-Host ""

    $rangeInput = Read-Host "  Episodi [tutti]"
    $toDownload = $Anime.Episodes

    if ($rangeInput -and $rangeInput -ne "tutti") {
        if ($rangeInput -match '^(\d+)$') {
            $epNum = $rangeInput
            $toDownload = @($Anime.Episodes | Where-Object { $_.Num -eq $epNum })
        } elseif ($rangeInput -match '^(\d+)-(\d+)$') {
            $from = [int]$Matches[1]; $to = [int]$Matches[2]
            $toDownload = @($Anime.Episodes | Where-Object {
                $n = [double]$_.Num
                $n -ge $from -and $n -le $to
            })
        }
    }

    if ($toDownload.Count -eq 0) {
        Write-OutputColor "  Nessun episodio da scaricare" -Style warning
        Start-Sleep 1
        return
    }

    Save-AnimeDownload -Anime $Anime -Episodes $toDownload
    Write-Host ""
    Write-Host "  Download completato!" -ForegroundColor Green
    Start-Sleep 2
}

function _HandleHistoryRemoval {
    param([object[]]$WatchHistory)

    _WriteHeader
    Write-Host "  Rimuovi dalla cronologia" -ForegroundColor Cyan
    Write-Host ""

    if ($WatchHistory.Count -eq 0) {
        Write-OutputColor "  Cronologia vuota" -Style warning
        return
    }

    $toRemove = Show-Menu -Items $WatchHistory `
        -Prompt "Seleziona da rimuovere" `
        -MultiSelect

    if ($toRemove -and $toRemove.Count -gt 0) {
        foreach ($a in $toRemove) { Remove-FromHistory -Anime $a }
        Write-OutputColor "  Rimossi $($toRemove.Count) elementi" -Style success
    }
}

 Export-ModuleMember -Function @()
 