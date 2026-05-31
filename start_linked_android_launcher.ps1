$ErrorActionPreference = "Stop"

Set-Location "C:\Users\Danie\support_worker_log"

$WriterPath = "C:\Users\Danie\support_worker_log\mr_notes_node_writer.js"
$Port = 51239
$DeviceId = "emulator-5554"

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
Write-Host "Launching current git checkout on active emulator: $DeviceId"
Write-Host "Press r in this window for hot reload."
Write-Host "Press R for hot restart."
Write-Host "Press q to quit."
Write-Host ""

if (-not (Test-Path ".dart_tool\package_config.json")) {
    flutter pub get
}

flutter run --no-pub -d $DeviceId
