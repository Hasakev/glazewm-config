# Installs GlazeWM, Zebar and AltSnap for the current user (no admin), points GlazeWM
# at this repo's config.yaml, starts it at login and auto-hides the taskbar.
# Run from the folder you intend to keep: GlazeWM reads the config from here.
# Re-run to upgrade after changing the versions below.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # Progress bar makes downloads very slow in PowerShell 5.1.

$glazewmVersion = 'v3.10.1'  # v3.2.0+ needed so Win-key bindings don't pop the Start menu.
$zebarVersion = 'v3.3.1'
$altSnapVersion = '1.68'
# AltSnap is not code-signed, so the download is checked against this hash.
# Take it from the release page's asset list when changing the version.
$altSnapSha256 = '7DB3DAD3746E7B23857DB92FC05EE2D3E17EEE1B28E237709A612366BA909C79'
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
    $cli = Start-Process (Join-Path $programs 'GlazeWM\cli\glazewm.exe') -ArgumentList 'command', 'wm-exit' -NoNewWindow -PassThru
    # A hung GlazeWM never answers, so force it closed after 15 seconds. Its
    # watcher process (left running) then restores any hidden windows.
    if (-not $cli.WaitForExit(15000)) {
        $cli.Kill()
        $running | Where-Object Name -eq 'glazewm' | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    $running | Wait-Process -Timeout 10 -ErrorAction SilentlyContinue
}
Get-Process zebar, AltSnap -ErrorAction SilentlyContinue | Stop-Process -Force

# 2. Install.
Install-GlzrMsi 'glazewm' $glazewmVersion "standalone-glazewm-$glazewmVersion-x64.msi" 'GlazeWM'
Install-GlzrMsi 'zebar' $zebarVersion "zebar-$zebarVersion-opt1-x64.msi" 'Zebar'

# 2b. AltSnap (Win+drag to move, Win+right-drag to resize), portable build.
#     It reports drags the same way a title-bar drag does, so GlazeWM re-tiles
#     the window where it is dropped.
$zip = Join-Path $env:TEMP "AltSnap$altSnapVersion.zip"
Invoke-WebRequest "https://github.com/RamonUnch/AltSnap/releases/download/$altSnapVersion/AltSnap${altSnapVersion}bin_x64.zip" -OutFile $zip -UseBasicParsing
if ((Get-FileHash $zip -Algorithm SHA256).Hash -ne $altSnapSha256) { throw "AltSnap $altSnapVersion download does not match the expected hash." }
Expand-Archive $zip (Join-Path $programs 'AltSnap') -Force
Remove-Item $zip
# Settings on top of AltSnap's defaults (its AltSnap.ini is reset on every run):
# Win instead of Alt as the drag key; no snapping of its own, GlazeWM places
# windows; no title-bar actions without Win (scroll rolls up, middle-click
# sends to back).
Add-Type -Namespace Win32 -Name Ini -MemberDefinition '[DllImport("kernel32.dll", CharSet = CharSet.Unicode)] public static extern bool WritePrivateProfileString(string section, string key, string value, string path);'
$altSnapIni = Join-Path $programs 'AltSnap\AltSnap.ini'
foreach ($s in @('Input', 'Hotkeys', '5B 5C'), @('General', 'Aero', '0'), @('General', 'AutoSnap', '0'),
               @('Input', 'ScrollT', 'Nothing'), @('Input', 'MMBT', 'Nothing')) {
    if (-not [Win32.Ini]::WritePrivateProfileString($s[0], $s[1], $s[2], $altSnapIni)) { throw "Could not write $($s[1]) to $altSnapIni." }
}

# 3. Put the GlazeWM CLI on PATH, as the official installer does. Zebar's first
#    run checks `where glazewm` to choose its GlazeWM bar over the plain one.
$cliDir = Join-Path $programs 'GlazeWM\cli'
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($userPath -split ';') -notcontains $cliDir) {
    $newPath = if ($userPath) { "$($userPath.TrimEnd(';'));$cliDir" } else { $cliDir }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
}
$env:Path = "$env:Path;$cliDir"

# 3b. Link this repo's bar into Zebar's config folder (a junction, so edits
#     here are live) and make it the only widget Zebar starts. This replaces
#     whatever was chosen in Zebar's own settings screen.
$zebarDir = Join-Path $env:USERPROFILE '.glzr\zebar'
$barLink = Join-Path $zebarDir 'hypr-bar'
$barSrc = Join-Path $PSScriptRoot 'zebar'
New-Item -ItemType Directory -Force $zebarDir | Out-Null
$existing = Get-Item $barLink -Force -ErrorAction SilentlyContinue
if ($existing -and $existing.LinkType -eq 'Junction' -and $existing.Target -ne $barSrc) {
    # Never Remove-Item -Recurse a junction: PowerShell 5.1 can delete the target's files.
    $existing.Delete()
    $existing = $null
}
if (-not $existing) {
    New-Item -ItemType Junction -Path $barLink -Target $barSrc | Out-Null
} elseif ($existing.LinkType -ne 'Junction') {
    throw "$barLink exists and is not a link. Move it away and run again."
}
Set-Content (Join-Path $zebarDir 'settings.json') -Encoding ASCII -Value '{ "startupConfigs": [{ "pack": "hypr-bar", "widget": "bar", "preset": "default" }] }'

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

# 8. Start GlazeWM now (it starts Zebar and AltSnap via startup_commands).
Start-Process $exe -ArgumentList 'start', "--config=`"$config`""
Write-Host "GlazeWM $glazewmVersion, Zebar $zebarVersion and AltSnap $altSnapVersion running from $programs with $config"
