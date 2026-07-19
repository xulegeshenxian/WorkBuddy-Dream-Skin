[CmdletBinding()]
param(
  [ValidateSet('List', 'Apply')]
  [string]$Action = 'List',
  [string]$Id,
  [switch]$NoApply,
  [switch]$RestartExisting
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common-workbuddy.ps1')

function Get-ThemePresets {
  if (-not (Test-Path -LiteralPath $script:ThemeLibraryRoot)) { return @() }
  return @(Get-ChildItem -LiteralPath $script:ThemeLibraryRoot -Directory | ForEach-Object {
    $configPath = Join-Path $_.FullName 'theme.json'
    if (-not (Test-Path -LiteralPath $configPath)) { return }
    try {
      $theme = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
      [pscustomobject]@{
        Id = $_.Name
        Name = [string]$theme.name
        Schema = [int]$theme.schemaVersion
        Path = $_.FullName
      }
    } catch {}
  })
}

if ($Action -eq 'List') {
  $presets = @(Get-ThemePresets)
  if ($presets.Count -eq 0) {
    Write-Host 'No saved WorkBuddy theme presets were found.'
  } else {
    $presets | Sort-Object Name, Id | Format-Table Id, Name, Schema -AutoSize
  }
  exit 0
}

if (-not $Id -or [IO.Path]::GetFileName($Id) -ne $Id) { throw 'Apply requires a valid preset -Id.' }
$presetRoot = Join-Path $script:ThemeLibraryRoot $Id
$presetConfig = Join-Path $presetRoot 'theme.json'
if (-not (Test-Path -LiteralPath $presetConfig)) { throw "Theme preset was not found: $Id" }

if (Test-Path -LiteralPath $script:ThemeRoot) {
  $autosaveRoot = Join-Path $script:ThemeLibraryRoot '_autosave-current'
  New-Item -ItemType Directory -Force -Path $script:ThemeLibraryRoot | Out-Null
  if (Test-Path -LiteralPath $autosaveRoot) { Remove-Item -LiteralPath $autosaveRoot -Recurse -Force }
  Copy-Item -LiteralPath $script:ThemeRoot -Destination $autosaveRoot -Recurse -Force
  Remove-Item -LiteralPath $script:ThemeRoot -Recurse -Force
}
Copy-Item -LiteralPath $presetRoot -Destination $script:ThemeRoot -Recurse -Force

# Detect palette drift: if the preset claims a canonical `style` but the palette-
# critical color tokens don't match the shipped palette, the preset was corrupted
# by an earlier partial write. Re-apply the canonical palette to heal it. Common
# case: legacy scripts wrote `id`/`name` for one style but left `accentAlt` /
# `panelAlt` / `line` from a different palette (observed on gilded-night-banquet
# where deep-sea tokens leaked in).
$appliedConfig = Join-Path $script:ThemeRoot 'theme.json'
$appliedTheme = Get-Content -LiteralPath $appliedConfig -Raw -Encoding UTF8 | ConvertFrom-Json
$appliedStyle = if ($appliedTheme.PSObject.Properties['style']) { [string]$appliedTheme.style } else { $null }
$canonicalStyles = @{ 'pink-dream'='PinkDream'; 'mint-bloom'='MintBloom'; 'sunlit-campus'='SunlitCampus'; 'gilded-night'='GildedNight'; 'deep-sea'='DeepSea' }
$healArg = 'Current'
if ($appliedStyle -and $canonicalStyles.ContainsKey($appliedStyle)) {
  try {
    $palettes = Get-Content -LiteralPath (Join-Path $script:SkinRoot 'assets\style-palettes.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $palette = $palettes.$appliedStyle
    if ($palette) {
      foreach ($key in @('accentAlt', 'panelAlt', 'secondary', 'line')) {
        if ([string]$appliedTheme.colors.$key -ne [string]$palette.colors.$key) {
          Write-Warning "Preset $Id declares style '$appliedStyle' but has drifted token '$key'. Re-applying the canonical palette."
          $healArg = $canonicalStyles[$appliedStyle]
          break
        }
      }
    }
  } catch {}
}
& (Join-Path $PSScriptRoot 'customize-workbuddy-theme.ps1') -Style $healArg -SyncDecoration -NoApply

# If we healed, mirror the corrected theme.json back into the preset dir so
# the next switch won't repeat the same warning.
if ($healArg -ne 'Current') {
  try {
    Copy-Item -LiteralPath $appliedConfig -Destination (Join-Path $presetRoot 'theme.json') -Force
    Write-Host "Preset $Id file was healed in place."
  } catch {
    Write-Warning "Preset $Id was applied cleanly but the preset file could not be healed: $($_.Exception.Message)"
  }
}
$activeConfig = Join-Path $script:ThemeRoot 'theme.json'
$activeTheme = Get-Content -LiteralPath $activeConfig -Raw -Encoding UTF8 | ConvertFrom-Json
$activeTheme | Add-Member -NotePropertyName presetId -NotePropertyValue $Id -Force
Write-JsonUtf8NoBom $activeConfig $activeTheme
Write-Host "Applied WorkBuddy theme preset: $Id"

if (-not $NoApply) {
  $activeEndpoint = $false
  try {
    if (Test-Path -LiteralPath $script:StatePath) {
      $state = Get-Content -LiteralPath $script:StatePath -Raw | ConvertFrom-Json
      $activeEndpoint = [bool]($state.port -and (Test-WorkBuddyDebugPort ([int]$state.port)))
    }
  } catch {}
  if ($activeEndpoint) {
    & (Join-Path $PSScriptRoot 'start-workbuddy-skin.ps1')
    Write-Host 'The running WorkBuddy theme and injector were refreshed.'
  } elseif ($RestartExisting) {
    & (Join-Path $PSScriptRoot 'start-workbuddy-skin.ps1') -RestartExisting
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host 'WorkBuddy was restarted and the selected theme is active.'
  } else {
    Write-Warning 'The preset was saved, but WorkBuddy does not have an active skin endpoint.'
  }
}
