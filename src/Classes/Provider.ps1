#Requires -Version 5.1
# Abstract provider base class.
# Mirrors the Python providers/provider.py interface.
# Depends on: SharedTypes.ps1, AnimeEpisode.ps1, Anime.ps1, WebSessionCore.ps1, Config.ps1

. (Join-Path $PSScriptRoot 'SharedTypes.ps1')
. (Join-Path $PSScriptRoot 'AnimeEpisode.ps1')
. (Join-Path $PSScriptRoot 'Anime.ps1')
. (Join-Path $PSScriptRoot '..\Private\WebSessionCore.ps1')

class Provider {
    hidden [object]   $Session     # WebRequestSession for HTTP ops
    [string]          $BaseUrl
    [string]          $UserAgent
    hidden [hashtable] $_Cache

    Provider([string]$BaseUrl) {
        $this.Session = New-AwSession
        $this.BaseUrl = $BaseUrl
        $this._Cache = @{}
        $this.UserAgent = $this.Session.Headers['User-Agent']
    }

    Provider([string]$BaseUrl, [object]$Session) {
        $this.Session = if ($Session) { $Session } else { New-AwSession }
        $this.BaseUrl = $BaseUrl
        $this._Cache = @{}
        $this.UserAgent = $this.Session.Headers['User-Agent']
    }

    # ── Public API ─────────────────────────────────────────────────────

    [object[]] Search([string]$Input) {
        $result = $this._SearchImpl($Input)
        foreach ($anime in $result) {
            $anime.Name = $this._SanitizeName($anime.Name)
        }
        return $result
    }

    [object[]] Latest([string]$Filter) {
        $specials = Get-ConfigValue -Key 'general.specials' -Default $false
        return $this._LatestImpl($Filter, $specials)
    }

    [void] FetchEpisodes([object]$Anime) {
        $specials = Get-ConfigValue -Key 'general.specials' -Default $false
        $this._FetchEpisodesImpl($Anime, $specials)
    }

    [void] LoadAnimeInfo([object]$Anime) {
        $this._InfoAnimeImpl($Anime)
    }

    [string] GetEpisodeLink([object]$Anime, [object]$Episode) {
        return $this._EpisodeLinkImpl($Anime, $Episode)
    }

    # ── Protected Virtual Methods (override in subclasses) ──────────────

    hidden [object[]] _SearchImpl([string]$Input) {
        throw "NotImplementedException: _SearchImpl must be implemented by subclass"
    }

    hidden [object[]] _LatestImpl([string]$Filter, [bool]$Specials) {
        throw "NotImplementedException: _LatestImpl must be implemented by subclass"
    }

    hidden [void] _FetchEpisodesImpl([object]$Anime, [bool]$Specials) {
        $episodes = $this._EpisodesImpl($Anime)
        $Anime.UpdateEpisodesEx($episodes, $Specials)
    }

    hidden [hashtable] _EpisodesImpl([object]$Anime) {
        throw "NotImplementedException: _EpisodesImpl must be implemented by subclass"
    }

    hidden [string] _EpisodeLinkImpl([object]$Anime, [object]$Episode) {
        throw "NotImplementedException: _EpisodeLinkImpl must be implemented by subclass"
    }

    hidden [void] _InfoAnimeImpl([object]$Anime) {
        # Default: no-op. Override in subclasses.
    }

    # ── Protected Helpers ───────────────────────────────────────────────

    hidden [string] _SanitizeName([string]$Name) {
        $replacements = @{
            '"' = '"';    '/' = '/';   ':' = ':';   '<' = '<';
            '>' = '>';    '?' = '?';   '\' = '\';   '|' = '|';
            '*' = '*'
        }
        foreach ($char in $replacements.Keys) {
            $Name = $Name.Replace($char, $replacements[$char])
        }
        return $Name.Trim()
    }

    hidden [string] HtmlDecode([string]$Text) {
        $entities = @{
            '&'  = '&';   '<'  = '<';  '>'  = '>';
            '"' = '"';   '&apos;' = "'";  '&nbsp;' = ' '
        }
        foreach ($e in $entities.Keys) {
            $Text = $Text.Replace($e, $entities[$e])
        }
        return $Text
    }

    hidden [string] _GetCached([string]$Key) {
        if ($this._Cache.ContainsKey($Key)) { return $this._Cache[$Key] }
        return $null
    }

    hidden [void] _SetCached([string]$Key, [object]$Value) {
        $this._Cache[$Key] = $Value
    }
}

# ── Provider Factory ─────────────────────────────────────────────────────

function New-Provider {
    param(
        [ValidateSet('animeworld', 'animeunity', 'local')]
        [string]$Name = 'animeworld',

        [object]$Session = $null
    )
    switch ($Name) {
        'animeworld' {
            . (Join-Path $PSScriptRoot '..\Private\Providers\Animeworld.ps1')
            if ($Session) { return [Animeworld]::new($Session) }
            return [Animeworld]::new()
        }
        'animeunity' {
            . (Join-Path $PSScriptRoot '..\Private\Providers\Animeunity.ps1')
            if ($Session) { return [Animeunity]::new($Session) }
            return [Animeunity]::new()
        }
        'local' {
            . (Join-Path $PSScriptRoot '..\Private\Providers\LocalProvider.ps1')
            return [LocalProvider]::new()
        }
        default {
            . (Join-Path $PSScriptRoot '..\Private\Providers\Animeworld.ps1')
            return [Animeworld]::new()
        }
    }
}

 try {
     Export-ModuleMember -Function 'New-Provider'
 } catch { }