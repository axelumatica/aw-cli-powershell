#Requires -Version 5.1
# Local provider - browses downloaded anime from filesystem.
# Depends on: Provider base class (loaded by Provider.ps1)

. (Join-Path $PSScriptRoot '..\..\Classes\Provider.ps1')

class LocalProvider : Provider {
    hidden [string]   $BasePath
    hidden [object[]] $History

    LocalProvider() : base("local") {
        $this.BasePath = Join-Path $env:USERPROFILE "Videos\Anime"
        if (-not (Test-Path $this.BasePath)) {
            New-Item -ItemType Directory -Path $this.BasePath -Force | Out-Null
        }
    }

    LocalProvider([string]$DownloadPath) : base("local") {
        if (-not $DownloadPath -or $DownloadPath -eq "local") {
            $DownloadPath = Join-Path $env:USERPROFILE "Videos\Anime"
        }
        $this.BasePath = $DownloadPath
        if (-not (Test-Path $this.BasePath)) {
            New-Item -ItemType Directory -Path $this.BasePath -Force | Out-Null
        }
    }

    [void] SetHistory([object[]]$History) {
        $this.History = $History
    }

    hidden [object[]] _SearchImpl([string]$Input) {
        $animes = @()
        if (-not (Test-Path $this.BasePath)) { return @() }

        foreach ($folder in Get-ChildItem -Path $this.BasePath -Directory -ErrorAction SilentlyContinue) {
            $name = $folder.Name
            if ($Input -and $name -notmatch $Input) { continue }

            $anime = [Anime]::new($name, $name)

            # Enrich from history
            if ($this.History) {
                foreach ($h in $this.History) {
                    if ($h.Name -eq $name) {
                        $anime.Ref = $h.Ref
                        $anime.SetInfo($h.AnilistId, $h.Status, $h.Genres)
                        $anime.Image = $h.Image
                        break
                    }
                }
            }

            try {
                $eps = $this._EpisodesImpl($anime)
                $anime.UpdateEpisodesEx($eps, $true)
                $lastEpObj = $anime.Episodes | Select-Object -Last 1
                if ($lastEpObj) { $anime.CurrEp = $lastEpObj.Num }
            } catch { }

            $animes += $anime
        }
        return $animes
    }

    hidden [object[]] _LatestImpl([string]$Filter, [bool]$Specials) {
        $all = $this._SearchImpl("")
        foreach ($anime in $all) {
            $lastEpObj = $anime.Episodes | Select-Object -Last 1
            if ($lastEpObj) { $anime.CurrEp = $lastEpObj.Num }
        }
        # Sort by folder modified date descending
        $sorted = @($all | ForEach-Object {
            $folder = Join-Path $this.BasePath $_.Name
            $_.PSObject.Properties.Add((New-Object PSNoteProperty('FolderDate', (Get-Item $folder -ErrorAction SilentlyContinue).LastWriteTime)))
            $_
        } | Sort-Object { $_.FolderDate } -Descending)
        return $sorted
    }

    hidden [hashtable] _EpisodesImpl([object]$Anime) {
        $animePath = Join-Path $this.BasePath $Anime.Name
        if (-not (Test-Path $animePath)) { return @{} }

        $episodes = @{}
        $videoExts = @('*.mp4', '*.mkv', '*.avi', '*.webm', '*.mov')

        foreach ($ext in $videoExts) {
            foreach ($file in Get-ChildItem -Path $animePath -Filter $ext -ErrorAction SilentlyContinue) {
                $fileName = $file.BaseName
                $epNum = $null

                # Extract episode number: " Anime - 01", "Ep. 12", "01", etc.
                $m = [regex]::Match($fileName, '(?:[-–]\s*)?(?:[Ee]p\.?\s*)?(\d[\d\-]*)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                if ($m.Success) { $epNum = $m.Groups[1].Value }

                if (-not $epNum) { continue }
                $episodes[$epNum] = $file.Name
            }
        }
        return $episodes
    }

    hidden [string] _EpisodeLinkImpl([object]$Anime, [object]$Episode) {
        $fullPath = Join-Path $this.BasePath $Anime.Name $Episode.Ref
        if (-not (Test-Path $fullPath)) {
            # Try without Ref (fallback: just use the episode num)
            $animePath = Join-Path $this.BasePath $Anime.Name
            $videoExts = @('*.mp4', '*.mkv', '*.avi', '*.webm', '*.mov')
            foreach ($ext in $videoExts) {
                $files = Get-ChildItem -Path $animePath -Filter $ext -ErrorAction SilentlyContinue
                foreach ($f in $files) {
                    if ($f.BaseName -match "(?:[-]\s*)?(?:[Ee]p\.?\s*)?$([regex]::Escape($Episode.Num))") {
                        return $f.FullName
                    }
                }
            }
            throw "Local file not found: $fullPath"
        }
        return $fullPath
    }

    hidden [void] _InfoAnimeImpl([object]$Anime) {
        if (-not $this.History) { return }
        foreach ($h in $this.History) {
            if ($h.Name -eq $Anime.Name) {
                $Anime.SetInfo($h.AnilistId, $h.Status, $h.Genres)
                $Anime.Image = $h.Image
                return
            }
        }
    }
}

function Get-DownloadPath {
    return Join-Path $env:USERPROFILE "Videos\Anime"
}

 try {
     Export-ModuleMember -Function 'Get-DownloadPath'
 } catch { }