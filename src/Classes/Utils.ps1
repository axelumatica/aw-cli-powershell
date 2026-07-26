#Requires -Version 5.1
# Utility functions - no class dependencies.

# ── Encoding helpers ──────────────────────────────────────────────────────

function Get-EncodingFromBom {
    param([System.IO.FileInfo]$File)
    $bytes = [System.IO.File]::ReadAllBytes($File.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return [System.Text.Encoding]::UTF8
    }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        return [System.Text.Encoding]::Unicode
    }
    return [System.Text.Encoding]::UTF8
}

function Read-FileContent {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
    }
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

function Write-FileUtf8 {
    param([string]$Path, [string]$Content)
    $encoding = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

# ── String helpers ────────────────────────────────────────────────────────

function Test-LikeAny {
    param([string]$Text, [string[]]$Patterns)
    foreach ($p in $Patterns) {
        if ($Text -like $p) { return $true }
    }
    return $false
}

function Get-NormalizedPath {
    param([string]$Path)
    if (-not $Path) { return "" }
    $p = $Path.Trim()
    $p = $p -replace '/', '\'
    return $p
}

function Remove-InvalidFileNameChars {
    param([string]$Name)
    $re = '[\\\/:*?"<>|]'
    return $Name -replace $re, '_'
}

# ── Console helpers ────────────────────────────────────────────────────────

function Write-OutputColor {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Message,
        [ValidateSet('', 'error', 'warning', 'info', 'success', 'highlight', 'general')]
        [string]$Style = 'general'
    )

    $colorMap = @{
        'error'    = [ConsoleColor]::Red
        'warning'  = [ConsoleColor]::Yellow
        'info'     = [ConsoleColor]::Cyan
        'success'  = [ConsoleColor]::Green
        'highlight'= [ConsoleColor]::Magenta
        'general'  = [ConsoleColor]::White
    }
    $fg = if ($colorMap.ContainsKey($Style)) { $colorMap[$Style] } else { [ConsoleColor]::White }
    $prev = $Host.UI.RawUI.ForegroundColor
    try { $Host.UI.RawUI.ForegroundColor = $fg } catch { }
    Write-Host $Message
    try { $Host.UI.RawUI.ForegroundColor = $prev } catch { }
}

function Clear-Screen {
    if ($Host.Name -eq 'console' -or $null -eq $Host.Name) {
        [Console]::Clear()
    } else {
        Clear-Host
    }
}

# ── Numeric helpers ───────────────────────────────────────────────────────

function Get-NumericValue {
    param([string]$Text)
    if (-not $Text) { return 0 }
    $m = [regex]::Match($Text, '[\d.]+')
    if ($m.Success) {
        $v = if ($m.Value.Contains('.')) { [double]$m.Value } else { [int]$m.Value }
        return $v
    }
    return 0
}

function ConvertTo-MultiValue {
    param([string]$Input)
    if ($Input -match '^\d+$') {
        return @( "[int]$Input", "[string]'$Input'" )
    }
    if ($Input -match '^\d+-\d+$') {
        $parts = $Input -split '-'
        $nums = @()
        for ($n = [int]$parts[0]; $n -le [int]$parts[1]; $n++) {
            $nums += "[int]$n"
        }
        return $nums
    }
    if ($Input -match '^\d+\.\d+$') {
        return @( "[int]$([int][double]$Input)" )
    }
    return @()
}

# ── Date helpers ──────────────────────────────────────────────────────────

function Get-UnixTimestamp {
    return [int]([DateTimeOffset]::Now.ToUnixTimeSeconds())
}

# ── Registry helpers ──────────────────────────────────────────────────────

function Get-OsName {
    if (-not $IsWindows) {
        $uname = uname -a 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $uname) { return "Windows" }
        $parts = $uname -split '\s+'
        $name = $parts[0]
        if ($name -eq 'Linux' -and $parts[-1] -eq 'Android') { return 'Android' }
        if ($parts[2] -match 'WSL') { return 'WSL' }
        return $name
    }
    return "Windows"
}

 try {
     Export-ModuleMember -Function @(
         'Write-OutputColor', 'Clear-Screen',
         'Get-EncodingFromBom', 'Read-FileContent', 'Write-FileUtf8',
         'Test-LikeAny', 'Get-NormalizedPath', 'Remove-InvalidFileNameChars',
         'Get-NumericValue', 'ConvertTo-MultiValue',
         'Get-UnixTimestamp', 'Get-OsName'
     )
 } catch { }