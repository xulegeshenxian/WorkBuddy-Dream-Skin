[CmdletBinding()]
param(
  [int]$Port = 0,
  [switch]$RestartNormally,
  [switch]$Uninstall,
  [string]$WorkBuddyPath
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common-workbuddy.ps1')
$node = Resolve-NodeExecutable
$state = $null
if (Test-Path -LiteralPath $script:StatePath) {
  try { $state = Get-Content -LiteralPath $script:StatePath -Raw | ConvertFrom-Json } catch {}
}
if ($Port -eq 0 -and $state -and $state.port) { $Port = [int]$state.port }
if (-not $WorkBuddyPath -and $state -and $state.workBuddyPath) { $WorkBuddyPath = $state.workBuddyPath }

Stop-RecordedInjector
Start-Sleep -Milliseconds 250
if ($Port -ge 1024 -and (Test-WorkBuddyDebugPort $Port)) {
  try { & $node $script:InjectorPath --remove --port $Port --timeout-ms 4000 | Out-Host } catch {}
}
Remove-Item -LiteralPath $script:StatePath -Force -ErrorAction SilentlyContinue

if ($RestartNormally) {
  $exe = Resolve-WorkBuddyExecutable $WorkBuddyPath
  Stop-WorkBuddyForRestart $exe
  Start-WorkBuddyDesktop $exe | Out-Null
}

if ($Uninstall) {
  Stop-RecordedTray
  $desktop = [Environment]::GetFolderPath('Desktop')
  $startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
  foreach ($path in @(
    (Join-Path $desktop 'WorkBuddy Dream Skin.lnk'),
    (Join-Path $desktop 'WorkBuddy Dream Skin - Restore.lnk'),
    (Join-Path $desktop 'WorkBuddy Dream Skin - Customize.lnk'),
    (Join-Path $desktop 'WorkBuddy Dream Skin - Themes.lnk'),
    (Join-Path $desktop 'WorkBuddy Dream Skin Control.lnk'),
    (Join-Path $startMenu 'WorkBuddy Dream Skin.lnk'),
    (Join-Path $startMenu 'WorkBuddy Dream Skin Control.lnk')
  )) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
}
Write-Host 'WorkBuddy Dream Skin has been removed from the live renderer.'
