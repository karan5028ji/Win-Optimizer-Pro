# engine.ps1 - Core module for the PC Optimizer
# Dot-source from optimizer.ps1 or the GUI wrapper.
# No param block on purpose: this file is a function library.

$script:OptimizerLogFilePath = $null

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
function Set-OptimizerLogFile {
    param([string]$Path)
    $script:OptimizerLogFilePath = $Path
}

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Write-Host $line
    if ($script:OptimizerLogFilePath) {
        Add-Content -LiteralPath $script:OptimizerLogFilePath -Value $line
    }
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ---------------------------------------------------------------------------
# Privilege helpers (for locked / access-denied items)
# ---------------------------------------------------------------------------
function Grant-Privileges {
    <#
        .SYNOPSIS
        Recursively take ownership and grant full control to Administrators.
        Runs takeown + icacls so locked files can be deleted afterwards.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [switch]$DryRun
    )
    if (-not (Test-Path -LiteralPath $Path)) { return }
    if ($DryRun) {
        Write-Log "[dry-run] would takeown /a /r /d Y : $Path"
        Write-Log "[dry-run] would icacls /grant Administrators:(OI)(CI)F : $Path"
        return
    }
    Write-Log "[acl] takeown ... $Path"
    & takeown.exe /f $Path /a /r /d Y 2>$null | Out-Null
    Write-Log "[acl] icacls  ... $Path"
    & icacls.exe $Path /grant "*S-1-5-32-544:(OI)(CI)F" /t /c /q 2>$null | Out-Null
}

# ---------------------------------------------------------------------------
# Hybrid cleanup loop (cmd "for /f" driven from PowerShell)
# ---------------------------------------------------------------------------
function Clear-FolderItems {
    <#
        .SYNOPSIS
        Deletes every item inside a folder using a native cmd for /f loop.
        Files are deleted with del, directories with rd /s /q, so locked /
        in-use files are skipped instead of aborting the whole run.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$Label = $Path,
        [switch]$DryRun
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Log "[skip] $Label (not found)"
        return
    }

    Grant-Privileges -Path $Path -DryRun:$DryRun

    $items = @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue)
    if ($items.Count -eq 0) {
        Write-Log "[clean] $Label : already empty"
        return
    }
    if ($DryRun) {
        Write-Log "[dry-run] $Label : $($items.Count) item(s) listed, nothing removed"
        return
    }

    Write-Log "[clean] $Label : removing $($items.Count) item(s) ..."
    $cmdline = 'for /f "delims= eol=" %F in (''dir /a /b "{0}" 2^>nul'') do (del /a /f /q "{0}\%F" 2>nul & rd /s /q "{0}\%F" 2>nul)' -f $Path
    & cmd.exe /d /s /c $cmdline

    $left = @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue).Count
    Write-Log "[done] $Label : $left item(s) remain (locked/in-use)"
}

# ---------------------------------------------------------------------------
# Temp folder cleanup: %temp%, C:\Windows\Temp, Prefetch
# ---------------------------------------------------------------------------
function Clear-TempFolders {
    param(
        [switch]$UserTemp,
        [switch]$WindowsTemp,
        [switch]$Prefetch,
        [switch]$DryRun
    )
    $targets = @()
    if ($UserTemp)    { $targets += @{ Label = '%temp%';         Path = $env:TEMP } }
    if ($WindowsTemp) { $targets += @{ Label = 'Windows Temp';   Path = "$env:SystemRoot\Temp" } }
    if ($Prefetch)    { $targets += @{ Label = 'Prefetch';       Path = "$env:SystemRoot\Prefetch" } }
    if ($targets.Count -eq 0) {
        $targets = @(
            @{ Label = '%temp%';         Path = $env:TEMP },
            @{ Label = 'Windows Temp';   Path = "$env:SystemRoot\Temp" },
            @{ Label = 'Prefetch';       Path = "$env:SystemRoot\Prefetch" }
        )
    }
    foreach ($t in $targets) {
        Clear-FolderItems -Path $t.Path -Label $t.Label -DryRun:$DryRun
    }
}

# ---------------------------------------------------------------------------
# Network & browser cache flush
# ---------------------------------------------------------------------------
function Clear-NetworkCache {
    param(
        [switch]$FlushDNS,
        [switch]$Chrome,
        [switch]$Edge,
        [switch]$Firefox,
        [switch]$INet,
        [switch]$DryRun
    )
    $any = $FlushDNS -or $Chrome -or $Edge -or $Firefox -or $INet

    if (-not $any -or $FlushDNS) {
        if ($DryRun) {
            Write-Log "[dry-run] would flush DNS resolver cache (ipconfig /flushdns)"
        }
        else {
            Write-Log "[net] flushing DNS resolver cache ..."
            & ipconfig.exe /flushdns
        }
    }

    if (-not $any -or $Chrome) {
        foreach ($p in @(
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache"
        )) {
            if (Test-Path -LiteralPath $p) { Clear-FolderItems -Path $p -Label $p -DryRun:$DryRun }
        }
    }

    if (-not $any -or $Edge) {
        foreach ($p in @(
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache"
        )) {
            if (Test-Path -LiteralPath $p) { Clear-FolderItems -Path $p -Label $p -DryRun:$DryRun }
        }
    }

    if (-not $any -or $INet) {
        $p = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"
        if (Test-Path -LiteralPath $p) { Clear-FolderItems -Path $p -Label $p -DryRun:$DryRun }
    }

    if (-not $any -or $Firefox) {
        $firefoxProfiles = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
        if (Test-Path -LiteralPath $firefoxProfiles) {
            Get-ChildItem -LiteralPath $firefoxProfiles -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                foreach ($sub in @('cache2', 'thumbnails', 'startupCache')) {
                    $p = Join-Path $_.FullName $sub
                    if (Test-Path -LiteralPath $p) {
                        Clear-FolderItems -Path $p -Label $p -DryRun:$DryRun
                    }
                }
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Bloatware categories
# ---------------------------------------------------------------------------
$Script:BloatCategories = [ordered]@{
    'Bing'      = @('Microsoft.Bing*')
    'Xbox'      = @(
        'Microsoft.XboxApp',
        'Microsoft.XboxGameOverlay',
        'Microsoft.XboxGamingOverlay',
        'Microsoft.XboxIdentityProvider',
        'Microsoft.XboxSpeechToTextOverlay'
    )
    'Media'     = @(
        'Microsoft.ZuneMusic',
        'Microsoft.ZuneVideo',
        'Microsoft.Movies',
        'Microsoft.WindowsMaps'
    )
    'News'      = @(
        'Microsoft.BingNews',
        'Microsoft.BingWeather',
        'Microsoft.BingSports',
        'Microsoft.BingFinance'
    )
    'Social'    = @(
        'Microsoft.SkypeApp',
        'Microsoft.People',
        'Microsoft.Facebook',
        'Microsoft.Twitter',
        'Microsoft.Instagram'
    )
    'Office'    = @(
        'Microsoft.OfficeHub',
        'Microsoft.MicrosoftOfficeHub',
        'Microsoft.Office.Sway',
        'Microsoft.Office.OneNote',
        'Microsoft.OneConnect'
    )
    'Games'     = @(
        'Microsoft.MicrosoftSolitaireCollection',
        'Microsoft.Minesweeper',
        'Microsoft.TreasureHunt',
        'Microsoft.Wallet'
    )
    'Phone'     = @('Microsoft.YourPhone')
    'Misc'      = @(
        'Microsoft.549981C3F5F10',
        'Microsoft.MixedReality.Portal',
        'Microsoft.WindowsFeedbackHub',
        'Microsoft.Getstarted',
        'Microsoft.WindowsAlarms'
    )
}

# Packages we should never touch, even if a pattern matches.
$Script:ProtectedPackages = @(
    'Microsoft.WindowsStore',
    'Microsoft.StorePurchaseApp',
    'Microsoft.DesktopAppInstaller',
    'Microsoft.WindowsTerminal',
    'Microsoft.WindowsCalculator',
    'Microsoft.Windows.Photos',
    'Microsoft.ScreenSketch',
    'Microsoft.WindowsNotepad',
    'Microsoft.WindowsCamera',
    'Microsoft.Paint',
    'Microsoft.Windows.DevHome',
    'Microsoft.WindowsSettings',
    'Microsoft.ShellExperienceHost',
    'Microsoft.Search',
    'MicrosoftWindows.CrossDevice'
)

function Get-BloatCategories {
    <#
        .SYNOPSIS
        Prints every available category with the packages it maps to.
    #>
    foreach ($key in $Script:BloatCategories.Keys) {
        $names = $Script:BloatCategories[$key] -join ', '
        Write-Log "  [$key] -> $names"
    }
}

# Single-pass helpers: enumerate Appx packages ONCE, filter in memory. The old
# code re-ran Get-AppxPackage / Get-AppxProvisionedPackage once per pattern,
# which made the list + remove paths 20-40x slower than they needed to be.

function Get-AppxSnapshot {
    <#
        .SYNOPSIS
        One Get-AppxPackage call (AllUsers when elevated), deduped, protected
        packages already excluded. Used by the list and remove paths.
    #>
    $admin = Test-IsAdmin
    if ($admin) {
        $pkgs = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue)
    }
    else {
        $pkgs = @(Get-AppxPackage -ErrorAction SilentlyContinue)
    }
    $seen = @{}
    foreach ($p in $pkgs) {
        if ($p.Name -in $Script:ProtectedPackages) { continue }
        if ($seen.ContainsKey($p.PackageFullName)) { continue }
        $seen[$p.PackageFullName] = $p
    }
    return $seen.Values
}

function Get-ProvisionedSnapshot {
    <#
        .SYNOPSIS
        One Get-AppxProvisionedPackage -Online call, protected packages excluded.
    #>
    @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -notin $Script:ProtectedPackages })
}

function Remove-Bloatware {
    <#
        .SYNOPSIS
        Removes pre-installed bloatware, category-wise.
        Use -Category 'Xbox' or -Package 'Microsoft.XboxApp'. Without filters,
        pass -All to strip every category. Run -DryRun first to preview.
    #>
    param(
        [switch]$All,
        [string[]]$Category = @(),
        [string[]]$Package = @(),
        [switch]$DryRun
    )

    $targets = @()
    if ($All) {
        foreach ($pat in @($Script:BloatCategories.Values)) {
            foreach ($p in @($pat)) { $targets += $p }
        }
    }
    foreach ($c in $Category) {
        if ($Script:BloatCategories.Contains($c)) {
            foreach ($p in @($Script:BloatCategories[$c])) { $targets += $p }
        }
        else {
            Write-Log "[warn] unknown category: $c (see Get-BloatCategories)"
        }
    }
    foreach ($p in $Package) { $targets += $p }
    $targets = @($targets | Sort-Object -Unique)

    if ($targets.Count -eq 0) {
        Write-Log "[debloat] nothing to do. Use -All, -Category or -Package."
        return
    }

    if ($DryRun -and -not (Test-IsAdmin)) {
        Write-Log "[dry-run] previewing current-user packages only (run elevated for a full preview)."
    }
    if (-not $DryRun -and -not (Test-IsAdmin)) {
        Write-Log "[!] Remove-Bloatware requires elevation. Re-run elevated."
        return
    }

    $admin = Test-IsAdmin
    $snap = @(Get-AppxSnapshot)
    $prov = @()
    if ($admin) { $prov = @(Get-ProvisionedSnapshot) }

    $matched = 0
    $handled = @{}
    foreach ($pattern in $targets) {
        if ($pattern -in $Script:ProtectedPackages) {
            Write-Log "[protect] skipping protected package pattern: $pattern"
            continue
        }
        foreach ($pkg in $snap) {
            if ($pkg.Name -like $pattern -and -not $handled.ContainsKey($pkg.PackageFullName)) {
                $handled[$pkg.PackageFullName] = $true
                $matched++
                if ($DryRun) {
                    Write-Log "[dry-run] would remove: $($pkg.Name)  v$($pkg.Version)"
                }
                else {
                    Write-Log "[remove] $($pkg.Name)  v$($pkg.Version)"
                    Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
                }
            }
        }
        if (-not $admin) { continue }
        foreach ($p in $prov) {
            if ($p.DisplayName -like $pattern -and -not $handled.ContainsKey($p.PackageName)) {
                $handled[$p.PackageName] = $true
                $matched++
                if ($DryRun) {
                    Write-Log "[dry-run] would remove provisioned: $($p.DisplayName)"
                }
                else {
                    Write-Log "[remove provisioned] $($p.DisplayName)"
                    Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction SilentlyContinue
                }
            }
        }
    }
    Write-Log "[debloat] $matched package(s) matched."
}

function Get-BloatableApps {
    <#
        .SYNOPSIS
        Returns installed Appx packages that match any bloatware category,
        tagged with their category. Single Appx enumeration, filtered in memory.
    #>
    $all = @(Get-AppxSnapshot)
    $rows = @()
    foreach ($cat in $Script:BloatCategories.Keys) {
        foreach ($pattern in $Script:BloatCategories[$cat]) {
            foreach ($pkg in $all) {
                if ($pkg.Name -like $pattern) {
                    $rows += [pscustomobject]@{
                        Category    = $cat
                        Name        = $pkg.Name
                        DisplayName = $pkg.DisplayName
                    }
                }
            }
        }
    }
    $rows | Sort-Object Category, Name
}

function Restore-Bloatware {
    <#
        .SYNOPSIS
        Re-registers all provisioned Appx packages (best-effort restore after
        a debloat). Only re-adds provisioned packages still on the image.
    #>
    param([switch]$DryRun)
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | ForEach-Object {
        if ($DryRun) {
            Write-Log "[dry-run] would restore provisioned: $($_.DisplayName)"
        }
        else {
            Write-Log "[restore] $($_.DisplayName)"
            Add-AppxProvisionedPackage -Online -PackageName $_.PackageName -SkipLicense -ErrorAction SilentlyContinue | Out-Null
        }
    }
    Write-Log "[restore] done. Some apps may also need a Store refresh."
}

# ---------------------------------------------------------------------------
# System tweaks (registry / services / power)
# ---------------------------------------------------------------------------
$Script:TweakOptions = [ordered]@{
    'telemetry'      = 'Disable telemetry (DiagTrack + dmwappushservice services)'
    'backgroundapps' = 'Deny apps from running in the background'
    'hibernation'    = 'Disable hibernation (removes hiberfil.sys)'
    'faststartup'    = 'Disable fast startup (hybrid boot)'
    'gamebar'        = 'Disable Xbox Game Bar / GameDVR overlay'
    'cortana'        = 'Disable Cortana'
    'tips'           = 'Disable Windows tips & suggestions'
    'searchweb'      = 'Disable Bing web results in Start search'
}

# Registry location + expected value that proves a tweak is currently applied.
# Key  Name  Expected
$Script:TweakStateChecks = @{
    'telemetry'      = @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection', 'AllowTelemetry', 0)
    'backgroundapps' = @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy', 'LetAppsRunInBackground', 2)
    'hibernation'    = @('HKLM:\SYSTEM\CurrentControlSet\Control\Power', 'HibernateEnabled', 0)
    'faststartup'    = @('HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power', 'HiberbootEnabled', 0)
    'gamebar'        = @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR', 'AllowGameDVR', 0)
    'cortana'        = @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search', 'AllowCortana', 0)
    'tips'           = @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent', 'DisableSoftLanding', 1)
    'searchweb'      = @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search', 'ConnectedSearchUseWeb', 0)
}

function Set-RegistryDword {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][int]$Value
    )
    if (-not (Test-Path $Key)) { New-Item -Path $Key -Force | Out-Null }
    Set-ItemProperty -Path $Key -Name $Name -Value $Value -Type DWord -Force
}

function Get-TweakList {
    foreach ($key in $Script:TweakOptions.Keys) {
        Write-Log "  [$key] -> $($Script:TweakOptions[$key])"
    }
}

function Get-TweakState {
    <#
        .SYNOPSIS
        Reports whether each tweak is already applied, as STATE|id|true|false
        lines. Read-only, works without elevation.
    #>
    foreach ($key in $Script:TweakOptions.Keys) {
        $applied = $false
        $check = $Script:TweakStateChecks[$key]
        if ($check -and (Test-Path -LiteralPath $check[0])) {
            $val = (Get-ItemProperty -LiteralPath $check[0] -Name $check[1] -ErrorAction SilentlyContinue).$($check[1])
            if ($null -ne $val -and [int]$val -eq [int]$check[2]) { $applied = $true }
        }
        Write-Log "STATE|$key|$applied"
    }
    Write-Log "=== STATE COMPLETE ==="
}

function Apply-SystemTweaks {
    <#
        .SYNOPSIS
        Applies registry/service tweaks. Use -All for everything or -Tweak a,b.
        Run -DryRun first to preview. Requires elevation to apply.
    #>
    param(
        [switch]$All,
        [string[]]$Tweak = @(),
        [switch]$DryRun
    )
    $targets = [System.Collections.Generic.List[string]]::new()
    if ($All) {
        $Script:TweakOptions.Keys | ForEach-Object { $targets.Add($_) }
    }
    foreach ($t in $Tweak) {
        if ($Script:TweakOptions.Contains($t)) {
            $targets.Add($t)
        }
        else {
            Write-Log "[warn] unknown tweak: $t (see Get-TweakList)"
        }
    }
    $targets = $targets | Sort-Object -Unique
    if ($targets.Count -eq 0) {
        Write-Log "[tweaks] nothing to do. Use -All or -Tweak."
        return
    }
    if (-not $DryRun -and -not (Test-IsAdmin)) {
        Write-Log "[!] Apply-SystemTweaks requires elevation. Re-run elevated."
        return
    }

    foreach ($t in $targets) {
        switch ($t) {
            'telemetry' {
                if ($DryRun) { Write-Log "[dry-run] telemetry: stop+disable DiagTrack/dmwappushservice, AllowTelemetry=0" }
                else {
                    Stop-Service DiagTrack -Force -ErrorAction SilentlyContinue
                    Set-Service DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue
                    Stop-Service dmwappushservice -Force -ErrorAction SilentlyContinue
                    Set-Service dmwappushservice -StartupType Disabled -ErrorAction SilentlyContinue
                    Set-RegistryDword -Key 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Value 0
                    Write-Log "[tweak] telemetry disabled"
                }
            }
            'backgroundapps' {
                if ($DryRun) { Write-Log "[dry-run] backgroundapps: LetAppsRunInBackground=2 (deny by default)" }
                else {
                    Set-RegistryDword -Key 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' -Name 'LetAppsRunInBackground' -Value 2
                    Write-Log "[tweak] background apps denied by default"
                }
            }
            'hibernation' {
                if ($DryRun) { Write-Log "[dry-run] hibernation: powercfg /h off" }
                else {
                    & powercfg.exe /h off | Out-Null
                    Write-Log "[tweak] hibernation disabled"
                }
            }
            'faststartup' {
                if ($DryRun) { Write-Log "[dry-run] faststartup: HiberbootEnabled=0" }
                else {
                    Set-RegistryDword -Key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -Value 0
                    Write-Log "[tweak] fast startup disabled"
                }
            }
            'gamebar' {
                if ($DryRun) { Write-Log "[dry-run] gamebar: AllowGameDVR=0" }
                else {
                    Set-RegistryDword -Key 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'AllowGameDVR' -Value 0
                    Write-Log "[tweak] game bar disabled"
                }
            }
            'cortana' {
                if ($DryRun) { Write-Log "[dry-run] cortana: AllowCortana=0" }
                else {
                    Set-RegistryDword -Key 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowCortana' -Value 0
                    Write-Log "[tweak] cortana disabled"
                }
            }
            'tips' {
                if ($DryRun) { Write-Log "[dry-run] tips: DisableSoftLanding + consumer features" }
                else {
                    Set-RegistryDword -Key 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableSoftLanding' -Value 1
                    Set-RegistryDword -Key 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableConsumerAccountFeatures' -Value 1
                    Set-RegistryDword -Key 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableWindowsConsumerFeatures' -Value 1
                    Write-Log "[tweak] tips & suggestions disabled"
                }
            }
            'searchweb' {
                if ($DryRun) { Write-Log "[dry-run] searchweb: ConnectedSearchUseWeb=0" }
                else {
                    Set-RegistryDword -Key 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'ConnectedSearchUseWeb' -Value 0
                    Write-Log "[tweak] Bing web results disabled in search"
                }
            }
        }
    }
    Write-Log "[tweaks] done."
}

# ---------------------------------------------------------------------------
# Restore point (safety net before destructive actions)
# ---------------------------------------------------------------------------
function New-RestorePoint {
    <#
        .SYNOPSIS
        Enables System Restore on the system drive and creates a checkpoint.
        Failure to create one is logged as a warning, never fatal.
    #>
    param([switch]$DryRun)
    if ($DryRun) {
        Write-Log "[restorepoint] (dry-run) would create a System Restore point"
        return
    }
    try {
        Write-Log "[restorepoint] enabling System Restore on $env:SystemDrive ..."
        Enable-ComputerRestore -Drive "$env:SystemDrive" -ErrorAction Stop
        Write-Log "[restorepoint] creating restore point (may take a moment) ..."
        Checkpoint-Computer -Description 'PC Optimizer' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Log "[restorepoint] restore point created."
    }
    catch {
        Write-Log "[restorepoint] warning: could not create restore point ($($_.Exception.Message))"
    }
}

# ---------------------------------------------------------------------------
# Fast health scan (dashboard "Quick Scan")
# ---------------------------------------------------------------------------
function Invoke-QuickScan {
    <#
        .SYNOPSIS
        Lightweight, read-only health snapshot. Uses single-pass enumerations so
        it finishes in a few seconds instead of running a full debloat preview.
    #>
    param([switch]$DryRun)
    Write-Log "[scan] collecting quick health snapshot ..."

    $userTemp = @(Get-ChildItem -LiteralPath $env:TEMP -Force -ErrorAction SilentlyContinue).Count
    $winTemp = @(Get-ChildItem -LiteralPath "$env:SystemRoot\Temp" -Force -ErrorAction SilentlyContinue).Count
    $dns = @(ipconfig /displaydns | Select-String 'Record Name').Count

    $bloat = @(Get-BloatableApps)
    $pending = 0
    foreach ($t in $Script:TweakOptions.Keys) {
        $applied = $false
        $check = $Script:TweakStateChecks[$t]
        if ($check -and (Test-Path -LiteralPath $check[0])) {
            $val = (Get-ItemProperty -LiteralPath $check[0] -Name $check[1] -ErrorAction SilentlyContinue).$($check[1])
            if ($null -ne $val -and [int]$val -eq [int]$check[2]) { $applied = $true }
        }
        if (-not $applied) { $pending++ }
    }

    Write-Log "SCAN|temp_items|$userTemp"
    Write-Log "SCAN|windows_temp_items|$winTemp"
    Write-Log "SCAN|dns_entries|$dns"
    Write-Log "SCAN|bloat_apps|$($bloat.Count)"
    Write-Log "SCAN|tweaks_pending|$pending"
    Write-Log "=== SCAN COMPLETE ==="
}

# ---------------------------------------------------------------------------
# System info (for the dashboard)
# ---------------------------------------------------------------------------
function Get-SystemInfo {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
    $ramGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    [pscustomobject]@{
        CPU          = $cpu
        RAM          = "$ramGB GB"
        OS           = "$($os.Caption) (Build $($os.BuildNumber))"
        Architecture = $env:PROCESSOR_ARCHITECTURE
    }
}
