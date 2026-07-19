[CmdletBinding()]
param(
  [switch]$Probe
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common-workbuddy.ps1')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$menuContract = @(
  'status', 'refresh', 'restart', 'themes', 'decoration', 'import-image',
  'open-theme-folder', 'restore', 'restore-restart', 'exit'
)
if ($Probe) {
  $themeIds = @()
  if (Test-Path -LiteralPath $script:ThemeLibraryRoot) {
    $themeIds = @(Get-ChildItem -LiteralPath $script:ThemeLibraryRoot -Directory | Where-Object { $_.Name -ne '_autosave-current' } | Select-Object -ExpandProperty Name)
  }
  [pscustomobject]@{
    pass = $true
    notifyIcon = [bool]('System.Windows.Forms.NotifyIcon' -as [type])
    menu = $menuContract
    themeCount = $themeIds.Count
    themeIds = $themeIds
  } | ConvertTo-Json -Depth 3
  exit 0
}

New-Item -ItemType Directory -Force -Path $script:StateRoot | Out-Null
$created = $false
$mutex = New-Object Threading.Mutex($true, 'Local\WorkBuddyDreamSkinTray', [ref]$created)
if (-not $created) {
  $mutex.Dispose()
  exit 0
}

$powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
$trayScriptPath = $MyInvocation.MyCommand.Path

function Get-UiText {
  param([string]$Base64)
  return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Base64))
}

function ConvertTo-CommandArgument {
  param([string]$Value)
  if ($null -eq $Value) { return '""' }
  return '"' + ($Value -replace '"', '\"') + '"'
}

function Start-SkinCommand {
  param([string]$ScriptPath, [string[]]$Arguments = @())
  $parts = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (ConvertTo-CommandArgument $ScriptPath))
  $parts += @($Arguments | ForEach-Object { ConvertTo-CommandArgument $_ })
  Start-Process -FilePath $powershell -ArgumentList ($parts -join ' ') -WindowStyle Hidden | Out-Null
}

function Test-ActiveSkinEndpoint {
  if (-not (Test-Path -LiteralPath $script:StatePath)) { return $false }
  try {
    $state = Get-Content -LiteralPath $script:StatePath -Raw | ConvertFrom-Json
    return [bool]($state.port -and (Test-WorkBuddyDebugPort ([int]$state.port)))
  } catch {
    return $false
  }
}

function Test-WorkBuddyIsRunning {
  try {
    $exe = Resolve-WorkBuddyExecutable
    return @(Get-MainWorkBuddyProcesses $exe).Count -gt 0
  } catch {
    return $false
  }
}

function Confirm-SkinRestart {
  $message = Get-UiText '5b2T5YmNIFdvcmtCdWRkeSDpnIDopoHph43mlrDlkK/liqjmiY3og73lkK/nlKjnmq7ogqTjgILor7flhYjkv53lrZjmraPlnKjov5vooYznmoTlt6XkvZzjgILmmK/lkKbnjrDlnKjph43lkK/vvJ8='
  return [Windows.Forms.MessageBox]::Show($message, 'WorkBuddy Dream Skin', 'OKCancel', 'Warning') -eq [Windows.Forms.DialogResult]::OK
}

function Invoke-SmartSkinStart {
  $startScript = Join-Path $PSScriptRoot 'start-workbuddy-skin.ps1'
  if (Test-ActiveSkinEndpoint) {
    Start-SkinCommand $startScript
    return
  }
  if (Test-WorkBuddyIsRunning) {
    if (Confirm-SkinRestart) { Start-SkinCommand $startScript @('-RestartExisting') }
    return
  }
  Start-SkinCommand $startScript
}

function Get-TrayStatusText {
  if (-not (Test-Path -LiteralPath $script:StatePath)) { return Get-UiText '54q25oCB77ya55qu6IKk5pyq5ZCv55So' }
  try {
    $state = Get-Content -LiteralPath $script:StatePath -Raw | ConvertFrom-Json
    if ($state.port -and (Test-WorkBuddyDebugPort ([int]$state.port))) {
      $themeName = Get-UiText '5b2T5YmN5Li76aKY'
      $themePath = Join-Path $script:ThemeRoot 'theme.json'
      if (Test-Path -LiteralPath $themePath) {
        try { $themeName = [string](Get-Content -LiteralPath $themePath -Raw -Encoding UTF8 | ConvertFrom-Json).name } catch {}
      }
      return ((Get-UiText '54q25oCB77ya5bey5ZCv55SoIMK3IHswfQ==') -f $themeName)
    }
  } catch {}
  return Get-UiText '54q25oCB77ya6ZyA6KaB5Yi35paw'
}

function Add-TrayItem {
  param([Windows.Forms.ToolStripItemCollection]$Items, [string]$Text, [scriptblock]$OnClick)
  $item = New-Object Windows.Forms.ToolStripMenuItem
  $item.Text = $Text
  if ($OnClick) { $item.Add_Click($OnClick) }
  [void]$Items.Add($item)
  return $item
}

$context = New-Object Windows.Forms.ApplicationContext
$menu = New-Object Windows.Forms.ContextMenuStrip
$statusItem = Add-TrayItem $menu.Items (Get-TrayStatusText) $null
$statusItem.Enabled = $false

[void](Add-TrayItem $menu.Items (Get-UiText '5ZCv55So5oiW5Yi35paw55qu6IKk') {
  Invoke-SmartSkinStart
})
[void](Add-TrayItem $menu.Items (Get-UiText '6YeN5ZCvIFdvcmtCdWRkeSDlubblkK/nlKg=') {
  $answer = [Windows.Forms.MessageBox]::Show((Get-UiText '6L+Z5Lya5YWz6Zet5bm26YeN5paw5ZCv5YqoIFdvcmtCdWRkeeOAguivt+WFiOS/neWtmOato+WcqOi/m+ihjOeahOW3peS9nOOAgg=='), 'WorkBuddy Dream Skin', 'OKCancel', 'Warning')
  if ($answer -eq [Windows.Forms.DialogResult]::OK) {
    Start-SkinCommand (Join-Path $PSScriptRoot 'start-workbuddy-skin.ps1') @('-RestartExisting')
  }
})

$themesItem = Add-TrayItem $menu.Items (Get-UiText '5YiH5o2i5Li76aKY') $null
$themesPlaceholder = New-Object Windows.Forms.ToolStripMenuItem
$themesPlaceholder.Text = Get-UiText '5rKh5pyJ5bey5L+d5a2Y5Li76aKY'
$themesPlaceholder.Enabled = $false
[void]$themesItem.DropDownItems.Add($themesPlaceholder)
$themesItem.DropDown.Add_Opening({
  $themesItem.DropDownItems.Clear()
  $activeTheme = $null
  $activeThemePath = Join-Path $script:ThemeRoot 'theme.json'
  if (Test-Path -LiteralPath $activeThemePath) {
    try { $activeTheme = Get-Content -LiteralPath $activeThemePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
  }
  $presets = @()
  if (Test-Path -LiteralPath $script:ThemeLibraryRoot) {
    $presets = @(Get-ChildItem -LiteralPath $script:ThemeLibraryRoot -Directory | Where-Object { $_.Name -ne '_autosave-current' })
  }
  if ($presets.Count -eq 0) {
    $empty = New-Object Windows.Forms.ToolStripMenuItem
    $empty.Text = Get-UiText '5rKh5pyJ5bey5L+d5a2Y5Li76aKY'
    $empty.Enabled = $false
    [void]$themesItem.DropDownItems.Add($empty)
    return
  }
  foreach ($preset in $presets) {
    $label = $preset.Name
    $configPath = Join-Path $preset.FullName 'theme.json'
    try {
      $theme = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($theme.name) { $label = [string]$theme.name }
    } catch {}
    $item = New-Object Windows.Forms.ToolStripMenuItem
    $item.Text = $label
    $item.Tag = $preset.Name
    $item.CheckOnClick = $false
    $activePresetId = if ($activeTheme -and $activeTheme.PSObject.Properties['presetId']) { [string]$activeTheme.presetId } else { '' }
    $activeName = if ($activeTheme -and $activeTheme.PSObject.Properties['name']) { [string]$activeTheme.name } else { '' }
    $item.Checked = [bool]($activeTheme -and (
      ($activePresetId -and $activePresetId -eq $preset.Name) -or
      (-not $activePresetId -and $activeName -eq $label)
    ))
    $item.Add_Click({
      param($sender, $eventArgs)
      foreach ($sibling in $sender.Owner.Items) {
        if ($sibling -is [Windows.Forms.ToolStripMenuItem]) { $sibling.Checked = $false }
      }
      $sender.Checked = $true
      $switchScript = Join-Path $PSScriptRoot 'switch-workbuddy-theme.ps1'
      $themeId = [string]$sender.Tag
      if (Test-ActiveSkinEndpoint) {
        Start-SkinCommand $switchScript @($themeId)
      } elseif (Test-WorkBuddyIsRunning) {
        if (Confirm-SkinRestart) {
          Start-SkinCommand $switchScript @($themeId, '-RestartExisting')
        } else {
          Start-SkinCommand $switchScript @($themeId, '-NoApply')
          $notifyIcon.ShowBalloonTip(2000, 'WorkBuddy Dream Skin', (Get-UiText '5Li76aKY5bey5L+d5a2Y77yM5bCG5Zyo5LiL5qyh5ZCv55So55qu6IKk5pe255Sf5pWI44CC'), [Windows.Forms.ToolTipIcon]::Info)
        }
      } else {
        Start-SkinCommand $switchScript @($themeId, '-RestartExisting')
      }
    })
    [void]$themesItem.DropDownItems.Add($item)
  }
})

$decorationItem = Add-TrayItem $menu.Items (Get-UiText '5oyC5Lu25pi+56S6') $null
foreach ($entry in @(
  @{ Text = (Get-UiText '6Ieq5Yqo'); Mode = 'Auto' },
  @{ Text = (Get-UiText '5aeL57uI5pi+56S6'); Mode = 'On' },
  @{ Text = (Get-UiText '5YWz6Zet'); Mode = 'Off' }
)) {
  $item = New-Object Windows.Forms.ToolStripMenuItem
  $item.Text = $entry.Text
  $item.Tag = $entry.Mode
  $item.CheckOnClick = $false
  $item.Add_Click({
    param($sender, $eventArgs)
    foreach ($sibling in $sender.Owner.Items) {
      if ($sibling -is [Windows.Forms.ToolStripMenuItem]) { $sibling.Checked = $false }
    }
    $sender.Checked = $true
    Start-SkinCommand (Join-Path $PSScriptRoot 'customize-workbuddy-theme.ps1') @('-DecorationMode', [string]$sender.Tag, '-Style', 'Current')
  })
  [void]$decorationItem.DropDownItems.Add($item)
}
$decorationItem.DropDown.Add_Opening({
  $activeMode = 'auto'
  $activeThemePath = Join-Path $script:ThemeRoot 'theme.json'
  if (Test-Path -LiteralPath $activeThemePath) {
    try {
      $activeTheme = Get-Content -LiteralPath $activeThemePath -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($activeTheme.decoration.mode -in @('auto', 'on', 'off')) { $activeMode = [string]$activeTheme.decoration.mode }
    } catch {}
  }
  foreach ($item in $decorationItem.DropDownItems) {
    if ($item -is [Windows.Forms.ToolStripMenuItem]) { $item.Checked = ([string]$item.Tag).ToLowerInvariant() -eq $activeMode }
  }
})

[void]$menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))
[void](Add-TrayItem $menu.Items (Get-UiText '5a+85YWl5oiW5pu05o2i5Zu+54mH') {
  Start-SkinCommand (Join-Path $PSScriptRoot 'customize-workbuddy-theme.ps1')
})
[void](Add-TrayItem $menu.Items (Get-UiText '5omT5byA5Li76aKY55uu5b2V') {
  New-Item -ItemType Directory -Force -Path $script:ThemeRoot | Out-Null
  Start-Process explorer.exe -ArgumentList (ConvertTo-CommandArgument $script:ThemeRoot) | Out-Null
})
[void](Add-TrayItem $menu.Items (Get-UiText '5oGi5aSN5a6Y5pa55aSW6KeC') {
  Start-SkinCommand (Join-Path $PSScriptRoot 'restore-workbuddy-skin.ps1')
})
[void](Add-TrayItem $menu.Items (Get-UiText '5oGi5aSN5bm25q2j5bi46YeN5ZCv') {
  $answer = [Windows.Forms.MessageBox]::Show((Get-UiText '6L+Z5Lya5oGi5aSN5a6Y5pa55aSW6KeC5bm26YeN5paw5ZCv5YqoIFdvcmtCdWRkeeOAguivt+WFiOS/neWtmOato+WcqOi/m+ihjOeahOW3peS9nOOAgg=='), 'WorkBuddy Dream Skin', 'OKCancel', 'Warning')
  if ($answer -eq [Windows.Forms.DialogResult]::OK) {
    Start-SkinCommand (Join-Path $PSScriptRoot 'restore-workbuddy-skin.ps1') @('-RestartNormally')
  }
})
[void]$menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))
[void](Add-TrayItem $menu.Items (Get-UiText '6YCA5Ye65omY55uY') { $context.ExitThread() })

$notifyIcon = New-Object Windows.Forms.NotifyIcon
try {
  $workBuddy = Resolve-WorkBuddyExecutable
  $notifyIcon.Icon = [Drawing.Icon]::ExtractAssociatedIcon($workBuddy)
} catch {
  $notifyIcon.Icon = [Drawing.SystemIcons]::Application
}
$notifyIcon.Text = 'WorkBuddy Dream Skin'
$notifyIcon.ContextMenuStrip = $menu
$notifyIcon.Visible = $true
$notifyIcon.Add_DoubleClick({ Start-SkinCommand (Join-Path $PSScriptRoot 'start-workbuddy-skin.ps1') })

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 2500
$timer.Add_Tick({ $statusItem.Text = Get-TrayStatusText })
$timer.Start()

Write-JsonUtf8NoBom $script:TrayStatePath ([ordered]@{
  schemaVersion = 1
  trayPid = $PID
  skinRoot = $script:SkinRoot
  startedAt = (Get-Date).ToString('o')
})

try {
  [Windows.Forms.Application]::Run($context)
} finally {
  $timer.Stop()
  $timer.Dispose()
  $notifyIcon.Visible = $false
  $notifyIcon.Dispose()
  $menu.Dispose()
  try {
    if (Test-Path -LiteralPath $script:TrayStatePath) {
      $state = Get-Content -LiteralPath $script:TrayStatePath -Raw | ConvertFrom-Json
      if ([int]$state.trayPid -eq $PID) { Remove-Item -LiteralPath $script:TrayStatePath -Force }
    }
  } catch {}
  $mutex.ReleaseMutex()
  $mutex.Dispose()
}
