#requires -Version 5.1
#
# Win-Optimizer-Pro - one-line launcher
#
#   irm https://raw.githubusercontent.com/karan5028ji/Win-Optimizer-Pro/main/run.ps1 | iex
#
# Downloads the latest release from GitHub.
#   - Portable build (zip): extracted to %TEMP% and launched directly (no install).
#   - Falls back to the setup.exe installer if no portable build exists.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

# --- Banner ------------------------------------------------------------------

function Get-LetterBlock {
    param([string]$letter)
    $map = @{
        'W' = @('#   #', '#   #', '# # #', '# # #', '# # #', '# # #', ' # # ')
        'I' = @('#####', '  #  ', '  #  ', '  #  ', '  #  ', '  #  ', '#####')
        'N' = @('#   #', '##  #', '##  #', '# # #', '# # #', '#  ##', '#  ##')
        'O' = @(' ### ', '#   #', '#   #', '#   #', '#   #', '#   #', ' ### ')
        'P' = @('#### ', '#   #', '#   #', '#### ', '#    ', '#    ', '#    ')
        'T' = @('#####', '  #  ', '  #  ', '  #  ', '  #  ', '  #  ', '  #  ')
        'M' = @('#   #', '## ##', '# # #', '# # #', '#   #', '#   #', '#   #')
        'Z' = @('#####', '   # ', '  #  ', ' #   ', '#    ', '#    ', '#####')
        'E' = @('#####', '#    ', '#    ', '#### ', '#    ', '#    ', '#####')
        'R' = @('#### ', '#   #', '#   #', '#### ', '# #  ', '#  # ', '#   #')
        '-' = @('     ', '     ', '     ', '#####', '     ', '     ', '     ')
    }
    if ($map.ContainsKey($letter)) { return $map[$letter] }
    return @('     ', '     ', '     ', '     ', '     ', '     ', '     ')
}

function Show-Banner {
    Clear-Host
    $title = 'WIN-OPTIMIZER-PRO'
    $block = [char]0x2588
    $rowColors = @('DarkMagenta', 'Magenta', 'Magenta', 'DarkMagenta', 'Magenta', 'Magenta', 'DarkMagenta')
    for ($r = 0; $r -lt 7; $r++) {
        $line = ''
        foreach ($ch in $title.ToCharArray()) {
            $blockRows = Get-LetterBlock ([string]$ch)
            $line += $blockRows[$r] + ' '
        }
        Write-Host $line.TrimEnd().Replace('#', $block) -ForegroundColor $rowColors[$r]
    }
    Write-Host ''
}

function Write-Status {
    param([string]$msg, [string]$color = 'Magenta')
    Write-Host ('[*] ' + $msg) -ForegroundColor $color
}

# --- Release handling ---------------------------------------------------------

function Get-Release {
    param([string]$apiUrl)
    $release = Invoke-RestMethod -Uri $apiUrl -Headers @{ 'User-Agent' = 'Win-Optimizer-Pro' }
    if (-not $release) { throw 'GitHub API returned an empty release response.' }
    return $release
}

function Invoke-LaunchPortable {
    param($asset)
    $zip = Join-Path $env:TEMP 'WinOptimizerPro-portable.zip'
    $runDir = Join-Path $env:TEMP 'WinOptimizerPro'

    Write-Status 'Portable build found - no installation required.'
    Write-Status "Downloading: $($asset.name)"
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing

    if (-not (Test-Path $zip) -or (Get-Item $zip).Length -lt 64KB) {
        throw 'Portable download looks invalid (missing or too small).'
    }

    Remove-Item $runDir -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -Path $zip -DestinationPath $runDir

    $exe = Join-Path $runDir 'pc-optimizer.exe'
    if (-not (Test-Path $exe)) {
        throw 'Portable archive did not contain pc-optimizer.exe.'
    }

    Write-Status "Extracted to $runDir"
    Write-Status 'Launching Win-Optimizer-Pro...'
    Start-Process -FilePath $exe -WorkingDirectory $runDir
}

function Invoke-LaunchInstaller {
    param($assets)
    $asset = $assets | Where-Object { $_.name -match 'setup\.exe$' } | Select-Object -First 1
    if (-not $asset) {
        $asset = $assets | Where-Object { $_.name -match '\.exe$' } | Select-Object -First 1
    }
    if (-not $asset) { throw 'Release found but no executable (.exe) asset is attached.' }

    Write-Status "Downloading: $($asset.name)"
    $outFile = Join-Path $env:TEMP 'WinOptimizerPro.exe'
    Remove-Item $outFile -Force -ErrorAction SilentlyContinue
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $outFile -UseBasicParsing

    if (-not (Test-Path $outFile) -or (Get-Item $outFile).Length -lt 64KB) {
        throw 'Downloaded file looks invalid (missing or too small).'
    }

    Write-Status "Saved to $outFile"
    Write-Status 'Launching installer...'
    Start-Process -FilePath $outFile
}

function Main {
    Show-Banner

    Write-Status 'Initializing Next-Gen Optimizer... Fetching the latest release from GitHub.'

    $apiUrl = 'https://api.github.com/repos/karan5028ji/Win-Optimizer-Pro/releases/latest'
    try {
        $release = Get-Release -apiUrl $apiUrl

        $portable = $release.assets | Where-Object { $_.name -match 'portable.*\.zip$' } | Select-Object -First 1
        if ($portable) {
            Invoke-LaunchPortable -asset $portable
        }
        else {
            Invoke-LaunchInstaller -assets $release.assets
        }
    }
    catch {
        Write-Host ''
        Write-Host "[!] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host '    Check your internet connection, or that a release exists on GitHub.' -ForegroundColor DarkGray
        return
    }
}

Main
