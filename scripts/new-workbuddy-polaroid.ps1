[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ImagePath,
  [Parameter(Mandatory = $true)]
  [string]$OutputPath,
  [string]$Caption = 'SUNLIT CAMPUS',
  [string]$Subcaption = 'BREATHE  MOVE  CREATE',
  [ValidateRange(0, 100)]
  [double]$FocusX = 50,
  [ValidateRange(0, 100)]
  [double]$FocusY = 38,
  [ValidateRange(-12, 12)]
  [double]$Rotation = 3
)

$ErrorActionPreference = 'Stop'

$source = (Resolve-Path -LiteralPath $ImagePath -ErrorAction Stop).Path
$extension = [IO.Path]::GetExtension($source).ToLowerInvariant()
if ($extension -notin @('.png', '.jpg', '.jpeg', '.webp', '.gif')) {
  throw 'The polaroid source must be PNG, JPG, JPEG, WebP, or GIF.'
}
if ((Get-Item -LiteralPath $source).Length -gt 16MB) {
  throw 'The polaroid source must be 16 MB or smaller.'
}

Add-Type -AssemblyName System.Drawing
$bitmap = [System.Drawing.Image]::FromFile($source)
try {
  $imageWidth = [double]$bitmap.Width
  $imageHeight = [double]$bitmap.Height
} finally {
  $bitmap.Dispose()
}

$cropWidth = [Math]::Round($imageWidth * 0.52, 2)
$cropHeight = [Math]::Round($imageHeight * 0.78, 2)
$cropX = [Math]::Max(0, [Math]::Min($imageWidth - $cropWidth, ($imageWidth * $FocusX / 100) - ($cropWidth / 2)))
$cropY = [Math]::Max(0, [Math]::Min($imageHeight - $cropHeight, ($imageHeight * $FocusY / 100) - ($cropHeight / 2)))
$mime = switch ($extension) {
  '.jpg' { 'image/jpeg' }
  '.jpeg' { 'image/jpeg' }
  '.webp' { 'image/webp' }
  '.gif' { 'image/gif' }
  default { 'image/png' }
}
$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($source))
$safeCaption = [Security.SecurityElement]::Escape($Caption)
$safeSubcaption = [Security.SecurityElement]::Escape($Subcaption)
$svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="360" height="440" viewBox="0 0 360 440">
  <defs>
    <filter id="shadow" x="-30%" y="-30%" width="160%" height="170%">
      <feDropShadow dx="0" dy="16" stdDeviation="13" flood-color="#001b16" flood-opacity=".42"/>
    </filter>
    <clipPath id="photo"><rect x="44" y="42" width="272" height="258" rx="3"/></clipPath>
  </defs>
  <g transform="rotate($Rotation 180 220)" filter="url(#shadow)">
    <rect x="26" y="20" width="308" height="386" rx="7" fill="#fffdf4" stroke="#d8e5c4" stroke-width="2"/>
    <g clip-path="url(#photo)">
      <svg x="44" y="42" width="272" height="258" viewBox="$cropX $cropY $cropWidth $cropHeight" preserveAspectRatio="xMidYMid slice">
        <image width="$imageWidth" height="$imageHeight" href="data:$mime;base64,$base64"/>
      </svg>
      <rect x="44" y="42" width="272" height="258" fill="none" stroke="#ffffff" stroke-opacity=".7"/>
    </g>
    <path d="M76 324c31 13 177 13 208 0" fill="none" stroke="#b8d98d" stroke-width="1.5" stroke-dasharray="2 7"/>
    <text x="180" y="348" text-anchor="middle" fill="#26554b" font-family="Georgia, 'Times New Roman', serif" font-size="19" font-weight="700" letter-spacing="2.4">$safeCaption</text>
    <text x="180" y="374" text-anchor="middle" fill="#73907f" font-family="Segoe UI, sans-serif" font-size="8.5" font-weight="700" letter-spacing="2.1">$safeSubcaption</text>
    <path d="M162 391h36" stroke="#e4c35b" stroke-width="3" stroke-linecap="round"/>
    <rect x="130" y="8" width="100" height="28" rx="3" fill="#f6e79c" fill-opacity=".72" transform="rotate(-2 180 22)"/>
  </g>
</svg>
"@

$destination = [IO.Path]::GetFullPath($OutputPath)
$directory = [IO.Path]::GetDirectoryName($destination)
if ($directory) { [IO.Directory]::CreateDirectory($directory) | Out-Null }
[IO.File]::WriteAllText($destination, $svg, (New-Object Text.UTF8Encoding($false)))
Write-Host "Created WorkBuddy polaroid artwork: $destination"
