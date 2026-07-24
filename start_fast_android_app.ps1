$ErrorActionPreference = "Stop"

Set-Location "C:\Users\Danie\support_worker_log"

$AdbPath = "C:\Users\Danie\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$WriterPath = "C:\Users\Danie\support_worker_log\mr_notes_node_writer.js"
$Port = 51239
$WriterVersion = "2026-07-24-document-read-v1"
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

        return $Result.ok -eq $true -and $Result.version -eq $WriterVersion
    }
    catch {
        return $false
    }
}

function Stop-StaleWriter {
    $Connections = Get-NetTCPConnection `
        -LocalPort $Port `
        -State Listen `
        -ErrorAction SilentlyContinue

    $ProcessIds = $Connections |
        Select-Object -ExpandProperty OwningProcess -Unique

    foreach ($ProcessId in $ProcessIds) {
        if ($ProcessId -gt 0 -and $ProcessId -ne $PID) {
            Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
        }
    }
}

if (-not (Test-Writer)) {
    Stop-StaleWriter
    Start-Process `
        -FilePath "node" `
        -ArgumentList "`"$WriterPath`"" `
        -WorkingDirectory "C:\Users\Danie\support_worker_log" `
        -WindowStyle Hidden

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
