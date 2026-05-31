$ErrorActionPreference = "Stop"

Set-Location "C:\Users\Danie\support_worker_log"

$WriterPath = "C:\Users\Danie\support_worker_log\mr_notes_node_writer.js"
$Port = 51239
$WebPort = 51243
$ServerPath = "C:\Users\Danie\support_worker_log\desktop_static_server.js"
$BuildStamp = "C:\Users\Danie\support_worker_log\build\web\.desktop_build_stamp"
$ChromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$ChromeProfile = "C:\Users\Danie\support_worker_log\.desktop_chrome_profile"

function Test-Writer {
    try {
        $Result = Invoke-RestMethod `
            -Method Post `
            -Uri "http://127.0.0.1:$Port/ping" `
            -Body "{}" `
            -ContentType "application/json" `
            -TimeoutSec 3

        return $Result.ok -eq $true
    }
    catch {
        return $false
    }
}

function Test-WebServer {
    try {
        $Response = Invoke-WebRequest `
            -Uri "http://localhost:$WebPort/__health" `
            -UseBasicParsing `
            -TimeoutSec 2

        return $Response.StatusCode -eq 200
    }
    catch {
        return $false
    }
}

function Get-NewestSourceWrite {
    $Paths = @(
        "lib",
        "web",
        "assets",
        "pubspec.yaml",
        "pubspec.lock"
    )

    $Newest = Get-Date "2000-01-01"

    foreach ($Path in $Paths) {
        if (-not (Test-Path $Path)) {
            continue
        }

        $Items = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue

        if ((Get-Item $Path) -is [System.IO.FileInfo]) {
            $Items = @(Get-Item $Path)
        }

        foreach ($Item in $Items) {
            if ($Item.LastWriteTime -gt $Newest) {
                $Newest = $Item.LastWriteTime
            }
        }
    }

    return $Newest
}

if (-not (Test-Writer)) {
    Write-Host "Starting local notes writer..."

    Start-Process `
        -FilePath "node" `
        -ArgumentList "`"$WriterPath`"" `
        -WorkingDirectory "C:\Users\Danie\support_worker_log" `
        -WindowStyle Minimized

    Start-Sleep -Seconds 2
}

if (-not (Test-Writer)) {
    throw "Local notes writer failed to start."
}

Write-Host "Local notes writer is running."
Write-Host "Notes folder: C:\Users\Danie\MR NOTES FOLDER"
Write-Host ""

if (-not (Test-Path ".dart_tool\package_config.json")) {
    flutter pub get
}

$NeedsBuild = -not (Test-Path "build\web\index.html") -or -not (Test-Path $BuildStamp)

if (-not $NeedsBuild) {
    $NewestSource = Get-NewestSourceWrite
    $StampTime = (Get-Item $BuildStamp).LastWriteTime
    $NeedsBuild = $NewestSource -gt $StampTime
}

if ($NeedsBuild) {
    Write-Host "Building desktop app cache..."
    flutter build web --release --no-pub --pwa-strategy=none --no-wasm-dry-run
    New-Item -ItemType File -Force -Path $BuildStamp | Out-Null
}
else {
    Write-Host "Using cached desktop app build."
}

if (-not (Test-WebServer)) {
    Write-Host "Starting desktop app server..."

    Start-Process `
        -FilePath "node" `
        -ArgumentList "`"$ServerPath`"" `
        -WorkingDirectory "C:\Users\Danie\support_worker_log" `
        -WindowStyle Minimized

    for ($Index = 0; $Index -lt 40; $Index++) {
        if (Test-WebServer) {
            break
        }

        Start-Sleep -Milliseconds 250
    }
}

if (-not (Test-WebServer)) {
    throw "Desktop app server failed to start."
}

Write-Host "Opening desktop app..."

$AppUrl = "http://localhost:$WebPort/?v=$((Get-Date).Ticks)"

if (Test-Path $ChromePath) {
    Start-Process `
        -FilePath $ChromePath `
        -ArgumentList "--user-data-dir=$ChromeProfile", "--app=$AppUrl", "--new-window"
}
else {
    Start-Process $AppUrl
}
