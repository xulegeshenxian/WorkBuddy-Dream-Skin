Set-StrictMode -Version 2.0

$script:SkinRoot = Split-Path -Parent $PSScriptRoot
$script:StateRoot = Join-Path $env:LOCALAPPDATA 'WorkBuddyDreamSkin'
$script:StatePath = Join-Path $script:StateRoot 'state.json'
$script:TrayStatePath = Join-Path $script:StateRoot 'tray-state.json'
$script:ThemeRoot = Join-Path $script:StateRoot 'theme'
$script:ThemeLibraryRoot = Join-Path $script:StateRoot 'themes'
$script:InjectorPath = Join-Path $PSScriptRoot 'injector.mjs'

function Resolve-WorkBuddyExecutable {
  param([string]$ExplicitPath)

  $candidates = New-Object System.Collections.Generic.List[string]
  if ($ExplicitPath) { $candidates.Add($ExplicitPath) }

  Get-CimInstance Win32_Process -Filter "Name='WorkBuddy.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.ExecutablePath } |
    ForEach-Object { $candidates.Add($_.ExecutablePath) }

  foreach ($registryRoot in @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
  )) {
    Get-ItemProperty $registryRoot -ErrorAction SilentlyContinue |
      Where-Object { $_.PSObject.Properties['DisplayName'] -and $_.DisplayName -match '^WorkBuddy' } |
      ForEach-Object {
        if ($_.PSObject.Properties['InstallLocation'] -and $_.InstallLocation) {
          $candidates.Add((Join-Path $_.InstallLocation 'WorkBuddy.exe'))
        }
        if ($_.PSObject.Properties['DisplayIcon'] -and $_.DisplayIcon) {
          $candidates.Add(($_.DisplayIcon -replace '^"|"(?:,\d+)?$|,\d+$', ''))
        }
      }
  }

  foreach ($candidate in @(
    (Join-Path $env:LOCALAPPDATA 'Programs\WorkBuddy\WorkBuddy.exe'),
    (Join-Path $env:LOCALAPPDATA 'WorkBuddy\WorkBuddy.exe'),
    (Join-Path $env:ProgramFiles 'WorkBuddy\WorkBuddy.exe'),
    'D:\software\WorkBuddy\WorkBuddy.exe'
  )) { if ($candidate) { $candidates.Add($candidate) } }

  foreach ($candidate in $candidates) {
    if (-not $candidate) { continue }
    try {
      $resolved = (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).Path
      if ([IO.Path]::GetFileName($resolved) -ieq 'WorkBuddy.exe') { return $resolved }
    } catch {}
  }
  throw 'WorkBuddy.exe was not found. Pass -WorkBuddyPath with its absolute path.'
}

function Resolve-NodeExecutable {
  $command = Get-Command node -ErrorAction SilentlyContinue
  if (-not $command) {
    $candidates = New-Object System.Collections.Generic.List[string]
    if ($env:ProgramFiles) { $candidates.Add((Join-Path $env:ProgramFiles 'nodejs\node.exe')) }
    if (${env:ProgramFiles(x86)}) { $candidates.Add((Join-Path ${env:ProgramFiles(x86)} 'nodejs\node.exe')) }
    if ($env:LOCALAPPDATA) { $candidates.Add((Join-Path $env:LOCALAPPDATA 'Programs\nodejs\node.exe')) }
    $managedRoot = Join-Path $env:USERPROFILE '.workbuddy\binaries\node\versions'
    if (Test-Path -LiteralPath $managedRoot) {
      Get-ChildItem -Directory -LiteralPath $managedRoot -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        ForEach-Object { $candidates.Add((Join-Path $_.FullName 'node.exe')) }
    }
    foreach ($path in $candidates) {
      if ($path -and (Test-Path -LiteralPath $path)) {
        $command = [PSCustomObject]@{ Source = $path }
        break
      }
    }
  }
  if (-not $command) { throw "Node.js 22 or newer is required. 'node' was not found on PATH or in common install locations (Program Files\nodejs, LOCALAPPDATA\Programs\nodejs, %USERPROFILE%\.workbuddy\binaries\node)." }
  $versionText = & $command.Source --version
  $major = [int](($versionText -replace '^v', '').Split('.')[0])
  if ($major -lt 22) { throw "Node.js 22 or newer is required. Found $versionText at $($command.Source)." }
  return $command.Source
}

function Get-WorkBuddyVersion {
  param([string]$Executable)
  return (Get-Item -LiteralPath $Executable).VersionInfo.FileVersion
}

function Start-WorkBuddyDesktop {
  param([string]$Executable, [string[]]$Arguments = @())
  $savedRunAsNode = $env:ELECTRON_RUN_AS_NODE
  try {
    Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue
    $startParameters = @{
      FilePath = $Executable
      WorkingDirectory = (Split-Path -Parent $Executable)
      PassThru = $true
    }
    if ($Arguments.Count -gt 0) { $startParameters.ArgumentList = $Arguments }
    return Start-Process @startParameters
  } finally {
    if ($null -ne $savedRunAsNode) { $env:ELECTRON_RUN_AS_NODE = $savedRunAsNode }
  }
}

function Get-MainWorkBuddyProcesses {
  param([string]$Executable)
  $resolved = [IO.Path]::GetFullPath($Executable)
  return @(Get-CimInstance Win32_Process -Filter "Name='WorkBuddy.exe'" -ErrorAction SilentlyContinue |
    Where-Object {
      $_.ExecutablePath -and [IO.Path]::GetFullPath($_.ExecutablePath).Equals($resolved, [StringComparison]::OrdinalIgnoreCase) -and
      $_.CommandLine -notmatch '\s--type=' -and $_.CommandLine -notmatch 'app\.asar\\(?:main|cli)\\'
    })
}

function Stop-WorkBuddyForRestart {
  param([string]$Executable)
  $main = @(Get-MainWorkBuddyProcesses $Executable)
  foreach ($item in $main) {
    try { [void](Get-Process -Id $item.ProcessId -ErrorAction Stop).CloseMainWindow() } catch {}
  }
  $deadline = (Get-Date).AddSeconds(12)
  while (@(Get-MainWorkBuddyProcesses $Executable).Count -gt 0 -and (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 300
  }
  if (@(Get-MainWorkBuddyProcesses $Executable).Count -gt 0) {
    Get-CimInstance Win32_Process -Filter "Name='WorkBuddy.exe'" -ErrorAction SilentlyContinue |
      Where-Object { $_.ExecutablePath -and [IO.Path]::GetFullPath($_.ExecutablePath).Equals([IO.Path]::GetFullPath($Executable), [StringComparison]::OrdinalIgnoreCase) } |
      ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    $forceDeadline = (Get-Date).AddSeconds(8)
    while (@(Get-MainWorkBuddyProcesses $Executable).Count -gt 0 -and (Get-Date) -lt $forceDeadline) {
      Start-Sleep -Milliseconds 250
    }
  }
  if (@(Get-MainWorkBuddyProcesses $Executable).Count -gt 0) { throw 'WorkBuddy could not be stopped safely.' }
}

function Get-AvailableLoopbackPort {
  param([int]$PreferredPort = 0)
  if ($PreferredPort -ge 1024 -and $PreferredPort -le 65535) {
    $used = Get-NetTCPConnection -LocalPort $PreferredPort -State Listen -ErrorAction SilentlyContinue
    if (-not $used) { return $PreferredPort }
    throw "Port $PreferredPort is already in use. Omit -Port to select a dynamic port."
  }
  $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
  try {
    $listener.Start()
    return ([Net.IPEndPoint]$listener.LocalEndpoint).Port
  } finally {
    $listener.Stop()
  }
}

function Get-CdpTargets {
  param([int]$Port)
  try {
    return @(Invoke-RestMethod "http://127.0.0.1:$Port/json/list" -TimeoutSec 1)
  } catch {
    return @()
  }
}

function Test-WorkBuddyDebugPort {
  param([int]$Port)
  $targets = Get-CdpTargets $Port
  return [bool]($targets | Where-Object { $_.type -eq 'page' -and ($_.url -like 'vscode-file://*' -or $_.url -like 'file://*') })
}

function Assert-PortOwnedByWorkBuddy {
  param([int]$Port, [string]$Executable)
  $listeners = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
  if ($listeners.Count -eq 0) { throw "No listener exists on loopback port $Port." }
  $expected = [IO.Path]::GetFullPath($Executable)
  foreach ($listener in $listeners) {
    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$($listener.OwningProcess)" -ErrorAction SilentlyContinue
    if (-not $process -or -not $process.ExecutablePath) { throw "Could not identify the listener on port $Port." }
    $actual = [IO.Path]::GetFullPath($process.ExecutablePath)
    if (-not $actual.Equals($expected, [StringComparison]::OrdinalIgnoreCase)) {
      throw "Port $Port belongs to another executable: $actual"
    }
    if ($listener.LocalAddress -notin @('127.0.0.1', '::1')) {
      throw "Port $Port is listening outside the loopback interface: $($listener.LocalAddress)"
    }
  }
}

function Get-ActiveThemeDirectory {
  if (Test-Path -LiteralPath (Join-Path $script:ThemeRoot 'theme.json')) { return $script:ThemeRoot }
  return $null
}

function Write-JsonUtf8NoBom {
  param([string]$Path, [object]$Value)
  $json = $Value | ConvertTo-Json -Depth 10
  $encoding = New-Object Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($Path, $json, $encoding)
}

function Stop-RecordedInjector {
  if (-not (Test-Path -LiteralPath $script:StatePath)) { return }
  try {
    $state = Get-Content -LiteralPath $script:StatePath -Raw | ConvertFrom-Json
    if (-not $state.injectorPid) { return }
    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$state.injectorPid)" -ErrorAction SilentlyContinue
    if ($process -and $process.CommandLine -like "*$script:InjectorPath*") {
      Stop-Process -Id ([int]$state.injectorPid) -Force -ErrorAction SilentlyContinue
    }
  } catch {}
}

function Stop-RecordedTray {
  if (-not (Test-Path -LiteralPath $script:TrayStatePath)) { return }
  try {
    $state = Get-Content -LiteralPath $script:TrayStatePath -Raw | ConvertFrom-Json
    if (-not $state.trayPid) { return }
    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$state.trayPid)" -ErrorAction SilentlyContinue
    $trayRoot = if ($state.skinRoot) { [string]$state.skinRoot } else { $script:SkinRoot }
    $trayScript = Join-Path $trayRoot 'scripts\workbuddy-skin-tray.ps1'
    if ($process -and $process.CommandLine -like "*$trayScript*") {
      Stop-Process -Id ([int]$state.trayPid) -Force -ErrorAction SilentlyContinue
    }
  } catch {}
  Remove-Item -LiteralPath $script:TrayStatePath -Force -ErrorAction SilentlyContinue
}

function Test-RecordedTray {
  if (-not (Test-Path -LiteralPath $script:TrayStatePath)) { return $false }
  try {
    $state = Get-Content -LiteralPath $script:TrayStatePath -Raw | ConvertFrom-Json
    if (-not $state.trayPid) { return $false }
    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$state.trayPid)" -ErrorAction SilentlyContinue
    $trayRoot = if ($state.skinRoot) { [string]$state.skinRoot } else { $script:SkinRoot }
    $trayScript = Join-Path $trayRoot 'scripts\workbuddy-skin-tray.ps1'
    return [bool]($process -and $process.CommandLine -like "*$trayScript*")
  } catch {
    return $false
  }
}

function Start-WorkBuddyTray {
  if (Test-RecordedTray) {
    return [int](Get-Content -LiteralPath $script:TrayStatePath -Raw | ConvertFrom-Json).trayPid
  }
  Remove-Item -LiteralPath $script:TrayStatePath -Force -ErrorAction SilentlyContinue
  $trayScript = Join-Path $PSScriptRoot 'workbuddy-skin-tray.ps1'
  if (-not (Test-Path -LiteralPath $trayScript)) { throw "The tray controller was not found: $trayScript" }
  $powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
  $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$trayScript`"")
  $process = Start-Process -FilePath $powershell -ArgumentList ($arguments -join ' ') -WindowStyle Hidden -PassThru
  $deadline = (Get-Date).AddSeconds(8)
  while (-not (Test-RecordedTray) -and -not $process.HasExited -and (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 200
  }
  if (-not (Test-RecordedTray)) {
    if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue }
    throw 'The WorkBuddy Dream Skin tray controller did not start.'
  }
  return [int](Get-Content -LiteralPath $script:TrayStatePath -Raw | ConvertFrom-Json).trayPid
}
