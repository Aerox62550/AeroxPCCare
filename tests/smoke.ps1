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
# Boutons coupés : un bouton hors d'une liste qui défile doit être entièrement dans la fenêtre (sinon on ne peut pas cliquer)
$script:ClippedButtons = New-Object System.Collections.ArrayList
function Test-ButtonsVisible($Win) {
    try {
        $root = $Win.Content; if (-not $root) { return }
        $stack = New-Object System.Collections.Stack; $stack.Push($root)
        while ($stack.Count) {
            $el = $stack.Pop()
            if ($el -is [System.Windows.Controls.ScrollViewer]) { continue }   # ce qui est dans une liste qui défile peut être plus bas
            if ($el -is [System.Windows.Controls.Primitives.ButtonBase] -and $el.IsVisible) {
                $pt = $el.TranslatePoint((New-Object System.Windows.Point(0, $el.ActualHeight)), $root)
                if ($pt.Y -gt $root.ActualHeight + 1) { [void]$script:ClippedButtons.Add(("{0} : « {1} » coupé ({2:N0} px sous le bas de la fenêtre)" -f $Win.Title, $el.Content, ($pt.Y - $root.ActualHeight))) }
            }
            if ($el -is [System.Windows.DependencyObject]) { for ($i = 0; $i -lt [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($el); $i++) { $stack.Push([System.Windows.Media.VisualTreeHelper]::GetChild($el, $i)) } }
        }
    } catch {}
}
# Toute fenêtre ouverte est capturée puis fermée dès qu'elle est affichée
[System.Windows.EventManager]::RegisterClassHandler([System.Windows.Window], [System.Windows.FrameworkElement]::LoadedEvent, [System.Windows.RoutedEventHandler]{
    param($s, $e)
    if ($s -eq $window) { return }
    [void]$s.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::ApplicationIdle, [Action[object]]{ param($w) Test-ButtonsVisible $w; try { if ($w.Content -is [System.Windows.UIElement] -and $w.Title -notlike '*Overlay*') { Save-Shot $w.Content ('fenetre-' + ($w.Title -replace '^.*?:\s*', '')) $w.Background } } catch {}; try { $w.Close() } catch {} }, $s)
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
    # ---- Audit du 21/10/2026 : chaque défaut corrigé a son test (il échoue si le défaut revient)
    Smoke 'Windows 11 : fin de support par version (audit M3)' {
        function Assert-Sup([int]$Build, [string]$Caption, [string]$Today, [string]$State, [string]$Name = '') {
            $r = Get-Win11Support $Build $Caption ([datetime]$Today)
            if ($r.State -ne $State -or ($Name -and $r.Name -ne $Name)) { throw ("{0} / build {1} le {2} : attendu {3} {4}, obtenu {5} {6}" -f $Caption, $Build, $Today, $State, $Name, $r.State, $r.Name) }
        }
        $j = '2026-10-21'
        Assert-Sup 26100 'Microsoft Windows 11 Famille' $j 'ended' '24H2'      # fin du support Famille / Pro : 13/10/2026
        Assert-Sup 26100 'Microsoft Windows 11 Pro' $j 'ended'
        Assert-Sup 26100 'Microsoft Windows 11 Professionnel' $j 'ended'
        Assert-Sup 26100 'Microsoft Windows 11 Pro Education' $j 'ended'       # « Pro Education » : 24 mois, comme Pro
        Assert-Sup 26100 'Microsoft Windows 11 Entreprise' $j 'ok'             # Entreprise / Éducation : 36 mois
        Assert-Sup 26100 'Microsoft Windows 11 Enterprise' $j 'ok'
        Assert-Sup 26100 'Microsoft Windows 11 Education' $j 'ok'
        Assert-Sup 26100 'Microsoft Windows 11 Éducation' $j 'ok'
        Assert-Sup 26200 'Microsoft Windows 11 Famille' $j 'ok' '25H2'
        Assert-Sup 26200 'Microsoft Windows 11 Pro' '2027-10-12' 'ok'
        Assert-Sup 26200 'Microsoft Windows 11 Pro' '2027-10-13' 'ended'
        Assert-Sup 22631 'Microsoft Windows 11 Famille' $j 'ended' '23H2'
        Assert-Sup 22631 'Microsoft Windows 11 Entreprise' $j 'ok'
        Assert-Sup 22631 'Microsoft Windows 11 Entreprise' '2026-11-11' 'ended'
        Assert-Sup 22621 'Microsoft Windows 11 Entreprise' $j 'ended' '22H2'
        Assert-Sup 22000 'Microsoft Windows 11 Famille' $j 'ended' '21H2'
        Assert-Sup 26100 'Microsoft Windows 11 Famille' '2026-10-13' 'ok'      # le jour même, la dernière mise à jour est encore livrée
        Assert-Sup 26100 'Microsoft Windows 11 Famille' '2026-10-14' 'ended'
        # Aucun avis (jamais de fausse alerte ni de fausse bonne nouvelle) : serveur, support long, version préliminaire ou trop récente
        Assert-Sup 26100 'Microsoft Windows Server 2025 Datacenter' $j 'unknown'
        Assert-Sup 26100 'Microsoft Windows 11 Enterprise LTSC' $j 'unknown'
        Assert-Sup 25398 'Microsoft Windows 11 Famille' $j 'unknown'
        Assert-Sup 28000 'Microsoft Windows 11 Famille' $j 'unknown'
        # Sur le vrai système de cette machine : la fonction répond et le diagnostic ne plante pas
        $os = Get-CimInstance Win32_OperatingSystem
        $r = Get-Win11Support ([int]$os.BuildNumber) "$($os.Caption)"
        Write-Host ("        cette machine : {0} (build {1}) -> {2} {3}" -f $os.Caption, $os.BuildNumber, $r.State, $r.Name)
    }
    Smoke 'Compteur de FPS : seule une copie signée par Intel entre dans le dossier protégé (audit M1)' {
        # 1) Le nom d'organisation du certificat doit être exactement celui attendu
        if (-not (Test-CertOrg 'CN=Intel Corporation, O=Intel Corporation, S=California, C=US' 'Intel Corporation')) { throw "vrai certificat d'Intel refusé" }
        if (-not (Test-CertOrg 'O=Intel Corporation' 'Intel Corporation')) { throw "sujet réduit à l'organisation refusé" }
        if (-not (Test-CertOrg 'CN=x, O=Intel Corporation' 'Intel Corporation')) { throw "organisation en dernier refusée" }
        foreach ($bad in 'CN=Evil, O=Intel Corporation Fake, C=US', 'CN=Evil, O=Fake Intel Corporation, C=US', 'CN=Intel Corporation, O=Evil Inc, C=US', 'CN=Evil, OU=O=Intel Corporation, C=US', '') {
            if (Test-CertOrg $bad 'Intel Corporation') { throw "faux certificat accepté : $bad" }
        }
        # 2) Vraies signatures Windows : un programme signé par Microsoft n'est pas « d'Intel », un fichier sans signature non plus
        $psx = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (-not (Test-ToolSignature $psx 'Microsoft Corporation')) { throw "powershell.exe pas reconnu comme signé par Microsoft" }
        if (Test-ToolSignature $psx 'Intel Corporation') { throw "programme signé Microsoft accepté comme étant d'Intel" }
        $work = Join-Path $env:TEMP 'aerox-pm-test'; New-Item -ItemType Directory -Force -Path $work | Out-Null
        $unsigned = Join-Path $work 'sans-signature.exe'; [IO.File]::WriteAllBytes($unsigned, [byte[]](0x4D, 0x5A, 0x90, 0, 3, 0, 0, 0))
        if (Test-ToolSignature $unsigned 'Intel Corporation') { throw "fichier sans signature accepté" }
        # 3) Faux PresentMon rangés au même endroit que celui de winget (dossier de l'utilisateur) : aucun ne doit être copié ni lancé
        $safe = Join-Path (Get-ToolsDir) 'presentmon\PresentMon.exe'; $safeDir = Split-Path $safe -Parent
        $wgRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'; $fakeDir = Join-Path $wgRoot 'Intel.PresentMon.Console_AeroxTest'
        if ((Test-Path -LiteralPath $safe) -or (Test-Path -LiteralPath $fakeDir)) { Write-Host '        (vrai PresentMon présent : test sauté)'; Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue; return }
        try {
            New-Item -ItemType Directory -Force -Path $fakeDir | Out-Null
            Copy-Item -LiteralPath $unsigned -Destination (Join-Path $fakeDir 'PresentMon-fake1.exe') -Force
            Copy-Item -LiteralPath $psx -Destination (Join-Path $fakeDir 'PresentMon-fake2.exe') -Force
            (Get-Item -LiteralPath (Join-Path $fakeDir 'PresentMon-fake2.exe')).LastWriteTime = (Get-Date).AddMinutes(5)   # le plus récent : essayé en premier
            if (@(Find-PresentMonInstalled -All).Count -lt 2) { throw "faux PresentMon pas trouvés par la recherche ($(@(Find-PresentMonInstalled -All).Count))" }
            if (Find-PresentMon) { throw "un PresentMon qui n'est pas signé par Intel a été accepté" }
            if (Test-Path -LiteralPath $safe) { throw "faux PresentMon copié dans le dossier protégé" }
            if (Test-Path -LiteralPath (Join-Path $safeDir 'PresentMon-verif.exe')) { throw "copie de vérification laissée dans le dossier protégé" }
            if ((Get-ToolStatus).PresentMon) { throw "l'état des outils annonce un compteur de FPS installé" }
            # 4) Copie déjà rangée par une ancienne version d'AEROX (sans vérification) : retirée, jamais lancée
            New-Item -ItemType Directory -Force -Path $safeDir | Out-Null
            Copy-Item -LiteralPath $unsigned -Destination $safe -Force
            if (Find-PresentMon) { throw "ancienne copie non signée toujours acceptée" }
            if (Test-Path -LiteralPath $safe) { throw "ancienne copie non signée laissée dans le dossier protégé" }
            Write-Host "        faux PresentMon (sans signature, signé par Microsoft, ancienne copie) : tous refusés"
        } finally {
            Remove-Item -LiteralPath $fakeDir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $safe -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath (Join-Path $safeDir 'PresentMon-verif.exe') -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Smoke 'Fenêtre principale : jamais plus grande que la zone utile de l''écran (audit M4)' {
        # Zones utiles courantes (largeur, hauteur en pixels, barre des tâches exclue) : 1024×768, 1366×768, 1920×1080 à 150 %, 1366×768 à 125 %, 1080p, 4K, très petit écran
        foreach ($a in @(@(1024, 720), @(1366, 720), @(1280, 672), @(1093, 566), @(1920, 1032), @(3840, 2080), @(800, 560))) {
            $f = Get-WindowFit $a[0] $a[1]
            if ($f.W -gt $a[0] - 16 -or $f.H -gt $a[1] - 16) { throw ("zone {0}×{1} : fenêtre {2}×{3} plus grande que la zone utile moins la marge" -f $a[0], $a[1], $f.W, $f.H) }
            if ($f.MinW -gt $f.W -or $f.MinH -gt $f.H) { throw ("zone {0}×{1} : taille minimale {2}×{3} supérieure à la taille {4}×{5}" -f $a[0], $a[1], $f.MinW, $f.MinH, $f.W, $f.H) }
            if ($f.W -gt 1120 -or $f.H -gt 780) { throw "fenêtre agrandie au-delà de la taille prévue" }
        }
        $g = Get-WindowFit 1920 1032; if ($g.W -ne 1120 -or $g.H -ne 780 -or $g.MinW -ne 960 -or $g.MinH -ne 660) { throw "grand écran : la taille prévue (1120×780, minimum 960×660) a changé" }
        $p = Get-WindowFit 1024 720;  if ($p.W -ne 1008 -or $p.H -ne 704 -or $p.MinW -ne 960 -or $p.MinH -ne 660) { throw ("écran 1024×768 : {0}×{1} (minimum {2}×{3}) au lieu de 1008×704 (minimum 960×660)" -f $p.W, $p.H, $p.MinW, $p.MinH) }
        # Sur cette machine : la vraie fenêtre créée tient dans la zone utile
        $wa = [System.Windows.SystemParameters]::WorkArea
        Write-Host ("        zone utile de cette machine : {0}×{1} ; fenêtre {2}×{3} (minimum {4}×{5})" -f $wa.Width, $wa.Height, $window.Width, $window.Height, $window.MinWidth, $window.MinHeight)
        if ($window.Width -gt $wa.Width - 16 -or $window.Height -gt $wa.Height - 16) { throw "la fenêtre créée dépasse la zone utile de l'écran" }
        # Fenêtres de dialogue : même limite
        $dlg = New-Dialog 'Test' 600
        if ($dlg.MaxHeight -gt $wa.Height - 16 -or $dlg.Width -gt $wa.Width - 16) { throw "dialogue plus grand que la zone utile ($($dlg.Width)×$($dlg.MaxHeight))" }
        $dlg2 = New-Dialog 'Test large' 5000
        if ($dlg2.Width -gt $wa.Width - 16) { throw "dialogue plus large que la zone utile" }
    }
    Smoke 'Lancement avec Windows : seulement depuis un dossier réservé aux administrateurs (audit M2)' {
        $pf = $env:ProgramFiles; $dir = Join-Path $pf 'AeroxTestM2'; $outside = Join-Path $env:TEMP 'aerox-m2-test'
        $link = Join-Path $dir 'lien'
        try {
            New-Item -ItemType Directory -Force -Path $outside | Out-Null
            $out = Join-Path $outside 'AeroxPCCare.exe'; [IO.File]::WriteAllBytes($out, [byte[]](0x4D, 0x5A))
            # 1) Hors de Program Files, chemin vide, fichier introuvable : refusés
            if (Test-AdminOnlyPath $out) { throw "un fichier hors de Program Files est accepté" }
            if (Test-AdminOnlyPath '') { throw "un chemin vide est accepté" }
            if (Test-AdminOnlyPath (Join-Path $pf 'AeroxTestM2-absent\AeroxPCCare.exe')) { throw "un fichier introuvable est accepté" }
            # 2) Dans Program Files, créé par un administrateur : accepté
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            $exe = Join-Path $dir 'AeroxPCCare.exe'; [IO.File]::WriteAllBytes($exe, [byte[]](0x4D, 0x5A))
            if (-not (Test-AdminOnlyPath $exe)) { throw ("fichier normal de Program Files refusé : dossier « {0} », fichier « {1} »" -f (Get-AclWeakness $dir), (Get-AclWeakness $exe)) }
            # 3) Un autre compte peut le modifier : refusé (dossier ouvert aux utilisateurs, fichier ouvert à tout le monde, ou propriétaire ordinaire)
            & icacls.exe $dir /grant '*S-1-5-32-545:(OI)(CI)M' | Out-Null
            if (Test-AdminOnlyPath $exe) { throw "dossier modifiable par les utilisateurs accepté" }
            & icacls.exe $dir /remove:g '*S-1-5-32-545' | Out-Null
            if (-not (Test-AdminOnlyPath $exe)) { throw ("droits retirés, le chemin devrait être de nouveau accepté : « {0} » / « {1} »" -f (Get-AclWeakness $dir), (Get-AclWeakness $exe)) }
            & icacls.exe $exe /grant '*S-1-1-0:(W)' | Out-Null
            if (Test-AdminOnlyPath $exe) { throw "fichier modifiable par tout le monde accepté" }
            & icacls.exe $exe /remove:g '*S-1-1-0' | Out-Null
            if (-not (Test-AdminOnlyPath $exe)) { throw ("droits retirés, le fichier devrait être de nouveau accepté : « {0} »" -f (Get-AclWeakness $exe)) }
            & icacls.exe $dir /setowner $env:USERNAME | Out-Null
            if ($LASTEXITCODE -eq 0) {
                if (Test-AdminOnlyPath $exe) { throw "dossier appartenant à un compte ordinaire accepté" }
                & icacls.exe $dir /setowner '*S-1-5-32-544' | Out-Null
                if ($LASTEXITCODE -ne 0 -or -not (Test-AdminOnlyPath $exe)) { throw "propriétaire d'origine non rétabli : « $(Get-AclWeakness $dir) »" }
            } else { Write-Host '        (changement de propriétaire impossible ici : cas sauté)' }
            # 4) Jonction : un chemin qui passe par un lien est refusé, même si le dossier visé est sain
            $real = Join-Path $dir 'reel'; New-Item -ItemType Directory -Force -Path $real | Out-Null
            [IO.File]::WriteAllBytes((Join-Path $real 'AeroxPCCare.exe'), [byte[]](0x4D, 0x5A))
            if (-not (Test-AdminOnlyPath (Join-Path $real 'AeroxPCCare.exe'))) { throw "dossier normal refusé" }
            New-Item -ItemType Junction -Path $link -Target $real | Out-Null
            if (Test-AdminOnlyPath (Join-Path $link 'AeroxPCCare.exe')) { throw "fichier atteint par une jonction accepté" }
            [IO.Directory]::Delete($link)
            # 5) L'option « lancer avec Windows » : refusée hors de Program Files, créée dans Program Files, tâche douteuse retirée
            $AeroxLauncher = $out
            $b = Get-AutoStartBlock
            if ($b -notlike '*Program Files*') { throw "lanceur hors de Program Files : blocage attendu, obtenu « $b »" }
            $threw = $false; try { Set-AutoStart $true } catch { $threw = $true }
            if (-not $threw -or (Test-AutoStart)) { throw "tâche créée alors que le lanceur est hors de Program Files" }
            $AeroxLauncher = $exe
            $b = Get-AutoStartBlock; if ($b) { throw "lanceur de Program Files bloqué : « $b »" }
            Set-AutoStart $true
            $t = Get-ScheduledTask -TaskName $script:AutoTaskName -ErrorAction Stop
            if ("$(@($t.Actions)[0].Arguments)" -ne '--discret' -or "$($t.Principal.RunLevel)" -ne 'Highest') { throw "tâche mal créée : $(@($t.Actions)[0].Arguments) / $($t.Principal.RunLevel)" }
            if ((Get-AutoStartTarget) -ne $exe) { throw "programme visé par la tâche : « $(Get-AutoStartTarget) » au lieu de « $exe »" }
            if (Repair-AutoStartTask) { throw "tâche saine retirée" }
            if (-not (Test-AutoStart)) { throw "tâche saine disparue" }
            Set-AutoStart $false
            foreach ($cible in @($out, (Join-Path $dir 'disparu.exe'))) {
                $a = New-ScheduledTaskAction -Execute $cible -Argument '--discret'
                Register-ScheduledTask -TaskName $script:AutoTaskName -Action $a -Trigger (New-ScheduledTaskTrigger -AtLogOn) -Force -ErrorAction Stop | Out-Null
                if (-not (Repair-AutoStartTask)) { throw "tâche visant « $cible » non retirée" }
                if (Test-AutoStart) { throw "tâche visant « $cible » toujours là" }
            }
            Write-Host '        Program Files : accepté ; dossier libre, droits ouverts, autre propriétaire, jonction, fichier absent : refusés ; tâche douteuse retirée'
        } finally {
            Unregister-ScheduledTask -TaskName $script:AutoTaskName -Confirm:$false -ErrorAction SilentlyContinue
            if (Test-Path -LiteralPath $link) { try { [IO.Directory]::Delete($link) } catch {} }
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $outside -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Smoke 'Diagnostic : seuils du disque, de la mémoire, des températures et de l''antivirus (audit D1 à D5)' {
        function Assert-Is([string]$Name, $Got, $Want) { if ("$Got" -ne "$Want") { throw ("{0} : obtenu « {1} », attendu « {2} »" -f $Name, $Got, $Want) } }
        # D1 : un disque se juge sur le pourcentage ET sur l'espace réellement libre (2 To à 14 % libres ne sont pas « presque pleins »)
        Assert-Is 'D1 2 To, 280 Go libres' (Get-SystemDiskLevel 280GB 2000GB) ''
        Assert-Is 'D1 2 To, 180 Go libres' (Get-SystemDiskLevel 180GB 2000GB) ''
        Assert-Is 'D1 500 Go, 70 Go libres' (Get-SystemDiskLevel 70GB 500GB) ''
        Assert-Is 'D1 500 Go, 45 Go libres' (Get-SystemDiskLevel 45GB 500GB) 'warn'
        Assert-Is 'D1 256 Go, 21 Go libres' (Get-SystemDiskLevel 21GB 256GB) 'warn'
        Assert-Is 'D1 256 Go, 17 Go libres' (Get-SystemDiskLevel 17GB 256GB) 'crit'
        Assert-Is 'D1 128 Go, 25 Go libres' (Get-SystemDiskLevel 25GB 128GB) ''
        Assert-Is 'D1 128 Go, 6 Go libres' (Get-SystemDiskLevel 6GB 128GB) 'crit'
        Assert-Is 'D1 taille inconnue' (Get-SystemDiskLevel 0 0) ''
        Assert-Is 'D1 autre disque 4 To, 160 Go libres' (Test-OtherDiskFull 160GB 4000GB) $false
        Assert-Is 'D1 autre disque 1 To, 10 Go libres' (Test-OtherDiskFull 10GB 1000GB) $true
        Assert-Is 'D1 autre disque 64 Go, 2 Go libres' (Test-OtherDiskFull 2GB 64GB) $true
        # D2 : « peu de mémoire » se juge sur la mémoire INSTALLÉE (Windows en réserve une part pour le circuit graphique intégré)
        Assert-Is 'D2 8 Go installés, 7,4 utilisables' (Test-LowRam 8GB 7.4GB) $false
        Assert-Is 'D2 8 Go installés, 6 utilisables' (Test-LowRam 8GB 6GB) $false
        Assert-Is 'D2 4 Go installés' (Test-LowRam 4GB 3.9GB) $true
        Assert-Is 'D2 6 Go installés' (Test-LowRam 6GB 5.9GB) $true
        Assert-Is 'D2 installé inconnu, 7 utilisables' (Test-LowRam 0 7GB) $false
        Assert-Is 'D2 installé inconnu, 3,9 utilisables' (Test-LowRam 0 3.9GB) $true
        Assert-Is 'D2 tout inconnu' (Test-LowRam 0 0) $false
        $ram = Get-InstalledRam; $sys = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
        Write-Host ("        cette machine : {0} installés, {1} utilisables" -f $(if ($ram) { Format-Size $ram } else { 'inconnu' }), (Format-Size $sys))
        # D3 : seuils de température par type de disque
        Assert-Is 'D3 NVMe' (Get-DiskTempLimit 'SSD' 'NVMe') 80
        Assert-Is 'D3 SSD SATA' (Get-DiskTempLimit 'SSD' 'SATA') 70
        Assert-Is 'D3 disque dur' (Get-DiskTempLimit 'HDD' 'SATA') 60
        Assert-Is 'D3 inconnu' (Get-DiskTempLimit 'Unspecified' '') 70
        # D4 : processeur (les Ryzen récents visent 95 °C en charge : normal ; un Intel à 95 °C en charge ne l'est pas)
        $ryzen = 'AMD Ryzen 9 7950X 16-Core Processor'; $intel = '12th Gen Intel(R) Core(TM) i7-12700K'; $vieux = 'AMD Ryzen 5 5600X 6-Core Processor'
        Assert-Is 'D4 Ryzen 7000 reconnu' (Test-RyzenTarget95 $ryzen) $true
        Assert-Is 'D4 Ryzen 7800X3D reconnu' (Test-RyzenTarget95 'AMD Ryzen 7 7800X3D 8-Core Processor') $true
        Assert-Is 'D4 Ryzen 5000 non concerné' (Test-RyzenTarget95 $vieux) $false
        Assert-Is 'D4 Intel non concerné' (Test-RyzenTarget95 $intel) $false
        Assert-Is 'D4 Ryzen 7000 à 95 °C en charge' (Get-CpuTempVerdict 95 80 $ryzen) ''
        Assert-Is 'D4 Ryzen 7000 à 100 °C' (Get-CpuTempVerdict 100 80 $ryzen) 'crit'
        Assert-Is 'D4 Ryzen 7000 à 82 °C au repos' (Get-CpuTempVerdict 82 10 $ryzen) 'warn'
        Assert-Is 'D4 Intel à 94 °C en charge' (Get-CpuTempVerdict 94 90 $intel) ''
        Assert-Is 'D4 Intel à 95 °C en charge' (Get-CpuTempVerdict 95 90 $intel) 'warn'
        Assert-Is 'D4 Intel à 100 °C' (Get-CpuTempVerdict 100 90 $intel) 'crit'
        Assert-Is 'D4 Intel à 79 °C au repos' (Get-CpuTempVerdict 79 5 $intel) ''
        Assert-Is 'D4 Intel à 80 °C au repos' (Get-CpuTempVerdict 80 5 $intel) 'warn'
        Assert-Is 'D4 Ryzen 5000 à 95 °C en charge' (Get-CpuTempVerdict 95 90 $vieux) 'warn'
        # D4 : plusieurs relevés (valeur du milieu) avant de conclure
        Assert-Is 'D4 milieu de 5 relevés' (Get-Median @(90, 60, 91, 92, 88)) 90
        Assert-Is 'D4 milieu d''un seul relevé' (Get-Median @(97)) 97
        Assert-Is 'D4 aucun relevé' ($null -eq (Get-Median @())) $true
        $sync = @{ Sens = @{ 'cpu.temp' = 91.0; 'cpu.load' = 55.0 } }     # capteurs fabriqués (cette copie de $sync ne sort pas du test)
        $m = Get-SensorMedian @('cpu.temp', 'cpu.load', 'gpu.temp') 3 1
        Assert-Is 'D4 température relevée' $m['cpu.temp'] 91
        Assert-Is 'D4 charge relevée' $m['cpu.load'] 55
        Assert-Is 'D4 capteur absent' $m.ContainsKey('gpu.temp') $false
        # D5 : une seule alerte quand Defender est le seul antivirus et que sa protection permanente est coupée ; jamais de faux « aucun antivirus »
        Assert-Is 'D5 un antivirus actif' (Test-NoAvIssue 1 0 $true $true) $false
        Assert-Is 'D5 Defender seul, protection permanente coupée' (Test-NoAvIssue 0 0 $true $false) $false
        Assert-Is 'D5 aucun antivirus ne répond' (Test-NoAvIssue 0 0 $false $false) $true
        Assert-Is 'D5 antivirus tiers inactif, Defender coupé' (Test-NoAvIssue 0 1 $true $false) $true
        Assert-Is 'D5 Centre de sécurité en retard, Defender protège' (Test-NoAvIssue 0 0 $true $true) $false
    }
    Smoke 'Réglages : écriture tout ou rien et copie de secours (audit S3-1)' {
        $d = Join-Path $env:TEMP 'aerox-reglages-test'; New-Item -ItemType Directory -Force -Path $d | Out-Null
        $f = Join-Path $d 'reglages.json'
        try {
            Write-FileAtomic $f '{"InstallId":"un","Launches":1}'
            Write-FileAtomic $f '{"InstallId":"deux","Launches":2}'
            if ((Get-Content -LiteralPath $f -Raw -Encoding UTF8) -notlike '*"deux"*') { throw "le fichier n'a pas la dernière version" }
            if ((Get-Content -LiteralPath "$f.bak" -Raw -Encoding UTF8) -notlike '*"un"*') { throw "la copie de secours n'a pas la version précédente" }
            if (Test-Path -LiteralPath "$f.tmp") { throw "fichier temporaire laissé à côté" }
            $SettingsFile = $f     # les fonctions appelées d'ici lisent ce fichier-là
            $h = Read-SettingsFile; if ($h.InstallId -ne 'deux') { throw "lecture normale : « $($h.InstallId) » au lieu de « deux »" }
            # Fichier principal tronqué (coupure de courant avec l'ancienne méthode d'écriture) : la copie de secours est lue
            [IO.File]::WriteAllText($f, '{"InstallId":"deu')
            $h = Read-SettingsFile; if ($h.InstallId -ne 'un') { throw "fichier abîmé : copie de secours non lue (« $($h.InstallId) »)" }
            # Fichier principal vide : idem
            [IO.File]::WriteAllText($f, '')
            $h = Read-SettingsFile; if ($h.InstallId -ne 'un') { throw "fichier vide : copie de secours non lue" }
            # Réécriture par-dessus un fichier abîmé : l'enregistrement redevient normal
            Write-FileAtomic $f '{"InstallId":"trois"}'
            $h = Read-SettingsFile; if ($h.InstallId -ne 'trois') { throw "réécriture après abîmage : « $($h.InstallId) »" }
            # Un fichier .tmp oublié par un plantage ne gêne pas
            [IO.File]::WriteAllText("$f.tmp", 'reste')
            Write-FileAtomic $f '{"InstallId":"quatre"}'
            $h = Read-SettingsFile; if ($h.InstallId -ne 'quatre' -or (Test-Path -LiteralPath "$f.tmp")) { throw "fichier .tmp oublié : « $($h.InstallId) »" }
            # Première écriture (fichier absent)
            Remove-Item -LiteralPath $f, "$f.bak" -Force
            Write-FileAtomic $f '{"InstallId":"neuf"}'
            $h = Read-SettingsFile; if ($h.InstallId -ne 'neuf') { throw "première écriture : « $($h.InstallId) »" }
            # Rien de lisible : pas d'erreur, juste $null (réglages par défaut)
            Remove-Item -LiteralPath $f, "$f.bak" -Force -ErrorAction SilentlyContinue
            if ($null -ne (Read-SettingsFile)) { throw "aucun fichier : une valeur a été renvoyée" }
        } finally { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }
    }
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
        # Dossiers d'essai à part : ces fausses annulations ne doivent pas rester dans le vrai historique
        # (le test « Annulations depuis l historique » plus bas exécute celles qu'il y trouve)
        $iso = Join-Path $env:TEMP ('AeroxSceaux-' + [guid]::NewGuid().ToString('N'))
        $copie = @{}; foreach ($k in @($AppInfo.Keys)) { $copie[$k] = $AppInfo[$k] }
        $copie.LogDir = Join-Path $iso 'journal'; $copie.Secure = Join-Path $iso 'protege'
        New-Item -ItemType Directory -Force -Path $copie.LogDir, $copie.Secure | Out-Null
        $AppInfo = $copie
        try {
        Add-Change -Title 'Test sceau' -Undo 'Set-CpuMaxState 100'
        $c = @(Get-Changes 5 | Where-Object { $_.Title -eq 'Test sceau' })[0]
        if (-not (Test-UndoAuthorized $c.Id $c.Undo)) { throw "annulation notée par AEROX refusée" }
        if (Test-UndoAuthorized 'faux123' "Set-BgItem 'service' '' 'RemoteRegistry' 'auto'") { throw "annulation trafiquée acceptée" }
        if (Test-UndoAuthorized $c.Id "Set-BgItem 'task' '\X\' 'Y' 'on'") { throw "annulation remplacée dans l'historique acceptée" }
        # Audit S1 : le sceau est obligatoire pour les 18 actions (avant : 15 sur 18 acceptées sans sceau, par exemple un changement de DNS)
        $exemples = @(
            "Set-UserProxy 0 '' ''", "Restore-HostsBackup 'C:\x\hosts.bak'", "Set-StartupApps -Enable @('a')", "Set-PowerScheme 'guid' 'nom'",
            'Enable-StorageSense', 'Disable-StorageSense', 'Enable-Hibernation', "Set-DisplayHz '\\.\DISPLAY1' 60", 'Set-NetAdapterSleep ''Ethernet'' $true',
            "Restore-Dns '{00000000-0000-0000-0000-000000000000}' '9.9.9.9'", 'Set-CpuMaxState 100', "Set-BgItem 'service' '' 'X' 'auto'", "Restore-RegBackup 'C:\x.reg'",
            "Set-ReservedStorage 'Enabled'", "Set-HiberType 'full'", "Set-RestoreSpace '10'", "Set-CompactOS 'on'", 'Resume-BitLockerOs', "Restore-Quarantine '0123456789abcdef0123456789abcdef'")
        if ($exemples.Count -ne 19) { throw "il devait y avoir 19 exemples, il y en a $($exemples.Count)" }
        $n = 0
        foreach ($u in $exemples) {
            $n++
            if (-not (Test-SafeUndo $u)) { throw "exemple d'annulation non reconnu comme sûr : $u" }
            if (Test-UndoAuthorized "sans-sceau-$n" $u) { throw "annulation SANS sceau acceptée : $u" }
            Add-Change -Title 'Test sceau (toutes les actions)' -Undo $u
            $e = @(Get-Changes 100 | Where-Object { $_.Title -eq 'Test sceau (toutes les actions)' -and $_.Undo -eq $u })[0]
            if (-not $e) { throw "changement de test non retrouvé dans l'historique : $u" }
            if (-not (Test-UndoAuthorized $e.Id $e.Undo)) { throw "annulation notée par AEROX refusée : $u" }
            if (Test-UndoAuthorized "$($e.Id)x" $e.Undo) { throw "sceau accepté pour un autre identifiant : $u" }
        }
        Write-Host "        19 actions : sceau obligatoire pour chacune"
        } finally { Remove-Item -LiteralPath $iso -Recurse -Force -ErrorAction SilentlyContinue }
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
        if (-not (Test-WinUriAllowed 'steam://open/games')) { throw "liens Steam toujours refusés" }
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
    foreach ($k in 'home', 'clean', 'update', 'repair', 'security', 'perf', 'help', 'monitor') { Smoke-Page $k }
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
    # ---------------- Sécurité (2.6.0) : règles, faux éléments plantés exprès, analyse complète (0 critique attendu), fenêtres
    Smoke 'Sécurité : règles pures' {
        $bad = @()
        $chk = { param($n, $got, $want) if ("$got" -ne "$want") { $script:SecBad += "$n : '$got' au lieu de '$want'" } }
        $script:SecBad = @()
        & $chk 'zone temp' (Get-PathZone 'C:\Users\a\AppData\Local\Temp\x.exe') 'temp'
        & $chk 'zone pf' (Get-PathZone 'C:\Program Files\Steam\steam.exe') 'programfiles'
        & $chk 'zone racine' (Get-PathZone 'C:\Intel\x.exe') 'rootdir'
        & $chk 'cmd encodée' (Get-CommandRisk 'powershell -w hidden -enc SQBFAFgAIAAoAE4AZQB3AC0ATwBiAGoAZQBjAHQAIABOAGUAdAA=').Level 'strong'
        & $chk 'cmd Windows (SMB1)' (Get-CommandRisk 'powershell.exe -ExecutionPolicy Unrestricted -NonInteractive -NoProfile -WindowStyle Hidden "& %windir%\system32\WindowsPowerShell\v1.0\Modules\SmbShare\DisableUnusedSmb1.ps1 -Scenario Client"').Level 'weak'
        & $chk 'cmd normale' (Get-CommandRisk '"C:\Program Files\Steam\steam.exe" -silent').Level ''
        & $chk 'faux svchost' (Test-Masquerade 'svchost.exe' 'C:\Users\a\AppData\Roaming\svchost.exe') 'exact'
        & $chk 'vrai svchost' (Test-Masquerade 'svchost.exe' (Join-Path $env:SystemRoot 'System32\svchost.exe') $env:SystemRoot) ''
        & $chk 'scvhost' (Test-Masquerade 'scvhost.exe' 'C:\x\scvhost.exe') 'like:svchost'
        & $chk 'exclusion racine' (Get-ExclusionRisk 'C:\' 'path') 'crit'
        & $chk 'exclusion jeu' (Get-ExclusionRisk 'D:\SteamLibrary' 'path') 'info'
        & $chk 'exclusion .exe' (Get-ExclusionRisk '.exe' 'ext') 'crit'
        & $chk 'anydesk' (Get-RemoteToolName 'AnyDesk').Name 'AnyDesk'
        & $chk 'radmin vpn' (Get-RemoteToolName 'Radmin VPN') ''
        & $chk 'rat' (Get-RemoteToolName 'remcos.exe').Kind 'rat'
        & $chk 'appât' ((Test-RiskyDownloadName 'GTA5 Mod Menu.exe') -join ',') 'appat'
        & $chk 'double extension' ((Test-RiskyDownloadName 'facture.pdf.exe') -join ',') 'double'
        & $chk 'nom normal' ((Test-RiskyDownloadName 'DiscordSetup.exe') -join ',') ''
        & $chk 'secret' (Test-SecretFileName 'mdp insta.txt') $true
        & $chk 'pas secret' (Test-SecretFileName 'facture.pdf') $false
        & $chk 'verdict' (Get-SecVerdict @(@{ Sev = 'info' })).Level 'ok'
        & $chk 'cachette nom au hasard' ([bool](Get-SuspiciousPlacement 'C:\ProgramData\Windows\Config\57AE748E\AppManagerServicef7ad.exe')) $true
        & $chk 'cachette dossier camouflé' ([bool](Get-SuspiciousPlacement 'C:\Users\a\AppData\Local\Microsoft\Windows\tVKCIG.{20D04FE0-3AEA-1069-A2D8-08002B30309D}\MicrosoftStorageWorker.exe')) $true
        & $chk 'pas de cachette' ([bool](Get-SuspiciousPlacement 'C:\Users\a\AppData\Local\Programs\lunarclient\Lunar Client.exe' 'Lunar Client')) $false
        # Fichiers signés par Microsoft : JAMAIS signalés, même copiés dans un dossier temporaire ou sous le nom d'un programme de Windows
        & $chk 'svchost de Windows' (Get-LaunchRisk ('"{0}" -k netsvcs' -f (Join-Path $env:SystemRoot 'System32\svchost.exe'))).Sev ''
        & $chk 'Explorateur' (Get-LaunchRisk (Join-Path $env:SystemRoot 'explorer.exe')).Sev ''
        & $chk 'rundll32 de Windows' (Get-LaunchRisk ('{0} shell32.dll,Control_RunDLL' -f (Join-Path $env:SystemRoot 'System32\rundll32.exe'))).Sev ''
        $tmp = Join-Path $env:TEMP 'aerox-secu-signe'; New-Item -ItemType Directory -Force -Path $tmp | Out-Null
        Copy-Item (Join-Path $env:SystemRoot 'System32\whoami.exe') (Join-Path $tmp 'whoami.exe') -Force
        Copy-Item (Join-Path $env:SystemRoot 'System32\svchost.exe') (Join-Path $tmp 'svchost.exe') -Force
        $script:SecSigCache = @{}
        & $chk 'copie Microsoft dans Temp' (Get-LaunchRisk ('"{0}"' -f (Join-Path $tmp 'whoami.exe'))).Sev ''
        & $chk 'vrai svchost copié dans Temp' (Get-LaunchRisk ('"{0}"' -f (Join-Path $tmp 'svchost.exe'))).Sev ''
        [IO.File]::WriteAllText((Join-Path $tmp 'outil.exe'), 'pas un vrai programme')
        & $chk 'sans signature dans Temp' (Get-LaunchRisk ('"{0}"' -f (Join-Path $tmp 'outil.exe'))).Sev 'crit'
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
        if ($script:SecBad.Count) { throw ($script:SecBad -join ' | ') }
    }
    Smoke 'Sécurité : faux éléments plantés exprès' {
        $d = 'C:\aerox\secu-test'; Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force -Path $d | Out-Null
        $sh = New-Object -ComObject WScript.Shell
        $lnk = $sh.CreateShortcut((Join-Path $d 'Mes photos.lnk')); $lnk.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'; $lnk.Arguments = '-WindowStyle Hidden -File C:\aerox\secu-test\absent.ps1'; $lnk.Save()
        $ok = $sh.CreateShortcut((Join-Path $d 'Invite de commandes.lnk')); $ok.TargetPath = Join-Path $env:SystemRoot 'System32\cmd.exe'; $ok.Save()
        [IO.File]::WriteAllText((Join-Path $d 'facture.pdf.exe'), 'pas un vrai programme')
        [IO.File]::WriteAllText((Join-Path $d 'GTA5 Mod Menu.exe'), 'pas un vrai programme')
        [IO.File]::WriteAllText((Join-Path $d 'DiscordSetup.exe'), 'pas un vrai programme')
        [IO.File]::WriteAllText((Join-Path $d 'mdp insta.txt'), 'rien')
        $script:SecItems = New-Object System.Collections.ArrayList; $script:SecChecked = New-Object System.Collections.ArrayList; $script:SecSigCache = @{}
        $line = $null; while ($sync.Queue.TryDequeue([ref]$line)) {}
        Get-SecDownloads -Dirs @($d)
        Get-SecSecrets -Dirs @($d)
        $journal = New-Object System.Collections.ArrayList; while ($sync.Queue.TryDequeue([ref]$line)) { [void]$journal.Add($line) }
        foreach ($x in $script:SecItems) { Write-Host ("        [{0}] {1} | {2} | {3}" -f $x.Sev, $x.Rule, $x.Title, $x.Why) }
        $rules = @($script:SecItems | ForEach-Object { "$($_.Rule)" })
        foreach ($want in 'raccourci-piege', 'fausse-extension', 'appat', 'mots-de-passe') { if ($rules -notcontains $want) { throw "« $want » pas trouvé" } }
        if (@($script:SecItems | Where-Object { $_.Title -match 'Invite de commandes|DiscordSetup' }).Count) { throw "un fichier normal a été signalé" }
        if (@($script:SecItems | Where-Object { $_.Rule -eq 'raccourci-piege' -and $_.Sev -ne 'crit' }).Count) { throw "raccourci piégé pas critique" }
        if (@($journal | Where-Object { $_ -match 'mdp insta' }).Count) { throw "le nom d'un fichier de mots de passe est écrit dans le journal" }
        $k = 0; foreach ($x in $script:SecItems) { $k++; $x.Num = $k }
        $rep = @{ Items = @($script:SecItems); Checked = @($script:SecChecked); Verdict = (Get-SecVerdict $script:SecItems); Date = (Get-Date); Code = (New-SecCode) }
        if ($rep.Code -notmatch '^[A-Z0-9]{6}$') { throw "code du rapport invalide : $($rep.Code)" }
        $txt = Get-SecReportText $rep
        if ($txt -notmatch 'n° 1 ' -or $txt -notmatch [regex]::Escape($rep.Code)) { throw "numéros ou code absents du rapport" }
        if ($txt -match 'mdp insta') { throw "le nom d'un fichier de mots de passe est dans le rapport à copier" }
        $script:SecTestReport = $rep
    }
    Smoke 'Sécurité 2.7 : cachettes plantées (COM, tâche cachée, ligne vide, dossier de mod menu)' {
        $tmp = Join-Path $env:TEMP 'aerox-cachettes'; New-Item -ItemType Directory -Force -Path $tmp | Out-Null
        $evil = Join-Path $tmp 'evil.dll'; [IO.File]::WriteAllText($evil, 'pas une vraie DLL')
        $evilExe = Join-Path $tmp 'relance.exe'; [IO.File]::WriteAllText($evilExe, 'pas un vrai programme')
        $clsid = '{' + [guid]::NewGuid().ToString() + '}'
        $ck = "HKCU:\Software\Classes\CLSID\$clsid\InprocServer32"
        New-Item -Path $ck -Force | Out-Null; Set-ItemProperty -LiteralPath $ck -Name '(default)' -Value $evil
        $tf = Join-Path $env:SystemRoot 'System32\Tasks\AeroxTestTacheCachee'
        [IO.File]::WriteAllText($tf, ('<?xml version="1.0" encoding="UTF-16"?><Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"><Settings><Enabled>true</Enabled></Settings><Actions Context="Author"><Exec><Command>{0}</Command></Exec></Actions></Task>' -f $evilExe), [Text.Encoding]::Unicode)
        $rk = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        Set-ItemProperty -LiteralPath $rk -Name 'AeroxTestLigneVide' -Value '"C:\aerox\absent\rien.exe" --x'
        try {
            $script:SecItems = New-Object System.Collections.ArrayList; $script:SecChecked = New-Object System.Collections.ArrayList; $script:SecSigCache = @{}; $script:SecDefOn = $true
            Get-SecAutoruns
            foreach ($x in @($script:SecItems | Where-Object { $_.Rule -in 'com', 'tache-cachee', 'demarrage-vide' })) { Write-Host ("        [{0}] {1} | {2} | {3}" -f $x.Sev, $x.Rule, $x.Title, $x.Path) }
            if (-not @($script:SecItems | Where-Object { $_.Rule -eq 'com' -and $_.Path -eq $evil -and $_.Sev -eq 'crit' }).Count) { throw "composant COM détourné pas trouvé" }
            if (-not @($script:SecItems | Where-Object { $_.Rule -eq 'tache-cachee' -and $_.Path -eq $evilExe -and $_.Sev -eq 'crit' }).Count) { throw "tâche cachée pas trouvée" }
            $lv = @($script:SecItems | Where-Object { $_.Rule -eq 'demarrage-vide' -and $_.Title -match 'AeroxTestLigneVide' })[0]
            if (-not $lv -or $lv.Sev -ne 'info' -or -not $lv.Fix) { throw "ligne de démarrage vide pas trouvée (ou sans correction)" }
            if (@($script:SecItems | Where-Object { $_.Rule -in 'demarrage-vide' -and $_.Default }).Count) { throw "une ligne vide est cochée d'office" }
            $sync.SecReport = @{ Items = @($script:SecItems); Checked = @(); Verdict = (Get-SecVerdict $script:SecItems); Date = (Get-Date); Code = 'TEST27' }
            Repair-SecurityItems -Ids @($lv.Id)
            if ($null -ne (Get-ItemProperty -LiteralPath $rk -Name 'AeroxTestLigneVide' -ErrorAction SilentlyContinue)) { throw "ligne vide pas retirée" }
            # rundll32 avec une extension inhabituelle
            $t = Get-CommandTarget ('rundll32.exe "{0}\a b.dat",Run' -f $tmp)
            if ($t -ne (Join-Path $tmp 'a b.dat')) { throw "cible de rundll32 mal lue : $t" }
            # Dossier de mod menu dans Documents
            $doc = 'C:\aerox\secu-docs'; New-Item -ItemType Directory -Force -Path (Join-Path $doc 'modest-menu_v0.9.4') | Out-Null
            $script:SecItems = New-Object System.Collections.ArrayList
            Get-SecDownloads -Dirs @($doc)
            if (-not @($script:SecItems | Where-Object { $_.Rule -eq 'dossier-appat' }).Count) { throw "dossier de mod menu pas trouvé" }
            Remove-Item -LiteralPath $doc -Recurse -Force -ErrorAction SilentlyContinue
        } finally {
            Remove-Item -LiteralPath "HKCU:\Software\Classes\CLSID\$clsid" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $tf -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -LiteralPath $rk -Name 'AeroxTestLigneVide' -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Smoke 'Sécurité 2.7 : protections coupées et exclusions regroupées (Defender simulé)' {
        # Fausses réponses de Defender, seulement pour ce test (les fonctions passent avant les commandes du même nom)
        function Get-MpComputerStatus { [pscustomobject]@{ AntivirusEnabled = $true; AMServiceEnabled = $true; RealTimeProtectionEnabled = $false; IsTamperProtected = $true; BehaviorMonitorEnabled = $true } }
        function Get-MpPreference { [pscustomobject]@{ ExclusionPath = @(); ExclusionExtension = @(); ExclusionProcess = @(1..6 | ForEach-Object { "C:\Users\a\AppData\Local\Temp\x$($_)q7rk2.exe" }); MAPSReporting = 2; DisableRealtimeMonitoring = $true; DisableIOAVProtection = $false; DisableScriptScanning = $true; DisableBehaviorMonitoring = $false; DisableBlockAtFirstSeen = $false } }
        $script:SecItems = New-Object System.Collections.ArrayList; $script:SecChecked = New-Object System.Collections.ArrayList
        Get-SecDefender
        foreach ($x in $script:SecItems) { Write-Host ("        [{0}] {1} | {2} | {3}" -f $x.Sev, $x.Rule, $x.Title, $x.Path) }
        $g = @($script:SecItems | Where-Object { $_.Rule -eq 'exclusion' })
        if ($g.Count -ne 1 -or @($g[0].Fix).Count -ne 6) { throw "6 exclusions attendues en UNE ligne avec 6 corrections (obtenu : $($g.Count) ligne(s))" }
        if ($g[0].Why -notmatch "n'existent plus") { throw "les exclusions de programmes disparus ne sont pas signalées comme traces" }
        $c = @($script:SecItems | Where-Object { $_.Rule -eq 'defender-coupe' })
        if (-not $c.Count -or $c[0].Path -notmatch 'temps réel' -or $c[0].Path -notmatch 'scripts') { throw "protections coupées pas signalées" }
    }
    Smoke 'Sécurité : fenêtre (éléments plantés)' { $sync.SecReport = $script:SecTestReport; Show-SecDialog $null }
    Smoke 'Sécurité : fenêtre d''envoi au développeur' { $sync.SecReport = $script:SecTestReport; Show-SecSendDialog }
    Smoke 'Sécurité : quarantaine AEROX du faux fichier (annulable)' {
        $it = @($script:SecTestReport.Items | Where-Object { $_.Rule -eq 'fausse-extension' })[0]
        if (@($it.Fix | ForEach-Object { $_.Kind }) -notcontains 'quarantine') { throw "pas de quarantaine proposée" }
        $sync.SecReport = $script:SecTestReport
        Repair-SecurityItems -Ids @($it.Id)
        if (Test-Path -LiteralPath 'C:\aerox\secu-test\facture.pdf.exe') { throw "fichier pas mis en quarantaine" }
        $q = @(Get-ChildItem -LiteralPath (Join-Path $AppInfo.Secure 'quarantaine') -Filter '*.quarantaine' -ErrorAction SilentlyContinue)
        if (-not $q.Count) { throw "fichier introuvable dans la quarantaine (AEROX ne doit jamais supprimer)" }
        foreach ($f in $q) { $wk = Get-AclWeakness $f.FullName; if ($wk) { throw "fichier en quarantaine modifiable sans droits admin : $wk" } }
        $ch = @(Get-Changes 20 | Where-Object { $_.Undo -like 'Restore-Quarantine*' })[0]
        if (-not $ch -or -not (Test-UndoAuthorized $ch.Id $ch.Undo)) { throw "pas d'annulation autorisée dans l'historique" }
        try { [void](Move-ToQuarantine (Join-Path $env:SystemRoot 'System32\whoami.exe')); throw "un fichier de Windows a été accepté" } catch { if ($_.Exception.Message -match 'accepté') { throw } }
        Write-Host "        en quarantaine, annulation scellée (remis à sa place par le test des annulations)"
    }
    Smoke 'Sécurité : vider la quarantaine (seulement après 24 heures)' {
        $dir = Get-SecureDir 'quarantaine'
        $recent = @(Get-QuarantineItems | Where-Object { -not $_.CanDelete })
        if (-not $recent.Count) { throw "le fichier mis en quarantaine à l'instant n'est pas listé" }
        Clear-Quarantine -Ids @($recent[0].Id)
        if (-not (Test-Path -LiteralPath (Join-Path $dir "$($recent[0].Id).quarantaine"))) { throw "un fichier mis en quarantaine il y a moins de 24 h a été supprimé" }
        $old = [guid]::NewGuid().ToString('N')
        [IO.File]::WriteAllText((Join-Path $dir "$old.quarantaine"), 'faux fichier de test')
        [IO.File]::WriteAllText((Join-Path $dir "$old.json"), (@{ id = $old; chemin = 'C:\aerox\vieux.exe'; sha256 = ''; date = (Get-Date).AddDays(-3).ToString('s') } | ConvertTo-Json -Compress))
        if (-not @(Get-QuarantineItems | Where-Object { $_.Id -eq $old -and $_.CanDelete }).Count) { throw "fichier de 3 jours pas supprimable" }
        Clear-Quarantine -Ids @($old, 'pas-un-id')
        if (Test-Path -LiteralPath (Join-Path $dir "$old.quarantaine")) { throw "fichier de 3 jours pas supprimé" }
    }
    Smoke 'Sécurité : fenêtre quarantaine' { Show-QuarantineDialog }
    Smoke 'Sécurité : analyse approfondie (0 critique attendu)' {
        Invoke-SecurityScan
        $r = $sync.SecReport
        if (-not $r) { throw "pas de résultat" }
        Write-Host ("        verdict : {0} · vérifié : {1}" -f $r.Verdict.Title, ($r.Checked -join ' | '))
        foreach ($x in @($r.Items)) { Write-Host ("        [{0}] {1} | {2} | {3} | {4}" -f $x.Sev, $x.Rule, $x.Title, $x.Path, $x.Why) }
        # Machine de test GitHub : Defender y est volontairement aveuglé (exclusion des disques entiers) et ses agents
        # tournent sans signature depuis ProgramData\GitHub et Temp. Vrais signes sur un PC normal, seulement notés ici.
        $runner = { param($x) $env:GITHUB_ACTIONS -eq 'true' -and (($x.Rule -eq 'exclusion' -and "$($x.Path)" -match '^[A-Za-z]:\\?( · [A-Za-z]:\\?)*$') -or $x.Rule -eq 'defender-coupe' -or "$($x.Path)" -match '(?i)\\GitHub\\|\\provjobd|\\actions-runner\\|\\hostedtoolcache\\') }
        foreach ($x in @($r.Items | Where-Object { & $runner $_ })) { Write-Host ("        (machine de test GitHub, attendu) {0} {1}" -f $x.Title, $x.Path) }
        $crit = @($r.Items | Where-Object { $_.Sev -eq 'crit' -and -not (& $runner $_) })
        if ($crit.Count) { throw ("{0} critique(s) sur une machine saine : {1}" -f $crit.Count, (($crit | ForEach-Object { "$($_.Rule) $($_.Title) $($_.Path)" }) -join ' | ')) }
        if (-not @($r.Checked).Count) { throw "pas de liste de vérifications" }
    }
    Smoke 'Sécurité : signes forts du diagnostic' {
        $script:Issues = New-Object System.Collections.ArrayList; $script:OkList = New-Object System.Collections.ArrayList; $script:CurrentCat = 'Sécurité'
        Test-SecQuickSigns
        # Machine de test GitHub : exclusion des disques entiers voulue (voir ci-dessus)
        if ($env:GITHUB_ACTIONS -eq 'true') { foreach ($i in @($script:Issues | Where-Object { $_.Id -eq 'secu-exclusion' -and "$($_.Detail)" -match '^([A-Za-z]:\\?(, )?)+$' })) { Write-Host "        (machine de test GitHub, attendu) $($i.Title) $($i.Detail)"; $script:Issues.Remove($i) } }
        if ($script:Issues.Count) { throw ("signe fort sur une machine saine : " + (($script:Issues | ForEach-Object { "$($_.Title) $($_.Detail)" }) -join ' | ')) }
    }
    Smoke 'Sécurité : fenêtre (machine de test)' { Show-SecDialog $null }
    Smoke 'Sécurité : fenêtre « compte piraté »' { Show-HackedDialog }
    Remove-Item -LiteralPath 'C:\aerox\secu-test' -Recurse -Force -ErrorAction SilentlyContinue
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
    Smoke 'Carte graphique : décrochages regroupés par incident' {
        $t0 = (Get-Date).Date.AddHours(20)
        $m = @(Merge-GpuResets @(@{ Time = $t0; Src = 'a' }, @{ Time = $t0.AddSeconds(40); Src = 'b' }, @{ Time = $t0.AddSeconds(50); Src = 'a' }, @{ Time = $t0.AddHours(3); Src = 'c' }, @{ Time = $t0.AddMinutes(-90); Src = 'd' }))
        if ($m.Count -ne 3 -or (@($m[1].Srcs) -join ',') -ne 'a,b' -or $m[0].Time -ne $t0.AddMinutes(-90)) { throw "regroupement faux : $($m.Count) incident(s), sources du 2e : $(@($m[1].Srcs) -join ',')" }
        $r = @(Get-GpuResets (Get-Date).AddDays(-14)); Write-Host "        ce PC : $($r.Count) décrochage(s) en 14 jours"
    }
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
            # Compteur de version : une fois par PC et par version, pas à chaque envoi
            $mk = 'maj:' + ($AppVersion -replace '\.', '-')
            if ($b.ev.$mk -ne 1) { throw "compteur « $mk » absent du premier envoi" }
            Add-StatsEvent 'lent:rien'
            $g = & $run $false
            if (@($g).Count -ne 2) { throw "2e envoi incorrect" }
            if ($g[1].B -like "*maj:*") { throw "compteur de version renvoyé : $($g[1].B)" }
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
    Smoke 'Mise à jour d''AEROX : proposée, reportable, jamais forcée' {
        $oldU = $sync.UpdateInfo; $oldS = @{ V = $script:Settings.UpdSnoozeVer; N = $script:Settings.UpdSnoozes; A = $script:Settings.AutoUpdate }; $oldJ = $script:Job
        try {
            $sync.UpdateInfo = @{ Version = '99.0.0'; Url = 'https://github.com/'; Setup = 'https://example.invalid/AeroxPCCare_Setup.exe'; Digest = ''; Test = $false; Notes = "- Nouveauté de test`n- Correction de test" }
            $script:Settings.AutoUpdate = $true; $script:Settings.UpdSnoozeVer = ''; $script:Settings.UpdSnoozes = 0
            # Fenêtre fermée sans choisir (croix) = « Plus tard » : rien n'est installé, report compté, reproposée dans 2 h
            Show-UpdateDialog
            if ($script:Job) { throw "une installation a été lancée alors que la fenêtre a été fermée" }
            if ($script:Settings.UpdSnoozes -ne 1 -or $script:Settings.UpdSnoozeVer -ne '99.0.0') { throw "report non compté ($($script:Settings.UpdSnoozes))" }
            if (-not $script:UpdPromptAt -or ($script:UpdPromptAt - (Get-Date)).TotalMinutes -lt 100) { throw "pas reproposée 2 h plus tard" }
            Show-UpdateDialog; Show-UpdateDialog   # 3e fois : message d'insistance (capture)
            if ($script:Settings.UpdSnoozes -ne 3) { throw "reports mal comptés ($($script:Settings.UpdSnoozes))" }
            # Pendant une opération : pas de fenêtre, reproposée 1 minute plus tard
            $script:Job = @{ Label = 'test' }; $script:UpdPromptAt = (Get-Date).AddSeconds(-1)
            Request-UpdatePrompt
            if (($script:UpdPromptAt - (Get-Date)).TotalSeconds -gt 70 -or ($script:UpdPromptAt - (Get-Date)).TotalSeconds -lt 30) { throw "pas reportée d'une minute pendant une opération" }
            $script:Job = $oldJ
            # Nouvelle version : le compteur repart de zéro
            $sync.UpdateInfo.Version = '99.0.1'; if ((Get-UpdateSnoozes) -ne 0) { throw "compteur gardé pour une autre version" }
            if (-not (Get-AutoUpdCardStatus).StatusText) { throw "carte du réglage vide" }
        } finally {
            $sync.UpdateInfo = $oldU; $script:Job = $oldJ; $script:UpdPromptAt = $null
            $script:Settings.UpdSnoozeVer = $oldS.V; $script:Settings.UpdSnoozes = $oldS.N; $script:Settings.AutoUpdate = $oldS.A; Save-Settings
        }
    }
    Smoke 'BIOS : vérification du fichier téléchargé (cas fabriqués)' {
        $b = Get-BoardIdentity @{ BoardMaker = 'Micro-Star International Co., Ltd.'; BoardModel = 'MAG B650 TOMAHAWK WIFI (MS-7D75)'; BiosVersion = '1.H0'; Brand = 'MSI'; Custom = $true }
        if ($b.Vendor -ne 'MSI' -or $b.MsiId -ne '7D75') { throw "identité MSI fausse" }
        $tmp = Join-Path $env:TEMP 'aerox-bios-test'; Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force -Path "$tmp\z\7D75v1J" | Out-Null
        $bytes = New-Object byte[] (8MB)
        [IO.File]::WriteAllBytes("$tmp\z\7D75v1J\E7D75AMS.1J0", $bytes); Set-Content "$tmp\z\7D75v1J\lisez-moi.txt" 'x'
        Add-Type -AssemblyName System.IO.Compression.FileSystem; [IO.Compression.ZipFile]::CreateFromDirectory("$tmp\z", "$tmp\7D75v1J.zip")
        $r = Get-BiosFileReport "$tmp\7D75v1J.zip" $b
        if ($r.Verdict -ne 'ok' -or $r.Name -ne 'E7D75AMS.1J0' -or -not (Test-Path -LiteralPath $r.File)) { throw "zip MSI de la bonne carte : $($r.Verdict) $($r.Name)" }
        [IO.File]::WriteAllBytes("$tmp\E7D78AMS.1J0", $bytes); if ((Get-BiosFileReport "$tmp\E7D78AMS.1J0" $b).Verdict -ne 'bad') { throw "BIOS d'une autre carte MSI accepté" }
        [IO.File]::WriteAllBytes("$tmp\B650AORUSELITEAX.F20", $bytes); if ((Get-BiosFileReport "$tmp\B650AORUSELITEAX.F20" $b).Verdict -ne 'bad') { throw "BIOS d'une autre marque accepté" }
        $a = Get-BoardIdentity @{ BoardMaker = 'ASUSTeK COMPUTER INC.'; BoardModel = 'PRIME B650-PLUS'; BiosVersion = '2801'; Brand = 'ASUS'; Custom = $true }
        [IO.File]::WriteAllBytes("$tmp\PRIME-B650-PLUS-WIFI-ASUS-3024.CAP", $bytes); if ((Get-BiosFileReport "$tmp\PRIME-B650-PLUS-WIFI-ASUS-3024.CAP" $a).Verdict -ne 'unknown') { throw "modèle voisin (WIFI) pas signalé" }
        [IO.File]::WriteAllBytes("$tmp\PRIME-B650-PLUS-ASUS-3024.CAP", $bytes); $r = Get-BiosFileReport "$tmp\PRIME-B650-PLUS-ASUS-3024.CAP" $a; if ($r.Verdict -ne 'ok' -or $r.Cmp -ne 1) { throw "BIOS ASUS plus récent : $($r.Verdict) $($r.Cmp)" }
        Set-Content "$tmp\E7D75AMS.1K0" 'petit'; if ((Get-BiosFileReport "$tmp\E7D75AMS.1K0" $b).Verdict -ne 'bad') { throw "fichier trop petit accepté" }
        if ((Compare-BiosVersion 'Gigabyte' 'F3' 'F20') -ne 1 -or (Compare-BiosVersion 'ASRock' '2.02' '1.28') -ne -1 -or $null -ne (Compare-BiosVersion 'MSI' '1.H0' '1J0')) { throw "comparaison des versions" }
        foreach ($v in 'MSI', 'ASUS', 'Gigabyte', 'ASRock', '') { if (-not @((Get-BiosFlashSteps $v 'X.ROM')[0]).Count) { throw "pas d'étapes pour $v" } }
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
    Smoke 'BIOS : la clé USB ne peut jamais être un disque interne' {
        $keys = @(Get-UsbKeys); Write-Host ("        clés USB vues : {0}" -f $keys.Count)
        $sys = Get-Disk | Where-Object { $_.IsSystem -or $_.IsBoot } | Select-Object -First 1
        $n0 = @(Get-Partition -DiskNumber $sys.Number).Count
        $refused = $false
        try { [void](Initialize-BiosUsb -DiskNumber $sys.Number -Source $PSCommandPath -Vendor 'MSI' -Format $true) } catch { $refused = $true; Write-Host "        refusé : $($_.Exception.Message)" }
        if (-not $refused) { throw "le disque de Windows a été accepté !" }
        if (@(Get-Partition -DiskNumber $sys.Number).Count -ne $n0) { throw "le disque de Windows a été modifié !" }
    }
    Smoke 'Fenêtre : mise à jour du BIOS' {
        Show-BiosUpdateDialog @{ BoardMaker = 'Micro-Star International Co., Ltd.'; BoardModel = 'MAG B650 TOMAHAWK WIFI (MS-7D75)'; BiosVersion = '1.H0'; Brand = 'MSI'; Maker = 'Micro-Star International Co., Ltd.'; Model = 'MAG B650 TOMAHAWK WIFI (MS-7D75)'; Custom = $true; IsLaptop = $false }
        Show-BiosUpdateDialog @{ BoardMaker = 'Dell Inc.'; BoardModel = '0ABC12'; BiosVersion = '1.20.0'; Brand = 'Dell'; Maker = 'Dell Inc.'; Model = 'XPS 15 9530'; Custom = $false; IsLaptop = $true }
    }
    Smoke 'Tailles lisibles (Format-Size)' {
        $ci = [Threading.Thread]::CurrentThread.CurrentCulture; [Threading.Thread]::CurrentThread.CurrentCulture = 'fr-FR'
        try {
            $cases = @(@(16GB, '16 Go'), @(15.99GB, '15,99 Go'), @(931.51GB, '931,5 Go'), @(2TB, '2 To'), @(1.82TB, '1,82 To'), @(128GB, '128 Go'), @(291.2MB, '291,2 Mo'), @(545KB, '545 Ko'))
            foreach ($c in $cases) { $r = (Format-Size $c[0]) -replace [char]0xA0, ' ' -replace [char]0x202F, ' '; if ($r -ne $c[1]) { throw "$($c[0]) octets : « $r » au lieu de « $($c[1]) »" } }
        } finally { [Threading.Thread]::CurrentThread.CurrentCulture = $ci }
    }
    Smoke 'Code : aucune fonction en double, aucune fonction jamais utilisée' {
        $f = Join-Path (Split-Path $PSCommandPath) 'AeroxPCCare.ps1'
        $src = [IO.File]::ReadAllText($f)
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($src, [ref]$null, [ref]$null)
        $fns = @($ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))
        $dup = @($fns | Group-Object Name | Where-Object { $_.Count -gt 1 } | ForEach-Object { "$($_.Name) ($($_.Count) fois)" })
        if ($dup.Count) { throw ("fonction(s) en double : " + ($dup -join ', ')) }
        $dead = @($fns | Where-Object { [regex]::Matches($src, '(?<![\w-])' + [regex]::Escape($_.Name) + '(?![\w-])').Count -le 1 } | ForEach-Object { $_.Name })
        if ($dead.Count) { throw ("fonction(s) jamais utilisée(s) : " + ($dead -join ', ')) }
        Write-Host ("        {0} fonctions, aucune en double ni inutilisée" -f $fns.Count)
    }
    Smoke 'Fenêtre : quoi de neuf' { Show-WhatsNew '1.6.0'; Show-WhatsNew '' }
    Smoke 'Infos BIOS : vitesse prévue des barrettes, canaux, XMP / EXPO' {
        $cases = @{ 'CMK32GX5M2B6000C36' = 6000; 'F4-3600C16-8GVKC' = 3600; 'F5-6000J3038F16G' = 6000; 'KF560C36BBEK2-32' = 6000; 'KF432C16BB/8' = 3200; 'BL8G32C16U4B' = 3200; 'CP2K16G56C46U5' = 5600; 'TF3D416G3200HC16F' = 3200; 'M471A1K43DB1-CWE' = 0; 'HMA81GS6CJR8N-XN' = 0; '' = 0; 'AX5U6000C3016G-B' = 6000; 'PSD48G266681' = 0 }
        foreach ($k in $cases.Keys) { $r = Get-RamRatedSpeed $k; if ($r -ne $cases[$k]) { throw "vitesse de « $k » : $r au lieu de $($cases[$k])" } }
        foreach ($c in @(@('DIMM_A2', 'BANK 1', 'A'), @('ChannelB-DIMM0', 'BANK 2', 'B'), @('DIMM 1', 'P0 CHANNEL A', 'A'), @('A1', '', 'A'), @('DIMM0', 'BANK 0', ''), @('XMM1', '', ''))) { $r = Get-MemChannel $c[0] $c[1]; if ($r -ne $c[2]) { throw "canal de $($c[0]) / $($c[1]) : [$r] au lieu de [$($c[2])]" } }
        foreach ($c in @(@('DDR5', 4800, 6000, 1100, $false, $false, 'off'), @('DDR5', 6000, 6000, 1350, $false, $false, 'on'), @('DDR4', 3200, 0, 1350, $false, $false, 'on'), @('DDR4', 2666, 0, 1200, $true, $false, 'standard'), @('DDR4', 2666, 0, 1200, $false, $false, 'unknown'), @('LPDDR5', 6400, 0, 0, $false, $true, 'soldered'), @('DDR5', 5600, 6000, 1250, $false, $false, 'below'), @('DDR4', 3200, 3200, 1200, $false, $false, 'ok'))) {
            $r = Get-XmpState $c[0] $c[1] $c[2] $c[3] $c[4] $c[5]; if ($r.State -ne $c[6]) { throw "XMP $($c[0..5] -join '/') : $($r.State) au lieu de $($c[6])" }
        }
        # Réglage à la main (rapport de Sam : kit 6400 réglé à 5600 sur Ryzen 7800X3D) et vitesse idéale des Ryzen 7000 / 9000
        foreach ($c in @(@('DDR5', 5600, 6400, 0, $false, $false, $true, 'below', '6000 MT/s'), @('DDR5', 5600, 6400, 0, $false, $false, $false, 'below', 'à la main'), @('DDR5', 6000, 6400, 1350, $false, $false, $true, 'ok', 'idéale'), @('DDR5', 4800, 6400, 1100, $false, $false, $true, 'off', '6000 MT/s'), @('DDR5', 6400, 6400, 1350, $false, $false, $true, 'on', 'ratio 1:2'), @('DDR5', 6000, 6400, 1350, $false, $false, $false, 'below', 'profil'), @('DDR4', 3000, 3600, 1350, $false, $false, $true, 'below', 'profil'), @('DDR4', 2133, 3600, 1200, $false, $false, $false, 'off', 'pas activé'))) {
            $r = Get-XmpState $c[0] $c[1] $c[2] $c[3] $c[4] $c[5] $c[6]
            if ($r.State -ne $c[7] -or -not $r.Text.Contains($c[8])) { throw "XMP $($c[0..6] -join '/') : $($r.State) au lieu de $($c[7]) (texte : $($r.Text))" }
        }
        if ((Get-XmpState 'DDR4' 3000 3600 1350 $false $false $true).Text -match 'Ryzen') { throw "conseil Ryzen DDR5 donné pour de la DDR4" }
        foreach ($b in 'ASUS', 'MSI', 'Gigabyte', 'ASRock', 'Dell', '') { foreach ($w in 'xmp', 'virt', 'rebar', 'fans') { if (-not (Get-BiosHowTo $b $w $true $false 'DDR5')) { throw "pas d'explication $b / $w" } } }
    }
    Smoke 'Infos matérielles lues une seule fois par diagnostic (même résultat)' {
        $old = $script:CimCache
        try {
            $script:CimCache = $null
            $a = Get-CimStatic Win32_ComputerSystem; $n0 = @(Get-CimStatic Win32_PhysicalMemory).Count
            $script:CimCache = @{}
            $b = Get-CimStatic Win32_ComputerSystem; $c = Get-CimStatic Win32_ComputerSystem; $n1 = @(Get-CimStatic Win32_PhysicalMemory).Count
            if ("$($a.Model)|$($a.TotalPhysicalMemory)" -ne "$($c.Model)|$($c.TotalPhysicalMemory)" -or $n0 -ne $n1) { throw "résultat différent avec la mémoire" }
            if (-not [object]::ReferenceEquals($b, $c)) { throw "relu au lieu d'être gardé" }
            if ($null -ne (Get-CimStatic Win32_ClasseQuiNExistePas -Quiet)) { throw "-Quiet doit ne rien renvoyer" }
            $ko = $false; try { Get-CimStatic Win32_ClasseQuiNExistePas | Out-Null } catch { $ko = $true }; if (-not $ko) { throw "sans -Quiet, l'erreur doit remonter" }
        } finally { $script:CimCache = $old }
    }
    Smoke 'Infos BIOS : ce PC' {
        $si = $sync.SysInfo; if (-not $si) { Get-SystemInfo | Out-Null; $si = $sync.SysInfo }
        $bi = Get-BiosInfo $si
        $r = $bi.Ram
        Write-Host ("        RAM : {0} barrette(s) {1}, {2} MT/s (prévue {3}), {4} mV, XMP {5}, canaux {6}, emplacements {7}" -f $r.Count, $r.Type, $r.Conf, $r.Rated, $r.Volt, $r.Xmp.State, $r.Channels, $r.Slots)
        if ($r.Count -and $r.Total -lt 512MB) { throw "quantité de RAM fausse : $($r.Total) octets pour $($r.Count) barrette(s)" }
        Write-Host ("        barrettes : " + ((@($r.Modules) | ForEach-Object { "[$($_.Slot) / $($_.Bank) → $($_.Channel)] $($_.Maker) $($_.Part)" }) -join ' · '))
        Write-Host ("        virtualisation : {0} · Resizable BAR : {1} · logiciels ventilateurs : {2}" -f $bi.Virt, $bi.Rebar.State, ((@($bi.FanSoft)) -join ', '))
    }
    Smoke 'Ventilateurs : lecture et alertes (cas fabriqués)' {
        $f = Get-FanFindings @(@{ Src = 'mb'; Name = 'Fan #1'; Rpm = 0 }, @{ Src = 'mb'; Name = 'Fan #2'; Rpm = 0 }) 90 50 40
        if ($f.Alerts.Count -ne 1 -or $f.Alerts[0].Kind -ne 'bad') { throw "processeur chaud sans ventilateur pas signalé" }
        $f = Get-FanFindings @(@{ Src = 'gpu'; Name = 'GPU Fan 1'; Rpm = 0; Pct = 0 }, @{ Src = 'mb'; Name = 'CPU Fan'; Rpm = 1100; Pct = 40 }, @{ Src = 'mb'; Name = 'Fan #3'; Rpm = 0 }) 45 5 48
        if ($f.Alerts.Count -or $f.Rows.Count -ne 2 -or $f.IdleHeaders -ne 1 -or $f.Rows[1].Note -ne 'zero') { throw "PC normal : alerte ou lignes fausses" }
        if ((Get-FanFindings @(@{ Src = 'gpu'; Name = 'GPU Fan'; Rpm = 0 }) 50 10 85).Alerts.Count -ne 1) { throw "carte graphique chaude ventilateurs arrêtés pas signalée" }
        if ((Get-FanFindings @(@{ Src = 'mb'; Name = 'AIO Pump'; Rpm = 3000 }) 40 5 40).Alerts.Count) { throw "pompe de watercooling signalée à tort" }
        $old = $script:FanUi
        try {
            $script:FanUi = @{ Panel = (New-Object System.Windows.Controls.StackPanel); Brand = 'ASUS'; Amd = $true; Oem = $false; Soft = @('Armoury Crate'); Lhm = $true }
            Update-FanCard @{ fans = @(@{ Src = 'mb'; Name = 'CPU Fan'; Rpm = 1200; Pct = 45 }); 'cpu.temp' = 50; 'cpu.load' = 10; 'gpu.temp' = 40 } @{ Lhm = $true; PawnIO = $true }
            if ($script:FanUi.Panel.Children.Count -lt 2) { throw "carte des ventilateurs vide" }
            Update-FanCard @{} @{ Lhm = $false; PawnIO = $false }
            if ($script:FanUi.Panel.Children.Count -lt 2) { throw "carte sans module vide" }
        } finally { $script:FanUi = $old }
    }
    Smoke 'Disques : un message « volume en bon état » n est pas une erreur' {
        $ev = @([pscustomobject]@{ Id = 98; Level = 4 }, [pscustomobject]@{ Id = 98; Level = 2 }, [pscustomobject]@{ Id = 55; Level = 2 }, [pscustomobject]@{ Id = 153; Level = 3 }, [pscustomobject]@{ Id = 7; Level = 0 }, [pscustomobject]@{ Id = 98; Level = 4 })
        $k = @(Select-DiskProblemEvents $ev)
        if ($k.Count -ne 3 -or @($k | Where-Object { $_.Id -eq 98 }).Count -ne 1) { throw "filtre faux : $($k.Count) gardé(s)" }
        if (@(Select-DiskProblemEvents @()).Count -ne 0) { throw "liste vide mal gérée" }
        # Ce PC : combien d'événements 98 « bon état » auraient été comptés avant
        $all = @(Get-EventsSafe @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Ntfs'; Id = 98; StartTime = (Get-Date).AddDays(-30) })
        Write-Host ("        ce PC : {0} événement(s) Ntfs 98 dont {1} vrai(s) problème(s)" -f $all.Count, @(Select-DiskProblemEvents $all).Count)
    }
    Smoke 'Mises à jour : winget lui-même toujours en dernier' {
        $o = (@(Get-UpdateOrder @('Microsoft.AppInstaller', 'ALCPU.CoreTemp', 'Discord.Discord', 'Valve.Steam')) -join ',')
        if ($o -ne '1,2,3,0') { throw "ordre faux : $o" }
        if (@(Get-UpdateOrder @('A.B')).Count -ne 1 -or @(Get-UpdateOrder @()).Count -ne 0) { throw "cas simples faux" }
    }
    Smoke 'Liens Windows : seulement ceux prévus' {
        foreach ($u in 'ms-settings:sound', 'windowsdefender://threat', 'windowsdefender:', 'ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1', 'steam://open/games', 'microsoft.windows.camera:', 'ms-availablenetworks:') { if (-not (Test-WinUriAllowed $u)) { throw "refusé à tort : $u" } }
        foreach ($u in 'shell:AppsFolder\x!y', 'shell:startup', 'steam://run/730', 'ms-settings:sound & calc', 'file:///C:/Windows/System32/calc.exe', 'ms-settings:SOUND', "ms-settings:sound`n", 'search-ms:query=x', 'ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1&x=1') { if (Test-WinUriAllowed $u) { throw "accepté à tort : $u" } }
    }
    Smoke 'Module natif : vérifié par son empreinte avant chargement' {
        $src = $NativeDll; $bytes = [IO.File]::ReadAllBytes($src); $sha = Get-FileSha256 $bytes
        $dir = Join-Path $env:TEMP ("aerox-module-" + [guid]::NewGuid().ToString('N'))
        try {
            $c = Get-VerifiedNative $src $sha $dir
            if (-not (Test-Path -LiteralPath $c) -or (Get-FileSha256 ([IO.File]::ReadAllBytes($c))) -ne $sha) { throw "copie vérifiée absente ou fausse" }
            $c2 = Get-VerifiedNative $src $sha.ToLowerInvariant() $dir; if ($c2 -ne $c) { throw "empreinte en minuscules mal gérée" }
            $bad = Join-Path $dir 'modifie.dll'; $b2 = [byte[]]$bytes.Clone(); $b2[200] = $b2[200] -bxor 1; [IO.File]::WriteAllBytes($bad, $b2)
            $refused = $false; try { [void](Get-VerifiedNative $bad $sha $dir) } catch { $refused = $true }
            if (-not $refused) { throw "module modifié accepté" }
            Write-Host "        copie vérifiée : $([IO.Path]::GetFileName($c))"
        } finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Smoke 'Partager AEROX : message tout prêt' {
        $t = Get-ShareMessage
        if ($t -notmatch "https://github\.com/$([regex]::Escape($GitHubRepo))/releases/latest" -or $t -match '\{\d\}') { throw "message incomplet : $t" }
        if ($sync.DiscordUrl -and $t -notlike "*$($sync.DiscordUrl)*") { throw "lien Discord absent" }
        Write-Host ("        " + ($t -replace "`r`n", ' / '))
    }
    Smoke 'Fenêtre : avis' { Show-ReviewDialog; Write-Host ("        invitation sur l'accueil : {0}" -f (Test-ReviewInvite)) }
    Smoke 'Rapport de bug' { $r = Build-BugReport 'test' 20 5; if ($r.Length -lt 100) { throw 'rapport vide' } }
    Smoke 'Captures des pages' {
        Show-Page 'home'; Save-Shot $window.Content 'fenetre-complete' $window.Background
        foreach ($k in 'home', 'diag', 'clean', 'update', 'repair', 'security', 'perf', 'system', 'help') { Show-Page $k; Save-Shot $PageHost ("page-" + $k) $window.Background }
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
    Smoke 'Gaming : lancement avec Windows (refusé hors de Program Files)' {
        # Le test tourne sans le lanceur, depuis un dossier libre : l'option est refusée avec une explication, sans rien créer.
        # (La création de la tâche depuis Program Files est testée plus haut : audit M2.)
        $AeroxLauncher = Join-Path $AppRoot 'AeroxPCCare.exe'
        if (-not (Get-AutoStartBlock)) { throw "option permise depuis un dossier libre ($AppRoot)" }
        $threw = $false; try { Set-AutoStart $true } catch { $threw = $true }
        if (-not $threw) { throw "Set-AutoStart n'a pas refusé" }
        if (Test-AutoStart) { throw "tâche créée malgré le refus" }
        Write-Host '        refusé, rien créé : OK'
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
    Smoke 'Fenêtres : aucun bouton coupé (écran 1024 × 720)' {
        foreach ($c in @($script:ClippedButtons)) { Write-Host "        $c" }
        if (@($script:ClippedButtons).Count) { throw (@($script:ClippedButtons | Select-Object -Unique) -join ' | ') }
    }
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
