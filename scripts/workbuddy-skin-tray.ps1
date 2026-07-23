[CmdletBinding()]
param(
  [switch]$Probe
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common-workbuddy.ps1')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$menuContract = @(
  'status', 'refresh', 'restart', 'themes', 'decoration', 'import-image',
  'save-preset', 'open-theme-folder', 'restore', 'restore-restart', 'exit'
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

function Show-SavePresetDialog {
  # Modern WPF dialog for naming a new preset. Fluent-styled: rounded corners,
  # accent-strip header, solid-accent primary button, ghost secondary button,
  # live validation with green/red inline feedback. Auto-adapts to Windows
  # apps light/dark mode via HKCU AppsUseLightTheme. Returns validated id or
  # $null (on cancel/close/invalid input).
  #
  # Icon is a Drawing.Icon (from the tray notify icon). WPF wants an
  # ImageSource, so we skip embedding it - WPF picks up the app default,
  # which for a PowerShell host looks clean enough.
  param([string]$DefaultName = '', [Drawing.Icon]$Icon = $null)

  # Detect Windows apps light/dark mode; default to light on failure.
  $isLight = $true
  try {
    $reg = Get-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -ErrorAction Stop
    $isLight = ($reg.AppsUseLightTheme -eq 1)
  } catch {}

  if ($isLight) {
    $c = @{
      BG          = '#F3F3F3'
      TEXT        = '#1B1B1B'
      MUTED       = '#606060'
      BORDER      = '#D1D1D1'
      INPUT_BG    = '#FFFFFF'
      ACCENT      = '#0067C0'
      ACCENT_FG   = '#FFFFFF'
      ACCENT_HOV  = '#005AA5'
      HOVER_BG    = '#E9E9E9'
      DISABLED    = '#B0B0B0'
      SUCCESS     = '#107C10'
      ERROR       = '#C42B1C'
    }
  } else {
    $c = @{
      BG          = '#202020'
      TEXT        = '#F5F5F5'
      MUTED       = '#A6A6A6'
      BORDER      = '#3D3D3D'
      INPUT_BG    = '#2B2B2B'
      ACCENT      = '#4CC2FF'
      ACCENT_FG   = '#000000'
      ACCENT_HOV  = '#62CCFF'
      HOVER_BG    = '#2E2E2E'
      DISABLED    = '#4A4A4A'
      SUCCESS     = '#6CCB5F'
      ERROR       = '#FF99A4'
    }
  }

  $c['TITLE']      = Get-UiText 'V29ya0J1ZGR5IERyZWFtIFNraW4g4oCUIOS/neWtmOS4uumihOiuvg=='
  $c['HEADER']     = Get-UiText '5Y+m5a2Y5Li66aKE6K6+'
  $c['PROMPT']     = Get-UiText '5Li66L+Z5aWX6Ieq5a6a5LmJ5Li76aKY6LW35LiqIGlk'
  $c['RULES']      = Get-UiText '6KeE5YiZ77yaYS16IC8gMC05IC8g6L+e5a2X56ym77yM6ZW/5bqmIDMtNDDvvIzpppblsL7lv4XpobvmmK/lrZfmr43miJbmlbDlrZc='
  $c['BTN_SAVE']   = Get-UiText '5L+d5a2Y'
  $c['BTN_CANCEL'] = Get-UiText '5Y+W5raI'
  $c['DEFAULT']    = [System.Security.SecurityElement]::Escape($DefaultName)

  $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="__TITLE__"
        Width="560" Height="340"
        WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize"
        ShowInTaskbar="False"
        Background="__BG__"
        FontFamily="Segoe UI">
  <Window.Resources>
    <Style x:Key="PrimaryButton" TargetType="Button">
      <Setter Property="Background" Value="__ACCENT__"/>
      <Setter Property="Foreground" Value="__ACCENT_FG__"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="MinWidth" Value="100"/>
      <Setter Property="Padding" Value="20,10"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" Background="{TemplateBinding Background}" CornerRadius="5">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="Background" Value="__ACCENT_HOV__"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="B" Property="Background" Value="__DISABLED__"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="GhostButton" TargetType="Button">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Foreground" Value="__TEXT__"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="MinWidth" Value="92"/>
      <Setter Property="Padding" Value="20,10"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" Background="{TemplateBinding Background}" BorderBrush="__BORDER__" BorderThickness="1" CornerRadius="5">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="Background" Value="__HOVER_BG__"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="4"/>
      <RowDefinition Height="*"/>
    </Grid.RowDefinitions>
    <Rectangle Grid.Row="0" Fill="__ACCENT__"/>

    <Grid Grid.Row="1" Margin="30,24,30,24">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <TextBlock Grid.Row="0" Text="__HEADER__" FontSize="17" FontWeight="SemiBold" Foreground="__TEXT__"/>
      <TextBlock Grid.Row="1" Text="__PROMPT__" Margin="0,6,0,0" FontSize="11" Foreground="__MUTED__"/>

      <Border x:Name="InputBorder" Grid.Row="2" Margin="0,18,0,0"
              Background="__INPUT_BG__" BorderBrush="__BORDER__" BorderThickness="1"
              CornerRadius="5" Padding="14,10">
        <TextBox x:Name="TxtName" MaxLength="40" FontFamily="Consolas" FontSize="14"
                 BorderThickness="0" Background="Transparent" Foreground="__TEXT__"
                 CaretBrush="__ACCENT__"/>
      </Border>

      <TextBlock Grid.Row="3" x:Name="LblValid" Margin="2,10,0,0" FontSize="11"/>

      <TextBlock Grid.Row="4" Text="__RULES__" Margin="2,14,0,0" FontSize="10.5"
                 Foreground="__MUTED__" TextWrapping="Wrap"/>

      <StackPanel Grid.Row="6" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
        <Button x:Name="BtnCancel" Content="__BTN_CANCEL__" Style="{StaticResource GhostButton}" IsCancel="True"/>
        <Button x:Name="BtnSave" Content="__BTN_SAVE__" Style="{StaticResource PrimaryButton}" Margin="12,0,0,0" IsDefault="True"/>
      </StackPanel>
    </Grid>
  </Grid>
</Window>
'@

  foreach ($k in $c.Keys) { $xaml = $xaml.Replace("__${k}__", $c[$k]) }

  $window = [Windows.Markup.XamlReader]::Parse($xaml)
  $txt      = $window.FindName('TxtName')
  $lblValid = $window.FindName('LblValid')
  $btnSave  = $window.FindName('BtnSave')
  $btnCancel = $window.FindName('BtnCancel')
  $input    = $window.FindName('InputBorder')

  $txt.Text = $DefaultName

  $borderNormal = [Windows.Media.BrushConverter]::new().ConvertFromString($c['BORDER'])
  $borderFocus  = [Windows.Media.BrushConverter]::new().ConvertFromString($c['ACCENT'])
  $colorSuccess = [Windows.Media.BrushConverter]::new().ConvertFromString($c['SUCCESS'])
  $colorError   = [Windows.Media.BrushConverter]::new().ConvertFromString($c['ERROR'])

  $script:dialogResult = $null

  $validate = {
    $n = $txt.Text.Trim().ToLowerInvariant()
    $ok = $false
    if ($n.Length -lt 3) {
      $msg = Get-UiText '4pyXIOiHs+WwkeimgSAzIOS4quWtl+espg=='
    } elseif ($n.Length -gt 40) {
      $msg = Get-UiText '4pyXIOacgOWkmiA0MCDkuKrlrZfnrKY='
    } elseif ($n -eq '_autosave-current') {
      $msg = Get-UiText '4pyXICJfYXV0b3NhdmUtY3VycmVudCIg5piv5L+d55WZ5ZCN'
    } elseif ($n -notmatch '^[a-z0-9-]+$') {
      $msg = Get-UiText '4pyXIOWPquWFgeiuuCBhLXrjgIEwLTnjgIHov57lrZfnrKY='
    } elseif ($n -match '^-|-$') {
      $msg = Get-UiText '4pyXIOmmluWwvuW/hemhu+aYr+Wtl+avjeaIluaVsOWtl++8jOS4jeiDveaYr+i/nuWtl+espg=='
    } else {
      $ok = $true
      $msg = Get-UiText '4pyTIOi/meS4quWQjeWtl+WPr+S7peeUqA=='
    }
    $lblValid.Text = $msg
    $lblValid.Foreground = if ($ok) { $colorSuccess } else { $colorError }
    $btnSave.IsEnabled = $ok
  }
  $txt.Add_TextChanged($validate)
  & $validate

  # Focus ring on input
  $txt.Add_GotFocus({ $input.BorderBrush = $borderFocus; $input.BorderThickness = New-Object Windows.Thickness 2 })
  $txt.Add_LostFocus({ $input.BorderBrush = $borderNormal; $input.BorderThickness = New-Object Windows.Thickness 1 })

  $btnSave.Add_Click({
    $script:dialogResult = $txt.Text.Trim().ToLowerInvariant()
    $window.Close()
  })
  $btnCancel.Add_Click({
    $script:dialogResult = $null
    $window.Close()
  })

  $window.Add_Loaded({ $txt.Focus(); $txt.SelectAll() })
  [void]$window.ShowDialog()
  return $script:dialogResult
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
[void](Add-TrayItem $menu.Items (Get-UiText '5L+d5a2Y5b2T5YmN5Li76aKY5Li66aKE6K6+Li4u') {
  # Save the currently applied theme (in $ThemeRoot) as a named preset in
  # $ThemeLibraryRoot so it survives the next theme switch.
  $activeThemePath = Join-Path $script:ThemeRoot 'theme.json'
  if (-not (Test-Path -LiteralPath $activeThemePath)) {
    [void][Windows.Forms.MessageBox]::Show(
      (Get-UiText '5b2T5YmN5rKh5pyJ55Sf5pWI55qE5Li76aKY77yM6K+35YWI5YiH5o2i5oiW5a+85YWl5Zu+54mH5YaN5L+d5a2Y44CC'),
      'WorkBuddy Dream Skin', 'OK', 'Information')
    return
  }
  $default = ('my-theme-{0:yyyyMMdd-HHmm}' -f (Get-Date))
  $name = Show-SavePresetDialog -DefaultName $default -Icon $notifyIcon.Icon
  if (-not $name) { return }
  try {
    New-Item -ItemType Directory -Force -Path $script:ThemeLibraryRoot | Out-Null
    $targetPreset = Join-Path $script:ThemeLibraryRoot $name
    if (Test-Path -LiteralPath $targetPreset) {
      $confirm = [Windows.Forms.MessageBox]::Show(
        ((Get-UiText 'aWQgInswfSIg5bey5a2Y5Zyo77yM6KaG55uW5ZCX77yf') -f $name),
        'WorkBuddy Dream Skin', 'YesNo', 'Question')
      if ($confirm -ne [Windows.Forms.DialogResult]::Yes) { return }
      Remove-Item -LiteralPath $targetPreset -Recurse -Force
    }
    Copy-Item -LiteralPath $script:ThemeRoot -Destination $targetPreset -Recurse -Force
    # Stamp presetId so the tray's active-preset checkmark matches the new dir.
    $savedThemePath = Join-Path $targetPreset 'theme.json'
    $savedTheme = Get-Content -LiteralPath $savedThemePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $savedTheme | Add-Member -NotePropertyName presetId -NotePropertyValue $name -Force
    Write-JsonUtf8NoBom $savedThemePath $savedTheme
    # Mirror the presetId back into the currently applied theme.json too so
    # the running skin knows it's now "the saved preset", not a floating temp.
    $activeTheme = Get-Content -LiteralPath $activeThemePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $activeTheme | Add-Member -NotePropertyName presetId -NotePropertyValue $name -Force
    Write-JsonUtf8NoBom $activeThemePath $activeTheme
    $notifyIcon.ShowBalloonTip(2500, 'WorkBuddy Dream Skin',
      ((Get-UiText '5bey5L+d5a2Y5Yiw5Li76aKY5bqT77yaezB9') -f $name),
      [Windows.Forms.ToolTipIcon]::Info)
  } catch {
    [void][Windows.Forms.MessageBox]::Show(
      ((Get-UiText '5L+d5a2Y5aSx6LSl77yaezB9') -f $_.Exception.Message),
      'WorkBuddy Dream Skin', 'OK', 'Error')
  }
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
