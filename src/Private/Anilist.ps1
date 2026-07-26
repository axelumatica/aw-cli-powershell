#Requires -Version 5.1
# AniList GraphQL integration.
# Mirrors the Python anilist.py.

. (Join-Path $PSScriptRoot '..\Classes\SharedTypes.ps1')
. (Join-Path $PSScriptRoot 'Config.ps1')

function Update-AniListEntry {
    param(
        [int]$AniListId,
        [int]$EpisodeNum,
        [int]$Rating,
        [switch]$Favorite,
        [switch]$Dropped
    )
    $token = Get-ConfigValue -Key 'anilist.token' -Default ''
    if (-not $token) { return $false }

    $status = if ($Dropped) { 'DROPPED' } elseif ($Favorite) { 'REPEATING' } else { 'WATCHING' }

    $mutation = @"
mutation {
    SaveMediaListEntry(
        mediaId: $AniListId,
        status: $status,
        progress: $EpisodeNum
        $(if ($Rating -gt 0) { ", score: $Rating" })
    ) {
        id
        status
        progress
        score
    }
}
"@

    try {
        $resp = Invoke-WebRequest -Uri 'https://graphql.anilist.co' `
            -Method POST `
            -Headers @{
                'Authorization' = "Bearer $token"
                'Content-Type'  = 'application/json'
            } `
            -Body ($mutation | ConvertTo-Json -Compress) `
            -TimeoutSec 15 `
            -ErrorAction SilentlyContinue
        return $null -ne $resp
    } catch {
        Write-OutputColor "AniList update failed: $_" -Style warning
        return $false
    }
}

function Get-AniListUserId {
    $token = Get-ConfigValue -Key 'anilist.token' -Default ''
    if (-not $token) { return 0 }

    $savedId = Get-ConfigValue -Key 'anilist.user_id' -Default 0
    if ($savedId -and $savedId -gt 0) { return $savedId }

    $query = '{ Viewer { id name } }'
    try {
        $resp = Invoke-WebRequest -Uri 'https://graphql.anilist.co' `
            -Method POST `
            -Headers @{ 'Authorization' = "Bearer $token"; 'Content-Type' = 'application/json' } `
            -Body ($query | ConvertTo-Json -Compress) `
            -TimeoutSec 15 `
            -ErrorAction SilentlyContinue

        if ($resp -and $resp.Content) {
            $data = $resp.Content | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
            $uid = $data['data']['viewer']['id']
            if ($uid) {
                Set-ConfigValue -Key 'anilist.user_id' -Value $uid
                return $uid
            }
        }
    } catch { }
    return 0
}

function Get-AnimeAniListRating {
    param([int]$AniListId)
    $token = Get-ConfigValue -Key 'anilist.token' -Default ''
    if (-not $token -or $AniListId -le 0) { return 0 }

    $query = "query { Media(id: $AniListId) { averageScore siteUrl } }"
    try {
        $resp = Invoke-WebRequest -Uri 'https://graphql.anilist.co' `
            -Method POST `
            -Headers @{ 'Authorization' = "Bearer $token"; 'Content-Type' = 'application/json' } `
            -Body ($query | ConvertTo-Json -Compress) `
            -TimeoutSec 15 `
            -ErrorAction SilentlyContinue

        if ($resp -and $resp.Content) {
            $data = $resp.Content | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
            $score = $data['data']['media']['averageScore']
            return if ($score) { $score } else { 0 }
        }
    } catch { }
    return 0
}

 Export-ModuleMember -Function @(
         'Update-AniListEntry',
         'Get-AniListUserId',
         'Get-AnimeAniListRating'
     )
 