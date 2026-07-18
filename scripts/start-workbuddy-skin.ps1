[CmdletBinding()]
param(
  [int]$Port = 0,
  [string]$WorkBuddyPath,
  [switch]$RestartExisting,
  [switch]$ForegroundInjector,
  [switch]$NoTray
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common-workbuddy.ps1')
New-Item -ItemType Directory -Force -Path $script:StateRoot | Out-Null

$exe = Resolve-WorkBuddyExecutable $WorkBuddyPath
$node = Resolve-NodeExecutable
$version = Get-WorkBuddyVersion $exe
$mainProcesses = @(Get-MainWorkBuddyProcesses $exe)

if ($mainProcesses.Count -gt 0) {
  $existingState = $null
  if (Test-Path -LiteralPath $script:StatePath) {
    try { $existingState = Get-Content -LiteralPath $script:StatePath -Raw | ConvertFrom-Json } catch {}
  }
  if ($existingState -and $existingState.port -and (Test-WorkBuddyDebugPort ([int]$existingState.port))) {
    $Port = [int]$existingState.port
    Assert-PortOwnedByWorkBuddy $Port $exe
  } else {
    if (-not $RestartExisting) {
      throw 'WorkBuddy is running without the verified skin endpoint. Close it or rerun with -RestartExisting.'
    }
    Stop-WorkBuddyForRestart $exe
  }
}

if (-not (Test-WorkBuddyDebugPort $Port)) {
  $Port = Get-AvailableLoopbackPort $Port
  $arguments = @("--remote-debugging-address=127.0.0.1", "--remote-debugging-port=$Port")
  $app = Start-WorkBuddyDesktop $exe $arguments
  $deadline = (Get-Date).AddSeconds(45)
  while (-not (Test-WorkBuddyDebugPort $Port)) {
    if ($app.HasExited) { throw "WorkBuddy exited before exposing CDP. Exit code: $($app.ExitCode)" }
    if ((Get-Date) -ge $deadline) { throw "WorkBuddy did not expose a verified CDP target on port $Port within 45 seconds." }
    Start-Sleep -Milliseconds 400
  }
}

Assert-PortOwnedByWorkBuddy $Port $exe
Stop-RecordedInjector
$themeDir = Get-ActiveThemeDirectory
$themeArgs = @()
if ($themeDir) { $themeArgs = @('--theme-dir', $themeDir) }

if ($ForegroundInjector) {
  & $node $script:InjectorPath --watch --port $Port @themeArgs
  exit $LASTEXITCODE
}

$stdoutPath = Join-Path $script:StateRoot 'injector.log'
$stderrPath = Join-Path $script:StateRoot 'injector-error.log'
$injectorArgs = @("`"$script:InjectorPath`"", '--watch', '--port', "$Port") + $themeArgs
$daemon = Start-Process -FilePath $node -ArgumentList $injectorArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath

$mainPid = (Get-MainWorkBuddyProcesses $exe | Select-Object -First 1).ProcessId
$state = [ordered]@{
  schemaVersion = 1
  port = $Port
  injectorPid = $daemon.Id
  workBuddyPid = $mainPid
  workBuddyPath = $exe
  workBuddyVersion = $version
  startedAt = (Get-Date).ToString('o')
  skinRoot = $script:SkinRoot
  themeDir = $themeDir
}
Write-JsonUtf8NoBom $script:StatePath $state

$verified = $false
for ($attempt = 0; $attempt -lt 45; $attempt++) {
  Start-Sleep -Milliseconds 700
  & $node $script:InjectorPath --verify --port $Port --timeout-ms 2500 @themeArgs *> $null
  if ($LASTEXITCODE -eq 0) { $verified = $true; break }
  if ($daemon.HasExited) { break }
}
if (-not $verified) {
  Stop-RecordedInjector
  throw "WorkBuddy started, but skin verification failed. See $stderrPath"
}
if (-not $NoTray) { [void](Start-WorkBuddyTray) }
Write-Host "WorkBuddy Dream Skin $((Get-Content (Join-Path $script:SkinRoot 'VERSION') -Raw).Trim()) is active on loopback port $Port."
