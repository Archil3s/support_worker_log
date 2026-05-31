$ErrorActionPreference = "Stop"

Set-Location "C:\Users\Danie\support_worker_log"

$AdbPath = "C:\Users\Danie\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$WriterPath = "C:\Users\Danie\support_worker_log\mr_notes_node_writer.js"
$Port = 51239
$DeviceId = "emulator-5554"
$PackageName = "com.archil3s.support_worker_log"

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

& $AdbPath -s $DeviceId shell monkey `
    -p $PackageName `
    -c android.intent.category.LAUNCHER 1

Write-Host ""
Write-Host "Opened installed app on $DeviceId without rebuilding."
Write-Host "Use the linked Android launcher only when code changes need to be rebuilt."
