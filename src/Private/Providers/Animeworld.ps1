#Requires -Version 5.1
# Animeworld provider - scrapes animeworld.ac.
# Depends on: Provider base class (loaded by Provider.ps1)

. (Join-Path $PSScriptRoot '..\..\Classes\Provider.ps1')

class Animeworld : Provider {

    Animeworld([object]$Session) : base("https://www.animeworld.ac", $Session) { }
    Animeworld() : base("https://www.animeworld.ac") { }

    # ── Search ───────────────────────────────────────────────────────────

    hidden [object[]] _SearchImpl([string]$Input) {
        $url = "$($this.BaseUrl)/api/search/v2"
        $body = @{ keyword = $Input } | ConvertTo-Json -Compress

        try {
            $raw = Invoke-WebRequest -Uri $url -Method POST `
                -Headers @{
                    'Content-Type' = 'application/json'
                    'Referer' = $this.BaseUrl
                    'X-Requested-With' = 'XMLHttpRequest'
                } `
                -WebSession $this.Session `
                -Body $body `
                -TimeoutSec 30 `
                -ErrorAction SilentlyContinue

            if (-not $raw -or -not $raw.Content) { return @() }
            $data = $raw.Content | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
            if (-not $data -or -not $data['data']) { return @() }

            $results = @()
            foreach ($item in $data['data']) {
                $anime = [Anime]::new()
                $anime.Name    = $this.HtmlDecode($item['title'])
                $anime.Ref     = $item['url']
                $anime.Image   = $item['thumbnail']
                $anime.Url     = "$($this.BaseUrl)/$($item['url'])"

                $statusStr = if ($item['status']) { $item['status'] } else { "" }
                $anime.Status = ConvertFrom-AnimeStatusString $statusStr

                $results += $anime
            }
            return $results
        } catch {
            Write-OutputColor "Animeworld search failed: $_" -Style error
            return @()
        }
    }

    # ── Latest ─────────────────────────────────────────────────────────

    hidden [object[]] _LatestImpl([string]$Filter, [bool]$Specials) {
        $map = @{ 'a' = 'all'; 's' = 'sub'; 'd' = 'dub'; 't' = 'trending' }
        $tag = if ($map.ContainsKey($Filter)) { $map[$Filter] } else { 'all' }

        try {
            # Scrape latest page
            $url = "$($this.BaseUrl)/latest"
            $html = Invoke-WebRequest -Uri $url -WebSession $this.Session -TimeoutSec 30 -ErrorAction SilentlyContinue
            if (-not $html -or -not $html.Content) { return @() }

            $animes = @()
            # Parse: <a class="episode" href="/watch/...">...</a>
            $matches = [regex]::Matches($html.Content, '<a class="episode" href="([^"]+)"[^>]*>([\s\S]*?)</a>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            $seen = @{}
            foreach ($m in $matches) {
                $href = $m.Groups[1].Value.Trim()
                if ($seen.ContainsKey($href)) { continue }
                $seen[$href] = $true

                $animeRef = $href -replace '/watch/', ''
                $animeRef = $animeRef -replace '^\.\.?/', ''

                # Extract anime name from episode alt text
                $inner = $m.Groups[2].Value
                $imgM = [regex]::Match($inner, 'alt="([^"]+)"')
                $name = if ($imgM.Success) { $imgM.Groups[1].Value } else { $animeRef }

                $anime = [Anime]::new($name, $animeRef)
                $anime.Url = "$($this.BaseUrl)$href"
                $anime.Status = [AnimeStatus]::Ongoing
                $animes += $anime
            }
            return $animes
        } catch {
            Write-OutputColor "Animeworld latest failed: $_" -Style error
            return @()
        }
    }

    # ── Episodes ────────────────────────────────────────────────────────

    hidden [hashtable] _EpisodesImpl([object]$Anime) {
        # Check cache
        $cachedKey = "episodes_$($Anime.Ref)"
        $cached = $this._GetCached($cachedKey)
        if ($cached) { return $cached }

        $url = "$($this.BaseUrl)/api/episodes/$($Anime.Ref)"
        try {
            $resp = Invoke-WebRequest -Uri $url -WebSession $this.Session -TimeoutSec 30 -ErrorAction SilentlyContinue
            if (-not $resp -or -not $resp.Content) { return @{} }
            $data = $resp.Content | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue

            $episodes = @{}
            if ($data -and $data['data']) {
                foreach ($ep in $data['data']) {
                    $num = $ep['number'].ToString()
                    $epId = $ep['id'].ToString()
                    $episodes[$num] = $epId
                }
            }
            $this._SetCached($cachedKey, $episodes)
            return $episodes
        } catch {
            # Fallback: scrape HTML
            $htmlPage = Invoke-WebRequest -Uri $Anime.Url -WebSession $this.Session -TimeoutSec 30 -ErrorAction SilentlyContinue
            if (-not $htmlPage -or -not $htmlPage.Content) { return @{} }

            $episodes = @{}
            $matches = [regex]::Matches($htmlPage.Content, 'data-id="(\d+)"[^>]*data-number="([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            foreach ($m in $matches) {
                $num = $m.Groups[2].Value
                $epId = $m.Groups[1].Value
                $episodes[$num] = $epId
            }
            $this._SetCached($cachedKey, $episodes)
            return $episodes
        }
    }

    # ── Episode link ────────────────────────────────────────────────────

    hidden [string] _EpisodeLinkImpl([object]$Anime, [object]$Episode) {
        $apiUrl = "$($this.BaseUrl)/api/episode/serverPlayerAnimeWorld"
        $body = @{ id = $Episode.Ref } | ConvertTo-Json -Compress

        try {
            $resp = Invoke-WebRequest -Uri $apiUrl -Method POST `
                -Headers @{
                    'Content-Type' = 'application/json'
                    'Referer' = "$($this.BaseUrl)/watch/$($Anime.Ref)"
                    'X-Requested-With' = 'XMLHttpRequest'
                } `
                -WebSession $this.Session `
                -Body $body `
                -TimeoutSec 30 `
                -ErrorAction SilentlyContinue

            if (-not $resp -or -not $resp.Content) { throw "No response" }
            $data = $resp.Content | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue

            # Look for video URL in response
            $srcM = [regex]::Match($resp.Content, '<source src="([^"]+)"')
            if ($srcM.Success) {
                return $srcM.Groups[1].Value
            }
            if ($data -and $data['data']) {
                $src = $data['data']['src']
                if ($src) { return $src }
                $sources = $data['data']['sources']
                if ($sources -and $sources.Count -gt 0) {
                    $best = $sources | Sort-Object { [double]($_.value) } -Descending | Select-Object -First 1
                    return $best.src
                }
            }
            throw "Video URL not found in response"
        } catch {
            Write-OutputColor "Episode link failed: $_" -Style error
            throw "Impossibile ottenere il link video: $_"
        }
    }

    # ── Info ───────────────────────────────────────────────────────────

    hidden [void] _InfoAnimeImpl([object]$Anime) {
        if (-not $Anime.Url) { return }
        try {
            $html = Invoke-WebRequest -Uri $Anime.Url -WebSession $this.Session -TimeoutSec 30 -ErrorAction SilentlyContinue
            if (-not $html -or -not $html.Content) { return }

            # Title
            $titleM = [regex]::Match($html.Content, '<h1[^>]*>([\s\S]*?)</h1>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($titleM.Success) {
                $Anime.Name = $this.HtmlDecode($titleM.Groups[1].Value.Trim())
            }

            # Image
            $imgM = [regex]::Match($html.Content, 'property="og:image" content="([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if (-not $imgM.Success) {
                $imgM = [regex]::Match($html.Content, 'src="([^"]*cover[^"]+\.(?:jpg|png|webp))"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            }
            if ($imgM.Success) { $Anime.Image = $imgM.Groups[1].Value }

            # Description
            $descM = [regex]::Match($html.Content, 'property="og:description" content="([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($descM.Success) { $Anime.Description = $this.HtmlDecode($descM.Groups[1].Value) }

            # Genre
            $genreM = [regex]::Matches($html.Content, 'href="/genres/[^"]+">([^<]+)<', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            $genres = @($genreM | ForEach-Object { $_.Groups[1].Value.Trim() })
            if ($genres.Count -gt 0) { $Anime.Genres = $genres -join ', ' }

            # Status
            $statusM = [regex]::Match($html.Content, 'Stato:</b>\s*<a[^>]*>([^<]+)<', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($statusM.Success) { $Anime.Status = ConvertFrom-AnimeStatusString $statusM.Groups[1].Value }

            # Episode count
            $epM = [regex]::Match($html.Content, 'Episodi:</b>\s*(\d+)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($epM.Success) { $Anime.EpCount = [int]$epM.Groups[1].Value }

        } catch {
            Write-OutputColor "Info fetch failed: $_" -Style warning
        }
    }
}