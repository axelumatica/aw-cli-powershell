#Requires -Version 5.1
# Animeunity provider - uses animeunity.so REST API.
# Depends on: Provider base class (loaded by Provider.ps1)

. (Join-Path $PSScriptRoot '..\..\Classes\Provider.ps1')

class Animeunity : Provider {

    hidden [string] $CsrfToken

    Animeunity([object]$Session) : base("https://www.animeunity.so", $Session) {
        $this._LoadCsrfToken()
    }
    Animeunity() : base("https://www.animeunity.so") {
        $this._LoadCsrfToken()
    }

    hidden [void] _LoadCsrfToken() {
        try {
            # Fetch animeunity home page to get cookies and CSRF token
            $resp = Invoke-WebRequest -Uri $this.BaseUrl -WebSession $this.Session -TimeoutSec 30 -ErrorAction SilentlyContinue
            if ($resp -and $resp.Content) {
                # Try to extract CSRF token from meta tag or cookie
                $tokenM = [regex]::Match($resp.Content, 'name="csrf-token" content="([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                if ($tokenM.Success) { $this.CsrfToken = $tokenM.Groups[1].Value }
                else {
                    # Try from cookie
                    foreach ($c in $this.Session.Cookies.GetCookies()) {
                        if ($c.Name -eq 'csrf_token') { $this.CsrfToken = $c.Value; break }
                    }
                }
            }
        } catch { }
    }

    # ── Search ───────────────────────────────────────────────────────────

    hidden [object[]] _SearchImpl([string]$Input) {
        $url = "$($this.BaseUrl)/livesearch"

        try {
            $form = @{ value = $Input } | ConvertTo-Json -Compress
            $headers = @{ 'X-CSRF-TOKEN' = $this.CsrfToken; 'X-Requested-With' = 'XMLHttpRequest' }

            $resp = Invoke-WebRequest -Uri $url -Method POST `
                -Headers $headers `
                -ContentType 'application/json' `
                -WebSession $this.Session `
                -Body $form `
                -TimeoutSec 30 `
                -ErrorAction SilentlyContinue

            if (-not $resp -or -not $resp.Content) { return @() }
            $data = $resp.Content | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
            if (-not $data -or -not $data['data']) { return @() }

            $results = @()
            foreach ($item in $data['data']) {
                $anime = [Anime]::new()
                $anime.Name  = $this.HtmlDecode($item['title'])
                $anime.Ref   = $item['id'].ToString()
                $anime.Image = "https://cdn.animeunity.so$($item['poster'])"
                $anime.Url   = "$($this.BaseUrl)/anime/$($item['id'])"

                # Status
                $statusId = if ($item['status']) { $item['status'] } else { 1 }
                $anime.Status = switch ($statusId) {
                    0 { [AnimeStatus]::Ongoing }
                    1 { [AnimeStatus]::Finished }
                    2 { [AnimeStatus]::NotReleased }
                    default { [AnimeStatus]::Unknown }
                }

                $results += $anime
            }
            return $results
        } catch {
            Write-OutputColor "Animeunity search failed: $_" -Style error
            return @()
        }
    }

    # ── Latest ─────────────────────────────────────────────────────────

    hidden [object[]] _LatestImpl([string]$Filter, [bool]$Specials) {
        try {
            $url = "$($this.BaseUrl)/info_api/_latest"
            $resp = Invoke-WebRequest -Uri $url -WebSession $this.Session -TimeoutSec 30 -ErrorAction SilentlyContinue
            if (-not $resp -or -not $resp.Content) { return @() }
            $data = $resp.Content | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue

            $results = @()
            foreach ($item in $data) {
                $anime = [Anime]::new()
                $anime.Name  = $this.HtmlDecode($item['title'])
                $anime.Ref   = $item['id'].ToString()
                $anime.Image = "https://cdn.animeunity.so$($item['poster'])"
                $anime.Url   = "$($this.BaseUrl)/anime/$($item['id'])"
                $anime.Status = [AnimeStatus]::Ongoing
                $results += $anime
            }
            return $results
        } catch {
            Write-OutputColor "Animeunity latest failed: $_" -Style error
            return @()
        }
    }

    # ── Episodes ────────────────────────────────────────────────────────

    hidden [hashtable] _EpisodesImpl([object]$Anime) {
        $cachedKey = "ep_$($Anime.Ref)"
        $cached = $this._GetCached($cachedKey)
        if ($cached) { return $cached }

        try {
            $url = "$($this.BaseUrl)/info_api/$($Anime.Ref)"
            $resp = Invoke-WebRequest -Uri $url -WebSession $this.Session -TimeoutSec 30 -ErrorAction SilentlyContinue
            if (-not $resp -or -not $resp.Content) { return @{} }

            $data = $resp.Content | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
            if (-not $data -or -not $data['episodes']) { return @{} }

            $episodes = @{}
            foreach ($ep in $data['episodes']) {
                $num = $ep['number'].ToString()
                $epId = $ep['id'].ToString()
                $episodes[$num] = $epId
            }
            $this._SetCached($cachedKey, $episodes)
            return $episodes
        } catch {
            Write-OutputColor "Animeunity episodes failed: $_" -Style error
            return @{}
        }
    }

    # ── Episode link ────────────────────────────────────────────────────

    hidden [string] _EpisodeLinkImpl([object]$Anime, [object]$Episode) {
        try {
            $url = "$($this.BaseUrl)/embed-url/$($Episode.Ref)"
            $headers = @{
                'X-CSRF-TOKEN' = $this.CsrfToken
                'X-Requested-With' = 'XMLHttpRequest'
                'Referer' = "$($this.BaseUrl)/anime/$($Anime.Ref)"
            }

            $resp = Invoke-WebRequest -Uri $url -Method GET `
                -Headers $headers `
                -WebSession $this.Session `
                -TimeoutSec 30 `
                -ErrorAction SilentlyContinue

            if (-not $resp -or -not $resp.Content) { throw "No response" }
            $data = $resp.Content | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue

            if ($data -and $data['url']) { return $data['url'] }
            throw "URL not found"
        } catch {
            Write-OutputColor "Episode link failed: $_" -Style error
            throw "Impossibile ottenere il link video: $_"
        }
    }

    # ── Info ───────────────────────────────────────────────────────────

    hidden [void] _InfoAnimeImpl([object]$Anime) {
        try {
            $url = "$($this.BaseUrl)/info_api/$($Anime.Ref)"
            $resp = Invoke-WebRequest -Uri $url -WebSession $this.Session -TimeoutSec 30 -ErrorAction SilentlyContinue
            if (-not $resp -or -not $resp.Content) { return }

            $data = $resp.Content | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
            if (-not $data) { return }

            $Anime.Name        = $this.HtmlDecode($data['title'])
            if ($data['cover']) { $Anime.Image = "https://cdn.animeunity.so$($data['cover'])" }
            if ($data['description']) { $Anime.Description = $this.HtmlDecode($data['description']) }
            if ($data['genres'] -and $data['genres'] -is [array]) {
                $Anime.Genres = $data['genres'] -join ', '
            }
            if ($data['episodes_count']) { $Anime.EpCount = [int]$data['episodes_count'] }
            if ($data['status']) {
                $Anime.Status = switch ([int]$data['status']) {
                    0 { [AnimeStatus]::Ongoing }
                    1 { [AnimeStatus]::Finished }
                    2 { [AnimeStatus]::NotReleased }
                    default { [AnimeStatus]::Unknown }
                }
            }
            if ($data['score']) { $Anime.Score = [double]$data['score'] }
            if ($data['aired_on']) { $Anime.DateAired = $data['aired_on'] }

        } catch {
            Write-OutputColor "Info fetch failed: $_" -Style warning
        }
    }
}