# Installs GlazeWM for the current user (no admin), points it at this repo's
# config.yaml and starts it at login. Run from the folder you intend to keep:
# GlazeWM reads the config from here. Re-run to upgrade after changing $version.
$ErrorActionPreference = 'Stop'

$version = 'v3.10.1'  # v3.2.0+ needed so Win-key bindings don't pop the Start menu.
$config = Join-Path $PSScriptRoot 'config.yaml'
$dir = Join-Path $env:LOCALAPPDATA 'Programs\GlazeWM'
$exe = Join-Path $dir 'glazewm.exe'

# 1. Stop a running instance cleanly (so windows hidden on other workspaces
#    are restored and the exe can be replaced).
$running = Get-Process glazewm -ErrorAction SilentlyContinue
if ($running) {
    & (Join-Path $dir 'cli\glazewm.exe') command wm-exit
    $running | Wait-Process -Timeout 10 -ErrorAction SilentlyContinue
}

# 2. Unpack the official MSI into the user folder. The MSI itself installs
#    per machine (needs admin); an administrative unpack (/a) does not.
$tmp = Join-Path $env:TEMP "glazewm-$version"
$msi = Join-Path $tmp 'glazewm.msi'
New-Item -ItemType Directory -Force $tmp | Out-Null
Invoke-WebRequest "https://github.com/glzr-io/glazewm/releases/download/$version/standalone-glazewm-$version-x64.msi" -OutFile $msi
if ((Get-AuthenticodeSignature $msi).Status -ne 'Valid') { throw "MSI signature is not valid: $msi" }
$p = Start-Process msiexec -ArgumentList '/a', "`"$msi`"", '/qn', "TARGETDIR=`"$tmp\x`"" -Wait -PassThru
if ($p.ExitCode -ne 0) { throw "msiexec unpack failed with exit code $($p.ExitCode)." }
New-Item -ItemType Directory -Force $dir | Out-Null
Copy-Item "$tmp\x\PFiles64\glzr.io\GlazeWM\*" $dir -Recurse -Force
Remove-Item $tmp -Recurse -Force

# 3. Point GlazeWM at this repo's config.
[Environment]::SetEnvironmentVariable('GLAZEWM_CONFIG_PATH', $config, 'User')
$env:GLAZEWM_CONFIG_PATH = $config

# 4. Start at login. Same registry value as the tray's "Run on system startup",
#    so the tray toggle stays in sync and GlazeWM never starts twice.
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'GlazeWM' -Value "`"$exe`""

# 5. Start it now.
Start-Process $exe -ArgumentList 'start', "--config=`"$config`""
Write-Host "GlazeWM $version running from $dir with $config"
