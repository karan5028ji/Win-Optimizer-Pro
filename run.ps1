#requires -Version 5.1
#
# Win-Optimizer-Pro - one-line launcher
#
#   irm https://raw.githubusercontent.com/karan5028ji/Win-Optimizer-Pro/main/run.ps1 | iex
#
# Downloads the latest release executable from GitHub and launches it.

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

function Get-ReleaseUrl {
    param([string]$apiUrl)
    $release = Invoke-RestMethod -Uri $apiUrl -Headers @{ 'User-Agent' = 'Win-Optimizer-Pro' }
    if (-not $release) { throw 'GitHub API returned an empty release response.' }

    $asset = $release.assets | Where-Object { $_.name -match 'setup\.exe$' } | Select-Object -First 1
    if (-not $asset) {
        $asset = $release.assets | Where-Object { $_.name -match '\.exe$' } | Select-Object -First 1
    }
    if (-not $asset) { throw 'Release found but no executable (.exe) asset is attached.' }

    return $asset.browser_download_url
}

function Main {
    Show-Banner

    Write-Status 'Initializing Next-Gen Optimizer... Fetching the latest release from GitHub.'

    $apiUrl = 'https://api.github.com/repos/karan5028ji/Win-Optimizer-Pro/releases/latest'
    try {
        $downloadUrl = Get-ReleaseUrl -apiUrl $apiUrl
    }
    catch {
        Write-Host ''
        Write-Host "[!] Could not fetch the latest release." -ForegroundColor Red
        Write-Host "    $($_.Exception.Message)" -ForegroundColor DarkYellow
        Write-Host '    Check your internet connection, or that a release exists on GitHub.' -ForegroundColor DarkGray
        return
    }

    Write-Status "Found release asset, downloading: $downloadUrl"

    $outFile = Join-Path $env:TEMP 'WinOptimizerPro.exe'
    Remove-Item $outFile -Force -ErrorAction SilentlyContinue

    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $outFile -UseBasicParsing
    }
    catch {
        Write-Host ''
        Write-Host "[!] Download failed: $($_.Exception.Message)" -ForegroundColor Red
        Remove-Item $outFile -Force -ErrorAction SilentlyContinue
        return
    }

    if (-not (Test-Path $outFile) -or (Get-Item $outFile).Length -lt 64KB) {
        Write-Host ''
        Write-Host '[!] Downloaded file looks invalid (missing or too small).' -ForegroundColor Red
        Remove-Item $outFile -Force -ErrorAction SilentlyContinue
        return
    }

    Write-Status "Saved to $outFile"
    Write-Status 'Launching Win-Optimizer-Pro...'
    Start-Process -FilePath $outFile
}

Main
