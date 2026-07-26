# Memory Index

- [aw-cli-powershell-context](memory/aw-cli-powershell-context.md) — Project context for aw-cli Python to PowerShell port. Phase 1 complete (directory scan + architecture analysis). Phase 2+ pending.

Goal: Port the Python-based `aw-cli` anime CLI to native PowerShell module + standalone EXE.

## Critical Constraints

1. **CLI Only** — No GUI. Must run entirely in Console/Terminal.
2. **PS2EXE: NO `-NoConsole` flag** — The EXE must open a console window for I/O.
3. **Windows Native** — Support Screenbox, Photos App, MPV, VLC natively (no WSL/Python).
4. **Phased Work** — 5 phases, wait for user confirmation between each.
5. **shell: powershell** — Use Windows PowerShell 5.1 syntax in CI/CD (not `pwsh`).

## Final Repository Structure

```
aw-cli/
├── src/
│   ├── aw-cli.psm1          # Main module (dot-sources Public/Private)
│   ├── aw-cli.psd1           # Manifest (ModuleVersion synced with Git Tag)
│   ├── Public/               # Exported functions
│   ├── Private/              # Internal helpers
│   └── Classes/              # [Anime], [AnimeEpisode], [AnimeStatus]
├── tools/
│   ├── build.ps1             # PS2EXE compilation (no -NoConsole!)
│   └── install.ps1           # Bootstrap installer
├── .github/workflows/
│   └── release.yml           # CI/CD: build, version, release
└── README.md
```

## 5-Phase Execution Plan

| Phase | Status | Description |
|-------|--------|-------------|
| 1: Analysis & Architecture | **COMPLETE** | Scanned repo, mapped Python logic, defined PS folder structure |
| 2: Core Porting | **COMPLETE** | All Phase 2 files written — HTTP session/WebSession layer, Anime/Episode/Status classes, Provider factory, Animeworld + Animeunity + LocalProvider implementations, Config JSON, History JSON, root module aw-cli.psm1 |
| 3: Player & UI | **COMPLETE** | Player abstraction (Screenbox/Photos/MPV/VLC, UWP AppFolder launch), native console TUI (Show-Menu with arrow-key navigation, replaces fzf) |
| 4: Packaging | **COMPLETE** | .psd1 manifest (FunctionsToExport explicit, PowerShellVersion 5.1, ModuleVersion 1.0.0), tools/build.ps1 (PS2EXE no -NoConsole, auto-install PS2EXE, auto-detect module version), tools/install.ps1 (first-run config wizard, Italian UI) |
| 5: CI/CD Pipeline | **COMPLETE** | .github/workflows/release.yml (on-tag v*, version sync → ModuleVersion, hybrid shell: pwsh + shell: powershell for PS2EXE, builds: EXE + ZIP + Inno Setup + MSI placeholder, softprops/action-gh-release@v2 multi-artifact upload), tools/setup.iss (Inno Setup installer script, Italian + English languages) |

## Phase 1 Findings (Python Architecture)

**Directory**: 42 files total, `src/aw_cli/` is the main package.

### Key Files
- `run.py` (745 lines) — Central CLI loop: search → episode selection → playback → history
- `anime.py` (382 lines) — Data models. **Episode nums are STRINGS** (`"1-12"`, `"1.5"` for ranges/specials)
- `providers/provider.py` — ABC base class defining: `search`, `latest`, `episodes`, `episode_link`, `info_anime`
- `providers/animeworld.py` (218 lines) — Cookie-based scraping with CSRF token, HTML regex parsing
- `providers/animeunity.py` (158 lines) — API-based, session with CSRF + cookies
- `providers/local.py` (62 lines) — Offline downloaded anime browser
- `fzf.py` (214 lines) — fzf CLI wrapper with `--listen` for dynamic reload → **Needs native PS replacement**
- `history.py` (151 lines) — JSON persistence of watch history
- `download.py` (98 lines) — Async concurrent video downloads
- `anilist.py` (125 lines) — AniList GraphQL sync (mutation + queries)
- `utilities.py` (88 lines) — TOML config parsing, Rich console styling
- `arg_parser.py` (139 lines) — CLI flags: `-c` (history), `-l` (latest), `-d` (download), `-o` (offline), `-p` (private), `-a` (config), `-u` (update), `-i` (info), `-s` (syncplay)
- `update.py` (57 lines) — Self-update via uv/pipx/pip

### CLI Flags Summary
```
aw-cli [-h] [-v] [-c [{r}]] [-l [{a,s,d,t}]] [-i] [-s] [-d] [-o] [-p] [-u [UPDATE]] [-a]
```

### AniList API (anilist.py)
- **Endpoint**: `https://graphql.anilist.co`
- **Auth**: `Authorization: Bearer {token}` header
- **Queries**: Viewer ID, MediaList entry, ToggleFavourite mutation

### Configuration (TOML)
Stored in `src/aw_cli/config.toml`, sections: `player` (type/path), `provider` (source), `anilist` (token/user_id/rating/favorite/drop), `general` (specials/parallel-downloads), `syncplay` (path), `style`.

## Python → PowerShell Mappings

| Python | PowerShell |
|--------|------------|
| `requests.Session()` | `$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession` |
| `requests.cookies` | `$session.Cookies.Add((New-Object System.Net.Cookie($name, $value)))` |
| `response.text` | `(Invoke-WebRequest -WebSession $s).Content` |
| `[regex]::Matches($text, $p).Value` | `re.findall($p, $text)` |
| `json.loads()` | `ConvertFrom-Json` |
| `rich.Console` | `Write-Host` / `$Host.UI.RawUI` for console styling |
| `fzf --listen` | **Native console menu**: `Write-Host` + `Read-Host` or `$Host.UI.RawUI.ReadKey()` |
| `threading.Thread` | `Start-Job` / `Start-ThreadJob` |
| `async stream` | `[System.IO.FileStream]` with `[System.Net.Http.HttpClient]` |
| `pydantic` models | `[PSCustomObject]` + scriptclass with validation |

## Providers to Port

1. **Animeworld** — Cookie/CSRF session → POST `/api/search/v2` → JSON → HTML episode list (regex `<li class="episode">`) → API `/api/episode/serverPlayerAnimeWorld` for video URL → regex `<source src>`
2. **Animeunity** — Session with CSRF token + cookies → `/livesearch` (POST) → JSON → `/info_api/{id}` → `/embed-url/{ep_id}` → video page regex `window.downloadUrl`

## Testing Strategy

The Python tests mock `httpx.Client`. In PowerShell, mock `Invoke-WebRequest`:
```powershell
Mock Invoke-WebRequest -ModuleName aw-cli {
    $mockPath = Join-Path $TestDrive "fixtures\$Name.json"
    ConvertFrom-Json (Get-Content $mockPath -Raw)
}
```

## Build Step (PS2EXE)

```powershell
# WRONG (GUI mode):
Invoke-PS2EXE -NoConsole ...

# CORRECT (Console CLI):
Invoke-PS2EXE @params  # No -NoConsole flag
```

## CI/CD Release Workflow Triggers

- **Trigger**: On git tag push (`v*.*.*`)
- **Version**: Parse tag → update `ModuleVersion` in `.psd1`
- **Build**: `shell: powershell` (Windows PS 5.1)
- **Artifacts**: `aw-cli.exe`, module `.zip`
- **Release**: `softprops/action-gh-release@v2` with multi-line `files:` YAML

## Debug Notes (v1.0.2+)

### PS 5.1 Compatibility Fixes
- **?. operator**: Not supported in PS 5.1 → replaced with null checks
- **try/catch blocks**: Malformed `try { Export-ModuleMember } catch { }` → removed wrapper
- **$IsWindows**: Doesn't exist in PS 5.1 → replaced with env check
- **WiX v5**: Removed `InstallScope`/`InstallPrivileges` from Package element

### Files Fixed: 12 files in src/ including Anime.ps1, Provider.ps1, etc.

### Error Logging
- Log file: `%LOCALAPPDATA%\aw-cli\error.log`
- Popup on crash for EXE builds

## TODO: What's Next

- **Phase 5**: COMPLETE — release.yml CI/CD pipeline + tools/setup.iss (Inno Setup)
- **All 5 phases complete** — ready for first git tag release
- **First release**: `git tag v1.0.0 && git push --tags`
- **Always start by reading this memory file first**
- Remember: final deliverable is a CLI executable, not a GUI app