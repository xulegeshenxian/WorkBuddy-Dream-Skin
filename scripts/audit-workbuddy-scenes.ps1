[CmdletBinding()]
param([int]$Port = 0)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common-workbuddy.ps1')
$node = Resolve-NodeExecutable

if ($Port -eq 0 -and (Test-Path -LiteralPath $script:StatePath)) {
  $state = Get-Content -LiteralPath $script:StatePath -Raw | ConvertFrom-Json
  $Port = [int]$state.port
}
if ($Port -lt 1024) { throw 'No active skin port was found.' }

& $node $script:InjectorPath '--audit-scenes' '--port' "$Port"
exit $LASTEXITCODE
