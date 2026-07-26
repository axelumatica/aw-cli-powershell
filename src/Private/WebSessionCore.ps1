#Requires -Version 5.1
# Web session utilities - HTTP client wrapper with cookie and header management.
# No class dependencies.

# ── Session Factory ────────────────────────────────────────────────────────

function New-AwSession {
    <# Creates a new WebRequestSession with default aw-cli headers. #>
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

    # Default headers mirroring the Python requests session
    $session.Headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36 aw-cli/1.0'
    $session.Headers['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
    $session.Headers['Accept-Language'] = 'en-US,en;q=0.5'
    $session.Headers['Accept-Encoding'] = 'gzip, deflate, br'
    $session.Headers['DNT'] = '1'
    $session.Headers['Connection'] = 'keep-alive'
    $session.Headers['Upgrade-Insecure-Requests'] = '1'

    return $session
}

# ── Cookie helpers ─────────────────────────────────────────────────────────

function Add-SessionCookie {
    param(
        [Parameter(Mandatory)]
        [object]$Session,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Value,

        [string]$Domain = '.animeworld.ac',
        [string]$Path = '/'
    )
    try {
        $cookie = New-Object System.Net.Cookie($Name, $Value, $Path, $Domain)
        $session.Cookies.Add($cookie)
    } catch { Write-Warning "Failed to add cookie $Name : $_" }
}

function Get-SessionCookies {
    param([object]$Session)
    if (-not $session -or -not $session.Cookies) { return @() }
    $cookies = @()
    foreach ($cookie in $session.Cookies.GetCookies()) {
        $cookies += [PSCustomObject]@{
            Name    = $cookie.Name
            Value   = $cookie.Value
            Domain  = $cookie.Domain
            Path    = $cookie.Path
            Expires = $cookie.Expires
        }
    }
    return $cookies
}

function Clear-SessionCookies {
    param([object]$Session)
    if (-not $session -or -not $session.Cookies) { return }
    $session.Cookies.Clear()
}

# ── HTTP Request helpers ───────────────────────────────────────────────────

function Invoke-AwRequest {
    <# Makes an HTTP GET request and returns raw content (string for HTML, byte[] for binary). #>
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [object]$Session = $null,

        [string]$Method = 'GET',

        [hashtable]$Headers = @{},

        [int]$TimeoutSec = 30,

        [switch]$Binary
    )
    try {
        $params = @{
            Uri         = $Url
            Method      = $Method
            TimeoutSec  = $TimeoutSec
            ContentType = 'application/x-www-form-urlencoded'
        }
        if ($Session) { $params['WebSession'] = $Session }
        foreach ($k in $Headers.Keys) { $params[$k] = $Headers[$k] }

        if ($Binary) {
            $resp = Invoke-WebRequest @params -ErrorAction Stop
            return $resp.Content
        } else {
            $resp = Invoke-WebRequest @params -ErrorAction Stop
            return $resp.Content
        }
    } catch {
        Write-OutputColor "Request failed [$Url]: $_" -Style error
        return $null
    }
}

function Get-AwHtml {
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [object]$Session = $null
    )
    $html = Invoke-AwRequest -Url $Url -Session $Session -Method GET
    return $html
}

function Invoke-AwJsonRequest {
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [object]$Session = $null,

        [object]$Body = $null,

        [string]$Method = 'POST',

        [hashtable]$Headers = @{}
    )
    try {
        $allHeaders = @{
            'Content-Type' = 'application/json'
            'Accept'      = 'application/json'
        }
        foreach ($k in $Headers.Keys) { $allHeaders[$k] = $Headers[$k] }

        $params = @{
            Uri        = $Url
            Method     = $Method
            Body       = $Body
            WebSession = $Session
            TimeoutSec = 30
        }

        $jsonBody = if ($Body) {
            if ($Body -is [string]) { $Body }
            else { $Body | ConvertTo-Json -Compress }
        } else { $null }

        $resp = Invoke-WebRequest @params -ErrorAction Stop
        if ($resp.Content) {
            return $resp.Content | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
        }
        return $null
    } catch {
        Write-OutputColor "JSON request failed: $_" -Style error
        return $null
    }
}

function Invoke-AwDownload {
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [string]$OutFile,

        [object]$Session = $null,

        [switch]$Resume
    )
    try {
        $params = @{
            Uri        = $Url
            OutFile    = $OutFile
            WebSession = $Session
            TimeoutSec = 300
        }
        if ($Resume) {
            # Use headers to support Range resume
            $existingSize = 0
            if (Test-Path $OutFile) {
                $existingSize = (Get-Item $OutFile).Length
                $params['Headers'] = @{ 'Range' = "bytes=$existingSize-" }
            }
        }
        Invoke-WebRequest @params -ErrorAction Stop | Out-Null
        return $true
    } catch {
        Write-OutputColor "Download failed: $_" -Style error
        return $false
    }
}

# ── Query String helpers ────────────────────────────────────────────────────

function ConvertTo-QueryString {
    param([hashtable]$Params)
    if (-not $Params -or $Params.Count -eq 0) { return "" }
    $parts = @()
    foreach ($k in $Params.Keys) {
        $v = $Params[$k]
        if ($v -ne $null) {
            $encodedKey = [System.Uri]::EscapeDataString($k)
            $encodedVal = [System.Uri]::EscapeDataString($v.ToString())
            $parts += "$encodedKey=$encodedVal"
        }
    }
    return $parts -join '&'
}

function New-FormEncodedBody {
    param([hashtable]$Fields)
    return ConvertTo-QueryString -Params $Fields
}

 try {
     Export-ModuleMember -Function @(
         'New-AwSession', 'Add-SessionCookie', 'Get-SessionCookies', 'Clear-SessionCookies',
         'Invoke-AwRequest', 'Get-AwHtml', 'Invoke-AwJsonRequest', 'Invoke-AwDownload',
         'ConvertTo-QueryString', 'New-FormEncodedBody'
     )
 } catch { }