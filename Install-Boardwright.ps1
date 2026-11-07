<#
.SYNOPSIS
  Installs Boardwright (AI design assistant for Altium Designer) on this PC.

.DESCRIPTION
  One run does everything a user would otherwise do by hand:
    1. checks for Altium Designer, Git and Claude Code (offers to install
       Git and the Claude Code CLI when they are missing)
    2. installs the Boardwright plugin into Claude Code (CLI and the VS Code
       extension share it)
    3. registers the same plugin folder for GitHub Copilot Chat in VS Code
    4. removes an older eda-agent / Altium skill set-up that would fight
       Boardwright for Altium (everything removed is listed in
       %USERPROFILE%\Boardwright\old-setup-removed.json)
    5. prepares %USERPROFILE%\Boardwright and the Altium bridge scripts
    6. puts a "Start Boardwright in Altium" shortcut on the desktop
    7. offers to start the bridge in a running Altium, then runs the check

  Nothing has to be registered inside Altium.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\Install-Boardwright.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\Install-Boardwright.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    [switch]$NoCopilot,   # do not register the plugin for GitHub Copilot
    [switch]$KeepOld,     # leave an older eda-agent set-up registered
    [switch]$NoShortcut,  # no desktop shortcut
    [switch]$Yes,         # answer yes to every question
    [switch]$Uninstall,   # remove Boardwright (your data folder stays)
    [string]$Source = 'https://github.com/Aka8sh3/boardwright-plugin.git'  # marketplace to install from
)

$ErrorActionPreference = 'Stop'
$Repo = $Source
$PluginId = 'boardwright@boardwright'
$ShortcutName = 'Start Boardwright in Altium.lnk'

function Step($m) { Write-Host ""; Write-Host "== $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "  [ok]   $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  [!]    $m" -ForegroundColor Yellow }
function Stop-Install($m) {
    Write-Host "  [FAIL] $m" -ForegroundColor Red
    Write-Host ""
    exit 1
}
function Ask($question) {
    if ($Yes) { return $true }
    # Without a console to answer (a script or -NonInteractive run), the
    # answer is no: nothing is installed or started that nobody agreed to.
    try { $a = Read-Host "  $question [Y/n]" } catch { return $false }
    if ($null -eq $a) { return $false }
    return ($a -eq '' -or $a -match '^[yYjJ]')
}
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Find-Claude {
    $cmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $local = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
    if (Test-Path $local) { return $local }
    # The Claude Code extension for VS Code brings its own copy of the CLI.
    $ext = Join-Path $env:USERPROFILE '.vscode\extensions'
    $found = Get-ChildItem $ext -Directory -Filter 'anthropic.claude-code-*' -ErrorAction SilentlyContinue |
        Sort-Object { [version](($_.Name -split '-')[2]) } -Descending |
        ForEach-Object { Join-Path $_.FullName 'resources\native-binary\claude.exe' } |
        Where-Object { Test-Path $_ } | Select-Object -First 1
    return $found
}

function Find-Altium {
    $roots = @("$env:ProgramFiles\Altium", "${env:ProgramFiles(x86)}\Altium") | Where-Object { $_ -and (Test-Path $_) }
    foreach ($r in $roots) {
        $x2 = Get-ChildItem $r -Filter 'X2.EXE' -Recurse -Depth 2 -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($x2) { return $x2.FullName }
    }
    return $null
}

function Invoke-Claude([string[]]$ClaudeArgs) {
    # Windows PowerShell turns a native program's stderr into errors when it
    # is captured; with 'Stop' the first progress line would end the script.
    $ErrorActionPreference = 'Continue'
    $out = & $script:Claude @ClaudeArgs 2>&1 | ForEach-Object { "$_" } | Out-String
    return @{ Code = $LASTEXITCODE; Text = $out.Trim() }
}

$ClaudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$PluginDir = Join-Path $ClaudeDir 'plugins\marketplaces\boardwright'
$DataHome = if ($env:BOARDWRIGHT_HOME) { $env:BOARDWRIGHT_HOME } else { Join-Path $env:USERPROFILE 'Boardwright' }
$Desktop = [Environment]::GetFolderPath('Desktop')

function Find-Runtime {
    # Claude Code's marketplace copy (a stable path), else the installed
    # plugin in its cache (a local-folder marketplace has no copy).
    $stable = Join-Path $PluginDir 'runtime\python.exe'
    if (Test-Path $stable) { return $stable }
    return Get-ChildItem (Join-Path $ClaudeDir 'plugins\cache\boardwright\boardwright') -Directory -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        ForEach-Object { Join-Path $_.FullName 'runtime\python.exe' } |
        Where-Object { Test-Path $_ } | Select-Object -First 1
}

Write-Host "Boardwright installer" -ForegroundColor White

# ---------------------------------------------------------------- uninstall
if ($Uninstall) {
    $script:Claude = Find-Claude
    Step 'Removing Boardwright'
    $Python = Find-Runtime
    if ($Python) {
        # Unregisters Copilot and anything Boardwright 1.0 registered.
        & $Python -I -m boardwright remove
    }
    if ($script:Claude) {
        $r = Invoke-Claude @('plugin', 'uninstall', $PluginId)
        if ($r.Code -eq 0) { Ok 'Claude Code: plugin uninstalled' } else { Warn $r.Text }
        $r = Invoke-Claude @('plugin', 'marketplace', 'remove', 'boardwright')
        if ($r.Code -eq 0) { Ok 'Claude Code: marketplace removed' }
    } else {
        Warn 'Claude Code CLI not found: in Claude Code run /plugin uninstall boardwright@boardwright'
    }
    $lnk = Join-Path $Desktop $ShortcutName
    if (Test-Path $lnk) { Remove-Item $lnk -Force; Ok 'desktop shortcut removed' }
    Write-Host ""
    Write-Host "Done. Your data stays in $DataHome (delete it by hand if you want)."
    Write-Host "Restart VS Code / Claude Code."
    exit 0
}

# ---------------------------------------------------------------- 1. checks
Step 'Checking this PC'
if ($env:OS -ne 'Windows_NT') { Stop-Install 'Boardwright runs on Windows (where Altium Designer runs).' }
$Altium = Find-Altium
if ($Altium) { Ok "Altium Designer: $Altium" }
else { Warn 'Altium Designer not found under Program Files. Boardwright installs anyway; it needs Altium to design.' }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Warn 'Git is missing. Claude Code uses it to download the plugin.'
    if ((Get-Command winget -ErrorAction SilentlyContinue) -and (Ask 'Install Git for Windows now with winget?')) {
        winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
        Refresh-Path
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Stop-Install 'Install Git for Windows (https://git-scm.com/download/win), then run this again.'
    }
}
Ok 'Git'

$script:Claude = Find-Claude
if (-not $script:Claude) {
    Warn 'Claude Code is missing (neither the CLI nor the VS Code extension).'
    if (Ask 'Install the Claude Code CLI now (official installer from claude.ai)?') {
        Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
        Refresh-Path
        $script:Claude = Find-Claude
    }
    if (-not $script:Claude) {
        Stop-Install 'Install Claude Code (the VS Code extension "Claude Code", or https://claude.ai/code), then run this again.'
    }
}
Ok "Claude Code: $script:Claude"

$VsUser = Join-Path $env:APPDATA 'Code\User'
$HasVsCode = Test-Path $VsUser
$Copilot = $HasVsCode -and -not $NoCopilot

# ---------------------------------------------------------------- 2. plugin
Step 'Installing the Boardwright plugin for Claude Code'
Write-Host '  (Git may open a browser window once to sign in to GitHub.)'
if (Test-Path (Join-Path $PluginDir '.claude-plugin\marketplace.json')) {
    $r = Invoke-Claude @('plugin', 'marketplace', 'update', 'boardwright')
    if ($r.Code -ne 0) { Stop-Install "updating the Boardwright marketplace failed:`n$($r.Text)" }
    Ok 'marketplace updated'
} else {
    $r = Invoke-Claude @('plugin', 'marketplace', 'add', $Repo)
    if ($r.Code -ne 0) {
        Stop-Install ("adding the marketplace failed. Check that your GitHub account can open " +
                      "$Repo (ask for read access).`n$($r.Text)")
    }
    Ok 'marketplace added'
}
$r = Invoke-Claude @('plugin', 'install', $PluginId)
if ($r.Code -ne 0) { Stop-Install "installing the plugin failed:`n$($r.Text)" }
# 'install' leaves an installed plugin at its old version; 'update' moves
# it to the marketplace's (measured 2026-11-08: rc2 stayed after install).
$r = Invoke-Claude @('plugin', 'update', $PluginId)
if ($r.Code -ne 0) { Warn "updating the plugin reported: $($r.Text)" }
$listed = (Invoke-Claude @('plugin', 'list')).Text -split "`n"
$at = [array]::FindIndex($listed, [Predicate[string]]{ param($l) $l -match [regex]::Escape($PluginId) })
$version = if ($at -ge 0) { ($listed[$at..($at + 3)] | Select-String 'Version:\s*(\S+)' | Select-Object -First 1).Matches.Groups[1].Value }
Ok "plugin installed and enabled (version $version)"
$Python = Find-Runtime
if (-not $Python) { Stop-Install "the installed plugin has no runtime (looked in $PluginDir and the plugin cache)" }

# ---------------------------------------------------------------- 3-5. setup
Step 'Preparing this PC'
$setupArgs = @('-I', '-m', 'boardwright', 'setup')
if ($Copilot) { $setupArgs += '--copilot' }
if (-not $KeepOld) { $setupArgs += '--clean-old' }
$env:BOARDWRIGHT_CLAUDE = $script:Claude
& $Python @setupArgs
if ($LASTEXITCODE -ne 0) { Stop-Install 'boardwright setup reported a failure (see above).' }
$Info = & $Python -I -m boardwright info | Out-String | ConvertFrom-Json
$Launcher = Join-Path $Info.home 'Start Boardwright in Altium.cmd'

# ---------------------------------------------------------------- 6. shortcut
if (-not $NoShortcut -and (Test-Path $Launcher)) {
    Step 'Desktop shortcut'
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut((Join-Path $Desktop $ShortcutName))
    $lnk.TargetPath = $Launcher
    $lnk.WorkingDirectory = $Info.home
    $lnk.Description = 'Start the Boardwright bridge in the running Altium Designer'
    if ($Altium) { $lnk.IconLocation = "$Altium,0" }
    $lnk.Save()
    Ok "$ShortcutName on the desktop"
}

# ---------------------------------------------------------------- 7. bridge + check
$running = Get-Process -Name X2 -ErrorAction SilentlyContinue
$live = $false
if ($running) {
    Step 'Altium is running'
    if (Ask 'Start the Boardwright bridge in Altium now?') {
        & $Python -I -m boardwright relaunch
        $live = ($LASTEXITCODE -eq 0)
    } else {
        Write-Host '  Not started. Use the desktop shortcut when you are ready.'
    }
}
Step 'Checking the installation'
if ($live) { & $Python -I -m boardwright doctor } else { & $Python -I -m boardwright doctor --offline }

Write-Host ""
Write-Host "Boardwright is installed." -ForegroundColor Green
Write-Host "  1. Restart VS Code (or Claude Code) so it loads the plugin."
Write-Host "  2. Open Altium Designer; double-click 'Start Boardwright in Altium' on the desktop"
Write-Host "     (or let the AI start it; it asks first)."
Write-Host "  3. In Claude Code type /boardwright, e.g. /boardwright check the setup"
if ($Copilot) {
    Write-Host "     In GitHub Copilot Chat (Agent mode) the same skill is available as /boardwright."
}
Write-Host "  Uninstall: run this script with -Uninstall (your data folder stays)."
