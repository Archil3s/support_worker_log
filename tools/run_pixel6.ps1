$ErrorActionPreference = "Continue"

$projectPath = "$env:USERPROFILE\support_worker_log"
Set-Location $projectPath

$logPath = Join-Path $projectPath "logs\latest_android_run_log.txt"
Remove-Item $logPath -Force -ErrorAction SilentlyContinue

function Log {
  param([string]$Text)
  $Text | Tee-Object -FilePath $logPath -Append | Out-Null
  Write-Host $Text
}

function Copy-Failure {
  param([string]$Title)

  $message = @"
$Title

Project:
$projectPath

Log:
$(Get-Content $logPath -Raw)
"@

  $message | Set-Clipboard
}

function Get-AdbPath {
  $adbFromPath = Get-Command adb -ErrorAction SilentlyContinue

  if ($adbFromPath) {
    return $adbFromPath.Source
  }

  $sdkAdb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"

  if (Test-Path $sdkAdb) {
    return $sdkAdb
  }

  return $null
}

function Get-EmulatorDeviceId {
  param([string]$AdbPath)

  $adbOutput = & $AdbPath devices 2>&1

  foreach ($line in $adbOutput) {
    Log "$line"

    if ($line -match "^(emulator-\d+)\s+device$") {
      return $matches[1]
    }
  }

  return $null
}

function Is-BootComplete {
  param(
    [string]$AdbPath,
    [string]$DeviceId
  )

  $bootState = & $AdbPath -s $DeviceId shell getprop sys.boot_completed 2>$null

  if ("$bootState".Trim() -eq "1") {
    return $true
  }

  return $false
}

Log "Support Worker Log - Pixel 6 launcher"
Log "Time: $(Get-Date)"
Log "Project: $projectPath"
Log ""

$adbPath = Get-AdbPath

if (-not $adbPath) {
  Log "ERROR: adb.exe was not found."
  Copy-Failure "adb.exe was not found."
  Read-Host "Press Enter to close"
  exit 1
}

Log "ADB path: $adbPath"
Log ""

Log "Starting ADB server..."
& $adbPath start-server 2>&1 | ForEach-Object { Log "$_" }

Log ""
Log "Checking for existing emulator..."
$deviceId = Get-EmulatorDeviceId -AdbPath $adbPath

if (-not $deviceId) {
  Log ""
  Log "No emulator detected by ADB."
  Log "Launching Pixel_6 emulator..."
  Log ""

  Start-Process -FilePath "cmd.exe" -ArgumentList "/c flutter emulators --launch Pixel_6"
}

Log ""
Log "Waiting for emulator device..."
Log ""

$deviceId = $null

for ($i = 1; $i -le 80; $i++) {
  Start-Sleep -Seconds 3

  Log ""
  Log "ADB device attempt $i/80"
  $deviceId = Get-EmulatorDeviceId -AdbPath $adbPath

  if ($deviceId) {
    Log "ADB detected emulator: $deviceId"
    break
  }
}

if (-not $deviceId) {
  Log ""
  Log "ERROR: ADB did not detect a usable emulator."
  Log "Open Android Studio > Device Manager > Pixel 6 > Play, then try again."
  Copy-Failure "ADB did not detect the Pixel 6 emulator."
  Read-Host "Press Enter to close"
  exit 1
}

Log ""
Log "Waiting for Android boot to complete..."
Log ""

$bootComplete = $false

for ($i = 1; $i -le 80; $i++) {
  Start-Sleep -Seconds 3

  if (Is-BootComplete -AdbPath $adbPath -DeviceId $deviceId) {
    $bootComplete = $true
    Log "Android boot complete."
    break
  }

  Log "Boot attempt $i/80 - still booting..."
}

if (-not $bootComplete) {
  Log ""
  Log "ERROR: Emulator appeared, but Android did not finish booting."
  Copy-Failure "Pixel 6 emulator did not finish booting."
  Read-Host "Press Enter to close"
  exit 1
}

Log ""
Log "Waiting 15 more seconds for Flutter device discovery..."
Start-Sleep -Seconds 15

Log ""
Log "Flutter devices:"
flutter devices 2>&1 | ForEach-Object { Log "$_" }

Log ""
Log "Running Flutter app on $deviceId..."
Log ""

flutter run -d $deviceId --device-timeout 180 2>&1 | ForEach-Object { Log "$_" }

if ($LASTEXITCODE -ne 0) {
  Log ""
  Log "ERROR: Flutter run failed."
  Copy-Failure "Flutter Android run failed."
  Read-Host "Press Enter to close"
  exit 1
}

Log ""
Log "Flutter app launched successfully."
Read-Host "Press Enter to close"
