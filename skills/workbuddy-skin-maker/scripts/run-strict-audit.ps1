[CmdletBinding()]
param(
  [string]$ProjectRoot,
  [string]$ArtifactDirectory,
  [string]$ManualReviewManifest,
  [ValidateSet('All', 'Verify', 'Hover', 'Composer', 'Scenes', 'Pages', 'Details', 'Settings')]
  [string[]]$LiveGates = @('All'),
  [switch]$StaticOnly
)

$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

if (-not $ProjectRoot) {
  $ProjectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
}
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$scriptsRoot = Join-Path $ProjectRoot 'scripts'
$assetsRoot = Join-Path $ProjectRoot 'assets'

foreach ($requiredPath in @(
  (Join-Path $ProjectRoot 'VERSION'),
  (Join-Path $assetsRoot 'theme.json'),
  (Join-Path $assetsRoot 'renderer-inject.js'),
  (Join-Path $scriptsRoot 'injector.mjs'),
  (Join-Path $scriptsRoot 'restore-workbuddy-skin.ps1')
)) {
  if (-not (Test-Path -LiteralPath $requiredPath)) { throw "Required project file is missing: $requiredPath" }
}

if (-not $ArtifactDirectory) {
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $ArtifactDirectory = Join-Path $ProjectRoot "artifacts\strict-audit-$stamp"
}
$ArtifactDirectory = [IO.Path]::GetFullPath($ArtifactDirectory)
New-Item -ItemType Directory -Force -Path $ArtifactDirectory | Out-Null

$results = New-Object System.Collections.Generic.List[object]

function Add-GateResult {
  param([string]$Name, [bool]$Pass, [string]$Detail, [string]$LogPath = '', [long]$DurationMs = 0)
  $script:results.Add([pscustomobject]@{
    name = $Name
    pass = $Pass
    detail = $Detail
    logPath = $LogPath
    durationMs = $DurationMs
  })
}

function Invoke-ExternalGate {
  param([string]$Name, [string]$Executable, [string[]]$Arguments)
  $safeName = $Name -replace '[^a-zA-Z0-9]+', '_'
  $logPath = Join-Path $script:ArtifactDirectory "$safeName.log"
  $timer = [Diagnostics.Stopwatch]::StartNew()
  $previousPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $output = & $Executable @Arguments 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
  } catch {
    $output = $_ | Out-String
    $exitCode = if ($LASTEXITCODE) { $LASTEXITCODE } else { 1 }
  } finally {
    $ErrorActionPreference = $previousPreference
    $timer.Stop()
  }
  [IO.File]::WriteAllText($logPath, $output, $script:utf8NoBom)
  Add-GateResult -Name $Name -Pass ($exitCode -eq 0) -Detail "exitCode=$exitCode" -LogPath $logPath -DurationMs $timer.ElapsedMilliseconds
}

function Test-LiveGate {
  param([string]$Name)
  return $script:LiveGates -contains 'All' -or $script:LiveGates -contains $Name
}

$parseErrors = New-Object System.Collections.Generic.List[object]
Get-ChildItem -LiteralPath $scriptsRoot -Filter '*.ps1' -File | ForEach-Object {
  $tokens = $null
  $errors = $null
  [void][Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)
  foreach ($item in @($errors)) { if ($item) { $parseErrors.Add($item) } }
}
Add-GateResult -Name 'PowerShell parse' -Pass ($parseErrors.Count -eq 0) -Detail "errors=$($parseErrors.Count)"

$node = (Get-Command node -ErrorAction Stop).Source
Invoke-ExternalGate -Name 'Node injector syntax' -Executable $node -Arguments @('--check', (Join-Path $scriptsRoot 'injector.mjs'))
Invoke-ExternalGate -Name 'Node renderer syntax' -Executable $node -Arguments @('--check', (Join-Path $assetsRoot 'renderer-inject.js'))
Invoke-ExternalGate -Name 'Payload assembly' -Executable $node -Arguments @((Join-Path $scriptsRoot 'injector.mjs'), '--check-payload')

try {
  $theme = Get-Content -LiteralPath (Join-Path $assetsRoot 'theme.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $themePass = [int]$theme.schemaVersion -in @(1, 2) -and $theme.id -and $theme.name
  Add-GateResult -Name 'Theme JSON' -Pass $themePass -Detail "schema=$($theme.schemaVersion); id=$($theme.id)"
} catch {
  Add-GateResult -Name 'Theme JSON' -Pass $false -Detail $_.Exception.Message
}

$version = (Get-Content -LiteralPath (Join-Path $ProjectRoot 'VERSION') -Raw).Trim()
$payloadLog = $results | Where-Object name -eq 'Payload assembly'
$payloadText = if ($payloadLog.logPath) { Get-Content -LiteralPath $payloadLog.logPath -Raw } else { '' }
Add-GateResult -Name 'Version consistency' -Pass ($version -and $payloadText -match [regex]::Escape('"version": "' + $version + '"')) -Detail "version=$version"

if (-not $StaticOnly) {
  $powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
  if (Test-LiveGate 'Verify') { Invoke-ExternalGate -Name 'Live verify' -Executable $powershell -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $scriptsRoot 'verify-workbuddy-skin.ps1'), '-ScreenshotPath', (Join-Path $ArtifactDirectory 'verify.png')) }
  if (Test-LiveGate 'Hover') { Invoke-ExternalGate -Name 'Hover audit' -Executable $powershell -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $scriptsRoot 'audit-workbuddy-hover.ps1'), '-ScreenshotPath', (Join-Path $ArtifactDirectory 'hover.png')) }
  if (Test-LiveGate 'Composer') { Invoke-ExternalGate -Name 'Composer audit' -Executable $powershell -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $scriptsRoot 'audit-workbuddy-composer.ps1'), '-ScreenshotPath', (Join-Path $ArtifactDirectory 'composer.png')) }
  if (Test-LiveGate 'Scenes') { Invoke-ExternalGate -Name 'Scene audit' -Executable $powershell -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $scriptsRoot 'audit-workbuddy-scenes.ps1')) }
  if (Test-LiveGate 'Pages') { Invoke-ExternalGate -Name 'Page and history audit' -Executable $powershell -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $scriptsRoot 'audit-workbuddy-pages.ps1'), '-ScreenshotDirectory', (Join-Path $ArtifactDirectory 'pages')) }
  if (Test-LiveGate 'Details') { Invoke-ExternalGate -Name 'Detail audit' -Executable $powershell -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $scriptsRoot 'audit-workbuddy-details.ps1'), '-ScreenshotDirectory', (Join-Path $ArtifactDirectory 'details')) }
  if (Test-LiveGate 'Settings') { Invoke-ExternalGate -Name 'Settings audit' -Executable $powershell -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $scriptsRoot 'audit-workbuddy-settings.ps1'), '-ScreenshotDirectory', (Join-Path $ArtifactDirectory 'settings')) }

  if (Test-LiveGate 'Pages') {
    $pageDirectory = Join-Path $ArtifactDirectory 'pages'
    $topShots = @(Get-ChildItem -LiteralPath $pageDirectory -Filter '*history-task-*-top.png' -File -ErrorAction SilentlyContinue)
    $bottomShots = @(Get-ChildItem -LiteralPath $pageDirectory -Filter '*history-task-*-bottom.png' -File -ErrorAction SilentlyContinue)
    $historyPass = $topShots.Count -ge 4 -and $bottomShots.Count -ge 4
    $pairDetails = New-Object System.Collections.Generic.List[string]
    foreach ($topShot in $topShots) {
      $bottomName = $topShot.Name -replace '-top\.png$', '-bottom.png'
      $bottomShot = $bottomShots | Where-Object Name -eq $bottomName | Select-Object -First 1
      if (-not $bottomShot) {
        $historyPass = $false
        $pairDetails.Add("missing=$bottomName")
        continue
      }
      $topHash = (Get-FileHash -LiteralPath $topShot.FullName -Algorithm SHA256).Hash
      $bottomHash = (Get-FileHash -LiteralPath $bottomShot.FullName -Algorithm SHA256).Hash
      $different = $topHash -ne $bottomHash
      if (-not $different) { $historyPass = $false }
      $pairDetails.Add("$($topShot.BaseName):different=$different")
    }
    Add-GateResult -Name 'History screenshot evidence' -Pass $historyPass -Detail "top=$($topShots.Count); bottom=$($bottomShots.Count); $($pairDetails -join '; ')"
  }

  $fullLiveRequested = $LiveGates -contains 'All' -or @('Verify', 'Hover', 'Composer', 'Scenes', 'Pages', 'Details', 'Settings').Where({ $LiveGates -contains $_ }).Count -eq 7
  $manualPass = $false
  $manualDetail = if ($fullLiveRequested) { 'manifest missing' } else { 'full live gate was not requested' }
  if ($fullLiveRequested -and $ManualReviewManifest) {
    try {
      $manifestPath = [IO.Path]::GetFullPath($ManualReviewManifest)
      $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
      $requiredChecks = @('welcome', 'sidebar', 'composer', 'historyTopBottom', 'longConversation', 'markdownCodeTable', 'artifactShelf', 'overlaysAndSettings', 'narrowWindow', 'maximizedWindow', 'keyboardFocus', 'reducedMotion', 'decorationNonBlocking', 'noOcclusionOrOverflow')
      $checksPass = $true
      foreach ($check in $requiredChecks) {
        if (-not $manifest.checks.PSObject.Properties[$check] -or $manifest.checks.$check -ne $true) { $checksPass = $false }
      }
      $lightPass = @($manifest.themes | Where-Object { $_.appearance -eq 'light' -and $_.passed -eq $true }).Count -ge 1
      $darkPass = @($manifest.themes | Where-Object { $_.appearance -eq 'dark' -and $_.passed -eq $true }).Count -ge 1
      $evidencePath = if ([IO.Path]::IsPathRooted([string]$manifest.evidenceDirectory)) { [string]$manifest.evidenceDirectory } else { Join-Path $ProjectRoot ([string]$manifest.evidenceDirectory) }
      $evidencePass = $manifest.evidenceDirectory -and (Test-Path -LiteralPath $evidencePath)
      $manualPass = [int]$manifest.schemaVersion -eq 1 -and $manifest.reviewer -and $manifest.reviewedAt -and $checksPass -and $lightPass -and $darkPass -and $evidencePass
      $manualDetail = "checks=$checksPass; light=$lightPass; dark=$darkPass; evidence=$evidencePass"
    } catch {
      $manualDetail = $_.Exception.Message
    }
  }
  if ($fullLiveRequested) { Add-GateResult -Name 'Manual visual review' -Pass $manualPass -Detail $manualDetail }
}

$automatedResults = @($results | Where-Object name -ne 'Manual visual review')
$automatedPass = $automatedResults.Count -gt 0 -and @($automatedResults | Where-Object { -not $_.pass }).Count -eq 0
$manualResult = $results | Where-Object name -eq 'Manual visual review' | Select-Object -First 1
$fullLiveRequested = -not $StaticOnly -and ($LiveGates -contains 'All' -or @('Verify', 'Hover', 'Composer', 'Scenes', 'Pages', 'Details', 'Settings').Where({ $LiveGates -contains $_ }).Count -eq 7)
$releaseReady = $fullLiveRequested -and $automatedPass -and $manualResult -and $manualResult.pass
$report = [pscustomobject]@{
  schemaVersion = 1
  projectRoot = $ProjectRoot
  version = $version
  staticOnly = [bool]$StaticOnly
  liveGates = $LiveGates
  fullLiveRequested = [bool]$fullLiveRequested
  automatedPass = $automatedPass
  releaseReady = [bool]$releaseReady
  artifactDirectory = $ArtifactDirectory
  results = $results
}
$reportPath = Join-Path $ArtifactDirectory 'strict-audit-report.json'
[IO.File]::WriteAllText($reportPath, ($report | ConvertTo-Json -Depth 8), $utf8NoBom)
$report | ConvertTo-Json -Depth 8

if (-not $automatedPass) { exit 1 }
if (-not $StaticOnly -and -not $releaseReady) { exit 2 }
exit 0
