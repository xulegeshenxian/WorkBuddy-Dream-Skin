[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [string]$Id,
  [switch]$NoApply,
  [switch]$RestartExisting
)

$ErrorActionPreference = 'Stop'
$manager = Join-Path $PSScriptRoot 'manage-workbuddy-themes.ps1'

if (-not $Id) {
  & $manager -Action List
  exit $LASTEXITCODE
}

& $manager -Action Apply -Id $Id -NoApply:$NoApply -RestartExisting:$RestartExisting
if (-not $?) {
  if ($LASTEXITCODE) { exit $LASTEXITCODE }
  exit 1
}
exit 0
