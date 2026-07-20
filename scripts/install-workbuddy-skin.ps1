[CmdletBinding()]
param(
  [string]$InstallDirectory = (Join-Path $env:LOCALAPPDATA 'WorkBuddyDreamSkin\app'),
  [string]$WorkBuddyPath,
  [switch]$StartNow,
  [switch]$RestartExisting,
  [switch]$NoDesktopShortcut,
  [switch]$NoTray,
  [switch]$ResetBuiltinPresets
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common-workbuddy.ps1')

$sourceRoot = [IO.Path]::GetFullPath($script:SkinRoot)
$destinationRoot = [IO.Path]::GetFullPath($InstallDirectory)
$sourceIsDestination = $sourceRoot.Equals($destinationRoot, [StringComparison]::OrdinalIgnoreCase)
$installMarker = Join-Path $destinationRoot '.workbuddy-dream-skin-install'

if ([IO.Path]::GetPathRoot($destinationRoot).Equals($destinationRoot, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'The install directory cannot be a drive root.'
}
if (-not $sourceIsDestination -and (Test-Path -LiteralPath $destinationRoot)) {
  $hasContent = @(Get-ChildItem -LiteralPath $destinationRoot -Force -ErrorAction SilentlyContinue).Count -gt 0
  if ($hasContent -and -not (Test-Path -LiteralPath $installMarker)) {
    throw "The install directory contains files and is not marked as a WorkBuddy Dream Skin installation: $destinationRoot"
  }
}

if (-not $sourceIsDestination) {
  Stop-RecordedInjector
  Stop-RecordedTray
  New-Item -ItemType Directory -Force -Path $destinationRoot | Out-Null
  foreach ($name in @('assets', 'scripts')) {
    $destination = Join-Path $destinationRoot $name
    if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Recurse -Force }
    Copy-Item -LiteralPath (Join-Path $sourceRoot $name) -Destination $destination -Recurse -Force
  }
  foreach ($name in @('VERSION', 'README.md', 'CHANGELOG.md')) {
    $source = Join-Path $sourceRoot $name
    if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination (Join-Path $destinationRoot $name) -Force }
  }
  [IO.File]::WriteAllText($installMarker, 'workbuddy-dream-skin', (New-Object Text.UTF8Encoding($false)))
}

$powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
$shell = New-Object -ComObject WScript.Shell
$startScript = Join-Path $destinationRoot 'scripts\start-workbuddy-skin.ps1'

function New-SkinShortcut {
  param([string]$Path, [string]$Script, [string]$ExtraArguments = '')
  $shortcut = $shell.CreateShortcut($Path)
  $shortcut.TargetPath = $powershell
  # -WindowStyle Hidden 让脚本运行期间不显示黑色 PS 窗口（避免 30s 验证轮询时的碍眼窗口）；
  # WindowStyle = 7 (minimized) 是保险，某些系统在 -WindowStyle Hidden 生效前会有极短闪烁。
  $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Script`" $ExtraArguments".Trim()
  $shortcut.WorkingDirectory = $destinationRoot
  $shortcut.IconLocation = (Resolve-WorkBuddyExecutable $WorkBuddyPath) + ',0'
  $shortcut.WindowStyle = 7
  $shortcut.Save()
}

$startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
New-Item -ItemType Directory -Force -Path $startMenu | Out-Null
$desktop = [Environment]::GetFolderPath('Desktop')
foreach ($legacyShortcut in @(
  (Join-Path $desktop 'WorkBuddy Dream Skin - Restore.lnk'),
  (Join-Path $desktop 'WorkBuddy Dream Skin - Customize.lnk'),
  (Join-Path $desktop 'WorkBuddy Dream Skin - Themes.lnk'),
  (Join-Path $desktop 'WorkBuddy Dream Skin Control.lnk'),
  (Join-Path $startMenu 'WorkBuddy Dream Skin Control.lnk')
)) {
  Remove-Item -LiteralPath $legacyShortcut -Force -ErrorAction SilentlyContinue
}
New-SkinShortcut (Join-Path $startMenu 'WorkBuddy Dream Skin.lnk') $startScript

if (-not $NoDesktopShortcut) {
  New-SkinShortcut (Join-Path $desktop 'WorkBuddy Dream Skin.lnk') $startScript
}

Write-Host "WorkBuddy Dream Skin was installed to $destinationRoot"
Write-Host 'The official WorkBuddy files were not modified.'

# Seed built-in theme presets into the user's theme library. First-time users
# get all 11 shipped themes ready to switch to from the tray. Existing preset
# directories are left alone unless -ResetBuiltinPresets is passed, so any
# user tweaks (renames, palette overrides, hero image swaps) survive re-install.
$presetSource = Join-Path $destinationRoot 'assets\theme-presets'
if (Test-Path -LiteralPath $presetSource) {
  New-Item -ItemType Directory -Force -Path $script:ThemeLibraryRoot | Out-Null
  $seeded = 0; $skipped = 0
  foreach ($srcPreset in (Get-ChildItem -LiteralPath $presetSource -Directory)) {
    $targetPreset = Join-Path $script:ThemeLibraryRoot $srcPreset.Name
    if (Test-Path -LiteralPath $targetPreset) {
      if ($ResetBuiltinPresets) {
        Remove-Item -LiteralPath $targetPreset -Recurse -Force
      } else {
        $skipped += 1
        continue
      }
    }
    Copy-Item -LiteralPath $srcPreset.FullName -Destination $targetPreset -Recurse -Force
    $seeded += 1
  }
  Write-Host "Built-in preset seeding: $seeded new, $skipped kept as-is (use -ResetBuiltinPresets to overwrite)."
}

if ($StartNow) {
  & $startScript -WorkBuddyPath $WorkBuddyPath -RestartExisting:$RestartExisting -NoTray:$NoTray
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  exit 0
}
