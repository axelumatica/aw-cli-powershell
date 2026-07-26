#Requires -Version 5.1
# AnimeEpisode class - represents a single anime episode.
# Episode numbers are STRINGS to support ranges ("1-12") and specials ("1.5").

. (Join-Path $PSScriptRoot 'SharedTypes.ps1')

class AnimeEpisode {
    [string]    $Num      # Episode number (string: "1", "12-24", "1.5")
    [string]    $Ref      # Provider-specific reference (URL segment, ID, or filename)
    [string]    $Title    # Episode title (optional)
    [long]       $Duration  # Duration in seconds
    [string]    $DateAired # Air date string
    [long]       $FileSize   # File size in bytes
    [long]       $WatchedPos # Resume position (seconds)
    [bool]       $IsCompleted

    AnimeEpisode() { }

    AnimeEpisode([string]$Num, [string]$Ref) {
        $this.Num = $Num
        $this.Ref = $Ref
    }

    AnimeEpisode([string]$Num, [string]$Ref, [string]$Title) {
        $this.Num = $Num
        $this.Ref = $Ref
        $this.Title = $Title
    }

    # ── Numeric conversion for sorting ───────────────────────────────────

    [double] ToNumericInt() {
        if (-not $this.Num) { return 0.0 }
        $n = $this.Num.Trim()
        # Range: use max value
        if ($n -match '^(\d+)-') { return [double]$matches[1] }
        # Special: drop decimal part (1.5 -> 1.0)
        if ($n -match '^\d+\.\d+$') { return [Math]::Floor([double]$n) }
        # Plain number
        $try = 0
        if ([double]::TryParse($n, [ref]$try)) { return $try }
        return 0.0
    }

    [bool] IsSpecial() {
        if (-not $this.Num) { return $false }
        return $this.Num.Contains('.')
    }

    [bool] IsRange() {
        if (-not $this.Num) { return $false }
        return $this.Num.Contains('-')
    }

    [string] ToString() {
        $s = "Ep. $($this.Num)"
        if ($this.Title) { $s += " - $($this.Title)" }
        return $s
    }

    # ── Equality ─────────────────────────────────────────────────────────

    [bool] Equals([object]$Other) {
        if ($null -eq $Other) { return $false }
        if ($Other -isnot [AnimeEpisode]) { return $false }
        return $this.Ref -eq $Other.Ref -and $this.Num -eq $Other.Num
    }

    [int] GetHashCode() {
        return "$($this.Ref):$($this.Num)".GetHashCode()
    }

    [bool] IsCompleted() {
        return $this.IsCompleted -or $this.WatchedPos -gt 0
    }

    [void] MarkCompleted() {
        $this.IsCompleted = $true
        $this.WatchedPos = 0
    }

    # ── Serialization ─────────────────────────────────────────────────────

    [hashtable] ToDict() {
        return @{
            Num         = $this.Num
            Ref         = $this.Ref
            Title       = $this.Title
            Duration    = $this.Duration
            DateAired   = $this.DateAired
            FileSize    = $this.FileSize
            WatchedPos  = $this.WatchedPos
            IsCompleted = $this.IsCompleted
        }
    }

    static [object] FromDict([hashtable]$Dict) {
        $ep = [AnimeEpisode]::new()
        $ep.Num         = if ($Dict['num'])       { $Dict['num'] }       else { "" }
        $ep.Ref         = if ($Dict['ref'])        { $Dict['ref'] }        else { "" }
        $ep.Title        = if ($Dict['title'])      { $Dict['title'] }      else { "" }
        $ep.Duration     = if ($Dict['duration'])   { [long]$Dict['duration']   } else { 0L }
        $ep.DateAired    = if ($Dict['dateaired'])  { $Dict['dateaired']  } else { "" }
        $ep.FileSize     = if ($Dict['filesize'])   { [long]$Dict['filesize']   } else { 0L }
        $ep.WatchedPos   = if ($Dict['watchedpos']) { [long]$Dict['watchedpos'] } else { 0L }
        $ep.IsCompleted  = if ($Dict['completed'])  { [bool]$Dict['completed']  } else { $false }
        return $ep
    }
}

 Export-ModuleMember -Class 'AnimeEpisode'
 