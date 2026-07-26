# aw-cli PowerShell

Guarda anime dal terminale su Windows. Nativamente, senza Python, senza WSL.

I provider supportati sono [Animeworld](https://www.animeworld.ac/) e [Animeunity](https://www.animeunity.so/).

## Installazione

### Option 1: Eseguire direttamente
```powershell
.\aw-cli.ps1
```

### Option 2: Modulo PowerShell
```powershell
Import-Module .\aw-cli.psm1 -Force
Get-Command -Module aw-cli
```

### Option 3: Compilare in EXE
```powershell
.\tools\build.ps1
# Output: dist\aw-cli.exe, dist\aw-cli-module.zip
```

## Utilizzo

```powershell
.\aw-cli.ps1                    # Ricerca interattiva
.\aw-cli.ps1 -Latest            # Ultimi episodi
.\aw-cli.ps1 -LatestFilter a   # all / s (sub) / d (dub) / t (trending)
.\aw-cli.ps1 -History           # Cronologia
.\aw-cli.ps1 -History -RemoveHistory  # Rimuovi dalla cronologia
.\aw-cli.ps1 -Info              # Info prima di guardare
.\aw-cli.ps1 -Download          # Scarica episodi
.\aw-cli.ps1 -Offline            # Anime gia' scaricati
.\aw-cli.ps1 -Config            # Configurazione
.\aw-cli.ps1 -Version           # Versione
```

## Player Supportati

| Player | Tipo | Resume | Note |
|--------|------|--------|------|
| MPV | CLI | Si | Consigliato |
| VLC | GUI | Si | Funziona |
| Screenbox | UWP | No | App Windows |
| Photos | UWP | No | App Windows |

## Configurazione

Al primo avvio viene eseguito il wizard di configurazione. Oppure:
```powershell
.\aw-cli.ps1 -Config
```

Il file di configurazione viene salvato accanto al modulo (`config.json`).

## Struttura del Progetto

```
aw-cli-powershell/
├── aw-cli.ps1      # CLI entry point
├── aw-cli.psm1     # PowerShell module (Import-Module)
├── aw-cli.psd1     # Module manifest
├── src/
│   ├── Classes/        # Data models (Anime, AnimeEpisode, etc.)
│   ├── Private/         # Internal modules
│   │   ├── Providers/   # Animeworld, Animeunity, Local
│   │   ├── Player.ps1
│   │   ├── ConsoleUI.ps1
│   │   └── ...
│   └── Public/
├── tools/
│   ├── build.ps1        # PS2EXE compilation
│   └── install.ps1      # Config wizard
└── dist/                # Build output
```

## Requisiti

- Windows PowerShell 5.1 (o PowerShell 7+)
- Preferibilmente [MPV](https://mpv.io/) o [VLC](https://www.videolan.org/) installato
- FZF NON richiesto - la UI e' completamente nativa PowerShell