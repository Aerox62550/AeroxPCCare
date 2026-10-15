# =====================================================================
#  Test automatique sur un vrai Windows (GitHub Actions, windows-latest).
#  Injecté à la place de « $window.ShowDialog() » dans une COPIE du script :
#  construit toutes les pages, lance les analyses (lecture seule) et ouvre chaque
#  fenêtre (fermée automatiquement). Rien n'est réparé ni modifié sur le PC de test,
#  sauf le faux profil Chrome créé exprès pour tester le blocage des notifications.
# =====================================================================
$ErrorActionPreference = 'Continue'
$script:SmokeFail = New-Object System.Collections.ArrayList
$script:SmokeBugFile = Join-Path $LogDir 'bugs.jsonl'
$script:SmokeBug0 = 0; if (Test-Path $script:SmokeBugFile) { $script:SmokeBug0 = @(Get-Content $script:SmokeBugFile).Count }
function Confirm-Box([string]$Text) { Write-Host "    (confirmation refusée automatiquement : $($Text.Split("`n")[0]))"; return $false }
# Captures d'écran de chaque page et de chaque fenêtre (pour vérifier le rendu réel à chaque version)
$script:ShotDir = 'C:\aerox\captures'; $script:ShotN = 0
try { New-Item -ItemType Directory -Force -Path $script:ShotDir | Out-Null } catch {}
function Save-Shot($El, [string]$Name, $Bg) {
    try {
        $El.UpdateLayout()
        $w = [math]::Ceiling($El.ActualWidth); $h = [math]::Min(9000, [math]::Ceiling($El.ActualHeight))
        if ($w -lt 10 -or $h -lt 10) { return }
        $dv = New-Object System.Windows.Media.DrawingVisual; $dc = $dv.RenderOpen()
        $r = New-Object System.Windows.Rect(0, 0, $w, $h)
        $dc.DrawRectangle($Bg, $null, $r)
        $vb = New-Object System.Windows.Media.VisualBrush($El); $vb.Stretch = 'None'; $vb.AlignmentX = 'Left'; $vb.AlignmentY = 'Top'
        $dc.DrawRectangle($vb, $null, (New-Object System.Windows.Rect(0, 0, $El.ActualWidth, $El.ActualHeight))); $dc.Close()
        $bmp = New-Object System.Windows.Media.Imaging.RenderTargetBitmap([int]$w, [int]$h, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32); $bmp.Render($dv)
        $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder; $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bmp))
        $script:ShotN++
        $f = Join-Path $script:ShotDir ("{0:00}-{1}.png" -f $script:ShotN, ($Name -replace '[^\w-]+', '_'))
        $fs = [IO.File]::Create($f); $enc.Save($fs); $fs.Close()
    } catch { Write-Host "        (capture $Name impossible : $($_.Exception.Message))" }
}
# Toute fenêtre ouverte est capturée puis fermée dès qu'elle est affichée
[System.Windows.EventManager]::RegisterClassHandler([System.Windows.Window], [System.Windows.FrameworkElement]::LoadedEvent, [System.Windows.RoutedEventHandler]{
    param($s, $e)
    if ($s -eq $window) { return }
    [void]$s.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::ApplicationIdle, [Action[object]]{ param($w) try { if ($w.Content -is [System.Windows.UIElement] -and $w.Title -notlike '*Overlay*') { Save-Shot $w.Content ('fenetre-' + ($w.Title -replace '^.*?:\s*', '')) $w.Background } } catch {}; try { $w.Close() } catch {} }, $s)
})
function Smoke([string]$Name, [scriptblock]$Code) {
    Write-Host ("  … {0}" -f $Name)
    [Console]::Out.Flush()
    try { [IO.File]::AppendAllText('C:\aerox\progress.txt', ("{0:HH:mm:ss} début : {1}`r`n" -f (Get-Date), $Name)) } catch {}
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $before = $sync.Errors.Count
    try { & $Code; $st = 'OK' }
    catch { $st = 'ÉCHEC'; [void]$script:SmokeFail.Add("$Name : $($_.Exception.Message) $($_.InvocationInfo.PositionMessage)") }
    # Lignes du journal
    $line = $null; $warn = @()
    while ($sync.Queue.TryDequeue([ref]$line)) { if ($line -match '⚠|❌|Erreur|erreur') { $warn += $line } }
    $errs = @($sync.Errors.ToArray() | Select-Object -Skip $before)
    Write-Host ("[{0,-5}] {1} ({2:n1} s)" -f $st, $Name, $sw.Elapsed.TotalSeconds)
    try { [IO.File]::AppendAllText('C:\aerox\progress.txt', ("{0:HH:mm:ss} [{1}] {2} ({3:n1} s){4}`r`n" -f (Get-Date), $st, $Name, $sw.Elapsed.TotalSeconds, $(if ($errs.Count) { ' · erreurs : ' + (($errs | ForEach-Object { $_.Title }) -join ' | ') } else { '' }))) } catch {}
    foreach ($w in $warn | Select-Object -First 8) { Write-Host "        journal : $w" }
    foreach ($x in $errs) { Write-Host "        erreur affichée : $($x.Title) | $($x.Cause)" }
}
function Smoke-Page([string]$Key) {
    Smoke "Page $Key" {
        $b0 = $(if (Test-Path $script:SmokeBugFile) { @(Get-Content $script:SmokeBugFile).Count } else { 0 })
        Show-Page $Key
        $b1 = $(if (Test-Path $script:SmokeBugFile) { @(Get-Content $script:SmokeBugFile).Count } else { 0 })
        if ($b1 -gt $b0) { throw ("la page a planté : " + (Get-Content $script:SmokeBugFile -Encoding UTF8 | Select-Object -Last 1)) }
    }
}
Write-Host "== Démarrage : version $AppVersion, portable=$Portable, données=$LogDir"
if ($env:AEROX_SMOKE_PORTABLE) {
    if (-not $Portable -or $LogDir -notlike "*\donnees\*") { Write-Host "ÉCHEC : mode portable non détecté"; exit 1 }
    Write-Host "OK : mode portable détecté, données sur la clé"; exit 0
}
function Get-SmokeMem { $p = Get-Process -Id $PID; return ("mémoire utilisée {0:N0} Mo (privée {1:N0} Mo)" -f ($p.WorkingSet64 / 1MB), ($p.PrivateMemorySize64 / 1MB)) }
function Invoke-Smoke {
    $timer.Stop()
    $script:NoAnim = $true   # pas d'animation d'apparition : les captures doivent montrer la page entière
    Write-Host ("== Démarrage jusqu'à la fenêtre affichée : {0:N1} s · {1}" -f ((Get-Date) - (Get-Process -Id $PID).StartTime).TotalSeconds, (Get-SmokeMem))
    Smoke 'Nouveau : place gardée par Windows' { $x = @(Get-WindowsSpaceItems); foreach ($i in $x) { Write-Host ("        {0} ≈ {1}" -f $i.T, (Format-Size $i.S)) } }
    Smoke 'Nouveau : dossiers OneDrive' { @(Get-OneDriveFolders) | ForEach-Object { Write-Host "        $_" } }
    Smoke 'Nouveau : logiciels installés + dernière utilisation' { $a = Get-InstalledApps; $a = @($a); Write-Host ("        {0} logiciels, {1} avec une date d'utilisation" -f $a.Count, @($a | Where-Object { $_.LastUsed }).Count) }
    # ---- Gaming : carnet de performances par jeu (pas de vrai jeu sur la machine de test : parties simulées)
    Smoke 'Gaming : reconnaissance des jeux' {
        $ok = @{ 'C:\Program Files\Epic Games\Fortnite\FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping.exe' = 'Fortnite'; 'C:\Riot Games\VALORANT\live\ShooterGame\Binaries\Win64\VALORANT-Win64-Shipping.exe' = 'VALORANT'; 'D:\SteamLibrary\steamapps\common\Call of Duty HQ\cod.exe' = 'Call of Duty HQ'; 'C:\Program Files (x86)\Overwatch\_retail_\Overwatch.exe' = 'Overwatch' }
        foreach ($p in $ok.Keys) { $g = Get-GameFromPath $p; if (-not $g -or $g.Name -ne $ok[$p]) { throw "jeu non reconnu : $p" } }
        foreach ($p in 'C:\Program Files\Epic Games\Fortnite\FortniteGame\Binaries\Win64\FortniteLauncher.exe', 'C:\Riot Games\Riot Client\RiotClientServices.exe', 'C:\Program Files\Google\Chrome\Application\chrome.exe') { if (Get-GameFromPath $p) { throw "pris pour un jeu à tort : $p" } }
        $fg = [AeroxGame]::Foreground(); Write-Host "        premier plan : $fg"
        $me = [AeroxGame]::ProcessPath($PID)
        if (-not [AeroxGame]::Alive($PID, $me)) { throw "AEROX vu comme fermé" }
        if ([AeroxGame]::Alive($PID, 'C:\autre.exe')) { throw "numéro réutilisé non détecté" }
        if ([AeroxGame]::Alive(999999, '')) { throw "programme inexistant vu comme ouvert" }
        $v = Get-GameVerdict @{ Fps = 300.0; GpuL = 30; CpuL = 15; Core = 60; Cv = 0.12; Med = 297.0; Hz = 144 }; if ($v.Id -ne 'engine') { throw "Roblox-like : verdict $($v.Id) au lieu de engine" }
        $v = Get-GameVerdict @{ Fps = 239.0; GpuL = 30; CpuL = 15; Core = 60; Cv = 0.05; Med = 239.6; Hz = 144 }; if ($v.Id -ne 'cap' -or $v.Cap -ne 240) { throw "FPS bridés à 240 : verdict $($v.Id) $($v.Cap)" }
        $v = Get-GameVerdict @{ Fps = 90.0; GpuL = 55; CpuL = 30; Core = 95; Cv = 0.15; Med = 92.0; Hz = 144 }; if ($v.Id -ne 'cpu') { throw "cœur saturé : verdict $($v.Id)" }
        $v = Get-GameVerdict @{ Fps = 200.0; GpuL = 75; CpuL = 30; Core = 92; Cv = 0.15; Med = 205.0; Hz = 144 }; if ($v.Id -eq 'cpu') { throw "processeur accusé alors que la carte graphique est à 75 %" }
        $v = Get-GameVerdict @{ Fps = 100.0; GpuL = 97; CpuL = 30; Core = 60; Cv = 0.15; Med = 105.0; Hz = 144; N = 20 }; if ($v.Id) { throw "conclusion avec 20 mesures seulement : $($v.Id)" }
        Invoke-GameWatch   # ne doit rien lancer (pas de jeu au premier plan)
        if ($script:GameSess) { throw "partie détectée sans jeu : $($script:GameSess.Name)" }
    }
    Smoke 'Gaming : partie simulée' {
        if (-not $script:Fps) { $script:Fps = New-Object AeroxFps }
        $script:Fps.BeginSession(4242)
        $script:Fps.Feed('Application,ProcessID,SwapChainAddress,Runtime,SyncInterval,PresentFlags,Dropped,TimeInSeconds,msInPresentAPI,msBetweenPresents')
        $rnd = New-Object Random 7
        for ($i = 0; $i -lt 30000; $i++) { $ms = 8 + $rnd.NextDouble(); if ($i % 3000 -eq 2999) { $ms = 70 }; $script:Fps.Feed(("JeuTest.exe,4242,0x0,DXGI,0,0,0,0,0.1,{0}" -f $ms.ToString('F3', [Globalization.CultureInfo]::InvariantCulture))) }
        $fl = New-Object 'System.Collections.Generic.List[double]'; for ($i = 0; $i -lt 300; $i++) { $fl.Add(110 + $rnd.Next(-12, 12)) }
        $script:GameSess = @{ Pid = 4242; Path = 'C:\Jeux\JeuTest\JeuTest.exe'; Name = 'Jeu de test AEROX'; Store = 'Test'; Key = 'jeu-de-test-aerox'; Start = (Get-Date).AddMinutes(-42)
            N = 300; Fps = $fl; CpuL = 40.0 * 300; GpuL = 96.0 * 300; Core = 70.0 * 300; NL = 300; NGpu = 300; NCore = 300; CpuT = 74.0; GpuT = 70.0; GpuHot = 82.0; Vram = 60.0; Ram = 65.0 }
        $sync.GameCtx = @{ Gpu = 'Carte de test'; Driver = '1.0'; Hz = 144; MaxHz = 144 }
        Remove-Item -LiteralPath (Get-GameFile 'jeu-de-test-aerox') -Force -ErrorAction SilentlyContinue
        Stop-GameSession
        $g = Read-GameFile 'jeu-de-test-aerox'
        if (-not $g -or @($g.Sessions).Count -ne 1) { throw "partie non enregistrée" }
        $r = @($g.Sessions)[0]
        Write-Host ("        " + $script:LastGame.Text)
        if ([math]::Abs([double]$r.Fps - 117.3) -gt 2) { throw "FPS moyen faux : $($r.Fps)" }
        if ([int]$r.Stut -lt 8) { throw "saccades non comptées : $($r.Stut)" }
        if ($r.Verdict -ne 'gpu') { throw "verdict faux : $($r.Verdict)" }
        if ($script:LastGame.Text -notmatch 'FPS de moyenne' -or $script:LastGame.Text -notmatch 'carte graphique') { throw "résumé incomplet" }
        if (-not ($script:Tray -and $script:Tray.Visible)) { throw "pas de notification de fin de partie" }
        # Deux autres parties pour la fiche (meilleure / pire, courbe)
        foreach ($x in @(@(92.0, 55, 88, 93), @(124.0, 60, 70, 60))) {
            $S = @{ Start = (Get-Date).AddMinutes(-30); Fps = $fl; CpuL = 50.0; NL = 1; GpuL = [double]$x[1]; NGpu = 1; Core = 92.0; NCore = 1; CpuT = 80.0; GpuT = [double]$x[2]; Ram = [double]$x[3] }
            Save-GameRecord 'jeu-de-test-aerox' 'Jeu de test AEROX' 'C:\Jeux\JeuTest\JeuTest.exe' 'Test' (New-GameRecord $S @(100000, 1800, $x[0], ($x[0] * 0.7), ($x[0] * 0.5), 3) @(100, 110, 90) (Get-Date) @{ Hz = 60; MaxHz = 144 })
        }
        if (@((Read-GameFile 'jeu-de-test-aerox').Sessions).Count -ne 3) { throw "3 parties attendues" }
    }
    Smoke 'Fenêtre : fiche du jeu' { Show-GameDialog 'jeu-de-test-aerox' }
    Smoke 'Gaming : zone de notification' {
        $script:Settings.Gaming.Tray = $true
        try {
            $h = Get-MainHandle
            Write-Host ("        fenêtre ouverte : " + (Get-SmokeMem))
            $window.Close()   # la croix cache AEROX au lieu de le fermer
            if (-not $script:InTray -or [AeroxGame]::Visible($h)) { throw "la croix n'a pas caché AEROX" }
            Optimize-TrayMemory
            if ($PageHost.Children.Count) { throw "la page n'a pas été libérée en mode discret" }
            Show-Page 'diag'; if ($PageHost.Children.Count) { throw "une page a été construite alors qu'AEROX est caché" }
            Write-Host ("        caché près de l'horloge : " + (Get-SmokeMem))
            $ev = [System.Threading.EventWaitHandle]::OpenExisting('Local\AeroxPCCare_Ouvrir'); [void]$ev.Set(); $ev.Close()
            if (-not $script:ShowEvent.WaitOne(0)) { throw "le signal de réouverture n'arrive pas" }
            Show-MainWindow 'monitor'
            if ($script:InTray -or -not [AeroxGame]::Visible($h)) { throw "AEROX ne se réaffiche pas" }
            if (-not $PageHost.Children.Count -or $script:Cur -ne 'monitor') { throw "la page n'est pas reconstruite à la réouverture" }
        } finally { $script:Settings.Gaming.Tray = $false; $script:InTray = $false; Update-TrayIcon }
    }
    # ---- Points relevés par une relecture externe (Gemini), corrigés en 2.1.1
    Smoke 'Désinstallation : confirmée seulement quand le logiciel a disparu' {
        $script:UniApps = @(@{ Name = 'Logiciel parti'; Key = 'HKCU:\Software\AeroxTestNExistePas'; Pending = $true }, @{ Name = 'Logiciel resté'; Key = 'HKCU:\Software'; Pending = $true })
        [void](Update-UninstallPending)
        if (-not $script:UniApps[0].Removed -or $script:UniApps[1].Removed -or -not $script:UniApps[1].Pending) { throw "état après vérification incorrect" }
        [void](Update-UninstallPending $true)
        if ($script:UniApps[1].Pending -or -not $script:UniApps[1].NotRemoved -or $script:UniApps[1].Removed) { throw "logiciel toujours installé non signalé" }
        $apps = Get-InstalledApps; $k = @(@($apps) | Where-Object { $_.Kind -eq 'win32' -and $_.Key }).Count
        if (-not $k) { throw "les logiciels n'ont pas leur clé de registre" }
        Write-Host "        $k logiciels avec leur clé de désinstallation"
    }
    Smoke 'OneDrive : ce qui est gardé sur le PC n est pas touché' {
        $d = Join-Path $env:TEMP 'aerox-onedrive-test'; Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path (Join-Path $d 'sous') | Out-Null
        'a' | Set-Content (Join-Path $d 'a.txt'); 'b' | Set-Content (Join-Path $d 'sous\b.txt')
        $c = [AeroxFiles]::SetOnlineOnly($d); Write-Host ("        en ligne : {0}, gardés : {1} (disque sans OneDrive : rien de spécial attendu)" -f $c[0], $c[1])
        Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue
        $threw = $false; if (-not (Get-Process OneDrive -ErrorAction SilentlyContinue)) { try { Set-OneDriveOnlineOnly 'C:\pas-onedrive' } catch { $threw = $true } }
        else { $threw = $true }
        if (-not $threw) { throw "accepté sans OneDrive" }
    }
    Smoke 'Nettoyage Windows : pas deux nettoyages en même temps' { if (-not (Wait-WindowsCleanup)) { throw "voie bloquée alors qu'aucun nettoyage ne tourne" } }
    Smoke 'Envoi au relais sans figer la fenêtre' {
        $script:RelayRes = $null
        Send-RelayAsync 'https://127.0.0.1:9/test' ([System.Text.Encoding]::UTF8.GetBytes('{}')) { param($r) $script:RelayRes = $r }
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while (-not $script:RelayRes -and $sw.Elapsed.TotalSeconds -lt 30) { $window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::ContextIdle); Start-Sleep -Milliseconds 100 }
        if (-not $script:RelayRes) { throw "pas de réponse en 30 s" }
        if ($script:RelayRes.Ok) { throw "un envoi impossible a été vu comme réussi" }
        Write-Host ("        erreur bien remontée : {0}" -f $script:RelayRes.Err)
    }
    foreach ($k in 'home', 'clean', 'update', 'repair', 'perf', 'help', 'monitor') { Smoke-Page $k }
    foreach ($t in 'live', 'overlay', 'jeux') { $script:GameTab = $t; Smoke-Page 'monitor' }
    Smoke 'Infos système' { Get-SystemInfo }
    Smoke-Page 'system'
    Smoke 'Diagnostic complet' { Invoke-Diagnostic; $script:Diag = $sync.Diag; $script:OpenSteps = @{}; Update-Bilan }
    if ($script:Diag) { foreach ($i in $script:Diag.Issues) { Write-Host ("        problème : [{0}] {1} — {2}" -f $i.Cat, $i.Title, $i.Detail) } }
    Smoke-Page 'diag'
    Smoke-Page 'home'
    # Faux profil Chrome : vérifie le blocage des notifications sur un vrai Windows
    $chrome = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data\Default'
    New-Item -ItemType Directory -Force -Path $chrome | Out-Null
    $pref = '{"profile":{"content_settings":{"exceptions":{"notifications":{"https://captcha-robot.xyz:443,*":{"last_modified":"1","setting":1},"https://www.youtube.com:443,*":{"setting":1}}}}},"homepage":"http://search.pirate-xyz.top/","homepage_is_newtabpage":false,"intl":{"accept_languages":"fr-FR,fr,é"}}'
    [IO.File]::WriteAllText((Join-Path $chrome 'Preferences'), $pref, (New-Object Text.UTF8Encoding($false)))
    Smoke 'Navigateurs : analyse' { Get-BrowserReport; foreach ($x in $sync.BrowserReport.Items) { Write-Host ("        {0} bad={1} {2} | {3}" -f $x.Type, $x.Bad, $x.Label, $x.Detail) } }
    Smoke 'Navigateurs : fenêtre' { Show-BrowserDialog $null }
    Smoke 'Navigateurs : blocage' {
        $fix = @($sync.BrowserReport.Items | Where-Object { $_.Type -eq 'notif' -and $_.Check } | ForEach-Object { $_.Fix })
        if ($fix.Count -ne 1) { throw "1 site suspect attendu, $($fix.Count) trouvé(s)" }
        Repair-BrowserItems -Items $fix
        $j = [IO.File]::ReadAllText((Join-Path $chrome 'Preferences'))
        if ($j -ne $pref.Replace('"last_modified":"1","setting":1', '"last_modified":"1","setting":2')) { throw "fichier Preferences inattendu : $j" }
        Write-Host "        Preferences modifié au bon endroit uniquement (é conservé)"
    }
    Smoke 'Programmes en fond' { Get-BgItems }
    Smoke 'Fenêtre : programmes en fond' { Show-BgDialog $null }
    Smoke 'Fenêtre : démarrage' { Show-StartupDialog $null }
    Smoke 'Fenêtre : aide à distance' { Show-RemoteHelpDialog }
    Smoke 'Lenteurs (20 s)' { Get-SlowReport }
    Smoke 'Fenêtre : lenteurs' { Show-SlowDialog }
    Smoke 'Analyse du nettoyage' { Get-CleanupAnalysis }
    Smoke 'Fenêtre : nettoyage' { Show-CleanDialog $null }
    Smoke 'Logiciels installés' { Get-InstalledAppsAdvice }
    Smoke 'Fenêtre : logiciels' { Show-UninstallDialog $null }
    # Doublons : 2 copies d'une même « photo » dans Documents et Téléchargements
    $docs = Get-SessionFolder 'Personal'; $dls = Get-SessionFolder 'Downloads'
    New-Item -ItemType Directory -Force -Path $docs, $dls | Out-Null
    $bytes = New-Object byte[] 2500000; (New-Object Random 42).NextBytes($bytes)
    [IO.File]::WriteAllBytes((Join-Path $docs 'vacances.jpg'), $bytes); [IO.File]::WriteAllBytes((Join-Path $dls 'vacances (1).jpg'), $bytes)
    Smoke 'Doublons' {
        Get-Duplicates
        $g = @($sync.Dupes.Groups | Where-Object { @($_ | Where-Object { $_.Path -like '*vacances*' }).Count -eq 2 })
        if ($g.Count -ne 1) { throw "doublon de test non trouvé ($(@($sync.Dupes.Groups).Count) groupe(s))" }
    }
    Smoke 'Fenêtre : doublons' { Show-DuplicatesDialog }
    Smoke 'Espace disque' { Get-SpaceUsage 'C:'; foreach ($x in @($sync.SpaceScan.Win)) { Write-Host ("        Windows : {0} ≈ {1} (coché={2})" -f $x.T, (Format-Size $x.S), $x.Check) }; foreach ($x in @($sync.SpaceScan.Forgotten | Select-Object -First 5)) { if ($x.Name -isnot [string]) { throw "liste des logiciels oubliés mal construite" }; Write-Host ("        oublié : {0} {1}" -f $x.Name, (Format-Size $x.Size)) } }
    Smoke 'Fenêtre : espace disque' { Show-SpaceDialog }
    Smoke 'Bilan avant/après' { $s = Get-PcSnapshot; Write-Host ("        démarrage={0}s, démarrage auto={1}, fond={2}" -f $s.BootSec, $s.Startup, $s.Procs) }
    Smoke 'Annulations autorisées' {
        $ok = @("Set-BgItem 'task' '\X\' 'Y' 'on'", "Restore-RegBackup 'C:\x.reg'", "Set-CpuMaxState 100")
        $ko = @("Set-BgItem 'task' '\X\' 'Y' 'off'", "Remove-Item C:\ -Recurse", "Restore-RegBackup (Get-Item x)", "Set-CpuMaxState 100; Remove-Item x")
        foreach ($c in $ok) { if (-not (Test-SafeUndo $c)) { throw "refusé à tort : $c" } }
        foreach ($c in $ko) { if (Test-SafeUndo $c) { throw "accepté à tort : $c" } }
    }
    Smoke 'Fenêtre : quoi de neuf' { Show-WhatsNew '1.6.0'; Show-WhatsNew '' }
    Smoke 'Fenêtre : avis' { Show-ReviewDialog; Write-Host ("        invitation sur l'accueil : {0}" -f (Test-ReviewInvite)) }
    Smoke 'Rapport de bug' { $r = Build-BugReport 'test' 20 5; if ($r.Length -lt 100) { throw 'rapport vide' } }
    Smoke 'Captures des pages' {
        Show-Page 'home'; Save-Shot $window.Content 'fenetre-complete' $window.Background
        foreach ($k in 'home', 'diag', 'clean', 'update', 'repair', 'perf', 'system', 'help') { Show-Page $k; Save-Shot $PageHost ("page-" + $k) $window.Background }
        foreach ($t in 'jeux', 'live', 'overlay') { $script:GameTab = $t; Show-Page 'home'; Show-Page 'monitor'; Save-Shot $PageHost ("page-gaming-" + $t) $window.Background }
        Write-Host ("        {0} captures" -f @(Get-ChildItem $script:ShotDir -Filter *.png -ErrorAction SilentlyContinue).Count)
    }
}

# Actions réelles : uniquement sur la machine de test jetable de GitHub (AEROX_SMOKE_ACTIONS=1)
function Invoke-SmokeActions {
    Write-Host ''
    Write-Host '== Actions (machine de test jetable)'
    Smoke 'Fichiers temporaires' { Clear-TempFiles }
    Smoke 'Nettoyage approfondi (sélection conseillée)' {
        $ids = @($sync.CleanList | Where-Object { $_.Default -and $_.Id -notmatch '^(components|resetbase|winold|hiber|windows)$' } | ForEach-Object { $_.Id })
        Write-Host "        catégories : $($ids -join ', ')"
        Invoke-DeepClean -Ids $ids
    }
    Smoke 'Corbeille' { Clear-RecycleBinAll }
    Smoke 'Place gardée par Windows' {
        $ids = @($sync.SpaceScan.Win | Where-Object { $_.Id -ne 'compact' } | ForEach-Object { if ($_.Arg) { "{0}:{1}" -f $_.Id, $_.Arg } else { $_.Id } })
        Write-Host "        éléments : $($ids -join ', ')"
        if ($ids.Count) { Invoke-WindowsSpace -Items $ids }
    }
    Smoke 'Gaming : lancement avec Windows' {
        $AeroxLauncher = Join-Path $AppRoot 'AeroxPCCare.exe'   # le test tourne sans le lanceur
        Set-AutoStart $true
        $t = Get-ScheduledTask -TaskName $script:AutoTaskName -ErrorAction Stop
        if ("$(@($t.Actions)[0].Arguments)" -ne '--discret' -or "$($t.Principal.RunLevel)" -ne 'Highest') { throw "tâche mal créée : $(@($t.Actions)[0].Arguments) / $($t.Principal.RunLevel)" }
        Set-AutoStart $false
        if (Test-AutoStart) { throw "tâche toujours là" }
        Write-Host '        créée puis retirée : OK'
    }
    Smoke 'Mode performances' { Set-HighPerformance; Set-BalancedPower }
    Smoke 'Assistant stockage' { Enable-StorageSense; if (-not (Get-StorageSenseOn)) { throw 'pas activé' }; Disable-StorageSense }
    Smoke 'Puissance du processeur' { Set-CpuMaxState 90 }
    Smoke 'Vérification après réparation' {
        # Problème créé exprès (processeur bridé à 90 %), vérifié présent, réparé, puis vérifié réglé
        $q = $null; while ($sync.Verify.TryDequeue([ref]$q)) {}
        Test-IssueGone 'Performances' 'cpumax'; [void]$sync.Verify.TryDequeue([ref]$q)
        if ($q -notlike 'cpumax|still|*') { throw "le problème créé exprès n'est pas détecté : $q" }
        Set-CpuMaxState 100
        Test-IssueGone 'Performances' 'cpumax'; [void]$sync.Verify.TryDequeue([ref]$q)
        if ($q -notlike 'cpumax|gone|*') { throw "après réparation, le problème est encore vu : $q" }
        Write-Host '        détecté avant, réglé après : OK'
        Set-CpuMaxState 90   # remis pour tester ensuite l'annulation depuis l'historique
    }
    Smoke 'Programme au démarrage' {
        $e = @(Get-StartupEntries | Where-Object { $_.Enabled }) | Select-Object -First 1
        if ($e) { Set-StartupApps -Disable @($e.Id); if (@(Get-StartupEntries | Where-Object { $_.Id -eq $e.Id -and -not $_.Enabled }).Count -ne 1) { throw "« $($e.Name) » toujours actif" } } else { Write-Host '        (aucun programme au démarrage)' }
    }
    Smoke 'Programme caché en fond' {
        $x = @($sync.BgItems | Where-Object { $_.Verdict -ne 'keep' -and $_.Kind -eq 'task' }) | Select-Object -First 1
        if ($x) { Disable-BgItems -Items @(("{0}|{1}|{2}|{3}" -f $x.Kind, $x.Path, $x.Name, $x.Name)) } else { Write-Host '        (aucune tâche à couper)' }
    }
    Smoke 'Dépannage : son' { Repair-Sound }
    Smoke 'Dépannage : micro' { Repair-Microphone }
    Smoke 'Dépannage : webcam' { Repair-Webcam }
    Smoke 'Dépannage : imprimante' { Repair-Printing }
    Smoke 'Dépannage : bureau figé' { Restart-Shell }
    Smoke 'Test de connexion' { Test-Internet }
    Smoke 'Point de restauration' { New-RestorePoint }
    Smoke 'Annulations depuis l historique' {
        $n = 0
        foreach ($c in @(Get-Changes | Where-Object { $_.Undo })) {
            if (-not (Test-SafeUndo $c.Undo)) { throw "annulation refusée : $($c.Undo)" }
            $script:AeroxUndo = $true
            try { Invoke-Expression $c.Undo } finally { $script:AeroxUndo = $false }
            $n++; Write-Host "        annulé : $($c.Title)"
        }
        if (-not $n) { throw 'aucune annulation trouvée dans l historique' }
        $e = @(Get-StartupEntries | Where-Object { -not $_.Enabled })
        if ($e.Count) { Write-Host ("        encore désactivés au démarrage : " + (($e | ForEach-Object { $_.Name }) -join ', ')) }
    }
}
# Bilan
function Complete-Smoke {
    # Seuls les vrais bugs comptent (type « bug ») : les erreurs expliquées à l'utilisateur (pas de son, pas d'imprimante… sur la machine de test) sont normales
    $bugs = @(); if (Test-Path $script:SmokeBugFile) { $bugs = @(Get-Content $script:SmokeBugFile -Encoding UTF8 | Select-Object -Skip $script:SmokeBug0 | Where-Object { $_ -notmatch '"type":"erreur"' }) }
    Write-Host ''
    Write-Host "== Bugs enregistrés par le logiciel pendant le test : $($bugs.Count)"
    foreach ($b in $bugs) { Write-Host "   $b" }
    Write-Host "== Échecs : $($script:SmokeFail.Count)"
    foreach ($f in $script:SmokeFail) { Write-Host "   $f" }
    $script:SmokeExit = $(if ($script:SmokeFail.Count -or $bugs.Count) { 1 } else { 0 })
}
$script:SmokeExit = 2
$window.Add_ContentRendered({
    try { Invoke-Smoke; if ($env:AEROX_SMOKE_ACTIONS) { Invoke-SmokeActions } } catch { [void]$script:SmokeFail.Add("Test interrompu : $($_.Exception.Message) $($_.InvocationInfo.PositionMessage)") }
    Complete-Smoke
    $window.Close()
})
[void]$window.ShowDialog()
exit $script:SmokeExit
