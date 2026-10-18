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
    Smoke 'Sauvegarde de réglages : contenu vérifié avant de la remettre' {
        $d = Join-Path $LogDir 'sauvegardes\navigateurs'; New-Item -ItemType Directory -Force -Path $d | Out-Null
        $ok = Join-Path $d 'test_ok.reg'; $ko = Join-Path $d 'test_ko.reg'
        [IO.File]::WriteAllText($ok, "Windows Registry Editor Version 5.00`r`n`r`n[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Google\Chrome]`r`n`"HomepageLocation`"=`"https://exemple.fr`"`r`n", [Text.Encoding]::Unicode)
        [IO.File]::WriteAllText($ko, "Windows Registry Editor Version 5.00`r`n`r`n[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Google\Chrome]`r`n`r`n[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run]`r`n`"Piege`"=`"C:\\piege.exe`"`r`n", [Text.Encoding]::Unicode)
        if (-not (Test-RegBackupSafe $ok)) { throw "vraie sauvegarde refusée" }
        if (Test-RegBackupSafe $ko) { throw "sauvegarde piégée acceptée" }
        $threw = $false; try { Restore-RegBackup $ko } catch { $threw = $true }
        if (-not $threw) { throw "sauvegarde piégée importée" }
        if (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name Piege -ErrorAction SilentlyContinue) { throw "valeur piégée écrite dans le registre" }
        Remove-Item $ok, $ko -Force
        $a = New-SessionShortcutPath '.lnk'; $b = New-SessionShortcutPath '.lnk'; if ($a -eq $b) { throw "nom de raccourci prévisible" }
    }
    # ---- 2.1.3 : grand ménage sécurité (chaque correction a son contrôle)
    Smoke 'Sécurité : suppression jamais à travers un lien' {
        $base = Join-Path $env:TEMP ('aerox-lien-' + [guid]::NewGuid().ToString('N'))
        $vict = Join-Path $base 'a-proteger'; $clean = Join-Path $base 'a-nettoyer'
        New-Item -ItemType Directory -Force -Path $vict, (Join-Path $clean 'sous') | Out-Null
        'garder' | Set-Content (Join-Path $vict 'sentinelle.txt')
        'x' | Set-Content (Join-Path $clean 'jeter.txt'); 'y' | Set-Content (Join-Path $clean 'sous\jeter2.txt')
        New-Item -ItemType Junction -Path (Join-Path $clean 'piege') -Target $vict | Out-Null
        $freed = Remove-PathContent $clean
        if (-not (Test-Path (Join-Path $vict 'sentinelle.txt'))) { throw "un fichier a été supprimé à travers une jonction" }
        if ((Test-Path (Join-Path $clean 'jeter.txt')) -or (Test-Path (Join-Path $clean 'sous\jeter2.txt'))) { throw "le nettoyage normal n'a pas marché" }
        # Dossier à nettoyer qui est lui-même un lien : rien n'est touché
        $j2 = Join-Path $base 'temp-piege'; New-Item -ItemType Junction -Path $j2 -Target $vict | Out-Null
        $null = Remove-PathContent $j2
        if (-not (Test-Path (Join-Path $vict 'sentinelle.txt'))) { throw "dossier-lien nettoyé" }
        # Fichier atteint par un chemin qui passe par un lien : refusé
        if ([AeroxSafeDelete]::IsDirectPath((Join-Path $j2 'sentinelle.txt'))) { throw "chemin par une jonction vu comme direct" }
        if (-not [AeroxSafeDelete]::IsDirectPath((Join-Path $vict 'sentinelle.txt'))) { throw "chemin direct refusé" }
        $null = Remove-ItemSafe (Get-Item (Join-Path $j2 'sentinelle.txt'))
        if (-not (Test-Path (Join-Path $vict 'sentinelle.txt'))) { throw "fichier supprimé par un chemin passant par une jonction" }
        Write-Host ("        {0} octets libérés, fichier protégé intact" -f $freed)
        [IO.Directory]::Delete((Join-Path $clean 'piege'), $false); [IO.Directory]::Delete($j2, $false); Remove-Item $base -Recurse -Force
    }
    Smoke 'Sécurité : outils et sauvegardes dans un dossier protégé' {
        $t = Get-ToolsDir
        if ($t -notlike "$env:ProgramFiles\*") { throw "outils hors de Program Files : $t" }
        $bad = @((Get-Acl -LiteralPath $t).Access | Where-Object { "$($_.IdentityReference)" -match '(?i)\\Users$|Utilisateurs$|Authenticated Users|Everyone|Tout le monde' -and $_.AccessControlType -eq 'Allow' -and ("$($_.FileSystemRights)" -match 'Write|Modify|FullControl|CreateFiles|AppendData') })
        if ($bad.Count) { throw "les utilisateurs peuvent écrire dans le dossier protégé : $($bad[0].IdentityReference) $($bad[0].FileSystemRights)" }
        if (@($env:Path -split ';' | Where-Object { $_ -like "$env:SystemDrive\Users\*" }).Count) { throw "PATH avec un dossier perso" }
        if (@($env:PSModulePath -split ';' | Where-Object { $_ -like "$env:SystemDrive\Users\*" }).Count) { throw "modules PowerShell cherchés dans un dossier perso" }
        $threw = $false; try { Open-WinUri 'file:///C:/Windows/System32/calc.exe' } catch { $threw = $true }; if (-not $threw) { throw "lien non autorisé accepté" }
        if (Open-Url 'file:///C:/Windows/System32/calc.exe') { throw "fichier ouvert comme une page web" }
        Write-Host "        dossier protégé : $t"
    }
    Smoke 'Sécurité : annulations scellées' {
        Add-Change -Title 'Test sceau' -Undo 'Set-CpuMaxState 100'
        $c = @(Get-Changes 5 | Where-Object { $_.Title -eq 'Test sceau' })[0]
        if (-not (Test-UndoAuthorized $c.Id $c.Undo)) { throw "annulation notée par AEROX refusée" }
        if (Test-UndoAuthorized 'faux123' "Set-BgItem 'service' '' 'RemoteRegistry' 'auto'") { throw "annulation trafiquée acceptée" }
        if (Test-UndoAuthorized $c.Id "Set-BgItem 'task' '\X\' 'Y' 'on'") { throw "annulation remplacée dans l'historique acceptée" }
    }
    Smoke 'Mises à jour : doublons et logiciels déjà désinstallés' {
        $k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\AeroxTestFantome'
        New-Item -Path $k -Force | Out-Null
        Set-ItemProperty -Path $k -Name DisplayName -Value 'AeroxTestFantome'; Set-ItemProperty -Path $k -Name UninstallString -Value '"C:\Program Files\AeroxTestFantome\unins000.exe"'
        try {
            $l = Add-AppGhostInfo @([ordered]@{ Name = 'AeroxTestFantome'; Id = 'Test.Fantome'; Version = '1'; Available = '2' }, [ordered]@{ Name = 'AeroxTestFantome'; Id = 'Test.Fantome'; Version = '1'; Available = '2' }, [ordered]@{ Name = 'Inconnu'; Id = 'Test.Autre'; Version = '1'; Available = '2' })
            if (@($l).Count -ne 2) { throw "doublon pas retiré ($(@($l).Count))" }
            if (-not $l[0].Ghost) { throw "logiciel déjà désinstallé pas repéré" }
            if ($l[1].Ghost) { throw "logiciel inconnu pris pour une trace" }
        } finally { Remove-Item -Path $k -Force -ErrorAction SilentlyContinue }
    }
    Smoke 'Mises à jour : logiciels qui se mettent à jour tout seuls' {
        Add-SelfUpdating 'Aerox.TestAuto' '9.9'
        $l = Add-AppGhostInfo @([ordered]@{ Name = 'Aerox Test Auto'; Id = 'Aerox.TestAuto'; Version = '1'; Available = '9.9' }, [ordered]@{ Name = 'Aerox Test Neuf'; Id = 'Aerox.TestNeuf'; Version = '1'; Available = '2' })
        if (-not $l[0].Self) { throw "logiciel qui se met à jour seul encore proposé" }
        if ($l[1].Self) { throw "logiciel normal pris pour un logiciel autonome" }
        $l = Add-AppGhostInfo @([ordered]@{ Name = 'Aerox Test Auto'; Id = 'Aerox.TestAuto'; Version = '1'; Available = '10.0' })
        if ($l[0].Self) { throw "nouvelle version pas reproposée" }
        $f = Get-SelfUpdatingFile; [IO.File]::WriteAllLines($f, [string[]]@(Get-SelfUpdatingKeys | Where-Object { $_ -notlike 'aerox.testauto|*' }))
    }
    Smoke 'Démarrage : désactivation vérifiée et appli qui se remet toute seule' {
        $run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; $ap = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
        if (-not (Test-Path -LiteralPath $run)) { New-Item -Path $run -Force | Out-Null }
        New-ItemProperty -Path $run -Name 'AeroxTestDemarrage' -Value "$env:SystemRoot\notepad.exe" -PropertyType String -Force | Out-Null
        $saveOff = @($AppInfo.StartupOff)
        try {
            $e = @(Get-StartupEntries | Where-Object { $_.ValueName -eq 'AeroxTestDemarrage' })[0]
            if (-not $e -or -not $e.Enabled) { throw "élément de test pas vu comme actif" }
            # Identifiant écrit autrement (clé de la session via HKEY_USERS) : doit désigner le même élément
            $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
            Set-StartupApps -Disable @("Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run|AeroxTestDemarrage")
            $e = @(Get-StartupEntries | Where-Object { $_.ValueName -eq 'AeroxTestDemarrage' })[0]
            if ($e.Enabled) { throw "toujours actif après désactivation" }
            if (@($AppInfo.StartupOff) -notcontains $e.Key) { throw "désactivation pas retenue" }
            # L'appli se remet elle-même au démarrage (comme Discord ou Spotify à leur lancement)
            New-ItemProperty -Path $ap -Name 'AeroxTestDemarrage' -PropertyType Binary -Value ([byte[]](2,0,0,0,0,0,0,0,0,0,0,0)) -Force | Out-Null
            $e = @(Get-StartupEntries | Where-Object { $_.ValueName -eq 'AeroxTestDemarrage' })[0]
            if (-not (Test-StartupBack $e)) { throw "appli revenue toute seule pas repérée" }
            Set-StartupApps -Enable @($e.Id)
            if (@($AppInfo.StartupOff) -contains $e.Key) { throw "réactivée par toi mais encore signalée" }
            Write-Host "        clé : $($e.Key)"
        } finally {
            Remove-ItemProperty -Path $run -Name 'AeroxTestDemarrage' -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $ap -Name 'AeroxTestDemarrage' -ErrorAction SilentlyContinue
            $AppInfo.StartupOff = $saveOff
        }
    }
    Smoke 'Overlay : fond progressif et texte net à toutes les tailles' {
        $b = New-OverlayBrush 0.5; if ($b.Color.A -lt 120 -or $b.Color.A -gt 135) { throw "fond à 50 % : alpha $($b.Color.A)" }
        if ((New-OverlayBrush 0).Color.A -ne 0 -or (New-OverlayBrush 1).Color.A -ne 255) { throw "bornes du fond fausses" }
        $saveSc = $script:Settings.Overlay.Scale
        try {
            if (-not $script:Ov) { New-OverlayWindow }
            $b = New-OverlayBrush 0.49; $c = New-OverlayBrush 0.51; if ([math]::Abs([int]$c.Color.A - [int]$b.Color.A) -gt 8) { throw "saut du fond entre 49 et 51 % : $($b.Color.A) → $($c.Color.A)" }
            $script:Settings.Overlay.Scale = 2.5; Build-OverlayContent
            $fs = @($script:OvRows | ForEach-Object { $_.Lbl.FontSize })[0]; if ($fs -ne [math]::Round(11 * 2.5)) { throw "taille 250 % pas appliquée (texte $fs px)" }
            foreach ($sc in 0.5, 0.85, 1.0, 1.35, 2.2, 3.0) {
                $script:Settings.Overlay.Scale = $sc; Build-OverlayContent
                if ($script:OvBorder.LayoutTransform -and -not $script:OvBorder.LayoutTransform.Value.IsIdentity) { throw "overlay agrandi après coup à $sc (flou)" }
                foreach ($r in $script:OvRows) { foreach ($t in $r.Val, $r.Lbl) { if ($t.FontSize -ne [math]::Round($t.FontSize)) { throw "taille de texte non entière à $sc : $($t.FontSize)" } } }
            }
            $script:OvBorder.Background = New-OverlayBrush 0.2
        } finally { $script:Settings.Overlay.Scale = $saveSc; Build-OverlayContent }
    }
    Smoke 'État du PC : tous les disques' {
        $d = @(Get-DriveList)
        if (-not $d.Count -or $d[0].Id -ne $env:SystemDrive) { throw "disque de Windows absent ou pas en premier" }
        Update-HomeStats
        for ($w = 0; $w -lt 40 -and -not $sync.DrivesNew; $w++) { Start-Sleep -Milliseconds 250 }
        Update-HomeStats -KeepDrives
        Write-Host ("        disques : {0} · tuile : {1} / {2}" -f (($d | ForEach-Object { $_.Id }) -join ' '), $script:Stats.DISK.V, ($script:Stats.DISK.S -replace "`n", ' | '))
        if ($d.Count -gt 1 -and $script:Stats.DISK.S -notmatch [regex]::Escape($d[1].Id)) { throw "2e disque pas affiché sur l'accueil" }
    }
    Smoke 'Espace disque : fichiers de jeu repérés, fichiers perso supprimables' {
        $base = "$env:SystemDrive\aerox-test-espace"
        New-Item -ItemType Directory -Force -Path "$base\Jeux\MonJeu\.egstore\bps", "$base\Jeux\AutreJeu\bin\x64", "$base\Films", "$base\Telechargements" | Out-Null
        [IO.File]::WriteAllText("$base\Jeux\AutreJeu\AutreJeu.exe", 'x'); [IO.File]::WriteAllText("$base\Jeux\AutreJeu\bin\x64\moteur.exe", 'x')
        [IO.File]::WriteAllText("$base\Telechargements\setup.exe", 'x')
        try {
            $c = @{}
            $k = Get-BigFileKind "$base\Jeux\MonJeu\.egstore\bps\gros.bin" $c
            if ($k.Kind -ne 'program' -or $k.App -ne 'MonJeu') { throw "fichier de jeu Epic pas repéré ($($k.Kind) $($k.App))" }
            $k = Get-BigFileKind "$base\Jeux\AutreJeu\bin\x64\data.pak" $c
            if ($k.Kind -ne 'program' -or $k.App -ne 'AutreJeu') { throw "jeu repéré au mauvais niveau ($($k.App))" }
            if ((Get-BigFileKind "$base\Films\film.mkv" $c).Kind -ne 'user') { throw "vidéo perso prise pour un jeu" }
            if ((Get-BigFileKind "$base\Telechargements\film.mkv" $c).Kind -ne 'user') { throw "vidéo à côté d'un installateur prise pour un jeu" }
            if ((Get-BigFileKind "$env:USERPROFILE\AppData\Local\x.bin" $c).Kind -ne 'system') { throw "fichier d'AppData proposé à la suppression" }
        } finally { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Smoke 'Composants de mesure : désinstallables' {
        $d = Join-Path (Get-ToolsDir) 'lhm'; $dll = Join-Path $d 'LibreHardwareMonitorLib.dll'
        if (Test-Path -LiteralPath $dll) { Write-Host '        (module réel installé : pas touché)'; return }
        New-Item -ItemType Directory -Force -Path $d | Out-Null; [IO.File]::WriteAllText($dll, 'test')
        if (-not (Get-ToolStatus).Lhm) { throw "module de test pas vu comme installé" }
        Uninstall-SensorLib
        if ((Get-ToolStatus).Lhm -or (Test-Path -LiteralPath $d)) { throw "module toujours là après désinstallation" }
        $row = New-ToolRow 'Test' 'Test' $true 'Installé' 'inst-lhm' 'uninst-lhm'
        if (-not @($row.Children | Where-Object { $_ -is [System.Windows.Controls.Button] -and "$($_.Content)" -eq 'Désinstaller' }).Count) { throw "bouton « Désinstaller » absent" }
        Uninstall-PawnIO
    }
    Smoke 'Stabilité : seuls les plantages après la réparation comptent' {
        $save = $AppInfo.StabilityFixAt
        try {
            $AppInfo.StabilityFixAt = @{ crash = (Get-Date).AddHours(-1).ToString('s') }
            $d = Get-StabilitySince 'crash' (Get-Date).AddDays(-7)
            if ([math]::Abs(((Get-Date).AddHours(-1) - $d).TotalMinutes) -gt 2) { throw "date de réparation ignorée ($d)" }
            if ((Get-StabilitySince 'bsod' (Get-Date).AddDays(-30)) -gt (Get-Date).AddDays(-29)) { throw "date d'une autre réparation appliquée aux écrans bleus" }
            $script:Issues = New-Object System.Collections.ArrayList; $script:OkList = New-Object System.Collections.ArrayList; $script:IgnoredList = New-Object System.Collections.ArrayList
            Test-Stability
            Write-Host ("        stabilité : {0} problème(s), OK : {1}" -f $script:Issues.Count, ($script:OkList -join ' | '))
        } finally { $AppInfo.StabilityFixAt = $save }
        $gd = Get-GpuDriverInstallDates
        Write-Host ("        pilotes graphiques installés : {0}" -f (($gd.Keys | ForEach-Object { "{0} le {1:dd/MM/yyyy HH:mm}" -f $_, $gd[$_] }) -join ' · '))
    }
    Smoke 'Écrans bleus : pilote en cause lu dans le rapport de plantage' {
        # Faux petit rapport de plantage (même structure qu'un vrai) : un pilote NVIDIA sur la pile et dans les paramètres
        $b = New-Object byte[] 0x20000
        $put32 = { param($o, $v) [BitConverter]::GetBytes([uint32]$v).CopyTo($b, $o) }
        $put64 = { param($o, $v) [BitConverter]::GetBytes([uint64]$v).CopyTo($b, $o) }
        [Text.Encoding]::ASCII.GetBytes('PAGEDU64').CopyTo($b, 0); & $put32 0x38 0xD1; & $put64 0x58 ([Convert]::ToUInt64('FFFFF80090001234', 16)); & $put32 0xF98 4
        $drv = @(@('ntoskrnl.exe', [Convert]::ToUInt64('FFFFF80000000000', 16), 0x1000000), @('hal.dll', [Convert]::ToUInt64('FFFFF80001000000', 16), 0x100000)) + @(0..11 | ForEach-Object { , @("pilote$_.sys", ([Convert]::ToUInt64('FFFFF80010000000', 16) + [uint64]$_ * 0x100000), 0x80000) }) + @(, @('nvlddmkm.sys', [Convert]::ToUInt64('FFFFF80090000000', 16), 0x4000000))
        $pool = 0x8000
        for ($i = 0; $i -lt $drv.Count; $i++) {
            $e = 0x3000 + $i * 0x98; & $put32 $e $pool; & $put64 ($e + 0x38) $drv[$i][1]; & $put32 ($e + 0x48) $drv[$i][2]
            $n = [Text.Encoding]::Unicode.GetBytes($drv[$i][0]); & $put32 $pool $drv[$i][0].Length; $n.CopyTo($b, $pool + 4); $pool += 8 + $n.Length
        }
        & $put64 0x10008 ([Convert]::ToUInt64('FFFFF80000000100', 16)); & $put64 0x10010 ([Convert]::ToUInt64('FFFFF80090002000', 16))
        & $put32 0x2028 0x10000; & $put32 0x202C 0x100; & $put32 0x2030 0x3000; & $put32 0x2034 $drv.Count
        $f = Join-Path $env:TEMP 'aerox-test.dmp'; [IO.File]::WriteAllBytes($f, $b)
        $r = [AeroxDump]::Analyze($f); Remove-Item -LiteralPath $f -Force
        Write-Host "        analyse : $r"
        if ($r -notlike '0x000000D1|*|nvlddmkm.sys|ntoskrnl.exe,nvlddmkm.sys') { throw "pilote en cause pas retrouvé" }
        $bad = Join-Path $env:TEMP 'aerox-faux.dmp'; [IO.File]::WriteAllBytes($bad, (New-Object byte[] 0x4000)); if ([AeroxDump]::Analyze($bad)) { throw "fichier quelconque pris pour un rapport" }; Remove-Item -LiteralPath $bad -Force
        $an = Get-BsodAnalysis (Get-Date).AddDays(-30)
        Write-Host ("        ce PC : {0} rapport(s), erreurs matérielles {1}, XMP « {2} »" -f @($an.Dumps).Count, $an.Whea, $an.Xmp)
        $k = Get-DriverFileInfo 'ntoskrnl.exe' @{}; if (-not $k.Ms) { throw "noyau de Windows pas reconnu comme Microsoft ($($k.Company))" }
    }
    if (-not $Portable) {
        Smoke 'Sécurité : données dans le dossier protégé, anciennes données reprises' {
            if (-not $LogDir.StartsWith($AppInfo.Secure, [StringComparison]::OrdinalIgnoreCase)) { throw "données hors du dossier protégé : $LogDir" }
            if (-not (Test-Path -LiteralPath (Join-Path $LogDir 'jeux\reprise-test.json'))) { throw "anciennes données pas reprises" }
            if (Test-Path -LiteralPath (Join-Path $LogDir 'lien-piege')) { throw "lien de l'ancien dossier suivi pendant la reprise" }
            Write-Host "        données : $LogDir"
        }
    }
    Smoke 'Sécurité : signature des outils téléchargés (Authenticode)' {
        if (-not [AeroxTrust]::IsSignedBy("$env:SystemRoot\System32\notepad.exe", 'Microsoft Corporation') -and -not [AeroxTrust]::IsSignedBy("$env:SystemRoot\explorer.exe", 'Microsoft Corporation')) { throw "programme de Microsoft pas reconnu comme signé" }
        $t = Join-Path $env:TEMP 'aerox-faux.exe'; [IO.File]::WriteAllText($t, 'MZ'); $ok = [AeroxTrust]::IsSignedBy($t, 'Microsoft Corporation'); Remove-Item $t -Force
        if ($ok) { throw "faux programme accepté" }
        # Le vrai speedtest.exe d'Ookla : signé ? (sinon le test de débit passera toujours par Cloudflare)
        try {
            $d = Join-Path $env:TEMP 'aerox-ookla'; New-Item -ItemType Directory -Force $d | Out-Null
            Invoke-WebRequest -Uri ([AeroxSpeed]::OoklaZip) -OutFile "$d\o.zip" -UseBasicParsing -TimeoutSec 30
            Expand-Archive "$d\o.zip" $d -Force
            $sg = Get-AuthenticodeSignature "$d\speedtest.exe"
            Write-Host ("        speedtest.exe : {0} · {1} · SHA-256 {2} · accepté par AEROX : {3}" -f $sg.Status, $sg.SignerCertificate.Subject, (Get-FileHash "$d\speedtest.exe" -Algorithm SHA256).Hash, [AeroxSpeed]::IsTrustedOokla("$d\speedtest.exe"))
            $okla = [AeroxSpeed]::IsTrustedOokla("$d\speedtest.exe")
            $fake = "$d\faux.exe"; Copy-Item "$env:SystemRoot\System32\whoami.exe" $fake -Force
            $fk = [AeroxSpeed]::IsTrustedOokla($fake)
        } catch { Write-Host "        speedtest.exe : non testé ($($_.Exception.Message))"; $okla = $true; $fk = $false }
        if (-not $okla) { throw "le vrai programme d'Ookla est refusé : le test de débit passerait toujours par Cloudflare" }
        if ($fk) { throw "un autre programme est accepté comme celui d'Ookla" }
    }
    Smoke 'SFC : résultat lu dans le journal de Windows (toutes langues)' {
        $f = Join-Path $env:TEMP 'aerox-cbs.log'; $t = Get-Date
        [IO.File]::WriteAllLines($f, [string[]]@(("{0:yyyy-MM-dd HH:mm:ss}, Info CSI 01 [SR] Verify complete" -f $t.AddSeconds(5)), ("{0:yyyy-MM-dd HH:mm:ss}, Info CSI 02 [SR] Repairing 0 components" -f $t.AddSeconds(6)), ("{0:yyyy-MM-dd HH:mm:ss}, Info CSI 03 [SR] Repair complete" -f $t.AddSeconds(7))))
        $r1 = Get-SfcResultFromCbs $t $f
        Add-Content $f ("{0:yyyy-MM-dd HH:mm:ss}, Info CSI 04 [SR] Cannot repair member file x" -f $t.AddSeconds(8))
        $r2 = Get-SfcResultFromCbs $t $f; Remove-Item $f -Force
        if ($r1 -ne 'clean' -or $r2 -ne 'unrepaired') { throw "lecture fausse : $r1 / $r2" }
    }
    Smoke 'Liens Steam et rapport de batterie' {
        if ((Get-Command Open-WinUri).Definition -notmatch '\|steam\)') { throw "liens Steam toujours refusés" }
        if (Open-LocalFile "$env:SystemRoot\win.ini") { throw "fichier hors du dossier protégé ouvert" }
    }
    Smoke 'Hosts verrouillé (lecture seule) : déverrouillé puis réparé' {
        $f = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'; $orig = [IO.File]::ReadAllLines($f)
        try {
            [IO.File]::WriteAllLines($f, [string[]]@($orig + '0.0.0.0 discord.com'))
            (Get-Item $f -Force).Attributes = 'ReadOnly'
            Repair-Hosts
            if (@(Get-HostsHijacks).Count) { throw "discord.com toujours détourné" }
        } finally { (Get-Item $f -Force).Attributes = 'Normal'; [IO.File]::WriteAllLines($f, [string[]]$orig) }
    }
    Smoke 'Sécurité : raccourcis de session dans le dossier protégé' {
        $p = New-SessionShortcutPath '.lnk'
        if (-not $p.StartsWith((Join-Path $AppInfo.Secure 'session'), [StringComparison]::OrdinalIgnoreCase)) { throw "raccourci hors du dossier protégé : $p" }
    }
    Smoke 'Avis : gros mots masqués' {
        $r = Hide-Profanity "Super logiciel (j'aime la chatte), putain de console, conseil pour Bitcoin"
        Write-Host "        $r"
        if ($r -ne "Super logiciel (j'aime la c*****), p***** de console, conseil pour Bitcoin") { throw "masquage faux" }
    }
    Smoke 'Analyses approfondies : démarrage, figements, disques' {
        $e = @(Get-WinEvent -LogName System -MaxEvents 1)[0]; $f = Get-EventFields $e; Write-Host ("        champs d'un événement : {0}" -f (@($f.Keys) -join ', '))
        $script:Issues = New-Object System.Collections.ArrayList; $script:OkList = New-Object System.Collections.ArrayList; $script:IgnoredList = New-Object System.Collections.ArrayList
        Test-BootSpeed; Test-Stability; Test-DiskHealth
        Write-Host ("        problèmes : {0} · OK : {1}" -f (($script:Issues | ForEach-Object { $_.Id }) -join ', '), ($script:OkList -join ' | '))
    }
    Smoke 'Réseau : ce qui bloque des sites ou des téléchargements' {
        $f = Join-Path $env:TEMP 'aerox-hosts-test'
        [IO.File]::WriteAllLines($f, [string[]]@('# commentaire', '127.0.0.1 localhost', '0.0.0.0 discord.com', '0.0.0.0 vortex.data.microsoft.com', '1.2.3.4 www.google.fr  # pirate', '0.0.0.0 downloads.exemple.org'))
        $h = @(Get-HostsHijacks $f); Remove-Item -LiteralPath $f -Force
        Write-Host ("        hosts détournés : {0}" -f (($h | ForEach-Object { $_.Host }) -join ', '))
        if (($h | ForEach-Object { $_.Host }) -join ',' -ne 'discord.com,www.google.fr') { throw "lecture du fichier hosts fausse" }
        $ok = Test-SiteReachable 'https://discord.com/'; $ko = Test-SiteReachable 'https://aerox-site-qui-n-existe-pas.invalid/'
        Write-Host "        discord.com : $ok · site inexistant : $ko"
        if ($ok -ne 'ok' -or $ko -eq 'ok') { throw "test de site joignable faux" }
        $sk = Get-ClockSkew; Write-Host "        décalage de l'heure : $sk s"
        $script:Issues = New-Object System.Collections.ArrayList; $script:OkList = New-Object System.Collections.ArrayList; $script:IgnoredList = New-Object System.Collections.ArrayList
        Test-NetBlockers; Write-Host ("        problèmes : {0} · OK : {1}" -f (($script:Issues | ForEach-Object { $_.Id }) -join ', '), ($script:OkList -join ' | '))
    }
    Smoke 'Dépannage : Discord' { Repair-Discord }
    Smoke 'BIOS : page du fabricant vérifiée avant ouverture' {
        $sync.SysInfo = $null; Find-BiosPage; $si = $sync.SysInfo
        if (-not $si) { throw "infos du PC non chargées" }
        if ("$($si.Model)$($si.Maker)".Trim()) { if (-not $sync.BiosUrl -or $sync.BiosUrl.Url -notmatch '^https://') { throw "aucune adresse" } }
        elseif ($sync.BiosUrl) { throw "recherche lancée alors que Windows ne connaît pas le modèle" }
        Write-Host ("        ce PC : « {0} » « {1} » → {2}" -f $si.Maker, $si.Model, $(if ($sync.BiosUrl) { "$($sync.BiosUrl.Kind) $($sync.BiosUrl.Url)" } else { 'pas de recherche (modèle inconnu)' }))
        # Les adresses devinées pour quelques cartes mères connues (information : un site peut bloquer les robots)
        $tests = @(
            @('ASUS', 'https://www.asus.com/supportonly/ROG%20STRIX%20B550-F%20GAMING/helpdesk_bios/', 'ROG STRIX B550-F GAMING'),
            @('MSI', 'https://www.msi.com/Motherboard/MAG-B550-TOMAHAWK/support', 'MAG B550 TOMAHAWK'),
            @('Gigabyte', 'https://www.gigabyte.com/fr/Motherboard/B550-AORUS-ELITE-V2-rev-10/support', 'B550 AORUS ELITE V2'),
            @('Gigabyte sans rév.', 'https://www.gigabyte.com/fr/Motherboard/B550-AORUS-ELITE-V2/support', 'B550 AORUS ELITE V2'),
            @('ASRock', 'https://www.asrock.com/mb/AMD/B550%20Phantom%20Gaming%204/index.fr.asp', 'B550 Phantom Gaming 4'),
            @('ASUS recherche', 'https://www.asus.com/fr/searchresult?searchType=support&searchKey=ROG%20STRIX%20B550-F%20GAMING', ''),
            @('MSI recherche', 'https://www.msi.com/search/MAG%20B550%20TOMAHAWK', ''),
            @('Gigabyte recherche', 'https://www.gigabyte.com/fr/Search?kw=B550%20AORUS%20ELITE%20V2', '')
        )
        foreach ($t in $tests) { Write-Host ("        {0} : {1}" -f $t[0], $(if (Test-WebPageHas $t[1] @($t[2] | Where-Object { $_ })) { 'OK' } else { 'refusé ou introuvable' })) }
    }
    Smoke 'Désinstallation : désinstalleur disparu expliqué' {
        try { Uninstall-App 'win32' '"C:\Program Files\AeroxRienDuTout\unins000.exe" /SILENT' 'Logiciel test'; throw "pas d'erreur" }
        catch { if ($_.Exception.Message -notlike 'Le désinstalleur de*') { throw "message pas clair : $($_.Exception.Message)" } }
    }
    Smoke 'Gaming : saccades par heure sur le temps vraiment joué' {
        $f = @(Get-GameFlags @{ Min = 60.0; Act = 10.0; Stut = 8 })
        if ($f -notcontains 'stutter') { throw "8 saccades en 10 min de jeu (50 min d'Alt+Tab) non signalées" }
        $f = @(Get-GameFlags @{ Min = 60.0; Act = 60.0; Stut = 8 })
        if ($f -contains 'stutter') { throw "8 saccades en 1 h signalées à tort" }
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
    Smoke 'Lenteurs : ce qui a été vérifié' {
        $r = $sync.SlowReport
        if (-not $r -or -not @($r.Checked).Count) { throw "pas de liste de vérifications" }
        Write-Host ("        {0}" -f ((@($r.Checked) | ForEach-Object { $(if ($_.Ok) { 'OK ' } else { '!! ' }) + $_.T }) -join ' | '))
        Write-Host ("        pistes : {0} · carte graphique mesurée : {1} ({2} %) · bridage : {3} · interruptions : {4} %" -f ((@($r.Findings) | ForEach-Object { $_.Id }) -join ', '), $r.GpuOk, $r.Gpu, $r.Limit, $r.Dpc)
        # Aucune piste réseau inventée quand le ping ne répond pas (machine de test dans le cloud)
        if (-not $r.Net.Ok -and @($r.Findings | Where-Object { $_.Id -in 'internet-pertes', 'ping-instable' }).Count) { throw "piste réseau sans mesure" }
        foreach ($x in @($r.Findings)) { if (-not $x.Id -or -not $x.Title) { throw "piste sans identifiant" } }
    }
    Smoke 'Lag : règles de la connexion (cas fabriqués)' {
        $ok = @{ Ok = $true; Loss = 0.0; Avg = 3.0; Jitter = 1.0; Max = 5.0 }; $off = @{ Ok = $false; Loss = 0.0; Avg = 0.0; Jitter = 0.0; Max = 0.0 }
        $none = @{ Signal = -1; Band = '' }
        $ids = { param($l) (@($l) | ForEach-Object { $_.Id }) -join ',' }
        $c = & $ids (Get-NetFindings @{ Ok = $true; Loss = 8.0; Avg = 25.0; Jitter = 30.0; Max = 300.0 } @{ Ok = $true; Loss = 9.0; Avg = 60.0; Jitter = 35.0; Max = 400.0 } 0 0 $true @{ Signal = 45; Band = '2.4' })
        if ($c -ne 'wifi-instable') { throw "Wi-Fi instable mal reconnu : $c" }
        $c = & $ids (Get-NetFindings $ok @{ Ok = $true; Loss = 6.0; Avg = 30.0; Jitter = 5.0; Max = 90.0 } 0 0 $false $none)
        if ($c -ne 'internet-pertes') { throw "pertes de la ligne mal reconnues : $c" }
        $c = & $ids (Get-NetFindings $ok @{ Ok = $true; Loss = 0.0; Avg = 95.0; Jitter = 40.0; Max = 300.0 } (8MB) 0 $false $none)
        if ($c -ne 'ping-instable,connexion-occupee') { throw "ping + téléchargement mal reconnus : $c" }
        $c = & $ids (Get-NetFindings $off $off 0 0 $false $none)
        if ($c) { throw "piste inventée sans mesure : $c" }
        $c = & $ids (Get-NetFindings $ok $ok 0 0 $true @{ Signal = 85; Band = '5' })
        if ($c) { throw "piste sur une connexion saine : $c" }
        $c = & $ids (Get-NetFindings $ok $ok 0 0 $true @{ Signal = 35; Band = '2.4' })
        if ($c -ne 'wifi-faible') { throw "Wi-Fi faible mal reconnu : $c" }
        # Calculs du ping : pertes, moyenne, irrégularité
        $s = New-PingSeries '10.0.0.1'; $s.Ok = 8; $s.Lost = 2; foreach ($t in 10, 12, 10, 30, 10, 10, 11, 10) { [void]$s.Times.Add([double]$t) }
        $st = Get-PingStats $s
        if ($st.Loss -ne 20 -or $st.Avg -ne 12.9 -or $st.Jitter -ne 6.6) { throw "calcul faux : $($st.Loss) % · $($st.Avg) ms · ±$($st.Jitter)" }
        # Une adresse qui ne répond pas est abandonnée après 3 essais (jamais comptée comme des pertes)
        $b = New-PingSeries '192.0.2.1'; $pg = New-Object System.Net.NetworkInformation.Ping; for ($i = 0; $i -lt 6; $i++) { Add-PingSample $b $pg }
        if (-not $b.Off -or $b.Lost -ne 3 -or (Get-PingStats $b).Ok) { throw "adresse muette pas abandonnée ($($b.Lost) essais)" }
    }
    Smoke 'Lag : analyse de la connexion (10 s)' {
        Get-LagReport -Seconds 10
        if (-not $sync.SlowReport -or $sync.SlowReport.Mode -ne 'lag') { throw "pas de rapport" }
        Write-Host ("        {0} · pistes : {1}" -f ((@($sync.SlowReport.Checked) | ForEach-Object { $_.T }) -join ' | '), ((@($sync.SlowReport.Findings) | ForEach-Object { $_.Id }) -join ', '))
    }
    Smoke 'Fenêtre : lag' { Show-SlowDialog }
    Smoke 'Mesure pendant un jeu (attente + 20 s)' {
        Get-SlowReport -Delay 1 -Mode jeu
        if (-not $sync.SlowReport -or $sync.SlowReport.Mode -ne 'jeu') { throw "pas de rapport en mode jeu" }
    }
    Smoke 'Fenêtre : mesure en jeu' { Show-SlowDialog }
    Smoke 'Discord : seule une vraie invitation est acceptée' {
        foreach ($x in @(@('https://discord.gg/AbC123', $true), @('https://discord.com/invite/aerox-pc', $true), @('https://discord.gg.pirate.com/x', $false), @('http://discord.gg/abc', $false),
                         @('https://discord.gg/abc?x=1', $false), @('https://discord.gg/', $false), @('https://evil.com/discord.gg/abc', $false), @("https://discord.gg/abc`nhttps://evil.com", $false))) {
            if ((Test-DiscordInvite $x[0]) -ne $x[1]) { throw "« $($x[0]) » : $(-not $x[1]) au lieu de $($x[1])" }
        }
        Find-DiscordLink; Write-Host "        lien publié : « $($sync.DiscordUrl) »"
        if ($sync.DiscordUrl -and -not (Test-DiscordInvite $sync.DiscordUrl)) { throw "lien invalide gardé" }
    }
    Smoke 'Statistiques anonymes : filtre, désactivation et envoi (faux relais local)' {
        $oldOff = $AppInfo.StatsOff; $oldRelay = $sync.BugRelay; $oldQ = $AppInfo.StatsQueue
        $stamp = Join-Path $AppInfo.LogDir 'stats-envoi.txt'; Remove-Item -LiteralPath $stamp -ErrorAction SilentlyContinue
        $serve = {
            param($port, $out, [bool]$old)
            $l = New-Object System.Net.HttpListener; $l.Prefixes.Add("http://localhost:$port/"); $l.Start()
            try {
                for ($i = 0; $i -lt 2; $i++) {
                    $ar = $l.BeginGetContext($null, $null); if (-not $ar.AsyncWaitHandle.WaitOne(8000)) { break }
                    $c = $l.EndGetContext($ar); $body = ''
                    if ($c.Request.HasEntityBody) { $sr = New-Object IO.StreamReader($c.Request.InputStream, [Text.Encoding]::UTF8); $body = $sr.ReadToEnd() }
                    [void]$out.Add(@{ M = $c.Request.HttpMethod; P = $c.Request.Url.AbsolutePath; H = "$($c.Request.Headers['X-Aerox'])"; B = $body })
                    $txt = if ($c.Request.HttpMethod -ne 'GET') { '{"ok":true}' } elseif ($old) { 'AEROX PC Care : relais des rapports de bug et des avis.' } else { '{"aerox":"stats","ok":true}' }
                    $bytes = [Text.Encoding]::UTF8.GetBytes($txt); $c.Response.ContentType = $(if ($old -and $c.Request.HttpMethod -eq 'GET') { 'text/plain' } else { 'application/json' })
                    $c.Response.ContentLength64 = $bytes.Length
                    $c.Response.OutputStream.Write($bytes, 0, $bytes.Length); $c.Response.OutputStream.Close(); $c.Response.Close()
                }
                Start-Sleep -Milliseconds 1500   # laisse le logiciel lire la dernière réponse avant de fermer
            } finally { $l.Stop() }
        }
        $run = {
            param([bool]$old)
            $port = Get-Random -Minimum 20000 -Maximum 40000
            $got = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
            $ps = [powershell]::Create(); [void]$ps.AddScript($serve).AddArgument($port).AddArgument($got).AddArgument($old)
            $h = $ps.BeginInvoke(); Start-Sleep -Milliseconds 700
            $sync.BugRelay = "http://localhost:$port"
            Send-Stats -Force
            [void]$h.AsyncWaitHandle.WaitOne(10000); try { $ps.Dispose() } catch {}
            return ,@($got.ToArray())
        }
        try {
            $AppInfo.StatsQueue = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
            $AppInfo.StatsOff = $true; Add-StatsEvent 'lent:rien'
            if ($AppInfo.StatsQueue.Count) { throw "compteur gardé alors que les statistiques sont désactivées" }
            $AppInfo.StatsOff = $false
            foreach ($k in 'lent:rien', 'lent:rien', ('probleme:' + (ConvertTo-StatsId 'diskD:')), 'Mauvaise clé', 'x:../../etc', 'nom:Jean Dupont', 'pc:PC-DE-JEAN', 'Lent:rien') { Add-StatsEvent $k }
            $q = (@($AppInfo.StatsQueue.ToArray()) -join ',')
            if ($q -cne 'lent:rien,lent:rien,probleme:diskd') { throw "filtre faux : $q" }
            # Ancien relais (pas encore mis à jour) : il ne sait pas recevoir → rien n'est envoyé, les compteurs attendent
            $g = & $run $true
            if (@($g).Count -ne 1 -or $g[0].M -ne 'GET') { throw "envoyé à un relais qui ne sait pas recevoir ($(@($g).Count) requête(s))" }
            if ($AppInfo.StatsQueue.Count -lt 3) { throw "compteurs perdus" }
            # Relais à jour : un seul envoi, rien de personnel dedans
            $n0 = $AppInfo.StatsQueue.Count
            $g = & $run $false
            if (@($g).Count -ne 2 -or $g[1].M -ne 'POST' -or $g[1].P -ne '/stats' -or $g[1].H -ne '1') { throw "envoi incorrect ($(@($g).Count) requête(s))" }
            $b = $g[1].B | ConvertFrom-Json
            if ($b.ev.'lent:rien' -ne 2 -or $b.ev.'probleme:diskd' -ne 1 -or $b.nouveau_mois -ne $true -or $b.v -ne $AppVersion) { throw "contenu faux : $($g[1].B)" }
            foreach ($bad in @($env:COMPUTERNAME, $env:USERNAME, $AppInfo.LogDir) | Where-Object { "$_".Length -ge 3 }) { if ($g[1].B -like "*$bad*") { throw "donnée personnelle dans l'envoi" } }
            if ($AppInfo.StatsQueue.Count -or -not (Test-Path -LiteralPath $stamp)) { throw "file non vidée après l'envoi ($($AppInfo.StatsQueue.Count) restant(s), erreur : $($AppInfo.StatsLastError))" }
            Write-Host ("        envoyé ({0} compteur(s)) : {1}" -f $n0, $g[1].B)
        } finally { $AppInfo.StatsOff = $oldOff; $sync.BugRelay = $oldRelay; $AppInfo.StatsQueue = $oldQ; Remove-Item -LiteralPath $stamp -ErrorAction SilentlyContinue }
    }
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
    Smoke 'Bilan avant/après' {
        $s = Get-PcSnapshot; Write-Host ("        démarrage={0}s, démarrage auto={1}, fond={2}, autres disques={3}" -f $s.BootSec, $s.Startup, $s.Procs, (@($s.Drives.Keys) -join ' '))
        $r = ConvertTo-Hash ($s | ConvertTo-Json -Depth 4 | ConvertFrom-Json)
        if (@(Get-DriveList).Count -gt 1 -and -not ($r.Drives -is [hashtable] -and $r.Drives.Count)) { throw "autres disques absents du bilan enregistré" }
    }
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
    Smoke 'Corbeille' {
        # Un fichier à la corbeille de la personne + un faux dossier d'un autre compte (jamais touché)
        Add-Type -AssemblyName Microsoft.VisualBasic
        $f = Join-Path $env:TEMP 'aerox-corbeille-test.bin'; [IO.File]::WriteAllBytes($f, (New-Object byte[] (3MB)))
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($f, 'OnlyErrorDialogs', 'SendToRecycleBin')
        $other = "$env:SystemDrive\`$Recycle.Bin\S-1-5-21-1111111111-2222222222-3333333333-1999"
        New-Item -ItemType Directory -Force -Path $other | Out-Null; [IO.File]::WriteAllBytes((Join-Path $other 'autre.bin'), (New-Object byte[] (2MB)))
        try {
            $b = Get-RecycleBinSizes
            Write-Host ("        avant : à toi {0}, autres comptes {1}" -f (Format-Size $b.Mine), (Format-Size $b.Others))
            if ($b.Mine -lt 2MB) { throw "fichier mis à la corbeille pas compté" }
            Clear-RecycleBinAll
            $a = Get-RecycleBinSizes
            if ($a.Mine -gt 64KB) { throw "corbeille pas vidée ($(Format-Size $a.Mine) restent)" }
            if (-not (Test-Path -LiteralPath (Join-Path $other 'autre.bin'))) { throw "corbeille d'un autre compte touchée" }
        } finally { Remove-Item -LiteralPath $other -Recurse -Force -ErrorAction SilentlyContinue }
    }
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
    Smoke 'Dépannage : son' {
        # Le service du son ne doit PAS être relancé s'il marche (Discord perdait le micro)
        $p0 = (Get-CimInstance Win32_Service -Filter "Name='Audiosrv'").ProcessId
        Repair-Sound
        $p1 = (Get-CimInstance Win32_Service -Filter "Name='Audiosrv'").ProcessId
        Write-Host "        service audio : processus $p0 → $p1 · sortie par défaut : « $(Get-AudioDefaultName $false 0) »"
        if ($p0 -and $p1 -and $p0 -ne $p1) { throw "le service audio a été relancé alors qu'il marchait" }
    }
    Smoke 'Dépannage : micro' { Repair-Microphone }
    Smoke 'Dépannage : webcam' { Repair-Webcam }
    Smoke 'Dépannage : imprimante' { Repair-Printing }
    Smoke 'Dépannage : bureau figé' { Restart-Shell }
    Smoke 'Test de connexion' { Test-Internet }
    Smoke 'Point de restauration' { New-RestorePoint }
    Smoke 'Annulations depuis l historique' {
        $n = 0
        foreach ($c in @(Get-Changes | Where-Object { $_.Undo })) {
            if (-not (Test-UndoAuthorized $c.Id $c.Undo)) { throw "annulation refusée : $($c.Undo)" }
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
