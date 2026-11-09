# glazewm-config

A Hyprland-style keymap and look for Windows 11, built on [GlazeWM](https://github.com/glzr-io/glazewm) with [Zebar](https://github.com/glzr-io/zebar) as the status bar. This is only a config: GlazeWM does the window management.

## Install

1. Clone this repo, or download a release zip and extract it somewhere permanent such as `%USERPROFILE%\glazewm-config`. GlazeWM reads the config from this folder, so do not leave it in Downloads.
2. Run `powershell -ExecutionPolicy Bypass -File install.ps1` from that folder. No admin rights are needed.

The script:

- unpacks the signed GlazeWM and Zebar release MSIs into `%LOCALAPPDATA%\Programs`;
- unpacks the portable [AltSnap](https://github.com/RamonUnch/AltSnap) build there too (checked against a pinned SHA-256, as AltSnap is not code-signed) and sets it to use the Win key;
- adds the GlazeWM CLI to your `PATH` (as the official installer does);
- links this repo's `zebar` folder into `%USERPROFILE%\.glzr\zebar\hypr-bar` and sets it as the only bar Zebar starts (this replaces any choice made in Zebar's own settings);
- sets `GLAZEWM_CONFIG_PATH` to this folder's `config.yaml`;
- starts GlazeWM at login (the same setting as the tray's "Run on system startup");
- adds a GlazeWM Start-menu entry with the shortcut `Ctrl+Alt+G`;
- turns off taskbar auto-hide, so the Windows taskbar stays shown;
- starts GlazeWM, which starts Zebar and AltSnap.

To upgrade, change the versions at the top of `install.ps1` and run it again.

If you already have GlazeWM installed with winget, uninstall it first so only one copy runs.

Once running, GlazeWM tiles every open window. `Win+Shift+P` pauses and resumes it. `Win+Esc` exits it; `Ctrl+Alt+G` starts it again.

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
| `Win+T` | T3 Code |
| `Win+Shift+R` | Reload config |
| `Win+Shift+P` | Pause GlazeWM |
| `Win+Esc` | Exit GlazeWM |
| `Win`+drag | Move window (a tiled window is re-tiled where it is dropped) |
| `Win`+right-drag | Resize window |

Win+drag comes from AltSnap, which GlazeWM starts and stops with itself. It cannot drag apps running as administrator. `install.ps1` resets AltSnap's settings each time it runs, so make lasting changes in its settings block rather than in AltSnap's own settings window.

Left to Windows: `Win+L` lock, `Win+V` clipboard, `Win+A` quick settings, `Win+N` notifications, `Win+W` widgets, `Win+E` Explorer, `Win+R` Run, `Print` and media keys.

## Bar

The Zebar bar (`zebar/bar.html`, `zebar/styles.css`) shows, from left to right:

- a Start button (opens the Windows Start menu, after about a second), workspaces (click to switch) and the focused window's title;
- the date and time in the middle;
- media controls, weather, CPU and memory use, network, volume (click to mute, scroll to change), battery, the system tray and a power button.

The power button opens Lock, Sleep, Sign out, Restart and Shut down. Sign out, Restart and Shut down need a second click within 4 seconds.

Edits to the bar take effect when Zebar restarts. GlazeWM starts and stops Zebar, so press `Win+Esc` then `Ctrl+Alt+G`.

## Editing

Edit `config.yaml` in this folder, then press `Win+Shift+R`. GlazeWM shows an error if the config is invalid. All options are documented in GlazeWM's [sample config](https://github.com/glzr-io/glazewm/blob/v3.10.1/resources/assets/sample-config.yaml).

## Uninstall

Exit GlazeWM (`Win+Esc`), then in PowerShell:

```powershell
# Remove the bar link first, without -Recurse, so the repo's files are kept.
(Get-Item "$env:USERPROFILE\.glzr\zebar\hypr-bar").Delete()
Remove-Item "$env:LOCALAPPDATA\Programs\GlazeWM", "$env:LOCALAPPDATA\Programs\Zebar", "$env:LOCALAPPDATA\Programs\AltSnap" -Recurse
Remove-Item "$([Environment]::GetFolderPath('Programs'))\GlazeWM.lnk"
Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name GlazeWM
[Environment]::SetEnvironmentVariable('GLAZEWM_CONFIG_PATH', $null, 'User')
[Environment]::SetEnvironmentVariable('Path', (([Environment]::GetEnvironmentVariable('Path', 'User') -split ';') -ne "$env:LOCALAPPDATA\Programs\GlazeWM\cli") -join ';', 'User')
```
