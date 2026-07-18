[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('pink-dream', 'mint-bloom', 'sunlit-campus', 'gilded-night', 'deep-sea')]
  [string]$Style,
  [Parameter(Mandatory = $true)]
  [string]$OutputPath,
  [string]$Accent = '#F58FB1',
  [string]$AccentAlt = '#FFD2E0',
  [string]$Secondary = '#C97996',
  [string]$Highlight = '#FFE09C'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common-workbuddy.ps1')

foreach ($entry in @{ Accent = $Accent; AccentAlt = $AccentAlt; Secondary = $Secondary; Highlight = $Highlight }.GetEnumerator()) {
  if ($entry.Value -notmatch '^#[0-9a-fA-F]{6}$') { throw "$($entry.Key) must use the #RRGGBB format." }
}

$templates = @{
  'pink-dream' = @'
<g filter="url(#shadow)">
  <path d="M118 382C74 332 77 263 119 215c32-37 68-71 77-125 42 45 48 102 18 148-28 43-68 76-96 144Z" fill="none" stroke="ACCENT" stroke-width="10" stroke-linecap="round" opacity=".68"/>
  <path d="M90 338c44-7 83-31 112-67" fill="none" stroke="ACCENT_ALT" stroke-width="6" stroke-linecap="round"/>
  <ellipse cx="137" cy="226" rx="44" ry="58" fill="ACCENT_ALT" transform="rotate(-24 137 226)"/>
  <ellipse cx="176" cy="231" rx="42" ry="57" fill="ACCENT" opacity=".82" transform="rotate(24 176 231)"/>
  <ellipse cx="156" cy="196" rx="37" ry="53" fill="#fff7f9" opacity=".92"/>
  <circle cx="157" cy="230" r="25" fill="HIGHLIGHT"/>
  <path d="M157 286c-28 30-38 69-28 110M166 286c25 34 30 71 13 111" fill="none" stroke="SECONDARY" stroke-width="7" stroke-linecap="round"/>
  <g fill="#fff7f9"><circle cx="86" cy="179" r="13"/><circle cx="221" cy="161" r="10"/><circle cx="229" cy="304" r="14"/></g>
</g>
'@
  'mint-bloom' = @'
<g filter="url(#shadow)">
  <path d="M145 414C116 321 122 204 169 84" fill="none" stroke="SECONDARY" stroke-width="8" stroke-linecap="round"/>
  <g fill="ACCENT" opacity=".9"><ellipse cx="122" cy="311" rx="32" ry="67" transform="rotate(-48 122 311)"/><ellipse cx="186" cy="255" rx="29" ry="65" transform="rotate(45 186 255)"/><ellipse cx="132" cy="179" rx="27" ry="57" transform="rotate(-44 132 179)"/></g>
  <g fill="ACCENT_ALT"><circle cx="174" cy="127" r="35"/><circle cx="141" cy="118" r="31"/><circle cx="157" cy="91" r="32"/><circle cx="194" cy="96" r="30"/></g>
  <circle cx="168" cy="110" r="21" fill="HIGHLIGHT"/>
  <rect x="76" y="342" width="174" height="96" rx="20" fill="#f5fffc" opacity=".9" stroke="ACCENT" stroke-width="5"/>
  <path d="M105 376h116M105 401h78" stroke="SECONDARY" stroke-width="7" stroke-linecap="round" opacity=".58"/>
</g>
'@
  'sunlit-campus' = @'
<g filter="url(#shadow)" transform="rotate(4 160 250)">
  <rect x="64" y="76" width="208" height="326" rx="18" fill="#fffdf1" stroke="HIGHLIGHT" stroke-width="7"/>
  <rect x="86" y="104" width="164" height="178" rx="10" fill="SECONDARY" opacity=".78"/>
  <circle cx="207" cy="148" r="30" fill="HIGHLIGHT"/>
  <path d="M91 259c35-54 65-79 93-75 24 4 43 31 66 75Z" fill="ACCENT"/>
  <path d="M105 320h126M105 349h91" stroke="SECONDARY" stroke-width="9" stroke-linecap="round" opacity=".72"/>
  <path d="M238 391l-33 58-21-47" fill="ACCENT"/>
</g>
'@
  'gilded-night' = @'
<g filter="url(#shadow)">
  <circle cx="168" cy="186" r="98" fill="none" stroke="HIGHLIGHT" stroke-width="5" opacity=".72"/>
  <path d="M168 88A98 98 0 0 0 91 246c32-18 60-27 84-25 28 2 52 17 72 44A98 98 0 0 0 168 88Z" fill="ACCENT" opacity=".34"/>
  <path d="M72 351c58-68 123-76 193-22-57-15-104 2-141 51Z" fill="SECONDARY" opacity=".82"/>
  <path d="M91 347c43-81 101-108 174-82-43 9-79 43-109 104Z" fill="none" stroke="HIGHLIGHT" stroke-width="8"/>
  <g fill="ACCENT_ALT"><circle cx="106" cy="133" r="7"/><circle cx="229" cy="111" r="5"/><circle cx="257" cy="212" r="8"/></g>
</g>
'@
  'deep-sea' = @'
<g filter="url(#shadow)">
  <circle cx="168" cy="244" r="118" fill="none" stroke="ACCENT" stroke-width="5" opacity=".58"/>
  <circle cx="168" cy="244" r="82" fill="none" stroke="ACCENT_ALT" stroke-width="3" opacity=".48"/>
  <circle cx="168" cy="244" r="43" fill="none" stroke="SECONDARY" stroke-width="3" opacity=".58"/>
  <path d="M168 244 242 151A118 118 0 0 1 274 246Z" fill="ACCENT" opacity=".24"/>
  <circle cx="227" cy="194" r="10" fill="HIGHLIGHT"/>
  <circle cx="118" cy="287" r="7" fill="ACCENT_ALT"/>
  <path d="M168 104v280M28 244h280" stroke="ACCENT" stroke-width="2" opacity=".3"/>
</g>
'@
}

$body = $templates[$Style].Replace('ACCENT_ALT', $AccentAlt).Replace('SECONDARY', $Secondary).Replace('HIGHLIGHT', $Highlight).Replace('ACCENT', $Accent)
$svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="336" height="480" viewBox="0 0 336 480">
  <defs><filter id="shadow" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="0" dy="14" stdDeviation="12" flood-color="#000" flood-opacity=".2"/></filter></defs>
  $body
</svg>
"@

$parent = Split-Path -Parent $OutputPath
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
[IO.File]::WriteAllText($OutputPath, $svg, (New-Object Text.UTF8Encoding($false)))
Write-Host "Generated $Style decoration: $OutputPath"
