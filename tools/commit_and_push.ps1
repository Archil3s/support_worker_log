$ErrorActionPreference = "Continue"

$projectPath = "$env:USERPROFILE\support_worker_log"
Set-Location $projectPath

Write-Host "Project:"
Write-Host $projectPath
Write-Host ""

if (-not (Test-Path ".git")) {
  Write-Host "ERROR: This is not a Git repository."
  Read-Host "Press Enter to close"
  exit 1
}

Write-Host "Running checks..."
Write-Host ""

.\tools\check.ps1

if ($LASTEXITCODE -ne 0) {
  Write-Host ""
  Write-Host "Checks failed. Error report has been copied to clipboard."
  Write-Host "Paste it into ChatGPT."
  Read-Host "Press Enter to close"
  exit 1
}

Write-Host ""
Write-Host "Checks passed."
Write-Host ""

$status = git status --short

if ([string]::IsNullOrWhiteSpace($status)) {
  Write-Host "No changes to commit."
  Read-Host "Press Enter to close"
  exit 0
}

Write-Host "Changed files:"
git status --short
Write-Host ""

# Stage only useful project files. Excludes logs and build outputs by not adding all files.
git add .gitignore lib test pubspec.yaml pubspec.lock tools/check.ps1 tools/commit_and_push.ps1 tools/run_pixel6.ps1

$stagedFiles = git diff --cached --name-only

if ([string]::IsNullOrWhiteSpace($stagedFiles)) {
  Write-Host "No staged project changes to commit."
  Read-Host "Press Enter to close"
  exit 0
}

$areas = New-Object System.Collections.Generic.List[string]

foreach ($file in $stagedFiles) {
  if ($file -match "features/quick_entry") {
    if (-not $areas.Contains("quick entry")) { $areas.Add("quick entry") }
  } elseif ($file -match "features/entries") {
    if (-not $areas.Contains("entries")) { $areas.Add("entries") }
  } elseif ($file -match "features/pay_period") {
    if (-not $areas.Contains("pay period")) { $areas.Add("pay period") }
  } elseif ($file -match "features/tax") {
    if (-not $areas.Contains("tax")) { $areas.Add("tax") }
  } elseif ($file -match "features/charts") {
    if (-not $areas.Contains("charts")) { $areas.Add("charts") }
  } elseif ($file -match "features/settings") {
    if (-not $areas.Contains("settings")) { $areas.Add("settings") }
  } elseif ($file -match "core/services") {
    if (-not $areas.Contains("services")) { $areas.Add("services") }
  } elseif ($file -match "core/state") {
    if (-not $areas.Contains("app state")) { $areas.Add("app state") }
  } elseif ($file -match "core/models") {
    if (-not $areas.Contains("models")) { $areas.Add("models") }
  } elseif ($file -match "core/utils") {
    if (-not $areas.Contains("utils")) { $areas.Add("utils") }
  } elseif ($file -match "shared/widgets") {
    if (-not $areas.Contains("shared widgets")) { $areas.Add("shared widgets") }
  } elseif ($file -match "tools/") {
    if (-not $areas.Contains("developer tools")) { $areas.Add("developer tools") }
  } elseif ($file -match "pubspec") {
    if (-not $areas.Contains("dependencies")) { $areas.Add("dependencies") }
  }
}

if ($areas.Count -eq 0) {
  $commitTitle = "Update app"
} else {
  $commitTitle = "Update " + ($areas -join ", ")
}

$commitBody = @"
Auto-generated commit.

Changed files:
$($stagedFiles -join "`n")
"@

Write-Host "Auto commit title:"
Write-Host $commitTitle
Write-Host ""

git commit -m "$commitTitle" -m "$commitBody"

if ($LASTEXITCODE -ne 0) {
  Write-Host ""
  Write-Host "Commit failed."
  Read-Host "Press Enter to close"
  exit 1
}

git push

if ($LASTEXITCODE -ne 0) {
  Write-Host ""
  Write-Host "Push failed."
  Read-Host "Press Enter to close"
  exit 1
}

Write-Host ""
Write-Host "Committed and pushed successfully."
Write-Host ""
Read-Host "Press Enter to close"
