[CmdletBinding()]
param(
  [string]$ImagePath,
  [string]$BackgroundImagePath,
  [string]$HeroImagePath,
  [string]$CharacterImagePath,
  [switch]$ClearCharacter,
  [ValidateSet('Auto', 'On', 'Off')]
  [string]$DecorationMode,
  [switch]$SyncDecoration,
  [ValidateSet('Auto', 'Current', 'PinkDream', 'MintBloom', 'SunlitCampus', 'GildedNight', 'DeepSea')]
  [string]$Style = 'Auto',
  [switch]$AnalyzeOnly,
  [string]$Name,
  [string]$Accent,
  [string]$AccentAlt,
  [string]$Background,
  [string]$Panel,
  [string]$PanelAlt,
  [string]$Secondary,
  [string]$Highlight,
  [string]$Text,
  [string]$Muted,
  [string]$Line,
  [string]$BackgroundPosition,
  [string]$BackgroundSize,
  [string]$HeroPosition,
  [string]$HeroSize,
  [string]$CharacterPosition,
  [string]$CharacterSize,
  [Nullable[double]]$BackgroundOverlay,
  [Nullable[double]]$HeroOverlay,
  [Nullable[double]]$CharacterOpacity,
  [Nullable[double]]$PanelOpacity,
  [string]$SavePreset,
  [switch]$Reset,
  [switch]$NoApply
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common-workbuddy.ps1')

function Test-ThemeImagePath {
  param([string]$Path)
  $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
  $extension = [IO.Path]::GetExtension($resolved).ToLowerInvariant()
  if ($extension -notin @('.png', '.jpg', '.jpeg', '.webp', '.gif', '.svg')) { throw "Unsupported image type: $extension" }
  if ((Get-Item -LiteralPath $resolved).Length -gt 16MB) { throw 'Each image must be 16 MB or smaller.' }
  return $resolved
}

function Copy-ThemeImage {
  param([string]$Path, [string]$Role)
  $resolved = Test-ThemeImagePath $Path
  $extension = [IO.Path]::GetExtension($resolved).ToLowerInvariant()
  $imageName = "$Role-image$extension"
  Copy-Item -LiteralPath $resolved -Destination (Join-Path $script:ThemeRoot $imageName) -Force
  return $imageName
}

function Assert-CssPosition {
  param([string]$Value, [string]$Name)
  if (-not $Value) { return }
  $token = '(?:left|center|right|top|bottom|-?\d+(?:\.\d+)?(?:%|px))'
  if ($Value.Trim() -notmatch "^$token(?:\s+$token){0,3}$") { throw "$Name contains an unsupported CSS position." }
}

function Assert-CssSize {
  param([string]$Value, [string]$Name)
  if (-not $Value) { return }
  $token = '(?:cover|contain|auto|\d+(?:\.\d+)?(?:%|px|vw|vh))'
  if ($Value.Trim() -notmatch "^$token(?:\s+$token)?$") { throw "$Name contains an unsupported CSS size." }
}

function Assert-Opacity {
  param([Nullable[double]]$Value, [string]$Name, [double]$Minimum = 0)
  if ($null -eq $Value) { return }
  if ($Value -lt $Minimum -or $Value -gt 1) { throw "$Name must be between $Minimum and 1." }
}

function Get-ThemeStyleFromImage {
  param([string]$Path)
  $resolved = Test-ThemeImagePath $Path
  try {
    Add-Type -AssemblyName System.Drawing
    $source = [Drawing.Image]::FromFile($resolved)
    $sample = $null
    try {
      $sample = New-Object Drawing.Bitmap 64, 64
      $graphics = [Drawing.Graphics]::FromImage($sample)
      try { $graphics.DrawImage($source, 0, 0, 64, 64) } finally { $graphics.Dispose() }
      $scores = @{ 'pink-dream' = 0.0; 'mint-bloom' = 0.0; 'sunlit-campus' = 0.0; 'gilded-night' = 0.0 }
      $lightnessTotal = 0.0
      $pixelCount = 0
      for ($y = 0; $y -lt 64; $y += 2) {
        for ($x = 0; $x -lt 64; $x += 2) {
          $color = $sample.GetPixel($x, $y)
          $brightness = [double]$color.GetBrightness()
          $saturation = [double]$color.GetSaturation()
          $hue = [double]$color.GetHue()
          $lightnessTotal += $brightness
          $pixelCount += 1
          if ($saturation -lt 0.08 -or $brightness -lt 0.08) { continue }
          $weight = $saturation * (0.35 + $brightness)
          if ($hue -le 35 -or $hue -ge 325) { $scores['pink-dream'] += $weight }
          if ($hue -ge 145 -and $hue -le 190) { $scores['mint-bloom'] += $weight }
          if ($hue -gt 35 -and $hue -lt 145) { $scores['sunlit-campus'] += $weight }
          if ($hue -gt 24 -and $hue -lt 58 -and $brightness -lt 0.56) { $scores['gilded-night'] += $weight * 1.25 }
        }
      }
      $averageLightness = if ($pixelCount) { $lightnessTotal / $pixelCount } else { 0 }
      if ($averageLightness -lt 0.24) { return 'deep-sea' }
      return [string](($scores.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key)
    } finally {
      if ($sample) { $sample.Dispose() }
      $source.Dispose()
    }
  } catch {
    $fileName = [IO.Path]::GetFileNameWithoutExtension($resolved).ToLowerInvariant()
    if ($fileName -match 'pink|rose|girl') { return 'pink-dream' }
    if ($fileName -match 'mint|bloom|flower|garden') { return 'mint-bloom' }
    if ($fileName -match 'campus|school|sunlit') { return 'sunlit-campus' }
    Write-Warning 'Image analysis failed. DeepSea was selected. Use -Style to choose another palette.'
    return 'deep-sea'
  }
}

function ConvertTo-HexColor {
  param([double]$Hue, [double]$Saturation, [double]$Value)
  # HSV → hex (#RRGGBB). Hue in [0,360), S/V in [0,1].
  $c = $Value * $Saturation
  $seg = ($Hue / 60) % 6
  $x = $c * (1 - [math]::Abs(($seg % 2) - 1))
  $m = $Value - $c
  if ($Hue -lt 60) { $r = $c; $g = $x; $b = 0 }
  elseif ($Hue -lt 120) { $r = $x; $g = $c; $b = 0 }
  elseif ($Hue -lt 180) { $r = 0; $g = $c; $b = $x }
  elseif ($Hue -lt 240) { $r = 0; $g = $x; $b = $c }
  elseif ($Hue -lt 300) { $r = $x; $g = 0; $b = $c }
  else { $r = $c; $g = 0; $b = $x }
  $R = [int][math]::Round(($r + $m) * 255)
  $G = [int][math]::Round(($g + $m) * 255)
  $B = [int][math]::Round(($b + $m) * 255)
  return ('#{0:X2}{1:X2}{2:X2}' -f $R, $G, $B)
}

function Get-VividAccentFromImage {
  # Extract the dominant vivid color from an image and normalize into a
  # UI-friendly range. Returns $null if the image is too flat / grayscale
  # to yield a stable accent (fallback to canonical palette).
  param([string]$Path, [string]$Appearance = 'dark')
  try {
    $resolved = Test-ThemeImagePath $Path
    Add-Type -AssemblyName System.Drawing
    $source = [Drawing.Image]::FromFile($resolved)
    $sample = $null
    try {
      $sample = New-Object Drawing.Bitmap 128, 128
      $graphics = [Drawing.Graphics]::FromImage($sample)
      try { $graphics.DrawImage($source, 0, 0, 128, 128) } finally { $graphics.Dispose() }
      $bucketCount = 24
      $counts = New-Object 'double[]' $bucketCount
      $hSum = New-Object 'double[]' $bucketCount
      $sSum = New-Object 'double[]' $bucketCount
      $vSum = New-Object 'double[]' $bucketCount
      $vivid = 0
      for ($y = 0; $y -lt 128; $y += 2) {
        for ($x = 0; $x -lt 128; $x += 2) {
          $c = $sample.GetPixel($x, $y)
          $h = [double]$c.GetHue()
          $s = [double]$c.GetSaturation()
          $v = [double]$c.GetBrightness()
          if ($s -lt 0.28 -or $v -lt 0.15 -or $v -gt 0.92) { continue }
          $idx = [int][math]::Floor($h / 15) % $bucketCount
          $w = $s * (0.4 + $v * 0.6)
          $counts[$idx] += $w
          $hSum[$idx] += $h * $w
          $sSum[$idx] += $s * $w
          $vSum[$idx] += $v * $w
          $vivid += 1
        }
      }
      if ($vivid -lt 200) { return $null }
      $bestIdx = 0
      $bestScore = 0.0
      for ($i = 0; $i -lt $bucketCount; $i++) {
        if ($counts[$i] -gt $bestScore) { $bestScore = $counts[$i]; $bestIdx = $i }
      }
      if ($bestScore -le 0) { return $null }
      $H = $hSum[$bestIdx] / $counts[$bestIdx]
      $S = $sSum[$bestIdx] / $counts[$bestIdx]
      $V = $vSum[$bestIdx] / $counts[$bestIdx]
      # Normalize into UI-friendly range so button text stays readable.
      $targetS = [math]::Max($S, 0.55)
      if ($Appearance -eq 'light') {
        $targetV = [math]::Min([math]::Max($V, 0.4), 0.58)
        $altV = [math]::Min($targetV + 0.12, 0.7)
      } else {
        $targetV = [math]::Min([math]::Max($V, 0.58), 0.82)
        $altV = [math]::Min($targetV + 0.12, 0.95)
      }
      $altS = [math]::Max($targetS - 0.15, 0.35)
      return [pscustomobject]@{
        Hue = $H
        AccentHex = ConvertTo-HexColor $H $targetS $targetV
        AccentAltHex = ConvertTo-HexColor $H $altS $altV
      }
    } finally {
      if ($sample) { $sample.Dispose() }
      $source.Dispose()
    }
  } catch {
    Write-Warning "Accent extraction failed: $($_.Exception.Message)"
    return $null
  }
}

function Resolve-ThemeStyle {
  param([string]$RequestedStyle, [string]$ImageForAnalysis)
  $styleMap = @{ PinkDream = 'pink-dream'; MintBloom = 'mint-bloom'; SunlitCampus = 'sunlit-campus'; GildedNight = 'gilded-night'; DeepSea = 'deep-sea' }
  if ($RequestedStyle -eq 'Current') { return $null }
  if ($RequestedStyle -ne 'Auto') { return $styleMap[$RequestedStyle] }
  if (-not $ImageForAnalysis) { return $null }
  return Get-ThemeStyleFromImage $ImageForAnalysis
}

function Invoke-HotApply {
  if ($NoApply -or -not (Test-Path -LiteralPath $script:StatePath)) { return }
  try {
    $state = Get-Content -LiteralPath $script:StatePath -Raw | ConvertFrom-Json
    if ($state.port -and (Test-WorkBuddyDebugPort ([int]$state.port))) {
      & (Join-Path $PSScriptRoot 'start-workbuddy-skin.ps1')
      Write-Host 'The running WorkBuddy theme and injector were refreshed.'
    }
  } catch {
    Write-Warning "Theme saved, but hot refresh failed: $($_.Exception.Message)"
  }
}

if ($Reset) {
  $active = $false
  if (-not $NoApply -and (Test-Path -LiteralPath $script:StatePath)) {
    try {
      $state = Get-Content -LiteralPath $script:StatePath -Raw | ConvertFrom-Json
      $active = [bool]($state.port -and (Test-WorkBuddyDebugPort ([int]$state.port)))
    } catch {}
  }
  Stop-RecordedInjector
  if (Test-Path -LiteralPath $script:ThemeRoot) { Remove-Item -LiteralPath $script:ThemeRoot -Recurse -Force }
  if ($active) {
    & (Join-Path $PSScriptRoot 'start-workbuddy-skin.ps1')
    Write-Host 'The built in theme is active.'
  } else {
    Write-Host 'The custom theme was reset. Start the skin again to use the built in theme.'
  }
  exit 0
}

$hasExplicitCustomization = $ImagePath -or $BackgroundImagePath -or $HeroImagePath -or $CharacterImagePath -or $ClearCharacter -or $SyncDecoration -or
  $PSBoundParameters.ContainsKey('DecorationMode') -or
  $Style -ne 'Auto' -or $AnalyzeOnly -or $Name -or $Accent -or $AccentAlt -or $Background -or $Panel -or $PanelAlt -or
  $Secondary -or $Highlight -or $Text -or $Muted -or $Line -or
  $BackgroundPosition -or $BackgroundSize -or $HeroPosition -or $HeroSize -or $CharacterPosition -or $CharacterSize -or
  $null -ne $BackgroundOverlay -or $null -ne $HeroOverlay -or $null -ne $CharacterOpacity -or $null -ne $PanelOpacity

if (-not $hasExplicitCustomization) {
  Add-Type -AssemblyName System.Windows.Forms
  $dialog = New-Object Windows.Forms.OpenFileDialog
  $dialog.Title = 'Choose a WorkBuddy Dream Skin background and hero image'
  $dialog.Filter = 'Theme images|*.png;*.jpg;*.jpeg;*.webp;*.gif;*.svg'
  if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { exit 0 }
  $ImagePath = $dialog.FileName
}

$analysisImage = if ($HeroImagePath) { $HeroImagePath } elseif ($ImagePath) { $ImagePath } elseif ($BackgroundImagePath) { $BackgroundImagePath } else { $null }
$resolvedStyle = Resolve-ThemeStyle $Style $analysisImage
if ($AnalyzeOnly) {
  if (-not $analysisImage) { throw 'AnalyzeOnly requires an image path.' }
  [pscustomobject]@{ Image = (Resolve-Path -LiteralPath $analysisImage).Path; Style = $resolvedStyle }
  exit 0
}

New-Item -ItemType Directory -Force -Path $script:ThemeRoot | Out-Null
$currentTheme = Join-Path $script:ThemeRoot 'theme.json'
$builtInTheme = Join-Path $script:SkinRoot 'assets\theme.json'
$themeSource = if (Test-Path -LiteralPath $currentTheme) { $currentTheme } else { $builtInTheme }
$themeSourceRoot = Split-Path -Parent $themeSource
$theme = Get-Content -LiteralPath $themeSource -Raw -Encoding UTF8 | ConvertFrom-Json
if ($theme.PSObject.Properties['presetId']) { $theme.PSObject.Properties.Remove('presetId') }

if (-not $resolvedStyle -and -not $theme.PSObject.Properties['appearance'] -and $theme.style -in @('pink-dream', 'mint-bloom', 'sunlit-campus', 'gilded-night', 'deep-sea')) {
  $resolvedStyle = [string]$theme.style
  Write-Host "Migrating legacy theme to adaptive palette: $resolvedStyle"
}

if ([int]$theme.schemaVersion -eq 1) {
  $legacyImage = [string]$theme.image
  $theme | Add-Member -NotePropertyName images -NotePropertyValue ([pscustomobject]@{ background = $legacyImage; hero = $legacyImage; character = $null }) -Force
  $theme | Add-Member -NotePropertyName layout -NotePropertyValue ([pscustomobject]@{
    backgroundPosition = '50% 50%'; backgroundSize = 'cover'; heroPosition = '50% 50%'; heroSize = 'cover'
    characterPosition = 'right 28px bottom 86px'; characterSize = '360px auto'
  }) -Force
  $theme | Add-Member -NotePropertyName effects -NotePropertyValue ([pscustomobject]@{
    backgroundOverlay = 0.86; heroOverlay = 0.72; characterOpacity = 1; panelOpacity = 0.96
  }) -Force
  $theme.PSObject.Properties.Remove('image')
}
$theme.schemaVersion = 2

if ($resolvedStyle) {
  $palettePath = Join-Path $script:SkinRoot 'assets\style-palettes.json'
  $palettes = Get-Content -LiteralPath $palettePath -Raw -Encoding UTF8 | ConvertFrom-Json
  $palette = $palettes.$resolvedStyle
  if (-not $palette) { throw "Theme palette was not found: $resolvedStyle" }
  $theme | Add-Member -NotePropertyName style -NotePropertyValue $resolvedStyle -Force
  $theme | Add-Member -NotePropertyName appearance -NotePropertyValue ([string]$palette.appearance) -Force
  $theme.id = $resolvedStyle
  $theme.name = [string]$palette.name
  $theme.eyebrow = [string]$palette.eyebrow
  $theme.tagline = [string]$palette.tagline
  foreach ($property in @('background', 'panel', 'panelAlt', 'accent', 'accentAlt', 'secondary', 'highlight', 'text', 'muted', 'line')) {
    $theme.colors.$property = [string]$palette.colors.$property
  }
  $theme.effects.backgroundOverlay = [double]$palette.backgroundOverlay
  $theme.effects.heroOverlay = [double]$palette.heroOverlay
  $theme.effects.panelOpacity = [double]$palette.panelOpacity
  Write-Host "Image style palette selected: $resolvedStyle"

  # 方案 A: derive accent + accentAlt from the imported image itself.
  # Keeps the canonical palette's structural values (background / panel /
  # text / muted / line-alpha) so contrast and hover states stay safe, but
  # lets the UI's main color respond to whatever image the user just
  # imported (紫色宇宙图 → 紫色 accent; 橙红夕阳 → 橙红 accent).
  # Only applied when the user did NOT explicitly pass -Accent / -AccentAlt.
  $primaryImage = if ($ImagePath) { $ImagePath }
    elseif ($HeroImagePath) { $HeroImagePath }
    elseif ($BackgroundImagePath) { $BackgroundImagePath }
    else { $null }
  if ($primaryImage) {
    # Give the imported theme its own identity instead of pretending to be
    # the canonical preset whose palette we borrowed. Without this, the
    # WorkBuddy top-left badge reads "晴日校园 / SUNLIT CAMPUS NOTES" even
    # though the hero image is the user's own photo, and the tray's
    # "切换主题" menu ends up ticking the built-in `sunlit-campus` row
    # via its fallback name-match. Structure colors and accent still come
    # from the canonical palette + image extraction — only the identity
    # strings change.
    if (-not $PSBoundParameters.ContainsKey('Name')) {
      $imageBaseName = [IO.Path]::GetFileNameWithoutExtension($primaryImage)
      $theme.id = 'custom-import'
      $theme.name = if ($imageBaseName) { "自定义 · $imageBaseName" } else { '自定义主题' }
      $theme.eyebrow = ('CUSTOM IMPORT · {0}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm'))
      $theme.tagline = '从你导入的图片生成。'
      # Clear presetId if it was inherited from a previous switch, so the
      # tray's active-preset check mark does not stick to the wrong row.
      if ($theme.PSObject.Properties['presetId']) {
        $theme.PSObject.Properties.Remove('presetId')
      }
      Write-Host "Custom import identity: $($theme.name)"
    }

    $accentResult = Get-VividAccentFromImage $primaryImage ([string]$palette.appearance)
    if ($accentResult) {
      if (-not $PSBoundParameters.ContainsKey('Accent')) {
        $theme.colors.accent = $accentResult.AccentHex
      }
      if (-not $PSBoundParameters.ContainsKey('AccentAlt')) {
        $theme.colors.accentAlt = $accentResult.AccentAltHex
      }
      if (-not $PSBoundParameters.ContainsKey('Line')) {
        $accentHex = $theme.colors.accent
        $rr = [Convert]::ToInt32($accentHex.Substring(1,2), 16)
        $gg = [Convert]::ToInt32($accentHex.Substring(3,2), 16)
        $bb = [Convert]::ToInt32($accentHex.Substring(5,2), 16)
        $theme.colors.line = "rgba($rr, $gg, $bb, .28)"
      }
      Write-Host "Image accent applied: accent=$($theme.colors.accent) accentAlt=$($theme.colors.accentAlt)"
    } else {
      Write-Host "Image accent extraction fell back to canonical palette (image too flat / grayscale)."
    }
  }
}

foreach ($role in @('background', 'hero', 'character')) {
  $fileName = $theme.images.$role
  if (-not $fileName) { continue }
  $destination = Join-Path $script:ThemeRoot $fileName
  if (-not (Test-Path -LiteralPath $destination)) {
    $source = Join-Path $themeSourceRoot $fileName
    if (-not (Test-Path -LiteralPath $source)) { throw "Theme image is missing: $source" }
    Copy-Item -LiteralPath $source -Destination $destination -Force
  }
}

if ($ImagePath) {
  $sharedImage = Copy-ThemeImage $ImagePath 'shared'
  $theme.images.background = $sharedImage
  $theme.images.hero = $sharedImage
}
if ($BackgroundImagePath) { $theme.images.background = Copy-ThemeImage $BackgroundImagePath 'background' }
if ($HeroImagePath) { $theme.images.hero = Copy-ThemeImage $HeroImagePath 'hero' }

$themeStyleProperty = $theme.PSObject.Properties['style']
$themeDecorationProperty = $theme.PSObject.Properties['decoration']
$themeStyle = if ($themeStyleProperty) { [string]$themeStyleProperty.Value } else { $null }
$themeDecoration = if ($themeDecorationProperty) { $themeDecorationProperty.Value } else { $null }
$decorationStyle = if ($resolvedStyle) { $resolvedStyle } elseif ($themeStyle) { $themeStyle } else {
  switch ([string]$theme.colors.accent) {
    '#D8B06B' { 'gilded-night' }
    '#B9E46F' { 'sunlit-campus' }
    '#58E6C2' { 'deep-sea' }
    default { $null }
  }
}
if ($decorationStyle -and -not $themeStyle) { $theme | Add-Member -NotePropertyName style -NotePropertyValue $decorationStyle -Force }
$storedDecorationMode = if ($themeDecoration -and $themeDecoration.mode -in @('auto', 'on', 'off')) { [string]$themeDecoration.mode } else { 'auto' }
$effectiveDecorationMode = if ($PSBoundParameters.ContainsKey('DecorationMode')) { $DecorationMode.ToLowerInvariant() } else { $storedDecorationMode }
$existingDecorationStyle = if ($themeDecoration) { [string]$themeDecoration.style } else { $null }
$decorationCompatible = [bool]($themeDecoration -and $themeDecoration.source -eq 'hero-full' -and $theme.images.hero -and $decorationStyle -and $existingDecorationStyle -eq $decorationStyle)
$decorationNeedsSource = [bool](
  $PSBoundParameters.ContainsKey('DecorationMode') -and
  $effectiveDecorationMode -ne 'off' -and
  $theme.images.hero -and
  (-not $themeDecoration -or $themeDecoration.source -in @('', 'none') -or $themeDecoration.variant -eq 'none')
)

if ($CharacterImagePath) {
  $theme.images.character = Copy-ThemeImage $CharacterImagePath 'character'
  $theme | Add-Member -NotePropertyName decoration -NotePropertyValue ([pscustomobject]@{
    mode = $effectiveDecorationMode; style = $decorationStyle; source = 'custom'; variant = 'custom-image'
  }) -Force
  $decorationCompatible = $true
} elseif ($ClearCharacter -or $effectiveDecorationMode -eq 'off') {
  $theme.images.character = $null
  $theme | Add-Member -NotePropertyName decoration -NotePropertyValue ([pscustomobject]@{
    mode = 'off'; style = $decorationStyle; source = 'none'; variant = 'none'
  }) -Force
} elseif (($resolvedStyle -or $SyncDecoration -or $ImagePath -or $HeroImagePath -or $decorationNeedsSource) -and -not $decorationCompatible) {
  if ($decorationStyle) {
    $allPalettes = Get-Content -LiteralPath (Join-Path $script:SkinRoot 'assets\style-palettes.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $decorationPalette = $allPalettes.$decorationStyle
    $theme.images.character = $null
    $theme.layout.characterPosition = [string]$decorationPalette.decoration.position
    $theme.layout.characterSize = [string]$decorationPalette.decoration.size
    $theme.effects.characterOpacity = [double]$decorationPalette.decoration.opacity
    $theme | Add-Member -NotePropertyName decoration -NotePropertyValue ([pscustomobject]@{
      mode = $effectiveDecorationMode; style = $decorationStyle; source = 'hero-full'; variant = 'full-image-card'
    }) -Force
  } else {
    $theme.images.character = $null
  }
} elseif ($themeDecoration) {
  $themeDecoration.mode = $effectiveDecorationMode
}

if ($Name) { $theme.name = $Name.Trim().Substring(0, [Math]::Min(80, $Name.Trim().Length)) }
$colorUpdates = @{
  accent = $Accent; accentAlt = $AccentAlt; background = $Background; panel = $Panel; panelAlt = $PanelAlt
  secondary = $Secondary; highlight = $Highlight; text = $Text; muted = $Muted; line = $Line
}
foreach ($property in $colorUpdates.Keys) {
  $value = $colorUpdates[$property]
  if (-not $value) { continue }
  if ($property -eq 'line') {
    if ($value -notmatch '^(?:#[0-9a-fA-F]{6}|rgba?\([0-9., %]+\))$') { throw 'line must use #RRGGBB, rgb(), or rgba() format.' }
  } elseif ($value -notmatch '^#[0-9a-fA-F]{6}$') { throw "$property must use the #RRGGBB format." }
  $theme.colors.$property = $value
}

Assert-CssPosition $BackgroundPosition 'BackgroundPosition'
Assert-CssPosition $HeroPosition 'HeroPosition'
Assert-CssPosition $CharacterPosition 'CharacterPosition'
Assert-CssSize $BackgroundSize 'BackgroundSize'
Assert-CssSize $HeroSize 'HeroSize'
Assert-CssSize $CharacterSize 'CharacterSize'
if ($BackgroundPosition) { $theme.layout.backgroundPosition = $BackgroundPosition.Trim() }
if ($BackgroundSize) { $theme.layout.backgroundSize = $BackgroundSize.Trim() }
if ($HeroPosition) { $theme.layout.heroPosition = $HeroPosition.Trim() }
if ($HeroSize) { $theme.layout.heroSize = $HeroSize.Trim() }
if ($CharacterPosition) { $theme.layout.characterPosition = $CharacterPosition.Trim() }
if ($CharacterSize) { $theme.layout.characterSize = $CharacterSize.Trim() }

Assert-Opacity $BackgroundOverlay 'BackgroundOverlay'
Assert-Opacity $HeroOverlay 'HeroOverlay'
Assert-Opacity $CharacterOpacity 'CharacterOpacity'
Assert-Opacity $PanelOpacity 'PanelOpacity' 0.35
if ($null -ne $BackgroundOverlay) { $theme.effects.backgroundOverlay = [double]$BackgroundOverlay }
if ($null -ne $HeroOverlay) { $theme.effects.heroOverlay = [double]$HeroOverlay }
if ($null -ne $CharacterOpacity) { $theme.effects.characterOpacity = [double]$CharacterOpacity }
if ($null -ne $PanelOpacity) { $theme.effects.panelOpacity = [double]$PanelOpacity }

Write-JsonUtf8NoBom $currentTheme $theme
$referencedImages = @($theme.images.background, $theme.images.hero, $theme.images.character) | Where-Object { $_ } | Select-Object -Unique
Get-ChildItem -LiteralPath $script:ThemeRoot -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Extension.ToLowerInvariant() -in @('.png', '.jpg', '.jpeg', '.webp', '.gif', '.svg') -and $_.Name -notin $referencedImages } |
  Remove-Item -Force
Write-Host "Custom theme saved to $currentTheme"

if ($SavePreset) {
  $presetId = ($SavePreset.Trim().ToLowerInvariant() -replace '[^a-z0-9._-]+', '-') -replace '^-+|-+$', ''
  if (-not $presetId) { $presetId = Get-Date -Format 'yyyyMMdd-HHmmss' }
  $theme.id = $presetId
  Write-JsonUtf8NoBom $currentTheme $theme
  $presetRoot = Join-Path $script:ThemeLibraryRoot $presetId
  New-Item -ItemType Directory -Force -Path $script:ThemeLibraryRoot | Out-Null
  if (Test-Path -LiteralPath $presetRoot) { Remove-Item -LiteralPath $presetRoot -Recurse -Force }
  Copy-Item -LiteralPath $script:ThemeRoot -Destination $presetRoot -Recurse -Force
  Write-Host "Theme preset saved as $presetId"
}

Invoke-HotApply
