# engine.ps1 - Core module for Win-Optimizer-Pro
# Dot-source from optimizer.ps1 or the GUI wrapper.
# No param block on purpose: this file is a function library.

$script:OptimizerLogFilePath = $null

# ---------------------------------------------------------------------------
# Progress reporting (live percent for the UI status bar)
# ---------------------------------------------------------------------------
# A run is a sequence of phases. Each phase owns a share of 100% (its Weight),
# and reports finer progress as units complete within it. Every change is
# emitted as one machine-readable stdout line the frontend parses:
#     [PROGRESS]<0-100>|<current message>
$script:TotalPhaseWeight     = 0
$script:CompletedPhaseWeight = 0
$script:PhaseWeight          = 0
$script:PhaseUnitsTotal      = 0
$script:PhaseUnitsDone       = 0
$script:ProgressActive       = $false
$script:ProgressLastPct      = -1
$script:ProgressMessage      = ''

function Reset-Progress {
    $script:TotalPhaseWeight     = 0
    $script:CompletedPhaseWeight = 0
    $script:PhaseWeight          = 0
    $script:PhaseUnitsTotal      = 0
    $script:PhaseUnitsDone       = 0
    $script:ProgressActive       = $false
    $script:ProgressLastPct      = -1
    $script:ProgressMessage      = ''
}

function Set-ProgressTotal {
    param([int]$Weight)
    $script:TotalPhaseWeight = [Math]::Max(1, $Weight)
}

function Begin-ProgressPhase {
    param(
        [Parameter(Mandatory = $true)][int]$Weight,
        [Parameter(Mandatory = $true)][string]$Message
    )
    $script:PhaseWeight          = [Math]::Max(0, $Weight)
    $script:PhaseUnitsTotal      = 0
    $script:PhaseUnitsDone       = 0
    $script:ProgressMessage      = $Message
    $script:ProgressActive       = $true
    Write-ProgressLine -Force
}

function Complete-ProgressPhase {
    $script:CompletedPhaseWeight += $script:PhaseWeight
    $script:PhaseWeight          = 0
    $script:PhaseUnitsTotal      = 0
    $script:PhaseUnitsDone       = 0
    Write-ProgressLine -Force
}

function Add-PhaseUnits {
    param([int]$Units)
    if (-not $script:ProgressActive) { return }
    $script:PhaseUnitsTotal += $Units
}

function Step-Progress {
    param([int]$Units = 1, [string]$Message)
    if (-not $script:ProgressActive) { return }
    $script:PhaseUnitsDone += $Units
    if ($Message) { $script:ProgressMessage = $Message }
    Write-ProgressLine
}

function Write-ProgressLine {
    param([switch]$Force, [string]$Message)
    if (-not $script:ProgressActive -or $script:TotalPhaseWeight -le 0) { return }
    if ($Message) { $script:ProgressMessage = $Message }
    $done = $script:CompletedPhaseWeight
    if ($script:PhaseUnitsTotal -gt 0) {
        $frac = $script:PhaseUnitsDone / $script:PhaseUnitsTotal
        if ($frac -gt 1) { $frac = 1 }
        $done += $script:PhaseWeight * $frac
    }
    $pct = [int][math]::Floor($done / $script:TotalPhaseWeight * 100)
    if ($pct -gt 100) { $pct = 100 }
    if ($Force -or $pct -ne $script:ProgressLastPct) {
        $script:ProgressLastPct = $pct
        Write-Output ("[PROGRESS]{0}|{1}" -f $pct, $script:ProgressMessage)
    }
}

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
# Folder emptying (robocopy /mir for speed + live percent)
# ---------------------------------------------------------------------------
function Get-FolderEntryCount {
    <#
        .SYNOPSIS
        Fast top-level entry count via lazy Win32 enumeration. Much lighter
        than Get-ChildItem (no FileInfo objects) on huge temp folders.
        Returns -1 when the folder is mid-deletion and can't be enumerated.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    $n = 0
    try {
        foreach ($e in [System.IO.Directory]::EnumerateFileSystemEntries($Path)) { $n++ }
    }
    catch {
        return -1
    }
    return $n
}

function Clear-FolderItems {
    <#
        .SYNOPSIS
        Empties a folder with a native robocopy /mir sweep. robocopy runs as a
        background process while the remaining count is polled so the status
        bar percent climbs live instead of freezing. Locked/in-use files are
        skipped (robocopy /r:0 /w:0) instead of aborting the whole run, and
        privileges are taken only if anything actually survives the first pass.
        -Count pre-registers the folder's unit share to avoid re-enumeration.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$Label = $Path,
        [switch]$DryRun,
        [int]$Count = -1
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Log "[skip] $Label (not found)"
        return
    }

    $enumerable = $true
    if ($Count -lt 0) {
        $Count = Get-FolderEntryCount -Path $Path
        if ($Count -lt 0) {
            # Enumeration failed (access denied / mid-deletion). Don't report it
            # as "already empty" - run the sweep anyway so whatever is reachable
            # still gets removed. Progress units are unknown (0) in this case.
            $enumerable = $false
            $Count = 0
            Write-Log "[clean] $Label : cannot enumerate (locked/access denied), running sweep anyway ..."
        }
        elseif ($Count -gt 0) {
            Add-PhaseUnits -Units $Count
        }
    }
    if ($Count -eq 0) {
        if ($enumerable) {
            Write-Log "[clean] $Label : already empty"
            return
        }
    }
    if ($DryRun) {
        if ($script:ProgressActive) {
            Step-Progress -Units $Count -Message "Cleaning $Label"
        }
        Write-Log "[dry-run] $Label : $Count item(s) listed, nothing removed"
        return
    }

    Write-Log "[clean] $Label : removing $Count item(s) ..."
    $deleted = 0
    Invoke-FastDelete -Path $Path -Label $Label
    $pass = $script:FastDeleteResult
    $deleted += $pass.Deleted
    $left = $pass.Remaining

    # Only when the plain pass leaves survivors do we take ownership (once) and
    # retry. A full takeown /r + icacls /t sweep on every clean was the single
    # biggest slowdown - it walked the whole temp tree every run.
    if ($left -gt 0) {
        Write-Log "[acl] $left item(s) locked - taking ownership once ..."
        Grant-Privileges -Path $Path -DryRun:$DryRun
        Invoke-FastDelete -Path $Path -Label $Label
        $retry = $script:FastDeleteResult
        $deleted += $retry.Deleted
        $left = $retry.Remaining
    }
    # Top off so the phase percent reflects this folder's full share even if a
    # few entries stay locked forever.
    if ($deleted -lt $Count) {
        Step-Progress -Units ($Count - $deleted)
    }
    Write-Log "[done] $Label : $left item(s) remain (locked/in-use)"
}

function Invoke-FastDelete {
    <#
        .SYNOPSIS
        Empties a folder with robocopy /mir against an empty scratch source.
        Returns { Deleted, Remaining }.

        Live progress comes from robocopy's own stdout: each file it deletes is
        printed on its own line, and a background runspace streams those lines
        in 64 KB chunks, counting newlines into a shared counter. Counting
        output lines instead of re-enumerating the directory avoids the NTFS
        contention that polling the folder caused (robocopy ran ~3x slower).
        The stream must be drained regardless, or the pipe buffer fills and
        robocopy stalls (5x+ slower in practice).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$Label = $Path
    )
    $empty = Join-Path $env:LOCALAPPDATA 'Win-Optimizer-Pro\empty-src'
    Remove-Item -LiteralPath $empty -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $empty -Force | Out-Null

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'robocopy.exe'
    $psi.Arguments = '"{0}" "{1}" /mir /r:0 /w:0 /njh /njs /nc /ns /np' -f $empty, $Path
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $p = [System.Diagnostics.Process]::Start($psi)

    $counter = @{ lines = 0 }
    $rs = [System.Management.Automation.PowerShell]::Create()
    $rs2 = $null
    $async = $null
    $async2 = $null
    try {
        # Stream robocopy's stdout in chunks, tallying newlines. Runs in its own
        # runspace so the main thread stays free to poll and step progress.
        [void]$rs.AddScript({
            param($s, $c)
            try {
                $buf = New-Object byte[] 65536
                while (($n = $s.Read($buf, 0, 65536)) -gt 0) {
                    $chunk = [System.Text.Encoding]::UTF8.GetString($buf, 0, $n)
                    $c['lines'] += ([regex]::Matches($chunk, "`n")).Count
                }
            }
            catch { }
        }).AddArgument($p.StandardOutput.BaseStream).AddArgument($counter)
        $async = $rs.BeginInvoke()

        # stderr is near-empty but must be drained too.
        $rs2 = [System.Management.Automation.PowerShell]::Create()
        [void]$rs2.AddScript({
            param($s)
            try {
                $buf = New-Object byte[] 65536
                while (($n = $s.Read($buf, 0, 65536)) -gt 0) { }
            }
            catch { }
        }).AddArgument($p.StandardError.BaseStream)
        $async2 = $rs2.BeginInvoke()

        $done = 0
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while (-not $p.HasExited) {
            Start-Sleep -Milliseconds 300
            $p.Refresh()
            if ($p.HasExited) { break }
            if ($sw.Elapsed.TotalMinutes -gt 10) { $p.Kill(); break }
            $proc = $counter['lines']
            if ($proc -gt $done) {
                $step = [Math]::Min($proc - $done, $script:PhaseUnitsTotal - $script:PhaseUnitsDone)
                if ($step -gt 0) {
                    Step-Progress -Units $step -Message "Cleaning $Label"
                    $done += $step
                }
            }
        }
        $p.WaitForExit()
        $sw.Stop()

        $proc = $counter['lines']
        if ($proc -gt $done) {
            $step = [Math]::Min($proc - $done, $script:PhaseUnitsTotal - $script:PhaseUnitsDone)
            if ($step -gt 0) {
                Step-Progress -Units $step -Message "Cleaning $Label"
                $done += $step
            }
        }
        $rs.EndInvoke($async)
        $rs2.EndInvoke($async2)
        $rs.Dispose()
        $rs2.Dispose()
        $rs = $null
        $rs2 = $null
    }
    finally {
        if ($rs -and $async)  { $rs.EndInvoke($async) }
        if ($rs2 -and $async2) { $rs2.EndInvoke($async2) }
        if ($rs)  { $rs.Dispose() }
        if ($rs2) { $rs2.Dispose() }
    }

    $remaining = Get-FolderEntryCount -Path $Path
    if ($remaining -lt 0) { $remaining = 0 }
    # Result is stashed on the script scope instead of returned through the
    # pipeline: the [PROGRESS] lines written by Step-Progress bubble up as
    # pipeline output too, and `$pass = Invoke-FastDelete ...` would swallow
    # them all into the assignment.
    $script:FastDeleteResult = [pscustomobject]@{
        Deleted   = $done
        Remaining = [Math]::Max(0, $remaining)
    }
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
    # Count every folder up-front (fast lazy enumeration) so the running
    # percent climbs monotonically across folders. The status message updates
    # while scanning so the UI never looks frozen on huge temp trees.
    $units = 0
    foreach ($t in $targets) {
        # -1 (enumeration denied) is clamped for the unit total so a locked
        # folder never shows a negative count in the log; the -1 is still passed
        # to Clear-FolderItems so it knows to run the sweep anyway.
        $t.Count = Get-FolderEntryCount -Path $t.Path
        $units += [Math]::Max(0, $t.Count)
        if ($script:ProgressActive) {
            Write-ProgressLine -Force -Message "Scanning $($t.Label) ..."
        }
    }
    Add-PhaseUnits -Units $units
    foreach ($t in $targets) {
        Clear-FolderItems -Path $t.Path -Label $t.Label -DryRun:$DryRun -Count $t.Count
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

    # Collect every cache folder that will be cleaned (DNS flush counts as one).
    $folders = [System.Collections.Generic.List[string]]::new()
    if (-not $any -or $Chrome) {
        foreach ($p in @(
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache"
        )) {
            if (Test-Path -LiteralPath $p) { $folders.Add($p) }
        }
    }
    if (-not $any -or $Edge) {
        foreach ($p in @(
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache"
        )) {
            if (Test-Path -LiteralPath $p) { $folders.Add($p) }
        }
    }
    if (-not $any -or $INet) {
        $p = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"
        if (Test-Path -LiteralPath $p) { $folders.Add($p) }
    }
    if (-not $any -or $Firefox) {
        $firefoxProfiles = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
        if (Test-Path -LiteralPath $firefoxProfiles) {
            Get-ChildItem -LiteralPath $firefoxProfiles -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                foreach ($sub in @('cache2', 'thumbnails', 'startupCache')) {
                    $p = Join-Path $_.FullName $sub
                    if (Test-Path -LiteralPath $p) { $folders.Add($p) }
                }
            }
        }
    }

    # Register all units up-front so the percent climbs monotonically.
    $units = 0
    if (-not $any -or $FlushDNS) { $units += 1 }
    $folderCounts = @{}
    foreach ($f in $folders) {
        $c = Get-FolderEntryCount -Path $f
        $folderCounts[$f] = $c
        $units += [Math]::Max(0, $c)
    }
    Add-PhaseUnits -Units $units

    if (-not $any -or $FlushDNS) {
        if ($DryRun) {
            Write-Log "[dry-run] would flush DNS resolver cache (ipconfig /flushdns)"
        }
        else {
            Write-Log "[net] flushing DNS resolver cache ..."
            & ipconfig.exe /flushdns
        }
        Step-Progress -Units 1 -Message "Flushing DNS cache"
    }

    foreach ($f in $folders) {
        Clear-FolderItems -Path $f -Label $f -DryRun:$DryRun -Count $folderCounts[$f]
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

    # Match everything first (fast, in-memory) so the removal pass can report a
    # truthful percent based on a stable unit total.
    $handled = @{}
    $toRemove     = [System.Collections.Generic.List[object]]::new()
    $toRemoveProv = [System.Collections.Generic.List[object]]::new()
    foreach ($pattern in $targets) {
        if ($pattern -in $Script:ProtectedPackages) {
            Write-Log "[protect] skipping protected package pattern: $pattern"
            continue
        }
        foreach ($pkg in $snap) {
            if ($pkg.Name -like $pattern -and -not $handled.ContainsKey($pkg.PackageFullName)) {
                $handled[$pkg.PackageFullName] = $true
                $toRemove.Add($pkg)
            }
        }
        if (-not $admin) { continue }
        foreach ($p in $prov) {
            if ($p.DisplayName -like $pattern -and -not $handled.ContainsKey($p.PackageName)) {
                $handled[$p.PackageName] = $true
                $toRemoveProv.Add($p)
            }
        }
    }
    $matched = $toRemove.Count + $toRemoveProv.Count
    if ($matched -eq 0) {
        Write-Log "[debloat] no matching packages found."
        return
    }
    Add-PhaseUnits -Units $matched

    foreach ($pkg in $toRemove) {
        if ($DryRun) {
            Write-Log "[dry-run] would remove: $($pkg.Name)  v$($pkg.Version)"
        }
        else {
            Write-Log "[remove] $($pkg.Name)  v$($pkg.Version)"
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
        }
        Step-Progress -Units 1 -Message "Removing bloatware ($($pkg.Name))"
    }
    foreach ($p in $toRemoveProv) {
        if ($DryRun) {
            Write-Log "[dry-run] would remove provisioned: $($p.DisplayName)"
        }
        else {
            Write-Log "[remove provisioned] $($p.DisplayName)"
            Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction SilentlyContinue
        }
        Step-Progress -Units 1 -Message "Removing bloatware ($($p.DisplayName))"
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
    Add-PhaseUnits -Units $targets.Count

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
        Step-Progress -Units 1 -Message "Applying tweak: $t"
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
        Checkpoint-Computer -Description 'Win-Optimizer-Pro' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Log "[restorepoint] restore point created."
    }
    catch {
        Write-Log "[restorepoint] warning: could not create restore point ($($_.Exception.Message))"
    }
    Step-Progress -Units 1 -Message "Creating restore point"
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
