# winutil.ps1 - WinUtil-style feature module for Win-Optimizer-Pro
# Dot-sourced from optimizer.ps1 alongside engine.ps1.
# Implements: WinGet Install/Upgrade/Uninstall, DNS switcher,
# Windows Update modes, Power plans, Windows Features, system Fixes,
# legacy Control Panel launchers, OpenSSH server, undo-tweaks.

# ---------------------------------------------------------------------------
# WinGet app catalog (category -> list of winget packages)
# ---------------------------------------------------------------------------
$Script:WingetCatalog = [ordered]@{
    'Browsers' = @(
        @{ Id = 'Google.Chrome';            Name = 'Google Chrome' }
        @{ Id = 'Mozilla.Firefox';          Name = 'Mozilla Firefox' }
        @{ Id = 'Brave.Brave';              Name = 'Brave Browser' }
        @{ Id = 'Opera.Opera';              Name = 'Opera' }
        @{ Id = 'Vivaldi.Vivaldi';          Name = 'Vivaldi' }
        @{ Id = 'Microsoft.Edge';           Name = 'Microsoft Edge' }
        @{ Id = 'Mullvad.Browser';          Name = 'Mullvad Browser' }
        @{ Id = 'TorProject.TorBrowser';    Name = 'Tor Browser' }
    )
    'Essentials' = @(
        @{ Id = '7zip.7zip';                Name = '7-Zip' }
        @{ Id = 'NanaZip.NanaZip';          Name = 'NanaZip' }
        @{ Id = 'Notepad++.Notepad++';      Name = 'Notepad++' }
        @{ Id = 'Microsoft.PowerToys';      Name = 'Microsoft PowerToys' }
        @{ Id = 'Microsoft.Sysinternals.ProcessExplorer'; Name = 'Process Explorer' }
        @{ Id = 'Greenshot.Greenshot';      Name = 'Greenshot' }
        @{ Id = 'ShareX.ShareX';            Name = 'ShareX' }
        @{ Id = 'voidtools.Everything';     Name = 'Everything Search' }
        @{ Id = 'RARLab.WinRAR';            Name = 'WinRAR' }
    )
    'Media' = @(
        @{ Id = 'VideoLAN.VLC';             Name = 'VLC Media Player' }
        @{ Id = 'MPC-HC.MPC-HC';            Name = 'MPC-HC' }
        @{ Id = 'OBSProject.OBSStudio';     Name = 'OBS Studio' }
        @{ Id = 'GIMP.GIMP';                Name = 'GIMP' }
        @{ Id = 'Krita.Krita';              Name = 'Krita' }
        @{ Id = 'Audacity.Audacity';        Name = 'Audacity' }
        @{ Id = 'Spotify.Spotify';          Name = 'Spotify' }
        @{ Id = 'Winamp.Winamp';            Name = 'Winamp' }
    )
    'Music' = @(
        @{ Id = 'Audacity.Audacity';        Name = 'Audacity' }
        @{ Id = 'Musixmatch.Musixmatch';    Name = 'Musixmatch' }
    )
    'Graphics' = @(
        @{ Id = 'Inkscape.Inkscape';        Name = 'Inkscape' }
        @{ Id = 'BlenderFoundation.Blender'; Name = 'Blender' }
        @{ Id = 'Autodesk.AutoCAD';         Name = 'AutoCAD (via installer)' }
        @{ Id = 'Serif.AffinityDesigner';   Name = 'Affinity Designer' }
    )
    'Communication' = @(
        @{ Id = 'Discord.Discord';          Name = 'Discord' }
        @{ Id = 'SlackTechnologies.Slack';  Name = 'Slack' }
        @{ Id = 'Zoom.Zoom';                Name = 'Zoom' }
        @{ Id = 'TeamSpeakSystems.TeamSpeakClient'; Name = 'TeamSpeak' }
        @{ Id = 'Microsoft.Teams';          Name = 'Microsoft Teams' }
        @{ Id = 'WhatsApp.WhatsApp';        Name = 'WhatsApp' }
        @{ Id = 'Telegram.TelegramDesktop'; Name = 'Telegram Desktop' }
        @{ Id = 'Signal.Signal';            Name = 'Signal' }
    )
    'Development' = @(
        @{ Id = 'Microsoft.VisualStudioCode'; Name = 'VS Code' }
        @{ Id = 'Microsoft.VisualStudio.2022.BuildTools'; Name = 'VS 2022 Build Tools' }
        @{ Id = 'Git.Git';                  Name = 'Git' }
        @{ Id = 'GitHub.GitHubDesktop';     Name = 'GitHub Desktop' }
        @{ Id = 'GitHub.cli';               Name = 'GitHub CLI' }
        @{ Id = 'Python.Python.3.12';       Name = 'Python 3.12' }
        @{ Id = 'OpenJS.NodeJS.LTS';        Name = 'Node.js LTS' }
        @{ Id = 'Docker.DockerDesktop';     Name = 'Docker Desktop' }
        @{ Id = 'JetBrains.IntelliJIDEA.Community'; Name = 'IntelliJ IDEA Community' }
        @{ Id = 'JetBrains.PyCharm.Community'; Name = 'PyCharm Community' }
        @{ Id = 'Oracle.VirtualBox';        Name = 'VirtualBox' }
        @{ Id = 'VMware.WorkstationPlayer'; Name = 'VMware Workstation Player' }
        @{ Id = 'Postman.Postman';          Name = 'Postman' }
        @{ Id = 'PuTTY.PuTTY';              Name = 'PuTTY' }
        @{ Id = 'Rustlang.Rustup';          Name = 'Rust (rustup)' }
        @{ Id = 'OpenJS.NodeJS';            Name = 'Node.js' }
    )
    'Utilities' = @(
        @{ Id = 'Microsoft.Sysinternals';   Name = 'Sysinternals Suite' }
        @{ Id = 'Microsoft.PowerShell';     Name = 'PowerShell 7' }
        @{ Id = 'Microsoft.WindowsTerminal'; Name = 'Windows Terminal' }
        @{ Id = 'Microsoft.WingetCreate';   Name = 'WinGet Create' }
        @{ Id = 'Microsoft.DevToys';        Name = 'DevToys' }
        @{ Id = 'Rufus.Rufus';              Name = 'Rufus' }
        @{ Id = 'Balena.Etcher';            Name = 'balenaEtcher' }
        @{ Id = 'CrystalDewWorld.CrystalDiskMark'; Name = 'CrystalDiskMark' }
        @{ Id = 'CrystalDewWorld.CrystalDiskInfo'; Name = 'CrystalDiskInfo' }
        @{ Id = 'Speedtest.Ookla';          Name = 'Speedtest by Ookla' }
        @{ Id = 'Tailscale.Tailscale';      Name = 'Tailscale' }
        @{ Id = 'ProtonVPN.ProtonVPN';      Name = 'Proton VPN' }
    )
    'Gaming' = @(
        @{ Id = 'Valve.Steam';              Name = 'Steam' }
        @{ Id = 'EpicGames.EpicGamesLauncher'; Name = 'Epic Games Launcher' }
        @{ Id = 'GOG.Galaxy';               Name = 'GOG Galaxy' }
        @{ Id = 'Ubisoft.Connect';          Name = 'Ubisoft Connect' }
        @{ Id = 'Discord.Discord';          Name = 'Discord' }
        @{ Id = 'OBSProject.OBSStudio';     Name = 'OBS Studio' }
        @{ Id = 'Parsec.Parsec';            Name = 'Parsec' }
    )
    'Security' = @(
        @{ Id = 'Malwarebytes.Malwarebytes'; Name = 'Malwarebytes' }
        @{ Id = 'Bitdefender.Bitdefender';  Name = 'Bitdefender' }
        @{ Id = 'Proton.ProtonVPN';         Name = 'Proton VPN' }
        @{ Id = 'OpenVPNTechnologies.OpenVPN'; Name = 'OpenVPN' }
        @{ Id = 'Bitwarden.Bitwarden';      Name = 'Bitwarden' }
    )
    'Office' = @(
        @{ Id = 'LibreOffice.LibreOffice';  Name = 'LibreOffice' }
        @{ Id = 'OnlyOffice.OnlyOffice';    Name = 'OnlyOffice' }
        @{ Id = 'Notion.Notion';            Name = 'Notion' }
        @{ Id = 'Obsidian.Obsidian';        Name = 'Obsidian' }
        @{ Id = 'Microsoft.Office';         Name = 'Microsoft 365 (via installer)' }
    )
    'Windows11' = @(
        @{ Id = 'Microsoft.WindowsAppRuntime.Copy'; Name = 'Windows App Runtime' }
        @{ Id = 'NanaZip.NanaZip';          Name = 'NanaZip' }
        @{ Id = 'Microsoft.PowerToys';      Name = 'PowerToys' }
    )
}

# Dedupe the catalog by Id while preserving category mapping.
function Get-WingetCatalog {
    $seen = @{}
    $rows = @()
    foreach ($cat in $Script:WingetCatalog.Keys) {
        foreach ($app in $Script:WingetCatalog[$cat]) {
            if ($seen.ContainsKey($app.Id)) { continue }
            $seen[$app.Id] = $true
            $rows += [pscustomobject]@{
                Category = $cat
                Id       = $app.Id
                Name     = $app.Name
            }
        }
    }
    return $rows
}

# Returns installed winget package IDs (one winget list call, cached).
$Script:WingetInstalledCache = $null

function Get-WingetInstalled {
    if ($null -ne $Script:WingetInstalledCache) { return $Script:WingetInstalledCache }
    Write-Log "[winget] querying installed packages ..."
    $raw = & winget.exe list --disable-interactivity --accept-source-agreements --accept-package-agreements 2>$null
    $ids = @()
    foreach ($line in $raw) {
        # winget list columns: Name | Id | Version | Available | Source
        # The package Id is the SECOND column; the first is the display Name
        # (which rarely contains a dot, so the old regex never matched and the
        # wrong column was captured). Skip header / separator / blank lines by
        # requiring a dotted Id in column two.
        $parts = @(($line -split '\s{2,}') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        if ($parts.Count -ge 2 -and $parts[1] -match '^\S+\.\S+$') {
            $ids += $parts[1]
        }
    }
    $Script:WingetInstalledCache = $ids
    return $ids
}

function Clear-WingetCache {
    $Script:WingetInstalledCache = $null
}

function Write-WingetAppRows {
    <#
        .SYNOPSIS
        Prints WAPP|category|id|name|installed rows for the catalog.
        The frontend renders these into the Install tab.
    #>
    $installed = @(Get-WingetInstalled)
    foreach ($app in (Get-WingetCatalog)) {
        $isInstalled = $app.Id -in $installed
        Write-Log "WAPP|$($app.Category)|$($app.Id)|$($app.Name)|$isInstalled"
    }
    Write-Log "=== WINGET LIST COMPLETE ==="
}

function Invoke-WingetAction {
    <#
        .SYNOPSIS
        Runs winget install / upgrade / uninstall for a list of package IDs.
        -Action install|upgrade|uninstall|upgrade-all
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Action,
        [string[]]$App = @(),
        [switch]$DryRun
    )
    $apps = @($App)
    if ($Action -eq 'upgrade-all') {
        if ($DryRun) {
            Write-Log "[winget] (dry-run) would upgrade all outdated packages"
            return
        }
        Write-Log "[winget] upgrading all packages ..."
        & winget.exe upgrade --all --silent --disable-interactivity --accept-source-agreements --accept-package-agreements 2>&1 | ForEach-Object { Write-Log $_ }
        Write-Log "[winget] upgrade-all done."
        return
    }

    $apps = @($apps | ForEach-Object { ($_ -split ',') } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($apps.Count -eq 0) {
        Write-Log "[winget] no packages selected."
        return
    }

    $verb = switch ($Action) { 'install' { 'installing' } 'upgrade' { 'upgrading' } 'uninstall' { 'uninstalling' } }
    foreach ($id in $apps) {
        if ($DryRun) {
            Write-Log "[winget] (dry-run) would ${Action}: $id"
            continue
        }
        Write-Log "[winget] ${verb}: $id ..."
        $args = switch ($Action) {
            'install'   { @('install', $id, '--silent', '--disable-interactivity', '--accept-source-agreements', '--accept-package-agreements') }
            'upgrade'   { @('upgrade', $id, '--silent', '--disable-interactivity', '--accept-source-agreements', '--accept-package-agreements') }
            'uninstall' { @('uninstall', $id, '--silent', '--disable-interactivity', '--accept-source-agreements') }
        }
        & winget.exe @args 2>&1 | ForEach-Object { Write-Log $_ }
    }
    Clear-WingetCache
    Write-Log "[winget] done."
}

# ---------------------------------------------------------------------------
# DNS switcher
# ---------------------------------------------------------------------------
$Script:DnsPresets = [ordered]@{
    'Default'   = @{ Label = 'Default / DHCP'; Primary4 = $null; Secondary4 = $null; Primary6 = $null; Secondary6 = $null }
    'Google'    = @{ Label = 'Google';         Primary4 = '8.8.8.8';        Secondary4 = '8.8.4.4';        Primary6 = '2001:4860:4860::8888'; Secondary6 = '2001:4860:4860::8844' }
    'Cloudflare'= @{ Label = 'Cloudflare';     Primary4 = '1.1.1.1';        Secondary4 = '1.0.0.1';        Primary6 = '2606:4700:4700::1111'; Secondary6 = '2606:4700:4700::1001' }
    'CloudflareMalware' = @{ Label = 'Cloudflare (malware blocking)'; Primary4 = '1.1.1.2'; Secondary4 = '1.0.0.2'; Primary6 = '2606:4700:4700::1112'; Secondary6 = '2606:4700:4700::1002' }
    'CloudflareAdult' = @{ Label = 'Cloudflare (malware + adult)'; Primary4 = '1.1.1.3'; Secondary4 = '1.0.0.3'; Primary6 = '2606:4700:4700::1113'; Secondary6 = '2606:4700:4700::1003' }
    'OpenDNS'   = @{ Label = 'OpenDNS';        Primary4 = '208.67.222.222'; Secondary4 = '208.67.220.220'; Primary6 = '2620:119:35::35'; Secondary6 = '2620:119:53::53' }
    'Quad9'     = @{ Label = 'Quad9';          Primary4 = '9.9.9.9';        Secondary4 = '149.112.112.112'; Primary6 = '2620:fe::fe'; Secondary6 = '2620:fe::9' }
    'AdGuard'   = @{ Label = 'AdGuard';        Primary4 = '94.140.14.14';   Secondary4 = '94.140.15.15';   Primary6 = '2a10:50c0::ad1:ff'; Secondary6 = '2a10:50c0::ad2:ff' }
}

function Get-DnsPresets {
    foreach ($key in $Script:DnsPresets.Keys) {
        Write-Log "DNS|$key|$($Script:DnsPresets[$key].Label)"
    }
    Write-Log "=== DNS LIST COMPLETE ==="
}

function Set-DnsPreset {
    <#
        .SYNOPSIS
        Applies a DNS preset to every active network adapter (IPv4 + IPv6).
        'Default' restores DHCP-assigned DNS.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Preset,
        [switch]$DryRun
    )
    if (-not $Script:DnsPresets.Contains($Preset)) {
        Write-Log "[dns] unknown preset: $Preset"
        return
    }
    $p = $Script:DnsPresets[$Preset]
    $adapters = @(Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' })
    if ($adapters.Count -eq 0) { $adapters = @(Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }) }
    if ($adapters.Count -eq 0) {
        Write-Log "[dns] no active network adapter found."
        return
    }

    foreach ($a in $adapters) {
        Write-Log "[dns] $($a.Name): applying '$($p.Label)' ..."
        if ($DryRun) {
            Write-Log "[dry-run] would set DNS on $($a.Name) to $($p.Primary4),$($p.Secondary4)"
            continue
        }
        if ($null -eq $p.Primary4) {
            Set-DnsClientServerAddress -InterfaceAlias $a.Name -ResetServerAddresses -ErrorAction SilentlyContinue
        }
        else {
            Set-DnsClientServerAddress -InterfaceAlias $a.Name -ServerAddresses @($p.Primary4, $p.Secondary4) -ErrorAction SilentlyContinue
            if ($p.Primary6) {
                Set-DnsClientServerAddress -InterfaceAlias $a.Name -AddressFamily IPv6 -ServerAddresses @($p.Primary6, $p.Secondary6) -ErrorAction SilentlyContinue
            }
        }
    }
    Write-Log "[dns] done."
}

# ---------------------------------------------------------------------------
# Windows Update modes
# ---------------------------------------------------------------------------
$Script:UpdateModes = @{
    'Default'  = 'Restore standard Windows Update behavior'
    'Security' = 'Delay feature updates 365 days, security 4 days'
    'Disabled' = 'Disable ALL updates (not recommended)'
}

function Get-UpdateModes {
    foreach ($key in $Script:UpdateModes.Keys) {
        Write-Log "UPDMODE|$key|$($Script:UpdateModes[$key])"
    }
    Write-Log "=== UPDMODE LIST COMPLETE ==="
}

function Set-UpdateMode {
    <#
        .SYNOPSIS
        Applies a Windows Update servicing policy.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Mode,
        [switch]$DryRun
    )
    $key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    $au = "$key\AU"
    if ($DryRun) {
        Write-Log "[updates] (dry-run) would set update mode: $Mode"
        return
    }
    Write-Log "[updates] applying mode: $Mode"

    switch ($Mode) {
        'Default' {
            if (Test-Path $key) { Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction SilentlyContinue }
            Write-Log "[updates] default behavior restored (policy keys removed)."
        }
        'Security' {
            New-Item -Path $key -Force | Out-Null
            New-Item -Path $au -Force | Out-Null
            Set-ItemProperty -Path $key -Name 'PauseFeatureUpdatesStartTime' -Value '' -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $key -Name 'DeferFeatureUpdates' -Value 1 -Type DWord
            Set-ItemProperty -Path $key -Name 'DeferFeatureUpdatesPeriodInDays' -Value 365 -Type DWord
            Set-ItemProperty -Path $key -Name 'DeferQualityUpdates' -Value 1 -Type DWord
            Set-ItemProperty -Path $key -Name 'DeferQualityUpdatesPeriodInDays' -Value 4 -Type DWord
            Set-ItemProperty -Path $key -Name 'ProductVersion' -Value 'Windows 10' -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $key -Name 'TargetReleaseVersionInfo' -Value '24H2' -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $key -Name 'TargetReleaseVersion' -Value 1 -Type DWord -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $au -Name 'NoAutoUpdate' -Value 0 -Type DWord
            Set-ItemProperty -Path $au -Name 'NoAutoRebootWithLoggedOnUsers' -Value 1 -Type DWord
            Write-Log "[updates] security mode: feature updates delayed 365d, quality 4d."
        }
        'Disabled' {
            New-Item -Path $key -Force | Out-Null
            New-Item -Path $au -Force | Out-Null
            Set-ItemProperty -Path $key -Name 'NoAutoUpdate' -Value 1 -Type DWord
            Set-ItemProperty -Path $au -Name 'NoAutoUpdate' -Value 1 -Type DWord
            Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
            Set-Service wuauserv -StartupType Disabled -ErrorAction SilentlyContinue
            Stop-Service bits -Force -ErrorAction SilentlyContinue
            Set-Service bits -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log "[updates] all updates disabled. Use Default mode to restore."
        }
    }
}

# ---------------------------------------------------------------------------
# Power plans
# ---------------------------------------------------------------------------
function Get-PowerPlans {
    & powercfg.exe /list | ForEach-Object {
        if ($_ -match 'Power Scheme GUID:\s+(\S+)\s+\((.+?)\)\s*\*?$') {
            $guid = $Matches[1]
            $name = $Matches[2]
            $active = if ($_.TrimEnd().EndsWith('*')) { 'active' } else { 'inactive' }
            Write-Log "POWER|$guid|$name|$active"
        }
    }
    Write-Log "=== POWER LIST COMPLETE ==="
}

function Set-PowerPlan {
    param(
        [Parameter(Mandatory = $true)][string]$Plan,
        [switch]$DryRun
    )
    $Ultimate = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
    $Balanced = '381b4222-f694-41f0-9685-ff5bb260df2e'
    $HighPerformance = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    $PowerSaver = 'a1841308-3541-4fab-bc81-f71556f20b4a'

    $guid = switch ($Plan) {
        'Ultimate'        { $Ultimate }
        'Balanced'        { $Balanced }
        'HighPerformance' { $HighPerformance }
        'PowerSaver'      { $PowerSaver }
        default           { $null }
    }
    if (-not $guid) { Write-Log "[power] unknown plan: $Plan"; return }
    if ($DryRun) { Write-Log "[power] (dry-run) would activate plan: $Plan"; return }
    Write-Log "[power] activating $Plan plan ..."
    & powercfg.exe -duplicatescheme $guid 2>$null | Out-Null
    & powercfg.exe -setactive $guid | Out-Null
    Write-Log "[power] active plan set to $Plan."
}

# ---------------------------------------------------------------------------
# Windows Features (Config tab)
# ---------------------------------------------------------------------------
$Script:WinFeatures = [ordered]@{
    '.NET Framework 3.5' = 'NetFx3'
    '.NET Framework 4.8' = 'NET-Framework-45-Features'
    'Hyper-V'            = 'Microsoft-Hyper-V-All'
    'Windows Sandbox'    = 'Containers-DisposableClientVM'
    'WSL'                = 'Microsoft-Windows-Subsystem-Linux'
    'Virtual Machine Platform' = 'VirtualMachinePlatform'
    'Legacy Media (WMP / DirectPlay)' = 'LegacyComponents'
    'NFS (Network File System)'      = 'ServicesForNFS'
    'Windows Media Player'           = 'WindowsMediaPlayer'
    'Windows Subsystem for Android'  = 'Microsoft-Windows-Subsystem-Android'
    'MSMQ'               = 'MSMQ-Container'
    'SMB1'               = 'SMB1Protocol'
}

function Get-WinFeatures {
    <#
        .SYNOPSIS
        Prints FEAT|id|label|enabled for the curated feature list.
        Requires elevation; falls back to "unknown" state otherwise.
    #>
    foreach ($label in $Script:WinFeatures.Keys) {
        $fname = $Script:WinFeatures[$label]
        $enabled = 'unknown'
        try {
            $f = Get-WindowsOptionalFeature -Online -FeatureName $fname -ErrorAction Stop
            if ($f) { $enabled = ($f.State -eq 'Enabled') }
        }
        catch {
            $enabled = 'unknown'
        }
        Write-Log "FEAT|$fname|$label|$enabled"
    }
    Write-Log "=== FEATURES LIST COMPLETE ==="
}

function Set-WinFeatures {
    <#
        .SYNOPSIS
        Enables or disables Windows optional features.
        -Enable 'NetFx3' or -Disable 'Hyper-V'. Multiple names via -Feature.
    #>
    param(
        [string[]]$Feature = @(),
        [switch]$Enable,
        [switch]$Disable,
        [switch]$DryRun
    )
    $features = @($Feature | ForEach-Object { ($_ -split ',') } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($features.Count -eq 0) {
        Write-Log "[features] no features selected."
        return
    }
    if ($Enable -and $Disable) { Write-Log "[features] pick either -Enable or -Disable, not both."; return }

    $action = if ($Enable) { 'Enable' } else { 'Disable' }
    foreach ($f in $features) {
        if ($DryRun) {
            Write-Log "[features] (dry-run) would $($action.ToLower()) feature: $f"
            continue
        }
        Write-Log "[features] ${action}ing $f ..."
        if ($Enable) {
            if ($f -eq 'NetFx3') {
                # Needs Windows Update as source; try local source first, fall back to WU.
                DISM.exe /Online /Enable-Feature /FeatureName:NetFx3 /All /NoRestart /Quiet | ForEach-Object { Write-Log $_ }
            }
            else {
                Enable-WindowsOptionalFeature -Online -FeatureName $f -All -NoRestart -ErrorAction SilentlyContinue | Out-Null
            }
        }
        else {
            Disable-WindowsOptionalFeature -Online -FeatureName $f -NoRestart -ErrorAction SilentlyContinue | Out-Null
        }
    }
    Write-Log "[features] done. Some features require a restart."
}

# ---------------------------------------------------------------------------
# System Fixes (Config tab)
# ---------------------------------------------------------------------------
$Script:Fixes = @{
    'Autologin'        = 'Set up automatic login for the current user'
    'ResetWindowsUpdate' = 'Re-register update DLLs and restart update services'
    'ResetNetwork'     = 'netsh int ip reset + winsock reset'
    'SystemCorruption' = 'sfc /scannow + DISM /RestoreHealth'
    'WinGetReinstall'  = 'Restore WinGet if installs start failing'
}

function Get-Fixes {
    foreach ($key in $Script:Fixes.Keys) {
        Write-Log "FIX|$key|$($Script:Fixes[$key])"
    }
    Write-Log "=== FIXES LIST COMPLETE ==="
}

function Invoke-Fix {
    param(
        [Parameter(Mandatory = $true)][string]$Fix,
        [switch]$DryRun
    )
    if (-not $Script:Fixes.ContainsKey($Fix)) { Write-Log "[fix] unknown fix: $Fix"; return }
    if ($DryRun) { Write-Log "[fix] (dry-run) would run: $Fix"; return }

    switch ($Fix) {
        'Autologin' {
            $user = [Environment]::UserName
            $domain = [Environment]::UserDomainName
            $key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
            Set-ItemProperty -Path $key -Name 'AutoAdminLogon' -Value '1' -Type String
            Set-ItemProperty -Path $key -Name 'DefaultUserName' -Value $user -Type String
            Set-ItemProperty -Path $key -Name 'DefaultDomainName' -Value $domain -Type String
            Write-Log "[fix] autologin enabled for $domain\$user (password may need to be set)."
        }
        'ResetWindowsUpdate' {
            Write-Log "[fix] resetting Windows Update components ..."
            $svc = 'wuauserv','bits','cryptsvc','msiserver'
            foreach ($s in $svc) { Stop-Service $s -Force -ErrorAction SilentlyContinue }
            & regsvr32.exe /s atl.dll
            & regsvr32.exe /s urlmon.dll
            & regsvr32.exe /s mshtml.dll
            & regsvr32.exe /s shdocvw.dll
            & regsvr32.exe /s browseui.dll
            & regsvr32.exe /s jscript.dll
            & regsvr32.exe /s vbscript.dll
            & regsvr32.exe /s scrrun.dll
            & regsvr32.exe /s msxml.dll
            & regsvr32.exe /s msxml3.dll
            & regsvr32.exe /s msxml6.dll
            & regsvr32.exe /s actxprxy.dll
            & regsvr32.exe /s softpub.dll
            & regsvr32.exe /s wintrust.dll
            & regsvr32.exe /s dssenh.dll
            & regsvr32.exe /s rsaenh.dll
            & regsvr32.exe /s gpkcsp.dll
            & regsvr32.exe /s sccbase.dll
            & regsvr32.exe /s slbcsp.dll
            & regsvr32.exe /s cryptdlg.dll
            foreach ($s in $svc) { Set-Service $s -StartupType Manual -ErrorAction SilentlyContinue; Start-Service $s -ErrorAction SilentlyContinue }
            Write-Log "[fix] Windows Update components re-registered."
        }
        'ResetNetwork' {
            Write-Log "[fix] resetting network stack ..."
            & netsh.exe int ip reset | ForEach-Object { Write-Log $_ }
            & netsh.exe winsock reset | ForEach-Object { Write-Log $_ }
            Write-Log "[fix] network reset complete. Restart recommended."
        }
        'SystemCorruption' {
            Write-Log "[fix] running sfc /scannow (this can take a while) ..."
            & sfc.exe /scannow | ForEach-Object { Write-Log $_ }
            Write-Log "[fix] running DISM /RestoreHealth ..."
            & DISM.exe /Online /Cleanup-Image /RestoreHealth | ForEach-Object { Write-Log $_ }
            Write-Log "[fix] system corruption check complete."
        }
        'WinGetReinstall' {
            Write-Log "[fix] reinstalling WinGet ..."
            $installer = "$env:TEMP\WinGet.msixbundle"
            $url = 'https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
            Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing
            Add-AppxPackage -Path $installer -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
            Write-Log "[fix] WinGet reinstalled."
        }
    }
}

# ---------------------------------------------------------------------------
# Legacy Windows Panels
# ---------------------------------------------------------------------------
$Script:LegacyPanels = @{
    'ControlPanel'     = @{ Label = 'Control Panel';   Command = 'control.exe' }
    'NetworkConnections' = @{ Label = 'Network Connections'; Command = 'ncpa.cpl' }
    'PowerPanel'       = @{ Label = 'Power Options';   Command = 'powercfg.cpl' }
    'Region'           = @{ Label = 'Region';          Command = 'intl.cpl' }
    'SoundSettings'    = @{ Label = 'Sound';           Command = 'mmsys.cpl' }
    'SystemProperties' = @{ Label = 'System Properties'; Command = 'sysdm.cpl' }
    'UserAccounts'     = @{ Label = 'User Accounts';   Command = 'control.exe userpasswords2' }
    'RemoteAccess'     = @{ Label = 'Remote Access';   Command = 'control.exe sysdm.cpl,,5' }
}

function Get-LegacyPanels {
    foreach ($key in $Script:LegacyPanels.Keys) {
        Write-Log "PANEL|$key|$($Script:LegacyPanels[$key].Label)"
    }
    Write-Log "=== PANELS LIST COMPLETE ==="
}

function Invoke-LegacyPanel {
    param([Parameter(Mandatory = $true)][string]$Panel)
    if (-not $Script:LegacyPanels.ContainsKey($Panel)) { Write-Log "[panel] unknown panel: $Panel"; return }
    Write-Log "[panel] launching $($Script:LegacyPanels[$Panel].Label) ..."
    $cmd = $Script:LegacyPanels[$Panel].Command
    $parts = $cmd -split ' ', 2
    if ($parts.Count -eq 2) {
        Start-Process -FilePath $parts[0] -ArgumentList $parts[1]
    }
    else {
        Start-Process -FilePath $cmd
    }
    Write-Log "[panel] done."
}

# ---------------------------------------------------------------------------
# OpenSSH server
# ---------------------------------------------------------------------------
function Set-SshServer {
    param(
        [switch]$Enable,
        [switch]$Disable,
        [switch]$DryRun
    )
    if ($DryRun) {
        $which = if ($Enable) { 'enable' } else { 'disable' }
        Write-Log "[ssh] (dry-run) would $which OpenSSH server"
        return
    }
    if ($Enable) {
        Write-Log "[ssh] installing/enabling OpenSSH server ..."
        Get-WindowsCapability -Online -Name 'OpenSSH.Server*' | ForEach-Object {
            Add-WindowsCapability -Online -Name $_.Name | Out-Null
        }
        Set-Service sshd -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service sshd -ErrorAction SilentlyContinue
        New-NetFirewallRule -DisplayName 'OpenSSH Server' -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow -ErrorAction SilentlyContinue | Out-Null
        Write-Log "[ssh] OpenSSH server enabled on port 22."
    }
    else {
        Write-Log "[ssh] disabling OpenSSH server ..."
        Stop-Service sshd -Force -ErrorAction SilentlyContinue
        Set-Service sshd -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Log "[ssh] OpenSSH server disabled."
    }
}

# ---------------------------------------------------------------------------
# Undo selected tweaks (Phase 3)
# ---------------------------------------------------------------------------
# Reverses every registry / service change that Apply-SystemTweaks makes.
function Undo-SystemTweaks {
    <#
        .SYNOPSIS
        Reverts the effects of Apply-SystemTweaks for the selected tweaks.
        -All undoes every tweak; -Tweak a,b undoes specific ones.
    #>
    param(
        [switch]$All,
        [string[]]$Tweak = @(),
        [switch]$DryRun
    )
    $targets = [System.Collections.Generic.List[string]]::new()
    if ($All) { $Script:TweakOptions.Keys | ForEach-Object { $targets.Add($_) } }
    foreach ($t in $Tweak) { $targets.Add($t) }
    $targets = $targets | Sort-Object -Unique
    if ($targets.Count -eq 0) { Write-Log "[undo] nothing to undo."; return }
    if (-not $DryRun -and -not (Test-IsAdmin)) { Write-Log "[!] Undo-SystemTweaks requires elevation."; return }

    foreach ($t in $targets) {
        switch ($t) {
            'telemetry' {
                if ($DryRun) { Write-Log "[dry-run] undo telemetry: re-enable DiagTrack/dmwappushservice" }
                else {
                    Set-Service DiagTrack -StartupType Automatic -ErrorAction SilentlyContinue
                    Set-Service dmwappushservice -StartupType Automatic -ErrorAction SilentlyContinue
                    Start-Service DiagTrack -ErrorAction SilentlyContinue
                    Start-Service dmwappushservice -ErrorAction SilentlyContinue
                    $k = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
                    if (Test-Path $k) { Remove-ItemProperty -Path $k -Name 'AllowTelemetry' -ErrorAction SilentlyContinue }
                    Write-Log "[undo] telemetry restored"
                }
            }
            'backgroundapps' {
                if ($DryRun) { Write-Log "[dry-run] undo backgroundapps: allow by default" }
                else {
                    $k = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'
                    if (Test-Path $k) { Remove-ItemProperty -Path $k -Name 'LetAppsRunInBackground' -ErrorAction SilentlyContinue }
                    Write-Log "[undo] background apps restored"
                }
            }
            'hibernation' {
                if ($DryRun) { Write-Log "[dry-run] undo hibernation: powercfg /h on" }
                else {
                    & powercfg.exe /h on | Out-Null
                    Write-Log "[undo] hibernation re-enabled"
                }
            }
            'faststartup' {
                if ($DryRun) { Write-Log "[dry-run] undo faststartup: HiberbootEnabled=1" }
                else {
                    Set-RegistryDword -Key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -Value 1
                    Write-Log "[undo] fast startup re-enabled"
                }
            }
            'gamebar' {
                if ($DryRun) { Write-Log "[dry-run] undo gamebar: allow Game DVR" }
                else {
                    $k = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'
                    if (Test-Path $k) { Remove-ItemProperty -Path $k -Name 'AllowGameDVR' -ErrorAction SilentlyContinue }
                    Write-Log "[undo] game bar re-enabled"
                }
            }
            'cortana' {
                if ($DryRun) { Write-Log "[dry-run] undo cortana: allow" }
                else {
                    $k = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
                    if (Test-Path $k) { Remove-ItemProperty -Path $k -Name 'AllowCortana' -ErrorAction SilentlyContinue }
                    Write-Log "[undo] cortana re-enabled"
                }
            }
            'tips' {
                if ($DryRun) { Write-Log "[dry-run] undo tips: re-enable suggestions" }
                else {
                    $k = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
                    if (Test-Path $k) {
                        Remove-ItemProperty -Path $k -Name 'DisableSoftLanding' -ErrorAction SilentlyContinue
                        Remove-ItemProperty -Path $k -Name 'DisableConsumerAccountFeatures' -ErrorAction SilentlyContinue
                        Remove-ItemProperty -Path $k -Name 'DisableWindowsConsumerFeatures' -ErrorAction SilentlyContinue
                    }
                    Write-Log "[undo] tips restored"
                }
            }
            'searchweb' {
                if ($DryRun) { Write-Log "[dry-run] undo searchweb: allow Bing web results" }
                else {
                    $k = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
                    if (Test-Path $k) { Remove-ItemProperty -Path $k -Name 'ConnectedSearchUseWeb' -ErrorAction SilentlyContinue }
                    Write-Log "[undo] Bing web results restored"
                }
            }
        }
    }
    Write-Log "[undo] done."
}

# ---------------------------------------------------------------------------
# Win11 Creator (Phase 4) - custom ISO builder
# ---------------------------------------------------------------------------
# Builds a debloated Windows 11 ISO from a source ISO.
# Pipeline: mount ISO -> copy to staging -> DISM mount install.wim ->
#           strip bloat + apply privacy tweaks -> commit -> rebuild ISO.

function Test-Oscdimg {
    # oscdimg ships with the Windows ADK. Returns the path if found.
    $candidates = @(
        "$env:ProgramFiles(x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\oscdimg\oscdimg.exe",
        "$env:ProgramFiles(x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x64\oscdimg\oscdimg.exe",
        "$env:ProgramFiles\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\oscdimg\oscdimg.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    return $null
}

function Mount-IsoPath {
    param([Parameter(Mandatory = $true)][string]$Iso)
    $img = Mount-DiskImage -ImagePath $Iso -PassThru -ErrorAction SilentlyContinue
    if ($img) {
        $drv = $img | Get-Volume | Select-Object -ExpandProperty DriveLetter
        if ($drv) { return "$drv`:" }
    }
    return $null
}

function New-Win11Iso {
    <#
        .SYNOPSIS
        Creates a customized Windows 11 ISO from a source ISO.
        .PARAMETER SourceIso   Path to a Windows 11 ISO.
        .PARAMETER OutPath     Where to write the custom ISO (default Desktop).
        .PARAMETER Index       install.wim index to use (default: highest).
        .PARAMETER StripBloat  Remove known bloat Appx packages from the image.
        .PARAMETER DisableTelemetry  Apply offline privacy registry tweaks.
        .PARAMETER RemoveOneDrive    Disable OneDrive in the image.
        .PARAMETER DryRun     Preview only.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$SourceIso,
        [string]$OutPath = "$env:USERPROFILE\Desktop\Win11-Custom.iso",
        [int]$Index = 0,
        [switch]$StripBloat,
        [switch]$DisableTelemetry,
        [switch]$RemoveOneDrive,
        [switch]$DryRun
    )
    if (-not (Test-Path -LiteralPath $SourceIso)) {
        Write-Log "[win11] ERROR: source ISO not found: $SourceIso"
        return
    }
    $OutPath = if ([System.IO.Path]::IsPathRooted($OutPath)) { $OutPath } else { Join-Path (Get-Location) $OutPath }
    if ($DryRun) {
        Write-Log "[win11] (dry-run) would build: $OutPath"
        Write-Log "[win11] (dry-run) source: $SourceIso, bloat=$StripBloat telemetry=$DisableTelemetry onedrive=$RemoveOneDrive"
        return
    }

    $oscdimg = Test-Oscdimg
    if (-not $oscdimg) {
        Write-Log "[win11] WARNING: oscdimg (Windows ADK) not found. ISO rebuild will be skipped."
        Write-Log "[win11] Install the 'Deployment Tools' from the Windows ADK to rebuild the ISO."
    }

    $staging = Join-Path $env:TEMP "win11create_$([guid]::NewGuid().ToString('N').Substring(0,8))"
    $mountDir = Join-Path $staging 'mount'
    $isoDir = Join-Path $staging 'iso'
    New-Item -ItemType Directory -Path $mountDir, $isoDir -Force | Out-Null

    try {
        Write-Log "[win11] mounting source ISO ..."
        $srcDrive = Mount-IsoPath $SourceIso
        if (-not $srcDrive) {
            Write-Log "[win11] ERROR: could not mount source ISO."
            return
        }

        Write-Log "[win11] copying ISO contents (large; this takes a few minutes) ..."
        Copy-Item -LiteralPath "$srcDrive\*" -Destination $isoDir -Recurse -Force

        $wim = Join-Path $isoDir 'sources\install.wim'
        if (-not (Test-Path -LiteralPath $wim)) {
            # Windows 11 ISOs may use install.esd
            $esd = Join-Path $isoDir 'sources\install.esd'
            if (Test-Path -LiteralPath $esd) {
                Write-Log "[win11] found install.esd; exporting to install.wim ..."
                $wim = Join-Path $isoDir 'sources\install.wim'
                DISM.exe /Export-Image /SourceImageFile:$esd /SourceIndex:1 /DestinationImageFile:$wim /Compress:max /CheckIntegrity 2>$null | ForEach-Object { Write-Log $_ }
            }
            else {
                Write-Log "[win11] ERROR: no install.wim/install.esd found in ISO."
                return
            }
        }

        # Pick image index
        $info = DISM.exe /Get-WimInfo /ImageFile:$wim 2>$null
        $indexes = @($info | Select-String '^Index :\s+(\d+)' | ForEach-Object { [int]$_.Matches[0].Groups[1].Value })
        if ($indexes.Count -eq 0) {
            Write-Log "[win11] ERROR: no image indexes found in $wim"
            return
        }
        if ($Index -le 0 -or $Index -gt $indexes[-1]) { $Index = $indexes[-1] }
        $editionMatch = $info | Select-String -Pattern "^Edition ID\s*:\s*(\S+)"
        if (-not $editionMatch) {
            Write-Log "[win11] ERROR: could not determine edition for image index $Index."
            return
        }
        $edition = $editionMatch.Matches[0].Groups[1].Value
        Write-Log "[win11] mounting image index $Index ($edition) ..."

        DISM.exe /Mount-Image /ImageFile:$wim /Index:$Index /MountDir:$mountDir /Optimize | ForEach-Object { Write-Log $_ }

        if ($StripBloat) {
            Write-Log "[win11] stripping bloat packages ..."
            $bloat = @(
                'Microsoft.BingNews','Microsoft.BingWeather','Microsoft.BingSports',
                'Microsoft.BingFinance','Microsoft.MicrosoftSolitaireCollection',
                'Microsoft.MicrosoftOfficeHub','Microsoft.Office.OneNote',
                'Microsoft.People','Microsoft.WindowsFeedbackHub','Microsoft.MixedReality.Portal',
                'Microsoft.Todos','Microsoft.WindowsAlarms','Microsoft.WindowsCamera',
                'Microsoft.WindowsCommunicationsApps','Microsoft.XboxGameCallableUI',
                'Microsoft.XboxApp','Microsoft.ZuneMusic','Microsoft.ZuneVideo'
            )
            $installed = @(Get-AppxProvisionedPackage -Path $mountDir -ErrorAction SilentlyContinue)
            foreach ($pkg in $installed) {
                if ($pkg.DisplayName -in $bloat) {
                    Write-Log "[win11] removing: $($pkg.DisplayName)"
                    Remove-AppxProvisionedPackage -Path $mountDir -PackageName $pkg.PackageName -ErrorAction SilentlyContinue | Out-Null
                }
            }
        }

        if ($RemoveOneDrive) {
            Write-Log "[win11] disabling OneDrive ..."
            $pkg = Get-AppxProvisionedPackage -Path $mountDir -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Microsoft.OneDrive*' }
            if ($pkg) {
                Remove-AppxProvisionedPackage -Path $mountDir -PackageName $pkg.PackageName -ErrorAction SilentlyContinue | Out-Null
            }
        }

        if ($DisableTelemetry) {
            Write-Log "[win11] applying privacy registry tweaks ..."
            $off = Join-Path $mountDir 'Windows\System32\config'
            # Use a RegistryOffline handle via PowerShell not possible directly;
            # write an offline registry .reg through reg.exe with HKEY_LOCAL_MACHINE
            # via reg load.
            $hive = Join-Path $off 'SOFTWARE'
            $tmpKey = 'HKLM\TEMP_WIN11'
            & reg.exe load "$tmpKey" $hive | ForEach-Object { Write-Log $_ }
            $sets = @(
                @{ Key = "$tmpKey\Policies\Microsoft\Windows\DataCollection"; Name = 'AllowTelemetry'; Value = 0; Type = 'DWORD' },
                @{ Key = "$tmpKey\Policies\Microsoft\Windows\OneDrive"; Name = 'DisableFileSyncNGSC'; Value = 1; Type = 'DWORD' }
            )
            foreach ($s in $sets) {
                New-Item -Path $s.Key -Force | Out-Null
                if ($s.Type -eq 'DWORD') { Set-ItemProperty -Path $s.Key -Name $s.Name -Value $s.Value -Type DWord }
            }
            & reg.exe unload "$tmpKey" 2>$null | Out-Null
        }

        Write-Log "[win11] committing image changes ..."
        DISM.exe /Commit-Image /MountDir:$mountDir /CheckIntegrity | ForEach-Object { Write-Log $_ }
        Write-Log "[win11] unmounting ..."
        DISM.exe /Unmount-Image /MountDir:$mountDir /Commit | ForEach-Object { Write-Log $_ }

        if ($oscdimg) {
            Write-Log "[win11] rebuilding ISO with oscdimg ..."
            & $oscdimg -m -o -u2 -udfver102 -bootdata:2 -h -l WIN11CUSTOM "$isoDir" $OutPath 2>&1 | ForEach-Object { Write-Log $_ }
            if (Test-Path -LiteralPath $OutPath) {
                Write-Log "[win11] DONE: custom ISO written to $OutPath"
            }
            else {
                Write-Log "[win11] ERROR: ISO rebuild produced no output. Check ADK tools."
            }
        }
        else {
            Write-Log "[win11] Staging files left at $isoDir - copy this folder onto a USB stick with Rufus to create a bootable drive."
        }
    }
    catch {
        Write-Log "[win11] ERROR: $($_.Exception.Message)"
    }
    finally {
        if (Test-Path -LiteralPath $mountDir) {
            # Best-effort cleanup; ignore errors if still mounted.
            try { DISM.exe /Unmount-Image /MountDir:$mountDir /Discard 2>$null | Out-Null } catch {}
            Remove-Item -LiteralPath $mountDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# Anti-Brick pre-flight checks (Safety & Security First)
# ---------------------------------------------------------------------------
# Heavy operations (DISM repairs, ISO creation, deep debloat, bulk installs)
# call Test-Preflight first. Any failed check logs PRE|...|fail and returns
# $false so the caller aborts before touching the system.
function Test-Preflight {
    <#
        .SYNOPSIS
        Validates that the system is safe for a heavy operation.
        Action = iso | dism | debloat | install
        Emits PRE|category|status|detail lines and returns $true/$false.
    #>
    param(
        [ValidateSet('iso', 'dism', 'debloat', 'install')]
        [string]$Action = 'dism'
    )
    $ok = $true

    # --- Disk space: need >= 20 GB free on C: for image/repair work ---
    try {
        $drive = Get-PSDrive -Name C -ErrorAction Stop
        $freeGB = [math]::Round($drive.Free / 1GB, 1)
        $needGB = 20
        if ($freeGB -lt $needGB) {
            $ok = $false
            Write-Log "PRE|disk|fail|C: only $freeGB GB free (need >= $needGB GB) for $Action"
        }
        else {
            Write-Log "PRE|disk|ok|C: $freeGB GB free"
        }
    }
    catch {
        Write-Log "PRE|disk|fail|could not query C: drive ($($_.Exception.Message))"
        $ok = $false
    }

    # --- Battery: laptops need >= 30% or charging for long jobs ---
    try {
        $batt = Get-CimInstance Win32_Battery -ErrorAction Stop
        if ($batt) {
            $pct = $batt.EstimatedChargeRemaining
            $charging = ($batt.BatteryStatus -in 2, 6)  # 2 = AC, 6 = charging
            if ($pct -lt 30 -and -not $charging) {
                $ok = $false
                Write-Log "PRE|battery|fail|Battery at $pct% and not charging (need >= 30% or AC power)"
            }
            else {
                $status = if ($charging) { 'charging' } else { "$pct% battery" }
                Write-Log "PRE|battery|ok|$status"
            }
        }
        else {
            Write-Log "PRE|battery|ok|desktop (no battery)"
        }
    }
    catch {
        Write-Log "PRE|battery|ok|unable to query battery, skipping"
    }

    # --- Elevation: heavy ops must run as admin ---
    if (-not (Test-IsAdmin)) {
        $ok = $false
        Write-Log "PRE|admin|fail|elevation required for $Action"
    }
    else {
        Write-Log "PRE|admin|ok|elevated"
    }

    if ($ok) {
        Write-Log "PRE|RESULT|ok|All pre-flight checks passed"
    }
    else {
        Write-Log "PRE|RESULT|fail|Pre-flight checks failed - operation aborted"
    }
    return $ok
}

# ---------------------------------------------------------------------------
# 1-Click Power-User Profiles
# ---------------------------------------------------------------------------
$Script:ProfileApps = [ordered]@{
    'Gamer'     = @(
        @{ Id = 'Discord.Discord'; Name = 'Discord' }
        @{ Id = 'OBSProject.OBSStudio'; Name = 'OBS Studio' }
        @{ Id = 'Parsec.Parsec'; Name = 'Parsec' }
    )
    'Developer' = @(
        @{ Id = 'Microsoft.VisualStudioCode'; Name = 'VS Code' }
        @{ Id = 'Git.Git'; Name = 'Git' }
        @{ Id = 'Python.Python.3.12'; Name = 'Python 3.12' }
        @{ Id = 'OpenJS.NodeJS.LTS'; Name = 'Node.js LTS' }
        @{ Id = 'Docker.DockerDesktop'; Name = 'Docker Desktop' }
    )
    'Privacy'   = @(
        @{ Id = 'Mozilla.Firefox'; Name = 'Firefox' }
        @{ Id = 'Bitwarden.Bitwarden'; Name = 'Bitwarden' }
        @{ Id = 'ProtonVPN.ProtonVPN'; Name = 'Proton VPN' }
    )
}

function Invoke-Profile {
    <#
        .SYNOPSIS
        Applies a complete power-user profile in one click.
        Profile = Gamer | Privacy | Developer
    #>
    param(
        [ValidateSet('Gamer', 'Privacy', 'Developer')]
        [Parameter(Mandatory = $true)][string]$Profile,
        [switch]$DryRun
    )
    Write-Log "PROF|$Profile|Applying $Profile profile ..."
    if (-not $DryRun -and -not (Test-IsAdmin)) {
        Write-Log "[profile] requires elevation."
        return
    }

    switch ($Profile) {
        'Gamer' {
            Write-Log "PROF|$Profile|Max performance power plan"
            Set-PowerPlan -Plan 'Ultimate' -DryRun:$DryRun
            Write-Log "PROF|$Profile|Background apps blocked"
            Apply-SystemTweaks -Tweak 'backgroundapps' -DryRun:$DryRun
            Write-Log "PROF|$Profile|Game Bar DVR disabled"
            Apply-SystemTweaks -Tweak 'gamebar' -DryRun:$DryRun
        }
        'Privacy' {
            Write-Log "PROF|$Profile|Telemetry + Cortana + Bing disabled"
            Apply-SystemTweaks -Tweak @('telemetry', 'cortana', 'searchweb', 'tips', 'backgroundapps') -DryRun:$DryRun
            Write-Log "PROF|$Profile|AdGuard DNS applied"
            Set-DnsPreset -Preset 'AdGuard' -DryRun:$DryRun
            Write-Log "PROF|$Profile|Windows Update security policy"
            Set-UpdateMode -Mode 'Security' -DryRun:$DryRun
        }
        'Developer' {
            Write-Log "PROF|$Profile|High performance power plan"
            Set-PowerPlan -Plan 'HighPerformance' -DryRun:$DryRun
            Write-Log "PROF|$Profile|Enabling WSL, Hyper-V, Sandbox, VM Platform"
            Set-WinFeatures -Feature @('Microsoft-Windows-Subsystem-Linux', 'Microsoft-Hyper-V-All', 'Containers-DisposableClientVM', 'VirtualMachinePlatform') -Enable -DryRun:$DryRun
            Write-Log "PROF|$Profile|Installing dev essentials"
            $ids = @($Script:ProfileApps['Developer'] | ForEach-Object { $_.Id })
            Invoke-WingetAction -Action install -App $ids -DryRun:$DryRun
        }
    }
    Write-Log "PROF|$Profile|Profile complete"
}

# ---------------------------------------------------------------------------
# Config Import / Export (JSON profiles)
# ---------------------------------------------------------------------------
# Profiles capture the user's winget apps, tweaks, DNS, power plan, update mode
# and optional feature/SSH settings. Shareable as a single .json file.

function Get-ProfileDir {
    $dir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Win-Optimizer-Pro'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    return $dir
}

function Export-OptimizerConfig {
    <#
        .SYNOPSIS
        Writes the selected settings to a shareable JSON profile.
        -Path or -Name (stored in Documents\Win-Optimizer-Pro).
    #>
    param(
        [string[]]$WingetApps = @(),
        [string[]]$Tweaks = @(),
        [string]$Dns = $null,
        [string]$Power = $null,
        [string]$UpdateMode = $null,
        [string[]]$FeaturesEnable = @(),
        [switch]$Ssh,
        [string]$Path = $null,
        [string]$Name = $null
    )
    if (-not $Path) {
        $Name = if ($Name) { $Name } else { "profile-$(Get-Date -Format 'yyyyMMdd-HHmmss')" }
        $Path = Join-Path (Get-ProfileDir) "$Name.json"
    }
    $profile = [ordered]@{
        version    = 1
        app        = 'win-optimizer-pro'
        created    = (Get-Date).ToString('o')
        apps       = @($WingetApps)
        tweaks     = @($Tweaks)
        dns        = $Dns
        power      = $Power
        updateMode = $UpdateMode
        featuresEnable = @($FeaturesEnable)
        ssh        = [bool]$Ssh
    }
    try {
        $json = $profile | ConvertTo-Json -Depth 4
        Set-Content -LiteralPath $Path -Value $json -Encoding UTF8
        Write-Log "CONFIG|exported|$Path"
    }
    catch {
        Write-Log "CONFIG|error|$($_.Exception.Message)"
    }
}

function Get-OptimizerConfigs {
    $dir = Get-ProfileDir
    Get-ChildItem -LiteralPath $dir -Filter '*.json' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | ForEach-Object {
        Write-Log "CONFIG|$($_.BaseName)|$($_.FullName)|$($_.LastWriteTime.ToString('g'))"
    }
    Write-Log "=== CONFIG LIST COMPLETE ==="
}

function Import-OptimizerConfig {
    <#
        .SYNOPSIS
        Applies a JSON profile. -DryRun previews which changes it would make.
        -Path or -Name (from the profile library) selects the profile.
    #>
    param(
        [string]$Path = $null,
        [string]$Name = $null,
        [switch]$DryRun
    )
    if (-not $Path -and $Name) {
        $Path = Join-Path (Get-ProfileDir) "$Name.json"
    }
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        Write-Log "CONFIG|error|profile not found: $Path"
        return
    }
    try {
        $p = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    }
    catch {
        Write-Log "CONFIG|error|invalid profile JSON: $($_.Exception.Message)"
        return
    }
    Write-Log "CONFIG|loaded|$Path"

    if ($p.apps) {
        Write-Log "CONFIG|step|Install $($p.apps.Count) app(s): $($p.apps -join ', ')"
        Invoke-WingetAction -Action install -App @($p.apps) -DryRun:$DryRun
    }
    if ($p.tweaks) {
        Write-Log "CONFIG|step|Apply tweaks: $($p.tweaks -join ', ')"
        Apply-SystemTweaks -Tweak @($p.tweaks) -DryRun:$DryRun
    }
    if ($p.dns) {
        Write-Log "CONFIG|step|DNS preset: $($p.dns)"
        Set-DnsPreset -Preset $p.dns -DryRun:$DryRun
    }
    if ($p.power) {
        Write-Log "CONFIG|step|Power plan: $($p.power)"
        Set-PowerPlan -Plan $p.power -DryRun:$DryRun
    }
    if ($p.updateMode) {
        Write-Log "CONFIG|step|Update mode: $($p.updateMode)"
        Set-UpdateMode -Mode $p.updateMode -DryRun:$DryRun
    }
    if ($p.featuresEnable) {
        Write-Log "CONFIG|step|Enable features: $($p.featuresEnable -join ', ')"
        Set-WinFeatures -Feature @($p.featuresEnable) -Enable -DryRun:$DryRun
    }
    if ($p.PSObject.Properties['ssh'] -and $p.ssh) {
        Write-Log "CONFIG|step|Enable OpenSSH server"
        Set-SshServer -Enable -DryRun:$DryRun
    }
    Write-Log "CONFIG|imported|profile applied"
}

# ---------------------------------------------------------------------------
# Windows 11 context menu + Startup manager
# ---------------------------------------------------------------------------
# Classic restores the Windows 10-style right-click menu (Win11 -> Win10).

function Set-ContextMenuStyle {
    <#
        .SYNOPSIS
        Classic = restore the Windows 10 full context menu on Windows 11.
        Default = restore the modern Win11 compact menu.
    #>
    param(
        [ValidateSet('Classic', 'Default')]
        [Parameter(Mandatory = $true)][string]$Style,
        [switch]$DryRun
    )
    $clsid = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
    if ($Style -eq 'Classic') {
        if ($DryRun) { Write-Log "[ctxmenu] (dry-run) would enable classic context menu"; return }
        New-Item -Path $clsid -Force | Out-Null
        Set-ItemProperty -Path $clsid -Name '(default)' -Value '' -Type String -Force
        Write-Log "[ctxmenu] classic context menu enabled"
    }
    else {
        if ($DryRun) { Write-Log "[ctxmenu] (dry-run) would restore default context menu"; return }
        if (Test-Path -LiteralPath 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}') {
            Remove-Item -LiteralPath 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}' -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-Log "[ctxmenu] default context menu restored"
    }
    if (-not $DryRun) {
        Write-Log "[ctxmenu] restarting Explorer to apply ..."
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Start-Process explorer.exe -ErrorAction SilentlyContinue
    }
}

function Get-ContextMenuState {
    <#
        .SYNOPSIS
        Reports whether the classic (Win10-style) context menu is enabled.
        Emits CTXMENU|classic|true|false.
    #>
    $clsid = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'
    $classic = Test-Path -LiteralPath $clsid
    Write-Log "CTXMENU|classic|$classic"
}

function Get-StartupItems {
    <#
        .SYNOPSIS
        Lists startup entries from registry Run keys and the Startup folders.
        Emits STARTUP|scope|name|command|enabled.
    #>
    $sources = @(
        @{ Scope = 'HKCU'; Key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Scope = 'HKLM'; Key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' },
        @{ Scope = 'HKLM32'; Key = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' }
    )
    foreach ($s in $sources) {
        if (Test-Path -LiteralPath $s.Key) {
            $props = Get-ItemProperty -LiteralPath $s.Key
            foreach ($p in $props.PSObject.Properties) {
                if ($p.Name -in @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')) { continue }
                if ($p.Value) {
                    Write-Log "STARTUP|$($s.Scope)|$($p.Name)|$($p.Value)|true"
                }
            }
        }
    }
    # Startup folders
    $folders = @(
        @{ Scope = 'USERFOLDER'; Path = [Environment]::GetFolderPath('Startup') },
        @{ Scope = 'MACHINEFOLDER'; Path = [Environment]::GetFolderPath('CommonStartup') }
    )
    foreach ($f in $folders) {
        if ($f.Path -and (Test-Path -LiteralPath $f.Path)) {
            Get-ChildItem -LiteralPath $f.Path -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in '.lnk', '.url', '.bat', '.cmd', '.exe', '.vbs' } | ForEach-Object {
                Write-Log "STARTUP|$($f.Scope)|$($_.Name)|$($_.FullName)|true"
            }
        }
    }
    Write-Log "=== STARTUP LIST COMPLETE ==="
}

function Set-StartupItem {
    <#
        .SYNOPSIS
        Disables or enables a startup entry.
        -Item "<scope>|<name>" (as emitted by Get-StartupItems).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Item,
        [switch]$Enable,
        [switch]$Disable,
        [switch]$DryRun
    )
    $parts = $Item.Split('|', 2)
    if ($parts.Count -ne 2) { Write-Log "[startup] invalid item: $Item"; return }
    $scope = $parts[0]
    $name = $parts[1]

    if ($scope -in 'HKCU', 'HKLM', 'HKLM32') {
        $key = switch ($scope) {
            'HKCU'   { 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' }
            'HKLM'   { 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' }
            'HKLM32' { 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' }
        }
        $disabledKey = switch ($scope) {
            'HKCU'   { 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunDisabled' }
            'HKLM'   { 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunDisabled' }
            'HKLM32' { 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunDisabled' }
        }
        $value = (Get-ItemProperty -LiteralPath $key -Name $name -ErrorAction SilentlyContinue).$name
        if ($null -eq $value) {
            # Maybe already moved to RunDisabled
            $value = (Get-ItemProperty -LiteralPath $disabledKey -Name $name -ErrorAction SilentlyContinue).$name
            if ($null -eq $value) { Write-Log "[startup] item not found: $Item"; return }
            $from = $disabledKey; $to = $key
        }
        else {
            $from = $key; $to = $disabledKey
        }
        if ($Disable -and $from -eq $disabledKey) { Write-Log "[startup] already disabled: $name"; return }
        if ($Enable -and $from -eq $key) { Write-Log "[startup] already enabled: $name"; return }

        $action = if ($Enable) { 'enable' } else { 'disable' }
        if ($DryRun) { Write-Log "[startup] (dry-run) would ${action}: $name"; return }
        New-Item -Path $to -Force | Out-Null
        Set-ItemProperty -Path $to -Name $name -Value $value -Type String -Force
        Remove-ItemProperty -Path $from -Name $name -ErrorAction SilentlyContinue
        Write-Log "[startup] ${action}d: $name"
    }
    else {
        # File-based startup entry (Startup folders)
        if (-not (Test-Path -LiteralPath $name)) { Write-Log "[startup] file not found: $name"; return }
        $dir = Split-Path -Parent $name
        $base = Split-Path -Leaf $name
        if ($Disable) {
            if ($base -like '*.disabled') { Write-Log "[startup] already disabled: $base"; return }
            if ($DryRun) { Write-Log "[startup] (dry-run) would disable: $base"; return }
            Move-Item -LiteralPath $name -Destination (Join-Path $dir "$base.disabled") -Force
            Write-Log "[startup] disabled: $base"
        }
        else {
            if ($base -notlike '*.disabled') { Write-Log "[startup] already enabled: $base"; return }
            $orig = $base -replace '\.disabled$', ''
            if ($DryRun) { Write-Log "[startup] (dry-run) would enable: $orig"; return }
            Move-Item -LiteralPath $name -Destination (Join-Path $dir $orig) -Force
            Write-Log "[startup] enabled: $orig"
        }
    }
}

# ---------------------------------------------------------------------------
# Transparency metadata - registry keys touched by each tweak (UI tooltips)
# ---------------------------------------------------------------------------
function Get-TweakRegistryInfo {
    $info = @{
        'telemetry'     = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection\AllowTelemetry=0'
        'backgroundapps' = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy\LetAppsRunInBackground=2'
        'hibernation'   = 'powercfg /h off (removes hiberfil.sys)'
        'faststartup'   = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power\HiberbootEnabled=0'
        'gamebar'       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR\AllowGameDVR=0'
        'cortana'       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search\AllowCortana=0'
        'tips'          = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent (3x DWORD=1)'
        'searchweb'     = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search\ConnectedSearchUseWeb=0'
    }
    foreach ($k in $info.Keys) {
        Write-Log "TWEAKINFO|$k|$($info[$k])"
    }
}

