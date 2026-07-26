# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`aw-cli` is a terminal-based anime watching CLI application (Italian interface). It supports streaming/downloading anime from Animeworld and Animeunity providers, with optional AniList sync integration.

## Common Commands

```bash
# Development
uv run pyright                    # Type checking
uv run pytest                     # Run all tests
uv run pytest tests/core/test_anime.py::test_name -v  # Run single test
uv run pytest --update-fixtures   # Refresh test fixtures (auto-regenerates if outdated/7+ days old)
uv run pre-commit run --all-files  # Run all pre-commit hooks (pyright, pytest, uv-lock)

# Installation
uv tool install aw-cli             # Install locally
```

## Architecture

### Provider Pattern
The codebase uses an abstract `Provider` base class (`providers/provider.py`) that defines the interface for anime sources. Each provider implements:
- `_search(input)` - Search anime by title
- `_latest(filter, specials)` - Get latest releases
- `_episodes(anime)` - Fetch episode list
- `_episode_link(anime, episode)` - Get video URL
- `_info_anime(anime)` - Populate anime metadata

Current providers:
- `Animeworld` (`providers/animeworld.py`) - Scrapes animeworld.ac
- `Animeunity` (`providers/animeunity.py`) - Uses animeunity.so API
- `LocalProvider` (`providers/local.py`) - Browse downloaded anime

The provider is selected via config: `aw_cli.providers.create_provider(source)` in `run.py:621`.

### Data Models
- `Anime` (`anime.py`) - Core model with Episode list, status, progress tracking
- `Anime.Episode` - Inner class; episode nums are **strings** to support ranges (e.g., "1-12") and specials ("1.5")
- `History` (`history.py`) - JSON-persisted watch history
- Episode sorting uses `__lt__` with numeric comparison: ranges resolve to max value, specials drop decimal

### Key Entry Points
- `run.py:main()` - Central CLI loop, handles search → episode selection → playback → menu navigation
- `run.py:open_player` global - Pluggable player (mpv/vlc/syncplay), set based on config at startup
- `watch_episode()` - Orchestrates playback, progress tracking, AniList updates
- `setup_config()` - Interactive configuration wizard (player, provider, AniList OAuth)

### UI Layer
- `Fzf` class (`interface/fzf.py`) - Wraps fzf with `--listen` for dynamic reloads
- `Rich` (`utilities.py`) - Terminal styling via custom theme; `ut.console` is the global Console
- `History.background_reload()` - Threaded reload of latest episodes while browsing history

### Download System
- `download.episodes()` - Async concurrent downloads (default 3 parallel, configurable via `general.parallel-downloads`)
- Uses `httpx.AsyncClient` streaming, saves to `~/Videos/Anime/{anime_name}/`

### AniList Integration
- `anilist.py` - OAuth token handling, anime status/rating sync
- Updates are fire-and-forget threads from `run.py:update_anilist()`

### Configuration
- Stored as `config.toml` in `src/aw_cli/` (same directory as `run.py`)
- Loaded via `ut.get_config()` into `ut.config_data` (defaultdict)
- Key sections: `player`, `provider`, `anilist`, `syncplay`, `general`, `style`

## Testing Notes
- Fixtures in `tests/fixtures/` are auto-generated from live provider pages
- They deprecate after 7 days and regenerate automatically on `pytest` run
- Provider implementations are closely coupled to HTML/API structure; fixture updates happen when providers change their layouts
- Tests inject mock `httpx.Client` into providers via constructor to avoid network calls

## Platform-Specific Code
- `os_name` detection (Linux/Darwin/Windows/Android/WSL) in `utilities.py:get_os()`
- WSL path conversion for Windows executables (`wslpath`)
- Android intents for mpv/vlc via `am start`