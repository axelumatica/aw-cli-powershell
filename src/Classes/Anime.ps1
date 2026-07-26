#Requires -Version 5.1
# Anime data model - the primary domain object.
# Episode numbers are STRINGS to support ranges ("1-12") and specials ("1.5").
# Depends on: SharedTypes.ps1, AnimeEpisode.ps1

. (Join-Path $PSScriptRoot 'SharedTypes.ps1')
. (Join-Path $PSScriptRoot 'AnimeEpisode.ps1')

class Anime {
    [string]      $Name
    [string]      $Ref         # Provider reference (URL slug, ID, or folder name)
    [AnimeStatus] $Status
    [string]      $Image
    [string]      $Url
    [int]         $AnilistId
    [string]      $Genres
    [string]      $Studio
    [double]      $Score
    [int]         $EpCount
    [string]      $DateAired
    [string]      $Description
    [string]      $CurrEp      # Current episode progress as STRING (supports ranges/specials)
    [string]      $LastEp      # Total/Last episode as STRING
    [hashtable]   $Tags         # Custom metadata tags
    [object[]]    $Episodes     # [AnimeEpisode[]]

    Anime() {
        $this.Status = [AnimeStatus]::Unknown
        $this.Episodes = @()
        $this.CurrEp = ""
        $this.LastEp = ""
        $this.Tags = @{}
    }

    Anime([string]$Name, [string]$Ref) {
        $this.Name = $Name
        $this.Ref = $Ref
        $this.Status = [AnimeStatus]::Unknown
        $this.Episodes = @()
        $this.CurrEp = ""
        $this.LastEp = ""
        $this.Tags = @{}
    }

    # ── Dict constructor (from JSON / history) ────────────────────────────

    Anime([hashtable]$Dict) {
        $this.Name      = if ($Dict['name'])      { $Dict['name'] }       else { "" }
        $this.Ref       = if ($Dict['ref'])       { $Dict['ref'] }        else { "" }
        $this.Image     = if ($Dict['image'])      { $Dict['image'] }      else { "" }
        $this.Url       = if ($Dict['url'])        { $Dict['url'] }         else { "" }
        $this.AnilistId = if ($Dict['anilistId']) { [int]$Dict['anilistId'] } else { 0 }
        $this.Genres    = if ($Dict['genres'])     { $Dict['genres'] }     else { "" }
        $this.Studio    = if ($Dict['studio'])     { $Dict['studio'] }     else { "" }
        $this.Score     = if ($Dict['score'])      { [double]$Dict['score'] } else { 0.0 }
        $this.EpCount   = if ($Dict['epCount'])    { [int]$Dict['epCount'] }   else { 0 }
        $this.DateAired = if ($Dict['dateAired']) { $Dict['dateAired'] }  else { "" }
        $this.Description = if ($Dict['description']) { $Dict['description'] } else { "" }

        $statusStr = if ($Dict['status']) { $Dict['status'] } else { "Unknown" }
        if ($statusStr -is [string]) {
            $this.Status = ConvertFrom-AnimeStatusString $statusStr
        } elseif ($statusStr -is [int]) {
            $this.Status = [AnimeStatus]$statusStr
        } else {
            $this.Status = [AnimeStatus]::Unknown
        }

        $this.CurrEp = if ($Dict['currEp']) { $Dict['currEp'] } else { "" }
        $this.LastEp = if ($Dict['lastEp']) { $Dict['lastEp'] } else { "" }

        $this.Tags = if ($Dict['tags'] -is [hashtable]) { $Dict['tags'] } else { @{} }

        # Reconstruct episodes if present
        $this.Episodes = @()
        $epList = $Dict['episodes']
        if ($epList -and $epList -is [array]) {
            foreach ($ep in $epList) {
                $epObj = if ($ep -is [hashtable]) { [AnimeEpisode]::FromDict($ep) }
                          else { [AnimeEpisode]::new($ep.ToString(), $ep.Ref) }
                $this.Episodes += $epObj
            }
        } elseif ($epList -is [hashtable]) {
            # Episodic dictionary: num -> ref mapping
            foreach ($n in ($epList.Keys | Sort-Object { [double]$_ })) {
                $this.Episodes += [AnimeEpisode]::new($n.ToString(), $epList[$n])
            }
        }
    }

    # ── Episode Management ────────────────────────────────────────────────

    [void] SetEpisodes([hashtable]$EpisodeMap) {
        $this.Episodes = @()
        $nums = @($EpisodeMap.Keys | Sort-Object { [double]$_ })
        foreach ($num in $nums) {
            $this.Episodes += [AnimeEpisode]::new($num.ToString(), $EpisodeMap[$num])
        }
        if ($nums.Count -gt 0) { $this.LastEp = $nums[-1].ToString() }
    }

    [void] UpdateEpisodesEx([hashtable]$EpisodeMap, [bool]$IncludeSpecials) {
        $this.SetEpisodes($EpisodeMap)
        if (-not $IncludeSpecials) {
            $this.Episodes = @($this.Episodes | Where-Object { -not $_.IsSpecial() })
        }
    }

    [void] SetProgress([string]$EpNum) {
        $this.CurrEp = $EpNum
    }

    [void] SetInfo([int]$AniId, [AnimeStatus]$Status, [string]$Genres) {
        if ($AniId -gt 0)    { $this.AnilistId = $AniId }
        if ($Status -ge 0)   { $this.Status = $Status }
        if ($Genres)          { $this.Genres = $Genres }
    }

    # ── Progress helpers ─────────────────────────────────────────────────

    [bool] HasCurrentEpisode() {
        return $null -ne $this.CurrEp -and $this.CurrEp -ne ""
    }

    [string] GetDisplayProgress() {
        if (-not $this.HasCurrentEpisode()) { return "0/$($this.LastEp)" }
        return "$($this.CurrEp)/$($this.LastEp)"
    }

    [int] GetNumericProgress() {
        if (-not $this.HasCurrentEpisode()) { return 0 }
        $lastObj = $this.Episodes | Select-Object -Last 1
        if ($lastObj) {
            $lastNum = $lastObj.ToNumericInt()
            if ($lastNum -gt 0) { return [int]([Math]::Min([double]$this.CurrEp, $lastNum)) }
        }
        $n = 0
        if ([double]::TryParse($this.CurrEp, [ref]$n)) { return [int]$n }
        return 0
    }

    [bool] IsCompleted() {
        $lastObj = $this.Episodes | Select-Object -Last 1
        if (-not $lastObj) { return $false }
        if (-not $this.HasCurrentEpisode()) { return $false }
        return $this.CurrEp -eq $this.LastEp
    }

    [string] ToString() {
        $prog = $this.GetDisplayProgress()
        $statusName = Get-AnimeStatusName $this.Status
        return "$($this.Name) [$prog] ($statusName)"
    }

    [bool] Equals([object]$Other) {
        if ($null -eq $Other) { return $false }
        if ($Other -isnot [Anime]) { return $false }
        return $this.Ref -eq $Other.Ref -and $this.Name -eq $Other.Name
    }

    [int] GetHashCode() {
        return "$($this.Ref):$($this.Name)".GetHashCode()
    }

    # ── Serialization ───────────────────────────────────────────────────

    [hashtable] ToDict() {
        $epDicts = @($this.Episodes | ForEach-Object { $_.ToDict() })
        return @{
            name       = $this.Name
            ref        = $this.Ref
            image      = $this.Image
            url        = $this.Url
            anilistId  = $this.AnilistId
            genres     = $this.Genres
            studio     = $this.Studio
            score      = $this.Score
            epCount    = $this.EpCount
            dateAired  = $this.DateAired
            description= $this.Description
            status     = $this.Status.ToString()
            currEp     = $this.CurrEp
            lastEp     = $this.LastEp
            tags       = $this.Tags
            episodes   = $epDicts
        }
    }
}

 try {
     Export-ModuleMember -Class 'Anime'
 } catch { }