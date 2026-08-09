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
#   .\optimizer.ps1 -ListTweaks           # show available tweaks
#   .\optimizer.ps1 -SysInfo              # print system specs (CPU/RAM/OS)
#   .\optimizer.ps1 -ListApps             # list installed bloatware (APP|cat|name|display)
#   .\optimizer.ps1 -ListCategories       # show available categories
#   .\optimizer.ps1 -All -DryRun          # preview everything, change nothing
#   .\optimizer.ps1 -All                  # full optimize
#   .\optimizer.ps1 -Restore              # re-register provisioned apps
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
    [switch]$All,
    [switch]$DryRun,
    [switch]$NoElevate,
    [switch]$ListCategories,
    [switch]$ListTweaks,
    [switch]$ListApps,
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
    [string[]]$Category = @(),
    [string[]]$Package = @(),
    [string[]]$Tweak = @(),
    [string]$LogFile = 'optimizer.log'
)

# --- Load the core module ---------------------------------------------------
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$scriptRoot = $PSScriptRoot
if ($scriptRoot -like '\\?\*') { $scriptRoot = $scriptRoot.Substring(4) }
. (Join-Path $scriptRoot 'engine.ps1')

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
  -SysInfo              print system specs
  -Restore              re-register provisioned apps (undo debloat)
  -DryRun               preview only, change nothing
  -NoElevate            do not auto-request administrator rights
"@ | Write-Host
}

# --- Auto-elevation ---------------------------------------------------------
$isAdmin = Test-IsAdmin
if ($isAdmin) {
    Write-Log "[+] Running with administrator rights."
}
elseif ($DryRun -or $ListCategories -or $ListTweaks -or $ListApps -or $SysInfo) {
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
    if ($Category.Count -gt 0 -or $Package.Count -gt 0) {
        Remove-Bloatware -Category $Category -Package $Package -DryRun:$DryRun
    }
    else {
        Remove-Bloatware -All -DryRun:$DryRun
    }
}

if ($Tweaks) {
    if ($Tweak.Count -gt 0) {
        Apply-SystemTweaks -Tweak $Tweak -DryRun:$DryRun
    }
    else {
        Apply-SystemTweaks -All -DryRun:$DryRun
    }
}

if ($All) {
    Clear-TempFolders -DryRun:$DryRun
    Clear-NetworkCache -DryRun:$DryRun
    Remove-Bloatware -All -DryRun:$DryRun
    Apply-SystemTweaks -All -DryRun:$DryRun
}

# --- Summary ----------------------------------------------------------------
$ranAnything = $ListCategories -or $ListTweaks -or $ListApps -or $SysInfo -or $Restore -or $Network -or $Clean -or $Debloat -or $Tweaks -or $All -or $UserTemp -or $WindowsTemp -or $Prefetch -or $FlushDNS -or $Chrome -or $Edge -or $Firefox -or $INet
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
