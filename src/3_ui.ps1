
# Rend les fonctions utilitaires (Format-Size, Write-Bug...) disponibles aussi pour l'interface
Set-SplashStep 58 'Chargement des outils…'
. $TaskLibrary
Set-SplashStep 66 'Création de l''interface…'

# =====================================================================
#  Interface (WPF)
# =====================================================================
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="AEROX PC Care" Width="1120" Height="780" MinWidth="960" MinHeight="660"
        WindowStartupLocation="CenterScreen" Background="#0E1016" FontFamily="Segoe UI" Foreground="#E6E9F2">
  <Window.Resources>
    <Style x:Key="ActionBtn" TargetType="Button">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="Background" Value="#2A2F3D"/>
      <Setter Property="Padding" Value="18,9"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Opacity" Value="0.85"/></Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="bd" Property="Opacity" Value="0.7"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="bd" Property="Opacity" Value="0.35"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="PrimaryBtn" TargetType="Button" BasedOn="{StaticResource ActionBtn}"><Setter Property="Background" Value="#7C5CFF"/></Style>
    <Style x:Key="FixBtn" TargetType="Button" BasedOn="{StaticResource ActionBtn}"><Setter Property="Background" Value="#4ADE80"/><Setter Property="Foreground" Value="#0B1A11"/></Style>
    <Style x:Key="GhostBtn" TargetType="Button" BasedOn="{StaticResource ActionBtn}">
      <Setter Property="Background" Value="#1A1E2A"/><Setter Property="Padding" Value="12,5"/><Setter Property="FontSize" Value="12"/><Setter Property="FontWeight" Value="Normal"/>
    </Style>
    <Style x:Key="TextBtn" TargetType="Button" BasedOn="{StaticResource ActionBtn}">
      <Setter Property="Background" Value="Transparent"/><Setter Property="Foreground" Value="#A9B0C2"/><Setter Property="Padding" Value="10,9"/><Setter Property="FontWeight" Value="Normal"/>
    </Style>
    <Style x:Key="PlainBtn" TargetType="Button">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="Transparent"><ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center"/></Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="NavBtn" TargetType="RadioButton">
      <Setter Property="Foreground" Value="#A9B0C2"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Margin" Value="0,2"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RadioButton">
            <Border x:Name="bd" Background="Transparent" CornerRadius="8" Padding="12,10">
              <ContentPresenter VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="#1C2030"/></Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#262B3D"/>
                <Setter Property="Foreground" Value="White"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Grid>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="240"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <Border Grid.Column="0" Background="#141720" BorderBrush="#1F2330" BorderThickness="0,0,1,0">
      <DockPanel Margin="16,22,16,18">
        <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Margin="8,0,0,28">
          <Border Width="40" Height="40" CornerRadius="10" Background="#7C5CFF">
            <TextBlock Text="A" FontSize="21" FontWeight="Bold" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <StackPanel Margin="12,0,0,0" VerticalAlignment="Center">
            <TextBlock Text="AEROX" FontSize="18" FontWeight="Bold" Foreground="White"/>
            <TextBlock Text="PC Care" FontSize="12" Foreground="#8B93A7"/>
          </StackPanel>
        </StackPanel>
        <TextBlock x:Name="VersionText" DockPanel.Dock="Bottom" FontSize="11" Foreground="#6E768B" Margin="8,0,0,0"/>
        <StackPanel>
          <RadioButton x:Name="NavHome" Style="{StaticResource NavBtn}" GroupName="nav">
            <StackPanel Orientation="Horizontal"><TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE80F;" Width="28" VerticalAlignment="Center"/><TextBlock Text="Accueil"/></StackPanel>
          </RadioButton>
          <RadioButton x:Name="NavDiag" Style="{StaticResource NavBtn}" GroupName="nav">
            <DockPanel Width="180">
              <Border x:Name="DiagBadge" DockPanel.Dock="Right" Background="#FF6B6B" CornerRadius="9" Padding="6,0" MinWidth="18" Visibility="Collapsed" VerticalAlignment="Center">
                <TextBlock x:Name="DiagBadgeText" FontSize="11" FontWeight="Bold" Foreground="White" HorizontalAlignment="Center"/>
              </Border>
              <StackPanel Orientation="Horizontal"><TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE721;" Width="28" VerticalAlignment="Center"/><TextBlock Text="Diagnostic"/></StackPanel>
            </DockPanel>
          </RadioButton>
          <RadioButton x:Name="NavClean" Style="{StaticResource NavBtn}" GroupName="nav">
            <StackPanel Orientation="Horizontal"><TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE74D;" Width="28" VerticalAlignment="Center"/><TextBlock Text="Nettoyage"/></StackPanel>
          </RadioButton>
          <RadioButton x:Name="NavUpdate" Style="{StaticResource NavBtn}" GroupName="nav">
            <StackPanel Orientation="Horizontal"><TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE895;" Width="28" VerticalAlignment="Center"/><TextBlock Text="Mises à jour"/></StackPanel>
          </RadioButton>
          <RadioButton x:Name="NavRepair" Style="{StaticResource NavBtn}" GroupName="nav">
            <StackPanel Orientation="Horizontal"><TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE90F;" Width="28" VerticalAlignment="Center"/><TextBlock Text="Réparation"/></StackPanel>
          </RadioButton>
          <RadioButton x:Name="NavPerf" Style="{StaticResource NavBtn}" GroupName="nav">
            <StackPanel Orientation="Horizontal"><TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE945;" Width="28" VerticalAlignment="Center"/><TextBlock Text="Performances"/></StackPanel>
          </RadioButton>
          <RadioButton x:Name="NavMonitor" Style="{StaticResource NavBtn}" GroupName="nav">
            <StackPanel Orientation="Horizontal"><TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE9D9;" Width="28" VerticalAlignment="Center"/><TextBlock Text="Gaming"/></StackPanel>
          </RadioButton>
          <RadioButton x:Name="NavSystem" Style="{StaticResource NavBtn}" GroupName="nav">
            <StackPanel Orientation="Horizontal"><TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE7F4;" Width="28" VerticalAlignment="Center"/><TextBlock Text="Mon PC (BIOS)"/></StackPanel>
          </RadioButton>
          <RadioButton x:Name="NavHelp" Style="{StaticResource NavBtn}" GroupName="nav">
            <StackPanel Orientation="Horizontal"><TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE897;" Width="28" VerticalAlignment="Center"/><TextBlock Text="Aide"/></StackPanel>
          </RadioButton>
        </StackPanel>
      </DockPanel>
    </Border>

    <Grid Grid.Column="1">
      <Grid.RowDefinitions>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <ScrollViewer x:Name="Scroll" Grid.Row="0" VerticalScrollBarVisibility="Auto">
        <StackPanel x:Name="PageHost" Margin="32,28,32,20"/>
      </ScrollViewer>

      <Border Grid.Row="1" x:Name="BusyPanel" Background="#171A23" Padding="32,12" Visibility="Collapsed">
        <StackPanel>
          <DockPanel>
            <Button x:Name="CancelBtn" DockPanel.Dock="Right" Content="Annuler" Style="{StaticResource TextBtn}" Margin="14,0,0,0" VerticalAlignment="Center"/>
            <TextBlock x:Name="ElapsedText" DockPanel.Dock="Right" Foreground="#8B93A7" FontSize="12" VerticalAlignment="Center"/>
            <TextBlock x:Name="StatusText" Foreground="White" FontWeight="SemiBold" FontSize="13"/>
          </DockPanel>
          <ProgressBar x:Name="Progress" Height="6" Margin="0,8,0,0" IsIndeterminate="True" Maximum="100" Foreground="#7C5CFF" Background="#252A3A" BorderThickness="0"/>
        </StackPanel>
      </Border>

      <Border Grid.Row="2" Background="#0A0C11" BorderBrush="#1F2330" BorderThickness="0,1,0,0">
        <DockPanel>
          <DockPanel DockPanel.Dock="Top" Margin="24,7,20,7">
            <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
              <Button x:Name="BtnReport" Content="Signaler un bug" Style="{StaticResource GhostBtn}"/>
              <Button x:Name="BtnCopyLog" Content="Copier" Style="{StaticResource GhostBtn}" Margin="8,0,0,0"/>
              <Button x:Name="BtnOpenLogs" Content="Dossier des journaux" Style="{StaticResource GhostBtn}" Margin="8,0,0,0"/>
            </StackPanel>
            <Button x:Name="LogToggle" Style="{StaticResource PlainBtn}" HorizontalContentAlignment="Left" Margin="0,0,16,0">
              <DockPanel>
                <TextBlock x:Name="LogChevron" FontFamily="Segoe MDL2 Assets" Text="&#xE70E;" FontSize="11" Foreground="#8B93A7" VerticalAlignment="Center" Margin="0,0,10,0"/>
                <TextBlock Text="JOURNAL" FontSize="11" FontWeight="Bold" Foreground="#6E768B" VerticalAlignment="Center"/>
                <Ellipse x:Name="LogDot" Width="7" Height="7" Fill="#7C5CFF" Margin="10,0,0,0" VerticalAlignment="Center" Visibility="Collapsed"/>
                <TextBlock x:Name="LogLast" Margin="12,0,0,0" FontFamily="Cascadia Mono, Consolas" FontSize="12" Foreground="#8B93A7" TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/>
              </DockPanel>
            </Button>
          </DockPanel>
          <TextBox x:Name="LogBox" Height="170" Visibility="Collapsed" IsReadOnly="True" Background="Transparent" Foreground="#C3CAD9" BorderThickness="0"
                   FontFamily="Cascadia Mono, Consolas" FontSize="12" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Padding="28,0,24,10"/>
        </DockPanel>
      </Border>
    </Grid>
  </Grid>
</Window>
'@

$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
Set-SplashStep 78 'Création de l''interface…'
foreach ($n in 'Scroll','PageHost','BusyPanel','StatusText','ElapsedText','CancelBtn','Progress','LogBox','LogToggle','LogChevron','LogDot','LogLast','BtnReport','BtnCopyLog','BtnOpenLogs',
               'VersionText','DiagBadge','DiagBadgeText','NavHome','NavDiag','NavClean','NavUpdate','NavRepair','NavPerf','NavMonitor','NavSystem','NavHelp') {
    Set-Variable -Name $n -Value $window.FindName($n) -Scope Script
}
$VersionText.Text = "Version $AppVersion" + $(if ($Portable) { "  ·  portable" } else { '' })
# Canal test (réservé au développeur) : 7 clics rapides sur le numéro de version
$script:VerClicks = @()
$VersionText.Add_MouseLeftButtonUp({
    $now = Get-Date
    $script:VerClicks = @(@($script:VerClicks) + $now | Where-Object { ($now - $_).TotalSeconds -lt 4 })
    if ($script:VerClicks.Count -lt 7) { return }
    $script:VerClicks = @()
    $on = -not [bool]$script:Settings.BetaChannel
    $script:Settings.BetaChannel = $on; Save-Settings; Update-VersionText
    [System.Windows.MessageBox]::Show($(if ($on) { "Canal test activé.`n`nCe PC reçoit les versions de test avant tout le monde, pour les vérifier avant leur publication." } else { "Canal test désactivé : ce PC reçoit uniquement les versions publiques." }), $AppName, 'OK', 'Information') | Out-Null
    if ($GitHubRepo) { $sync.UpdateInfo = $null; $script:UpdateShown = $false; Start-Background 'Find-AppUpdate' }
})
$NavMap = @{ home = $NavHome; diag = $NavDiag; clean = $NavClean; update = $NavUpdate; repair = $NavRepair; perf = $NavPerf; monitor = $NavMonitor; system = $NavSystem; help = $NavHelp }

# ---------------------------------------------------------------- État de l'interface
$script:BC          = New-Object System.Windows.Media.BrushConverter
$script:PageButtons = New-Object System.Collections.ArrayList
$script:Job         = $null
$script:Cur         = 'home'
$script:Diag        = $null
$script:Scanning    = $false
$script:LastScanVer = -1
$script:OpenSteps   = @{}
$script:FixingIssue = $null
$script:FixQueue    = New-Object System.Collections.Queue
$script:QueueRunning  = $false
$script:PendingErrors = New-Object System.Collections.ArrayList
$script:Stats       = @{}
$script:LogOpen     = $false
$script:UpdateShown = $false
$script:ManualUpdateCheck = $false

# ---------------------------------------------------------------- Réglages (mémorisés dans reglages.json)
$script:OverlayMetrics = [ordered]@{
    fps = 'FPS'; low = '1 % low'; frametime = "Temps d'image"
    cpu = 'CPU : utilisation'; cputemp = 'CPU : température'; cpupower = 'CPU : consommation'
    gpu = 'GPU : utilisation'; gputemp = 'GPU : température'; gpupower = 'GPU : consommation'
    vram = 'VRAM'; ram = 'RAM'; clock = 'Heure'
}
$script:Settings = @{
    LogOpen = $false
    IgnoredApps = @()
    IgnoredIssues = @()
    StartupKept = @()
    StartupOff = @()
    StabilityFixAt = @{}
    SpeedHistory = @()
    BetaChannel = $false
    StatsOff = $false
    PostOptimize = $false
    InstallId = ''; Launches = 0; ReviewSent = $false; ReviewNever = $false; ReviewSnooze = ''; ReviewNote = 0; ReviewText = ''; ReviewPseudo = ''; LastSeenVersion = ''
    Overlay = @{ Visible = $false; X = 30; Y = 30; Scale = 1.0; Opacity = 0.6; Metrics = @('fps', 'low', 'cpu', 'cputemp', 'gpu', 'gputemp'); AlertOn = $true; AlertCpu = 90; AlertGpu = 85 }
    Gaming = @{ Track = $true; Tray = $false; TrayTip = $false; Ignore = @() }
}
function ConvertTo-Hash($o) {
    if ($null -eq $o) { return $null }
    if ($o -is [System.Management.Automation.PSCustomObject]) { $h = @{}; foreach ($p in $o.PSObject.Properties) { $h[$p.Name] = ConvertTo-Hash $p.Value }; return $h }
    if ($o -is [System.Collections.IEnumerable] -and $o -isnot [string]) { return ,@($o | ForEach-Object { ConvertTo-Hash $_ }) }
    return $o
}
function Load-Settings {
    try {
        if (Test-Path -LiteralPath $SettingsFile) {
            $h = ConvertTo-Hash (Get-Content -LiteralPath $SettingsFile -Raw -Encoding UTF8 | ConvertFrom-Json)
            foreach ($k in 'LogOpen', 'IgnoredApps', 'IgnoredIssues', 'StartupKept', 'StartupOff', 'SpeedHistory', 'BetaChannel', 'StatsOff', 'PostOptimize', 'InstallId', 'Launches', 'ReviewSent', 'ReviewNever', 'ReviewSnooze', 'ReviewNote', 'ReviewText', 'ReviewPseudo', 'LastSeenVersion') { if ($h.ContainsKey($k)) { $script:Settings[$k] = $h[$k] } }
            if ($h.Overlay -is [hashtable]) { foreach ($k in @($h.Overlay.Keys)) { $script:Settings.Overlay[$k] = $h.Overlay[$k] } }
            if ($h.Gaming -is [hashtable]) { foreach ($k in @($h.Gaming.Keys)) { $script:Settings.Gaming[$k] = $h.Gaming[$k] } }
            if ($h.StabilityFixAt -is [hashtable]) { $script:Settings.StabilityFixAt = $h.StabilityFixAt }
        } elseif (Test-Path -LiteralPath $OldSettings) {
            $script:Settings.LogOpen = ((Get-Content -LiteralPath $OldSettings -ErrorAction Stop) -match 'journal=ouvert')
        }
    } catch { Write-Bug -Context 'Lecture des réglages' -ErrorRecord $_ }
    $script:Settings.IgnoredApps = @($script:Settings.IgnoredApps | Where-Object { $_ })
    $script:Settings.StartupKept = @($script:Settings.StartupKept | Where-Object { $_ })
    $script:Settings.StartupOff = @($script:Settings.StartupOff | Where-Object { $_ })
    $script:Settings.IgnoredIssues = @($script:Settings.IgnoredIssues | Where-Object { $_ -is [hashtable] -and $_.Id })
    $script:Settings.SpeedHistory = @($script:Settings.SpeedHistory | Where-Object { $_ -is [hashtable] })
    $script:Settings.Overlay.Metrics = @($script:Settings.Overlay.Metrics | Where-Object { $_ })
    $script:Settings.Gaming.Ignore = @($script:Settings.Gaming.Ignore | Where-Object { $_ })
    $AppInfo.IgnoredApps = @($script:Settings.IgnoredApps)
    $AppInfo.IgnoredIssues = @($script:Settings.IgnoredIssues | ForEach-Object { [string]$_.Id })
    $AppInfo.StartupKept = @($script:Settings.StartupKept)
    $AppInfo.StartupOff = @($script:Settings.StartupOff)
    $AppInfo.StabilityFixAt = $script:Settings.StabilityFixAt
    $AppInfo.Beta = [bool]$script:Settings.BetaChannel
    $AppInfo.StatsOff = [bool]$script:Settings.StatsOff
    $AppInfo.StatsQueue = Read-StatsQueue
    Update-VersionText
}
function Update-VersionText { $VersionText.Text = "Version $AppVersion" + $(if ($Portable) { "  ·  portable" } else { '' }) + $(if ($script:Settings.BetaChannel) { "  ·  canal test" } else { '' }) }
function Save-Settings {
    $AppInfo.Beta = [bool]$script:Settings.BetaChannel
    $AppInfo.StatsOff = [bool]$script:Settings.StatsOff
    $AppInfo.IgnoredApps = @($script:Settings.IgnoredApps)
    $AppInfo.IgnoredIssues = @($script:Settings.IgnoredIssues | ForEach-Object { [string]$_.Id })
    $AppInfo.StartupKept = @($script:Settings.StartupKept)
    $script:Settings.StartupOff = @($AppInfo.StartupOff | Where-Object { $_ })
    $AppInfo.StabilityFixAt = $script:Settings.StabilityFixAt
    try { $script:Settings | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $SettingsFile -Encoding UTF8 } catch {}
}

# ---------------------------------------------------------------- Fabrique d'éléments
function Brush([string]$Hex) { $script:BC.ConvertFromString($Hex) }
function Th([double]$l, [double]$t, [double]$r, [double]$b) { New-Object System.Windows.Thickness($l, $t, $r, $b) }
function Corner([double]$r) { New-Object System.Windows.CornerRadius($r) }

function New-Text {
    param([string]$Text, [double]$Size = 13, [string]$Color = '#A9B0C2', [string]$Weight = 'Normal')
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Text; $t.FontSize = $Size; $t.Foreground = Brush $Color
    $t.FontWeight = [System.Windows.FontWeights]::$Weight
    $t.TextWrapping = [System.Windows.TextWrapping]::Wrap
    return $t
}
# Ligne « Libellé : texte » (+ code en police fixe)
function New-Rich([string]$Label, [string]$Text, [string]$Code) {
    $t = New-Object System.Windows.Controls.TextBlock
    $t.TextWrapping = 'Wrap'; $t.FontSize = 13; $t.Foreground = Brush '#8B93A7'; $t.Margin = Th 0 3 0 0
    if ($Label) { $r = New-Object System.Windows.Documents.Run("$Label : "); $r.FontWeight = 'SemiBold'; $r.Foreground = Brush '#C3CAD9'; $t.Inlines.Add($r) }
    if ($Text)  { $t.Inlines.Add((New-Object System.Windows.Documents.Run($Text))) }
    if ($Code)  { $c = New-Object System.Windows.Documents.Run(" $Code "); $c.FontFamily = 'Cascadia Mono, Consolas'; $c.FontSize = 12; $c.Background = Brush '#10131A'; $c.Foreground = Brush '#C3CAD9'; $t.Inlines.Add($c) }
    return $t
}
function New-Pill([string]$Text, [string]$Fg, [string]$Bg) {
    $b = New-Object System.Windows.Controls.Border
    $b.Background = Brush $Bg; $b.CornerRadius = Corner 6; $b.Padding = Th 8 2 8 2; $b.Margin = Th 8 0 0 0; $b.VerticalAlignment = 'Center'
    $b.Child = New-Text $Text.ToUpper() 10.5 $Fg 'Bold'
    return $b
}
function New-Button([string]$Text, [string]$Style, $Tag, [bool]$Busy = $true) {
    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = $Text; $btn.Style = $window.FindResource($Style); $btn.Tag = $Tag; $btn.VerticalAlignment = 'Center'
    $btn.Add_Click({ Invoke-UiCommand $this.Tag })
    if ($Busy) { $Tag.Busy = $true; $btn.IsEnabled = -not [bool]$script:Job; [void]$script:PageButtons.Add($btn) }
    return $btn
}
function New-CardBorder([string]$BorderColor = '#232838') {
    $card = New-Object System.Windows.Controls.Border
    $card.Background = Brush '#171A23'; $card.BorderBrush = Brush $BorderColor; $card.BorderThickness = Th 1 1 1 1
    $card.CornerRadius = Corner 12; $card.Padding = Th 20 16 20 16; $card.Margin = Th 0 0 0 12
    return $card
}
function New-Section([string]$Text) { $t = New-Text $Text.ToUpper() 11.5 '#7A8399' 'Bold'; $t.Margin = Th 0 18 0 10; return $t }
function Add-Child($Parent, $Child) { [void]$Parent.Children.Add($Child) }

# Icône de chaque carte (police d'icônes de Windows, rien à télécharger)
$script:CardIcons = @{
    deepclean = 'E74D'; space = 'EDA2'; dupes = 'E8C8'; 'Clear-TempFiles' = 'E7C3'; 'Clear-RecycleBinAll' = 'E74D'; 'Enable-StorageSense' = 'E916'; 'Disable-StorageSense' = 'E916'
    appupdates = 'E896'; 'Update-Apps' = 'E895'; 'Update-Windows' = 'E777'; drivers = 'E713'; 'Open-WindowsUpdate' = 'E8A7'
    speedtest = 'EC4A'; 'Repair-Sound' = 'E767'; 'Repair-Microphone' = 'E720'; 'Repair-Webcam' = 'E714'; 'Repair-Printing' = 'E749'; 'Restart-Shell' = 'E72C'
    browser = 'EA18'; 'Test-Internet' = 'E701'; 'Repair-Network' = 'E774'; 'Repair-System' = 'E90F'; 'Test-Disk' = 'EDA2'; 'Reset-WindowsUpdate' = 'E895'; 'New-RestorePoint' = 'E81C'
    slow = 'E9D9'; lag = 'E839'; share = 'E72D'; discord = 'E8F2'; 'stats-toggle' = 'E9D2'; bgitems = 'E71D'; startup = 'E7E8'; 'Set-HighPerformance' = 'E945'; 'Set-BalancedPower' = 'E945'; 'Open-VisualEffects' = 'E790'; uninstall = 'E74D'
    remotehelp = 'E7F4'; whatsnew = 'E946'; review = 'E734'; report = 'EBE8'; history = 'E81C'; checkupdate = 'E896'; logs = 'E8B7'
    optimize = 'E945'; diag = 'E9D9'; 'Start-QuickOptimize' = 'EC4A'
}
function New-CardIcon([string]$Hex, [bool]$Primary) {
    $b = New-Object System.Windows.Controls.Border; $b.Width = 42; $b.Height = 42; $b.CornerRadius = Corner 11; $b.Margin = Th 0 0 16 0; $b.VerticalAlignment = 'Top'
    $b.Background = Brush $(if ($Primary) { '#2E2560' } else { '#20243A' })
    $t = New-Object System.Windows.Controls.TextBlock; $t.FontFamily = 'Segoe MDL2 Assets'; $t.FontSize = 18; $t.HorizontalAlignment = 'Center'; $t.VerticalAlignment = 'Center'
    $t.Text = [string][char][Convert]::ToInt32($Hex, 16); $t.Foreground = Brush $(if ($Primary) { '#C9BBFF' } else { '#A9B0C2' })
    $b.Child = $t
    return $b
}
# Survol : la carte s'éclaire légèrement (repère visuel de ce qui est cliquable)
function Add-CardHover($Card) {
    $Card.Add_MouseEnter({ $this.BorderBrush = Brush '#3B3566'; $this.Background = Brush '#1A1D28' })
    $Card.Add_MouseLeave({ $this.BorderBrush = Brush '#232838'; $this.Background = Brush '#171A23' })
}
function New-ActionCard($Def) {
    if ($Def.StatusFn) {
        $st = $null
        try { $st = & $Def.StatusFn } catch { Write-Bug -Context "Statut ($($Def.T))" -ErrorRecord $_ }
        if ($st) {
            $D = @{}; foreach ($k in $Def.Keys) { if ($k -ne 'StatusFn') { $D[$k] = $Def[$k] } }
            foreach ($k in $st.Keys) { $D[$k] = $st[$k] }
            $Def = $D
        }
    }
    $card = New-CardBorder; Add-CardHover $card
    $grid = New-Object System.Windows.Controls.Grid
    $c0 = New-Object System.Windows.Controls.ColumnDefinition; $c0.Width = [System.Windows.GridLength]::Auto
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = [System.Windows.GridLength]::Auto
    $grid.ColumnDefinitions.Add($c0); $grid.ColumnDefinitions.Add($c1); $grid.ColumnDefinitions.Add($c2)
    $ik = $(if ($Def.UI) { $Def.UI } elseif ($Def.Go) { $Def.Go } else { $Def.A })
    $ih = $script:CardIcons[[string]$ik]; if (-not $ih) { $ih = 'E946' }
    Add-Child $grid (New-CardIcon $ih ([bool]$Def.P))
    $sp = New-Object System.Windows.Controls.StackPanel; [System.Windows.Controls.Grid]::SetColumn($sp, 1)
    $row = New-Object System.Windows.Controls.WrapPanel
    Add-Child $row (New-Text $Def.T 15 '#FFFFFF' 'SemiBold')
    if ($Def.Badge) { Add-Child $row (New-Pill $Def.Badge '#B9A8FF' '#2A2350') }
    Add-Child $sp $row
    $d = New-Text $Def.D 13 '#8B93A7'; $d.Margin = Th 0 5 0 0; Add-Child $sp $d
    if ($Def.StatusText) {
        $col = switch ($Def.StatusKind) { 'on' { '#4ADE80' } 'warn' { '#FFB547' } default { '#8B93A7' } }
        $sr = New-Object System.Windows.Controls.StackPanel; $sr.Orientation = 'Horizontal'; $sr.Margin = Th 0 8 0 0
        $dot = New-Object System.Windows.Shapes.Ellipse; $dot.Width = 8; $dot.Height = 8; $dot.Fill = Brush $col; $dot.VerticalAlignment = 'Center'; $dot.Margin = Th 0 0 8 0
        Add-Child $sr $dot; Add-Child $sr (New-Text $Def.StatusText 13 $col 'SemiBold')
        Add-Child $sp $sr
    }
    Add-Child $grid $sp
    $style = if ($Def.P) { 'PrimaryBtn' } else { 'ActionBtn' }
    $btn = New-Button $Def.B $style @{ Kind = $(if ($Def.UI) { 'ui' } elseif ($Def.Go) { 'go' } else { 'action' }); Def = $Def } (-not $Def.UI -or $Def.UiBusy)
    $btn.Margin = Th 20 0 0 0; $btn.MinWidth = 130
    [System.Windows.Controls.Grid]::SetColumn($btn, 2); Add-Child $grid $btn
    $card.Child = $grid
    return $card
}

# ---------------------------------------------------------------- Bilan avant / après (bilan.json dans le dossier des journaux)
$script:BilanFile = Join-Path $LogDir 'bilan.json'
function Read-Bilan { try { if (Test-Path -LiteralPath $script:BilanFile) { return ConvertTo-Hash (Get-Content -LiteralPath $script:BilanFile -Raw -Encoding UTF8 | ConvertFrom-Json) } } catch {}; return $null }
function Save-Bilan($b) { try { $b | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:BilanFile -Encoding UTF8 } catch {} }
# Le tout premier diagnostic devient « Avant » ; chaque diagnostic suivant met à jour « Maintenant »
function Update-Bilan {
    $snap = $script:Diag.Snap
    if (-not $snap) { return }
    $snap.Score = Get-Score
    $snap.Open = @(Get-OpenIssues).Count
    $b = Read-Bilan
    if (-not ($b -is [hashtable]) -or -not ($b.Before -is [hashtable])) { $b = @{ Before = $snap; After = $null } }
    else { $b.After = $snap }
    Save-Bilan $b
}
function Reset-Bilan {
    if (-not (Confirm-Box "Repartir de zéro ?`n`nLe prochain diagnostic servira de nouveau point de départ « Avant ».")) { return }
    try { Remove-Item -LiteralPath $script:BilanFile -Force -ErrorAction Stop } catch {}
    Write-UiLog "Bilan remis à zéro : le prochain diagnostic sera le nouveau point de départ."
    Refresh-Page
}
function Add-BilanCard($sp) {
    $b = Read-Bilan
    if (-not ($b -is [hashtable]) -or -not ($b.Before -is [hashtable])) { return }
    $a = $b.Before; $n = $b.After
    Add-Child $sp (New-Section 'Avant / après AEROX')
    $c = New-CardBorder; $cs = New-Object System.Windows.Controls.StackPanel
    $since = ''; try { $since = Format-Date ([datetime]$a.Date) } catch {}
    if (-not ($n -is [hashtable])) {
        $t = New-Text ("Point de départ enregistré le {0}. Fais tes réglages (démarrage, nettoyage, désinstallations, mises à jour…), redémarre le PC, puis relance le diagnostic : tu verras ici la différence, chiffres à l'appui." -f $since) 13 '#A9B0C2'
        Add-Child $cs $t; $c.Child = $cs; Add-Child $sp $c; return
    }
    $g = New-Object System.Windows.Controls.Grid
    foreach ($wd in 3, 1.4, 1.4, 1.6) { $cd = New-Object System.Windows.Controls.ColumnDefinition; $cd.Width = New-Object System.Windows.GridLength($wd, [System.Windows.GridUnitType]::Star); $g.ColumnDefinitions.Add($cd) }
    $script:BilanRow = 0
    $row = {
        param($cells, $colors, $weight)
        $rd = New-Object System.Windows.Controls.RowDefinition; $rd.Height = [System.Windows.GridLength]::Auto; $g.RowDefinitions.Add($rd)
        for ($k = 0; $k -lt 4; $k++) {
            $t = New-Text $cells[$k] 13 $colors[$k] $weight; $t.Margin = Th 0 4 8 4
            if ($k -gt 0) { $t.TextAlignment = 'Right' }
            [System.Windows.Controls.Grid]::SetRow($t, $script:BilanRow); [System.Windows.Controls.Grid]::SetColumn($t, $k); Add-Child $g $t
        }
        $script:BilanRow++
    }
    & $row @('', ("Avant ({0})" -f $since), 'Maintenant', 'Différence') @('#7A8399', '#7A8399', '#7A8399', '#7A8399') 'SemiBold'
    # Une ligne par mesure : valeur avant, maintenant, et écart coloré (vert = mieux)
    $line = {
        param($label, $va, $vn, [bool]$lowerBetter, $fmt)
        if ($null -eq $va -or $null -eq $vn) { return }
        $d = [double]$vn - [double]$va
        $better = if ($lowerBetter) { $d -lt 0 } else { $d -gt 0 }
        $col = if ([math]::Abs($d) -lt 1e-9) { '#8B93A7' } elseif ($better) { '#4ADE80' } else { '#FFB547' }
        $ds = if ([math]::Abs($d) -lt 1e-9) { '=' } else { $(if ($d -gt 0) { '+' } else { '−' }) + (& $fmt ([math]::Abs($d))) }
        & $row @($label, (& $fmt ([double]$va)), (& $fmt ([double]$vn)), $ds) @('#C3CAD9', '#A9B0C2', '#FFFFFF', $col) 'Normal'
    }
    $num = { param($v) "{0:N0}" -f $v }
    $sec = { param($v) $v = [int][math]::Round($v); if ($v -ge 60) { "{0} min {1:D2} s" -f [math]::Floor($v / 60), ($v % 60) } else { "$v s" } }
    $size = { param($v) Format-Size $v }
    & $line 'Note du diagnostic' $a.Score $n.Score $false $num
    & $line 'Problèmes à régler' $a.Open $n.Open $true $num
    & $line 'Temps de démarrage de Windows' $a.BootSec $n.BootSec $true $sec
    & $line 'Programmes lancés au démarrage' $a.Startup $n.Startup $true $num
    & $line 'Programmes en fond' $a.Procs $n.Procs $true $num
    & $line 'Mémoire utilisée' $a.RamUsed $n.RamUsed $true $size
    & $line "Espace libre sur $env:SystemDrive" $a.Free $n.Free $false $size
    if ($a.Drives -is [hashtable] -and $n.Drives -is [hashtable]) {
        foreach ($k in @($n.Drives.Keys | Sort-Object)) { if ($a.Drives.ContainsKey($k)) { & $line "Espace libre sur $k" ([double]$a.Drives[$k]) ([double]$n.Drives[$k]) $false $size } }
    }
    Add-Child $cs $g
    $note = "Temps de démarrage : mesuré par Windows au dernier démarrage complet. Après tes réglages, redémarre le PC (« Redémarrer », pas « Arrêter ») puis relance le diagnostic pour le voir changer. Mémoire et programmes en fond varient selon ce qui est ouvert au moment de la mesure."
    $t = New-Text $note 11.5 '#7A8399'; $t.Margin = Th 0 8 0 4; Add-Child $cs $t
    $rb = New-Button 'Repartir de zéro' 'TextBtn' @{ Kind = 'ui'; Def = @{ UI = 'bilan-reset' } } $false; $rb.HorizontalAlignment = 'Left'; Add-Child $cs $rb
    $c.Child = $cs; Add-Child $sp $c
}

function Get-Score { if (-not $script:Diag) { return $null }; $s = 100; foreach ($i in $script:Diag.Issues) { if ($i.Status -ne 'done') { $s -= $(if ($i.Sev -eq 'crit') { 12 } else { 5 }) } }; return [math]::Max([double]0, $s) }
function Get-Level([int]$S) { if ($S -ge 85) { return @{ Text = 'Bonne forme'; Color = '#4ADE80' } } elseif ($S -ge 60) { return @{ Text = 'Correct, à surveiller'; Color = '#FFB547' } } else { return @{ Text = 'À améliorer'; Color = '#FF6B6B' } } }
function Get-OpenIssues { if (-not $script:Diag) { return @() }; return @($script:Diag.Issues | Where-Object { $_.Status -ne 'done' }) }

function New-Ring([int]$Score, [double]$Size = 96) {
    $g = New-Object System.Windows.Controls.Grid; $g.Width = $Size; $g.Height = $Size; $g.VerticalAlignment = 'Center'
    $th = [math]::Round($Size * 0.095)
    $tr = New-Object System.Windows.Shapes.Ellipse; $tr.Stroke = Brush '#252A3A'; $tr.StrokeThickness = $th; Add-Child $g $tr
    $col = (Get-Level $Score).Color
    $r = ($Size - $th) / 2; $c = $Size / 2
    if ($Score -ge 100) { $e = New-Object System.Windows.Shapes.Ellipse; $e.Stroke = Brush $col; $e.StrokeThickness = $th; Add-Child $g $e }
    elseif ($Score -gt 0) {
        $a = [math]::PI * 2 * $Score / 100
        $inv = [Globalization.CultureInfo]::InvariantCulture
        $d = [string]::Format($inv, 'M {0},{1} A {2},{2} 0 {3} 1 {4},{5}', $c, ($c - $r), $r, $(if ($Score -gt 50) { 1 } else { 0 }), ($c + $r * [math]::Sin($a)), ($c - $r * [math]::Cos($a)))
        $p = New-Object System.Windows.Shapes.Path; $p.Data = [System.Windows.Media.Geometry]::Parse($d)
        $p.Stroke = Brush $col; $p.StrokeThickness = $th; $p.StrokeStartLineCap = 'Round'; $p.StrokeEndLineCap = 'Round'
        Add-Child $g $p
    }
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.HorizontalAlignment = 'Center'; $sp.VerticalAlignment = 'Center'
    $n = New-Text "$Score" ([math]::Round($Size * 0.27)) '#FFFFFF' 'Bold'; $n.HorizontalAlignment = 'Center'; Add-Child $sp $n
    if ($Size -ge 80) { $u = New-Text '/ 100' 10 '#8B93A7'; $u.HorizontalAlignment = 'Center'; Add-Child $sp $u }
    Add-Child $g $sp
    return $g
}
function New-Chip([string]$Text, [string]$Kind) {
    $c = @{ bad = @('#FF6B6B', '#3A1E24'); warn = @('#FFB547', '#3A2D17'); ok = @('#4ADE80', '#173326') }[$Kind]
    $b = New-Object System.Windows.Controls.Border; $b.Background = Brush $c[1]; $b.CornerRadius = Corner 10; $b.Padding = Th 10 3 10 3; $b.Margin = Th 0 8 8 0
    $b.Child = New-Text $Text 12 $c[0] 'SemiBold'
    return $b
}
function New-StatusDot([string]$State) {
    $map = @{ ok = @('✓', '#4ADE80', '#173326'); warn = @('!', '#FFB547', '#3A2D17'); bad = @('✕', '#FF6B6B', '#3A1E24'); run = @('…', '#B9A8FF', '#2A2350'); wait = @('', '#6E768B', '#1E2230') }
    $m = $map[$State]; if (-not $m) { $m = $map.wait }
    $b = New-Object System.Windows.Controls.Border; $b.Width = 22; $b.Height = 22; $b.CornerRadius = Corner 11; $b.Background = Brush $m[2]; $b.VerticalAlignment = 'Center'
    $t = New-Text $m[0] 12 $m[1] 'Bold'; $t.HorizontalAlignment = 'Center'; $t.VerticalAlignment = 'Center'; $b.Child = $t
    return $b
}

# ---------------------------------------------------------------- Cartes de problème (diagnostic + erreurs)
function New-IssueCard($I, [switch]$IsError) {
    $done = $I.Status -eq 'done'; $fixing = $I.Status -in 'fixing', 'verifying'
    $sev = if ($IsError) { 'crit' } else { $I.Sev }
    $card = New-CardBorder $(if (-not $done -and $sev -eq 'crit') { '#4A2229' } else { '#232838' })
    $card.Padding = Th 18 16 18 16; $card.Margin = Th 0 0 0 10
    $grid = New-Object System.Windows.Controls.Grid
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::Auto
    $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $grid.ColumnDefinitions.Add($c1); $grid.ColumnDefinitions.Add($c2)
    $ico = New-StatusDot $(if ($done) { 'ok' } elseif ($sev -eq 'crit') { 'bad' } else { 'warn' })
    $ico.Width = 34; $ico.Height = 34; $ico.CornerRadius = Corner 17; $ico.VerticalAlignment = 'Top'; $ico.Margin = Th 0 0 14 0
    $ico.Child.FontSize = 16
    if (-not $done -and $sev -ne 'crit') { $ico.Child.Text = 'i' }
    Add-Child $grid $ico
    $sp = New-Object System.Windows.Controls.StackPanel; [System.Windows.Controls.Grid]::SetColumn($sp, 1)
    $head = New-Object System.Windows.Controls.WrapPanel
    $title = New-Text $I.Title 15 $(if ($done) { '#8B93A7' } else { '#FFFFFF' }) 'SemiBold'
    if ($done) { $title.TextDecorations = [System.Windows.TextDecorations]::Strikethrough }
    Add-Child $head $title
    if ($done) { Add-Child $head (New-Pill 'Corrigé' '#4ADE80' '#173326') }
    elseif ($sev -eq 'crit') { Add-Child $head (New-Pill $(if ($IsError) { 'Erreur' } else { 'Critique' }) '#FF6B6B' '#3A1E24') }
    else { Add-Child $head (New-Pill 'À corriger' '#FFB547' '#3A2D17') }
    if ($I.Cat) { Add-Child $head (New-Pill $I.Cat '#8B93A7' '#222736') }
    Add-Child $sp $head
    if ($done) { if ($I.Detail) { Add-Child $sp (New-Rich '' $I.Detail '') } }
    else {
        if ($I.Code) { Add-Child $sp (New-Rich $(if ($I.Detail) { $I.Detail } else { 'Code' }) '' $I.Code) }
        elseif ($I.Detail) { Add-Child $sp (New-Rich '' $I.Detail '') }
        if ($I.Cause)  { Add-Child $sp (New-Rich 'Cause' $I.Cause '') }
        if ($I.Effect) { Add-Child $sp (New-Rich 'Conséquence' $I.Effect '') }
        $acts = New-Object System.Windows.Controls.WrapPanel; $acts.Margin = Th 0 10 0 0
        $hint = $null
        if ($fixing) { Add-Child $acts (New-Text $(if ($I.Status -eq 'verifying') { "Vérification que c'est bien réglé…" } else { "Réparation en cours…" }) 13 '#B9A8FF' 'SemiBold') }
        else {
            if ($I.FixLabel) {
                $b = New-Button $I.FixLabel 'FixBtn' @{ Kind = $(if ($IsError) { 'errfix' } else { 'fix' }); Issue = $I }; $b.Margin = Th 0 0 8 0; Add-Child $acts $b
                $hint = $(if ($I.UiFix) { 'Tu choisis' } elseif ($I.OpenOnly) { 'Ouvre la bonne page, à finir toi-même' } else { 'Réparation automatique' })
            }
            if ($I.Steps) {
                $open = [bool]$script:OpenSteps[$I.Title]
                $b = New-Button $(if ($open) { 'Masquer' } else { 'Voir comment faire' }) $(if ($I.FixLabel) { 'TextBtn' } else { 'ActionBtn' }) @{ Kind = 'steps'; Key = $I.Title } $false
                $b.Margin = Th 0 0 8 0; Add-Child $acts $b
                if (-not $I.FixLabel -and -not $IsError) {
                    $b2 = New-Button "C'est fait" 'TextBtn' @{ Kind = 'done'; Issue = $I } $false; Add-Child $acts $b2
                    $hint = 'À faire toi-même'
                }
            }
            if ($hint) { $h = New-Text $hint 12 '#7A8399'; $h.VerticalAlignment = 'Center'; $h.Margin = Th 4 0 0 0; Add-Child $acts $h }
            if (-not $IsError -and $I.Id -and $I.Cat -ne 'Sécurité') {
                $bi = New-Button 'Ne plus signaler' 'TextBtn' @{ Kind = 'ignore'; Issue = $I } $false; $bi.Margin = Th 8 0 0 0; Add-Child $acts $bi
            }
        }
        if ($I.VerifyFailed -and -not $done -and -not $fixing) {
            $vf = New-Text "⚠ La réparation automatique a été faite mais le problème est toujours là : suis les étapes « Voir comment faire », ou envoie un rapport de bug pour que ce soit amélioré." 12.5 '#FFB547'
            $vf.Margin = Th 0 8 0 0; Add-Child $sp $vf
        }
        if ($acts.Children.Count) { Add-Child $sp $acts }
        if ($I.Steps -and $script:OpenSteps[$I.Title]) {
            $st = New-Object System.Windows.Controls.StackPanel; $st.Margin = Th 4 10 0 0
            $k = 1; foreach ($s in $I.Steps) { $l = New-Text ("{0}.  {1}" -f $k, $s) 13 '#C3CAD9'; $l.Margin = Th 0 2 0 2; Add-Child $st $l; $k++ }
            Add-Child $sp $st
        }
    }
    Add-Child $grid $sp
    $card.Child = $grid
    return $card
}

# ---------------------------------------------------------------- Pages
$PageDefs = [ordered]@{
 clean = @{ Title = "Nettoyage"; Sub = "Libère de la place et supprime les fichiers inutiles. Tes fichiers perso (photos, documents, téléchargements, jeux) ne sont jamais touchés."; Cards = @(
    @{ T = "Nettoyage approfondi"; Badge = "Recommandé"; P = $true; B = "Analyser"; UI = 'deepclean'; UiBusy = $true; D = "Analyse tout ce qui peut être supprimé (temporaires, caches des navigateurs et des applis, mises à jour, rapports de plantage, nettoyage Windows, anciens composants…) et t'affiche la taille de chaque catégorie. Tu choisis, ça nettoie." },
    @{ T = "Ce qui prend de la place"; B = "Analyser le disque"; UI = 'space'; UiBusy = $true; D = "Trouve ce qui remplit le disque et te dit quoi en faire : place gardée par Windows (stockage réservé, veille prolongée, points de restauration, anciens pilotes), OneDrive en double, jeux et logiciels oubliés, plus gros fichiers et dossiers. 1 à 3 minutes." },
    @{ T = "Fichiers en double"; B = "Chercher"; UI = 'dupes'; UiBusy = $true; D = "Photos, vidéos, documents et installateurs présents en plusieurs exemplaires dans tes dossiers. Tu choisis ce qui part à la corbeille, un exemplaire est toujours gardé." },
    @{ T = "Fichiers temporaires (rapide)"; B = "Nettoyer"; A = "Clear-TempFiles"; D = "Juste les fichiers temporaires et le cache des miniatures, en quelques secondes." },
    @{ T = "Corbeille"; B = "Vider"; A = "Clear-RecycleBinAll"; D = "Vide la corbeille de tous les disques. Vérifie avant qu'il n'y a rien dedans dont tu as besoin !"; C = "Vider définitivement la corbeille ? Les fichiers dedans ne pourront plus être récupérés." },
    @{ T = "Nettoyage automatique"; B = "Activer"; A = "Enable-StorageSense"; StatusFn = { Get-SenseCardStatus }; D = "L'Assistant stockage de Windows vide tout seul les fichiers temporaires et la corbeille régulièrement." }) }
 update = @{ Title = "Mises à jour"; Sub = "Des logiciels et un Windows à jour, c'est moins de bugs, moins de plantages et plus de sécurité."; Cards = @(
    @{ T = "Choisir les mises à jour de logiciels"; P = $true; B = "Voir la liste"; UI = 'appupdates'; UiBusy = $true; StatusFn = { Get-IgnoredCardStatus }; D = "Liste les logiciels qui ont une nouvelle version : coche ceux à mettre à jour, ignore ceux que tu ne veux pas toucher (c'est mémorisé)." },
    @{ T = "Tout mettre à jour"; B = "Tout mettre à jour"; A = "Update-Apps"; D = "Met à jour d'un coup tous les logiciels, sauf ceux que tu as ignorés. Outil officiel de Microsoft (winget)."; C = "Tous les logiciels qui ont une mise à jour vont être mis à jour (sauf ceux que tu as ignorés).`n`nFerme tes logiciels ouverts avant de continuer.`n`nContinuer ?" },
    @{ T = "Mises à jour Windows"; P = $true; B = "Rechercher et installer"; A = "Update-Windows"; D = "Recherche, télécharge et installe les mises à jour de sécurité de Windows. Peut prendre 5 à 30 minutes."; C = "L'installation peut prendre du temps et le PC devra peut-être redémarrer ensuite.`n`nContinuer ?" },
    @{ T = "Pilotes (drivers)"; B = "Vérifier"; UI = 'drivers'; UiBusy = $true; D = "Compare le pilote de ta carte graphique à la dernière version officielle, liste les pilotes que Windows propose (tu choisis lesquels installer) et les périphériques qui ont un problème. 1 à 2 minutes." },
    @{ T = "Ouvrir Windows Update"; B = "Ouvrir"; A = "Open-WindowsUpdate"; D = "Ouvre la page Windows Update des Paramètres, si tu préfères regarder toi-même." }) }
 repair = @{ Title = "Réparation"; Sub = "Pour les bugs, les plantages, les problèmes de connexion ou un Windows Update bloqué."; Cards = @(
    @{ T = "Test de débit Internet"; Badge = "Speedtest® by Ookla"; P = $true; B = "Lancer le test"; UI = 'speedtest'; StatusFn = { Get-SpeedCardStatus }; D = "Mesure ta vitesse de téléchargement, d'envoi et ton ping, et t'explique si c'est bien pour jouer, regarder des vidéos ou télécharger." },
    @{ T = "Pas de son"; Badge = "Dépannage rapide"; B = "Réparer"; A = "Repair-Sound"; D = "Vérifie le son de Windows (le relance seulement s'il est arrêté), réactive ce qui est désactivé, enlève la sourdine, remonte le volume s'il est à zéro, et te dit quoi choisir dans Discord." },
    @{ T = "Discord bugue ou ne s'installe plus"; Badge = "Dépannage rapide"; B = "Réparer"; A = "Repair-Discord"; D = "Écran gris, chargement sans fin, son ou micro bizarres, ou réinstallation impossible ? Ferme Discord, vide son cache (tu restes connecté), repère une installation abîmée et vérifie que son téléchargement passe depuis ce PC."; C = "Discord va être fermé et son cache vidé. Tu restes connecté et tes réglages sont gardés.`n`nContinuer ?" },
    @{ T = "Le micro ne marche pas"; Badge = "Dépannage rapide"; B = "Réparer"; A = "Repair-Microphone"; D = "Réautorise le micro dans la confidentialité de Windows (cause n°1), réactive le micro s'il est désactivé, enlève la sourdine et remonte son niveau." },
    @{ T = "Webcam introuvable ou image noire"; Badge = "Dépannage rapide"; B = "Réparer"; A = "Repair-Webcam"; D = "Réautorise la caméra dans la confidentialité de Windows, réactive la webcam si elle est désactivée, vérifie son pilote et ouvre l'appli Caméra pour tester." },
    @{ T = "L'imprimante n'imprime plus"; Badge = "Dépannage rapide"; B = "Débloquer"; A = "Repair-Printing"; D = "Vide la file d'impression bloquée, relance le service d'impression, remet en ligne une imprimante restée « hors connexion » et affiche l'état de chaque imprimante."; C = "Les impressions en attente seront annulées (tu pourras les relancer après).`n`nContinuer ?" },
    @{ T = "Bureau ou barre des tâches figés"; Badge = "Dépannage rapide"; B = "Relancer"; A = "Restart-Shell"; D = "Le menu Démarrer ne s'ouvre plus, la barre des tâches ne répond plus, les icônes ont disparu ? Relance l'Explorateur Windows en quelques secondes, sans redémarrer le PC."; C = "Le bureau et la barre des tâches vont disparaître 2 ou 3 secondes, et les fenêtres de dossiers ouvertes se fermeront. Tes logiciels et ton travail en cours ne sont pas touchés.`n`nContinuer ?" },
    @{ T = "Pubs et fausses alertes de virus"; Badge = "Arnaques"; B = "Analyser"; UI = 'browser'; UiBusy = $true; D = "Des « Ton PC est infecté ! » en bas de l'écran, des pubs partout, une page d'accueil ou une recherche qui a changé toute seule ? Trouve les sites qui t'envoient des notifications, les extensions douteuses et les réglages imposés à Chrome, Edge, Brave et Opera, et les bloque." },
    @{ T = "Ça lague en ligne (jeu, Discord)"; Badge = "Nouveau"; B = "Analyser"; UI = 'lag'; UiBusy = $true; D = "Personnages qui « sautent », voix hachée, déconnexions ? Mesure ta connexion pendant 1 minute (liaison PC ↔ box, Internet, Wi-Fi, téléchargements en fond, VPN) et te dit d'où vient le lag." },
    @{ T = "Tester ma connexion"; B = "Tester"; A = "Test-Internet"; D = "Vérifie la box, Internet, le DNS, le ping et le Wi-Fi, et t'explique d'où vient le problème." },
    @{ T = "Réparer la connexion Internet"; B = "Réparer"; A = "Repair-Network"; D = "Remet à zéro les réglages réseau de Windows (DNS, Winsock, TCP/IP). Règle la plupart des « connecté mais pas d'Internet »."; C = "La connexion va se couper quelques secondes et il faudra redémarrer le PC à la fin.`n`nContinuer ?" },
    @{ T = "Réparer les fichiers de Windows"; P = $true; B = "Réparer"; A = "Repair-System"; D = "Vérifie et répare les fichiers système abîmés (outils officiels DISM + SFC). À faire si Windows bugue, plante ou fait des écrans bleus. 15 à 45 minutes."; C = "La réparation prend 15 à 45 minutes. Laisse le PC branché et le logiciel ouvert.`n`nLancer ?" },
    @{ T = "Vérifier le disque"; B = "Vérifier"; A = "Test-Disk"; D = "Contrôle la santé de tes disques et cherche des erreurs sur le disque de Windows." },
    @{ T = "Débloquer Windows Update"; B = "Débloquer"; A = "Reset-WindowsUpdate"; D = "Si les mises à jour Windows restent bloquées ou échouent en boucle : remet Windows Update à zéro."; C = "Windows Update va être remis à zéro. Un redémarrage sera conseillé ensuite.`n`nContinuer ?" },
    @{ T = "Créer un point de restauration"; B = "Créer"; A = "New-RestorePoint"; D = "Sauvegarde l'état actuel de Windows pour pouvoir revenir en arrière si quelque chose se passe mal plus tard." }) }
 perf = @{ Title = "Performances"; Sub = "Pour un PC qui démarre plus vite et rame moins. Chaque réglage affiche son état actuel et peut être annulé."; Cards = @(
    @{ T = "Pourquoi mon PC rame ?"; Badge = "Commence ici"; P = $true; B = "Analyser"; UI = 'slow'; UiBusy = $true; D = "Mesure pendant 20 secondes ce qui occupe le processeur, la mémoire et le disque, trouve les programmes gourmands et les réglages qui brident le PC, et te dit quoi faire. Encore mieux si tu la lances quand le PC rame." },
    @{ T = "Programmes cachés en fond"; Badge = "Gros gain"; B = "Voir"; UI = 'bgitems'; UiBusy = $true; D = "Tâches planifiées et services qui tournent tout seuls sans apparaître au démarrage : statistiques des fabricants, outils de mise à jour inutiles, logiciels « d'optimisation »… AEROX t'explique chacun, tu choisis ce que tu coupes (annulable)." },
    @{ T = "Programmes au démarrage"; Badge = "Gros gain"; P = $true; B = "Choisir"; UI = 'startup'; StatusFn = { Get-StartupCardStatus }; D = "Choisis appli par appli ce qui se lance tout seul à l'allumage. Garde ce que tu utilises tout le temps (Discord, par exemple), décoche le reste." },
    @{ T = "Mode performances maximales"; B = "Activer"; A = "Set-HighPerformance"; StatusFn = { Get-PerfCardStatus }; D = "Le processeur ne se bride plus pour économiser l'énergie. Idéal pour jouer sur un PC fixe." },
    @{ T = "Effets visuels"; B = "Régler"; A = "Open-VisualEffects"; StatusFn = { Get-FxCardStatus }; D = "Désactive les animations et transparences de Windows. Utile surtout sur les PC un peu anciens." },
    @{ T = "Désinstaller les logiciels inutiles"; B = "Analyser"; UI = 'uninstall'; UiBusy = $true; D = "Repère les logiciels inutiles ou douteux (faux « optimiseurs », barres d'outils, logiciels de pilotes, antivirus en double, applis préinstallées) et t'explique pourquoi. Tous tes logiciels sont listés, du plus gros au plus petit." }) }
 help = @{ Title = "Aide"; Sub = "Tout ce qu'il faut savoir pour utiliser AEROX PC Care sans stress."; Cards = @(
    @{ T = "Partager AEROX à un ami"; Badge = "💜"; P = $true; B = "Copier le message"; UI = 'share'; D = "Un pote dont le PC rame ou bugue ? Copie un petit message tout prêt avec le lien de téléchargement, à coller sur Discord, WhatsApp, Snap… AEROX est gratuit : plus on est nombreux, plus il s'améliore." },
    @{ T = "Rejoindre la communauté Discord"; Badge = "Communauté"; P = $true; B = "Rejoindre"; UI = 'discord'; StatusFn = { Get-DiscordCardStatus }; D = "Pose tes questions, partage ta config, propose des idées et suis les nouvelles versions avec les autres utilisateurs d'AEROX et le développeur." },
    @{ T = "Aide à distance"; Badge = "Nouveau"; P = $true; B = "J'ai besoin d'aide"; UI = 'remotehelp'; D = "Quelqu'un que tu connais prend la main sur ton PC pour t'aider, avec l'outil gratuit de Microsoft (Assistance rapide). Prépare aussi un rapport de ton PC à lui envoyer." },
    @{ T = "Quoi de neuf ?"; B = "Voir"; UI = 'whatsnew'; D = "Les nouveautés des dernières versions d'AEROX PC Care." },
    @{ T = "Donner mon avis"; Badge = "⭐"; B = "Donner mon avis"; UI = 'review'; D = "AEROX PC Care est gratuit : une note et un petit mot font plaisir au développeur et aident d'autres personnes à lui faire confiance. Ton avis est publié sur la page GitHub du logiciel." },
    @{ T = "Signaler un bug"; B = "Faire un rapport"; UI = 'report'; D = "Un truc ne marche pas comme prévu ? Envoie un rapport au développeur. Il ne contient ni ton nom, ni tes fichiers, ni tes mots de passe." },
    @{ T = "Historique et annulation"; B = "Voir"; UI = 'history'; D = "Tout ce qu'AEROX PC Care a changé sur ce PC, avec un bouton « Annuler » pour chaque réglage (démarrage, mode d'alimentation...). Et la restauration complète de Windows si besoin." },
    @{ T = "Rechercher une mise à jour d'AEROX PC Care"; B = "Rechercher"; UI = 'checkupdate'; D = "Vérifie si une nouvelle version du logiciel est disponible et l'installe en un clic (tes réglages sont gardés)." },
    @{ T = "Statistiques anonymes"; B = "Changer"; UI = 'stats-toggle'; StatusFn = { Get-StatsCardStatus }; D = "Des compteurs envoyés de temps en temps au développeur : version d'AEROX, types de problèmes trouvés, lenteurs qu'AEROX n'a pas su expliquer, réparations qui n'ont pas suffi. Jamais ton nom, celui du PC, tes fichiers ni ton adresse IP : ça sert seulement à corriger d'abord ce qui touche le plus de monde." },
    @{ T = "Dossier des journaux"; B = "Ouvrir"; UI = 'logs'; D = "Tous les journaux sont enregistrés jour par jour sur ce PC." }) }
}

function Get-PerfCardStatus {
    $p = Get-PowerStatus
    if ($p.Perf) { return @{ StatusText = "Activé : $($p.Name)"; StatusKind = 'on'; B = 'Revenir à Équilibré'; A = 'Set-BalancedPower'; P = $false } }
    return @{ StatusText = $(if ($p.Name) { "Désactivé (mode actuel : $($p.Name))" } else { 'Désactivé' }); StatusKind = 'off'; B = 'Activer'; A = 'Set-HighPerformance'; P = $true }
}
function Get-FxCardStatus {
    switch (Get-VisualFxStatus) {
        2 { return @{ StatusText = 'Réglé sur « meilleures performances »'; StatusKind = 'on'; B = 'Modifier' } }
        3 { return @{ StatusText = 'Réglage personnalisé'; StatusKind = 'on'; B = 'Modifier' } }
        default { return @{ StatusText = 'Tous les effets activés (réglage par défaut de Windows)'; StatusKind = 'off'; B = 'Régler' } }
    }
}
function Get-SenseCardStatus {
    if (Get-StorageSenseOn) { return @{ StatusText = 'Activé : Windows nettoie tout seul'; StatusKind = 'on'; B = 'Désactiver'; A = 'Disable-StorageSense'; P = $false } }
    return @{ StatusText = 'Désactivé'; StatusKind = 'off'; B = 'Activer'; A = 'Enable-StorageSense'; P = $true }
}
function Get-DiscordCardStatus {
    if (-not $sync.DiscordUrl) { return @{ StatusText = "Le lien du serveur arrive bientôt"; StatusKind = 'off' } }
    return $null
}
function Get-StatsCardStatus {
    if ($script:Settings.StatsOff) { return @{ B = 'Activer'; StatusText = "Désactivées : rien n'est envoyé"; StatusKind = 'off' } }
    return @{ B = 'Désactiver'; StatusText = "Activées : compteurs anonymes seulement"; StatusKind = 'on' }
}
function Get-StartupCardStatus {
    $n = @(Get-StartupEntries | Where-Object { $_.Enabled }).Count
    return @{ StatusText = "$n programme(s) se lancent au démarrage"; StatusKind = $(if ($n -gt 8) { 'warn' } else { 'on' }) }
}
function Get-IgnoredCardStatus {
    $n = @($script:Settings.IgnoredApps).Count
    if ($n) { return @{ StatusText = "$n logiciel(s) ignoré(s) : ils ne seront jamais mis à jour par AEROX"; StatusKind = 'off' } }
    return $null
}

function Build-Header($Sp, [string]$Title, [string]$Sub) {
    Add-Child $Sp (New-Text $Title 26 '#FFFFFF' 'Bold')
    $s = New-Text $Sub 13 '#8B93A7'; $s.Margin = Th 0 6 0 20; $s.MaxWidth = 760; $s.HorizontalAlignment = 'Left'; Add-Child $Sp $s
}

function Build-HomePage {
    $sp = New-Object System.Windows.Controls.StackPanel
    Build-Header $sp "Salut 👋" "Lance le diagnostic : AEROX PC Care trouve ce qui ne va pas, t'explique pourquoi et le répare pour toi quand c'est possible. Rien n'est modifié sans ton clic."
    if ($sync.UpdateInfo) {
        $u = New-CardBorder '#2A2350'
        $g = New-Object System.Windows.Controls.DockPanel
        if ($sync.UpdateInfo.Setup) { $b = New-Button "Mettre à jour" 'PrimaryBtn' @{ Kind = 'ui'; Def = @{ UI = 'selfupdate' } } $false }
        else { $b = New-Button "Télécharger" 'PrimaryBtn' @{ Kind = 'openurl'; Url = $sync.UpdateInfo.Url } $false }
        [System.Windows.Controls.DockPanel]::SetDock($b, 'Right'); Add-Child $g $b
        $t = New-Object System.Windows.Controls.StackPanel
        Add-Child $t (New-Text ("Nouvelle version disponible : {0}{1}" -f $sync.UpdateInfo.Version, $(if ($sync.UpdateInfo.Test) { ' (version de test)' } else { '' })) 15 '#FFFFFF' 'SemiBold')
        Add-Child $t (New-Text $(if ($sync.UpdateInfo.Setup) { "Un clic : le logiciel télécharge la nouvelle version, l'installe et se relance tout seul. Tes réglages sont gardés." } else { "Télécharge-la, dézippe-la et remplace l'ancien dossier" + $(if ($Portable) { " sur la clé (garde le dossier « donnees » : il contient tes réglages)." } else { '.' }) }) 13 '#8B93A7')
        Add-Child $g $t; $u.Child = $g; Add-Child $sp $u
    }
    if (Test-ReviewInvite) {
        $rv = New-CardBorder '#2A2350'; $rd = New-Object System.Windows.Controls.DockPanel
        $rb = New-Object System.Windows.Controls.StackPanel; $rb.Orientation = 'Horizontal'; [System.Windows.Controls.DockPanel]::SetDock($rb, 'Right'); $rb.VerticalAlignment = 'Center'
        $b1 = New-Button 'Plus tard' 'TextBtn' @{ Kind = 'ui'; Def = @{ UI = 'review-later' } } $false; $b1.Margin = Th 0 0 4 0; Add-Child $rb $b1
        $b2 = New-Button 'Ne plus demander' 'TextBtn' @{ Kind = 'ui'; Def = @{ UI = 'review-never' } } $false; $b2.Margin = Th 0 0 8 0; Add-Child $rb $b2
        Add-Child $rb (New-Button 'Donner mon avis' 'PrimaryBtn' @{ Kind = 'ui'; Def = @{ UI = 'review' } } $false)
        Add-Child $rd $rb
        $rt = New-Object System.Windows.Controls.StackPanel; $rt.VerticalAlignment = 'Center'
        Add-Child $rt (New-Text "AEROX PC Care t'a aidé ? ⭐" 15 '#FFFFFF' 'SemiBold')
        Add-Child $rt (New-Text "Le logiciel est gratuit : une note et un petit mot, ça fait plaisir et ça aide d'autres personnes à lui faire confiance." 13 '#8B93A7')
        Add-Child $rd $rt; $rv.Child = $rd; Add-Child $sp $rv
    }
    # Bannière santé, mise en avant (dégradé violet discret)
    $h = New-CardBorder '#2E2856'; $h.Padding = Th 22 18 22 18
    $gb = New-Object System.Windows.Media.LinearGradientBrush; $gb.StartPoint = New-Object System.Windows.Point(0, 0); $gb.EndPoint = New-Object System.Windows.Point(1, 0)
    $gb.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString('#231E40'), 0)))
    $gb.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString('#171A23'), 0.75)))
    $h.Background = $gb
    $dp = New-Object System.Windows.Controls.DockPanel
    if (-not $script:Diag) {
        $b = New-Button "Lancer le diagnostic" 'PrimaryBtn' @{ Kind = 'startdiag' }; [System.Windows.Controls.DockPanel]::SetDock($b, 'Right'); Add-Child $dp $b
        $t = New-Object System.Windows.Controls.StackPanel; $t.VerticalAlignment = 'Center'
        Add-Child $t (New-Text 'ÉTAT DE TON PC' 11 '#9C8CFF' 'Bold')
        Add-Child $t (New-Text "Pas encore analysé" 18 '#FFFFFF' 'Bold')
        Add-Child $t (New-Text "Le diagnostic prend une minute environ et ne modifie rien." 13 '#8B93A7')
        Add-Child $dp $t
    } else {
        $s = Get-Score; $lv = Get-Level $s; $open = @(Get-OpenIssues)
        $b = New-Button "Voir le diagnostic" $(if ($open.Count) { 'PrimaryBtn' } else { 'ActionBtn' }) @{ Kind = 'go'; Def = @{ Go = 'diag' } } $false
        [System.Windows.Controls.DockPanel]::SetDock($b, 'Right'); Add-Child $dp $b
        $ring = New-Ring $s 80; $ring.Margin = Th 0 0 20 0; [System.Windows.Controls.DockPanel]::SetDock($ring, 'Left'); Add-Child $dp $ring
        $t = New-Object System.Windows.Controls.StackPanel; $t.VerticalAlignment = 'Center'
        Add-Child $t (New-Text 'ÉTAT DE TON PC' 11 '#9C8CFF' 'Bold')
        Add-Child $t (New-Text $lv.Text 18 $lv.Color 'Bold')
        Add-Child $t (New-Text $(if ($open.Count) { "$($open.Count) problème(s) à régler" } else { "Aucun problème en attente" }) 13 '#8B93A7')
        Add-Child $dp $t
    }
    $h.Child = $dp; Add-Child $sp $h
    # Tuiles
    $tiles = New-Object System.Windows.Controls.Primitives.UniformGrid; $tiles.Columns = 4; $tiles.Margin = Th 0 0 0 4
    foreach ($k in 'OS', 'CPU', 'RAM', 'DISK') {
        $st = $script:Stats[$k]; if (-not $st) { $st = @{ L = $k; V = '...'; S = ''; C = '#FFFFFF' } }
        $b = New-Object System.Windows.Controls.Border; $b.Background = Brush '#171A23'; $b.CornerRadius = Corner 12; $b.Padding = Th 16 14 16 14; $b.Margin = Th 0 0 10 12
        $s2 = New-Object System.Windows.Controls.StackPanel
        Add-Child $s2 (New-Text $st.L.ToUpper() 11 '#7A8399' 'Bold')
        $v = New-Text $st.V 16 $st.C 'SemiBold'; $v.Margin = Th 0 6 0 0; Add-Child $s2 $v
        $x = New-Text $st.S 12 '#8B93A7'; $x.Margin = Th 0 2 0 0; Add-Child $s2 $x
        $b.Child = $s2; Add-Child $tiles $b
    }
    Add-Child $sp $tiles
    Add-Child $sp (New-ActionCard @{ T = "Optimisation complète"; Badge = "Le plus efficace"; P = $true; B = "Commencer"; UI = 'optimize'; UiBusy = $true; D = "Le grand ménage guidé, étape par étape : point de restauration, diagnostic, programmes au démarrage, programmes cachés en fond, logiciels inutiles, nettoyage approfondi et mises à jour. Tu choisis à chaque étape, puis le bilan avant / après te montre la différence." })
    Add-Child $sp (New-ActionCard @{ T = "Diagnostic complet"; Badge = "Commence ici"; P = $true; B = "Lancer"; Go = 'diag'; D = "Vérifie ton PC point par point (stockage, performances, stabilité, mises à jour, pilotes, sécurité, réseau...) et t'affiche chaque problème avec sa cause et sa réparation." })
    $nCh = @(Get-Changes 300 | Where-Object { $_.Undo -and -not $_.Undone }).Count
    Add-Child $sp (New-ActionCard @{ T = "Historique des changements"; B = "Voir"; UI = 'history'; D = $(if ($nCh) { "$nCh réglage(s) modifié(s) par AEROX PC Care peuvent être annulés en un clic." } else { "Tout ce qu'AEROX PC Care change sur ce PC est noté ici, avec un bouton pour l'annuler." }) })
    Add-Child $sp (New-ActionCard @{ T = "Optimisation rapide"; Badge = "Recommandé"; P = $true; B = "Optimiser"; A = "Start-QuickOptimize"
        D = "En un clic : point de restauration, fichiers temporaires, cache des navigateurs et du DNS, mise à jour des logiciels."
        C = "L'optimisation rapide va :`n`n• créer un point de restauration (sécurité)`n• supprimer les fichiers temporaires`n• vider le cache des navigateurs fermés`n• mettre à jour tes logiciels`n`nFerme tes logiciels ouverts avant. Tes fichiers perso ne sont pas touchés.`n`nOn y va ?" })
    return $sp
}

function Build-DiagPage {
    $sp = New-Object System.Windows.Controls.StackPanel
    Build-Header $sp "Diagnostic" "Vérifie ton PC point par point. Pour chaque problème : ce qui se passe, pourquoi, et la réparation en un clic quand c'est possible."
    if ($script:Scanning) {
        $ug = New-Object System.Windows.Controls.Primitives.UniformGrid; $ug.Columns = 2
        foreach ($k in $sync.ScanOrder) {
            $state = $sync.Scan[$k]
            $b = New-Object System.Windows.Controls.Border; $b.Background = Brush '#171A23'; $b.CornerRadius = Corner 10; $b.Padding = Th 14 10 14 10; $b.Margin = Th 0 0 8 8
            $dp = New-Object System.Windows.Controls.StackPanel; $dp.Orientation = 'Horizontal'
            Add-Child $dp (New-StatusDot $state)
            $t = New-Text ($k + $(if ($state -eq 'run') { '  — vérification…' } else { '' })) 13 '#C3CAD9'; $t.Margin = Th 10 0 0 0; $t.VerticalAlignment = 'Center'; Add-Child $dp $t
            $b.Child = $dp; Add-Child $ug $b
        }
        Add-Child $sp $ug
        return $sp
    }
    if (-not $script:Diag) {
        $c = New-CardBorder; $st = New-Object System.Windows.Controls.StackPanel; $st.HorizontalAlignment = 'Center'; $st.Margin = Th 0 12 0 12
        $t = New-Text "Aucun diagnostic pour l'instant" 16 '#FFFFFF' 'SemiBold'; $t.HorizontalAlignment = 'Center'; Add-Child $st $t
        $t = New-Text "Ça prend une minute environ et ne modifie rien sur le PC." 13 '#8B93A7'; $t.HorizontalAlignment = 'Center'; Add-Child $st $t
        $b = New-Button "Lancer le diagnostic" 'PrimaryBtn' @{ Kind = 'startdiag' }; $b.Margin = Th 0 14 0 0; $b.HorizontalAlignment = 'Center'; Add-Child $st $b
        $c.Child = $st; Add-Child $sp $c
        return $sp
    }
    $s = Get-Score; $lv = Get-Level $s; $open = @(Get-OpenIssues)
    $crit = @($open | Where-Object { $_.Sev -eq 'crit' }).Count; $warn = $open.Count - $crit
    $auto = @($open | Where-Object { $_.FixLabel -and -not $_.UiFix -and -not $_.OpenOnly }).Count; $fixed = $script:Diag.Issues.Count - $open.Count
    $sum = New-CardBorder; $sum.Padding = Th 22 18 22 18
    $dp = New-Object System.Windows.Controls.DockPanel
    $btns = New-Object System.Windows.Controls.StackPanel; $btns.VerticalAlignment = 'Center'; [System.Windows.Controls.DockPanel]::SetDock($btns, 'Right')
    if ($auto) { $b = New-Button "Tout réparer ($auto)" 'FixBtn' @{ Kind = 'fixall' }; $b.Margin = Th 0 0 0 8; Add-Child $btns $b }
    $b = New-Button "Mon PC rame : analyser" 'ActionBtn' @{ Kind = 'ui'; Def = @{ UI = 'slow' } }; $b.Margin = Th 0 0 0 8; Add-Child $btns $b
    Add-Child $btns (New-Button "Relancer" 'ActionBtn' @{ Kind = 'startdiag' })
    Add-Child $dp $btns
    $ring = New-Ring $s 96; $ring.Margin = Th 0 0 22 0; [System.Windows.Controls.DockPanel]::SetDock($ring, 'Left'); Add-Child $dp $ring
    $t = New-Object System.Windows.Controls.StackPanel; $t.VerticalAlignment = 'Center'
    Add-Child $t (New-Text $lv.Text 18 $lv.Color 'Bold')
    $msg = if ($open.Count) { "$($open.Count) problème(s) trouvé(s)" + $(if ($auto) { ", dont $auto réparable(s) automatiquement." } else { '.' }) } else { "Tout est réglé, bravo !" }
    Add-Child $t (New-Text $msg 13 '#8B93A7')
    $chips = New-Object System.Windows.Controls.WrapPanel
    if ($crit)  { Add-Child $chips (New-Chip "$crit critique(s)" 'bad') }
    if ($warn)  { Add-Child $chips (New-Chip "$warn à corriger" 'warn') }
    if ($fixed) { Add-Child $chips (New-Chip "$fixed corrigé(s)" 'ok') }
    Add-Child $chips (New-Chip "$($script:Diag.Ok.Count) OK" 'ok')
    Add-Child $t $chips
    $d = New-Text ("Analyse du {0}" -f $script:Diag.Date.ToString('dd/MM/yyyy à HH:mm')) 11 '#6E768B'; $d.Margin = Th 0 8 0 0; Add-Child $t $d
    Add-Child $dp $t
    $sum.Child = $dp; Add-Child $sp $sum
    Add-BilanCard $sp

    $todo = @($open | Sort-Object @{ Expression = { if ($_.Sev -eq 'crit') { 0 } else { 1 } } })
    $done = @($script:Diag.Issues | Where-Object { $_.Status -eq 'done' })
    if ($todo.Count) { Add-Child $sp (New-Section 'À régler'); foreach ($i in $todo) { Add-Child $sp (New-IssueCard $i) } }
    if ($done.Count) { Add-Child $sp (New-Section 'Corrigé'); foreach ($i in $done) { Add-Child $sp (New-IssueCard $i) } }
    Add-Child $sp (New-Section 'Ce qui va bien')
    $ok = New-Object System.Windows.Controls.Border; $ok.Background = Brush '#171A23'; $ok.CornerRadius = Corner 12; $ok.Padding = Th 16 6 16 6
    $ol = New-Object System.Windows.Controls.StackPanel
    foreach ($o in $script:Diag.Ok) {
        $row = New-Object System.Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'; $row.Margin = Th 0 6 0 6
        Add-Child $row (New-StatusDot 'ok'); $x = New-Text $o 13 '#C3CAD9'; $x.Margin = Th 10 0 0 0; $x.VerticalAlignment = 'Center'; Add-Child $row $x
        Add-Child $ol $row
    }
    $ok.Child = $ol; Add-Child $sp $ok
    $ign = @($script:Diag.Ignored | Where-Object { $_ })
    if ($ign.Count) {
        Add-Child $sp (New-Section 'Ignoré à ta demande')
        $ib = New-Object System.Windows.Controls.Border; $ib.Background = Brush '#13161E'; $ib.CornerRadius = Corner 12; $ib.Padding = Th 16 6 12 6
        $il = New-Object System.Windows.Controls.StackPanel
        foreach ($x in $ign) {
            $row = New-Object System.Windows.Controls.DockPanel; $row.Margin = Th 0 6 0 6
            $rb = New-Button 'Réactiver' 'TextBtn' @{ Kind = 'unignore'; Issue = $x } $false; [System.Windows.Controls.DockPanel]::SetDock($rb, 'Right'); Add-Child $row $rb
            $tx = New-Object System.Windows.Controls.StackPanel; $tx.VerticalAlignment = 'Center'
            Add-Child $tx (New-Text $x.Title 13 '#8B93A7' 'SemiBold')
            if ($x.Detail) { Add-Child $tx (New-Text $x.Detail 12 '#6E768B') }
            Add-Child $row $tx
            Add-Child $il $row
        }
        $ib.Child = $il; Add-Child $sp $ib
    }
    return $sp
}

function Build-StaticPage([string]$Key) {
    $def = $PageDefs[$Key]
    $sp = New-Object System.Windows.Controls.StackPanel
    Build-Header $sp $def.Title $def.Sub
    foreach ($c in $def.Cards) { Add-Child $sp (New-ActionCard $c) }
    if ($Key -eq 'help') {
        $t = New-Text ("Bon à savoir :`n" +
            "• Un point de restauration est créé avant les réparations automatiques.`n" +
            "• Le logiciel ne supprime jamais tes photos, documents, téléchargements ou jeux.`n" +
            "• Pas de « nettoyeur de registre » ni de réglages douteux : uniquement des outils officiels de Windows.`n" +
            "• Quand une erreur arrive, le logiciel affiche sa cause et la réparation possible.`n" +
            "• Les opérations longues peuvent sembler bloquées sur un pourcentage : c'est normal, laisse tourner.") 13 '#A9B0C2'
        $t.Margin = Th 0 10 0 0; $t.LineHeight = 21; Add-Child $sp $t
    }
    return $sp
}

function Show-Page([string]$Key) {
    # Caché près de l'horloge : la page sera construite à la réouverture (économise la mémoire)
    if ($script:InTray) { $script:Cur = $Key; return }
    $same = ($Key -eq $script:Cur); $offset = $Scroll.VerticalOffset
    $script:Cur = $Key
    $script:PageButtons.Clear()
    try {
        $page = switch ($Key) { 'home' { Build-HomePage } 'diag' { Build-DiagPage } 'monitor' { Build-MonitorPage } 'system' { Build-SystemPage } default { Build-StaticPage $Key } }
    } catch {
        # Une page qui plante ne doit jamais fermer le logiciel : on affiche l'erreur à la place
        Write-Bug -Context "Page $Key" -ErrorRecord $_
        $page = New-Object System.Windows.Controls.StackPanel
        Add-Child $page (New-Text "Cette page n'a pas pu s'afficher" 20 '#FFFFFF' 'Bold')
        $t = New-Text ("Un bug du logiciel l'en empêche : " + $_.Exception.Message + "`n`nLe reste du logiciel fonctionne. Clique sur « Signaler un bug » en bas pour qu'il soit corrigé.") 13 '#A9B0C2'
        $t.Margin = Th 0 8 0 0; Add-Child $page $t
    }
    if ($Key -ne 'monitor') { $script:MonUi = $null }
    $PageHost.Children.Clear()
    Add-Child $PageHost $page
    if (-not $same -and -not $script:NoAnim) {
        try {
            $tt = New-Object System.Windows.Media.TranslateTransform(0, 8); $page.RenderTransform = $tt
            $da = New-Object System.Windows.Media.Animation.DoubleAnimation(0, 1, [TimeSpan]::FromMilliseconds(180))
            $dy = New-Object System.Windows.Media.Animation.DoubleAnimation(8, 0, [TimeSpan]::FromMilliseconds(220)); $dy.EasingFunction = New-Object System.Windows.Media.Animation.CubicEase
            $page.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $da)
            $tt.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $dy)
        } catch {}
    }
    if ($same) { $Scroll.UpdateLayout(); $Scroll.ScrollToVerticalOffset($offset) } else { $Scroll.ScrollToTop() }
}
function Go-Page([string]$Key) { $nav = $NavMap[$Key]; if ($nav.IsChecked) { Show-Page $Key } else { $nav.IsChecked = $true } }
function Refresh-Page { Show-Page $script:Cur }

function Update-DiagBadge {
    $n = @(Get-OpenIssues).Count
    if ($n -gt 0) { $DiagBadgeText.Text = "$n"; $DiagBadge.Visibility = 'Visible' } else { $DiagBadge.Visibility = 'Collapsed' }
}

function Update-HomeStats([switch]$KeepDrives) {
    try {
        $os  = Get-CimInstance Win32_OperatingSystem
        $cs  = Get-CimInstance Win32_ComputerSystem
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $c   = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
        $ramPct = [math]::Round((1 - ([double]$os.FreePhysicalMemory * 1KB) / [double]$cs.TotalPhysicalMemory) * 100)
        $pct = [math]::Round($c.FreeSpace / $c.Size * 100)
        $script:Stats = @{
            OS   = @{ L = 'Système'; V = ($os.Caption -replace '^Microsoft\s+', ''); S = "Build $($os.BuildNumber)"; C = '#FFFFFF' }
            CPU  = @{ L = 'Processeur'; V = ($cpu.Name.Trim() -replace '\s+', ' ' -replace '\(R\)|\(TM\)|CPU|Processor|\d+-Core', '' -replace '\s+', ' ').Trim(); S = "$($cpu.NumberOfCores) cœurs / $($cpu.NumberOfLogicalProcessors) threads"; C = '#FFFFFF' }
            RAM  = @{ L = 'Mémoire'; V = (Format-Size $cs.TotalPhysicalMemory); S = "$ramPct % utilisée"; C = $(if ($ramPct -ge 85) { '#FFB547' } else { '#FFFFFF' }) }
            DISK = @{ L = "Disque $env:SystemDrive"; V = "$(Format-Size $c.FreeSpace) libres"; S = "sur $(Format-Size $c.Size) ($pct %)"; C = $(if ($pct -lt 10) { '#FF6B6B' } elseif ($pct -lt 15) { '#FFB547' } else { '#FFFFFF' }) }
        }
        # Les autres disques (internes et externes) sous celui de Windows : lus en arrière-plan (un disque USB en veille
        # peut mettre plusieurs secondes à répondre), affichés au rafraîchissement suivant
        if (-not $KeepDrives) { Start-Background '$sync.Drives = @(Get-DriveList | Where-Object { $_.Id -ne $env:SystemDrive }); $sync.DrivesNew = $true' }
        $others = @($sync.Drives | Where-Object { $_ })
        if ($others.Count) {
            $script:Stats.DISK.L = 'Disques'
            $script:Stats.DISK.V = "$env:SystemDrive $(Format-Size $c.FreeSpace) libres"
            $script:Stats.DISK.S = (@("sur $(Format-Size $c.Size) ($pct %)") + @($others | Select-Object -First 4 | ForEach-Object { "{0} {1} libres sur {2}{3}" -f $_.Id, (Format-Size $_.Free), (Format-Size $_.Size), $(if ($_.Removable) { ' (amovible)' } else { '' }) }) + @($(if ($others.Count -gt 4) { "+ $($others.Count - 4) autre(s)" }) | Where-Object { $_ })) -join "`n"
        }
    } catch { Write-Bug -Context 'Infos de l''accueil' -ErrorRecord $_ }
}

# ---------------------------------------------------------------- Journal
function Append-Log([string]$Text) {
    $LogBox.AppendText($Text)
    $LogBox.ScrollToEnd()
    try { [IO.File]::AppendAllText($LogFile, $Text, [Text.Encoding]::UTF8) } catch {}
    $last = @($Text -split "`r?`n" | Where-Object { $_.Trim() }) | Select-Object -Last 1
    if ($last) { $LogLast.Text = ($last -replace '^\[\d\d:\d\d:\d\d\]\s*', '').Trim(); if (-not $script:LogOpen) { $LogDot.Visibility = 'Visible' } }
}
function Write-UiLog([string]$Line) { Append-Log ($Line + "`r`n") }
function Flush-Queue {
    $sb = New-Object System.Text.StringBuilder
    $line = $null
    while ($sync.Queue.TryDequeue([ref]$line)) { [void]$sb.AppendLine($line) }
    if ($sb.Length -gt 0) { Append-Log $sb.ToString() }
}
function Set-LogOpen([bool]$Open) {
    $script:LogOpen = $Open
    $LogBox.Visibility = $(if ($Open) { 'Visible' } else { 'Collapsed' })
    $LogChevron.Text = $(if ($Open) { [string][char]0xE70D } else { [string][char]0xE70E })
    $LogLast.Visibility = $(if ($Open) { 'Collapsed' } else { 'Visible' })
    if ($Open) { $LogDot.Visibility = 'Collapsed'; $LogBox.ScrollToEnd() }
    $script:Settings.LogOpen = $Open; Save-Settings
}

# ---------------------------------------------------------------- Exécution des tâches
function Set-Busy([bool]$Busy, [string]$Label = '') {
    foreach ($b in $script:PageButtons) { $b.IsEnabled = -not $Busy }
    if ($Busy) { $BusyPanel.Visibility = 'Visible'; $StatusText.Text = "En cours : $Label"; $Progress.IsIndeterminate = $true; $CancelBtn.Content = 'Annuler'; $CancelBtn.IsEnabled = $true }
    else { $BusyPanel.Visibility = 'Collapsed' }
}

# ---------------------------------------------------------------- Annuler une tâche en cours
# Analyses (lecture seule) : arrêt immédiat. Mises à jour de logiciels : arrêt après le logiciel en cours.
# Opérations qui modifient Windows en profondeur : pas d'arrêt au milieu (risque de laisser le PC dans un état bancal).
$script:HardCancel = '^(Invoke-Diagnostic|Get-SpaceUsage|Get-DriverReport|Get-AppUpdatesForUi|Get-CleanupAnalysis|Get-InstalledAppsAdvice|Get-SlowReport|Get-BgItems|Get-BrowserReport|Get-Duplicates|Open-BatteryReport|Test-Internet|Test-Disk)\b'
$script:SoftCancel = '^(Update-SelectedApps|Update-Apps|Invoke-WindowsSpace|New-RestorePoint; Invoke-WindowsSpace|Invoke-DeepClean)\b'
function Stop-AeroxTask {
    $job = $script:Job
    if (-not $job) { return }
    $act = "$($job.Action)".Trim()
    $hard = $act -match $script:HardCancel
    $soft = ($act -match $script:SoftCancel) -or $script:QueueRunning
    if (-not $hard -and -not $soft) {
        if ($script:Wiz) {
            $script:Wiz = $null
            [System.Windows.MessageBox]::Show("« $($job.Label) » modifie Windows : elle va se terminer normalement (l'arrêter au milieu pourrait laisser le PC dans un état bancal).`n`nL'optimisation complète s'arrêtera juste après.", $AppName, 'OK', 'Information') | Out-Null
            Write-UiLog "⏹ L'optimisation complète s'arrêtera après l'étape en cours."
            return
        }
        [System.Windows.MessageBox]::Show("« $($job.Label) » modifie Windows : l'arrêter au milieu pourrait laisser le PC dans un état bancal.`n`nLaisse-la se terminer, ça ne devrait plus être long.", $AppName, 'OK', 'Information') | Out-Null
        return
    }
    $sync.Cancel = $true
    $script:FixQueue.Clear()
    $CancelBtn.IsEnabled = $false
    if ($hard -and -not $script:QueueRunning) {
        $CancelBtn.Content = 'Arrêt…'
        $job.StopAt = Get-Date
        try { [AeroxNative]::StopScan = $true } catch {}
        try { [void]$job.PS.BeginStop($null, $null) } catch {}
        # Outils en ligne de commande lancés par l'analyse (lecture seule) : arrêtés aussi
        try {
            foreach ($p in @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$PID" -ErrorAction SilentlyContinue)) {
                if ("$($p.Name)" -match '(?i)^(winget|powercfg|ping|nslookup|tracert|pathping)\.exe$') { try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }
            }
        } catch {}
        Write-UiLog "⏹ Arrêt demandé…"
    } else {
        $CancelBtn.Content = 'Arrêt après l''étape en cours…'
        Write-UiLog "⏹ Arrêt demandé : l'étape en cours se termine proprement, la suite est annulée."
    }
}
$CancelBtn.Add_Click({ Stop-AeroxTask })

function Start-AeroxTask([string]$Action, [string]$Label, [string]$OnDone = '') {
    if ($script:Job) { [System.Windows.MessageBox]::Show("Une opération est déjà en cours, attends qu'elle se termine.", $AppName, 'OK', 'Information') | Out-Null; return $false }
    $sync.Progress = -1
    $sync.Errors.Clear()
    Write-UiLog ''
    Write-UiLog ("════════ {0} ════════" -f $Label)
    $code = $TaskLibrary.ToString() + "`n" + "try { $Action } catch { Add-TaskError -Title 'Erreur inattendue pendant l''opération' -Cause `$_.Exception.Message -Effect 'L''opération s''est arrêtée. Envoie un rapport de bug pour que ce soit corrigé.' -Bug `$_ }"
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'; $rs.ThreadOptions = 'ReuseThread'; $rs.Open()
    $rs.SessionStateProxy.SetVariable('sync', $sync)
    $rs.SessionStateProxy.SetVariable('AppInfo', $AppInfo)
    $ps = [powershell]::Create(); $ps.Runspace = $rs; [void]$ps.AddScript($code)
    $sync.Cancel = $false
    try { [AeroxNative]::StopScan = $false } catch {}
    $script:Job = @{ PS = $ps; RS = $rs; Handle = $ps.BeginInvoke(); Label = $Label; Action = $Action; Start = (Get-Date); OnDone = $OnDone }
    Set-Busy $true $Label
    return $true
}

function Start-Background([string]$Code) {
    $rs = [runspacefactory]::CreateRunspace(); $rs.Open()
    $rs.SessionStateProxy.SetVariable('sync', $sync); $rs.SessionStateProxy.SetVariable('AppInfo', $AppInfo)
    $ps = [powershell]::Create(); $ps.Runspace = $rs; [void]$ps.AddScript($TaskLibrary.ToString() + "`n" + $Code)
    # Libéré par la boucle de l'interface dès que c'est fini (sinon chaque tâche resterait en mémoire)
    [void]$script:Zombies.Add(@{ PS = $ps; RS = $rs; Handle = $ps.BeginInvoke() })
}

# ---------------------------------------------------------------- Vérification après chaque réparation
# Le problème n'est marqué « réglé » que si le contrôle de sa catégorie ne le trouve plus.
# (Pas pour les problèmes où l'on choisit soi-même quoi faire : programmes au démarrage, logiciels…)
function Start-IssueCheck($I) {
    # Plantages, écrans bleus, arrêts brutaux : ils sont dans l'historique de Windows et ne disparaissent pas d'un coup.
    # On note l'heure de la réparation : à partir de maintenant, seuls les nouveaux comptent (vérifiable aux prochains diagnostics).
    if ($I.Id -in 'crash', 'bsod', 'power41', 'tdr', 'hang', 'diskbad', 'diskretry', 'ntfs') { Set-StabilityFixed $I.Id; return $false }
    if (-not $I.Id -or $I.UiFix -or $I.OpenOnly -or -not (Get-DiagCheckFn $I.Cat)) { return $false }
    $I.VerifyAt = Get-Date
    Start-Background ("Test-IssueGone {0} {1}" -f (ConvertTo-PsLiteral $I.Cat), (ConvertTo-PsLiteral $I.Id))
    return $true
}
function Set-StabilityFixed([string]$Id) {
    if (-not ($script:Settings.StabilityFixAt -is [hashtable])) { $script:Settings.StabilityFixAt = @{} }
    $script:Settings.StabilityFixAt[$Id] = (Get-Date).ToString('s')
    Save-Settings
    Write-UiLog "   Les plantages déjà passés restent dans l'historique de Windows : à partir de maintenant, AEROX ne compte que les nouveaux. S'il y en a encore, le prochain diagnostic te le dira."
}
function Receive-IssueChecks {
    $line = $null; $changed = $false
    while ($sync.Verify.TryDequeue([ref]$line)) {
        $p = $line.Split('|', 3)
        $i = @($script:Diag.Issues | Where-Object { $_.Id -eq $p[0] -and $_.Status -eq 'verifying' }) | Select-Object -First 1
        if (-not $i) { continue }
        $changed = $true
        if ($p[1] -eq 'still') {
            $i.Status = 'open'; $i.VerifyFailed = $true
            Add-StatsEvent ("pascorrige:" + (ConvertTo-StatsId $i.Id))
            Write-UiLog ("⚠ Vérifié : « {0} » est toujours là, la réparation n'a pas suffi. Regarde « Voir comment faire » ou envoie un rapport de bug." -f $i.Title)
        } else {
            $i.Status = 'done'
            if ($p[1] -eq 'gone') { Add-StatsEvent ("corrige:" + (ConvertTo-StatsId $i.Id)) }
            Write-UiLog $(if ($p[1] -eq 'gone') { "✅ Vérifié : « $($i.Title) » est réglé." } else { "✅ Corrigé : $($i.Title)" })
        }
    }
    # Sécurité : une vérification sans réponse au bout de 3 minutes compte comme faite
    if ($script:Diag) {
        foreach ($i in @($script:Diag.Issues | Where-Object { $_.Status -eq 'verifying' -and $_.VerifyAt -and ((Get-Date) - $_.VerifyAt).TotalMinutes -ge 3 })) { $i.Status = 'done'; $changed = $true; Write-UiLog ("✅ Corrigé : " + $i.Title) }
    }
    if ($changed) { Update-DiagBadge; Update-HomeStats; if ($script:Cur -in 'diag', 'home') { Refresh-Page } }
}

# Une analyse arrêtée qui reste coincée dans un appel de Windows plus de 8 secondes : on rend la main tout de suite,
# elle finit de s'arrêter toute seule en arrière-plan (elle ne fait que lire, rien n'est modifié)
$script:Zombies = New-Object System.Collections.ArrayList
function Abandon-Job {
    $job = $script:Job
    $script:Job = $null
    [void]$script:Zombies.Add($job)
    Flush-Queue
    $sync.Errors.Clear()
    $sync.Cancel = $false
    Set-Busy $false
    Write-UiLog ("⏹ Arrêté à ta demande : {0} (Windows termine sa dernière étape en arrière-plan, tu peux continuer)" -f $job.Label)
    $script:FixQueue.Clear(); $script:QueueRunning = $false
    if ($script:FixingIssue) { $script:FixingIssue.Status = 'open'; $script:FixingIssue = $null }
    if ($job.Action -eq 'Invoke-Diagnostic') { $script:Scanning = $false }
    if ($script:Wiz) { $script:Wiz = $null; Write-UiLog "⏹ Optimisation complète arrêtée à ta demande. Tu peux la relancer quand tu veux depuis l'accueil." }
    try { Update-HomeStats; Update-DiagBadge; Refresh-Page } catch {}
}
function Complete-Job {
    $job = $script:Job
    $cancelled = [bool]$sync.Cancel
    try { [void]$job.PS.EndInvoke($job.Handle) } catch { if (-not $cancelled) { Write-UiLog ("❌ " + $_.Exception.Message); Write-Bug -Context "Tâche $($job.Label)" -ErrorRecord $_ } }
    Flush-Queue
    $errs = @($sync.Errors.ToArray())
    $sync.Errors.Clear()
    $dur = '{0:mm\:ss}' -f ((Get-Date) - $job.Start)
    try { $job.PS.Dispose(); $job.RS.Close(); $job.RS.Dispose() } catch {}
    $script:Job = $null
    if ((@($AppInfo.StartupOff) -join '|') -ne (@($script:Settings.StartupOff) -join '|')) { Save-Settings }
    $hardStop = $cancelled -and ("$($job.Action)".Trim() -match $script:HardCancel)
    if ($hardStop) { $errs = @() }
    Write-UiLog $(if ($cancelled) { "⏹ Arrêté à ta demande : $($job.Label) (durée $dur)" } elseif ($errs.Count) { "⚠ Terminé avec $($errs.Count) problème(s) : $($job.Label) (durée $dur)" } else { "✅ Terminé : $($job.Label) (durée $dur)" })
    $sync.Cancel = $false
    Set-Busy $false
    if ($cancelled) {
        $script:FixQueue.Clear()
        if ($script:FixingIssue) {
            # Arrêt « doux » : l'étape en cours est allée au bout, on garde son vrai résultat
            $script:FixingIssue.Status = $(if ($hardStop -or $errs.Count -or $script:FixingIssue.OpenOnly) { 'open' } else { 'done' })
            $script:FixingIssue = $null
        }
        foreach ($e in @($script:PendingErrors.ToArray())) { $errs += $e }
        $script:PendingErrors.Clear(); $script:QueueRunning = $false
        if ($job.Action -eq 'Invoke-Diagnostic') { $script:Scanning = $false }
        if ($script:Wiz) { $script:Wiz = $null; Write-UiLog "⏹ Optimisation complète arrêtée à ta demande. Tu peux la relancer quand tu veux depuis l'accueil." }
        Update-HomeStats; Update-DiagBadge; Refresh-Page
        if ($errs.Count) { Show-ErrorDialog $errs $job.Label }
        if ($sync.NeedReboot) {
            $sync.NeedReboot = $false
            $r = [System.Windows.MessageBox]::Show("Un redémarrage est nécessaire pour terminer.`n`nEnregistre ton travail en cours, puis clique sur « Oui » pour redémarrer maintenant.", $AppName, 'YesNo', 'Question')
            if ($r -eq 'Yes') { Restart-Computer -Force }
        }
        return
    }

    if ($job.Action -eq 'Invoke-Diagnostic') {
        $script:Scanning = $false
        if ($sync.Diag) { $script:Diag = $sync.Diag; $script:OpenSteps = @{}; Update-Bilan }
    }
    if ($script:FixingIssue) {
        if ($script:FixingIssue.OpenOnly) {
            $script:FixingIssue.Status = 'open'
            Write-UiLog ("→ Page ouverte pour « {0} ». Une fois fait, relance le diagnostic pour vérifier." -f $script:FixingIssue.Title)
        } else {
            $fi = $script:FixingIssue
            $fi.VerifyFailed = $false
            if ($errs.Count) { $fi.Status = 'open'; Add-StatsEvent ("echec:" + (ConvertTo-StatsId $fi.Id)) }
            elseif ($sync.NeedReboot) { $fi.Status = 'done'; Write-UiLog ("✅ Corrigé : {0} (effectif après le redémarrage)" -f $fi.Title) }
            elseif (Start-IssueCheck $fi) { $fi.Status = 'verifying'; Write-UiLog ("🔎 Vérification : {0}…" -f $fi.Title) }
            else { $fi.Status = 'done'; Write-UiLog ("✅ Corrigé : " + $fi.Title) }
        }
        $script:FixingIssue = $null
    }
    Update-HomeStats
    Update-DiagBadge
    if ($script:QueueRunning) {
        foreach ($e in $errs) { [void]$script:PendingErrors.Add($e) }
        if (Start-NextQueued) { Refresh-Page; return }
        $errs = @($script:PendingErrors.ToArray()); $script:PendingErrors.Clear()
        $left = @(Get-OpenIssues).Count
        Write-UiLog $(if ($left) { "Réparations terminées. Il reste $left chose(s) à faire toi-même (voir « Voir comment faire »)." } else { "Réparations terminées : tout est réglé !" })
    }
    if ($job.OnDone -eq 'tools') { $script:ToolStAt = $null; Stop-Monitoring; if (Test-MonitorNeeded) { Start-Sensors; Start-FpsCounter } }
    if ($job.OnDone -eq 'undo' -and $script:UndoId) {
        if (-not $errs.Count) { Set-ChangeUndone $script:UndoId; Write-UiLog ("↩ Annulé : " + $script:UndoTitle) }
        $script:UndoId = $null
    }
    Refresh-Page
    if ($job.Action -match '^(Invoke-Diagnostic|Get-SlowReport|Get-LagReport)') { Start-Background 'Send-Stats' }
    try {
    # Erreurs d'abord, puis la fenêtre de résultat quand même : une erreur mineure pendant une analyse ne doit pas cacher
    # ce qui a été trouvé (relecture Gemini n° 4)
    if ($errs.Count) { Show-ErrorDialog $errs $job.Label }
    if ($job.OnDone -eq 'appdialog' -and $sync.AppList) { Show-AppUpdatesDialog $script:AppsIssue; $script:AppsIssue = $null }
    elseif ($job.OnDone -eq 'cleandialog' -and $sync.CleanList) { Show-CleanDialog $script:CleanIssue; $script:CleanIssue = $null }
    elseif ($job.OnDone -eq 'spacedialog' -and $sync.SpaceScan) { Show-SpaceDialog }
    elseif ($job.OnDone -eq 'slowdialog' -and $sync.SlowReport) { Show-SlowDialog }
    elseif ($job.OnDone -eq 'biospage' -and $sync.BiosUrl) { [void](Open-Url $sync.BiosUrl.Url) }
    elseif ($job.OnDone -eq 'bgdialog' -and $null -ne $sync.BgItems) { Show-BgDialog $script:BgIssue; $script:BgIssue = $null }
    elseif ($job.OnDone -eq 'dupdialog' -and $null -ne $sync.Dupes) { Show-DuplicatesDialog }
    elseif ($job.OnDone -eq 'browserdialog' -and $null -ne $sync.BrowserReport) { Show-BrowserDialog $script:BrowserIssue; $script:BrowserIssue = $null }
    elseif ($job.OnDone -eq 'driverdialog' -and $sync.DriverScan) { Show-DriverDialog $script:DrvIssue; $script:DrvIssue = $null }
    elseif ($job.OnDone -eq 'uninstalldialog' -and $sync.InstalledApps) { Show-UninstallDialog $script:UniIssue; $script:UniIssue = $null }
    elseif ($job.OnDone -eq 'selfupdate' -and $sync.UpdateReady) { $script:Wiz = $null; Complete-SelfUpdate; return }
    } catch {
        # Une fenêtre qui plante ne doit pas bloquer l'optimisation complète : on passe à l'étape suivante
        Write-Bug -Context "Fenêtre après « $($job.Label) »" -ErrorRecord $_
        Write-UiLog ("⚠ " + $_.Exception.Message)
    }
    if ($sync.NeedReboot -and -not $script:Job -and -not $script:Wiz) {
        $sync.NeedReboot = $false
        $r = [System.Windows.MessageBox]::Show("Un redémarrage est nécessaire pour terminer.`n`nEnregistre ton travail en cours, puis clique sur « Oui » pour redémarrer maintenant.", $AppName, 'YesNo', 'Question')
        if ($r -eq 'Yes') { Restart-Computer -Force }
    }
    if ($script:Wiz -and -not $script:Job) { Step-Wizard }
}

# ---------------------------------------------------------------- Optimisation complète : parcours guidé
# Chaque étape réutilise l'outil existant (tu choisis dans sa fenêtre ; fermer la fenêtre = passer l'étape).
# Le parcours avance tout seul à la fin de chaque tâche (Complete-Job appelle Step-Wizard).
$script:Wiz = $null
$script:WizSteps = @(
    @{ T = "Point de restauration (sécurité)"; Run = { [void](Start-AeroxTask 'New-RestorePoint' 'Point de restauration') } },
    @{ T = "Diagnostic complet"; Run = { Start-Diagnostic } },
    @{ T = "Programmes au démarrage"; Run = { Show-StartupDialog $null } },
    @{ T = "Programmes cachés en fond"; Run = { Start-BgList $null } },
    @{ T = "Logiciels inutiles"; Run = { Start-UninstallList $null } },
    @{ T = "Nettoyage approfondi"; Run = { Start-CleanAnalysis $null } },
    @{ T = "Mises à jour des logiciels"; Run = { Start-AppUpdatesList $null } }
)
function Start-Optimize {
    if ($script:Job -or $script:Wiz) { [System.Windows.MessageBox]::Show("Une opération est déjà en cours, attends qu'elle se termine.", $AppName, 'OK', 'Information') | Out-Null; return }
    $steps = (@(for ($i = 0; $i -lt $script:WizSteps.Count; $i++) { "  {0}. {1}" -f ($i + 1), $script:WizSteps[$i].T }) -join "`n")
    $msg = "Optimisation complète : AEROX enchaîne les étapes une par une.`n`n$steps`n`nTu gardes la main : à chaque étape, tu vois ce qui est proposé et tu choisis. Ferme une fenêtre pour passer l'étape, ou clique sur « Annuler » en bas pour tout arrêter.`n`nCompte 10 à 30 minutes selon le PC. À la fin, un redémarrage, puis le bilan avant / après.`n`nCommencer ?"
    if ([System.Windows.MessageBox]::Show($msg, $AppName, 'YesNo', 'Question') -ne 'Yes') { return }
    $script:Wiz = @{ Index = 0 }
    Write-UiLog ''
    Write-UiLog "════════ Optimisation complète ════════"
    Step-Wizard
}
function Step-Wizard {
    while ($script:Wiz -and -not $script:Job) {
        $i = [int]$script:Wiz.Index
        if ($i -ge $script:WizSteps.Count) { Complete-Wizard; return }
        $script:Wiz.Index = $i + 1
        $st = $script:WizSteps[$i]
        Write-UiLog ("▶ Optimisation, étape {0}/{1} : {2}" -f ($i + 1), $script:WizSteps.Count, $st.T)
        try { & $st.Run } catch { Write-Bug -Context "Optimisation / $($st.T)" -ErrorRecord $_; Write-UiLog ("   ⚠ Étape passée : " + $_.Exception.Message) }
    }
}
function Complete-Wizard {
    $script:Wiz = $null
    $sync.NeedReboot = $false
    $script:Settings.PostOptimize = $true; Save-Settings
    Write-UiLog "✅ Optimisation complète terminée."
    Refresh-Page
    $r = [System.Windows.MessageBox]::Show("Optimisation terminée !`n`nRedémarre maintenant pour que tout s'applique (programmes au démarrage et en fond, mises à jour).`n`nAu prochain lancement d'AEROX PC Care, le diagnostic se relancera tout seul et tu verras le bilan avant / après.`n`nEnregistre ton travail en cours, puis clique sur « Oui » pour redémarrer maintenant.", $AppName, 'YesNo', 'Question')
    if ($r -eq 'Yes') { Restart-Computer -Force }
}

function Start-NextQueued {
    while ($script:FixQueue.Count -gt 0) {
        $item = $script:FixQueue.Dequeue()
        if ($item.Issue) { if ($item.Issue.Status -eq 'done') { continue }; $item.Issue.Status = 'fixing'; $script:FixingIssue = $item.Issue }
        if (Start-AeroxTask $item.Action $item.Label) { return $true }
    }
    $script:QueueRunning = $false
    return $false
}

function Confirm-Box([string]$Text) { return ([System.Windows.MessageBox]::Show($Text, $AppName, 'YesNo', 'Question') -eq 'Yes') }

function Start-Diagnostic {
    if ($script:Job) { return }
    $script:Scanning = $true; $script:LastScanVer = -1
    $sync.ScanOrder = @(); $sync.Diag = $null
    if (Start-AeroxTask 'Invoke-Diagnostic' 'Diagnostic complet') { Go-Page 'diag' } else { $script:Scanning = $false }
}

function Invoke-UiCommand($T) {
    try {
        switch ($T.Kind) {
            'action' {
                $d = $T.Def
                if ($d.C -and -not (Confirm-Box $d.C)) { return }
                [void](Start-AeroxTask $d.A $d.T)
            }
            'go' { if ($T.Def.Go -eq 'diag' -and -not $script:Diag -and -not $script:Scanning) { Start-Diagnostic } else { Go-Page $T.Def.Go } }
            'startdiag' { Start-Diagnostic }
            'fix' {
                $i = $T.Issue
                if ($i.UiFix -eq 'startup') { Show-StartupDialog $i; return }
                if ($i.UiFix -eq 'display') { $d = @(Get-Displays) | Where-Object { $_.Device -eq $i.Display.Device } | Select-Object -First 1; Set-DisplayWithConfirm $d $i; return }
                if ($i.UiFix -eq 'apps') { Start-AppUpdatesList $i; return }
                if ($i.UiFix -eq 'clean') { Start-CleanAnalysis $i; return }
                if ($i.UiFix -eq 'uninstall') { Start-UninstallList $i; return }
                if ($i.UiFix -eq 'drivers') { Start-DriverCheck $i; return }
                if ($i.UiFix -eq 'bgitems') { Start-BgList $i; return }
                if ($i.UiFix -eq 'browser') { Start-BrowserCheck $i; return }
                if ($i.Confirm -and -not (Confirm-Box $i.Confirm)) { return }
                $i.Status = 'fixing'; $script:FixingIssue = $i
                if (-not (Start-AeroxTask $i.FixAction $i.FixLabel)) { $i.Status = 'open'; $script:FixingIssue = $null }
                Refresh-Page
            }
            'fixall' {
                # Les corrections qui demandent un accord (réseau, DNS...) se font une par une, jamais en lot
                $list = @(Get-OpenIssues | Where-Object { $_.FixLabel -and -not $_.UiFix -and -not $_.OpenOnly -and -not $_.Confirm -and $_.Id -notin 'uptime', 'pending' })
                if (-not $list.Count) { return }
                $txt = "Réparer automatiquement $($list.Count) problème(s) ?`n`n" + (($list | ForEach-Object { "• " + $_.Title }) -join "`n") +
                       "`n`nUn point de restauration est créé avant. Tes fichiers perso ne sont pas touchés. Certaines réparations peuvent prendre du temps."
                if (-not (Confirm-Box $txt)) { return }
                $script:FixQueue.Clear(); $script:PendingErrors.Clear()
                if (-not ($list | Where-Object { $_.Id -eq 'restore' })) { $script:FixQueue.Enqueue(@{ Issue = $null; Action = 'New-RestorePoint'; Label = 'Point de restauration' }) }
                foreach ($i in $list) { $script:FixQueue.Enqueue(@{ Issue = $i; Action = $i.FixAction; Label = $i.FixLabel }) }
                $script:QueueRunning = $true
                [void](Start-NextQueued)
                Refresh-Page
            }
            'steps' { $script:OpenSteps[$T.Key] = -not [bool]$script:OpenSteps[$T.Key]; Refresh-Page }
            'ignore' {
                $x = $T.Issue
                if (Confirm-Box ("Ne plus signaler « $($x.Title) » ?`n`nCette alerte ne comptera plus dans les problèmes ni dans la note du diagnostic. Tu la retrouveras tout en bas du diagnostic, dans « Ignoré à ta demande », pour la réactiver quand tu veux.")) {
                    $script:Settings.IgnoredIssues = @($script:Settings.IgnoredIssues | Where-Object { $_.Id -ne $x.Id }) + @(@{ Id = $x.Id; Title = $x.Title })
                    Save-Settings
                    $script:Diag.Issues = @($script:Diag.Issues | Where-Object { $_ -ne $x })
                    $script:Diag.Ignored = @($script:Diag.Ignored) + @($x)
                    Write-UiLog ("🔕 Ne sera plus signalé : " + $x.Title)
                    Update-HomeStats; Update-DiagBadge; Refresh-Page
                }
            }
            'unignore' {
                $x = $T.Issue
                $script:Settings.IgnoredIssues = @($script:Settings.IgnoredIssues | Where-Object { $_.Id -ne $x.Id })
                Save-Settings
                $script:Diag.Ignored = @($script:Diag.Ignored | Where-Object { $_ -ne $x })
                if ($x.ContainsKey('Status')) { $x.Status = 'open'; $script:Diag.Issues = @($script:Diag.Issues) + @($x) }
                Write-UiLog ("🔔 De nouveau signalé : " + $x.Title + " (relance le diagnostic pour tout revoir)")
                Update-HomeStats; Update-DiagBadge; Refresh-Page
            }
            'done' {
                $T.Issue.Status = 'done'; Write-UiLog ("✅ Marqué comme fait : " + $T.Issue.Title)
                # Problème lu dans l'historique de Windows (extinctions, plantages…) : « c'est fait » = seuls les nouveaux comptent désormais
                if ($T.Issue.Id -in 'crash', 'bsod', 'power41', 'tdr', 'hang', 'diskbad', 'diskretry', 'ntfs') { Set-StabilityFixed $T.Issue.Id }
                Update-DiagBadge; Refresh-Page
            }
            'openurl' { [void](Open-Url $T.Url) }
            'errfix' { }
            'dlg' { }
            'ui' {
                switch ($T.Def.UI) {
                    'report' { Show-BugReport '' }
                    'review' { Show-ReviewDialog }
                    'whatsnew' { Show-WhatsNew '' }
                    'lag' { Start-LagReport }
                    'share' { Copy-ShareMessage }
                    'discord' {
                        if ($sync.DiscordUrl) { if (Open-Url $sync.DiscordUrl) { Write-UiLog "💬 Invitation au serveur Discord ouverte dans ton navigateur." } }
                        else { Write-UiLog "💬 Le serveur Discord de la communauté ouvre bientôt : le bouton marchera dès que le lien sera prêt (sans mise à jour)." }
                    }
                    'stats-toggle' {
                        $off = -not [bool]$script:Settings.StatsOff
                        if (-not $off -or (Confirm-Box "Ne plus envoyer de statistiques anonymes ?`n`nElles ne contiennent que des compteurs (version d'AEROX, types de problèmes trouvés, lenteurs non reconnues), jamais ton nom, celui du PC ni tes fichiers. Elles aident le développeur à corriger d'abord ce qui touche le plus de monde.")) {
                            $script:Settings.StatsOff = $off; Save-Settings
                            if ($off) { try { $AppInfo.StatsQueue.Clear(); Save-StatsQueue } catch {} }
                            Write-UiLog $(if ($off) { "📊 Statistiques anonymes désactivées." } else { "📊 Statistiques anonymes activées. Merci !" })
                            Refresh-Page
                        }
                    }
                    'review-later' { $script:Settings.ReviewSnooze = (Get-Date).AddDays(14).ToString('s'); Save-Settings; Refresh-Page }
                    'review-never' { $script:Settings.ReviewNever = $true; Save-Settings; Refresh-Page }
                    'remotehelp' { Show-RemoteHelpDialog }
                    'history' { Show-HistoryDialog }
                    'display-fix' { $d = @(Get-Displays) | Where-Object { $_.Device -eq $T.Def.Device } | Select-Object -First 1; Set-DisplayWithConfirm $d $null }
                    'speedtest' { Show-SpeedTestDialog }
                    'sys-refresh' { $sync.SysInfo = $null; Refresh-Page }
                    'bios-site' { [void](Start-AeroxTask 'Find-BiosPage' 'Page du BIOS' 'biospage') }
                    'bilan-reset' { Reset-Bilan }
                    'battery-report' { [void](Start-AeroxTask 'Open-BatteryReport' 'Rapport de la batterie') }
                    'bios-reboot' { Restart-ToBios }
                    'pc-health' { [void](Open-Url 'https://aka.ms/GetPCHealthCheckApp') }
                    'selfupdate' { Start-SelfUpdate }
                    'ov-alert' { $script:Settings.Overlay.AlertOn = -not [bool]$script:Settings.Overlay.AlertOn; Save-Settings; Refresh-Page }
                    'startup' { Show-StartupDialog $null }
                    'slow' {
                        # Les outils de mesure d'AEROX (capteurs, compteur de FPS) s'arrêtent pendant l'analyse pour ne pas la fausser
                        if (-not $script:GameSess -and -not $script:GameProbe) { try { Stop-Monitoring } catch {} }
                        [void](Start-AeroxTask 'Get-SlowReport' 'Analyse des lenteurs' 'slowdialog')
                    }
                    'bgitems' { Start-BgList $null }
                    'dupes' { Start-DuplicateScan }
                    'browser' { Start-BrowserCheck $null }
                    'optimize' { Start-Optimize }
                    'appupdates' { Start-AppUpdatesList $null }
                    'deepclean' { Start-CleanAnalysis $null }
                    'uninstall' { Start-UninstallList $null }
                    'space' { Start-SpaceScan }
                    'drivers' { Start-DriverCheck $null }
                    'inst-pm' { [void](Start-AeroxTask 'Install-PresentMon' 'Installation du compteur de FPS' 'tools') }
                    'inst-lhm' { [void](Start-AeroxTask 'Install-SensorLib' 'Installation du module de températures' 'tools') }
                    'uninst-lhm' { Start-ToolUninstall 'Uninstall-SensorLib' 'le module de températures' "Les températures avancées (processeur, carte graphique, consommation) ne seront plus affichées, ni dans l'overlay ni dans le suivi des parties." }
                    'uninst-pm' { Start-ToolUninstall 'Uninstall-PresentMon' 'le compteur de FPS' "Les FPS ne seront plus mesurés : plus de FPS dans l'overlay, et le suivi des parties n'aura plus de FPS ni de saccades." }
                    'uninst-pawn' { Start-ToolUninstall 'Uninstall-PawnIO' 'le pilote PawnIO' "La température du processeur ne sera plus lue (celle de la carte graphique oui, si le module de températures reste installé)." }
                    'inst-pawn' {
                        if (Confirm-Box "Installer le pilote PawnIO ?`n`nC'est un petit pilote signé, utilisé par les logiciels de monitoring connus (LibreHardwareMonitor, FanControl…) pour lire la température du processeur. Il se désinstalle comme un logiciel normal.") {
                            [void](Start-AeroxTask 'Install-PawnIO' 'Installation du pilote PawnIO' 'tools')
                        }
                    }
                    'game-track' { Set-GamingOption 'track' }
                    'game-tray' { Set-GamingOption 'tray' }
                    'game-autostart' { Set-GamingOption 'autostart' }
                    'game-sheet' { Show-GameDialog $T.Def.Key }
                    'game-tab' { $script:GameTab = $T.Def.Tab; Refresh-Page }
                    'ov-toggle' { Show-Overlay (-not ($script:Ov -and $script:Ov.IsVisible)); Refresh-Page }
                    'ov-edit' { Set-OverlayEdit (-not $script:OvEdit); Refresh-Page }
                    'ov-corner' { Set-OverlayCorner $T.Def.Corner }
                    'logs' { Start-Process explorer.exe $LogDir }
                    'checkupdate' {
                        if (-not $GitHubRepo) { [System.Windows.MessageBox]::Show("La recherche de mise à jour n'est pas encore configurée dans cette version.", $AppName, 'OK', 'Information') | Out-Null; return }
                        $script:ManualUpdateCheck = $true; $sync.UpdateDone = $false
                        Write-UiLog "Recherche d'une nouvelle version d'AEROX PC Care..."
                        Start-Background 'Find-AppUpdate'
                    }
                }
            }
        }
    } catch {
        Write-UiLog ("❌ " + $_.Exception.Message)
        Write-Bug -Context "Interface ($($T.Kind))" -ErrorRecord $_
    }
}

# ---------------------------------------------------------------- Fréquence de l'écran (avec retour automatique)
function Set-DisplayWithConfirm($d, $Issue) {
    if (-not $d) { return }
    if ($script:Job) { [System.Windows.MessageBox]::Show("Une opération est en cours, attends qu'elle se termine.", $AppName, 'OK', 'Information') | Out-Null; return }
    $prev = [int]$d.Hz; $target = [int]$d.MaxHz
    if ($target -le $prev) { Write-UiLog ("{0} est déjà à {1} Hz." -f $d.Name, $prev); if ($Issue) { $Issue.Status = 'done'; Update-DiagBadge; Refresh-Page }; return }
    # Essai SANS enregistrer : si le PC est éteint pendant l'essai, Windows redémarre avec l'ancien réglage
    $r = [AeroxDisplay]::SetFrequency($d.Device, $target, $false)
    if ($r -ne 0) {
        Write-UiLog ("❌ Windows a refusé de régler {0} à {1} Hz (code {2})." -f $d.Name, $target, $r)
        [System.Windows.MessageBox]::Show(("Windows a refusé de passer {0} à {1} Hz (code {2}).`n`nCauses fréquentes : un câble qui ne supporte pas cette fréquence (il faut du DisplayPort ou du HDMI 2.0 minimum), ou le pilote de la carte graphique.`n`nTu peux aussi essayer dans Paramètres > Affichage > Affichage avancé." -f $d.Name, $target, $r), $AppName, 'OK', 'Warning') | Out-Null
        return
    }
    $timer.Stop()   # aucune autre fenêtre ne doit s'ouvrir pendant l'essai
    $w = New-Dialog "$AppName : écran" 480
    $script:HzWin = $w; $script:HzKeep = $false; $script:HzLeft = 15; $script:HzPrev = $prev; $script:HzDev = $d.Device; $script:HzReverted = $false
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = Th 24 22 24 20
    Add-Child $sp (New-Text ("{0} est maintenant à {1} Hz" -f $d.Name, $target) 17 '#FFFFFF' 'Bold')
    $t = New-Text "L'image s'affiche bien ? Si tu ne cliques sur rien, l'ancien réglage revient tout seul." 13 '#A9B0C2'; $t.Margin = Th 0 6 0 10; Add-Child $sp $t
    $script:HzCount = New-Text ("Retour à {0} Hz dans 15 s" -f $prev) 13 '#FFB547' 'SemiBold'; Add-Child $sp $script:HzCount
    $row = New-Object System.Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'; $row.HorizontalAlignment = 'Right'; $row.Margin = Th 0 16 0 0
    $bBack = New-Object System.Windows.Controls.Button; $bBack.Content = ("Revenir à {0} Hz" -f $prev); $bBack.Style = $window.FindResource('ActionBtn'); $bBack.Margin = Th 0 0 8 0
    $bKeep = New-Object System.Windows.Controls.Button; $bKeep.Content = 'Garder'; $bKeep.Style = $window.FindResource('PrimaryBtn')
    Add-Child $row $bBack; Add-Child $row $bKeep; Add-Child $sp $row
    $bKeep.Add_Click({ $script:HzKeep = $true; $script:HzWin.Close() })
    $bBack.Add_Click({ $script:HzKeep = $false; $script:HzWin.Close() })
    $script:HzTimer = New-Object System.Windows.Threading.DispatcherTimer; $script:HzTimer.Interval = [TimeSpan]::FromSeconds(1)
    $script:HzTimer.Add_Tick({
        $script:HzLeft--
        $script:HzCount.Text = ("Retour à {0} Hz dans {1} s" -f $script:HzPrev, $script:HzLeft)
        if ($script:HzLeft -le 0) {
            $script:HzTimer.Stop()
            # Retour immédiat, sans attendre la fermeture de la fenêtre
            if (-not $script:HzReverted) { [void][AeroxDisplay]::SetFrequency($script:HzDev, $script:HzPrev, $false); $script:HzReverted = $true }
            $script:HzWin.Close()
        }
    })
    $w.Content = $sp
    $script:HzTimer.Start()
    try { [void]$w.ShowDialog() } finally { $script:HzTimer.Stop(); $timer.Start() }
    if (-not $script:HzKeep) {
        if (-not $script:HzReverted) { [void][AeroxDisplay]::SetFrequency($d.Device, $prev, $false) }
        Write-UiLog ("↩ {0} remis à {1} Hz." -f $d.Name, $prev)
        return
    }
    # Confirmé : maintenant on enregistre le réglage
    $r2 = [AeroxDisplay]::SetFrequency($d.Device, $target, $true)
    if ($r2 -ne 0) { Write-UiLog ("⚠ Le réglage à {0} Hz n'a pas pu être enregistré (code {1}) : il sera perdu au redémarrage." -f $target, $r2); return }
    Add-Change -Title ("{0} : {1} Hz → {2} Hz" -f $d.Name, $prev, $target) -Detail "Fréquence de rafraîchissement de l'écran." -Undo ("Set-DisplayHz {0} {1}" -f (ConvertTo-PsLiteral $d.Device), $prev)
    Write-UiLog ("✅ {0} réglé à {1} Hz (au lieu de {2} Hz)." -f $d.Name, $target, $prev)
    $hid = "hz" + ($d.Device -replace '\W', '')
    foreach ($x in @(Get-OpenIssues | Where-Object { $_.Id -eq $hid })) { $x.Status = 'done' }
    if ($Issue) { $Issue.Status = 'done' }
    Update-DiagBadge
    Refresh-Page
}

# ---------------------------------------------------------------- Historique des changements
function Show-HistoryDialog {
    $w = New-Dialog "$AppName : historique des changements" 700
    $script:HistWin = $w; $script:HistChoice = $null
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = Th 24 22 24 20
    Add-Child $sp (New-Text "Historique des changements" 18 '#FFFFFF' 'Bold')
    $p = New-Text "Tout ce qu'AEROX PC Care a modifié sur ce PC, du plus récent au plus ancien. Les réglages se remettent comme avant avec « Annuler ». Les nettoyages et désinstallations sont notés pour info." 13 '#A9B0C2'
    $p.Margin = Th 0 6 0 12; Add-Child $sp $p
    $list = New-Object System.Windows.Controls.StackPanel
    $changes = @(Get-Changes 300)
    if (-not $changes.Count) { Add-Child $list (New-Text "Aucun changement pour l'instant." 13 '#8B93A7') }
    foreach ($c in $changes) {
        $row = New-Object System.Windows.Controls.Border; $row.Background = Brush '#171A23'; $row.CornerRadius = Corner 10; $row.Padding = Th 12 9 12 9; $row.Margin = Th 0 0 6 6
        $dp = New-Object System.Windows.Controls.DockPanel
        if ($c.Undone) { $x = New-Pill 'Annulé' '#8B93A7' '#232838'; [System.Windows.Controls.DockPanel]::SetDock($x, 'Right'); Add-Child $dp $x }
        elseif ($c.Undo) {
            $b = New-Object System.Windows.Controls.Button; $b.Content = 'Annuler'; $b.Style = $window.FindResource('ActionBtn'); $b.Tag = $c; $b.VerticalAlignment = 'Center'; $b.Margin = Th 10 0 0 0
            $b.Add_Click({ $script:HistChoice = $this.Tag; $script:HistWin.Close() })
            [System.Windows.Controls.DockPanel]::SetDock($b, 'Right'); Add-Child $dp $b
        } else { $x = New-Pill 'Info' '#8B93A7' '#232838'; [System.Windows.Controls.DockPanel]::SetDock($x, 'Right'); Add-Child $dp $x }
        $t = New-Object System.Windows.Controls.StackPanel
        $h = New-Object System.Windows.Controls.WrapPanel
        $d = New-Text ((Format-Date $c.Date 'dd/MM HH:mm') + '   ') 12 '#7A8399'; $d.VerticalAlignment = 'Center'; Add-Child $h $d
        Add-Child $h (New-Text $c.Title 13.5 $(if ($c.Undone) { '#8B93A7' } else { '#FFFFFF' }) 'SemiBold')
        Add-Child $t $h
        if ($c.Detail) { $dd = New-Text $c.Detail 12 '#8B93A7'; $dd.Margin = Th 0 2 0 0; Add-Child $t $dd }
        Add-Child $dp $t
        $row.Child = $dp; Add-Child $list $row
    }
    $sv = New-Object System.Windows.Controls.ScrollViewer; $sv.VerticalScrollBarVisibility = 'Auto'; $sv.MaxHeight = 430; $sv.Content = $list
    Add-Child $sp $sv
    $bar = New-Object System.Windows.Controls.DockPanel; $bar.Margin = Th 0 14 0 0
    $bClose = New-Object System.Windows.Controls.Button; $bClose.Content = 'Fermer'; $bClose.Style = $window.FindResource('TextBtn')
    [System.Windows.Controls.DockPanel]::SetDock($bClose, 'Right'); Add-Child $bar $bClose
    $bRest = New-Object System.Windows.Controls.Button; $bRest.Content = 'Restauration complète de Windows'; $bRest.Style = $window.FindResource('GhostBtn'); $bRest.HorizontalAlignment = 'Left'
    $bRest.ToolTip = "Remet tout Windows dans l'état d'un point de restauration (tes fichiers perso ne sont pas touchés)."
    Add-Child $bar $bRest; Add-Child $sp $bar
    $bClose.Add_Click({ $script:HistWin.Close() })
    $bRest.Add_Click({ $script:HistChoice = 'restore'; $script:HistWin.Close() })
    $w.Content = $sp
    [void]$w.ShowDialog()

    $c = $script:HistChoice
    if (-not $c) { return }
    if ($c -eq 'restore') { Start-Process 'rstrui.exe'; Write-UiLog "Restauration du système ouverte : choisis un point de restauration et suis les étapes."; return }
    if ($script:Job) { [System.Windows.MessageBox]::Show("Une opération est en cours, attends qu'elle se termine.", $AppName, 'OK', 'Information') | Out-Null; return }
    if (-not (Test-UndoAuthorized $c.Id $c.Undo)) {
        Write-Bug -Context 'Historique' -ErrorRecord ("Action d'annulation refusée (non reconnue) : " + $c.Undo) -Type 'erreur'
        [System.Windows.MessageBox]::Show("Ce changement ne peut pas être annulé automatiquement (l'historique a été modifié ou vient d'une ancienne version).`n`nTu peux utiliser « Restauration complète de Windows » à la place.", $AppName, 'OK', 'Warning') | Out-Null
        return
    }
    if (-not (Confirm-Box ("Annuler ce changement ?`n`n« {0} »" -f $c.Title))) { return }
    $script:UndoId = $c.Id; $script:UndoTitle = $c.Title
    if (-not (Start-AeroxTask ('$script:AeroxUndo = $true; ' + $c.Undo) ("Annulation : " + $c.Title) 'undo')) { $script:UndoId = $null }
}

# ---------------------------------------------------------------- Mise à jour du logiciel
function Start-SelfUpdate {
    $u = $sync.UpdateInfo
    if (-not $u) { return }
    if (-not $u.Setup) { [void](Open-Url $u.Url); return }
    if ($script:Job) { [System.Windows.MessageBox]::Show("Une opération est en cours, attends qu'elle se termine.", $AppName, 'OK', 'Information') | Out-Null; return }
    $notes = ("$($u.Notes)" -replace '\r', '').Trim()
    if ($notes.Length -gt 700) { $notes = $notes.Substring(0, 700) + '…' }
    $txt = "Installer AEROX PC Care $($u.Version) ?`n`n" + $(if ($notes) { "Nouveautés :`n$notes`n`n" } else { '' }) +
           "Le logiciel va télécharger la nouvelle version, se fermer, l'installer et se rouvrir tout seul (quelques secondes). Tes réglages et journaux sont gardés."
    if (-not (Confirm-Box $txt)) { return }
    [void](Start-AeroxTask 'Install-AppUpdate' "Mise à jour d'AEROX PC Care" 'selfupdate')
}
function Complete-SelfUpdate {
    $ready = $sync.UpdateReady; $sync.UpdateReady = $null
    $setup = if ($ready -is [hashtable]) { $ready.Path } else { "$ready" }
    try {
        if ($ready -is [hashtable] -and $ready.Sha) {
            $h = (Get-FileHash -LiteralPath $setup -Algorithm SHA256 -ErrorAction Stop).Hash
            if ($h -ne $ready.Sha.ToUpper()) { throw "Le fichier de mise à jour a été modifié depuis son téléchargement : installation annulée par sécurité." }
        }
        [System.Windows.MessageBox]::Show("La nouvelle version est prête.`n`nAEROX PC Care va se fermer, l'installer et se rouvrir tout seul dans quelques secondes.", $AppName, 'OK', 'Information') | Out-Null
        Start-Process -FilePath $setup -ArgumentList '/S', '/UPDATE'
        Write-UiLog "Installation de la nouvelle version..."
        $script:SelfUpdating = $true
        $script:QuitNow = $true   # même en mode discret, AEROX doit vraiment se fermer pour se mettre à jour
        $window.Close()
    } catch {
        Write-Bug -Context 'Mise à jour du logiciel' -ErrorRecord $_
        [System.Windows.MessageBox]::Show("L'installateur de la mise à jour n'a pas pu démarrer :`n`n$($_.Exception.Message)`n`nTu gardes la version actuelle. Tu peux aussi télécharger AeroxPCCare_Setup.exe sur la page GitHub du logiciel.", $AppName, 'OK', 'Warning') | Out-Null
    }
}

# ---------------------------------------------------------------- Page « Mon PC » : carte mère, BIOS, TPM, Secure Boot
$script:SysWaiting = $false
function Get-BiosKeys([string]$Brand) {
    switch ($Brand) {
        'ASUS' { 'Suppr ou F2' } 'MSI' { 'Suppr' } 'Gigabyte' { 'Suppr' } 'ASRock' { 'F2 ou Suppr' } 'Dell' { 'F2' }
        'HP' { 'Échap puis F10' } 'Lenovo' { 'F1 ou F2 (ou le petit bouton « Novo »)' } 'Acer' { 'F2' } 'Microsoft' { 'maintenir Volume + en allumant' }
        default { 'Suppr, F2 ou F10 (affiché brièvement au démarrage)' }
    }
}
function Open-BiosSupport {
    $i = $sync.SysInfo; if (-not $i) { return }
    $q = "$($i.Model) BIOS"
    if ($i.BrandSite) { $q = "site:$($i.BrandSite) $q" } else { $q = "$($i.Maker) $q support" }
    [void](Open-Url ("https://www.bing.com/search?q=" + [uri]::EscapeDataString($q)))
}
function Restart-ToBios {
    $i = $sync.SysInfo
    $keys = Get-BiosKeys $(if ($i) { $i.Brand } else { '' })
    if ($i -and $i.Uefi -eq $false) {
        [System.Windows.MessageBox]::Show("Ton PC démarre en mode ancien (Legacy) : Windows ne peut pas l'envoyer directement dans le BIOS.`n`nRedémarre-le et appuie plusieurs fois sur $keys dès l'allumage.", $AppName, 'OK', 'Information') | Out-Null
        return
    }
    if (-not (Confirm-Box "Redémarrer maintenant dans le BIOS ?`n`nEnregistre et ferme ton travail avant. Le PC va redémarrer directement sur l'écran du BIOS.`n`nDans le BIOS : déplace-toi avec les flèches ou la souris, F10 = enregistrer et quitter, Échap = quitter sans rien changer.")) { return }
    try {
        $p = Start-Process -FilePath "$env:SystemRoot\System32\shutdown.exe" -ArgumentList '/r', '/fw', '/t', '5' -WindowStyle Hidden -Wait -PassThru
        if ($p.ExitCode -ne 0) { throw "code $($p.ExitCode)" }
        Write-UiLog "Redémarrage vers le BIOS dans 5 secondes..."
    } catch {
        [System.Windows.MessageBox]::Show("Windows n'a pas pu programmer le redémarrage vers le BIOS ($($_.Exception.Message)).`n`nRedémarre le PC et appuie plusieurs fois sur $keys dès l'allumage.", $AppName, 'OK', 'Information') | Out-Null
    }
}

function New-InfoRow([string]$Label, [string]$Value, [string]$Pill = '', [string]$PillKind = '', [string]$Help = '') {
    $box = New-Object System.Windows.Controls.StackPanel; $box.Margin = Th 0 6 0 6
    $dp = New-Object System.Windows.Controls.DockPanel
    if ($Pill) {
        $c = switch ($PillKind) { 'ok' { @('#4ADE80', '#173326') } 'warn' { @('#FFB547', '#3A2C12') } 'bad' { @('#FF6B6B', '#3A1B1B') } default { @('#B9A8FF', '#2A2350') } }
        $p = New-Pill $Pill $c[0] $c[1]; [System.Windows.Controls.DockPanel]::SetDock($p, 'Right'); Add-Child $dp $p
    }
    $l = New-Text $Label 13 '#8B93A7'; $l.Width = 190; $l.VerticalAlignment = 'Center'; [System.Windows.Controls.DockPanel]::SetDock($l, 'Left'); Add-Child $dp $l
    $v = New-Text $Value 14 '#FFFFFF' 'SemiBold'; $v.VerticalAlignment = 'Center'; $v.TextWrapping = 'Wrap'; Add-Child $dp $v
    Add-Child $box $dp
    if ($Help) { $h = New-Text $Help 12.5 '#A9B0C2'; $h.Margin = Th 190 4 0 0; $h.LineHeight = 19; Add-Child $box $h }
    return $box
}

function Build-SystemPage {
    $sp = New-Object System.Windows.Controls.StackPanel
    Build-Header $sp "Mon PC" "Carte mère, version du BIOS, sécurité du démarrage (TPM, Secure Boot) et santé de la batterie sur les portables. Juste des infos : rien n'est modifié ici. Pratique avant d'installer Windows 11, un jeu avec anti-triche (Valorant, Battlefield, Call of Duty...) ou un nouveau processeur."
    $i = $sync.SysInfo
    if (-not $i) {
        if (-not $script:SysWaiting) { $script:SysWaiting = $true; Start-Background 'Get-SystemInfo' }
        Add-Child $sp (New-Text "Lecture des infos du PC..." 14 '#A9B0C2')
        return $sp
    }
    $keys = Get-BiosKeys $i.Brand

    # ---- Carte mère et BIOS
    Add-Child $sp (New-Section 'Carte mère et BIOS')
    $c = New-CardBorder; $cs = New-Object System.Windows.Controls.StackPanel
    Add-Child $cs (New-InfoRow $(if ($i.Custom) { 'Carte mère' } else { 'Modèle du PC' }) ("{0} {1}" -f $(if ($i.Brand) { $i.Brand } else { $i.Maker }), $i.Model))
    if (-not $i.Custom -and $i.BoardModel -and $i.BoardModel -ne $i.Model) { Add-Child $cs (New-InfoRow 'Carte mère' ("{0} {1}" -f $i.BoardMaker, $i.BoardModel)) }
    $age = $i.BiosAgeDays
    $ageTxt = if ($null -eq $age) { '' } elseif ($age -lt 60) { "il y a $age jours" } elseif ($age -lt 730) { "il y a $([math]::Round($age / 30)) mois" } else { "il y a $([math]::Floor($age / 365)) ans" }
    $pill = ''; $pk = ''; $help = ''
    if ($null -ne $age) {
        if ($age -le 365) { $pill = 'Récent'; $pk = 'ok'; $help = "Ton BIOS a moins d'un an : rien à faire." }
        elseif ($age -le 1095) { $pill = 'À vérifier'; $pk = 'warn'; $help = "Ton BIOS a plus d'un an : une version plus récente existe peut-être. Compare ta version avec celle du site du fabricant." }
        else { $pill = 'Ancien'; $pk = 'warn'; $help = "Ton BIOS a plus de 3 ans. Si le fabricant suit encore ton modèle, une mise à jour corrige souvent des bugs, la compatibilité TPM / Secure Boot et la prise en charge des nouveaux processeurs." }
    }
    Add-Child $cs (New-InfoRow 'Version du BIOS' ("{0}{1}" -f $i.BiosVersion, $(if ($i.BiosDate) { "  ·  du " + (Format-Date $i.BiosDate) + " ($ageTxt)" } else { '' })) $pill $pk $help)
    $n = New-Text ("AEROX ne peut pas connaître la dernière version de chaque modèle : le bouton ci-dessous cherche ta page sur le site officiel du fabricant pour comparer." +
        $(if ($i.BrandTool) { "`n" + $i.BrandTool } else { '' }) +
        "`nMets à jour le BIOS seulement si tu en as besoin (TPM, Secure Boot, nouveau processeur, plantages), avec le fichier du site officiel uniquement, et sans jamais couper le courant pendant l'opération.") 12 '#7A8399'
    $n.Margin = Th 0 8 0 10; $n.LineHeight = 19; Add-Child $cs $n
    $bw = New-Object System.Windows.Controls.WrapPanel
    $b = New-Button "Chercher mon BIOS sur le site officiel" 'PrimaryBtn' @{ Kind = 'ui'; Def = @{ UI = 'bios-site' } } $false; $b.Margin = Th 0 0 8 0; Add-Child $bw $b
    $b = New-Button "Redémarrer dans le BIOS" 'ActionBtn' @{ Kind = 'ui'; Def = @{ UI = 'bios-reboot' } } $false; $b.Margin = Th 0 0 8 0; Add-Child $bw $b
    Add-Child $cs $bw
    $c.Child = $cs; Add-Child $sp $c

    # ---- Sécurité du démarrage
    Add-Child $sp (New-Section 'Sécurité du démarrage')
    $c = New-CardBorder; $cs = New-Object System.Windows.Controls.StackPanel
    $tpmName = if ($i.CpuAmd) { "« fTPM » (ou « AMD CPU fTPM »)" } else { "« PTT » (ou « Intel Platform Trust Technology »)" }
    # Mode de démarrage
    if ($i.Uefi -eq $true) { Add-Child $cs (New-InfoRow 'Mode de démarrage' 'UEFI (moderne)' 'OK' 'ok') }
    elseif ($i.Uefi -eq $false) {
        Add-Child $cs (New-InfoRow 'Mode de démarrage' 'Legacy / CSM (ancien)' 'Ancien' 'warn' ("Secure Boot et Windows 11 demandent le mode UEFI. ATTENTION : ne passe pas le BIOS en UEFI tant que le disque est en MBR, sinon Windows ne démarre plus. Il faut d'abord convertir le disque en GPT (outil MBR2GPT de Microsoft, sans perte de données) : à faire après une sauvegarde, idéalement accompagné avec l'aide à distance."))
    } else { Add-Child $cs (New-InfoRow 'Mode de démarrage' 'Inconnu') }
    # Disque
    if ($i.DiskStyle) {
        if ($i.DiskStyle -eq 'GPT') { Add-Child $cs (New-InfoRow 'Disque de Windows' 'GPT (moderne)' 'OK' 'ok') }
        else { Add-Child $cs (New-InfoRow 'Disque de Windows' "$($i.DiskStyle) (ancien)" 'Ancien' 'warn' "Le format MBR empêche le démarrage en UEFI, donc Secure Boot et Windows 11. Il se convertit en GPT sans perte de données avec l'outil MBR2GPT de Microsoft (après une sauvegarde).") }
    }
    # TPM
    if ($i.TpmPresent -and $i.TpmVersion -like '2*') {
        if ($i.TpmReady) { Add-Child $cs (New-InfoRow 'Puce de sécurité (TPM)' ("TPM {0}{1}" -f $i.TpmVersion, $(if ($i.TpmMaker) { "  ·  $($i.TpmMaker)" } else { '' })) 'Activé' 'ok') }
        else { Add-Child $cs (New-InfoRow 'Puce de sécurité (TPM)' "TPM $($i.TpmVersion)" 'Pas prêt' 'warn' "Le TPM est présent mais pas prêt à l'emploi. Ouvre « Sécurité Windows » > « Sécurité de l'appareil » > « Processeur de sécurité » : Windows propose souvent de le préparer. Sinon, vérifie qu'il est bien activé dans le BIOS ($tpmName).") }
    } elseif ($i.TpmPresent -and $i.TpmVersion) {
        Add-Child $cs (New-InfoRow 'Puce de sécurité (TPM)' "TPM $($i.TpmVersion)" 'Trop ancien' 'warn' "Windows 11 demande un TPM 2.0. Sur certains PC, une mise à jour du BIOS ou du firmware TPM du fabricant le fait passer en 2.0.")
    } else {
        Add-Child $cs (New-InfoRow 'Puce de sécurité (TPM)' 'Non détecté' 'Désactivé ?' 'bad' ("Sur presque tous les PC depuis 2017, le TPM est intégré au processeur mais désactivé dans le BIOS.`n1. Clique sur « Redémarrer dans le BIOS » (ou appuie sur $keys au démarrage).`n2. Cherche l'option $tpmName, souvent dans Advanced, Security ou Trusted Computing.`n3. Mets-la sur « Enabled », puis F10 pour enregistrer et redémarrer.`nIntrouvable ? Une mise à jour du BIOS l'ajoute parfois."))
    }
    # Secure Boot
    switch ($i.SecureBoot) {
        'on' { Add-Child $cs (New-InfoRow 'Secure Boot' 'Activé' 'OK' 'ok') }
        'off' {
            $sbHelp = "1. Clique sur « Redémarrer dans le BIOS » (ou appuie sur $keys au démarrage).`n2. Dans Boot ou Security > Secure Boot : mets-le sur « Enabled ». Sur certaines cartes il faut d'abord désactiver « CSM » ou mettre « OS Type » sur « Windows UEFI mode ».`n3. Si l'option est grisée : choisis « Install default Secure Boot keys » (ou « Restore Factory Keys »).`n4. F10 pour enregistrer et redémarrer."
            if ($i.DiskStyle -and $i.DiskStyle -ne 'GPT') { $sbHelp = "Ton disque est en MBR : convertis-le d'abord en GPT (voir plus haut), sinon Windows ne démarrera plus.`n" + $sbHelp }
            Add-Child $cs (New-InfoRow 'Secure Boot' 'Désactivé' 'Désactivé' 'warn' $sbHelp)
        }
        'legacy' { Add-Child $cs (New-InfoRow 'Secure Boot' 'Indisponible en mode Legacy' 'Indisponible' 'warn' "Il faut d'abord passer en mode UEFI (voir « Mode de démarrage »).") }
        default { Add-Child $cs (New-InfoRow 'Secure Boot' 'Inconnu') }
    }
    $c.Child = $cs; Add-Child $sp $c

    # ---- Windows 11
    Add-Child $sp (New-Section 'Windows 11')
    $c = New-CardBorder; $cs = New-Object System.Windows.Controls.StackPanel
    if ($i.Win11) {
        Add-Child $cs (New-InfoRow 'Système' ("{0} {1} (build {2})" -f $i.OsName, $i.OsVersion, $i.OsBuild) 'Windows 11' 'ok')
    } else {
        Add-Child $cs (New-InfoRow 'Système' ("{0} {1} (build {2})" -f $i.OsName, $i.OsVersion, $i.OsBuild) 'Windows 10' 'warn' "Windows 10 ne reçoit plus de mises à jour de sécurité gratuites depuis octobre 2025. Voici ce que Windows 11 demande :")
        $ok = { param($b) if ($b) { @('OK', 'ok') } else { @('Manquant', 'bad') } }
        $r = & $ok ($i.TpmPresent -and $i.TpmVersion -like '2*'); Add-Child $cs (New-InfoRow 'TPM 2.0' $(if ($i.TpmVersion) { "TPM $($i.TpmVersion)" } else { 'non détecté' }) $r[0] $r[1])
        $r = & $ok ($i.Uefi -eq $true); Add-Child $cs (New-InfoRow 'UEFI + Secure Boot possible' $(if ($i.Uefi) { 'UEFI' } else { 'Legacy' }) $r[0] $r[1])
        $r = & $ok ($i.Ram -ge 3.8GB); Add-Child $cs (New-InfoRow 'Mémoire (4 Go minimum)' (Format-Size $i.Ram) $r[0] $r[1])
        $r = & $ok ($i.DiskSize -ge 60GB); Add-Child $cs (New-InfoRow 'Disque (64 Go minimum)' (Format-Size $i.DiskSize) $r[0] $r[1])
        Add-Child $cs (New-InfoRow 'Processeur' $i.Cpu 'À vérifier' 'info' "Microsoft accepte en gros les Intel 8e génération et plus récents, et les AMD Ryzen 2000 et plus récents. L'outil officiel « Contrôle d'intégrité du PC » donne la réponse exacte.")
        $b = New-Button "Outil officiel de Microsoft" 'ActionBtn' @{ Kind = 'ui'; Def = @{ UI = 'pc-health' } } $false; $b.HorizontalAlignment = 'Left'; $b.Margin = Th 0 8 0 0; Add-Child $cs $b
    }
    $c.Child = $cs; Add-Child $sp $c

    # ---- Matériel
    Add-Child $sp (New-Section 'Matériel')
    $c = New-CardBorder; $cs = New-Object System.Windows.Controls.StackPanel
    Add-Child $cs (New-InfoRow 'Processeur' $i.Cpu)
    $drv = @($i.GpuDrivers)
    if ($drv.Count) {
        foreach ($g in $drv) {
            $ver = $g.Version + $(if ($g.Installed) { "  ·  installé le " + (Format-Date $g.Installed) } elseif ($g.Date) { "  ·  pilote daté du " + (Format-Date $g.Date) } else { '' })
            $pill = switch ($g.Status) { 'ok' { 'À jour' } 'old' { 'Mise à jour dispo' } 'none' { 'Pas de pilote' } default { '' } }
            $pk = switch ($g.Status) { 'ok' { 'ok' } 'old' { 'warn' } 'none' { 'bad' } default { '' } }
            $help = ''
            if ($g.Vendor -eq 'NVIDIA' -and $g.Latest) {
                $help = "Dernière version NVIDIA : $($g.Latest.Version)" + $(if ($g.Latest.Date) { " (sortie le " + (Format-Date $g.Latest.Date) + ")" } else { '' }) + "."
                if ($g.Status -eq 'old' -and $g.Latest.Date -and ((Get-Date) - $g.Latest.Date).TotalDays -lt 21 -and $g.AgeDays -lt 120) { $pill = 'Récent'; $pk = 'ok'; $help += " Elle vient de sortir, rien d'urgent." }
            } elseif ($g.Vendor -eq 'NVIDIA') { $help = "Dernière version NVIDIA introuvable pour l'instant (pas de connexion, ou modèle inconnu)." }
            elseif ($g.Status -eq 'old') { $help = "Le pilote a plus d'un an : une version plus récente existe sûrement ($($g.Tool))." }
            Add-Child $cs (New-InfoRow 'Carte graphique' $g.Name)
            Add-Child $cs (New-InfoRow 'Pilote graphique' $ver $pill $pk $help)
            if ($g.Status -eq 'old' -and $pk -ne 'ok' -and ($g.Page -or $g.Latest)) {
                $url = if ($g.Latest -and $g.Latest.Url) { $g.Latest.Url } else { $g.Page }
                $b = New-Button $(if ($g.Latest -and $g.Latest.Url) { "Télécharger le pilote officiel $($g.Latest.Version)" } else { "Page officielle des pilotes $($g.Vendor)" }) 'ActionBtn' @{ Kind = 'openurl'; Url = $url } $false
                $b.HorizontalAlignment = 'Left'; $b.Margin = Th 190 2 0 8; Add-Child $cs $b
            }
        }
    } elseif (@($i.Gpu).Count) { Add-Child $cs (New-InfoRow 'Carte graphique' (@($i.Gpu) -join "`n")) }
    foreach ($d in @(Get-Displays)) {
        $low = Test-DisplayHzLow $d
        Add-Child $cs (New-InfoRow $d.Name ("{0} x {1}  ·  {2} Hz" -f $d.Width, $d.Height, $d.Hz) $(if ($low) { "Peut aller à $($d.MaxHz) Hz" } else { 'OK' }) $(if ($low) { 'warn' } else { 'ok' }) $(if ($low) { "Ton écran est capable de $($d.MaxHz) Hz mais Windows l'utilise à $($d.Hz) Hz : l'image est moins fluide. Le réglage revient tout seul au bout de 15 secondes si l'image ne s'affiche pas bien." } else { '' }))
        if ($low) { $b = New-Button "Passer à $($d.MaxHz) Hz" 'ActionBtn' @{ Kind = 'ui'; Def = @{ UI = 'display-fix'; Device = $d.Device } } $false; $b.HorizontalAlignment = 'Left'; $b.Margin = Th 190 2 0 8; Add-Child $cs $b }
    }
    Add-Child $cs (New-InfoRow 'Mémoire' ("{0}{1}{2}" -f (Format-Size $i.Ram), $(if ($i.RamModules) { "  ·  $($i.RamModules) barrette(s)" } else { '' }), $(if ($i.RamSpeed) { "  ·  $($i.RamSpeed) MHz" } else { '' })))
    $c.Child = $cs; Add-Child $sp $c

    # ---- Batterie (portables)
    $bats = @($i.Batteries | Where-Object { $_ })
    if ($bats.Count) {
        Add-Child $sp (New-Section 'Batterie')
        $c = New-CardBorder; $cs = New-Object System.Windows.Controls.StackPanel
        $k = 0
        foreach ($bt in $bats) {
            $k++
            $nm = (@($bt.Maker, $bt.Name) | Where-Object { $_ }) -join ' '
            if ($nm) { Add-Child $cs (New-InfoRow $(if ($bats.Count -gt 1) { "Batterie $k" } else { 'Batterie' }) $nm) }
            if ($null -ne $bt.Health) {
                $hp = [math]::Min($bt.Health, 100)
                $pill = if ($bt.Health -ge 80) { 'Bonne' } elseif ($bt.Health -ge 60) { 'Un peu usée' } else { 'Très usée' }
                $pk = if ($bt.Health -ge 80) { 'ok' } elseif ($bt.Health -ge 60) { 'warn' } else { 'bad' }
                $help = ("Capacité actuelle : {0:N1} Wh sur {1:N1} Wh à l'origine." -f ($bt.Full / 1000), ($bt.Design / 1000)) +
                    $(if ($bt.Health -lt 60) { " L'autonomie est bien réduite : une batterie de remplacement redonnera au PC son autonomie d'origine." } elseif ($bt.Health -lt 80) { " Usure normale après quelques années d'utilisation." } else { '' })
                Add-Child $cs (New-InfoRow 'Santé' ("{0} %" -f $hp) $pill $pk $help)
            } else { Add-Child $cs (New-InfoRow 'Santé' 'Non mesurable sur ce PC' '' '' "Windows ne donne pas la capacité d'origine de cette batterie. Le rapport complet ci-dessous en dit parfois plus.") }
            if ($bt.Cycles) { Add-Child $cs (New-InfoRow 'Cycles de charge' ("{0}" -f $bt.Cycles) '' '' "Un cycle = l'équivalent d'une recharge complète. Une batterie de portable est prévue en général pour 300 à 1000 cycles selon les modèles.") }
            if ($null -ne $bt.Charge) {
                $ch = "{0} %" -f $bt.Charge
                if ($bt.State) { $ch += "  ·  $($bt.State)" }
                if ($bt.RunMin -and $bt.State -eq 'sur batterie') { $ch += ("  ·  environ {0} h {1:D2} restantes" -f [math]::Floor($bt.RunMin / 60), ($bt.RunMin % 60)) }
                Add-Child $cs (New-InfoRow 'Charge actuelle' $ch)
            }
            if ($bt.Chem) { Add-Child $cs (New-InfoRow 'Type' $bt.Chem) }
        }
        $b = New-Button "Rapport complet de Windows" 'ActionBtn' @{ Kind = 'ui'; Def = @{ UI = 'battery-report' } }; $b.HorizontalAlignment = 'Left'; $b.Margin = Th 0 8 0 4; Add-Child $cs $b
        $t = New-Text "Historique de charge, capacité au fil des mois et autonomie estimée, par l'outil officiel de Windows." 12 '#7A8399'; $t.Margin = Th 0 2 0 4; Add-Child $cs $t
        $c.Child = $cs; Add-Child $sp $c
    }

    $b = New-Button "Actualiser" 'TextBtn' @{ Kind = 'ui'; Def = @{ UI = 'sys-refresh' } } $false; $b.HorizontalAlignment = 'Left'; $b.Margin = Th 0 6 0 0; Add-Child $sp $b
    return $sp
}

# ---------------------------------------------------------------- Test de débit
function Get-SpeedCardStatus {
    $l = @($script:Settings.SpeedHistory) | Select-Object -Last 1
    if (-not $l) { return $null }
    return @{ StatusText = ("Dernier test ({0}) : {1:N0} Mb/s ↓  {2:N0} Mb/s ↑  ping {3:N0} ms{4}" -f $l.Date, [double]$l.Down, [double]$l.Up, [double]$l.Ping, $(if ($l.Wifi) { ' · Wi-Fi' } else { ' · câble' })); StatusKind = 'on'; B = 'Refaire le test' }
}
function Get-ActiveLink {
    try {
        $r = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction Stop | Sort-Object RouteMetric | Select-Object -First 1
        $a = Get-NetAdapter -InterfaceIndex $r.ifIndex -ErrorAction Stop
        $wifi = ("$($a.PhysicalMediaType)" -match '802\.11' -or "$($a.InterfaceDescription) $($a.Name)" -match '(?i)wi-?fi|wireless|wlan|802\.11')
        $sig = -1
        if ($wifi) { $w = (netsh.exe wlan show interfaces 2>$null) | Out-String; if ($w -match 'Signal\s*:\s*(\d+)\s*%') { $sig = [int]$matches[1] } }
        return @{ Wifi = $wifi; Name = "$($a.InterfaceDescription)"; Link = "$($a.LinkSpeed)"; Signal = $sig }
    } catch { return $null }
}
function Format-Mbps($v) { if ($null -eq $v -or $v -lt 0) { return '—' }; if ($v -ge 100) { return ('{0:N0}' -f $v) }; return ('{0:N1}' -f $v) }
function Get-SpeedVerdict($Down, $Up, $Ping, $Jitter, $Link, $Loss = -1) {
    $lines = New-Object System.Collections.ArrayList
    $dv = if ($Down -lt 5) { @('Très lent', '#FF6B6B', "Même une vidéo en HD risque de saccader.") }
          elseif ($Down -lt 25) { @('Correct', '#FFB547', "Suffisant pour la vidéo HD et le jeu en ligne, mais télécharger un jeu sera long.") }
          elseif ($Down -lt 100) { @('Bon', '#4ADE80', "Parfait pour la 4K, le jeu en ligne et plusieurs écrans en même temps.") }
          elseif ($Down -lt 500) { @('Très bon', '#4ADE80', "Débit de fibre : tout est fluide, les téléchargements vont vite.") }
          else { @('Excellent', '#4ADE80', "Fibre très rapide.") }
    [void]$lines.Add(@(("Réception : " + $dv[0]), $dv[1], ($dv[2] + $(if ($Down -gt 0) { " Un jeu de 100 Go se télécharge en {0} environ." -f (Format-Duration (100 * 8000 / $Down)) } else { '' }))))
    $pv = if ($Ping -lt 20) { @('Excellent pour jouer', '#4ADE80', "Idéal même pour les FPS compétitifs.") }
          elseif ($Ping -lt 50) { @('Bon pour jouer', '#4ADE80', "Aucun souci pour le jeu en ligne.") }
          elseif ($Ping -lt 100) { @('Moyen', '#FFB547', "Ça se sent dans les jeux rapides (FPS, jeux de combat).") }
          else { @('Élevé', '#FF6B6B', "Le jeu en ligne va être pénible (décalage, « lag »).") }
    [void]$lines.Add(@(("Ping : " + $pv[0]), $pv[1], $pv[2]))
    if ($Jitter -ge 15) { [void]$lines.Add(@("Connexion instable", '#FFB547', ("Le ping varie beaucoup ({0:N0} ms de variation) : c'est ce qui donne des « lags » par moments. Cause la plus fréquente : le Wi-Fi, ou quelqu'un qui télécharge en même temps sur le réseau." -f $Jitter))) }
    if ($Loss -gt 1) { [void]$lines.Add(@(("Perte de paquets : {0:N1} %" -f $Loss), '#FF6B6B', "Des données se perdent en route : coupures en jeu, appels qui hachent. Causes fréquentes : Wi-Fi faible, câble abîmé, box à redémarrer ou souci chez le fournisseur.")) }
    if ($Up -ge 0 -and $Up -lt 5) { [void]$lines.Add(@("Envoi lent", '#FFB547', "Le streaming (Twitch), les appels vidéo et l'envoi de gros fichiers seront limités.")) }
    if ($Link -and $Link.Wifi) {
        $t = "Tu es en Wi-Fi" + $(if ($Link.Signal -ge 0) { " (signal $($Link.Signal) %)" } else { '' }) + ". Pour connaître le vrai débit de ta box, refais le test avec un câble Ethernet : en Wi-Fi on perd souvent 30 à 70 %."
        [void]$lines.Add(@("Wi-Fi", $(if ($Link.Signal -ge 0 -and $Link.Signal -lt 60) { '#FFB547' } else { '#8B93A7' }), $t))
    } elseif ($Link -and $Link.Link -match '^100 Mbps' -and $Down -gt 80) {
        [void]$lines.Add(@("Câble limité à 100 Mb/s", '#FFB547', "Ta carte réseau est connectée à 100 Mb/s seulement : souvent un vieux câble (catégorie 5) ou une prise mal enfoncée. Avec un câble Cat 6, la fibre peut aller beaucoup plus vite."))
    }
    return $lines
}
function Format-Duration([double]$Sec) {
    if ($Sec -lt 90) { return ("{0:N0} secondes" -f $Sec) }
    if ($Sec -lt 5400) { return ("{0:N0} minutes" -f ($Sec / 60)) }
    return ("{0:N1} heures" -f ($Sec / 3600))
}

function Show-SpeedTestDialog {
    $w = New-Dialog "$AppName : test de débit" 600
    $script:SpWin = $w
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = Th 24 22 24 20
    Add-Child $sp (New-Text "Test de débit Internet" 18 '#FFFFFF' 'Bold')
    $sub = New-Text "Ferme les téléchargements et les vidéos en cours pour un résultat juste. Le test dure environ 30 secondes." 13 '#A9B0C2'; $sub.Margin = Th 0 6 0 4; Add-Child $sp $sub
    $lic = New-Object System.Windows.Controls.TextBlock; $lic.TextWrapping = 'Wrap'; $lic.FontSize = 11.5; $lic.Foreground = Brush '#7A8399'; $lic.Margin = Th 0 0 0 16
    $lic.Inlines.Add("Mesure faite avec Speedtest® by Ookla, l'outil officiel de speedtest.net (téléchargé la première fois, environ 1 Mo) : mêmes serveurs que le site. Gratuit pour un usage personnel ; en lançant le test, tu acceptes ses ")
    $hl = New-Object System.Windows.Documents.Hyperlink; $hl.Inlines.Add("conditions d'utilisation"); $hl.NavigateUri = [uri]'https://www.speedtest.net/about/eula'; $hl.Foreground = Brush '#B9A8FF'
    $hl.Add_RequestNavigate({ param($s, $e) [void](Open-Url $e.Uri.AbsoluteUri); $e.Handled = $true }); $lic.Inlines.Add($hl); $lic.Inlines.Add('.')
    Add-Child $sp $lic

    $big = New-Object System.Windows.Controls.StackPanel; $big.HorizontalAlignment = 'Center'
    $phase = New-Text "Prêt" 13 '#B9A8FF' 'SemiBold'; $phase.HorizontalAlignment = 'Center'; Add-Child $big $phase
    $num = New-Text "—" 54 '#FFFFFF' 'Bold'; $num.HorizontalAlignment = 'Center'; Add-Child $big $num
    $unit = New-Text "Mb/s" 14 '#8B93A7'; $unit.HorizontalAlignment = 'Center'; Add-Child $big $unit
    Add-Child $sp $big
    $bar = New-Object System.Windows.Controls.ProgressBar; $bar.Height = 6; $bar.Margin = Th 0 14 0 16; $bar.Minimum = 0; $bar.Maximum = 100
    $bar.Foreground = Brush '#7C5CFF'; $bar.Background = Brush '#232838'; $bar.BorderThickness = Th 0 0 0 0
    Add-Child $sp $bar

    $grid = New-Object System.Windows.Controls.Primitives.UniformGrid; $grid.Columns = 3
    $cells = @{}
    foreach ($k in @(@('ping', 'PING'), @('down', 'RÉCEPTION'), @('up', 'ENVOI'))) {
        $b = New-Object System.Windows.Controls.Border; $b.Background = Brush '#171A23'; $b.CornerRadius = Corner 10; $b.Padding = Th 12 10 12 10; $b.Margin = Th 0 0 8 0
        $st = New-Object System.Windows.Controls.StackPanel
        Add-Child $st (New-Text $k[1] 11 '#7A8399' 'Bold')
        $v = New-Text '—' 22 '#FFFFFF' 'Bold'; $v.Margin = Th 0 4 0 0; Add-Child $st $v
        $u = New-Text $(if ($k[0] -eq 'ping') { 'ms' } else { 'Mb/s' }) 12 '#8B93A7'; Add-Child $st $u
        $b.Child = $st; Add-Child $grid $b; $cells[$k[0]] = @{ V = $v; U = $u }
    }
    Add-Child $sp $grid
    $info = New-Text "" 12 '#7A8399'; $info.Margin = Th 0 10 0 0; Add-Child $sp $info
    $verdict = New-Object System.Windows.Controls.StackPanel; $verdict.Margin = Th 0 10 0 0; Add-Child $sp $verdict

    $row = New-Object System.Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'; $row.HorizontalAlignment = 'Right'; $row.Margin = Th 0 14 0 0
    $bGo = New-Object System.Windows.Controls.Button; $bGo.Content = 'Lancer le test'; $bGo.Style = $window.FindResource('PrimaryBtn'); $bGo.Margin = Th 0 0 8 0
    $bClose = New-Object System.Windows.Controls.Button; $bClose.Content = 'Fermer'; $bClose.Style = $window.FindResource('TextBtn')
    Add-Child $row $bGo; Add-Child $row $bClose; Add-Child $sp $row
    $w.Content = $sp

    $script:SpUi = @{ Phase = $phase; Num = $num; Unit = $unit; Bar = $bar; Cells = $cells; Info = $info; Verdict = $verdict; Go = $bGo; Link = $null; Saved = $false }
    $script:SpTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:SpTimer.Interval = [TimeSpan]::FromMilliseconds(200)
    $script:SpTimer.Add_Tick({
        try {
            $u = $script:SpUi; $ph = [AeroxSpeed]::Phase
            $u.Bar.Value = [AeroxSpeed]::Percent
            switch ($ph) {
                'install' { $u.Phase.Text = "Téléchargement de l'outil Speedtest (première fois)..." }
                'meta' { $u.Phase.Text = 'Recherche du meilleur serveur...' }
                'ping' { $u.Phase.Text = 'Mesure du ping...'; $u.Unit.Text = 'ms' }
                'down' { $u.Phase.Text = 'Réception (téléchargement)'; $u.Num.Text = Format-Mbps ([AeroxSpeed]::Live); $u.Unit.Text = 'Mb/s' }
                'up'   { $u.Phase.Text = 'Envoi'; $u.Num.Text = Format-Mbps ([AeroxSpeed]::Live); $u.Unit.Text = 'Mb/s' }
            }
            if ([AeroxSpeed]::Ping -ge 0) { $u.Cells.ping.V.Text = ('{0:N0}' -f [AeroxSpeed]::Ping); $u.Cells.ping.U.Text = ('ms  ·  variation {0:N0} ms' -f [AeroxSpeed]::Jitter) }
            if ([AeroxSpeed]::Down -ge 0) { $u.Cells.down.V.Text = Format-Mbps ([AeroxSpeed]::Down) }
            if ([AeroxSpeed]::Up -ge 0) { $u.Cells.up.V.Text = Format-Mbps ([AeroxSpeed]::Up) }
            if ([AeroxSpeed]::Isp -or [AeroxSpeed]::Server) {
                $srv = if ([AeroxSpeed]::Engine -eq 'ookla') { "Speedtest® by Ookla · serveur $([AeroxSpeed]::Server)" + $(if ([AeroxSpeed]::City) { " ($([AeroxSpeed]::City))" } else { '' }) } else { "Serveurs Cloudflare" + $(if ([AeroxSpeed]::City) { " ($([AeroxSpeed]::City))" } else { '' }) }
                $u.Info.Text = $srv + $(if ([AeroxSpeed]::Isp) { "  ·  fournisseur $([AeroxSpeed]::Isp)" } else { '' }) + $(if ([AeroxSpeed]::Note) { "`n" + [AeroxSpeed]::Note } else { '' })
            }
            if ($ph -in 'done', 'error', 'stopped' -and -not [AeroxSpeed]::Running) {
                $script:SpTimer.Stop()
                $u.Go.IsEnabled = $true; $u.Go.Content = 'Refaire le test'
                if ($ph -eq 'error') {
                    $u.Phase.Text = 'Le test a échoué'; $u.Num.Text = '—'
                    $e = New-Text ("Impossible de joindre le serveur de test : " + [AeroxSpeed]::Error + "`nVérifie que tu es connecté à Internet (sinon lance « Tester ma connexion »). Un antivirus, un VPN ou un réseau d'entreprise peuvent aussi bloquer le test.") 12.5 '#FFB547'
                    $u.Verdict.Children.Clear(); Add-Child $u.Verdict $e
                    Write-UiLog ("❌ Test de débit : " + [AeroxSpeed]::Error)
                } elseif ($ph -eq 'done') {
                    $d = [AeroxSpeed]::Down; $up = [AeroxSpeed]::Up; $pg = [AeroxSpeed]::Ping; $jt = [AeroxSpeed]::Jitter
                    $u.Phase.Text = 'Résultat (réception)'; $u.Num.Text = Format-Mbps $d; $u.Unit.Text = 'Mb/s'
                    $u.Verdict.Children.Clear()
                    foreach ($l in (Get-SpeedVerdict $d $up $pg $jt $u.Link ([AeroxSpeed]::Loss))) {
                        $bx = New-Object System.Windows.Controls.StackPanel; $bx.Margin = Th 0 0 0 8
                        Add-Child $bx (New-Text $l[0] 13.5 $l[1] 'SemiBold')
                        $t = New-Text $l[2] 12.5 '#A9B0C2'; $t.Margin = Th 0 2 0 0; Add-Child $bx $t
                        Add-Child $u.Verdict $bx
                    }
                    if ([AeroxSpeed]::ResultUrl) {
                        $rb = New-Object System.Windows.Controls.Button; $rb.Content = 'Voir le résultat officiel sur speedtest.net'; $rb.Style = $window.FindResource('TextBtn'); $rb.HorizontalAlignment = 'Left'
                        $rb.Tag = [AeroxSpeed]::ResultUrl; $rb.Add_Click({ [void](Open-Url ([string]$this.Tag)) }); Add-Child $u.Verdict $rb
                    }
                    $hist = @($script:Settings.SpeedHistory) + @(@{ Date = (Get-Date -Format 'dd/MM HH:mm'); Down = [math]::Round($d, 1); Up = [math]::Round($up, 1); Ping = [math]::Round($pg); Wifi = [bool]($u.Link -and $u.Link.Wifi) })
                    $script:Settings.SpeedHistory = @($hist | Select-Object -Last 10); Save-Settings
                    Write-UiLog ("📶 Test de débit : {0} Mb/s en réception, {1} Mb/s en envoi, ping {2:N0} ms ({3})." -f (Format-Mbps $d), (Format-Mbps $up), $pg, $(if ($u.Link -and $u.Link.Wifi) { 'Wi-Fi' } else { 'câble' }))
                    if ($script:Cur -eq 'repair') { Refresh-Page }
                } else { $u.Phase.Text = 'Test arrêté' }
            }
        } catch { $script:SpTimer.Stop(); Write-Bug -Context 'Test de débit' -ErrorRecord $_ }
    })
    $bGo.Add_Click({
        $u = $script:SpUi
        $u.Link = Get-ActiveLink
        $u.Verdict.Children.Clear(); $u.Info.Text = ''
        foreach ($c in $u.Cells.Values) { $c.V.Text = '—' }
        $u.Cells.ping.U.Text = 'ms'
        $u.Num.Text = '—'
        $this.IsEnabled = $false; $this.Content = 'Test en cours...'
        [AeroxSpeed]::Start((Join-Path (Get-ToolsDir) 'speedtest'))
        $script:SpTimer.Start()
    })
    $bClose.Add_Click({ $script:SpWin.Close() })
    $w.Add_Closed({ [AeroxSpeed]::Cancel(); try { $script:SpTimer.Stop() } catch {} })
    [void]$w.ShowDialog()
}

# ---------------------------------------------------------------- Aide à distance
function Build-HelpReport {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("=== Rapport d'aide AEROX PC Care ===")
    try {
        $os = Get-CimInstance Win32_OperatingSystem; $cs = Get-CimInstance Win32_ComputerSystem
        $cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name.Trim() -replace '\s+', ' '
        $gpu = @(Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name }) -join ' + '
        $disp = try { (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop).DisplayVersion } catch { '' }
        [void]$sb.AppendLine("PC : $($cs.Manufacturer) $($cs.Model)")
        [void]$sb.AppendLine("Windows : $($os.Caption) $disp (build $($os.BuildNumber))")
        [void]$sb.AppendLine("Processeur : $cpu")
        [void]$sb.AppendLine("Carte graphique : $gpu")
        [void]$sb.AppendLine("Mémoire : $(Format-Size $cs.TotalPhysicalMemory)")
        foreach ($d in @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3')) { [void]$sb.AppendLine("Disque $($d.DeviceID) : $(Format-Size $d.FreeSpace) libres sur $(Format-Size $d.Size)") }
        $si = $sync.SysInfo
        if ($si -and $si.BiosVersion) {
            [void]$sb.AppendLine("Carte mère / modèle : $($si.Maker) $($si.Model)")
            [void]$sb.AppendLine("BIOS : $($si.BiosVersion) du $(if ($si.BiosDate) { (Format-Date $si.BiosDate) } else { '?' })")
            [void]$sb.AppendLine("Démarrage : $(if ($si.Uefi) { 'UEFI' } elseif ($si.Uefi -eq $false) { 'Legacy (ancien)' } else { '?' }), disque $($si.DiskStyle), Secure Boot $($si.SecureBoot), TPM $(if ($si.TpmPresent) { $si.TpmVersion + $(if ($si.TpmReady) { ' prêt' } else { ' pas prêt' }) } else { 'absent ou désactivé' })")
        }
        $lastSp = @($script:Settings.SpeedHistory) | Select-Object -Last 1
        if ($lastSp) { [void]$sb.AppendLine(("Dernier test de débit ({0}) : {1:N0} Mb/s en réception, {2:N0} Mb/s en envoi, ping {3:N0} ms, {4}" -f $lastSp.Date, [double]$lastSp.Down, [double]$lastSp.Up, [double]$lastSp.Ping, $(if ($lastSp.Wifi) { 'en Wi-Fi' } else { 'en câble' }))) }
        $up = (Get-Date) - $os.LastBootUpTime
        [void]$sb.AppendLine("Allumé depuis : $([math]::Floor($up.TotalDays)) j $($up.Hours) h")
    } catch {}
    [void]$sb.AppendLine('')
    if ($script:Diag) {
        [void]$sb.AppendLine("Dernier diagnostic : $(Get-Score)/100")
        $open = @(Get-OpenIssues)
        if ($open.Count) { foreach ($i in $open) { [void]$sb.AppendLine(("  - [{0}] {1}{2}" -f $(if ($i.Sev -eq 'crit') { 'IMPORTANT' } else { 'à voir' }), $i.Title, $(if ($i.Detail) { " : $($i.Detail)" } else { '' }))) } }
        else { [void]$sb.AppendLine("  Aucun problème en attente.") }
    } else { [void]$sb.AppendLine("Diagnostic : pas encore lancé.") }
    [void]$sb.AppendLine('')
    [void]$sb.Append((Build-BugReport "" 40 10))
    return (Protect-Text $sb.ToString())
}

function Open-QuickAssist {
    $qa = Join-Path $env:SystemRoot 'System32\quickassist.exe'
    # Logiciel ouvert avec le mot de passe d'un autre compte (ADMIN) : Assistance rapide doit s'ouvrir chez la personne
    # devant l'écran. Ouverte dans le compte admin, elle ne peut pas créer ses fichiers (« Création du répertoire de données impossible »).
    if (Test-OtherAccount) { Open-QuickAssistForSession $qa; return }
    try {
        $pkg = Get-AppxPackage -Name 'MicrosoftCorporationII.QuickAssist' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($pkg) {
            $appId = 'App'
            try { $appId = @((Get-AppxPackageManifest $pkg).Package.Applications.Application)[0].Id } catch {}
            Start-Process explorer.exe ("shell:AppsFolder\{0}!{1}" -f $pkg.PackageFamilyName, $appId)
            Write-UiLog "Assistance rapide ouverte."
            return
        }
    } catch {}
    if (Test-Path -LiteralPath $qa) { Start-Process $qa; Write-UiLog "Assistance rapide ouverte."; return }
    if (Confirm-Box "Assistance rapide n'est pas encore installée sur ce PC.`n`nC'est l'outil gratuit de Microsoft pour l'aide à distance. L'installer depuis le Microsoft Store ?") {
        Open-WinUri 'ms-windows-store://pdp/?ProductId=9P7BP5VNWKX5'
    }
}
# Compte standard + mot de passe ADMIN : lancée dans la session de la personne, puis on VÉRIFIE qu'elle s'est ouverte
function Open-QuickAssistForSession([string]$Qa) {
    $user = ''; try { $user = "$((Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).UserName)" } catch {}
    $upkg = $null
    if ($user) { try { $upkg = Get-AppxPackage -User $user -Name 'MicrosoftCorporationII.QuickAssist' -ErrorAction Stop | Select-Object -First 1 } catch {} }
    $before = @(Get-Process -Name quickassist -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    $how = 'aucun'
    $window.Cursor = [System.Windows.Input.Cursors]::Wait
    try {
        if ($upkg) {
            $appId = 'App'
            try { $appId = @((Get-AppxPackageManifest $upkg).Package.Applications.Application)[0].Id } catch {}
            $how = 'store'
            [void](Start-AsSessionUser (Join-Path $env:SystemRoot 'explorer.exe') ("shell:AppsFolder\{0}!{1}" -f $upkg.PackageFamilyName, $appId))
        } elseif (Test-Path -LiteralPath $Qa) {
            $how = 'system32'
            [void](Start-AsSessionUser $Qa)
        }
    } finally { $window.Cursor = $null }
    if ($how -eq 'aucun') { Show-QuickAssistFail $user $false $how $Qa; return }
    # Vérifie pendant 6 secondes qu'elle s'ouvre, sans figer la fenêtre
    $script:QaCheck = @{ Before = $before; N = 0; User = $user; Pkg = [bool]$upkg; How = $how; Qa = $Qa }
    $t = New-Object System.Windows.Threading.DispatcherTimer; $t.Interval = [TimeSpan]::FromMilliseconds(500)
    $t.Add_Tick({
        $c = $script:QaCheck
        if (@(Get-Process -Name quickassist -ErrorAction SilentlyContinue | Where-Object { $c.Before -notcontains $_.Id }).Count) { $this.Stop(); Write-UiLog "Assistance rapide ouverte."; return }
        $c.N++
        if ($c.N -ge 12) { $this.Stop(); Show-QuickAssistFail $c.User $c.Pkg $c.How $c.Qa }
    })
    $t.Start()
}
function Show-QuickAssistFail([string]$user, [bool]$upkg, [string]$how, [string]$Qa) {
    Write-Bug -Context 'Assistance rapide (compte ADMIN séparé)' -ErrorRecord ("ne s'est pas ouverte : session={0}, appli Store pour ce compte={1}, essai={2}, tâche={3}" -f $user, $upkg, $how, $script:LastSessionTask)
    if (-not $upkg -and -not (Test-Path -LiteralPath $Qa)) {
        if (Confirm-Box "Assistance rapide n'est pas installée pour ce compte.`n`nC'est l'outil gratuit de Microsoft pour l'aide à distance. Ouvrir le Microsoft Store pour l'installer ?") { Open-WinUri 'ms-windows-store://pdp/?ProductId=9P7BP5VNWKX5' }
        return
    }
    [System.Windows.MessageBox]::Show("Assistance rapide n'a pas pu s'ouvrir toute seule (AEROX tourne avec le mot de passe d'un autre compte).`n`nOuvre-la toi-même : menu Démarrer, tape « Assistance rapide », puis Entrée.$(if (-not $upkg) { "`n`nSi elle n'apparaît pas, installe-la depuis le Microsoft Store (recherche « Assistance rapide »)." })", $AppName, 'OK', 'Information') | Out-Null
}

# ---------------------------------------------------------------- Envoi au relais sans figer la fenêtre
# La requête part dans un fil séparé ; $Done reçoit @{ Ok; R; Err } quand elle est finie (20 s au plus)
function Send-RelayAsync([string]$Uri, [byte[]]$Body, [scriptblock]$Done) {
    $ps = [powershell]::Create()
    [void]$ps.AddScript({
        param($u, $b)
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
        try { $r = Invoke-RestMethod -Uri $u -Method Post -Body $b -ContentType 'application/json; charset=utf-8' -Headers @{ 'X-Aerox' = '1' } -TimeoutSec 20 -ErrorAction Stop; @{ Ok = $true; R = $r } }
        catch { $m = $_.Exception.Message; try { $e = $_.ErrorDetails.Message | ConvertFrom-Json; if ($e.error) { $m = $e.error } } catch {}; @{ Ok = $false; Err = $m } }
    }).AddArgument($Uri).AddArgument($Body)
    $h = $ps.BeginInvoke()
    $t = New-Object System.Windows.Threading.DispatcherTimer; $t.Interval = [TimeSpan]::FromMilliseconds(200)
    $t.Tag = @{ PS = $ps; H = $h; Done = $Done }
    $t.Add_Tick({
        $x = $this.Tag
        if (-not $x.H.IsCompleted) { return }
        $this.Stop()
        $res = $null
        try { $res = @($x.PS.EndInvoke($x.H))[0] } catch { $res = @{ Ok = $false; Err = $_.Exception.Message } }
        try { $x.PS.Dispose() } catch {}
        if (-not $res) { $res = @{ Ok = $false; Err = "pas de réponse du service d'envoi" } }
        try { & $x.Done $res } catch { Write-Bug -Context 'Envoi au relais' -ErrorRecord $_ }
    })
    $t.Start()
}

# ---------------------------------------------------------------- Avis (note + commentaire, publiés sur GitHub)
$script:ReviewsUrl = "https://github.com/$GitHubRepo/issues?q=label%3Aavis+is%3Aopen"
function Test-ReviewInvite {
    $st = $script:Settings
    if ($st.ReviewSent -or $st.ReviewNever -or [int]$st.Launches -lt 3 -or -not $sync.BugRelay) { return $false }
    if ($st.ReviewSnooze) { try { if ([datetime]$st.ReviewSnooze -gt (Get-Date)) { return $false } } catch {} }
    return $true
}
function Show-ReviewDialog {
    $w = New-Dialog "$AppName : donner mon avis" 560
    $script:RevWin = $w; $script:RevNote = [int]$script:Settings.ReviewNote; $script:RevStars = New-Object System.Collections.ArrayList
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = Th 24 22 24 20
    Add-Child $sp (New-Text $(if ($script:Settings.ReviewSent) { "Modifier mon avis" } else { "Donner mon avis" }) 18 '#FFFFFF' 'Bold')
    $p = New-Text "Ton avis est publié sur la page GitHub d'AEROX PC Care, visible par tout le monde, avec le pseudo de ton choix (ou « Anonyme »). N'y mets pas d'informations personnelles. Un seul avis par PC : tu pourras le modifier." 13 '#A9B0C2'
    $p.Margin = Th 0 6 0 14; Add-Child $sp $p
    Add-Child $sp (New-Text "Ta note" 12 '#C3CAD9' 'SemiBold')
    $row = New-Object System.Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'; $row.Margin = Th 0 4 0 12
    foreach ($i in 1..5) {
        $b = New-Object System.Windows.Controls.Button; $b.Content = '★'; $b.FontSize = 30; $b.Tag = $i; $b.Cursor = 'Hand'
        $b.Background = [System.Windows.Media.Brushes]::Transparent; $b.BorderThickness = Th 0 0 0 0; $b.Padding = Th 2 0 2 0; $b.Margin = Th 0 0 4 0
        $b.Add_Click({ $script:RevNote = [int]$this.Tag; & $script:PaintStars })
        Add-Child $row $b; [void]$script:RevStars.Add($b)
    }
    $script:RevLabel = New-Text '' 13 '#B9A8FF' 'SemiBold'; $script:RevLabel.VerticalAlignment = 'Center'; $script:RevLabel.Margin = Th 10 0 0 0; Add-Child $row $script:RevLabel
    Add-Child $sp $row
    $mk = { param($h, $max, $multi)
        $t = New-Object System.Windows.Controls.TextBox; $t.MaxLength = $max; $t.Margin = Th 0 6 0 12
        if ($multi) { $t.AcceptsReturn = $true; $t.TextWrapping = 'Wrap'; $t.Height = $h; $t.VerticalScrollBarVisibility = 'Auto' }
        $t.Background = Brush '#0E1016'; $t.Foreground = Brush '#E6E9F2'; $t.BorderBrush = Brush '#2E3446'; $t.Padding = Th 8 6 8 6; $t.FontSize = 13; $t.CaretBrush = Brush '#E6E9F2'
        return $t }
    Add-Child $sp (New-Text "Ton commentaire (facultatif)" 12 '#C3CAD9' 'SemiBold')
    $script:RevText = & $mk 110 1500 $true; $script:RevText.Text = "$($script:Settings.ReviewText)"; Add-Child $sp $script:RevText
    Add-Child $sp (New-Text "Ton pseudo (facultatif)" 12 '#C3CAD9' 'SemiBold')
    $script:RevPseudo = & $mk 0 30 $false; $script:RevPseudo.Text = "$($script:Settings.ReviewPseudo)"; Add-Child $sp $script:RevPseudo
    $bar = New-Object System.Windows.Controls.DockPanel; $bar.Margin = Th 0 4 0 0
    $bRead = New-DlgButton 'Lire les avis' 'TextBtn'; [System.Windows.Controls.DockPanel]::SetDock($bRead, 'Left'); Add-Child $bar $bRead
    $right = New-Object System.Windows.Controls.StackPanel; $right.Orientation = 'Horizontal'; $right.HorizontalAlignment = 'Right'
    $bClose = New-DlgButton 'Fermer' 'TextBtn'; $bClose.Margin = Th 0 0 8 0
    $script:RevSend = New-DlgButton 'Envoyer' 'PrimaryBtn'
    Add-Child $right $bClose; Add-Child $right $script:RevSend; Add-Child $bar $right; Add-Child $sp $bar
    $script:PaintStars = {
        $labels = @('', 'Décevant', 'Bof', 'Correct', 'Bien', 'Génial !')
        foreach ($s in $script:RevStars) { $s.Foreground = Brush $(if ([int]$s.Tag -le $script:RevNote) { '#FFC83D' } else { '#3A4052' }) }
        $script:RevLabel.Text = $labels[$script:RevNote]
        $script:RevSend.IsEnabled = ($script:RevNote -ge 1)
    }
    $bRead.Add_Click({ [void](Open-Url $script:ReviewsUrl) })
    $bClose.Add_Click({ $script:RevWin.Close() })
    $script:RevSend.Add_Click({
        $btn = $this
        try {
            if (-not $sync.BugRelay) { throw "le service d'envoi ne répond pas pour l'instant. Réessaie plus tard." }
            $btn.IsEnabled = $false; $btn.Content = 'Envoi...'
            [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
            $payload = @{ note = $script:RevNote; commentaire = (Hide-Profanity $script:RevText.Text.Trim()); pseudo = (Hide-Profanity $script:RevPseudo.Text.Trim()); version = $AppVersion; id = "$($script:Settings.InstallId)" } | ConvertTo-Json -Compress
            $script:RevBtn = $btn
            Send-RelayAsync ($sync.BugRelay.TrimEnd('/') + '/avis') ([System.Text.Encoding]::UTF8.GetBytes($payload)) {
                param($res)
                [System.Windows.Input.Mouse]::OverrideCursor = $null
                if (-not $res.Ok) {
                    $script:RevBtn.IsEnabled = $true; $script:RevBtn.Content = 'Envoyer'
                    [System.Windows.MessageBox]::Show("L'avis n'a pas pu être envoyé : $($res.Err)", $AppName, 'OK', 'Warning') | Out-Null
                    return
                }
                $script:Settings.ReviewSent = $true; $script:Settings.ReviewNote = $script:RevNote; $script:Settings.ReviewText = $script:RevText.Text.Trim(); $script:Settings.ReviewPseudo = $script:RevPseudo.Text.Trim(); Save-Settings
                Write-UiLog ("⭐ Avis " + $(if ($res.R.updated) { 'modifié' } else { 'publié' }) + ". Merci !")
                [System.Windows.MessageBox]::Show("Merci pour ton avis ! Il est publié sur la page GitHub d'AEROX PC Care.", $AppName, 'OK', 'Information') | Out-Null
                $script:RevWin.Close()
            }
        } catch {
            [System.Windows.Input.Mouse]::OverrideCursor = $null
            $btn.IsEnabled = $true; $btn.Content = 'Envoyer'
            $m = $_.Exception.Message
            try { $resp = $_.ErrorDetails.Message | ConvertFrom-Json; if ($resp.error) { $m = $resp.error } } catch {}
            [System.Windows.MessageBox]::Show("L'avis n'a pas pu être envoyé : $m", $AppName, 'OK', 'Warning') | Out-Null
        }
    })
    & $script:PaintStars
    $w.Content = $sp
    [void]$w.ShowDialog()
    Refresh-Page
}

# ---------------------------------------------------------------- « Quoi de neuf » après une mise à jour
# Une entrée par version, en mots simples (la plus récente en premier)
$script:WhatsNew = [ordered]@{
    '2.4.3' = @("Nouveau : « Partager AEROX à un ami » (onglet Aide) copie un petit message tout prêt avec le lien, à coller sur Discord, WhatsApp, Snap… Tu aimes AEROX ? Fais-le connaître, et signale le moindre souci : chaque retour compte !", "Sécurité renforcée : AEROX vérifie l'empreinte de ses propres fichiers avant de les lancer avec les droits administrateur (utile surtout pour la version portable).", "Test de la webcam : l'application Caméra de Windows s'ouvre de nouveau pour vérifier l'image.")
    '2.4.2' = @("Écran qui devient noir quelques secondes puis revient : le diagnostic le repère beaucoup mieux (toutes les traces que Windows garde des décrochages de la carte graphique), te dit si ça a commencé avec ton dernier pilote, et ce qu'il faut faire.", "Si Windows 11 bloque AEROX au démarrage (Contrôle intelligent des applications), le message explique maintenant clairement pourquoi et quoi faire.")
    '2.4.1' = @("Nouveau : la communauté AEROX sur Discord ! Onglet Aide > « Rejoindre la communauté Discord » : pose tes questions, partage ta config, propose des idées.")
    '2.4.0' = @("« Pourquoi mon PC rame ? » va beaucoup plus loin : carte graphique, processeur bridé par la chauffe ou la batterie, pilote qui fait saccader, connexion qui lague, téléchargement qui sature, disque plein. Et il montre tout ce qu'il a vérifié.", "Rien trouvé ? Dis à AEROX ce qui rame (ça lague en ligne, les jeux saccadent, lent au démarrage, un logiciel précis, tout est lent) : il lance l'analyse qui correspond. Pour les jeux, la mesure se fait pendant que tu joues.", "Nouveau dépannage « Ça lague en ligne (jeu, Discord) » : 1 minute de mesure, et AEROX te dit si c'est ton Wi-Fi, ta box, ta ligne, un téléchargement, un VPN ou la carte réseau.", "Statistiques anonymes : des compteurs (types de problèmes trouvés, lenteurs non reconnues), jamais ton nom ni tes fichiers, pour corriger d'abord ce qui touche le plus de monde. Désactivables dans l'onglet Aide.")
    '2.3.0' = @("Grande mise à jour de correctifs et de sécurité : les données d'AEROX (réglages, historique, bilans, journaux) sont rangées dans son dossier protégé, que seul un administrateur peut modifier. Elles ont été reprises automatiquement.", "Sites bloqués (fichier hosts) : AEROX débloque maintenant même un fichier verrouillé, et te dit si c'est ton antivirus qui le protège.", "Pilotes : AEROX dit exactement quel périphérique a un problème (ce n'est souvent pas la carte graphique), pourquoi, et peut réinstaller son pilote en un clic.", "Rapport de batterie et boutons « Ouvrir Steam » : ils remarchent. « Réparer les fichiers Windows » donne un résultat fiable quelle que soit la langue de Windows.", "Sécurité : la mise à jour d'AEROX n'est installée que si son empreinte est vérifiée, et l'outil du test de débit seulement si c'est bien le programme officiel d'Ookla.", "BIOS : « Mettre à jour » trouve la page de ton modèle même si les infos du PC n'étaient pas encore chargées.")
    '2.2.1' = @("Sécurité renforcée (relecture externe) : un désinstalleur rangé hors des dossiers protégés de Windows n'est plus lancé avec les droits administrateur, et les raccourcis temporaires d'AEROX sont dans son dossier protégé.", "Test de débit : s'il se bloque, il passe tout seul sur un autre serveur au lieu de rester figé. Une petite erreur pendant une analyse n'empêche plus d'afficher les résultats.")
    '2.2.0' = @("Diagnostic plus poussé : démarrage lent (Windows dit lui-même ce qui le ralentit), extinctions brutales expliquées (bouton maintenu, veille ou coupure nette), pilote graphique qui décroche, logiciels qui se figent, erreurs de lecture des disques et résultat du test de mémoire de Windows. Chaque fois avec la cause et quoi faire.", "Avis et rapports : les gros mots sont masqués par des étoiles avant d'être publiés.", "Sites ou téléchargements qui ne passent pas (ex. Discord) : AEROX cherche la cause (proxy, fichier hosts qui détourne des sites, heure du PC fausse, DNS qui bloque) et la répare.", "Nouveau dépannage « Discord bugue ou ne s'installe plus » : cache vidé, installation abîmée repérée, téléchargement vérifié.", "Mises à jour : un logiciel qui se réaffiche juste après sa mise à jour (VS Code) n'est plus proposé en boucle. « C'est fait » sur une extinction brutale ou un plantage n'est plus resignalé au diagnostic suivant.")
    '2.1.9' = @("Écrans bleus : AEROX lit les rapports de plantage de Windows et te dit quel pilote les provoque (carte graphique, réseau, anti-triche d'un jeu, antivirus…), avec la bonne réparation. Il signale aussi les erreurs matérielles et la mémoire en XMP/EXPO.", "BIOS : « Chercher mon BIOS » ouvre la page de ton modèle sur le site du fabricant quand AEROX peut la vérifier (ASUS, MSI, Gigabyte, ASRock, Dell, Lenovo), sinon la recherche de son site officiel.", "Carte réseau : si son pilote refuse de couper l'économie d'énergie tout de suite, le réglage est enregistré pour le prochain redémarrage (avant : « réglé » puis toujours signalé).", "Mises à jour : un logiciel dont l'installateur échoue deux fois (Corsair iCUE…) n'est plus proposé en boucle : AEROX te dit de le mettre à jour depuis le logiciel lui-même.")
    '2.1.8' = @("Bilan avant / après : la place libre de tous tes disques (D:, E:…) est comparée, pas seulement C:. Visible à partir du prochain bilan.", "« Pas de son » ne relance plus le son de Windows quand il marche : ça coupait le micro et le casque dans Discord. Son et micro te disent maintenant quoi choisir exactement dans Discord (Entrée / Sortie), y compris avec SteelSeries Sonar.", "Navigateurs : « Gérer » ouvre directement la page de l'extension, dans le bon profil.", "Pilotes graphiques : la vraie date d'installation est affichée (la date du pilote, c'est celle du fabricant).", "Plantages : après une réparation ou un nouveau pilote graphique, seuls les nouveaux plantages comptent, et dwm.exe (l'affichage de Windows) est réparé par le pilote graphique, pas par les mises à jour de logiciels.", "Désinstallation : si le désinstalleur d'un logiciel n'existe plus, AEROX te l'explique clairement.")
    '2.1.7' = @("Espace disque : un bouton « Corbeille » à côté de chacun de tes gros fichiers, sur tous les disques (D:, E:…), pas seulement dans ton dossier perso.", "Les gros fichiers qui font partie d'un jeu ou d'un logiciel ne sont plus mélangés avec les tiens : AEROX te montre le jeu entier et te propose de le désinstaller (supprimé fichier par fichier, il ne marcherait plus).", "En analysant un autre disque que C:, le bouton « Nettoyage approfondi » (qui s'occupe du disque de Windows) n'apparaît plus.", "« Mettre la sélection à la corbeille » ne ferme plus la fenêtre, et le choix du disque à analyser est bien aligné.")
    '2.1.6' = @("Diagnostic : chaque disque est détaillé dans le journal (place libre et santé), avec ses lettres (C:, D:…), y compris les disques et clés USB.", "Corbeille : elle est vraiment vidée sur tous les disques, et la taille annoncée est bien celle de ta corbeille (celle des autres comptes du PC n'est jamais touchée).")
    '2.1.5' = @("Overlay : le fond passe vraiment en douceur de transparent à opaque (avant, il basculait d'un coup à 50 %), et la taille suit exactement le curseur. Taille minimum relevée à 70 % pour que le texte reste net.", "Correction d'un calcul qui pouvait planter quand plus de 2 Go étaient libérés (OneDrive, nettoyage).")
    '2.1.4' = @("Programmes au démarrage : chaque appli décochée est vérifiée tout de suite, et si une appli se remet toute seule au démarrage (Discord, Spotify…), AEROX te le dit et t'explique comment l'en empêcher.", "Mises à jour des logiciels : les logiciels qui se mettent à jour tout seuls ou par leur lanceur (Microsoft Edge, Epic Online Services…) ne sont plus proposés ni comptés comme des erreurs.", "Gaming : le module de températures, le pilote PawnIO et le compteur de FPS se désinstallent d'un clic si tu n'en veux plus (Gaming > En direct).", "Overlay : le fond change en douceur quand tu bouges le curseur (avec le pourcentage affiché), et le texte reste net à toutes les tailles.", "État du PC : tous les disques sont affichés et vérifiés (D:, disques et clés USB…), plus seulement C:.")
    '2.1.3' = @("Grand contrôle de sécurité : les outils téléchargés (températures, FPS, test de débit) et les sauvegardes sont rangés dans un dossier protégé, et AEROX n'ouvre plus jamais un lien, un navigateur ou un fichier modifiable par un autre programme avec ses droits administrateur.", "Nettoyage : AEROX ne peut jamais supprimer quoi que ce soit en dehors du dossier qu'il nettoie, même si un lien vers un autre dossier y a été glissé.", "Mises à jour des logiciels : un logiciel n'apparaît plus en double, et un logiciel déjà désinstallé (il ne reste qu'une trace dans Windows) n'est plus réinstallé.", "Corbeille : la place annoncée est celle vraiment libérée. Gaming : saccades comptées sur le temps vraiment joué, et fréquence de l'écran où tourne le jeu.")
    '2.1.2' = @("Sécurité renforcée : AEROX ne lance plus jamais avec ses droits administrateur un désinstalleur ou une sauvegarde qu'un autre programme aurait pu modifier.")
    '2.1.1' = @("Désinstallation : un logiciel n'est marqué « désinstallé » que quand il a vraiment disparu (si tu annules dans son désinstalleur, AEROX te le dit).", "OneDrive : les dossiers que tu as choisis de « toujours conserver sur cet appareil » ne sont plus jamais touchés.", "Nettoyage approfondi : « Annuler » arrête vraiment le nettoyage de Windows, et deux nettoyages ne se lancent plus en même temps.", "L'envoi d'un rapport de bug ou d'un avis ne fige plus la fenêtre.")
    '2.1.0' = @("Interface rafraîchie : une icône pour chaque outil, des cartes qui s'éclairent au survol, des pages qui apparaissent en douceur et des textes plus lisibles.", "Accueil : l'état de ton PC est mis en avant.", "Gaming rangé en 3 onglets : « Mes jeux », « En direct » et « Overlay en jeu ».")
    '2.0.2' = @("Caché près de l'horloge, AEROX consomme beaucoup moins de mémoire : il libère son affichage et rend à Windows la mémoire inutilisée. Tout revient instantanément quand tu le rouvres.")
    '2.0.1' = @("Gaming : Roblox est reconnu même en fenêtre (pas seulement en plein écran).", "Gaming : analyse plus juste. Quand ni le processeur ni la carte graphique ne sont à fond, AEROX dit que c'est le jeu qui fixe le rythme (Roblox, Minecraft…) au lieu d'accuser le processeur, et il te dit quand tu as déjà plus de FPS que ton écran n'en affiche.")
    '2.0.0' = @("Nouvel onglet Gaming (à la place de « Moniteur ») : AEROX reconnaît tes jeux tout seul et note chaque partie (FPS moyens, 1 % low, saccades, températures).", "À la fin de la partie : un résumé en une ligne (notification + dans AEROX), et une fiche par jeu avec l'évolution partie après partie, ce qui limite le jeu (processeur, carte graphique, limite de FPS) et quoi faire.", "Option : garder AEROX près de l'horloge quand tu le fermes, et le lancer avec Windows en mode discret pour ne rater aucune partie. Rien n'est injecté dans les jeux : aucun risque avec les anti-triche.")
    '1.9.0' = @("Après chaque réparation, AEROX vérifie que le problème est vraiment réglé. Sinon, il te le dit et t'explique quoi faire.", "Pilotes : plus de boucle « mets à jour » quand tu as déjà installé la dernière version proposée pour ta carte, et un pilote que Windows repropose sans arrêt est signalé au lieu d'être réinstallé.")
    '1.8.0' = @("« Quoi de neuf » : cette fenêtre s'affiche après chaque mise à jour pour te montrer les nouveautés (onglet Aide pour la revoir).")
    '1.7.2' = @("« Annuler » marche maintenant à tout moment, même pendant le nettoyage approfondi.", "Le nettoyage de Windows ne peut plus bloquer AEROX : il affiche son avancement et s'arrête au bout de 10 minutes au plus.")
    '1.7.0' = @("Donne ton avis (onglet Aide) : une note et un petit commentaire, publiés sur la page du logiciel. Ça fait plaisir et ça aide d'autres personnes à lui faire confiance ⭐")
    '1.6.0' = @("« Ce qui prend de la place » libère ce que Windows garde pour lui : stockage réservé, veille prolongée, points de restauration, anciens pilotes (souvent 10 à 20 Go sur un petit disque).", "Nouveau : « Fichiers en double » (photos, vidéos, documents), un exemplaire est toujours gardé.", "Conseils : OneDrive en double sur le PC, jeux et logiciels pas utilisés depuis 3 mois, plus gros fichiers à mettre à la corbeille.")
    '1.5.0' = @("« Pubs et fausses alertes de virus » (onglet Réparation) : bloque les sites qui envoient des notifications de pub et repère les extensions douteuses.", "Dépannages rapides : pas de son, micro, webcam, imprimante, bureau figé.", "Version portable sur clé USB, pour dépanner plusieurs PC sans rien installer.")
}
function Compare-AppVersion([string]$A, [string]$B) { try { return ([version]$A).CompareTo([version]$B) } catch { return 0 } }
# Au démarrage : nouveautés depuis la dernière version vue (rien au tout premier lancement)
# ---------------------------------------------------------------- Partager AEROX à un ami
function Get-ShareMessage {
    $t = "Je te conseille AEROX PC Care 👍 Une appli gratuite qui analyse ton PC Windows et règle les soucis : PC qui rame, lags, bugs, nettoyage, pilotes, écrans bleus…`r`n" +
         "Téléchargement : https://github.com/$GitHubRepo/releases/latest"
    if ($sync.DiscordUrl) { $t += "`r`nLa communauté sur Discord : $($sync.DiscordUrl)" }
    return $t
}
function Copy-ShareMessage {
    $t = Get-ShareMessage
    try { [System.Windows.Clipboard]::SetText($t) } catch { Write-Bug -Context 'Partager AEROX' -ErrorRecord $_; return }
    Add-StatsEvent 'partage'
    Write-UiLog "💜 Message de partage copié : colle-le à un ami (Ctrl+V). Merci !"
    [System.Windows.MessageBox]::Show("Message copié ! Colle-le (Ctrl+V) à un ami sur Discord, WhatsApp, Snap, Messenger…`n`n$t", $AppName, 'OK', 'Information') | Out-Null
}
# Encadré « partage + retours » (fenêtre Quoi de neuf)
function New-ShareBox {
    $box = New-Object System.Windows.Controls.Border; $box.Background = Brush '#211B3D'; $box.BorderBrush = Brush '#7C5CFF'; $box.BorderThickness = Th 1 1 1 1
    $box.CornerRadius = Corner 10; $box.Padding = Th 14 12 14 12; $box.Margin = Th 0 12 0 0
    $bs = New-Object System.Windows.Controls.StackPanel
    Add-Child $bs (New-Text "💜 Tu aimes AEROX PC Care ?" 14 '#FFFFFF' 'SemiBold')
    $t = New-Text "N'hésite pas à le partager à tes amis : il est gratuit, et plus on est nombreux, plus il s'améliore. Et fais-nous un retour sur le moindre souci, même petit (Aide > Signaler un bug, ou sur le Discord) : chaque retour est lu et corrigé." 12.5 '#C3CAD9'
    $t.Margin = Th 0 4 0 8; Add-Child $bs $t
    $row = New-Object System.Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'
    $b1 = New-DlgButton 'Partager à un ami' 'ActionBtn'; $b1.Margin = Th 0 0 8 0; $b1.Add_Click({ Copy-ShareMessage }); Add-Child $row $b1
    if ($sync.DiscordUrl) { $b2 = New-DlgButton 'Rejoindre le Discord' 'ActionBtn'; $b2.Add_Click({ [void](Open-Url $sync.DiscordUrl) }); Add-Child $row $b2 }
    Add-Child $bs $row
    $box.Child = $bs
    return $box
}
function Show-WhatsNewIfUpdated {
    $last = "$($script:Settings.LastSeenVersion)"
    if ($last -eq $AppVersion) { return }
    $first = (-not $last) -and ([int]$script:Settings.Launches -le 1)
    $script:Settings.LastSeenVersion = $AppVersion; Save-Settings
    if ($first -or ($last -and (Compare-AppVersion $AppVersion $last) -le 0)) { return }
    Show-WhatsNew $last
}
function Show-WhatsNew([string]$Since) {
    $vers = @($script:WhatsNew.Keys | Where-Object { (Compare-AppVersion $_ $AppVersion) -le 0 -and (-not $Since -or (Compare-AppVersion $_ $Since) -gt 0) })
    if (-not $Since) { $vers = @($vers | Select-Object -First 4) }
    if (-not $vers.Count) { return }
    $w = New-Dialog "$AppName : quoi de neuf ?" 600
    $script:NewWin = $w
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = Th 24 22 24 20
    Add-Child $sp (New-Text $(if ($Since) { "Quoi de neuf dans la $AppVersion ?" } else { "Quoi de neuf ?" }) 18 '#FFFFFF' 'Bold')
    $p = New-Text "AEROX PC Care s'améliore grâce à vos retours et vos rapports de bug. Merci !" 13 '#A9B0C2'; $p.Margin = Th 0 6 0 10; Add-Child $sp $p
    $list = New-Object System.Windows.Controls.StackPanel
    $sv = New-Object System.Windows.Controls.ScrollViewer; $sv.VerticalScrollBarVisibility = 'Auto'; $sv.MaxHeight = 420; $sv.Content = $list
    Add-Child $sp $sv
    foreach ($v in $vers) {
        $h = New-Text ("VERSION {0}" -f $v) 11.5 '#B9A8FF' 'Bold'; $h.Margin = Th 2 10 0 6; Add-Child $list $h
        foreach ($line in $script:WhatsNew[$v]) {
            $card = New-Object System.Windows.Controls.Border; $card.Background = Brush '#171A23'; $card.CornerRadius = Corner 10; $card.Padding = Th 14 9 12 9; $card.Margin = Th 0 0 0 6
            $card.Child = (New-Text ("•  " + $line) 13 '#E6E9F2'); Add-Child $list $card
        }
    }
    Add-Child $sp (New-ShareBox)
    $b = New-DlgButton 'Super !' 'PrimaryBtn'; $b.HorizontalAlignment = 'Right'; $b.Margin = Th 0 14 0 0
    $b.Add_Click({ $script:NewWin.Close() }); Add-Child $sp $b
    $w.Content = $sp
    [void]$w.ShowDialog()
}

function Show-RemoteHelpDialog {
    if (-not $sync.SysInfo -and -not $script:SysWaiting) { $script:SysWaiting = $true; Start-Background 'Get-SystemInfo' }
    $w = New-Dialog "$AppName : aide à distance" 640
    $script:HelpWin = $w
    $sv = New-Object System.Windows.Controls.ScrollViewer; $sv.VerticalScrollBarVisibility = 'Auto'
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = Th 24 22 24 20
    Add-Child $sp (New-Text "Aide à distance" 18 '#FFFFFF' 'Bold')
    $p = New-Text "Une personne de confiance voit ton écran et peut prendre la main pour t'aider, avec « Assistance rapide », l'outil gratuit de Microsoft inclus dans Windows." 13 '#A9B0C2'
    $p.Margin = Th 0 6 0 12; Add-Child $sp $p

    $warn = New-Object System.Windows.Controls.Border; $warn.Background = Brush '#3A1B1B'; $warn.CornerRadius = Corner 10; $warn.Padding = Th 14 10 14 10; $warn.Margin = Th 0 0 0 14
    $wt = New-Text "⚠ N'accepte JAMAIS l'aide à distance de quelqu'un qui t'a appelé, écrit ou affiché un message de lui-même (« support Microsoft », « technicien », « ton PC est infecté »...). C'est l'arnaque la plus répandue. Utilise-la seulement avec quelqu'un que tu connais vraiment." 13 '#FFB4B4' 'SemiBold'
    $warn.Child = $wt; Add-Child $sp $warn

    $steps = @(
        @("1", "Envoie ton rapport", "Il résume ton PC et ses problèmes (sans mots de passe ni fichiers perso). Il est copié : colle-le dans Discord, Messenger ou un SMS à la personne qui t'aide.", "Préparer et copier mon rapport", 'report'),
        @("2", "Ouvre Assistance rapide", "La personne qui t'aide l'ouvre aussi de son côté, clique sur « Aider quelqu'un » et te donne un code de sécurité à 6 caractères.", "Ouvrir Assistance rapide", 'qa'),
        @("3", "Tape le code et accepte", "Entre le code dans « Code de sécurité de l'assistant », clique sur « Envoyer » puis accepte le partage d'écran. Tu peux tout arrêter à tout moment avec le bouton « Arrêter » ou en fermant la fenêtre.", $null, $null)
    )
    foreach ($s in $steps) {
        $row = New-Object System.Windows.Controls.Border; $row.Background = Brush '#171A23'; $row.CornerRadius = Corner 10; $row.Padding = Th 14 12 14 12; $row.Margin = Th 0 0 0 8
        $dp = New-Object System.Windows.Controls.DockPanel
        $num = New-Object System.Windows.Controls.Border; $num.Width = 28; $num.Height = 28; $num.CornerRadius = Corner 14; $num.Background = Brush '#2A2350'; $num.VerticalAlignment = 'Top'; $num.Margin = Th 0 0 12 0
        $nt = New-Text $s[0] 13 '#B9A8FF' 'Bold'; $nt.HorizontalAlignment = 'Center'; $nt.VerticalAlignment = 'Center'; $num.Child = $nt
        [System.Windows.Controls.DockPanel]::SetDock($num, 'Left'); Add-Child $dp $num
        $tx = New-Object System.Windows.Controls.StackPanel
        Add-Child $tx (New-Text $s[1] 14 '#FFFFFF' 'SemiBold')
        $d = New-Text $s[2] 12.5 '#A9B0C2'; $d.Margin = Th 0 3 0 0; Add-Child $tx $d
        if ($s[3]) {
            $b = New-Object System.Windows.Controls.Button; $b.Content = $s[3]; $b.Style = $window.FindResource($(if ($s[4] -eq 'qa') { 'PrimaryBtn' } else { 'ActionBtn' })); $b.Tag = $s[4]
            $b.HorizontalAlignment = 'Left'; $b.Margin = Th 0 8 0 0
            $b.Add_Click({
                try {
                    if ($this.Tag -eq 'qa') { Open-QuickAssist; return }
                    $txt = Build-HelpReport
                    [System.Windows.Clipboard]::SetText($txt)
                    $f = Join-Path (Get-SessionFolder 'Desktop') 'Rapport AEROX PC Care.txt'
                    # Le Bureau est indiqué dans le registre de la personne (modifiable sans droits admin) : jamais dans un dossier de Windows
                    $dd = [IO.Path]::GetFullPath((Split-Path $f -Parent))
                    if ($dd -like "$env:SystemRoot*" -or $dd -like "$env:ProgramFiles*" -or $dd -like "${env:ProgramFiles(x86)}*" -or $dd -like "$env:ProgramData*" -or -not [AeroxSafeDelete]::IsDirectPath($dd)) { $f = $null }
                    elseif (Test-Path -LiteralPath $f) { $it = Get-Item -LiteralPath $f -Force; if ($it.Attributes -band [IO.FileAttributes]::ReparsePoint) { $f = $null } }
                    if ($f) { try { [IO.File]::WriteAllText($f, $txt, (New-Object System.Text.UTF8Encoding($true))) } catch { $f = $null } }
                    $this.Content = '✔ Rapport copié'
                    Write-UiLog ("Rapport d'aide copié dans le presse-papiers" + $(if ($f) { " et enregistré sur le Bureau (« Rapport AEROX PC Care.txt »)." } else { '.' }))
                    if (-not $script:Diag) { [System.Windows.MessageBox]::Show("Rapport copié.`n`nAstuce : lance d'abord le diagnostic pour que le rapport contienne les problèmes du PC.", $AppName, 'OK', 'Information') | Out-Null }
                } catch { Write-Bug -Context "Aide à distance" -ErrorRecord $_; Write-UiLog ("❌ " + $_.Exception.Message) }
            })
            Add-Child $tx $b
        }
        Add-Child $dp $tx
        $row.Child = $dp; Add-Child $sp $row
    }
    $n = New-Text ("Bon à savoir :`n" +
        "• La personne qui aide doit se connecter avec un compte Microsoft (gratuit). Toi, non.`n" +
        "• Si une fenêtre « Voulez-vous autoriser... » apparaît, c'est toi qui dois cliquer : la personne qui t'aide ne la voit pas.`n" +
        "• Pour aider quelqu'un toi-même : ouvre Assistance rapide et clique sur « Aider quelqu'un ».") 12 '#8B93A7'
    $n.Margin = Th 0 6 0 0; $n.LineHeight = 19; Add-Child $sp $n
    $close = New-Object System.Windows.Controls.Button; $close.Content = 'Fermer'; $close.Style = $window.FindResource('TextBtn'); $close.HorizontalAlignment = 'Right'; $close.Margin = Th 0 12 0 0
    $close.Add_Click({ $script:HelpWin.Close() }); Add-Child $sp $close
    $sv.Content = $sp; $w.Content = $sv
    [void]$w.ShowDialog()
}

# ---------------------------------------------------------------- Fenêtre : programmes au démarrage (choix appli par appli)
function Show-StartupDialog($Issue) {
    if ($script:Job) { [System.Windows.MessageBox]::Show("Une opération est en cours, attends qu'elle se termine.", $AppName, 'OK', 'Information') | Out-Null; return }
    $entries = @(Get-StartupEntries)
    if (-not $entries.Count) { [System.Windows.MessageBox]::Show("Aucun programme ne se lance au démarrage.", $AppName, 'OK', 'Information') | Out-Null; return }
    $order = @{ back = -1; optional = 0; other = 1; mine = 2; keep = 3 }
    $kindOf = { param($e) if (Test-StartupBack $e) { 'back' } elseif ((Get-StartupKind $e) -ne 'keep' -and (Test-StartupKept $e)) { 'mine' } else { Get-StartupKind $e } }
    $entries = @($entries | Sort-Object @{ Expression = { $order[(& $kindOf $_)] } }, @{ Expression = { $_.Name } })

    $w = New-Dialog "$AppName : programmes au démarrage" 640
    $script:StartupWin = $w; $script:StartupChoice = $null
    $script:StartupRows = New-Object System.Collections.ArrayList
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = Th 24 22 24 20
    Add-Child $sp (New-Text "Programmes au démarrage" 18 '#FFFFFF' 'Bold')
    $p = New-Text "Coché = se lance tout seul quand tu allumes le PC. Décoche ce dont tu n'as pas besoin dès l'allumage : l'appli reste installée et tu l'ouvres quand tu veux.`nCe que tu laisses coché est validé : le diagnostic ne te le signalera plus." 13 '#A9B0C2'
    $p.Margin = Th 0 6 0 12; Add-Child $sp $p

    $list = New-Object System.Windows.Controls.StackPanel
    foreach ($e in $entries) {
        $kind = & $kindOf $e
        $row = New-Object System.Windows.Controls.Border; $row.Background = Brush '#171A23'; $row.CornerRadius = Corner 10; $row.Padding = Th 12 9 12 9; $row.Margin = Th 0 0 6 6
        $dp = New-Object System.Windows.Controls.DockPanel
        $pill = switch ($kind) { 'optional' { New-Pill 'Pas indispensable' '#B9A8FF' '#2A2350' } 'keep' { New-Pill 'À garder' '#4ADE80' '#173326' } 'mine' { New-Pill 'Validé par toi' '#7DD3FC' '#12303F' } 'back' { New-Pill 'De nouveau actif' '#FFB547' '#3A2A12' } default { $null } }
        if ($pill) { [System.Windows.Controls.DockPanel]::SetDock($pill, 'Right'); Add-Child $dp $pill }
        $cb = New-Object System.Windows.Controls.CheckBox; $cb.IsChecked = [bool]$e.Enabled; $cb.VerticalContentAlignment = 'Center'; $cb.Cursor = 'Hand'
        $txt = New-Object System.Windows.Controls.StackPanel; $txt.Margin = Th 8 0 0 0
        Add-Child $txt (New-Text $e.Name 14 '#FFFFFF' 'SemiBold')
        $cmd = New-Text ($e.Command -replace '"', '') 11 '#7A8399'; $cmd.TextWrapping = 'NoWrap'; $cmd.TextTrimming = 'CharacterEllipsis'; $cmd.MaxWidth = 420; Add-Child $txt $cmd
        if ($kind -eq 'back') { $bk = New-Text "Tu l'avais décoché, mais il est de nouveau actif : le plus souvent, c'est l'appli qui se remet toute seule au démarrage. Pour que ça tienne : ouvre-la, va dans ses paramètres et désactive son option du type « Lancer au démarrage de Windows »." 11.5 '#FFB547'; $bk.MaxWidth = 440; $bk.Margin = Th 0 3 0 0; Add-Child $txt $bk }
        $cb.Content = $txt
        Add-Child $dp $cb
        $row.Child = $dp; Add-Child $list $row
        [void]$script:StartupRows.Add(@{ Entry = $e; Check = $cb; Kind = $kind })
    }
    $sv = New-Object System.Windows.Controls.ScrollViewer; $sv.VerticalScrollBarVisibility = 'Auto'; $sv.MaxHeight = 400; $sv.Content = $list
    Add-Child $sp $sv

    $bar = New-Object System.Windows.Controls.DockPanel; $bar.Margin = Th 0 14 0 0
    $right = New-Object System.Windows.Controls.StackPanel; $right.Orientation = 'Horizontal'; [System.Windows.Controls.DockPanel]::SetDock($right, 'Right')
    $bCancel = New-Object System.Windows.Controls.Button; $bCancel.Content = 'Annuler'; $bCancel.Style = $window.FindResource('TextBtn'); $bCancel.Margin = Th 0 0 8 0
    $bApply  = New-Object System.Windows.Controls.Button; $bApply.Content = 'Appliquer'; $bApply.Style = $window.FindResource('PrimaryBtn')
    Add-Child $right $bCancel; Add-Child $right $bApply; Add-Child $bar $right
    $left = New-Object System.Windows.Controls.StackPanel; $left.Orientation = 'Horizontal'
    $bSugg = New-Object System.Windows.Controls.Button; $bSugg.Content = 'Décocher les suggestions'; $bSugg.Style = $window.FindResource('GhostBtn')
    $bTm   = New-Object System.Windows.Controls.Button; $bTm.Content = 'Gestionnaire des tâches'; $bTm.Style = $window.FindResource('TextBtn')
    Add-Child $left $bSugg; Add-Child $left $bTm
    if (@($script:Settings.StartupKept).Count) {
        $bReset = New-Object System.Windows.Controls.Button; $bReset.Content = 'Oublier mes choix'; $bReset.Style = $window.FindResource('TextBtn')
        $bReset.ToolTip = "Le diagnostic te signalera de nouveau toutes les applis au démarrage."
        $bReset.Add_Click({ $script:Settings.StartupKept = @(); Save-Settings; Write-UiLog "Choix des programmes au démarrage oubliés."; $this.IsEnabled = $false; $this.Content = 'Choix oubliés' })
        Add-Child $left $bReset
    }
    Add-Child $bar $left
    Add-Child $sp $bar

    $bSugg.Add_Click({ foreach ($r in $script:StartupRows) { if ($r.Kind -eq 'optional') { $r.Check.IsChecked = $false } } })
    $bTm.Add_Click({ Start-Process taskmgr.exe -ArgumentList '/0 /startup' })
    $bCancel.Add_Click({ $script:StartupWin.Close() })
    $bApply.Add_Click({
        $dis = @(); $en = @(); $keepOff = @(); $kept = @()
        foreach ($r in $script:StartupRows) {
            $on = [bool]$r.Check.IsChecked
            if ($on -and $r.Kind -ne 'keep') { $kept += (Get-StartupKey $r.Entry) }
            if ($r.Entry.Enabled -and -not $on) { $dis += $r.Entry.Id; if ($r.Kind -eq 'keep') { $keepOff += $r.Entry.Name } }
            elseif (-not $r.Entry.Enabled -and $on) { $en += $r.Entry.Id }
        }
        $script:StartupChoice = @{ Dis = $dis; En = $en; KeepOff = $keepOff; Kept = $kept }
        $script:StartupWin.Close()
    })
    $w.Content = $sp
    [void]$w.ShowDialog()

    $c = $script:StartupChoice
    if (-not $c) { return }
    # Ce qui reste coché est validé : plus signalé aux prochains diagnostics (les applis décochées ne sont plus validées)
    $disKeys = @($script:StartupRows | Where-Object { -not [bool]$_.Check.IsChecked } | ForEach-Object { Get-StartupKey $_.Entry })
    $script:Settings.StartupKept = @(@($script:Settings.StartupKept | Where-Object { $disKeys -notcontains $_ }) + @($c.Kept) | Where-Object { $_ } | Sort-Object -Unique)
    # Laissé coché alors qu'il était « de nouveau actif » : tu le gardes, il n'est plus signalé
    $onKeys = @($script:StartupRows | Where-Object { [bool]$_.Check.IsChecked } | ForEach-Object { $_.Entry.Key })
    $AppInfo.StartupOff = @($AppInfo.StartupOff | Where-Object { $_ -and $onKeys -notcontains $_ })
    Save-Settings
    if ($c.Kept.Count) { Write-UiLog ("✅ {0} appli(s) gardée(s) au démarrage : le diagnostic ne te les signalera plus." -f $c.Kept.Count) }
    if (-not $c.Dis.Count -and -not $c.En.Count) {
        if ($Issue) { $Issue.Status = 'done'; Write-UiLog "✅ Programmes au démarrage vérifiés : tu as tout gardé tel quel."; Update-DiagBadge; Refresh-Page }
        return
    }
    if ($c.KeepOff.Count -and -not (Confirm-Box ("Tu as décoché des éléments marqués « À garder » :`n`n• " + ($c.KeepOff -join "`n• ") + "`n`nCe sont souvent l'antivirus ou des pilotes (son, carte graphique). Continuer quand même ?"))) { return }
    $q = { param($a) ConvertTo-PsList @($a) }
    $action = "Set-StartupApps -Disable $(& $q $c.Dis) -Enable $(& $q $c.En)"
    if ($Issue) { $Issue.Status = 'fixing'; $script:FixingIssue = $Issue }
    if (-not (Start-AeroxTask $action 'Programmes au démarrage')) { if ($Issue) { $Issue.Status = 'open'; $script:FixingIssue = $null } }
    Refresh-Page
}

# ---------------------------------------------------------------- Fenêtre d'erreurs
function New-Dialog([string]$Title, [double]$Width) {
    $w = New-Object System.Windows.Window
    $w.Title = $Title; $w.Width = $Width; $w.SizeToContent = 'Height'; $w.MaxHeight = 720
    $w.WindowStartupLocation = 'CenterOwner'; $w.Owner = $window; $w.ResizeMode = 'NoResize'
    $w.Background = Brush '#141720'; $w.FontFamily = 'Segoe UI'; $w.ShowInTaskbar = $false
    return $w
}

function Show-ErrorDialog($Errors, [string]$Label) {
    $w = New-Dialog "$AppName : problème rencontré" 600
    $script:DialogChoice = $null
    $sv = New-Object System.Windows.Controls.ScrollViewer; $sv.VerticalScrollBarVisibility = 'Auto'
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = Th 24 22 24 20
    $head = New-Object System.Windows.Controls.WrapPanel
    Add-Child $head (New-Text $(if ($Errors.Count -gt 1) { "$($Errors.Count) problèmes pendant « $Label »" } else { "Un problème pendant « $Label »" }) 17 '#FFFFFF' 'Bold')
    Add-Child $sp $head
    $p = New-Text "Le reste s'est bien passé. Voici ce qui a coincé, pourquoi, et comment le régler :" 13 '#A9B0C2'; $p.Margin = Th 0 6 0 14; Add-Child $sp $p
    foreach ($e in $Errors) {
        $e.Status = 'open'
        $card = New-IssueCard $e -IsError
        # Les boutons « réparer » de la fenêtre ferment la fenêtre et lancent la réparation
        Add-Child $sp $card
    }
    $row = New-Object System.Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'; $row.HorizontalAlignment = 'Right'; $row.Margin = Th 0 10 0 0
    if (@($Errors | Where-Object { $_.IsBug }).Count) {
        $rb = New-Button "Signaler ce bug" 'ActionBtn' @{ Kind = 'dlg'; Choice = 'report' } $false; $rb.Margin = Th 0 0 8 0; Add-Child $row $rb
    }
    $cb = New-Button "Fermer" 'ActionBtn' @{ Kind = 'dlg'; Choice = 'close' } $false; Add-Child $row $cb
    Add-Child $sp $row
    $sv.Content = $sp; $w.Content = $sv
    # Redirige les clics des boutons de la fenêtre
    $w.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
        param($s, $ev)
        $t = $ev.OriginalSource.Tag
        if (-not $t) { return }
        $ev.Handled = $true
        if ($t.Kind -eq 'steps') { $script:DialogChoice = @{ Reopen = $true }; $s.Close(); return }
        $script:DialogChoice = $t
        $s.Close()
    })
    [void]$w.ShowDialog()
    $c = $script:DialogChoice
    if (-not $c) { return }
    if ($c.Reopen) { Show-ErrorDialog $Errors $Label; return }
    if ($c.Kind -eq 'errfix') {
        $e = $c.Issue
        if ($e.Confirm -and -not (Confirm-Box $e.Confirm)) { return }
        [void](Start-AeroxTask $e.FixAction $e.FixLabel)
    } elseif ($c.Choice -eq 'report') {
        Show-BugReport ("Erreur pendant « $Label » : " + (($Errors | Where-Object { $_.IsBug } | ForEach-Object { $_.Cause }) -join ' / '))
    }
}

# ---------------------------------------------------------------- Rapport de bug (journal + GitHub)
function Get-SensitiveNames {
    if ($script:SensitiveNames) { return $script:SensitiveNames }
    $n = New-Object System.Collections.ArrayList
    foreach ($x in @($env:USERNAME, $env:COMPUTERNAME, $env:USERDOMAIN)) { if ($x -and $x.Length -ge 3) { [void]$n.Add($x) } }
    try { foreach ($p in Get-UserProfiles) { $leaf = Split-Path $p -Leaf; if ($leaf.Length -ge 3) { [void]$n.Add($leaf) } } } catch {}
    $script:SensitiveNames = @($n | Select-Object -Unique | Sort-Object Length -Descending)
    return $script:SensitiveNames
}
function Protect-Text([string]$Text) {
    # Mot entier uniquement : un compte « Admin » ne doit pas transformer « administrateur » en « <utilisateur>istrateur »
    foreach ($n in Get-SensitiveNames) { $Text = $Text -replace ('(?<![\p{L}\d_])' + [regex]::Escape($n) + '(?![\p{L}\d_])'), '<utilisateur>' }
    $Text = $Text -replace '[\w\.\-]+@[\w\-]+\.[\w\.\-]+', '<email>'
    return $Text
}
function Get-NewBugs {
    $since = [datetime]::MinValue
    try { if (Test-Path $LastReportFile) { $since = [datetime]::Parse((Get-Content -LiteralPath $LastReportFile -Raw).Trim()) } } catch {}
    $list = @()
    if (Test-Path $BugFile) {
        foreach ($l in Get-Content -LiteralPath $BugFile -Encoding UTF8 -ErrorAction SilentlyContinue) {
            try { $o = $l | ConvertFrom-Json; if ([datetime]::Parse($o.date) -gt $since) { $list += $o } } catch {}
        }
    }
    return @($list | Select-Object -Last 25)
}
function Build-BugReport([string]$Description, [int]$LogLines = 60, [int]$MaxBugs = 25) {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $disp = try { (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop).DisplayVersion } catch { '' }
    $bugs = @(Get-NewBugs | Select-Object -Last $MaxBugs)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("## Rapport $AppName")
    [void]$sb.AppendLine("- Version : $AppVersion")
    [void]$sb.AppendLine("- Windows : $($os.Caption) $disp (build $($os.BuildNumber)), langue $((Get-Culture).Name)")
    [void]$sb.AppendLine("- Date : $(Get-Date -Format 'dd/MM/yyyy HH:mm')")
    if ($script:Diag) { [void]$sb.AppendLine("- Dernier diagnostic : $(Get-Score)/100, problèmes : " + (($script:Diag.Issues | ForEach-Object { "$($_.Id)($($_.Status))" }) -join ', ')) }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('### Ce qui s''est passé')
    [void]$sb.AppendLine($(if ($Description.Trim()) { $Description.Trim() } else { '(non précisé)' }))
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("### Bugs et erreurs enregistrés ($($bugs.Count) depuis le dernier rapport)")
    if ($bugs.Count) { foreach ($b in $bugs) { [void]$sb.AppendLine(("- [{0}] [{1}] v{2} {3} : {4} {5}" -f $b.date, $b.type, $b.version, $b.context, $b.message, $b.position).Trim()) } }
    else { [void]$sb.AppendLine('(aucun)') }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('### Fin du journal')
    [void]$sb.AppendLine('```')
    $lines = @($LogBox.Text -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last $LogLines)
    foreach ($l in $lines) { [void]$sb.AppendLine($l) }
    [void]$sb.AppendLine('```')
    return (Protect-Text $sb.ToString())
}
function Save-ReportDone { try { Set-Content -LiteralPath $LastReportFile -Value (Get-Date).ToString('s') -Encoding UTF8 } catch {} }

function Show-BugReport([string]$Prefill) {
    $w = New-Dialog "$AppName : signaler un bug" 640
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = Th 24 22 24 20
    Add-Child $sp (New-Text "Signaler un bug" 18 '#FFFFFF' 'Bold')
    $p = New-Text "Ce rapport aide le développeur (AEROX) à corriger les bugs. Il ne contient ni ton nom, ni tes fichiers, ni tes mots de passe : uniquement la version de Windows, les erreurs du logiciel et la fin du journal. Tu peux tout vérifier ci-dessous." 13 '#A9B0C2'
    $p.Margin = Th 0 6 0 14; Add-Child $sp $p
    Add-Child $sp (New-Text "Décris ce qui s'est passé (facultatif)" 12 '#C3CAD9' 'SemiBold')
    $desc = New-Object System.Windows.Controls.TextBox
    $desc.Text = $Prefill; $desc.AcceptsReturn = $true; $desc.TextWrapping = 'Wrap'; $desc.Height = 70; $desc.Margin = Th 0 6 0 12
    $desc.Background = Brush '#0E1016'; $desc.Foreground = Brush '#E6E9F2'; $desc.BorderBrush = Brush '#2E3446'; $desc.Padding = Th 8 6 8 6; $desc.FontSize = 13
    $desc.CaretBrush = Brush '#E6E9F2'
    Add-Child $sp $desc
    Add-Child $sp (New-Text "Contenu du rapport" 12 '#C3CAD9' 'SemiBold')
    $prev = New-Object System.Windows.Controls.TextBox
    $prev.IsReadOnly = $true; $prev.TextWrapping = 'Wrap'; $prev.Height = 220; $prev.VerticalScrollBarVisibility = 'Auto'; $prev.Margin = Th 0 6 0 14
    $prev.Background = Brush '#0A0C11'; $prev.Foreground = Brush '#C3CAD9'; $prev.BorderBrush = Brush '#2E3446'; $prev.FontFamily = 'Cascadia Mono, Consolas'; $prev.FontSize = 11.5; $prev.Padding = Th 8 6 8 6
    $prev.Text = Build-BugReport $Prefill
    Add-Child $sp $prev
    $script:RptWin = $w; $script:RptDesc = $desc; $script:RptPrev = $prev
    $desc.Add_TextChanged({ $script:RptPrev.Text = Build-BugReport $script:RptDesc.Text })
    $note = New-Text "« Copier » : colle le rapport (Ctrl+V) dans un message Discord ou un mail au développeur." 12 '#7A8399'; $note.Margin = Th 0 0 0 10
    if ($sync.BugRelay) { $note.Text = "« Envoyer le rapport » l'envoie directement au développeur, sans compte à créer. Il sera visible dans la liste publique des bugs du logiciel sur GitHub (sans ton nom ni celui du PC)." }
    elseif ($GitHubRepo) { $note.Text = "« Envoyer sur GitHub » ouvre la page de rapport préremplie (compte GitHub gratuit requis). Sinon, « Copier » puis colle-le dans un message au développeur." }
    Add-Child $sp $note
    $row = New-Object System.Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'; $row.HorizontalAlignment = 'Right'
    $bClose = New-Object System.Windows.Controls.Button; $bClose.Content = 'Fermer'; $bClose.Style = $window.FindResource('TextBtn'); $bClose.Margin = Th 0 0 8 0
    $bCopy  = New-Object System.Windows.Controls.Button; $bCopy.Content = 'Copier le rapport'; $bCopy.Style = $window.FindResource($(if ($GitHubRepo) { 'ActionBtn' } else { 'PrimaryBtn' }))
    Add-Child $row $bClose; Add-Child $row $bCopy
    if ($sync.BugRelay) {
        $bCopy.Style = $window.FindResource('ActionBtn')
        $bSend = New-Object System.Windows.Controls.Button; $bSend.Content = 'Envoyer le rapport'; $bSend.Style = $window.FindResource('PrimaryBtn'); $bSend.Margin = Th 8 0 0 0
        Add-Child $row $bSend
        $bSend.Add_Click({
            $btn = $this
            try {
                $btn.IsEnabled = $false; $btn.Content = 'Envoi...'
                [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
                $title = "[Bug v$AppVersion] " + $(if ($script:RptDesc.Text.Trim()) { Hide-Profanity (($script:RptDesc.Text.Trim() -split "`r?`n")[0]) } else { "Rapport automatique" })
                if ($title.Length -gt 100) { $title = $title.Substring(0, 97) + '...' }
                $payload = @{ title = $title; body = (Build-BugReport (Hide-Profanity $script:RptDesc.Text)); version = $AppVersion } | ConvertTo-Json -Compress
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
                $script:RptBtn = $btn
                Send-RelayAsync $sync.BugRelay $bytes {
                    param($res)
                    [System.Windows.Input.Mouse]::OverrideCursor = $null
                    if (-not $res.Ok) {
                        $script:RptBtn.IsEnabled = $true; $script:RptBtn.Content = 'Envoyer le rapport'
                        [System.Windows.MessageBox]::Show("Le rapport n'a pas pu être envoyé : $($res.Err)`n`nUtilise « Copier le rapport » et colle-le dans un message au développeur.", $AppName, 'OK', 'Warning') | Out-Null
                        return
                    }
                    $r = $res.R
                    Save-ReportDone
                    Write-UiLog ("✔ Rapport de bug envoyé" + $(if ($r.number) { " (n°$($r.number))" } else { '' }) + ". Merci !")
                    [System.Windows.MessageBox]::Show("Rapport envoyé" + $(if ($r.number) { " (n°$($r.number))" } else { '' }) + ". Merci, ça aide à corriger le logiciel !", $AppName, 'OK', 'Information') | Out-Null
                    $script:RptWin.Close()
                }
            } catch {
                [System.Windows.Input.Mouse]::OverrideCursor = $null
                $btn.IsEnabled = $true; $btn.Content = 'Envoyer le rapport'
                $m = $_.Exception.Message
                try { $resp = $_.ErrorDetails.Message | ConvertFrom-Json; if ($resp.error) { $m = $resp.error } } catch {}
                [System.Windows.MessageBox]::Show("Le rapport n'a pas pu être envoyé : $m`n`nUtilise « Copier le rapport » et colle-le dans un message au développeur.", $AppName, 'OK', 'Warning') | Out-Null
            }
        })
    }
    if ($GitHubRepo) {
        $bGh = New-Object System.Windows.Controls.Button; $bGh.Content = $(if ($sync.BugRelay) { 'Avec mon compte GitHub' } else { 'Envoyer sur GitHub' }); $bGh.Style = $window.FindResource($(if ($sync.BugRelay) { 'TextBtn' } else { 'PrimaryBtn' })); $bGh.Margin = Th 8 0 0 0
        Add-Child $row $bGh
        $bGh.Add_Click({
            try {
                $full = Build-BugReport $script:RptDesc.Text
                [System.Windows.Clipboard]::SetText($full)
                $title = "[Bug v$AppVersion] " + $(if ($script:RptDesc.Text.Trim()) { ($script:RptDesc.Text.Trim() -split "`r?`n")[0] } else { "Rapport automatique" })
                if ($title.Length -gt 90) { $title = $title.Substring(0, 87) + '...' }
                $lines = 40; $bugs = 15
                do {
                    $body = Build-BugReport $script:RptDesc.Text $lines $bugs
                    $url = "https://github.com/$GitHubRepo/issues/new?labels=bug&title=" + [uri]::EscapeDataString($title) + "&body=" + [uri]::EscapeDataString($body + "`n_(Si le rapport semble coupé, colle le rapport complet copié dans ton presse-papiers.)_")
                    $lines = [math]::Floor($lines / 2); $bugs = [math]::Max([double]3, [math]::Floor($bugs / 2))
                } while ($url.Length -gt 7500 -and $lines -ge 2)
                [void](Open-Url $url)
                Save-ReportDone
                Write-UiLog "Rapport de bug ouvert sur GitHub (le rapport complet est aussi copié)."
                $script:RptWin.Close()
            } catch { [System.Windows.MessageBox]::Show("Impossible d'ouvrir GitHub : $($_.Exception.Message)`n`nUtilise « Copier le rapport » à la place.", $AppName, 'OK', 'Warning') | Out-Null }
        })
    }
    $bClose.Add_Click({ $script:RptWin.Close() })
    $bCopy.Add_Click({
        try {
            [System.Windows.Clipboard]::SetText((Build-BugReport $script:RptDesc.Text))
            Save-ReportDone
            Write-UiLog "Rapport de bug copié dans le presse-papiers."
            [System.Windows.MessageBox]::Show("Rapport copié ! Colle-le (Ctrl+V) dans un message au développeur.", $AppName, 'OK', 'Information') | Out-Null
            $script:RptWin.Close()
        } catch { [System.Windows.MessageBox]::Show("Impossible de copier : $($_.Exception.Message)", $AppName, 'OK', 'Warning') | Out-Null }
    })
    Add-Child $sp $row
    $w.Content = $sp
    [void]$w.ShowDialog()
}

# ---------------------------------------------------------------- Outils communs des fenêtres de choix
function New-DlgButton([string]$Text, [string]$Style) {
    $b = New-Object System.Windows.Controls.Button; $b.Content = $Text; $b.Style = $window.FindResource($Style); return $b
}
function New-CheckRow([bool]$Checked, $Content, $Right) {
    $row = New-Object System.Windows.Controls.Border; $row.Background = Brush '#171A23'; $row.CornerRadius = Corner 10; $row.Padding = Th 12 9 12 9; $row.Margin = Th 0 0 6 6
    $dp = New-Object System.Windows.Controls.DockPanel
    if ($Right) { [System.Windows.Controls.DockPanel]::SetDock($Right, 'Right'); Add-Child $dp $Right }
    $cb = New-Object System.Windows.Controls.CheckBox; $cb.IsChecked = $Checked; $cb.VerticalContentAlignment = 'Center'; $cb.Cursor = 'Hand'
    $cb.Content = $Content
    Add-Child $dp $cb
    $row.Child = $dp
    return @{ Row = $row; Check = $cb }
}

# ---------------------------------------------------------------- Fenêtre : choisir les mises à jour (et ignorer)
function Show-AppUpdatesDialog($Issue) {
    $apps = @($sync.AppList)
    if (-not $apps.Count) {
        [System.Windows.MessageBox]::Show("Tous tes logiciels sont à jour !", $AppName, 'OK', 'Information') | Out-Null
        if ($Issue) { $Issue.Status = 'done'; Update-DiagBadge; Refresh-Page }
        return
    }
    foreach ($a in $apps) { $a.Ignored = ($script:Settings.IgnoredApps -contains $a.Id) }
    $w = New-Dialog "$AppName : mises à jour des logiciels" 680
    $script:UpdWin = $w; $script:UpdChoice = $null; $script:UpdApps = $apps; $script:UpdRows = New-Object System.Collections.ArrayList
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = Th 24 22 24 20
    Add-Child $sp (New-Text "Mises à jour des logiciels" 18 '#FFFFFF' 'Bold')
    $p = New-Text "Coche ce que tu veux mettre à jour. « Ignorer » met un logiciel de côté : il ne sera plus proposé, ni touché par « Tout mettre à jour » (tu peux changer d'avis plus bas)." 13 '#A9B0C2'
    $p.Margin = Th 0 6 0 12; Add-Child $sp $p
    $list = New-Object System.Windows.Controls.StackPanel
    $script:UpdList = $list
    $sv = New-Object System.Windows.Controls.ScrollViewer; $sv.VerticalScrollBarVisibility = 'Auto'; $sv.MaxHeight = 430; $sv.Content = $list
    Add-Child $sp $sv
    $bar = New-Object System.Windows.Controls.DockPanel; $bar.Margin = Th 0 14 0 0
    $right = New-Object System.Windows.Controls.StackPanel; $right.Orientation = 'Horizontal'; [System.Windows.Controls.DockPanel]::SetDock($right, 'Right')
    $bCancel = New-DlgButton 'Annuler' 'TextBtn'; $bCancel.Margin = Th 0 0 8 0
    $bApply = New-DlgButton 'Mettre à jour' 'PrimaryBtn'; $script:UpdApply = $bApply
    Add-Child $right $bCancel; Add-Child $right $bApply; Add-Child $bar $right
    $bAll = New-DlgButton 'Tout cocher / décocher' 'GhostBtn'; $bAll.HorizontalAlignment = 'Left'; Add-Child $bar $bAll
    Add-Child $sp $bar
    $w.Content = $sp

    $script:RenderUpd = {
        $script:UpdList.Children.Clear(); $script:UpdRows.Clear()
        $active = @($script:UpdApps | Where-Object { -not $_.Ignored }); $ign = @($script:UpdApps | Where-Object { $_.Ignored })
        if (-not $active.Count) { $t = New-Text "Plus rien à mettre à jour (tout le reste est ignoré)." 13 '#8B93A7'; $t.Margin = Th 4 4 0 10; Add-Child $script:UpdList $t }
        foreach ($a in $active) {
            $txt = New-Object System.Windows.Controls.StackPanel; $txt.Margin = Th 8 0 0 0
            Add-Child $txt (New-Text $a.Name 14 '#FFFFFF' 'SemiBold')
            Add-Child $txt (New-Text ("{0}  →  {1}" -f $a.Version, $a.Available) 12 '#8B93A7')
            if ($a.Ghost) { Add-Child $txt (New-Text "Semble déjà désinstallé (il ne reste qu'une trace dans Windows) : le cocher le réinstallerait. Ne le coche que si tu l'utilises encore." 12 '#FFB547') }
            elseif ($a.Self) { Add-Child $txt (New-Text "Se met à jour tout seul ou par son propre lanceur : l'outil de Microsoft ne peut pas le faire à sa place. Rien à faire." 12 '#8B93A7') }
            $ib = New-DlgButton 'Ignorer' 'TextBtn'; $ib.Tag = $a; $ib.VerticalAlignment = 'Center'
            $ib.Add_Click({ $x = $this.Tag; $x.Ignored = $true; $script:Settings.IgnoredApps = @($script:Settings.IgnoredApps) + $x.Id; Save-Settings; & $script:RenderUpd })
            $r = New-CheckRow (-not $a.Ghost -and -not $a.Self) $txt $ib
            $r.Check.Add_Click({ & $script:CountUpd })
            Add-Child $script:UpdList $r.Row
            [void]$script:UpdRows.Add(@{ App = $a; Check = $r.Check })
        }
        if ($ign.Count) {
            $h = New-Text ("IGNORÉS ({0})" -f $ign.Count) 11.5 '#7A8399' 'Bold'; $h.Margin = Th 2 12 0 8; Add-Child $script:UpdList $h
            foreach ($a in $ign) {
                $row = New-Object System.Windows.Controls.Border; $row.Background = Brush '#13161E'; $row.CornerRadius = Corner 10; $row.Padding = Th 14 9 12 9; $row.Margin = Th 0 0 6 6
                $dp = New-Object System.Windows.Controls.DockPanel
                $ub = New-DlgButton 'Ne plus ignorer' 'TextBtn'; $ub.Tag = $a; [System.Windows.Controls.DockPanel]::SetDock($ub, 'Right'); Add-Child $dp $ub
                $ub.Add_Click({ $x = $this.Tag; $x.Ignored = $false; $script:Settings.IgnoredApps = @($script:Settings.IgnoredApps | Where-Object { $_ -ne $x.Id }); Save-Settings; & $script:RenderUpd })
                $txt = New-Object System.Windows.Controls.StackPanel
                Add-Child $txt (New-Text $a.Name 14 '#8B93A7' 'SemiBold')
                Add-Child $txt (New-Text ("{0}  →  {1}  (ignoré)" -f $a.Version, $a.Available) 12 '#6E768B')
                Add-Child $dp $txt
                $row.Child = $dp; Add-Child $script:UpdList $row
            }
        }
        & $script:CountUpd
    }
    $script:CountUpd = {
        $n = @($script:UpdRows | Where-Object { $_.Check.IsChecked }).Count
        $script:UpdApply.Content = $(if ($n) { "Mettre à jour ($n)" } else { 'Mettre à jour' })
        $script:UpdApply.IsEnabled = ($n -gt 0)
    }
    $bAll.Add_Click({ $any = @($script:UpdRows | Where-Object { -not $_.Check.IsChecked }).Count -gt 0; foreach ($r in $script:UpdRows) { $r.Check.IsChecked = $any }; & $script:CountUpd })
    $bCancel.Add_Click({ $script:UpdWin.Close() })
    $bApply.Add_Click({ $script:UpdChoice = @($script:UpdRows | Where-Object { $_.Check.IsChecked } | ForEach-Object { $_.App }); $script:UpdWin.Close() })
    & $script:RenderUpd
    [void]$w.ShowDialog()

    Update-DiagBadge
    $sel = $script:UpdChoice
    if (-not $sel -or -not $sel.Count) {
        if ($Issue -and -not @($apps | Where-Object { -not $_.Ignored -and -not $_.Self -and -not $_.Ghost }).Count) { $Issue.Status = 'done'; Write-UiLog "✅ Mises à jour : plus rien à faire (le reste est ignoré à ta demande ou se met à jour tout seul)."; Update-DiagBadge; Refresh-Page }
        return
    }
    if (-not (Confirm-Box ("Mettre à jour $($sel.Count) logiciel(s) ?`n`nFerme-les avant de continuer (regarde aussi les icônes près de l'horloge) : un logiciel ouvert ne peut pas être mis à jour."))) { return }
    $action = "Update-SelectedApps -Ids $(ConvertTo-PsList @($sel | ForEach-Object { $_.Id })) -Names $(ConvertTo-PsList @($sel | ForEach-Object { $_.Name })) -Versions $(ConvertTo-PsList @($sel | ForEach-Object { "$($_.Available)" }))"
    if ($Issue) { $Issue.Status = 'fixing'; $script:FixingIssue = $Issue }
    if (-not (Start-AeroxTask $action ("Mise à jour de {0} logiciel(s)" -f $sel.Count))) { if ($Issue) { $Issue.Status = 'open'; $script:FixingIssue = $null } }
    Refresh-Page
}

# ---------------------------------------------------------------- Fenêtre : nettoyage approfondi (catégories + tailles)
function Show-CleanDialog($Issue) {
    $cats = @($sync.CleanList)
    if (-not $cats.Count) { return }
    $w = New-Dialog "$AppName : nettoyage approfondi" 700
    $script:CleanWin = $w; $script:CleanChoice = $null; $script:CleanRows = New-Object System.Collections.ArrayList
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = Th 24 22 24 20
    Add-Child $sp (New-Text "Nettoyage approfondi" 18 '#FFFFFF' 'Bold')
    $p = New-Text "Voici ce qui peut être supprimé sans risque pour tes fichiers perso. Les cases cochées sont conseillées ; les autres sont à choisir en connaissance de cause (lis la description)." 13 '#A9B0C2'
    $p.Margin = Th 0 6 0 12; Add-Child $sp $p
    $list = New-Object System.Windows.Controls.StackPanel
    foreach ($c in $cats) {
        $txt = New-Object System.Windows.Controls.StackPanel; $txt.Margin = Th 8 0 0 0
        Add-Child $txt (New-Text $c.Name 14 '#FFFFFF' 'SemiBold')
        $d = New-Text $c.Desc 12 '#8B93A7'; $d.MaxWidth = 470; Add-Child $txt $d
        $sz = if ($c.Size -ge 0) { Format-Size $c.Size } else { '?' }
        $st = New-Text $sz 14 $(if ($c.Size -ge 1GB) { '#4ADE80' } elseif ($c.Size -lt 0) { '#7A8399' } else { '#C3CAD9' }) 'SemiBold'
        $st.VerticalAlignment = 'Center'; $st.Margin = Th 12 0 0 0; $st.MinWidth = 70; $st.TextAlignment = 'Right'
        $r = New-CheckRow ([bool]$c.Default) $txt $st
        $r.Check.Add_Click({ & $script:CountClean })
        Add-Child $list $r.Row
        [void]$script:CleanRows.Add(@{ Cat = $c; Check = $r.Check })
    }
    $sv = New-Object System.Windows.Controls.ScrollViewer; $sv.VerticalScrollBarVisibility = 'Auto'; $sv.MaxHeight = 450; $sv.Content = $list
    Add-Child $sp $sv
    $bar = New-Object System.Windows.Controls.DockPanel; $bar.Margin = Th 0 14 0 0
    $right = New-Object System.Windows.Controls.StackPanel; $right.Orientation = 'Horizontal'; [System.Windows.Controls.DockPanel]::SetDock($right, 'Right')
    $bCancel = New-DlgButton 'Annuler' 'TextBtn'; $bCancel.Margin = Th 0 0 8 0
    $bApply = New-DlgButton 'Nettoyer la sélection' 'PrimaryBtn'
    Add-Child $right $bCancel; Add-Child $right $bApply; Add-Child $bar $right
    $script:CleanTotal = New-Text '' 13 '#C3CAD9' 'SemiBold'; $script:CleanTotal.VerticalAlignment = 'Center'; Add-Child $bar $script:CleanTotal
    Add-Child $sp $bar
    $w.Content = $sp
    $script:CountClean = {
        $t = [double]0; $unk = $false
        foreach ($r in $script:CleanRows) { if ($r.Check.IsChecked) { if ($r.Cat.Size -gt 0) { $t += $r.Cat.Size } elseif ($r.Cat.Size -lt 0) { $unk = $true } } }
        $script:CleanTotal.Text = "Environ " + (Format-Size $t) + $(if ($unk) { " + ce que trouvera Windows" } else { '' })
    }
    $bCancel.Add_Click({ $script:CleanWin.Close() })
    $bApply.Add_Click({ $script:CleanChoice = @($script:CleanRows | Where-Object { $_.Check.IsChecked } | ForEach-Object { $_.Cat }); $script:CleanWin.Close() })
    & $script:CountClean
    [void]$w.ShowDialog()

    $sel = $script:CleanChoice
    if (-not $sel -or -not $sel.Count) { return }
    $risky = @($sel | Where-Object { $_.Id -in 'recycle', 'winold', 'resetbase', 'hiber' })
    $msg = "Nettoyer $($sel.Count) catégorie(s) ?`n`n" + (($sel | ForEach-Object { "• " + $_.Name }) -join "`n")
    if ($risky.Count) { $msg += "`n`n⚠ Irréversible :`n" + (($risky | ForEach-Object { "• " + $_.Name }) -join "`n") }
    if ($sel | Where-Object { $_.Id -in 'windows', 'components', 'resetbase' }) { $msg += "`n`nLe nettoyage Windows et des composants peut prendre 10 à 30 minutes : laisse le logiciel ouvert." }
    if (-not (Confirm-Box $msg)) { return }
    if ($Issue) { $Issue.Status = 'fixing'; $script:FixingIssue = $Issue }
    if (-not (Start-AeroxTask ("Invoke-DeepClean -Ids " + (ConvertTo-PsList @($sel | ForEach-Object { $_.Id }))) 'Nettoyage approfondi')) { if ($Issue) { $Issue.Status = 'open'; $script:FixingIssue = $null } }
    Refresh-Page
}

# ---------------------------------------------------------------- Fenêtre : logiciels installés et conseils de désinstallation
function Show-UninstallDialog($Issue) {
    $apps = @($sync.InstalledApps)
    if (-not $apps.Count) { return }
    $w = New-Dialog "$AppName : logiciels installés" 760
    $script:UniWin = $w; $script:UniApps = $apps; $script:UniFilter = ''
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = Th 24 22 24 20
    Add-Child $sp (New-Text "Logiciels installés" 18 '#FFFFFF' 'Bold')
    $p = New-Text "En haut, ce qu'AEROX te conseille d'enlever, avec la raison. « Désinstaller » lance le désinstalleur officiel du logiciel : suis ses étapes. Dans le doute (pilote, Microsoft Visual C++, .NET…), n'y touche pas." 13 '#A9B0C2'
    $p.Margin = Th 0 6 0 10; Add-Child $sp $p
    $search = New-Object System.Windows.Controls.TextBox; $search.Margin = Th 0 0 0 10; $search.Padding = Th 8 6 8 6; $search.FontSize = 13
    $search.Background = Brush '#0E1016'; $search.Foreground = Brush '#E6E9F2'; $search.BorderBrush = Brush '#2E3446'; $search.CaretBrush = Brush '#E6E9F2'
    $search.ToolTip = 'Rechercher un logiciel'
    $fbar = New-Object System.Windows.Controls.DockPanel; $fbar.Margin = Th 0 0 0 10
    $drv = New-Object System.Windows.Controls.ComboBox; $drv.MinWidth = 150; $drv.Margin = Th 10 0 0 0; $drv.FontSize = 13; $drv.VerticalContentAlignment = 'Center'
    [void]$drv.Items.Add('Tous les disques')
    foreach ($d in @($apps | ForEach-Object { $_.Drive } | Where-Object { $_ } | Sort-Object -Unique)) {
        $n = @($apps | Where-Object { $_.Drive -eq $d }).Count
        [void]$drv.Items.Add("Disque $d ($n)")
    }
    $drv.SelectedIndex = 0
    [System.Windows.Controls.DockPanel]::SetDock($drv, 'Right'); Add-Child $fbar $drv
    $search.Margin = Th 0 0 0 0; Add-Child $fbar $search
    Add-Child $sp $fbar
    $script:UniDrive = ''
    $drv.Add_SelectionChanged({ $t = [string]$this.SelectedItem; $script:UniDrive = $(if ($t -match '^Disque ([A-Z]:)') { $matches[1] } else { '' }); & $script:RenderUni })
    $list = New-Object System.Windows.Controls.StackPanel; $script:UniList = $list
    $sv = New-Object System.Windows.Controls.ScrollViewer; $sv.VerticalScrollBarVisibility = 'Auto'; $sv.Height = 470; $sv.Content = $list
    Add-Child $sp $sv
    $row = New-Object System.Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'; $row.HorizontalAlignment = 'Right'; $row.Margin = Th 0 12 0 0
    $bSet = New-DlgButton 'Ouvrir les Paramètres Windows' 'TextBtn'; $bSet.Margin = Th 0 0 8 0
    $bClose = New-DlgButton 'Fermer' 'PrimaryBtn'
    Add-Child $row $bSet; Add-Child $row $bClose; Add-Child $sp $row
    $w.Content = $sp

    $script:RenderUni = {
        $script:UniList.Children.Clear()
        $f = $script:UniFilter
        $dv = $script:UniDrive
        $vis = @($script:UniApps | Where-Object { -not $_.Removed -and (-not $dv -or $_.Drive -eq $dv) -and (-not $f -or $_.Name -like "*$f*" -or $_.Publisher -like "*$f*" -or $_.Location -like "*$f*") })
        $groups = @(
            @('CONSEILLÉ DE DÉSINSTALLER', @($vis | Where-Object { $_.Tag -eq 'reco' }), '#FFB547'),
            @('À VOIR SELON TON USAGE', @($vis | Where-Object { $_.Tag -eq 'maybe' }), '#B9A8FF'),
            @('TOUS LES AUTRES LOGICIELS (DU PLUS GROS AU PLUS PETIT)', @($vis | Where-Object { -not $_.Tag } | Sort-Object { -$_.Size }), '#7A8399')
        )
        foreach ($g in $groups) {
            if (-not $g[1].Count) { continue }
            $h = New-Text ("{0} ({1})" -f $g[0], $g[1].Count) 11.5 $g[2] 'Bold'; $h.Margin = Th 2 10 0 8; Add-Child $script:UniList $h
            foreach ($a in $g[1]) {
                $b = New-Object System.Windows.Controls.Border; $b.Background = Brush '#171A23'; $b.CornerRadius = Corner 10; $b.Padding = Th 14 10 12 10; $b.Margin = Th 0 0 6 6
                $dp = New-Object System.Windows.Controls.DockPanel
                $btn = New-DlgButton $(if ($a.Pending) { 'En cours…' } else { 'Désinstaller' }) $(if ($a.Tag -eq 'reco') { 'PrimaryBtn' } else { 'ActionBtn' }); $btn.Tag = $a; $btn.VerticalAlignment = 'Center'; $btn.Margin = Th 12 0 0 0
                if ($a.Pending) { $btn.IsEnabled = $false }
                $btn.Add_Click({ Invoke-UninstallApp $this.Tag })
                [System.Windows.Controls.DockPanel]::SetDock($btn, 'Right'); Add-Child $dp $btn
                if ($a.Location) {
                    $ob = New-DlgButton 'Dossier' 'TextBtn'; $ob.Tag = $a.Location; $ob.VerticalAlignment = 'Center'; $ob.ToolTip = 'Ouvrir le dossier du logiciel'
                    $ob.Add_Click({ Start-Process explorer.exe "`"$($this.Tag)`"" })
                    [System.Windows.Controls.DockPanel]::SetDock($ob, 'Right'); Add-Child $dp $ob
                }
                $t = New-Object System.Windows.Controls.StackPanel
                Add-Child $t (New-Text $a.Name 14 '#FFFFFF' 'SemiBold')
                $meta = @(); if ($a.Drive) { $meta += "Disque $($a.Drive)" }; if ($a.Publisher) { $meta += $a.Publisher }; if ($a.Size -gt 0) { $meta += (Format-Size $a.Size) }; if ($a.Date) { $meta += ("installé le " + $a.Date.ToString('dd/MM/yyyy')) }; if ($a.LastUsed) { $meta += ("utilisé le " + $a.LastUsed.ToString('dd/MM/yyyy')) }
                if ($meta.Count) { Add-Child $t (New-Text ($meta -join '  ·  ') 12 '#8B93A7') }
                if ($a.Location) { $lt = New-Text $a.Location 11 '#6E768B'; $lt.FontFamily = 'Cascadia Mono, Consolas'; $lt.TextTrimming = 'CharacterEllipsis'; $lt.TextWrapping = 'NoWrap'; $lt.ToolTip = $a.Location; Add-Child $t $lt }
                elseif ($a.Kind -eq 'win32') { Add-Child $t (New-Text 'Emplacement non indiqué par le logiciel' 11 '#6E768B') }
                if ($a.Reason) { $r = New-Text $a.Reason 12 $(if ($a.Tag -eq 'reco') { '#FFB547' } else { '#B9A8FF' }); $r.Margin = Th 0 3 0 0; Add-Child $t $r }
                if ($a.Pending) { $r = New-Text "Désinstallation en cours : termine-la dans la fenêtre du désinstalleur. Le logiciel disparaîtra d'ici dès qu'il sera vraiment désinstallé." 12 '#4ADE80'; $r.Margin = Th 0 3 0 0; Add-Child $t $r }
                elseif ($a.NotRemoved) { $r = New-Text "Toujours installé : la désinstallation a été annulée ou n'a pas abouti." 12 '#FFB547'; $r.Margin = Th 0 3 0 0; Add-Child $t $r }
                Add-Child $dp $t
                $b.Child = $dp; Add-Child $script:UniList $b
            }
        }
        if (-not $vis.Count) { $e = New-Text "Aucun logiciel trouvé." 13 '#8B93A7'; $e.Margin = Th 4 8 0 0; Add-Child $script:UniList $e }
    }
    $search.Add_TextChanged({ $script:UniFilter = $this.Text.Trim(); & $script:RenderUni })
    $bSet.Add_Click({ Open-WinUri 'ms-settings:appsfeatures' })
    $bClose.Add_Click({ $script:UniWin.Close() })
    & $script:RenderUni
    # Toutes les 2 secondes : les désinstallations lancées sont-elles vraiment finies ?
    $ut = New-Object System.Windows.Threading.DispatcherTimer; $ut.Interval = [TimeSpan]::FromSeconds(2)
    $ut.Add_Tick({ try { if (Update-UninstallPending) { & $script:RenderUni } } catch {} })
    $ut.Start()
    [void]$w.ShowDialog()
    $ut.Stop()
    [void](Update-UninstallPending $true)
    if ($Issue -and -not @($script:UniApps | Where-Object { $_.Tag -eq 'reco' -and -not $_.Removed }).Count) { $Issue.Status = 'done'; Update-DiagBadge; Refresh-Page }
}
# Vrai si une désinstallation lancée a changé d'état ; à la fermeture ($Final), ce qui n'est pas fini est signalé
function Update-UninstallPending([bool]$Final = $false) {
    $changed = $false
    foreach ($a in @($script:UniApps | Where-Object { $_.Pending })) {
        if (-not (Test-Path -LiteralPath $a.Key)) {
            $a.Pending = $false; $a.Removed = $true; $changed = $true
            Add-Change -Kind 'info' -Title ("Désinstallation de « {0} »" -f $a.Name) -Detail "Pour le récupérer : réinstalle-le depuis son site officiel."
            Write-UiLog ("✔ « {0} » désinstallé." -f $a.Name)
        } elseif ($Final) {
            $a.Pending = $false; $a.NotRemoved = $true
            Write-UiLog ("« {0} » est toujours installé (désinstallation annulée, pas finie ou refusée par le logiciel)." -f $a.Name)
        }
    }
    return $changed
}

function Invoke-UninstallApp($A) {
    $msg = "Désinstaller « $($A.Name) » ?" + $(if ($A.Kind -eq 'store') { "`n`nL'appli sera retirée tout de suite (elle se réinstalle depuis le Microsoft Store si besoin)." } else { "`n`nLe désinstalleur du logiciel va s'ouvrir : suis ses étapes (attention aux cases « garder mes données » ou aux offres qu'il peut proposer)." })
    if (-not (Confirm-Box $msg)) { return }
    try {
        Uninstall-App $A.Kind $A.Cmd $A.Name ([bool]$A.PerUser)
        if ($A.Kind -eq 'store' -or -not $A.Key) {
            $A.Removed = $true
            Add-Change -Kind 'info' -Title ("Désinstallation de « {0} »" -f $A.Name) -Detail "Pour la récupérer : Microsoft Store."
            Write-UiLog ("✔ « {0} » désinstallé." -f $A.Name)
        } else {
            # Pas encore « désinstallé » : on attend que le désinstalleur ait vraiment fini (annulation ou échec possibles)
            $A.Pending = $true
            Write-UiLog ("Désinstalleur de « {0} » ouvert : suis ses étapes." -f $A.Name)
        }
        & $script:RenderUni
    } catch {
        Write-UiLog ("❌ Impossible de désinstaller « {0} » : {1}" -f $A.Name, $_.Exception.Message)
        $known = ($_.Exception.Message -like "Le désinstalleur de*")
        if (-not $known) { Write-Bug -Context "Désinstallation $($A.Name)" -ErrorRecord $_ -Type 'erreur' }
        [System.Windows.MessageBox]::Show("Impossible de désinstaller « $($A.Name) » ici :`n$($_.Exception.Message)" + $(if ($known) { '' } else { "`n`nEssaie depuis Paramètres > Applications." }), $AppName, 'OK', 'Warning') | Out-Null
    }
}
function Start-UninstallList($Issue) {
    $script:UniIssue = $Issue
    [void](Start-AeroxTask 'Get-InstalledAppsAdvice' 'Analyse des logiciels installés' 'uninstalldialog')
}

# ---------------------------------------------------------------- Fenêtre : ce qui prend de la place (arbre des dossiers)
$script:SpaceHints = @(
    @('(?i)\\steamapps\\common$', 'Jeux Steam : désinstalle ceux auxquels tu ne joues plus depuis Steam'),
    @('(?i)\\Epic Games$', 'Jeux Epic : désinstalle-les depuis le launcher Epic'),
    @('(?i)\\(Riot Games|Battle\.net|EA Games|Ubisoft Game Launcher)$', 'Jeux : désinstalle-les depuis leur launcher'),
    @('(?i)^[A-Z]:\\Windows$', 'Windows : ne rien supprimer à la main (utilise le nettoyage approfondi)'),
    @('(?i)\\Downloads$|\\Téléchargements$', 'Téléchargements : souvent plein de vieux installateurs à trier'),
    @('(?i)\\Videos$|\\Vidéos$', 'Vidéos : à déplacer sur un autre disque si besoin'),
    @('(?i)\\Pictures$|\\Images$', 'Photos : à déplacer sur un autre disque si besoin'),
    @('(?i)\\AppData\\Local\\Temp$', 'Temporaires : le nettoyage approfondi les vide'),
    @('(?i)pagefile\.sys$', 'Mémoire virtuelle de Windows : ne pas supprimer'),
    @('(?i)hiberfil\.sys$', 'Veille prolongée : peut être désactivée dans le nettoyage approfondi'),
    @('(?i)swapfile\.sys$', 'Fichier système : ne pas supprimer'),
    @('(?i)\\Windows\.old$', "Ancien Windows : peut être supprimé dans le nettoyage approfondi"),
    @('(?i)\\\$Recycle\.Bin$', 'Corbeille'),
    @('(?i)\\System Volume Information$', 'Points de restauration de Windows')
)
function Get-SpaceHint([string]$Path) { foreach ($h in $script:SpaceHints) { if ($Path -match $h[0]) { return $h[1] } }; return '' }

function New-SpaceItem([string]$Path, [double]$Size, [double]$Max, [bool]$IsFile) {
    $it = New-Object System.Windows.Controls.TreeViewItem
    $it.Tag = $Path
    $row = New-Object System.Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'; $row.Margin = Th 0 3 0 3
    $barBg = New-Object System.Windows.Controls.Border; $barBg.Width = 90; $barBg.Height = 8; $barBg.Background = Brush '#252A3A'; $barBg.CornerRadius = Corner 4; $barBg.VerticalAlignment = 'Center'
    $bar = New-Object System.Windows.Controls.Border; $bar.HorizontalAlignment = 'Left'; $bar.Height = 8; $bar.CornerRadius = Corner 4; $bar.Background = Brush '#7C5CFF'
    $bar.Width = [math]::Max([double]2, [math]::Min([double]90, 90.0 * [double]$Size / [math]::Max([double]1, [double]$Max))); $barBg.Child = $bar
    Add-Child $row $barBg
    $sz = New-Text (Format-Size $Size) 13 '#FFFFFF' 'SemiBold'; $sz.Width = 90; $sz.TextAlignment = 'Right'; $sz.Margin = Th 0 0 12 0; Add-Child $row $sz
    $name = [IO.Path]::GetFileName($Path); if (-not $name) { $name = $Path }
    Add-Child $row (New-Text $name 13 $(if ($IsFile) { '#B9A8FF' } else { '#E6E9F2' }))
    $hint = Get-SpaceHint $Path
    if ($hint) { $h = New-Text ("   " + $hint) 12 '#7A8399'; Add-Child $row $h }
    $it.Header = $row
    $it.Foreground = Brush '#E6E9F2'
    if (-not $IsFile -and $script:SpaceKids.ContainsKey($Path)) { [void]$it.Items.Add('…') }
    $it.Add_Expanded({
        param($s, $e)
        $node = $e.OriginalSource
        if ($node.Items.Count -eq 1 -and $node.Items[0] -is [string]) {
            $node.Items.Clear()
            $kids = @($script:SpaceKids[[string]$node.Tag] | Sort-Object { -$script:SpaceSizes[$_] } | Select-Object -First 40)
            $mx = if ($kids.Count) { $script:SpaceSizes[$kids[0]] } else { 1 }
            foreach ($k in $kids) { if ($script:SpaceSizes[$k] -ge 1MB) { [void]$node.Items.Add((New-SpaceItem $k $script:SpaceSizes[$k] $mx $false)) } }
        }
        $e.Handled = $true
    })
    $it.Add_MouseDoubleClick({ param($s, $e) if ($e.OriginalSource -and $s.IsSelected) { $p = [string]$s.Tag; if (Test-Path -LiteralPath $p -PathType Container) { Start-Process explorer.exe "`"$p`"" } else { Start-Process explorer.exe "/select,`"$p`"" } }; $e.Handled = $true })
    return $it
}

function Show-SpaceDialog {
    $scan = $sync.SpaceScan
    if (-not $scan) { return }
    $script:SpaceSizes = @{}; $script:SpaceKids = @{}
    $root = "$($scan.Drive)\"
    $top = New-Object System.Collections.ArrayList; $files = New-Object System.Collections.ArrayList
    $big = New-Object System.Collections.ArrayList
    foreach ($l in $scan.Lines) {
        if ($l.StartsWith('B|')) {
            $q = $l.Split('|', 4)
            if ($q.Count -eq 4) { try { [void]$big.Add(@{ Size = [double]$q[1]; Date = ([datetime]::new([int64]$q[2], 'Utc')).ToLocalTime(); Path = $q[3] }) } catch {} }
            continue
        }
        $p = $l.Split('|', 3)
        if ($p.Count -lt 3) { continue }
        $size = [double]$p[1]; $path = $p[2]
        $script:SpaceSizes[$path] = $size
        if ($p[0] -eq 'F') { [void]$files.Add($path); continue }
        $parent = [IO.Path]::GetDirectoryName($path)
        if ($p[0] -eq '1') { [void]$top.Add($path) }
        if (-not $script:SpaceKids.ContainsKey($parent)) { $script:SpaceKids[$parent] = New-Object System.Collections.ArrayList }
        [void]$script:SpaceKids[$parent].Add($path)
    }
    $w = New-Dialog "$AppName : ce qui prend de la place" 860
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = Th 24 22 24 20
    Add-Child $sp (New-Text ("Ce qui prend de la place sur {0}" -f $scan.Drive) 18 '#FFFFFF' 'Bold')
    $used = $scan.Size - $scan.Free
    $p = New-Text ("{0} utilisés sur {1} — {2} libres. Clique sur ▸ pour voir le détail d'un dossier, double-clic pour l'ouvrir. Supprime ou déplace tes fichiers toi-même : AEROX ne touche jamais à tes fichiers perso." -f (Format-Size $used), (Format-Size $scan.Size), (Format-Size $scan.Free)) 13 '#A9B0C2'
    $p.Margin = Th 0 6 0 12; Add-Child $sp $p
    $body = New-Object System.Windows.Controls.StackPanel
    $sv = New-Object System.Windows.Controls.ScrollViewer; $sv.VerticalScrollBarVisibility = 'Auto'; $sv.MaxHeight = 450; $sv.Content = $body
    Add-Child $sp $sv
    Add-SpaceAdvice $body $scan $big
    $h = New-Text "TOUS LES DOSSIERS, DU PLUS GROS AU PLUS PETIT" 11.5 '#7A8399' 'Bold'; $h.Margin = Th 2 14 0 8; Add-Child $body $h
    $tv = New-Object System.Windows.Controls.TreeView
    $tv.Background = Brush '#0E1016'; $tv.BorderBrush = Brush '#232838'; $tv.Foreground = Brush '#E6E9F2'; $tv.Padding = Th 6 6 6 6; $tv.Height = 380
    $items = @($top | ForEach-Object { @{ P = $_; S = $script:SpaceSizes[$_]; F = $false } }) + @($files | ForEach-Object { @{ P = $_; S = $script:SpaceSizes[$_]; F = $true } })
    $items = @($items | Sort-Object { -$_.S })
    $mx = if ($items.Count) { $items[0].S } else { 1 }
    foreach ($i in $items) { if ($i.S -ge 1MB) { [void]$tv.Items.Add((New-SpaceItem $i.P $i.S $mx $i.F)) } }
    Add-Child $body $tv
    $row = New-Object System.Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'; $row.HorizontalAlignment = 'Right'; $row.Margin = Th 0 12 0 0
    $bClean = New-DlgButton 'Nettoyage approfondi' 'ActionBtn'; $bClean.Margin = Th 0 0 8 0
    $bApps = New-DlgButton 'Désinstaller des logiciels' 'ActionBtn'; $bApps.Margin = Th 0 0 8 0
    $bOther = New-DlgButton 'Analyser un autre disque' 'TextBtn'; $bOther.Margin = Th 0 0 8 0
    $bClose = New-DlgButton 'Fermer' 'PrimaryBtn'
    if (@(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue).Count -gt 1) { Add-Child $row $bOther }
    Add-Child $row $bApps
    # Le nettoyage approfondi s'occupe du disque de Windows : pas proposé quand on analyse un autre disque
    if ($scan.Drive -eq $env:SystemDrive) { Add-Child $row $bClean }
    Add-Child $row $bClose
    Add-Child $sp $row
    $script:SpaceWin = $w; $script:SpaceNext = $null
    $bClose.Add_Click({ $script:SpaceWin.Close() })
    $bApps.Add_Click({ $script:SpaceNext = 'apps'; $script:SpaceWin.Close() })
    $bOther.Add_Click({ $script:SpaceNext = 'other'; $script:SpaceWin.Close() })
    $bClean.Add_Click({ $script:SpaceNext = 'clean'; $script:SpaceWin.Close() })
    $w.Content = $sp
    [void]$w.ShowDialog()
    switch ($script:SpaceNext) {
        'clean'   { Start-CleanAnalysis $null }
        'apps'    { Start-UninstallList $null }
        'other'   { Start-SpaceScan }
        'recycle' { if (Confirm-Box "Vider définitivement la corbeille ? Les fichiers dedans ne pourront plus être récupérés.") { [void](Start-AeroxTask 'Clear-RecycleBinAll' 'Vidage de la corbeille') } }
        'oldinst' { Remove-OldInstallers }
        'dupes'   { Start-DuplicateScan }
        'bigfiles' {
            $sel = @($script:BigChecks | Where-Object { $_.Check.IsChecked -and $_.Check.IsEnabled } | ForEach-Object { $_.File })
            if ($sel.Count) { [void](Remove-FilesToRecycle $sel 'gros fichier(s)') } else { [System.Windows.MessageBox]::Show("Coche d'abord les fichiers à mettre à la corbeille.", $AppName, 'OK', 'Information') | Out-Null }
        }
        'onedrive' {
            if (Confirm-Box ("Garder le dossier OneDrive « {0} » uniquement en ligne ?`n`nTes fichiers restent dans OneDrive (rien n'est supprimé) et apparaissent toujours dans le dossier. Ils se téléchargent quand tu les ouvres : il faut Internet pour ça.`n`nPour garder un dossier sur le PC : clic droit dessus > « Toujours conserver sur cet appareil »." -f $script:SpaceArg)) {
                [void](Start-AeroxTask ("Set-OneDriveOnlineOnly " + (ConvertTo-PsLiteral $script:SpaceArg)) 'OneDrive : fichiers uniquement en ligne')
            }
        }
        'winspace' {
            $sel = @($script:SpaceWinRows | Where-Object { $_.Check.IsChecked } | ForEach-Object { $_.Item })
            if (-not $sel.Count) { return }
            $ids = @($sel | ForEach-Object { if ($_.Arg) { "{0}:{1}" -f $_.Id, $_.Arg } else { $_.Id } })
            $tot = [double](($sel | ForEach-Object { $_.S } | Measure-Object -Sum).Sum)
            $msg = ("Libérer environ {0} ?`n`n{1}" -f (Format-Size $tot), ((@($sel | ForEach-Object { "•  " + $_.T }) -join "`n")))
            if (@($sel | Where-Object { $_.Id -eq 'compact' }).Count) { $msg += "`n`nLa compression de Windows prend 10 à 20 minutes : laisse le PC allumé." }
            if (@($sel | Where-Object { $_.Id -eq 'drivers' }).Count) { $msg += "`n`nUn point de restauration est créé avant de supprimer les anciens pilotes." }
            $msg += "`n`nContinuer ?"
            if (Confirm-Box $msg) {
                $pre = if (@($sel | Where-Object { $_.Id -eq 'drivers' }).Count) { 'New-RestorePoint; ' } else { '' }
                [void](Start-AeroxTask ($pre + "Invoke-WindowsSpace -Items " + (ConvertTo-PsList $ids)) 'Libération de la place gardée par Windows')
            }
        }
    }
}
# Met des fichiers à la corbeille (jamais supprimés directement), après confirmation
function Remove-FilesToRecycle($Files, [string]$What) {
    # Uniquement des fichiers atteints directement (aucun lien glissé sur le chemin depuis l'analyse)
    $files = @($Files | Where-Object { $_ -and (Test-Path -LiteralPath $_.Path) -and [AeroxSafeDelete]::IsDirectPath($_.Path) })
    if (-not $files.Count) { return 0 }
    $tot = [double](($files | ForEach-Object { $_.Size } | Measure-Object -Sum).Sum)
    $list = (@($files | Select-Object -First 12 | ForEach-Object { "•  " + [IO.Path]::GetFileName($_.Path) + "  (" + (Format-Size $_.Size) + ")" }) -join "`n") + $(if ($files.Count -gt 12) { "`n… et $($files.Count - 12) autre(s)" } else { '' })
    $bin = if ((Get-SessionUser).Other) { "Ils iront dans la corbeille du compte administrateur (celui dont le mot de passe a été tapé), pas dans la tienne." } else { "Ils restent récupérables dans la corbeille tant que tu ne la vides pas." }
    if (-not (Confirm-Box ("Mettre ces {0} fichier(s) à la corbeille ({1}) ?`n`n{2}`n`n{3}" -f $files.Count, (Format-Size $tot), $list, $bin))) { return 0 }
    Add-Type -AssemblyName Microsoft.VisualBasic
    $ok = 0; $freed = 0.0
    foreach ($f in $files) {
        # AllDialogs : si un fichier est trop gros pour la corbeille, Windows demande avant de le supprimer définitivement
        try { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($f.Path, 'AllDialogs', 'SendToRecycleBin'); if (-not (Test-Path -LiteralPath $f.Path)) { $ok++; $freed += $f.Size } } catch {}
    }
    Write-UiLog ("🗑 {0} {1} mis à la corbeille ({2}). Vide la corbeille pour récupérer la place." -f $ok, $What, (Format-Size $freed))
    if ($ok) { Add-Change -Kind 'info' -Title ("{0} {1} mis à la corbeille ({2})" -f $ok, $What, (Format-Size $freed)) -Detail "Récupérables depuis la corbeille tant qu'elle n'est pas vidée." }
    return $ok
}

# Choix du disque à analyser (s'il y en a plusieurs)
function Start-SpaceScan {
    $drives = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue | Where-Object { $_.Size } | Sort-Object DeviceID)
    if ($drives.Count -le 1) { [void](Start-AeroxTask 'Get-SpaceUsage' 'Analyse de l''espace disque' 'spacedialog'); return }
    $w = New-Dialog "$AppName : quel disque analyser ?" 520
    $script:DriveWin = $w; $script:DrivePick = $null
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = Th 24 22 24 20
    Add-Child $sp (New-Text "Quel disque analyser ?" 18 '#FFFFFF' 'Bold')
    $t = New-Text "L'analyse détaille tous les dossiers du disque choisi (1 à 3 minutes)." 13 '#A9B0C2'; $t.Margin = Th 0 6 0 12; Add-Child $sp $t
    foreach ($d in $drives) {
        $pct = [math]::Round(100 * [double]$d.FreeSpace / [double]$d.Size)
        $lbl = "{0}  {1}" -f $d.DeviceID, $(if ($d.VolumeName) { $d.VolumeName } elseif ($d.DeviceID -eq $env:SystemDrive) { 'Windows' } else { 'Disque local' })
        $b = New-Object System.Windows.Controls.Button; $b.Style = $window.FindResource('ActionBtn'); $b.HorizontalContentAlignment = 'Stretch'; $b.Margin = Th 0 0 0 8; $b.Tag = "$($d.DeviceID)"
        $dp = New-Object System.Windows.Controls.DockPanel; $dp.LastChildFill = $true
        $r = New-Text ("{0} libres sur {1} ({2} %)" -f (Format-Size ([double]$d.FreeSpace)), (Format-Size ([double]$d.Size)), $pct) 12.5 $(if ($pct -lt 10) { '#FF6B6B' } elseif ($pct -lt 15) { '#FFB547' } else { '#A9B0C2' }); $r.Margin = Th 16 0 0 0; $r.VerticalAlignment = 'Center'; [System.Windows.Controls.DockPanel]::SetDock($r, 'Right'); Add-Child $dp $r
        Add-Child $dp (New-Text $lbl 14 '#FFFFFF' 'SemiBold')
        $b.Content = $dp
        $b.Add_Click({ $script:DrivePick = [string]$this.Tag; $script:DriveWin.Close() })
        Add-Child $sp $b
    }
    $c = New-DlgButton 'Annuler' 'TextBtn'; $c.HorizontalAlignment = 'Right'; $c.Margin = Th 0 6 0 0; $c.Add_Click({ $script:DriveWin.Close() }); Add-Child $sp $c
    $w.Content = $sp
    [void]$w.ShowDialog()
    if ($script:DrivePick -match '^[A-Za-z]:$') { [void](Start-AeroxTask ("Get-SpaceUsage '{0}'" -f $script:DrivePick) ("Analyse de l'espace sur " + $script:DrivePick) 'spacedialog') }
}

# Gros fichier : à toi (vidéo, image disque, sauvegarde… → corbeille possible) ou morceau d'un jeu / logiciel
# (le supprimer seul abîmerait le jeu, et son lanceur le retéléchargerait : on propose de désinstaller le jeu).
# Jeu ou logiciel repéré par son dossier : un .exe, ou un dossier .egstore (Epic) / steamapps, dans un dossier parent.
function Get-BigFileKind([string]$Path, [hashtable]$Cache) {
    if ($Path -match '(?i)^[a-z]:\\users\\[^\\]+\\(?!appdata\\)') { return @{ Kind = 'user' } }
    if ($Path -match '(?i)^[a-z]:\\users\\') { return @{ Kind = 'system' } }
    $d = [IO.Path]::GetDirectoryName($Path)
    # Dossiers de rangement perso (un installateur .exe téléchargé à côté ne fait pas d'une vidéo un fichier de jeu)
    $perso = '(?i)^(t[ée]l[ée]chargements?|downloads?|vid[ée]os?|films?|s[ée]ries?|images?|photos?|pictures|musique|music|documents?|desktop|bureau|sauvegardes?|backups?|iso)$'
    while ($d -and [IO.Path]::GetPathRoot($d) -ne $d) {
        if ((Split-Path $d -Leaf) -match $perso) { return @{ Kind = 'user' } }
        if (-not $Cache.ContainsKey($d)) {
            $hit = $false
            try {
                $hit = ([IO.Directory]::Exists((Join-Path $d '.egstore')) -or (Split-Path $d -Leaf) -match '(?i)^steamapps$' -or
                        @([IO.Directory]::EnumerateFiles($d, '*.exe') | Select-Object -First 1).Count -gt 0)
            } catch {}
            $Cache[$d] = $hit
        }
        if ($Cache[$d]) {
            # Remonte au dossier du jeu lui-même (pas un sous-dossier « bin », « x64 »…) : le plus haut dossier marqué
            $top = $d; $up = [IO.Path]::GetDirectoryName($d)
            while ($up -and [IO.Path]::GetPathRoot($up) -ne $up) {
                if (-not $Cache.ContainsKey($up)) { $h2 = $false; try { $h2 = ([IO.Directory]::Exists((Join-Path $up '.egstore')) -or @([IO.Directory]::EnumerateFiles($up, '*.exe') | Select-Object -First 1).Count -gt 0) } catch {}; $Cache[$up] = $h2 }
                if ($Cache[$up]) { $top = $up }
                $up = [IO.Path]::GetDirectoryName($up)
            }
            return @{ Kind = 'program'; Root = $top; App = (Split-Path $top -Leaf) }
        }
        $d = [IO.Path]::GetDirectoryName($d)
    }
    return @{ Kind = 'user' }
}

# Pistes concrètes pour libérer de la place, triées par taille, avec l'action qui va avec
function Add-SpaceAdvice($Body, $Scan, $Big) {
    $root = "$($Scan.Drive)\"
    $script:SpaceWinRows = New-Object System.Collections.ArrayList; $script:BigChecks = New-Object System.Collections.ArrayList
    # Place gardée par Windows : cases à cocher + un seul bouton
    $win = @($Scan.Win | Where-Object { $_ })
    if ($win.Count) {
        $wt = [double](($win | ForEach-Object { $_.S } | Measure-Object -Sum).Sum)
        $h = New-Text ("WINDOWS GARDE DE LA PLACE POUR LUI · ENVIRON {0} RÉCUPÉRABLES" -f (Format-Size $wt)) 11.5 '#B9A8FF' 'Bold'; $h.Margin = Th 2 4 0 8; Add-Child $Body $h
        foreach ($x in @($win | Sort-Object { - $_.S })) {
            $txt = New-Object System.Windows.Controls.StackPanel; $txt.Margin = Th 8 0 0 0
            $hd = New-Object System.Windows.Controls.WrapPanel
            Add-Child $hd (New-Text $x.T 14 '#FFFFFF' 'SemiBold')
            Add-Child $hd (New-Pill ($(if ($x.Est) { '≈ ' } else { '' }) + (Format-Size $x.S)) '#B9A8FF' '#2A2350')
            Add-Child $txt $hd
            $d = New-Text $x.D 12.5 '#A9B0C2'; $d.Margin = Th 0 3 0 0; Add-Child $txt $d
            $r = New-CheckRow ([bool]$x.Check) $txt $null
            Add-Child $Body $r.Row
            [void]$script:SpaceWinRows.Add(@{ Item = $x; Check = $r.Check })
        }
        $bw = New-DlgButton 'Libérer la sélection' 'PrimaryBtn'; $bw.HorizontalAlignment = 'Right'; $bw.Margin = Th 0 2 0 14
        $bw.Add_Click({ $script:SpaceNext = 'winspace'; $script:SpaceWin.Close() })
        Add-Child $Body $bw
    }
    $tips = New-Object System.Collections.ArrayList
    $sz = { param($p) if ($script:SpaceSizes.ContainsKey($p)) { [double]$script:SpaceSizes[$p] } else { 0.0 } }
    $rb = & $sz ($root + '$Recycle.Bin')
    if ($rb -ge 100MB) { [void]$tips.Add(@{ S = $rb; T = "Corbeille"; D = "Des fichiers supprimés qui prennent encore de la place. Vérifie qu'il n'y a rien dedans dont tu as besoin."; B = 'Vider la corbeille'; A = 'recycle' }) }
    $wo = & $sz ($root + 'Windows.old')
    if ($wo -ge 1GB) { [void]$tips.Add(@{ S = $wo; T = "Ancienne installation de Windows (Windows.old)"; D = "Gardée après une grosse mise à jour pour pouvoir revenir en arrière. Si tout marche bien depuis, elle ne sert plus."; B = 'Nettoyage approfondi'; A = 'clean' }) }
    $hb = & $sz ($root + 'hiberfil.sys')
    if ($hb -ge 1GB) { [void]$tips.Add(@{ S = $hb; T = "Fichier de veille prolongée (hiberfil.sys)"; D = "Sert seulement si tu utilises la « veille prolongée ». Sur un PC fixe, on peut le supprimer (option du nettoyage approfondi)."; B = 'Nettoyage approfondi'; A = 'clean' }) }
    $old = @($Scan.OldInstallers | Where-Object { $_ })
    if ($old.Count) {
        $tot = [double](($old | ForEach-Object { $_.Size } | Measure-Object -Sum).Sum)
        if ($tot -ge 50MB) {
            $names = (@($old | Select-Object -First 3 | ForEach-Object { [IO.Path]::GetFileName($_.Path) }) -join ', ') + $(if ($old.Count -gt 3) { " et $($old.Count - 3) autre(s)" } else { '' })
            [void]$tips.Add(@{ S = $tot; T = "$($old.Count) vieux installateur(s) et archive(s) dans les Téléchargements"; D = "Fichiers d'installation déjà utilisés depuis plus d'un mois : $names. Ils iront dans la corbeille (récupérables)."; B = 'Mettre à la corbeille'; A = 'oldinst' })
        }
    }
    foreach ($prof in @($script:SpaceSizes.Keys | Where-Object { $_ -match '^[A-Za-z]:\\Users\\[^\\]+\\(Downloads|Videos)$' })) {
        $v = & $sz $prof
        if ($v -ge 2GB) {
            $isDl = $prof -match 'Downloads$'
            [void]$tips.Add(@{ S = $v; T = $(if ($isDl) { "Téléchargements de « $(Split-Path (Split-Path $prof -Parent) -Leaf) »" } else { "Vidéos de « $(Split-Path (Split-Path $prof -Parent) -Leaf) »" }); D = $(if ($isDl) { "Souvent plein de fichiers récupérés une fois et oubliés. À trier toi-même." } else { "Des vidéos à garder sur un disque externe ou un autre disque si besoin." }); B = 'Ouvrir le dossier'; A = 'open'; P = $prof })
        }
    }
    $games = @($script:SpaceSizes.Keys | Where-Object { $_ -match '(?i)\\steamapps\\common\\[^\\]+$' } | Sort-Object { - $script:SpaceSizes[$_] } | Select-Object -First 6)
    if ($games.Count) {
        $gt = [double](($games | ForEach-Object { $script:SpaceSizes[$_] } | Measure-Object -Sum).Sum)
        $gl = ($games | ForEach-Object { "{0} ({1})" -f (Split-Path $_ -Leaf), (Format-Size $script:SpaceSizes[$_]) }) -join ' · '
        if ($gt -ge 5GB) { [void]$tips.Add(@{ S = $gt; T = "Jeux Steam les plus gros"; D = "$gl. Désinstalle depuis Steam ceux auxquels tu ne joues plus (tes sauvegardes restent sur Steam)."; B = 'Ouvrir Steam'; A = 'url'; P = 'steam://open/games' }) }
    }
    foreach ($od in @($Scan.OneDrive | Where-Object { $_ })) {
        [void]$tips.Add(@{ S = $od.Local; T = "OneDrive garde aussi tes fichiers sur le PC"; D = "Le dossier « $($od.Folder) » est en double : dans le cloud ET sur le disque. En le gardant « uniquement en ligne », la place est libérée ; tes fichiers restent dans OneDrive et s'ouvrent d'un clic (il faut Internet pour les ouvrir)."; B = 'Garder uniquement en ligne'; A = 'onedrive'; P = $od.Folder })
    }
    $fg = @($Scan.Forgotten | Where-Object { $_ })
    if ($fg.Count) {
        $ft0 = [double](($fg | ForEach-Object { $_.Size } | Measure-Object -Sum).Sum)
        $fl = (@($fg | Select-Object -First 5 | ForEach-Object { "{0} ({1}, {2})" -f $_.Name, (Format-Size $_.Size), $(if ($_.LastUsed) { "dernière utilisation le " + (Format-Date $_.LastUsed) } else { 'pas lancé récemment' }) }) -join ' · ') + $(if ($fg.Count -gt 5) { " et $($fg.Count - 5) autre(s)" } else { '' })
        $hasGame = @($fg | Where-Object { $_.Kind -eq 'game' }).Count -gt 0
        [void]$tips.Add(@{ S = $ft0; T = "Jeux et logiciels pas utilisés depuis 3 mois"; D = "$fl." + $(if ($hasGame) { " Les jeux Steam se désinstallent depuis Steam (tes sauvegardes restent sur Steam)." } else { '' }); B = $(if ($hasGame) { 'Ouvrir Steam' } else { 'Voir les logiciels' }); A = $(if ($hasGame) { 'url' } else { 'apps' }); P = 'steam://open/games' })
    }
    foreach ($od in @($Scan.OtherDrives | Where-Object { $_ })) {
        [void]$tips.Add(@{ S = 0; T = "Ton disque $($od.Drive) a $(Format-Size $od.Free) de libre"; D = "Déplace-y ce qui est gros et que tu n'ouvres pas tout le temps. Téléchargements, Vidéos, Images : clic droit sur le dossier > Propriétés > onglet « Emplacement » > « Déplacer… », choisis un dossier sur $($od.Drive). Jeux Steam : Steam > Paramètres > Stockage > ajoute $($od.Drive), puis « Déplacer » sur chaque jeu."; B = 'Ouvrir mes dossiers'; A = 'open'; P = (Get-SessionUser).Profile })
    }
    [void]$tips.Add(@{ S = 0; T = "Fichiers en double"; D = "Photos, vidéos, documents ou installateurs présents en plusieurs exemplaires dans tes dossiers (Bureau, Documents, Images, Vidéos, Musique, Téléchargements). Tu choisis lesquels supprimer, une copie est toujours gardée."; B = 'Chercher les doublons'; A = 'dupes' })
    $skip = '(?i)\\(windows|program files( \(x86\))?|programdata|\$recycle\.bin|system volume information|steamapps|epic games|riot games)\\|\\appdata\\local\\(packages|docker)|(pagefile|hiberfil|swapfile)\.sys$|\.vhdx?$'
    $kc = @{}; $mine = New-Object System.Collections.ArrayList; $progs = [ordered]@{}
    foreach ($f in @($Big | Where-Object { $_ -and $_.Path -notmatch $skip })) {
        $k = Get-BigFileKind $f.Path $kc
        if ($k.Kind -eq 'user') { if ($mine.Count -lt 10) { [void]$mine.Add($f) } }
        elseif ($k.Kind -eq 'program' -and -not $progs.Contains($k.Root)) { $progs[$k.Root] = $k.App }
    }
    if ($mine.Count) {
        $ft = [double](($mine | ForEach-Object { $_.Size } | Measure-Object -Sum).Sum)
        if ($ft -ge 1GB) { [void]$tips.Add(@{ S = $ft; T = "Tes plus gros fichiers"; Files = @($mine); D = "Vidéos, images disque, sauvegardes… À garder, déplacer ou supprimer : c'est toi qui décides. « Corbeille » sur une ligne, ou coche-en plusieurs (date = dernière modification). Ils restent récupérables dans la corbeille."; B = 'Mettre la sélection à la corbeille'; A = 'bigfiles' }) }
    }
    # Jeux et logiciels : un de leurs fichiers seul ne se supprime pas (le jeu serait abîmé et retéléchargé) → désinstaller le jeu
    if ($progs.Count) {
        $pl = @($progs.Keys | ForEach-Object { @{ Root = $_; App = $progs[$_]; S = $(if ($script:SpaceSizes.ContainsKey($_)) { [double]$script:SpaceSizes[$_] } else { 0.0 }) } } | Sort-Object { - $_.S } | Select-Object -First 6)
        $pt = [double](($pl | ForEach-Object { $_.S } | Measure-Object -Sum).Sum)
        $txt = (@($pl | ForEach-Object { if ($_.S -gt 0) { "{0} ({1})" -f $_.App, (Format-Size $_.S) } else { $_.App } }) -join ' · ')
        [void]$tips.Add(@{ S = $pt; T = "Les jeux et logiciels qui prennent le plus de place"; D = "$txt. Leurs gros fichiers font partie du jeu : supprimés un par un, le jeu ne marcherait plus et son lanceur (Steam, Epic…) les retéléchargerait. Pour récupérer la place, désinstalle le jeu entier depuis son lanceur ou la liste des logiciels."; B = 'Voir les logiciels'; A = 'apps' })
    }
    if ($Scan.Drive -eq $env:SystemDrive) {
        [void]$tips.Add(@{ S = 0; T = "Fichiers inutiles de Windows et des logiciels"; D = "Temporaires, caches des navigateurs, anciennes mises à jour, rapports de plantage : le nettoyage approfondi te montre la taille de chaque catégorie avant de supprimer."; B = 'Nettoyage approfondi'; A = 'clean' })
    }
    [void]$tips.Add(@{ S = 0; T = "Logiciels installés"; D = "La liste de tes logiciels du plus gros au plus petit, avec ceux qui ne servent à rien repérés pour toi."; B = 'Voir les logiciels'; A = 'apps' })

    $h = New-Text "CE QUE TU PEUX FAIRE POUR LIBÉRER DE LA PLACE" 11.5 '#7A8399' 'Bold'; $h.Margin = Th 2 4 0 8; Add-Child $Body $h
    foreach ($t in @($tips | Sort-Object { - $_.S })) {
        $card = New-Object System.Windows.Controls.Border; $card.Background = Brush '#171A23'; $card.CornerRadius = Corner 10; $card.Padding = Th 14 10 12 10; $card.Margin = Th 0 0 0 6
        $dp = New-Object System.Windows.Controls.DockPanel
        if ($t.B) {
            $b = New-DlgButton $t.B 'ActionBtn'; $b.VerticalAlignment = 'Center'; $b.Margin = Th 12 0 0 0; $b.Tag = $t
            $b.Add_Click({
                $x = $this.Tag
                switch ($x.A) {
                    'bigfiles' {
                        # Dans la fenêtre même : elle reste ouverte, les lignes mises à la corbeille passent en gris
                        $sel = @($script:BigChecks | Where-Object { $_.Check.IsChecked -and $_.Check.IsEnabled })
                        if (-not $sel.Count) { [System.Windows.MessageBox]::Show("Coche d'abord les fichiers à mettre à la corbeille (case à gauche de chaque fichier), ou clique sur « Corbeille » sur une ligne.", $AppName, 'OK', 'Information') | Out-Null; return }
                        if ((Remove-FilesToRecycle @($sel | ForEach-Object { $_.File }) 'gros fichier(s)') -gt 0) {
                            foreach ($e in $sel) { if (-not (Test-Path -LiteralPath $e.File.Path)) { $e.Check.IsChecked = $false; $e.Check.IsEnabled = $false; $e.Btn.IsEnabled = $false; $e.Btn.Content = 'À la corbeille ✓'; $e.Show.IsEnabled = $false; $e.Row.Opacity = 0.5 } }
                        }
                    }
                    'open' { Start-Process explorer.exe ('"{0}"' -f $x.P) }
                    'url'  { if ("$($x.P)" -like 'steam:*') { Open-WinUri $x.P } else { [void](Open-Url $x.P) } }
                    default { $script:SpaceNext = $x.A; $script:SpaceArg = $x.P; $script:SpaceWin.Close() }
                }
            })
            [System.Windows.Controls.DockPanel]::SetDock($b, 'Right'); Add-Child $dp $b
        }
        $cs = New-Object System.Windows.Controls.StackPanel
        $hd = New-Object System.Windows.Controls.WrapPanel
        Add-Child $hd (New-Text $t.T 14 '#FFFFFF' 'SemiBold')
        if ($t.S -gt 0) { Add-Child $hd (New-Pill (Format-Size $t.S) '#B9A8FF' '#2A2350') }
        Add-Child $cs $hd
        $d = New-Text $t.D 12.5 '#A9B0C2'; $d.Margin = Th 0 3 0 0; Add-Child $cs $d
        foreach ($f in @($t.Files | Where-Object { $_ })) {
            $fr = New-Object System.Windows.Controls.DockPanel; $fr.Margin = Th 0 4 0 0
            # « Corbeille » : ce fichier seul, tout de suite (confirmation, récupérable), sans fermer la fenêtre
            $rb2 = New-DlgButton 'Corbeille' 'TextBtn'; [System.Windows.Controls.DockPanel]::SetDock($rb2, 'Right'); Add-Child $fr $rb2
            $fb = New-DlgButton 'Afficher' 'TextBtn'; $fb.Tag = $f.Path; [System.Windows.Controls.DockPanel]::SetDock($fb, 'Right')
            $fb.Add_Click({ Start-Process explorer.exe ('/select,"{0}"' -f [string]$this.Tag) })
            Add-Child $fr $fb
            $cb = New-Object System.Windows.Controls.CheckBox; $cb.VerticalAlignment = 'Center'; $cb.Margin = Th 0 0 8 0; $cb.Cursor = 'Hand'
            [System.Windows.Controls.DockPanel]::SetDock($cb, 'Left'); Add-Child $fr $cb
            $entry = @{ File = $f; Check = $cb; Row = $fr; Btn = $rb2; Show = $fb }
            [void]$script:BigChecks.Add($entry)
            $rb2.Tag = $entry
            $rb2.Add_Click({
                $e = $this.Tag
                if ((Remove-FilesToRecycle @($e.File) 'gros fichier') -gt 0) {
                    $e.Check.IsChecked = $false; $e.Check.IsEnabled = $false; $e.Btn.IsEnabled = $false; $e.Btn.Content = 'À la corbeille ✓'; $e.Show.IsEnabled = $false; $e.Row.Opacity = 0.5
                }
            })
            Add-Child $fr (New-Text ("{0}  ·  {1}  ·  {2}" -f (Format-Size $f.Size), [IO.Path]::GetFileName($f.Path), (Format-Date $f.Date)) 12.5 '#E6E9F2')
            $ft = New-Object System.Windows.Controls.StackPanel; Add-Child $ft $fr
            $fp = New-Text ([IO.Path]::GetDirectoryName($f.Path)) 11 '#6E768B'; Add-Child $ft $fp
            Add-Child $cs $ft
        }
        Add-Child $dp $cs
        $card.Child = $dp; Add-Child $Body $card
    }
}

# Vieux installateurs des Téléchargements : à la corbeille (récupérables), après confirmation
function Remove-OldInstallers {
    [void](Remove-FilesToRecycle @($sync.SpaceScan.OldInstallers) 'vieux installateur(s)')
}

function Start-CleanAnalysis($Issue) {
    $script:CleanIssue = $Issue
    [void](Start-AeroxTask 'Get-CleanupAnalysis' 'Analyse du nettoyage' 'cleandialog')
}
# ---------------------------------------------------------------- Fenêtre : pilotes (carte graphique, Windows Update, périphériques)
function Start-DriverCheck($Issue) {
    $script:DrvIssue = $Issue
    [void](Start-AeroxTask 'Get-DriverReport' 'Vérification des pilotes' 'driverdialog')
}

function New-DrvSection([string]$Text) { $h = New-Text $Text 11.5 '#7A8399' 'Bold'; $h.Margin = Th 2 14 0 8; return $h }

function Show-DriverDialog($Issue) {
    $rep = $sync.DriverScan
    if (-not $rep) { return }
    $w = New-Dialog "$AppName : pilotes" 720
    $script:DrvWin = $w; $script:DrvChoice = $null; $script:DrvRows = New-Object System.Collections.ArrayList
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = Th 24 22 24 20
    Add-Child $sp (New-Text "Pilotes (drivers)" 18 '#FFFFFF' 'Bold')
    $p = New-Text "Les pilotes font le lien entre Windows et ton matériel. Ici tu vois s'ils sont à jour, et tu installes en un clic ceux que Windows propose. AEROX n'utilise que des sources officielles (fabricant et Windows Update)." 13 '#A9B0C2'
    $p.Margin = Th 0 6 0 4; Add-Child $sp $p
    $list = New-Object System.Windows.Controls.StackPanel
    $sv = New-Object System.Windows.Controls.ScrollViewer; $sv.VerticalScrollBarVisibility = 'Auto'; $sv.MaxHeight = 470; $sv.Content = $list
    Add-Child $sp $sv

    # 1. Carte(s) graphique(s)
    Add-Child $list (New-DrvSection 'CARTE GRAPHIQUE')
    if (-not @($rep.Gpus).Count) { Add-Child $list (New-Text "Aucune carte graphique détectée." 13 '#8B93A7') }
    foreach ($g in @($rep.Gpus)) {
        $row = New-Object System.Windows.Controls.Border; $row.Background = Brush '#171A23'; $row.CornerRadius = Corner 10; $row.Padding = Th 14 10 12 10; $row.Margin = Th 0 0 6 6
        $dp = New-Object System.Windows.Controls.DockPanel
        $url = if ($g.Latest -and $g.Latest.Url) { $g.Latest.Url } else { $g.Page }
        if ($url) {
            $b = New-DlgButton $(if ($g.Status -in 'old', 'none') { 'Télécharger le pilote officiel' } else { 'Page officielle' }) $(if ($g.Status -in 'old', 'none') { 'PrimaryBtn' } else { 'TextBtn' })
            $b.Tag = $url; $b.VerticalAlignment = 'Center'; $b.Margin = Th 10 0 0 0
            $b.Add_Click({ if (Open-Url ([string]$this.Tag)) { Write-UiLog "   ✔ Page officielle du pilote ouverte dans le navigateur" } })
            [System.Windows.Controls.DockPanel]::SetDock($b, 'Right'); Add-Child $dp $b
        }
        $txt = New-Object System.Windows.Controls.StackPanel
        $head = New-Object System.Windows.Controls.StackPanel; $head.Orientation = 'Horizontal'
        Add-Child $head (New-Text $g.Name 14 '#FFFFFF' 'SemiBold')
        switch ($g.Status) {
            'ok'   { Add-Child $head (New-Pill 'À jour' '#4ADE80' '#173326') }
            'old'  { Add-Child $head (New-Pill 'Pas à jour' '#FFB547' '#3A2D17') }
            'none' { Add-Child $head (New-Pill 'Pas de pilote' '#FF6B6B' '#3A1E24') }
            default { Add-Child $head (New-Pill 'Non vérifiable' '#8B93A7' '#222736') }
        }
        Add-Child $txt $head
        # La date de Windows est celle que le fabricant a donnée au pilote (souvent quelques jours avant sa sortie), pas celle de ton installation
        $info = "Version installée : $($g.Version)" + $(if ($g.Installed) { ", installée le " + (Format-Date $g.Installed) } else { '' }) + $(if ($g.Date) { " (pilote daté du " + (Format-Date $g.Date) + " par le fabricant)" } else { '' })
        if ($g.Latest -and $g.Latest.Version) { $info += "   ·   Dernière officielle : $($g.Latest.Version)" + $(if ($g.Latest.Date) { " (sortie le " + (Format-Date $g.Latest.Date) + ")" } else { '' }) }
        Add-Child $txt (New-Text $info 12 '#8B93A7')
        if ($g.Tool -and $g.Status -ne 'ok') { $t = New-Text ("Le plus simple : installe « {0} », il garde le pilote à jour tout seul." -f $g.Tool) 12 '#7A8399'; $t.Margin = Th 0 3 0 0; Add-Child $txt $t }
        Add-Child $dp $txt
        $row.Child = $dp; Add-Child $list $row
    }

    # 2. Pilotes proposés par Windows Update
    $wu = @($rep.Wu | Where-Object { -not $_.Display }); $wuDisp = @($rep.Wu | Where-Object { $_.Display })
    Add-Child $list (New-DrvSection 'PROPOSÉS PAR WINDOWS UPDATE')
    if ($rep.WuError) {
        Add-Child $list (New-Text ("Windows Update n'a pas répondu ({0}). Si ça se répète : onglet Réparation > « Débloquer Windows Update »." -f $rep.WuError) 13 '#FFB547')
    } elseif (-not $wu.Count) {
        Add-Child $list (New-Text "Rien à installer : Windows ne propose aucun nouveau pilote pour ton PC." 13 '#4ADE80')
    }
    foreach ($u in $wu) {
        $txt = New-Object System.Windows.Controls.StackPanel; $txt.Margin = Th 8 0 0 0
        Add-Child $txt (New-Text $u.Title 13.5 '#FFFFFF' 'SemiBold')
        $meta = @(); if ($u.Maker) { $meta += $u.Maker }; if ($u.Class) { $meta += $u.Class }; if ($u.Date) { $meta += "pilote du " + (Format-Date $u.Date) }; if ($u.Size -gt 0) { $meta += (Format-Size $u.Size) }
        if ($meta.Count) { Add-Child $txt (New-Text ($meta -join '  ·  ') 12 '#8B93A7') }
        if ($u.Repeat) { $rt = New-Text ("Déjà installé par AEROX le {0}, mais Windows le propose encore : le réinstaller ne changera rien (un pilote équivalent est souvent déjà en place)." -f (Format-Date $u.DoneAt)) 12 '#FFB547'; $rt.Margin = Th 0 3 0 0; Add-Child $txt $rt }
        $r = New-CheckRow (-not $u.Repeat) $txt $null
        $r.Check.Add_Click({ & $script:CountDrv })
        Add-Child $list $r.Row
        [void]$script:DrvRows.Add(@{ U = $u; Check = $r.Check })
    }
    if ($wuDisp.Count) {
        $t = New-Text ("{0} pilote(s) graphique(s) proposé(s) par Windows non affiché(s) : ils sont souvent plus vieux que ceux du fabricant. Pour la carte graphique, utilise le bouton officiel au-dessus." -f $wuDisp.Count) 12 '#7A8399'
        $t.Margin = Th 2 2 0 0; Add-Child $list $t
    }

    # 3. Périphériques en erreur
    if (@($rep.Devices).Count) {
        Add-Child $list (New-DrvSection ("PÉRIPHÉRIQUES AVEC UN PROBLÈME ({0})" -f @($rep.Devices).Count))
        foreach ($d in @($rep.Devices)) { $t = New-Text ("•  {0} — {1}" -f $d.Name, $d.Reason) 13 '#E6E9F2'; $t.Margin = Th 4 0 0 4; Add-Child $list $t }
        $t = New-Text $(if ($wu.Count) { "Installe d'abord les pilotes proposés au-dessus et redémarre : ça règle souvent ces problèmes. Sinon, prends le pilote sur le site du fabricant de ton PC ou de ta carte mère (onglet Mon PC)." } else { "Windows n'a pas de pilote pour eux : prends-le sur le site du fabricant de ton PC ou de ta carte mère (onglet Mon PC > « Chercher sur le site officiel »)." }) 12 '#7A8399'
        $t.Margin = Th 4 4 0 0; Add-Child $list $t
    }

    $bar = New-Object System.Windows.Controls.DockPanel; $bar.Margin = Th 0 14 0 0
    $right = New-Object System.Windows.Controls.StackPanel; $right.Orientation = 'Horizontal'; [System.Windows.Controls.DockPanel]::SetDock($right, 'Right')
    $bClose = New-DlgButton 'Fermer' 'TextBtn'; $bClose.Margin = Th 0 0 8 0
    $bApply = New-DlgButton 'Installer' 'PrimaryBtn'; $script:DrvApply = $bApply
    Add-Child $right $bClose; Add-Child $right $bApply; Add-Child $bar $right
    $bDev = New-DlgButton 'Gestionnaire de périphériques' 'GhostBtn'; $bDev.HorizontalAlignment = 'Left'; Add-Child $bar $bDev
    Add-Child $sp $bar
    $w.Content = $sp

    $script:CountDrv = {
        $n = @($script:DrvRows | Where-Object { $_.Check.IsChecked }).Count
        $script:DrvApply.Content = $(if ($n) { "Installer ($n)" } else { 'Installer' })
        $script:DrvApply.IsEnabled = ($n -gt 0)
    }
    $bDev.Add_Click({ Open-SystemTool 'devmgmt.msc' })
    $bClose.Add_Click({ $script:DrvWin.Close() })
    $bApply.Add_Click({ $script:DrvChoice = @($script:DrvRows | Where-Object { $_.Check.IsChecked } | ForEach-Object { $_.U }); $script:DrvWin.Close() })
    & $script:CountDrv
    [void]$w.ShowDialog()

    $sel = $script:DrvChoice
    if (-not $sel -or -not $sel.Count) { return }
    if (-not (Confirm-Box ("Installer $($sel.Count) pilote(s) depuis Windows Update ?`n`nUn point de restauration est créé avant, pour pouvoir revenir en arrière si un pilote pose problème. Le PC devra peut-être redémarrer à la fin."))) { return }
    $action = "Install-DriverUpdates -Ids $(ConvertTo-PsList @($sel | ForEach-Object { $_.Id }))"
    [void](Start-AeroxTask $action ("Installation de {0} pilote(s)" -f $sel.Count))
    Refresh-Page
}

# ---------------------------------------------------------------- Fenêtre : pourquoi mon PC rame
function New-Meter([string]$Label, [double]$Pct, [string]$Sub) {
    $col = if ($Pct -ge 85) { '#FF6B6B' } elseif ($Pct -ge 60) { '#FFB547' } else { '#4ADE80' }
    $b = New-Object System.Windows.Controls.Border; $b.Background = Brush '#171A23'; $b.CornerRadius = Corner 10; $b.Padding = Th 14 10 14 12; $b.Margin = Th 0 0 8 0
    $sp = New-Object System.Windows.Controls.StackPanel
    Add-Child $sp (New-Text $Label 12 '#8B93A7' 'SemiBold')
    Add-Child $sp (New-Text ("{0} %" -f [math]::Round($Pct)) 24 $col 'Bold')
    $tr = New-Object System.Windows.Controls.Border; $tr.Height = 6; $tr.CornerRadius = Corner 3; $tr.Background = Brush '#252A3A'; $tr.Margin = Th 0 4 0 4
    $g = New-Object System.Windows.Controls.Grid
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = New-Object System.Windows.GridLength([math]::Max([double]0.01, [math]::Min([double]100.0, $Pct)), [System.Windows.GridUnitType]::Star)
    $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = New-Object System.Windows.GridLength([math]::Max([double]0.01, 100.0 - [math]::Min([double]100.0, $Pct)), [System.Windows.GridUnitType]::Star)
    $g.ColumnDefinitions.Add($c1); $g.ColumnDefinitions.Add($c2)
    $fl = New-Object System.Windows.Controls.Border; $fl.CornerRadius = Corner 3; $fl.Background = Brush $col; Add-Child $g $fl
    $tr.Child = $g; Add-Child $sp $tr
    if ($Sub) { Add-Child $sp (New-Text $Sub 11.5 '#7A8399') }
    $b.Child = $sp
    return $b
}
function New-StatTile([string]$Label, [string]$Value, [string]$Color, [string]$Sub) {
    $b = New-Object System.Windows.Controls.Border; $b.Background = Brush '#171A23'; $b.CornerRadius = Corner 10; $b.Padding = Th 14 10 14 12; $b.Margin = Th 0 0 8 0
    $sp = New-Object System.Windows.Controls.StackPanel
    Add-Child $sp (New-Text $Label 12 '#8B93A7' 'SemiBold')
    Add-Child $sp (New-Text $Value 24 $Color 'Bold')
    if ($Sub) { Add-Child $sp (New-Text $Sub 11.5 '#7A8399') }
    $b.Child = $sp
    return $b
}
function Start-LagReport { [void](Start-AeroxTask 'Get-LagReport' 'Analyse de la connexion' 'slowdialog') }
function Start-GameMeasure {
    if ($script:Job) { return }
    [System.Windows.MessageBox]::Show("Lance ton jeu maintenant et joue normalement.`n`nLa mesure démarre dans 1 minute et dure 20 secondes. Reviens ensuite sur AEROX : le résultat t'attendra.", $AppName, 'OK', 'Information') | Out-Null
    if (-not $script:GameSess -and -not $script:GameProbe) { try { Stop-Monitoring } catch {} }
    [void](Start-AeroxTask 'Get-SlowReport -Delay 60 -Mode jeu' 'Mesure pendant ton jeu' 'slowdialog')
}
# « Dis-moi ce qui rame » : quand la mesure ne trouve rien (ou pas la bonne chose), la personne dit ce qu'elle vit
# et AEROX lance l'analyse qui correspond (comme un réparateur qui pose la question avant de chercher)
$script:SlowSymptoms = @(
    @('lag', "Ça lague en ligne", "Jeu ou Discord : personnages qui sautent, voix hachée, déconnexions. Mesure la connexion pendant 1 minute."),
    @('fps', "Les jeux saccadent / FPS bas", "La mesure se fait pendant que tu joues (tu as 1 minute pour lancer ton jeu)."),
    @('demarrage', "Lent à démarrer", "Choisis ce qui se lance au démarrage. Le diagnostic complet regarde aussi ce que Windows a noté sur ses démarrages."),
    @('logiciel', "Un logiciel précis bugue", "Discord, navigateur, imprimante, son, Windows Update… : les dépannages rapides."),
    @('tout', "Tout est lent, tout le temps", "Lance le diagnostic complet : santé du disque, pilotes, plantages, logiciels inutiles, Windows.")
)
function Show-SlowDialog {
    $r = $sync.SlowReport
    if (-not $r) { return }
    $mode = "$($r.Mode)"
    $title = switch ($mode) { 'lag' { "Pourquoi ça lague ?" } 'jeu' { "Ce qui ralentit ton jeu" } default { "Pourquoi mon PC rame ?" } }
    $w = New-Dialog ("$AppName : " + $(switch ($mode) { 'lag' { "pourquoi ça lague" } 'jeu' { "mesure pendant ton jeu" } default { "pourquoi mon PC rame" } })) 820
    $script:SlowWin = $w; $script:SlowNext = $null; $script:SlowArg = $null
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = Th 24 22 24 20
    Add-Child $sp (New-Text $title 18 '#FFFFFF' 'Bold')
    $sub = switch ($mode) {
        'lag' { "Connexion mesurée pendant 1 minute : entre le PC et la box, puis vers Internet. Si ça lague seulement à certains moments, relance l'analyse à ce moment-là." }
        'jeu' { "Mesure faite pendant 20 secondes, pendant que tu jouais." }
        default { "Mesure faite pendant 20 secondes. Si le PC rame surtout à un moment précis (démarrage, navigateur, jeu), relance l'analyse à ce moment-là : c'est là qu'on voit le coupable." }
    }
    $p = New-Text $sub 13 '#A9B0C2'; $p.Margin = Th 0 6 0 12; Add-Child $sp $p
    $body = New-Object System.Windows.Controls.StackPanel
    $sv = New-Object System.Windows.Controls.ScrollViewer; $sv.VerticalScrollBarVisibility = 'Auto'; $sv.MaxHeight = 520; $sv.Content = $body
    Add-Child $sp $sv
    $mg = New-Object System.Windows.Controls.Grid
    $tiles = @()
    if ($mode -eq 'lag') {
        $col = { param($v, $warn, $bad) if ($v -ge $bad) { '#FF6B6B' } elseif ($v -ge $warn) { '#FFB547' } else { '#4ADE80' } }
        $tiles += $(if ($r.Gw.Ok) { New-StatTile 'PC ↔ BOX' ("{0} ms" -f [math]::Round($r.Gw.Avg)) (& $col $r.Gw.Avg 10 30) ("±{0} ms · {1} % perdus" -f $r.Gw.Jitter, $r.Gw.Loss) } else { New-StatTile 'PC ↔ BOX' '—' '#8B93A7' 'la box ne répond pas au ping' })
        $tiles += $(if ($r.Net.Ok) { New-StatTile 'INTERNET' ("{0} ms" -f [math]::Round($r.Net.Avg)) (& $col $r.Net.Avg 50 80) ("variations ±{0} ms" -f $r.Net.Jitter) } else { New-StatTile 'INTERNET' '—' '#8B93A7' 'ping bloqué sur ce réseau' })
        $tiles += $(if ($r.Net.Ok) { New-StatTile 'PAQUETS PERDUS' ("{0} %" -f $r.Net.Loss) (& $col $r.Net.Loss 1 3) 'vers Internet' } else { New-StatTile 'PAQUETS PERDUS' '—' '#8B93A7' 'non mesuré' })
    } else {
        $tiles += New-Meter 'PROCESSEUR' $r.Cpu ("pointe à {0} %" -f $r.CpuMax)
        $tiles += New-Meter 'MÉMOIRE (RAM)' $r.Ram ("sur {0}" -f (Format-Size $r.RamTotal))
        $tiles += New-Meter 'DISQUE' $r.Disk $(if ($r.Hdd) { 'disque dur classique (HDD)' } else { "activité moyenne" })
        if ($r.GpuOk) { $tiles += New-Meter 'CARTE GRAPHIQUE' $r.Gpu 'utilisation moyenne' }
    }
    for ($k = 0; $k -lt $tiles.Count; $k++) {
        $cd = New-Object System.Windows.Controls.ColumnDefinition; $cd.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star); $mg.ColumnDefinitions.Add($cd)
        if ($k -eq $tiles.Count - 1) { $tiles[$k].Margin = Th 0 0 0 0 }
        [System.Windows.Controls.Grid]::SetColumn($tiles[$k], $k); Add-Child $mg $tiles[$k]
    }
    Add-Child $body $mg

    $fs = @($r.Findings | Where-Object { $_ })
    $h = New-Text $(if ($fs.Count) { $(if ($mode -eq 'lag') { "CE QUI FAIT LAGUER ($($fs.Count))" } else { "CE QUI RALENTIT TON PC ($($fs.Count))" }) } else { 'RÉSULTAT' }) 11.5 '#7A8399' 'Bold'; $h.Margin = Th 2 16 0 8; Add-Child $body $h
    if (-not $fs.Count) {
        $msg = if ($mode -eq 'lag') { "Rien d'anormal pendant la mesure : la connexion est stable. Si ça lague seulement dans un jeu précis, c'est souvent le serveur du jeu (regarde le ping affiché dans le jeu) ou un autre appareil de la maison qui télécharge à ce moment-là." }
               else { "Rien d'anormal pendant la mesure : tout ce qui est listé plus bas a été vérifié. Dis-moi juste en dessous ce qui rame exactement : AEROX lance l'analyse qui correspond." }
        $t = New-Text $msg 13 '#4ADE80'; $t.Margin = Th 2 0 0 6; Add-Child $body $t
    }
    foreach ($x in $fs) {
        $card = New-Object System.Windows.Controls.Border; $card.Background = Brush '#171A23'; $card.CornerRadius = Corner 10; $card.Padding = Th 14 10 14 12; $card.Margin = Th 0 0 0 8
        $card.BorderThickness = Th 3 0 0 0; $card.BorderBrush = Brush $(if ($x.Sev -eq 'bad') { '#FF6B6B' } else { '#FFB547' })
        $cs = New-Object System.Windows.Controls.StackPanel
        Add-Child $cs (New-Text $x.Title 14 '#FFFFFF' 'SemiBold')
        if ($x.Text) { $t = New-Text $x.Text 12.5 '#C3CAD9'; $t.Margin = Th 0 3 0 0; Add-Child $cs $t }
        if ($x.Advice) { $t = New-Text ("→ " + $x.Advice) 12.5 '#A9B0C2'; $t.Margin = Th 0 5 0 0; Add-Child $cs $t }
        $lbl = switch ($x.Action) { 'taskmgr' { 'Ouvrir le Gestionnaire des tâches' } 'startup' { 'Choisir les programmes au démarrage' } 'balanced' { 'Passer en mode Équilibré' } 'cpumax' { 'Remettre à 100 %' }
                                    'space' { 'Voir ce qui prend de la place' } 'drivers' { 'Vérifier les pilotes' } 'pagefile' { 'Remettre en automatique' } 'netpower' { "Désactiver cette économie d'énergie" } default { '' } }
        if ($lbl) {
            $b = New-DlgButton $lbl 'ActionBtn'; $b.Tag = @($x.Action, "$($x.Adapter)"); $b.HorizontalAlignment = 'Left'; $b.Margin = Th 0 8 0 0
            $b.Add_Click({ $script:SlowNext = [string]$this.Tag[0]; $script:SlowArg = [string]$this.Tag[1]; $script:SlowWin.Close() }); Add-Child $cs $b
        }
        $card.Child = $cs; Add-Child $body $card
    }

    # Ce qui a été vérifié, avec les valeurs mesurées (rien n'est « OK » sans avoir été regardé)
    $ck = @($r.Checked | Where-Object { $_ })
    if ($ck.Count) {
        $h = New-Text "CE QUI A ÉTÉ VÉRIFIÉ" 11.5 '#7A8399' 'Bold'; $h.Margin = Th 2 14 0 6; Add-Child $body $h
        $cb = New-Object System.Windows.Controls.Border; $cb.Background = Brush '#13161E'; $cb.CornerRadius = Corner 10; $cb.Padding = Th 14 8 14 8
        $cl = New-Object System.Windows.Controls.StackPanel
        foreach ($c in $ck) { $t = New-Text ($(if ($c.Ok) { '✔  ' } else { '⚠  ' }) + $c.T) 12.5 $(if ($c.Ok) { '#9FE3B4' } else { '#FFC870' }); $t.Margin = Th 0 2 0 2; Add-Child $cl $t }
        $cb.Child = $cl; Add-Child $body $cb
    }

    $top = @($r.Top | Where-Object { $_ })
    if ($top.Count) {
        $h = New-Text "CE QUI CONSOMME LE PLUS (MOYENNE SUR 20 S)" 11.5 '#7A8399' 'Bold'; $h.Margin = Th 2 14 0 6; Add-Child $body $h
        $tb = New-Object System.Windows.Controls.Border; $tb.Background = Brush '#13161E'; $tb.CornerRadius = Corner 10; $tb.Padding = Th 14 6 14 8
        $tg = New-Object System.Windows.Controls.Grid
        $widths = if ($r.GpuOk) { @(5, 1.1, 1.1, 1.3, 1.3) } else { @(5, 1, 1.3, 1.3) }
        foreach ($wd in $widths) { $cd = New-Object System.Windows.Controls.ColumnDefinition; $cd.Width = New-Object System.Windows.GridLength($wd, [System.Windows.GridUnitType]::Star); $tg.ColumnDefinitions.Add($cd) }
        $addRow = {
            param($cells, $color, $weight)
            $rd = New-Object System.Windows.Controls.RowDefinition; $rd.Height = [System.Windows.GridLength]::Auto; $tg.RowDefinitions.Add($rd)
            for ($c = 0; $c -lt $cells.Count; $c++) {
                $t = New-Text $cells[$c] 12.5 $color $weight; $t.Margin = Th 0 3 8 3
                if ($c -gt 0) { $t.TextAlignment = 'Right' }
                [System.Windows.Controls.Grid]::SetRow($t, $script:SlowRow); [System.Windows.Controls.Grid]::SetColumn($t, $c); Add-Child $tg $t
            }
            $script:SlowRow++
        }
        $script:SlowRow = 0
        if ($r.GpuOk) { & $addRow @('Programme', 'Processeur', 'Carte gr.', 'Mémoire', 'Lect./écrit.') '#7A8399' 'SemiBold' } else { & $addRow @('Programme', 'Processeur', 'Mémoire', 'Lect./écrit.') '#7A8399' 'SemiBold' }
        foreach ($x in $top) {
            $nm = if ($x.Label -and $x.Label -ne $x.Name) { "$($x.Label)  ($($x.Name))" } else { $x.Name }
            $io = $(if ($x.Io -ge 1KB) { (Format-Size $x.Io) + '/s' } else { '—' })
            if ($r.GpuOk) { & $addRow @($nm, ("{0} %" -f [math]::Round($x.Cpu)), $(if ($x.Gpu -ge 1) { "{0} %" -f $x.Gpu } else { '—' }), (Format-Size $x.Mem), $io) '#E6E9F2' 'Normal' }
            else { & $addRow @($nm, ("{0} %" -f [math]::Round($x.Cpu)), (Format-Size $x.Mem), $io) '#E6E9F2' 'Normal' }
        }
        $tb.Child = $tg; Add-Child $body $tb
    }

    # Dis-moi ce qui rame
    $h = New-Text $(if ($fs.Count) { "CE N'EST PAS ÇA ? DIS-MOI CE QUI RAME" } else { "DIS-MOI CE QUI RAME EXACTEMENT" }) 11.5 $(if ($fs.Count) { '#7A8399' } else { '#B9A8FF' }) 'Bold'; $h.Margin = Th 2 14 0 6; Add-Child $body $h
    $wp = New-Object System.Windows.Controls.WrapPanel
    foreach ($sy in $script:SlowSymptoms) {
        if (($mode -eq 'lag' -and $sy[0] -eq 'lag') -or ($mode -eq 'jeu' -and $sy[0] -eq 'fps')) { continue }
        $b = New-DlgButton $sy[1] 'ActionBtn'; $b.Tag = $sy[0]; $b.ToolTip = $sy[2]; $b.Margin = Th 0 0 8 8
        $b.Add_Click({ $script:SlowNext = 'sym'; $script:SlowArg = [string]$this.Tag; $script:SlowWin.Close() })
        Add-Child $wp $b
    }
    Add-Child $body $wp

    $bar = New-Object System.Windows.Controls.StackPanel; $bar.Orientation = 'Horizontal'; $bar.HorizontalAlignment = 'Right'; $bar.Margin = Th 0 14 0 0
    $bAgain = New-DlgButton 'Refaire la mesure' 'ActionBtn'; $bAgain.Margin = Th 0 0 8 0
    $bClose = New-DlgButton 'Fermer' 'PrimaryBtn'
    Add-Child $bar $bAgain; Add-Child $bar $bClose; Add-Child $sp $bar
    $bAgain.Add_Click({ $script:SlowNext = 'again'; $script:SlowWin.Close() })
    $bClose.Add_Click({ $script:SlowWin.Close() })
    $w.Content = $sp
    [void]$w.ShowDialog()
    switch ($script:SlowNext) {
        'again'    { switch ($mode) { 'lag' { Start-LagReport } 'jeu' { Start-GameMeasure } default { [void](Start-AeroxTask 'Get-SlowReport' 'Analyse des lenteurs' 'slowdialog') } } }
        'taskmgr'  { Start-Process taskmgr.exe }
        'startup'  { Show-StartupDialog $null }
        'balanced' { [void](Start-AeroxTask 'Set-BalancedPower' 'Mode Équilibré') }
        'cpumax'   { if (Confirm-Box "Le processeur pourra de nouveau utiliser 100 % de sa puissance sur secteur.`n`nAnnulable dans l'historique des changements.") { [void](Start-AeroxTask 'Set-CpuMaxState 100' 'Puissance du processeur') } }
        'space'    { Start-SpaceScan }
        'drivers'  { Start-DriverCheck $null }
        'pagefile' { if (Confirm-Box "Windows gérera de nouveau la mémoire virtuelle lui-même (réglage d'origine). Un redémarrage sera nécessaire.") { [void](Start-AeroxTask 'Enable-AutoPagefile' 'Mémoire virtuelle') } }
        'netpower' {
            if ($script:SlowArg -and (Confirm-Box "La carte réseau ne sera plus mise en veille par Windows. La connexion peut se couper 2 ou 3 secondes pendant le réglage.`n`nTu pourras annuler dans l'historique des changements.")) {
                [void](Start-AeroxTask ("Set-NetAdapterSleep {0} `$false" -f (ConvertTo-PsLiteral $script:SlowArg)) "Économie d'énergie de la carte réseau")
            }
        }
        'sym' {
            $k = $script:SlowArg
            # Compteurs anonymes : ce que les gens vivent, et quand AEROX n'avait rien trouvé (= ce qu'il faut lui apprendre)
            Add-StatsEvent "symptome:$k"
            if (-not $fs.Count) { Add-StatsEvent ("inconnu:{0}-{1}" -f $(if ($mode) { $mode } else { 'lent' }), $k) }
            switch ($k) {
                'lag'       { Start-LagReport }
                'fps'       { Start-GameMeasure }
                'demarrage' { Write-UiLog "→ Démarrage lent : choisis ce qui se lance tout seul. Le diagnostic complet lit aussi ce que Windows a noté sur ses derniers démarrages (ce qui l'a ralenti)."; Show-StartupDialog $null }
                'logiciel'  { Go-Page 'repair'; Write-UiLog "→ Dépannages rapides : choisis le logiciel qui bugue. S'il n'est pas dans la liste, envoie un rapport de bug en disant lequel : il sera ajouté." }
                'tout'      { if (-not $script:Scanning) { Start-Diagnostic } else { Go-Page 'diag' } }
            }
        }
    }
}

# ---------------------------------------------------------------- Fenêtre : programmes cachés en fond
function Start-BgList($Issue) {
    $script:BgIssue = $Issue
    [void](Start-AeroxTask 'Get-BgItems' 'Programmes cachés en fond' 'bgdialog')
}
function Show-BgDialog($Issue) {
    $items = @($sync.BgItems | Where-Object { $_ })
    $w = New-Dialog "$AppName : programmes cachés en fond" 760
    $script:BgWin = $w; $script:BgChoice = $null; $script:BgRows = New-Object System.Collections.ArrayList
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = Th 24 22 24 20
    Add-Child $sp (New-Text "Programmes cachés en fond" 18 '#FFFFFF' 'Bold')
    $p = New-Text "Ils se lancent tout seuls (tâches planifiées et services) sans apparaître dans les programmes au démarrage. Ceux qui ne servent à rien sont déjà cochés. Un service coupé passe en « manuel » : il redémarre si un logiciel en a vraiment besoin. Tout est annulable dans l'historique." 13 '#A9B0C2'
    $p.Margin = Th 0 6 0 12; Add-Child $sp $p
    $list = New-Object System.Windows.Controls.StackPanel
    $sv = New-Object System.Windows.Controls.ScrollViewer; $sv.VerticalScrollBarVisibility = 'Auto'; $sv.MaxHeight = 450; $sv.Content = $list
    Add-Child $sp $sv
    if (-not $items.Count) { $t = New-Text "Rien à signaler : aucune tâche ni aucun service en dehors de Windows ne tourne en fond." 13 '#4ADE80'; Add-Child $list $t }
    foreach ($grp in @(@('off', 'INUTILES EN FOND (RECOMMANDÉ DE COUPER)', '#FFB547'), @('unknown', 'NON RECONNUS (GARDE-LES SI TU NE SAIS PAS)', '#8B93A7'), @('keep', 'À GARDER', '#4ADE80'))) {
        $sel = @($items | Where-Object { $_.Verdict -eq $grp[0] } | Sort-Object { if ($_.Label) { $_.Label } else { $_.Name } })
        if (-not $sel.Count) { continue }
        $h = New-Text ("{0} · {1}" -f $grp[1], $sel.Count) 11.5 $grp[2] 'Bold'; $h.Margin = Th 2 10 0 8; Add-Child $list $h
        foreach ($x in $sel) {
            $txt = New-Object System.Windows.Controls.StackPanel; $txt.Margin = Th 8 0 0 0
            $title = if ($x.Label) { $x.Label } elseif ($x.Display) { $x.Display } else { $x.Name }
            Add-Child $txt (New-Text $title 13.5 '#FFFFFF' 'SemiBold')
            $meta = @($(if ($x.Kind -eq 'task') { 'Tâche planifiée' } else { 'Service' + $(if ($x.Running) { ' (en marche)' } else { '' }) }), $(if ($x.Display -and $x.Display -ne $title) { $x.Display } else { $x.Name }), $x.Company) | Where-Object { $_ }
            Add-Child $txt (New-Text ($meta -join '  ·  ') 11.5 '#7A8399')
            Add-Child $txt (New-Text $x.Why 12 '#A9B0C2')
            if ($x.Verdict -eq 'keep') {
                $row = New-Object System.Windows.Controls.Border; $row.Background = Brush '#13161E'; $row.CornerRadius = Corner 10; $row.Padding = Th 14 9 12 9; $row.Margin = Th 0 0 6 6
                $row.Child = $txt; Add-Child $list $row
            } else {
                $r = New-CheckRow ($x.Verdict -eq 'off') $txt $null
                $r.Check.Add_Click({ & $script:CountBg })
                Add-Child $list $r.Row
                [void]$script:BgRows.Add(@{ Item = $x; Check = $r.Check })
            }
        }
    }
    $bar = New-Object System.Windows.Controls.StackPanel; $bar.Orientation = 'Horizontal'; $bar.HorizontalAlignment = 'Right'; $bar.Margin = Th 0 14 0 0
    $bCancel = New-DlgButton 'Fermer' 'TextBtn'; $bCancel.Margin = Th 0 0 8 0
    $bApply = New-DlgButton 'Couper' 'PrimaryBtn'; $script:BgApply = $bApply
    Add-Child $bar $bCancel; Add-Child $bar $bApply; Add-Child $sp $bar
    $script:CountBg = {
        $n = @($script:BgRows | Where-Object { $_.Check.IsChecked }).Count
        $script:BgApply.Content = $(if ($n) { "Couper la sélection ($n)" } else { 'Couper la sélection' }); $script:BgApply.IsEnabled = ($n -gt 0)
    }
    $bCancel.Add_Click({ $script:BgWin.Close() })
    $bApply.Add_Click({ $script:BgChoice = @($script:BgRows | Where-Object { $_.Check.IsChecked } | ForEach-Object { $_.Item }); $script:BgWin.Close() })
    & $script:CountBg
    $w.Content = $sp
    [void]$w.ShowDialog()
    $sel = @($script:BgChoice | Where-Object { $_ })
    if (-not $sel.Count) { return }
    if (-not (Confirm-Box ("Couper {0} programme(s) caché(s) en fond ?`n`nL'effet est complet au prochain redémarrage. Tu peux tout annuler dans l'historique des changements." -f $sel.Count))) { return }
    $ids = @($sel | ForEach-Object { "{0}|{1}|{2}|{3}" -f $_.Kind, $_.Path, $_.Name, ($(if ($_.Label) { $_.Label } elseif ($_.Display) { $_.Display } else { $_.Name }) -replace '\|', '/') })
    if ($Issue) { $Issue.Status = 'fixing'; $script:FixingIssue = $Issue }
    if (-not (Start-AeroxTask ("Disable-BgItems -Items " + (ConvertTo-PsList $ids)) ("Coupure de {0} programme(s) en fond" -f $sel.Count))) { if ($Issue) { $Issue.Status = 'open'; $script:FixingIssue = $null } }
}

# ---------------------------------------------------------------- Fenêtre : arnaques du navigateur
function Start-BrowserCheck($Issue) {
    $script:BrowserIssue = $Issue
    [void](Start-AeroxTask 'Get-BrowserReport' 'Analyse des navigateurs' 'browserdialog')
}
function New-BrowserRow($Content, $Right) {
    $row = New-Object System.Windows.Controls.Border; $row.Background = Brush '#13161E'; $row.CornerRadius = Corner 10; $row.Padding = Th 14 9 12 9; $row.Margin = Th 0 0 6 6
    $dp = New-Object System.Windows.Controls.DockPanel
    if ($Right) { [System.Windows.Controls.DockPanel]::SetDock($Right, 'Right'); $Right.VerticalAlignment = 'Center'; Add-Child $dp $Right }
    Add-Child $dp $Content; $row.Child = $dp
    return $row
}
function Show-BrowserDialog($Issue) {
    $items = @($sync.BrowserReport.Items | Where-Object { $_ })
    $w = New-Dialog "$AppName : arnaques du navigateur" 780
    $script:BrWin = $w; $script:BrChoice = $null; $script:BrRows = New-Object System.Collections.ArrayList
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = Th 24 22 24 20
    Add-Child $sp (New-Text "Pubs et fausses alertes du navigateur" 18 '#FFFFFF' 'Bold')
    $p = New-Text "Les fausses alertes de virus en bas de l'écran viennent presque toujours d'un site qui a obtenu le droit d'envoyer des notifications (« clique sur Autoriser pour prouver que tu n'es pas un robot »). Ce qui est suspect est déjà coché. Le navigateur sera fermé le temps de la modification." 13 '#A9B0C2'
    $p.Margin = Th 0 6 0 12; Add-Child $sp $p
    $list = New-Object System.Windows.Controls.StackPanel
    $sv = New-Object System.Windows.Controls.ScrollViewer; $sv.VerticalScrollBarVisibility = 'Auto'; $sv.MaxHeight = 450; $sv.Content = $list
    Add-Child $sp $sv
    if (-not $items.Count) { Add-Child $list (New-Text "Aucun navigateur Chrome, Edge, Brave ou Opera trouvé sur ce PC." 13 '#8B93A7') }
    $groups = @(
        @('notif', "NOTIFICATIONS AUTORISÉES (D'OÙ VIENNENT LES FAUSSES ALERTES)", "Aucun site ne peut t'envoyer de notifications. Rien à faire."),
        @('pol', "RÉGLAGES IMPOSÉS AU NAVIGATEUR (« GÉRÉ PAR TON ORGANISATION »)", ''),
        @('home', "PAGE D'ACCUEIL, DÉMARRAGE ET RECHERCHE", ''),
        @('ext', 'EXTENSIONS INSTALLÉES', ''),
        @('firefox', 'FIREFOX', ''))
    $anyBrowser = @($items | Where-Object { $_.Type -ne 'firefox' }).Count -gt 0
    foreach ($grp in $groups) {
        $sel = @($items | Where-Object { $_.Type -eq $grp[0] } | Sort-Object @{ Expression = { -not $_.Bad } }, @{ Expression = { $_.Where } }, @{ Expression = { $_.Label } })
        if (-not $sel.Count) {
            if ($grp[2] -and $anyBrowser) { $h = New-Text $grp[1] 11.5 '#4ADE80' 'Bold'; $h.Margin = Th 2 10 0 4; Add-Child $list $h; $t = New-Text $grp[2] 12.5 '#8B93A7'; $t.Margin = Th 2 0 0 8; Add-Child $list $t }
            continue
        }
        $nb = @($sel | Where-Object { $_.Bad }).Count
        $h = New-Text ("{0} · {1}{2}" -f $grp[1], $sel.Count, $(if ($nb) { " (dont $nb suspect" + $(if ($nb -gt 1) { 's' } else { '' }) + ')' } else { '' })) 11.5 $(if ($nb) { '#FFB547' } else { '#4ADE80' }) 'Bold'
        $h.Margin = Th 2 10 0 8; Add-Child $list $h
        foreach ($x in $sel) {
            $txt = New-Object System.Windows.Controls.StackPanel; $txt.Margin = Th 8 0 0 0
            Add-Child $txt (New-Text $x.Label 13.5 $(if ($x.Bad) { '#FFB547' } else { '#FFFFFF' }) 'SemiBold')
            Add-Child $txt (New-Text ((@($x.Where, $x.Detail) | Where-Object { $_ }) -join '  ·  ') 11.5 '#8B93A7')
            if ($x.Type -in 'notif', 'pol' -and -not $x.Locked) {
                $r = New-CheckRow ([bool]$x.Check) $txt $null
                $r.Check.Add_Click({ & $script:CountBr })
                Add-Child $list $r.Row
                [void]$script:BrRows.Add(@{ Item = $x; Check = $r.Check })
            } else {
                $btn = $null
                if ($x.Exe -and $x.Page -and ($x.Bad -or $x.Type -in 'firefox', 'ext')) {
                    $btn = New-DlgButton $(if ($x.Type -eq 'ext') { 'Gérer' } else { 'Ouvrir les réglages' }) 'TextBtn'
                    $btn.Tag = @($x.Exe, $x.Page, "$($x.Prof)")
                    $btn.Add_Click({
                        $t = $this.Tag
                        Open-BrowserPage $t[0] $t[1] $t[2]
                        # Certains navigateurs refusent d'ouvrir leurs pages internes depuis un autre programme : l'adresse est copiée, prête à coller
                        try { [System.Windows.Clipboard]::SetText($t[1]) } catch {}
                        Write-UiLog ("→ Si le navigateur ne s'ouvre pas sur la bonne page : clique dans sa barre d'adresse, fais Ctrl+V puis Entrée (l'adresse {0} est copiée)." -f $t[1])
                    })
                }
                if ($x.Locked) { Add-Child $txt (New-Text "PC d'entreprise ou d'école : ces réglages viennent sûrement de l'informaticien, AEROX n'y touche pas." 11.5 '#7A8399') }
                Add-Child $list (New-BrowserRow $txt $btn)
            }
        }
        if ($grp[0] -eq 'ext') {
            $t = New-Text "Retire toute extension que tu n'as pas installée toi-même ou que tu n'utilises pas : « Gérer », puis « Supprimer » dans le navigateur." 12 '#8B93A7'; $t.Margin = Th 2 2 0 8; Add-Child $list $t
        }
    }
    $bar = New-Object System.Windows.Controls.StackPanel; $bar.Orientation = 'Horizontal'; $bar.HorizontalAlignment = 'Right'; $bar.Margin = Th 0 14 0 0
    $bCancel = New-DlgButton 'Fermer' 'TextBtn'; $bCancel.Margin = Th 0 0 8 0
    $bApply = New-DlgButton 'Bloquer' 'PrimaryBtn'; $script:BrApply = $bApply
    Add-Child $bar $bCancel; Add-Child $bar $bApply; Add-Child $sp $bar
    $script:CountBr = {
        $n = @($script:BrRows | Where-Object { $_.Check.IsChecked }).Count
        $script:BrApply.Content = $(if ($n) { "Bloquer / retirer la sélection ($n)" } else { 'Bloquer / retirer la sélection' }); $script:BrApply.IsEnabled = ($n -gt 0)
    }
    $bCancel.Add_Click({ $script:BrWin.Close() })
    $bApply.Add_Click({ $script:BrChoice = @($script:BrRows | Where-Object { $_.Check.IsChecked } | ForEach-Object { $_.Item }); $script:BrWin.Close() })
    & $script:CountBr
    $w.Content = $sp
    [void]$w.ShowDialog()
    $sel = @($script:BrChoice | Where-Object { $_ })
    if (-not $sel.Count) {
        # Rien de suspect et rien à bloquer : le problème du diagnostic est réglé
        if ($Issue -and -not @($items | Where-Object { $_.Bad -and -not $_.Locked }).Count) { $Issue.Status = 'done'; Update-DiagBadge; Refresh-Page }
        return
    }
    $procs = @($sel | Where-Object { $_.Type -eq 'notif' } | ForEach-Object { $_.Proc } | Select-Object -Unique | Where-Object { $_ -and (Get-Process -Name $_ -ErrorAction SilentlyContinue) })
    $names = @{ chrome = 'Google Chrome'; msedge = 'Microsoft Edge'; brave = 'Brave'; opera = 'Opera' }
    $msg = "Bloquer / retirer {0} élément(s) ?" -f $sel.Count
    if ($procs.Count) { $msg += "`n`n{0} va être fermé le temps de la modification. Tes onglets te seront proposés à la réouverture." -f (@($procs | ForEach-Object { $names[$_] }) -join ' et ') }
    if (@($sel | Where-Object { $_.Type -eq 'pol' }).Count) { $msg += "`n`nLes réglages imposés retirés sont sauvegardés : annulable dans l'historique des changements." }
    if (-not (Confirm-Box ($msg + "`n`nContinuer ?"))) { return }
    $fix = @($sel | ForEach-Object { $_.Fix })
    if ($Issue) { $Issue.Status = 'fixing'; $script:FixingIssue = $Issue }
    if (-not (Start-AeroxTask ("Repair-BrowserItems -Items " + (ConvertTo-PsList $fix)) ("Nettoyage des navigateurs ({0})" -f $sel.Count))) { if ($Issue) { $Issue.Status = 'open'; $script:FixingIssue = $null } }
}

# ---------------------------------------------------------------- Fenêtre : fichiers en double
function Start-DuplicateScan { [void](Start-AeroxTask 'Get-Duplicates' 'Recherche des fichiers en double' 'dupdialog') }
function Show-DuplicatesDialog {
    $groups = @($sync.Dupes.Groups | Where-Object { $_ })
    if (-not $groups.Count) { [System.Windows.MessageBox]::Show("Aucun fichier en double trouvé dans tes dossiers (Bureau, Documents, Images, Vidéos, Musique, Téléchargements).", $AppName, 'OK', 'Information') | Out-Null; return }
    $w = New-Dialog "$AppName : fichiers en double" 820
    $script:DupWin = $w; $script:DupChoice = $null; $script:DupRows = New-Object System.Collections.ArrayList
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = Th 24 22 24 20
    $gain = [double](($groups | ForEach-Object { $_[0].Size * ($_.Count - 1) } | Measure-Object -Sum).Sum)
    Add-Child $sp (New-Text ("Fichiers en double · {0} récupérables" -f (Format-Size $gain)) 18 '#FFFFFF' 'Bold')
    $p = New-Text "Ces fichiers sont identiques au contenu près. Pour chacun, AEROX garde un exemplaire (celui qui n'est pas dans Téléchargements, sinon le plus ancien) et coche les copies. Tu peux changer les cases ; au moins un exemplaire est toujours gardé. Les copies vont à la corbeille." 13 '#A9B0C2'
    $p.Margin = Th 0 6 0 12; Add-Child $sp $p
    $list = New-Object System.Windows.Controls.StackPanel
    $sv = New-Object System.Windows.Controls.ScrollViewer; $sv.VerticalScrollBarVisibility = 'Auto'; $sv.MaxHeight = 470; $sv.Content = $list
    Add-Child $sp $sv
    $gi = 0
    foreach ($g in $groups) {
        $gi++
        # Exemplaire gardé : hors Téléchargements, sans « copie / copy / (1) », le plus ancien, le chemin le plus court
        $keep = @($g | Sort-Object @{ Expression = { $_.Path -match '(?i)\\(downloads|téléchargements)\\' } }, @{ Expression = { [IO.Path]::GetFileNameWithoutExtension($_.Path) -match '(?i)copie|copy|\(\d+\)$| - \d+$' } }, @{ Expression = { $_.Date } }, @{ Expression = { $_.Path.Length } })[0]
        $h = New-Text ("{0}  ·  {1} exemplaires  ·  {2} chacun" -f [IO.Path]::GetFileName($keep.Path), $g.Count, (Format-Size $keep.Size)) 13 '#FFFFFF' 'SemiBold'
        $h.Margin = Th 2 10 0 6; Add-Child $list $h
        foreach ($f in $g) {
            $isKeep = ($f.Path -eq $keep.Path)
            $txt = New-Object System.Windows.Controls.StackPanel; $txt.Margin = Th 8 0 0 0
            Add-Child $txt (New-Text ([IO.Path]::GetDirectoryName($f.Path)) 12.5 $(if ($isKeep) { '#4ADE80' } else { '#E6E9F2' }))
            Add-Child $txt (New-Text (("{0}  ·  modifié le {1}" -f [IO.Path]::GetFileName($f.Path), (Format-Date $f.Date)) + $(if ($isKeep) { '  ·  gardé' } else { '' })) 11.5 '#7A8399')
            $b = New-DlgButton 'Afficher' 'TextBtn'; $b.Tag = $f.Path; $b.Add_Click({ Start-Process explorer.exe ('/select,"{0}"' -f [string]$this.Tag) })
            $r = New-CheckRow (-not $isKeep) $txt $b
            $r.Check.Add_Click({ & $script:CountDup })
            Add-Child $list $r.Row
            [void]$script:DupRows.Add(@{ File = $f; Group = $gi; Check = $r.Check })
        }
    }
    $bar = New-Object System.Windows.Controls.StackPanel; $bar.Orientation = 'Horizontal'; $bar.HorizontalAlignment = 'Right'; $bar.Margin = Th 0 14 0 0
    $bCancel = New-DlgButton 'Fermer' 'TextBtn'; $bCancel.Margin = Th 0 0 8 0
    $bApply = New-DlgButton 'Mettre à la corbeille' 'PrimaryBtn'; $script:DupApply = $bApply
    Add-Child $bar $bCancel; Add-Child $bar $bApply; Add-Child $sp $bar
    $script:CountDup = {
        $sel = @($script:DupRows | Where-Object { $_.Check.IsChecked })
        $t = [double](($sel | ForEach-Object { $_.File.Size } | Measure-Object -Sum).Sum)
        $script:DupApply.Content = $(if ($sel.Count) { "Mettre à la corbeille ({0} · {1})" -f $sel.Count, (Format-Size $t) } else { 'Mettre à la corbeille' }); $script:DupApply.IsEnabled = ($sel.Count -gt 0)
    }
    $bCancel.Add_Click({ $script:DupWin.Close() })
    $bApply.Add_Click({
        # Jamais tous les exemplaires d'un même fichier
        $full = @($script:DupRows | Group-Object { $_.Group } | Where-Object { @($_.Group | Where-Object { -not $_.Check.IsChecked }).Count -eq 0 })
        if ($full.Count) { [System.Windows.MessageBox]::Show("Pour {0} fichier(s), tous les exemplaires sont cochés : décoche au moins un exemplaire à garder." -f $full.Count, $AppName, 'OK', 'Warning') | Out-Null; return }
        $script:DupChoice = @($script:DupRows | Where-Object { $_.Check.IsChecked } | ForEach-Object { $_.File }); $script:DupWin.Close()
    })
    & $script:CountDup
    $w.Content = $sp
    [void]$w.ShowDialog()
    if (@($script:DupChoice).Count) { [void](Remove-FilesToRecycle $script:DupChoice 'fichier(s) en double') }
}

function Start-AppUpdatesList($Issue) {
    $script:AppsIssue = $Issue
    [void](Start-AeroxTask 'Get-AppUpdatesForUi' 'Recherche des mises à jour' 'appdialog')
}

# =====================================================================
#  MONITEUR : capteurs (températures, utilisation), FPS et overlay en jeu
# =====================================================================
$script:SensPS = $null; $script:SensRS = $null
$script:Fps = $null
$script:GamePid = 0; $script:GameName = ''
$script:Live = @{}
$script:MonUi = $null
$script:Ov = $null; $script:OvRows = @{}; $script:OvEdit = $false; $script:OvHotPrev = 0; $script:HotkeyText = ''
$script:MonIdle = 0
$script:TickN = 0
$script:Blink = $false
$script:OverheatState = @{}

$SensorLoopCode = @'
$ErrorActionPreference = 'SilentlyContinue'
# Les températures sont lues par « AeroxPCCare.exe --capteurs » dans un processus séparé :
# si le module LibreHardwareMonitor plante, le logiciel reste ouvert et on garde les mesures de base.
$lhmDir = Join-Path (Join-Path $AppInfo.Secure 'outils') 'lhm'   # dossier protégé (le module est chargé avec les droits admin)
$sp = $null
$sync.SensMode = 'basic'; $sync.SensError = ''
if ((Test-Path (Join-Path $lhmDir 'LibreHardwareMonitorLib.dll')) -and $AppInfo.Launcher -and (Test-Path -LiteralPath $AppInfo.Launcher)) {
    $sp = New-Object AeroxSensorProc
    if (-not $sp.Start($AppInfo.Launcher, $lhmDir)) { $sync.SensError = $sp.LastError; $sp = $null }
} elseif (Test-Path (Join-Path $lhmDir 'LibreHardwareMonitorLib.dll')) {
    $sync.SensError = "Lance le logiciel avec le raccourci AEROX PC Care pour avoir les températures."
}
$spWait = 0
# Outil du pilote NVIDIA : seulement à ses emplacements officiels (jamais trouvé par le PATH)
$smi = $null
foreach ($p in @("$env:SystemRoot\System32\nvidia-smi.exe", "$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe")) { if (-not $smi -and (Test-Path -LiteralPath $p)) { $smi = $p } }
$cpuName = ((Get-CimInstance Win32_Processor | Select-Object -First 1).Name -replace '\s+', ' ').Trim()
$tot = [double](Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
function Pick($sensors, [string]$type, [string[]]$names) {
    foreach ($n in $names) {
        foreach ($s in $sensors) { if ("$($s.SensorType)" -eq $type -and $s.Name -eq $n -and $null -ne $s.Value) { return [double]$s.Value } }
    }
    return $null
}
while (-not $sync.SensStop) {
    $v = @{ 'cpu.name' = $cpuName }
    $frame = $null
    if ($sp) {
        $frame = $sp.Latest()
        if (-not $frame -and -not $sp.Running) {
            # Le module s'est arrêté : on le relance 2 fois maximum, puis on reste en mesures de base
            if ($sp.Restarts -lt 2) { $r = $sp.Restarts + 1; $err = $sp.LastError; [void]$sp.Start($AppInfo.Launcher, $lhmDir); $sp.Restarts = $r; $sp.LastError = $err }
            else { $sync.SensError = $(if ($sp.LastError) { $sp.LastError } else { "Le module de températures s'est arrêté." }); $sp = $null; $sync.SensMode = 'basic' }
        } elseif (-not $frame) {
            $spWait++
            if ($spWait -gt 20 -and $sp.LastError) { $sync.SensError = $sp.LastError }
        }
    }
    if ($frame) {
        $sync.SensMode = 'lhm'; $sync.SensError = ''; $spWait = 0
        try {
            # Regroupe les lignes "Type|Matériel|TypeCapteur|Capteur|Valeur" par matériel
            $hws = [ordered]@{}
            foreach ($line in $frame) {
                $f = $line.Split('|')
                if ($f.Count -lt 5) { continue }
                $val = 0.0
                if (-not [double]::TryParse($f[4], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$val)) { continue }
                $k = $f[0] + '|' + $f[1]
                if (-not $hws.Contains($k)) { $hws[$k] = @{ Type = $f[0]; Name = $f[1]; Sens = New-Object System.Collections.ArrayList } }
                [void]$hws[$k].Sens.Add([pscustomobject]@{ SensorType = $f[2]; Name = $f[3]; Value = $val })
            }
            $best = $null; $bestRank = -1
            foreach ($hw in $hws.Values) {
                $t = $hw.Type; $sens = $hw.Sens
                if ($t -eq 'Cpu') {
                    $x = Pick $sens 'Temperature' @('Core (Tctl/Tdie)', 'CPU Package', 'Package', 'Core (Tdie)', 'Core (Tctl)', 'Core Average', 'Core Max'); if ($x) { $v['cpu.temp'] = $x }
                    $x = Pick $sens 'Load' @('CPU Total'); if ($null -ne $x) { $v['cpu.load'] = $x }
                    # Cœur le plus chargé : un jeu limité par le processeur sature souvent 1 ou 2 cœurs, pas tout le processeur
                    $x = Pick $sens 'Load' @('CPU Core Max')
                    if ($null -eq $x) { $cm = @($sens | Where-Object { $_.SensorType -eq 'Load' -and $_.Name -match '^CPU Core #\d+' } | ForEach-Object { [double]$_.Value }); if ($cm.Count) { $x = ($cm | Measure-Object -Maximum).Maximum } }
                    if ($null -ne $x) { $v['cpu.coremax'] = $x }
                    $x = Pick $sens 'Power' @('Package', 'CPU Package'); if ($x) { $v['cpu.power'] = $x }
                    $cl = @($sens | Where-Object { $_.SensorType -eq 'Clock' -and $_.Name -match '^Core #\d+' -and $_.Value })
                    if ($cl.Count) { $v['cpu.clock'] = ($cl | ForEach-Object { [double]$_.Value } | Measure-Object -Average).Average }
                } elseif ($t -match '^Gpu') {
                    $rank = if ($t -eq 'GpuNvidia') { 3 } elseif ($t -eq 'GpuAmd') { if ($hw.Name -match 'Radeon\(TM\) Graphics|Radeon Graphics$') { 1 } else { 2 } } else { 0 }
                    if ($rank -gt $bestRank) { $bestRank = $rank; $best = $hw }
                }
            }
            if ($best) {
                $s = $best.Sens; $v['gpu.name'] = $best.Name
                $x = Pick $s 'Temperature' @('GPU Core', 'GPU Hot Spot'); if ($x) { $v['gpu.temp'] = $x }
                $x = Pick $s 'Temperature' @('GPU Hot Spot'); if ($x) { $v['gpu.hot'] = $x }
                $x = Pick $s 'Load' @('GPU Core', 'D3D 3D'); if ($null -ne $x) { $v['gpu.load'] = $x }
                $x = Pick $s 'SmallData' @('GPU Memory Used', 'D3D Dedicated Memory Used'); if ($x) { $v['gpu.vram'] = $x }
                $x = Pick $s 'SmallData' @('GPU Memory Total'); if ($x) { $v['gpu.vramtotal'] = $x }
                $x = Pick $s 'Power' @('GPU Package', 'GPU Power', 'GPU Core'); if ($x) { $v['gpu.power'] = $x }
                $x = Pick $s 'Clock' @('GPU Core'); if ($x) { $v['gpu.clock'] = $x }
            }
        } catch { $sync.SensError = $_.Exception.Message }
    }
    if (-not $v.ContainsKey('cpu.load')) {
        $c = Get-CimInstance Win32_PerfFormattedData_Counters_ProcessorInformation -Filter "Name='_Total'"
        if ($c) { $v['cpu.load'] = [math]::Min([double]100, [double]$c.PercentProcessorUtility) }
    }
    if ($smi -and -not $v.ContainsKey('gpu.temp')) {
        $o = & $smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw --format=csv,noheader,nounits 2>$null | Select-Object -First 1
        if ($o) {
            $f = @($o -split ',\s*')
            $v['gpu.name'] = $f[0]
            $n = 0.0
            if ([double]::TryParse($f[1], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$n)) { $v['gpu.temp'] = $n }
            if ([double]::TryParse($f[2], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$n)) { $v['gpu.load'] = $n }
            if ([double]::TryParse($f[3], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$n)) { $v['gpu.vram'] = $n }
            if ([double]::TryParse($f[4], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$n)) { $v['gpu.vramtotal'] = $n }
            if ($f.Count -gt 5 -and [double]::TryParse($f[5], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$n)) { $v['gpu.power'] = $n }
        }
    }
    $os = Get-CimInstance Win32_OperatingSystem
    if ($os) { $free = [double]$os.FreePhysicalMemory * 1KB; $v['ram.used'] = $tot - $free; $v['ram.total'] = $tot; $v['ram.load'] = ($tot - $free) / $tot * 100 }
    $sync.Sens = $v
    Start-Sleep -Milliseconds 1000
}
if ($sp) { try { $sp.Stop() } catch {} }
'@

function Start-Sensors {
    if ($script:SensPS) { return }
    $sync.SensStop = $false
    $rs = [runspacefactory]::CreateRunspace(); $rs.ApartmentState = 'MTA'; $rs.Open()
    $rs.SessionStateProxy.SetVariable('sync', $sync); $rs.SessionStateProxy.SetVariable('AppInfo', $AppInfo)
    $ps = [powershell]::Create(); $ps.Runspace = $rs; [void]$ps.AddScript($SensorLoopCode)
    $script:SensHandle = $ps.BeginInvoke()
    $script:SensPS = $ps; $script:SensRS = $rs
}
function Stop-Sensors {
    if (-not $script:SensPS) { return }
    $sync.SensStop = $true
    $ps = $script:SensPS; $rs = $script:SensRS
    $script:SensPS = $null; $script:SensRS = $null
    try { [void]$ps.EndInvoke($script:SensHandle) } catch {}
    try { $ps.Dispose(); $rs.Close(); $rs.Dispose() } catch {}
    $sync.Sens = $null
}
function Get-PresentMonPath { return (Find-PresentMon) }
function Start-FpsCounter {
    $pm = Get-PresentMonPath
    if (-not $pm) { return }
    if ($script:Fps -and $script:Fps.Running) { return }
    try { Get-Process -Name 'PresentMon*' -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $pm } | Stop-Process -Force -ErrorAction SilentlyContinue } catch {}
    if (-not $script:Fps) { $script:Fps = New-Object AeroxFps }
    if (-not $script:Fps.Start($pm)) { Write-Bug -Context 'Compteur de FPS' -ErrorRecord ("PresentMon n'a pas démarré : " + $script:Fps.LastError) -Type 'erreur' }
}
function Stop-FpsCounter { if ($script:Fps) { try { $script:Fps.Stop() } catch {} } }
function Stop-Monitoring { Stop-FpsCounter; Stop-Sensors }

function Test-MonitorNeeded { return (($script:Cur -eq 'monitor' -and -not $script:InTray) -or ($script:Ov -and $script:Ov.IsVisible) -or $script:GameSess -or $script:GameProbe) }

# Collecte : capteurs + FPS du jeu au premier plan
function Update-LiveData {
    $v = @{}; $s = $sync.Sens
    if ($s) { foreach ($k in $s.Keys) { $v[$k] = $s[$k] } }
    if ($script:Fps -and $script:Fps.Running) {
        $fg = [AeroxNative]::ForegroundPid()
        if ($fg -and $fg -ne $PID) {
            $r = $script:Fps.Get($fg)
            if ($r) { $script:GamePid = $fg; $script:GameName = $script:Fps.AppName($fg) }
        }
        if ($script:GamePid) {
            $r = $script:Fps.Get($script:GamePid)
            if ($r) { $v['fps'] = $r[0]; $v['low'] = $r[1]; $v['frametime'] = $r[2]; $v['game'] = $script:GameName }
            else { $script:GamePid = 0; $script:GameName = '' }
        }
    }
    $script:Live = $v
}

function Format-Val($v, [string]$fmt, [string]$unit) { if ($null -eq $v) { return '—' }; return ([string]::Format([Globalization.CultureInfo]::GetCultureInfo('fr-FR'), $fmt, [double]$v) + $unit) }
function Get-TempLimit([string]$Part) { $o = $script:Settings.Overlay; if ($Part -eq 'gpu') { return [double]$o.AlertGpu } else { return [double]$o.AlertCpu } }
function Get-TempColor($t, [string]$Part = 'cpu') {
    if ($null -eq $t) { return '#FFFFFF' }
    $lim = Get-TempLimit $Part
    if ($t -ge $lim) { return '#FF6B6B' }; if ($t -ge $lim - 10) { return '#FFB547' }; return '#FFFFFF'
}
# Alerte surchauffe : vrai si la pièce dépasse le seuil choisi (et que l'alerte est activée)
function Test-Overheat([string]$Part) {
    if (-not $script:Settings.Overlay.AlertOn) { return $false }
    $t = $script:Live["$Part.temp"]
    return ($null -ne $t -and $t -ge (Get-TempLimit $Part))
}
function Update-OverheatAlert {
    $script:Blink = -not $script:Blink
    foreach ($part in 'cpu', 'gpu') {
        $hot = Test-Overheat $part
        $key = "Hot$part"
        if ($hot -and -not $script:OverheatState[$key]) {
            $script:OverheatState[$key] = $true
            $last = $script:OverheatState["Last$part"]
            if (-not $last -or ((Get-Date) - $last).TotalMinutes -ge 5) {
                $script:OverheatState["Last$part"] = Get-Date
                $name = if ($part -eq 'gpu') { 'La carte graphique' } else { 'Le processeur' }
                Write-UiLog ("🔥 {0} chauffe : {1:N0} °C (ton seuil d'alerte : {2} °C)." -f $name, $script:Live["$part.temp"], (Get-TempLimit $part))
            }
        } elseif (-not $hot -and $script:Live["$part.temp"] -lt (Get-TempLimit $part) - 3) { $script:OverheatState[$key] = $false }
    }
}

# ---------------------------------------------------------------- Overlay
function Get-OverlayRows {
    $m = @($script:Settings.Overlay.Metrics); $v = $script:Live
    $rows = New-Object System.Collections.ArrayList
    if ($m -contains 'fps') { [void]$rows.Add(@('FPS', (Format-Val $v['fps'] '{0:N0}' ''), '#4ADE80', $true)) }
    if ($m -contains 'low') { [void]$rows.Add(@('1% LOW', (Format-Val $v['low'] '{0:N0}' ''), '#C3CAD9', $false)) }
    if ($m -contains 'frametime') { [void]$rows.Add(@('FRAME', (Format-Val $v['frametime'] '{0:N1}' ' ms'), '#C3CAD9', $false)) }
    $cp = @(); if ($m -contains 'cpu') { $cp += Format-Val $v['cpu.load'] '{0:N0}' ' %' }; if ($m -contains 'cputemp') { $cp += Format-Val $v['cpu.temp'] '{0:N0}' ' °C' }; if ($m -contains 'cpupower') { $cp += Format-Val $v['cpu.power'] '{0:N0}' ' W' }
    if ($cp.Count) { $hot = Test-Overheat 'cpu'; [void]$rows.Add(@($(if ($hot) { '⚠ CPU' } else { 'CPU' }), ($cp -join '  '), $(if ($hot) { if ($script:Blink) { '#FF3B3B' } else { '#FFD0D0' } } else { Get-TempColor $(if ($m -contains 'cputemp') { $v['cpu.temp'] }) 'cpu' }), $false)) }
    $gp = @(); if ($m -contains 'gpu') { $gp += Format-Val $v['gpu.load'] '{0:N0}' ' %' }; if ($m -contains 'gputemp') { $gp += Format-Val $v['gpu.temp'] '{0:N0}' ' °C' }; if ($m -contains 'gpupower') { $gp += Format-Val $v['gpu.power'] '{0:N0}' ' W' }
    if ($gp.Count) { $hot = Test-Overheat 'gpu'; [void]$rows.Add(@($(if ($hot) { '⚠ GPU' } else { 'GPU' }), ($gp -join '  '), $(if ($hot) { if ($script:Blink) { '#FF3B3B' } else { '#FFD0D0' } } else { Get-TempColor $(if ($m -contains 'gputemp') { $v['gpu.temp'] }) 'gpu' }), $false)) }
    if ($m -contains 'vram') { $t = if ($null -ne $v['gpu.vram']) { "{0} / {1}" -f (Format-Val ($v['gpu.vram'] / 1024) '{0:N1}' ''), (Format-Val $(if ($v['gpu.vramtotal']) { $v['gpu.vramtotal'] / 1024 }) '{0:N0}' ' Go') } else { '—' }; [void]$rows.Add(@('VRAM', $t, '#FFFFFF', $false)) }
    if ($m -contains 'ram') { $t = if ($null -ne $v['ram.used']) { "{0}  {1}" -f (Format-Val ($v['ram.used'] / 1GB) '{0:N1}' ' Go'), (Format-Val $v['ram.load'] '{0:N0}' ' %') } else { '—' }; [void]$rows.Add(@('RAM', $t, '#FFFFFF', $false)) }
    if ($m -contains 'clock') { [void]$rows.Add(@('HEURE', (Get-Date -Format 'HH:mm'), '#FFFFFF', $false)) }
    return $rows
}

# Fond de l'overlay : de 0 % (invisible) à 100 % (opaque), en douceur
function New-OverlayBrush([double]$Opacity) {
    $a = [byte]([math]::Round(255 * [math]::Max([double]0, [math]::Min([double]1, $Opacity))))
    $b = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromArgb($a, 10, 12, 17)); $b.Freeze()
    return $b
}
# Réglages enregistrés une fois le curseur relâché (pas à chaque cran : ça saccadait le curseur et l'aperçu)
function Save-SettingsSoon {
    if (-not $script:SaveSoon) {
        $script:SaveSoon = New-Object System.Windows.Threading.DispatcherTimer; $script:SaveSoon.Interval = [TimeSpan]::FromMilliseconds(700)
        $script:SaveSoon.Add_Tick({ $script:SaveSoon.Stop(); Save-Settings })
    }
    $script:SaveSoon.Stop(); $script:SaveSoon.Start()
}
function Build-OverlayContent {
    if (-not $script:Ov) { return }
    $o = $script:Settings.Overlay
    $border = New-Object System.Windows.Controls.Border
    $border.Background = New-OverlayBrush ([double]$o.Opacity)
    # Taille : le texte est dessiné directement à la bonne taille (pixels entiers), pas agrandi après coup (c'était flou à certaines tailles)
    $k = [math]::Max([double]0.7, [math]::Min([double]3, [double]$o.Scale))
    $px = { param($v) [math]::Max([double]1, [math]::Round($v * $k)) }
    $border.CornerRadius = Corner (& $px 8); $border.Padding = Th (& $px 10) (& $px 7) (& $px 12) (& $px 7)
    if ($script:OvEdit) { $border.BorderBrush = Brush '#7C5CFF'; $border.BorderThickness = Th 2 2 2 2 }
    $border.UseLayoutRounding = $true; $border.SnapsToDevicePixels = $true
    [System.Windows.Media.TextOptions]::SetTextFormattingMode($border, $(if ($k -le 1.3) { 'Display' } else { 'Ideal' }))
    [System.Windows.Media.TextOptions]::SetTextHintingMode($border, 'Fixed')
    $script:OvBorder = $border
    $sp = New-Object System.Windows.Controls.StackPanel
    $grid = New-Object System.Windows.Controls.Grid
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::Auto
    $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = [System.Windows.GridLength]::Auto
    $grid.ColumnDefinitions.Add($c1); $grid.ColumnDefinitions.Add($c2)
    $script:OvRows = New-Object System.Collections.ArrayList
    $rows = Get-OverlayRows
    if (-not $rows.Count) { $rows = @(, @('AEROX', 'aucune info cochée', '#8B93A7', $false)) }
    $i = 0
    foreach ($r in $rows) {
        $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
        $l = New-Object System.Windows.Controls.TextBlock; $l.Text = $r[0]; $l.FontSize = (& $px 11); $l.FontWeight = 'Bold'; $l.Foreground = Brush '#9AA3B8'; $l.VerticalAlignment = 'Center'; $l.Margin = Th 0 (& $px 1) (& $px 12) (& $px 1)
        $l.FontFamily = 'Segoe UI'
        $val = New-Object System.Windows.Controls.TextBlock; $val.Text = $r[1]; $val.FontSize = $(if ($r[3]) { & $px 20 } else { & $px 14 }); $val.FontWeight = 'Bold'; $val.Foreground = Brush $r[2]; $val.VerticalAlignment = 'Center'
        $val.FontFamily = 'Segoe UI'
        $sh = New-Object System.Windows.Media.Effects.DropShadowEffect; $sh.BlurRadius = $(if ($k -lt 1) { 1 } else { & $px 3 }); $sh.ShadowDepth = [math]::Max([double]1, [math]::Round($k)); $sh.Opacity = 0.9; $sh.Color = [System.Windows.Media.Colors]::Black
        $val.Effect = $sh
        [System.Windows.Controls.Grid]::SetRow($l, $i); [System.Windows.Controls.Grid]::SetRow($val, $i); [System.Windows.Controls.Grid]::SetColumn($val, 1)
        Add-Child $grid $l; Add-Child $grid $val
        [void]$script:OvRows.Add(@{ Val = $val; Lbl = $l })
        $i++
    }
    Add-Child $sp $grid
    if ($script:OvEdit) { $h = New-Text "Glisse pour déplacer · molette : taille" (& $px 10) '#B9A8FF'; $h.Margin = Th 0 (& $px 4) 0 0; Add-Child $sp $h }
    $border.Child = $sp
    $script:Ov.Content = $border
}

function Update-OverlayValues {
    if (-not $script:Ov -or -not $script:Ov.IsVisible) { return }
    $rows = Get-OverlayRows
    if ($rows.Count -ne $script:OvRows.Count) { Build-OverlayContent; return }
    for ($i = 0; $i -lt $rows.Count; $i++) {
        $o = $script:OvRows[$i]; $o.Val.Text = $rows[$i][1]; $o.Val.Foreground = Brush $rows[$i][2]
        $o.Lbl.Text = $rows[$i][0]; $o.Lbl.Foreground = Brush $(if ($rows[$i][0] -like '⚠*') { '#FF6B6B' } else { '#9AA3B8' })
    }
}

function New-OverlayWindow {
    $w = New-Object System.Windows.Window
    $w.WindowStyle = 'None'; $w.AllowsTransparency = $true; $w.Background = [System.Windows.Media.Brushes]::Transparent
    $w.Topmost = $true; $w.ShowInTaskbar = $false; $w.SizeToContent = 'WidthAndHeight'; $w.ResizeMode = 'NoResize'; $w.ShowActivated = $false
    $w.WindowStartupLocation = 'Manual'; $w.Left = [double]$script:Settings.Overlay.X; $w.Top = [double]$script:Settings.Overlay.Y
    $w.Title = 'AEROX Overlay'
    $w.Add_SourceInitialized({ $h = (New-Object System.Windows.Interop.WindowInteropHelper($script:Ov)).Handle; [AeroxNative]::SetClickThrough($h, -not $script:OvEdit) })
    $w.Add_MouseLeftButtonDown({ if ($script:OvEdit) { try { $script:Ov.DragMove() } catch {}; $script:Settings.Overlay.X = [math]::Round($script:Ov.Left); $script:Settings.Overlay.Y = [math]::Round($script:Ov.Top); Save-Settings } })
    $w.Add_MouseWheel({ param($s, $e) if ($script:OvEdit) { $n = [double]$script:Settings.Overlay.Scale + $(if ($e.Delta -gt 0) { 0.1 } else { -0.1 }); $script:Settings.Overlay.Scale = [math]::Round([math]::Max([double]0.7, [math]::Min([double]3, $n)), 1); Save-SettingsSoon; Build-OverlayContent; if ($script:Cur -eq 'monitor' -and $script:MonUi -and $script:MonUi.Scale) { $script:MonUi.Scale.Value = $script:Settings.Overlay.Scale * 100 } } })
    $script:Ov = $w
    Build-OverlayContent
}

function Show-Overlay([bool]$Show) {
    if ($Show) {
        if (-not $script:Ov) { New-OverlayWindow }
        Start-Sensors; Start-FpsCounter
        $script:Ov.Show()
        $h = (New-Object System.Windows.Interop.WindowInteropHelper($script:Ov)).Handle
        if ($h -ne [IntPtr]::Zero) { [AeroxNative]::SetClickThrough($h, -not $script:OvEdit) }
    } elseif ($script:Ov) {
        $script:OvEdit = $false
        $script:Ov.Hide()
    }
    $script:Settings.Overlay.Visible = $Show
    Save-Settings
}
function Set-OverlayEdit([bool]$Edit) {
    $script:OvEdit = $Edit
    if (-not $script:Ov -or -not $script:Ov.IsVisible) { Show-Overlay $true }
    $h = (New-Object System.Windows.Interop.WindowInteropHelper($script:Ov)).Handle
    if ($h -ne [IntPtr]::Zero) { [AeroxNative]::SetClickThrough($h, -not $Edit) }
    Build-OverlayContent
}
function Set-OverlayCorner([string]$Corner) {
    if (-not $script:Ov -or -not $script:Ov.IsVisible) { Show-Overlay $true }
    $script:Ov.UpdateLayout()
    $wa = [System.Windows.SystemParameters]::WorkArea; $m = 16
    $wd = $script:Ov.ActualWidth; $ht = $script:Ov.ActualHeight
    $script:Ov.Left = if ($Corner -match 'R') { $wa.Right - $wd - $m } else { $wa.Left + $m }
    $script:Ov.Top = if ($Corner -match 'B') { $wa.Bottom - $ht - $m } else { $wa.Top + $m }
    $script:Settings.Overlay.X = [math]::Round($script:Ov.Left); $script:Settings.Overlay.Y = [math]::Round($script:Ov.Top); Save-Settings
}

# ---------------------------------------------------------------- Page Moniteur
function New-MonTile([string]$Label) {
    $b = New-Object System.Windows.Controls.Border; $b.Background = Brush '#171A23'; $b.CornerRadius = Corner 12; $b.Padding = Th 16 14 16 14; $b.Margin = Th 0 0 10 10
    $sp = New-Object System.Windows.Controls.StackPanel
    Add-Child $sp (New-Text $Label 11 '#7A8399' 'Bold')
    $name = New-Text '' 12 '#8B93A7'; $name.TextTrimming = 'CharacterEllipsis'; $name.TextWrapping = 'NoWrap'; $name.Margin = Th 0 2 0 0; Add-Child $sp $name
    $big = New-Text '—' 26 '#FFFFFF' 'Bold'; $big.Margin = Th 0 6 0 0; Add-Child $sp $big
    $l1 = New-Text '' 13 '#C3CAD9'; $l1.Margin = Th 0 2 0 0; Add-Child $sp $l1
    $l2 = New-Text '' 12 '#8B93A7'; Add-Child $sp $l2
    $b.Child = $sp
    return @{ Box = $b; Name = $name; Big = $big; L1 = $l1; L2 = $l2 }
}
function Update-MonitorUi {
    $u = $script:MonUi; if (-not $u) { return }
    if ($u.Sess -and $script:GameSess) {
        $r = $null; if ($script:Fps -and $script:Fps.Running) { $r = $script:Fps.Get([int]$script:GameSess.Pid) }
        $u.Sess.Text = (Format-GameTime ((Get-Date) - $script:GameSess.Start).TotalMinutes) + $(if ($r) { "  ·  {0:N0} FPS en ce moment" -f $r[0] } else { '' })
    }
    if (-not $u.Live) { return }
    $v = $script:Live
    $u.Cpu.Name.Text = [string]$v['cpu.name']
    $u.Cpu.Big.Text = Format-Val $v['cpu.temp'] '{0:N0}' ' °C'; $u.Cpu.Big.Foreground = Brush (Get-TempColor $v['cpu.temp'] 'cpu')
    $u.Cpu.L1.Text = "Utilisation " + (Format-Val $v['cpu.load'] '{0:N0}' ' %')
    $u.Cpu.L2.Text = @((Format-Val $v['cpu.power'] '{0:N0}' ' W'), (Format-Val $(if ($v['cpu.clock']) { $v['cpu.clock'] / 1000 }) '{0:N2}' ' GHz')) -join '  ·  '
    if ($null -eq $v['cpu.temp']) { $u.Cpu.Big.Text = '—'; $u.Cpu.L2.Text = $(if ($sync.SensMode -ne 'lhm') { 'Installe le module de températures ↓' } elseif (-not $script:ToolSt.PawnIO) { 'Installe le pilote PawnIO pour la température ↓' } else { $u.Cpu.L2.Text }) }
    $u.Gpu.Name.Text = [string]$v['gpu.name']
    $u.Gpu.Big.Text = Format-Val $v['gpu.temp'] '{0:N0}' ' °C'; $u.Gpu.Big.Foreground = Brush (Get-TempColor $v['gpu.temp'] 'gpu')
    $u.Gpu.L1.Text = "Utilisation " + (Format-Val $v['gpu.load'] '{0:N0}' ' %') + $(if ($v['gpu.hot']) { "  ·  point chaud " + (Format-Val $v['gpu.hot'] '{0:N0}' ' °C') } else { '' })
    $u.Gpu.L2.Text = @(("VRAM " + $(if ($null -ne $v['gpu.vram']) { (Format-Val ($v['gpu.vram'] / 1024) '{0:N1}' '') + ' / ' + (Format-Val $(if ($v['gpu.vramtotal']) { $v['gpu.vramtotal'] / 1024 }) '{0:N0}' ' Go') } else { '—' })), (Format-Val $v['gpu.power'] '{0:N0}' ' W')) -join '  ·  '
    $u.Ram.Name.Text = $(if ($v['ram.total']) { "{0} au total" -f (Format-Size $v['ram.total']) } else { '' })
    $u.Ram.Big.Text = Format-Val $v['ram.load'] '{0:N0}' ' %'
    $u.Ram.L1.Text = $(if ($null -ne $v['ram.used']) { "{0} utilisés" -f (Format-Size $v['ram.used']) } else { '' })
    $u.Fps.Name.Text = $(if ($v['game']) { [string]$v['game'] } elseif (-not $script:ToolSt.PresentMon) { 'Compteur non installé' } else { 'Lance un jeu (fenêtré sans bordure)' })
    $u.Fps.Big.Text = Format-Val $v['fps'] '{0:N0}' ''
    $u.Fps.L1.Text = "1 % low " + (Format-Val $v['low'] '{0:N0}' '')
    $u.Fps.L2.Text = "Temps d'image " + (Format-Val $v['frametime'] '{0:N1}' ' ms')
}

function Start-ToolUninstall([string]$Action, [string]$What, [string]$Effect) {
    if ($script:GameSess) { [System.Windows.MessageBox]::Show("Une partie est en cours de suivi : attends de l'avoir quittée pour désinstaller $What.", $AppName, 'OK', 'Information') | Out-Null; return }
    if (-not (Confirm-Box ("Désinstaller $What ?`n`n$Effect`n`nTu pourras le réinstaller quand tu veux, ici même."))) { return }
    # Mesures arrêtées d'abord : sinon ses fichiers sont utilisés et ne peuvent pas être retirés (relancées après, sans lui)
    try { Stop-Monitoring } catch {}
    $lbl = "Désinstallation : $What"
    [void](Start-AeroxTask $Action ($lbl.Substring(0, 1).ToUpper() + $lbl.Substring(1)) 'tools')
}
function New-ToolRow([string]$Title, [string]$Desc, [bool]$Ok, [string]$OkText, [string]$Ui, [string]$UninstUi = '') {
    $row = New-Object System.Windows.Controls.DockPanel; $row.Margin = Th 0 6 0 6
    if ($Ok) {
        # Installé : tu peux le retirer quand tu veux (rien n'est obligatoire)
        if ($UninstUi) { $ub = New-Button 'Désinstaller' 'TextBtn' @{ Kind = 'ui'; Def = @{ UI = $UninstUi } } $false; $ub.Margin = Th 8 0 0 0; $ub.VerticalAlignment = 'Center'; [System.Windows.Controls.DockPanel]::SetDock($ub, 'Right'); Add-Child $row $ub }
        $p = New-Pill $OkText '#4ADE80' '#173326'; $p.VerticalAlignment = 'Center'; [System.Windows.Controls.DockPanel]::SetDock($p, 'Right'); Add-Child $row $p
    }
    else { $b = New-Button 'Installer' 'ActionBtn' @{ Kind = 'ui'; Def = @{ UI = $Ui } }; $b.Margin = Th 12 0 0 0; [System.Windows.Controls.DockPanel]::SetDock($b, 'Right'); Add-Child $row $b }
    $t = New-Object System.Windows.Controls.StackPanel
    Add-Child $t (New-Text $Title 14 '#FFFFFF' 'SemiBold')
    Add-Child $t (New-Text $Desc 12 '#8B93A7')
    Add-Child $row $t
    return $row
}

$script:GameTab = 'jeux'
function New-TabBar($Items, [string]$Cur, [string]$Ui) {
    $b = New-Object System.Windows.Controls.Border; $b.Background = Brush '#141720'; $b.CornerRadius = Corner 10; $b.Padding = Th 4 4 4 4; $b.HorizontalAlignment = 'Left'; $b.Margin = Th 0 0 0 16
    $wp = New-Object System.Windows.Controls.StackPanel; $wp.Orientation = 'Horizontal'
    foreach ($it in $Items) {
        $on = ($it[0] -eq $Cur)
        $bt = New-Button $it[1] $(if ($on) { 'PrimaryBtn' } else { 'TextBtn' }) @{ Kind = 'ui'; Def = @{ UI = $Ui; Tab = $it[0] } } $false
        $bt.Padding = Th 18 8 18 8; $bt.Margin = Th 0 0 4 0; Add-Child $wp $bt
    }
    $b.Child = $wp
    return $b
}
function Build-MonitorPage {
    Start-Sensors; Start-FpsCounter
    # Gardé une minute (lire le registre et les fichiers à chaque rafraîchissement faisait de petits à-coups) ;
    # remis à zéro après une installation / désinstallation d'outil
    if (-not $script:ToolSt -or -not $script:ToolStAt -or ((Get-Date) - $script:ToolStAt).TotalSeconds -gt 60) { $script:ToolSt = Get-ToolStatus; $script:ToolStAt = Get-Date }
    $sp = New-Object System.Windows.Controls.StackPanel
    Build-Header $sp "Gaming" "AEROX reconnaît tes jeux tout seul et note chaque partie : FPS, saccades, températures, et ce qui limite le jeu. Plus les mesures en direct et l'overlay par-dessus tes jeux."
    if ($script:GameTab -notin 'jeux', 'live', 'overlay') { $script:GameTab = 'jeux' }
    Add-Child $sp (New-TabBar @(@('jeux', 'Mes jeux'), @('live', 'En direct'), @('overlay', 'Overlay en jeu')) $script:GameTab 'game-tab')
    $u = @{ Cpu = (New-MonTile 'PROCESSEUR'); Gpu = (New-MonTile 'CARTE GRAPHIQUE'); Ram = (New-MonTile 'MÉMOIRE'); Fps = (New-MonTile 'FPS'); Live = ($script:GameTab -eq 'live') }
    if ($script:GameTab -eq 'jeux') {
        try { Add-GamingSections $sp $u } catch { Write-Bug -Context 'Gaming : mes jeux' -ErrorRecord $_ }
        $script:MonUi = $u
        return $sp
    }
    if ($script:GameTab -eq 'overlay') { Add-OverlaySection $sp $u; $script:MonUi = $u; return $sp }
    if ($script:GameSess) { $c = New-CardBorder '#3B2F7A'; $u.Sess = New-Text '' 13 '#B9A8FF'; $cs = New-Object System.Windows.Controls.StackPanel; Add-Child $cs (New-Text ("🎮 Partie en cours : " + $script:GameSess.Name) 15 '#FFFFFF' 'SemiBold'); Add-Child $cs $u.Sess; $c.Child = $cs; Add-Child $sp $c }
    $ug = New-Object System.Windows.Controls.Primitives.UniformGrid; $ug.Columns = 4
    foreach ($k in 'Cpu', 'Gpu', 'Ram', 'Fps') { Add-Child $ug $u[$k].Box }
    Add-Child $sp $ug
    if ($sync.SensError) { $e = New-Text ("Capteurs : " + $sync.SensError) 12 '#FFB547'; $e.Margin = Th 0 0 0 8; Add-Child $sp $e }

    # Composants
    Add-Child $sp (New-Section 'Composants de mesure')
    $c = New-CardBorder; $cs = New-Object System.Windows.Controls.StackPanel
    $st = $script:ToolSt
    Add-Child $cs (New-ToolRow "Températures et capteurs (LibreHardwareMonitor)" "Températures CPU / GPU, consommation, fréquences. Logiciel libre reconnu, téléchargé depuis nuget.org (~2 Mo)." $st.Lhm 'Installé' 'inst-lhm' 'uninst-lhm')
    Add-Child $cs (New-ToolRow "Température du processeur (pilote PawnIO)" "Pilote signé qui permet de lire la température du processeur en toute sécurité (remplace l'ancien WinRing0 bloqué par Windows)." $st.PawnIO 'Installé' 'inst-pawn' 'uninst-pawn')
    Add-Child $cs (New-ToolRow "Compteur de FPS (PresentMon d'Intel)" "Outil officiel d'Intel, installé avec winget (Microsoft). Rien n'est injecté dans les jeux : aucun risque avec les anti-triche." $st.PresentMon 'Installé' 'inst-pm' 'uninst-pm')
    $n = New-Text $(if ($st.Nvsmi -and -not $st.Lhm) { "Sans le module, la carte NVIDIA est quand même lue (température, utilisation) via son pilote." } else { "Téléchargés depuis les sources officielles, uniquement quand tu cliques sur « Installer ». Tu peux les désinstaller quand tu veux." }) 12 '#7A8399'
    $n.Margin = Th 0 6 0 0; Add-Child $cs $n
    $c.Child = $cs; Add-Child $sp $c
    $script:MonUi = $u
    Update-LiveData; Update-MonitorUi
    return $sp
}
function Add-OverlaySection($sp, $u) {
    $c = New-CardBorder; $os = New-Object System.Windows.Controls.StackPanel
    $top = New-Object System.Windows.Controls.WrapPanel
    $visible = [bool]($script:Ov -and $script:Ov.IsVisible)
    $b1 = New-Button $(if ($visible) { "Masquer l'overlay" } else { "Afficher l'overlay" }) $(if ($visible) { 'ActionBtn' } else { 'PrimaryBtn' }) @{ Kind = 'ui'; Def = @{ UI = 'ov-toggle' } } $false
    $b1.Margin = Th 0 0 8 8; Add-Child $top $b1
    $b2 = New-Button $(if ($script:OvEdit) { "Terminer le placement" } else { "Déplacer / redimensionner" }) $(if ($script:OvEdit) { 'FixBtn' } else { 'ActionBtn' }) @{ Kind = 'ui'; Def = @{ UI = 'ov-edit' } } $false
    $b2.Margin = Th 0 0 16 8; Add-Child $top $b2
    foreach ($pc in @(@('Haut gauche', 'TL'), @('Haut droite', 'TR'), @('Bas gauche', 'BL'), @('Bas droite', 'BR'))) {
        $b = New-Button $pc[0] 'GhostBtn' @{ Kind = 'ui'; Def = @{ UI = 'ov-corner'; Corner = $pc[1] } } $false; $b.Margin = Th 0 0 6 8; Add-Child $top $b
    }
    Add-Child $os $top
    $h = New-Text "Infos affichées" 12 '#C3CAD9' 'SemiBold'; $h.Margin = Th 0 6 0 6; Add-Child $os $h
    $wp = New-Object System.Windows.Controls.WrapPanel
    foreach ($k in $script:OverlayMetrics.Keys) {
        $cb = New-Object System.Windows.Controls.CheckBox; $cb.Margin = Th 0 0 18 8; $cb.Cursor = 'Hand'; $cb.Tag = $k
        $cb.Content = (New-Text $script:OverlayMetrics[$k] 13 '#E6E9F2'); $cb.IsChecked = (@($script:Settings.Overlay.Metrics) -contains $k)
        $cb.Add_Click({ $k = $this.Tag; $m = @($script:Settings.Overlay.Metrics | Where-Object { $_ -ne $k }); if ($this.IsChecked) { $m += $k }; $order = @($script:OverlayMetrics.Keys); $script:Settings.Overlay.Metrics = @($order | Where-Object { $m -contains $_ }); Save-Settings; Build-OverlayContent })
        Add-Child $wp $cb
    }
    Add-Child $os $wp
    $sl = New-Object System.Windows.Controls.Grid; $sl.Margin = Th 0 6 0 0
    foreach ($w in 0, 1, 2, 3) { $cd = New-Object System.Windows.Controls.ColumnDefinition; $cd.Width = $(if ($w % 2 -eq 0) { [System.Windows.GridLength]::Auto } else { New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) }); $sl.ColumnDefinitions.Add($cd) }
    $l1 = New-Text ("Taille  {0} %" -f [math]::Round([double]$script:Settings.Overlay.Scale * 100)) 13 '#C3CAD9'; $l1.VerticalAlignment = 'Center'; $l1.Margin = Th 0 0 10 0; $l1.MinWidth = 92; Add-Child $sl $l1; $u.ScaleTxt = $l1
    $s1 = New-Object System.Windows.Controls.Slider; $s1.Minimum = 70; $s1.Maximum = 300; $s1.Value = [double]$script:Settings.Overlay.Scale * 100; $s1.Margin = Th 0 0 24 0; $s1.VerticalAlignment = 'Center'
    $s1.Add_ValueChanged({ $script:Settings.Overlay.Scale = [math]::Round($this.Value / 100, 2); if ($script:MonUi.ScaleTxt) { $script:MonUi.ScaleTxt.Text = "Taille  {0} %" -f [math]::Round($this.Value) }; Save-SettingsSoon; Build-OverlayContent })
    [System.Windows.Controls.Grid]::SetColumn($s1, 1); Add-Child $sl $s1
    $l2 = New-Text ("Fond  {0} %" -f [math]::Round([double]$script:Settings.Overlay.Opacity * 100)) 13 '#C3CAD9'; $l2.VerticalAlignment = 'Center'; $l2.Margin = Th 0 0 10 0; $l2.MinWidth = 82; $u.OpTxt = $l2; [System.Windows.Controls.Grid]::SetColumn($l2, 2); Add-Child $sl $l2
    $s2 = New-Object System.Windows.Controls.Slider; $s2.Minimum = 0; $s2.Maximum = 100; $s2.Value = [double]$script:Settings.Overlay.Opacity * 100; $s2.VerticalAlignment = 'Center'
    $s2.Add_ValueChanged({
        $script:Settings.Overlay.Opacity = [math]::Round($this.Value / 100, 2)
        if ($script:MonUi.OpTxt) { $script:MonUi.OpTxt.Text = "Fond  {0} %" -f [math]::Round($this.Value) }
        # Seul le fond change : appliqué tout de suite, sans reconstruire l'overlay
        if ($script:OvBorder) { $script:OvBorder.Background = New-OverlayBrush ([double]$script:Settings.Overlay.Opacity) }
        Save-SettingsSoon
    })
    [System.Windows.Controls.Grid]::SetColumn($s2, 3); Add-Child $sl $s2
    Add-Child $os $sl
    # Alerte surchauffe
    $ah = New-Object System.Windows.Controls.DockPanel; $ah.Margin = Th 0 14 0 4
    $ab = New-Button $(if ($script:Settings.Overlay.AlertOn) { 'Activée' } else { 'Désactivée' }) $(if ($script:Settings.Overlay.AlertOn) { 'FixBtn' } else { 'ActionBtn' }) @{ Kind = 'ui'; Def = @{ UI = 'ov-alert' } } $false
    [System.Windows.Controls.DockPanel]::SetDock($ab, 'Right'); Add-Child $ah $ab
    $at = New-Object System.Windows.Controls.StackPanel
    Add-Child $at (New-Text "Alerte surchauffe" 12 '#C3CAD9' 'SemiBold')
    Add-Child $at (New-Text "Au-dessus du seuil, la ligne clignote en rouge dans l'overlay (et c'est noté dans le journal)." 12 '#7A8399')
    Add-Child $ah $at; Add-Child $os $ah
    $ag = New-Object System.Windows.Controls.WrapPanel; $ag.Margin = Th 0 4 0 0
    foreach ($pt in @(@('CPU', 'AlertCpu', @(70, 75, 80, 85, 90, 95, 100)), @('GPU', 'AlertGpu', @(65, 70, 75, 80, 85, 90, 95)))) {
        $lb = New-Text ("Seuil " + $pt[0]) 13 '#C3CAD9'; $lb.VerticalAlignment = 'Center'; $lb.Margin = Th 0 0 8 0; Add-Child $ag $lb
        $cbx = New-Object System.Windows.Controls.ComboBox; $cbx.Width = 90; $cbx.Margin = Th 0 0 24 0; $cbx.Tag = $pt[1]
        foreach ($val in $pt[2]) { [void]$cbx.Items.Add("$val °C") }
        $cbx.SelectedItem = ("{0} °C" -f [int]$script:Settings.Overlay[$pt[1]])
        if ($null -eq $cbx.SelectedItem) { [void]$cbx.Items.Add(("{0} °C" -f [int]$script:Settings.Overlay[$pt[1]])); $cbx.SelectedIndex = $cbx.Items.Count - 1 }
        $cbx.Add_SelectionChanged({ $n = [int](("$($this.SelectedItem)") -replace '[^\d]', ''); if ($n) { $script:Settings.Overlay[$this.Tag] = $n; Save-Settings } })
        Add-Child $ag $cbx
    }
    Add-Child $os $ag
    $an = New-Text "Repères : un processeur en jeu tourne souvent entre 60 et 85 °C (certains Ryzen 7000 et Intel récents montent à 95 °C par conception). Une carte graphique entre 60 et 80 °C." 11.5 '#7A8399'
    $an.Margin = Th 0 6 0 0; Add-Child $os $an
    $hk = if ($script:HotkeyText) { "Raccourci : $($script:HotkeyText) pour afficher / masquer l'overlay, même en jeu." } else { "Raccourci clavier indisponible (déjà pris par d'autres logiciels) : utilise le bouton ci-dessus." }
    $tip = New-Text ($hk + "`n" +
        "Marche avec les jeux en mode « fenêtré sans bordure » (le réglage par défaut de la plupart des jeux) : en plein écran exclusif, Windows le cache.`n" +
        "En mode placement, glisse l'overlay avec la souris et utilise la molette pour la taille. Sinon les clics passent au travers, il ne gêne pas.") 12 '#7A8399'
    $tip.Margin = Th 0 10 0 0; $tip.LineHeight = 19; Add-Child $os $tip
    $c.Child = $os; Add-Child $sp $c
    $u.Scale = $s1
}

# Appelé par la boucle de l'interface (toutes les 150 ms)
function Invoke-MonitorTick {
    $hot = [AeroxHotkey]::Presses
    if ($hot -ne $script:OvHotPrev) { $script:OvHotPrev = $hot; Show-Overlay (-not ($script:Ov -and $script:Ov.IsVisible)); if ($script:Cur -eq 'monitor' -and -not $script:InTray) { Refresh-Page } }
    $script:TickN++
    if ($script:TickN % 20 -eq 0) {
        try { Invoke-GameWatch } catch { Write-Bug -Context 'Gaming : détection du jeu' -ErrorRecord $_ }
        # Mode discret sans partie en cours : mémoire rendue à Windows à la mise en veille, après une partie, puis toutes les 15 minutes
        if ($script:InTray -and -not $script:GameSess -and -not $script:GameProbe -and -not $script:Job -and (($script:TrimDue -and (Get-Date) -ge $script:TrimDue) -or ($script:LastTrim -and ((Get-Date) - $script:LastTrim).TotalMinutes -ge 15))) {
            try { Optimize-TrayMemory } catch { Write-Bug -Context 'Mode discret : mémoire' -ErrorRecord $_ }
        }
    }
    if ($script:TickN % 6 -ne 0) { return }
    if (Test-MonitorNeeded) {
        $script:MonIdle = 0
        Update-LiveData
        Update-OverheatAlert
        if ($script:GameSess) { try { Add-GameSample } catch { Write-Bug -Context 'Gaming : mesure de la partie' -ErrorRecord $_ } }
        if ($script:Cur -eq 'monitor' -and -not $script:InTray) { Update-MonitorUi }
        Update-OverlayValues
    } else {
        $script:MonIdle++
        if ($script:MonIdle -eq 20 -and ($script:SensPS -or ($script:Fps -and $script:Fps.Running))) { Stop-Monitoring }
    }
}

# =====================================================================
#  GAMING : carnet de performances par jeu
#  Le jeu est détecté tout seul, chaque partie est mesurée en silence (PresentMon + capteurs,
#  rien n'est injecté dans le jeu), puis résumée et rangée dans la fiche du jeu.
# =====================================================================
$script:GameSess = $null; $script:GameProbe = $null; $script:GameSkip = @{}
$script:GameDir = Join-Path $LogDir 'jeux'
$script:GameMinMinutes = 3
$script:LastGame = $null
$script:PmCache = @{ Path = $null; At = [datetime]::MinValue }
$script:Tray = $null; $script:InTray = $false; $script:QuitNow = $false; $script:BalloonKey = ''; $script:DeferredStart = $false; $script:TrimDue = $null; $script:LastTrim = $null
$script:AutoTaskName = 'AEROX PC Care (mode discret)'
# Dossiers des boutiques de jeux : le nom du jeu est le dossier juste après
$script:GameRoots = @(
    @('\\steamapps\\common\\([^\\]+)\\', 'Steam'),
    @('\\Epic Games\\([^\\]+)\\', 'Epic Games'),
    @('\\Riot Games\\([^\\]+)\\', 'Riot'),
    @('\\(?:EA Games|Origin Games|Electronic Arts)\\([^\\]+)\\', 'EA'),
    @('\\Ubisoft Game Launcher\\games\\([^\\]+)\\', 'Ubisoft'),
    @('\\GOG Galaxy\\Games\\([^\\]+)\\', 'GOG'),
    @('\\GOG Games\\([^\\]+)\\', 'GOG'),
    @('\\XboxGames\\([^\\]+)\\', 'Xbox'),
    @('\\Rockstar Games\\([^\\]+)\\', 'Rockstar'),
    @('\\([^\\]+)\\_(?:retail|classic|classic_era|ptr|beta)_\\', 'Battle.net'),
    @('\\Roblox\\Versions\\[^\\]+\\RobloxPlayerBeta\.exe$', 'Roblox', 'Roblox'),
    @('\\Minecraft Launcher\\|\\\.minecraft\\', 'Minecraft', 'Minecraft (Java)')
)
$script:GameRootSkip = '(?i)^(Launcher|Riot Client|Epic Online Services|DirectXRedist|DirectX|Steamworks Shared|Social Club|Rockstar Games Launcher|EA Desktop|EA app|Battle\.net|Ubisoft Connect|GalaxyClient|Steam|Common Redist|_CommonRedist|Steam Controller Configs|SteamVR)$'
$script:GameExeSkip = '(?i)(launcher|crash|setup|unins|redist|dxsetup|easyanticheat|battleye|beservice|prereq|updater|helper|cefprocess|webhelper|overlay|bootstrap|install|anticheat|vanguard|dedicated|server)'
# Programmes souvent en plein écran qui ne sont pas des jeux (vidéo, navigateur, bureautique, diffusion…)
$script:NotGames = '(?i)^(chrome|msedge|firefox|opera|opera_gx|brave|vivaldi|iexplore|arc|vlc|mpc-hc|mpc-hc64|mpc-be|mpc-be64|potplayer|potplayer64|potplayermini|potplayermini64|wmplayer|video\.ui|microsoft\.media\.player|kodi|plex|plex media player|spotify|netflix|powerpnt|winword|excel|onenote|acrord32|acrobat|obs64|obs32|obs|discord|teams|ms-teams|zoom|slack|skype|mstsc|anydesk|teamviewer|parsecd|rustdesk|explorer|applicationframehost|searchhost|searchapp|startmenuexperiencehost|shellexperiencehost|lockapp|steam|steamwebhelper|epicgameslauncher|battle\.net|riotclientservices|riotclientux|eadesktop|upc|galaxyclient|nvidia app|nvcontainer|nvidia overlay|amdrsserv|radeonsoftware|photoshop|lightroom|premiere|afterfx|resolve|blender|unity|unrealeditor|code|devenv|powershell|pwsh|windowsterminal|cmd|conhost|taskmgr|aeroxpccare|presentmon.*)$'
$script:GameClassSkip = '^(Progman|WorkerW|Shell_TrayWnd|Shell_SecondaryTrayWnd|Windows\.UI\.Core\.CoreWindow|ApplicationFrameWindow|ConsoleWindowClass|CASCADIA_HOSTING_WINDOW_CLASS|XamlExplorerHostIslandWindow)$'

function Get-PresentMonCached {
    $age = ((Get-Date) - $script:PmCache.At).TotalSeconds
    if (($script:PmCache.Path -and $age -lt 600) -or (-not $script:PmCache.Path -and $age -lt 60)) { return $script:PmCache.Path }
    $script:PmCache = @{ Path = (Find-PresentMon); At = Get-Date }
    return $script:PmCache.Path
}
function Get-GameKey([string]$Name) {
    $k = ($Name.ToLowerInvariant() -replace '[^\p{L}\p{Nd}]+', '-').Trim('-')
    if ($k.Length -gt 60) { $k = $k.Substring(0, 60).Trim('-') }
    if (-not $k) { $k = 'jeu' }
    return $k
}
function Format-GameName([string]$Name) { return (($Name -replace '[_]+', ' ' -replace '[®™©]', '' -replace '\s+', ' ').Trim()) }
# Jeu installé par une boutique (Steam, Epic, Riot, Battle.net…) : @{ Name; Store } ou $null
function Get-GameFromPath([string]$Path) {
    if (-not $Path) { return $null }
    $exe = [IO.Path]::GetFileNameWithoutExtension($Path)
    if ($exe -match $script:GameExeSkip) { return $null }
    foreach ($r in $script:GameRoots) {
        $m = [regex]::Match($Path, $r[0], 'IgnoreCase')
        if ($m.Success) {
            if ($r.Count -ge 3) { return @{ Name = $r[2]; Store = $r[1] } }   # nom fixe (Roblox…)
            $n = $m.Groups[1].Value
            if ($n -match $script:GameRootSkip) { return $null }
            return @{ Name = (Format-GameName $n); Store = $r[1] }
        }
    }
    return $null
}
# Autre jeu : nom du produit inscrit dans le programme, sinon son dossier
function Get-GameNameGeneric([string]$Path) {
    if ([IO.Path]::GetFileNameWithoutExtension($Path) -match '(?i)^javaw?$') { return 'Minecraft (Java)' }
    try {
        $vi = [Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
        foreach ($n in @($vi.ProductName, $vi.FileDescription)) {
            $n = Format-GameName "$n"
            if ($n -and $n.Length -le 60 -and $n -notmatch '(?i)^(unreal|unity|game|launcher|bootstrap|application|win64|shipping|client|direct3d|opengl|vulkan)\b') { return $n }
        }
    } catch {}
    $d = Split-Path $Path -Parent
    while ($d -and (Split-Path $d -Leaf) -match '(?i)^(bin|bin64|binaries|win64|win32|x64|x86|retail|game|client|shipping|live|release)$') { $d = Split-Path $d -Parent }
    if ($d -and (Split-Path $d -Leaf) -notmatch '(?i)^(program files.*|games|jeux|[a-z]:\\?)$') { return (Format-GameName (Split-Path $d -Leaf)) }
    return (Format-GameName ([IO.Path]::GetFileNameWithoutExtension($Path)))
}

# Toutes les 3 secondes : un jeu au premier plan ? la partie en cours est-elle finie ?
function Invoke-GameWatch {
    $g = $script:Settings.Gaming
    if (-not $g.Track) { if ($script:GameSess) { Stop-GameSession }; $script:GameProbe = $null; return }
    if ($script:GameSess) {
        if (-not [AeroxGame]::Alive([int]$script:GameSess.Pid, [string]$script:GameSess.Path)) { Stop-GameSession }
        return
    }
    if ($script:GameProbe) {
        $p = $script:GameProbe
        if (-not [AeroxGame]::Alive([int]$p.Pid, [string]$p.Path)) { $script:GameProbe = $null; return }
        $r = $null; if ($script:Fps -and $script:Fps.Running) { $r = $script:Fps.Get([int]$p.Pid) }
        if ($r -and $r[0] -ge 20) { $p.Hits++; if ($p.Hits -ge 3) { $script:GameProbe = $null; Start-GameSession $p.Pid $p.Path $p.Name 'plein écran' } ; return }
        if (((Get-Date) - $p.Since).TotalSeconds -ge 20) { $script:GameSkip["$($p.Pid)|$($p.Path)"] = $true; $script:GameProbe = $null }
        return
    }
    $f = ("$([AeroxGame]::Foreground())").Split('|')
    if ($f.Count -lt 4) { return }
    $gpid = 0; [void][int]::TryParse($f[0], [ref]$gpid); $path = $f[1]
    if (-not $gpid -or $gpid -eq $PID -or -not $path) { return }
    $sk = "$gpid|$path"
    if ($script:GameSkip.ContainsKey($sk)) { return }
    if ($script:GameSkip.Count -gt 500) { $script:GameSkip.Clear() }
    if (@($g.Ignore) -contains $path.ToLowerInvariant()) { $script:GameSkip[$sk] = $true; return }
    $script:GameDevice = $(if ($f.Count -ge 5) { $f[4] } else { '' })
    $id = Get-GameFromPath $path
    if ($id) { Start-GameSession $gpid $path $id.Name $id.Store; return }
    # Autre programme en plein écran : on vérifie d'abord qu'il affiche des images comme un jeu
    if ($f[2] -ne '1' -or $f[3] -match $script:GameClassSkip) { return }
    $exe = [IO.Path]::GetFileNameWithoutExtension($path)
    if ($exe -match $script:NotGames -or $exe -match $script:GameExeSkip -or $path -like "$env:windir\*") { $script:GameSkip[$sk] = $true; return }
    if (-not (Get-PresentMonCached)) { return }
    Start-FpsCounter
    $script:GameProbe = @{ Pid = $gpid; Path = $path; Name = (Get-GameNameGeneric $path); Since = Get-Date; Hits = 0 }
}

function Start-GameSession([int]$GamePid, [string]$Path, [string]$Name, [string]$Store) {
    $script:GameSess = @{ Pid = $GamePid; Path = $Path; Name = $Name; Store = $Store; Key = (Get-GameKey $Name); Start = Get-Date
        N = 0; Fps = (New-Object 'System.Collections.Generic.List[double]'); CpuL = 0.0; GpuL = 0.0; Core = 0.0; NL = 0; NGpu = 0; NCore = 0
        CpuT = $null; GpuT = $null; GpuHot = $null; Vram = $null; Ram = $null }
    $sync.GameCtx = $null
    try { Start-Background ('Get-GameContext ' + (ConvertTo-PsLiteral "$script:GameDevice")) } catch {}
    Start-Sensors
    if (Get-PresentMonCached) { Start-FpsCounter; if ($script:Fps) { $script:Fps.BeginSession($GamePid) } }
    Write-UiLog ("🎮 Partie détectée : {0}. AEROX note les performances en silence (rien n'est injecté dans le jeu)." -f $Name)
    if ($script:Cur -eq 'monitor' -and -not $script:InTray) { Refresh-Page }
}

# Une mesure par seconde pendant la partie
function Add-GameSample {
    $s = $script:GameSess; if (-not $s) { return }
    $v = $script:Live
    foreach ($k in @(@('cpu.temp', 'CpuT'), @('gpu.temp', 'GpuT'), @('gpu.hot', 'GpuHot'), @('ram.load', 'Ram'))) {
        $x = $v[$k[0]]; if ($null -ne $x -and ($null -eq $s[$k[1]] -or [double]$x -gt $s[$k[1]])) { $s[$k[1]] = [double]$x }
    }
    if ($null -ne $v['gpu.vram'] -and $v['gpu.vramtotal']) { $x = 100.0 * $v['gpu.vram'] / $v['gpu.vramtotal']; if ($null -eq $s.Vram -or $x -gt $s.Vram) { $s.Vram = $x } }
    # Utilisation : seulement quand on joue vraiment (jeu au premier plan et qui affiche des images)
    $fpsOn = [bool]($script:Fps -and $script:Fps.Running)
    $r = $null; if ($fpsOn) { $r = $script:Fps.Get([int]$s.Pid) }
    if ([AeroxNative]::ForegroundPid() -ne $s.Pid -or ($fpsOn -and -not $r)) { return }
    if ($r -and $s.Fps.Count -lt 30000) { $s.Fps.Add([double]$r[0]) }
    if ($null -ne $v['cpu.load']) { $s.CpuL += [double]$v['cpu.load']; $s.NL++ }
    if ($null -ne $v['gpu.load']) { $s.GpuL += [double]$v['gpu.load']; $s.NGpu++ }
    if ($null -ne $v['cpu.coremax']) { $s.Core += [double]$v['cpu.coremax']; $s.NCore++ }
    $s.N++
}

function Stop-GameSession {
    $s = $script:GameSess; if (-not $s) { return }
    $script:GameSess = $null
    $st = $null; $mins = @()
    if ($script:Fps) { try { if ($script:Fps.SessionPid -eq $s.Pid) { $st = $script:Fps.SessionStats(); $mins = @($script:Fps.SessionMinutes()) }; $script:Fps.EndSession() } catch {} }
    $rec = New-GameRecord $s $st $mins (Get-Date) $sync.GameCtx
    if (-not $rec) { Write-UiLog ("🎮 Fin de {0} : partie de moins de {1} minutes, pas notée." -f $s.Name, $script:GameMinMinutes); return }
    Save-GameRecord $s.Key $s.Name $s.Path $s.Store $rec
    $txt = Format-GameSummary $s.Name $rec
    Write-UiLog $txt
    $script:LastGame = @{ Key = $s.Key; Text = $txt; At = Get-Date }
    if ($script:InTray) { $script:TrimDue = (Get-Date).AddSeconds(45) }   # après l'arrêt des mesures
    try { Show-TrayBalloon 'Fin de partie' $txt $s.Key } catch { Write-Bug -Context 'Notification de fin de partie' -ErrorRecord $_ -Type 'erreur' }
    if ($script:Cur -eq 'monitor' -and -not $script:InTray) { Refresh-Page }
}

function Get-Median($Values) { $a = @($Values | Sort-Object); if (-not $a.Count) { return $null }; return [double]$a[[int][math]::Floor($a.Count / 2)] }
# Résultat d'une partie, rangé dans la fiche du jeu
function New-GameRecord($S, $St, $Mins, [datetime]$End, $Ctx) {
    $min = ($End - $S.Start).TotalMinutes
    if ($min -lt $script:GameMinMinutes) { return $null }
    $r = [ordered]@{ Start = $S.Start.ToString('s'); Min = [math]::Round($min, 1); App = $AppVersion }
    if ($St -and $St[0] -ge 300) {
        $r.Fps = [math]::Round($St[2], 1); $r.Low1 = [math]::Round($St[3], 1); $r.Low01 = [math]::Round($St[4], 1); $r.Stut = [int]$St[5]; $r.Frames = [long]$St[0]
    }
    $c = @($Mins | ForEach-Object { [int][math]::Round([double]$_) })
    if ($c.Count -gt 240) { $step = $c.Count / 240.0; $c = @(for ($i = 0; $i -lt 240; $i++) { $c[[int][math]::Floor($i * $step)] }) }
    if ($c.Count -ge 2) { $r.Curve = $c }
    foreach ($k in 'CpuT', 'GpuT', 'GpuHot', 'Vram', 'Ram') { if ($null -ne $S[$k]) { $r[$k] = [int][math]::Round($S[$k]) } }
    if ($S.NL) { $r.CpuL = [int][math]::Round($S.CpuL / $S.NL) }
    if ($S.NGpu) { $r.GpuL = [int][math]::Round($S.GpuL / $S.NGpu) }
    if ($S.NCore) { $r.Core = [int][math]::Round($S.Core / $S.NCore) }
    $r.N = [int]$S.N
    if ($S.Fps -and $S.Fps.Count -ge 30) {
        $a = @($S.Fps); $mean = ($a | Measure-Object -Average).Average
        $var = 0.0; foreach ($x in $a) { $var += ($x - $mean) * ($x - $mean) }
        $r.Med = [math]::Round((Get-Median $a), 1)
        if ($mean -gt 0) { $r.Cv = [math]::Round([math]::Sqrt($var / $a.Count) / $mean, 3) }
    }
    if ($Ctx) { foreach ($k in 'Gpu', 'Driver', 'Hz', 'MaxHz', 'Device') { if ($Ctx[$k]) { $r[$k] = $Ctx[$k] } } }
    # Temps réellement joué (images affichées), pour les saccades par heure : un Alt+Tab ne doit pas les diluer
    if ($St -and $St[1] -gt 0) { $r.Act = [math]::Round([math]::Min($min, $St[1] / 60.0), 1) }
    $v = Get-GameVerdict $r
    $r.Verdict = $v.Id; if ($v.Cap) { $r.Cap = $v.Cap }
    $r.Flags = @(Get-GameFlags $r)
    return $r
}
function Get-RecValue($R, [string]$K) { if ($R -is [System.Collections.IDictionary]) { if ($R.Contains($K)) { return $R[$K] } else { return $null } }; return $R.$K }
# FPS très stables autour d'une limite courante (V-Sync, limite du jeu, G-Sync / Reflex juste sous la fréquence de l'écran)
function Test-FpsCap([double]$Med, [int]$Hz) {
    if ($Med -le 0) { return $false }
    $caps = @(30, 72, 75, 144, 165, 175) + @(for ($i = 5; $i -le 40; $i++) { $i * 10 })
    if ($Hz -gt 0) { $caps += @($Hz, ($Hz - 3), ($Hz - 4), [math]::Round(3600.0 * $Hz / (3600 + $Hz))) }
    foreach ($c in $caps) { if ([math]::Abs($Med - $c) -le [math]::Max([double]1.5, $c * 0.02)) { return $true } }
    return $false
}
# Ce qui limite le jeu pendant la partie
function Get-GameVerdict($R) {
    $gl = Get-RecValue $R 'GpuL'; $cv = Get-RecValue $R 'Cv'; $core = Get-RecValue $R 'Core'; $cl = Get-RecValue $R 'CpuL'
    $hasFps = $null -ne (Get-RecValue $R 'Fps')
    $onCap = $hasFps -and $null -ne $cv -and (Test-FpsCap ([double](Get-RecValue $R 'Med')) ([int](Get-RecValue $R 'Hz')))
    # FPS très stables sur une limite, ou carte graphique peu utilisée avec des FPS posés sur une limite courante
    if ($onCap -and ($null -eq $gl -or $gl -lt 85) -and ($cv -le 0.035 -or ($null -ne $gl -and $gl -lt 70 -and $cv -le 0.08))) { return @{ Id = 'cap'; Cap = [int][math]::Round([double](Get-RecValue $R 'Med')) } }
    if ($null -eq $gl) { return @{ Id = '' } }
    # Pas assez de mesures pendant qu'on jouait vraiment (jeu au premier plan) : pas de conclusion plutôt qu'une conclusion fausse
    $n = Get-RecValue $R 'N'; if ($null -ne $n -and [int]$n -lt 60) { return @{ Id = '' } }
    if ($gl -ge 85) { return @{ Id = 'gpu' } }
    # Processeur vraiment saturé ET carte graphique qui attend (sinon, on n'accuse pas le processeur)
    if (($null -ne $core -and $core -ge 90 -and $gl -lt 75) -or ($null -ne $cl -and $cl -ge 80 -and $gl -lt 85)) { return @{ Id = 'cpu' } }
    # Ni l'un ni l'autre à fond : c'est le jeu qui fixe le rythme (moteur sur 1-2 cœurs, limite d'images…)
    if ($gl -lt 70) { return @{ Id = 'engine' } }
    return @{ Id = 'mixed' }
}
function Get-GameFlags($R) {
    $f = @()
    $o = $script:Settings.Overlay
    if ($null -ne (Get-RecValue $R 'GpuT') -and (Get-RecValue $R 'GpuT') -ge [double]$o.AlertGpu) { $f += 'hot-gpu' }
    if ($null -ne (Get-RecValue $R 'CpuT') -and (Get-RecValue $R 'CpuT') -ge [double]$o.AlertCpu) { $f += 'hot-cpu' }
    if ($null -ne (Get-RecValue $R 'Vram') -and (Get-RecValue $R 'Vram') -ge 95) { $f += 'vram' }
    if ($null -ne (Get-RecValue $R 'Ram') -and (Get-RecValue $R 'Ram') -ge 90) { $f += 'ram' }
    $st = Get-RecValue $R 'Stut'; $mn = [double](Get-RecValue $R 'Min')
    $act = Get-RecValue $R 'Act'; if ($null -ne $act -and [double]$act -ge 1) { $mn = [double]$act }
    if ($null -ne $st -and $st -ge 5 -and $mn -gt 0 -and ($st * 60.0 / $mn) -ge 30) { $f += 'stutter' }
    $hz = [int](Get-RecValue $R 'Hz'); $mx = [int](Get-RecValue $R 'MaxHz')
    if ($hz -gt 0 -and $mx -ge 100 -and ($mx - $hz) -ge 20) { $f += 'hz' }
    return $f
}
function Format-GameTime([double]$Min) {
    if ($Min -lt 60) { return ("{0} min" -f [int][math]::Round($Min)) }
    $h = [int][math]::Floor($Min / 60); $m = [int][math]::Round($Min - $h * 60); if ($m -eq 60) { $h++; $m = 0 }
    return ("{0} h {1:00}" -f $h, $m)
}
function Get-VerdictLabel($R) {
    switch ("$(Get-RecValue $R 'Verdict')") {
        'gpu' { return 'limité par la carte graphique' }
        'cpu' { return 'limité par le processeur' }
        'engine' { return 'limité par le jeu lui-même' }
        'cap' { return ("plafonné à {0} FPS" -f (Get-RecValue $R 'Cap')) }
        'mixed' { return 'processeur et carte graphique équilibrés' }
    }
    return ''
}
# Résumé d'une ligne : « 🎮 Warzone · 1 h 12 · 118 FPS de moyenne · 1 % low 79 · 4 saccades · limité par la carte graphique · GPU 71 °C max »
function Format-GameSummary([string]$Name, $R) {
    $p = @("🎮 $Name", (Format-GameTime ([double](Get-RecValue $R 'Min'))))
    if ($null -ne (Get-RecValue $R 'Fps')) {
        $p += ("{0} FPS de moyenne" -f [int][math]::Round([double](Get-RecValue $R 'Fps')))
        $p += ("1 % low {0}" -f [int][math]::Round([double](Get-RecValue $R 'Low1')))
        $n = [int](Get-RecValue $R 'Stut'); $p += $(if ($n -eq 0) { 'aucune saccade' } elseif ($n -eq 1) { '1 saccade' } else { "$n saccades" })
    }
    $vl = Get-VerdictLabel $R; if ($vl) { $p += $vl }
    if ($null -ne (Get-RecValue $R 'GpuT')) { $p += ("GPU {0} °C max" -f (Get-RecValue $R 'GpuT')) } elseif ($null -ne (Get-RecValue $R 'CpuT')) { $p += ("CPU {0} °C max" -f (Get-RecValue $R 'CpuT')) }
    return ($p -join ' · ')
}

# ---------------------------------------------------------------- Fiches (un fichier par jeu dans « jeux »)
function Get-GameFile([string]$Key) { return (Join-Path $script:GameDir ($Key + '.json')) }
function Read-GameFile([string]$Key) {
    $f = Get-GameFile $Key
    if (-not (Test-Path -LiteralPath $f)) { return $null }
    try {
        $g = ConvertTo-Hash ([IO.File]::ReadAllText($f, [Text.Encoding]::UTF8) | ConvertFrom-Json)
        if ($g -isnot [hashtable]) { return $null }
        $g.Sessions = @($g.Sessions | Where-Object { $_ -is [hashtable] })
        # Verdict recalculé à chaque lecture : une analyse améliorée s'applique aussi aux anciennes parties
        foreach ($x in $g.Sessions) { try { $v = Get-GameVerdict $x; $x.Verdict = $v.Id; if ($v.Cap) { $x.Cap = $v.Cap } else { $x.Remove('Cap') } } catch {} }
        if (-not $g.Key) { $g.Key = $Key }
        return $g
    } catch { Write-Bug -Context "Fiche du jeu $Key" -ErrorRecord $_ -Type 'erreur'; return $null }
}
function Save-GameFile($G) {
    New-Item -ItemType Directory -Force -Path $script:GameDir | Out-Null
    $json = $G | ConvertTo-Json -Depth 6 -Compress
    $f = Get-GameFile $G.Key; $tmp = "$f.tmp"
    [IO.File]::WriteAllText($tmp, $json, (New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination $f -Force
}
function Save-GameRecord([string]$Key, [string]$Name, [string]$Path, [string]$Store, $Rec) {
    $g = Read-GameFile $Key
    if (-not $g) { $g = @{ Key = $Key; Name = $Name; Sessions = @() } }
    $g.Name = $Name; $g.Path = $Path; if ($Store) { $g.Store = $Store }
    $g.Sessions = @(@($g.Sessions) + @($Rec) | Select-Object -Last 200)
    Save-GameFile $g
}
function Get-GameList {
    $list = New-Object System.Collections.ArrayList
    foreach ($f in @(Get-ChildItem -LiteralPath $script:GameDir -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
        $g = Read-GameFile ([IO.Path]::GetFileNameWithoutExtension($f.Name))
        if (-not $g -or -not @($g.Sessions).Count) { continue }
        $last = @($g.Sessions)[-1]
        $g.Last = $last; $g.LastAt = ConvertTo-DateSafe $last.Start
        $g.TotalMin = (@($g.Sessions) | ForEach-Object { [double]$_.Min } | Measure-Object -Sum).Sum
        [void]$list.Add($g)
    }
    return @($list | Sort-Object { $_.LastAt } -Descending)
}

# ---------------------------------------------------------------- Conseils (boutons = fonctions qui existent déjà)
function Get-GameAdvice($R) {
    $out = New-Object System.Collections.ArrayList
    $gl = Get-RecValue $R 'GpuL'; $hz = [int](Get-RecValue $R 'Hz'); $mx = [int](Get-RecValue $R 'MaxHz')
    $fps = Get-RecValue $R 'Fps'; $vd = "$(Get-RecValue $R 'Verdict')"
    # Plus d'images que l'écran n'en affiche : rien à gagner côté PC
    if ($null -ne $fps -and $hz -gt 0 -and [double]$fps -ge $hz * 0.97 -and $vd -in 'cpu', 'engine', 'mixed') {
        [void]$out.Add(@{ C = '#4ADE80'; T = ("Déjà plus de FPS que ton écran n'en affiche"); D = ("{0} FPS en moyenne pour un écran à {1} Hz : l'écran ne montre que {1} images par seconde, le reste ne se voit pas. Rien à améliorer côté PC pour ce jeu." -f [int][math]::Round([double]$fps), $hz) })
    }
    switch ($vd) {
        'gpu' { [void]$out.Add(@{ C = '#4ADE80'; T = 'Limité par la carte graphique : c''est normal'; D = ("Ta carte graphique tourne à fond ({0} % en moyenne) : rien n'est gâché, c'est le cas idéal. Pour gagner des FPS : active DLSS, FSR ou XeSS en mode « Qualité », ou baisse les réglages les plus lourds (ombres, nuages, ray tracing). Un pilote graphique à jour aide aussi." -f $gl); B = 'Vérifier mon pilote graphique'; Ui = 'drivers' }) }
        'cpu' { [void]$out.Add(@{ C = '#FFB547'; T = 'Limité par le processeur'; D = ("La carte graphique attend le processeur : elle n'est utilisée qu'à {0} %. Ferme ce qui tourne en fond pendant que tu joues (navigateur, enregistrement, logiciels de LED…) et vérifie le mode performances. Bonne nouvelle : tu peux monter la qualité graphique, ça ne coûtera presque pas de FPS. Certains jeux (stratégie, MMO, simulation) sont limités par le processeur quoi qu'il arrive." -f $gl); B = 'Voir ce qui tourne en fond'; Ui = 'bgitems'; B2 = 'Optimisations'; Ui2 = 'page-perf' }) }
        'cap' {
            $cap = [int](Get-RecValue $R 'Cap')
            if ($hz -gt 0 -and $cap -ge $hz - 12 -and $cap -le $hz + 2) { [void]$out.Add(@{ C = '#4ADE80'; T = ("Calé sur ton écran ({0} FPS)" -f $cap); D = ("Le jeu suit la fréquence de ton écran ({0} Hz) : c'est parfait, l'image est fluide et sans déchirure. Plus de FPS ne servirait à rien sur cet écran." -f $hz) }) }
            elseif ($hz -gt 0 -and $cap -lt $hz - 12) { [void]$out.Add(@{ C = '#FFB547'; T = ("Bridé à {0} FPS" -f $cap); D = ("Le jeu reste bloqué à {0} FPS alors que ton écran monte à {1} Hz. Dans les options du jeu, cherche « Limite d'images / Max FPS » ou « V-Sync » et monte la limite à {1} pour profiter de ton écran." -f $cap, $hz) }) }
            else { [void]$out.Add(@{ C = '#8B93A7'; T = ("Plafonné à {0} FPS" -f $cap); D = "Le jeu est limité par V-Sync ou une limite d'images : les FPS ne bougent presque pas. Si c'est voulu (moins de bruit et de chaleur), c'est très bien." }) }
        }
        'engine' { [void]$out.Add(@{ C = '#8B93A7'; T = 'Limité par le jeu lui-même'; D = ("Ni ton processeur ni ta carte graphique (utilisée à {0} %) ne sont à fond : c'est le jeu qui fixe le rythme. Son moteur n'utilise souvent qu'un ou deux cœurs du processeur, ou il a une limite d'images dans ses options (« Max FPS », « Fréquence d'images maximale »). Très courant avec Roblox, Minecraft, les jeux compétitifs ou anciens : ce n'est pas un défaut du PC." -f $gl) }) }
        'mixed' { [void]$out.Add(@{ C = '#4ADE80'; T = 'Bien équilibré'; D = "Ni le processeur ni la carte graphique ne bloquent franchement : le PC est bien réglé pour ce jeu." }) }
        default {
            if ($null -eq $gl) { [void]$out.Add(@{ C = '#8B93A7'; T = 'Pas de conclusion'; D = "L'utilisation de la carte graphique n'a pas pu être lue : installe le module de températures (onglet Gaming > En direct) pour savoir ce qui limite ce jeu. AEROX préfère ne rien affirmer sans mesure." }) }
            else { [void]$out.Add(@{ C = '#8B93A7'; T = 'Pas de conclusion'; D = "Pas assez de mesures pendant que le jeu était au premier plan pour conclure sans risque de se tromper. La prochaine partie le dira." }) }
        }
    }
    $flags = @(Get-RecValue $R 'Flags')
    if ($flags -contains 'hot-gpu') { [void]$out.Add(@{ C = '#FF6B6B'; T = ("Carte graphique très chaude ({0} °C)" -f (Get-RecValue $R 'GpuT')); D = "Trop chaude, elle ralentit pour se protéger : moins de FPS. Dépoussière le PC (bombe d'air sec, PC éteint), dégage les grilles d'aération, et pour un portable pose-le sur une surface dure." }) }
    if ($flags -contains 'hot-cpu') { [void]$out.Add(@{ C = '#FF6B6B'; T = ("Processeur très chaud ({0} °C)" -f (Get-RecValue $R 'CpuT')); D = "Trop chaud, il ralentit pour se protéger. Dépoussière le ventilateur et le radiateur ; si le PC a plusieurs années, la pâte thermique est peut-être sèche (à refaire par un réparateur)." }) }
    if ($flags -contains 'vram') { [void]$out.Add(@{ C = '#FFB547'; T = ("Mémoire de la carte graphique pleine ({0} %)" -f (Get-RecValue $R 'Vram')); D = "Quand elle déborde, le jeu va chercher ses images dans la mémoire du PC : c'est la cause n°1 des saccades. Baisse la qualité des textures d'un cran." }) }
    if ($flags -contains 'ram') { [void]$out.Add(@{ C = '#FFB547'; T = ("Mémoire vive presque pleine ({0} %)" -f (Get-RecValue $R 'Ram')); D = "Windows doit se servir du disque à la place : saccades et chargements lents. Ferme le navigateur et les logiciels inutiles avant de jouer."; B = 'Pourquoi mon PC rame ?'; Ui = 'slow' }) }
    if ($flags -contains 'stutter') { [void]$out.Add(@{ C = '#FFB547'; T = ("Beaucoup de saccades ({0})" -f (Get-RecValue $R 'Stut')); D = "Une saccade, c'est une image qui met nettement plus de temps que les autres : un petit gel. Souvent normal sur les premières parties après une mise à jour (le jeu prépare ses « shaders »). Si ça continue : mémoire trop pleine, programme en fond qui se réveille ou pilote graphique ancien." }) }
    if ($flags -contains 'hz') { [void]$out.Add(@{ C = '#FFB547'; T = ("Ton écran tourne à {0} Hz au lieu de {1} Hz" -f $hz, $mx); D = ("Tu ne vois que {0} images par seconde, même si le jeu en calcule plus." -f $hz); B = ("Passer à {0} Hz" -f $mx); Ui = 'display-fix' }) }
    return $out.ToArray()
}
# Pourquoi la pire partie a été moins bonne que la meilleure
function Get-GameWhy($Worst, $Best) {
    $w = @()
    if ($null -ne $Worst.GpuT -and $null -ne $Best.GpuT -and ($Worst.GpuT - $Best.GpuT) -ge 8) { $w += ("carte graphique plus chaude ({0} °C contre {1} °C)" -f $Worst.GpuT, $Best.GpuT) }
    if ($null -ne $Worst.Ram -and $Worst.Ram -ge 90 -and ($null -eq $Best.Ram -or $Best.Ram -lt 85)) { $w += ("mémoire vive pleine ({0} %)" -f $Worst.Ram) }
    if ($null -ne $Worst.Vram -and $Worst.Vram -ge 95 -and ($null -eq $Best.Vram -or $Best.Vram -lt 90)) { $w += ("mémoire de la carte graphique pleine ({0} %)" -f $Worst.Vram) }
    if ($Worst.Driver -and $Best.Driver -and $Worst.Driver -ne $Best.Driver) { $w += ("pilote graphique différent ({0} contre {1})" -f $Worst.Driver, $Best.Driver) }
    if ($Worst.Hz -and $Best.Hz -and $Worst.Hz -ne $Best.Hz) { $w += ("écran à {0} Hz (contre {1} Hz)" -f $Worst.Hz, $Best.Hz) }
    if ($null -ne $Worst.CpuL -and $null -ne $Best.CpuL -and ($Worst.CpuL - $Best.CpuL) -ge 20) { $w += ("processeur bien plus occupé ({0} % contre {1} %) : un programme en fond ?" -f $Worst.CpuL, $Best.CpuL) }
    if ($Worst.Verdict -eq 'cap' -and $Best.Verdict -ne 'cap') { $w += ("FPS bridés à {0}" -f $Worst.Cap) }
    if (-not $w.Count) { return "pas de cause visible côté PC : sans doute une carte, un mode de jeu ou une scène plus lourde." }
    return ($w -join ' ; ')
}

# ---------------------------------------------------------------- Zone de notification (mode discret)
function Initialize-Tray {
    if ($script:Tray) { return }
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $ni = New-Object System.Windows.Forms.NotifyIcon
    # Icône du programme lui-même (pas un fichier du dossier, modifiable en version portable)
    try { $ni.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($(if ($AeroxLauncher) { $AeroxLauncher } else { throw 'pas de lanceur' })) } catch { $ni.Icon = [System.Drawing.SystemIcons]::Application }
    $ni.Text = 'AEROX PC Care'
    $m = New-Object System.Windows.Forms.ContextMenuStrip
    [void]$m.Items.Add('Ouvrir AEROX PC Care', $null, [EventHandler]{ Show-MainWindow '' })
    [void]$m.Items.Add('Gaming : mes jeux', $null, [EventHandler]{ Show-MainWindow 'monitor' })
    [void]$m.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    [void]$m.Items.Add('Quitter AEROX PC Care', $null, [EventHandler]{ Exit-Aerox })
    $ni.ContextMenuStrip = $m
    $ni.Add_MouseClick({ param($s, $e) if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Show-MainWindow '' } })
    $ni.Add_BalloonTipClicked({ $k = $script:BalloonKey; Show-MainWindow 'monitor'; if ($k) { Show-GameDialog $k } })
    $script:Tray = $ni
}
function Update-TrayIcon { if ($script:Settings.Gaming.Tray -or $script:InTray) { Initialize-Tray; $script:Tray.Visible = $true } elseif ($script:Tray -and -not $script:BalloonKey) { $script:Tray.Visible = $false } }
function Show-TrayBalloon([string]$Title, [string]$Text, [string]$Key) {
    Initialize-Tray
    $script:BalloonKey = $Key
    $script:Tray.Visible = $true
    if ($Text.Length -gt 250) { $Text = $Text.Substring(0, 247) + '…' }
    $script:Tray.ShowBalloonTip(10000, $Title, $Text, [System.Windows.Forms.ToolTipIcon]::Info)
}
function Get-MainHandle { return (New-Object System.Windows.Interop.WindowInteropHelper($window)).Handle }
function Hide-ToTray([bool]$Tip = $true) {
    Initialize-Tray; $script:Tray.Visible = $true
    [AeroxGame]::Hide((Get-MainHandle)); $script:InTray = $true
    $script:TrimDue = (Get-Date).AddSeconds(2)
    if ($Tip -and -not $script:Settings.Gaming.TrayTip) {
        $script:Settings.Gaming.TrayTip = $true; Save-Settings
        $script:Tray.ShowBalloonTip(8000, 'AEROX PC Care reste ouvert', "Il note tes parties en silence, ici près de l'horloge. Clic droit sur l'icône > Quitter pour le fermer complètement.", [System.Windows.Forms.ToolTipIcon]::Info)
    }
}
function Show-MainWindow([string]$Page) {
    if (-not $window.ShowInTaskbar) {
        # Démarré en mode discret : la fenêtre était placée hors de l'écran
        $window.ShowInTaskbar = $true
        $wa = [System.Windows.SystemParameters]::WorkArea
        $window.Left = $wa.Left + [math]::Max([double]0, ($wa.Width - $window.ActualWidth) / 2); $window.Top = $wa.Top + [math]::Max([double]0, ($wa.Height - $window.ActualHeight) / 2)
    }
    if ($window.WindowState -eq 'Minimized') { $window.WindowState = 'Normal' }
    $script:InTray = $false
    # La page est reconstruite avant d'afficher la fenêtre (elle a été libérée en mode discret)
    if ($Page) { Go-Page $Page } else { Refresh-Page }
    [AeroxGame]::Show((Get-MainHandle)); try { [void]$window.Activate() } catch {}
    Update-TrayIcon
    if ($script:DeferredStart) { $script:DeferredStart = $false; Invoke-StartupExtras }
}
# Mode discret : libère la page affichée et rend la mémoire inutilisée à Windows.
# Rien n'est perdu : résultats d'analyse, journal et réglages restent ; la page se reconstruit à la réouverture.
function Optimize-TrayMemory {
    $script:TrimDue = $null
    if (-not $script:InTray) { return }
    try { $PageHost.Children.Clear(); $script:PageButtons.Clear(); $script:MonUi = $null } catch {}
    [GC]::Collect(); [GC]::WaitForPendingFinalizers(); [GC]::Collect()
    [AeroxGame]::TrimMemory()
    $script:LastTrim = Get-Date
}
function Exit-Aerox { $script:QuitNow = $true; if ($script:InTray) { Show-MainWindow '' }; $window.Close(); $script:QuitNow = $false }

# ---------------------------------------------------------------- Lancement avec Windows (tâche planifiée, sans demande d'autorisation)
function Get-AutoStartBlock {
    if ($Portable) { return "Pas disponible en version portable (la clé USB n'est pas toujours branchée)." }
    if ((Get-SessionUser).Other) { return "Pas disponible quand AEROX est lancé avec le mot de passe d'un autre compte : Windows le redemanderait à chaque démarrage." }
    if (-not $AeroxLauncher -or -not (Test-Path -LiteralPath $AeroxLauncher)) { return "Lance AEROX avec son raccourci pour activer cette option." }
    return ''
}
function Test-AutoStart { try { return [bool](Get-ScheduledTask -TaskName $script:AutoTaskName -ErrorAction Stop) } catch { return $false } }
function Set-AutoStart([bool]$On) {
    if (-not $On) { Unregister-ScheduledTask -TaskName $script:AutoTaskName -Confirm:$false -ErrorAction SilentlyContinue; return }
    $b = Get-AutoStartBlock; if ($b) { throw $b }
    $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $a = New-ScheduledTaskAction -Execute $AeroxLauncher -Argument '--discret'
    $t = New-ScheduledTaskTrigger -AtLogOn -User $user; $t.Delay = 'PT45S'
    $p = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
    $st = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $script:AutoTaskName -Action $a -Trigger $t -Principal $p -Settings $st -Description "Lance AEROX PC Care caché près de l'horloge pour noter tes parties. Option de l'onglet Gaming, à désactiver au même endroit." -Force -ErrorAction Stop | Out-Null
}
function Set-GamingOption([string]$What) {
    $g = $script:Settings.Gaming
    switch ($What) {
        'track' { $g.Track = -not [bool]$g.Track; Write-UiLog $(if ($g.Track) { "🎮 Les parties seront notées automatiquement." } else { "🎮 Les parties ne sont plus notées." }) }
        'tray' {
            $g.Tray = -not [bool]$g.Tray
            if (-not $g.Tray -and (Test-AutoStart)) { Set-AutoStart $false; Write-UiLog "AEROX ne se lance plus avec Windows." }
            Update-TrayIcon
            Write-UiLog $(if ($g.Tray) { "La croix cache maintenant AEROX près de l'horloge (clic droit sur l'icône > Quitter pour le fermer)." } else { "La croix ferme de nouveau AEROX." })
        }
        'autostart' {
            if (Test-AutoStart) { Set-AutoStart $false; Write-UiLog "AEROX ne se lance plus avec Windows." }
            else {
                try {
                    Set-AutoStart $true
                    if (-not $g.Tray) { $g.Tray = $true; Update-TrayIcon }
                    Write-UiLog "AEROX se lancera avec Windows, caché près de l'horloge : il ne fait rien tant que tu ne lances pas de jeu."
                } catch { [System.Windows.MessageBox]::Show("Impossible d'activer le lancement avec Windows :`n`n$($_.Exception.Message)", $AppName, 'OK', 'Warning') | Out-Null }
            }
        }
    }
    Save-Settings
    if ($script:Cur -eq 'monitor') { Refresh-Page }
}

# ---------------------------------------------------------------- Page Gaming : mes jeux
function New-VerdictPill($R) {
    $id = "$(Get-RecValue $R 'Verdict')"
    $t = switch ($id) { 'gpu' { @('carte graphique', '#9FE8B5', '#173326') } 'cpu' { @('processeur', '#FFD08A', '#3A2A12') } 'cap' { @(("plafonné {0}" -f (Get-RecValue $R 'Cap')), '#C3CAD9', '#232838') } 'engine' { @('moteur du jeu', '#C3CAD9', '#232838') } 'mixed' { @('équilibré', '#9FE8B5', '#173326') } default { $null } }
    if (-not $t) { return $null }
    return (New-Pill $t[0] $t[1] $t[2])
}
function Format-GameDate($D) {
    $d = ConvertTo-DateSafe $D; if (-not $d) { return '' }
    $fr = [Globalization.CultureInfo]::GetCultureInfo('fr-FR')
    if ($d.Date -eq (Get-Date).Date) { return ("aujourd'hui à " + $d.ToString('HH:mm', $fr)) }
    if ($d.Date -eq (Get-Date).Date.AddDays(-1)) { return ("hier à " + $d.ToString('HH:mm', $fr)) }
    return $d.ToString("ddd dd/MM 'à' HH:mm", $fr)
}
function New-GameRow($G) {
    $card = New-CardBorder; $card.Padding = Th 18 12 14 12; $card.Margin = Th 0 0 0 8
    $dp = New-Object System.Windows.Controls.DockPanel
    $b = New-Button 'Voir la fiche' 'ActionBtn' @{ Kind = 'ui'; Def = @{ UI = 'game-sheet'; Key = $G.Key } } $false
    $b.Margin = Th 14 0 0 0; [System.Windows.Controls.DockPanel]::SetDock($b, 'Right'); Add-Child $dp $b
    $l = $G.Last
    $right = New-Object System.Windows.Controls.StackPanel; $right.Margin = Th 14 0 0 0; $right.VerticalAlignment = 'Center'; $right.MinWidth = 110
    if ($null -ne $l.Fps) {
        $f = New-Text ("{0} FPS" -f [int][math]::Round([double]$l.Fps)) 20 '#FFFFFF' 'Bold'; $f.HorizontalAlignment = 'Right'; Add-Child $right $f
        $lo = New-Text ("1 % low {0}" -f [int][math]::Round([double]$l.Low1)) 12 '#8B93A7'; $lo.HorizontalAlignment = 'Right'; Add-Child $right $lo
    } else { $f = New-Text 'FPS non mesurés' 12 '#7A8399'; $f.HorizontalAlignment = 'Right'; Add-Child $right $f }
    [System.Windows.Controls.DockPanel]::SetDock($right, 'Right'); Add-Child $dp $right
    $left = New-Object System.Windows.Controls.StackPanel; $left.VerticalAlignment = 'Center'
    $h = New-Object System.Windows.Controls.WrapPanel
    $n = New-Text $G.Name 15 '#FFFFFF' 'SemiBold'; $n.VerticalAlignment = 'Center'; Add-Child $h $n
    $p = New-VerdictPill $l; if ($p) { Add-Child $h $p }
    Add-Child $left $h
    $cnt = @($G.Sessions).Count
    Add-Child $left (New-Text ("{0} partie{1} · {2} au total · dernière {3}" -f $cnt, $(if ($cnt -gt 1) { 's' } else { '' }), (Format-GameTime $G.TotalMin), (Format-GameDate $l.Start)) 12 '#8B93A7')
    Add-Child $dp $left
    $card.Child = $dp
    return $card
}
function New-GamingToggle([string]$Title, [string]$Desc, [bool]$On, [string]$Ui, [string]$Block) {
    $row = New-Object System.Windows.Controls.DockPanel; $row.Margin = Th 0 6 0 6
    if ($Block) { $p = New-Pill 'indisponible' '#8B93A7' '#232838'; [System.Windows.Controls.DockPanel]::SetDock($p, 'Right'); Add-Child $row $p }
    else { $b = New-Button $(if ($On) { 'Activé' } else { 'Désactivé' }) $(if ($On) { 'FixBtn' } else { 'ActionBtn' }) @{ Kind = 'ui'; Def = @{ UI = $Ui } } $false; $b.Margin = Th 12 0 0 0; $b.MinWidth = 110; [System.Windows.Controls.DockPanel]::SetDock($b, 'Right'); Add-Child $row $b }
    $t = New-Object System.Windows.Controls.StackPanel
    Add-Child $t (New-Text $Title 14 '#FFFFFF' 'SemiBold')
    Add-Child $t (New-Text $(if ($Block) { $Block } else { $Desc }) 12 '#8B93A7')
    Add-Child $row $t
    return $row
}
function Add-GamingSections($Sp, $U) {
    $g = $script:Settings.Gaming
    # Partie en cours
    if ($script:GameSess) {
        $c = New-CardBorder '#3B2F7A'; $cs = New-Object System.Windows.Controls.StackPanel
        Add-Child $cs (New-Text ("🎮 Partie en cours : " + $script:GameSess.Name) 15 '#FFFFFF' 'SemiBold')
        $U.Sess = New-Text '' 13 '#B9A8FF'; $U.Sess.Margin = Th 0 4 0 0; Add-Child $cs $U.Sess
        Add-Child $cs (New-Text "Le résumé s'affichera quand tu quitteras le jeu (notification + fiche du jeu ci-dessous)." 12 '#8B93A7')
        $c.Child = $cs; Add-Child $Sp $c
    } elseif ($script:LastGame -and ((Get-Date) - $script:LastGame.At).TotalHours -lt 12) {
        $c = New-CardBorder; $dp = New-Object System.Windows.Controls.DockPanel
        $b = New-Button 'Voir la fiche' 'ActionBtn' @{ Kind = 'ui'; Def = @{ UI = 'game-sheet'; Key = $script:LastGame.Key } } $false; [System.Windows.Controls.DockPanel]::SetDock($b, 'Right'); $b.Margin = Th 12 0 0 0; Add-Child $dp $b
        $cs = New-Object System.Windows.Controls.StackPanel
        Add-Child $cs (New-Text 'DERNIÈRE PARTIE' 11 '#7A8399' 'Bold')
        $t = New-Text $script:LastGame.Text 14 '#E6E9F2'; $t.Margin = Th 0 4 0 0; Add-Child $cs $t
        Add-Child $dp $cs; $c.Child = $dp; Add-Child $Sp $c
    }
    # Mes jeux
    Add-Child $Sp (New-Section 'Mes jeux')
    $games = @(Get-GameList)
    if (-not $games.Count) {
        $c = New-CardBorder; $cs = New-Object System.Windows.Controls.StackPanel
        Add-Child $cs (New-Text "Aucune partie notée pour l'instant" 15 '#FFFFFF' 'SemiBold')
        $t = New-Text ("Lance un jeu : AEROX le reconnaît tout seul (Steam, Epic, Riot, Battle.net, EA, Ubisoft, GOG, Xbox ou n'importe quel jeu en plein écran) et note la partie quand tu le quittes, à partir de {0} minutes de jeu. AEROX doit rester ouvert pendant que tu joues : active « Garder AEROX près de l'horloge » plus bas pour qu'il ne gêne pas." -f $script:GameMinMinutes) 13 '#A9B0C2'
        $t.Margin = Th 0 6 0 0; Add-Child $cs $t
        if (-not $script:ToolSt.PresentMon) { $w = New-Text "Installe d'abord le compteur de FPS (onglet « En direct » ci-dessus) : sans lui, seules la durée et les températures sont notées." 12.5 '#FFB547'; $w.Margin = Th 0 8 0 0; Add-Child $cs $w }
        $c.Child = $cs; Add-Child $Sp $c
    } else {
        foreach ($x in @($games | Select-Object -First 12)) { Add-Child $Sp (New-GameRow $x) }
        if ($games.Count -gt 12) { $t = New-Text ("+ {0} autre(s) jeu(x) plus ancien(s), dans le dossier « jeux » des journaux." -f ($games.Count - 12)) 12 '#7A8399'; Add-Child $Sp $t }
        if (-not $script:ToolSt.PresentMon) { $w = New-Text "Le compteur de FPS n'est pas installé (onglet « En direct » ci-dessus) : seules la durée et les températures sont notées." 12.5 '#FFB547'; $w.Margin = Th 0 2 0 4; Add-Child $Sp $w }
    }
    # Réglages du suivi
    Add-Child $Sp (New-Section 'Suivi automatique')
    $c = New-CardBorder; $cs = New-Object System.Windows.Controls.StackPanel
    Add-Child $cs (New-GamingToggle "Noter mes parties automatiquement" "Détecte le jeu, mesure FPS, saccades et températures pendant la partie, puis affiche un résumé. Rien n'est injecté dans le jeu : aucun risque avec les anti-triche." ([bool]$g.Track) 'game-track' '')
    Add-Child $cs (New-GamingToggle "Garder AEROX près de l'horloge quand je le ferme" "La croix cache AEROX dans la zone de notification au lieu de le fermer : il continue de noter tes parties sans rien afficher. Clic droit sur l'icône > Quitter pour le fermer." ([bool]$g.Tray) 'game-tray' '')
    Add-Child $cs (New-GamingToggle "Lancer AEROX avec Windows, en mode discret" "Caché près de l'horloge, il ne fait rien tant que tu ne joues pas. C'est le seul programme qu'AEROX ajoute au démarrage, et seulement si tu l'actives ici." (Test-AutoStart) 'game-autostart' (Get-AutoStartBlock))
    $c.Child = $cs; Add-Child $Sp $c
}

# ---------------------------------------------------------------- Fiche d'un jeu
function New-LineChart($Series, [double]$W = 640, [double]$H = 120, [string]$Unit = 'FPS') {
    $all = @(foreach ($s in $Series) { foreach ($x in @($s.V)) { if ([double]$x -gt 0) { [double]$x } } })
    $dp = New-Object System.Windows.Controls.DockPanel
    if (-not $all.Count) { return $dp }
    $mx = ($all | Measure-Object -Maximum).Maximum; $mn = ($all | Measure-Object -Minimum).Minimum
    $lo = [math]::Max([double]0, [math]::Floor($mn * 0.9 / 10) * 10); $hi = [math]::Ceiling($mx * 1.05 / 10) * 10; if ($hi -le $lo) { $hi = $lo + 10 }
    $ax = New-Object System.Windows.Controls.Grid; $ax.Width = 44; $ax.Height = $H
    $t1 = New-Text ("{0}" -f $hi) 11 '#7A8399'; $t1.VerticalAlignment = 'Top'; Add-Child $ax $t1
    $t2 = New-Text ("{0}" -f $lo) 11 '#7A8399'; $t2.VerticalAlignment = 'Bottom'; Add-Child $ax $t2
    [System.Windows.Controls.DockPanel]::SetDock($ax, 'Left'); Add-Child $dp $ax
    $cv = New-Object System.Windows.Controls.Canvas; $cv.Width = $W; $cv.Height = $H; $cv.ClipToBounds = $true; $cv.Background = Brush '#10131A'
    foreach ($i in 1, 2, 3) {
        $ln = New-Object System.Windows.Shapes.Line; $ln.X1 = 0; $ln.X2 = $W; $ln.Y1 = $H * $i / 4; $ln.Y2 = $ln.Y1; $ln.Stroke = Brush '#1E2230'; $ln.StrokeThickness = 1; [void]$cv.Children.Add($ln)
    }
    foreach ($s in $Series) {
        $v = @($s.V); if ($v.Count -lt 1) { continue }
        $pl = New-Object System.Windows.Shapes.Polyline; $pl.Stroke = Brush $s.Color; $pl.StrokeThickness = 2; $pl.StrokeLineJoin = 'Round'
        $pc = New-Object System.Windows.Media.PointCollection
        for ($i = 0; $i -lt $v.Count; $i++) {
            if ([double]$v[$i] -le 0) { continue }
            $x = $(if ($v.Count -gt 1) { ($W - 8) * $i / ($v.Count - 1) + 4 } else { $W / 2 })
            $y = $H - 4 - ([double]$v[$i] - $lo) / ($hi - $lo) * ($H - 8)
            $pc.Add((New-Object System.Windows.Point($x, $y)))
            if ($v.Count -le 40) { $e = New-Object System.Windows.Shapes.Ellipse; $e.Width = 6; $e.Height = 6; $e.Fill = Brush $s.Color; [System.Windows.Controls.Canvas]::SetLeft($e, $x - 3); [System.Windows.Controls.Canvas]::SetTop($e, $y - 3); [void]$cv.Children.Add($e) }
        }
        $pl.Points = $pc; [void]$cv.Children.Add($pl)
    }
    Add-Child $dp $cv
    return $dp
}
function New-StatTile([string]$Label, [string]$Big, [string]$Small) {
    $b = New-Object System.Windows.Controls.Border; $b.Background = Brush '#171A23'; $b.CornerRadius = Corner 10; $b.Padding = Th 14 10 14 10; $b.Margin = Th 0 0 8 8
    $sp = New-Object System.Windows.Controls.StackPanel
    Add-Child $sp (New-Text $Label 10.5 '#7A8399' 'Bold')
    $t = New-Text $Big 20 '#FFFFFF' 'Bold'; $t.Margin = Th 0 4 0 0; Add-Child $sp $t
    if ($Small) { Add-Child $sp (New-Text $Small 11.5 '#8B93A7') }
    $b.Child = $sp
    return $b
}
function New-LegendLine($Items) {
    $wp = New-Object System.Windows.Controls.WrapPanel; $wp.Margin = Th 44 6 0 0
    foreach ($it in $Items) {
        $r = New-Object System.Windows.Shapes.Rectangle; $r.Width = 14; $r.Height = 3; $r.Fill = Brush $it[1]; $r.Margin = Th 0 0 6 0; $r.VerticalAlignment = 'Center'; Add-Child $wp $r
        $t = New-Text $it[0] 11.5 '#8B93A7'; $t.Margin = Th 0 0 16 0; Add-Child $wp $t
    }
    return $wp
}
function Show-GameDialog([string]$Key) {
    $g = Read-GameFile $Key
    if (-not $g -or -not @($g.Sessions).Count) { Write-UiLog "Pas encore de partie notée pour ce jeu."; return }
    $ses = @($g.Sessions); $last = $ses[-1]
    $w = New-Dialog "$AppName : $($g.Name)" 780
    $script:GameWin = $w; $script:GameAction = $null
    $sv = New-Object System.Windows.Controls.ScrollViewer; $sv.VerticalScrollBarVisibility = 'Auto'
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = Th 24 22 24 20
    Add-Child $sp (New-Text $g.Name 20 '#FFFFFF' 'Bold')
    $tot = ($ses | ForEach-Object { [double]$_.Min } | Measure-Object -Sum).Sum
    $sub = New-Text ("{0} partie{1} notée{1} · {2} de jeu{3}" -f $ses.Count, $(if ($ses.Count -gt 1) { 's' } else { '' }), (Format-GameTime $tot), $(if ($g.Store) { " · " + $g.Store } else { '' })) 13 '#A9B0C2'
    $sub.Margin = Th 0 4 0 12; Add-Child $sp $sub
    $withFps = @($ses | Where-Object { $null -ne $_.Fps })
    # Chiffres clés
    $ug = New-Object System.Windows.Controls.Primitives.UniformGrid; $ug.Columns = 4
    if ($null -ne $last.Fps) { Add-Child $ug (New-StatTile 'DERNIÈRE PARTIE' ("{0} FPS" -f [int][math]::Round([double]$last.Fps)) ("1 % low {0}" -f [int][math]::Round([double]$last.Low1))) }
    else { Add-Child $ug (New-StatTile 'DERNIÈRE PARTIE' (Format-GameTime ([double]$last.Min)) 'FPS non mesurés') }
    $recent = @($withFps | Select-Object -Last 5)
    if ($recent.Count) { Add-Child $ug (New-StatTile ("MOYENNE ({0} DERNIÈRES)" -f $recent.Count) ("{0} FPS" -f [int][math]::Round((($recent | ForEach-Object { [double]$_.Fps } | Measure-Object -Average).Average))) ("1 % low {0}" -f [int][math]::Round((($recent | ForEach-Object { [double]$_.Low1 } | Measure-Object -Average).Average)))) }
    $gt = @($ses | Where-Object { $null -ne $_.GpuT } | ForEach-Object { [double]$_.GpuT })
    if ($gt.Count) { Add-Child $ug (New-StatTile 'CARTE GRAPHIQUE' ("{0} °C" -f [int]($gt | Measure-Object -Maximum).Maximum) 'température max notée') }
    $stm = (@($withFps | ForEach-Object { [double]$_.Min }) | Measure-Object -Sum).Sum; $stn = (@($withFps | ForEach-Object { [double]$_.Stut }) | Measure-Object -Sum).Sum
    if ($stm -gt 0) { Add-Child $ug (New-StatTile 'SACCADES' ("{0:N0} / h" -f ($stn * 60 / $stm)) 'en moyenne') }
    Add-Child $sp $ug
    # Évolution partie après partie
    if ($withFps.Count -ge 2) {
        $h = New-Text 'PARTIE APRÈS PARTIE' 11.5 '#7A8399' 'Bold'; $h.Margin = Th 0 14 0 8; Add-Child $sp $h
        $lastN = @($withFps | Select-Object -Last 30)
        Add-Child $sp (New-LineChart @(@{ V = @($lastN | ForEach-Object { [double]$_.Fps }); Color = '#7C5CFF' }, @{ V = @($lastN | ForEach-Object { [double]$_.Low1 }); Color = '#8B93A7' }) 640 120)
        Add-Child $sp (New-LegendLine @(@('FPS moyen', '#7C5CFF'), @('1 % low', '#8B93A7')))
    }
    if (@($last.Curve).Count -ge 2) {
        $h = New-Text 'DERNIÈRE PARTIE, MINUTE PAR MINUTE' 11.5 '#7A8399' 'Bold'; $h.Margin = Th 0 14 0 8; Add-Child $sp $h
        Add-Child $sp (New-LineChart @(@{ V = @($last.Curve); Color = '#4ADE80' }) 640 90)
    }
    # Ce qui limite ce jeu et quoi faire
    $h = New-Text 'CE QUI LIMITE CE JEU ET QUOI FAIRE' 11.5 '#7A8399' 'Bold'; $h.Margin = Th 0 16 0 8; Add-Child $sp $h
    # Verdict le plus fréquent sur les 5 dernières parties (une partie isolée peut tromper)
    $ref = $last
    $vs = @($ses | Select-Object -Last 5 | Where-Object { $_.Verdict } | Group-Object { $_.Verdict } | Sort-Object Count -Descending)
    if ($vs.Count -and $vs[0].Name -ne "$($last.Verdict)") { $ref = @($vs[0].Group)[-1] }
    # Les mesures sur lesquelles repose le verdict, pour que chacun puisse vérifier
    $ev = @()
    if ($null -ne $ref.GpuL) { $ev += ("carte graphique {0} %" -f $ref.GpuL) }
    if ($null -ne $ref.CpuL) { $ev += ("processeur {0} %" -f $ref.CpuL) }
    if ($null -ne $ref.Core) { $ev += ("cœur le plus chargé {0} %" -f $ref.Core) }
    if ($null -ne $ref.Fps -and $ref.Hz) { $ev += ("{0} FPS pour un écran à {1} Hz" -f [int][math]::Round([double]$ref.Fps), $ref.Hz) }
    if ($ev.Count) { $t = New-Text ("Utilisation moyenne mesurée pendant la partie : " + ($ev -join ' · ')) 12 '#8B93A7'; $t.Margin = Th 0 0 0 8; Add-Child $sp $t }
    $adv = @(Get-GameAdvice $ref)
    if ($ref -ne $last) { foreach ($a in @(Get-GameAdvice $last)) { if ($a.T -notin @($adv | ForEach-Object { $_.T }) -and $a.C -ne '#4ADE80') { $adv += $a } } }
    foreach ($a in $adv) {
        $c = New-Object System.Windows.Controls.Border; $c.Background = Brush '#171A23'; $c.BorderBrush = Brush $a.C; $c.BorderThickness = Th 3 0 0 0; $c.CornerRadius = Corner 8; $c.Padding = Th 14 10 14 10; $c.Margin = Th 0 0 0 8
        $cs = New-Object System.Windows.Controls.StackPanel
        Add-Child $cs (New-Text $a.T 14 '#FFFFFF' 'SemiBold')
        $d = New-Text $a.D 12.5 '#A9B0C2'; $d.Margin = Th 0 3 0 0; Add-Child $cs $d
        if ($a.B) {
            $bw = New-Object System.Windows.Controls.WrapPanel; $bw.Margin = Th 0 8 0 0
            foreach ($bb in @(@($a.B, $a.Ui), @($a.B2, $a.Ui2))) {
                if (-not $bb[0]) { continue }
                $btn = New-DlgButton $bb[0] 'ActionBtn'; $btn.Tag = $bb[1]; $btn.Margin = Th 0 0 8 0
                $btn.Add_Click({ $script:GameAction = $this.Tag; $script:GameWin.Close() }); Add-Child $bw $btn
            }
            Add-Child $cs $bw
        }
        $c.Child = $cs; Add-Child $sp $c
    }
    # Meilleure et pire partie
    $long = @($withFps | Where-Object { [double]$_.Min -ge 5 })
    if ($long.Count -ge 3) {
        $best = $long | Sort-Object { [double]$_.Fps } -Descending | Select-Object -First 1
        $worst = $long | Sort-Object { [double]$_.Fps } | Select-Object -First 1
        if ([double]$best.Fps -gt [double]$worst.Fps * 1.08) {
            $h = New-Text 'MEILLEURE ET PIRE PARTIE' 11.5 '#7A8399' 'Bold'; $h.Margin = Th 0 8 0 8; Add-Child $sp $h
            Add-Child $sp (New-Rich 'Meilleure' ("{0} FPS, {1}" -f [int][math]::Round([double]$best.Fps), (Format-GameDate $best.Start)) '')
            Add-Child $sp (New-Rich 'Pire' ("{0} FPS, {1}" -f [int][math]::Round([double]$worst.Fps), (Format-GameDate $worst.Start)) '')
            Add-Child $sp (New-Rich 'Pourquoi' (Get-GameWhy $worst $best) '')
        }
    }
    # Dernières parties
    $h = New-Text 'DERNIÈRES PARTIES' 11.5 '#7A8399' 'Bold'; $h.Margin = Th 0 16 0 8; Add-Child $sp $h
    $rl = @($ses | Select-Object -Last 10); [array]::Reverse($rl)
    foreach ($s in $rl) {
        $row = New-Object System.Windows.Controls.Border; $row.Background = Brush '#171A23'; $row.CornerRadius = Corner 8; $row.Padding = Th 12 7 12 7; $row.Margin = Th 0 0 0 4
        $dp = New-Object System.Windows.Controls.DockPanel
        $pl = New-VerdictPill $s; if ($pl) { [System.Windows.Controls.DockPanel]::SetDock($pl, 'Right'); Add-Child $dp $pl }
        $bits = @((Format-GameDate $s.Start), (Format-GameTime ([double]$s.Min)))
        if ($null -ne $s.Fps) { $bits += ("{0} FPS" -f [int][math]::Round([double]$s.Fps)); $bits += ("1 % low {0}" -f [int][math]::Round([double]$s.Low1)); $bits += ("{0} saccade{1}" -f [int]$s.Stut, $(if ([int]$s.Stut -gt 1) { 's' } else { '' })) }
        if ($null -ne $s.GpuT) { $bits += ("GPU {0} °C" -f $s.GpuT) }
        Add-Child $dp (New-Text ($bits -join '  ·  ') 12.5 '#C3CAD9')
        $row.Child = $dp; Add-Child $sp $row
    }
    $tip = New-Text "FPS mesurés par PresentMon (outil d'Intel) sans rien injecter dans le jeu. 1 % low = les FPS des 1 % d'images les plus lentes : plus il est proche de la moyenne, plus c'est fluide." 11.5 '#7A8399'
    $tip.Margin = Th 0 10 0 0; Add-Child $sp $tip
    # Boutons
    $row = New-Object System.Windows.Controls.DockPanel; $row.Margin = Th 0 16 0 0
    $bc = New-DlgButton 'Fermer' 'PrimaryBtn'; $bc.Add_Click({ $script:GameWin.Close() }); [System.Windows.Controls.DockPanel]::SetDock($bc, 'Right'); Add-Child $row $bc
    $bl = New-Object System.Windows.Controls.StackPanel; $bl.Orientation = 'Horizontal'
    $bn = New-DlgButton "Ce n'est pas un jeu" 'GhostBtn'; $bn.Margin = Th 0 0 8 0; $bn.Add_Click({ $script:GameAction = 'notgame'; $script:GameWin.Close() }); Add-Child $bl $bn
    $bd = New-DlgButton "Effacer l'historique" 'GhostBtn'; $bd.Add_Click({ $script:GameAction = 'forget'; $script:GameWin.Close() }); Add-Child $bl $bd
    Add-Child $row $bl
    Add-Child $sp $row
    $sv.Content = $sp; $w.Content = $sv
    [void]$w.ShowDialog()
    $act = $script:GameAction; $script:GameAction = $null
    if (-not $act) { return }
    switch ($act) {
        'notgame' {
            if (Confirm-Box ("« $($g.Name) » n'est pas un jeu ?`n`nAEROX ne le suivra plus et efface ses parties notées.")) {
                if ($g.Path) { $script:Settings.Gaming.Ignore = @(@($script:Settings.Gaming.Ignore) + @("$($g.Path)".ToLowerInvariant()) | Select-Object -Unique); Save-Settings }
                Remove-Item -LiteralPath (Get-GameFile $Key) -Force -ErrorAction SilentlyContinue
                Write-UiLog ("🎮 « {0} » n'est plus suivi." -f $g.Name); Refresh-Page
            }
        }
        'forget' {
            if (Confirm-Box ("Effacer les {0} partie(s) notée(s) de « {1} » ?" -f $ses.Count, $g.Name)) {
                Remove-Item -LiteralPath (Get-GameFile $Key) -Force -ErrorAction SilentlyContinue
                Write-UiLog ("🎮 Historique de « {0} » effacé." -f $g.Name); Refresh-Page
            }
        }
        'page-perf' { Go-Page 'perf' }
        'display-fix' { $ds = @(Get-Displays); $d = $ds | Where-Object { $_.Device -and $_.Device -eq "$($last.Device)" } | Select-Object -First 1; if (-not $d) { $d = $ds | Where-Object { $_.Primary } | Select-Object -First 1 }; Set-DisplayWithConfirm $d $null }
        default { Invoke-UiCommand @{ Kind = 'ui'; Def = @{ UI = $act } } }
    }
}

# ---------------------------------------------------------------- Événements
$NavHome.Add_Checked({ Show-Page 'home' })
$NavDiag.Add_Checked({ Show-Page 'diag' })
$NavClean.Add_Checked({ Show-Page 'clean' })
$NavUpdate.Add_Checked({ Show-Page 'update' })
$NavRepair.Add_Checked({ Show-Page 'repair' })
$NavPerf.Add_Checked({ Show-Page 'perf' })
$NavMonitor.Add_Checked({ Show-Page 'monitor' })
$NavSystem.Add_Checked({ Show-Page 'system' })
$NavHelp.Add_Checked({ Show-Page 'help' })
$LogToggle.Add_Click({ Set-LogOpen (-not $script:LogOpen) })
$BtnCopyLog.Add_Click({ try { if ($LogBox.Text) { [System.Windows.Clipboard]::SetText((Protect-Text $LogBox.Text)) }; Write-UiLog "Journal copié dans le presse-papiers." } catch {} })
$BtnOpenLogs.Add_Click({ Start-Process explorer.exe $LogDir })
$BtnReport.Add_Click({ Show-BugReport '' })

$window.Add_SourceInitialized({
    try {
        $script:HotkeyText = [AeroxHotkey]::Register()
        if (-not $script:HotkeyText) { Write-Bug -Context 'Raccourci Ctrl+Maj+O' -ErrorRecord "Ctrl+Maj+O, Ctrl+Alt+O et Ctrl+Maj+F10 sont déjà utilisés par d'autres logiciels" -Type 'erreur' }
    } catch { Write-Bug -Context 'Raccourci Ctrl+Maj+O' -ErrorRecord $_ }
})
$window.Add_Closing({
    param($s, $e)
    # Mode discret : la croix cache AEROX près de l'horloge (il continue de noter les parties)
    if ($script:Settings.Gaming.Tray -and -not $script:QuitNow) { $e.Cancel = $true; try { Hide-ToTray } catch { Write-Bug -Context 'Zone de notification' -ErrorRecord $_ }; return }
    if ($script:Job) {
        $r = [System.Windows.MessageBox]::Show("Une opération est en cours. Quitter quand même ?`n(Mieux vaut attendre la fin, surtout pendant une réparation ou des mises à jour.)", $AppName, 'YesNo', 'Warning')
        if ($r -ne 'Yes') { $e.Cancel = $true; return } else { try { $script:Job.PS.Stop() } catch {} }
    }
    try { Stop-GameSession } catch { Write-Bug -Context 'Gaming : fin de partie' -ErrorRecord $_ }
    try { if ($script:SaveSoon -and $script:SaveSoon.IsEnabled) { $script:SaveSoon.Stop(); Save-Settings } } catch {}
    try { Stop-Monitoring } catch {}
    try { [AeroxHotkey]::Unregister() } catch {}
    try { if ($script:Ov) { $script:Ov.Close() } } catch {}
    try { if ($script:Tray) { $script:Tray.Visible = $false; $script:Tray.Dispose(); $script:Tray = $null } } catch {}
})

# Rafraîchissement : journal, barre de progression, scan en direct, nouvelle version
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(150)
$timer.Add_Tick({
    try {
        # Disques lus en arrière-plan : la tuile de l'accueil se met à jour dès qu'ils ont répondu
        if ($sync.DrivesNew) {
            $sync.DrivesNew = $false
            $sig = (@($sync.Drives | Where-Object { $_ } | ForEach-Object { "{0}{1}" -f $_.Id, [math]::Round([double]$_.Free / 1GB) }) -join ',')
            if ($sig -ne $script:DrivesSig) { $script:DrivesSig = $sig; Update-HomeStats -KeepDrives; if ($script:Cur -eq 'home') { Refresh-Page } }
        }
        Flush-Queue
        if ($script:ShowEvent -and $script:ShowEvent.WaitOne(0)) { Show-MainWindow '' }
        try { Invoke-MonitorTick } catch { Write-Bug -Context 'Gaming' -ErrorRecord $_ }
        if ($script:Job) {
            $p = $sync.Progress
            if ($p -ge 0) { $Progress.IsIndeterminate = $false; $Progress.Value = $p } else { $Progress.IsIndeterminate = $true }
            $ElapsedText.Text = '{0:mm\:ss}' -f ((Get-Date) - $script:Job.Start)
            if ($script:Scanning -and $script:Cur -eq 'diag' -and $sync.ScanVer -ne $script:LastScanVer) { $script:LastScanVer = $sync.ScanVer; Refresh-Page }
            if ($script:Job.Handle.IsCompleted) { Complete-Job }
            elseif ($script:Job.StopAt -and ((Get-Date) - $script:Job.StopAt).TotalSeconds -ge 8) { Abandon-Job }
        }
        try { Receive-IssueChecks } catch { Write-Bug -Context 'Vérification après réparation' -ErrorRecord $_ }
        foreach ($z in @($script:Zombies | Where-Object { $_.Handle.IsCompleted })) { try { $z.PS.Dispose(); $z.RS.Close(); $z.RS.Dispose() } catch {}; [void]$script:Zombies.Remove($z) }
        if ($script:SysWaiting -and $sync.SysInfo) { $script:SysWaiting = $false; if ($script:Cur -eq 'system') { Refresh-Page } }
        if ($sync.UpdateInfo -and -not $script:UpdateShown) {
            $script:UpdateShown = $true
            Write-UiLog ("Nouvelle version d'AEROX PC Care disponible : {0}" -f $sync.UpdateInfo.Version)
            if ($script:Cur -eq 'home') { Refresh-Page }
        }
        if ($script:ManualUpdateCheck -and $sync.UpdateDone) {
            $script:ManualUpdateCheck = $false
            if ($sync.UpdateInfo -and $sync.UpdateInfo.Setup) { Start-SelfUpdate }
            elseif ($sync.UpdateInfo) {
                if (Confirm-Box ("Nouvelle version disponible : {0}`n`nOuvrir la page de téléchargement ?" -f $sync.UpdateInfo.Version)) { [void](Open-Url $sync.UpdateInfo.Url) }
            } else { [System.Windows.MessageBox]::Show("Tu as déjà la dernière version ($AppVersion).", $AppName, 'OK', 'Information') | Out-Null }
        }
    } catch { Write-Bug -Context 'Boucle de l''interface' -ErrorRecord $_ }
})

# ---------------------------------------------------------------- Lancement
Set-SplashStep 88 'Lecture de tes réglages…'
Write-UiLog ("Bienvenue dans $AppName $AppVersion — " + (Get-Date -Format 'dddd dd MMMM yyyy HH:mm'))
Write-UiLog "Commence par « Lancer le diagnostic » sur l'accueil."
$LogDot.Visibility = 'Collapsed'
Load-Settings
if ($script:Settings.LogOpen) { Set-LogOpen $true }
try {
    if ("$($script:Settings.InstallId)" -notmatch '^[0-9a-f]{32}$') { $script:Settings.InstallId = [guid]::NewGuid().ToString('N') }
    $script:Settings.Launches = [int]$script:Settings.Launches + 1
    Save-Settings
} catch {}
# Fichiers temporaires d'une mise à jour terminée
foreach ($mj in @((Join-Path $OldLogDir 'maj'), (Join-Path $AppRoot 'maj'), (Join-Path $SecureRoot 'maj'))) { try { if (Test-Path -LiteralPath $mj) { $null = Remove-PathContent $mj } } catch {} }
# Module de températures installé par une ancienne version dans le dossier perso : réinstallé dans le dossier protégé
try {
    if ((Test-Path -LiteralPath (Join-Path $OldLogDir 'outils\lhm\LibreHardwareMonitorLib.dll')) -and -not (Test-Path -LiteralPath (Join-Path $SecureRoot 'outils\lhm\LibreHardwareMonitorLib.dll'))) { Start-Background 'Install-SensorLib' }
} catch {}
# Version installée : garde le bon numéro dans « Applications installées » après une mise à jour automatique
try {
    $uk = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\AeroxPCCare'
    if (-not $Portable -and (Test-Path $uk) -and (Get-ItemProperty $uk -ErrorAction Stop).DisplayVersion -ne $AppVersion) { Set-ItemProperty -Path $uk -Name DisplayVersion -Value $AppVersion }
} catch {}
# L'overlay se rouvre seulement une fois la fenêtre principale affichée
$window.Add_ContentRendered({
    Close-Splash
    if ($script:OvStarted) { return }
    $script:OvStarted = $true
    if ($script:StartHidden) { try { Hide-ToTray $false } catch { Write-Bug -Context 'Mode discret' -ErrorRecord $_ } }
    if ($script:Settings.Overlay.Visible) { try { Show-Overlay $true } catch { Write-Bug -Context 'Overlay au démarrage' -ErrorRecord $_ } }
    # Mode discret : nouveautés et bilan d'après optimisation attendent que la fenêtre soit ouverte
    if ($script:StartHidden) { $script:DeferredStart = $true } else { Invoke-StartupExtras }
})
function Invoke-StartupExtras {
    try { Show-WhatsNewIfUpdated } catch { Write-Bug -Context 'Quoi de neuf' -ErrorRecord $_ }
    if ($script:Settings.PostOptimize) {
        $script:Settings.PostOptimize = $false; Save-Settings
        Write-UiLog "Bilan après l'optimisation complète : diagnostic en cours…"
        Start-Diagnostic
    }
}
# Lancé avec Windows (mode discret) : fenêtre cachée près de l'horloge, rien ne s'affiche
$script:StartHidden = ([bool]$AeroxDiscreet -and [bool]$script:Settings.Gaming.Tray)
if ($script:StartHidden) { $window.ShowInTaskbar = $false; $window.ShowActivated = $false; $window.WindowStartupLocation = 'Manual'; $window.Left = -32000; $window.Top = -32000; Close-Splash }
try { Update-TrayIcon } catch { Write-Bug -Context 'Zone de notification' -ErrorRecord $_ }
# Un 2e lancement d'AEROX (raccourci) réaffiche la fenêtre cachée
try {
    $evs = New-Object System.Security.AccessControl.EventWaitHandleSecurity
    foreach ($sid in 'S-1-5-11', 'S-1-5-32-544', 'S-1-5-18') { $evs.AddAccessRule((New-Object System.Security.AccessControl.EventWaitHandleAccessRule((New-Object System.Security.Principal.SecurityIdentifier($sid)), ([System.Security.AccessControl.EventWaitHandleRights]'Synchronize, Modify'), 'Allow'))) }
    $evNew = $false
    $script:ShowEvent = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::AutoReset, 'Local\AeroxPCCare_Ouvrir', [ref]$evNew, $evs)
} catch { $script:ShowEvent = $null }
Update-HomeStats
$NavHome.IsChecked = $true
$timer.Start()
if ($GitHubRepo) { Start-Background 'Find-AppUpdate; Find-BugRelay; Find-DiscordLink; Send-Stats' }
Set-SplashStep 95 'Ouverture…'
[void]$window.ShowDialog()
$timer.Stop()
try { Stop-Monitoring } catch {}
