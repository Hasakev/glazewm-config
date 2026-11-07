# glazewm-config

A Hyprland-style keymap and look for Windows 11, built on [GlazeWM](https://github.com/glzr-io/glazewm). This is only a config: GlazeWM does the window management.

## Install

1. Clone this repo, or download a release zip and extract it somewhere permanent such as `%USERPROFILE%\glazewm-config`. GlazeWM reads the config from this folder, so do not leave it in Downloads.
2. Run `powershell -ExecutionPolicy Bypass -File install.ps1` from that folder. No admin rights are needed.

The script unpacks GlazeWM's signed release MSI into `%LOCALAPPDATA%\Programs\GlazeWM`, sets `GLAZEWM_CONFIG_PATH` to this folder's `config.yaml`, enables start at login (the same setting as the tray's "Run on system startup") and starts GlazeWM. To upgrade GlazeWM, change `$version` in `install.ps1` and run it again.

If you already have GlazeWM installed with winget, uninstall it first so only one copy runs.

Once running, GlazeWM tiles every open window. `Win+Shift+P` pauses it and `Win+Esc` exits it.

## Shortcuts

| Keys | Action |
|---|---|
| `Win+Arrows` | Focus window in that direction |
| `Win+1` to `Win+6` | Go to workspace |
| `Win+Shift+1` to `Win+Shift+6` | Move window to workspace |
| `Win+C` | Close window |
| `Win+F` | Toggle floating |
| `Win+J` | Toggle split direction |
| `Win+Shift+F` | Fullscreen (maximised) |
| `Win+Ctrl+F` | Fullscreen |
| `Win+M`, `Win+Shift+M` | Minimise |
| `Win+Q`, `Ctrl+Alt+T` | Windows Terminal |
| `Win+I` | Vivaldi |
| `Win+Z` | Zed |
| `Win+D` | Start menu (opens after about 1 second) |
| `Win+Shift+R` | Reload config |
| `Win+Shift+P` | Pause GlazeWM |
| `Win+Esc` | Exit GlazeWM |

Left to Windows: `Win+L` lock, `Win+V` clipboard, `Win+A` quick settings, `Win+N` notifications, `Win+W` widgets, `Win+E` Explorer, `Win+R` Run, `Print` and media keys.

## Editing

Edit `config.yaml` in this folder, then press `Win+Shift+R`. GlazeWM shows an error if the config is invalid. All options are documented in GlazeWM's [sample config](https://github.com/glzr-io/glazewm/blob/v3.10.1/resources/assets/sample-config.yaml).

## Uninstall

Exit GlazeWM (`Win+Esc`), then in PowerShell:

```powershell
Remove-Item "$env:LOCALAPPDATA\Programs\GlazeWM" -Recurse
Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name GlazeWM
[Environment]::SetEnvironmentVariable('GLAZEWM_CONFIG_PATH', $null, 'User')
```
