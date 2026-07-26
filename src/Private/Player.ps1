#Requires -Version 5.1
# Player abstraction layer - auto-detects and launches media players.
# Supports: mpv, vlc, screenbox (UWP), photos (UWP).

. (Join-Path $PSScriptRoot '..\Classes\SharedTypes.ps1')
. (Join-Path $PSScriptRoot 'WebSessionCore.ps1')

class PlayerInfo {
    [string] $Name
    [string] $Type      # 'mpv', 'vlc', 'uwp'
    [string] $Path
    [bool]   $SupportsResume

    PlayerInfo([string]$N, [string]$T, [string]$P, [bool]$SR) {
        $this.Name = $N; $this.Type = $T; $this.Path = $P; $this.SupportsResume = $SR
    }

    [bool] IsInstalled() {
        if ($this.Type -eq 'uwp') {
            return $null -ne (Get-AppxPackage -Name $this.Path -ErrorAction SilentlyContinue)
        }
        if ($this.Path) {
            $exePath = if (Test-Path $this.Path) { $this.Path } else { $null }
            if (-not $exePath) {
                try { $c = Get-Command $this.Path -ErrorAction SilentlyContinue; if ($c) { $exePath = $c.Source } } catch { }
            }
            return $null -ne $exePath
        }
        return $false
    }
}

function Find-AvailablePlayers {
    $avail = @{}
    $cfgType = Get-ConfigValue -Key 'player.type' -Default ''
    $cfgPath = Get-ConfigValue -Key 'player.path' -Default ''

    $defs = @{
        'mpv'      = [PlayerInfo]::new('mpv',      'mpv',  'mpv',                                    $true)
        'vlc'      = [PlayerInfo]::new('vlc',      'vlc',  'vlc',                                    $true)
        'screenbox'= [PlayerInfo]::new('screenbox', 'uwp',  'Microsoft.Screenbox',                   $false)
        'photos'   = [PlayerInfo]::new('photos',   'uwp',  'Microsoft.Windows.Photos',              $false)
    }

    foreach ($key in @('mpv', 'vlc', 'screenbox', 'photos')) {
        $p = $defs[$key]
        if ($key -eq $cfgType -and $cfgPath) { $p.Path = $cfgPath }
        else { $p.Path = _DetectPlayerPath $key }
        if ($p.IsInstalled()) { $avail[$key] = $p }
    }
    return $avail
}

function Get-DetectedPlayer {
    $avail = Find-AvailablePlayers
    foreach ($name in @('mpv', 'vlc', 'screenbox', 'photos')) {
        if ($avail.ContainsKey($name)) { return $avail[$name] }
    }
    return $null
}

function _DetectPlayerPath([string]$Name) {
    switch ($Name) {
        'mpv' {
            $cmd = Get-Command 'mpv' -ErrorAction SilentlyContinue
            if ($cmd) { return $cmd.Source }
            foreach ($p in @("${env:ProgramFiles}\mpv\mpv.exe", "${env:ProgramFiles(x86)}\mpv\mpv.exe", "C:\mpv\mpv.exe")) {
                if (Test-Path $p) { return $p }
            }
        }
        'vlc' {
            $cmd = Get-Command 'vlc' -ErrorAction SilentlyContinue
            if ($cmd) { return $cmd.Source }
            foreach ($p in @("${env:ProgramFiles}\VideoLAN\VLC\vlc.exe", "${env:ProgramFiles(x86)}\VideoLAN\VLC\vlc.exe")) {
                if (Test-Path $p) { return $p }
            }
        }
        'screenbox' { return 'Microsoft.Screenbox' }
        'photos'    { return 'Microsoft.Windows.Photos' }
    }
    return $null
}

function Invoke-MediaPlayer {
    param(
        [string]$MediaPath,
        [string]$Title = "",
        [int]$ResumePosition = 0,
        [string]$PlayerName = ""
    )

    if (-not $PlayerName) {
        $PlayerName = Get-ConfigValue -Key 'player.type' -Default ''
        if (-not $PlayerName) {
            $detected = Get-DetectedPlayer
            if ($detected) { $PlayerName = $detected.Name }
        }
    }

    $avail = Find-AvailablePlayers
    if (-not $avail.ContainsKey($PlayerName)) {
        foreach ($n in @('mpv', 'vlc', 'screenbox', 'photos')) {
            if ($avail.ContainsKey($n)) { $PlayerName = $n; break }
        }
    }
    if (-not $PlayerName -or -not $avail.ContainsKey($PlayerName)) {
        Write-OutputColor "Nessun player installato. Installa mpv o vlc." -Style error
        return @{ Completed = $false; Progress = $ResumePosition }
    }

    $player = $avail[$PlayerName]
    if ($Title) { Write-OutputColor "Riproduco $Title con $PlayerName..." -Style info }

    $fileArg = $MediaPath
    if ($MediaPath -notmatch '^https?://') {
        if (Test-Path $MediaPath -ErrorAction SilentlyContinue) {
            $abs = (Resolve-Path $MediaPath -ErrorAction SilentlyContinue).Path
            if ($abs) {
                $fileArg = "file:///$($abs -replace '\\', '/' -replace ' ', '%20')"
            }
        }
    }

    switch ($PlayerName) {
        'mpv'      { return _LaunchMpv $player $fileArg $Title $ResumePosition }
        'vlc'      { return _LaunchVlc $player $fileArg $Title $ResumePosition }
        'screenbox'{ return _LaunchUwp $player $fileArg $Title $ResumePosition }
        'photos'   { return _LaunchUwp $player $fileArg $Title $ResumePosition }
        default    { return @{ Completed = $false; Progress = $ResumePosition } }
    }
}

function _LaunchMpv {
    param([PlayerInfo]$P, [string]$File, [string]$Title, [int]$Resume)

    $mpvPath = $P.Path
    if (-not (Test-Path $mpvPath)) {
        $cmd = Get-Command $mpvPath -ErrorAction SilentlyContinue
        if ($cmd) { $mpvPath = $cmd.Source }
        else { $mpvPath = "mpv" }
    }

    $args = @($File, "--force-media-title=$Title", "--fullscreen", "--keep-open")
    if ($Resume -gt 0) { $args += "--start=$Resume" }

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $mpvPath
        $psi.Arguments = $args -join ' '
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $false

        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()

        # Parse progress from mpv output
        $progressMatches = [regex]::Matches($stdout, '(\d+):(\d+):(\d+) / [\d:]+\s*\((\d+)%\)')
        $lastMatch = $progressMatches | Select-Object -Last 1
        if ($lastMatch) {
            $h = [int]$lastMatch.Groups[1].Value
            $m = [int]$lastMatch.Groups[2].Value
            $s = [int]$lastMatch.Groups[3].Value
            $pct = [int]$lastMatch.Groups[4].Value
            $final = ($h * 3600) + ($m * 60) + $s
            return @{ Completed = ($pct -ge 90); Progress = $final }
        }
        return @{ Completed = $true; Progress = $Resume }
    } catch {
        Write-OutputColor "Errore avviando MPV: $_" -Style error
        return @{ Completed = $false; Progress = $Resume }
    }
}

function _LaunchVlc {
    param([PlayerInfo]$P, [string]$File, [string]$Title, [int]$Resume)

    $vlcPath = $P.Path
    if (-not (Test-Path $vlcPath)) {
        $cmd = Get-Command $vlcPath -ErrorAction SilentlyContinue
        if ($cmd) { $vlcPath = $cmd.Source }
        else { $vlcPath = "vlc" }
    }

    $quotedFile = $File -replace '"', '`"'
    $args = @($quotedFile, "--meta-title=`"$Title`"", "--fullscreen")
    if ($Resume -gt 0) { $args += "--start-time=$Resume" }

    Start-Process -FilePath $vlcPath -ArgumentList ($args -join ' ') -NoNewWindow
    return @{ Completed = $true; Progress = $Resume }
}

function _LaunchUwp {
    param([PlayerInfo]$P, [string]$File, [string]$Title, [int]$Resume)

    try {
        $aumid = $P.Path
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "explorer.exe"
        $psi.Arguments = "shell:AppsFolder\$aumid $File"
        $psi.UseShellExecute = $true
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    } catch {
        # Fallback: open with default handler
        Start-Process $File
    }
    return @{ Completed = $true; Progress = $Resume }
}

 try {
     Export-ModuleMember -Function 'Find-AvailablePlayers', 'Get-DetectedPlayer', 'Invoke-MediaPlayer'
 } catch { }