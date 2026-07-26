#Requires -Version 5.1
# Native console TUI - replaces fzf with PowerShell-native arrow-key menus.

function Show-Menu {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]]$Items,

        [string]$Prompt = "> ",

        [switch]$MultiSelect,

        [switch]$FilterMode,

        [scriptblock]$ItemDisplay
    )

    begin { $allItems = @($Items) }
    process { foreach ($i in $Items) { $allItems += $i } }
    end {
        if ($allItems.Count -eq 0) { return $null }
        return _ShowConsoleMenu -Items $allItems -Prompt $Prompt `
            -MultiSelect:$MultiSelect -FilterMode:$FilterMode -ItemDisplay $ItemDisplay
    }
}

function _ShowConsoleMenu {
    param(
        [object[]]$Items,
        [string]$Prompt,
        [bool]$MultiSelect,
        [bool]$FilterMode,
        $ItemDisplay
    )

    # Build display lines
    $lines = @()
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $text = if ($ItemDisplay) { & $ItemDisplay $Items[$i] $i } else { _DefaultDisplay $Items[$i] $i }
        $lines += [PSCustomObject]@{
            Index    = $i
            Item     = $Items[$i]
            Text     = $text
            Selected = $false
        }
    }
    $lines[0].Selected = $true

    while ($true) {
        Clear-ConsoleScreen
        Write-Host ""
        Write-Host "  $Prompt" -ForegroundColor Cyan
        Write-Host "  ($($lines.Count) elementi)" -ForegroundColor DarkGray
        Write-Host ""

        $pageSize = if ($Host.UI.RawUI.WindowSize.Height -gt 0) { $Host.UI.RawUI.WindowSize.Height - 10 } else { 20 }
        if ($pageSize -lt 5) { $pageSize = 20 }
        $pageLines = $lines | Select-Object -First $pageSize

        for ($pi = 0; $pi -lt $pageLines.Count; $pi++) {
            $line = $pageLines[$pi]
            $numStr = "$($line.Index + 1)"
            if ($line.Selected) {
                Write-Host "  $($numStr) " -NoNewline -ForegroundColor Yellow
                Write-Host ">" -NoNewline -ForegroundColor Yellow
                Write-Host "  $numStr" -NoNewline -ForegroundColor White
                Write-Host " - $($line.Text)" -ForegroundColor White
            } else {
                Write-Host "  $($numStr)    $($line.Text)" -ForegroundColor DarkGray
            }
        }

        Write-Host ""
        $navHelp = "↑↓ naviga  | Enter conferma  | Esc esci"
        if ($MultiSelect) { $navHelp += "  | Ctrl+A seleziona tutto" }
        Write-Host "  $navHelp" -ForegroundColor DarkGray
        if ($FilterMode) { Write-Host "  Digita per filtrare" -ForegroundColor DarkGray }

        $key = _ReadKey
        if ($null -eq $key) { return $null }

        # Find selected index
        $selIdx = 0
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i].Selected) { $selIdx = $i; break }
        }

        $keyStr = $key.KeyDown.ToString()
        $mods   = $key.Modifiers.ToString()

        if ($mods -eq 'Control') {
            if ($keyStr -eq 'A' -and $MultiSelect) {
                $allSel = (($lines | Where-Object { $_.Selected }).Count) -eq $lines.Count
                foreach ($l in $lines) { $l.Selected = -not $allSel }
            }
            if ($keyStr -in 'C', 'Escape') { return $null }
            continue
        }

        switch ($keyStr) {
            'UpArrow' {
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    if ($lines[$i].Selected -and $i -gt 0) {
                        $lines[$i].Selected = $false
                        $lines[$i - 1].Selected = $true
                        break
                    }
                }
            }
            'DownArrow' {
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    if ($lines[$i].Selected -and $i -lt $lines.Count - 1) {
                        $lines[$i].Selected = $false
                        $lines[$i + 1].Selected = $true
                        break
                    }
                }
            }
            'Enter' {
                $selected = @($lines | Where-Object { $_.Selected })
                if ($selected.Count -eq 0) { return $null }
                if ($MultiSelect) { return @($selected | ForEach-Object { $_.Item }) }
                return $selected[0].Item
            }
            'Escape' { return $null }
            default {
                if ($FilterMode -and $key.Character) {
                    $filterQ = $key.Character
                    $filtered = @($lines | Where-Object { $_.Text -like "*$filterQ*" })
                    if ($filtered.Count -eq 0) { continue }
                    foreach ($l in $lines) { $l.Selected = $false }
                    $filtered[0].Selected = $true
                }
            }
        }
    }
}

function _ReadKey {
    try {
        return $Host.UI.RawUI.ReadKey("NoEcho, AllowCtrlC, IncludeKeyUp")
    } catch { return $null }
}

function _DefaultDisplay([object]$Item, [int]$Index) {
    if ($Item -is [string]) { return $Item }
    if ($Item.PSObject.TypeNames -and $Item.PSObject.TypeNames -contains 'Anime') {
        return "$($Item.Name) [Ep $($Item.CurrEp)/$($Item.LastEp)]"
    }
    if ($Item.PSObject.TypeNames -and $Item.PSObject.TypeNames -contains 'AnimeEpisode') {
        return "Ep. $($Item.Num)"
    }
    if ($Item.Name) { return "$($Item.Name)" }
    return $Item.ToString()
}

function Show-YesNoPrompt {
    param(
        [string]$Message,
        [string]$Yes = "s",
        [string]$No = "n"
    )
    $choices = "$Yes/$No"
    while ($true) {
        $answer = Read-Host "$Message ($choices)"
        if ($answer -eq $Yes -or $answer -eq $Yes.ToUpper()) { return $true }
        if ($answer -eq $No  -or $answer -eq $No.ToUpper())  { return $false }
        Write-OutputColor "Seleziona una risposta valida!" -Style error
    }
}

function Show-ListPrompt {
    param(
        [string]$Message,
        [string[]]$Options,
        [int]$DefaultIndex = 0
    )
    for ($i = 0; $i -lt $Options.Count; $i++) {
        $marker = if ($i -eq $DefaultIndex) { "[>]" } else { "[ ]" }
        Write-Host "  $marker $($Options[$i])"
    }
    Write-Host ""
    $answer = Read-Host "$Message [$($DefaultIndex + 1)]"
    if (-not $answer) { return $Options[$DefaultIndex] }
    $idx = [int]$answer - 1
    if ($idx -lt 0 -or $idx -ge $Options.Count) { return $Options[$DefaultIndex] }
    return $Options[$idx]
}

 try {
     Export-ModuleMember -Function 'Show-Menu', 'Show-YesNoPrompt', 'Show-ListPrompt'
 } catch { }