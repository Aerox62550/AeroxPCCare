# Test de l'installateur et du lanceur sur un VRAI Windows (machine de test GitHub, Windows PowerShell 5.1, droits administrateur).
# Ce que « Vérifier sur Windows » ne couvre pas : l'installateur lui-même, le dossier protégé, la reprise d'une ancienne installation,
# la tâche « lancer avec Windows », la mise à jour, la désinstallation, le refus d'un fichier modifié et la taille de la vraie fenêtre.
# Paramètre : le dossier « build » construit par ./build.sh (AeroxPCCare_Setup.exe + « AEROX PC Care »).
param([Parameter(Mandatory = $true)][string]$Build)
. (Join-Path $PSScriptRoot 'outils.ps1')
Add-Type -AssemblyName System.Windows.Forms

$Setup    = Join-Path $Build 'AeroxPCCare_Setup.exe'
$Appli    = Join-Path $Build 'AEROX PC Care'
$Script   = Join-Path $Appli 'AeroxPCCare.ps1'
$Dir      = Join-Path $env:ProgramFiles 'AeroxPCCare'
$Exe      = Join-Path $Dir 'AeroxPCCare.exe'
$Cle      = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\AeroxPCCare'
$Tache    = 'AEROX PC Care (mode discret)'
$Fichiers = @('AeroxPCCare.exe', 'AeroxPCCare.ps1', 'AeroxPCCare.Native.dll', 'aerox.ico', 'LISEZMOI.txt')
$Bureau   = Join-Path $env:Public 'Desktop\AEROX PC Care.lnk'
$Menu     = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\AEROX PC Care.lnk'

Note ("Machine : {0} (build {1}), processus 64 bits : {2}" -f (Get-CimInstance Win32_OperatingSystem).Caption, (Get-CimInstance Win32_OperatingSystem).BuildNumber, [Environment]::Is64BitProcess)
Note ("Installateur : {0} ({1:N0} octets)" -f $Setup, (Get-Item -LiteralPath $Setup).Length)
Exiger (Test-Path -LiteralPath $Setup) 'installateur introuvable'
Exiger (Test-Path -LiteralPath $Script) 'script construit introuvable'

# Les fonctions du programme qui jugent un dossier « réservé aux administrateurs » : reprises telles quelles
Invoke-Expression (Get-CodeAerox $Script @('Get-AclWeakness', 'Test-AdminOnlyPath') @('$script:AdminSids'))

function Nettoyer {
    Stop-Aerox
    Unregister-ScheduledTask -TaskName $Tache -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $Cle -Recurse -Force -ErrorAction SilentlyContinue
    foreach ($d in @($Dir, 'C:\AeroxCustom', 'C:\AeroxOld')) { if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue } }
    Remove-Item -LiteralPath $Bureau, $Menu -Force -ErrorAction SilentlyContinue
}
# Réglages posés avant le premier lancement : aucune statistique envoyée au vrai relais, aucune mise à jour automatique
function Preparer-Reglages {
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $d = Join-Path $Dir "protege\donnees\$sid"
    New-Item -ItemType Directory -Force $d | Out-Null
    [IO.File]::WriteAllText((Join-Path $d 'reglages.json'), '{"StatsOff":true,"AutoUpdate":false,"ReviewNever":true}', (New-Object System.Text.UTF8Encoding($true)))
}
function Lire-Registre([string]$Nom) { try { return "$((Get-ItemProperty -LiteralPath $Cle -ErrorAction Stop).$Nom)" } catch { return '' } }
function Meme-Fichier([string]$A, [string]$B) { return ((Get-FileHash -LiteralPath $A -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $B -Algorithm SHA256).Hash) }
# La tâche « lancer avec Windows » doit viser le programme installé dans Program Files et garder TOUS ses autres réglages
# (compte, droits les plus élevés, délai de 45 s, batterie, durée, instances) : $Avant = Get-TacheInfo pris avant l'opération testée
function Exiger-Tache([string]$Contexte, $Avant) {
    $i = $null
    try { $i = Get-TacheInfo $Tache } catch { throw "$Contexte : la tâche « lancer avec Windows » a disparu ($($_.Exception.Message))" }
    Note ("  tâche : {0} {1} | niveau {2}, compte {3}, ouverture {4}, délai {5}, batterie {6}, durée {7}, instances {8}" -f $i.Cible, $i.Arguments, $i.Niveau, $i.Compte, $i.Ouverture, $i.Delai, $i.Batterie, $i.DureeMax, $i.Instances)
    Exiger ($i.Cible -eq $Exe) ("$Contexte : la tâche vise « {0} » au lieu de « {1} »" -f $i.Cible, $Exe)
    foreach ($k in @('Arguments', 'Niveau', 'Declencheurs', 'Compte', 'Ouverture', 'TypeDeclencheur', 'Delai', 'Batterie', 'DureeMax', 'Instances')) {
        Exiger ("$($i[$k])" -eq "$($Avant[$k])") ("$Contexte : réglage « {0} » de la tâche changé : « {1} » devenu « {2} »" -f $k, $Avant[$k], $i[$k])
    }
    Exiger ($i.Arguments -eq '--discret') "$Contexte : paramètre de la tâche : « $($i.Arguments) »"
    Exiger ($i.Niveau -eq 'Highest') "$Contexte : niveau d'exécution de la tâche : $($i.Niveau)"
    Exiger ($i.Declencheurs -ge 1) "$Contexte : déclencheur de la tâche perdu"
    Exiger (Test-AdminOnlyPath $i.Cible) "$Contexte : la tâche vise un programme modifiable par d'autres comptes"
}
function Exiger-Installation([string]$Contexte) {
    foreach ($f in $Fichiers) {
        Exiger (Test-Path -LiteralPath (Join-Path $Dir $f)) "$Contexte : $f absent de $Dir"
        Exiger (Meme-Fichier (Join-Path $Dir $f) (Join-Path $Appli $f)) "$Contexte : $f installé différent de celui construit"
    }
    Exiger (Test-Path -LiteralPath (Join-Path $Dir 'Desinstaller.exe')) "$Contexte : Desinstaller.exe absent"
    Exiger ((Lire-Registre 'Dossier') -eq $Dir) ("$Contexte : dossier noté dans le registre = « {0} » au lieu de « {1} »" -f (Lire-Registre 'Dossier'), $Dir)
    Exiger ((Lire-Registre 'InstallLocation') -eq $Dir) "$Contexte : InstallLocation du registre incorrect"
    Exiger (Test-Path -LiteralPath $Bureau) "$Contexte : raccourci du Bureau absent"
    Exiger (Test-Path -LiteralPath $Menu) "$Contexte : raccourci du menu Démarrer absent"
}
function Preparer-Ancienne([string]$Ancien, [switch]$AvecFichierPerso, [switch]$AvecTache) {
    New-Item -ItemType Directory -Force (Join-Path $Ancien 'maj') | Out-Null
    foreach ($f in $Fichiers) { Copy-Item -LiteralPath (Join-Path $Appli $f) -Destination $Ancien -Force }
    Set-Content -LiteralPath (Join-Path $Ancien 'Desinstaller.exe') 'faux'
    Set-Content -LiteralPath (Join-Path $Ancien 'maj\AeroxPCCare_Setup_2.5.0.exe') 'faux'
    if ($AvecFichierPerso) { Set-Content -LiteralPath (Join-Path $Ancien 'mes-notes.txt') 'a garder' }
    New-Item -Path $Cle -Force | Out-Null
    Set-ItemProperty -LiteralPath $Cle -Name 'Dossier' -Value $Ancien
    Set-ItemProperty -LiteralPath $Cle -Name 'InstallLocation' -Value $Ancien
    if ($AvecTache) { Register-TacheDiscret (Join-Path $Ancien 'AeroxPCCare.exe') $Tache }
}

Nettoyer

# ---------------------------------------------------------------------------------------------------- Installation
Verifier 'Installation silencieuse : fichiers, registre, raccourcis, dossier réservé aux administrateurs' {
    $code = Lancer-Programme $Setup '/S'
    Exiger ($code -eq 0) "code de sortie $code"
    Exiger-Installation 'installation'
    foreach ($f in $Fichiers) { Exiger (Test-AdminOnlyPath (Join-Path $Dir $f)) ("« {0} » modifiable par un autre compte que les administrateurs : {1}" -f $f, (Get-AclWeakness (Join-Path $Dir $f))) }
    Exiger (Test-AdminOnlyPath $Dir) ("dossier d'installation modifiable par un autre compte que les administrateurs : {0}" -f (Get-AclWeakness $Dir))
    Note ("  installé dans {0} ; Test-AdminOnlyPath = {1}" -f $Dir, (Test-AdminOnlyPath $Exe))
}
Verifier 'Le dossier ne se choisit pas : /D=C:\AeroxCustom est ignoré' {
    $code = Lancer-Programme $Setup '/S /D=C:\AeroxCustom'
    Exiger ($code -eq 0) "code de sortie $code"
    Exiger-Installation 'avec /D='
    Exiger (-not (Test-Path -LiteralPath 'C:\AeroxCustom\AeroxPCCare.exe')) 'AEROX installé dans C:\AeroxCustom malgré tout'
}
Verifier 'Réinstallation par-dessus (même version) : rien de perdu, la tâche « lancer avec Windows » n''est pas touchée' {
    Preparer-Reglages
    Register-TacheDiscret $Exe $Tache
    $tacheAvant = Get-TacheInfo $Tache
    $avant = (Get-ChildItem -LiteralPath (Join-Path $Dir 'protege') -Recurse -File | Measure-Object).Count
    $code = Lancer-Programme $Setup '/S'
    Exiger ($code -eq 0) "code de sortie $code"
    Exiger-Installation 'réinstallation'
    $apres = (Get-ChildItem -LiteralPath (Join-Path $Dir 'protege') -Recurse -File | Measure-Object).Count
    Exiger ($apres -eq $avant) "fichiers du dossier protégé : $avant avant, $apres après"
    Exiger-Tache 'réinstallation' $tacheAvant
    Unregister-ScheduledTask -TaskName $Tache -Confirm:$false -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------------------------------- Lanceur
$zone = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
Note ("Zone utile de l'écran de cette machine : {0}x{1}" -f $zone.Width, $zone.Height)
Verifier 'Lancement réel : la fenêtre principale apparaît et tient dans la zone utile de l''écran (M4)' {
    Stop-Aerox; Preparer-Reglages
    $p = Start-Exe $Exe
    try {
        $r = Wait-Fenetre $p '^visible \| HwndWrapper.*\| AEROX PC Care \|' 150
        Note-Fenetres $r
        Exiger (-not $r.Sorti -and -not $r.Delai) 'la fenêtre principale n''est pas apparue'
        $w = @($r.Fenetres | Where-Object { $_ -match '^visible \| HwndWrapper.*\| AEROX PC Care \|' })[0]
        Exiger ($w -match 'taille=(\d+)x(\d+)') 'taille de la fenêtre illisible'
        $lw = [int]$Matches[1]; $lh = [int]$Matches[2]
        Note ("  fenêtre {0}x{1} dans une zone utile de {2}x{3}" -f $lw, $lh, $zone.Width, $zone.Height)
        Exiger ($lw -le $zone.Width -and $lh -le $zone.Height) ("fenêtre {0}x{1} plus grande que la zone utile {2}x{3}" -f $lw, $lh, $zone.Width, $zone.Height)
    } finally { Stop-Aerox }
}
Verifier 'Lanceur : la marque « téléchargé depuis Internet » n''est retirée que des fichiers d''AEROX, jamais d''un fichier voisin (S2)' {
    Stop-Aerox; Preparer-Reglages
    $marque = "[ZoneTransfer]`r`nZoneId=3`r`n"
    $voisin = Join-Path $Dir 'voisin-telecharge.txt'
    $siens = @((Join-Path $Dir 'AeroxPCCare.ps1'), (Join-Path $Dir 'AeroxPCCare.Native.dll'))
    function Test-Marque([string]$Fichier) { return [bool](Get-Item -LiteralPath $Fichier -Stream 'Zone.Identifier' -ErrorAction SilentlyContinue) }
    try {
        Set-Content -LiteralPath $voisin -Value 'un autre fichier telecharge'
        foreach ($f in @($voisin) + $siens) { Set-Content -LiteralPath $f -Stream 'Zone.Identifier' -Value $marque }
        foreach ($f in @($voisin) + $siens) { Exiger (Test-Marque $f) "marque de départ non posée sur $f" }
        $p = Start-Exe $Exe
        try {
            $r = Wait-Fenetre $p '^visible \| HwndWrapper.*\| AEROX PC Care \|' 150
            Exiger (-not $r.Sorti -and -not $r.Delai) 'la fenêtre principale n''est pas apparue'
        } finally { Stop-Aerox }
        foreach ($f in $siens) { Exiger (-not (Test-Marque $f)) ("marque « téléchargé » pas retirée de " + (Split-Path $f -Leaf)) }
        Exiger (Test-Marque $voisin) 'le fichier voisin a perdu sa marque « téléchargé » : le lanceur débloque aussi ce qui n''est pas à lui'
    } finally { Remove-Item -LiteralPath $voisin -Force -ErrorAction SilentlyContinue }
}
Verifier 'Script modifié : le lanceur refuse de le lancer en administrateur' {
    Stop-Aerox
    $ps1 = Join-Path $Dir 'AeroxPCCare.ps1'
    $orig = [IO.File]::ReadAllBytes($ps1)
    try {
        [IO.File]::WriteAllBytes($ps1, $orig + [byte[]](0x23, 0x20, 0x78))
        $p = Start-Exe $Exe
        $r = Wait-Fenetre $p '#32770' 90
        Note-Fenetres $r
        Exiger (-not @($r.Fenetres | Where-Object { $_ -match 'HwndWrapper' }).Count) 'la fenêtre principale s''est ouverte avec un script modifié'
        Exiger (@($r.Fenetres | Where-Object { $_ -match 'ne correspond pas' }).Count -eq 1) 'pas de message de refus'
    } finally { Stop-Aerox; [IO.File]::WriteAllBytes($ps1, $orig) }
    Exiger (Meme-Fichier $ps1 (Join-Path $Appli 'AeroxPCCare.ps1')) 'script d''origine non remis'
}
Verifier 'Module natif (DLL) modifié : le logiciel refuse de démarrer' {
    Stop-Aerox
    $dll = Join-Path $Dir 'AeroxPCCare.Native.dll'
    $orig = [IO.File]::ReadAllBytes($dll)
    try {
        [IO.File]::WriteAllBytes($dll, $orig + [byte[]](0, 0, 0, 0))
        $p = Start-Exe $Exe
        $r = Wait-Fenetre $p '#32770|HwndWrapper' 90
        Note-Fenetres $r
        Exiger (-not @($r.Fenetres | Where-Object { $_ -match '^visible \| HwndWrapper.*\| AEROX PC Care \|' }).Count) 'la fenêtre principale s''est ouverte avec un module modifié'
        Exiger ($r.Sorti -or @($r.Fenetres | Where-Object { $_ -match '#32770' }).Count -ge 1) 'ni message de refus ni arrêt du programme'
    } finally { Stop-Aerox; [IO.File]::WriteAllBytes($dll, $orig) }
    Exiger (Meme-Fichier $dll (Join-Path $Appli 'AeroxPCCare.Native.dll')) 'module d''origine non remis'
}

# ---------------------------------------------------------------------------------------------------- Lancement avec Windows (M2)
Verifier 'Au démarrage, une tâche « lancer avec Windows » qui vise un dossier libre est retirée' {
    Stop-Aerox; Preparer-Reglages
    New-Item -ItemType Directory -Force 'C:\AeroxOld' | Out-Null
    Copy-Item -LiteralPath $Exe -Destination 'C:\AeroxOld\AeroxPCCare.exe' -Force
    Register-TacheDiscret 'C:\AeroxOld\AeroxPCCare.exe' $Tache
    Exiger ((Get-TacheInfo $Tache).Cible -eq 'C:\AeroxOld\AeroxPCCare.exe') 'tâche de départ mal créée'
    $p = Start-Exe $Exe
    try {
        $r = Wait-Fenetre $p '^visible \| HwndWrapper.*\| AEROX PC Care \|' 150
        Exiger (-not $r.Sorti -and -not $r.Delai) 'la fenêtre principale n''est pas apparue'
        $retiree = $false
        for ($i = 0; $i -lt 60; $i++) { if (-not (Get-ScheduledTask -TaskName $Tache -ErrorAction SilentlyContinue)) { $retiree = $true; break }; Start-Sleep -Seconds 1 }
        Exiger $retiree 'la tâche qui vise C:\AeroxOld est toujours là 60 s après le démarrage'
    } finally { Stop-Aerox; Unregister-ScheduledTask -TaskName $Tache -Confirm:$false -ErrorAction SilentlyContinue; Remove-Item -LiteralPath 'C:\AeroxOld' -Recurse -Force -ErrorAction SilentlyContinue }
}
Verifier 'Au démarrage, une tâche qui vise le programme installé dans Program Files est conservée' {
    Stop-Aerox; Preparer-Reglages
    Register-TacheDiscret $Exe $Tache
    $p = Start-Exe $Exe
    try {
        $r = Wait-Fenetre $p '^visible \| HwndWrapper.*\| AEROX PC Care \|' 150
        Exiger (-not $r.Sorti -and -not $r.Delai) 'la fenêtre principale n''est pas apparue'
        Start-Sleep -Seconds 20
        Exiger ([bool](Get-ScheduledTask -TaskName $Tache -ErrorAction SilentlyContinue)) 'la tâche saine a été retirée'
        $i = Get-TacheInfo $Tache
        Exiger ($i.Cible -eq $Exe -and $i.Arguments -eq '--discret' -and $i.Niveau -eq 'Highest') ("tâche modifiée : {0} {1} {2}" -f $i.Cible, $i.Arguments, $i.Niveau)
    } finally { Stop-Aerox; Unregister-ScheduledTask -TaskName $Tache -Confirm:$false -ErrorAction SilentlyContinue }
}

# ---------------------------------------------------------------------------------------------------- Reprise d'une ancienne installation (M2)
Verifier 'Ancienne installation dans un dossier libre : reprise, fichiers d''AEROX retirés, fichier perso gardé, tâche déplacée avec tous ses réglages' {
    Nettoyer
    Preparer-Ancienne 'C:\AeroxOld' -AvecFichierPerso -AvecTache
    $tacheAvant = Get-TacheInfo $Tache
    Exiger ($tacheAvant.Cible -eq 'C:\AeroxOld\AeroxPCCare.exe') "tâche de départ : « $($tacheAvant.Cible) »"
    $code = Lancer-Programme $Setup '/S'
    Exiger ($code -eq 0) "code de sortie $code"
    Exiger-Installation 'reprise'
    foreach ($f in $Fichiers + @('Desinstaller.exe')) { Exiger (-not (Test-Path -LiteralPath (Join-Path 'C:\AeroxOld' $f))) "$f est resté dans l'ancien dossier" }
    Exiger (-not (Test-Path -LiteralPath 'C:\AeroxOld\maj')) 'dossier maj resté dans l''ancien dossier'
    Exiger ((Get-Content -LiteralPath 'C:\AeroxOld\mes-notes.txt' -ErrorAction Stop) -eq 'a garder') 'fichier perso touché'
    Exiger-Tache 'reprise' $tacheAvant
}
Verifier 'Ancienne installation sans autre fichier : l''ancien dossier disparaît' {
    Nettoyer
    Preparer-Ancienne 'C:\AeroxOld'
    $code = Lancer-Programme $Setup '/S'
    Exiger ($code -eq 0) "code de sortie $code"
    Exiger-Installation 'reprise'
    Exiger (-not (Test-Path -LiteralPath 'C:\AeroxOld')) 'dossier vide resté'
}
Verifier 'Registre qui désigne le dossier actuel (autre écriture) ou son parent : rien de ce qui vient d''être installé n''est effacé' {
    foreach ($ecriture in @(($Dir.ToLower() + '\'), $Dir.ToUpper(), $env:ProgramFiles, ($env:ProgramFiles + '\'))) {
        Nettoyer
        New-Item -Path $Cle -Force | Out-Null
        Set-ItemProperty -LiteralPath $Cle -Name 'Dossier' -Value $ecriture
        Set-ItemProperty -LiteralPath $Cle -Name 'InstallLocation' -Value $ecriture
        $code = Lancer-Programme $Setup '/S'
        Exiger ($code -eq 0) "code de sortie $code (registre : $ecriture)"
        Exiger-Installation "registre « $ecriture »"
        Exiger (Test-Path -LiteralPath $env:ProgramFiles) 'Program Files supprimé !'
    }
}

# ---------------------------------------------------------------------------------------------------- Mise à jour automatique
Verifier 'Mise à jour silencieuse (/S /UPDATE) : installée, puis AEROX est relancé tout seul' {
    Nettoyer
    $code = Lancer-Programme $Setup '/S'
    Exiger ($code -eq 0) "première installation : code $code"
    Preparer-Reglages
    Register-TacheDiscret $Exe $Tache
    $tacheAvant = Get-TacheInfo $Tache
    $code = Lancer-Programme $Setup '/S /UPDATE'
    Exiger ($code -eq 0) "mise à jour : code $code"
    Exiger-Installation 'mise à jour'
    Exiger-Tache 'mise à jour' $tacheAvant
    $vu = $false
    for ($i = 0; $i -lt 40; $i++) { if (Get-Process -Name 'AeroxPCCare' -ErrorAction SilentlyContinue) { $vu = $true; break }; Start-Sleep -Milliseconds 500 }
    Exiger $vu 'AEROX n''a pas été relancé après la mise à jour'
    Stop-Aerox
}

# ---------------------------------------------------------------------------------------------------- Désinstallation
Verifier 'Désinstallation silencieuse : fichiers, tâche, registre et raccourcis retirés, données gardées' {
    Stop-Aerox
    Register-TacheDiscret $Exe $Tache
    $outil = Join-Path $Dir 'protege\outils'; New-Item -ItemType Directory -Force $outil | Out-Null; Set-Content -LiteralPath (Join-Path $outil 'x.txt') 'x'
    $donnees = @(Get-ChildItem -LiteralPath (Join-Path $Dir 'protege\donnees') -Recurse -File -ErrorAction SilentlyContinue).Count
    Exiger ($donnees -ge 1) 'pas de données à garder pour le test'
    $code = Lancer-Programme (Join-Path $Dir 'Desinstaller.exe') "/S _?=$Dir"
    Exiger ($code -eq 0) "code de sortie $code"
    foreach ($f in $Fichiers) { Exiger (-not (Test-Path -LiteralPath (Join-Path $Dir $f))) "$f est resté" }
    Exiger (-not (Get-ScheduledTask -TaskName $Tache -ErrorAction SilentlyContinue)) 'la tâche planifiée est restée'
    Exiger (-not (Test-Path -LiteralPath $Cle)) 'clé du registre restée'
    Exiger (-not (Test-Path -LiteralPath $Bureau)) 'raccourci du Bureau resté'
    Exiger (-not (Test-Path -LiteralPath $Menu)) 'raccourci du menu Démarrer resté'
    Exiger (-not (Test-Path -LiteralPath (Join-Path $Dir 'protege\outils'))) 'outils téléchargés restés'
    Exiger (@(Get-ChildItem -LiteralPath (Join-Path $Dir 'protege\donnees') -Recurse -File -ErrorAction SilentlyContinue).Count -eq $donnees) 'données supprimées en mode silencieux'
}

Nettoyer
Note ''
Note ("RÉSUMÉ : {0} échec(s)" -f $script:Echecs.Count)
foreach ($e in $script:Echecs) { Note ("  - " + $e) }
Envoyer 'Installation'
exit $(if ($script:Echecs.Count) { 1 } else { 0 })
