param(
  [ValidateSet("none", "web", "apk")]
  [string]$Build = "none"
)

$ErrorActionPreference = "Continue"

$logPath = Join-Path (Get-Location) "logs\latest_check_output.txt"
$errorPath = Join-Path (Get-Location) "logs\latest_errors_for_chatgpt.txt"

New-Item -ItemType Directory -Force ".\logs" | Out-Null
Remove-Item $logPath -Force -ErrorAction SilentlyContinue
Remove-Item $errorPath -Force -ErrorAction SilentlyContinue

function Add-Line {
  param([string]$Text)

  $Text | Add-Content -Encoding UTF8 $logPath
  Write-Host $Text
}

function Run-Command {
  param(
    [string]$Title,
    [string]$Command
  )

  Add-Line ""
  Add-Line "=============================="
  Add-Line $Title
  Add-Line "Command: $Command"
  Add-Line "=============================="

  $output = cmd.exe /c "$Command" 2>&1
  $exitCode = $LASTEXITCODE

  if ($output) {
    $output | ForEach-Object {
      Add-Line "$_"
    }
  }

  Add-Line "Exit code: $exitCode"

  if ($exitCode -ne 0) {
    return $false
  }

  return $true
}

Add-Line "Flutter local check report"
Add-Line "Time: $(Get-Date)"
Add-Line "Folder: $(Get-Location)"

$passed = $true

if (-not (Run-Command "flutter pub get" "flutter pub get")) {
  $passed = $false
}

if (-not (Run-Command "dart format lib test" "dart format lib test")) {
  $passed = $false
}

if (-not (Run-Command "flutter analyze" "flutter analyze")) {
  $passed = $false
}

if (-not (Run-Command "flutter test" "flutter test")) {
  $passed = $false
}

if ($Build -eq "web") {
  if (-not (Run-Command "flutter build web" "flutter build web")) {
    $passed = $false
  }
}

if ($Build -eq "apk") {
  if (-not (Run-Command "flutter build apk --debug" "flutter build apk --debug")) {
    $passed = $false
  }
}

$gitStatus = cmd.exe /c "git status --short" 2>&1
$failed = -not $passed

$report = @"
Flutter local check report

Project:
$(Get-Location)

Build target:
$Build

Failed:
$failed

Git status:
$gitStatus

Full output:
$(Get-Content $logPath -Raw)
"@

$report | Set-Content -Encoding UTF8 $errorPath
$report | Set-Clipboard

Write-Host ""
Write-Host "Report copied to clipboard."
Write-Host "Report saved to:"
Write-Host $errorPath

if ($failed) {
  Write-Host ""
  Write-Host "One or more checks failed. Paste the clipboard into ChatGPT."
  exit 1
}

Write-Host ""
Write-Host "Checks passed."
exit 0
