[CmdletBinding()]
param(
  [int]$Port = 0,
  [string]$ScreenshotPath
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common-workbuddy.ps1')
$node = Resolve-NodeExecutable

if ($Port -eq 0 -and (Test-Path -LiteralPath $script:StatePath)) {
  $state = Get-Content -LiteralPath $script:StatePath -Raw | ConvertFrom-Json
  $Port = [int]$state.port
}
if ($Port -lt 1024) { throw 'No active skin port was found.' }

$arguments = @($script:InjectorPath, '--audit-composer', '--port', "$Port")
if ($ScreenshotPath) { $arguments += @('--screenshot', [IO.Path]::GetFullPath($ScreenshotPath)) }
& $node @arguments
exit $LASTEXITCODE
