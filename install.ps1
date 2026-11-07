# Installs GlazeWM and Zebar for the current user (no admin), points GlazeWM
# at this repo's config.yaml, starts it at login and auto-hides the taskbar.
# Run from the folder you intend to keep: GlazeWM reads the config from here.
# Re-run to upgrade after changing the versions below.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # Progress bar makes downloads very slow in PowerShell 5.1.

$glazewmVersion = 'v3.10.1'  # v3.2.0+ needed so Win-key bindings don't pop the Start menu.
$zebarVersion = 'v3.3.1'
$config = Join-Path $PSScriptRoot 'config.yaml'
$programs = Join-Path $env:LOCALAPPDATA 'Programs'
$exe = Join-Path $programs 'GlazeWM\glazewm.exe'

# Unpacks a signed GLZR release MSI into %LOCALAPPDATA%\Programs\<Name>. The
# MSIs install per machine (needs admin); an administrative unpack (/a) does not.
function Install-GlzrMsi($repo, $version, $asset, $name) {
    $tmp = Join-Path $env:TEMP "$repo-$version"
    $msi = Join-Path $tmp 'setup.msi'
    New-Item -ItemType Directory -Force $tmp | Out-Null
    Invoke-WebRequest "https://github.com/glzr-io/$repo/releases/download/$version/$asset" -OutFile $msi -UseBasicParsing
    $sig = Get-AuthenticodeSignature $msi
    if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notlike '*GLZR SOFTWARE*') { throw "$asset is not signed by GLZR Software." }
    $p = Start-Process msiexec -ArgumentList '/a', "`"$msi`"", '/qn', "TARGETDIR=`"$tmp\x`"" -Wait -PassThru
    if ($p.ExitCode -ne 0) { throw "Unpacking $asset failed with exit code $($p.ExitCode)." }
    $src = Get-ChildItem "$tmp\x" -Directory -Recurse -Filter $name | Select-Object -First 1
    if (-not $src) { throw "No $name folder found in $asset." }
    $dest = Join-Path $programs $name
    New-Item -ItemType Directory -Force $dest | Out-Null
    Copy-Item "$($src.FullName)\*" $dest -Recurse -Force
    Remove-Item $tmp -Recurse -Force
}

# 1. Stop running instances cleanly, so windows hidden on other workspaces are
#    restored and the files can be replaced. Exiting GlazeWM also stops Zebar.
$running = Get-Process glazewm, glazewm-watcher -ErrorAction SilentlyContinue
if ($running) {
    & (Join-Path $programs 'GlazeWM\cli\glazewm.exe') command wm-exit
    $running | Wait-Process -Timeout 10 -ErrorAction SilentlyContinue
}
Get-Process zebar -ErrorAction SilentlyContinue | Stop-Process -Force

# 2. Install.
Install-GlzrMsi 'glazewm' $glazewmVersion "standalone-glazewm-$glazewmVersion-x64.msi" 'GlazeWM'
Install-GlzrMsi 'zebar' $zebarVersion "zebar-$zebarVersion-opt1-x64.msi" 'Zebar'

# 3. Put the GlazeWM CLI on PATH, as the official installer does. Zebar's first
#    run checks `where glazewm` to choose its GlazeWM bar over the plain one.
$cliDir = Join-Path $programs 'GlazeWM\cli'
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($userPath -split ';') -notcontains $cliDir) {
    $newPath = if ($userPath) { "$($userPath.TrimEnd(';'));$cliDir" } else { $cliDir }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
}
$env:Path = "$env:Path;$cliDir"

# 4. Point GlazeWM at this repo's config.
[Environment]::SetEnvironmentVariable('GLAZEWM_CONFIG_PATH', $config, 'User')
$env:GLAZEWM_CONFIG_PATH = $config

# 5. Start at login. Same registry value as the tray's "Run on system startup",
#    so the tray toggle stays in sync and GlazeWM never starts twice.
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'GlazeWM' -Value "`"$exe`""

# 6. Start-menu entry with Ctrl+Alt+G, to start GlazeWM again after Win+Esc.
$lnk = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path ([Environment]::GetFolderPath('Programs')) 'GlazeWM.lnk'))
$lnk.TargetPath = $exe
$lnk.Hotkey = 'Ctrl+Alt+G'
$lnk.Save()

# 7. Auto-hide the taskbar (Zebar is the bar; the taskbar still slides up on
#    hover for the system tray). Same as the Settings toggle, no Explorer restart.
Add-Type -Namespace Win32 -Name AppBar -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)] public struct APPBARDATA {
    public int cbSize; public IntPtr hWnd; public uint uCallbackMessage; public uint uEdge;
    public int left, top, right, bottom; public IntPtr lParam; }
[DllImport("shell32.dll")] public static extern UIntPtr SHAppBarMessage(uint msg, ref APPBARDATA data);
'@
$abd = New-Object Win32.AppBar+APPBARDATA
$abd.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($abd)
$abd.lParam = [IntPtr]1  # ABS_AUTOHIDE
[Win32.AppBar]::SHAppBarMessage(0xA, [ref]$abd) | Out-Null  # ABM_SETSTATE

# 8. Start GlazeWM now (it starts Zebar via startup_commands).
Start-Process $exe -ArgumentList 'start', "--config=`"$config`""
Write-Host "GlazeWM $glazewmVersion and Zebar $zebarVersion running from $programs with $config"
