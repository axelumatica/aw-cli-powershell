#Requires -Version 5.1
# Configuration and console output utilities.
# Depends on: Utils.ps1

. (Join-Path $PSScriptRoot '..\Classes\SharedTypes.ps1')

# ── Default Style ──────────────────────────────────────────────────────────

$script:DefaultStyle = @{
    error     = "red"
    prompt    = "cyan"
    warning   = "yellow"
    success   = "green"
    info      = "yellow"
    highlight = "cyan"
    general   = "white"
}

# ── Module-level Config State ─────────────────────────────────────────────

$script:ConfigPath  = $null
$script:ConfigData  = @{}

# ── Path helpers ───────────────────────────────────────────────────────────

function Get-ConfigPath {
    if (-not $script:ConfigPath) {
        $baseDir = Split-Path $PSScriptRoot -Parent
        if (-not $baseDir) { $baseDir = $PSScriptRoot }
        $script:ConfigPath = Join-Path $baseDir "config.json"
    }
    return $script:ConfigPath
}

# ── Config CRUD ────────────────────────────────────────────────────────────

function Get-ConfigValue {
    param(
        [Parameter(Mandatory)]
        [string]$Key,

        [object]$Default = $null
    )
    $parts = $Key.Split('.')
    $current = $script:ConfigData
    foreach ($p in $parts) {
        if ($current -is [hashtable] -and $current.ContainsKey($p)) {
            $current = $current[$p]
        } else { return $Default }
    }
    return $current
}

function Set-ConfigValue {
    param(
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [object]$Value
    )
    $parts = $Key.Split('.')
    $current = $script:ConfigData
    for ($i = 0; $i -lt $parts.Count - 1; $i++) {
        $p = $parts[$i]
        if (-not $current.ContainsKey($p)) { $current[$p] = @{} }
        $current = $current[$p]
    }
    $current[$parts[-1]] = $Value
}

# ── Persistence ───────────────────────────────────────────────────────────

function Import-Config {
    $path = Get-ConfigPath
    if (Test-Path $path) {
        try {
            $json = Get-Content $path -Raw -ErrorAction SilentlyContinue
            if ($json) {
                $script:ConfigData = $json | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
                if (-not $script:ConfigData) { $script:ConfigData = @{} }
            }
        } catch {
            $script:ConfigData = @{}
        }
    } else { $script:ConfigData = @{} }

    # Merge defaults if missing
    if (-not $script:ConfigData.ContainsKey('player'))   { $script:ConfigData['player']   = @{} }
    if (-not $script:ConfigData.ContainsKey('provider'))  { $script:ConfigData['provider']  = @{ 'source' = 'animeworld' } }
    if (-not $script:ConfigData.ContainsKey('general'))   {
        $script:ConfigData['general'] = @{
            'specials'           = $false
            'parallel-downloads' = 3
        }
    }
    if (-not $script:ConfigData.ContainsKey('style'))    { $script:ConfigData['style']    = $script:DefaultStyle }

    # Set console title
    try { $Host.UI.RawUI.WindowTitle = "aw-cli" } catch { }
}

function Export-Config {
    $path = Get-ConfigPath
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $json = $script:ConfigData | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding $false))
}

function Initialize-Config {
    $path = Get-ConfigPath
    if (-not (Test-Path $path)) {
        $script:ConfigData = @{
            'player'   = @{ 'type' = 'mpv'; 'path' = 'mpv' }
            'provider' = @{ 'source' = 'animeworld' }
            'anilist'  = @{}
            'general'  = @{ 'specials' = $false; 'parallel-downloads' = 3 }
            'syncplay' = @{}
            'style'    = $script:DefaultStyle
        }
        Export-Config
    }
}

# ── Console output (mirrors Python Rich) ────────────────────────────────────

function Write-OutputColor {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Message,

        [ValidateSet('', 'error', 'warning', 'info', 'success', 'highlight', 'general')]
        [string]$Style = 'general'
    )
    $colorMap = @{
        'error'     = [ConsoleColor]::Red
        'warning'   = [ConsoleColor]::Yellow
        'info'      = [ConsoleColor]::Cyan
        'success'   = [ConsoleColor]::Green
        'highlight' = [ConsoleColor]::Magenta
        'general'   = [ConsoleColor]::White
    }
    $fg = if ($colorMap.ContainsKey($Style)) { $colorMap[$Style] } else { [ConsoleColor]::White }
    $prev = $Host.UI.RawUI.ForegroundColor
    try { $Host.UI.RawUI.ForegroundColor = $fg } catch { }
    Write-Host $Message
    try { $Host.UI.RawUI.ForegroundColor = $prev } catch { }
}

function Clear-ConsoleScreen {
    if ($Host.Name -eq 'console' -or $null -eq $Host.Name) { [Console]::Clear() }
    else { Clear-Host }
}

# Load on import
Import-Config

 Export-ModuleMember -Function @(
         'Get-ConfigPath', 'Get-ConfigValue', 'Set-ConfigValue',
         'Import-Config', 'Export-Config', 'Initialize-Config',
         'Write-OutputColor', 'Clear-ConsoleScreen'
     )
 