# optimizer.ps1 - CLI entry point for the PC Optimizer
#
# Usage:
#   .\optimizer.ps1 -Clean                # temp + browser cache + DNS flush
#   .\optimizer.ps1 -Network              # DNS flush + browser cache only
#   .\optimizer.ps1 -Debloat              # remove all bloatware
#   .\optimizer.ps1 -Debloat -Category Bing,Xbox
#   .\optimizer.ps1 -Debloat -Package Microsoft.SkypeApp
#   .\optimizer.ps1 -Tweaks               # apply all system tweaks
#   .\optimizer.ps1 -Tweaks -Tweak telemetry,backgroundapps
#   .\optimizer.ps1 -UndoTweaks           # revert tweaks
#   .\optimizer.ps1 -UndoTweaks -Tweak telemetry
#   .\optimizer.ps1 -ListTweaks           # show available tweaks
#   .\optimizer.ps1 -SysInfo              # print system specs (CPU/RAM/OS)
#   .\optimizer.ps1 -ListApps             # list installed bloatware (APP|cat|name|display)
#   .\optimizer.ps1 -ListCategories       # show available categories
#   .\optimizer.ps1 -All -DryRun          # preview everything, change nothing
#   .\optimizer.ps1 -All                  # full optimize
#   .\optimizer.ps1 -Restore              # re-register provisioned apps
#
# WinUtil-style features:
#   .\optimizer.ps1 -WingetList           # list catalog + installed state
#   .\optimizer.ps1 -WingetInstall -App a,b
#   .\optimizer.ps1 -WingetUpgrade -App a,b
#   .\optimizer.ps1 -WingetUpgradeAll
#   .\optimizer.ps1 -WingetUninstall -App a,b
#   .\optimizer.ps1 -ListDNS              # show DNS presets
#   .\optimizer.ps1 -SetDNS Google        # apply DNS preset
#   .\optimizer.ps1 -ListUpdateModes      # show update modes
#   .\optimizer.ps1 -SetUpdateMode Security
#   .\optimizer.ps1 -ListPower            # show power plans
#   .\optimizer.ps1 -SetPower Ultimate    # activate power plan
#   .\optimizer.ps1 -ListFeatures         # show Windows features
#   .\optimizer.ps1 -SetFeature -Enable NetFx3 -Feature Hyper-V
#   .\optimizer.ps1 -ListFixes            # show available fixes
#   .\optimizer.ps1 -RunFix ResetNetwork  # run one fix
#   .\optimizer.ps1 -ListPanels           # show legacy panels
#   .\optimizer.ps1 -OpenPanel ControlPanel
#   .\optimizer.ps1 -EnableSsh | -DisableSsh
#   .\optimizer.ps1 -CreateWin11Iso -SourceIso path
#
# Power-user profiles:
#   .\optimizer.ps1 -Profile Gamer        # max perf + gaming tweaks
#   .\optimizer.ps1 -Profile Privacy      # telemetry wipe + AdGuard DNS
#   .\optimizer.ps1 -Profile Developer    # WSL/Hyper-V/Sandbox + dev apps
#
# Profiles (JSON):
#   .\optimizer.ps1 -ExportConfig -WingetApps a,b -Tweaks x,y -Dns Google
#   .\optimizer.ps1 -ListConfigs          # list saved profiles
#   .\optimizer.ps1 -ImportConfig -Name myprofile
#
# Context menu + startup:
#   .\optimizer.ps1 -SetContextMenu Classic | Default
#   .\optimizer.ps1 -ListStartup
#   .\optimizer.ps1 -SetStartup -Item "HKCU|OneDrive" -Disable
#
# Pre-flight checks:
#   .\optimizer.ps1 -Preflight isod|dism|debloat|install
#
# Granular clean: -UserTemp -WindowsTemp -Prefetch -FlushDNS
#                 -Chrome -Edge -Firefox -INet
#
# Switches: -DryRun (preview only), -NoElevate (skip UAC relaunch)

[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$Network,
    [switch]$Debloat,
    [switch]$Tweaks,
    [switch]$UndoTweaks,
    [switch]$All,
    [switch]$DryRun,
    [switch]$NoElevate,
    [switch]$ListCategories,
    [switch]$ListTweaks,
    [switch]$TweakInfo,
    [switch]$ListApps,
    [switch]$TweakState,
    [switch]$QuickScan,
    [switch]$CreateRestorePoint,
    [switch]$Restore,
    [switch]$SysInfo,
    [switch]$UserTemp,
    [switch]$WindowsTemp,
    [switch]$Prefetch,
    [switch]$FlushDNS,
    [switch]$Chrome,
    [switch]$Edge,
    [switch]$Firefox,
    [switch]$INet,
    # --- WinUtil-style switches ---
    [switch]$WingetList,
    [switch]$WingetInstall,
    [switch]$WingetUpgrade,
    [switch]$WingetUpgradeAll,
    [switch]$WingetUninstall,
    [switch]$ListDNS,
    [string]$SetDNS = $null,
    [switch]$ListUpdateModes,
    [string]$SetUpdateMode = $null,
    [switch]$ListPower,
    [string]$SetPower = $null,
    [switch]$ListFeatures,
    [switch]$SetFeature,
    [switch]$EnableFeature,
    [switch]$DisableFeature,
    [switch]$ListFixes,
    [string]$RunFix = $null,
    [switch]$ListPanels,
    [string]$OpenPanel = $null,
    [switch]$EnableSsh,
    [switch]$DisableSsh,
    [switch]$CreateWin11Iso,
    [string]$SourceIso = $null,
    [string]$OutIso = $null,
    [string[]]$App = @(),
    [string[]]$Feature = @(),
    [string[]]$Category = @(),
    [string[]]$Package = @(),
    [string[]]$Tweak = @(),
    [string]$LogFile = 'optimizer.log',
    # --- Power-user profiles ---
    [ValidateSet('Gamer', 'Privacy', 'Developer')]
    [string]$Profile = $null,
    # --- JSON profiles ---
    [switch]$ExportConfig,
    [switch]$ListConfigs,
    [switch]$ImportConfig,
    [string]$ConfigPath = $null,
    [string]$ConfigName = $null,
    [string[]]$WingetApps = @(),
    [string]$Dns = $null,
    [string]$Power = $null,
    [string]$UpdateMode = $null,
    [string[]]$FeaturesEnable = @(),
    [switch]$Ssh,
    # --- Context menu + startup ---
    [ValidateSet('Classic', 'Default')]
    [string]$SetContextMenu = $null,
    [switch]$ListStartup,
    [string]$SetStartup = $null,
    [switch]$EnableStartup,
    [switch]$DisableStartup,
    # --- Pre-flight ---
    [ValidateSet('iso', 'dism', 'debloat', 'install')]
    [string]$Preflight = $null
)

# --- Load the core module ---------------------------------------------------
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# The GUI passes lists like "a,b,c" as one string (single native argument).
# Normalize every list parameter so both "a,b,c" and a,b,c bind the same way.
function Expand-List {
    param([string[]]$Items)
    $out = @()
    foreach ($i in $Items) {
        foreach ($part in ($i -split ',')) {
            $t = $part.Trim()
            if ($t) { $out += $t }
        }
    }
    return $out
}
$Category = @(Expand-List $Category)
$Package = @(Expand-List $Package)
$Tweak = @(Expand-List $Tweak)
$App = @(Expand-List $App)
$Feature = @(Expand-List $Feature)
$WingetApps = @(Expand-List $WingetApps)
$FeaturesEnable = @(Expand-List $FeaturesEnable)

$scriptRoot = $PSScriptRoot
if ($scriptRoot -like '\\?\*') { $scriptRoot = $scriptRoot.Substring(4) }
. (Join-Path $scriptRoot 'engine.ps1')
. (Join-Path $scriptRoot 'winutil.ps1')

$logPath = if ([System.IO.Path]::IsPathRooted($LogFile)) { $LogFile } else { Join-Path (Get-Location) $LogFile }
Set-OptimizerLogFile -Path $logPath

function Show-Usage {
    @"

PC Optimizer - CLI
  .\optimizer.ps1 -Clean | -Network | -Debloat | -Tweaks | -All
  -Category Bing,Xbox   filter bloatware categories
  -Package X            remove one specific package
  -Tweak telemetry,x    apply specific system tweaks
  -ListCategories       list available bloatware categories
  -ListTweaks           list available system tweaks
  -TweakState           show which tweaks are already applied
  -QuickScan            fast read-only health snapshot
  -SysInfo              print system specs
  -Restore              re-register provisioned apps (undo debloat)
  -CreateRestorePoint   create a System Restore point before debloat/tweaks
  -DryRun               preview only, change nothing
  -NoElevate            do not auto-request administrator rights
"@ | Write-Host
}

# --- Auto-elevation ---------------------------------------------------------
$isAdmin = Test-IsAdmin
if ($isAdmin) {
    Write-Log "[+] Running with administrator rights."
}
elseif ($DryRun -or $ListCategories -or $ListTweaks -or $TweakInfo -or $ListApps -or $SysInfo -or $TweakState -or $QuickScan -or $WingetList -or $ListDNS -or $ListUpdateModes -or $ListPower -or $ListFeatures -or $ListFixes -or $ListPanels -or $ListConfigs -or $ListStartup -or $Preflight -or $ExportConfig) {
    Write-Log "[dry-run] Read-only preview (non-admin)."
}
elseif ($NoElevate) {
    Write-Log "[!] Not running as administrator. Run elevated or drop -NoElevate."
    exit 1
}
else {
    Write-Log "[+] Requesting administrator privileges ..."

    $relaunch = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    foreach ($k in $PSBoundParameters.Keys) {
        $v = $PSBoundParameters[$k]
        if ($v -is [switch]) {
            if ($v) { $relaunch += "-$k" }
        }
        elseif ($v -is [array]) {
            if ($v.Count -gt 0) { $relaunch += "-$k"; $relaunch += ($v -join ',') }
        }
        else {
            $relaunch += "-$k"; $relaunch += [string]$v
        }
    }
    Start-Process -FilePath powershell.exe -Verb RunAs -ArgumentList $relaunch -Wait
    exit 0
}

# --- Dispatch actions -------------------------------------------------------
if ($ListCategories) {
    Write-Log "Available bloatware categories:"
    Get-BloatCategories
}

if ($ListTweaks) {
    Write-Log "Available system tweaks:"
    Get-TweakList
}

if ($TweakInfo) { Get-TweakRegistryInfo }

if ($TweakState) {
    Write-Log "Current tweak state:"
    Get-TweakState
}

if ($QuickScan) {
    Invoke-QuickScan -DryRun:$DryRun
}

if ($SysInfo) {
    $info = Get-SystemInfo
    Write-Log "CPU|$($info.CPU)"
    Write-Log "RAM|$($info.RAM)"
    Write-Log "OS|$($info.OS)"
    Write-Log "ARCH|$($info.Architecture)"
}

if ($ListApps) {
    Get-BloatableApps | ForEach-Object {
        $disp = if ($_.DisplayName) { $_.DisplayName } else { $_.Name }
        Write-Log "APP|$($_.Category)|$($_.Name)|$disp"
    }
    Write-Log "=== LIST COMPLETE ==="
}

if ($Restore) {
    Write-Log "Restoring provisioned Appx packages ..."
    Restore-Bloatware -DryRun:$DryRun
}

if ($Network) {
    Clear-NetworkCache -DryRun:$DryRun
}

if ($Clean) {
    Clear-TempFolders -DryRun:$DryRun
    Clear-NetworkCache -DryRun:$DryRun
}

# Granular cleanup (used by the GUI deep-clean tab)
if ($UserTemp -or $WindowsTemp -or $Prefetch) {
    Clear-TempFolders -UserTemp:$UserTemp -WindowsTemp:$WindowsTemp -Prefetch:$Prefetch -DryRun:$DryRun
}
if ($FlushDNS -or $Chrome -or $Edge -or $Firefox -or $INet) {
    Clear-NetworkCache -FlushDNS:$FlushDNS -Chrome:$Chrome -Edge:$Edge -Firefox:$Firefox -INet:$INet -DryRun:$DryRun
}

if ($Debloat) {
    if (Test-Preflight -Action 'debloat') {
        if ($CreateRestorePoint) { New-RestorePoint -DryRun:$DryRun }
        if ($Category.Count -gt 0 -or $Package.Count -gt 0) {
            Remove-Bloatware -Category $Category -Package $Package -DryRun:$DryRun
        }
        else {
            Remove-Bloatware -All -DryRun:$DryRun
        }
    }
}

if ($Tweaks) {
    if ($CreateRestorePoint) { New-RestorePoint -DryRun:$DryRun }
    if ($Tweak.Count -gt 0) {
        Apply-SystemTweaks -Tweak $Tweak -DryRun:$DryRun
    }
    else {
        Apply-SystemTweaks -All -DryRun:$DryRun
    }
}

if ($UndoTweaks) {
    if ($Tweak.Count -gt 0) {
        Undo-SystemTweaks -Tweak $Tweak -DryRun:$DryRun
    }
    else {
        Undo-SystemTweaks -All -DryRun:$DryRun
    }
}

# --- WinUtil-style feature dispatch ---
if ($WingetList) {
    Write-Log "Querying WinGet catalog ..."
    Write-WingetAppRows
}

if ($WingetInstall) {
    if (Test-Preflight -Action 'install') { Invoke-WingetAction -Action install -App $App -DryRun:$DryRun }
}
if ($WingetUpgrade) { Invoke-WingetAction -Action upgrade -App $App -DryRun:$DryRun }
if ($WingetUpgradeAll) { Invoke-WingetAction -Action upgrade-all -DryRun:$DryRun }
if ($WingetUninstall) { Invoke-WingetAction -Action uninstall -App $App -DryRun:$DryRun }

if ($ListDNS) { Get-DnsPresets }
if ($SetDNS) { Set-DnsPreset -Preset $SetDNS -DryRun:$DryRun }

if ($ListUpdateModes) { Get-UpdateModes }
if ($SetUpdateMode) { Set-UpdateMode -Mode $SetUpdateMode -DryRun:$DryRun }

if ($ListPower) { Get-PowerPlans }
if ($SetPower) { Set-PowerPlan -Plan $SetPower -DryRun:$DryRun }

if ($ListFeatures) { Get-WinFeatures }
if ($SetFeature) {
    if ($EnableFeature) { Set-WinFeatures -Feature $Feature -Enable -DryRun:$DryRun }
    elseif ($DisableFeature) { Set-WinFeatures -Feature $Feature -Disable -DryRun:$DryRun }
    else { Write-Log "[features] specify -EnableFeature or -DisableFeature." }
}

if ($ListFixes) { Get-Fixes }
if ($RunFix) {
    # DISM repairs are heavy: pre-flight first.
    $safe = $true
    if ($RunFix -eq 'SystemCorruption') { $safe = Test-Preflight -Action 'dism' }
    if ($safe) { Invoke-Fix -Fix $RunFix -DryRun:$DryRun }
}

if ($ListPanels) { Get-LegacyPanels }
if ($OpenPanel) { Invoke-LegacyPanel -Panel $OpenPanel }

if ($EnableSsh) { Set-SshServer -Enable -DryRun:$DryRun }
if ($DisableSsh) { Set-SshServer -Disable -DryRun:$DryRun }

if ($CreateWin11Iso) {
    if (Test-Preflight -Action 'iso') {
        New-Win11Iso -SourceIso $SourceIso -OutPath $OutIso -StripBloat -DisableTelemetry -RemoveOneDrive -DryRun:$DryRun
    }
}

# --- Power-user profiles ---
if ($Profile) { Invoke-Profile -Profile $Profile -DryRun:$DryRun }

# --- JSON profiles ---
if ($ExportConfig) {
    Export-OptimizerConfig -WingetApps $WingetApps -Tweaks $Tweak -Dns $Dns -Power $Power -UpdateMode $UpdateMode -FeaturesEnable $FeaturesEnable -Ssh:$Ssh -Path $ConfigPath -Name $ConfigName
}
if ($ListConfigs) { Get-OptimizerConfigs }
if ($ImportConfig) { Import-OptimizerConfig -Path $ConfigPath -Name $ConfigName -DryRun:$DryRun }

# --- Context menu + startup ---
if ($SetContextMenu) { Set-ContextMenuStyle -Style $SetContextMenu -DryRun:$DryRun }
if ($ListStartup) { Get-StartupItems }
if ($SetStartup) {
    if ($EnableStartup) { Set-StartupItem -Item $SetStartup -Enable -DryRun:$DryRun }
    elseif ($DisableStartup) { Set-StartupItem -Item $SetStartup -Disable -DryRun:$DryRun }
    else { Write-Log "[startup] specify -EnableStartup or -DisableStartup." }
}

# --- Pre-flight (explicit call for the UI to display status) ---
if ($Preflight) { Test-Preflight -Action $Preflight | Out-Null }

if ($All) {
    Clear-TempFolders -DryRun:$DryRun
    Clear-NetworkCache -DryRun:$DryRun
    Remove-Bloatware -All -DryRun:$DryRun
    Apply-SystemTweaks -All -DryRun:$DryRun
}

# --- Summary ----------------------------------------------------------------
$ranAnything = $ListCategories -or $ListTweaks -or $TweakInfo -or $ListApps -or $SysInfo -or $TweakState -or $QuickScan -or $Restore -or $Network -or $Clean -or $Debloat -or $Tweaks -or $UndoTweaks -or $All -or $UserTemp -or $WindowsTemp -or $Prefetch -or $FlushDNS -or $Chrome -or $Edge -or $Firefox -or $INet -or $WingetList -or $WingetInstall -or $WingetUpgrade -or $WingetUpgradeAll -or $WingetUninstall -or $ListDNS -or $SetDNS -or $ListUpdateModes -or $SetUpdateMode -or $ListPower -or $SetPower -or $ListFeatures -or $SetFeature -or $ListFixes -or $RunFix -or $ListPanels -or $OpenPanel -or $EnableSsh -or $DisableSsh -or $CreateWin11Iso -or $Profile -or $ExportConfig -or $ListConfigs -or $ImportConfig -or $SetContextMenu -or $ListStartup -or $SetStartup -or $Preflight
if (-not $ranAnything) {
    Show-Usage
}
else {
    if ($DryRun) {
        Write-Log "=== DRY-RUN COMPLETE: nothing was modified ==="
    }
    else {
        Write-Log "=== OPTIMIZER COMPLETE ==="
    }
}
