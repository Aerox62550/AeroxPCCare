
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
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
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
        <TextBlock x:Name="VersionText" DockPanel.Dock="Bottom" FontSize="11" Foreground="#5D6478" Margin="8,0,0,0"/>
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
            <StackPanel Orientation="Horizontal"><TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE9D9;" Width="28" VerticalAlignment="Center"/><TextBlock Text="Moniteur"/></StackPanel>
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
            <TextBlock x:Name="ElapsedText" DockPanel.Dock="Right" Foreground="#8B93A7" FontSize="12"/>
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
                <TextBlock Text="JOURNAL" FontSize="11" FontWeight="Bold" Foreground="#5D6478" VerticalAlignment="Center"/>
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
foreach ($n in 'Scroll','PageHost','BusyPanel','StatusText','ElapsedText','Progress','LogBox','LogToggle','LogChevron','LogDot','LogLast','BtnReport','BtnCopyLog','BtnOpenLogs',
               'VersionText','DiagBadge','DiagBadgeText','NavHome','NavDiag','NavClean','NavUpdate','NavRepair','NavPerf','NavMonitor','NavSystem','NavHelp') {
    Set-Variable -Name $n -Value $window.FindName($n) -Scope Script
}
$VersionText.Text = "Version $AppVersion"
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
    SpeedHistory = @()
    BetaChannel = $false
    Overlay = @{ Visible = $false; X = 30; Y = 30; Scale = 1.0; Opacity = 0.6; Metrics = @('fps', 'low', 'cpu', 'cputemp', 'gpu', 'gputemp'); AlertOn = $true; AlertCpu = 90; AlertGpu = 85 }
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
            foreach ($k in 'LogOpen', 'IgnoredApps', 'IgnoredIssues', 'StartupKept', 'SpeedHistory', 'BetaChannel') { if ($h.ContainsKey($k)) { $script:Settings[$k] = $h[$k] } }
            if ($h.Overlay -is [hashtable]) { foreach ($k in @($h.Overlay.Keys)) { $script:Settings.Overlay[$k] = $h.Overlay[$k] } }
        } elseif (Test-Path -LiteralPath $OldSettings) {
            $script:Settings.LogOpen = ((Get-Content -LiteralPath $OldSettings -ErrorAction Stop) -match 'journal=ouvert')
        }
    } catch { Write-Bug -Context 'Lecture des réglages' -ErrorRecord $_ }
    $script:Settings.IgnoredApps = @($script:Settings.IgnoredApps | Where-Object { $_ })
    $script:Settings.StartupKept = @($script:Settings.StartupKept | Where-Object { $_ })
    $script:Settings.IgnoredIssues = @($script:Settings.IgnoredIssues | Where-Object { $_ -is [hashtable] -and $_.Id })
    $script:Settings.SpeedHistory = @($script:Settings.SpeedHistory | Where-Object { $_ -is [hashtable] })
    $script:Settings.Overlay.Metrics = @($script:Settings.Overlay.Metrics | Where-Object { $_ })
    $AppInfo.IgnoredApps = @($script:Settings.IgnoredApps)
    $AppInfo.IgnoredIssues = @($script:Settings.IgnoredIssues | ForEach-Object { [string]$_.Id })
    $AppInfo.StartupKept = @($script:Settings.StartupKept)
    $AppInfo.Beta = [bool]$script:Settings.BetaChannel
    Update-VersionText
}
function Update-VersionText { $VersionText.Text = "Version $AppVersion" + $(if ($script:Settings.BetaChannel) { "  ·  canal test" } else { '' }) }
function Save-Settings {
    $AppInfo.Beta = [bool]$script:Settings.BetaChannel
    $AppInfo.IgnoredApps = @($script:Settings.IgnoredApps)
    $AppInfo.IgnoredIssues = @($script:Settings.IgnoredIssues | ForEach-Object { [string]$_.Id })
    $AppInfo.StartupKept = @($script:Settings.StartupKept)
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
function New-Section([string]$Text) { $t = New-Text $Text.ToUpper() 11.5 '#6B7389' 'Bold'; $t.Margin = Th 0 18 0 10; return $t }
function Add-Child($Parent, $Child) { [void]$Parent.Children.Add($Child) }

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
    $card = New-CardBorder
    $grid = New-Object System.Windows.Controls.Grid
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = [System.Windows.GridLength]::Auto
    $grid.ColumnDefinitions.Add($c1); $grid.ColumnDefinitions.Add($c2)
    $sp = New-Object System.Windows.Controls.StackPanel
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
    [System.Windows.Controls.Grid]::SetColumn($btn, 1); Add-Child $grid $btn
    $card.Child = $grid
    return $card
}

function Get-Score { if (-not $script:Diag) { return $null }; $s = 100; foreach ($i in $script:Diag.Issues) { if ($i.Status -ne 'done') { $s -= $(if ($i.Sev -eq 'crit') { 12 } else { 5 }) } }; return [math]::Max(0, $s) }
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
    $map = @{ ok = @('✓', '#4ADE80', '#173326'); warn = @('!', '#FFB547', '#3A2D17'); bad = @('✕', '#FF6B6B', '#3A1E24'); run = @('…', '#B9A8FF', '#2A2350'); wait = @('', '#5D6478', '#1E2230') }
    $m = $map[$State]; if (-not $m) { $m = $map.wait }
    $b = New-Object System.Windows.Controls.Border; $b.Width = 22; $b.Height = 22; $b.CornerRadius = Corner 11; $b.Background = Brush $m[2]; $b.VerticalAlignment = 'Center'
    $t = New-Text $m[0] 12 $m[1] 'Bold'; $t.HorizontalAlignment = 'Center'; $t.VerticalAlignment = 'Center'; $b.Child = $t
    return $b
}

# ---------------------------------------------------------------- Cartes de problème (diagnostic + erreurs)
function New-IssueCard($I, [switch]$IsError) {
    $done = $I.Status -eq 'done'; $fixing = $I.Status -eq 'fixing'
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
        if ($fixing) { Add-Child $acts (New-Text "Réparation en cours…" 13 '#B9A8FF' 'SemiBold') }
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
            if ($hint) { $h = New-Text $hint 12 '#6B7389'; $h.VerticalAlignment = 'Center'; $h.Margin = Th 4 0 0 0; Add-Child $acts $h }
            if (-not $IsError -and $I.Id -and $I.Cat -ne 'Sécurité') {
                $bi = New-Button 'Ne plus signaler' 'TextBtn' @{ Kind = 'ignore'; Issue = $I } $false; $bi.Margin = Th 8 0 0 0; Add-Child $acts $bi
            }
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
    @{ T = "Ce qui prend de la place"; B = "Analyser le disque"; UI = 'space'; UiBusy = $true; D = "Affiche les dossiers et fichiers les plus gros du disque C: sous forme d'arbre, pour savoir quoi trier (jeux, vidéos, téléchargements…). 1 à 3 minutes." },
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
    @{ T = "Tester ma connexion"; B = "Tester"; A = "Test-Internet"; D = "Vérifie la box, Internet, le DNS, le ping et le Wi-Fi, et t'explique d'où vient le problème." },
    @{ T = "Réparer la connexion Internet"; B = "Réparer"; A = "Repair-Network"; D = "Remet à zéro les réglages réseau de Windows (DNS, Winsock, TCP/IP). Règle la plupart des « connecté mais pas d'Internet »."; C = "La connexion va se couper quelques secondes et il faudra redémarrer le PC à la fin.`n`nContinuer ?" },
    @{ T = "Réparer les fichiers de Windows"; P = $true; B = "Réparer"; A = "Repair-System"; D = "Vérifie et répare les fichiers système abîmés (outils officiels DISM + SFC). À faire si Windows bugue, plante ou fait des écrans bleus. 15 à 45 minutes."; C = "La réparation prend 15 à 45 minutes. Laisse le PC branché et le logiciel ouvert.`n`nLancer ?" },
    @{ T = "Vérifier le disque"; B = "Vérifier"; A = "Test-Disk"; D = "Contrôle la santé de tes disques et cherche des erreurs sur le disque de Windows." },
    @{ T = "Débloquer Windows Update"; B = "Débloquer"; A = "Reset-WindowsUpdate"; D = "Si les mises à jour Windows restent bloquées ou échouent en boucle : remet Windows Update à zéro."; C = "Windows Update va être remis à zéro. Un redémarrage sera conseillé ensuite.`n`nContinuer ?" },
    @{ T = "Créer un point de restauration"; B = "Créer"; A = "New-RestorePoint"; D = "Sauvegarde l'état actuel de Windows pour pouvoir revenir en arrière si quelque chose se passe mal plus tard." }) }
 perf = @{ Title = "Performances"; Sub = "Pour un PC qui démarre plus vite et rame moins. Chaque réglage affiche son état actuel et peut être annulé."; Cards = @(
    @{ T = "Programmes au démarrage"; Badge = "Gros gain"; P = $true; B = "Choisir"; UI = 'startup'; StatusFn = { Get-StartupCardStatus }; D = "Choisis appli par appli ce qui se lance tout seul à l'allumage. Garde ce que tu utilises tout le temps (Discord, par exemple), décoche le reste." },
    @{ T = "Mode performances maximales"; B = "Activer"; A = "Set-HighPerformance"; StatusFn = { Get-PerfCardStatus }; D = "Le processeur ne se bride plus pour économiser l'énergie. Idéal pour jouer sur un PC fixe." },
    @{ T = "Effets visuels"; B = "Régler"; A = "Open-VisualEffects"; StatusFn = { Get-FxCardStatus }; D = "Désactive les animations et transparences de Windows. Utile surtout sur les PC un peu anciens." },
    @{ T = "Désinstaller les logiciels inutiles"; B = "Analyser"; UI = 'uninstall'; UiBusy = $true; D = "Repère les logiciels inutiles ou douteux (faux « optimiseurs », barres d'outils, logiciels de pilotes, antivirus en double, applis préinstallées) et t'explique pourquoi. Tous tes logiciels sont listés, du plus gros au plus petit." }) }
 help = @{ Title = "Aide"; Sub = "Tout ce qu'il faut savoir pour utiliser AEROX PC Care sans stress."; Cards = @(
    @{ T = "Aide à distance"; Badge = "Nouveau"; P = $true; B = "J'ai besoin d'aide"; UI = 'remotehelp'; D = "Quelqu'un que tu connais prend la main sur ton PC pour t'aider, avec l'outil gratuit de Microsoft (Assistance rapide). Prépare aussi un rapport de ton PC à lui envoyer." },
    @{ T = "Signaler un bug"; B = "Faire un rapport"; UI = 'report'; D = "Un truc ne marche pas comme prévu ? Envoie un rapport au développeur. Il ne contient ni ton nom, ni tes fichiers, ni tes mots de passe." },
    @{ T = "Historique et annulation"; B = "Voir"; UI = 'history'; D = "Tout ce qu'AEROX PC Care a changé sur ce PC, avec un bouton « Annuler » pour chaque réglage (démarrage, mode d'alimentation...). Et la restauration complète de Windows si besoin." },
    @{ T = "Rechercher une mise à jour d'AEROX PC Care"; B = "Rechercher"; UI = 'checkupdate'; D = "Vérifie si une nouvelle version du logiciel est disponible et l'installe en un clic (tes réglages sont gardés)." },
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
        Add-Child $t (New-Text $(if ($sync.UpdateInfo.Setup) { "Un clic : le logiciel télécharge la nouvelle version, l'installe et se relance tout seul. Tes réglages sont gardés." } else { "Télécharge-la, dézippe-la et remplace l'ancien dossier." }) 13 '#8B93A7')
        Add-Child $g $t; $u.Child = $g; Add-Child $sp $u
    }
    # Bannière santé
    $h = New-CardBorder; $dp = New-Object System.Windows.Controls.DockPanel
    if (-not $script:Diag) {
        $b = New-Button "Lancer le diagnostic" 'PrimaryBtn' @{ Kind = 'startdiag' }; [System.Windows.Controls.DockPanel]::SetDock($b, 'Right'); Add-Child $dp $b
        $t = New-Object System.Windows.Controls.StackPanel; $t.VerticalAlignment = 'Center'
        Add-Child $t (New-Text "Ton PC n'a pas encore été analysé" 15 '#FFFFFF' 'SemiBold')
        Add-Child $t (New-Text "Le diagnostic prend une minute environ et ne modifie rien." 13 '#8B93A7')
        Add-Child $dp $t
    } else {
        $s = Get-Score; $lv = Get-Level $s; $open = Get-OpenIssues
        $b = New-Button "Voir le diagnostic" $(if ($open.Count) { 'PrimaryBtn' } else { 'ActionBtn' }) @{ Kind = 'go'; Def = @{ Go = 'diag' } } $false
        [System.Windows.Controls.DockPanel]::SetDock($b, 'Right'); Add-Child $dp $b
        $ring = New-Ring $s 64; $ring.Margin = Th 0 0 18 0; [System.Windows.Controls.DockPanel]::SetDock($ring, 'Left'); Add-Child $dp $ring
        $t = New-Object System.Windows.Controls.StackPanel; $t.VerticalAlignment = 'Center'
        Add-Child $t (New-Text $lv.Text 15 $lv.Color 'SemiBold')
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
        Add-Child $s2 (New-Text $st.L.ToUpper() 11 '#6B7389' 'Bold')
        $v = New-Text $st.V 16 $st.C 'SemiBold'; $v.Margin = Th 0 6 0 0; Add-Child $s2 $v
        $x = New-Text $st.S 12 '#8B93A7'; $x.Margin = Th 0 2 0 0; Add-Child $s2 $x
        $b.Child = $s2; Add-Child $tiles $b
    }
    Add-Child $sp $tiles
    Add-Child $sp (New-ActionCard @{ T = "Diagnostic complet"; Badge = "Commence ici"; P = $true; B = "Lancer"; Go = 'diag'; D = "Vérifie 10 points (stockage, stabilité, mises à jour, pilotes, sécurité, réseau...) et t'affiche chaque problème avec sa cause et sa réparation." })
    $nCh = @(Get-Changes 300 | Where-Object { $_.Undo -and -not $_.Undone }).Count
    Add-Child $sp (New-ActionCard @{ T = "Historique des changements"; B = "Voir"; UI = 'history'; D = $(if ($nCh) { "$nCh réglage(s) modifié(s) par AEROX PC Care peuvent être annulés en un clic." } else { "Tout ce qu'AEROX PC Care change sur ce PC est noté ici, avec un bouton pour l'annuler." }) })
    Add-Child $sp (New-ActionCard @{ T = "Optimisation rapide"; Badge = "Recommandé"; P = $true; B = "Optimiser"; A = "Start-QuickOptimize"
        D = "En un clic : point de restauration, fichiers temporaires, cache des navigateurs et du DNS, mise à jour des logiciels."
        C = "L'optimisation rapide va :`n`n• créer un point de restauration (sécurité)`n• supprimer les fichiers temporaires`n• vider le cache des navigateurs fermés`n• mettre à jour tes logiciels`n`nFerme tes logiciels ouverts avant. Tes fichiers perso ne sont pas touchés.`n`nOn y va ?" })
    return $sp
}

function Build-DiagPage {
    $sp = New-Object System.Windows.Controls.StackPanel
    Build-Header $sp "Diagnostic" "Vérifie 10 points de ton PC. Pour chaque problème : ce qui se passe, pourquoi, et la réparation en un clic quand c'est possible."
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
    $s = Get-Score; $lv = Get-Level $s; $open = Get-OpenIssues
    $crit = @($open | Where-Object { $_.Sev -eq 'crit' }).Count; $warn = $open.Count - $crit
    $auto = @($open | Where-Object { $_.FixLabel -and -not $_.UiFix -and -not $_.OpenOnly }).Count; $fixed = $script:Diag.Issues.Count - $open.Count
    $sum = New-CardBorder; $sum.Padding = Th 22 18 22 18
    $dp = New-Object System.Windows.Controls.DockPanel
    $btns = New-Object System.Windows.Controls.StackPanel; $btns.VerticalAlignment = 'Center'; [System.Windows.Controls.DockPanel]::SetDock($btns, 'Right')
    if ($auto) { $b = New-Button "Tout réparer ($auto)" 'FixBtn' @{ Kind = 'fixall' }; $b.Margin = Th 0 0 0 8; Add-Child $btns $b }
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
    $d = New-Text ("Analyse du {0}" -f $script:Diag.Date.ToString('dd/MM/yyyy à HH:mm')) 11 '#5D6478'; $d.Margin = Th 0 8 0 0; Add-Child $t $d
    Add-Child $dp $t
    $sum.Child = $dp; Add-Child $sp $sum

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
            if ($x.Detail) { Add-Child $tx (New-Text $x.Detail 12 '#5D6478') }
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
    if ($same) { $Scroll.UpdateLayout(); $Scroll.ScrollToVerticalOffset($offset) } else { $Scroll.ScrollToTop() }
}
function Go-Page([string]$Key) { $nav = $NavMap[$Key]; if ($nav.IsChecked) { Show-Page $Key } else { $nav.IsChecked = $true } }
function Refresh-Page { Show-Page $script:Cur }

function Update-DiagBadge {
    $n = @(Get-OpenIssues).Count
    if ($n -gt 0) { $DiagBadgeText.Text = "$n"; $DiagBadge.Visibility = 'Visible' } else { $DiagBadge.Visibility = 'Collapsed' }
}

function Update-HomeStats {
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
    if ($Busy) { $BusyPanel.Visibility = 'Visible'; $StatusText.Text = "En cours : $Label"; $Progress.IsIndeterminate = $true }
    else { $BusyPanel.Visibility = 'Collapsed' }
}

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
    $script:Job = @{ PS = $ps; RS = $rs; Handle = $ps.BeginInvoke(); Label = $Label; Action = $Action; Start = (Get-Date); OnDone = $OnDone }
    Set-Busy $true $Label
    return $true
}

function Start-Background([string]$Code) {
    $rs = [runspacefactory]::CreateRunspace(); $rs.Open()
    $rs.SessionStateProxy.SetVariable('sync', $sync); $rs.SessionStateProxy.SetVariable('AppInfo', $AppInfo)
    $ps = [powershell]::Create(); $ps.Runspace = $rs; [void]$ps.AddScript($TaskLibrary.ToString() + "`n" + $Code)
    [void]$ps.BeginInvoke()
}

function Complete-Job {
    $job = $script:Job
    try { [void]$job.PS.EndInvoke($job.Handle) } catch { Write-UiLog ("❌ " + $_.Exception.Message); Write-Bug -Context "Tâche $($job.Label)" -ErrorRecord $_ }
    Flush-Queue
    $errs = @($sync.Errors.ToArray())
    $sync.Errors.Clear()
    $dur = '{0:mm\:ss}' -f ((Get-Date) - $job.Start)
    try { $job.PS.Dispose(); $job.RS.Close(); $job.RS.Dispose() } catch {}
    $script:Job = $null
    Write-UiLog $(if ($errs.Count) { "⚠ Terminé avec $($errs.Count) problème(s) : $($job.Label) (durée $dur)" } else { "✅ Terminé : $($job.Label) (durée $dur)" })
    Set-Busy $false

    if ($job.Action -eq 'Invoke-Diagnostic') {
        $script:Scanning = $false
        if ($sync.Diag) { $script:Diag = $sync.Diag; $script:OpenSteps = @{} }
    }
    if ($script:FixingIssue) {
        if ($script:FixingIssue.OpenOnly) {
            $script:FixingIssue.Status = 'open'
            Write-UiLog ("→ Page ouverte pour « {0} ». Une fois fait, relance le diagnostic pour vérifier." -f $script:FixingIssue.Title)
        } else {
            $script:FixingIssue.Status = $(if ($errs.Count) { 'open' } else { 'done' })
            if (-not $errs.Count) { Write-UiLog ("✅ Corrigé : " + $script:FixingIssue.Title) }
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
    if ($job.OnDone -eq 'tools') { Stop-Monitoring; if (Test-MonitorNeeded) { Start-Sensors; Start-FpsCounter } }
    if ($job.OnDone -eq 'undo' -and $script:UndoId) {
        if (-not $errs.Count) { Set-ChangeUndone $script:UndoId; Write-UiLog ("↩ Annulé : " + $script:UndoTitle) }
        $script:UndoId = $null
    }
    Refresh-Page
    if ($errs.Count) { Show-ErrorDialog $errs $job.Label }
    elseif ($job.OnDone -eq 'appdialog' -and $sync.AppList) { Show-AppUpdatesDialog $script:AppsIssue; $script:AppsIssue = $null }
    elseif ($job.OnDone -eq 'cleandialog' -and $sync.CleanList) { Show-CleanDialog $script:CleanIssue; $script:CleanIssue = $null }
    elseif ($job.OnDone -eq 'spacedialog' -and $sync.SpaceScan) { Show-SpaceDialog }
    elseif ($job.OnDone -eq 'driverdialog' -and $sync.DriverScan) { Show-DriverDialog $script:DrvIssue; $script:DrvIssue = $null }
    elseif ($job.OnDone -eq 'uninstalldialog' -and $sync.InstalledApps) { Show-UninstallDialog $script:UniIssue; $script:UniIssue = $null }
    elseif ($job.OnDone -eq 'selfupdate' -and $sync.UpdateReady) { Complete-SelfUpdate; return }
    if ($sync.NeedReboot -and -not $script:Job) {
        $sync.NeedReboot = $false
        $r = [System.Windows.MessageBox]::Show("Un redémarrage est nécessaire pour terminer.`n`nEnregistre ton travail en cours, puis clique sur « Oui » pour redémarrer maintenant.", $AppName, 'YesNo', 'Question')
        if ($r -eq 'Yes') { Restart-Computer -Force }
    }
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
            'done' { $T.Issue.Status = 'done'; Write-UiLog ("✅ Marqué comme fait : " + $T.Issue.Title); Update-DiagBadge; Refresh-Page }
            'openurl' { [void](Open-Url $T.Url) }
            'errfix' { }
            'dlg' { }
            'ui' {
                switch ($T.Def.UI) {
                    'report' { Show-BugReport '' }
                    'remotehelp' { Show-RemoteHelpDialog }
                    'history' { Show-HistoryDialog }
                    'display-fix' { $d = @(Get-Displays) | Where-Object { $_.Device -eq $T.Def.Device } | Select-Object -First 1; Set-DisplayWithConfirm $d $null }
                    'speedtest' { Show-SpeedTestDialog }
                    'sys-refresh' { $sync.SysInfo = $null; Refresh-Page }
                    'bios-site' { Open-BiosSupport }
                    'bios-reboot' { Restart-ToBios }
                    'pc-health' { [void](Open-Url 'https://aka.ms/GetPCHealthCheckApp') }
                    'selfupdate' { Start-SelfUpdate }
                    'ov-alert' { $script:Settings.Overlay.AlertOn = -not [bool]$script:Settings.Overlay.AlertOn; Save-Settings; Refresh-Page }
                    'startup' { Show-StartupDialog $null }
                    'appupdates' { Start-AppUpdatesList $null }
                    'deepclean' { Start-CleanAnalysis $null }
                    'uninstall' { Start-UninstallList $null }
                    'space' { [void](Start-AeroxTask 'Get-SpaceUsage' 'Analyse de l''espace disque' 'spacedialog') }
                    'drivers' { Start-DriverCheck $null }
                    'inst-pm' { [void](Start-AeroxTask 'Install-PresentMon' 'Installation du compteur de FPS' 'tools') }
                    'inst-lhm' { [void](Start-AeroxTask 'Install-SensorLib' 'Installation du module de températures' 'tools') }
                    'inst-pawn' {
                        if (Confirm-Box "Installer le pilote PawnIO ?`n`nC'est un petit pilote signé, utilisé par les logiciels de monitoring connus (LibreHardwareMonitor, FanControl…) pour lire la température du processeur. Il se désinstalle comme un logiciel normal.") {
                            [void](Start-AeroxTask 'Install-PawnIO' 'Installation du pilote PawnIO' 'tools')
                        }
                    }
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
        $d = New-Text ((Format-Date $c.Date 'dd/MM HH:mm') + '   ') 12 '#6B7389'; $d.VerticalAlignment = 'Center'; Add-Child $h $d
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
    if (-not (Test-SafeUndo $c.Undo)) {
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
    Build-Header $sp "Mon PC" "Carte mère, version du BIOS et sécurité du démarrage (TPM, Secure Boot). Juste des infos : rien n'est modifié ici. Pratique avant d'installer Windows 11, un jeu avec anti-triche (Valorant, Battlefield, Call of Duty...) ou un nouveau processeur."
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
        "`nMets à jour le BIOS seulement si tu en as besoin (TPM, Secure Boot, nouveau processeur, plantages), avec le fichier du site officiel uniquement, et sans jamais couper le courant pendant l'opération.") 12 '#6B7389'
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
            $ver = $g.Version + $(if ($g.Date) { "  ·  du " + (Format-Date $g.Date) } else { '' })
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
    $lic = New-Object System.Windows.Controls.TextBlock; $lic.TextWrapping = 'Wrap'; $lic.FontSize = 11.5; $lic.Foreground = Brush '#6B7389'; $lic.Margin = Th 0 0 0 16
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
        Add-Child $st (New-Text $k[1] 11 '#6B7389' 'Bold')
        $v = New-Text '—' 22 '#FFFFFF' 'Bold'; $v.Margin = Th 0 4 0 0; Add-Child $st $v
        $u = New-Text $(if ($k[0] -eq 'ping') { 'ms' } else { 'Mb/s' }) 12 '#8B93A7'; Add-Child $st $u
        $b.Child = $st; Add-Child $grid $b; $cells[$k[0]] = @{ V = $v; U = $u }
    }
    Add-Child $sp $grid
    $info = New-Text "" 12 '#6B7389'; $info.Margin = Th 0 10 0 0; Add-Child $sp $info
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
    $qa = Join-Path $env:SystemRoot 'System32\quickassist.exe'
    if (Test-Path -LiteralPath $qa) { Start-Process $qa; Write-UiLog "Assistance rapide ouverte."; return }
    if (Confirm-Box "Assistance rapide n'est pas encore installée sur ce PC.`n`nC'est l'outil gratuit de Microsoft pour l'aide à distance. L'installer depuis le Microsoft Store ?") {
        Start-Process 'ms-windows-store://pdp/?ProductId=9P7BP5VNWKX5'
    }
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
                    $f = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Rapport AEROX PC Care.txt'
                    try { [IO.File]::WriteAllText($f, $txt, (New-Object System.Text.UTF8Encoding($true))) } catch { $f = $null }
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
    $order = @{ optional = 0; other = 1; mine = 2; keep = 3 }
    $kindOf = { param($e) if ((Get-StartupKind $e) -ne 'keep' -and (Test-StartupKept $e)) { 'mine' } else { Get-StartupKind $e } }
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
        $pill = switch ($kind) { 'optional' { New-Pill 'Pas indispensable' '#B9A8FF' '#2A2350' } 'keep' { New-Pill 'À garder' '#4ADE80' '#173326' } 'mine' { New-Pill 'Validé par toi' '#7DD3FC' '#12303F' } default { $null } }
        if ($pill) { [System.Windows.Controls.DockPanel]::SetDock($pill, 'Right'); Add-Child $dp $pill }
        $cb = New-Object System.Windows.Controls.CheckBox; $cb.IsChecked = [bool]$e.Enabled; $cb.VerticalContentAlignment = 'Center'; $cb.Cursor = 'Hand'
        $txt = New-Object System.Windows.Controls.StackPanel; $txt.Margin = Th 8 0 0 0
        Add-Child $txt (New-Text $e.Name 14 '#FFFFFF' 'SemiBold')
        $cmd = New-Text ($e.Command -replace '"', '') 11 '#6B7389'; $cmd.TextWrapping = 'NoWrap'; $cmd.TextTrimming = 'CharacterEllipsis'; $cmd.MaxWidth = 420; Add-Child $txt $cmd
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
    foreach ($n in Get-SensitiveNames) { $Text = $Text -replace [regex]::Escape($n), '<utilisateur>' }
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
    $note = New-Text "« Copier » : colle le rapport (Ctrl+V) dans un message Discord ou un mail au développeur." 12 '#6B7389'; $note.Margin = Th 0 0 0 10
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
                $title = "[Bug v$AppVersion] " + $(if ($script:RptDesc.Text.Trim()) { ($script:RptDesc.Text.Trim() -split "`r?`n")[0] } else { "Rapport automatique" })
                if ($title.Length -gt 100) { $title = $title.Substring(0, 97) + '...' }
                $payload = @{ title = $title; body = (Build-BugReport $script:RptDesc.Text); version = $AppVersion } | ConvertTo-Json -Compress
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
                $r = Invoke-RestMethod -Uri $sync.BugRelay -Method Post -Body $bytes -ContentType 'application/json; charset=utf-8' -Headers @{ 'X-Aerox' = '1' } -TimeoutSec 20 -ErrorAction Stop
                [System.Windows.Input.Mouse]::OverrideCursor = $null
                Save-ReportDone
                Write-UiLog ("✔ Rapport de bug envoyé" + $(if ($r.number) { " (n°$($r.number))" } else { '' }) + ". Merci !")
                [System.Windows.MessageBox]::Show("Rapport envoyé" + $(if ($r.number) { " (n°$($r.number))" } else { '' }) + ". Merci, ça aide à corriger le logiciel !", $AppName, 'OK', 'Information') | Out-Null
                $script:RptWin.Close()
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
                    $lines = [math]::Floor($lines / 2); $bugs = [math]::Max(3, [math]::Floor($bugs / 2))
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
            $ib = New-DlgButton 'Ignorer' 'TextBtn'; $ib.Tag = $a; $ib.VerticalAlignment = 'Center'
            $ib.Add_Click({ $x = $this.Tag; $x.Ignored = $true; $script:Settings.IgnoredApps = @($script:Settings.IgnoredApps) + $x.Id; Save-Settings; & $script:RenderUpd })
            $r = New-CheckRow $true $txt $ib
            $r.Check.Add_Click({ & $script:CountUpd })
            Add-Child $script:UpdList $r.Row
            [void]$script:UpdRows.Add(@{ App = $a; Check = $r.Check })
        }
        if ($ign.Count) {
            $h = New-Text ("IGNORÉS ({0})" -f $ign.Count) 11.5 '#6B7389' 'Bold'; $h.Margin = Th 2 12 0 8; Add-Child $script:UpdList $h
            foreach ($a in $ign) {
                $row = New-Object System.Windows.Controls.Border; $row.Background = Brush '#13161E'; $row.CornerRadius = Corner 10; $row.Padding = Th 14 9 12 9; $row.Margin = Th 0 0 6 6
                $dp = New-Object System.Windows.Controls.DockPanel
                $ub = New-DlgButton 'Ne plus ignorer' 'TextBtn'; $ub.Tag = $a; [System.Windows.Controls.DockPanel]::SetDock($ub, 'Right'); Add-Child $dp $ub
                $ub.Add_Click({ $x = $this.Tag; $x.Ignored = $false; $script:Settings.IgnoredApps = @($script:Settings.IgnoredApps | Where-Object { $_ -ne $x.Id }); Save-Settings; & $script:RenderUpd })
                $txt = New-Object System.Windows.Controls.StackPanel
                Add-Child $txt (New-Text $a.Name 14 '#8B93A7' 'SemiBold')
                Add-Child $txt (New-Text ("{0}  →  {1}  (ignoré)" -f $a.Version, $a.Available) 12 '#5D6478')
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
        if ($Issue -and -not @($apps | Where-Object { -not $_.Ignored }).Count) { $Issue.Status = 'done'; Write-UiLog "✅ Mises à jour : tout le reste est ignoré à ta demande."; Update-DiagBadge; Refresh-Page }
        return
    }
    if (-not (Confirm-Box ("Mettre à jour $($sel.Count) logiciel(s) ?`n`nFerme-les avant de continuer (regarde aussi les icônes près de l'horloge) : un logiciel ouvert ne peut pas être mis à jour."))) { return }
    $action = "Update-SelectedApps -Ids $(ConvertTo-PsList @($sel | ForEach-Object { $_.Id })) -Names $(ConvertTo-PsList @($sel | ForEach-Object { $_.Name }))"
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
        $st = New-Text $sz 14 $(if ($c.Size -ge 1GB) { '#4ADE80' } elseif ($c.Size -lt 0) { '#6B7389' } else { '#C3CAD9' }) 'SemiBold'
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
            @('TOUS LES AUTRES LOGICIELS (DU PLUS GROS AU PLUS PETIT)', @($vis | Where-Object { -not $_.Tag } | Sort-Object { -$_.Size }), '#6B7389')
        )
        foreach ($g in $groups) {
            if (-not $g[1].Count) { continue }
            $h = New-Text ("{0} ({1})" -f $g[0], $g[1].Count) 11.5 $g[2] 'Bold'; $h.Margin = Th 2 10 0 8; Add-Child $script:UniList $h
            foreach ($a in $g[1]) {
                $b = New-Object System.Windows.Controls.Border; $b.Background = Brush '#171A23'; $b.CornerRadius = Corner 10; $b.Padding = Th 14 10 12 10; $b.Margin = Th 0 0 6 6
                $dp = New-Object System.Windows.Controls.DockPanel
                $btn = New-DlgButton 'Désinstaller' $(if ($a.Tag -eq 'reco') { 'PrimaryBtn' } else { 'ActionBtn' }); $btn.Tag = $a; $btn.VerticalAlignment = 'Center'; $btn.Margin = Th 12 0 0 0
                $btn.Add_Click({ Invoke-UninstallApp $this.Tag })
                [System.Windows.Controls.DockPanel]::SetDock($btn, 'Right'); Add-Child $dp $btn
                if ($a.Location) {
                    $ob = New-DlgButton 'Dossier' 'TextBtn'; $ob.Tag = $a.Location; $ob.VerticalAlignment = 'Center'; $ob.ToolTip = 'Ouvrir le dossier du logiciel'
                    $ob.Add_Click({ Start-Process explorer.exe "`"$($this.Tag)`"" })
                    [System.Windows.Controls.DockPanel]::SetDock($ob, 'Right'); Add-Child $dp $ob
                }
                $t = New-Object System.Windows.Controls.StackPanel
                Add-Child $t (New-Text $a.Name 14 '#FFFFFF' 'SemiBold')
                $meta = @(); if ($a.Drive) { $meta += "Disque $($a.Drive)" }; if ($a.Publisher) { $meta += $a.Publisher }; if ($a.Size -gt 0) { $meta += (Format-Size $a.Size) }; if ($a.Date) { $meta += ("installé le " + $a.Date.ToString('dd/MM/yyyy')) }
                if ($meta.Count) { Add-Child $t (New-Text ($meta -join '  ·  ') 12 '#8B93A7') }
                if ($a.Location) { $lt = New-Text $a.Location 11 '#5D6478'; $lt.FontFamily = 'Cascadia Mono, Consolas'; $lt.TextTrimming = 'CharacterEllipsis'; $lt.TextWrapping = 'NoWrap'; $lt.ToolTip = $a.Location; Add-Child $t $lt }
                elseif ($a.Kind -eq 'win32') { Add-Child $t (New-Text 'Emplacement non indiqué par le logiciel' 11 '#5D6478') }
                if ($a.Reason) { $r = New-Text $a.Reason 12 $(if ($a.Tag -eq 'reco') { '#FFB547' } else { '#B9A8FF' }); $r.Margin = Th 0 3 0 0; Add-Child $t $r }
                Add-Child $dp $t
                $b.Child = $dp; Add-Child $script:UniList $b
            }
        }
        if (-not $vis.Count) { $e = New-Text "Aucun logiciel trouvé." 13 '#8B93A7'; $e.Margin = Th 4 8 0 0; Add-Child $script:UniList $e }
    }
    $search.Add_TextChanged({ $script:UniFilter = $this.Text.Trim(); & $script:RenderUni })
    $bSet.Add_Click({ Start-Process 'ms-settings:appsfeatures' })
    $bClose.Add_Click({ $script:UniWin.Close() })
    & $script:RenderUni
    [void]$w.ShowDialog()
    if ($Issue -and -not @($script:UniApps | Where-Object { $_.Tag -eq 'reco' -and -not $_.Removed }).Count) { $Issue.Status = 'done'; Update-DiagBadge; Refresh-Page }
}

function Invoke-UninstallApp($A) {
    $msg = "Désinstaller « $($A.Name) » ?" + $(if ($A.Kind -eq 'store') { "`n`nL'appli sera retirée tout de suite (elle se réinstalle depuis le Microsoft Store si besoin)." } else { "`n`nLe désinstalleur du logiciel va s'ouvrir : suis ses étapes (attention aux cases « garder mes données » ou aux offres qu'il peut proposer)." })
    if (-not (Confirm-Box $msg)) { return }
    try {
        Uninstall-App $A.Kind $A.Cmd $A.Name
        Add-Change -Kind 'info' -Title ("Désinstallation de « {0} »" -f $A.Name) -Detail $(if ($A.Kind -eq 'store') { "Pour la récupérer : Microsoft Store." } else { "Pour le récupérer : réinstalle-le depuis son site officiel." })
        Write-UiLog ("✔ Désinstallation de « {0} » {1}." -f $A.Name, $(if ($A.Kind -eq 'store') { 'terminée' } else { 'lancée' }))
        $A.Removed = $true
        & $script:RenderUni
    } catch {
        Write-UiLog ("❌ Impossible de désinstaller « {0} » : {1}" -f $A.Name, $_.Exception.Message)
        Write-Bug -Context "Désinstallation $($A.Name)" -ErrorRecord $_ -Type 'erreur'
        [System.Windows.MessageBox]::Show("Impossible de désinstaller « $($A.Name) » ici :`n$($_.Exception.Message)`n`nEssaie depuis Paramètres > Applications.", $AppName, 'OK', 'Warning') | Out-Null
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
    if ($hint) { $h = New-Text ("   " + $hint) 12 '#6B7389'; Add-Child $row $h }
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
    foreach ($l in $scan.Lines) {
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
    $tv = New-Object System.Windows.Controls.TreeView
    $tv.Background = Brush '#0E1016'; $tv.BorderBrush = Brush '#232838'; $tv.Foreground = Brush '#E6E9F2'; $tv.Padding = Th 6 6 6 6; $tv.Height = 470
    $items = @($top | ForEach-Object { @{ P = $_; S = $script:SpaceSizes[$_]; F = $false } }) + @($files | ForEach-Object { @{ P = $_; S = $script:SpaceSizes[$_]; F = $true } })
    $items = @($items | Sort-Object { -$_.S })
    $mx = if ($items.Count) { $items[0].S } else { 1 }
    foreach ($i in $items) { if ($i.S -ge 1MB) { [void]$tv.Items.Add((New-SpaceItem $i.P $i.S $mx $i.F)) } }
    Add-Child $sp $tv
    $row = New-Object System.Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'; $row.HorizontalAlignment = 'Right'; $row.Margin = Th 0 12 0 0
    $bClean = New-DlgButton 'Nettoyage approfondi' 'ActionBtn'; $bClean.Margin = Th 0 0 8 0
    $bApps = New-DlgButton 'Désinstaller des logiciels' 'ActionBtn'; $bApps.Margin = Th 0 0 8 0
    $bClose = New-DlgButton 'Fermer' 'PrimaryBtn'
    Add-Child $row $bApps; Add-Child $row $bClean; Add-Child $row $bClose
    Add-Child $sp $row
    $script:SpaceWin = $w; $script:SpaceNext = $null
    $bClose.Add_Click({ $script:SpaceWin.Close() })
    $bApps.Add_Click({ Start-Process 'ms-settings:appsfeatures' })
    $bClean.Add_Click({ $script:SpaceNext = 'clean'; $script:SpaceWin.Close() })
    $w.Content = $sp
    [void]$w.ShowDialog()
    if ($script:SpaceNext -eq 'clean') { Start-CleanAnalysis $null }
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

function New-DrvSection([string]$Text) { $h = New-Text $Text 11.5 '#6B7389' 'Bold'; $h.Margin = Th 2 14 0 8; return $h }

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
        $info = "Installé : $($g.Version)" + $(if ($g.Date) { " (du " + (Format-Date $g.Date) + ")" } else { '' })
        if ($g.Latest -and $g.Latest.Version) { $info += "   ·   Dernier officiel : $($g.Latest.Version)" + $(if ($g.Latest.Date) { " (du " + (Format-Date $g.Latest.Date) + ")" } else { '' }) }
        Add-Child $txt (New-Text $info 12 '#8B93A7')
        if ($g.Tool -and $g.Status -ne 'ok') { $t = New-Text ("Le plus simple : installe « {0} », il garde le pilote à jour tout seul." -f $g.Tool) 12 '#6B7389'; $t.Margin = Th 0 3 0 0; Add-Child $txt $t }
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
        $r = New-CheckRow $true $txt $null
        $r.Check.Add_Click({ & $script:CountDrv })
        Add-Child $list $r.Row
        [void]$script:DrvRows.Add(@{ U = $u; Check = $r.Check })
    }
    if ($wuDisp.Count) {
        $t = New-Text ("{0} pilote(s) graphique(s) proposé(s) par Windows non affiché(s) : ils sont souvent plus vieux que ceux du fabricant. Pour la carte graphique, utilise le bouton officiel au-dessus." -f $wuDisp.Count) 12 '#6B7389'
        $t.Margin = Th 2 2 0 0; Add-Child $list $t
    }

    # 3. Périphériques en erreur
    if (@($rep.Devices).Count) {
        Add-Child $list (New-DrvSection ("PÉRIPHÉRIQUES AVEC UN PROBLÈME ({0})" -f @($rep.Devices).Count))
        foreach ($d in @($rep.Devices)) { $t = New-Text ("•  {0} — {1}" -f $d.Name, $d.Reason) 13 '#E6E9F2'; $t.Margin = Th 4 0 0 4; Add-Child $list $t }
        $t = New-Text $(if ($wu.Count) { "Installe d'abord les pilotes proposés au-dessus et redémarre : ça règle souvent ces problèmes. Sinon, prends le pilote sur le site du fabricant de ton PC ou de ta carte mère (onglet Mon PC)." } else { "Windows n'a pas de pilote pour eux : prends-le sur le site du fabricant de ton PC ou de ta carte mère (onglet Mon PC > « Chercher sur le site officiel »)." }) 12 '#6B7389'
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
    $bDev.Add_Click({ Start-Process 'devmgmt.msc' })
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
$lhmDir = Join-Path (Join-Path $AppInfo.LogDir 'outils') 'lhm'
$sp = $null
$sync.SensMode = 'basic'; $sync.SensError = ''
if ((Test-Path (Join-Path $lhmDir 'LibreHardwareMonitorLib.dll')) -and $AppInfo.Launcher -and (Test-Path -LiteralPath $AppInfo.Launcher)) {
    $sp = New-Object AeroxSensorProc
    if (-not $sp.Start($AppInfo.Launcher, $lhmDir)) { $sync.SensError = $sp.LastError; $sp = $null }
} elseif (Test-Path (Join-Path $lhmDir 'LibreHardwareMonitorLib.dll')) {
    $sync.SensError = "Lance le logiciel avec le raccourci AEROX PC Care pour avoir les températures."
}
$spWait = 0
$smi = "$env:SystemRoot\System32\nvidia-smi.exe"
if (-not (Test-Path $smi)) { $c = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue; $smi = if ($c) { $c.Source } else { $null } }
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
        if ($c) { $v['cpu.load'] = [math]::Min(100, [double]$c.PercentProcessorUtility) }
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

function Test-MonitorNeeded { return ($script:Cur -eq 'monitor' -or ($script:Ov -and $script:Ov.IsVisible)) }

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

function Build-OverlayContent {
    if (-not $script:Ov) { return }
    $o = $script:Settings.Overlay
    $border = New-Object System.Windows.Controls.Border
    $a = [byte]([math]::Round(255 * [math]::Max(0, [math]::Min(1, [double]$o.Opacity))))
    $border.Background = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromArgb($a, 10, 12, 17))
    $border.CornerRadius = Corner 8; $border.Padding = Th 10 7 12 7
    if ($script:OvEdit) { $border.BorderBrush = Brush '#7C5CFF'; $border.BorderThickness = Th 2 2 2 2 }
    $st = New-Object System.Windows.Media.ScaleTransform([double]$o.Scale, [double]$o.Scale)
    $border.LayoutTransform = $st
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
        $l = New-Object System.Windows.Controls.TextBlock; $l.Text = $r[0]; $l.FontSize = 11; $l.FontWeight = 'Bold'; $l.Foreground = Brush '#9AA3B8'; $l.VerticalAlignment = 'Center'; $l.Margin = Th 0 1 12 1
        $l.FontFamily = 'Segoe UI'
        $val = New-Object System.Windows.Controls.TextBlock; $val.Text = $r[1]; $val.FontSize = $(if ($r[3]) { 20 } else { 14 }); $val.FontWeight = 'Bold'; $val.Foreground = Brush $r[2]; $val.VerticalAlignment = 'Center'
        $val.FontFamily = 'Segoe UI'
        $sh = New-Object System.Windows.Media.Effects.DropShadowEffect; $sh.BlurRadius = 3; $sh.ShadowDepth = 1; $sh.Opacity = 0.9; $sh.Color = [System.Windows.Media.Colors]::Black
        $val.Effect = $sh
        [System.Windows.Controls.Grid]::SetRow($l, $i); [System.Windows.Controls.Grid]::SetRow($val, $i); [System.Windows.Controls.Grid]::SetColumn($val, 1)
        Add-Child $grid $l; Add-Child $grid $val
        [void]$script:OvRows.Add(@{ Val = $val; Lbl = $l })
        $i++
    }
    Add-Child $sp $grid
    if ($script:OvEdit) { $h = New-Text "Glisse pour déplacer · molette : taille" 10 '#B9A8FF'; $h.Margin = Th 0 4 0 0; Add-Child $sp $h }
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
    $w.Add_MouseWheel({ param($s, $e) if ($script:OvEdit) { $n = [double]$script:Settings.Overlay.Scale + $(if ($e.Delta -gt 0) { 0.1 } else { -0.1 }); $script:Settings.Overlay.Scale = [math]::Round([math]::Max(0.5, [math]::Min(3, $n)), 1); Save-Settings; Build-OverlayContent; if ($script:Cur -eq 'monitor' -and $script:MonUi -and $script:MonUi.Scale) { $script:MonUi.Scale.Value = $script:Settings.Overlay.Scale * 100 } } })
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
    Add-Child $sp (New-Text $Label 11 '#6B7389' 'Bold')
    $name = New-Text '' 12 '#8B93A7'; $name.TextTrimming = 'CharacterEllipsis'; $name.TextWrapping = 'NoWrap'; $name.Margin = Th 0 2 0 0; Add-Child $sp $name
    $big = New-Text '—' 26 '#FFFFFF' 'Bold'; $big.Margin = Th 0 6 0 0; Add-Child $sp $big
    $l1 = New-Text '' 13 '#C3CAD9'; $l1.Margin = Th 0 2 0 0; Add-Child $sp $l1
    $l2 = New-Text '' 12 '#8B93A7'; Add-Child $sp $l2
    $b.Child = $sp
    return @{ Box = $b; Name = $name; Big = $big; L1 = $l1; L2 = $l2 }
}
function Update-MonitorUi {
    $u = $script:MonUi; if (-not $u) { return }
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

function New-ToolRow([string]$Title, [string]$Desc, [bool]$Ok, [string]$OkText, [string]$Ui) {
    $row = New-Object System.Windows.Controls.DockPanel; $row.Margin = Th 0 6 0 6
    if ($Ok) { $p = New-Pill $OkText '#4ADE80' '#173326'; [System.Windows.Controls.DockPanel]::SetDock($p, 'Right'); Add-Child $row $p }
    else { $b = New-Button 'Installer' 'ActionBtn' @{ Kind = 'ui'; Def = @{ UI = $Ui } }; $b.Margin = Th 12 0 0 0; [System.Windows.Controls.DockPanel]::SetDock($b, 'Right'); Add-Child $row $b }
    $t = New-Object System.Windows.Controls.StackPanel
    Add-Child $t (New-Text $Title 14 '#FFFFFF' 'SemiBold')
    Add-Child $t (New-Text $Desc 12 '#8B93A7')
    Add-Child $row $t
    return $row
}

function Build-MonitorPage {
    Start-Sensors; Start-FpsCounter
    $script:ToolSt = Get-ToolStatus
    $sp = New-Object System.Windows.Controls.StackPanel
    Build-Header $sp "Moniteur" "Températures, utilisation et FPS en direct. L'overlay affiche ces infos par-dessus tes jeux, à l'endroit et à la taille que tu veux."
    $ug = New-Object System.Windows.Controls.Primitives.UniformGrid; $ug.Columns = 4
    $u = @{ Cpu = (New-MonTile 'PROCESSEUR'); Gpu = (New-MonTile 'CARTE GRAPHIQUE'); Ram = (New-MonTile 'MÉMOIRE'); Fps = (New-MonTile 'FPS') }
    foreach ($k in 'Cpu', 'Gpu', 'Ram', 'Fps') { Add-Child $ug $u[$k].Box }
    Add-Child $sp $ug
    if ($sync.SensError) { $e = New-Text ("Capteurs : " + $sync.SensError) 12 '#FFB547'; $e.Margin = Th 0 0 0 8; Add-Child $sp $e }

    # Composants
    Add-Child $sp (New-Section 'Composants de mesure')
    $c = New-CardBorder; $cs = New-Object System.Windows.Controls.StackPanel
    $st = $script:ToolSt
    Add-Child $cs (New-ToolRow "Températures et capteurs (LibreHardwareMonitor)" "Températures CPU / GPU, consommation, fréquences. Logiciel libre reconnu, téléchargé depuis nuget.org (~2 Mo)." $st.Lhm 'Installé' 'inst-lhm')
    Add-Child $cs (New-ToolRow "Température du processeur (pilote PawnIO)" "Pilote signé qui permet de lire la température du processeur en toute sécurité (remplace l'ancien WinRing0 bloqué par Windows)." $st.PawnIO 'Installé' 'inst-pawn')
    Add-Child $cs (New-ToolRow "Compteur de FPS (PresentMon d'Intel)" "Outil officiel d'Intel, installé avec winget (Microsoft). Rien n'est injecté dans les jeux : aucun risque avec les anti-triche." $st.PresentMon 'Installé' 'inst-pm')
    $n = New-Text $(if ($st.Nvsmi -and -not $st.Lhm) { "Sans le module, la carte NVIDIA est quand même lue (température, utilisation) via son pilote." } else { "Téléchargés depuis les sources officielles, uniquement quand tu cliques sur « Installer »." }) 12 '#6B7389'
    $n.Margin = Th 0 6 0 0; Add-Child $cs $n
    $c.Child = $cs; Add-Child $sp $c

    # Overlay
    Add-Child $sp (New-Section 'Overlay en jeu')
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
    $l1 = New-Text 'Taille' 13 '#C3CAD9'; $l1.VerticalAlignment = 'Center'; $l1.Margin = Th 0 0 10 0; Add-Child $sl $l1
    $s1 = New-Object System.Windows.Controls.Slider; $s1.Minimum = 50; $s1.Maximum = 300; $s1.Value = [double]$script:Settings.Overlay.Scale * 100; $s1.Margin = Th 0 0 24 0; $s1.VerticalAlignment = 'Center'
    $s1.Add_ValueChanged({ $script:Settings.Overlay.Scale = [math]::Round($this.Value / 100, 2); Save-Settings; Build-OverlayContent })
    [System.Windows.Controls.Grid]::SetColumn($s1, 1); Add-Child $sl $s1
    $l2 = New-Text 'Fond' 13 '#C3CAD9'; $l2.VerticalAlignment = 'Center'; $l2.Margin = Th 0 0 10 0; [System.Windows.Controls.Grid]::SetColumn($l2, 2); Add-Child $sl $l2
    $s2 = New-Object System.Windows.Controls.Slider; $s2.Minimum = 0; $s2.Maximum = 100; $s2.Value = [double]$script:Settings.Overlay.Opacity * 100; $s2.VerticalAlignment = 'Center'
    $s2.Add_ValueChanged({ $script:Settings.Overlay.Opacity = [math]::Round($this.Value / 100, 2); Save-Settings; Build-OverlayContent })
    [System.Windows.Controls.Grid]::SetColumn($s2, 3); Add-Child $sl $s2
    Add-Child $os $sl
    # Alerte surchauffe
    $ah = New-Object System.Windows.Controls.DockPanel; $ah.Margin = Th 0 14 0 4
    $ab = New-Button $(if ($script:Settings.Overlay.AlertOn) { 'Activée' } else { 'Désactivée' }) $(if ($script:Settings.Overlay.AlertOn) { 'FixBtn' } else { 'ActionBtn' }) @{ Kind = 'ui'; Def = @{ UI = 'ov-alert' } } $false
    [System.Windows.Controls.DockPanel]::SetDock($ab, 'Right'); Add-Child $ah $ab
    $at = New-Object System.Windows.Controls.StackPanel
    Add-Child $at (New-Text "Alerte surchauffe" 12 '#C3CAD9' 'SemiBold')
    Add-Child $at (New-Text "Au-dessus du seuil, la ligne clignote en rouge dans l'overlay (et c'est noté dans le journal)." 12 '#6B7389')
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
    $an = New-Text "Repères : un processeur en jeu tourne souvent entre 60 et 85 °C (certains Ryzen 7000 et Intel récents montent à 95 °C par conception). Une carte graphique entre 60 et 80 °C." 11.5 '#6B7389'
    $an.Margin = Th 0 6 0 0; Add-Child $os $an
    $hk = if ($script:HotkeyText) { "Raccourci : $($script:HotkeyText) pour afficher / masquer l'overlay, même en jeu." } else { "Raccourci clavier indisponible (déjà pris par d'autres logiciels) : utilise le bouton ci-dessus." }
    $tip = New-Text ($hk + "`n" +
        "Marche avec les jeux en mode « fenêtré sans bordure » (le réglage par défaut de la plupart des jeux) : en plein écran exclusif, Windows le cache.`n" +
        "En mode placement, glisse l'overlay avec la souris et utilise la molette pour la taille. Sinon les clics passent au travers, il ne gêne pas.") 12 '#6B7389'
    $tip.Margin = Th 0 10 0 0; $tip.LineHeight = 19; Add-Child $os $tip
    $c.Child = $os; Add-Child $sp $c
    $u.Scale = $s1
    $script:MonUi = $u
    Update-LiveData; Update-MonitorUi
    return $sp
}

# Appelé par la boucle de l'interface (toutes les 150 ms)
function Invoke-MonitorTick {
    $hot = [AeroxHotkey]::Presses
    if ($hot -ne $script:OvHotPrev) { $script:OvHotPrev = $hot; Show-Overlay (-not ($script:Ov -and $script:Ov.IsVisible)); if ($script:Cur -eq 'monitor') { Refresh-Page } }
    $script:TickN++
    if ($script:TickN % 6 -ne 0) { return }
    if (Test-MonitorNeeded) {
        $script:MonIdle = 0
        Update-LiveData
        Update-OverheatAlert
        if ($script:Cur -eq 'monitor') { Update-MonitorUi }
        Update-OverlayValues
    } else {
        $script:MonIdle++
        if ($script:MonIdle -eq 20 -and ($script:SensPS -or ($script:Fps -and $script:Fps.Running))) { Stop-Monitoring }
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
    if ($script:Job) {
        $r = [System.Windows.MessageBox]::Show("Une opération est en cours. Quitter quand même ?`n(Mieux vaut attendre la fin, surtout pendant une réparation ou des mises à jour.)", $AppName, 'YesNo', 'Warning')
        if ($r -ne 'Yes') { $e.Cancel = $true; return } else { try { $script:Job.PS.Stop() } catch {} }
    }
    try { Stop-Monitoring } catch {}
    try { [AeroxHotkey]::Unregister() } catch {}
    try { if ($script:Ov) { $script:Ov.Close() } } catch {}
})

# Rafraîchissement : journal, barre de progression, scan en direct, nouvelle version
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(150)
$timer.Add_Tick({
    try {
        Flush-Queue
        try { Invoke-MonitorTick } catch { Write-Bug -Context 'Moniteur' -ErrorRecord $_ }
        if ($script:Job) {
            $p = $sync.Progress
            if ($p -ge 0) { $Progress.IsIndeterminate = $false; $Progress.Value = $p } else { $Progress.IsIndeterminate = $true }
            $ElapsedText.Text = '{0:mm\:ss}' -f ((Get-Date) - $script:Job.Start)
            if ($script:Scanning -and $script:Cur -eq 'diag' -and $sync.ScanVer -ne $script:LastScanVer) { $script:LastScanVer = $sync.ScanVer; Refresh-Page }
            if ($script:Job.Handle.IsCompleted) { Complete-Job }
        }
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
# Fichiers temporaires d'une mise à jour terminée
foreach ($mj in @((Join-Path $LogDir 'maj'), (Join-Path $AppRoot 'maj'))) { try { Get-ChildItem -LiteralPath $mj -Force -ErrorAction Stop | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue } catch {} }
# Version installée : garde le bon numéro dans « Applications installées » après une mise à jour automatique
try {
    $uk = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\AeroxPCCare'
    if ((Test-Path $uk) -and (Get-ItemProperty $uk -ErrorAction Stop).DisplayVersion -ne $AppVersion) { Set-ItemProperty -Path $uk -Name DisplayVersion -Value $AppVersion }
} catch {}
# L'overlay se rouvre seulement une fois la fenêtre principale affichée
$window.Add_ContentRendered({
    Close-Splash
    if ($script:OvStarted) { return }
    $script:OvStarted = $true
    if ($script:Settings.Overlay.Visible) { try { Show-Overlay $true } catch { Write-Bug -Context 'Overlay au démarrage' -ErrorRecord $_ } }
})
Update-HomeStats
$NavHome.IsChecked = $true
$timer.Start()
if ($GitHubRepo) { Start-Background 'Find-AppUpdate; Find-BugRelay' }
Set-SplashStep 95 'Ouverture…'
[void]$window.ShowDialog()
$timer.Stop()
try { Stop-Monitoring } catch {}
