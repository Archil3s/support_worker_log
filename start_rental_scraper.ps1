$ErrorActionPreference = "Stop"

Set-Location "C:\Users\Danie\support_worker_log"

$ScraperRoot = "C:\Users\Danie\support_worker_log\tools\rental_scraper"
$ScraperScript = "$ScraperRoot\rental_scraper_server.js"
$NodeExe = "C:\Program Files\nodejs\node.exe"
$StdOutLog = "$ScraperRoot\scraper_stdout.log"
$StdErrLog = "$ScraperRoot\scraper_stderr.log"
$Port = 51247
$RequiredParserVersion = 6

function Test-ScraperReachable {
    try {
        $Result = Invoke-RestMethod `
            -Method Get `
            -Uri "http://127.0.0.1:$Port/ping" `
            -TimeoutSec 3

        return $Result.ok -eq $true
    }
    catch {
        return $false
    }
}

function Test-Scraper {
    try {
        $Result = Invoke-RestMethod `
            -Method Get `
            -Uri "http://127.0.0.1:$Port/ping" `
            -TimeoutSec 3

        $ParserVersion = 0
        if ($null -ne $Result.parserVersion) {
            $ParserVersion = [int]$Result.parserVersion
        }

        return ($Result.ok -eq $true) -and ($ParserVersion -ge $RequiredParserVersion)
    }
    catch {
        return $false
    }
}

function Test-JobScraper {
    try {
        $Body = @{ sources = @() } | ConvertTo-Json -Depth 5
        $Result = Invoke-RestMethod `
            -Method Post `
            -Uri "http://127.0.0.1:$Port/jobs" `
            -ContentType "application/json" `
            -Body $Body `
            -TimeoutSec 5

        return $Result.ok -eq $true
    }
    catch {
        return $false
    }
}

function Stop-ScraperOnPort {
    $Lines = netstat -ano | Select-String "127.0.0.1:$Port"
    foreach ($Line in $Lines) {
        $Text = $Line.ToString()
        if ($Text -notmatch "LISTENING") {
            continue
        }

        $Parts = $Text -split "\s+" | Where-Object { $_ }
        $ProcessId = [int]$Parts[-1]
        if ($ProcessId -gt 0) {
            Stop-Process -Id $ProcessId -Force
        }
    }
}

if (-not (Test-Path "$ScraperRoot\node_modules\playwright")) {
    Write-Host "Installing Playwright for the rental scraper..."
    & npm.cmd install --prefix "$ScraperRoot"

    if ($LASTEXITCODE -ne 0) {
        throw "npm install failed for the rental scraper."
    }
}

$ScraperReachable = Test-ScraperReachable
$ScraperCurrent = Test-Scraper
$JobScraperReady = Test-JobScraper

if ($ScraperReachable -and ((-not $ScraperCurrent) -or (-not $JobScraperReady))) {
    Write-Host "Restarting scraper to load current rental and job search parser..."
    Stop-ScraperOnPort
    Start-Sleep -Seconds 1
}

if (-not (Test-Scraper)) {
    Start-Process `
        -FilePath $NodeExe `
        -ArgumentList "`"$ScraperScript`"" `
        -WorkingDirectory $ScraperRoot `
        -RedirectStandardOutput $StdOutLog `
        -RedirectStandardError $StdErrLog `
        -WindowStyle Minimized

    Start-Sleep -Seconds 4
}

if (-not (Test-Scraper)) {
    if (Test-Path $StdErrLog) {
        Get-Content $StdErrLog | Write-Host
    }
    throw "Rental scraper failed to start."
}

if (-not (Test-JobScraper)) {
    if (Test-Path $StdErrLog) {
        Get-Content $StdErrLog | Write-Host
    }
    throw "Rental scraper started, but job scraping endpoint is not available."
}

Write-Host "Rental and job scraper is running on http://127.0.0.1:$Port"
