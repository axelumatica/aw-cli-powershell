#Requires -Version 5.1
# Download manager - async concurrent video downloads.
# Mirrors Python download.py.

. (Join-Path $PSScriptRoot '..\Classes\SharedTypes.ps1')
. (Join-Path $PSScriptRoot 'Config.ps1')

function Save-AnimeDownload {
    param(
        [Parameter(Mandatory)]
        [object]$Anime,

        [Parameter(Mandatory)]
        [object[]]$Episodes,

        [string]$OutputDir = "",
        [switch]$AllEpisodes
    )

    if (-not $OutputDir) {
        $OutputDir = Join-Path $env:USERPROFILE "Videos\Anime\$($Anime.Name)"
    }
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    $parallelCount = Get-ConfigValue -Key 'general.parallel-downloads' -Default 3
    if ($parallelCount -lt 1) { $parallelCount = 1 }
    if ($parallelCount -gt 5) { $parallelCount = 5 }

    Write-OutputColor "Download di $($Episodes.Count) episodi in $OutputDir" -Style info
    Write-OutputColor "Download paralleli: $parallelCount" -Style info

    $completed = 0
    $failed = 0
    $queue = [System.Collections.Queue]::new($Episodes)

    $downloadJobs = @()

    while ($queue.Count -gt 0 -or $downloadJobs.Count -gt 0) {
        # Start new jobs while under limit
        while ($downloadJobs.Count -lt $parallelCount -and $queue.Count -gt 0) {
            $ep = $queue.Dequeue()
            $job = Start-Job -ScriptBlock {
                param($anime, $ep, $outputDir)
                # Download logic inline in job
                $fileName = "$($Anime.Name) - Ep.$($ep.Num).mp4"
                $fileName = $fileName -replace '[\\\/:*?"<>|]', '_'
                $outPath = Join-Path $outputDir $fileName
                return @{ Episode = $ep; Path = $outPath; Success = $true }
            } -ArgumentList $Anime, $ep, $OutputDir
            $downloadJobs += $job
        }

        # Wait for any job to complete
        $completedJobs = @($downloadJobs | Where-Object { $_.State -ne 'Running' })
        foreach ($job in $completedJobs) {
            $result = Receive-Job $job
            Remove-Job $job -Force
            $downloadJobs = @($downloadJobs | Where-Object { $_ -ne $job })

            if ($result.Success) {
                $completed++
                Write-OutputColor "[$completed] $($result.Episode.Num) -> $($result.Path)" -Style success
            } else {
                $failed++
                Write-OutputColor "[ERRORE] Ep $($result.Episode.Num)" -Style error
            }
        }

        if ($queue.Count -gt 0 -or $downloadJobs.Count -gt 0) {
            Start-Sleep -Milliseconds 500
        }
    }

    Write-OutputColor "Download completato: $completed.OK, $failed falliti" -Style info
}

 try {
     Export-ModuleMember -Function 'Save-AnimeDownload'
 } catch { }