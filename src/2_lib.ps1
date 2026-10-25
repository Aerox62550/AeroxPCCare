
# =====================================================================
#  Bibliothèque des tâches (exécutée en arrière-plan : l'interface ne fige pas)
# =====================================================================
Set-SplashStep 50 'Chargement des outils…'
$TaskLibrary = {
$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
$script:TotalFreed     = [double]0
$script:LastLine       = ''
$script:NativeOutput   = New-Object System.Collections.ArrayList

# ---------------------------------------------------------------- Outils
function Log([string]$Message) {
    if ($Message) { $sync.Queue.Enqueue(("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message)) }
    else          { $sync.Queue.Enqueue('') }
}

# Dossier des raccourcis temporaires ouverts dans la session de la personne : un nom imprévisible à chaque fois
# (personne ne peut préparer ou remplacer le fichier à l'avance), et les anciens sont effacés.
function New-SessionShortcutPath([string]$Ext) {
    # Dans le dossier protégé (Program Files) : ProgramData laisse n'importe quel compte créer le dossier avant AEROX
    # et remplacer le raccourci entre son écriture et son ouverture (relecture Gemini n° 4)
    $dir = Get-SecureDir 'session'
    foreach ($old in @(Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(lien|lancer)' -and $_.LastWriteTime -lt (Get-Date).AddMinutes(-10) })) { try { Remove-Item -LiteralPath $old.FullName -Force } catch {} }
    return (Join-Path $dir ("{0}-{1}{2}" -f $(if ($Ext -eq '.url') { 'lien' } else { 'lancer' }), [guid]::NewGuid().ToString('N'), $Ext))
}
# Ouvre un lien dans la session de la personne connectée (tâche planifiée temporaire « seulement si l'utilisateur
# est connecté » : aucun mot de passe nécessaire), via un raccourci .url (pas de limite de longueur ni de souci de guillemets).
function Open-UrlAsSessionUser([string]$Url) {
    $tn = 'AEROX PC Care - ouvrir un lien'
    try {
        $user = "$((Get-CimStatic Win32_ComputerSystem).UserName)"
        if (-not $user) { return $false }
        $lnk = New-SessionShortcutPath '.url'
        $abs = ([uri]$Url).AbsoluteUri
        [IO.File]::WriteAllText($lnk, "[InternetShortcut]`r`nURL=$abs`r`n", [Text.Encoding]::ASCII)
        $a = New-ScheduledTaskAction -Execute (Join-Path $env:SystemRoot 'explorer.exe') -Argument ('"{0}"' -f $lnk)
        $p = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
        $st = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
        Register-ScheduledTask -TaskName $tn -Action $a -Principal $p -Settings $st -Force -ErrorAction Stop | Out-Null
        Start-ScheduledTask -TaskName $tn -ErrorAction Stop
        Start-Sleep -Milliseconds 1500
        return $true
    } catch { return $false }
    finally { try { Unregister-ScheduledTask -TaskName $tn -Confirm:$false -ErrorAction SilentlyContinue } catch {} }
}

# Lance un programme dans la session de la personne devant l'écran (sans droits admin), quand AEROX tourne
# avec le mot de passe d'un autre compte : sinon le programme s'ouvrirait dans le compte administrateur.
function Start-AsSessionUser([string]$Exe, [string]$Arguments = '') {
    $tn = 'AEROX PC Care - lancer pour la session'
    try {
        $user = "$((Get-CimStatic Win32_ComputerSystem).UserName)"
        if (-not $user -or -not $Exe) { return $false }
        $explorer = Join-Path $env:SystemRoot 'explorer.exe'
        if ([IO.Path]::GetFileName($Exe) -ieq 'explorer.exe') {
            # L'Explorateur passe la main au bureau de la personne et se ferme aussitôt
            if ($Arguments) { $a = New-ScheduledTaskAction -Execute $explorer -Argument $Arguments } else { $a = New-ScheduledTaskAction -Execute $explorer }
        } else {
            # Un programme lancé directement par la tâche serait fermé avec elle : on passe par un raccourci
            # ouvert par l'Explorateur, le programme devient alors un programme normal du bureau de la personne
            $lnk = New-SessionShortcutPath '.lnk'
            $ws = New-Object -ComObject WScript.Shell
            $sc = $ws.CreateShortcut($lnk); $sc.TargetPath = $Exe; $sc.Arguments = $Arguments; $sc.WorkingDirectory = (Split-Path $Exe -Parent); $sc.Save()
            $a = New-ScheduledTaskAction -Execute $explorer -Argument ('"{0}"' -f $lnk)
        }
        $p = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
        $st = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
        Register-ScheduledTask -TaskName $tn -Action $a -Principal $p -Settings $st -Force -ErrorAction Stop | Out-Null
        Start-ScheduledTask -TaskName $tn -ErrorAction Stop
        Start-Sleep -Milliseconds 1500
        try { $script:LastSessionTask = "{0} / 0x{1:X}" -f (Get-ScheduledTask -TaskName $tn).State, [int](Get-ScheduledTaskInfo -TaskName $tn).LastTaskResult } catch {}
        return $true
    } catch { $script:LastSessionTask = "échec : $($_.Exception.Message)"; return $false }
    finally { try { Unregister-ScheduledTask -TaskName $tn -Confirm:$false -ErrorAction SilentlyContinue } catch {} }
}

# Ouvre une page des Paramètres (ms-settings:), le Store ou une appli Windows. Avec le mot de passe d'un autre
# compte, elle s'ouvre chez la personne devant l'écran (sinon : dans le compte admin, invisible ou en erreur).
# Jamais ouvert directement avec les droits admin : le programme associé à un lien ou à un protocole peut être changé
# sans droits admin. On passe par l'Explorateur, qui l'ouvre dans la session normale (sans droits admin).
# Seulement les liens qu'AEROX utilise vraiment, en entier (pages des Paramètres, Sécurité Windows, Store, Steam, Caméra)
function Test-WinUriAllowed([string]$Uri) {
    return ($Uri -cmatch '^(ms-settings:[a-z0-9-]+|windowsdefender:(//[a-z]+)?|ms-windows-store://pdp/\?ProductId=[A-Z0-9]{12}|ms-availablenetworks:|steam://open/games|steam://uninstall/\d{1,10}|microsoft\.windows\.camera:)\z')
}
function Open-WinUri {
    [CmdletBinding()] param([string]$Uri)
    if (-not (Test-WinUriAllowed $Uri)) { throw "Lien non autorisé : $Uri" }
    $explorer = Join-Path $env:SystemRoot 'explorer.exe'
    if (Test-OtherAccount) { if (Start-AsSessionUser $explorer $Uri) { return } }
    Start-Process -FilePath $explorer -ArgumentList $Uri
}
# Outils de Windows (.msc, .cpl, .exe de System32) lancés par leur chemin complet, jamais par leur association
function Open-SystemTool([string]$Name) {
    $sys = Join-Path $env:SystemRoot 'System32'
    if ($Name -notmatch '^[\w.-]+$') { throw "Outil inconnu : $Name" }
    if ($Name -like '*.msc') { Start-Process -FilePath (Join-Path $sys 'mmc.exe') -ArgumentList ('"{0}"' -f (Join-Path $sys $Name)); return }
    if ($Name -like '*.cpl') { Start-Process -FilePath (Join-Path $sys 'control.exe') -ArgumentList $Name; return }
    Start-Process -FilePath (Join-Path $sys $Name)
}

# Ouvre une page web sur n'importe quel PC. Start-Process seul échoue (« fichier introuvable ») quand le logiciel
# tourne sous un autre compte que la personne devant le PC (compte standard + mot de passe d'un compte ADMIN) :
# ce compte-là n'a souvent aucun navigateur par défaut. On essaie alors les navigateurs installés, puis l'Explorateur,
# et en dernier recours le lien est copié pour être collé à la main.
function Open-Url([string]$Url) {
    if (-not $Url) { return $false }
    # Logiciel ouvert avec le mot de passe d'un autre compte : la page doit s'ouvrir chez la personne devant l'écran,
    # avec SON navigateur, pas dans le compte administrateur (où rien n'apparaît)
    # Pages web seulement (jamais un fichier ou un autre type de lien)
    try { $u = [uri]$Url; if ($u.Scheme -notin 'https', 'http') { return $false }; $Url = $u.AbsoluteUri } catch { return $false }
    if (Test-OtherAccount) { if (Open-UrlAsSessionUser $Url) { return $true } }
    # Le navigateur s'ouvre par l'Explorateur, dans la session normale : jamais avec les droits admin d'AEROX
    # (le navigateur par défaut peut être changé sans droits admin, et un navigateur ne doit pas tourner en administrateur)
    try { Start-Process -FilePath (Join-Path $env:SystemRoot 'explorer.exe') -ArgumentList ('"{0}"' -f $Url) -ErrorAction Stop; return $true } catch {}
    try { Set-Clipboard -Value $Url -ErrorAction Stop } catch {}
    Log ("⚠ Impossible d'ouvrir le navigateur sur ce PC. Le lien est copié : colle-le dans ton navigateur (Ctrl+V) → {0}" -f $Url)
    return $false
}
# Ouvre dans la session de la personne (sans droits admin) un fichier créé par AEROX dans son dossier protégé
# (rapport de batterie…). Jamais un autre fichier.
function Open-LocalFile([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($AppInfo.Secure.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $full -PathType Leaf)) { return $false }
    $explorer = Join-Path $env:SystemRoot 'explorer.exe'
    if (Test-OtherAccount) { return [bool](Start-AsSessionUser $explorer ('"{0}"' -f $full)) }
    try { Start-Process -FilePath $explorer -ArgumentList ('"{0}"' -f $full) -ErrorAction Stop; return $true } catch { return $false }
}
function Step([string]$Message) { $sync.Progress = -1; Log ''; Log ("▶ " + $Message) }

function ConvertTo-DateSafe($d) {
    if ($null -eq $d) { return $null }
    if ($d -is [datetime]) { return $d }
    $t = "$d"
    if ($t -match '^\d{14}\.\d{6}[+-]\d{3}$') { try { return [Management.ManagementDateTimeConverter]::ToDateTime($t) } catch {} }
    try { return [datetime]::Parse($t, [Globalization.CultureInfo]::InvariantCulture) } catch {}
    try { return [datetime]$t } catch {}
    return $null
}
function Format-Date($d, [string]$Fmt = 'dd/MM/yyyy') { $x = ConvertTo-DateSafe $d; if ($x) { return $x.ToString($Fmt) } else { return '?' } }
# Taille lisible : « 16 Go » (valeur ronde), « 28,40 Go », « 931,5 Go », « 1,82 To »
function Format-Size([double]$Bytes) {
    if ($Bytes -ge 1GB) {
        $v = $Bytes / 1GB; $u = 'Go'
        if ($Bytes -ge 1TB) { $v = $Bytes / 1TB; $u = 'To' }
        $fmt = if ($v -eq [math]::Floor($v)) { '{0:N0}' } elseif ($u -eq 'Go' -and $v -ge 100) { '{0:N1}' } else { '{0:N2}' }
        return (($fmt -f $v) + " $u")
    }
    if ($Bytes -ge 1MB) { return ("{0:N1} Mo" -f ($Bytes / 1MB)) }
    return ("{0:N0} Ko" -f ($Bytes / 1KB))
}

# Journal des bugs (envoyé au développeur uniquement si l'utilisateur fait un rapport)
function Write-Bug {
    param([string]$Context, $ErrorRecord, [string]$Type = 'bug')
    try {
        $isRec = $ErrorRecord -is [System.Management.Automation.ErrorRecord]
        $msg = if ($isRec) { $ErrorRecord.Exception.Message } else { "$ErrorRecord" }
        $pos = if ($isRec -and $ErrorRecord.InvocationInfo) { ($ErrorRecord.InvocationInfo.PositionMessage -replace '\s+', ' ').Trim() } else { '' }
        $entry = [ordered]@{ date = (Get-Date).ToString('s'); version = $AppInfo.Version; type = $Type; context = $Context; message = $msg; position = $pos }
        [IO.File]::AppendAllText($AppInfo.BugFile, (($entry | ConvertTo-Json -Compress) + "`r`n"), (New-Object Text.UTF8Encoding($false)))
    } catch {}
}

# Code d'erreur Windows (0x8024...) : PowerShell enveloppe les erreurs COM, le vrai code est dans l'exception la plus profonde
function Get-ErrorCode($Err) {
    $ex = $Err.Exception; while ($ex.InnerException) { $ex = $ex.InnerException }
    return ('0x{0:X8}' -f $ex.HResult)
}

# Erreur rencontrée pendant une action : affichée clairement avec sa cause et sa réparation
function Add-TaskError {
    param([string]$Title, [string]$Cause, [string]$Effect, [string]$Code, [string]$FixLabel, [string]$FixAction, [string]$Confirm, [string[]]$Steps, $Bug)
    [void]$sync.Errors.Add(@{ Title = $Title; Cause = $Cause; Effect = $Effect; Code = $Code; FixLabel = $FixLabel; FixAction = $FixAction; Confirm = $Confirm; Steps = $Steps; IsBug = [bool]$Bug })
    Log ("❌ ERREUR : " + $Title + $(if ($Code) { " ($Code)" } else { '' }))
    if ($Cause)    { Log ("   Cause : " + $Cause) }
    if ($FixLabel) { Log ("   → Réparation possible : « $FixLabel »") }
    if ($Bug) { Write-Bug -Context $Title -ErrorRecord $Bug -Type 'bug' }
    else      { Write-Bug -Context 'Erreur' -ErrorRecord ("$Title. $Cause" + $(if ($Code) { " [$Code]" } else { '' })) -Type 'erreur' }
}

function Get-FolderSize([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return [double]0 }
    $s = (Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if ($s) { return [double]$s } else { return [double]0 }
}

# Suppression sûre : ne suit JAMAIS les liens/jonctions, ignore les fichiers verrouillés
# Suppression avec les droits admin : jamais à travers un lien (jonction, lien symbolique), même glissé au dernier moment
# (voir AeroxSafeDelete dans AeroxNative.cs : chaque élément est vérifié puis supprimé par le même accès)
function Remove-ItemSafe($Item) {
    if (-not $Item) { return [double]0 }
    return [double][AeroxSafeDelete]::DeleteItem("$($Item.FullName)")
}

function Remove-PathContent([string]$Path) {
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return [double]0 }
    return [double][AeroxSafeDelete]::CleanDir($Path)
}
# Dossier protégé (créé au besoin) : Program Files\AeroxPCCare\protege\<sous-dossier>
function Get-SecureDir([string]$Sub) {
    $d = if ($Sub) { Join-Path $AppInfo.Secure $Sub } else { $AppInfo.Secure }
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Force -Path $d -ErrorAction Stop | Out-Null }
    return $d
}
# Le nom d'organisation du certificat (« O=… » dans son sujet) est-il EXACTEMENT celui attendu ?
# « O=Intel Corporation » oui ; « O=Intel Corporation Fake » ou « O=Fake Intel Corporation » non.
function Test-CertOrg([string]$Subject, [string]$Org) {
    return ("$Subject" -match ('(?i)(^|,\s*)O=' + [regex]::Escape($Org) + '\s*(,|$)'))
}
# Programme signé par l'éditeur attendu (signature Windows valide + organisation du certificat exacte) ?
function Test-ToolSignature([string]$Path, [string]$Publisher) {
    try {
        $sig = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
        return ($sig.Status -eq 'Valid' -and (Test-CertOrg $sig.SignerCertificate.Subject $Publisher))
    } catch { return $false }
}

# ---------------------------------------------------------------- Dossiers réservés aux administrateurs
# Un lancement automatique avec les droits admin (tâche « mode discret ») n'est permis que pour un programme que PERSONNE d'autre
# que SYSTEM, les administrateurs et TrustedInstaller ne peut modifier, supprimer ou remplacer : sinon n'importe quel programme du
# compte pourrait remplacer le fichier et se faire exécuter en administrateur au prochain démarrage de Windows.
$script:AutoTaskName = 'AEROX PC Care (mode discret)'
$script:AdminSids = @('S-1-5-18', 'S-1-5-32-544', 'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464')   # SYSTEM, Administrateurs, TrustedInstaller
# '' si seuls ces comptes peuvent modifier ce fichier ou dossier (et en changer les droits) ; sinon une phrase qui dit pourquoi
function Get-AclWeakness([string]$Path) {
    $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
    $own = "$($acl.GetOwner([Security.Principal.SecurityIdentifier]).Value)"
    if ($own -notin $script:AdminSids) { return "propriétaire $own" }
    # Écrire, ajouter, supprimer (lui ou son contenu), changer les droits, devenir propriétaire (+ droits génériques d'écriture / contrôle total)
    $mask = 0x2 -bor 0x4 -bor 0x40 -bor 0x10000 -bor 0x40000 -bor 0x80000 -bor 0x40000000 -bor 0x10000000
    foreach ($r in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
        if ($r.AccessControlType -ne 'Allow') { continue }
        if ($r.PropagationFlags -band [Security.AccessControl.PropagationFlags]::InheritOnly) { continue }   # ne vaut que pour ce qu'il y a dedans
        $sid = "$($r.IdentityReference.Value)"
        if ($sid -in $script:AdminSids -or $sid -eq 'S-1-3-0') { continue }                                   # S-1-3-0 : CREATOR OWNER
        if (([int]$r.FileSystemRights) -band $mask) { return "$sid : $($r.FileSystemRights)" }
    }
    return ''
}
# Dans Program Files, sans lien (jonction, lien symbolique) en chemin, et ni le fichier ni aucun dossier jusqu'à Program Files
# ne peut être modifié par un autre compte que SYSTEM / administrateurs / TrustedInstaller
function Test-AdminOnlyPath([string]$Path) {
    try {
        if (-not $Path) { return $false }
        $full = [IO.Path]::GetFullPath($Path).TrimEnd('\')
        $root = $null
        foreach ($pf in @($env:ProgramW6432, $env:ProgramFiles, ${env:ProgramFiles(x86)})) {
            if ($pf -and $full.StartsWith($pf.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { $root = $pf.TrimEnd('\'); break }
        }
        if (-not $root) { return $false }
        $p = $full
        while ($p.Length -gt $root.Length) {
            $item = Get-Item -LiteralPath $p -Force -ErrorAction Stop
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { return $false }
            if (Get-AclWeakness $p) { return $false }
            $p = Split-Path $p -Parent
        }
        return $true
    } catch { return $false }
}
# Programme visé par la tâche « mode discret » (vide si la tâche n'existe pas)
function Get-AutoStartTarget {
    try {
        $t = Get-ScheduledTask -TaskName $script:AutoTaskName -ErrorAction Stop
        return [Environment]::ExpandEnvironmentVariables("$(@($t.Actions)[0].Execute)".Trim().Trim('"'))
    } catch { return '' }
}
# Tâche « mode discret » qui vise un programme que d'autres comptes pourraient remplacer (ancienne installation dans un dossier libre,
# fichier disparu) : retirée. Mieux vaut un lancement à la main qu'un programme inconnu lancé en administrateur à chaque démarrage.
function Repair-AutoStartTask {
    $target = Get-AutoStartTarget
    $exists = $false; try { $exists = [bool](Get-ScheduledTask -TaskName $script:AutoTaskName -ErrorAction Stop) } catch {}
    if (-not $exists) { return $false }
    if ($target -and (Test-AdminOnlyPath $target)) { return $false }
    Unregister-ScheduledTask -TaskName $script:AutoTaskName -Confirm:$false -ErrorAction SilentlyContinue
    Log "⚠ Le lancement d'AEROX avec Windows a été désactivé par sécurité : il visait un programme que d'autres logiciels du PC pourraient remplacer ($target). Réinstalle AEROX avec son installateur (il se range tout seul dans Program Files), puis réactive l'option dans Gaming."
    return $true
}

function Clear-Location([string]$Path, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $f = Remove-PathContent $Path
    $script:TotalFreed += $f
    if ($f -gt 0) { Log ("   ✔ {0} : {1} libérés" -f $Label, (Format-Size $f)) }
    else          { Log ("   • {0} : déjà propre" -f $Label) }
}

function Get-UserProfiles {
    @(Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue |
        Where-Object { -not $_.Special -and $_.LocalPath -and (Test-Path -LiteralPath $_.LocalPath) } |
        ForEach-Object { $_.LocalPath })
}

function Get-TempLocations {
    $list = New-Object System.Collections.ArrayList
    foreach ($p in Get-UserProfiles) {
        $u = Split-Path $p -Leaf
        [void]$list.Add(@{ Path = (Join-Path $p 'AppData\Local\Temp');       Label = "Fichiers temporaires de $u" })
        [void]$list.Add(@{ Path = (Join-Path $p 'AppData\Local\CrashDumps'); Label = "Rapports de plantage de $u" })
    }
    [void]$list.Add(@{ Path = "$env:SystemRoot\Temp";                                  Label = "Fichiers temporaires de Windows" })
    [void]$list.Add(@{ Path = "$env:ProgramData\Microsoft\Windows\WER\ReportArchive"; Label = "Rapports d'erreurs archivés" })
    [void]$list.Add(@{ Path = "$env:ProgramData\Microsoft\Windows\WER\ReportQueue";   Label = "Rapports d'erreurs en attente" })
    return $list
}

# Lance un programme Windows (dism, sfc, winget...) : sortie dans le journal (sauf -Quiet) et dans $script:NativeOutput
function Invoke-Native {
    param([string]$File, [string[]]$Arguments, [System.Text.Encoding]$Encoding, [switch]$Quiet)
    $oldEnc = $null
    if ($Encoding) { try { $oldEnc = [Console]::OutputEncoding; [Console]::OutputEncoding = $Encoding } catch { $oldEnc = $null } }
    $script:LastLine = ''
    $script:NativeOutput = New-Object System.Collections.ArrayList
    # Outil de Windows appelé par son nom : toujours celui de System32 (jamais un fichier du même nom ailleurs)
    if ($File -notmatch '[\\/]') { $sysf = Join-Path $env:SystemRoot "System32\$File"; if (Test-Path -LiteralPath $sysf) { $File = $sysf } }
    try {
        & $File @Arguments 2>&1 | ForEach-Object {
            $raw   = ("$_") -replace "`0", ''
            $parts = @($raw -split "`r" | Where-Object { $_.Trim() })
            if ($parts.Count -eq 0) { [void]$script:NativeOutput.Add(''); return }
            $line = $parts[-1].TrimEnd()
            [void]$script:NativeOutput.Add($line)
            $line = $line.Trim()
            if ($line -match '[█▒░]' -or $line -match '^[\s\-\\|/=]+$') { return }
            if ($line -match '(\d{1,3}(?:[.,]\d+)?)\s?%') {
                $v = [double]($matches[1] -replace ',', '.')
                if ($v -le 100) { $sync.Progress = $v }
                return
            }
            if ($Quiet -or $line -eq $script:LastLine) { return }
            $script:LastLine = $line
            Log ("   " + $line)
        }
    } finally {
        if ($oldEnc) { try { [Console]::OutputEncoding = $oldEnc } catch {} }
    }
    return $LASTEXITCODE
}

# winget est une appli du Microsoft Store installée PAR COMPTE : quand AEROX tourne avec le mot de passe d'un autre
# compte (compte standard + ADMIN), winget peut exister sur le PC mais refuser de se lancer (« Accès refusé »).
# On vérifie donc qu'il démarre vraiment avant de s'en servir.
function Get-Winget {
    if ($null -ne $script:WingetPath) { if ($script:WingetPath) { return $script:WingetPath } else { return $null } }
    $script:WingetBlocked = $false
    $cands = New-Object System.Collections.ArrayList
    # D'abord la copie officielle dans Program Files (protégée), signée par Microsoft ; le raccourci du dossier perso
    # (modifiable sans droits admin) seulement en dernier recours. Jamais une recherche par le PATH.
    foreach ($p in @(Get-ChildItem "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)) { if (Test-ToolSignature $p.FullName 'Microsoft Corporation') { [void]$cands.Add($p.FullName) } }
    $alias = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if ((Test-Path -LiteralPath $alias) -and ((Get-Item -LiteralPath $alias -Force -ErrorAction SilentlyContinue).Attributes -band [IO.FileAttributes]::ReparsePoint)) { [void]$cands.Add($alias) }
    foreach ($c in $cands) { if (Test-WingetRuns $c) { $script:WingetPath = $c; return $c }; $script:WingetBlocked = $true }
    # Présent sur le PC mais pas pour ce compte : on l'active pour ce compte (commande officielle de Windows), puis on réessaie
    if ($cands.Count -or (Test-Path "$env:ProgramFiles\WindowsApps")) {
        try {
            Add-AppxPackage -RegisterByFamilyName -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' -ErrorAction Stop
            Log "   ✔ Outil de mise à jour des logiciels (winget) activé pour ce compte"
            Start-Sleep -Seconds 2
            foreach ($c in @($alias) + @($cands)) { if ((Test-Path -LiteralPath $c) -and (Test-WingetRuns $c)) { $script:WingetPath = $c; $script:WingetBlocked = $false; return $c } }
        } catch {}
    }
    $script:WingetPath = ''
    return $null
}
function Test-WingetRuns([string]$Path) {
    try { $out = (& $Path --version 2>&1 | Out-String); return ($out -match 'v?\d+\.\d+') } catch { return $false }
}
# AEROX lancé avec le mot de passe d'un autre compte que celui de la session ouverte ?
function Test-OtherAccount {
    if ($null -ne $script:OtherAccount) { return $script:OtherAccount }
    $script:OtherAccount = Test-OtherAccountNow
    return $script:OtherAccount
}
function Test-OtherAccountNow {
    try {
        $me = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $console = "$((Get-CimStatic Win32_ComputerSystem).UserName)"
        return ($console -and $me -and $console -ne $me)
    } catch { return $false }
}
# Compte de la personne devant l'écran. Différent du compte qui fait tourner AEROX quand on a tapé le mot de passe
# d'un compte ADMIN : ses réglages (registre HKCU) et ses dossiers sont alors ceux de la personne, pas ceux de l'admin.
function Get-SessionUser {
    if ($null -ne $script:SessionUser) { return $script:SessionUser }
    $r = @{ Other = $false; Sid = ''; Profile = $env:USERPROFILE; Hkcu = 'HKCU:' }
    try {
        if (Test-OtherAccount) {
            $name = "$((Get-CimStatic Win32_ComputerSystem).UserName)"
            $sid = ([Security.Principal.NTAccount]$name).Translate([Security.Principal.SecurityIdentifier]).Value
            $hk = "Registry::HKEY_USERS\$sid"
            $prof = "$((Get-CimInstance Win32_UserProfile -Filter ("SID='{0}'" -f $sid) -ErrorAction Stop).LocalPath)"
            if ((Test-Path -LiteralPath $hk) -and $prof -and (Test-Path -LiteralPath $prof)) { $r = @{ Other = $true; Sid = $sid; Profile = $prof; Hkcu = $hk } }
        }
    } catch {}
    $script:SessionUser = $r
    return $r
}
# Dossier de la personne devant l'écran : nom de valeur de « User Shell Folders » ('Local AppData', 'AppData', 'Desktop', 'Startup',
# 'Personal' = Documents, 'My Pictures', 'My Video', 'My Music', 'Downloads') ou 'LocalLow'
function Get-SessionFolder([string]$Name) {
    $u = Get-SessionUser
    if ($Name -eq 'LocalLow') { return (Join-Path $u.Profile 'AppData\LocalLow') }
    $vn = if ($Name -eq 'Downloads') { '{374DE290-123F-4565-9164-39C4925E467B}' } else { $Name }
    try {
        # Valeur brute (sans développer %USERPROFILE%, qui serait celui du compte qui fait tourner AEROX)
        $k = Get-Item -LiteralPath "$($u.Hkcu)\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -ErrorAction Stop
        $v = [string]$k.GetValue($vn, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if ($v) { return [Environment]::ExpandEnvironmentVariables(($v -replace '(?i)%USERPROFILE%', $u.Profile.Replace('$', '$$'))) }
    } catch {}
    $sub = @{ 'Local AppData' = 'AppData\Local'; 'AppData' = 'AppData\Roaming'; 'Desktop' = 'Desktop'; 'Personal' = 'Documents'; 'My Pictures' = 'Pictures'
              'My Video' = 'Videos'; 'My Music' = 'Music'; 'Downloads' = 'Downloads'; 'Startup' = 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup' }
    if ($sub.ContainsKey($Name)) { return (Join-Path $u.Profile $sub[$Name]) }
    return ''
}
# Gros mots masqués avant publication d'un avis ou d'un rapport (ils restent publics sur GitHub) :
# la 1re lettre est gardée, le reste en étoiles (« c***** »). L'avis lui-même est toujours publié.
$script:Profanity = '(?i)(?<![\p{L}])(put(e|ain|ains)|merde(s|ux)?|chatte(s)?|bite(s)?|couilles?|connard(e|s)?|connasse(s)?|conne(s)?|con|cons|encul[ée]e?s?|salope(s)?|salaud(s)?|b[aâ]tard(e|s)?|niqu(e|er|é|ez)|ntm|fdp|tg|ta gueule|foutre|chier|chiant(e|s)?|cul|zob|teub|schneck|pd|p[ée]d[ée]s?|branleu?r(s)?|fuck(ing|er|ed)?|shit|bitch(es)?|dick|pussy|asshole|motherfucker|wtf)(?![\p{L}])'
function Hide-Profanity([string]$Text) {
    if (-not $Text) { return $Text }
    return [regex]::Replace($Text, $script:Profanity, { param($m) $w = $m.Value; $w.Substring(0, 1) + ('*' * ($w.Length - 1)) })
}
# Message clair quand winget manque ou ne peut pas être lancé
function Add-WingetError([string]$What) {
    if ($script:WingetUnreadable) {
        Add-TaskError -Title "Impossible de lister les mises à jour des logiciels" -Cause "L'outil de Microsoft (winget) a répondu de façon inattendue : il est sans doute trop ancien sur ce PC." `
            -Effect "$What impossible pour l'instant." -FixLabel "Mettre à jour l'outil (Microsoft Store)" -FixAction 'Open-WingetStore'
    } elseif (Test-OtherAccount) {
        Add-TaskError -Title "Les logiciels ne peuvent pas être mis à jour depuis ce compte" `
            -Cause "AEROX a été ouvert avec le mot de passe d'un autre compte (administrateur). L'outil de Microsoft qui met les logiciels à jour (winget) n'est installé que pour le compte de la personne." `
            -Effect "$What impossible pour l'instant. Le reste du logiciel marche normalement." `
            -Steps @("Ouvre la session du compte administrateur (Démarrer > icône de profil > changer d'utilisateur).", "Lance AEROX PC Care depuis cette session : les mises à jour des logiciels fonctionneront.")
    } else {
        Add-TaskError -Title "L'outil de mise à jour des logiciels (winget) est absent" -Cause "Le « Programme d'installation d'application » de Microsoft n'est pas installé ou trop ancien." `
            -Effect "$What impossible pour l'instant." -FixLabel "L'installer (Microsoft Store)" -FixAction 'Open-WingetStore'
    }
}
function Get-WingetExtraArgs([string]$Winget) {
    try { $v = ((& $Winget --version) | Out-String) -replace '[^\d\.]', ''; if ([version]$v -ge [version]'1.4') { return @('--disable-interactivity') } } catch {}
    return @()
}
# Logiciels ignorés (choisis par l'utilisateur, mémorisés dans les réglages)
function Get-IgnoredApps { if ($AppInfo.IgnoredApps) { return @($AppInfo.IgnoredApps) } else { return @() } }

# Liste des logiciels qui ont une mise à jour (lit le tableau de winget) : objets Name, Id, Version, Available
function Get-AppUpdates([switch]$IncludeIgnored) {
    $wg = Get-Winget
    if (-not $wg) { return $null }
    $script:WingetUnreadable = $false
    try { if ([Console]::BufferWidth -lt 300) { [Console]::BufferWidth = 400 } } catch {}
    $args1 = @('upgrade', '--accept-source-agreements') + (Get-WingetExtraArgs $wg)
    $ec = Invoke-Native $wg $args1 ([System.Text.Encoding]::UTF8) -Quiet
    $lines = @($script:NativeOutput)
    if (-not (Test-WingetAnswered $lines)) {
        # Réponse non reconnue (souvent : catalogue de winget pas encore chargé sur ce compte) : on le met à jour et on réessaie une fois
        Log "   … Mise à jour du catalogue de logiciels (winget), puis nouvel essai"
        $null = Invoke-Native $wg @('source', 'update') ([System.Text.Encoding]::UTF8) -Quiet
        $ec = Invoke-Native $wg $args1 ([System.Text.Encoding]::UTF8) -Quiet
        $lines = @($script:NativeOutput)
    }
    if (-not (Test-WingetAnswered $lines)) {
        $script:WingetUnreadable = $true
        $tail = (@($lines | Where-Object { "$_".Trim() -and "$_" -notmatch '^[\s\-\\|/█▒░]+$' } | Select-Object -Last 4) -join ' | ')
        $ver = ''; try { $ver = ((& $wg --version) | Out-String).Trim() } catch {}
        Write-Bug -Context 'Mises à jour des logiciels : réponse de winget non reconnue' -ErrorRecord ("winget $ver, code $ec : $tail") -Type 'bug'
        Log ("   ⚠ winget ($ver) a répondu quelque chose d'inattendu : {0}" -f $(if ($tail) { $tail } else { '(rien)' }))
        return $null
    }
    if (Test-OtherAccount) { Log "   (AEROX tourne avec un autre compte que la session ouverte : les logiciels installés seulement pour la session de la personne ne sont pas visibles d'ici)" }
    return ,(Add-AppGhostInfo (ConvertFrom-WingetTable $lines -IncludeIgnored:$IncludeIgnored))
}
# Liste de winget nettoyée : un logiciel n'apparaît qu'une fois (installé pour la session ET pour le PC = 2 lignes),
# et un logiciel déjà désinstallé dont il ne reste qu'une trace dans Windows est repéré (« Ghost ») :
# le « mettre à jour » le réinstallerait (retour d'un testeur : logiciels désinstallés qui revenaient)
function Add-AppGhostInfo($List) {
    $out = New-Object System.Collections.ArrayList; $seen = @{}
    $selfKeys = @(Get-SelfUpdatingKeys)
    foreach ($a in @($List)) {
        if (-not $a.Id -or $seen.ContainsKey($a.Id)) { continue }; $seen[$a.Id] = $true; $a.Ghost = $false
        $a.Self = ($selfKeys -contains (Get-SelfUpdatingKey $a.Id $a.Available))
        [void]$out.Add($a)
    }
    $inst = $null; try { $inst = Get-InstalledApps } catch {}
    if ($inst) {
        $w32 = @(@($inst) | Where-Object { $_.Kind -eq 'win32' })
        foreach ($a in $out) {
            $cut = "$($a.Name)".EndsWith([string][char]0x2026)
            $n = "$($a.Name)".TrimEnd([char]0x2026).Trim()
            if ($n.Length -lt 3) { continue }
            $m = @($w32 | Where-Object { $_.Name -eq $n -or ($cut -and $_.Name.StartsWith($n, [StringComparison]::OrdinalIgnoreCase)) })
            if ($m.Count -and -not @($m | Where-Object { Test-AppPresent $_ }).Count) { $a.Ghost = $true }
        }
    }
    return ,$out
}
# Logiciels que winget liste mais ne peut pas mettre à jour (Edge, Epic Online Services… : ils se mettent à jour
# tout seuls ou par leur lanceur ; ou « aucune mise à jour applicable »). Retenus par version : plus proposés
# ni comptés pour CETTE version, de nouveau proposés dès qu'une autre version sort. Fichier dans le dossier protégé.
function Get-SelfUpdatingKey([string]$Id, [string]$Version) { return ("$Id|$Version").Trim().ToLowerInvariant() }
function Get-SelfUpdatingFile { return (Join-Path (Get-SecureDir '') 'maj-geres-par-le-logiciel.txt') }
function Get-SelfUpdatingKeys {
    try { $f = Get-SelfUpdatingFile; if (Test-Path -LiteralPath $f) { return @(Get-Content -LiteralPath $f -Encoding UTF8 -ErrorAction Stop | Where-Object { $_ }) } } catch {}
    return @()
}
function Add-SelfUpdating([string]$Id, [string]$Version) {
    # Identifiant ou version coupés par winget (« … ») : pas fiables, rien n'est retenu
    if (-not $Id -or -not $Version -or "$Id$Version" -match [char]0x2026) { return }
    try {
        $k = Get-SelfUpdatingKey $Id $Version
        $all = @(Get-SelfUpdatingKeys | Where-Object { $_ -ne $k }) + $k
        [IO.File]::WriteAllLines((Get-SelfUpdatingFile), [string[]]@($all | Select-Object -Last 200), (New-Object Text.UTF8Encoding($false)))
    } catch {}
}
# Installateur d'un logiciel qui échoue (winget 0x8A150006) : la 2e fois pour la même version, le logiciel est
# considéré comme « à mettre à jour depuis lui-même » (iCUE, etc.) au lieu de réessayer et d'échouer à chaque fois
function Register-InstallerFailure([string]$Id, [string]$Version) {
    if (-not $Id -or -not $Version) { return $false }
    try {
        $f = Join-Path (Get-SecureDir '') 'maj-echecs.txt'
        $k = Get-SelfUpdatingKey $Id $Version
        $all = @(); if (Test-Path -LiteralPath $f) { $all = @(Get-Content -LiteralPath $f -Encoding UTF8 -ErrorAction Stop | Where-Object { $_ }) }
        if ($all -contains $k) { Add-SelfUpdating $Id $Version; return $true }
        [IO.File]::WriteAllLines($f, [string[]]@(@($all + $k) | Select-Object -Last 200), (New-Object Text.UTF8Encoding($false)))
    } catch {}
    return $false
}
# Le logiciel est-il encore vraiment sur le PC ? (son désinstalleur ou son dossier existe)
function Test-AppPresent($App) {
    if ("$($App.Cmd)" -match '(?i)msiexec') { return $true }      # installé avec Windows Installer : Windows tient sa liste à jour
    try {
        $exe = [Environment]::ExpandEnvironmentVariables((Get-ExeFromCommand "$($App.Cmd)"))
        if ($exe -and (Test-Path -LiteralPath $exe)) { return $true }
    } catch { return $true }
    if ($App.Location -and (Test-Path -LiteralPath $App.Location)) { return $true }
    return $false
}
# winget a-t-il donné une vraie réponse ? (un tableau, ou un message « rien à mettre à jour », en français ou en anglais)
function Test-WingetAnswered([string[]]$Lines) {
    foreach ($l in $Lines) {
        if ($l -match '(?i)\sid\s' -and $l -match '(?i)version') { return $true }
        if ($l -match "(?i)aucun(e)? (mise à (jour|niveau)|package|paquet|application)|no (available )?upgrade|no installed package|no applicable (update|upgrade)") { return $true }
    }
    return $false
}
function ConvertFrom-WingetTable([string[]]$Lines, [switch]$IncludeIgnored) {
    $list = New-Object System.Collections.ArrayList
    $hdr = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) { if ($Lines[$i] -match '(?i)\sid\s' -and $Lines[$i] -match '(?i)version') { $hdr = $i; break } }
    if ($hdr -lt 0) { return ,$list }
    $cols = @([regex]::Matches($Lines[$hdr], '\S+') | ForEach-Object { $_.Index })
    if ($cols.Count -lt 4) { return ,$list }
    $ignored = Get-IgnoredApps
    $i = $hdr + 1
    if ($i -lt $Lines.Count -and $Lines[$i] -match '^-{5,}') { $i++ }
    for (; $i -lt $Lines.Count; $i++) {
        $l = $Lines[$i]
        if (-not $l.Trim()) { break }
        if ($l -match '^-{5,}' -or $l -match '(?i)upgrades? available|mises? à (jour|niveau)|package\(s\)|packages? (have|ont)|^\d+ (mises?|upgrades?|packages?|paquets?|applications?) ') { break }
        $cell = { param($k) $a = $cols[$k]; if ($a -ge $l.Length) { return '' }; $b = if ($k + 1 -lt $cols.Count) { [math]::Min($cols[$k + 1], $l.Length) } else { $l.Length }; return $l.Substring($a, $b - $a).Trim() }
        $o = [ordered]@{ Name = (& $cell 0); Id = (& $cell 1); Version = (& $cell 2); Available = (& $cell 3) }
        if (-not $o.Id) { continue }
        $o.Ignored = ($ignored -contains $o.Id)
        if ($o.Ignored -and -not $IncludeIgnored) { continue }
        [void]$list.Add($o)
    }
    return ,$list
}

function Request-Reboot { $sync.NeedReboot = $true; Log "   → Un redémarrage va t'être proposé." }

# ---------------------------------------------------------------- Réseau (utilisé par le diagnostic et l'action)
function Get-NetworkStatus {
    $st = @{ Route = $false; Gw = ''; GwOk = $false; Internet = $false; Avg = 0; Dns = $false; Signal = -1 }
    $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1
    if (-not $route) { return $st }
    $st.Route = $true; $st.Gw = $route.NextHop
    $st.GwOk = [bool](Test-Connection -ComputerName $route.NextHop -Count 2 -Quiet -ErrorAction SilentlyContinue)
    $net = Test-Connection -ComputerName 1.1.1.1 -Count 4 -ErrorAction SilentlyContinue
    if (-not $net) { $net = Test-Connection -ComputerName 8.8.8.8 -Count 2 -ErrorAction SilentlyContinue }
    if ($net) { $st.Internet = $true; $st.Avg = [math]::Round(($net | Measure-Object -Property ResponseTime -Average).Average) }
    try { $null = [System.Net.Dns]::GetHostAddresses('www.microsoft.com'); $st.Dns = $true } catch {}
    $wlan = (netsh.exe wlan show interfaces 2>$null) | Out-String
    if ($wlan -match 'Signal\s*:\s*(\d+)\s*%') { $st.Signal = [int]$matches[1] }
    return $st
}

# ---------------------------------------------------------------- Historique des changements (avec annulation)
# Chaque modification faite par AEROX est notée dans changements.jsonl ; si elle est réversible,
# « Undo » contient l'action qui la défait. Les annulations faites sont notées dans changements_annules.txt.
# Texte -> chaîne PowerShell entre apostrophes, sûre (gère aussi les apostrophes typographiques ‘ ’ ‚ ‛)
function ConvertTo-PsLiteral([string]$Text) { return "'" + [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($Text) + "'" }
function ConvertTo-PsList([string[]]$Items) {
    if (-not $Items -or -not $Items.Count) { return '@()' }
    return '@(' + (($Items | ForEach-Object { ConvertTo-PsLiteral $_ }) -join ',') + ')'
}
# Une action d'annulation lue dans l'historique n'est exécutée que si c'est UNE commande connue
# avec uniquement des valeurs fixes (le fichier d'historique est modifiable par d'autres programmes).
function Test-SafeUndo([string]$Code) {
    $allowed = 'Set-UserProxy', 'Restore-HostsBackup', 'Set-StartupApps', 'Set-PowerScheme', 'Enable-StorageSense', 'Disable-StorageSense', 'Enable-Hibernation', 'Set-DisplayHz', 'Set-NetAdapterSleep', 'Restore-Dns', 'Set-CpuMaxState', 'Set-BgItem', 'Restore-RegBackup', 'Set-ReservedStorage', 'Set-HiberType', 'Set-RestoreSpace', 'Set-CompactOS', 'Resume-BitLockerOs', 'Restore-Quarantine'
    $tok = $null; $err = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Code, [ref]$tok, [ref]$err)
    if ($err.Count -or $ast.EndBlock.Statements.Count -ne 1 -or $ast.BeginBlock -or $ast.ProcessBlock) { return $false }
    $pipe = $ast.EndBlock.Statements[0]
    if ($pipe -isnot [System.Management.Automation.Language.PipelineAst] -or $pipe.PipelineElements.Count -ne 1) { return $false }
    $cmd = $pipe.PipelineElements[0]
    if ($cmd -isnot [System.Management.Automation.Language.CommandAst] -or $allowed -notcontains $cmd.GetCommandName()) { return $false }
    if ($cmd.GetCommandName() -eq 'Set-BgItem') {
        $last = @($cmd.CommandElements)[-1]
        if ($last -isnot [System.Management.Automation.Language.StringConstantExpressionAst] -or $last.Value -notin 'on', 'auto') { return $false }
    }
    foreach ($el in @($cmd.CommandElements | Select-Object -Skip 1)) {
        $bad = $el.FindAll({ param($n) -not ($n -is [System.Management.Automation.Language.CommandParameterAst] -or $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
                                               $n -is [System.Management.Automation.Language.ConstantExpressionAst] -or $n -is [System.Management.Automation.Language.ArrayExpressionAst] -or
                                               $n -is [System.Management.Automation.Language.ArrayLiteralAst] -or $n -is [System.Management.Automation.Language.StatementBlockAst] -or
                                               $n -is [System.Management.Automation.Language.PipelineAst] -or $n -is [System.Management.Automation.Language.CommandExpressionAst] -or
                                               ($n -is [System.Management.Automation.Language.VariableExpressionAst] -and $n.VariablePath.UserPath -in 'true', 'false')) }, $true)
        if (@($bad).Count) { return $false }
    }
    return $true
}
function Add-Change {
    param([string]$Title, [string]$Detail = '', [string]$Undo = '', [string]$Kind = 'reglage')
    if ($script:AeroxUndo) { return }
    try {
        $o = [ordered]@{ id = [guid]::NewGuid().ToString('N').Substring(0, 12); date = (Get-Date).ToString('s'); title = $Title; detail = $Detail; undo = $Undo; kind = $Kind; version = $AppInfo.Version }
        $f = Join-Path $AppInfo.LogDir 'changements.jsonl'
        [IO.File]::AppendAllText($f, (($o | ConvertTo-Json -Compress) + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
        # Sceau de l'annulation dans le dossier protégé : l'historique (dossier perso) ne peut pas faire exécuter autre chose
        if ($Undo) { [IO.File]::AppendAllText((Join-Path (Get-SecureDir '') 'annulations.txt'), ((Get-UndoSeal $o.id $Undo) + "`r`n"), [Text.Encoding]::ASCII) }
    } catch {}
}
function Get-UndoSeal([string]$Id, [string]$Undo) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return (($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes("$Id|$Undo")) | ForEach-Object { $_.ToString('x2') }) -join '') } finally { $sha.Dispose() }
}
# Annulation autorisée ? Action connue et sans danger, ET notée par AEROX lui-même (sceau dans le dossier protégé).
# Sans sceau : refusée, quelle que soit l'action.
function Test-UndoAuthorized([string]$Id, [string]$Undo) {
    if (-not (Test-SafeUndo $Undo)) { return $false }
    $f = Join-Path $AppInfo.Secure 'annulations.txt'
    return ((Test-Path -LiteralPath $f) -and (@(Get-Content -LiteralPath $f -ErrorAction SilentlyContinue) -contains (Get-UndoSeal $Id $Undo)))
}
function Get-Changes([int]$Max = 300) {
    $f = Join-Path $AppInfo.LogDir 'changements.jsonl'
    $u = Join-Path $AppInfo.LogDir 'changements_annules.txt'
    $undone = @(); if (Test-Path -LiteralPath $u) { $undone = @(Get-Content -LiteralPath $u -ErrorAction SilentlyContinue | Where-Object { $_ }) }
    $list = New-Object System.Collections.ArrayList
    if (Test-Path -LiteralPath $f) {
        foreach ($l in @(Get-Content -LiteralPath $f -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -Last $Max)) {
            try { $o = $l | ConvertFrom-Json; [void]$list.Add(@{ Id = $o.id; Date = [datetime]$o.date; Title = $o.title; Detail = $o.detail; Undo = $o.undo; Kind = $o.kind; Undone = ($undone -contains $o.id) }) } catch {}
        }
    }
    $list.Reverse()
    return $list.ToArray()
}
function Set-ChangeUndone([string]$Id) {
    try { [IO.File]::AppendAllText((Join-Path $AppInfo.LogDir 'changements_annules.txt'), "$Id`r`n") } catch {}
}
function Set-PowerScheme([string]$Guid, [string]$Name) {
    Step ("Retour au mode d'alimentation « {0} »" -f $Name)
    $null = Invoke-Native 'powercfg.exe' @('/setactive', $Guid)
    if ((Get-PowerStatus).Guid -eq $Guid.ToLower()) { Log "   ✔ Mode « $Name » rétabli." }
    else { Add-TaskError -Title "Impossible de rétablir le mode « $Name »" -Cause "Ce mode d'alimentation n'existe plus sur ce PC." -FixLabel "Ouvrir les options d'alimentation" -FixAction "Open-SystemTool 'powercfg.cpl'" }
}
function Enable-Hibernation {
    Step "Réactivation de la veille prolongée"
    $null = Invoke-Native 'powercfg.exe' @('/hibernate', 'on')
    Log "   ✔ Veille prolongée réactivée."
}

# ---------------------------------------------------------------- Démarrage (registre + dossiers)
$script:StartupDisablePattern = '(?i)discord|steam|epicgames|epic games|spotify|battle\.net|eadesktop|ea app|origin|ubisoft|uplay|skype|teams|gog galaxy|galaxyclient|opera.*(assistant|browser)|opera gx|ccleaner|utorrent|bittorrent|overwolf|medal|riotclient|riot client'
$script:StartupKeepPattern    = '(?i)security|defender|antivirus|avast|avg|kaspersky|bitdefender|norton|malwarebytes|eset|mcafee|realtek|rtkaud|rtkngui|nvidia|amd|radeon|intel|synaptics|elan|logitech|razer|corsair|steelseries|onedrive|vanguard|audio|sound'

function Test-StartupEnabled([string]$Approved, [string]$ValueName) {
    try {
        $v = (Get-ItemProperty -LiteralPath $Approved -Name $ValueName -ErrorAction Stop).$ValueName
        if ($v -is [byte[]] -and $v.Length -gt 0) { return (($v[0] -band 1) -eq 0) }
    } catch {}
    return $true
}
function Get-StartupEntries {
    $hk = (Get-SessionUser).Hkcu   # programmes au démarrage de la personne devant l'écran
    $list = New-Object System.Collections.ArrayList
    $ab = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
    $sources = @(
        @{ Path = "$hk\Software\Microsoft\Windows\CurrentVersion\Run";               Approved = "$hk\$ab\Run" },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run';             Approved = "HKLM:\$ab\Run" },
        @{ Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Approved = "HKLM:\$ab\Run32" }
    )
    foreach ($s in $sources) {
        $key = Get-Item -LiteralPath $s.Path -ErrorAction SilentlyContinue
        if (-not $key) { continue }
        foreach ($n in $key.GetValueNames()) {
            if (-not $n) { continue }
            [void]$list.Add(@{ Id = "$($s.Approved)|$n"; Key = (Get-StartupIdKey "$($s.Approved)|$n"); Name = $n; Command = [string]$key.GetValue($n); Approved = $s.Approved; ValueName = $n; Enabled = (Test-StartupEnabled $s.Approved $n) })
        }
    }
    foreach ($f in @(@{ Dir = (Get-SessionFolder 'Startup'); Approved = "$hk\$ab\StartupFolder" },
                     @{ Dir = [Environment]::GetFolderPath('CommonStartup'); Approved = "HKLM:\$ab\StartupFolder" })) {
        if (-not $f.Dir -or -not (Test-Path -LiteralPath $f.Dir)) { continue }
        foreach ($file in @(Get-ChildItem -LiteralPath $f.Dir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' })) {
            [void]$list.Add(@{ Id = "$($f.Approved)|$($file.Name)"; Key = (Get-StartupIdKey "$($f.Approved)|$($file.Name)"); Name = $file.BaseName; Command = $file.FullName; Approved = $f.Approved; ValueName = $file.Name; Enabled = (Test-StartupEnabled $f.Approved $file.Name) })
        }
    }
    return $list
}
# Identifiant stable d'un programme au démarrage : « u|run|discord » (session) ou « m|run32|steam » (tout le PC).
# Ne dépend pas de l'écriture de la clé de la session (HKCU: ou HKEY_USERS\<SID>), pour que la fenêtre et la tâche
# de fond désignent toujours le même élément (accepte aussi les anciens identifiants de l'historique).
function Get-StartupIdKey([string]$Id) {
    $p = $Id.IndexOf('|'); if ($p -lt 1) { return $Id.ToLowerInvariant() }
    $ap = $Id.Substring(0, $p); $vn = $Id.Substring($p + 1)
    $scope = if ($ap -match '^(?i)(HKLM:|Registry::HKEY_LOCAL_MACHINE)') { 'm' } else { 'u' }
    return ("{0}|{1}|{2}" -f $scope, ($ap.TrimEnd('\') -split '\\')[-1], $vn).ToLowerInvariant()
}
function Get-StartupKind($Entry) {
    $t = "$($Entry.Name) $($Entry.Command)"
    if ($t -match $script:StartupKeepPattern) { return 'keep' }
    if ($t -match $script:StartupDisablePattern) { return 'optional' }
    return 'other'
}
function Set-StartupApps([string[]]$Disable = @(), [string[]]$Enable = @()) {
    Step "Modification des programmes au démarrage"
    $entries = @(Get-StartupEntries)
    $dk = @($Disable | Where-Object { $_ } | ForEach-Object { Get-StartupIdKey $_ })
    $ek = @($Enable | Where-Object { $_ } | ForEach-Object { Get-StartupIdKey $_ })
    $found = @{}
    foreach ($e in $entries) {
        $want = $null
        if ($dk -contains $e.Key) { $want = 3 } elseif ($ek -contains $e.Key) { $want = 2 }
        if ($null -eq $want) { continue }
        $found[$e.Key] = $true
        try {
            if (-not (Test-Path -LiteralPath $e.Approved)) { New-Item -Path $e.Approved -Force | Out-Null }
            New-ItemProperty -LiteralPath $e.Approved -Name $e.ValueName -PropertyType Binary -Value ([byte[]]($want,0,0,0,0,0,0,0,0,0,0,0)) -Force -ErrorAction Stop | Out-Null
            # Relu aussitôt : on n'annonce « fait » que si Windows a bien gardé le réglage
            if ((Test-StartupEnabled $e.Approved $e.ValueName) -ne ($want -eq 2)) {
                $raw = ''; try { $raw = (@((Get-ItemProperty -LiteralPath $e.Approved -Name $e.ValueName -ErrorAction Stop).($e.ValueName)) | ForEach-Object { '{0:X2}' -f $_ }) -join ' ' } catch { $raw = $_.Exception.Message }
                throw ("le réglage n'a pas été gardé par Windows (relu : {0} ; clé {1}, valeur « {2} »)" -f $raw, $e.Approved, $e.ValueName)
            }
            Log ("   ✔ {0} : {1}" -f $e.Name, $(if ($want -eq 3) { 'ne se lance plus au démarrage' } else { 'se lance de nouveau au démarrage' }))
            # Retenu : si l'appli se remet toute seule au démarrage, le diagnostic le dira au lieu de la recompter en silence
            $AppInfo.StartupOff = @(@($AppInfo.StartupOff | Where-Object { $_ -and $_ -ne $e.Key }) + $(if ($want -eq 3) { @($e.Key) } else { @() }))
            if ($want -eq 3) { Add-Change -Title ("« {0} » ne se lance plus au démarrage" -f $e.Name) -Detail "L'appli reste installée." -Undo ("Set-StartupApps -Enable @({0})" -f (ConvertTo-PsLiteral $e.Id)) }
            else { Add-Change -Title ("« {0} » se lance de nouveau au démarrage" -f $e.Name) -Undo ("Set-StartupApps -Disable @({0})" -f (ConvertTo-PsLiteral $e.Id)) }
        } catch {
            Add-TaskError -Title "Impossible de modifier « $($e.Name) » au démarrage" -Cause $_.Exception.Message `
                -FixLabel "Ouvrir le Gestionnaire des tâches" -FixAction "Start-Process taskmgr.exe -ArgumentList '/0 /startup'" -Bug $_
        }
    }
    # Demandé mais plus dans la liste (l'appli s'est retirée elle-même entre-temps, ou a été désinstallée)
    foreach ($k in @($dk + $ek | Where-Object { -not $found.ContainsKey($_) } | Select-Object -Unique)) {
        Log ("   • « {0} » n'est plus dans les programmes au démarrage : rien à changer." -f ($k -split '\|', 3)[-1])
    }
    Log "   (Les applis restent installées : tu les ouvres quand tu veux. Si l'une se réactive toute seule, décoche l'option « lancer au démarrage » dans ses propres réglages.)"
}

# ---------------------------------------------------------------- Mon PC : carte mère, BIOS, TPM, Secure Boot
$script:BrandSites = @(
    @{ Re = 'asus';              Name = 'ASUS';     Site = 'asus.com';        Tool = "Mise à jour depuis le BIOS avec « EZ Flash » (cartes mères) ou l'appli MyASUS (portables)." },
    @{ Re = 'micro-star|\bmsi\b'; Name = 'MSI';     Site = 'msi.com';         Tool = "Mise à jour depuis le BIOS avec « M-Flash » (clé USB)." },
    @{ Re = 'gigabyte|aorus';    Name = 'Gigabyte'; Site = 'gigabyte.com';    Tool = "Mise à jour depuis le BIOS avec « Q-Flash » (clé USB)." },
    @{ Re = 'asrock';            Name = 'ASRock';   Site = 'asrock.com';      Tool = "Mise à jour depuis le BIOS avec « Instant Flash » (clé USB)." },
    @{ Re = 'dell|alienware';    Name = 'Dell';     Site = 'dell.com';        Tool = "L'appli Dell SupportAssist (ou Dell Command Update) trouve et installe le BIOS toute seule." },
    @{ Re = '\bhp\b|hewlett';    Name = 'HP';       Site = 'hp.com';          Tool = "L'appli HP Support Assistant trouve et installe le BIOS toute seule." },
    @{ Re = 'lenovo';            Name = 'Lenovo';   Site = 'lenovo.com';      Tool = "L'appli Lenovo Vantage trouve et installe le BIOS toute seule." },
    @{ Re = 'acer|predator';     Name = 'Acer';     Site = 'acer.com';        Tool = "Télécharge le BIOS sur la page support Acer de ton modèle." },
    @{ Re = 'microsoft';         Name = 'Microsoft'; Site = 'microsoft.com';  Tool = "Le BIOS des Surface se met à jour avec Windows Update." },
    @{ Re = 'samsung';           Name = 'Samsung';  Site = 'samsung.com';     Tool = "L'appli Samsung Update gère le BIOS." },
    @{ Re = 'medion';            Name = 'Medion';   Site = 'medion.com';      Tool = "Télécharge le BIOS sur la page support Medion de ton modèle." },
    @{ Re = 'huawei';            Name = 'Huawei';   Site = 'consumer.huawei.com'; Tool = "L'appli PC Manager de Huawei gère le BIOS." },
    @{ Re = 'toshiba|dynabook';  Name = 'Dynabook'; Site = 'dynabook.com';    Tool = "Télécharge le BIOS sur la page support de ton modèle." },
    @{ Re = 'razer';             Name = 'Razer';    Site = 'razer.com';       Tool = "Télécharge le BIOS sur la page support Razer de ton modèle." },
    @{ Re = 'biostar';           Name = 'Biostar';  Site = 'biostar.com.tw';  Tool = "Mise à jour depuis le BIOS (clé USB)." }
)

# Page de téléchargement du BIOS de CE PC sur le site du fabricant. Chaque adresse devinée est vérifiée (la page
# existe et parle bien de ce modèle) avant d'être ouverte ; sinon la recherche du site du fabricant, sinon un moteur.
function Test-WebPageHas([string]$Url, [string[]]$Tokens) {
    try {
        $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10 -MaximumRedirection 5 -UserAgent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36' -ErrorAction Stop
        if ([int]$r.StatusCode -ne 200) { return $false }
        $c = "$($r.Content)"
        if ($c -match '(?is)<title[^>]*>(.*?)</title>' -and $matches[1] -match '(?i)\b404\b|not found|introuvable|n.existe pas|page error') { return $false }
        if (-not $Tokens.Count) { return $true }
        $flat = ($c -replace '%20', ' ' -replace '[\s\-_]+', '').ToLowerInvariant()
        foreach ($t in $Tokens) { if ($t -and $flat.Contains(($t -replace '[\s\-_]+', '').ToLowerInvariant())) { return $true } }
        return $false
    } catch { return $false }
}
function Find-BiosPage {
    Step "Recherche de la page du BIOS de ton PC sur le site du fabricant"
    $sync.BiosUrl = $null
    # Get-SystemInfo ne renvoie rien : il remplit $sync.SysInfo
    if (-not $sync.SysInfo) { Get-SystemInfo | Out-Null }; $i = $sync.SysInfo; if (-not $i) { $i = @{} }
    $m = ("$($i.Model)" -replace '\s*\(MS-[0-9A-Z]+\)\s*', ' ').Trim()
    $enc = [uri]::EscapeDataString($m)
    $dash = (($m -replace '[()]', '' -replace '\s+', '-').Trim('-'))
    $mk = "$($i.Maker)"
    $cands = New-Object System.Collections.ArrayList
    $add = { param($u, $tok, $kind, [bool]$trust = $false) [void]$cands.Add(@{ Url = $u; Tok = @($tok); Kind = $kind; Trust = $trust }) }
    if ($mk -match '(?i)dell|alienware' -and $i.Serial) { & $add ("https://www.dell.com/support/home/fr-fr/product-support/servicetag/{0}/drivers" -f [uri]::EscapeDataString($i.Serial)) @() 'exact' $true }
    elseif ($mk -match '(?i)asus') {
        & $add ("https://www.asus.com/supportonly/{0}/helpdesk_bios/" -f $enc) @($m) 'exact'
        & $add ("https://www.asus.com/fr/searchresult?searchType=support&searchKey={0}" -f $enc) @() 'search'
    } elseif ($mk -match '(?i)micro-star|\bmsi\b') {
        & $add ("https://www.msi.com/Motherboard/{0}/support#bios" -f $dash) @($m) 'exact'
        & $add ("https://www.msi.com/Laptop/{0}/support#bios" -f $dash) @($m) 'exact'
        & $add ("https://www.msi.com/search/{0}" -f $enc) @() 'search'
    } elseif ($mk -match '(?i)gigabyte|aorus') {
        foreach ($sfx in '', '-rev-10', '-rev-1x', '-rev-11', '-rev-12') { & $add ("https://www.gigabyte.com/fr/Motherboard/{0}{1}/support#support-dl-bios" -f $dash, $sfx) @($m) 'exact' }
        & $add ("https://www.gigabyte.com/fr/Search?kw={0}" -f $enc) @() 'search'
    } elseif ($mk -match '(?i)asrock') {
        & $add ("https://www.asrock.com/mb/{0}/{1}/index.fr.asp#BIOS" -f $(if ($i.CpuAmd) { 'AMD' } else { 'Intel' }), $enc) @($m) 'exact'
    } elseif ($mk -match '(?i)lenovo' -and $i.Serial) {
        & $add ("https://pcsupport.lenovo.com/fr/fr/products/{0}/downloads" -f [uri]::EscapeDataString($i.Serial)) @($i.Serial) 'exact'
    }
    foreach ($c in $cands) {
        if ($c.Trust -or (Test-WebPageHas $c.Url $c.Tok)) {
            $sync.BiosUrl = @{ Url = $c.Url; Kind = $c.Kind }
            Log $(if ($c.Kind -eq 'exact') { "   ✔ Page du BIOS de ton modèle trouvée sur le site du fabricant." } else { "   ✔ Recherche de ton modèle sur le site du fabricant (la page exacte n'a pas pu être vérifiée)." })
            return
        }
    }
    $q = ("$($i.Model) BIOS").Trim()
    if (-not "$($i.Model)".Trim() -and -not "$($i.Maker)".Trim()) {
        # Windows ne connaît ni la marque ni le modèle (PC assemblé sans infos) : on ne lance pas une recherche vide
        $sync.BiosUrl = $null
        Log "   ⚠ Windows ne connaît pas la marque ni le modèle de ta carte mère : regarde-les écrits dessus (ou dans le BIOS), puis cherche « modèle + BIOS » sur le site du fabricant."
        return
    }
    if ($i.BrandSite) { $q = "site:$($i.BrandSite) $q" } else { $q = ("$($i.Maker) $q support").Trim() }
    $sync.BiosUrl = @{ Url = ("https://www.bing.com/search?q=" + [uri]::EscapeDataString($q)); Kind = 'web' }
    Log "   • Le site du fabricant n'a pas donné de page vérifiable pour ce modèle : recherche limitée à son site officiel."
}

# =====================================================================
#  Mise à jour du BIOS (cartes mères MSI, ASUS, Gigabyte, ASRock) : AEROX vérifie le fichier téléchargé,
#  prépare la clé USB et explique l'installation. Le flash lui-même est TOUJOURS fait par l'outil officiel
#  du BIOS (M-Flash, EZ Flash, Q-Flash, Instant Flash) : AEROX n'écrit jamais dans la puce du BIOS.
# =====================================================================
function ConvertTo-BoardKey([string]$Text) { return (("$Text".ToUpperInvariant()) -replace '[^A-Z0-9]', '') }
# Identité de la carte mère pour vérifier un fichier BIOS : marque, modèle, numéro MSI (MS-7D75), version installée
function Get-BoardIdentity($I) {
    $vendor = switch -Regex ("$($I.BoardMaker) $($I.Brand)") { '(?i)micro-star|\bmsi\b' { 'MSI' } '(?i)asus' { 'ASUS' } '(?i)gigabyte|aorus' { 'Gigabyte' } '(?i)asrock' { 'ASRock' } default { '' } }
    $model = "$($I.BoardModel)".Trim()
    $msi = if ($model -match '(?i)\(MS-([0-9A-F]{4})\)') { $Matches[1].ToUpperInvariant() } else { '' }
    $clean = ($model -replace '(?i)\s*\(MS-[0-9A-F]{4}\)', '').Trim()
    return @{ Vendor = $vendor; Model = $clean; Key = (ConvertTo-BoardKey $clean); MsiId = $msi; Bios = "$($I.BiosVersion)".Trim(); Custom = [bool]$I.Custom; Laptop = [bool]$I.IsLaptop }
}
# Le fichier est-il un BIOS de cette marque, et pour quelle carte ? (lu dans son nom : format officiel de chaque marque)
#   MSI : E7D75AMS.1H0   ·   ASUS : ROG-STRIX-B650E-F-GAMING-WIFI-ASUS-3024.CAP   ·   Gigabyte : B650AORUSELITEAX.F20   ·   ASRock : B650M Pro RS(2.02)ROM
function Get-BiosFileInfo([string]$Name) {
    $n = [IO.Path]::GetFileName($Name)
    if ($n -cmatch '^E([0-9A-F]{4})[AI]MS\.([0-9A-Z]{3})\z') { return @{ Vendor = 'MSI'; Id = $Matches[1]; Version = $Matches[2]; Key = '' } }
    if ($n -match '(?i)^(.+)-ASUS-(\d{3,5})\.CAP\z') { return @{ Vendor = 'ASUS'; Id = ''; Version = $Matches[2]; Key = (ConvertTo-BoardKey $Matches[1]) } }
    if ($n -match '(?i)^(.+)\((\d+\.\d+[A-Z]?)\)\.?ROM\z') { return @{ Vendor = 'ASRock'; Id = ''; Version = $Matches[2]; Key = (ConvertTo-BoardKey $Matches[1]) } }
    if ($n -match '(?i)^([A-Z0-9-]+)\.(F\d{1,3}[A-Z]?)\z') { return @{ Vendor = 'Gigabyte'; Id = ''; Version = $Matches[2].ToUpperInvariant(); Key = (ConvertTo-BoardKey $Matches[1]) } }
    if ($n -match '(?i)\.CAP\z') { return @{ Vendor = 'ASUS'; Id = ''; Version = ''; Key = '' } }
    return $null
}
# Comparaison des versions : seulement quand le format de la marque le permet sans doute possible (sinon $null = « différente »)
function Compare-BiosVersion([string]$Vendor, [string]$Installed, [string]$File) {
    $a = "$Installed".Trim(); $b = "$File".Trim()
    if (-not $a -or -not $b) { return $null }
    switch ($Vendor) {
        'MSI' { if (($a -replace '\.', '') -eq $b) { return 0 }; return $null }
        'ASUS' { if ($a -match '^\d+\z' -and $b -match '^\d+\z') { return [math]::Sign([int]$b - [int]$a) }; return $null }
        'ASRock' { $x = 0.0; $y = 0.0; if ($a -match '^(\d+\.\d+)' -and [double]::TryParse($Matches[1], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$x) -and $b -match '^(\d+\.\d+)' -and [double]::TryParse($Matches[1], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$y)) { if ($x -eq $y) { return $(if ($a -eq $b) { 0 } else { $null }) }; return [math]::Sign($y - $x) }; return $null }
        'Gigabyte' {
            if ($a -match '(?i)^F(\d+)([A-Z]?)\z') { $na = [int]$Matches[1]; $sa = $Matches[2].ToUpperInvariant() } else { return $null }
            if ($b -match '(?i)^F(\d+)([A-Z]?)\z') { $nb = [int]$Matches[1]; $sb = $Matches[2].ToUpperInvariant() } else { return $null }
            if ($na -ne $nb) { return [math]::Sign($nb - $na) }
            return [math]::Sign([string]::CompareOrdinal($sb, $sa))
        }
    }
    return $null
}
# Analyse du fichier choisi (zip téléchargé ou fichier BIOS) : extrait le zip, trouve le fichier BIOS, vérifie modèle et version
# Verdict : ok (bonne carte) · bad (autre carte : on refuse) · unknown (impossible à vérifier : confirmation obligatoire)
function Get-BiosFileReport([string]$Path, $Board) {
    $r = @{ Path = $Path; File = ''; Name = ''; Size = 0; Verdict = 'unknown'; Lines = @(); Version = ''; Cmp = $null; Vendor = '' }
    $lines = New-Object System.Collections.ArrayList
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { $r.Verdict = 'bad'; [void]$lines.Add(@('bad', "Fichier introuvable.")); $r.Lines = $lines.ToArray(); return $r }
    $cands = @()
    if ($Path -match '(?i)\.zip\z') {
        $dir = Join-Path (Get-SecureDir 'bios') ([IO.Path]::GetFileNameWithoutExtension($Path) -replace '[^\w.-]', '_')
        if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [IO.Compression.ZipFile]::OpenRead($Path)
        try {
            foreach ($e in $zip.Entries) {
                if (-not $e.Name -or $e.Length -lt 4MB -or $e.Length -gt 128MB) { continue }   # un BIOS fait entre 4 et 128 Mo
                if (-not (Get-BiosFileInfo $e.Name) -and $e.Name -notmatch '(?i)\.(rom|bin|cap)\z') { continue }
                $out = Join-Path $dir $e.Name
                if (Test-Path -LiteralPath $out) { continue }
                [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $out)
                $cands += Get-Item -LiteralPath $out
            }
        } finally { $zip.Dispose() }
        if (-not $cands.Count) { $r.Verdict = 'bad'; [void]$lines.Add(@('bad', "Aucun fichier BIOS dans ce zip : vérifie que tu as bien téléchargé le BIOS (et pas un pilote ou un logiciel).")); $r.Lines = $lines.ToArray(); return $r }
    } else { $cands = @(Get-Item -LiteralPath $Path) }
    $known = @($cands | Where-Object { Get-BiosFileInfo $_.Name })
    $f = $(if ($known.Count) { $known[0] } else { $cands | Sort-Object Length -Descending | Select-Object -First 1 })
    if (@($known).Count -gt 1) { [void]$lines.Add(@('warn', "Plusieurs fichiers BIOS dans le zip : AEROX a pris « $($f.Name) ».")) }
    $r.File = $f.FullName; $r.Name = $f.Name; $r.Size = [double]$f.Length
    if ($f.Length -lt 4MB -or $f.Length -gt 128MB) { $r.Verdict = 'bad'; [void]$lines.Add(@('bad', ("Taille inhabituelle pour un BIOS ({0}) : ce n'est sûrement pas le bon fichier." -f (Format-Size $f.Length)))); $r.Lines = $lines.ToArray(); return $r }
    $fi = Get-BiosFileInfo $f.Name
    $ok = $false; $bad = $false
    if (-not $fi) { [void]$lines.Add(@('warn', "Nom de fichier non reconnu : AEROX ne peut pas vérifier pour quelle carte mère il est fait.")) }
    else {
        $r.Vendor = $fi.Vendor; $r.Version = $fi.Version
        if ($Board.Vendor -and $fi.Vendor -ne $Board.Vendor) { $bad = $true; [void]$lines.Add(@('bad', "C'est un BIOS $($fi.Vendor), et ta carte mère est une $($Board.Vendor).")) }
        elseif ($fi.Vendor -eq 'MSI') {
            if ($Board.MsiId -and $fi.Id -eq $Board.MsiId) { $ok = $true; [void]$lines.Add(@('ok', "Fait pour ta carte mère (MS-$($fi.Id)).")) }
            elseif ($Board.MsiId) { $bad = $true; [void]$lines.Add(@('bad', "Fait pour une autre carte mère (MS-$($fi.Id)) : la tienne est la MS-$($Board.MsiId).")) }
            else { [void]$lines.Add(@('warn', "Fichier pour la carte MS-$($fi.Id) : Windows ne donne pas le numéro de ta carte mère, vérifie-le sur sa boîte ou sous la carte graphique.")) }
        } elseif ($fi.Key -and $Board.Key) {
            if ($fi.Key -eq $Board.Key) { $ok = $true; [void]$lines.Add(@('ok', "Fait pour ta carte mère ($($Board.Model)).")) }
            else { [void]$lines.Add(@('warn', "Le nom du fichier ne correspond pas exactement à ta carte mère ($($Board.Model)). Vérifie sur le site que c'est bien la même (attention aux versions « WIFI », « PLUS », « -A »…).")) }
        } else { [void]$lines.Add(@('warn', "Impossible de vérifier le modèle à partir du nom de ce fichier.")) }
        if ($fi.Version) {
            $c = Compare-BiosVersion $fi.Vendor $Board.Bios $fi.Version; $r.Cmp = $c
            $vt = "Version du fichier : $($fi.Version) · installée : $($Board.Bios)"
            if ($c -eq 1) { [void]$lines.Add(@('ok', "$vt → plus récente.")) }
            elseif ($c -eq 0) { [void]$lines.Add(@('warn', "$vt → c'est déjà la version installée : pas besoin de la mettre.")) }
            elseif ($c -eq -1) { [void]$lines.Add(@('warn', "$vt → plus ANCIENNE que celle installée. Ne la mets que si tu sais pourquoi.")) }
            else { [void]$lines.Add(@('info', "$vt.")) }
        }
    }
    $r.Verdict = $(if ($bad) { 'bad' } elseif ($ok) { 'ok' } else { 'unknown' })
    $r.Lines = $lines.ToArray()
    return $r
}
# Nom à donner au fichier pour le bouton de secours « Flashback » (BIOS mis à jour sans démarrer le PC)
function Get-FlashbackName([string]$Vendor) { switch ($Vendor) { 'MSI' { 'MSI.ROM' } 'Gigabyte' { 'GIGABYTE.bin' } 'ASRock' { 'creative.rom' } default { '' } } }
# Clés USB branchées (jamais un disque interne, jamais le disque de Windows)
function Get-UsbKeys {
    $keys = New-Object System.Collections.ArrayList
    foreach ($d in @(Get-Disk -ErrorAction SilentlyContinue | Where-Object { "$($_.BusType)" -eq 'USB' -and -not $_.IsBoot -and -not $_.IsSystem })) {
        $vols = @(Get-Partition -DiskNumber $d.Number -ErrorAction SilentlyContinue | Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_ })
        $letters = @($vols | Where-Object { $_.DriveLetter } | ForEach-Object { "$($_.DriveLetter):" })
        $fs = @($vols | ForEach-Object { "$($_.FileSystem)" } | Where-Object { $_ } | Select-Object -Unique)
        [void]$keys.Add(@{ Number = [int]$d.Number; Name = ("$($d.FriendlyName)".Trim()); Size = [double]$d.Size; Letters = $letters; Fs = ($fs -join ', '); Fat32 = ($vols.Count -eq 1 -and "$($vols[0].FileSystem)" -eq 'FAT32' -and $vols[0].DriveLetter) })
    }
    return $keys.ToArray()
}
# Prépare la clé : (formatage FAT32 si demandé) + copie du fichier BIOS + copie au nom « Flashback » + vérification par empreinte
function Initialize-BiosUsb([int]$DiskNumber, [string]$Source, [string]$Vendor, [bool]$Format) {
    $d = Get-Disk -Number $DiskNumber -ErrorAction Stop
    # Garde-fous : uniquement une clé USB, jamais le disque de Windows ni un disque de plus de 256 Go (disque externe)
    if ("$($d.BusType)" -ne 'USB') { throw "Ce disque n'est pas une clé USB : rien n'a été touché." }
    if ($d.IsBoot -or $d.IsSystem) { throw "C'est le disque de Windows : rien n'a été touché." }
    if ([double]$d.Size -gt 256GB) { throw "Ce disque USB fait plus de 256 Go : par sécurité AEROX ne prépare que des clés USB. Rien n'a été touché." }
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { throw "Fichier BIOS introuvable." }
    if ($Format) {
        Step "Formatage de la clé USB en FAT32"
        Clear-Disk -Number $DiskNumber -RemoveData -RemoveOEM -Confirm:$false -ErrorAction Stop
        $d = Get-Disk -Number $DiskNumber
        if ("$($d.PartitionStyle)" -eq 'RAW') { Initialize-Disk -Number $DiskNumber -PartitionStyle MBR -ErrorAction Stop }
        # FAT32 : 32 Go au plus avec Windows (les outils du BIOS lisent le FAT32)
        $size = [math]::Min([double]32GB, [double]$d.Size - 2MB)
        $p = New-Partition -DiskNumber $DiskNumber -Size ([uint64]$size) -AssignDriveLetter -IsActive -ErrorAction Stop
        $null = Format-Volume -Partition $p -FileSystem FAT32 -NewFileSystemLabel 'BIOS' -Force -Confirm:$false -ErrorAction Stop
    }
    $vol = @(Get-Partition -DiskNumber $DiskNumber | Get-Volume | Where-Object { $_.DriveLetter -and "$($_.FileSystem)" -eq 'FAT32' }) | Select-Object -First 1
    if (-not $vol) { throw "La clé n'est pas en FAT32 : coche « Effacer et formater la clé »." }
    $root = "$($vol.DriveLetter):\"
    $name = [IO.Path]::GetFileName($Source)
    $copies = @($name); $fb = Get-FlashbackName $Vendor; if ($fb -and $fb -ne $name) { $copies += $fb }
    $sha = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
    foreach ($c in $copies) {
        $dst = Join-Path $root $c
        Copy-Item -LiteralPath $Source -Destination $dst -Force -ErrorAction Stop
        if ((Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash -ne $sha) { throw "La copie de $c sur la clé est abîmée : essaie une autre clé USB." }
        Log "   ✔ $c copié sur la clé ($root) et vérifié"
    }
    return @{ Drive = $root; Files = $copies }
}
function Get-BitLockerOn {
    try { return ("$((Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop).ProtectionStatus)" -eq 'On') } catch { return $false }
}
# BitLocker en pause pour 3 redémarrages (le temps du flash) : sinon Windows demande la clé de récupération après la mise à jour du BIOS
function Suspend-BitLockerForBios {
    Step "BitLocker mis en pause pour la mise à jour du BIOS"
    Suspend-BitLocker -MountPoint $env:SystemDrive -RebootCount 3 -ErrorAction Stop | Out-Null
    Add-Change -Title "BitLocker en pause pour la mise à jour du BIOS" -Detail "Il se réactive tout seul après 3 redémarrages." -Undo 'Resume-BitLockerOs'
    Log "   ✔ BitLocker se réactivera tout seul après 3 redémarrages."
}
function Resume-BitLockerOs { Resume-BitLocker -MountPoint $env:SystemDrive -ErrorAction Stop | Out-Null; Log "   ✔ BitLocker réactivé." }
# Étapes d'installation depuis le BIOS, selon la marque
function Get-BiosFlashSteps([string]$Vendor, [string]$File) {
    $fb = Get-FlashbackName $Vendor
    switch ($Vendor) {
        'MSI' { return @(@("Laisse la clé branchée (de préférence sur un port USB à l'arrière du PC).", "Clique sur « Redémarrer dans le BIOS » ci-dessous.", "Dans le BIOS, clique sur « M-FLASH » (sur l'écran d'accueil ; sinon touche F7 pour le mode avancé, puis M-FLASH) et accepte : le PC redémarre dans l'outil de mise à jour.", "Choisis la clé USB, puis le fichier $File, et confirme.", "Attends sans rien toucher (2 à 5 minutes) : le PC redémarre tout seul, parfois plusieurs fois, l'écran peut rester noir un moment."), "Secours (si le PC ne démarre plus) : PC éteint mais branché, mets la clé sur le port marqué « Flash BIOS » à l'arrière et appuie sur le bouton « Flash BIOS » : la lumière clignote pendant la mise à jour (fichier $fb déjà prêt sur la clé).") }
        'ASUS' { return @(@("Laisse la clé branchée (de préférence sur un port USB à l'arrière du PC).", "Clique sur « Redémarrer dans le BIOS » ci-dessous.", "Dans le BIOS, appuie sur F7 (mode avancé), onglet « Tool », puis « ASUS EZ Flash 3 Utility ».", "Choisis la clé USB, puis le fichier $File, et réponds « Oui ».", "Attends sans rien toucher (2 à 5 minutes) : le PC redémarre tout seul, parfois plusieurs fois."), "Secours « BIOS FlashBack » : il demande un nom de fichier propre à chaque carte, donné par l'outil « BIOSRenamer » inclus dans le zip ASUS. Avec EZ Flash, ce n'est pas nécessaire.") }
        'Gigabyte' { return @(@("Laisse la clé branchée (de préférence sur un port USB à l'arrière du PC).", "Clique sur « Redémarrer dans le BIOS » ci-dessous.", "Dans le BIOS, appuie sur F8 (ou clique sur « Q-Flash ») puis « Update BIOS ».", "Choisis la clé USB, puis le fichier $File, et confirme.", "Attends sans rien toucher (2 à 5 minutes) : le PC redémarre tout seul, parfois plusieurs fois."), "Secours « Q-Flash Plus » (si le PC ne démarre plus) : PC éteint mais branché, clé sur le port marqué « Q-Flash Plus » à l'arrière, appuie sur le bouton : la lumière clignote pendant la mise à jour (fichier $fb déjà prêt sur la clé).") }
        'ASRock' { return @(@("Laisse la clé branchée (de préférence sur un port USB à l'arrière du PC).", "Clique sur « Redémarrer dans le BIOS » ci-dessous.", "Dans le BIOS, appuie sur F6 (mode avancé), onglet « Tool », puis « Instant Flash ».", "Choisis le fichier $File et confirme.", "Attends sans rien toucher (2 à 5 minutes) : le PC redémarre tout seul."), "Secours « BIOS Flashback » (si ta carte a ce bouton) : PC éteint mais branché, clé sur le port « Flashback », appuie sur le bouton (fichier $fb déjà prêt sur la clé).") }
    }
    return @(@("Laisse la clé branchée.", "Clique sur « Redémarrer dans le BIOS » ci-dessous.", "Cherche l'outil de mise à jour du BIOS (souvent dans « Tool » ou « Advanced ») et choisis le fichier $File sur la clé.", "Attends sans rien toucher jusqu'au redémarrage."), '')
}
function Get-SystemInfo {
    $i = @{ Ready = $true }
    try {
        $cs = Get-CimStatic Win32_ComputerSystem -Quiet; $bb = Get-CimStatic Win32_BaseBoard -Quiet; $bios = Get-CimStatic Win32_BIOS -Quiet
        $os = Get-CimInstance Win32_OperatingSystem; $csp = Get-CimInstance Win32_ComputerSystemProduct
        $i.PcMaker = "$($cs.Manufacturer)".Trim(); $i.PcModel = "$($cs.Model)".Trim()
        if ($i.PcMaker -match '(?i)lenovo' -and $csp.Version) { $i.PcModel = "$($csp.Version)".Trim() }
        $i.BoardMaker = "$($bb.Manufacturer)".Trim(); $i.BoardModel = "$($bb.Product)".Trim()
        $chassis = @((Get-CimStatic Win32_SystemEnclosure -Quiet).ChassisTypes)
        $i.IsLaptop = [bool](@($chassis | Where-Object { $_ -in 8, 9, 10, 11, 14, 30, 31, 32 }).Count)
        # PC assemblé : le nom du « PC » est vide ou générique → on se fie à la carte mère
        $generic = '(?i)^(system manufacturer|system product name|to be filled|default string|o\.e\.m|not applicable|)$'
        $i.Custom = ($i.PcMaker -match $generic -or $i.PcModel -match $generic -or ($i.PcMaker -match '(?i)asus|micro-star|gigabyte|asrock|biostar' -and -not $i.IsLaptop))
        $i.Maker = if ($i.Custom) { $i.BoardMaker } else { $i.PcMaker }
        $i.Model = if ($i.Custom) { $i.BoardModel } else { $i.PcModel }
        $i.BiosMaker = "$($bios.Manufacturer)".Trim(); $i.BiosVersion = "$($bios.SMBIOSBIOSVersion)".Trim()
        # Numéro de série (Dell : « service tag ») : seulement pour ouvrir la page exacte du fabricant, jamais dans les rapports
        $sn = "$($bios.SerialNumber)".Trim(); if ($sn -and $sn -notmatch '(?i)^(to be filled|default string|system serial|o\.e\.m|none|0+$)') { $i.Serial = $sn }
        if ($bios.ReleaseDate) { $i.BiosDate = ConvertTo-DateSafe $bios.ReleaseDate; $i.BiosAgeDays = [int]((Get-Date) - $i.BiosDate).TotalDays }
        $brand = $script:BrandSites | Where-Object { $i.Maker -match "(?i)$($_.Re)" } | Select-Object -First 1
        if ($brand) { $i.Brand = $brand.Name; $i.BrandSite = $brand.Site; $i.BrandTool = $brand.Tool }
        $i.Cpu = ("$((Get-CimStatic Win32_Processor -Quiet | Select-Object -First 1).Name)".Trim() -replace '\s+', ' ')
        $i.CpuAmd = ($i.Cpu -match '(?i)amd|ryzen')
        $i.Gpu = @(Get-CimStatic Win32_VideoController -Quiet | ForEach-Object { $_.Name } | Where-Object { $_ -notmatch '(?i)basic display|remote|virtual|parsec|meta' })
        $i.Ram = [double]$cs.TotalPhysicalMemory
        $mods = @(Get-CimStatic Win32_PhysicalMemory -Quiet)
        $i.RamModules = $mods.Count
        $spd = @($mods | ForEach-Object { if ($_.ConfiguredClockSpeed) { $_.ConfiguredClockSpeed } else { $_.Speed } } | Where-Object { $_ }) | Sort-Object | Select-Object -First 1
        $i.RamSpeed = $spd
        $i.OsName = ($os.Caption -replace '^Microsoft\s+', ''); $i.OsBuild = [int]$os.BuildNumber
        $i.OsVersion = try { (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop).DisplayVersion } catch { '' }
        $i.Win11 = ($i.OsBuild -ge 22000)
        try { $i.GpuDrivers = @(Get-GpuDrivers) } catch { $i.GpuDrivers = @() }
        try { $i.Batteries = @(Get-BatteryInfo) } catch { $i.Batteries = @() }
    } catch { $i.Error = $_.Exception.Message }
    # Mode de démarrage : 1 = ancien (Legacy / CSM), 2 = UEFI
    try { $fw = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name PEFirmwareType -ErrorAction Stop).PEFirmwareType; $i.Uefi = ($fw -eq 2) } catch { $i.Uefi = $null }
    # Secure Boot
    try { $i.SecureBoot = if (Confirm-SecureBootUEFI -ErrorAction Stop) { 'on' } else { 'off' } }
    catch { $i.SecureBoot = if ($i.Uefi -eq $false) { 'legacy' } else { 'unknown' } }
    # TPM
    try {
        $t = Get-Tpm -ErrorAction Stop
        $i.TpmPresent = [bool]$t.TpmPresent; $i.TpmReady = [bool]$t.TpmReady; $i.TpmEnabled = [bool]$t.TpmEnabled
    } catch { $i.TpmPresent = $null }
    try {
        $w = Get-CimInstance -Namespace 'root/cimv2/Security/MicrosoftTpm' -ClassName Win32_Tpm -ErrorAction Stop
        if ($w) { $i.TpmPresent = $true; $i.TpmVersion = ("$($w.SpecVersion)" -split ',')[0].Trim(); $i.TpmMaker = "$($w.ManufacturerIdTxt)".Trim() }
    } catch {}
    # Disque de Windows : GPT (moderne) ou MBR (ancien)
    try {
        $dn = (Get-Partition -DriveLetter $env:SystemDrive[0] -ErrorAction Stop).DiskNumber
        $d = Get-Disk -Number $dn -ErrorAction Stop
        $i.DiskStyle = "$($d.PartitionStyle)"; $i.DiskSize = [double]$d.Size
    } catch {}
    # Infos BIOS lues depuis Windows : mémoire (XMP / EXPO, dual channel), virtualisation, Resizable BAR, logiciels de ventilateurs
    try { $i.BiosInfo = Get-BiosInfo $i } catch { $i.BiosInfo = $null }
    $sync.SysInfo = $i
}

# ---------------------------------------------------------------- Batterie (PC portables)
# Capacité d'origine et capacité actuelle (usure), cycles de charge, fabricant : données de Windows (WMI root\wmi),
# complétées par le rapport officiel « powercfg /batteryreport » quand Windows ne donne pas tout par WMI.
function ConvertFrom-BatteryChem($Code) {
    $t = ''
    try { if ($Code -is [string]) { $t = $Code } elseif ($Code) { $t = [Text.Encoding]::ASCII.GetString([BitConverter]::GetBytes([uint32]$Code)) } } catch {}
    $t = ($t -replace '[^\w-]', '').Trim()
    switch -Regex ($t) {
        '(?i)^li.?ion|^lion|^li-i' { return 'Lithium-ion' }
        '(?i)^lip|poly' { return 'Lithium-polymère' }
        '(?i)nimh' { return 'Nickel-métal-hydrure' }
        '(?i)^pbac|lead' { return 'Plomb' }
        default { return $t }
    }
}
function Get-BatteryInfo {
    $w32 = @(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
    if (-not $w32.Count) { return }
    $static = @(Get-CimInstance -Namespace 'root/wmi' -ClassName BatteryStaticData -ErrorAction SilentlyContinue)
    $full   = @(Get-CimInstance -Namespace 'root/wmi' -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue)
    $cyc    = @(Get-CimInstance -Namespace 'root/wmi' -ClassName BatteryCycleCount -ErrorAction SilentlyContinue)
    $st     = @(Get-CimInstance -Namespace 'root/wmi' -ClassName BatteryStatus -ErrorAction SilentlyContinue)
    $list = New-Object System.Collections.ArrayList
    $n = [math]::Max($w32.Count, $static.Count)
    for ($k = 0; $k -lt $n; $k++) {
        $s = if ($k -lt $static.Count) { $static[$k] } else { $null }
        $inst = if ($s) { "$($s.InstanceName)" } else { '' }
        $f = $full | Where-Object { "$($_.InstanceName)" -eq $inst } | Select-Object -First 1
        $c = $cyc  | Where-Object { "$($_.InstanceName)" -eq $inst } | Select-Object -First 1
        $x = $st   | Where-Object { "$($_.InstanceName)" -eq $inst } | Select-Object -First 1
        $w = if ($k -lt $w32.Count) { $w32[$k] } else { $null }
        $b = @{ Name = ''; Maker = ''; Chem = ''; Design = 0.0; Full = 0.0; Health = $null; Cycles = $null; Charge = $null; State = ''; RunMin = $null }
        if ($s) { $b.Name = "$($s.DeviceName)".Trim(); $b.Maker = "$($s.ManufactureName)".Trim(); $b.Design = [double]$s.DesignedCapacity; $b.Chem = ConvertFrom-BatteryChem $s.Chemistry }
        if ($f) { $b.Full = [double]$f.FullChargedCapacity }
        if ($c -and [int]$c.CycleCount -gt 0) { $b.Cycles = [int]$c.CycleCount }
        if ($w) {
            if (-not $b.Name) { $b.Name = "$($w.Name)".Trim() }
            if ($null -ne $w.EstimatedChargeRemaining) { $b.Charge = [int]$w.EstimatedChargeRemaining }
            if ($w.EstimatedRunTime -and [int64]$w.EstimatedRunTime -lt 6000) { $b.RunMin = [int]$w.EstimatedRunTime }
            if (-not $b.Chem) { $b.Chem = switch ([int]$w.Chemistry) { 6 { 'Lithium-ion' } 8 { 'Lithium-polymère' } 5 { 'Nickel-métal-hydrure' } default { '' } } }
        }
        if ($x) { $b.State = if ($x.Charging) { 'en charge' } elseif ($x.PowerOnline) { 'branché' } elseif ($x.Discharging) { 'sur batterie' } else { '' } }
        elseif ($w) { $b.State = switch ([int]$w.BatteryStatus) { 1 { 'sur batterie' } 2 { 'branché' } 6 { 'en charge' } 7 { 'en charge' } 8 { 'en charge' } 9 { 'en charge' } default { '' } } }
        [void]$list.Add($b)
    }
    # Compléments par le rapport officiel de Windows (capacités et cycles absents du WMI sur certains PC)
    if (@($list | Where-Object { -not $_.Design -or -not $_.Full -or $null -eq $_.Cycles }).Count) {
        try {
            # Dossier protégé : un nom fixe dans un dossier modifiable par le compte pouvait être piégé (écriture admin détournée)
            $xmlPath = Join-Path (Get-SecureDir 'session') ("batterie_{0}.xml" -f [guid]::NewGuid().ToString('N'))
            $null = & powercfg.exe /batteryreport /xml /output $xmlPath 2>&1
            if (Test-Path -LiteralPath $xmlPath) {
                [xml]$doc = Get-Content -LiteralPath $xmlPath -Raw -Encoding UTF8
                Remove-Item -LiteralPath $xmlPath -Force -ErrorAction SilentlyContinue
                $rb = @($doc.GetElementsByTagName('Battery'))
                for ($k = 0; $k -lt [math]::Min($rb.Count, $list.Count); $k++) {
                    $r = $rb[$k]; $b = $list[$k]
                    if (-not $b.Design -and $r.DesignCapacity) { $b.Design = [double]$r.DesignCapacity }
                    if (-not $b.Full -and $r.FullChargeCapacity) { $b.Full = [double]$r.FullChargeCapacity }
                    if ($null -eq $b.Cycles -and $r.CycleCount -and [int]$r.CycleCount -gt 0) { $b.Cycles = [int]$r.CycleCount }
                    if (-not $b.Maker -and $r.Manufacturer) { $b.Maker = "$($r.Manufacturer)".Trim() }
                    if (-not $b.Name -and $r.Id) { $b.Name = "$($r.Id)".Trim() }
                    if (-not $b.Chem -and $r.Chemistry) { $b.Chem = ConvertFrom-BatteryChem "$($r.Chemistry)" }
                }
            }
        } catch {}
    }
    foreach ($b in $list) { if ($b.Design -gt 0 -and $b.Full -gt 0) { $b.Health = [int][math]::Round(100.0 * $b.Full / $b.Design) } }
    return $list.ToArray()
}

# Rapport complet de Windows (page HTML) : enregistré dans le dossier protégé (lisible par tous, modifiable seulement en
# administrateur), puis ouvert dans la session de la personne
function Open-BatteryReport {
    Step "Rapport complet de la batterie (Windows)"
    $out = Join-Path (Get-SecureDir 'session') 'rapport_batterie.html'
    if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue }
    $null = & powercfg.exe /batteryreport /output $out 2>&1
    if (-not (Test-Path -LiteralPath $out)) {
        Add-TaskError -Title "Le rapport de batterie n'a pas pu être créé" -Cause "Windows n'a pas réussi à lire les informations de la batterie (pilote de batterie absent ou batterie retirée)."
        return
    }
    if (Open-LocalFile $out) { Log "   ✔ Rapport ouvert : historique de charge, capacité au fil du temps et autonomie estimée." }
}

function Test-Battery {
    $bats = @(Get-BatteryInfo)
    if (-not $bats.Count) { return }
    $k = 0
    foreach ($b in $bats) {
        $k++
        $label = if ($bats.Count -gt 1) { "Batterie $k" } else { 'Batterie' }
        if ($null -eq $b.Health) { Add-Ok "$label : usure non mesurable sur ce PC"; continue }
        $cap = "{0:N1} Wh sur {1:N1} Wh d'origine" -f ($b.Full / 1000), ($b.Design / 1000)
        if ($b.Health -ge 80) { Add-Ok ("{0} en bonne santé ({1} %)" -f $label, [math]::Min($b.Health, 100)) }
        elseif ($b.Health -ge 60) { Add-Ok ("{0} un peu usée ({1} %) : normal après quelques années" -f $label, $b.Health) }
        else {
            Add-Issue -Id "battery$k" -Sev 'warn' -Title ("{0} très usée : {1} % de sa capacité d'origine" -f $label, $b.Health) -Detail ($cap + $(if ($b.Cycles) { "  ·  $($b.Cycles) cycles de charge" } else { '' })) `
                -Cause "Une batterie perd de la capacité avec le temps et les recharges : c'est de l'usure normale, pas une panne du PC." `
                -Effect "Autonomie bien plus courte qu'à l'origine, et le PC peut s'éteindre d'un coup quand la batterie est faible." `
                -Steps @("Onglet « Mon PC » > Batterie : tu y trouves sa référence et sa capacité pour commander la bonne batterie de remplacement.", "Cherche une batterie avec le modèle exact du PC (ou la référence de la batterie) chez le fabricant ou un vendeur sérieux.", "En attendant : laisse le PC branché quand tu peux et évite de le laisser se vider complètement.")
        }
    }
}

# =====================================================================
#  PROGRAMMES CACHÉS EN FOND : tâches planifiées et services qui ne sont pas de Microsoft
# =====================================================================
# Reconnus : regex sur nom + chemin, libellé clair, verdict ('off' = inutile en fond, 'keep' = à garder), explication
$script:BgKnown = @(
    @('(?i)mcafee|norton|avast|\bavg\b|bitdefender|kaspersky|\beset\b|malwarebytes|sophos|trend ?micro|panda|f-secure|webroot|g ?data|windows ?defender', 'Antivirus', 'keep', "Protège le PC : ne pas toucher."),
    @('(?i)google ?update|gupdate|googleupdater', 'Mises à jour de Google Chrome', 'keep', "Installe les correctifs de sécurité de Chrome : à garder."),
    @('(?i)edgeupdate|microsoftedgeupdate', 'Mises à jour de Microsoft Edge', 'keep', "Installe les correctifs de sécurité d'Edge : à garder."),
    @('(?i)brave.*update|braveupdate|firefox.*(maintenance|background ?update)|mozilla', 'Mises à jour du navigateur', 'keep', "Correctifs de sécurité du navigateur : à garder."),
    @('(?i)onedrive.*(standalone|update)', 'Mises à jour de OneDrive', 'keep', "À garder si tu utilises OneDrive."),
    @('(?i)nvdisplay\.container|nvcontainerlocalsystem|nvidia display', 'Panneau de configuration NVIDIA', 'keep', "Nécessaire au pilote de la carte graphique."),
    @('(?i)realtek|audio|nahimic|dolby|dts|waves', 'Son (pilote audio)', 'keep', "Fait partie du pilote audio : à garder."),
    @('(?i)opera.*(assistant|autoupdate|scheduled)|opera gx', "Assistant et mises à jour d'Opera", 'off', "Inutile en fond : Opera se met à jour quand tu l'ouvres."),
    @('(?i)adobe ?arm|adobe acrobat update|acrobat.*update', "Mises à jour d'Adobe Acrobat Reader", 'off', "Reader se met aussi à jour quand tu l'ouvres."),
    @('(?i)adobe.*genuine|agsservice|adobegcinvoker|gc ?invoker', "Vérification de licence Adobe", 'off', "Tourne en permanence pour vérifier les licences Adobe : inutile si tu n'as pas de logiciel Adobe payant."),
    @('(?i)ccleaner|driver ?booster|iobit|advanced systemcare|glary|wise ?care|avast ?cleanup|pc ?app ?store|reimage|restoro|segurazo|wondershare.*helper', "Logiciel « d'optimisation » / douteux", 'off', "Ce genre de logiciel tourne en fond pour afficher des alertes et vendre une version payante."),
    @('(?i)nvtm|nvtelemetry|nvdriverupdatecheck|nvidia telemetry', 'Statistiques et vérifications NVIDIA', 'off', "Envoie des statistiques à NVIDIA : le pilote marche très bien sans."),
    @('(?i)intel.*(telemetry|computing improvement|system usage report)|sursvc|esrv', 'Statistiques Intel', 'off', "Envoie des statistiques d'utilisation à Intel."),
    @('(?i)hp.*(analytics|touchpoint|customer participation|insights|diagnostics data|app helper|jumpstart)|hpsvcsscan', 'Statistiques et publicités HP', 'off', "Collecte des données pour HP : le PC marche sans."),
    @('(?i)dell.*(data ?vault|supportassist ?remediation|techhub)', 'Statistiques Dell', 'off', "Collecte des données pour Dell : le PC marche sans."),
    @('(?i)lenovo.*(telemetry|experience improvement|customer feedback)|imcontroller.*telemetry', 'Statistiques Lenovo', 'off', "Collecte des données pour Lenovo : le PC marche sans."),
    @('(?i)acer.*(portal|jumpstart)|asus.*giftbox', 'Utilitaires du fabricant', 'off', "Petits utilitaires préinstallés qui tournent en fond sans être indispensables."),
    @('(?i)onedrive.*reporting', 'Rapports OneDrive', 'off', "Envoie des rapports d'utilisation à Microsoft."),
    @('(?i)cortana|\bbing\b|\bmsn\b', 'Services Bing / MSN', 'off', "Contenus et publicités Bing/MSN.")
)
function Get-BgVerdict([string]$Text) {
    foreach ($k in $script:BgKnown) { if ($Text -match $k[0]) { return @{ Label = $k[1]; Verdict = $k[2]; Why = $k[3] } } }
    return @{ Label = ''; Verdict = 'unknown'; Why = "Pas reconnu : garde-le si tu ne sais pas à quoi il sert." }
}
function Get-ExeFromCommand([string]$Cmd) {
    $c = "$Cmd".Trim()
    if ($c -match '^"([^"]+)"') { return $matches[1] }
    if ($c -match '^(.+?\.exe)\b') { return $matches[1] }
    return ($c -split '\s+')[0]
}
function Get-BgCompany([string]$Exe) {
    try { $p = [Environment]::ExpandEnvironmentVariables($Exe); if (Test-Path -LiteralPath $p) { return "$((Get-Item -LiteralPath $p).VersionInfo.CompanyName)".Trim() } } catch {}
    return ''
}
function Get-BgItemsList {
    $list = New-Object System.Collections.ArrayList
    # Tâches planifiées actives hors Microsoft
    foreach ($t in @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.State -ne 'Disabled' -and $_.TaskPath -notlike '\Microsoft\*' })) {
        $exe = ''; $arg = ''; try { $exe = Get-ExeFromCommand "$(@($t.Actions)[0].Execute)"; $arg = "$(@($t.Actions)[0].Arguments)" } catch {}
        $co = Get-BgCompany $exe
        if ($exe -match '(?i)(rundll32|wscript|cscript|powershell|pwsh|cmd|mshta|conhost)(\.exe)?$') {
            # Programme hôte de Windows : le vrai programme est dans les arguments
            $inner = [regex]::Match($arg, '(?i)[a-z]:\\[^"]+?\.(exe|dll)').Value
            if ($inner) { $exe = $inner; $co = Get-BgCompany $inner } else { $co = '' }
        }
        if ($co -match '^Microsoft' -and "$($t.TaskName)" -notmatch '(?i)onedrive|edge') { continue }
        if ("$($t.TaskName)" -match '(?i)aerox') { continue }
        $v = Get-BgVerdict ("{0} {1} {2} {3}" -f $t.TaskName, $t.TaskPath, $exe, $co)
        [void]$list.Add(@{ Kind = 'task'; Path = "$($t.TaskPath)"; Name = "$($t.TaskName)"; Exe = $exe; Company = $co; Label = $v.Label; Verdict = $v.Verdict; Why = $v.Why })
    }
    # Services qui démarrent avec Windows, hors Microsoft
    foreach ($sv in @(Get-CimInstance Win32_Service -Filter "StartMode='Auto'" -ErrorAction SilentlyContinue)) {
        $exe = Get-ExeFromCommand "$($sv.PathName)"
        if ($exe -match '(?i)\\windows\\(system32|syswow64)\\' -and "$($sv.PathName)" -match '(?i)svchost') { continue }
        $co = Get-BgCompany $exe
        if ($co -match '^Microsoft' -or (-not $co -and $exe -match '(?i)^[a-z]:\\windows\\')) { continue }
        $v = Get-BgVerdict ("{0} {1} {2} {3}" -f $sv.Name, $sv.DisplayName, $exe, $co)
        [void]$list.Add(@{ Kind = 'service'; Path = ''; Name = "$($sv.Name)"; Display = "$($sv.DisplayName)"; Exe = $exe; Company = $co; Label = $v.Label; Verdict = $v.Verdict; Why = $v.Why; Running = ("$($sv.State)" -eq 'Running') })
    }
    return $list.ToArray()
}
function Get-BgItems {
    Step "Recherche des programmes cachés qui tournent en fond (tâches planifiées et services)"
    $sync.BgItems = $null
    $items = @(Get-BgItemsList)
    $sync.BgItems = $items
    Log ("   ✔ {0} tâche(s) et {1} service(s) hors Microsoft, dont {2} inutile(s) en fond." -f @($items | Where-Object { $_.Kind -eq 'task' }).Count, @($items | Where-Object { $_.Kind -eq 'service' }).Count, @($items | Where-Object { $_.Verdict -eq 'off' }).Count)
}
# Un élément : tâche activée / désactivée, service automatique / manuel (manuel = il démarre seulement si un logiciel en a besoin)
function Set-BgItem([string]$Kind, [string]$Path, [string]$Name, [string]$State) {
    if ($Kind -eq 'task' -and $Path -like '\Microsoft\*' -and $State -ne 'on') { throw "Les tâches de Windows ne sont jamais coupées par AEROX." }
    if ($Kind -eq 'task') {
        if ($State -eq 'on') { Enable-ScheduledTask -TaskPath $Path -TaskName $Name -ErrorAction Stop | Out-Null } else { Disable-ScheduledTask -TaskPath $Path -TaskName $Name -ErrorAction Stop | Out-Null }
    } else {
        Set-Service -Name $Name -StartupType $(if ($State -eq 'auto') { 'Automatic' } else { 'Manual' }) -ErrorAction Stop
    }
}
function Disable-BgItems([string[]]$Items) {
    Step ("Désactivation de {0} programme(s) caché(s) en fond" -f $Items.Count)
    $ok = 0
    foreach ($it in $Items) {
        $p = $it.Split('|', 4); if ($p.Count -lt 4) { continue }
        $kind = $p[0]; $path = $p[1]; $name = $p[2]; $label = $p[3]
        try {
            if ($kind -eq 'task') {
                Set-BgItem 'task' $path $name 'off'
                Add-Change -Title ("Tâche en fond désactivée : {0}" -f $label) -Undo ("Set-BgItem 'task' {0} {1} 'on'" -f (ConvertTo-PsLiteral $path), (ConvertTo-PsLiteral $name))
            } else {
                Set-BgItem 'service' '' $name 'manual'
                Add-Change -Title ("Service en démarrage manuel : {0}" -f $label) -Detail "Il démarre seulement si un logiciel en a besoin." -Undo ("Set-BgItem 'service' '' {0} 'auto'" -f (ConvertTo-PsLiteral $name))
            }
            $ok++; Log ("   ✔ {0}" -f $label)
        } catch { Log ("   ⚠ {0} : {1}" -f $label, $_.Exception.Message) }
    }
    Log ("✅ {0} programme(s) caché(s) ne tournent plus en fond. Effet complet au prochain redémarrage. Tout est annulable dans l'historique." -f $ok)
}
# Diagnostic : programmes cachés reconnus comme inutiles
function Test-BgItems {
    $off = @(Get-BgItemsList | Where-Object { $_.Verdict -eq 'off' })
    if ($off.Count -ge 1) {
        $names = (@($off | Select-Object -First 3 | ForEach-Object { if ($_.Label) { $_.Label } else { $_.Name } } | Select-Object -Unique) -join ', ')
        Add-Issue -Id 'bgitems' -Sev 'warn' -Title ("{0} programme(s) caché(s) tournent en fond pour rien" -f $off.Count) -Detail $names `
            -Cause "Statistiques de fabricants, outils de mise à jour inutiles ou logiciels « d'optimisation » qui se lancent tout seuls, sans apparaître dans les programmes au démarrage." `
            -Effect "Ils prennent de la mémoire et du processeur en permanence, et ralentissent le démarrage." `
            -FixLabel "Voir et choisir" -UiFix 'bgitems'
    } else { Add-Ok "Programmes cachés en fond : rien d'inutile repéré" }
}

# =====================================================================
#  DÉPANNAGES DU QUOTIDIEN : imprimante, son, micro, webcam, bureau figé
# =====================================================================
# Autorisation Windows « Autoriser les applications à accéder au micro / à la caméra » (Confidentialité)
function Get-PrivacyBlocked([string]$Cap) {
    $blocked = @()
    foreach ($root in 'HKLM:', (Get-SessionUser).Hkcu) {
        $k = "$root\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$Cap"
        foreach ($p in @($k, "$k\NonPackaged")) {
            try { if ((Get-ItemProperty -LiteralPath $p -Name Value -ErrorAction Stop).Value -eq 'Deny') { $blocked += $p } } catch {}
        }
    }
    return $blocked
}
function Set-PrivacyAllowed([string]$Cap, [string]$Label) {
    $b = @(Get-PrivacyBlocked $Cap)
    if (-not $b.Count) { Log "   ✔ Windows autorise les applications à utiliser $Label"; return $false }
    foreach ($p in $b) { try { Set-ItemProperty -LiteralPath $p -Name Value -Value 'Allow' -ErrorAction Stop } catch {} }
    Log "   ✔ L'accès à $Label était bloqué dans les réglages de confidentialité de Windows : réautorisé."
    Add-Change -Kind 'info' -Title "Accès à $Label réautorisé (Confidentialité de Windows)"
    return $true
}
# Périphériques désactivés (code 22) d'une classe : réactivés
function Enable-DisabledDevices([string[]]$Classes, [string]$Label, [string]$IdPattern = '') {
    $n = 0
    foreach ($d in @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.Class -in $Classes -and [int]$_.ConfigManagerErrorCode -eq 22 -and (-not $IdPattern -or $_.InstanceId -match $IdPattern) })) {
        try { Enable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false -ErrorAction Stop; Log ("   ✔ {0} était désactivé : réactivé." -f $d.FriendlyName); $n++ } catch {}
    }
    if ($n) { Add-Change -Kind 'info' -Title ("{0} réactivé(s) : {1}" -f $Label, $n) }
    return $n
}

function Repair-Printing {
    Step "Imprimante : déblocage de l'impression"
    $printers = @(Get-CimInstance Win32_Printer -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '(?i)onenote|pdf|xps|fax|send to' })
    if (-not $printers.Count) {
        Add-TaskError -Title "Aucune imprimante installée sur ce PC" -Cause "Windows ne connaît aucune imprimante (hors imprimantes virtuelles PDF/XPS)." -Effect "Impossible d'imprimer tant qu'elle n'est pas ajoutée." `
            -FixLabel "Ajouter une imprimante" -FixAction "Open-WinUri 'ms-settings:printers'" -Steps @("Allume l'imprimante et vérifie qu'elle est branchée (USB) ou sur le même Wi-Fi que le PC.", "Paramètres > Bluetooth et appareils > Imprimantes et scanners > « Ajouter un appareil ».", "Si elle n'apparaît pas, installe le logiciel du fabricant (HP Smart, Canon, Epson…) depuis son site officiel.")
        return
    }
    $jobs = 0; try { $jobs = @(Get-CimInstance Win32_PrintJob -ErrorAction SilentlyContinue).Count } catch {}
    Log ("   • {0} impression(s) en attente dans la file" -f $jobs)
    # File d'attente bloquée : on arrête le service d'impression, on vide la file, on le relance
    try {
        Stop-Service -Name Spooler -Force -ErrorAction Stop
        Get-ChildItem -LiteralPath (Join-Path $env:SystemRoot 'System32\spool\PRINTERS') -File -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Start-Service -Name Spooler -ErrorAction Stop
        Log "   ✔ Service d'impression relancé et file d'attente vidée"
    } catch {
        try { Start-Service -Name Spooler -ErrorAction SilentlyContinue } catch {}
        Add-TaskError -Title "Le service d'impression n'a pas pu être relancé" -Cause $_.Exception.Message -FixLabel "Redémarrer le PC" -FixAction 'Request-Reboot'
        return
    }
    # Imprimante restée « hors connexion » dans Windows
    foreach ($pr in @(Get-CimInstance Win32_Printer -ErrorAction SilentlyContinue | Where-Object { $_.WorkOffline })) {
        try { Set-CimInstance -InputObject $pr -Property @{ WorkOffline = $false } -ErrorAction Stop; Log ("   ✔ « {0} » était en mode hors connexion : remise en ligne" -f $pr.Name) } catch {}
    }
    foreach ($pr in @(Get-CimInstance Win32_Printer -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '(?i)onenote|pdf|xps|fax|send to' })) {
        $st = switch ([int]$pr.PrinterStatus) { 3 { 'prête' } 4 { 'en train d''imprimer' } 5 { 'en préchauffage' } 7 { 'HORS LIGNE' } 1 { 'état inconnu' } 2 { 'état inconnu' } default { "état $($pr.PrinterStatus)" } }
        Log ("   • {0}{1} : {2}" -f $pr.Name, $(if ($pr.Default) { ' (par défaut)' } else { '' }), $st)
    }
    $def = $printers | Where-Object { $_.Default } | Select-Object -First 1
    if (-not $def) { Log "   ⚠ Aucune imprimante par défaut : choisis-la dans Paramètres > Imprimantes et scanners." }
    Log "✅ Relance une impression. Si rien ne sort : imprimante allumée, papier, câble ou même Wi-Fi que le PC, puis éteins-la et rallume-la."
    Add-Change -Kind 'info' -Title "Impression débloquée (service relancé, file d'attente vidée)"
}

# Nom de l'appareil son par défaut (sortie ou micro) : « Casque (3- Arctis Nova Pro Wireless) »…
function Get-AudioDefaultName([bool]$Capture, [int]$Role = 0) {
    $id = [AeroxAudio]::DefaultId($Capture, $Role)
    if (-not $id) { return '' }
    $d = @(Get-PnpDevice -Class AudioEndpoint -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -like "*$id" }) | Select-Object -First 1
    return $(if ($d) { "$($d.FriendlyName)" } else { '' })
}
# Ce qu'il faut choisir dans Discord (ou Teams, les jeux…) : les appareils de Windows, ou ceux de SteelSeries Sonar
# quand il est installé (Sonar fait passer le son des appels par ses propres appareils « Chat » et « Microphone »)
function Write-VoiceAppAdvice {
    $all = @(Get-PnpDevice -Class AudioEndpoint -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'OK' } | ForEach-Object { "$($_.FriendlyName)" })
    $sonarOut = @($all | Where-Object { $_ -match '(?i)sonar\s*-\s*chat' }) | Select-Object -First 1
    $sonarIn  = @($all | Where-Object { $_ -match '(?i)sonar\s*-\s*microphone' }) | Select-Object -First 1
    if ($sonarOut -and $sonarIn) {
        Log "   → SteelSeries Sonar est installé : dans Discord > Paramètres > Voix et vidéo, choisis"
        Log "       Périphérique d'entrée : « $sonarIn »"
        Log "       Périphérique de sortie : « $sonarOut »"
        Log "     (c'est ce que demande SteelSeries : Sonar envoie ensuite le son vers ton casque, réglable dans son appli)"
        return
    }
    $in = Get-AudioDefaultName $true 2; if (-not $in) { $in = Get-AudioDefaultName $true 0 }
    $out = Get-AudioDefaultName $false 2; if (-not $out) { $out = Get-AudioDefaultName $false 0 }
    if ($in -or $out) {
        Log "   → Dans Discord > Paramètres > Voix et vidéo, choisis les appareils que Windows utilise :"
        if ($in) { Log "       Périphérique d'entrée : « $in »" }
        if ($out) { Log "       Périphérique de sortie : « $out »" }
        Log "     (« Default » / « Par défaut » marche aussi : il suit ce que Windows utilise)"
    }
}
function Repair-Sound {
    Step "Son : vérification et réparation"
    foreach ($svc in 'AudioEndpointBuilder', 'Audiosrv') {
        try {
            $sv = Get-Service -Name $svc -ErrorAction Stop
            if ($sv.StartType -eq 'Disabled') { Set-Service -Name $svc -StartupType Automatic -ErrorAction Stop; Log "   ✔ Service audio « $svc » était désactivé : réactivé" }
        } catch {}
    }
    # Le service du son n'est relancé QUE s'il est arrêté : le relancer quand il marche coupe le son de tout le PC
    # quelques secondes, et Discord, Teams ou un jeu perdent alors le micro ou le casque (retour testeur)
    try {
        $as = Get-Service -Name Audiosrv -ErrorAction Stop
        if ($as.Status -ne 'Running') { Start-Service -Name Audiosrv -ErrorAction Stop; Log "   ✔ Service audio de Windows était arrêté : redémarré"; Start-Sleep -Seconds 2 }
        else { Log "   ✔ Service audio de Windows en marche" }
    } catch { Log "   ⚠ Le service audio de Windows ne démarre pas : $($_.Exception.Message)" }
    [void](Enable-DisabledDevices @('AudioEndpoint') 'Sortie son' '\{0\.0\.0\.')
    $outs = @(Get-PnpDevice -Class AudioEndpoint -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'OK' -and $_.InstanceId -match '\{0\.0\.0\.' } | ForEach-Object { $_.FriendlyName })
    if ($outs.Count) { Log ("   • Sorties détectées : {0}" -f ($outs -join ' · ')) }
    $info = [AeroxAudio]::Info($false)
    if (-not $info) {
        Add-TaskError -Title "Aucun haut-parleur ni casque actif" -Cause "Windows ne trouve pas de sortie son en marche." -Effect "Aucun son ne peut sortir du PC." `
            -FixLabel "Ouvrir les réglages du son" -FixAction "Open-WinUri 'ms-settings:sound'" -Steps @("Branche le casque ou les enceintes (prise verte ou USB), allume-les.", "Sur un écran HDMI, le son passe souvent par l'écran : vérifie son volume.", "Paramètres > Son : choisis le bon appareil dans « Choisir où lire le son ».", "Sinon : Mises à jour > Pilotes (drivers) pour installer le pilote audio.")
        return
    }
    $p = $info.Split('|'); $vol = [int]$p[0]; $muted = ($p[1] -eq '1')
    if ($muted -or $vol -lt 10) {
        [void][AeroxAudio]::Fix($false, 50)
        Log ("   ✔ Le son {0} : remis à {1} %" -f $(if ($muted) { 'était coupé (sourdine)' } else { "était presque à zéro ($vol %)" }), [math]::Max($vol, 50))
        Add-Change -Kind 'info' -Title "Son réactivé (sourdine enlevée / volume remonté)"
    } else { Log "   ✔ Volume à $vol %, sourdine désactivée" }
    $cur = Get-AudioDefaultName $false 0
    if ($cur) { Log "   • Le son sort actuellement sur : « $cur »" }
    Write-VoiceAppAdvice
    Log "✅ Si tu n'entends toujours rien : vérifie que le son sort sur le bon appareil (casque, écran ou enceintes) dans Paramètres > Son, et le volume de l'appareil lui-même."
}

function Repair-Microphone {
    Step "Micro : vérification et réparation"
    [void](Set-PrivacyAllowed 'microphone' 'le micro')
    [void](Enable-DisabledDevices @('AudioEndpoint') 'Micro' '\{0\.0\.1\.')
    $ins = @(Get-PnpDevice -Class AudioEndpoint -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'OK' -and $_.InstanceId -match '\{0\.0\.1\.' } | ForEach-Object { $_.FriendlyName })
    if ($ins.Count) { Log ("   • Micros détectés : {0}" -f ($ins -join ' · ')) }
    $info = [AeroxAudio]::Info($true)
    if (-not $info) {
        Add-TaskError -Title "Aucun micro actif" -Cause "Windows ne trouve pas de micro en marche." -Effect "Discord, Teams, les jeux… ne t'entendent pas." `
            -FixLabel "Ouvrir les réglages du son" -FixAction "Open-WinUri 'ms-settings:sound'" -Steps @("Branche le micro ou le casque (prise rose ou USB). Sur un casque, vérifie le bouton « mute » du câble.", "Paramètres > Son > Entrée : choisis le bon micro.", "Dans Discord/Teams, choisis aussi ce micro dans leurs propres réglages audio.")
        return
    }
    $p = $info.Split('|'); $vol = [int]$p[0]; $muted = ($p[1] -eq '1')
    if ($muted -or $vol -lt 30) {
        [void][AeroxAudio]::Fix($true, 80)
        Log ("   ✔ Le micro {0} : remis à {1} %" -f $(if ($muted) { 'était coupé (sourdine)' } else { "était très bas ($vol %)" }), [math]::Max($vol, 80))
        Add-Change -Kind 'info' -Title "Micro réactivé (sourdine enlevée / volume remonté)"
    } else { Log "   ✔ Micro à $vol %, sourdine désactivée" }
    $cur = Get-AudioDefaultName $true 0
    if ($cur) { Log "   • Micro utilisé par Windows : « $cur »" }
    Write-VoiceAppAdvice
    Log "✅ Teste ton micro : Paramètres > Son > ton micro > « Tester le micro ». Dans Discord, le bouton « Vérifions » (Voix et vidéo) te fait entendre ta voix."
}

function Repair-Webcam {
    Step "Webcam : vérification et réparation"
    [void](Set-PrivacyAllowed 'webcam' 'la caméra')
    [void](Enable-DisabledDevices @('Camera', 'Image') 'Webcam')
    $cams = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.Class -in 'Camera', 'Image' -and $_.FriendlyName -notmatch '(?i)scan|printer|imprim' })
    if (-not $cams.Count) {
        Add-TaskError -Title "Aucune webcam détectée" -Cause "Windows ne voit aucune caméra branchée ou allumée." -Effect "Les appels vidéo n'ont pas d'image." `
            -Steps @("Webcam USB : débranche-la et rebranche-la sur un autre port.", "PC portable : beaucoup ont un petit cache coulissant au-dessus de l'écran, ou une touche avec une caméra barrée (souvent F8, F10 ou Fn + une touche) qui coupe la webcam.", "Sinon : Mises à jour > Pilotes (drivers) pour vérifier son pilote.")
        return
    }
    foreach ($c in $cams) { Log ("   • {0} : {1}" -f $c.FriendlyName, $(if ($c.Status -eq 'OK') { 'en marche' } else { "problème ($($c.Status))" })) }
    if (@($cams | Where-Object { $_.Status -ne 'OK' }).Count) {
        Add-TaskError -Title "La webcam a un problème de pilote" -Cause "Windows la voit mais n'arrive pas à la faire fonctionner." -Effect "Pas d'image dans les appels vidéo." `
            -FixLabel "Ouvrir le Gestionnaire de périphériques" -FixAction "Open-SystemTool 'devmgmt.msc'" -Steps @("Débranche/rebranche la webcam (USB) ou redémarre le PC.", "Onglet Mises à jour > « Pilotes (drivers) » : installe le pilote que Windows propose.")
        return
    }
    try { Open-WinUri 'microsoft.windows.camera:' -ErrorAction Stop; Log "   ✔ L'application Caméra de Windows s'ouvre pour tester." } catch {}
    Log "✅ Si l'image reste noire : ferme les autres logiciels qui utilisent la caméra (Teams, Discord, navigateur…), et vérifie le cache ou la touche caméra sur un portable."
}

# Bureau, barre des tâches ou menu Démarrer figés : relance de l'Explorateur Windows
function Restart-Shell {
    Step "Relance du bureau et de la barre des tâches (Explorateur Windows)"
    $owner = ''
    try { $owner = "$((Get-CimStatic Win32_ComputerSystem -Quiet).UserName)" } catch {}
    Get-Process -Name explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    # Windows relance tout seul l'Explorateur de la personne connectée ; sinon on le relance pour elle
    for ($i = 0; $i -lt 10 -and -not (Get-Process -Name explorer -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 500 }
    # (Avec un compte admin séparé, on ne relance pas nous-mêmes : ce serait le bureau du compte admin, pas celui de la personne)
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue) -and -not (Test-OtherAccount)) { Start-Process explorer.exe }
    Log "✅ Bureau et barre des tâches relancés. Si le menu Démarrer bloque encore, redémarre le PC."
}

# =====================================================================
#  NAVIGATEURS : fausses alertes, extensions et réglages piratés
# =====================================================================
# Chrome, Edge, Brave, Opera : même fonctionnement (Chromium). Firefox : conseils seulement.
$script:BrowserDefs = @(
    @{ Key = 'chrome';  Name = 'Google Chrome';  Proc = 'chrome'; Data = 'AppData\Local\Google\Chrome\User Data';                Scheme = 'chrome'; Pol = 'SOFTWARE\Policies\Google\Chrome';        Exe = @('Google\Chrome\Application\chrome.exe') }
    @{ Key = 'edge';    Name = 'Microsoft Edge'; Proc = 'msedge'; Data = 'AppData\Local\Microsoft\Edge\User Data';               Scheme = 'edge';   Pol = 'SOFTWARE\Policies\Microsoft\Edge';       Exe = @('Microsoft\Edge\Application\msedge.exe') }
    @{ Key = 'brave';   Name = 'Brave';          Proc = 'brave';  Data = 'AppData\Local\BraveSoftware\Brave-Browser\User Data'; Scheme = 'brave';  Pol = 'SOFTWARE\Policies\BraveSoftware\Brave'; Exe = @('BraveSoftware\Brave-Browser\Application\brave.exe') }
    @{ Key = 'opera';   Name = 'Opera';          Proc = 'opera';  Data = 'AppData\Roaming\Opera Software\Opera Stable';         Scheme = 'opera';  Pol = '';                                      Exe = @('Programs\Opera\opera.exe', 'Opera\opera.exe') }
    @{ Key = 'operagx'; Name = 'Opera GX';       Proc = 'opera';  Data = 'AppData\Roaming\Opera Software\Opera GX Stable';      Scheme = 'opera';  Pol = '';                                      Exe = @('Programs\Opera GX\opera.exe', 'Opera GX\opera.exe') }
)
# Sites connus dont les notifications sont normales (messagerie, réseaux sociaux, mails…)
$script:NotifOk = '(?i)(^|\.)(google\.[a-z.]+|youtube\.com|gmail\.com|facebook\.com|messenger\.com|instagram\.com|whatsapp\.com|discord\.com|twitter\.com|x\.com|linkedin\.com|outlook\.com|live\.com|office\.com|office365\.com|microsoft\.com|cloud\.microsoft|slack\.com|telegram\.org|reddit\.com|twitch\.tv|netflix\.com|spotify\.com|deezer\.com|leboncoin\.fr|vinted\.[a-z.]+|amazon\.[a-z.]+|ebay\.[a-z.]+|pinterest\.[a-z.]+|tiktok\.com|snapchat\.com|zoom\.us|skype\.com|yahoo\.com|orange\.fr|free\.fr|sfr\.fr|bouyguestelecom\.fr|laposte\.(fr|net)|doctolib\.fr|ameli\.fr|gouv\.fr|chatgpt\.com|openai\.com|claude\.ai|notion\.so|trello\.com|github\.com|steamcommunity\.com|steampowered\.com|epicgames\.com|ea\.com|ubisoft\.com|battle\.net|blizzard\.com|apple\.com|icloud\.com|proton\.me|canva\.com|dropbox\.com|airbnb\.[a-z.]+|booking\.com|blablacar\.fr|sncf-connect\.com|uber\.com|deliveroo\.fr|lemonde\.fr|lefigaro\.fr|ouest-france\.fr|bfmtv\.com|francetvinfo\.fr|20minutes\.fr|lequipe\.fr|lavoixdunord\.fr|castorama\.fr|leroymerlin\.fr|ikea\.com|fnac\.com|darty\.com|boulanger\.com|cdiscount\.com|ldlc\.com|materiel\.net|decathlon\.fr|lidl\.fr|carrefour\.fr|e\.leclerc|leclerc\.[a-z]+|auchan\.fr|intermarche\.com|bricodepot\.fr|manomano\.fr|aliexpress\.[a-z]+|temu\.com|shein\.com|zalando\.fr|backmarket\.fr|allocine\.fr|marmiton\.org|caf\.fr|pole-emploi\.fr|francetravail\.fr|service-public\.fr|labanquepostale\.fr|credit-agricole\.fr|societegenerale\.fr|bnpparibas|lcl\.fr|boursorama\.com|creditmutuel\.fr|caisse-epargne\.fr|paypal\.com)$'
# Ce qui ressemble aux fausses alertes (« clique sur Autoriser pour prouver que tu n'es pas un robot »)
$script:NotifBad = '(?i)(captcha|robot|verif|allow|click|push|notif|alert|prize|winner|gift|bonus|virus|secur|protect|clean|update|download|stream|movie|film|porn|xxx|sex|dating|casino|bet|loan|crypto|bitcoin)|\.(xyz|top|club|online|site|live|icu|buzz|space|click|pw|info|life|work|fun|bid|loan|win|cf|ga|gq|ml|tk|biz|cyou|monster|rest|sbs|cfd|quest|hair|homes|beauty|autos|boats|lol|today|digital|world|pro)$|\d{4,}|^\d+\.\d+\.\d+\.\d+$'
# Pages d'accueil / moteurs de recherche normaux
$script:HomeOk = '(?i)(^|\.)(google\.[a-z.]+|bing\.com|msn\.com|microsoft\.com|duckduckgo\.com|qwant\.com|ecosia\.org|lilo\.org|startpage\.com|brave\.com|yahoo\.com|yandex\.[a-z]+|opera\.com|mozilla\.org|wikipedia\.org|youtube\.com|orange\.fr|free\.fr|sfr\.fr|laposte\.net|chatgpt\.com|perplexity\.ai)$'
# Éditeurs connus dont l'extension imposée est normale (antivirus, contrôle parental, mots de passe)
$script:ExtTrusted = '(?i)norton|avast|\bavg\b|bitdefender|kaspersky|\beset\b|mcafee|malwarebytes|avira|f-secure|trend micro|panda|qustodio|family|parental|1password|bitwarden|lastpass|dashlane|keeper|zscaler|google|microsoft'

function Get-UrlHost([string]$Url) {
    if (-not $Url) { return '' }
    if ($Url -match '\{google:baseURL\}') { return 'google.com' }
    $u = $Url -replace '^\[\*\.\]', '' -replace ',\*$', ''
    if ($u -notmatch '^[a-z][a-z0-9+.-]*://') { $u = 'http://' + $u }
    try { return ([uri]$u).Host.ToLower() } catch { return '' }
}
function Test-HomeUrlOk([string]$Url) {
    if (-not $Url -or $Url -match '^(?i)(chrome|edge|brave|opera|about)://|^about:') { return $true }
    $h = Get-UrlHost $Url
    return ($h -and $h -match $script:HomeOk)
}
function Read-JsonFile([string]$Path) {
    try { if (Test-Path -LiteralPath $Path) { return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) } } catch {}
    return $null
}
function Get-JsonValue([string]$Json, [string[]]$Path) { if (-not $Json) { return $null }; return [AeroxJson]::Get($Json, $Path) }

# Nom lisible d'une extension depuis son manifest (avec la traduction __MSG_xxx__)
function Get-ExtManifestInfo([string]$Dir) {
    $m = Read-JsonFile (Join-Path $Dir 'manifest.json')
    if (-not $m) { return $null }
    $name = Get-JsonValue $m @('name')
    if ($name -match '^__MSG_(.+)__$') {
        $key = $Matches[1]; $loc = Get-JsonValue $m @('default_locale')
        foreach ($l in @('fr', $loc, 'en', 'en_US') | Where-Object { $_ } | Select-Object -Unique) {
            $msgs = Read-JsonFile (Join-Path $Dir "_locales\$l\messages.json")
            if (-not $msgs) { continue }
            $k = @([AeroxJson]::Keys($msgs, [string[]]@()) | Where-Object { $_ -ieq $key }) | Select-Object -First 1
            if ($k) { $v = Get-JsonValue $msgs @($k, 'message'); if ($v) { $name = $v; break } }
        }
    }
    if ($name -match '^__MSG_') { $name = '' }
    return @{ Name = $name; Hijack = ($null -ne [AeroxJson]::Find($m, [string[]]@('chrome_settings_overrides')) -or $null -ne [AeroxJson]::Find($m, [string[]]@('chrome_url_overrides'))) }
}

function Get-BrowserExe($Def, [string]$ProfileRoot) {
    $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, (Join-Path $ProfileRoot 'AppData\Local')) | Where-Object { $_ }
    foreach ($r in $roots) { foreach ($e in $Def.Exe) { $p = Join-Path $r $e; if (Test-Path -LiteralPath $p) { return $p } } }
    return ''
}

# Ouvre une page interne du navigateur (chrome://extensions…) chez la personne devant l'écran
function Open-BrowserPage([string]$Exe, [string]$Page, [string]$ProfileDir = '') {
    if (-not $Exe -or -not (Test-Path -LiteralPath $Exe)) { Log "⚠ Navigateur introuvable : ouvre-le toi-même et tape $Page dans la barre d'adresse."; return }
    # Le bon profil du navigateur (« Profile 1 »…) : sinon il s'ouvre sur un autre profil, sans la page voulue
    $arg = $(if ($ProfileDir -match '^(Default|Profile \d+)$') { '--profile-directory="{0}" ' -f $ProfileDir } else { '' }) + $Page
    # Toujours dans la session normale, sans droits admin (le navigateur peut être installé dans le dossier perso)
    if (-not (Start-AsSessionUser $Exe $arg)) { Log "⚠ Ouvre ton navigateur et tape $Page dans la barre d'adresse." }
}

# Profils d'un navigateur Chromium : « Default », « Profile 1 »… (Opera : le dossier lui-même)
function Get-ChromiumProfiles([string]$DataDir) {
    $out = @()
    if (-not (Test-Path -LiteralPath $DataDir)) { return $out }
    $ls = Read-JsonFile (Join-Path $DataDir 'Local State')
    if (Test-Path -LiteralPath (Join-Path $DataDir 'Preferences')) { $out += @{ Dir = $DataDir; Name = '' } }
    foreach ($d in @(Get-ChildItem -LiteralPath $DataDir -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' })) {
        if (-not (Test-Path -LiteralPath (Join-Path $d.FullName 'Preferences'))) { continue }
        $n = Get-JsonValue $ls @('profile', 'info_cache', $d.Name, 'name')
        $out += @{ Dir = $d.FullName; Name = $(if ($n) { $n } else { $d.Name }) }
    }
    return $out
}

# Réglages imposés (« Géré par ton organisation ») : clés de stratégie des navigateurs, machine et comptes
function Get-BrowserPolicies($Def, $ExtNames) {
    $out = @()
    if (-not $Def.Pol) { return $out }
    $hives = @('Registry::HKEY_LOCAL_MACHINE')
    $hives += @(Get-ChildItem 'Registry::HKEY_USERS' -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^S-1-5-21-[\d-]+$' } | ForEach-Object { 'Registry::HKEY_USERS\' + $_.PSChildName })
    foreach ($h in $hives) {
        $k = "$h\$($Def.Pol)"
        if (-not (Test-Path -LiteralPath $k)) { continue }
        $props = $null; try { $props = Get-ItemProperty -LiteralPath $k -ErrorAction Stop } catch {}
        foreach ($n in 'HomepageLocation', 'NewTabPageLocation', 'DefaultSearchProviderSearchURL') {
            $v = "$($props.$n)"
            if (-not $v) { continue }
            $lbl = switch ($n) { 'HomepageLocation' { "Page d'accueil imposée" } 'NewTabPageLocation' { 'Page « Nouvel onglet » imposée' } default { 'Moteur de recherche imposé' } }
            $out += @{ Key = $k; Value = $n; Label = $lbl; Detail = $v; Bad = -not (Test-HomeUrlOk $v) }
        }
        foreach ($sub in 'RestoreOnStartupURLs', 'ExtensionInstallForcelist') {
            $sk = "$k\$sub"
            if (-not (Test-Path -LiteralPath $sk)) { continue }
            $sp = $null; try { $sp = Get-ItemProperty -LiteralPath $sk -ErrorAction Stop } catch { continue }
            foreach ($pp in @($sp.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' })) {
                $v = "$($pp.Value)"
                if ($sub -eq 'RestoreOnStartupURLs') {
                    $out += @{ Key = $sk; Value = $pp.Name; Label = 'Page imposée au démarrage'; Detail = $v; Bad = -not (Test-HomeUrlOk $v) }
                } else {
                    $id = ($v -split ';')[0].Trim(); $upd = (($v -split ';', 2) + @(''))[1].Trim()
                    $nm = "$($ExtNames[$id])"
                    $official = (-not $upd) -or $upd -match '(?i)^https://(clients2\.google\.com|edge\.microsoft\.com)/'
                    $bad = (-not $official) -or ($nm -notmatch $script:ExtTrusted)
                    $out += @{ Key = $sk; Value = $pp.Name; Label = 'Extension imposée (impossible à retirer)'; Detail = $(if ($nm) { "$nm ($id)" } else { "extension inconnue $id" }) + $(if (-not $official) { ' · téléchargée hors du magasin officiel' } else { '' }); Bad = $bad }
                }
            }
        }
    }
    return $out
}

# Analyse complète : une liste d'éléments pour la fenêtre (et le diagnostic)
# Type : notif (cochable), pol (cochable), home (info), ext (info) ; Bad = suspect
function Get-BrowserReportList {
    $items = New-Object System.Collections.ArrayList
    $users = @(Get-UserProfiles)
    $multi = $users.Count -gt 1
    $domain = $false; try { $domain = [bool](Get-CimStatic Win32_ComputerSystem).PartOfDomain } catch {}
    $firefox = $false
    foreach ($def in $script:BrowserDefs) {
        $extNames = @{}
        $exe = ''
        foreach ($u in $users) {
            $uname = Split-Path $u -Leaf
            $dataDir = Join-Path $u $def.Data
            $profiles = @(Get-ChromiumProfiles $dataDir)
            if (-not $profiles.Count) { continue }
            if (-not $exe) { $exe = Get-BrowserExe $def $u }
            foreach ($pr in $profiles) {
                $where = @($def.Name, $(if ($pr.Name -and @($profiles).Count -gt 1) { "profil « $($pr.Name) »" }), $(if ($multi) { "compte $uname" })) | Where-Object { $_ }
                $whereTxt = $where -join ' · '
                $prefFile = Join-Path $pr.Dir 'Preferences'
                $pref = Read-JsonFile $prefFile
                if (-not $pref) { continue }
                $sec = Read-JsonFile (Join-Path $pr.Dir 'Secure Preferences')
                # Notifications autorisées
                $np = [string[]]@('profile', 'content_settings', 'exceptions', 'notifications')
                foreach ($o in @([AeroxJson]::Keys($pref, $np))) {
                    if ("$([AeroxJson]::Get($pref, [string[]]($np + @($o, 'setting'))))" -ne '1') { continue }
                    if ($o -notmatch '^(?i)https?://') { continue }
                    $h = Get-UrlHost $o
                    $kind = if ($h -match $script:NotifOk) { 'ok' } elseif ($h -match $script:NotifBad) { 'bad' } else { 'unknown' }
                    [void]$items.Add(@{ Type = 'notif'; Browser = $def.Key; Where = $whereTxt; Label = $h; Kind = $kind; Bad = ($kind -ne 'ok'); Check = ($kind -ne 'ok'); Proc = $def.Proc
                                        Fix = "notif|$($def.Key)|$prefFile|$o"; Detail = $(switch ($kind) { 'bad' { "Typique des fausses alertes et des pubs" } 'unknown' { "Site inconnu : à bloquer si tu ne le connais pas" } default { "Site connu" } }) })
                }
                # Page d'accueil, pages au démarrage, moteur de recherche
                $hm = @()
                if ("$(Get-JsonValue $pref @('homepage_is_newtabpage'))" -eq 'false') { $hp = Get-JsonValue $pref @('homepage'); if ($hp) { $hm += @{ L = "Page d'accueil"; U = $hp } } }
                if ("$(Get-JsonValue $pref @('session', 'restore_on_startup'))" -eq '4') { foreach ($s in @([AeroxJson]::Items($pref, [string[]]@('session', 'startup_urls')))) { $hm += @{ L = 'Au démarrage'; U = $s } } }
                $su = Get-JsonValue $pref @('default_search_provider_data', 'template_url_data', 'url')
                $sn = Get-JsonValue $pref @('default_search_provider_data', 'template_url_data', 'short_name')
                if ($su) { $hm += @{ L = 'Recherche'; U = $su; N = $sn } }
                foreach ($x in $hm) {
                    $ok = Test-HomeUrlOk $x.U
                    $shown = if ($x.N -and $ok) { $x.N } else { Get-UrlHost $x.U }
                    if (-not $shown) { $shown = $x.U }
                    [void]$items.Add(@{ Type = 'home'; Browser = $def.Key; Where = $whereTxt; Label = "$($x.L) : $shown"; Bad = -not $ok; Exe = $exe; Page = "$($def.Scheme)://settings"; Prof = $(if ((Split-Path $pr.Dir -Leaf) -match '^(Default|Profile \d+)$') { Split-Path $pr.Dir -Leaf } else { '' })
                                        Detail = $(if ($ok) { 'Normal' } else { "Pas un site habituel : si tu ne l'as pas choisi toi-même, c'est un pirate de navigateur. Change-le dans les paramètres du navigateur." }) })
                }
                # Extensions installées
                $extDir = Join-Path $pr.Dir 'Extensions'
                $ids = @()
                foreach ($j in @($pref, $sec)) { if ($j) { $ids += @([AeroxJson]::Keys($j, [string[]]@('extensions', 'settings'))) } }
                foreach ($id in @($ids | Select-Object -Unique)) {
                    $loc = ''; $path = ''; $dis = ''
                    foreach ($j in @($sec, $pref)) {
                        if (-not $j) { continue }
                        if (-not $loc) { $loc = "$(Get-JsonValue $j @('extensions', 'settings', $id, 'location'))" }
                        if (-not $path) { $path = "$(Get-JsonValue $j @('extensions', 'settings', $id, 'path'))" }
                        if (-not $dis) { $dis = "$(Get-JsonValue $j @('extensions', 'settings', $id, 'disable_reasons'))" }
                    }
                    if ($loc -in '5', '10', '') { continue }   # composants internes du navigateur
                    $dir = ''
                    if ($path -match '^[A-Za-z]:\\') { $dir = $path }
                    elseif (Test-Path -LiteralPath (Join-Path $extDir $id)) {
                        $dir = @(Get-ChildItem -LiteralPath (Join-Path $extDir $id) -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | ForEach-Object { $_.FullName })[0]
                    }
                    if (-not $dir) { continue }
                    $mi = Get-ExtManifestInfo $dir
                    if (-not $mi) { continue }
                    $nm = if ($mi.Name) { $mi.Name } else { $id }
                    $extNames[$id] = $nm
                    $flags = @()
                    if ($loc -in '7', '9') { $flags += 'imposée par un réglage' }
                    elseif ($loc -in '2', '3', '6') { $flags += 'installée par un autre logiciel' }
                    elseif ($loc -in '4', '8') { $flags += 'installée à la main, hors magasin' }
                    if ($mi.Hijack) { $flags += "change la page d'accueil, le nouvel onglet ou la recherche" }
                    $off = ($dis -and $dis -ne '[]' -and $dis -ne '0')
                    $bad = (($loc -in '4', '7', '8', '9') -or $mi.Hijack) -and ($nm -notmatch $script:ExtTrusted)
                    [void]$items.Add(@{ Type = 'ext'; Browser = $def.Key; Where = $whereTxt; Label = $nm + $(if ($off) { ' (désactivée)' } else { '' }); Bad = $bad; Exe = $exe; Page = $(if ($def.Scheme -eq 'opera') { 'opera://extensions' } elseif ($id -match '^[a-p]{32}$') { "$($def.Scheme)://extensions/?id=$id" } else { "$($def.Scheme)://extensions" }); Prof = $(if ((Split-Path $pr.Dir -Leaf) -match '^(Default|Profile \d+)$') { Split-Path $pr.Dir -Leaf } else { '' })
                                        Detail = $(if ($flags.Count) { ($flags -join ' · ') } else { 'Installée depuis le magasin' }) })
                }
            }
        }
        foreach ($p in @(Get-BrowserPolicies $def $extNames)) {
            [void]$items.Add(@{ Type = 'pol'; Browser = $def.Key; Where = $def.Name; Label = $p.Label; Detail = $p.Detail; Bad = $p.Bad; Check = ($p.Bad -and -not $domain); Locked = $domain
                                Fix = "pol|$($p.Key)|$($p.Value)" })
        }
    }
    foreach ($u in $users) { if (Test-Path -LiteralPath (Join-Path $u 'AppData\Roaming\Mozilla\Firefox\Profiles')) { $firefox = $true } }
    if ($firefox) {
        $fx = ''; foreach ($r in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) { if ($r -and (Test-Path -LiteralPath (Join-Path $r 'Mozilla Firefox\firefox.exe'))) { $fx = Join-Path $r 'Mozilla Firefox\firefox.exe'; break } }
        [void]$items.Add(@{ Type = 'firefox'; Browser = 'firefox'; Where = 'Firefox'; Label = 'Firefox : à vérifier toi-même'; Bad = $false; Exe = $fx; Page = 'about:preferences#privacy'
                            Detail = "Paramètres > Vie privée et sécurité > Permissions > Notifications « Paramètres… » : supprime les sites que tu ne connais pas. Puis Modules complémentaires (Ctrl+Maj+A) : retire ce que tu n'as pas installé." })
    }
    return $items
}

function Get-BrowserReport {
    Step "Analyse des navigateurs : notifications, extensions, page d'accueil et réglages imposés"
    $sync.BrowserReport = $null
    $items = @(Get-BrowserReportList)
    $sync.BrowserReport = @{ Items = $items; Domain = [bool](@($items | Where-Object { $_.Locked }).Count) }
    Log ("   ✔ {0} site(s) autorisé(s) à envoyer des notifications, dont {1} suspect(s) ou inconnu(s) · {2} extension(s), dont {3} à vérifier · {4} réglage(s) imposé(s)" -f `
        @($items | Where-Object { $_.Type -eq 'notif' }).Count, @($items | Where-Object { $_.Type -eq 'notif' -and $_.Bad }).Count,
        @($items | Where-Object { $_.Type -eq 'ext' }).Count, @($items | Where-Object { $_.Type -eq 'ext' -and $_.Bad }).Count, @($items | Where-Object { $_.Type -eq 'pol' }).Count)
}

function Test-RegBackupSafe([string]$Path) {
    try { $txt = [IO.File]::ReadAllText($Path) } catch { return $false }
    $keys = 0
    foreach ($l in ($txt -split "`r?`n")) {
        $t = $l.Trim()
        if ($t -notlike '[[]*') { continue }
        $keys++
        if ($t -notmatch '^\[HKEY_(LOCAL_MACHINE|USERS\\S-1-5-21-[\d-]+)\\SOFTWARE\\Policies\\(Google\\Chrome|Microsoft\\Edge|BraveSoftware\\Brave)(\\[^\]\\]+)*\]$' -or $t -match '\\\.+(\\|\])') { return $false }
    }
    return ($keys -gt 0 -and $txt -match '^\W*Windows Registry Editor Version 5\.00')
}
# Remet une sauvegarde de réglages imposés (annulation depuis l'historique) : uniquement nos propres sauvegardes
function Restore-RegBackup([string]$File) {
    $root = [IO.Path]::GetFullPath((Get-SecureDir 'sauvegardes')) + '\'
    $old = [IO.Path]::GetFullPath((Join-Path $AppInfo.OldLogDir 'sauvegardes')) + '\'
    $full = [IO.Path]::GetFullPath($File)
    if ($full.StartsWith($old, [StringComparison]::OrdinalIgnoreCase)) { throw "Cette sauvegarde vient d'une ancienne version d'AEROX, rangée dans un dossier modifiable sans droits admin : elle n'est pas remise, par sécurité. Pour retirer ces réglages, relance « Pubs et fausses alertes de virus » (onglet Réparation)." }
    if (-not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or $full -notmatch '(?i)\.reg$' -or -not (Test-Path -LiteralPath $full) -or -not [AeroxSafeDelete]::IsDirectPath($full)) { throw "Sauvegarde introuvable : $File" }
    # Le dossier des sauvegardes est modifiable sans droits admin : on vérifie que le fichier ne touche QUE les réglages
    # imposés des navigateurs (ceux qu'AEROX a sauvegardés), sinon il n'est pas importé
    if (-not (Test-RegBackupSafe $full)) { throw "Cette sauvegarde a été modifiée et touche d'autres réglages de Windows que ceux des navigateurs : elle n'est pas remise, par sécurité." }
    $p = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\reg.exe') -ArgumentList @('import', ('"{0}"' -f $full)) -Wait -PassThru -WindowStyle Hidden
    if ($p.ExitCode -ne 0) { throw "La sauvegarde n'a pas pu être remise (code $($p.ExitCode))." }
    Log "   ✔ Réglages du navigateur remis comme avant"
}

# Bloque les notifications choisies et retire les réglages imposés choisis
# Items : "notif|navigateur|fichier Preferences|origine" ou "pol|clé de registre|valeur"
function Repair-BrowserItems([string[]]$Items) {
    Step "Nettoyage des navigateurs"
    $notifs = @($Items | Where-Object { $_ -like 'notif|*' })
    $pols = @($Items | Where-Object { $_ -like 'pol|*' })
    $bkDir = Join-Path $AppInfo.LogDir 'sauvegardes\navigateurs'     # copies des réglages perso (jamais remises en administrateur)
    New-Item -ItemType Directory -Force -Path $bkDir -ErrorAction SilentlyContinue | Out-Null
    $regDir = Get-SecureDir 'sauvegardes\navigateurs'                  # sauvegardes du registre : dossier protégé
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $blocked = 0
    if ($notifs.Count) {
        # Le navigateur réécrit ses réglages en se fermant : il doit être fermé AVANT la modification
        $procs = @($notifs | ForEach-Object { $k = ($_ -split '\|')[1]; ($script:BrowserDefs | Where-Object { $_.Key -eq $k } | Select-Object -First 1).Proc } | Where-Object { $_ } | Select-Object -Unique)
        foreach ($pn in $procs) { Stop-Browser $pn }
        $still = @($procs | Where-Object { Get-Process -Name $_ -ErrorAction SilentlyContinue })
        if ($still.Count) {
            Add-TaskError -Title "Le navigateur n'a pas pu être fermé" -Cause ("Toujours ouvert : {0}." -f ($still -join ', ')) -Effect "Les notifications ne sont pas bloquées (le navigateur annulerait la modification en se fermant)." `
                -Steps @("Ferme complètement le navigateur (y compris l'icône près de l'horloge s'il y en a une).", "Relance « Arnaques du navigateur ».")
            $notifs = @()
        }
        $byFile = @{}
        foreach ($n in $notifs) {
            $f = $n -split '\|', 4
            if ($f.Count -lt 4 -or $f[2] -notmatch '\\Preferences$' -or -not (Test-Path -LiteralPath $f[2])) { continue }
            if (-not $byFile.ContainsKey($f[2])) { $byFile[$f[2]] = @{ Browser = $f[1]; Origins = New-Object System.Collections.ArrayList } }
            [void]$byFile[$f[2]].Origins.Add($f[3])
        }
        $i = 0
        foreach ($file in $byFile.Keys) {
            $i++
            $g = $byFile[$file]
            if (-not [AeroxSafeDelete]::IsDirectPath($file)) { Log "   ⚠ Réglages ignorés (lien vers un autre endroit) : $file"; continue }
            $json = Read-JsonFile $file
            if (-not $json -or -not [AeroxJson]::Valid($json)) { Log "   ⚠ Réglages illisibles, rien n'est modifié : $file"; continue }
            $new = $json; $n = 0
            foreach ($o in $g.Origins) {
                $r = [AeroxJson]::Replace($new, [string[]]@('profile', 'content_settings', 'exceptions', 'notifications', $o, 'setting'), '2')
                if ($null -ne $r) { $new = $r; $n++; Log ("   ✔ Notifications bloquées : {0}" -f (Get-UrlHost $o)) }
            }
            if (-not $n) { continue }
            if (-not [AeroxJson]::Valid($new)) { Log "   ⚠ Modification annulée (le fichier de réglages aurait été abîmé) : $file"; continue }
            try {
                $bk = Join-Path $bkDir ("{0}_{1}_{2}_Preferences.json" -f $g.Browser, $stamp, $i)
                Copy-Item -LiteralPath $file -Destination $bk -Force -ErrorAction Stop
                # Écrit à côté puis remplace d'un coup : jamais de fichier à moitié écrit, même en cas de coupure
                $tmp = "$file.aerox-tmp"
                [IO.File]::WriteAllText($tmp, $new, (New-Object System.Text.UTF8Encoding($false)))
                [IO.File]::Replace($tmp, $file, [NullString]::Value)   # $null deviendrait "" (refusé)
                # Relecture : en cas de souci, on remet la sauvegarde
                if (-not [AeroxJson]::Valid((Read-JsonFile $file))) { Copy-Item -LiteralPath $bk -Destination $file -Force; Log "   ⚠ Écriture ratée, réglages remis comme avant : $file"; continue }
                $blocked += $n
            } catch {
                try { Remove-Item -LiteralPath "$file.aerox-tmp" -Force -ErrorAction SilentlyContinue } catch {}
                Log ("   ⚠ Impossible de modifier les réglages du navigateur : {0}" -f $_.Exception.Message)
            }
        }
        if ($blocked) { Add-Change -Kind 'info' -Title ("Navigateurs : notifications bloquées pour {0} site(s)" -f $blocked) -Detail "Sauvegarde des réglages : $bkDir" }
    }
    $removed = 0
    if ($pols.Count) {
        $byKey = [ordered]@{}
        foreach ($p in $pols) { $f = $p -split '\|', 3; if ($f.Count -eq 3) { if (-not $byKey.Contains($f[1])) { $byKey[$f[1]] = New-Object System.Collections.ArrayList }; [void]$byKey[$f[1]].Add($f[2]) } }
        $i = 0
        foreach ($k in $byKey.Keys) {
            $i++
            if ($k -notmatch '^Registry::HKEY_(LOCAL_MACHINE|USERS\\S-1-5-21-[\d-]+)\\SOFTWARE\\Policies\\(Google\\Chrome|Microsoft\\Edge|BraveSoftware\\Brave)(\\(RestoreOnStartupURLs|ExtensionInstallForcelist))?$') { continue }
            $regPath = $k -replace '^Registry::', ''
            $bk = Join-Path $regDir ("reglages_imposes_{0}_{1}.reg" -f $stamp, $i)
            $ex = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\reg.exe') -ArgumentList @('export', ('"{0}"' -f $regPath), ('"{0}"' -f $bk), '/y') -Wait -PassThru -WindowStyle Hidden
            if ($ex.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $bk)) { Log "   ⚠ Sauvegarde impossible, rien n'est retiré : $regPath"; continue }
            $done = @()
            foreach ($v in $byKey[$k]) {
                $names = @($v)
                # Moteur de recherche imposé : on retire tout le groupe de réglages qui va avec
                if ($v -eq 'DefaultSearchProviderSearchURL') { try { $names = @((Get-Item -LiteralPath $k -ErrorAction Stop).GetValueNames() | Where-Object { $_ -like 'DefaultSearchProvider*' }) } catch {} }
                foreach ($nm in $names) {
                    try { Remove-ItemProperty -LiteralPath $k -Name $nm -ErrorAction Stop; $done += $nm } catch {}
                }
            }
            if ($done.Count) {
                $removed += $done.Count
                Log ("   ✔ Réglage(s) imposé(s) retiré(s) : {0}" -f ($done -join ', '))
                Add-Change -Title "Navigateur : réglages imposés retirés" -Detail ("{0} : {1}" -f $regPath, ($done -join ', ')) -Undo ("Restore-RegBackup '{0}'" -f ($bk -replace "'", "''"))
            }
        }
        if ($removed) {
            # Une stratégie de groupe locale peut les remettre : on prévient
            foreach ($pol in @("$env:SystemRoot\System32\GroupPolicy\Machine\Registry.pol", "$env:SystemRoot\System32\GroupPolicy\User\Registry.pol")) {
                try { if ((Test-Path -LiteralPath $pol) -and ([Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($pol)) -match '(?i)Policies\\(Google\\Chrome|Microsoft\\Edge|BraveSoftware)')) {
                    Log "   ⚠ Une « stratégie de groupe » de Windows impose aussi des réglages au navigateur : ils peuvent revenir. Si c'est le cas, fais une analyse avec Malwarebytes (gratuit)."
                    break } } catch {}
            }
        }
    }
    if ($blocked -or $removed) { Log "✅ C'est fait. Rouvre ton navigateur : les fausses alertes ne s'affichent plus. Pense aussi à retirer les extensions que tu ne connais pas." }
    else { Log "• Rien n'a été modifié." }
}

# Diagnostic : notifications de pub, extensions qui détournent le navigateur, réglages imposés
function Test-Browsers {
    $items = @(Get-BrowserReportList)
    $n = @($items | Where-Object { $_.Type -eq 'notif' -and $_.Bad })
    $p = @($items | Where-Object { $_.Type -eq 'pol' -and $_.Bad -and -not $_.Locked })
    $e = @($items | Where-Object { ($_.Type -eq 'ext' -or $_.Type -eq 'home') -and $_.Bad })
    if ($n.Count + $p.Count + $e.Count) {
        $parts = @()
        if ($n.Count) { $parts += "$($n.Count) site(s) peuvent t'envoyer des notifications" }
        if ($p.Count) { $parts += "$($p.Count) réglage(s) imposé(s) au navigateur" }
        if ($e.Count) { $parts += "$($e.Count) extension(s) ou page(s) d'accueil suspecte(s)" }
        Add-Issue -Id 'browser' -Sev 'warn' -Title "Ton navigateur est peut-être détourné par des pubs" -Detail ($parts -join ' · ') `
            -Cause "Un site a obtenu le droit d'envoyer des notifications (« clique sur Autoriser pour continuer »), ou un logiciel a changé les réglages du navigateur." `
            -Effect "Fausses alertes de virus en bas de l'écran, pubs, redirections vers des sites d'arnaque." `
            -FixLabel "Voir et nettoyer" -UiFix 'browser'
    } else { Add-Ok "Navigateurs : pas de notifications de pub ni de réglage suspect" }
}

# =====================================================================
#  BILAN AVANT / APRÈS : mesures simples et vérifiables de l'état du PC
# =====================================================================
# Temps du dernier démarrage complet mesuré par Windows lui-même (journal « Diagnostics-Performance », événement 100)
# Lecture du journal de Windows qui ne bloque jamais un diagnostic (journal absent, filtre refusé…) : liste vide en cas d'erreur
function Get-EventsSafe([hashtable]$Filter, [int]$Max = 0) {
    try { if ($Max -gt 0) { return @(Get-WinEvent -FilterHashtable $Filter -MaxEvents $Max -ErrorAction Stop) } else { return @(Get-WinEvent -FilterHashtable $Filter -ErrorAction Stop) } } catch { return @() }
}
# Champs nommés d'un événement Windows (EventData) : @{ BootTime = '...'; FriendlyName = '...' }
function Get-EventFields($E) {
    $h = @{}
    try { foreach ($d in @(([xml]$E.ToXml()).Event.EventData.Data)) { if ($d.Name) { $h[$d.Name] = "$($d.'#text')" } } } catch {}
    return $h
}
function Get-LastBootTime {
    try {
        $e = Get-WinEvent -LogName 'Microsoft-Windows-Diagnostics-Performance/Operational' -FilterXPath '*[System[EventID=100]]' -MaxEvents 1 -ErrorAction Stop
        $x = [xml]$e.ToXml()
        $ms = ($x.Event.EventData.Data | Where-Object { $_.Name -eq 'BootTime' } | Select-Object -First 1).'#text'
        if ($ms -and [int64]$ms -gt 0 -and [int64]$ms -lt 1800000) { return @{ Sec = [math]::Round([double]$ms / 1000); Date = $e.TimeCreated } }
    } catch {}
    return $null
}
function Get-PcSnapshot {
    $s = @{ Date = (Get-Date).ToString('s') }
    try { $b = Get-LastBootTime; if ($b) { $s.BootSec = $b.Sec; $s.BootDate = $b.Date.ToString('s') } } catch {}
    try { $s.Startup = @(Get-StartupEntries | Where-Object { $_.Enabled }).Count } catch {}
    try { $os = Get-CimInstance Win32_OperatingSystem; $s.RamUsed = [double]($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) * 1KB } catch {}
    try { $s.Procs = @(Get-Process -ErrorAction SilentlyContinue).Count } catch {}
    try { $d = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"; $s.Free = [double]$d.FreeSpace } catch {}
    # Les autres disques aussi (D:, E:…), pour voir le gain du nettoyage partout
    try { $s.Drives = @{}; foreach ($o in @(Get-DriveList | Where-Object { $_.Id -ne $env:SystemDrive })) { $s.Drives[$o.Id] = $o.Free } } catch {}
    return $s
}

# =====================================================================
#  PLACE SUR LE DISQUE : ce que Windows garde pour lui, OneDrive, doublons, jeux et logiciels oubliés
# =====================================================================
# Dernière utilisation d'un programme : Windows note chaque lancement dans C:\Windows\Prefetch (NOM.EXE-XXXX.pf)
function Get-PrefetchMap {
    if ($null -ne $script:PrefetchMap) { return $script:PrefetchMap }
    $m = @{}
    try {
        foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $env:SystemRoot 'Prefetch') -Filter '*.pf' -File -ErrorAction Stop)) {
            $exe = ($f.Name -replace '-[0-9A-F]{8}\.pf$', '').ToUpperInvariant()
            if (-not $m.ContainsKey($exe) -or $m[$exe] -lt $f.LastWriteTime) { $m[$exe] = $f.LastWriteTime }
        }
    } catch {}
    $script:PrefetchMap = $m
    return $m
}
# Date du dernier lancement d'un des programmes d'un dossier (null si inconnue)
function Get-FolderLastUsed([string]$Dir) {
    if (-not $Dir -or -not (Test-Path -LiteralPath $Dir)) { return $null }
    if ($Dir -match '(?i)^[a-z]:\\(windows|program files( \(x86\))?)?\\?$') { return $null }
    $m = Get-PrefetchMap
    if (-not $m.Count) { return $null }
    $best = $null; $n = 0
    $dirs = @($Dir) + @(Get-ChildItem -LiteralPath $Dir -Directory -ErrorAction SilentlyContinue | Select-Object -First 40 | ForEach-Object { $_.FullName })
    foreach ($d in $dirs) {
        foreach ($e in @(Get-ChildItem -LiteralPath $d -Filter '*.exe' -File -ErrorAction SilentlyContinue)) {
            if (++$n -gt 300) { break }
            $k = $e.Name.ToUpperInvariant()
            if ($k.Length -gt 29) { $k = $k.Substring(0, 29) }   # Windows coupe le nom à 29 caractères
            if ($m.ContainsKey($k) -and ($null -eq $best -or $m[$k] -gt $best)) { $best = $m[$k] }
        }
    }
    return $best
}

# Ce que Windows garde pour lui sur le disque système (surtout utile sur les petits disques)
# Chaque élément : Id, T (titre), D (explication), S (octets gagnés, estimation si Est), Check (coché d'office), Arg
function Get-WindowsSpaceItems {
    $items = New-Object System.Collections.ArrayList
    $sd = $env:SystemDrive
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$sd'" -ErrorAction SilentlyContinue
    if (-not $disk) { return @() }
    $size = [double]$disk.Size; $free = [double]$disk.FreeSpace
    $small = ($size -le 300GB) -or ($free / $size -lt 0.15)
    $laptop = $false
    try { $laptop = [bool](@((Get-CimStatic Win32_SystemEnclosure -Quiet).ChassisTypes | Where-Object { $_ -in 8, 9, 10, 11, 14, 30, 31, 32 }).Count) } catch {}
    # 1. Stockage réservé aux mises à jour (~7 Go)
    try {
        $st = "$((Get-WindowsReservedStorageState -ErrorAction Stop).ReservedStorageState)"
        if ($st -match '(?i)enabled' -and $small) {
            [void]$items.Add(@{ Id = 'reserved'; T = 'Stockage réservé par Windows'; S = 7GB; Est = $true; Check = $true
                                D = "Windows bloque environ 7 Go pour ses futures mises à jour. Sur un petit disque, mieux vaut récupérer cette place : les mises à jour continuent de s'installer normalement. Annulable." })
        }
    } catch {}
    if ($sync.Cancel) { return $items.ToArray() }
    # 2. Fichier de veille prolongée : réduit au minimum (le démarrage rapide reste)
    try {
        $hf = New-Object IO.FileInfo (Join-Path $sd 'hiberfil.sys')
        $ram = [double](Get-CimStatic Win32_ComputerSystem -Quiet).TotalPhysicalMemory
        if ($hf.Exists -and $ram -gt 0 -and $hf.Length -gt 0.3 * $ram) {
            $gain = [double]$hf.Length - 0.2 * $ram
            if ($gain -ge 1GB) {
                [void]$items.Add(@{ Id = 'hiber'; T = 'Fichier de veille prolongée (hiberfil.sys)'; S = $gain; Est = $true; Check = (-not $laptop)
                                    D = $(if ($laptop) { "Réduit au strict nécessaire : le démarrage rapide de Windows reste, mais l'option « Veille prolongée » disparaît du menu. Garde-le si tu l'utilises sur ce portable. Annulable." } else { "Réduit au strict nécessaire : le démarrage rapide de Windows reste. Sur un PC fixe, la « veille prolongée » ne sert presque jamais. Annulable." }) })
            }
        }
    } catch {}
    # 3. Points de restauration : place limitée à 5 % du disque (les plus récents sont gardés)
    try {
        $vol = Get-CimInstance Win32_Volume -Filter ("DriveLetter='{0}'" -f $sd) -ErrorAction Stop
        $ss = @(Get-CimInstance Win32_ShadowStorage -ErrorAction Stop | Where-Object { "$($_.Volume.DeviceID)" -eq "$($vol.DeviceID)" }) | Select-Object -First 1
        if ($ss) {
            $target = 0.05 * $size
            $used = [double]$ss.UsedSpace; $max = [double]$ss.MaxSpace
            if ($used - $target -ge 1GB -and $max -gt $target * 1.1) {
                $prev = if ($max -ge 1e18) { 'UNBOUNDED' } else { "{0}MB" -f [math]::Floor($max / 1MB) }
                [void]$items.Add(@{ Id = 'restore'; T = 'Points de restauration'; S = ($used - $target); Est = $true; Check = $true; Arg = $prev
                                    D = ("Ils prennent {0}. On limite leur place à 5 % du disque ({1}) : les plus anciens sont supprimés, les plus récents sont gardés et Windows continue d'en créer. Annulable." -f (Format-Size $used), (Format-Size $target)) })
            }
        }
    } catch {}
    if ($sync.Cancel) { return $items.ToArray() }
    # 4. Anciennes versions de pilotes gardées par Windows (jamais celle utilisée)
    try {
        $used = @{}; foreach ($d in @(Get-CimInstance Win32_PnPSignedDriver -ErrorAction Stop)) { if ($d.InfName) { $used["$($d.InfName)".ToLower()] = $true } }
        $drv = @(Get-WindowsDriver -Online -ErrorAction Stop)
        $old = New-Object System.Collections.ArrayList
        foreach ($g in @($drv | Group-Object { "{0}|{1}|{2}" -f [IO.Path]::GetFileName("$($_.OriginalFileName)").ToLower(), $_.ProviderName, $_.ClassName })) {
            if ($g.Count -lt 2) { continue }
            $sorted = @($g.Group | Sort-Object @{ Expression = { try { [version]"$($_.Version)" } catch { [version]'0.0' } } }, @{ Expression = { $_.Date } } -Descending)
            foreach ($x in @($sorted | Select-Object -Skip 1)) {
                $inf = "$($x.Driver)".ToLower()
                if ($inf -notmatch '^oem\d+\.inf$' -or $used[$inf]) { continue }
                $dir = Split-Path "$($x.OriginalFileName)" -Parent
                [void]$old.Add(@{ Inf = $inf; Name = ("{0} {1}" -f $x.ProviderName, $x.ClassName).Trim(); Version = "$($x.Version)"; Size = (Get-FolderSize $dir) })
            }
        }
        $tot = [double](($old | ForEach-Object { $_.Size } | Measure-Object -Sum).Sum)
        if ($old.Count -and $tot -ge 300MB) {
            $names = (@($old | Sort-Object { - $_.Size } | Select-Object -First 4 | ForEach-Object { "$($_.Name) $($_.Version)" }) -join ' · ')
            [void]$items.Add(@{ Id = 'drivers'; T = "Anciennes versions de pilotes ($($old.Count))"; S = $tot; Est = $false; Check = $true; Arg = (@($old | ForEach-Object { $_.Inf }) -join ',')
                                D = "Windows garde les anciennes versions des pilotes après chaque mise à jour (surtout la carte graphique) : $names. Les pilotes utilisés ne sont jamais touchés. Définitif, mais ces versions ne servent plus." })
        }
    } catch {}
    # 5. Compression des fichiers de Windows (outil officiel CompactOS), seulement sur les petits disques
    if ($small -and -not $sync.Cancel) {
        try {
            $q = (& compact.exe /compactos:query 2>&1 | Out-String)
            if ($LASTEXITCODE -eq 0 -and $q -and $q -notmatch '(?i)\b(is in the compact state|est dans l.état compact|est à l.état compact|ist im komprimierten)') {
                [void]$items.Add(@{ Id = 'compact'; T = 'Compression de Windows (CompactOS)'; S = 2.5GB; Est = $true; Check = $false
                                    D = "Outil officiel de Microsoft prévu pour les petits disques : il compresse les fichiers de Windows, rien n'est supprimé. Gain de 2 à 4 Go. Prend 10 à 20 minutes ; Windows reste un tout petit peu plus sollicité ensuite (sans différence visible sur un PC récent). Annulable." })
            }
        } catch {}
    }
    return $items.ToArray()
}

# Dossiers OneDrive de la personne devant l'écran
function Get-OneDriveFolders {
    $out = @()
    $root = "$((Get-SessionUser).Hkcu)\Software\Microsoft\OneDrive\Accounts"
    foreach ($k in @(Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue)) {
        try { $f = "$((Get-ItemProperty -LiteralPath $k.PSPath -Name UserFolder -ErrorAction Stop).UserFolder)"; if ($f -and (Test-Path -LiteralPath $f) -and $out -notcontains $f) { $out += $f } } catch {}
    }
    return $out
}

# Jeux Steam et logiciels pas lancés depuis 3 mois (d'après le Prefetch de Windows)
function Get-ForgottenApps([string]$Drive, $ScanLines) {
    $limit = (Get-Date).AddDays(-90)
    $out = New-Object System.Collections.ArrayList
    foreach ($l in @($ScanLines | Where-Object { $_ -match '^\d+\|\d+\|.*\\steamapps\\common\\[^\\]+$' })) {
        $p = $l.Split('|', 3)
        $size = [double]$p[1]
        if ($size -lt 2GB) { continue }
        $lu = Get-FolderLastUsed $p[2]
        if ($null -eq $lu -or $lu -lt $limit) { [void]$out.Add(@{ Kind = 'game'; Name = (Split-Path $p[2] -Leaf); Size = $size; LastUsed = $lu; Path = $p[2] }) }
    }
    try {
        $apps = Get-InstalledApps   # (liste renvoyée d'un bloc : la dérouler avant de filtrer)
        foreach ($a in @($apps | Where-Object { $_.Kind -eq 'win32' -and $_.Size -ge 500MB -and $_.Drive -eq $Drive.ToUpper() })) {
            if ($a.Name -match '(?i)microsoft visual c\+\+|\.net|runtime|driver|pilote|redistributable|steam$|nvidia|amd software|intel|realtek|windows') { continue }
            if (($null -ne $a.LastUsed -and $a.LastUsed -lt $limit) -or ($null -eq $a.LastUsed -and $a.Date -and $a.Date -lt $limit)) {
                [void]$out.Add(@{ Kind = 'app'; Name = $a.Name; Size = $a.Size; LastUsed = $a.LastUsed; Path = $a.Location })
            }
        }
    } catch {}
    return @($out | Sort-Object { - $_.Size })
}

# Libère la place gardée par Windows. Items : 'reserved', 'hiber', 'restore:<taille d'avant>', 'drivers:oem1.inf,oem2.inf', 'compact'
function Invoke-WindowsSpace([string[]]$Items) {
    $before = [double](Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'").FreeSpace
    foreach ($it in $Items) {
        if ($sync.Cancel) { break }
        $id, $arg = $it -split ':', 2
        switch ($id) {
            'reserved' { Set-ReservedStorage 'Disabled' }
            'hiber'    { Set-HiberType 'reduced' }
            'restore'  { Set-RestoreSpace '5%' $arg }
            'drivers'  { Remove-OldDrivers @("$arg" -split ',' | Where-Object { $_ }) }
            'compact'  { Set-CompactOS 'on' }
        }
    }
    $after = [double](Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'").FreeSpace
    if ($after -gt $before) { Log ("✅ Place libérée sur {0} : {1} (il reste {2} de libre)." -f $env:SystemDrive, (Format-Size ($after - $before)), (Format-Size $after)) }
}
function Set-ReservedStorage([string]$State) {
    if ($State -notin 'Enabled', 'Disabled') { throw "État inconnu : $State" }
    Step $(if ($State -eq 'Disabled') { "Stockage réservé par Windows : libération" } else { "Stockage réservé par Windows : réactivation" })
    try {
        Set-WindowsReservedStorageState -State $State -ErrorAction Stop | Out-Null
        Log $(if ($State -eq 'Disabled') { "   ✔ Les ~7 Go réservés par Windows sont libérés." } else { "   ✔ Windows réserve de nouveau de la place pour ses mises à jour." })
        Add-Change -Title $(if ($State -eq 'Disabled') { "Stockage réservé de Windows libéré (~7 Go)" } else { "Stockage réservé de Windows réactivé" }) -Undo ("Set-ReservedStorage '{0}'" -f $(if ($State -eq 'Disabled') { 'Enabled' } else { 'Disabled' }))
    } catch {
        Add-TaskError -Title "Le stockage réservé n'a pas pu être libéré" -Cause "Windows s'en sert en ce moment (une mise à jour est en cours ou attend un redémarrage)." -Effect "Rien n'a changé." `
            -Steps @("Redémarre le PC.", "Laisse Windows Update finir les mises à jour en attente.", "Relance « Ce qui prend de la place ».")
    }
}
function Set-HiberType([string]$Type) {
    if ($Type -notin 'reduced', 'full') { throw "Type inconnu : $Type" }
    Step $(if ($Type -eq 'reduced') { "Fichier de veille prolongée : réduction" } else { "Fichier de veille prolongée : taille complète" })
    $hf = Join-Path $env:SystemDrive 'hiberfil.sys'
    $b = 0.0; try { $b = [double](New-Object IO.FileInfo $hf).Length } catch {}
    $code = Invoke-Native 'powercfg.exe' @('/hibernate', '/type', $Type)
    if ($code -ne 0) { Add-TaskError -Title "Le fichier de veille prolongée n'a pas pu être modifié" -Cause ($script:NativeOutput -join ' ') -Effect "Rien n'a changé."; return }
    $a = 0.0; try { $a = [double](New-Object IO.FileInfo $hf).Length } catch {}
    Log ("   ✔ hiberfil.sys : {0} → {1}" -f (Format-Size $b), (Format-Size $a))
    Add-Change -Title $(if ($Type -eq 'reduced') { "Fichier de veille prolongée réduit (le démarrage rapide reste)" } else { "Fichier de veille prolongée remis en taille complète" }) -Undo ("Set-HiberType '{0}'" -f $(if ($Type -eq 'reduced') { 'full' } else { 'reduced' }))
}
function Set-RestoreSpace([string]$Max, [string]$Previous = '') {
    if ($Max -notmatch '^(\d{1,2}%|\d{3,9}MB|UNBOUNDED)$' -or ($Previous -and $Previous -notmatch '^(\d{1,2}%|\d{3,9}MB|UNBOUNDED)$')) { throw "Taille invalide : $Max" }
    Step "Points de restauration : place maximale $Max"
    $code = Invoke-Native 'vssadmin.exe' @('resize', 'shadowstorage', "/for=$env:SystemDrive", "/on=$env:SystemDrive", "/maxsize=$Max")
    if ($code -ne 0) { Add-TaskError -Title "La place des points de restauration n'a pas pu être changée" -Cause ($script:NativeOutput -join ' ') -Effect "Rien n'a changé."; return }
    Log "   ✔ Les points de restauration les plus récents sont gardés, Windows continue d'en créer."
    if ($Previous) { Add-Change -Title "Place des points de restauration limitée à $Max" -Undo ("Set-RestoreSpace '{0}'" -f $Previous) }
    else { Add-Change -Kind 'info' -Title "Place des points de restauration : $Max" }
}
function Remove-OldDrivers([string[]]$Infs) {
    Step ("Suppression de {0} ancienne(s) version(s) de pilotes" -f @($Infs).Count)
    $inUse = @{}; foreach ($d in @(Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue)) { if ($d.InfName) { $inUse["$($d.InfName)".ToLower()] = $true } }
    $ok = 0
    foreach ($inf in $Infs) {
        $inf = "$inf".ToLower()
        if ($inf -notmatch '^oem\d+\.inf$' -or $inUse[$inf]) { continue }
        # Sans /force : Windows refuse tout seul si le pilote sert encore
        if ((Invoke-Native 'pnputil.exe' @('/delete-driver', $inf) -Quiet) -eq 0) { $ok++ }
    }
    Log ("   ✔ {0} ancienne(s) version(s) supprimée(s)." -f $ok)
    if ($ok) { Add-Change -Kind 'info' -Title ("{0} ancienne(s) version(s) de pilotes supprimée(s)" -f $ok) -Detail "Les pilotes utilisés par le PC n'ont pas été touchés." }
}
function Set-CompactOS([string]$State) {
    if ($State -notin 'on', 'off') { throw "État inconnu : $State" }
    Step $(if ($State -eq 'on') { "Compression des fichiers de Windows (10 à 20 minutes, laisse le PC allumé)" } else { "Décompression des fichiers de Windows (10 à 20 minutes)" })
    $code = Invoke-Native 'compact.exe' @("/compactos:$(if ($State -eq 'on') { 'always' } else { 'never' })") -Quiet
    if ($code -ne 0) { Add-TaskError -Title "La compression de Windows n'a pas pu se faire" -Cause (($script:NativeOutput | Select-Object -Last 3) -join ' ') -Effect "Rien n'a changé."; return }
    Log $(if ($State -eq 'on') { "   ✔ Fichiers de Windows compressés." } else { "   ✔ Fichiers de Windows décompressés." })
    Add-Change -Title $(if ($State -eq 'on') { "Fichiers de Windows compressés (CompactOS)" } else { "Fichiers de Windows décompressés" }) -Undo ("Set-CompactOS '{0}'" -f $(if ($State -eq 'on') { 'off' } else { 'on' }))
}
# OneDrive : les fichiers restent dans le cloud et s'ouvrent quand on clique dessus (téléchargés à ce moment-là)
function Set-OneDriveOnlineOnly([string]$Folder) {
    if (@(Get-OneDriveFolders) -notcontains $Folder) { throw "Ce dossier n'est pas un dossier OneDrive de ce PC : $Folder" }
    # Le dossier OneDrive est indiqué dans le registre de la personne (modifiable sans droits admin) : jamais un dossier
    # de Windows, des programmes, la racine d'un disque, ni un chemin qui passe par un lien
    $full = [IO.Path]::GetFullPath($Folder).TrimEnd('\')
    if ($full -like "$env:SystemRoot*" -or $full -like "$env:ProgramFiles*" -or $full -like "${env:ProgramFiles(x86)}*" -or $full -like "$env:ProgramData*" -or $full -match '^[A-Za-z]:$' -or -not [AeroxSafeDelete]::IsDirectPath($full)) { throw "Ce dossier ne peut pas être un dossier OneDrive : $Folder" }
    # OneDrive doit tourner : c'est lui qui libère la place, et seulement pour les fichiers déjà envoyés en ligne
    if (-not (Get-Process -Name 'OneDrive' -ErrorAction SilentlyContinue)) { throw "OneDrive n'est pas lancé sur ce PC. Ouvre OneDrive, attends qu'il soit à jour (icône du nuage sans flèches), puis recommence." }
    Step "OneDrive : fichiers gardés uniquement en ligne"
    $before = [AeroxFiles]::LocalCloudSize($Folder)
    $c = [AeroxFiles]::SetOnlineOnly($Folder)
    Start-Sleep -Seconds 5
    $after = [AeroxFiles]::LocalCloudSize($Folder)
    Log ("   ✔ {0} libérés pour l'instant (OneDrive continue en arrière-plan). Tes fichiers restent dans OneDrive et s'ouvrent d'un clic." -f (Format-Size ([math]::Max([double]0, $before - $after))))
    if ($c[1]) { Log ("   • {0} élément(s) que tu avais choisi(s) de « toujours conserver sur cet appareil » n'ont pas été touchés." -f $c[1]) }
    Log "   • Un fichier pas encore envoyé dans OneDrive reste sur le PC : OneDrive ne libère que ce qui est déjà en ligne."
    Add-Change -Kind 'info' -Title "OneDrive : fichiers gardés uniquement en ligne" -Detail "Les dossiers que tu avais choisis de garder sur le PC n'ont pas été touchés. Pour en garder un autre (sans Internet) : clic droit dessus > « Toujours conserver sur cet appareil »."
}

# Fichiers en double dans les dossiers perso de la personne devant l'écran (Bureau, Documents, Images, Vidéos, Musique, Téléchargements)
function Get-Duplicates {
    Step "Recherche des fichiers en double (photos, vidéos, documents…)"
    $sync.Dupes = $null
    $roots = @('Desktop', 'Personal', 'My Pictures', 'My Video', 'My Music', 'Downloads' | ForEach-Object { Get-SessionFolder $_ } | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique)
    Log ("   Dossiers : {0}" -f ($roots -join ' · '))
    $lines = [AeroxFiles]::FindDuplicates([string[]]$roots, 1MB, 300)
    if ($sync.Cancel) { return }
    $groups = @{}
    foreach ($l in $lines) {
        $p = $l.Split('|', 5)
        if ($p.Count -ne 5) { continue }
        if (-not $groups.ContainsKey($p[1])) { $groups[$p[1]] = New-Object System.Collections.ArrayList }
        [void]$groups[$p[1]].Add(@{ Size = [double]$p[2]; Date = ([datetime]::new([int64]$p[3], 'Utc')).ToLocalTime(); Path = $p[4] })
    }
    $out = @($groups.Keys | Sort-Object { [int]$_ } | ForEach-Object { , @($groups[$_]) })
    $sync.Dupes = @{ Groups = $out; Roots = $roots }
    $gain = [double](($out | ForEach-Object { $_[0].Size * ($_.Count - 1) } | Measure-Object -Sum).Sum)
    Log ("   ✔ {0} fichier(s) en plusieurs exemplaires, {1} récupérables." -f $out.Count, (Format-Size $gain))
}

# =====================================================================
#  LENTEURS : ce qui fait vraiment ramer le PC (mesure en direct + causes de fond)
# =====================================================================
# Noms parlants des programmes de Windows qui reviennent souvent dans « ce qui consomme »
$script:KnownProcs = @{
    'msmpeng' = @('Antivirus Microsoft Defender', 'transient'); 'mpdefendercoreservice' = @('Antivirus Microsoft Defender', 'transient'); 'nissrv' = @('Antivirus Microsoft Defender', 'transient')
    'searchindexer' = @('Indexation de la recherche Windows', 'transient'); 'searchprotocolhost' = @('Indexation de la recherche Windows', 'transient'); 'searchfilterhost' = @('Indexation de la recherche Windows', 'transient')
    'tiworker' = @('Installation de mises à jour Windows', 'transient'); 'trustedinstaller' = @('Installation de mises à jour Windows', 'transient'); 'mousocoreworker' = @('Windows Update', 'transient')
    'wuaueng' = @('Windows Update', 'transient'); 'usocoreworker' = @('Windows Update', 'transient'); 'compattelrunner' = @('Télémétrie de Windows (vérification de compatibilité)', 'transient')
    'system' = @('Windows (noyau et pilotes)', 'system'); 'memory compression' = @('Compression de la mémoire (la RAM déborde)', 'system'); 'registry' = @('Windows (registre)', 'system')
    'dwm' = @('Affichage de Windows', 'system'); 'explorer' = @('Explorateur Windows (bureau, barre des tâches)', 'system'); 'svchost' = @('Services de Windows', 'system')
    'csrss' = @('Windows', 'system'); 'lsass' = @('Windows (sécurité)', 'system'); 'audiodg' = @('Son de Windows', 'system'); 'sysmain' = @('Préchargement de Windows (SysMain)', 'transient')
    'onedrive' = @('OneDrive (synchronisation)', 'app'); 'chrome' = @('Google Chrome', 'app'); 'msedge' = @('Microsoft Edge', 'app'); 'firefox' = @('Firefox', 'app'); 'opera' = @('Opera', 'app'); 'brave' = @('Brave', 'app')
    'discord' = @('Discord', 'app'); 'steam' = @('Steam', 'app'); 'steamwebhelper' = @('Steam (fenêtre)', 'app'); 'epicgameslauncher' = @('Epic Games Launcher', 'app'); 'teams' = @('Microsoft Teams', 'app'); 'ms-teams' = @('Microsoft Teams', 'app')
}
function Get-ProcFriendly([string]$Name, [int]$ProcId) {
    $k = $Name.ToLower()
    if ($script:KnownProcs.ContainsKey($k)) { return @{ Label = $script:KnownProcs[$k][0]; Kind = $script:KnownProcs[$k][1] } }
    $lbl = $Name
    try { $p = Get-Process -Id $ProcId -ErrorAction Stop; $d = "$($p.Description)".Trim(); if (-not $d) { $d = "$($p.Product)".Trim() }; if ($d -and $d.Length -le 60) { $lbl = $d } } catch {}
    return @{ Label = $lbl; Kind = 'app' }
}
# ---------------------------------------------------------------- Infos BIOS (lues depuis Windows, rien n'est modifié)
# Vitesse prévue d'une barrette d'après sa référence (kits « gaming » : la vitesse XMP/EXPO est écrite dedans).
# 0 = inconnue (référence d'origine ou format pas reconnu) : on ne devine jamais.
function Get-RamRatedSpeed([string]$Part) {
    $p = "$Part".Trim().ToUpperInvariant()
    if (-not $p) { return 0 }
    $ok = { param($v) if ($v -ge 1600 -and $v -le 10000) { $v } else { 0 } }
    # G.Skill : F4-3600C16-8GVKC, F5-6000J3038F16G
    if ($p -match '^F[345]-(\d{4})') { return (& $ok ([int]$matches[1])) }
    # Kingston FURY / HyperX : KF560C36BBEK2-32 (DDR5-6000), KF432C16BB/8 (DDR4-3200), HX436C17PB4/16
    if ($p -match '^(KF|HX)[345](\d{2})C\d{2}') { return (& $ok ([int]$matches[2] * 100)) }
    # Crucial Ballistix / Pro : BL8G32C16U4B, CP16G60C36U5B, CP2K16G56C46U5
    if ($p -match '^(BL|CP)(\dK)?\d+G(\d{2})C\d{2}') { return (& $ok ([int]$matches[3] * 100)) }
    # Corsair : CMK32GX5M2B6000C36, CMW16GX4M2C3200C16, CMH32GX5M2E6000C36
    if ($p -match '^CM[A-Z]\d+GX[345]M\d[A-Z](\d{4})C\d{2}') { return (& $ok ([int]$matches[1])) }
    # TeamGroup / Patriot / ADATA XPG et autres : « 3200C16 », « 6000C30 », « 3600HC18 », « DDR4-3200 »
    if ($p -match '(?<!\d)(2133|2400|2666|2933|3000|3200|3333|3466|3600|3733|3800|4000|4133|4266|4400|4600|4800|5200|5600|6000|6200|6400|6600|6800|7000|7200|7600|8000|8200|8400)(C|HC|CL)\d{2}') { return [int]$matches[1] }
    if ($p -match 'DDR[345]-?(\d{4})') { return (& $ok ([int]$matches[1])) }
    return 0
}
# Barrettes « d'origine » sans profil XMP (PC de marque, portables, Kingston ValueRAM, Crucial standard…)
function Test-JedecPart([string]$Part) {
    return ("$Part".Trim().ToUpperInvariant() -match '^(M4\d\d|M3\d\d|M32|HMA|HMAA|HMCG|HMCT|HMT|MTA|MTC|MT\d|CT\d|KVR|KCP|ACR|AO1P|9905|99U5|TS\d|HP\d|SK\s?HYNIX|RMSA|H5)')
}
# Canal mémoire (A, B…) d'après le nom de l'emplacement donné par la carte mère
function Get-MemChannel([string]$Locator, [string]$Bank) {
    $t = "$Locator $Bank"
    if ($t -match '(?i)channel\s*([A-H])\b') { return $matches[1].ToUpperInvariant() }
    if ($t -match '(?i)channel([A-H])') { return $matches[1].ToUpperInvariant() }
    if ("$Locator" -match '(?i)(?:^|[_\s-])DIMM[_\s-]?([A-H])\d') { return $matches[1].ToUpperInvariant() }
    if ("$Locator".Trim() -match '(?i)^([A-H])\d(?:$|[_\s-])') { return $matches[1].ToUpperInvariant() }
    return ''
}
# XMP / EXPO activé ? Déduit de la vitesse actuelle, de la vitesse prévue par les barrettes et de leur tension.
# Windows ne le dit pas directement : chaque conclusion dit sur quoi elle s'appuie, et « impossible à dire » existe.
function Get-XmpState([string]$Type, [int]$Configured, [int]$Rated, [int]$VoltMv, [bool]$Jedec, [bool]$Laptop, [bool]$Am5 = $false) {
    $jedecMax = switch -Regex ($Type) { '^DDR5|^LPDDR5' { 6400 } '^DDR4|^LPDDR4' { 3200 } '^DDR3' { 1600 } default { 0 } }
    $jedecV = switch -Regex ($Type) { '^DDR5' { 1100 } '^DDR4' { 1200 } '^DDR3' { 1500 } default { 0 } }
    # Vitesse de départ des barrettes « gaming » quand aucun profil n'est activé (au-dessus : réglage à la main ou autre profil)
    $base = switch -Regex ($Type) { '^DDR5' { 4800 } '^DDR4' { 2400 } '^DDR3' { 1333 } default { 0 } }
    $highV = ($jedecV -and $VoltMv -ge ($jedecV + 50))
    $vTxt = if ($VoltMv -ge 500) { " · {0:N2} V" -f ($VoltMv / 1000.0) } else { '' }
    $zen = ($Am5 -and $Type -match '^DDR5')
    $sweet = if ($zen -and $Rated -gt 6050) { " Sur les Ryzen 7000 / 8000 / 9000, la vitesse idéale est en général 6000 MT/s : le contrôleur mémoire suit alors la RAM au même rythme (ratio 1:1). Au-delà, la carte mère le passe souvent en ratio 1:2 et la mémoire peut finir moins rapide. Le plus simple : activer l'EXPO, puis régler la vitesse sur 6000 MT/s." } else { '' }
    $gain = " L'activer donne en général plus de FPS dans les jeux limités par le processeur. C'est un réglage prévu par le fabricant des barrettes ; si le PC devient instable (écrans bleus), il suffit de revenir au réglage d'avant."
    if ($Type -match '^LP') { return @{ State = 'soldered'; Text = "Mémoire soudée au PC (LP$($Type.Substring(2))) : sa vitesse est fixée par le fabricant, il n'y a pas de profil XMP/EXPO à régler." } }
    if (-not $Configured) { return @{ State = 'unknown'; Text = "Windows ne donne pas la vitesse de la mémoire sur ce PC." } }
    if ($Rated -gt 0) {
        if ($Configured -ge ($Rated - 50)) {
            $hi = if ($zen -and $Configured -gt 6050) { " Sur un Ryzen 7000 / 8000 / 9000, au-delà de 6000 MT/s la carte mère passe souvent le contrôleur mémoire en ratio 1:2 : 6000 MT/s est souvent aussi rapide, voire plus." } else { '' }
            if ($Rated -gt $jedecMax -or $highV) { return @{ State = 'on'; Text = "Ta RAM tourne à $Configured MT/s, la vitesse prévue par tes barrettes ($Rated MT/s)$vTxt : le profil XMP/EXPO est activé.$hi" } }
            return @{ State = 'ok'; Text = "Ta RAM tourne à $Configured MT/s, la vitesse prévue par tes barrettes$vTxt.$hi" }
        }
        if ($zen -and $Rated -gt 6050 -and [math]::Abs($Configured - 6000) -le 50) { return @{ State = 'ok'; Text = "Ta RAM tourne à $Configured MT/s (barrettes prévues pour $Rated MT/s)$vTxt : c'est la vitesse idéale pour les Ryzen 7000 / 8000 / 9000 (contrôleur mémoire au même rythme que la RAM). Rien à changer." } }
        if ($highV -or $Configured -gt $jedecMax) { return @{ State = 'below'; Text = "Ta RAM tourne à $Configured MT/s alors que tes barrettes sont prévues pour $Rated MT/s$vTxt : un profil est actif mais réglé en dessous de leur vitesse (souvent volontaire pour la stabilité, ou limite du processeur avec 4 barrettes).$sweet" } }
        if ($base -and $Configured -gt ($base + 50)) { return @{ State = 'below'; Text = "Ta RAM tourne à $Configured MT/s alors que tes barrettes sont prévues pour $Rated MT/s$vTxt : soit la vitesse a été réglée à la main plus bas dans le BIOS, soit leur profil XMP/EXPO n'est pas activé. Si ce n'est pas voulu, active le profil.$(if ($sweet) { $sweet } else { $gain })" } }
        return @{ State = 'off'; Text = "Ta RAM tourne à $Configured MT/s alors que tes barrettes sont prévues pour $Rated MT/s : le profil XMP/EXPO n'est pas activé dans le BIOS.$gain$sweet" }
    }
    if ($highV -or ($jedecMax -and $Configured -gt $jedecMax)) { return @{ State = 'on'; Text = "Ta RAM tourne à $Configured MT/s$vTxt, au-dessus de la vitesse standard de la $Type : un profil XMP/EXPO (ou un réglage manuel) est activé." } }
    if ($Jedec -or $Laptop) { return @{ State = 'standard'; Text = "Ta RAM tourne à $Configured MT/s$vTxt : ce sont des barrettes standard (sans profil XMP/EXPO), elles tournent à leur vitesse normale." } }
    return @{ State = 'unknown'; Text = "Ta RAM tourne à $Configured MT/s$vTxt. Windows ne dit pas pour quelle vitesse tes barrettes sont prévues : regarde leur étiquette ou leur fiche produit (ex. « DDR5-6000 », « 3600 MHz »). Si c'est plus que $Configured, active le profil XMP/EXPO dans le BIOS." }
}
# Où trouver un réglage dans le BIOS selon la marque de la carte mère (les menus changent un peu selon la version)
function Get-BiosHowTo([string]$Brand, [string]$What, [bool]$Amd, [bool]$Oem, [string]$RamType = '') {
    $prof = if ($Amd -and $RamType -match 'DDR5') { 'EXPO' } elseif ($Amd) { 'D.O.C.P / A-XMP / XMP' } else { 'XMP' }
    $virt = if ($Amd) { '« SVM Mode »' } else { '« Intel Virtualization Technology » (VT-x)' }
    switch ($What) {
        'xmp' {
            if ($Oem) { return "Sur la plupart des PC de marque et des portables, ce réglage n'existe pas : la mémoire tourne à la vitesse choisie par le fabricant. Certains PC gamer (Alienware, Legion…) l'ont sous « XMP » ou « Memory Overclocking »." }
            switch ($Brand) {
                'ASUS'     { return "ASUS : en mode EZ, réglage « $(if ($Amd -and $RamType -match 'DDR5') { 'EXPO' } elseif ($Amd) { 'D.O.C.P.' } else { 'X.M.P.' }) » (à côté des infos de la mémoire) → profil 1. En mode avancé (F7) : Ai Tweaker > Ai Overclock Tuner." }
                'MSI'      { return "MSI : sur l'écran d'accueil, bouton « $(if ($Amd -and $RamType -match 'DDR5') { 'EXPO' } else { 'XMP' }) » en haut à gauche (à côté de Game Boost) → profil 1. Sinon : OC > Extreme Memory Profile (XMP)." }
                'Gigabyte' { return "Gigabyte / AORUS : en mode Easy, « $(if ($Amd -and $RamType -match 'DDR5') { 'EXPO' } else { 'XMP' }) » → Profile 1. En mode avancé (F2) : Tweaker > Extreme Memory Profile (X.M.P.)." }
                'ASRock'   { return "ASRock : OC Tweaker > DRAM Configuration > « Load $(if ($Amd -and $RamType -match 'DDR5') { 'EXPO' } else { 'XMP' }) Setting » → Profile 1 (ou le bouton « $(if ($Amd -and $RamType -match 'DDR5') { 'EXPO' } else { 'XMP' }) » en mode Easy)." }
                default    { return "Dans le BIOS, cherche « $prof » (souvent dans les menus Overclocking, Tweaker ou Memory) et choisis le profil 1." }
            }
        }
        'virt' {
            switch ($Brand) {
                'ASUS'     { return "ASUS : mode avancé (F7) > Advanced > CPU Configuration > $virt → Enabled." }
                'MSI'      { return "MSI : OC > Advanced CPU Configuration > $virt → Enabled." }
                'Gigabyte' { return "Gigabyte / AORUS : Tweaker > Advanced CPU Settings > $virt → Enabled." }
                'ASRock'   { return "ASRock : Advanced > CPU Configuration > $virt → Enabled." }
                'HP'       { return "HP : Configuration du système (ou Advanced) > « Virtualization Technology » → Activé." }
                'Dell'     { return "Dell : Virtualization Support (ou Advanced) > « Virtualization » / « Enable Intel Virtualization Technology » → coché." }
                'Lenovo'   { return "Lenovo : Configuration (ou Security > Virtualization) > « Intel Virtual Technology » / « AMD V(TM) Technology » → Enabled." }
                'Acer'     { return "Acer : Main (ou Advanced) > « Intel Virtualization Technology » / « AMD-V » → Enabled." }
                default    { return "Dans le BIOS, cherche $virt (souvent dans Advanced, CPU Configuration ou Security) → Enabled." }
            }
        }
        'rebar' {
            switch ($Brand) {
                'ASUS'     { return "ASUS : mode avancé (F7) > Advanced > PCI Subsystem Settings > « Above 4G Decoding » puis « Re-Size BAR Support » → Enabled." }
                'MSI'      { return "MSI : Settings > Advanced > PCIe/PCI Sub-system Settings > « Re-Size BAR Support » → Enabled (active aussi « Above 4G memory »)." }
                'Gigabyte' { return "Gigabyte / AORUS : Settings > IO Ports > « Above 4G Decoding » puis « Re-Size BAR Support » → Enabled (ou Auto)." }
                'ASRock'   { return "ASRock : Advanced > PCI Configuration > « Above 4G Decoding » et « Re-Size BAR Support » → Enabled." }
                default    { return "Dans le BIOS, cherche « Above 4G Decoding » et « Re-Size BAR » (souvent dans Advanced > PCI) → Enabled." }
            }
        }
        'fans' {
            if ($Oem) { return "Sur un portable ou un PC de marque, le BIOS ne propose en général pas de courbes de ventilateurs : ce sont le logiciel du fabricant (Armoury Crate, MSI Center, Lenovo Vantage, OMEN Gaming Hub, Alienware Command Center, NitroSense…) et le mode d'alimentation de Windows (onglet Performances) qui règlent le bruit." }
            switch ($Brand) {
                'ASUS'     { return "ASUS : en mode EZ, « QFan Control » (touche F6) → profils Silent / Standard / Turbo / Full Speed pour chaque ventilateur. En mode avancé : Monitor > Q-Fan Configuration." }
                'MSI'      { return "MSI : écran « Hardware Monitor » → courbe de chaque ventilateur (mode Smart Fan) ; « All set to Default » remet le réglage d'usine." }
                'Gigabyte' { return "Gigabyte / AORUS : « Smart Fan 6 » (touche F6) → profils Silent / Normal / Manual / Full Speed pour chaque ventilateur." }
                'ASRock'   { return "ASRock : « FAN-Tastic Tuning » (mode Easy, ou Advanced > H/W Monitor) → profils Silent / Standard / Performance / Full Speed." }
                default    { return "Dans le BIOS, cherche « Smart Fan », « Q-Fan » ou « Fan Control » (souvent dans Monitor ou H/W Monitor) : profils Silencieux / Standard / Performance." }
            }
        }
    }
    return ''
}
# Resizable BAR (cartes NVIDIA : lu par nvidia-smi, le seul moyen fiable depuis Windows)
function Get-RebarState {
    $r = @{ State = 'unknown'; Gpu = ''; Bar1 = 0; Vram = 0 }
    try {
        $smi = Get-NvidiaSmi
        if (-not $smi) { return $r }
        $r.Gpu = "$((& $smi --query-gpu=name --format=csv,noheader 2>$null) | Select-Object -First 1)".Trim()
        $o = @(& $smi -q -d MEMORY 2>$null)
        $sec = ''
        foreach ($l in $o) {
            if ($l -match '^\s*FB Memory Usage') { $sec = 'fb' } elseif ($l -match '^\s*BAR1 Memory Usage') { $sec = 'bar' } elseif ($l -match '^\s*\S.*Memory Usage') { $sec = '' }
            if ($l -match '^\s*Total\s*:\s*(\d+)\s*MiB') { if ($sec -eq 'fb' -and -not $r.Vram) { $r.Vram = [int]$matches[1] } elseif ($sec -eq 'bar' -and -not $r.Bar1) { $r.Bar1 = [int]$matches[1] } }
        }
        if ($r.Bar1 -gt 256) { $r.State = 'on' }
        elseif ($r.Bar1 -gt 0) { $r.State = $(if ($r.Gpu -match '(?i)RTX\s*(30|40|50)\d\d|RTX\s*A\d{3,4}|RTX\s*PRO') { 'off' } else { 'unsupported' }) }
    } catch {}
    return $r
}
# Logiciels de réglage des ventilateurs installés (fabricant, ou FanControl)
function Get-FanSoftware {
    $names = New-Object System.Collections.ArrayList
    $re = '(?i)^(Armoury Crate|MSI Center|MSI Dragon Center|Dragon Center|iCUE|CORSAIR iCUE|NZXT CAM|FanControl|Fan Control|Lenovo Legion Toolkit|OMEN Gaming Hub|Alienware Command Center|NitroSense|PredatorSense|G-Helper|GIGABYTE Control Center|AORUS ENGINE|Argus Monitor|SpeedFan)'
    foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', "$((Get-SessionUser).Hkcu)\Software\Microsoft\Windows\CurrentVersion\Uninstall\*") {
        try { foreach ($e in @(Get-ItemProperty $k -ErrorAction SilentlyContinue)) { $n = "$($e.DisplayName)".Trim(); if ($n -match $re -and $names -notcontains $matches[1]) { [void]$names.Add($matches[1]) } } } catch {}
    }
    try {
        foreach ($p in @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)LenovoCompanion|OMENCommandCenter|AlienwareCommandCenter|ArmouryCrate|MSICenter' })) {
            $n = switch -Regex ($p.Name) { 'LenovoCompanion' { 'Lenovo Vantage' } 'OMEN' { 'OMEN Gaming Hub' } 'Alienware' { 'Alienware Command Center' } 'Armoury' { 'Armoury Crate' } 'MSICenter' { 'MSI Center' } }
            if ($n -and $names -notcontains $n) { [void]$names.Add($n) }
        }
    } catch {}
    return $names.ToArray()
}
function Get-BiosInfo($I) {
    $b = @{ Ram = $null; Virt = 'unknown'; Rebar = $null; FanSoft = @(); Oem = $false }
    $b.Oem = [bool]$I.IsLaptop
    if (-not $I.Custom -and $I.Brand -in 'Dell', 'HP', 'Lenovo', 'Acer', 'Microsoft', 'Samsung', 'Medion', 'Huawei', 'Dynabook', 'Razer') { $b.Oem = $true }
    # ---- Mémoire
    try {
        $mods = @(Get-CimStatic Win32_PhysicalMemory | Where-Object { [double]$_.Capacity -gt 0 })
        $t = @($mods | ForEach-Object { [int]$_.SMBIOSMemoryType } | Where-Object { $_ }) | Select-Object -First 1
        $type = switch ($t) { 24 { 'DDR3' } 26 { 'DDR4' } 34 { 'DDR5' } 29 { 'LPDDR3' } 30 { 'LPDDR4' } 35 { 'LPDDR5' } 36 { 'LPDDR5' } default { '' } }
        $list = foreach ($m in $mods) {
            $part = "$($m.PartNumber)".Trim()
            @{ Slot = "$($m.DeviceLocator)".Trim(); Bank = "$($m.BankLabel)".Trim(); Size = [double]$m.Capacity; Maker = "$($m.Manufacturer)".Trim(); Part = $part
               Rated = (Get-RamRatedSpeed $part); Speed = [int]$m.Speed; Conf = [int]$m.ConfiguredClockSpeed; Volt = [int]$m.ConfiguredVoltage; Jedec = (Test-JedecPart $part)
               Channel = (Get-MemChannel "$($m.DeviceLocator)" "$($m.BankLabel)"); Form = [int]$m.FormFactor }
        }
        $list = @($list)
        $arr = @(Get-CimInstance Win32_PhysicalMemoryArray -ErrorAction SilentlyContinue | Where-Object { $_.Use -eq 3 })
        $slots = [int](($arr | Measure-Object MemoryDevices -Sum).Sum)
        $maxKb = [double](($arr | ForEach-Object { if ($_.MaxCapacityEx) { [double]$_.MaxCapacityEx } else { [double]$_.MaxCapacity } } | Measure-Object -Sum).Sum)
        $conf = @($list | ForEach-Object { if ($_.Conf) { $_.Conf } else { $_.Speed } } | Where-Object { $_ } | Sort-Object)[0]
        $ratedL = @($list | ForEach-Object { $_.Rated } | Where-Object { $_ -gt 0 } | Sort-Object)
        $rated = if ($ratedL.Count -eq $list.Count -and $ratedL.Count) { $ratedL[0] } elseif ($ratedL.Count) { $ratedL[0] } else { 0 }
        $volt = @($list | ForEach-Object { $_.Volt } | Where-Object { $_ -ge 500 } | Sort-Object -Descending)[0]
        $allJedec = ($list.Count -and @($list | Where-Object { $_.Jedec }).Count -eq $list.Count)
        $am5 = (-not $I.IsLaptop -and "$($I.Cpu)" -match '(?i)Ryzen\s+\d+\s+(PRO\s+)?[789]\d{3}')
        $xmp = Get-XmpState $type ([int]$conf) ([int]$rated) ([int]$volt) $allJedec ([bool]$I.IsLaptop) $am5
        # Canaux : dual channel si les barrettes sont sur au moins 2 canaux
        $ch = 'unknown'; $letters = @($list | ForEach-Object { $_.Channel })
        if ($list.Count -eq 1) { $ch = 'one' }
        elseif ($list.Count -ge 2 -and -not @($letters | Where-Object { -not $_ }).Count) { $ch = $(if (@($letters | Select-Object -Unique).Count -ge 2) { 'dual' } else { 'single' }) }
        $parts = @($list | ForEach-Object { $_.Part } | Where-Object { $_ } | Select-Object -Unique)
        $sizes = @($list | ForEach-Object { $_.Size } | Select-Object -Unique)
        $b.Ram = @{ Type = $type; Modules = $list; Count = $list.Count; Slots = $slots; MaxBytes = ($maxKb * 1KB); Total = [double](($list | ForEach-Object { [double]$_.Size } | Measure-Object -Sum).Sum)
                    Conf = [int]$conf; Rated = [int]$rated; Volt = [int]$volt; Xmp = $xmp; Channels = $ch; Mixed = ($parts.Count -gt 1 -or $sizes.Count -gt 1) }
    } catch {}
    # ---- Virtualisation (VT-x / AMD-V)
    try {
        $hyp = [bool](Get-CimStatic Win32_ComputerSystem).HypervisorPresent
        $fw = @(Get-CimStatic Win32_Processor | Select-Object -First 1)[0].VirtualizationFirmwareEnabled
        $b.Virt = if ($hyp) { 'inuse' } elseif ($fw -eq $true) { 'on' } elseif ($fw -eq $false) { 'off' } else { 'unknown' }
    } catch {}
    $b.Rebar = Get-RebarState
    $b.FanSoft = @(Get-FanSoftware)
    return $b
}
# Ventilateurs (module de températures) : lignes à afficher et alertes, sans jamais inventer de problème
function ConvertTo-FanLabel([string]$Name, [string]$Src) {
    if ($Src -eq 'gpu') { return $(if ($Name -match '(\d+)\s*$' -and $Name -notmatch '^GPU Fan$') { "Carte graphique, ventilateur $($matches[1])" } else { 'Carte graphique' }) }
    $nm = "$Name"
    if ($nm -match '(?i)pump|aio|w_?pump') { return "Pompe de watercooling ($nm)" }
    if ($nm -match '(?i)^cpu(_|\s)?(fan|opt)|cpu fan') { return $(if ($nm -match '(?i)opt') { "Processeur 2 ($nm)" } else { "Processeur ($nm)" }) }
    if ($nm -match '(?i)chassis|system|sys_?fan|case') { return "Boîtier ($nm)" }
    if ($nm -match '^Fan #(\d+)$') { return "Ventilateur n° $($matches[1]) (carte mère)" }
    return "$nm (carte mère)"
}
function Get-FanFindings($Fans, $CpuTemp, $CpuLoad, $GpuTemp) {
    $rows = New-Object System.Collections.ArrayList; $alerts = New-Object System.Collections.ArrayList
    $fl = @($Fans | Where-Object { $_ })
    $mb = @($fl | Where-Object { $_.Src -eq 'mb' }); $gp = @($fl | Where-Object { $_.Src -eq 'gpu' })
    $mbOn = @($mb | Where-Object { [double]$_.Rpm -gt 0 })
    foreach ($f in @($mbOn + $gp)) {
        $txt = if ([double]$f.Rpm -gt 0) { "{0:N0} tr/min" -f [double]$f.Rpm } else { "à l'arrêt" }
        if ($null -ne $f.Pct) { $txt += ("  ·  {0} %" -f [math]::Round([double]$f.Pct)) }
        $note = ''
        if ($f.Src -eq 'gpu' -and [double]$f.Rpm -eq 0) { $note = $(if ($GpuTemp -and [double]$GpuTemp -ge 80) { 'bad' } else { 'zero' }) }
        [void]$rows.Add(@{ Label = (ConvertTo-FanLabel "$($f.Name)" $f.Src); Text = $txt; Note = $note })
    }
    $idle = @($mb | Where-Object { [double]$_.Rpm -le 0 }).Count
    if ($mb.Count -and -not $mbOn.Count -and $CpuTemp -and [double]$CpuTemp -ge 85) {
        [void]$alerts.Add(@{ Kind = 'bad'; Text = ("Aucun ventilateur de la carte mère ne tourne alors que le processeur est à {0} °C : vérifie que le ventilateur du processeur (ou la pompe du watercooling) est bien branché, sur la prise « CPU_FAN » de la carte mère." -f [math]::Round([double]$CpuTemp)) })
    }
    if (@($gp | Where-Object { [double]$_.Rpm -eq 0 }).Count -and $GpuTemp -and [double]$GpuTemp -ge 80) {
        [void]$alerts.Add(@{ Kind = 'bad'; Text = ("Les ventilateurs de la carte graphique sont à l'arrêt alors qu'elle est à {0} °C : ventilateur bloqué ou en panne, ou réglage forcé dans un logiciel (MSI Afterburner…)." -f [math]::Round([double]$GpuTemp)) })
    }
    $fast = @($mbOn | Where-Object { [double]$_.Rpm -ge 2500 -and "$($_.Name)" -notmatch '(?i)pump|aio' })
    if ($fast.Count -and $null -ne $CpuLoad -and [double]$CpuLoad -lt 15 -and $CpuTemp -and [double]$CpuTemp -lt 55) {
        [void]$alerts.Add(@{ Kind = 'info'; Text = "Un ventilateur de la carte mère tourne vite alors que le PC ne fait presque rien. Si ton PC est bruyant au repos, son profil est sûrement réglé sur Performance / Turbo ou plein régime : passe-le en Standard ou Silencieux (voir ci-dessous). Si c'est la pompe d'un watercooling, c'est normal (souvent 2 000 à 3 000 tr/min)." })
    }
    return @{ Rows = $rows.ToArray(); Alerts = $alerts.ToArray(); IdleHeaders = $idle; Mb = $mb.Count; Gpu = $gp.Count }
}

# Mémoire : type (DDR3/4/5), barrettes et emplacements libres, pour un conseil d'ajout précis
function Get-RamLayout {
    $r = @{ Type = ''; Modules = 0; Slots = 0; ModuleSize = 0.0 }
    try {
        $mods = @(Get-CimStatic Win32_PhysicalMemory)
        $r.Modules = $mods.Count
        if ($mods.Count) { $r.ModuleSize = [double]($mods | Measure-Object Capacity -Maximum).Maximum }
        $t = @($mods | ForEach-Object { [int]$_.SMBIOSMemoryType } | Where-Object { $_ }) | Select-Object -First 1
        $r.Type = switch ($t) { 24 { 'DDR3' } 26 { 'DDR4' } 34 { 'DDR5' } 30 { 'LPDDR4' } 35 { 'LPDDR5' } default { '' } }
        $arr = @(Get-CimInstance Win32_PhysicalMemoryArray -ErrorAction Stop | Where-Object { $_.Use -eq 3 })
        $r.Slots = [int](($arr | Measure-Object MemoryDevices -Sum).Sum)
    } catch {}
    return $r
}
# Réglage « état maximal du processeur » (sur secteur) du mode d'alimentation actif : 100 = normal
function Get-CpuMaxState {
    try {
        $o = (& powercfg.exe /query SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 2>$null) | Out-String
        $m = [regex]::Matches($o, '0x([0-9a-fA-F]{8})')
        if ($m.Count -ge 2) { return [Convert]::ToInt32($m[$m.Count - 2].Groups[1].Value, 16) }
    } catch {}
    return $null
}
function Set-CpuMaxState([int]$Percent) {
    Step "Réglage de la puissance maximale du processeur"
    $prev = Get-CpuMaxState
    $null = & powercfg.exe /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX $Percent 2>&1
    $null = & powercfg.exe /setactive SCHEME_CURRENT 2>&1
    if ((Get-CpuMaxState) -eq $Percent) {
        Log "   ✔ Le processeur peut de nouveau monter à $Percent % de sa puissance (sur secteur)."
        if ($null -ne $prev -and $prev -ne $Percent) { Add-Change -Title "Puissance maximale du processeur : $Percent %" -Detail "Avant : $prev %" -Undo ("Set-CpuMaxState {0}" -f [int]$prev) }
    } else { Add-TaskError -Title "Impossible de changer la puissance maximale du processeur" -Cause "Windows a refusé le réglage (mode d'alimentation verrouillé par l'entreprise ou le fabricant)." -FixLabel "Ouvrir les options d'alimentation" -FixAction "Open-WinUri 'ms-settings:powersleep'" }
}
function Enable-AutoPagefile {
    Step "Réactivation de la mémoire virtuelle (gérée par Windows)"
    try {
        Set-CimInstance -Query 'SELECT * FROM Win32_ComputerSystem' -Property @{ AutomaticManagedPagefile = $true } -ErrorAction Stop
        Log "   ✔ Mémoire virtuelle gérée automatiquement par Windows. Redémarre le PC pour l'appliquer."
        Add-Change -Kind 'info' -Title "Mémoire virtuelle remise en automatique (réglage d'origine de Windows)"
        Request-Reboot
    } catch { Add-TaskError -Title "Impossible de réactiver la mémoire virtuelle" -Cause $_.Exception.Message -FixLabel "Ouvrir les paramètres système avancés" -FixAction "Open-SystemTool 'SystemPropertiesPerformance.exe'" }
}

# ---------------------------------------------------------------- Mesure de la connexion (pendant les analyses de lenteur et de lag)
# Temps de réponse, irrégularité (gigue) et paquets perdus vers une adresse. Une adresse qui ne répond à aucun des
# 3 premiers essais (ping bloqué par un pare-feu) n'est plus mesurée : jamais de « pertes » inventées.
function New-PingSeries([string]$Ip) { return @{ Ip = $Ip; Ok = 0; Lost = 0; Times = (New-Object System.Collections.ArrayList); Off = (-not $Ip) } }
function Add-PingSample($S, $Pinger) {
    if ($S.Off) { return }
    try {
        $r = $Pinger.Send($S.Ip, 900)
        if ($r.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) { $S.Ok++; [void]$S.Times.Add([double]$r.RoundtripTime) } else { $S.Lost++ }
    } catch { $S.Lost++ }
    if ($S.Ok -eq 0 -and $S.Lost -ge 3) { $S.Off = $true }
}
function Get-PingStats($S) {
    $n = $S.Ok + $S.Lost
    $r = @{ Ip = $S.Ip; N = $n; Ok = ($S.Ok -ge 5); Loss = 0.0; Avg = 0.0; Jitter = 0.0; Max = 0.0 }
    if (-not $r.Ok) { return $r }
    $r.Loss = [math]::Round(100.0 * $S.Lost / $n, 1)
    $t = @($S.Times)
    $r.Avg = [math]::Round([double](($t | Measure-Object -Average).Average), 1)
    $r.Max = [double](($t | Measure-Object -Maximum).Maximum)
    $d = 0.0
    for ($i = 1; $i -lt $t.Count; $i++) { $d += [math]::Abs($t[$i] - $t[$i - 1]) }
    if ($t.Count -ge 2) { $r.Jitter = [math]::Round($d / ($t.Count - 1), 1) }
    return $r
}
function Get-GatewayIp {
    try {
        $r = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction Stop | Where-Object { "$($_.NextHop)" -match '^\d+\.\d+\.\d+\.\d+$' -and "$($_.NextHop)" -ne '0.0.0.0' } | Sort-Object RouteMetric | Select-Object -First 1
        if ($r) { return "$($r.NextHop)" }
    } catch {}
    return ''
}
# Trafic réseau du PC (octets/s reçus et envoyés), sans les cartes virtuelles ni les VPN (sinon compté deux fois)
function Get-NetThroughput {
    $rx = 0.0; $tx = 0.0
    foreach ($x in @(Get-CimInstance Win32_PerfFormattedData_Tcpip_NetworkInterface -ErrorAction SilentlyContinue)) {
        if ("$($x.Name)" -match '(?i)isatap|teredo|loopback|pseudo|vethernet|hyper-v|wsl|virtual|vmware|virtualbox|bluetooth|tap-|wireguard|wintun|nordlynx|tunnel|vpn') { continue }
        $rx += [double]$x.BytesReceivedPersec; $tx += [double]$x.BytesSentPersec
    }
    return @{ Rx = $rx; Tx = $tx }
}
function Get-WifiInfo {
    $w = @{ Signal = -1; Band = ''; Ssid = '' }
    try {
        $t = (netsh.exe wlan show interfaces 2>$null) | Out-String
        if ($t -match 'Signal\s*:\s*(\d+)\s*%') { $w.Signal = [int]$matches[1] }
        if ($t -match '(?im)^\s*(Bande|Band)\s*:\s*([\d.,]+)\s*GHz') { $w.Band = ($matches[2] -replace ',', '.') }
    } catch {}
    return $w
}
# Programmes ouverts qui téléchargent souvent en fond (nommés seulement s'ils sont ouverts, jamais affirmé)
$script:Downloaders = @{ 'steam' = 'Steam'; 'epicgameslauncher' = 'Epic Games'; 'battle.net' = 'Battle.net'; 'eadesktop' = 'EA app'; 'upc' = 'Ubisoft Connect'
                         'riotclientservices' = 'Riot Client'; 'qbittorrent' = 'qBittorrent'; 'utorrent' = 'µTorrent'; 'bittorrent' = 'BitTorrent'; 'onedrive' = 'OneDrive'
                         'dropbox' = 'Dropbox'; 'googledrivefs' = 'Google Drive'; 'icloudservices' = 'iCloud'; 'gog galaxy' = 'GOG Galaxy'; 'galaxyclient' = 'GOG Galaxy' }
function Get-OpenDownloaders {
    return @(Get-Process -ErrorAction SilentlyContinue | ForEach-Object { "$($_.ProcessName)".ToLower() } | Select-Object -Unique |
             Where-Object { $script:Downloaders.ContainsKey($_) } | ForEach-Object { $script:Downloaders[$_] } | Select-Object -Unique)
}
# Ce que la mesure de la connexion révèle (mêmes règles pour « Mon PC rame » et « Ça lague »)
function Get-NetFindings($Gw, $Net, [double]$Rx, [double]$Tx, [bool]$Wifi, $WifiInfo) {
    $f = New-Object System.Collections.ArrayList
    $localBad = $false
    if ($Gw.Ok -and ($Gw.Loss -ge 5 -or $Gw.Jitter -ge 15 -or $Gw.Avg -ge 30)) {
        $localBad = $true
        $txt = "Entre le PC et la box : {0} ms en moyenne, variations de ±{1} ms, {2} % de paquets perdus. Une liaison saine : quelques ms, aucune perte." -f $Gw.Avg, $Gw.Jitter, $Gw.Loss
        $sev = $(if ($Gw.Loss -ge 5) { 'bad' } else { 'warn' })
        if ($Wifi) {
            if ($WifiInfo.Signal -ge 0) { $txt += " Signal Wi-Fi : $($WifiInfo.Signal) %." }
            if ($WifiInfo.Band -like '2*') { $txt += " Connecté en 2,4 GHz (plus encombré que le 5 GHz)." }
            [void]$f.Add(@{ Id = 'wifi-instable'; Sev = $sev; Title = "Le Wi-Fi entre le PC et la box est instable"; Text = $txt; Advice = "C'est ça qui fait laguer, pas Internet. Le mieux : un câble Ethernet (ou des boîtiers CPL). Sinon : rapproche le PC de la box, connecte-toi au réseau 5 GHz de la box s'il existe (souvent le même nom avec « 5G »), et redémarre la box."; Action = '' })
        } else {
            [void]$f.Add(@{ Id = 'lan-instable'; Sev = $sev; Title = "La liaison entre le PC et la box est instable"; Text = $txt; Advice = "Avec un câble, c'est anormal : essaie un autre câble et un autre port de la box. Avec des boîtiers CPL : branche-les directement sur une prise murale (pas sur une multiprise) ou rapproche-les. Redémarre aussi la box."; Action = '' })
        }
    } elseif ($Wifi -and $WifiInfo.Signal -ge 0 -and $WifiInfo.Signal -lt 50) {
        [void]$f.Add(@{ Id = 'wifi-faible'; Sev = 'warn'; Title = "Signal Wi-Fi faible ($($WifiInfo.Signal) %)"; Text = "Au-dessus de 70 %, c'est confortable. Un signal faible donne des lags par moments et un débit plus bas."; Advice = "Rapproche le PC de la box, évite de la mettre dans un meuble fermé, ou passe en câble Ethernet / CPL."; Action = '' })
    }
    $busy = ($Rx -ge 3MB -or $Tx -ge 1MB)
    if ($Net.Ok -and -not $localBad) {
        if ($Net.Loss -ge 3) {
            [void]$f.Add(@{ Id = 'internet-pertes'; Sev = 'bad'; Title = ("Ta connexion Internet perd des paquets ({0} %)" -f $Net.Loss)
                            Text = $(if ($Gw.Ok) { "La liaison entre le PC et la box est bonne : c'est entre la box et Internet que les paquets se perdent." } else { "Ta box ne répond pas au ping, donc impossible de dire si ça se perd avant ou après elle." })
                            Advice = "Effet : personnages qui « sautent » en jeu, voix hachée sur Discord. Redémarre la box (30 secondes débranchée). Si ça continue, appelle ton fournisseur d'accès avec ce résultat : il peut tester ta ligne."; Action = '' })
        } elseif ($Net.Jitter -ge 20 -or $Net.Avg -ge 80) {
            [void]$f.Add(@{ Id = 'ping-instable'; Sev = 'warn'; Title = $(if ($Net.Avg -ge 80) { "Le ping est élevé ($($Net.Avg) ms)" } else { "Le ping est irrégulier (variations de ±$($Net.Jitter) ms)" })
                            Text = ("Vers Internet : {0} ms en moyenne, variations de ±{1} ms, pointe à {2} ms. Bon pour jouer : moins de 40 ms et des variations sous 10 ms." -f $Net.Avg, $Net.Jitter, $Net.Max)
                            Advice = $(if ($busy) { "Un téléchargement occupe ta connexion pendant la mesure (voir ci-dessous) : c'est la cause la plus probable." } else { "Souvent un autre appareil de la maison qui télécharge ou regarde des vidéos (la box sature) : mets-les en pause pour tester. Si ça ne change rien, c'est ta ligne ou ton fournisseur." }); Action = '' })
        }
    }
    if ($busy) {
        $dl = @(Get-OpenDownloaders)
        [void]$f.Add(@{ Id = 'connexion-occupee'; Sev = 'warn'; Title = ("Ta connexion est occupée ({0}/s reçus, {1}/s envoyés)" -f (Format-Size $Rx), (Format-Size $Tx))
                        Text = $(if ($dl.Count) { "Programmes ouverts qui téléchargent souvent en fond : " + ($dl -join ', ') + "." } else { "Souvent Windows Update, la mise à jour d'un jeu ou une synchronisation (OneDrive…)." })
                        Advice = "Pendant que tu joues ou que tu es en vocal, mets ces téléchargements en pause : un téléchargement fait monter le ping."; Action = '' })
    }
    return $f.ToArray()
}
function Get-PingLine($S, [string]$Label) {
    if (-not $S.Ok) { return @{ Ok = $true; T = "$Label : ne répond pas au ping (normal sur certains réseaux), non mesuré" } }
    return @{ Ok = -not ($S.Loss -ge 3 -or $S.Jitter -ge 15); T = ("{0} : {1} ms en moyenne, variations ±{2} ms, {3} % perdus" -f $Label, $S.Avg, $S.Jitter, $S.Loss) }
}

# Mesure en direct pendant ~20 s : processeur, mémoire, disque, carte graphique, bridage, pilotes, connexion
# -Delay : attend avant de mesurer (le temps de lancer un jeu) ; -Mode 'jeu' : conseils adaptés à une mesure en jeu
function Get-SlowReport([int]$Delay = 0, [string]$Mode = '') {
    $sync.SlowReport = $null
    if ($Delay -gt 0) {
        Step "La mesure commence dans $Delay secondes : lance ton jeu (ou ce qui rame) maintenant et joue normalement."
        for ($s = 0; $s -lt $Delay; $s++) { if ($sync.Cancel) { return }; Start-Sleep -Seconds 1; $sync.Progress = [math]::Round(30 * ($s + 1) / $Delay) }
    }
    Step "Analyse des lenteurs : mesure pendant 20 secondes. Utilise le PC normalement (c'est encore mieux si tu la lances quand il rame)."
    $cores = [math]::Max([double]1, [Environment]::ProcessorCount)
    $me = $PID
    $acc = @{}; $cpuTot = New-Object System.Collections.ArrayList; $diskBusy = New-Object System.Collections.ArrayList; $diskQ = New-Object System.Collections.ArrayList
    $dpc = New-Object System.Collections.ArrayList; $lim = New-Object System.Collections.ArrayList; $gpuTot = New-Object System.Collections.ArrayList; $gpuAcc = @{}
    $rxL = New-Object System.Collections.ArrayList; $txL = New-Object System.Collections.ArrayList
    $gpuOk = $true
    $pg = New-Object System.Net.NetworkInformation.Ping
    $gwS = New-PingSeries (Get-GatewayIp); $netS = New-PingSeries '1.1.1.1'
    $null = Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction SilentlyContinue   # 1re lecture : amorce les compteurs
    $null = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -ErrorAction SilentlyContinue
    $null = Get-NetThroughput
    $n = 7
    for ($i = 0; $i -lt $n; $i++) {
        if ($sync.Cancel) { return }
        # 3 secondes entre deux relevés, occupées par la mesure de la connexion (1 essai par seconde vers la box et Internet)
        for ($k = 0; $k -lt 3; $k++) {
            $sw = [Diagnostics.Stopwatch]::StartNew()
            Add-PingSample $gwS $pg; Add-PingSample $netS $pg
            if ($netS.Off -and $netS.Ip -eq '1.1.1.1') { $netS = New-PingSeries '8.8.8.8' }
            $rest = 1000 - [int]$sw.ElapsedMilliseconds; if ($rest -gt 0) { Start-Sleep -Milliseconds $rest }
        }
        $sync.Progress = $(if ($Delay -gt 0) { 30 + [math]::Round(70 * ($i + 1) / $n) } else { [math]::Round(100 * ($i + 1) / $n) })
        foreach ($x in @(Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction SilentlyContinue)) {
            $nm = "$($x.Name)" -replace '#\d+$', ''
            if ($nm -in '_Total', 'Idle' -or [int]$x.IDProcess -eq $me -or $nm -match '(?i)^(wmiprvse|aeroxpccare)$') { continue }
            if (-not $acc.ContainsKey($nm)) { $acc[$nm] = @{ Name = $nm; Cpu = 0.0; Io = 0.0; Mem = 0.0; Gpu = 0.0; Pid = [int]$x.IDProcess; Seen = 0 } }
            $e = $acc[$nm]; $e.Cpu += [double]$x.PercentProcessorTime / $cores; $e.Io += [double]$x.IODataBytesPersec
        }
        # Mémoire : instantané par programme (somme de ses processus)
        if ($i -eq $n - 1) {
            foreach ($g in @(Get-Process -ErrorAction SilentlyContinue | Group-Object ProcessName)) {
                if ($acc.ContainsKey($g.Name)) { $acc[$g.Name].Mem = [double](($g.Group | Measure-Object WorkingSet64 -Sum).Sum) }
                elseif ($g.Name -notmatch '(?i)^(idle|aeroxpccare)$') { $acc[$g.Name] = @{ Name = $g.Name; Cpu = 0.0; Io = 0.0; Mem = [double](($g.Group | Measure-Object WorkingSet64 -Sum).Sum); Gpu = 0.0; Pid = [int]$g.Group[0].Id; Seen = $n } }
            }
        }
        $t = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction SilentlyContinue
        if ($t) { [void]$cpuTot.Add([double]$t.PercentProcessorTime); [void]$dpc.Add([double]$t.PercentDPCTime + [double]$t.PercentInterruptTime) }
        # Bridage du processeur par le PC lui-même (chauffe, alimentation) : « % de limite de performances » de Windows
        try {
            $pi = Get-CimInstance Win32_PerfFormattedData_Counters_ProcessorInformation -Filter "Name='_Total'" -ErrorAction Stop
            if ($pi -and $null -ne $pi.PercentPerformanceLimit) { [void]$lim.Add([double]$pi.PercentPerformanceLimit) }
        } catch {}
        # Carte graphique : utilisation 3D par programme (le total = la carte la plus occupée)
        if ($gpuOk) {
            try {
                $luid = @{}
                foreach ($x in @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction Stop)) {
                    if ("$($x.Name)" -notmatch '^pid_(\d+)_luid_(0x[0-9A-Fa-f]+_0x[0-9A-Fa-f]+)_.*engtype_3D$') { continue }
                    $gp = [int]$matches[1]; $gl = $matches[2]; $u = [double]$x.UtilizationPercentage
                    if ($gp -eq $me) { continue }
                    $luid[$gl] = [double]$luid[$gl] + $u
                    $gpuAcc[$gp] = [double]$gpuAcc[$gp] + $u
                }
                $mx = 0.0; foreach ($v in $luid.Values) { if ($v -gt $mx) { $mx = $v } }
                [void]$gpuTot.Add([math]::Min([double]100, $mx))
            } catch { $gpuOk = $false }
        }
        $nt = Get-NetThroughput; [void]$rxL.Add($nt.Rx); [void]$txL.Add($nt.Tx)
        # Disque le plus occupé (pas la moyenne de tous : un disque dur saturé + un SSD au repos donnerait 50 %)
        $dk = @(Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne '_Total' })
        if ($dk.Count) {
            [void]$diskBusy.Add([math]::Max([double]0, 100 - [double](($dk | Measure-Object PercentIdleTime -Minimum).Minimum)))
            [void]$diskQ.Add([double](($dk | Measure-Object CurrentDiskQueueLength -Maximum).Maximum))
        }
    }
    $avg = { param($l) if ($l.Count) { [math]::Round([double](($l | Measure-Object -Average).Average)) } else { 0 } }
    $os = Get-CimInstance Win32_OperatingSystem
    $ramTot = [double]$os.TotalVisibleMemorySize * 1KB
    $ramPct = [math]::Round(100 * (1 - [double]$os.FreePhysicalMemory / [double]$os.TotalVisibleMemorySize))
    $rep = @{ Mode = $Mode; Cpu = (& $avg $cpuTot); CpuMax = $(if ($cpuTot.Count) { [math]::Round([double](($cpuTot | Measure-Object -Maximum).Maximum)) } else { 0 }); Ram = $ramPct; RamTotal = $ramTot
              Disk = (& $avg $diskBusy); Queue = $(if ($diskQ.Count) { [math]::Round([double](($diskQ | Measure-Object -Average).Average), 1) } else { 0 }); Hdd = $false; Top = @(); Findings = @(); Checked = @()
              GpuOk = ($gpuOk -and $gpuTot.Count -gt 0); Gpu = (& $avg $gpuTot); Dpc = $(if ($dpc.Count) { [math]::Round([double](($dpc | Measure-Object -Average).Average), 1) } else { 0 })
              Limit = $(if ($lim.Count -ge 4) { & $avg $lim } else { $null }) }
    # Disque de Windows : SSD ou disque dur classique ?
    try { $dn = (Get-Partition -DriveLetter $env:SystemDrive[0] -ErrorAction Stop).DiskNumber; $pd = Get-PhysicalDisk | Where-Object { "$($_.DeviceId)" -eq "$dn" } | Select-Object -First 1; $rep.Hdd = ("$($pd.MediaType)" -eq 'HDD') } catch {}
    # Carte graphique par programme
    foreach ($gp in @($gpuAcc.Keys)) {
        $e = $acc.Values | Where-Object { $_.Pid -eq $gp } | Select-Object -First 1
        if (-not $e) { try { $pn = (Get-Process -Id $gp -ErrorAction Stop).ProcessName; if ($acc.ContainsKey($pn)) { $e = $acc[$pn] } } catch {} }
        if ($e) { $e.Gpu = [math]::Min([double]100 * $n, [double]$e.Gpu + $gpuAcc[$gp]) }
    }
    # Classement des programmes
    # Moyenne sur la durée de la mesure (tous les processus d'un même programme additionnés : Chrome, Discord…)
    $list = foreach ($e in $acc.Values) {
        $f = Get-ProcFriendly $e.Name $e.Pid
        @{ Name = $e.Name; Label = $f.Label; Kind = $f.Kind; Cpu = [math]::Round($e.Cpu / $n, 1); Io = $e.Io / $n; Mem = $e.Mem; Gpu = [math]::Round([math]::Min([double]100, $e.Gpu / $n)) }
    }
    $list = @($list)
    $byCpu = @($list | Sort-Object { - $_.Cpu } | Select-Object -First 5)
    $byMem = @($list | Sort-Object { - $_.Mem } | Select-Object -First 5)
    $byIo  = @($list | Sort-Object { - $_.Io } | Select-Object -First 5)
    $byGpu = @($list | Where-Object { $_.Gpu -ge 5 } | Sort-Object { - $_.Gpu } | Select-Object -First 3)
    $top = New-Object System.Collections.ArrayList
    foreach ($x in @($byCpu + $byMem + $byIo + $byGpu)) { if (-not ($top | Where-Object { $_.Name -eq $x.Name })) { [void]$top.Add($x) } }
    $rep.Top = @($top | Sort-Object { - ($_.Cpu * 4 + $_.Gpu * 2 + $_.Mem / 100MB + $_.Io / 2MB) } | Select-Object -First 8)
    $startup = @(); try { $startup = @(Get-StartupEntries | Where-Object { $_.Enabled } | ForEach-Object { "$($_.Name)".ToLower() }) } catch {}
    $f = New-Object System.Collections.ArrayList
    $chk = New-Object System.Collections.ArrayList
    $advice = {
        param($x)
        if ($x.Kind -eq 'transient') { return "Tâche de Windows temporaire : laisse-la finir (souvent quelques minutes après l'allumage ou une mise à jour)." }
        if ($x.Kind -eq 'system') { return "Composant de Windows : s'il reste haut longtemps, redémarre le PC et lance le diagnostic." }
        $st = $startup | Where-Object { $_ -like "*$($x.Name.ToLower())*" -or $x.Label.ToLower() -like "*$_*" } | Select-Object -First 1
        if ($st) { return "Il se lance au démarrage : retire-le du démarrage si tu ne t'en sers pas tout le temps (onglet Performances)." }
        return "Ferme-le si tu ne t'en sers pas en ce moment."
    }
    $hogs = @($byCpu | Where-Object { $_.Cpu -ge 20 })
    if ($rep.Cpu -ge 75 -or $hogs.Count) {
        $txt = ($hogs | ForEach-Object { "{0} : {1} %" -f $_.Label, [math]::Round($_.Cpu) }) -join ' · '
        if (-not $txt) { $txt = ($byCpu | Select-Object -First 3 | ForEach-Object { "{0} : {1} %" -f $_.Label, [math]::Round($_.Cpu) }) -join ' · ' }
        $adv = & $advice $(@($hogs + $byCpu)[0])
        if ($Mode -eq 'jeu' -and $rep.Cpu -ge 75) { $adv = "En jeu, c'est le processeur qui limite les FPS. Ferme ce qui tourne à côté (navigateur, enregistrement, partage d'écran) et baisse les réglages qui le chargent : distance d'affichage, foule, physique, ombres." }
        [void]$f.Add(@{ Id = 'processeur'; Sev = $(if ($rep.Cpu -ge 75) { 'bad' } else { 'warn' }); Title = $(if ($rep.Cpu -ge 75) { "Le processeur tourne presque à fond ($($rep.Cpu) % en moyenne)" } else { "Un programme occupe beaucoup le processeur" }); Text = $txt; Advice = $adv; Action = 'taskmgr' })
    }
    [void]$chk.Add(@{ Ok = ($rep.Cpu -lt 75); T = "Processeur : $($rep.Cpu) % en moyenne (pointe à $($rep.CpuMax) %)" })
    if ($rep.Ram -ge 85) {
        $lay = Get-RamLayout
        $txt = ($byMem | Select-Object -First 3 | ForEach-Object { "{0} : {1}" -f $_.Label, (Format-Size $_.Mem) }) -join ' · '
        $up = ''
        if ($ramTot -lt 15GB) {
            $free = $lay.Slots - $lay.Modules
            $up = "Avec {0} de mémoire, le PC sature vite." -f (Format-Size $ramTot)
            if ($free -gt 0 -and $lay.Type) { $up += " Il reste $free emplacement(s) libre(s) : ajouter une barrette $($lay.Type) de $(Format-Size $lay.ModuleSize) (pareille à celle en place) est la meilleure amélioration." }
            elseif ($lay.Type) { $up += " Tous les emplacements sont pris : il faudrait remplacer les barrettes par des plus grosses ($($lay.Type))." }
        }
        [void]$f.Add(@{ Id = 'memoire'; Sev = 'bad'; Title = "La mémoire (RAM) est saturée : $($rep.Ram) %"; Text = $txt; Advice = $(if ($up) { $up } else { "Ferme les programmes et onglets de navigateur inutiles, et retire du démarrage ce qui ne sert pas." }); Action = 'startup' })
    }
    [void]$chk.Add(@{ Ok = ($rep.Ram -lt 85); T = "Mémoire : $($rep.Ram) % utilisée sur $(Format-Size $ramTot)" })
    if ($rep.Disk -ge 70) {
        $txt = ($byIo | Select-Object -First 3 | Where-Object { $_.Io -gt 100KB } | ForEach-Object { "{0} : {1}/s" -f $_.Label, (Format-Size $_.Io) }) -join ' · '
        [void]$f.Add(@{ Id = 'disque-sature'; Sev = 'bad'; Title = "Le disque est saturé ($($rep.Disk) % d'activité)"; Text = $txt; Advice = $(if ($rep.Hdd) { "Windows est sur un disque dur classique : c'est la cause n°1 des lenteurs. Un SSD (à partir d'environ 40 €) rend le PC plusieurs fois plus réactif." } else { "Souvent une analyse antivirus, une mise à jour ou une synchronisation (OneDrive…) : ça passe en quelques minutes." }); Action = '' })
    } elseif ($rep.Hdd) {
        [void]$f.Add(@{ Id = 'hdd'; Sev = 'warn'; Title = "Windows est installé sur un disque dur classique (HDD)"; Text = "Un disque dur mécanique est 5 à 10 fois plus lent qu'un SSD."; Advice = "C'est la meilleure amélioration possible pour ce PC : passer à un SSD (à partir d'environ 40 €). Un réparateur peut copier Windows dessus sans rien perdre."; Action = '' })
    }
    [void]$chk.Add(@{ Ok = ($rep.Disk -lt 70 -and -not $rep.Hdd); T = "Disque : $($rep.Disk) % d'activité" + $(if ($rep.Hdd) { ' (disque dur classique)' } else { ' (SSD)' }) })
    # Carte graphique
    if ($rep.GpuOk) {
        $gtxt = ($byGpu | ForEach-Object { "{0} : {1} %" -f $_.Label, $_.Gpu }) -join ' · '
        if ($rep.Gpu -ge 85) {
            if ($Mode -eq 'jeu') {
                [void]$f.Add(@{ Id = 'gpu-limite'; Sev = 'warn'; Title = "La carte graphique est à fond ($($rep.Gpu) %) : c'est elle qui limite les FPS"; Text = $gtxt; Advice = "Normal en jeu si les FPS te conviennent. S'ils sont trop bas : baisse la qualité graphique ou la résolution, active DLSS / FSR, et vérifie que le pilote graphique est à jour."; Action = 'drivers' })
            } else {
                [void]$f.Add(@{ Id = 'gpu-occupe'; Sev = 'warn'; Title = "La carte graphique tourne presque à fond ($($rep.Gpu) %)"; Text = $gtxt; Advice = "Si c'est ton jeu, c'est normal. Si c'est un autre programme (navigateur, fond d'écran animé…), ferme-le. Un programme inconnu qui fait tourner la carte graphique en permanence peut être un mineur de cryptomonnaie : lance alors une analyse antivirus complète."; Action = 'taskmgr' })
            }
        }
        [void]$chk.Add(@{ Ok = ($rep.Gpu -lt 85); T = "Carte graphique : $($rep.Gpu) % d'utilisation" })
    }
    # Processeur bridé par le PC (chauffe ou alimentation)
    if ($null -ne $rep.Limit) {
        if ($rep.Limit -lt 75) {
            $bat = $null; try { $b = @(Get-CimInstance Win32_Battery -ErrorAction Stop) | Select-Object -First 1; if ($b) { $bat = ([int]$b.BatteryStatus -ne 2) } } catch {}
            $temp = $null; try { if ($sync.Sens -and $sync.Sens['cpu.temp']) { $temp = [math]::Round([double]$sync.Sens['cpu.temp']) } } catch {}
            $why = if ($bat) { "Le PC est sur batterie : Windows et le fabricant brident le processeur pour l'économiser." }
                   elseif ($temp -ge 90) { "Le processeur est à $temp °C : il ralentit pour ne pas surchauffer." }
                   else { "Il ralentit à cause de la chauffe ou d'une alimentation insuffisante (chargeur trop faible sur un portable, mode « silencieux » du logiciel du fabricant)." }
            [void]$f.Add(@{ Id = 'cpu-bride'; Sev = 'bad'; Title = "Le processeur est bridé : seulement $($rep.Limit) % de sa puissance autorisée"; Text = $why
                            Advice = $(if ($bat) { "Branche le chargeur d'origine pour jouer ou travailler." } else { "Dépoussière le PC (surtout le radiateur du processeur), vérifie que les ventilateurs tournent et que l'air circule. Sur un portable : chargeur d'origine branché, et mode « performance » dans le logiciel du fabricant. Si le PC a plus de 4-5 ans, changer la pâte thermique aide beaucoup." }); Action = '' })
        }
        [void]$chk.Add(@{ Ok = ($rep.Limit -ge 75); T = $(if ($rep.Limit -ge 75) { "Puissance du processeur : pas bridée pendant la mesure" } else { "Puissance du processeur : bridée à $($rep.Limit) %" }) })
    }
    # Pilote qui monopolise le processeur (interruptions)
    if ($dpc.Count) {
        if ($rep.Dpc -ge 6) {
            [void]$f.Add(@{ Id = 'pilote-interruptions'; Sev = 'warn'; Title = "Un pilote monopolise le processeur ($($rep.Dpc) % du temps en interruptions)"; Text = "Normalement moins de 2 %. Ça donne des micro-saccades, du son qui grésille et une souris qui accroche, même quand rien ne semble tourner."
                            Advice = "Le plus souvent : pilote réseau / Wi-Fi, son, USB ou carte graphique. Mets à jour les pilotes (bouton ci-dessous), puis débranche les périphériques USB un par un pour trouver le fautif."; Action = 'drivers' })
        }
        [void]$chk.Add(@{ Ok = ($rep.Dpc -lt 6); T = "Pilotes : $($rep.Dpc) % du temps en interruptions" + $(if ($rep.Dpc -lt 6) { ' (normal)' } else { '' }) })
    }
    # Place libre sur le disque de Windows
    try {
        $cd = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'" -ErrorAction Stop
        $fr = [double]$cd.FreeSpace; $pc = [math]::Round(100 * $fr / [math]::Max([double]1, [double]$cd.Size))
        # Peu de place en proportion ET en valeur absolue (voir Get-SystemDiskLevel), ou moins de 10 Go quelle que soit la taille du disque
        $lvl = Get-SystemDiskLevel $fr ([double]$cd.Size)
        $full = [bool]($lvl -or $fr -lt 10GB)
        if ($full) {
            [void]$f.Add(@{ Id = 'disque-plein'; Sev = $(if ($lvl -eq 'crit' -or $fr -lt 5GB) { 'bad' } else { 'warn' }); Title = "Le disque $env:SystemDrive est presque plein ($(Format-Size $fr) libres)"; Text = "Avec si peu de place libre, Windows ralentit et les mises à jour peuvent échouer."; Advice = "Regarde ce qui prend de la place et supprime ce qui ne sert plus (jeux finis, vieux téléchargements)."; Action = 'space' })
        }
        [void]$chk.Add(@{ Ok = -not $full; T = "Place libre sur $($env:SystemDrive) : $(Format-Size $fr) ($pc %)" })
    } catch {}
    # Causes de fond (réglages)
    try {
        $pw = Get-PowerStatus
        $saver = ($pw.Guid -eq 'a1841308-3541-4fab-bc81-f71556f20b4a' -or $pw.Name -match "(?i)économi|saver")
        if ($saver) { [void]$f.Add(@{ Id = 'economie'; Sev = 'warn'; Title = "Le PC est en mode « Économie d'énergie »"; Text = "Mode actuel : $($pw.Name)"; Advice = "Ce mode bride le processeur en permanence."; Action = 'balanced' }) }
        if ($pw.Name) { [void]$chk.Add(@{ Ok = -not $saver; T = "Mode d'alimentation : $($pw.Name)" }) }
        $mx = Get-CpuMaxState
        if ($null -ne $mx -and $mx -lt 100) { [void]$f.Add(@{ Id = 'cpumax'; Sev = 'warn'; Title = "Le processeur est bridé à $mx % de sa puissance"; Text = "Réglage du mode d'alimentation (souvent modifié par un logiciel « d'optimisation »)."; Advice = "Le remettre à 100 % rend toute sa puissance au processeur."; Action = 'cpumax' }) }
    } catch {}
    try {
        $cs = Get-CimStatic Win32_ComputerSystem -Quiet
        if (-not $cs.AutomaticManagedPagefile -and @(Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue).Count -eq 0 -and [double]$cs.TotalPhysicalMemory -lt 17GB) {
            [void]$f.Add(@{ Id = 'memoire-virtuelle'; Sev = 'warn'; Title = "La mémoire virtuelle de Windows est désactivée"; Text = "Le fichier d'échange a été désactivé (souvent par une astuce « d'optimisation »)."; Advice = "Quand la RAM est pleine, les jeux et logiciels plantent ou se ferment au lieu de ralentir un peu. Remets-la en automatique (réglage d'origine, redémarrage nécessaire)."; Action = 'pagefile' })
        }
    } catch {}
    $up = (Get-Date) - $os.LastBootUpTime
    if ($up.TotalDays -ge 7) { [void]$f.Add(@{ Id = 'redemarrage'; Sev = 'warn'; Title = "Le PC n'a pas redémarré depuis $([int]$up.TotalDays) jours"; Text = "« Arrêter » ne remet pas Windows à zéro (démarrage rapide) : seul « Redémarrer » le fait."; Advice = "Un redémarrage libère la mémoire et termine les mises à jour en attente."; Action = '' }) }
    [void]$chk.Add(@{ Ok = ($up.TotalDays -lt 7); T = $(if ($up.TotalDays -ge 1) { "Dernier redémarrage : il y a $([int]$up.TotalDays) jour(s)" } else { "Dernier redémarrage : il y a $([int]$up.TotalHours) heure(s)" }) })
    try { $nst = @(Get-StartupEntries | Where-Object { $_.Enabled }).Count; if ($nst -ge 10) { [void]$f.Add(@{ Id = 'demarrage'; Sev = 'warn'; Title = "$nst programmes se lancent au démarrage"; Text = "Ils ralentissent l'allumage et restent en fond toute la journée."; Advice = "Garde seulement ce que tu utilises tout le temps."; Action = 'startup' }) } } catch {}
    # Connexion (lag en ligne)
    $gw = Get-PingStats $gwS; $net = Get-PingStats $netS
    $rx = [double](& $avg $rxL); $tx = [double](& $avg $txL)
    $ad = $null; try { $ad = Get-ActiveAdapter } catch {}
    $wi = if ($ad -and $ad.Wifi) { Get-WifiInfo } else { @{ Signal = -1; Band = '' } }
    foreach ($x in @(Get-NetFindings $gw $net $rx $tx ([bool]($ad -and $ad.Wifi)) $wi)) { [void]$f.Add($x) }
    [void]$chk.Add((Get-PingLine $gw 'Connexion PC ↔ box'))
    [void]$chk.Add((Get-PingLine $net 'Connexion vers Internet'))
    $rep.Net = $net; $rep.Gw = $gw
    $rep.Findings = @($f.ToArray() | Sort-Object { if ($_.Sev -eq 'bad') { 0 } else { 1 } })
    $rep.Checked = $chk.ToArray()
    $sync.SlowReport = $rep
    Add-StatsEvent $(if ($Mode -eq 'jeu') { 'jeu' } else { 'lent' })
    if ($rep.Findings.Count) { foreach ($x in $rep.Findings) { Add-StatsEvent ("{0}:{1}" -f $(if ($Mode -eq 'jeu') { 'jeu' } else { 'lent' }), $x.Id) } }
    else { Add-StatsEvent $(if ($Mode -eq 'jeu') { 'jeu:rien' } else { 'lent:rien' }) }
    Log ("   ✔ Mesure terminée : processeur {0} %, mémoire {1} %, disque {2} %{3} · {4} piste(s) trouvée(s)." -f $rep.Cpu, $rep.Ram, $rep.Disk, $(if ($rep.GpuOk) { ", carte graphique $($rep.Gpu) %" } else { '' }), $rep.Findings.Count)
}

# « Ça lague en ligne » : la connexion mesurée pendant 1 minute (box, Internet, Wi-Fi, téléchargements, VPN)
function Get-LagReport([int]$Seconds = 60) {
    Step "Analyse de la connexion pendant $Seconds secondes : laisse tourner ton jeu ou Discord si c'est là que ça lague."
    $sync.SlowReport = $null
    $pg = New-Object System.Net.NetworkInformation.Ping
    $gwS = New-PingSeries (Get-GatewayIp); $netS = New-PingSeries '1.1.1.1'
    $rxL = New-Object System.Collections.ArrayList; $txL = New-Object System.Collections.ArrayList
    $null = Get-NetThroughput
    for ($i = 0; $i -lt $Seconds; $i++) {
        if ($sync.Cancel) { return }
        $sw = [Diagnostics.Stopwatch]::StartNew()
        Add-PingSample $gwS $pg; Add-PingSample $netS $pg
        if ($netS.Off -and $netS.Ip -eq '1.1.1.1') { $netS = New-PingSeries '8.8.8.8' }
        if ($i % 4 -eq 3) { $nt = Get-NetThroughput; [void]$rxL.Add($nt.Rx); [void]$txL.Add($nt.Tx) }
        $sync.Progress = [math]::Round(100 * ($i + 1) / $Seconds)
        $rest = 1000 - [int]$sw.ElapsedMilliseconds; if ($rest -gt 0) { Start-Sleep -Milliseconds $rest }
    }
    $gw = Get-PingStats $gwS; $net = Get-PingStats $netS
    $rx = 0.0; if ($rxL.Count) { $rx = [double](($rxL | Measure-Object -Average).Average) }
    $tx = 0.0; if ($txL.Count) { $tx = [double](($txL | Measure-Object -Average).Average) }
    $ad = $null; try { $ad = Get-ActiveAdapter } catch {}
    $wifi = [bool]($ad -and $ad.Wifi)
    $wi = if ($wifi) { Get-WifiInfo } else { @{ Signal = -1; Band = '' } }
    $f = New-Object System.Collections.ArrayList; $chk = New-Object System.Collections.ArrayList
    foreach ($x in @(Get-NetFindings $gw $net $rx $tx $wifi $wi)) { [void]$f.Add($x) }
    if ($wifi -and $wi.Band -like '2*' -and -not ($f | Where-Object { $_.Id -eq 'wifi-instable' }) -and $wi.Signal -ge 0 -and $wi.Signal -lt 70) {
        [void]$f.Add(@{ Id = 'wifi-24'; Sev = 'warn'; Title = "Connecté au Wi-Fi 2,4 GHz avec un signal moyen ($($wi.Signal) %)"; Text = "Le 2,4 GHz est plus lent et plus encombré (Wi-Fi des voisins, micro-ondes, Bluetooth)."; Advice = "Si ta box a un réseau 5 GHz (souvent le même nom avec « 5G »), connecte-toi dessus quand tu es proche de la box."; Action = '' })
    }
    # VPN par lequel passe la connexion
    $vpn = $false
    if ($ad -and "$($ad.Desc) $($ad.Name)" -match '(?i)tap-windows|wireguard|wintun|nordlynx|openvpn|proton|expressvpn|surfshark|cyberghost|hotspot shield|windscribe|mullvad|forticlient|anyconnect|vpn') {
        $vpn = $true
        [void]$f.Add(@{ Id = 'vpn'; Sev = 'warn'; Title = "Ta connexion passe par un VPN ($($ad.Desc))"; Text = "Un VPN fait faire un détour à tout ce que tu envoies et reçois : le ping monte."; Advice = "Coupe le VPN pour jouer, ou choisis un serveur en France / proche de chez toi."; Action = '' })
    }
    # Économie d'énergie de la carte réseau (cause classique de coupures en jeu sur un PC fixe)
    $laptop = $false; try { $laptop = [bool](@((Get-CimStatic Win32_SystemEnclosure -Quiet).ChassisTypes | Where-Object { $_ -in 8, 9, 10, 11, 14, 30, 31, 32 }).Count) } catch {}
    if ($ad -and -not $vpn) {
        $sl = Get-NetAdapterSleepState $ad.Name
        if ($sl -eq 'Enabled' -and -not $laptop) {
            [void]$f.Add(@{ Id = 'carte-veille'; Sev = 'warn'; Title = "Windows peut couper ta carte réseau pour économiser l'énergie"; Text = $ad.Desc; Advice = "Sur un PC fixe, c'est une cause classique de coupures de quelques secondes et de déconnexions de Discord ou des jeux."; Action = 'netpower'; Adapter = $ad.Name })
        }
        if ($sl) { [void]$chk.Add(@{ Ok = -not ($sl -eq 'Enabled' -and -not $laptop); T = $(if ($sl -eq 'Enabled') { "Carte réseau : Windows peut la mettre en veille" + $(if ($laptop) { ' (normal sur un portable)' } else { '' }) } else { "Carte réseau : jamais mise en veille par Windows" }) }) }
    }
    [void]$chk.Add((Get-PingLine $gw 'Connexion PC ↔ box'))
    [void]$chk.Add((Get-PingLine $net 'Connexion vers Internet'))
    if ($ad) { [void]$chk.Add(@{ Ok = $true; T = $(if ($wifi) { "Wi-Fi : " + $(if ($wi.Signal -ge 0) { "signal $($wi.Signal) %" } else { 'signal non lu' }) + $(if ($wi.Band) { ", $($wi.Band -replace '\.', ',') GHz" } else { '' }) } else { "Câble / carte réseau : $($ad.Desc)" }) }) }
    [void]$chk.Add(@{ Ok = -not ($rx -ge 3MB -or $tx -ge 1MB); T = ("Trafic pendant la mesure : {0}/s reçus, {1}/s envoyés" -f (Format-Size $rx), (Format-Size $tx)) })
    if (-not $vpn) { [void]$chk.Add(@{ Ok = $true; T = "VPN : aucun sur la connexion" }) }
    $rep = @{ Mode = 'lag'; Gw = $gw; Net = $net; Rx = $rx; Tx = $tx; Wifi = $wifi; Signal = $wi.Signal; Findings = @($f.ToArray() | Sort-Object { if ($_.Sev -eq 'bad') { 0 } else { 1 } }); Checked = $chk.ToArray(); Top = @() }
    $sync.SlowReport = $rep
    Add-StatsEvent 'lag'
    if ($rep.Findings.Count) { foreach ($x in $rep.Findings) { Add-StatsEvent "lag:$($x.Id)" } } else { Add-StatsEvent 'lag:rien' }
    Log ("   ✔ Mesure terminée : box {0}, Internet {1} · {2} piste(s) trouvée(s)." -f $(if ($gw.Ok) { "$($gw.Avg) ms" } else { 'non mesurée' }), $(if ($net.Ok) { "$($net.Avg) ms ±$($net.Jitter), $($net.Loss) % perdus" } else { 'non mesuré' }), $rep.Findings.Count)
}

# ---------------------------------------------------------------- Statistiques anonymes (compteurs seulement)
# Ce qui est envoyé : la version d'AEROX et des compteurs du genre « lent:memoire = 2 » ou « probleme:bsod = 1 »
# (types de problèmes trouvés, lenteurs non reconnues, réparations qui n'ont pas suffi). Jamais de nom, de nom du PC,
# de fichier, de chemin ni d'identifiant. Le relais additionne des nombres par mois. Désactivable dans l'onglet Aide.
# Clés vérifiées en respectant la casse (comme le relais) : minuscules, chiffres et tirets seulement.
# Envoi en un seul petit paquet, au plus toutes les 6 heures (et une fois par mois pour compter les PC actifs).
function ConvertTo-StatsId([string]$Id) { return (("$Id".ToLower() -replace '[^a-z0-9-]', '-') -replace '-+', '-').Trim('-') }
# Familles de compteurs que le relais accepte (le test tests/relais/relais.test.mjs vérifie que sa liste est identique à celle-ci
# et que chaque appel de Add-StatsEvent du logiciel en fait partie). Une nouvelle famille s'ajoute ici ET dans relais/worker.js.
$script:StatsPrefixes = @('probleme', 'lent', 'jeu', 'lag', 'diag', 'erreur', 'pascorrige', 'corrige', 'echec', 'inconnu', 'symptome', 'partage', 'maj')
function Test-StatsKey([string]$Key) {
    return ($Key -cmatch '^[a-z]+(:[a-z0-9][a-z0-9-]{0,39})?$') -and ($script:StatsPrefixes -ccontains $Key.Split(':')[0])
}
function Add-StatsEvent([string]$Key) {
    try {
        $q = $AppInfo.StatsQueue
        if ($AppInfo.StatsOff -or $null -eq $q -or -not (Test-StatsKey $Key)) { return }
        [System.Threading.Monitor]::Enter($q.SyncRoot)
        try { if ($q.Count -lt 300) { [void]$q.Add($Key) }; Save-StatsQueue } finally { [System.Threading.Monitor]::Exit($q.SyncRoot) }
    } catch {}
}
function Save-StatsQueue {
    try { [IO.File]::WriteAllLines((Join-Path $AppInfo.LogDir 'stats-attente.txt'), [string[]]@($AppInfo.StatsQueue.ToArray())) } catch {}
}
function Read-StatsQueue {
    $q = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
    try {
        $p = Join-Path $AppInfo.LogDir 'stats-attente.txt'
        if (Test-Path -LiteralPath $p) { foreach ($l in [IO.File]::ReadAllLines($p)) { if ($q.Count -lt 300 -and (Test-StatsKey $l)) { [void]$q.Add($l) } } }
    } catch {}
    return ,$q
}
function Send-Stats([switch]$Force) {
    if ($AppInfo.StatsOff -or $null -eq $AppInfo.StatsQueue -or $null -eq $AppInfo.StatsLock) { return }
    if (-not [System.Threading.Monitor]::TryEnter($AppInfo.StatsLock)) { return }
    try {
        if (-not $sync.BugRelay) { Find-BugRelay }
        $relay = "$($sync.BugRelay)".TrimEnd('/')
        if (-not $relay) { return }
        $stamp = Join-Path $AppInfo.LogDir 'stats-envoi.txt'
        $last = $null; $lastMonth = ''; $lastVer = ''
        if (Test-Path -LiteralPath $stamp) {
            $p = ([IO.File]::ReadAllText($stamp)).Trim().Split('|')
            try { $last = [datetime]::ParseExact($p[0], 's', [Globalization.CultureInfo]::InvariantCulture) } catch {}
            if ($p.Count -gt 1) { $lastMonth = $p[1] }
            if ($p.Count -gt 2) { $lastVer = $p[2] }
        }
        $month = (Get-Date).ToString('yyyy-MM')
        $newMonth = ($lastMonth -ne $month)
        # Une fois par PC et par version : « maj:2-5-3 » (combien de PC ont reçu chaque version, rien d'autre)
        $newVer = ("$lastVer" -ne "$($AppInfo.Version)")
        $q = $AppInfo.StatsQueue
        $keys = @()
        [System.Threading.Monitor]::Enter($q.SyncRoot); try { $keys = @($q.ToArray()) } finally { [System.Threading.Monitor]::Exit($q.SyncRoot) }
        if (-not $newMonth -and -not $newVer -and -not $keys.Count) { return }
        if (-not $newMonth -and -not $newVer -and -not $Force -and $last -and ((Get-Date) - $last).TotalHours -lt 6) { return }
        # Le relais sait-il recevoir les statistiques ? Sinon les compteurs attendent (rien n'est envoyé ailleurs)
        $cap = Invoke-RestMethod -Uri "$relay/stats" -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop
        if ($cap.aerox -ne 'stats' -or -not $cap.ok) { return }
        $ev = @{}
        foreach ($k in $keys) { if ($ev.ContainsKey($k)) { if ($ev[$k] -lt 50) { $ev[$k]++ } } elseif ($ev.Count -lt 59) { $ev[$k] = 1 } }
        if ($newVer -and "$($AppInfo.Version)" -match '^\d+(\.\d+){1,3}\z') { $ev['maj:' + ("$($AppInfo.Version)" -replace '\.', '-')] = 1 }
        $body = @{ v = "$($AppInfo.Version)"; nouveau_mois = [bool]$newMonth; ev = $ev } | ConvertTo-Json -Compress
        $r = Invoke-RestMethod -Uri "$relay/stats" -Method Post -Body ([Text.Encoding]::UTF8.GetBytes($body)) -ContentType 'application/json; charset=utf-8' -Headers @{ 'X-Aerox' = '1' } -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
        if ($r.ok) {
            [System.Threading.Monitor]::Enter($q.SyncRoot)
            try { $q.RemoveRange(0, [math]::Min($keys.Count, $q.Count)); Save-StatsQueue } finally { [System.Threading.Monitor]::Exit($q.SyncRoot) }
            [IO.File]::WriteAllText($stamp, ("{0}|{1}|{2}" -f (Get-Date).ToString('s'), $month, $AppInfo.Version))
            $AppInfo.StatsLastError = ''
        } else { $AppInfo.StatsLastError = "réponse du relais : $($r | ConvertTo-Json -Compress)" }
    } catch { $AppInfo.StatsLastError = $_.Exception.Message } finally { [System.Threading.Monitor]::Exit($AppInfo.StatsLock) }
}

# Diagnostic : causes de fond des lenteurs (réglages), sans mesure longue
function Test-Performance {
    $laptop = $false
    try { $laptop = [bool](@((Get-CimStatic Win32_SystemEnclosure -Quiet).ChassisTypes | Where-Object { $_ -in 8, 9, 10, 11, 14, 30, 31, 32 }).Count) } catch {}
    $found = $false
    $pw = Get-PowerStatus
    if (-not $laptop -and ($pw.Guid -eq 'a1841308-3541-4fab-bc81-f71556f20b4a' -or $pw.Name -match "(?i)économi|saver")) {
        Add-Issue -Id 'powersaver' -Sev 'warn' -Title "Le PC est en mode « Économie d'énergie »" -Detail "Mode actuel : $($pw.Name)" `
            -Cause "Ce mode bride le processeur en permanence pour consommer moins : sur un PC fixe, ça n'a aucun intérêt." -Effect "Tout est plus lent : démarrage, logiciels, jeux." `
            -FixLabel "Passer en mode Équilibré" -FixAction 'Set-BalancedPower'
        $found = $true
    }
    $mx = Get-CpuMaxState
    if ($null -ne $mx -and $mx -lt 100) {
        Add-Issue -Id 'cpumax' -Sev 'warn' -Title "Le processeur est bridé à $mx % de sa puissance" -Detail "Réglage « état maximal du processeur » du mode d'alimentation" `
            -Cause "Ce réglage a été baissé (souvent par un logiciel « d'optimisation » ou pour limiter la chauffe)." -Effect "Le processeur ne peut jamais donner toute sa puissance : le PC rame dès qu'il travaille." `
            -FixLabel "Remettre à 100 %" -FixAction 'Set-CpuMaxState 100' -Confirm "Le processeur pourra de nouveau utiliser 100 % de sa puissance sur secteur.`n`nAnnulable dans l'historique des changements."
        $found = $true
    }
    try {
        $cs = Get-CimStatic Win32_ComputerSystem -Quiet
        $pf = @(Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue)
        if (-not $cs.AutomaticManagedPagefile -and $pf.Count -eq 0 -and [double]$cs.TotalPhysicalMemory -lt 17GB) {
            Add-Issue -Id 'pagefile' -Sev 'warn' -Title "La mémoire virtuelle de Windows est désactivée" -Detail ("{0} de RAM" -f (Format-Size ([double]$cs.TotalPhysicalMemory))) `
                -Cause "Le fichier d'échange a été désactivé (souvent par une astuce « d'optimisation » trouvée sur Internet)." -Effect "Quand la RAM est pleine, les logiciels plantent ou se ferment au lieu de ralentir un peu." `
                -FixLabel "Remettre en automatique" -FixAction 'Enable-AutoPagefile' -Confirm "Windows gérera de nouveau la mémoire virtuelle lui-même (réglage d'origine). Un redémarrage sera nécessaire."
            $found = $true
        }
    } catch {}
    if (-not $found) { Add-Ok "Réglages de performance : rien ne bride le PC" }
}

# ---------------------------------------------------------------- Infos d'erreurs connues
function Get-WuErrorInfo([string]$Code) {
    switch -Regex ($Code) {
        '(?i)0x80070643'                       { return @{ Cause = "Les fichiers de mise à jour stockés par Windows sont endommagés, ou un composant (.NET, partition de récupération) bloque l'installation."; Fix = 'Reset-WindowsUpdate; Update-Windows' } }
        '(?i)0x800F0922'                       { return @{ Cause = "Windows n'a pas pu finir l'installation : souvent un VPN actif ou pas assez de place réservée au système."; Fix = 'Reset-WindowsUpdate; Update-Windows' } }
        '(?i)0x80073712|0x800F081F|0x800F0831' { return @{ Cause = "Des composants de Windows sont abîmés ou manquants : la mise à jour ne trouve pas ce dont elle a besoin."; Fix = 'Repair-System; Update-Windows' } }
        '(?i)0x80070070'                       { return @{ Cause = "Il n'y a pas assez d'espace sur le disque pour installer la mise à jour."; Fix = 'Clear-TempFiles; Clear-WindowsUpdateCache; Update-Windows' } }
        '(?i)0x80070002|0x80070003'            { return @{ Cause = "Des fichiers de mise à jour sont manquants (téléchargement incomplet)."; Fix = 'Reset-WindowsUpdate; Update-Windows' } }
        '(?i)0x8024'                           { return @{ Cause = "Windows Update n'a pas pu télécharger ou préparer la mise à jour (connexion coupée ou service bloqué)."; Fix = 'Reset-WindowsUpdate; Update-Windows' } }
        default                                { return @{ Cause = "Windows Update a rencontré une erreur pendant l'installation."; Fix = 'Reset-WindowsUpdate; Update-Windows' } }
    }
}
$script:BugChecks = @{
    '0x0000000A' = @('IRQL_NOT_LESS_OR_EQUAL', "Un pilote (souvent réseau, audio ou graphique) a accédé à la mémoire au mauvais moment. Ça peut aussi venir de la RAM ou d'un overclocking instable.", 'drv')
    '0x000000D1' = @('DRIVER_IRQL_NOT_LESS_OR_EQUAL', "Un pilote de périphérique est fautif : le plus souvent la carte réseau / Wi-Fi ou la carte graphique.", 'drv')
    '0x0000001A' = @('MEMORY_MANAGEMENT', "Problème de mémoire vive : barrette de RAM défectueuse, profil XMP/EXPO instable ou pilote fautif.", 'hw')
    '0x0000003B' = @('SYSTEM_SERVICE_EXCEPTION', "Un pilote ou un fichier système a planté (souvent le pilote graphique ou un antivirus tiers).", 'drv')
    '0x00000050' = @('PAGE_FAULT_IN_NONPAGED_AREA', "Windows a voulu lire une zone mémoire invalide : RAM, pilote ou fichier système abîmé.", 'hw')
    '0x0000007E' = @('SYSTEM_THREAD_EXCEPTION_NOT_HANDLED', "Un pilote a planté, souvent juste après une mise à jour de pilote.", 'drv')
    '0x0000007F' = @('UNEXPECTED_KERNEL_MODE_TRAP', "Problème matériel (RAM, surchauffe) ou pilote défaillant.", 'hw')
    '0x0000009F' = @('DRIVER_POWER_STATE_FAILURE', "Un pilote gère mal la mise en veille ou le réveil du PC.", 'drv')
    '0x00000116' = @('VIDEO_TDR_FAILURE', "La carte graphique a cessé de répondre : pilote graphique, surchauffe ou overclocking.", 'gpu')
    '0x00000117' = @('VIDEO_TDR_TIMEOUT_DETECTED', "La carte graphique a cessé de répondre : pilote graphique, surchauffe ou overclocking.", 'gpu')
    '0x00000124' = @('WHEA_UNCORRECTABLE_ERROR', "Le matériel a signalé une erreur grave : processeur, RAM, surchauffe ou overclocking / undervolting instable.", 'hw')
    '0x00000133' = @('DPC_WATCHDOG_VIOLATION', "Un pilote a bloqué le système trop longtemps, souvent celui du SSD ou un pilote ancien.", 'drv')
    '0x00000139' = @('KERNEL_SECURITY_CHECK_FAILURE', "Un pilote incompatible, ou des fichiers système / la RAM abîmés.", 'drv')
    '0x000000EF' = @('CRITICAL_PROCESS_DIED', "Un processus vital de Windows s'est arrêté : fichiers système abîmés ou disque défaillant.", 'sys')
}

# ---------------------------------------------------------------- DIAGNOSTIC
function Add-Issue {
    param([string]$Id, [string]$Sev, [string]$Title, [string]$Detail, [string]$Code, [string]$Cause, [string]$Effect,
          [string]$FixLabel, [string]$FixAction, [string]$Confirm, [string[]]$Steps, [string]$UiFix, [switch]$OpenOnly)
    # Alerte que l'utilisateur a choisi de ne plus voir (jamais pour la sécurité) : rangée à part, hors de la note
    if ($Id -and $script:CurrentCat -ne 'Sécurité' -and @($AppInfo.IgnoredIssues) -contains $Id) {
        if ($null -ne $script:IgnoredList) { [void]$script:IgnoredList.Add(@{ Id = $Id; Sev = $Sev; Cat = $script:CurrentCat; Title = $Title; Detail = $Detail }) }
        return
    }
    [void]$script:Issues.Add(@{ Id = $Id; Sev = $Sev; Cat = $script:CurrentCat; Title = $Title; Detail = $Detail; Code = $Code; Cause = $Cause; Effect = $Effect;
                                FixLabel = $FixLabel; FixAction = $FixAction; Confirm = $Confirm; Steps = $Steps; UiFix = $UiFix; OpenOnly = [bool]$OpenOnly; Status = 'open' })
}
function Add-Ok([string]$Text) { [void]$script:OkList.Add($Text) }

# Tous les disques avec une lettre : internes (C:, D:…) et externes (disque USB, clé USB, carte SD). Windows d'abord.
function Get-DriveList {
    $l = @(Get-CimInstance Win32_LogicalDisk -OperationTimeoutSec 4 -ErrorAction SilentlyContinue | Where-Object { ($_.DriveType -eq 3 -or $_.DriveType -eq 2) -and [double]$_.Size -gt 0 })
    return @($l | Sort-Object @{ Expression = { $_.DeviceID -ne $env:SystemDrive } }, @{ Expression = { $_.DeviceID } } | ForEach-Object {
        $kind = if ($_.DeviceID -eq $env:SystemDrive) { 'Windows' } elseif ($_.DriveType -eq 2) { 'amovible' } else { '' }
        @{ Id = $_.DeviceID; Name = "$($_.VolumeName)".Trim(); Free = [double]$_.FreeSpace; Size = [double]$_.Size; Pct = [math]::Round([double]$_.FreeSpace / [double]$_.Size * 100); Kind = $kind; Removable = ($_.DriveType -eq 2) }
    })
}
# Disque de Windows presque plein ? Le pourcentage seul trompe (14 % libres sur 2 To = 280 Go, ce n'est pas « presque plein »),
# et l'espace seul aussi : il faut peu de place en proportion ET en valeur absolue.
# 'crit' : moins de 10 % ET moins de 20 Go ; 'warn' : moins de 15 % ET moins de 50 Go ; sinon ''.
function Get-SystemDiskLevel([double]$Free, [double]$Size) {
    if ($Size -le 0) { return '' }
    $pct = [math]::Round($Free / $Size * 100)
    if ($pct -lt 10 -and $Free -lt 20GB) { return 'crit' }
    if ($pct -lt 15 -and $Free -lt 50GB) { return 'warn' }
    return ''
}
# Autres disques (jeux, fichiers) : plein si moins de 5 % ET moins de 20 Go
function Test-OtherDiskFull([double]$Free, [double]$Size) {
    if ($Size -le 0) { return $false }
    return ([math]::Round($Free / $Size * 100) -lt 5 -and $Free -lt 20GB)
}
function Test-Storage {
    $d = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
    $pct = [math]::Round($d.FreeSpace / $d.Size * 100)
    $detail = "{0} libres sur {1} ({2} %)" -f (Format-Size $d.FreeSpace), (Format-Size $d.Size), $pct
    $level = Get-SystemDiskLevel ([double]$d.FreeSpace) ([double]$d.Size)
    if ($level) {
        $tmp = [double]0; foreach ($loc in Get-TempLocations) { $tmp += Get-FolderSize $loc.Path }
        $wu  = Get-FolderSize "$env:SystemRoot\SoftwareDistribution\Download"
        $rb  = Get-FolderSize ("{0}\`$Recycle.Bin" -f $env:SystemDrive)
        $parts = @()
        if ($tmp -gt 100MB) { $parts += "$(Format-Size $tmp) de fichiers temporaires" }
        if ($wu  -gt 100MB) { $parts += "$(Format-Size $wu) de mises à jour déjà installées" }
        if ($rb  -gt 100MB) { $parts += "$(Format-Size $rb) dans la corbeille" }
        $cause = if ($parts) { ($parts -join ', ') + " prennent de la place pour rien." } else { "Le disque est rempli par tes fichiers, jeux et logiciels." }
        Add-Issue -Id 'disk' -Sev $level -Title "Le disque $env:SystemDrive est presque plein" -Detail $detail -Cause $cause `
            -Effect "Avec si peu de place libre, Windows ralentit et les mises à jour peuvent échouer." `
            -FixLabel "Libérer de la place" -UiFix 'freespace' `
            -Steps @("Clique sur « Libérer de la place » (bouton vert) : tout ce qui est sans risque est déjà coché, tu ajoutes les jeux et logiciels que tu n'utilises plus, et AEROX enchaîne tout.", "Pour voir tes plus gros dossiers et fichiers perso : « Voir tous les dossiers » dans la même fenêtre.", "Désinstalle les jeux et logiciels que tu n'utilises plus, déplace vidéos et photos sur un autre disque.")
    } else { Add-Ok "Disque $env:SystemDrive : $detail" }
    Log "   • Disque $env:SystemDrive (Windows) : $detail"
    # Les autres disques : internes et externes (USB), chacun affiché ; alerte si un disque interne ou externe fixe est plein
    foreach ($o in @(Get-DriveList | Where-Object { $_.Id -ne $env:SystemDrive })) {
        $lbl = "{0}{1}{2}" -f $o.Id, $(if ($o.Name) { " ($($o.Name))" } else { '' }), $(if ($o.Removable) { ', amovible' } else { '' })
        $det = "{0} libres sur {1} ({2} %)" -f (Format-Size $o.Free), (Format-Size $o.Size), $o.Pct
        Log "   • Disque $lbl : $det"
        if (-not $o.Removable -and (Test-OtherDiskFull $o.Free $o.Size)) {
            Add-Issue -Id "disk$($o.Id)" -Sev 'warn' -Title "Le disque $($o.Id) est plein" -Detail $det `
                -Cause "Ce disque n'a presque plus de place." -Effect "Les jeux ou fichiers dessus ne pourront plus se mettre à jour ni s'enregistrer." `
                -Steps @("Supprime ou déplace ce dont tu n'as plus besoin sur ce disque.", "Pour les jeux : désinstalle ceux auxquels tu ne joues plus depuis Steam / Epic.")
        } else { Add-Ok "Disque $lbl : $det" }
    }
}

# Mémoire vive INSTALLÉE (somme des barrettes) ; 0 si Windows ne la donne pas. « TotalPhysicalMemory » est ce que Windows peut
# UTILISER : il en retire la mémoire réservée au matériel (mémoire vidéo d'un processeur graphique intégré, par exemple).
# Un PC avec 8 Go installés peut y afficher 7,4 Go, voire 6 Go.
function Get-InstalledRam {
    try {
        $sum = [double]0
        foreach ($m in @(Get-CimStatic Win32_PhysicalMemory -Quiet)) { $sum += [double]$m.Capacity }
        return $sum
    } catch { return [double]0 }
}
# Peu de mémoire vive ? Mémoire installée sous 7,5 Go. Si Windows ne donne pas les barrettes (machine virtuelle, certains PC) :
# seulement si ce que Windows peut utiliser est sous 5,5 Go (jamais pour un PC de 8 Go dont une partie est réservée au matériel).
function Test-LowRam([double]$Installed, [double]$Usable) {
    if ($Installed -gt 0) { return ($Installed -lt 7.5GB) }
    return ($Usable -gt 0 -and $Usable -lt 5.5GB)
}
function Test-Memory {
    $os = Get-CimInstance Win32_OperatingSystem; $cs = Get-CimStatic Win32_ComputerSystem -Quiet
    $total = [double]$cs.TotalPhysicalMemory
    $installed = Get-InstalledRam
    $shown = if ($installed -gt 0) { $installed } else { $total }
    $pct = [math]::Round((1 - ([double]$os.FreePhysicalMemory * 1KB) / $total) * 100)
    $issue = $false
    if ($pct -ge 85) {
        $top = Get-Process -ErrorAction SilentlyContinue | Group-Object ProcessName | ForEach-Object {
            [pscustomobject]@{ Name = $_.Name; Mem = ($_.Group | Measure-Object WorkingSet64 -Sum).Sum } } | Sort-Object Mem -Descending | Select-Object -First 3
        $list = ($top | ForEach-Object { "{0} ({1})" -f $_.Name, (Format-Size $_.Mem) }) -join ', '
        Add-Issue -Id 'ram' -Sev 'warn' -Title "La mémoire est presque pleine ($pct %)" -Detail ("{0} au total" -f (Format-Size $total)) `
            -Cause "Les logiciels qui en prennent le plus en ce moment : $list." -Effect "Le PC rame, les jeux saccadent et des logiciels peuvent se fermer tout seuls." `
            -Steps @("Ferme les logiciels et onglets de navigateur dont tu n'as pas besoin.", "Redémarre le PC si ça fait longtemps.", "Désactive les programmes inutiles au démarrage (onglet Performances).")
        $issue = $true
    }
    if (Test-LowRam $installed $total) {
        Add-Issue -Id 'ramsize' -Sev 'warn' -Title "Peu de mémoire vive (moins de 8 Go)" -Detail ("{0} installés" -f (Format-Size $shown)) `
            -Cause "Windows 11 et les logiciels actuels ont besoin d'au moins 8 Go pour être à l'aise." -Effect "Le PC sera vite lent dès que plusieurs logiciels sont ouverts." `
            -Steps @("Évite d'ouvrir trop de logiciels en même temps.", "Si le PC le permet, ajoute une barrette de RAM (c'est souvent peu cher).")
        $issue = $true
    }
    if (-not $issue) { Add-Ok ("Mémoire : {0}, utilisation normale ({1} %)" -f (Format-Size $shown), $pct) }
}

# Fin de support de Windows 11, version par version (Microsoft Lifecycle) : Famille / Pro = 24 mois, Entreprise / Éducation = 36 mois.
# Dates = « Patch Tuesday » de la fin du support (dernière mise à jour de sécurité ce jour-là). À compléter à chaque nouvelle version de Windows.
$script:Win11Versions = @(
    @{ Build = 22000; Name = '21H2'; Std = [datetime]'2023-10-10'; Long = [datetime]'2024-10-08' }
    @{ Build = 22621; Name = '22H2'; Std = [datetime]'2024-10-08'; Long = [datetime]'2025-10-14' }
    @{ Build = 22631; Name = '23H2'; Std = [datetime]'2025-11-11'; Long = [datetime]'2026-11-10' }
    @{ Build = 26100; Name = '24H2'; Std = [datetime]'2026-10-13'; Long = [datetime]'2027-10-12' }
    @{ Build = 26200; Name = '25H2'; Std = [datetime]'2027-10-12'; Long = [datetime]'2028-10-10' }
)
# Etat du support d'une version de Windows 11 : 'ok' (encore mise à jour), 'ended' (plus de correctifs de sécurité) ou 'unknown'
# (serveur, édition à support long LTSC, version préliminaire ou plus récente que la table : aucun avis, jamais de fausse alerte).
function Get-Win11Support([int]$Build, [string]$Caption, [datetime]$Today = (Get-Date)) {
    $r = @{ State = 'unknown'; Name = ''; End = $null; Latest = $script:Win11Versions[$script:Win11Versions.Count - 1].Name }
    if ("$Caption" -match '(?i)server|serveur|LTSC|LTSB') { return $r }
    $v = @($script:Win11Versions | Where-Object { $_.Build -eq $Build }) | Select-Object -First 1
    if (-not $v) { return $r }
    # Entreprise / Éducation : 36 mois (« Pro Education » et « Pro for Workstations » restent à 24 mois)
    $long = ("$Caption" -match '(?i)entreprise|enterprise') -or ("$Caption" -match '(?i)(?<!pro\s)(éducation|education)')
    $r.Name = $v.Name
    $r.End = if ($long) { $v.Long } else { $v.Std }
    $r.State = if ($Today.Date -gt ([datetime]$r.End).Date) { 'ended' } else { 'ok' }
    return $r
}

function Test-SystemState {
    $os = Get-CimInstance Win32_OperatingSystem
    $build = [int]$os.BuildNumber
    if ($build -lt 22000 -and "$($os.Caption)" -notmatch '(?i)server|serveur') {
        Add-Issue -Id 'win10' -Sev 'warn' -Title "Windows 10 n'a plus de mises à jour de sécurité" -Detail "$($os.Caption) (build $build)" `
            -Cause "Microsoft a arrêté le support de Windows 10 le 14 octobre 2025 (sauf abonnement aux mises à jour étendues ESU)." `
            -Effect "Les nouvelles failles de sécurité ne sont plus corrigées sur ce PC." -FixLabel "Ouvrir Windows Update" -FixAction 'Open-WindowsUpdate' -OpenOnly `
            -Steps @("Dans Windows Update, regarde si ton PC peut passer à Windows 11 : la mise à niveau est gratuite.", "Si le PC n'est pas compatible, Windows Update propose de s'inscrire aux mises à jour étendues (ESU).")
    } else {
        $sup = Get-Win11Support $build "$($os.Caption)"
        if ($sup.State -eq 'ended') {
            Add-Issue -Id 'win11old' -Sev 'warn' -Title "Ta version de Windows 11 n'est plus prise en charge" -Detail ("{0} : version {1} (build {2}), support terminé le {3}" -f $os.Caption, $sup.Name, $build, (Format-Date $sup.End)) `
                -Cause ("Microsoft ne publie plus de correctifs de sécurité pour Windows 11 {0} (fin du support le {1})." -f $sup.Name, (Format-Date $sup.End)) `
                -Effect "Les nouvelles failles de sécurité ne sont plus corrigées sur ce PC." -FixLabel "Ouvrir Windows Update" -FixAction 'Open-WindowsUpdate' -OpenOnly `
                -Steps @(("Dans Windows Update, installe la « mise à jour des fonctionnalités » proposée (version {0} ou plus récente)." -f $sup.Latest), "Si Windows Update ne la propose pas, redémarre le PC puis clique sur « Rechercher des mises à jour ».")
        } elseif ($sup.State -eq 'ok') {
            Add-Ok ("{0} : version {1} (build {2}), prise en charge jusqu'au {3}" -f $os.Caption, $sup.Name, $build, (Format-Date $sup.End))
        } else { Add-Ok "$($os.Caption) (build $build)" }
    }

    $up = (Get-Date) - $os.LastBootUpTime
    $pending = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
               (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
    if ($pending) {
        Add-Issue -Id 'pending' -Sev 'warn' -Title "Un redémarrage est en attente" -Detail "Des mises à jour attendent pour se terminer" `
            -Cause "Windows a installé des mises à jour qui ne s'appliquent qu'au redémarrage." -Effect "Tant que le PC n'a pas redémarré, ces correctifs ne sont pas actifs." `
            -FixLabel "Redémarrer maintenant" -FixAction 'Request-Reboot'
    } elseif ($up.TotalDays -ge 7) {
        Add-Issue -Id 'uptime' -Sev 'warn' -Title "Le PC n'a pas redémarré depuis $($up.Days) jours" -Detail ("Allumé depuis {0} j {1} h" -f $up.Days, $up.Hours) `
            -Cause "« Arrêter » ne remet pas Windows à zéro à cause du démarrage rapide : seul « Redémarrer » le fait." `
            -Effect "La mémoire se remplit, des bugs bizarres apparaissent et certaines mises à jour attendent." -FixLabel "Redémarrer maintenant" -FixAction 'Request-Reboot' `
            -Steps @("Enregistre ce que tu as en cours.", "Démarrer > Marche/Arrêt > « Redémarrer » (pas « Arrêter »).", "À faire au moins une fois par semaine.")
    } else { Add-Ok ("Redémarré récemment (il y a {0} j)" -f $up.Days) }

    try {
        $lic = Get-CimInstance SoftwareLicensingProduct -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL" -ErrorAction Stop
        if (@($lic | Where-Object { $_.LicenseStatus -eq 1 }).Count -gt 0) { Add-Ok "Windows est activé" }
        else {
            Add-Issue -Id 'activation' -Sev 'warn' -Title "Windows n'est pas activé" -Detail "Licence non valide ou non trouvée" `
                -Cause "Windows ne trouve pas de licence valide pour ce PC (changement de matériel, réinstallation ou clé non valide)." `
                -Effect "Certaines options de personnalisation sont bloquées et un message s'affiche en permanence." -FixLabel "Ouvrir l'activation" -FixAction "Open-WinUri 'ms-settings:activation'" -OpenOnly `
                -Steps @("Ouvre Paramètres > Système > Activation.", "Clique sur « Résolution des problèmes » si tu avais une licence avant.", "Sinon, une licence s'achète sur le Microsoft Store.")
        }
    } catch {}
}

# Après une réparation de plantages / écrans bleus, seuls les NOUVEAUX comptent (les anciens restent dans l'historique
# de Windows : sans ça, la vérification juste après la réparation les retrouvait toujours)
# Décrochages de la carte graphique : toutes les traces que Windows garde, regroupées par incident
function Merge-GpuResets($Events) {
    # Un même décrochage laisse plusieurs traces (événement, rapport d'erreur, fichier) : regroupées à 2 minutes près
    $out = New-Object System.Collections.ArrayList
    foreach ($e in @($Events | Where-Object { $_ -and $_.Time } | Sort-Object { $_.Time })) {
        $last = if ($out.Count) { $out[$out.Count - 1] } else { $null }
        if ($last -and ($e.Time - $last.Time).TotalMinutes -le 2) { if ($last.Srcs -notcontains $e.Src) { $last.Srcs = @($last.Srcs) + $e.Src } }
        else { [void]$out.Add(@{ Time = [datetime]$e.Time; Srcs = @($e.Src) }) }
    }
    return $out.ToArray()
}
function Get-GpuResets([datetime]$Since) {
    $ev = New-Object System.Collections.ArrayList
    foreach ($e in @(Get-EventsSafe @{ LogName = 'System'; ProviderName = 'Display'; Id = 4101; StartTime = $Since } 300)) { [void]$ev.Add(@{ Time = $e.TimeCreated; Src = 'pilote relancé (4101)' }) }
    foreach ($pv in 'nvlddmkm', 'amdkmdag', 'amdwddmg', 'atikmdag', 'igfx', 'igfxn') {
        foreach ($e in @(Get-EventsSafe @{ LogName = 'System'; ProviderName = $pv; Level = 2; StartTime = $Since } 300)) { [void]$ev.Add(@{ Time = $e.TimeCreated; Src = "erreur $pv ($($e.Id))" }) }
    }
    # Rapports « LiveKernelEvent » de Windows : 141 / 117 = la carte graphique ne répondait plus
    foreach ($e in @(Get-EventsSafe @{ LogName = 'Application'; ProviderName = 'Windows Error Reporting'; Id = 1001; StartTime = $Since } 400)) {
        $v = @($e.Properties | ForEach-Object { "$($_.Value)" })
        $hit = ($v.Count -gt 5 -and $v[2] -eq 'LiveKernelEvent' -and $v[5] -match '^(141|117|1a1|1a8)$')
        if (-not $hit) { try { $m = "$($e.Message)"; $hit = ($m -match 'LiveKernelEvent' -and $m -match '(?m)P1\s*:\s*(141|117|1a1|1a8)\b') } catch {} }
        if ($hit) { [void]$ev.Add(@{ Time = $e.TimeCreated; Src = 'rapport LiveKernelEvent' }) }
    }
    try {
        foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $env:SystemRoot 'LiveKernelReports\WATCHDOG') -Filter '*.dmp' -File -ErrorAction Stop | Where-Object { $_.LastWriteTime -ge $Since })) {
            [void]$ev.Add(@{ Time = $f.LastWriteTime; Src = 'fichier WATCHDOG' })
        }
    } catch {}
    return @(Merge-GpuResets $ev.ToArray())
}
function Get-StabilitySince([string]$Id, [datetime]$Default) {
    try { $h = $AppInfo.StabilityFixAt; if ($h -and $h[$Id]) { $f = [datetime]$h[$Id]; if ($f -gt $Default) { return $f } } } catch {}
    return $Default
}
# ---------------------------------------------------------------- Écrans bleus : trouver le coupable
# Les rapports de plantage de Windows (C:\Windows\Minidump) gardent les pilotes présents sur la pile au moment du
# plantage : le premier pilote qui n'est pas de Microsoft est presque toujours le fautif (comme BlueScreenView).
$script:BsodCore = '(?i)^(ntoskrnl|ntkrnl\w*|hal\w*|pshed|kd\w*|werkernel|ci|clipsp|cng|ksecdd|msrpc|tm|clfs|fltmgr|wdf01000|wdfldr|acpi|pci|volmgr|volmgrx|mountmgr|partmgr)\.(exe|dll|sys)$'
function Get-DriverFileInfo([string]$Name, [hashtable]$Paths) {
    $p = $Paths[$Name.ToLowerInvariant()]
    if (-not $p) { foreach ($d in "$env:SystemRoot\System32\drivers", "$env:SystemRoot\System32") { $c = Join-Path $d $Name; if (Test-Path -LiteralPath $c) { $p = $c; break } } }
    $r = @{ Name = $Name; Company = ''; Desc = ''; Ms = $false }
    if ($p -and (Test-Path -LiteralPath $p)) {
        try { $v = [Diagnostics.FileVersionInfo]::GetVersionInfo($p); $r.Company = "$($v.CompanyName)".Trim(); $r.Desc = "$($v.FileDescription)".Trim() } catch {}
    }
    $r.Ms = ($r.Company -match '(?i)^microsoft') -or (-not $r.Company -and $Name -match $script:BsodCore)
    return $r
}
function Get-BsodKind($D) {
    $t = "$($D.Name) $($D.Company) $($D.Desc)"
    if ($t -match '(?i)nvlddmkm|amdkmdag|atikmdag|amdkmpfd|igdkmd|igfx|dxgkrnl|dxgmms|win32k|basicdisplay|graphics|display') { return 'gpu' }
    if ($t -match '(?i)\bvgk|easyanticheat|bedaisy|battleye|faceit|mhyprot|xigncode|nprotect|ricochet|anti.?cheat') { return 'anticheat' }
    if ($t -match '(?i)avast|avg|kaspersky|bitdefender|norton|symantec|mcafee|eset|malwarebytes|sophos|trend ?micro|avira|panda|webroot') { return 'antivirus' }
    if ($t -match '(?i)netw|wlan|wifi|wi-fi|ethernet|network|\brt\d|rtwlan|rtl8|e1d|e2f|e1r|killer|bcm|athw|qcamain|mt76|tcpip|ndis|netio|afd') { return 'network' }
    if ($t -match '(?i)storport|stornvme|storahci|iastor|nvme|ahci|raid|disk|classpnp|ntfs|samsung.*nvm|\bstor') { return 'storage' }
    if ($t -match '(?i)usb|xhci|hub') { return 'usb' }
    if ($t -match '(?i)audio|sound|realtek high definition|hdaudio|nahimic|sonic') { return 'audio' }
    return 'other'
}
# Analyse des écrans bleus depuis $Since : { Dumps = [ { Date; Code; Culprit (infos du pilote ou $null); Readable } ]; Top; TopCount; Whea; Xmp }
function Get-BsodAnalysis([datetime]$Since) {
    $res = @{ Dumps = @(); Top = $null; TopCount = 0; Whea = 0; Xmp = '' }
    $paths = @{}
    try { foreach ($d in @(Get-CimInstance Win32_SystemDriver -ErrorAction Stop)) { $pn = "$($d.PathName)" -replace '^\\\?\?\\', '' -replace '^\\SystemRoot', $env:SystemRoot -replace '^system32', "$env:SystemRoot\System32"; if ($pn) { $paths[[IO.Path]::GetFileName($pn).ToLowerInvariant()] = [Environment]::ExpandEnvironmentVariables($pn) } } } catch {}
    $files = @(Get-ChildItem -LiteralPath "$env:SystemRoot\Minidump" -Filter '*.dmp' -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $Since } | Sort-Object LastWriteTime -Descending | Select-Object -First 10)
    $list = New-Object System.Collections.ArrayList
    foreach ($f in $files) {
        $a = ''; try { $a = [AeroxDump]::Analyze($f.FullName) } catch {}
        $o = @{ Date = $f.LastWriteTime; Code = ''; Culprit = $null; Readable = $false; Stack = '' }
        if ($a) {
            $q = $a.Split('|'); $o.Code = $q[0]
            $mods = @(@($q[5] -split ',') + @($q[6] -split ',') | Where-Object { $_ } | Select-Object -Unique)
            $o.Readable = ($mods.Count -gt 0); $o.Stack = ($q[6] -replace ',', ', ')
            $infos = @($mods | ForEach-Object { Get-DriverFileInfo $_ $paths })
            $pick = @($infos | Where-Object { -not $_.Ms }) | Select-Object -First 1
            if (-not $pick) { $pick = @($infos | Where-Object { $_.Name -notmatch $script:BsodCore }) | Select-Object -First 1 }
            if ($pick) { $pick.Kind = Get-BsodKind $pick; $o.Culprit = $pick }
        }
        [void]$list.Add($o)
    }
    $res.Dumps = $list.ToArray()
    $g = @($res.Dumps | Where-Object { $_.Culprit } | Group-Object { $_.Culprit.Name } | Sort-Object Count -Descending)
    if ($g.Count) { $res.Top = ($g[0].Group | Select-Object -First 1).Culprit; $res.TopCount = $g[0].Count }
    try { $res.Whea = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WHEA-Logger'; StartTime = $Since } -ErrorAction SilentlyContinue | Where-Object { $_.Level -le 2 }).Count } catch {}
    try {
        $m = @(Get-CimStatic Win32_PhysicalMemory)
        $t = @($m | ForEach-Object { [int]$_.SMBIOSMemoryType } | Where-Object { $_ }) | Select-Object -First 1
        $spd = @($m | ForEach-Object { [int]$_.ConfiguredClockSpeed } | Where-Object { $_ }) | Sort-Object | Select-Object -First 1
        if (($t -eq 26 -and $spd -gt 3200) -or ($t -eq 34 -and $spd -gt 6400)) { $res.Xmp = "$(if ($t -eq 26) { 'DDR4' } else { 'DDR5' }) à $spd MT/s" }
    } catch {}
    return $res
}

# Programmes qui font partie de Windows : ils ne se « mettent pas à jour » comme un logiciel
$script:WinComponents = '(?i)^(dwm|explorer|svchost|sihost|ctfmon|runtimebroker|taskhostw|applicationframehost|shellexperiencehost|startmenuexperiencehost|searchhost|searchapp|searchui|textinputhost|lockapp|systemsettings|winlogon|csrss|lsass|spoolsv|audiodg|fontdrvhost|dllhost|wmiprvse|msedgewebview2|widgets|phoneexperiencehost)\.exe$'
function Test-Stability {
    $since = Get-StabilitySince 'bsod' (Get-Date).AddDays(-30)
    $bsod = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting'; Id = 1001; StartTime = $since } -ErrorAction SilentlyContinue)
    if ($bsod.Count -gt 0) {
        $codes = foreach ($e in $bsod) {
            $txt = (($e.Properties | ForEach-Object { "$($_.Value)" }) -join ' ') + ' ' + $e.Message
            if ($txt -match '0x([0-9a-fA-F]{1,8})') { '0x' + $matches[1].PadLeft(8, '0').ToUpper() }
        }
        $main = $codes | Group-Object | Sort-Object Count -Descending | Select-Object -First 1
        $info = if ($main -and $script:BugChecks.ContainsKey($main.Name)) { $script:BugChecks[$main.Name] } else { @('Erreur système', "Un pilote ou un composant matériel a provoqué un arrêt brutal de Windows.", 'drv') }
        $codeTxt = if ($main) { "{0} ({1})" -f $info[0], $main.Name } else { '' }
        # Les rapports de plantage : quel pilote était en cause à chaque écran bleu
        $an = Get-BsodAnalysis $since
        foreach ($d in $an.Dumps) {
            $nm = if ($script:BugChecks.ContainsKey($d.Code)) { $script:BugChecks[$d.Code][0] } else { 'code' }
            Log ("   • Écran bleu du {0} : {1} ({2}){3}" -f $d.Date.ToString('dd/MM/yyyy HH:mm'), $nm, $d.Code, $(if ($d.Culprit) { " → pilote en cause : $($d.Culprit.Name)" + $(if ($d.Culprit.Company) { " ($($d.Culprit.Company))" } else { '' }) } elseif ($d.Readable) { " → seulement Windows sur la pile ($($d.Stack))" } else { " → rapport illisible" }))
        }
        if (-not $an.Dumps.Count) { Log "   • Aucun rapport d'écran bleu gardé par Windows (C:\Windows\Minidump vide) : le coupable ne peut pas être lu, seulement le code." }
        $top = $an.Top; $detail = 'Code'; $fixL = "Réparer les fichiers Windows"; $fixA = 'Repair-System'; $ui = ''
        $cause = $info[1]
        $steps = switch ($info[2]) {
            'hw'  { @("Si tu as overclocké le PC ou activé XMP / EXPO dans le BIOS, remets les réglages par défaut.", "Teste la mémoire : tape « Diagnostic de mémoire Windows » dans Démarrer et redémarre.", "Vérifie que le PC ne chauffe pas (poussière, ventilateurs).", "Mets à jour Windows et tes pilotes (onglet Mises à jour).") }
            'gpu' { @("Mets à jour le pilote de la carte graphique avec l'outil officiel (onglet Mises à jour > Pilotes).", "Si tu as overclocké la carte graphique, remets-la par défaut.", "Vérifie que la carte graphique ne chauffe pas (poussière, ventilateurs).") }
            default { @("Mets à jour le pilote de la carte graphique et du Wi-Fi / réseau (onglet Mises à jour > Pilotes).", "Installe toutes les mises à jour Windows.", "Si les écrans bleus continuent, désinstalle le dernier logiciel ou pilote installé avant qu'ils commencent.") }
        }
        if ($top) {
            $extra = (@($top.Desc, $top.Company) | Where-Object { $_ }) -join ', '
            $who = "« $($top.Name) »" + $(if ($extra) { " ($extra)" } else { '' })
            $detail = "Pilote en cause : $($top.Name)"
            $cause = "Les rapports de plantage de Windows désignent $who dans $($an.TopCount) écran(s) bleu(s) sur $(@($an.Dumps).Count) analysé(s). "
            switch ($top.Kind) {
                'gpu' { $cause += "C'est le pilote de la carte graphique."; $fixL = "Vérifier les pilotes"; $fixA = ''; $ui = 'drivers'
                        $steps = @("Installe le dernier pilote de ta carte graphique (bouton vert, ou NVIDIA App / AMD Adrenalin).", "Si ça continue : réinstalle-le proprement (option « installation propre / réinitialiser » de l'installateur NVIDIA ou AMD).", "Si tu as overclocké la carte graphique (MSI Afterburner…), remets-la par défaut.") }
                'network' { $cause += "C'est un pilote réseau (carte réseau ou Wi-Fi)."; $fixL = "Vérifier les pilotes"; $fixA = ''; $ui = 'drivers'
                        $steps = @("Installe le dernier pilote réseau / Wi-Fi depuis le site du fabricant de ta carte mère ou de ton PC (pas seulement Windows Update).", "Si c'est une carte Killer ou Realtek : désinstalle son logiciel d'« optimisation » réseau s'il y en a un.") }
                'anticheat' { $cause += "C'est l'anti-triche d'un jeu."; $fixL = "Voir les logiciels"; $fixA = ''; $ui = 'uninstall'
                        $steps = @("Mets à jour le jeu qui l'utilise (ou réinstalle-le) : l'anti-triche se met à jour avec lui.", "Si tu n'y joues plus, désinstalle le jeu : son anti-triche part avec.") }
                'antivirus' { $cause += "C'est un antivirus en plus de celui de Windows."; $fixL = "Voir les logiciels"; $fixA = ''; $ui = 'uninstall'
                        $steps = @("Désinstalle cet antivirus : Windows Defender protège déjà très bien le PC, et deux antivirus se gênent.", "Si tu veux le garder, mets-le à jour depuis son propre menu.") }
                'storage' { $cause += "C'est un pilote du disque (stockage)."; $fixL = "Vérifier les pilotes"; $fixA = ''; $ui = 'drivers'
                        $steps = @("Installe les pilotes « chipset » et « stockage » du site du fabricant de ta carte mère.", "Mets à jour le firmware de ton SSD avec l'outil de sa marque (Samsung Magician, Crucial Storage Executive, WD Dashboard…).", "Sauvegarde tes fichiers importants en attendant.") }
                'usb' { $cause += "C'est un pilote USB (un appareil branché en USB)."; $fixL = "Vérifier les pilotes"; $fixA = ''; $ui = 'drivers'
                        $steps = @("Débranche les appareils USB dont tu n'as pas besoin (hubs, adaptateurs) et regarde si ça continue.", "Installe le pilote « chipset » du site du fabricant de ta carte mère.") }
                'audio' { $cause += "C'est un pilote audio."; $fixL = "Vérifier les pilotes"; $fixA = ''; $ui = 'drivers'
                        $steps = @("Installe le dernier pilote audio du site du fabricant de ta carte mère ou de ton PC.", "Désinstalle les logiciels d'« effets sonores » en plus (Nahimic, Sonic Studio…) si tu ne t'en sers pas.") }
                default { $cause += "Il a été installé par $(if ($top.Company) { $top.Company } else { 'un logiciel' })."; $fixL = "Voir les logiciels"; $fixA = ''; $ui = 'uninstall'
                        $steps = @("Mets à jour ou désinstalle le logiciel de $(if ($top.Company) { $top.Company } else { 'ce pilote' }).", "Si les écrans bleus ont commencé juste après l'avoir installé, désinstalle-le.") }
            }
        } elseif (@($an.Dumps | Where-Object { $_.Readable }).Count) {
            $cause = "Les rapports de plantage ne montrent que Windows lui-même, aucun pilote en particulier : c'est le signe classique d'un souci de mémoire vive (RAM), d'un réglage trop poussé (XMP/EXPO, overclocking) ou de fichiers de Windows abîmés."
            $steps = @("Lance « Réparer les fichiers Windows » (bouton vert).", "Teste la mémoire : tape « Diagnostic de mémoire Windows » dans Démarrer et redémarre.", "Si XMP / EXPO est activé dans le BIOS, essaie sans pendant quelques jours.")
        }
        # Indices matériels en plus (faits relevés par Windows, pas des suppositions)
        if ($an.Whea -gt 0) { $cause += " Windows a aussi noté $($an.Whea) erreur(s) matérielle(s) (WHEA) : le processeur, la RAM ou la carte mère signalent eux-mêmes un problème."; $steps = @($steps) + "Erreurs matérielles : enlève tout overclocking, mets à jour le BIOS et vérifie les températures." }
        if ($an.Xmp -and ($an.Whea -gt 0 -or $info[2] -eq 'hw' -or -not $top)) { $cause += " La mémoire tourne en profil XMP/EXPO ($($an.Xmp)) : souvent stable, mais c'est un overclocking, à désactiver pour tester." }
        if ($ui) {
            Add-Issue -Id 'bsod' -Sev 'crit' -Title "$($bsod.Count) écran(s) bleu(s) ces 30 derniers jours" -Detail $detail -Code $codeTxt -Cause $cause `
                -Effect "Le PC peut planter n'importe quand, avec un risque de perdre ce qui n'est pas enregistré." -FixLabel $fixL -UiFix $ui -Steps $steps
        } else {
            Add-Issue -Id 'bsod' -Sev 'crit' -Title "$($bsod.Count) écran(s) bleu(s) ces 30 derniers jours" -Detail $detail -Code $codeTxt -Cause $cause `
                -Effect "Le PC peut planter n'importe quand, avec un risque de perdre ce qui n'est pas enregistré." `
                -FixLabel "Réparer les fichiers Windows" -FixAction 'Repair-System' -Confirm "La réparation des fichiers Windows prend 15 à 45 minutes. Laisse le PC branché et le logiciel ouvert.`n`nElle corrige les fichiers système abîmés ; pour les pilotes, suis aussi les étapes « Voir comment faire »." `
                -Steps $steps
        }
    } else { Add-Ok "Aucun écran bleu ces 30 derniers jours" }

    $kp = @(Get-EventsSafe @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-Power'; Id = 41; StartTime = (Get-StabilitySince 'power41' (Get-Date).AddDays(-30)) } |
            Where-Object { "$($_.Properties[0].Value)" -eq '0' })
    if ($kp.Count -ge 2) {
        # Comment le PC s'est coupé : bouton maintenu (le PC était figé), pendant une mise en veille, ou coupure nette
        $btn = 0; $sleep = 0
        foreach ($e in $kp) { $f = Get-EventFields $e; if ($f.PowerButtonTimestamp -and $f.PowerButtonTimestamp -ne '0') { $btn++ } elseif ($f.SleepInProgress -and $f.SleepInProgress -ne '0' -and $f.SleepInProgress -ne 'false') { $sleep++ } }
        $cut = $kp.Count - $btn - $sleep
        $parts = @(); if ($btn) { $parts += "$btn fois en maintenant le bouton d'allumage" }; if ($sleep) { $parts += "$sleep fois pendant une mise en veille" }; if ($cut) { $parts += "$cut fois d'un coup, sans bouton (coupure nette)" }
        $cause = "Windows s'est coupé sans s'arrêter proprement : " + ($parts -join ', ') + "."
        $steps = @()
        if ($btn) { $cause += " Maintenir le bouton, c'est ce qu'on fait quand le PC est figé : le vrai problème, c'est ce qui le fige."; $steps += "Le PC se fige avant ? Regarde les autres alertes (pilote graphique, écrans bleus, plantages) : c'est souvent le pilote de la carte graphique ou une surchauffe." }
        if ($sleep) { $cause += " Les coupures pendant la mise en veille viennent souvent d'un pilote (carte graphique, Wi-Fi) ou du démarrage rapide de Windows."; $steps += "Mets à jour le pilote graphique et Wi-Fi ; si ça continue, désactive le « démarrage rapide » (Options d'alimentation > Choisir l'action des boutons)." }
        if ($cut) { $cause += " Une coupure nette sans bouton, c'est le courant (multiprise, coupure), l'alimentation du PC qui flanche sous la charge, ou une surchauffe."; $steps += "Si ça arrive surtout en jeu : poussière, ventilateurs, et l'alimentation du PC (bloc d'alim) peut être trop faible ou fatiguée."; $steps += "Branche le PC directement au mur (sans multiprise douteuse) pour éliminer le courant." }
        Add-Issue -Id 'power41' -Sev 'warn' -Title "Le PC s'est éteint brutalement $($kp.Count) fois" -Detail "Ces 30 derniers jours" -Cause $cause `
            -Effect "Risque de fichiers abîmés et de perte de travail." -Steps $steps
    }

    # Le pilote graphique qui « cesse de répondre et récupère » : écran noir quelques secondes qui revient tout seul,
    # jeu qui se fige ou se ferme. Toutes les traces que Windows en garde sont réunies (événement 4101, erreurs du pilote,
    # rapports « LiveKernelEvent » et fichiers WATCHDOG), et comparées à la date d'installation du pilote.
    $sinceTdr = Get-StabilitySince 'tdr' (Get-Date).AddDays(-14)
    $resets = @(Get-GpuResets $sinceTdr)
    foreach ($r in $resets) { Log ("   • Carte graphique : décrochage le {0} ({1})" -f $r.Time.ToString('dd/MM HH:mm'), ($r.Srcs -join ', ')) }
    if ($resets.Count -ge 2) {
        $days = [math]::Max([double]1, [math]::Ceiling(((Get-Date) - $sinceTdr).TotalDays))
        $gpus = @(Get-CimStatic Win32_VideoController -Quiet | Where-Object { $_.Name -notmatch '(?i)remote|virtual|parsec|basic display|de base|hyper-v|vmware|virtualbox' })
        $gpu = @($gpus | Sort-Object { if ("$($_.Name)" -match '(?i)intel') { 1 } else { 0 } } | Select-Object -First 1)
        $gName = if ($gpu.Count) { "$($gpu[0].Name)" } else { 'Carte graphique' }
        $vendor = if ($gName -match '(?i)nvidia|geforce|rtx|gtx') { 'NVIDIA' } elseif ($gName -match '(?i)amd|radeon') { 'AMD' } elseif ($gName -match '(?i)intel') { 'Intel' } else { '' }
        $inst = $null; try { $dd = @((Get-GpuDriverInstallDates).Values | Where-Object { $_ } | Sort-Object -Descending); if ($dd.Count) { $inst = [datetime]$dd[0] } } catch {}
        $before = 0; $after = 0
        if ($inst) { $before = @($resets | Where-Object { $_.Time -lt $inst }).Count; $after = @($resets | Where-Object { $_.Time -ge $inst }).Count }
        $temp = $null; try { if ($sync.Sens -and $sync.Sens['gpu.temp']) { $temp = [math]::Round([double]$sync.Sens['gpu.temp']) } } catch {}
        $clean = switch ($vendor) {
            'NVIDIA' { "Réinstalle le pilote proprement : télécharge-le sur nvidia.com (ou NVIDIA App), lance l'installation, choisis « Personnalisée » puis coche « Effectuer une installation propre »." }
            'AMD'    { "Réinstalle le pilote proprement : télécharge AMD Software (Adrenalin) sur amd.com et coche « Réinitialisation d'usine » pendant l'installation." }
            'Intel'  { "Réinstalle le pilote graphique avec « Intel Driver & Support Assistant » (site d'Intel), puis redémarre." }
            default  { "Réinstalle le pilote de la carte graphique depuis le site de son fabricant, en « installation propre » si l'installateur le propose." }
        }
        $steps = New-Object System.Collections.ArrayList
        if ($inst -and $inst -gt $sinceTdr -and $before -eq 0 -and $after -ge 2) {
            $cause = "Ça a commencé après l'installation du pilote graphique du {0} : aucun décrochage avant sur la période. Ce pilote (ou son installation) est le suspect n°1." -f $inst.ToString('dd/MM/yyyy')
            [void]$steps.Add($clean)
            [void]$steps.Add("Si ça continue après une installation propre : installe la version précédente du pilote (le site du fabricant garde les anciennes versions).")
        } elseif ($inst -and $before -ge 1 -and $after -ge 1) {
            $cause = "Ça arrivait déjà avant la dernière installation du pilote (le {0}) et ça continue après : la version du pilote n'est probablement pas en cause. Causes les plus fréquentes : surchauffe, overclocking de la carte, alimentation du PC trop juste, ou câble / écran." -f $inst.ToString('dd/MM/yyyy')
            [void]$steps.Add("Enlève tout overclocking ou undervolting de la carte graphique (MSI Afterburner, logiciel du fabricant).")
            [void]$steps.Add("Regarde la température de la carte en jeu (Gaming > En direct) : au-dessus de 85 °C, dépoussière.")
            [void]$steps.Add("Essaie un autre câble ou une autre prise de l'écran (DisplayPort / HDMI) : un câble fatigué fait aussi des écrans noirs.")
            [void]$steps.Add("Si ça arrive surtout en jeu : l'alimentation du PC est peut-être trop faible ou fatiguée pour la carte.")
        } else {
            $cause = "Windows a dû relancer le pilote de la carte graphique (écran noir quelques secondes qui revient tout seul). Causes classiques : pilote abîmé, trop vieux ou bogué, overclocking, surchauffe, ou alimentation trop juste."
            [void]$steps.Add($clean)
            [void]$steps.Add("Enlève tout overclocking de la carte graphique et regarde sa température en jeu (Gaming > En direct).")
            [void]$steps.Add("Si ça continue : essaie un autre câble ou une autre prise de l'écran, puis pense à l'alimentation du PC.")
        }
        if ($temp -ge 83) { $cause += " La carte est à $temp °C en ce moment : la chaleur peut suffire à la faire décrocher." }
        Add-Issue -Id 'tdr' -Sev $(if ($resets.Count -ge 5) { 'crit' } else { 'warn' }) -Title ("L'écran devient noir et revient : la carte graphique a décroché {0} fois" -f $resets.Count) `
            -Detail ("{0} · en {1} jours · dernier le {2}" -f $gName, $days, $resets[-1].Time.ToString('dd/MM à HH:mm')) `
            -Cause $cause -Effect "Écrans noirs de quelques secondes, jeux qui se figent ou se ferment, parfois écran bleu." -FixLabel "Vérifier le pilote graphique" -UiFix 'drivers' -Steps $steps.ToArray()
    } elseif ($resets.Count -eq 1) { Add-Ok ("Carte graphique : un seul décrochage en 14 jours (le {0}), rien d'inquiétant pour l'instant" -f $resets[0].Time.ToString('dd/MM')) }

    # Test de la mémoire de Windows (« Diagnostic de mémoire Windows ») : son résultat est un fait, pas une supposition
    $md = @(Get-EventsSafe @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-MemoryDiagnostics-Results'; StartTime = (Get-Date).AddDays(-90) } 5 | Sort-Object TimeCreated -Descending)
    if ($md.Count -and $md[0].Id -eq 1202) {
        Add-Issue -Id 'ramtest' -Sev 'crit' -Title "Le test de mémoire de Windows a trouvé des erreurs" -Detail ("Test du {0}" -f $md[0].TimeCreated.ToString('dd/MM/yyyy')) `
            -Cause "Une barrette de mémoire vive (RAM) est défectueuse ou mal réglée (profil XMP/EXPO trop poussé)." -Effect "Écrans bleus, plantages au hasard, fichiers abîmés." `
            -Steps @("Désactive XMP / EXPO dans le BIOS et refais le test (« Diagnostic de mémoire Windows » dans Démarrer).", "Si les erreurs restent : teste les barrettes une par une pour trouver la mauvaise, puis remplace-la (garantie souvent à vie sur la RAM).")
    } elseif ($md.Count -and $md[0].Id -eq 1201) { Add-Ok ("Test de mémoire de Windows sans erreur (le {0})" -f $md[0].TimeCreated.ToString('dd/MM/yyyy')) }

    # Logiciels qui se figent (« ne répond pas ») souvent
    $hangs = @(Get-EventsSafe @{ LogName = 'Application'; Id = 1002; StartTime = (Get-StabilitySince 'hang' (Get-Date).AddDays(-7)) } |
               Where-Object { "$($_.Properties[0].Value)" -notmatch '(?i)^(aerox ?pc ?care|aeroxpccare)' })
    $hg = @($hangs | Group-Object { "$($_.Properties[0].Value)" } | Where-Object { $_.Count -ge 3 } | Sort-Object Count -Descending)
    if ($hg.Count) {
        $h1 = $hg[0]
        $isWinH = ($h1.Name -match $script:WinComponents)
        Add-Issue -Id 'hang' -Sev 'warn' -Title "$($h1.Name) s'est figé $($h1.Count) fois cette semaine" -Detail ("« Ne répond pas »" + $(if ($hg.Count -gt 1) { " · aussi : " + (($hg | Select-Object -Skip 1 -First 3 | ForEach-Object { "$($_.Name) ($($_.Count))" }) -join ', ') } else { '' })) `
            -Cause $(if ($isWinH) { "$($h1.Name) fait partie de Windows : quand il se fige, c'est souvent le disque saturé, un logiciel qui s'accroche à l'Explorateur (extensions de menu clic droit, cloud), ou des fichiers de Windows abîmés." } else { "Le logiciel attend quelque chose qui ne vient pas : disque trop lent ou saturé, mémoire pleine, version boguée ou extension/plugin en trop." }) `
            -Effect "Fenêtre blanche « Ne répond pas », travail perdu si tu forces la fermeture." `
            -FixLabel $(if ($isWinH) { "Réparer les fichiers Windows" } else { "Mettre à jour mes logiciels" }) -FixAction $(if ($isWinH) { 'Repair-System' } else { 'Update-Apps' }) `
            -Steps @("Lance l'analyse « PC lent » au moment où ça se fige : AEROX te montre ce qui occupe le processeur, la mémoire et le disque.", $(if ($isWinH) { "Lance « Réparer les fichiers Windows »." } else { "Mets le logiciel à jour ; si ça continue, réinstalle-le (et retire ses extensions / plugins)." }))
    }

    # Les plantages d'AEROX PC Care lui-même ne sont pas un problème du PC (ils remontent par les rapports de bug)
    $crashes = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; Id = 1000; StartTime = (Get-StabilitySince 'crash' (Get-Date).AddDays(-7)) } -ErrorAction SilentlyContinue |
                 Where-Object { "$($_.Properties[0].Value)" -notmatch '(?i)^(aerox ?pc ?care|aeroxpccare)(_setup)?.*\.exe$' })
    $groups = @($crashes | Group-Object { "$($_.Properties[0].Value)" } | Where-Object { $_.Count -ge 3 } | Sort-Object Count -Descending)
    if ($groups.Count -gt 0) {
        $g = $groups[0]
        $module = ($g.Group | Group-Object { "$($_.Properties[3].Value)" } | Sort-Object Count -Descending | Select-Object -First 1).Name
        $gpuMod = ($module -match '(?i)^(nvwgf|nvogl|nvd3d|nvcuda|nvlddmkm|atiu|amdx|atidx|amdkmd|igd|ig\d|dxgi|d3d11|d3d12|dxcore)')
        $isWin = ($g.Name -match $script:WinComponents)
        $cause = if ($g.Name -match '(?i)^dwm\.exe$') { "dwm.exe, c'est l'affichage de Windows (fenêtres, bureau, effets) : quand il plante, l'écran clignote ou devient noir un instant. La cause est presque toujours le pilote de la carte graphique ($module)." }
                 elseif ($isWin -and $gpuMod) { "$($g.Name) fait partie de Windows ; le plantage vient du pilote de la carte graphique ($module)." }
                 elseif ($isWin) { "$($g.Name) fait partie de Windows ($module) : souvent des fichiers de Windows abîmés ou un pilote." }
                 elseif ($gpuMod) { "Le plantage vient du pilote de la carte graphique ($module)." }
                 elseif ($module -match '(?i)^(ntdll|kernelbase|ucrtbase|msvcp|vcruntime|clr|coreclr)') { "Le plantage vient du logiciel lui-même ($module) : souvent une version ancienne ou des fichiers abîmés." }
                 else { "Plantages répétés dans « $module » : souvent une version ancienne ou des fichiers du logiciel abîmés." }
        $others = if ($groups.Count -gt 1) { " Autres : " + (($groups | Select-Object -Skip 1 -First 3 | ForEach-Object { "$($_.Name) ($($_.Count))" }) -join ', ') + "." } else { '' }
        $per = $(if ((Get-StabilitySince 'crash' (Get-Date).AddDays(-7)) -gt (Get-Date).AddDays(-7)) { "depuis ta dernière réparation" } else { "cette semaine" })
        # Plantage lié à la carte graphique : seuls ceux d'APRÈS l'installation du pilote actuel comptent
        # (sinon, juste après avoir installé le nouveau pilote, AEROX continuerait d'accuser l'ancien)
        if ($gpuMod -or $g.Name -match '(?i)^dwm\.exe$') {
            $last = @((Get-GpuDriverInstallDates).Values | Sort-Object -Descending | Select-Object -First 1)
            if ($last.Count -and $last[0] -gt (Get-Date).AddDays(-7)) {
                $after = @($g.Group | Where-Object { $_.TimeCreated -gt $last[0] })
                if ($after.Count -lt 3) {
                    Add-Ok ("{0} plantait avant ({1} fois), plus depuis le nouveau pilote graphique installé le {2}" -f $g.Name, $g.Count, $last[0].ToString('dd/MM/yyyy à HH:mm'))
                    return
                }
                $g = @{ Name = $g.Name; Count = $after.Count; Group = $after }; $per = "depuis le nouveau pilote graphique"
            }
        }
        # La bonne réparation selon le coupable : pilote graphique, fichiers de Windows, ou le logiciel lui-même
        if ($gpuMod -or $g.Name -match '(?i)^dwm\.exe$') {
            Add-Issue -Id 'crash' -Sev 'warn' -Title "$($g.Name) a planté $($g.Count) fois $per" -Detail ("Module en cause : {0}" -f $module) -Cause ($cause + $others) `
                -Effect $(if ($isWin) { "Écran qui clignote ou devient noir, fenêtres qui se figent un instant." } else { "Fermetures soudaines et perte de ce qui n'était pas enregistré." }) `
                -FixLabel "Vérifier les pilotes" -UiFix 'drivers' `
                -Steps @("Installe le dernier pilote de ta carte graphique (bouton vert, ou NVIDIA App / AMD Adrenalin).", "Si tu as overclocké la carte graphique (MSI Afterburner…), remets-la par défaut.", "Si ça continue après la mise à jour, lance « Réparer les fichiers Windows » (onglet Réparer).")
        } elseif ($isWin) {
            Add-Issue -Id 'crash' -Sev 'warn' -Title "$($g.Name) a planté $($g.Count) fois $per" -Detail ("Module en cause : {0}" -f $module) -Cause ($cause + $others) `
                -Effect "Des morceaux de Windows se ferment ou redémarrent tout seuls." `
                -FixLabel "Réparer les fichiers Windows" -FixAction 'Repair-System' -Confirm "La réparation des fichiers Windows prend 15 à 45 minutes. Laisse le PC branché et le logiciel ouvert." `
                -Steps @("Lance « Réparer les fichiers Windows » (bouton vert).", "Installe toutes les mises à jour Windows et le pilote de ta carte graphique.")
        } else {
            Add-Issue -Id 'crash' -Sev 'warn' -Title "$($g.Name) a planté $($g.Count) fois $per" -Detail ("Module en cause : {0}" -f $module) -Cause ($cause + $others) `
                -Effect "Fermetures soudaines et perte de ce qui n'était pas enregistré." -FixLabel "Mettre à jour mes logiciels" -FixAction 'Update-Apps' `
                -Steps @("Mets à jour le logiciel (bouton vert) et le pilote graphique (onglet Mises à jour > Pilotes).", "Si ça continue : désinstalle-le puis réinstalle-le depuis son site officiel.")
        }
    } else { Add-Ok "Aucun logiciel ne plante en boucle" }
}

function Test-Updates {
    $since = (Get-Date).AddDays(-30)
    $fails = @(Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-WindowsUpdateClient/Operational'; Id = 20; StartTime = $since } -ErrorAction SilentlyContinue)
    $oks   = @(Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-WindowsUpdateClient/Operational'; Id = 19; StartTime = $since } -ErrorAction SilentlyContinue)
    $okTitles = @{}
    foreach ($o in $oks) { foreach ($v in $o.Properties.Value) { if ("$v" -match '\s') { $okTitles["$v"] = $o.TimeCreated } } }
    $still = @()
    foreach ($f in $fails) {
        $code  = $f.Properties.Value | Where-Object { "$_" -match '^0x[0-9a-fA-F]{8}$' } | Select-Object -First 1
        if (-not $code -and $f.Message -match '0x[0-9a-fA-F]{8}') { $code = $matches[0] }
        $title = $f.Properties.Value | Where-Object { "$_" -match '\s' } | Select-Object -First 1
        if ($title -and $okTitles.ContainsKey("$title") -and $okTitles["$title"] -gt $f.TimeCreated) { continue }
        $still += [pscustomobject]@{ Code = "$code".ToUpper() -replace '^0X', '0x'; Title = "$title" }
    }
    if ($still.Count -gt 0) {
        $main = $still | Group-Object Code | Sort-Object Count -Descending | Select-Object -First 1
        $wi = Get-WuErrorInfo $main.Name
        $names = ($still | Select-Object -ExpandProperty Title -Unique | Select-Object -First 2) -join ' / '
        Add-Issue -Id 'wu' -Sev 'crit' -Title "Windows Update n'arrive pas à installer des mises à jour" -Detail 'Erreur' -Code $main.Name -Cause ($wi.Cause + " (" + $names + ")") `
            -Effect "Le PC n'a pas les derniers correctifs de sécurité et Windows retente en boucle." -FixLabel "Débloquer et installer" -FixAction $wi.Fix `
            -Confirm "Windows Update va être remis à zéro puis les mises à jour seront réinstallées. Ça peut prendre 10 à 30 minutes et un redémarrage sera nécessaire."
    }
    $last = Get-HotFix -ErrorAction SilentlyContinue | Where-Object { $_.InstalledOn } | Sort-Object InstalledOn -Descending | Select-Object -First 1
    if ($last) {
        $age = [int]((Get-Date) - $last.InstalledOn).TotalDays
        if ($age -gt 45 -and $still.Count -eq 0) {
            Add-Issue -Id 'wuold' -Sev 'warn' -Title "Windows n'a pas été mis à jour depuis $age jours" -Detail "Dernière mise à jour : $($last.HotFixID)" `
                -Cause "Les mises à jour sont en pause, ou Windows Update n'arrive plus à les trouver." -Effect "Le PC n'a pas les derniers correctifs de sécurité et de stabilité." `
                -FixLabel "Installer les mises à jour" -FixAction 'Update-Windows' -Confirm "L'installation peut prendre 5 à 30 minutes et le PC devra peut-être redémarrer."
        } elseif ($still.Count -eq 0) { Add-Ok "Windows à jour (dernière mise à jour il y a $age jours)" }
    }
    $apps = Get-AppUpdates
    if ($null -eq $apps -and $script:WingetUnreadable) {
        Add-Issue -Id 'wingetread' -Sev 'warn' -Title "Impossible de lister les mises à jour des logiciels" -Detail "L'outil de Microsoft (winget) a répondu de façon inattendue" `
            -Cause "Le « Programme d'installation d'application » de Microsoft est sans doute trop ancien sur ce PC." -Effect "Les logiciels pas à jour ne peuvent pas être détectés automatiquement." `
            -FixLabel "Mettre à jour l'outil (Microsoft Store)" -FixAction 'Open-WingetStore' -OpenOnly `
            -Steps @("Clique sur le bouton : le Microsoft Store s'ouvre sur « Programme d'installation d'application ».", "Clique sur « Mettre à jour » (ou « Installer »), puis relance le diagnostic.")
    } elseif ($null -eq $apps -and (Test-OtherAccount)) {
        Add-Ok "Logiciels : non vérifiés depuis ce compte (ouvre AEROX depuis la session administrateur pour les vérifier)"
    } elseif ($null -eq $apps) {
        Add-Issue -Id 'winget' -Sev 'warn' -Title "L'outil de mise à jour des logiciels est absent" -Detail 'winget introuvable' `
            -Cause "Le « Programme d'installation d'application » de Microsoft n'est pas installé ou trop ancien." -Effect "AEROX PC Care ne peut pas mettre tes logiciels à jour automatiquement." `
            -FixLabel "L'installer (Microsoft Store)" -FixAction 'Open-WingetStore' -OpenOnly
    } elseif ($null -ne $apps -and ($apps = @($apps | Where-Object { -not $_.Ghost -and -not $_.Self })).Count -gt 0) {
        $shown = ($apps | Select-Object -First 4 | ForEach-Object { $_.Name }) -join ', '
        if ($apps.Count -gt 4) { $shown += " et $($apps.Count - 4) autre(s)" }
        $ign = @(Get-IgnoredApps).Count
        Add-Issue -Id 'apps' -Sev 'warn' -Title "$($apps.Count) logiciel(s) ne sont pas à jour" -Detail $shown `
            -Cause ("Ces logiciels ne se mettent pas à jour tout seuls." + $(if ($ign) { " ($ign logiciel(s) ignoré(s) à ta demande ne sont pas comptés.)" } else { '' })) `
            -Effect "Les anciennes versions ont des bugs et des failles de sécurité connues." `
            -FixLabel "Choisir les mises à jour" -UiFix 'apps'
    } else { Add-Ok $(if (@(Get-IgnoredApps).Count) { "Logiciels à jour ($(@(Get-IgnoredApps).Count) ignoré(s) à ta demande)" } else { "Tous les logiciels sont à jour" }) }
}

# ---------------------------------------------------------------- Coupures de connexion (contrôles prudents, corrections annulables)
function Get-ActiveAdapterIndex {
    # La carte réellement utilisée pour aller sur Internet (même choix que Windows)
    try { $f = Find-NetRoute -RemoteIPAddress 1.1.1.1 -ErrorAction Stop | Where-Object { $_.InterfaceIndex } | Select-Object -First 1; if ($f) { return [int]$f.InterfaceIndex } } catch {}
    $r = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | ForEach-Object {
        $m = (Get-NetIPInterface -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).InterfaceMetric
        [pscustomobject]@{ Index = $_.ifIndex; Metric = [int]$_.RouteMetric + [int]$m } } | Sort-Object Metric | Select-Object -First 1
    if ($r) { return [int]$r.Index }
    return $null
}
function Get-ActiveAdapter {
    $idx = Get-ActiveAdapterIndex
    if (-not $idx) { return $null }
    $a = Get-NetAdapter -InterfaceIndex $idx -ErrorAction SilentlyContinue
    if (-not $a) { return $null }
    $wifi = ("$($a.PhysicalMediaType)" -match '802\.11' -or "$($a.InterfaceDescription) $($a.Name)" -match '(?i)wi-?fi|wireless|wlan|802\.11')
    return @{ Name = $a.Name; Index = $a.ifIndex; Desc = "$($a.InterfaceDescription)"; Guid = "$($a.InterfaceGuid)"; Wifi = $wifi; DriverDate = (ConvertTo-DateSafe $a.DriverDate); DriverVersion = "$($a.DriverVersionString)" }
}
function Measure-Dns([string]$Server) {
    $names = 'www.google.com', 'www.youtube.com', 'www.amazon.fr', 'www.wikipedia.org', 'www.microsoft.com'
    $t = @()
    foreach ($n in $names) {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        try {
            if ($Server) { $null = Resolve-DnsName -Name $n -Server $Server -DnsOnly -NoHostsFile -QuickTimeout -ErrorAction Stop }
            else { $null = Resolve-DnsName -Name $n -DnsOnly -NoHostsFile -QuickTimeout -ErrorAction Stop }
            $t += $sw.Elapsed.TotalMilliseconds
        } catch { $t += 2000 }
    }
    $sorted = @($t | Sort-Object)
    return [math]::Round($sorted[[int]($sorted.Count / 2)])
}
function Test-ConnectionStability {
    $a = Get-ActiveAdapter
    if (-not $a) { return }
    $laptop = $false
    try { $laptop = [bool](@((Get-CimStatic Win32_SystemEnclosure -Quiet).ChassisTypes | Where-Object { $_ -in 8, 9, 10, 11, 14, 30, 31, 32 }).Count) } catch {}
    # 1. Économie d'énergie de la carte réseau (Windows peut la couper) : proposé seulement sur un PC fixe
    try {
        $sleep = Get-NetAdapterSleepState $a.Name
        if ($sleep -eq 'Enabled') {
            if (-not $laptop) {
                Add-Issue -Id 'netpower' -Sev 'warn' -Title "Windows peut couper ta carte réseau pour économiser l'énergie" -Detail $a.Desc `
                    -Cause "L'option « Autoriser l'ordinateur à éteindre ce périphérique » est activée : sur un PC fixe, c'est une cause classique de coupures et de déconnexions en jeu." `
                    -Effect "Coupures de quelques secondes, déconnexions de Discord ou des jeux, connexion lente au réveil du PC." `
                    -FixLabel "Désactiver cette économie d'énergie" -FixAction ("Set-NetAdapterSleep {0} `$false" -f (ConvertTo-PsLiteral $a.Name)) `
                    -Confirm "La carte réseau ne sera plus mise en veille par Windows. La connexion peut se couper 2 ou 3 secondes pendant le réglage.`n`nTu pourras annuler dans l'historique des changements." `
                    -Steps @("Le bouton désactive seulement cette option (annulable dans l'historique).", "À la main : Gestionnaire de périphériques > Cartes réseau > ta carte > Propriétés > Gestion de l'alimentation.")
            } else { Add-Ok "Carte réseau : économie d'énergie active (normal sur un portable, pour la batterie)" }
        } elseif ($sleep -eq 'Disabled') { Add-Ok "Carte réseau : jamais mise en veille par Windows" }
    } catch {}
    # 2. Pilote Wi-Fi ancien
    if ($a.Wifi -and $a.DriverDate) {
        $age = [int]((Get-Date) - $a.DriverDate).TotalDays
        # Cartes Intel d'ancienne génération : Intel ne sort plus que la branche « legacy » (19.51 pour 3165/3168/7265, 18.33 pour 3160/7260).
        # Avec cette branche installée, c'est la dernière version possible : pas d'alerte, même si sa date est ancienne.
        $legacy = ($a.Desc -match '(?i)wireless-ac (3165|3168|7265)' -and "$($a.DriverVersion)" -match '^19\.51\.') -or
                  ($a.Desc -match '(?i)wireless(-ac|-n)? (3160|7260)' -and "$($a.DriverVersion)" -match '^18\.33\.')
        if ($legacy) { Add-Ok ("Pilote Wi-Fi : dernière version proposée par Intel pour cette carte ({0})" -f $a.DriverVersion) }
        elseif ($age -ge 730) {
            $intel = ($a.Desc -match '(?i)intel|killer')
            $url = 'https://www.intel.fr/content/www/fr/fr/support/detect.html'
            Add-Issue -Id 'wifidrv' -Sev 'warn' -Title ("Le pilote Wi-Fi date de {0}" -f (Format-Date $a.DriverDate 'MMMM yyyy')) -Detail ("{0} (version {1})" -f $a.Desc, $a.DriverVersion) `
                -Cause "Un pilote Wi-Fi ancien est une cause fréquente de coupures, de débit bas et de connexion qui saute après la veille." -Effect "Wi-Fi instable : déconnexions, lags et débit plus faible que prévu." `
                -FixLabel $(if ($intel) { "Mettre à jour (outil Intel)" } else { "Vérifier les pilotes" }) -FixAction $(if ($intel) { "if (Open-Url {0}) {{ Log '   ✔ Page officielle ouverte dans le navigateur' }}" -f (ConvertTo-PsLiteral $url) } else { '' }) -UiFix $(if ($intel) { '' } else { 'drivers' }) -OpenOnly:$intel `
                -Steps $(if ($intel) { @("Installe « Intel Driver & Support Assistant » depuis la page officielle.", "Lance-le : il trouve et installe le dernier pilote Wi-Fi.", "Redémarre le PC.") } else { @("Clique sur « Vérifier les pilotes » : si Windows propose un pilote Wi-Fi plus récent, coche-le et installe-le.", "Sinon, prends le pilote sur le site du fabricant du PC ou de la carte mère (onglet Mon PC > « Chercher sur le site officiel »).") })
        } else { Add-Ok "Pilote Wi-Fi récent" }
    }
    # 3. DNS lents (mesurés) : proposition uniquement si l'écart est net
    try {
        $srv = @((Get-DnsClientServerAddress -InterfaceIndex $a.Index -AddressFamily IPv4 -ErrorAction Stop).ServerAddresses | Where-Object { $_ })
        if (-not $srv.Count -or $srv[0] -in '1.1.1.1', '1.0.0.1') { throw 'pas de mesure' }
        $mine = Measure-Dns $srv[0]
        $cf = Measure-Dns '1.1.1.1'
        if ($mine -ge 2000 -or $cf -ge 2000) { throw 'mesure impossible' }
        if ($mine -ge 80 -and $mine -ge 2 * $cf) {
            Add-Issue -Id 'dnsslow' -Sev 'warn' -Title ("Les DNS de ta connexion sont lents ({0} ms)" -f $mine) -Detail ("Cloudflare (1.1.1.1) répond en {0} ms" -f $cf) `
                -Cause "Le DNS traduit le nom des sites en adresses. Celui de ton fournisseur répond lentement : chaque nouveau site ou serveur de jeu met plus de temps à s'ouvrir." `
                -Effect "Sites et lancements de jeux plus lents, parfois des « serveur introuvable »." `
                -FixLabel "Utiliser les DNS de Cloudflare" -FixAction ("Set-FastDns {0}" -f $a.Index) `
                -Confirm "Les DNS de ta carte réseau vont passer sur Cloudflare (1.1.1.1 et 1.0.0.1), gratuits et rapides.`n`nÀ éviter si ton PC est sur un réseau d'entreprise ou avec un contrôle parental du fournisseur.`n`nTu pourras remettre ceux d'avant dans l'historique des changements." `
                -Steps @("Le bouton change seulement les DNS de cette carte réseau, et c'est annulable dans l'historique.", "Rien d'autre n'est modifié : Wi-Fi, box et mots de passe restent identiques.")
        } else { Add-Ok ("DNS rapides ({0} ms)" -f $mine) }
    } catch {}
}
# État de la case « Autoriser l'ordinateur à éteindre ce périphérique » : 'Enabled', 'Disabled' ou '' (inconnu).
# Même source que celle modifiée par Set-NetAdapterSleep, pour que l'alerte disparaisse bien une fois réglée.
function Get-NetAdapterSleepState([string]$Name) {
    try {
        $a = Get-NetAdapter -Name $Name -ErrorAction Stop
        $pnp = "$($a.PnPDeviceID)"
        $cls = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}'
        $key = Get-ChildItem -LiteralPath $cls -ErrorAction SilentlyContinue | Where-Object { "$((Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue).NetCfgInstanceId)" -eq "$($a.InterfaceGuid)" } | Select-Object -First 1
        if ($key) { $cap = (Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue).PnPCapabilities; if ($null -ne $cap -and ([int]$cap -band 0x10)) { return 'Disabled' } }
        foreach ($x in @(Get-CimInstance -Namespace 'root/wmi' -ClassName MSPower_DeviceEnable -ErrorAction SilentlyContinue)) {
            if ($pnp -and "$($x.InstanceName)".StartsWith($pnp, [StringComparison]::OrdinalIgnoreCase)) { return $(if ($x.Enable) { 'Enabled' } else { 'Disabled' }) }
        }
        return "$((Get-NetAdapterPowerManagement -Name $Name -ErrorAction Stop).AllowComputerToTurnOffDevice)"
    } catch { return '' }
}
# Case « Autoriser l'ordinateur à éteindre ce périphérique pour économiser l'énergie » (Gestionnaire de périphériques).
# Set-NetAdapterPowerManagement ne sait pas la modifier : on passe par la classe WMI que le Gestionnaire utilise
# (MSPower_DeviceEnable, effet immédiat), sinon par le réglage du pilote (PnPCapabilities, effet au redémarrage).
function Set-NetAdapterSleep([string]$Name, [bool]$Allow) {
    Step $(if ($Allow) { "Réactivation de l'économie d'énergie de la carte réseau" } else { "Désactivation de l'économie d'énergie de la carte réseau" })
    try {
        $a = Get-NetAdapter -Name $Name -ErrorAction Stop
        $pnp = "$($a.PnPDeviceID)"
        $done = $false; $reboot = $false
        foreach ($x in @(Get-CimInstance -Namespace 'root/wmi' -ClassName MSPower_DeviceEnable -ErrorAction SilentlyContinue)) {
            if ($pnp -and "$($x.InstanceName)".StartsWith($pnp, [StringComparison]::OrdinalIgnoreCase)) {
                Set-CimInstance -InputObject $x -Property @{ Enable = $Allow } -ErrorAction Stop
                $done = $true
            }
        }
        # Relu aussitôt : certains pilotes acceptent la demande sans l'appliquer (retour testeur : « réglé » puis toujours là)
        if ($done -and -not $Allow) {
            Start-Sleep -Milliseconds 500
            $still = @(Get-CimInstance -Namespace 'root/wmi' -ClassName MSPower_DeviceEnable -ErrorAction SilentlyContinue | Where-Object { "$($_.InstanceName)".StartsWith($pnp, [StringComparison]::OrdinalIgnoreCase) -and $_.Enable })
            if ($still.Count) { $done = $false; Log "   • Le pilote de la carte n'a pas pris le réglage tout de suite : il est enregistré pour le prochain redémarrage." }
        }
        if (-not $done) {
            $cls = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}'
            $key = Get-ChildItem -LiteralPath $cls -ErrorAction Stop | Where-Object { "$((Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue).NetCfgInstanceId)" -eq "$($a.InterfaceGuid)" } | Select-Object -First 1
            if (-not $key) { throw "Le réglage de cette carte réseau est introuvable dans Windows." }
            if ($Allow) { Remove-ItemProperty -LiteralPath $key.PSPath -Name PnPCapabilities -ErrorAction SilentlyContinue }
            else { Set-ItemProperty -LiteralPath $key.PSPath -Name PnPCapabilities -Value 24 -Type DWord -ErrorAction Stop }
            $reboot = $true
        }
        Log ("   ✔ {0} : {1}" -f $Name, $(if ($Allow) { 'Windows peut de nouveau la mettre en veille.' } else { 'Windows ne la coupera plus.' }))
        if ($reboot) { Log "   → Pris en compte au prochain redémarrage du PC." }
        if (-not $Allow) { Add-Change -Title ("Carte réseau « {0} » : plus de mise en veille par Windows" -f $Name) -Undo ("Set-NetAdapterSleep {0} `$true" -f (ConvertTo-PsLiteral $Name)) }
    } catch {
        Add-TaskError -Title "Impossible de modifier la gestion d'énergie de la carte réseau" -Cause $_.Exception.Message -FixLabel "Ouvrir le Gestionnaire de périphériques" -FixAction "Open-SystemTool 'devmgmt.msc'" `
            -Steps @("Dans le Gestionnaire de périphériques, ouvre « Cartes réseau » et double-clique sur ta carte.", "Onglet « Gestion de l'alimentation » : décoche « Autoriser l'ordinateur à éteindre ce périphérique pour économiser l'énergie ».", "Clique sur OK.")
    }
}
function Set-FastDns([int]$Index) {
    Step "Passage aux DNS de Cloudflare (1.1.1.1)"
    try {
        $a = Get-NetAdapter -InterfaceIndex $Index -ErrorAction Stop
        $key = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($a.InterfaceGuid)"
        $static = "$((Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue).NameServer)".Trim()
        Set-DnsClientServerAddress -InterfaceIndex $Index -ServerAddresses @('1.1.1.1', '1.0.0.1') -ErrorAction Stop
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        Log "   ✔ DNS de « $($a.Name) » : 1.1.1.1 et 1.0.0.1"
        $undo = "Restore-Dns {0} {1}" -f (ConvertTo-PsLiteral "$($a.InterfaceGuid)"), (ConvertTo-PsLiteral $static)
        Add-Change -Title ("DNS de « {0} » : Cloudflare (1.1.1.1)" -f $a.Name) -Detail $(if ($static) { "Avant : $static" } else { "Avant : DNS automatiques de la box / du fournisseur" }) -Undo $undo
    } catch {
        Add-TaskError -Title "Impossible de changer les DNS" -Cause $_.Exception.Message -FixLabel "Ouvrir les paramètres réseau" -FixAction "Open-WinUri 'ms-settings:network-status'"
    }
}
function Restore-Dns([string]$Guid, [string]$Servers) {
    Step "Retour aux DNS d'avant"
    $a = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { "$($_.InterfaceGuid)" -eq $Guid } | Select-Object -First 1
    if (-not $a) { Add-TaskError -Title "Carte réseau introuvable" -Cause "La carte réseau dont les DNS avaient été changés n'existe plus sur ce PC."; return }
    if ($Servers) { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses @($Servers -split '[,\s]+' | Where-Object { $_ }) -ErrorAction Stop }
    else { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ResetServerAddresses -ErrorAction Stop }
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Log "   ✔ DNS remis comme avant."
}

# ---------------------------------------------------------------- Écrans (fréquence de rafraîchissement)
function Get-Displays {
    $list = New-Object System.Collections.ArrayList
    $n = 0
    foreach ($l in @([AeroxDisplay]::List())) {
        $f = $l.Split('|'); if ($f.Count -lt 7) { continue }
        $n++
        $mon = $f[1]; if ($mon -match '(?i)generic|générique|^$|pnp') { $mon = '' }
        $label = $(if ($f[6] -eq '1') { 'Écran principal' } else { "Écran $n" }) + $(if ($mon) { " ($mon)" } else { '' })
        [void]$list.Add(@{ Device = $f[0]; Name = $label; Width = [int]$f[2]; Height = [int]$f[3]; Hz = [int]$f[4]; MaxHz = [int]$f[5]; Primary = ($f[6] -eq '1') })
    }
    return $list.ToArray()
}
# Contexte d'une partie (carnet de jeu) : carte graphique, version du pilote, fréquence de l'écran
function Get-GameContext([string]$Device = '') {
    $c = @{ Gpu = ''; Driver = ''; Hz = 0; MaxHz = 0; Device = '' }
    try {
        $g = @(Get-CimStatic Win32_VideoController | Where-Object { $_.Name -notmatch '(?i)remote|virtual|parsec|basic display|de base|hyper-v|vmware|virtualbox|parallels|qxl|red hat|citrix|dameware|mirage' })
        $best = $g | Sort-Object @{ E = { if ($_.Name -match '(?i)nvidia|radeon rx|radeon pro|arc ') { 0 } else { 1 } } }, @{ E = { - [double]$_.AdapterRAM } } | Select-Object -First 1
        if ($best) { $c.Gpu = "$($best.Name)".Trim(); $c.Driver = "$($best.DriverVersion)" }
    } catch {}
    # Écran où tourne le jeu (sinon l'écran principal)
    try {
        $ds = @(Get-Displays); $d = $null
        if ($Device) { $d = $ds | Where-Object { $_.Device -eq $Device } | Select-Object -First 1 }
        if (-not $d) { $d = $ds | Where-Object { $_.Primary } | Select-Object -First 1 }
        if ($d) { $c.Hz = [int]$d.Hz; $c.MaxHz = [int]$d.MaxHz; $c.Device = $d.Device }
    } catch {}
    $sync.GameCtx = $c
}
function Test-DisplayHzLow($d) { return ($d.MaxHz -ge 100 -and ($d.MaxHz - $d.Hz) -ge 20) }
function Test-Display {
    foreach ($d in @(Get-Displays)) {
        if (Test-DisplayHzLow $d) {
            Add-Issue -Id ("hz" + ($d.Device -replace '\W', '')) -Sev 'warn' -Title ("{0} tourne à {1} Hz au lieu de {2} Hz" -f $d.Name, $d.Hz, $d.MaxHz) -Detail ("{0} x {1}" -f $d.Width, $d.Height) `
                -Cause "Windows n'a jamais réglé l'écran à sa vraie fréquence : c'est très courant après une installation, un nouveau câble ou une mise à jour du pilote." `
                -Effect ("L'image est rafraîchie {0} fois par seconde au lieu de {1} : jeux et mouvements de souris moins fluides." -f $d.Hz, $d.MaxHz) `
                -FixLabel ("Passer à {0} Hz" -f $d.MaxHz) -UiFix 'display' `
                -Steps @("Clique sur le bouton : l'écran passe à $($d.MaxHz) Hz. Si l'image ne s'affiche pas bien, ne touche à rien : l'ancien réglage revient tout seul au bout de 15 secondes.", "Si l'option n'apparaît pas ou ne tient pas : vérifie le câble (DisplayPort ou HDMI 2.0 minimum pour les hautes fréquences).")
            $script:Issues[$script:Issues.Count - 1].Display = $d
        } else { Add-Ok ("{0} : {1} Hz{2}" -f $d.Name, $d.Hz, $(if ($d.Hz -ge $d.MaxHz) { ' (le maximum possible)' } else { '' })) }
    }
}
function Set-DisplayHz([string]$Device, [int]$Hz) {
    Step ("Réglage de l'écran à {0} Hz" -f $Hz)
    $r = [AeroxDisplay]::SetFrequency($Device, $Hz, $true)
    if ($r -eq 0) { Log ("   ✔ Écran réglé à {0} Hz." -f $Hz) }
    else { Add-TaskError -Title "Impossible de régler l'écran à $Hz Hz" -Code "$r" -Cause "Windows ou le pilote de la carte graphique refuse ce réglage." -FixLabel "Ouvrir les paramètres d'affichage" -FixAction "Open-WinUri 'ms-settings:display-advanced'" }
}

# ---------------------------------------------------------------- Pilotes graphiques (version installée et dernière version)
# NVIDIA : dernière version via l'API officielle de nvidia.com (identifiant du modèle tiré de la liste publique
# ZenitH-AT/nvidia-data, utilisée aussi par TinyNvidiaUpdateChecker). AMD / Intel : pas d'API publique, on se fie à l'âge.
function Get-NvidiaLatest([string]$GpuName, [bool]$Laptop) {
    $ua = @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AeroxPCCare' }
    $clean = ([regex]::Match($GpuName, '(?<=NVIDIA ).*').Value -replace '\s*\([A-Z]+\)$', '' -replace '\s+\d+GB$', '' -replace '\s+with Max-Q Design$', '' -replace '\s+COLLECTORS EDITION$', '').Trim() -replace 'Super', 'SUPER'
    if (-not $clean) { return $null }
    $data = (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ZenitH-AT/nvidia-data/main/gpu-data.json' -Headers $ua -TimeoutSec 8 -UseBasicParsing -ErrorAction Stop).Content | ConvertFrom-Json
    $pfid = $null
    foreach ($kind in $(if ($Laptop) { 'notebook', 'desktop' } else { 'desktop', 'notebook' })) {
        $p = $data.$kind.PSObject.Properties[$clean]
        if ($p) { $pfid = $p.Value; break }
    }
    if (-not $pfid) { return $null }
    $os = if ([Environment]::OSVersion.Version.Build -ge 22000) { 135 } else { 57 }
    $url = "https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php?func=DriverManualLookup&pfid=$pfid&osID=$os&dch=1&numberOfResults=10&languageCode=1078"
    $r = (Invoke-WebRequest -Uri $url -Headers $ua -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop).Content | ConvertFrom-Json
    if (-not $r -or [int]$r.Success -lt 1) { return $null }
    $pick = @($r.IDS | ForEach-Object { $_.downloadInfo } | Where-Object { "$($_.IsCRD)" -eq '0' }) | Select-Object -First 1
    if (-not $pick) { $pick = @($r.IDS)[0].downloadInfo }
    $date = $null; try { $date = [datetime]::Parse("$($pick.ReleaseDateTime)", [Globalization.CultureInfo]::InvariantCulture) } catch {}
    return @{ Version = "$($pick.Version)"; Date = $date; Url = "$($pick.DownloadURL)" }
}

# Versions des pilotes graphiques vues aux diagnostics précédents : si la version change, la personne vient de le mettre à jour
# (souvent la dernière dispo pour une carte ancienne, même si elle a plus d'un an) : on n'insiste plus tant qu'elle ne change pas.
function Test-GpuJustUpdated([string]$Name, [string]$Version) {
    $f = Join-Path $AppInfo.LogDir 'pilotes_graphiques.txt'
    $map = @{}
    try { foreach ($l in @(Get-Content -LiteralPath $f -Encoding UTF8 -ErrorAction Stop)) { $p = $l.Split('|'); if ($p.Count -ge 3) { $map[$p[0]] = @{ V = $p[1]; Up = ($p[2] -eq '1') } } } } catch {}
    $r = $map[$Name]
    $up = $false
    if ($r) { $up = $r.Up -or ($r.V -ne $Version); if ($r.V -ne $Version) { $r.V = $Version; $r.Up = $true } }
    else { $map[$Name] = @{ V = $Version; Up = $false } }
    try { [IO.File]::WriteAllLines($f, [string[]]@($map.Keys | ForEach-Object { "{0}|{1}|{2}" -f ($_ -replace '\|', '/'), $map[$_].V, $(if ($map[$_].Up) { '1' } else { '0' }) }), (New-Object System.Text.UTF8Encoding($false))) } catch {}
    return $up
}
# Vraie date d'installation du pilote de chaque carte graphique (pas la date donnée par le fabricant).
# 1) Journal de Windows « Kernel-PnP/Configuration » (événement 400 « appareil configuré ») : le premier événement qui
#    cite cette carte ET la version de pilote actuelle = son installation. 2) Sinon : création du fichier
#    C:\Windows\INF\oemNN.inf du pilote. Clé : identifiant PnP de la carte (majuscules).
function Get-GpuDriverInstallDates {
    $h = @{}
    try {
        $evs = @(Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-Kernel-PnP/Configuration'; Id = 400 } -MaxEvents 3000 -ErrorAction SilentlyContinue)
        foreach ($d in @(Get-CimInstance Win32_PnPSignedDriver -Filter "DeviceClass='DISPLAY'" -ErrorAction Stop)) {
            $id = "$($d.DeviceID)".ToUpperInvariant(); $ver = "$($d.DriverVersion)"
            if (-not $id) { continue }
            $hit = @($evs | Where-Object { $vals = @($_.Properties | ForEach-Object { "$($_.Value)" }); ($vals -contains $id) -and $ver -and ($vals -contains $ver) } | Sort-Object TimeCreated | Select-Object -First 1)
            if ($hit.Count) { $h[$id] = $hit[0].TimeCreated; continue }
            $inf = "$($d.InfName)"
            if ($inf -match '^oem\d+\.inf$') {
                $f = Join-Path $env:SystemRoot "INF\$inf"
                if (Test-Path -LiteralPath $f) { $h[$id] = (Get-Item -LiteralPath $f -Force).CreationTime }
            }
        }
    } catch {}
    return $h
}
function Get-GpuDrivers {
    $laptop = $false
    $inst = Get-GpuDriverInstallDates
    try { $laptop = [bool](@((Get-CimStatic Win32_SystemEnclosure -Quiet).ChassisTypes | Where-Object { $_ -in 8, 9, 10, 11, 14, 30, 31, 32 }).Count) } catch {}
    $list = New-Object System.Collections.ArrayList
    foreach ($g in @(Get-CimStatic Win32_VideoController -Quiet)) {
        if ($g.Name -match '(?i)remote|virtual|parsec|meta virtual|citrix|dameware|mirage|hyper-v|vmware|virtualbox|parallels|qxl|red hat') { continue }
        $vendor = if ("$($g.PNPDeviceID)" -match 'VEN_10DE' -or $g.Name -match 'NVIDIA') { 'NVIDIA' } elseif ("$($g.PNPDeviceID)" -match 'VEN_1002' -or $g.Name -match 'AMD|Radeon') { 'AMD' } elseif ("$($g.PNPDeviceID)" -match 'VEN_8086' -or $g.Name -match 'Intel') { 'Intel' } else { '' }
        $o = @{ Name = $g.Name; Vendor = $vendor; Raw = "$($g.DriverVersion)"; Version = "$($g.DriverVersion)"; Date = (ConvertTo-DateSafe $g.DriverDate); AgeDays = $null; Basic = ($g.Name -match '(?i)basic display|de base'); Latest = $null; Status = 'unknown'
                Installed = $inst["$($g.PNPDeviceID)".ToUpperInvariant()] }
        if ($o.Date) { $o.AgeDays = [int]((Get-Date) - $o.Date).TotalDays }
        if ($vendor -eq 'NVIDIA') {
            $digits = $o.Raw -replace '\D', ''
            if ($digits.Length -ge 5) { $v = $digits.Substring($digits.Length - 5); $o.Version = $v.Substring(0, 3) + '.' + $v.Substring(3) }
            try { $o.Latest = Get-NvidiaLatest $g.Name $laptop } catch { $o.LatestError = $_.Exception.Message }
            if ($o.Latest -and $o.Latest.Version) {
                $o.Status = if ([version]$o.Version -ge [version]$o.Latest.Version) { 'ok' } else { 'old' }
            }
        }
        if ($o.Status -eq 'unknown' -and $null -ne $o.AgeDays) { $o.Status = if ($o.AgeDays -ge 365) { 'old' } else { 'ok' } }
        if ($o.Basic) { $o.Status = 'none' }
        $o.Page = switch ($vendor) {
            'NVIDIA' { 'https://www.nvidia.com/fr-fr/drivers/' }
            'AMD'    { 'https://www.amd.com/fr/support/download/drivers.html' }
            'Intel'  { 'https://www.intel.fr/content/www/fr/fr/support/detect.html' }
            default  { '' }
        }
        $o.Tool = switch ($vendor) { 'NVIDIA' { 'NVIDIA App' } 'AMD' { 'AMD Software: Adrenalin Edition' } 'Intel' { 'Intel Driver & Support Assistant' } default { '' } }
        [void]$list.Add($o)
    }
    return $list.ToArray()
}

function Test-Drivers {
    foreach ($o in @(Get-GpuDrivers)) {
        if ($o.Status -eq 'none') {
            Add-Issue -Id ('gpunone-' + ($o.Name -replace '[^A-Za-z0-9]', '')) -Sev 'crit' -Title "Aucun pilote de carte graphique installé" -Detail $o.Name `
                -Cause "Windows utilise un pilote d'affichage de secours, sans accélération graphique." -Effect "Jeux et vidéos saccadent ou ne se lancent pas, résolution parfois limitée." `
                -FixLabel "Vérifier les pilotes" -UiFix 'drivers' -Steps @("Installe le pilote depuis le site du fabricant : NVIDIA App, AMD Adrenalin ou Intel Driver & Support Assistant.")
            continue
        }
        $page = if ($o.Latest -and $o.Latest.Url) { $o.Latest.Url } else { $o.Page }
        $fix = if ($page) { "if (Open-Url " + (ConvertTo-PsLiteral $page) + ") { Log '   ✔ Page officielle ouverte dans le navigateur' }" } else { '' }
        if ($o.Vendor -eq 'NVIDIA' -and $o.Latest) {
            $rel = if ($o.Latest.Date) { " (sortie le " + (Format-Date $o.Latest.Date) + ")" } else { '' }
            $late = if ($o.Latest.Date) { [int]((Get-Date) - $o.Latest.Date).TotalDays } else { 0 }
            if ($o.Status -eq 'old' -and ($late -ge 21 -or ($o.AgeDays -ge 120))) {
                Add-Issue -Id ('gpu-' + ($o.Name -replace '[^A-Za-z0-9]', '')) -Sev 'warn' -Title ("Pilote NVIDIA pas à jour : {0} installé, {1} disponible" -f $o.Version, $o.Latest.Version) -Detail ("{0}{1}" -f $o.Name, $rel) `
                    -Cause "NVIDIA sort régulièrement des pilotes qui corrigent des plantages et améliorent les performances des jeux récents." -Effect "Crashs ou bugs graphiques possibles dans certains jeux, performances un peu plus faibles." `
                    -FixLabel "Télécharger le pilote officiel" -FixAction $fix -OpenOnly `
                    -Steps @("Clique sur le bouton : le pilote officiel se télécharge depuis nvidia.com.", "Lance le fichier téléchargé et choisis l'installation « Express ».", "Ou, plus simple : installe la « NVIDIA App » qui fait les mises à jour toute seule.", "Redémarre le PC à la fin.")
            } else { Add-Ok ("Pilote NVIDIA à jour : {0}{1}" -f $o.Version, $(if ($o.Status -eq 'old') { " (la {0} vient de sortir{1})" -f $o.Latest.Version, $rel } else { '' })) }
            continue
        }
        if ($o.Status -eq 'old' -and $o.Date -and (Test-GpuJustUpdated $o.Name $o.Version)) {
            Add-Ok ("Pilote graphique mis à jour : {0} (version {1}, la plus récente proposée pour cette carte)" -f $o.Name, $o.Version)
            continue
        }
        if ($o.Status -eq 'old' -and $o.Date) {
            $steps = if ($o.Tool) { @("Télécharge « $($o.Tool) » sur la page officielle.", "Installe-le, ouvre-le et lance la mise à jour du pilote.", "Sur un PC portable, le site du fabricant du portable (rubrique Support) a parfois un pilote plus adapté.", "Redémarre le PC.", "Si l'outil officiel te dit que ton pilote est déjà le plus récent : ta carte n'a plus de mise à jour, clique sur « Ne plus signaler ».") } else { @("Ouvre Windows Update > Options avancées > Mises à jour facultatives > Pilotes.") }
            Add-Issue -Id ('gpu-' + ($o.Name -replace '[^A-Za-z0-9]', '')) -Sev 'warn' -Title ("Le pilote de la carte graphique date de {0}" -f (Format-Date $o.Date 'MMMM yyyy')) -Detail ("{0} (version {1})" -f $o.Name, $o.Version) `
                -Cause "Ce pilote a plus d'un an. Les fabricants publient régulièrement des versions qui corrigent des plantages et des bugs d'affichage en jeu : il en existe peut-être une plus récente pour ta carte (AEROX n'a pas pu vérifier la dernière version)." `
                -Effect "Si une version plus récente existe : crashs ou bugs graphiques possibles dans certains jeux, performances un peu plus faibles." `
                -FixLabel $(if ($fix) { "Télécharger le pilote officiel" } else { "Vérifier les pilotes" }) -FixAction $fix -UiFix $(if ($fix) { '' } else { 'drivers' }) -OpenOnly:([bool]$fix) -Steps $steps
        } else { Add-Ok ("Pilote graphique récent : {0}" -f $o.Name) }
    }
    $bad = @(Get-ProblemDevices -Full)
    foreach ($d in $bad) { Log ("   • Périphérique en panne : {0} (type {1}, code {2} : {3}) {4}" -f $d.Name, $d.Class, $d.Code, $d.Reason, $d.HwId) }
    if ($bad.Count -gt 0) {
        $desc = ($bad | Select-Object -First 3 | ForEach-Object { "$($_.Name) ($($_.Reason))" }) -join ', '
        $canRe = @($bad | Where-Object { $_.Reinstall }).Count -gt 0
        # Dit clairement de quel élément il s'agit (retour testeur : « problème de pilote alors que la mise à jour est bonne »
        # → il pensait à la carte graphique, alors que c'était un autre périphérique)
        $who = if ($bad.Count -eq 1) { "« $($bad[0].Name) » ($($bad[0].Kind))" } else { (@($bad | Select-Object -First 3 | ForEach-Object { "« $($_.Name) » ($($_.Kind))" }) -join ', ') }
        $notGpu = -not @($bad | Where-Object { $_.Class -eq 'Display' }).Count
        $cause = $(if ($notGpu) { "Ce n'est pas la carte graphique : c'est $who. " } else { "C'est $who. " }) + ((@($bad | Select-Object -First 3 | ForEach-Object { $_.Why }) | Select-Object -Unique) -join ' ')
        Add-Issue -Id 'devices' -Sev 'warn' -Title ("{0} : problème de pilote" -f $(if ($bad.Count -eq 1) { "« $($bad[0].Name) »" } else { "$($bad.Count) périphériques" })) -Detail $desc `
            -Cause $cause `
            -Effect "L'élément concerné peut ne pas marcher (son, Wi-Fi, Bluetooth, USB, manette...)." `
            -FixLabel $(if ($canRe) { "Réinstaller ce périphérique" } else { "Vérifier les pilotes" }) -FixAction $(if ($canRe) { 'Repair-ProblemDevices' } else { '' }) -UiFix $(if ($canRe) { '' } else { 'drivers' }) `
            -Confirm $(if ($canRe) { "Windows va retirer puis réinstaller le pilote de ce périphérique (il disparaît quelques secondes). Rien d'autre n'est touché.`n`nContinuer ?" } else { '' }) `
            -Steps @(($bad | Select-Object -First 3 | ForEach-Object { $_.Step }) + "Si le problème revient après un redémarrage : prends le pilote sur le site du fabricant de ton PC ou de ta carte mère (rubrique Support, avec le modèle exact)." | Select-Object -Unique)
    } else { Add-Ok "Tous les périphériques ont un pilote qui fonctionne" }
}

# « Aucun antivirus actif » et « Protection en temps réel désactivée » décrivent la même cause quand Windows Defender est le seul
# antivirus et que sa protection permanente est coupée : on ne garde alors que le second (avec son bouton « Réactiver »),
# au lieu de deux alertes critiques pour un seul problème. Et si Defender lui-même affirme protéger en temps réel, on ne
# prétend jamais « aucun antivirus » (le Centre de sécurité peut être en retard sur l'état réel).
function Test-NoAvIssue([int]$ActiveCount, [int]$ThirdCount, $DefenderEnabled, $DefenderRealtime) {
    if ($ActiveCount -gt 0) { return $false }
    if ($DefenderEnabled -and $DefenderRealtime) { return $false }
    if ($ThirdCount -eq 0 -and $DefenderEnabled -and -not $DefenderRealtime) { return $false }
    return $true
}
function Test-Security {
    $thirdAv = @()
    $mp = $null; try { $mp = Get-MpComputerStatus -ErrorAction Stop } catch {}
    try {
        $av = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop)
        $active = @($av | Where-Object { ($_.productState -band 0x1000) -ne 0 })
        $thirdAv = @($av | Where-Object { $_.displayName -notmatch 'Defender' } | ForEach-Object { $_.displayName } | Select-Object -Unique)
        if (Test-NoAvIssue $active.Count $thirdAv.Count ($mp -and $mp.AntivirusEnabled) ($mp -and $mp.RealTimeProtectionEnabled)) {
            Add-Issue -Id 'noav' -Sev 'crit' -Title "Aucun antivirus actif" -Detail "Protection désactivée" `
                -Cause "Aucun antivirus n'est en marche : il a été désactivé, ou un antivirus tiers a expiré." -Effect "Le PC n'est pas protégé contre les virus et arnaques." `
                -FixLabel "Ouvrir Sécurité Windows" -FixAction "Open-WinUri 'windowsdefender:'" -OpenOnly `
                -Steps @("Dans Sécurité Windows > Protection contre les virus et menaces, active la protection.", "Si un antivirus payant a expiré, désinstalle-le : Windows Defender reprendra la main gratuitement.")
        }
        if ($thirdAv.Count -gt 1) {
            Add-Issue -Id 'multiav' -Sev 'warn' -Title "Plusieurs antivirus sont installés" -Detail ($thirdAv -join ', ') `
                -Cause "Plusieurs antivirus surveillent les mêmes fichiers en même temps." -Effect "Ils ralentissent le PC et peuvent se bloquer entre eux." `
                -FixLabel "Ouvrir les applications" -FixAction "Open-WinUri 'ms-settings:appsfeatures'" -OpenOnly -Steps @("Garde-en un seul (Windows Defender suffit largement).", "Désinstalle les autres dans Paramètres > Applications.")
        }
    } catch {}
    try {
        if (-not $mp) { throw 'Windows Defender ne répond pas' }
        if ($mp.AntivirusEnabled -and $thirdAv.Count -eq 0) {
            if (-not $mp.RealTimeProtectionEnabled) {
                Add-Issue -Id 'rtp' -Sev 'crit' -Title "La protection en temps réel est désactivée" -Detail "Windows Defender" `
                    -Cause "La surveillance permanente de Windows Defender a été coupée (à la main ou par un logiciel)." -Effect "Un virus peut s'installer sans être détecté." `
                    -FixLabel "Réactiver la protection" -FixAction 'Enable-RealtimeProtection'
            } else { Add-Ok "Antivirus Windows Defender actif" }
            if ($mp.AntivirusSignatureAge -gt 3) {
                Add-Issue -Id 'sig' -Sev 'warn' -Title "L'antivirus n'est pas à jour" -Detail "Dernière mise à jour il y a $($mp.AntivirusSignatureAge) jours" `
                    -Cause "La liste des virus connus n'a pas été mise à jour récemment." -Effect "Les nouveaux virus ne sont pas reconnus." `
                    -FixLabel "Mettre à jour l'antivirus" -FixAction 'Update-DefenderSignatures'
            }
        } elseif ($thirdAv.Count -gt 0) { Add-Ok ("Antivirus actif : {0}" -f ($thirdAv -join ', ')) }
    } catch {}
    try {
        $thirdFw = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName FirewallProduct -ErrorAction SilentlyContinue)
        $off = @(Get-NetFirewallProfile -ErrorAction Stop | Where-Object { -not $_.Enabled })
        if ($off.Count -gt 0 -and $thirdFw.Count -eq 0) {
            Add-Issue -Id 'fw' -Sev 'crit' -Title "Le pare-feu Windows est désactivé" -Detail ("Profils coupés : {0}" -f (($off | ForEach-Object { $_.Name }) -join ', ')) `
                -Cause "Le pare-feu a été désactivé, à la main ou par un logiciel." -Effect "Le PC est exposé aux attaques venant du réseau, surtout en Wi-Fi public." `
                -FixLabel "Réactiver le pare-feu" -FixAction 'Enable-Firewall'
        } else { Add-Ok "Pare-feu activé" }
    } catch {}
    try {
        $lua = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name EnableLUA -ErrorAction Stop).EnableLUA
        if ($lua -eq 0) {
            Add-Issue -Id 'uac' -Sev 'warn' -Title "Le contrôle de compte (UAC) est désactivé" -Detail "Les logiciels obtiennent les droits admin sans demander" `
                -Cause "Le contrôle de compte d'utilisateur a été coupé." -Effect "N'importe quel logiciel, même malveillant, peut modifier Windows sans que tu sois prévenu." `
                -FixLabel "Réactiver l'UAC" -FixAction 'Enable-UAC'
        }
    } catch {}
    try {
        $rp = @(Get-ComputerRestorePoint -ErrorAction Stop)
        if ($rp.Count -eq 0) {
            Add-Issue -Id 'restore' -Sev 'warn' -Title "Aucun point de restauration" -Detail "Protection du système désactivée ou vide" `
                -Cause "Windows ne fait aucune sauvegarde de ses réglages sur ce PC." -Effect "Impossible de revenir en arrière si une mise à jour ou un pilote pose problème." `
                -FixLabel "Activer et créer" -FixAction 'New-RestorePoint'
        } else { Add-Ok ("Point de restauration disponible ({0})" -f ([Management.ManagementDateTimeConverter]::ToDateTime(($rp | Select-Object -Last 1).CreationTime).ToString('dd/MM/yyyy'))) }
    } catch {}
    # Signes forts et rapides d'intrusion : renvoient vers l'analyse de sécurité (jamais ignorables)
    Test-SecQuickSigns
}

function Test-Network {
    $n = Get-NetworkStatus
    if (-not $n.Route) {
        Add-Issue -Id 'nonet' -Sev 'crit' -Title "Le PC n'est connecté à aucun réseau" -Detail "Ni câble, ni Wi-Fi" `
            -Cause "Aucun câble Ethernet branché et pas de Wi-Fi connecté (ou carte réseau désactivée)." -Effect "Pas d'Internet, pas de mises à jour." `
            -Steps @("Vérifie que le câble est bien branché, ou reconnecte-toi au Wi-Fi (icône en bas à droite).", "Vérifie que le mode Avion n'est pas activé.")
        return
    }
    if (-not $n.Internet -and -not $n.Dns) {
        Add-Issue -Id 'noint' -Sev 'crit' -Title "Pas d'accès à Internet" -Detail $(if ($n.GwOk) { "La box répond, mais Internet ne passe pas" } else { "La box ne répond pas" }) `
            -Cause $(if ($n.GwOk) { "Coupure chez ton fournisseur, ou réglages réseau de Windows abîmés." } else { "La box est éteinte, plantée, ou le PC n'est pas vraiment relié à elle." }) `
            -Effect "Pas d'Internet, pas de mises à jour." -FixLabel "Réparer la connexion" -FixAction 'Repair-Network' `
            -Confirm "Les réglages réseau de Windows vont être remis à zéro. La connexion se coupera quelques secondes et il faudra redémarrer le PC." `
            -Steps @("Redémarre la box : débranche-la 30 secondes puis rebranche-la.", "Si rien ne change, utilise le bouton vert, puis redémarre le PC.", "Si ça ne marche toujours pas, appelle ton fournisseur d'accès.")
        return
    }
    if (-not $n.Dns) {
        Add-Issue -Id 'dns' -Sev 'crit' -Title "Les sites Internet ne sont pas trouvés (DNS)" -Detail "Internet répond, mais pas les noms de sites" `
            -Cause "Le service qui traduit les noms de sites (DNS) ne répond plus ou le cache DNS de Windows est abîmé." -Effect "Les sites ne s'ouvrent pas alors que la connexion marche." `
            -FixLabel "Réparer la connexion" -FixAction 'Repair-Network' -Confirm "Les réglages réseau de Windows vont être remis à zéro. Il faudra redémarrer le PC."
    } else { Add-Ok ("Internet fonctionne (ping {0} ms)" -f $n.Avg) }
    if ($n.Internet -and $n.Avg -gt 80) {
        Add-Issue -Id 'ping' -Sev 'warn' -Title "Connexion lente (ping $($n.Avg) ms)" -Detail "Un bon ping est sous 40 ms" `
            -Cause "Un téléchargement en cours, un Wi-Fi faible ou une box saturée ralentit la connexion." -Effect "Lag en jeu et coupures en appel." `
            -Steps @("Mets en pause les téléchargements (Steam, Windows Update, streaming sur d'autres appareils).", "Passe en câble Ethernet si possible.", "Redémarre la box.")
    }
    if ($n.Signal -ge 0) {
        if ($n.Signal -lt 60) {
            Add-Issue -Id 'wifi' -Sev 'warn' -Title "Signal Wi-Fi faible ($($n.Signal) %)" -Detail "Au-dessus de 70 %, c'est confortable" `
                -Cause "Le PC est loin de la box, ou des murs et appareils gênent le signal." -Effect "Lags en jeu et coupures en appel vocal." `
                -Steps @("Le mieux : branche un câble Ethernet entre le PC et la box.", "Sinon : rapproche la box ou ajoute un répéteur Wi-Fi / CPL.", "Évite de poser la box dans un meuble fermé.")
        } else { Add-Ok "Signal Wi-Fi correct ($($n.Signal) %)" }
    }
    if ($n.Internet -or $n.Dns) { Test-ConnectionStability; Test-NetBlockers }
}

# ---------------------------------------------------------------- Ce qui empêche des sites ou des téléchargements de passer
# (retour testeur : « impossible de retélécharger Discord » alors qu'Internet marche). Quatre causes classiques :
# un proxy réglé en douce, le fichier hosts qui détourne des sites, l'heure du PC fausse, un DNS qui bloque un site.
$script:HostsWatch = '(?i)(^|\.)(discord(app)?\.(com|net|gg|media)|discordcdn\.com|microsoft\.com|windowsupdate\.com|windows\.com|live\.com|google\.[a-z.]+|youtube\.com|gstatic\.com|steampowered\.com|steamcommunity\.com|steamstatic\.com|epicgames\.com|riotgames\.com|battle\.net|blizzard\.com|ea\.com|ubisoft\.com|nvidia\.com|amd\.com|intel\.com|github\.com|malwarebytes\.com|kaspersky\.[a-z]+|avast\.com|bitdefender\.[a-z]+|eset\.com|norton\.com|mcafee\.com)$'
$script:HostsIgnore = '(?i)(telemetry|vortex|watson|settings-win|\.data\.microsoft\.com|(^|\.)ads?\.|adservice|doubleclick|analytics|metrics)'
function Get-HostsHijacks([string]$File = '') {
    $f = if ($File) { $File } else { Join-Path $env:SystemRoot 'System32\drivers\etc\hosts' }
    $out = @()
    try {
        $n = 0
        foreach ($l in [IO.File]::ReadAllLines($f)) {
            $n++
            $t = ($l -replace '#.*$', '').Trim()
            if (-not $t) { continue }
            $p = $t -split '\s+'
            if ($p.Count -lt 2) { continue }
            foreach ($h in $p[1..($p.Count - 1)]) { if ($h -match $script:HostsWatch -and $h -notmatch $script:HostsIgnore) { $out += @{ Line = $n; Host = $h; Ip = $p[0] } } }
        }
    } catch {}
    return $out
}
function Get-ClockSkew {
    # Heure donnée par un serveur de Microsoft (en-tête « Date »), d'abord sans chiffrement : si l'heure du PC est très
    # fausse, les connexions sécurisées échouent justement à cause d'elle
    foreach ($u in 'http://www.msftconnecttest.com/connecttest.txt', 'https://www.microsoft.com/') {
        try {
            $r = Invoke-WebRequest -Uri $u -Method Head -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop
            $d = [datetime]::Parse($r.Headers['Date'], [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AdjustToUniversal)
            return ((Get-Date).ToUniversalTime() - $d).TotalSeconds
        } catch {}
    }
    return $null
}
function Get-UserProxy {
    $k = "$((Get-SessionUser).Hkcu)\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    try { $p = Get-ItemProperty -LiteralPath $k -ErrorAction Stop; return @{ Enable = [int]$p.ProxyEnable; Server = "$($p.ProxyServer)"; Pac = "$($p.AutoConfigURL)" } } catch { return $null }
}
function Test-NetBlockers {
    # 1. Proxy
    $px = Get-UserProxy
    if ($px -and (($px.Enable -eq 1 -and $px.Server) -or $px.Pac)) {
        $what = if ($px.Pac) { "script de configuration $($px.Pac)" } else { "serveur $($px.Server)" }
        Add-Issue -Id 'proxy' -Sev 'warn' -Title "Un proxy fait passer tes connexions par un autre serveur" -Detail $what `
            -Cause "Windows envoie tes connexions Internet par un intermédiaire ($what). Normal sur un PC d'entreprise ou d'école ; sinon, c'est souvent un logiciel publicitaire ou un « VPN » mal désinstallé." `
            -Effect "Sites ou téléchargements qui ne passent pas (Discord, mises à jour…), connexion lente, et tes connexions peuvent être espionnées." `
            -FixLabel "Désactiver le proxy" -FixAction 'Disable-UserProxy' -Confirm "Le proxy sera désactivé : Windows se connectera directement à Internet.`n`nSur un PC d'entreprise ou d'école, ne le fais pas. Annulable dans l'historique." `
            -Steps @("Si c'est un PC d'entreprise ou d'école : ne touche à rien, c'est voulu.", "Sinon : désactive-le (bouton vert), puis désinstalle le logiciel qui l'a mis (VPN gratuit, « optimiseur », barre d'outils…).")
    } elseif ($px) { Add-Ok "Pas de proxy : connexion directe à Internet" }
    # 2. Fichier hosts
    $hj = @(Get-HostsHijacks)
    if ($hj.Count) {
        $names = @($hj | ForEach-Object { $_.Host } | Select-Object -Unique)
        Add-Issue -Id 'hosts' -Sev 'warn' -Title "Des sites sont bloqués ou détournés sur ce PC (fichier hosts)" -Detail ((@($names | Select-Object -First 6) -join ', ') + $(if ($names.Count -gt 6) { " et $($names.Count - 6) autre(s)" } else { '' })) `
            -Cause "Le fichier « hosts » de Windows envoie ces sites vers une autre adresse : ils ne s'ouvrent plus, ou ouvrent un faux site. C'est souvent un virus, un logiciel de triche/crack ou un ancien « bloqueur »." `
            -Effect "Ces sites, leurs mises à jour ou leurs téléchargements ne marchent pas (ex. impossible de télécharger Discord)." `
            -FixLabel "Débloquer ces sites" -FixAction 'Repair-Hosts' -Confirm "Les lignes qui détournent ces sites seront retirées du fichier hosts (une copie est gardée, annulable dans l'historique).`n`nLes autres lignes ne sont pas touchées." `
            -Steps @("Le bouton retire seulement les lignes de ces sites (copie de sauvegarde gardée).", "Puis fais une analyse antivirus complète (Windows Defender > Analyse complète).")
    } else { Add-Ok "Aucun site important détourné (fichier hosts)" }
    # 3. Heure du PC
    $sk = Get-ClockSkew
    if ($null -ne $sk -and [math]::Abs($sk) -ge 300) {
        $mins = [math]::Round([math]::Abs($sk) / 60)
        $txt = if ($mins -ge 120) { "{0} h" -f [math]::Round($mins / 60) } else { "$mins min" }
        Add-Issue -Id 'clock' -Sev $(if ([math]::Abs($sk) -ge 3600) { 'crit' } else { 'warn' }) -Title "L'heure du PC est fausse de $txt" -Detail $(if ($sk -gt 0) { "Le PC est en avance" } else { "Le PC est en retard" }) `
            -Cause "Les sites sécurisés vérifient l'heure : si celle du PC est fausse, ils refusent la connexion. Souvent la pile de la carte mère usée, ou la synchronisation de l'heure désactivée." `
            -Effect "Sites « connexion non sécurisée », téléchargements et mises à jour qui échouent, jeux en ligne qui refusent de se connecter." `
            -FixLabel "Remettre à l'heure" -FixAction 'Repair-Clock' -Steps @("Le bouton active la mise à l'heure automatique et synchronise tout de suite.", "Si l'heure redevient fausse à chaque allumage : la pile de la carte mère (CR2032, ~3 €) est à changer.")
    } elseif ($null -ne $sk) { Add-Ok "Heure du PC juste" }
    # 4. Sites importants qui ne répondent pas au nom (DNS qui bloque, contrôle parental de la box…)
    $blocked = @()
    foreach ($h in 'discord.com', 'dl.discordapp.net', 'download.microsoft.com', 'store.steampowered.com') {
        try {
            $a = @(Resolve-DnsName -Name $h -Type A -DnsOnly -QuickTimeout -ErrorAction SilentlyContinue | Where-Object { $_.IP4Address } | ForEach-Object { $_.IP4Address })
            $a6 = @(Resolve-DnsName -Name $h -Type AAAA -DnsOnly -QuickTimeout -ErrorAction SilentlyContinue | Where-Object { $_.IP6Address } | ForEach-Object { "$($_.IP6Address)" })
            # Bloqué seulement si le site n'a d'adresse ni en IPv4 ni en IPv6, ou une adresse locale / vide (filtre)
            $bad = @($a | Where-Object { $_ -match '^(0\.0\.0\.0|127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)' }).Count + @($a6 | Where-Object { $_ -match '^(::1?|fe80:|fc|fd)' }).Count
            if ((-not $a.Count -and -not $a6.Count) -or $bad) { $blocked += $h }
        } catch { $blocked += $h }
    }
    if ($blocked.Count -and $blocked.Count -lt 4) {
        Add-Issue -Id 'dnsblock' -Sev 'warn' -Title "Certains sites sont bloqués par le DNS" -Detail ($blocked -join ', ') `
            -Cause "Le service qui traduit les noms de sites (DNS de ta box ou de ton fournisseur) ne donne pas la bonne adresse pour ces sites : contrôle parental, filtre de la box, ou DNS en panne." `
            -Effect "Ces sites et leurs téléchargements ne marchent pas." `
            -Steps @("Regarde le contrôle parental / filtrage de ta box (interface de la box, souvent 192.168.1.1).", "Ou passe sur un DNS public (Cloudflare 1.1.1.1 ou Google 8.8.8.8) dans Paramètres > Réseau > propriétés de ta connexion > Attribution du serveur DNS.")
    }
}
function Disable-UserProxy {
    Step "Désactivation du proxy"
    $k = "$((Get-SessionUser).Hkcu)\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $old = Get-UserProxy
    try {
        Set-ItemProperty -LiteralPath $k -Name ProxyEnable -Value 0 -Type DWord -ErrorAction Stop
        if ($old.Pac) { Remove-ItemProperty -LiteralPath $k -Name AutoConfigURL -ErrorAction SilentlyContinue }
        Log "   ✔ Proxy désactivé : Windows se connecte directement à Internet."
        Log "   → Désinstalle le logiciel qui l'avait mis (VPN gratuit, « optimiseur »…), sinon il peut le remettre."
        Add-Change -Title "Proxy désactivé" -Detail $(if ($old.Pac) { "Script : $($old.Pac)" } else { "Serveur : $($old.Server)" }) -Undo ("Set-UserProxy {0} {1} {2}" -f [int]$old.Enable, (ConvertTo-PsLiteral $old.Server), (ConvertTo-PsLiteral $old.Pac))
    } catch { Add-TaskError -Title "Impossible de désactiver le proxy" -Cause $_.Exception.Message -FixLabel "Ouvrir les réglages du proxy" -FixAction "Open-WinUri 'ms-settings:network-proxy'" }
}
function Set-UserProxy([int]$Enable, [string]$Server, [string]$Pac) {
    Step "Remise du proxy"
    $k = "$((Get-SessionUser).Hkcu)\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    Set-ItemProperty -LiteralPath $k -Name ProxyEnable -Value $Enable -Type DWord
    if ($Server) { Set-ItemProperty -LiteralPath $k -Name ProxyServer -Value $Server -Type String }
    if ($Pac) { Set-ItemProperty -LiteralPath $k -Name AutoConfigURL -Value $Pac -Type String }
    Log "   ✔ Proxy remis comme avant."
}
# Écrit le fichier hosts même s'il a été verrouillé : lecture seule (souvent mise par le logiciel qui l'a détourné) ou
# droits retirés (remis aux droits normaux de Windows). Si c'est un antivirus qui le protège, c'est dit clairement.
function Write-HostsFile([string[]]$Lines) {
    $f = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
    $it = Get-Item -LiteralPath $f -Force
    $wasRO = [bool]($it.Attributes -band [IO.FileAttributes]::ReadOnly)
    if ($wasRO) { $it.Attributes = $it.Attributes -band (-bnot [IO.FileAttributes]::ReadOnly); Log "   • Le fichier hosts était en lecture seule (souvent pour empêcher de le réparer) : déverrouillé" }
    try { [IO.File]::WriteAllLines($f, $Lines); return }
    catch [UnauthorizedAccessException] {
        # Droits du fichier modifiés : AEROX en reprend la propriété (administrateurs) et remet les droits par défaut de Windows
        $null = Invoke-Native 'takeown.exe' @('/f', $f, '/a') -Quiet
        $null = Invoke-Native 'icacls.exe' @($f, '/reset') -Quiet
        Log "   • Les droits du fichier hosts avaient été changés : remis comme Windows les met par défaut"
        [IO.File]::WriteAllLines($f, $Lines)
    }
}
function Repair-Hosts {
    Step "Déblocage des sites détournés (fichier hosts)"
    $f = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
    try {
        $lines = [IO.File]::ReadAllLines($f)
        $hj = @(Get-HostsHijacks); if (-not $hj.Count) { Log "   • Rien à débloquer."; return }
        $bad = @($hj | ForEach-Object { $_.Line })
        $bak = Join-Path (Get-SecureDir 'sauvegardes') ("hosts-{0:yyyyMMdd-HHmmss}.txt" -f (Get-Date))
        [IO.File]::WriteAllLines($bak, $lines)
        $keep = for ($i = 0; $i -lt $lines.Count; $i++) { if ($bad -notcontains ($i + 1)) { $lines[$i] } }
        Write-HostsFile ([string[]]@($keep))
        $null = Invoke-Native 'ipconfig.exe' @('/flushdns') -Quiet
        Log ("   ✔ {0} ligne(s) retirée(s) : {1}" -f $bad.Count, ((@($hj | ForEach-Object { $_.Host }) | Select-Object -Unique) -join ', '))
        Log "   → Fais aussi une analyse antivirus complète : ces lignes ont souvent été mises par un logiciel malveillant."
        Add-Change -Title "Sites débloqués (fichier hosts)" -Detail "Copie de l'ancien fichier gardée" -Undo ("Restore-HostsBackup {0}" -f (ConvertTo-PsLiteral $bak))
    } catch {
        # Encore refusé : c'est l'antivirus qui protège le fichier (Avast, Kaspersky, Bitdefender… le font)
        $av = @(); try { $av = @(Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName AntiVirusProduct -ErrorAction Stop | Where-Object { $_.displayName -notmatch '(?i)defender' } | ForEach-Object { "$($_.displayName)" }) } catch {}
        $who = if ($av.Count) { "ton antivirus « $($av -join ', ') »" } else { "un antivirus ou un logiciel de protection" }
        Add-TaskError -Title "Le fichier hosts est protégé par $who" -Cause ("Windows refuse la modification même en administrateur : c'est $who qui bloque le fichier. ($($_.Exception.Message))") `
            -Effect "Les sites détournés restent bloqués pour l'instant." -FixLabel "Réessayer" -FixAction 'Repair-Hosts' `
            -Steps @("Ouvre $(if ($av.Count) { $av[0] } else { "ton antivirus" }) et désactive sa protection 10 minutes (ou sa « protection du fichier hosts » / « auto-défense »).", "Clique sur « Réessayer » dans AEROX, puis réactive la protection.", "Si tu ne connais pas cet antivirus ou ne l'as pas installé toi-même : désinstalle-le (Windows Defender suffit).")
    }
}
function Restore-HostsBackup([string]$Path) {
    Step "Remise de l'ancien fichier hosts"
    $root = Get-SecureDir 'sauvegardes'
    $full = [IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($full) -notmatch '^hosts-\d{8}-\d{6}\.txt$' -or -not [AeroxSafeDelete]::IsDirectPath($full)) { throw "Copie de sauvegarde refusée (elle doit venir du dossier protégé d'AEROX)." }
    Write-HostsFile ([string[]]@([IO.File]::ReadAllLines($full)))
    $null = Invoke-Native 'ipconfig.exe' @('/flushdns') -Quiet
    Log "   ✔ Ancien fichier hosts remis."
}
function Repair-Clock {
    Step "Remise à l'heure du PC"
    try {
        Set-Service -Name W32Time -StartupType Automatic -ErrorAction SilentlyContinue
        if ((Get-Service W32Time).Status -ne 'Running') { Start-Service W32Time -ErrorAction Stop }
        $null = Invoke-Native 'w32tm.exe' @('/config', '/manualpeerlist:time.windows.com,0x9', '/syncfromflags:manual', '/update') -Quiet
        $null = Invoke-Native 'w32tm.exe' @('/resync', '/force') -Quiet
        try { Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters' -Name Type -Value 'NTP' -ErrorAction SilentlyContinue } catch {}
        Start-Sleep -Seconds 2
        $sk = Get-ClockSkew
        if ($null -ne $sk -and [math]::Abs($sk) -lt 120) { Log "   ✔ Le PC est à l'heure, et se remettra à l'heure tout seul." }
        else { Log "   • Synchronisation demandée. Si l'heure reste fausse : Paramètres > Heure et langue > « Synchroniser maintenant »." }
        Add-Change -Kind 'info' -Title "Heure du PC remise à l'heure (synchronisation automatique activée)"
    } catch { Add-TaskError -Title "Impossible de remettre le PC à l'heure" -Cause $_.Exception.Message -FixLabel "Ouvrir les réglages de l'heure" -FixAction "Open-WinUri 'ms-settings:dateandtime'" }
}

# ---------------------------------------------------------------- Discord qui bugue ou ne s'installe plus
function Repair-Discord {
    Step "Discord : vérification et réparation"
    $roam = Get-SessionFolder 'AppData'; $loc = Get-SessionFolder 'Local AppData'
    # 1. Fermer Discord (sinon ses fichiers sont verrouillés)
    $ps = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^(Discord|DiscordPTB|DiscordCanary)$' -or ($_.ProcessName -eq 'Update' -and "$($_.Path)" -match '(?i)\\Discord') })
    if ($ps.Count) { $ps | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2; Log "   ✔ Discord fermé" }
    # 2. Caches (Discord les recrée ; tu restes connecté, tes réglages sont gardés)
    $freed = [double]0
    foreach ($v in 'discord', 'discordptb', 'discordcanary') {
        foreach ($c in 'Cache', 'Code Cache', 'GPUCache', 'DawnCache', 'DawnGraphiteCache', 'DawnWebGPUCache') {
            $d = Join-Path (Join-Path $roam $v) $c
            if (Test-Path -LiteralPath $d) { $before = [double][AeroxNative]::FolderSize($d); $null = Remove-PathContent $d; $freed += [math]::Max([double]0, $before - [double][AeroxNative]::FolderSize($d)) }
        }
    }
    Log ("   ✔ Cache de Discord vidé ({0}) : ça règle la plupart des bugs d'affichage, d'écran gris ou de chargement sans fin" -f (Format-Size $freed))
    # 3. Installation abîmée (cause n° 1 de « Installation has failed »)
    $inst = Join-Path $loc 'Discord'
    if ((Test-Path -LiteralPath $inst) -and -not (Test-Path -LiteralPath (Join-Path $inst 'Update.exe'))) {
        Log "   ⚠ L'installation de Discord est incomplète (dossier sans son programme de mise à jour) : c'est ce qui fait échouer la réinstallation."
        Add-TaskError -Title "Installation de Discord abîmée" -Cause "Un ancien dossier de Discord à moitié supprimé bloque la nouvelle installation." `
            -FixLabel "Mettre l'ancien dossier à la corbeille" -FixAction 'Remove-DiscordLeftovers' -Confirm "L'ancien dossier du programme Discord ira à la corbeille (tes messages et serveurs sont sur Internet, rien n'est perdu ; il faudra peut-être te reconnecter).`n`nContinuer ?" `
            -Steps @("Après ça, télécharge Discord sur discord.com et installe-le.")
    }
    # 4. Le site de téléchargement répond-il ? Sinon, pourquoi (DNS, heure, proxy, hosts, antivirus)
    $why = Test-SiteReachable 'https://discord.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=win&arch=x64'
    if ($why -eq 'ok') { Log "   ✔ Le téléchargement de Discord est joignable depuis ce PC" }
    else {
        Log "   ⚠ Le téléchargement de Discord ne passe pas : $why"
        Add-TaskError -Title "Discord ne peut pas être téléchargé depuis ce PC" -Cause $why -Effect "L'installateur de Discord ne se télécharge pas." `
            -Steps @("Lance le diagnostic complet : il cherche ce qui bloque (proxy, fichier hosts, heure du PC, DNS).", "Si tu as un antivirus en plus de Windows Defender : désactive son « analyse web » le temps du téléchargement.")
    }
    Log "✅ Relance Discord. S'il ne s'ouvre plus du tout : réinstalle-le depuis discord.com (tes serveurs et messages sont gardés sur ton compte)."
}
function Remove-DiscordLeftovers {
    Step "Ancien dossier de Discord à la corbeille"
    $inst = Join-Path (Get-SessionFolder 'Local AppData') 'Discord'
    if (-not (Test-Path -LiteralPath $inst) -or -not [AeroxSafeDelete]::IsDirectPath($inst)) { Log "   • Rien à retirer."; return }
    Get-Process -ErrorAction SilentlyContinue | Where-Object { "$($_.Path)" -like "$inst\*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    Add-Type -AssemblyName Microsoft.VisualBasic
    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($inst, 'OnlyErrorDialogs', 'SendToRecycleBin')
    if (Test-Path -LiteralPath $inst) { Add-TaskError -Title "L'ancien dossier de Discord n'a pas pu être retiré" -Cause "Un fichier est encore utilisé." -Steps @("Redémarre le PC puis réessaie.") }
    else { Log "   ✔ Ancien dossier mis à la corbeille. Installe maintenant Discord depuis discord.com."; [void](Open-Url 'https://discord.com/download') }
}
# Un site répond-il ? « ok », ou la raison en mots simples
function Test-SiteReachable([string]$Url) {
    try { $null = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec 12 -MaximumRedirection 3 -ErrorAction Stop; return 'ok' }
    catch {
        $ex = $_.Exception
        if ($ex -is [System.Net.WebException]) {
            if ($ex.Response) { return 'ok' }   # le serveur a répondu (même par un refus) : le chemin est ouvert
            switch ("$($ex.Status)") {
                'NameResolutionFailure' { return "le nom du site n'est pas trouvé (DNS ou fichier hosts qui le bloque)" }
                'TrustFailure' { return "la connexion sécurisée est refusée (heure du PC fausse, ou antivirus qui inspecte le web)" }
                'SecureChannelFailure' { return "la connexion sécurisée échoue (antivirus qui inspecte le web, ou Windows trop ancien)" }
                'ProxyNameResolutionFailure' { return "le proxy réglé sur ce PC ne répond pas" }
                'ConnectFailure' { return "la connexion est refusée (pare-feu, antivirus ou filtrage de la box)" }
                'Timeout' { return "le site ne répond pas à temps (connexion très lente ou filtrée)" }
                default { return "erreur réseau ($($ex.Status))" }
            }
        }
        return $ex.Message
    }
}

function Get-StartupKey($Entry) { return ("$($Entry.ValueName)").ToLowerInvariant() }
function Test-StartupKept($Entry) { return (@($AppInfo.StartupKept) -contains (Get-StartupKey $Entry)) }
# Décoché dans AEROX mais de nouveau actif : l'appli s'est remise elle-même au démarrage (Discord, Spotify, Steam… le font à leur lancement)
function Test-StartupBack($Entry) { return ($Entry.Enabled -and @($AppInfo.StartupOff) -contains $Entry.Key) }

function Test-Startup {
    $all  = @(Get-StartupEntries | Where-Object { $_.Enabled })
    $back = @($all | Where-Object { Test-StartupBack $_ })
    if ($back.Count) {
        Add-Issue -Id 'startup-back' -Sev 'warn' -Title ("{0} appli(s) que tu avais décochée(s) se lancent de nouveau au démarrage" -f $back.Count) -Detail (($back | ForEach-Object { $_.Name }) -join ', ') `
            -Cause "Le plus souvent, c'est l'appli elle-même qui se remet au démarrage quand elle se lance : son propre réglage « lancer au démarrage » l'emporte." `
            -Effect "Elles se lancent de nouveau à chaque allumage." -FixLabel "Choisir les applis" -UiFix 'startup' `
            -Steps @("Ouvre l'appli concernée, va dans ses paramètres et désactive son option du type « Lancer au démarrage de Windows » (souvent dans « Général », « Windows » ou « Démarrage »).", "Ensuite, décoche-la encore une fois dans « Choisir les applis » : cette fois, ça tiendra.")
    }
    # Ce que tu as validé (« je le garde ») et l'essentiel (antivirus, pilotes) ne sont plus signalés
    $kept = @($all | Where-Object { Test-StartupKept $_ })
    $rest = @($all | Where-Object { -not (Test-StartupKept $_) -and -not (Test-StartupBack $_) -and (Get-StartupKind $_) -ne 'keep' })
    $opt  = @($rest | Where-Object { (Get-StartupKind $_) -eq 'optional' })
    $note = if ($kept.Count) { " ($($kept.Count) validé(s) par toi)" } else { '' }
    if ($rest.Count -gt 6 -or $opt.Count -ge 3) {
        $cause = if ($opt.Count) { "Des applis comme " + (($opt | Select-Object -First 4 | ForEach-Object { $_.Name }) -join ', ') + " se lancent toutes seules à chaque allumage. Certaines te servent peut-être tout le temps, d'autres non." }
                 else { "Beaucoup de logiciels se lancent tout seuls à chaque allumage." }
        Add-Issue -Id 'startup' -Sev 'warn' -Title "$($rest.Count) programmes au démarrage à vérifier$note" -Detail (($rest | Select-Object -First 6 | ForEach-Object { $_.Name }) -join ', ') `
            -Cause $cause -Effect "Le PC met plus longtemps à être utilisable et la mémoire est occupée pour rien." `
            -FixLabel "Choisir les applis" -UiFix 'startup' `
            -Steps @("Clique sur « Choisir les applis » : décoche celles qui n'ont pas besoin de se lancer toutes seules.", "Celles que tu laisses cochées sont validées : le diagnostic ne te les signalera plus.")
    } else { Add-Ok "$($all.Count) programmes au démarrage, c'est bon$note" }
    Test-BootSpeed
}
# Démarrage lent : Windows mesure chaque démarrage et note lui-même ce qui l'a ralenti (journal Diagnostics-Performance :
# 101 logiciel, 102 pilote, 103 service, 106 tâche de fond, 109 périphérique). On ne garde que ce qui revient.
function Test-BootSpeed {
    $b = Get-LastBootTime
    $since = (Get-Date).AddDays(-30)
    # Requête XPath (le filtre par table de ce journal renvoie « paramètre incorrect » sur certains Windows) ; jamais bloquant
    $ev = @(); try { $ev = @(Get-WinEvent -LogName 'Microsoft-Windows-Diagnostics-Performance/Operational' -FilterXPath "*[System[(EventID=101 or EventID=102 or EventID=103 or EventID=106 or EventID=109) and TimeCreated[timediff(@SystemTime) <= 2592000000]]]" -ErrorAction Stop) } catch {}
    $kinds = @{ 101 = 'logiciel'; 102 = 'pilote'; 103 = 'service'; 106 = 'tâche de fond'; 109 = 'périphérique' }
    $agg = @{}
    foreach ($e in $ev) {
        $f = Get-EventFields $e
        $n = @($f.FriendlyName, $f.FileName, $f.Name) | Where-Object { $_ } | Select-Object -First 1
        if (-not $n) { continue }
        # Composants de Windows lui-même (mises à jour qui finissent au démarrage, recherche, services) : rien à décocher
        if ("$($f.FileName) $($f.Name) $n" -match '(?i)tiworker|trustedinstaller|searchprotocolhost|searchindexer|svchost|services\.exe|wininit|winlogon|explorer\.exe|msmpeng|^(microsoft )?windows |processus hôte pour les services windows|host process for windows services|windows modules installer') { continue }
        $deg = 0; [void][int]::TryParse("$($f.DegradationTime)", [ref]$deg)
        $k = "$($e.Id)|$n"
        if (-not $agg.ContainsKey($k)) { $agg[$k] = @{ Name = $n; Kind = $kinds[[int]$e.Id]; Count = 0; Deg = 0 } }
        $agg[$k].Count++; $agg[$k].Deg += $deg
    }
    $slow = @($agg.Values | Where-Object { $_.Count -ge 2 -and ($_.Deg / $_.Count) -ge 3000 } | Sort-Object { - $_.Deg / $_.Count } | Select-Object -First 5)
    $bootTxt = if ($b) { "Dernier démarrage : $($b.Sec) s" } else { '' }
    if ($b) { Log ("   • {0} (mesuré par Windows le {1})" -f $bootTxt, $b.Date.ToString('dd/MM/yyyy HH:mm')) }
    foreach ($x in $slow) { Log ("   • Ralentit le démarrage : {0} ({1}) +{2} s en moyenne, {3} fois ce mois-ci" -f $x.Name, $x.Kind, [math]::Round($x.Deg / $x.Count / 1000), $x.Count) }
    if ($slow.Count -and (-not $b -or $b.Sec -ge 45)) {
        $list = ($slow | ForEach-Object { "{0} ({1}, +{2} s)" -f $_.Name, $_.Kind, [math]::Round($_.Deg / $_.Count / 1000) }) -join ' · '
        $hasApp = @($slow | Where-Object { $_.Kind -eq 'logiciel' }).Count -gt 0
        $hasDrv = @($slow | Where-Object { $_.Kind -in 'pilote', 'périphérique' }).Count -gt 0
        $steps = @()
        if ($hasApp) { $steps += "Logiciels : décoche-les dans « Choisir les applis » (programmes au démarrage), ou désactive leur option « lancer au démarrage »." }
        if ($hasDrv) { $steps += "Pilotes / périphériques : mets-les à jour (Mises à jour > Pilotes) ; un périphérique USB lent (hub, carte, vieux disque) peut aussi être débranché pour tester." }
        if (@($slow | Where-Object { $_.Kind -in 'service', 'tâche de fond' }).Count) { $steps += "Services et tâches de fond : regarde « Programmes cachés en fond », AEROX t'explique chacun." }
        Add-Issue -Id 'slowboot' -Sev 'warn' -Title "Démarrage lent : Windows a repéré ce qui le ralentit" -Detail ($(if ($bootTxt) { "$bootTxt · " } else { '' }) + $list) `
            -Cause "À chaque démarrage, Windows chronomètre ce qui se lance. Ces éléments le ralentissent régulièrement (mesures de Windows lui-même, ce mois-ci)." `
            -Effect "Le PC met plus longtemps à être utilisable après l'allumage." -FixLabel "Choisir les applis" -UiFix 'startup' -Steps $steps
    } elseif ($b) { Add-Ok ("Démarrage de Windows : {0} s" -f $b.Sec) }
}

# Seulement les vrais problèmes : le même numéro d'événement peut être une simple information. Ntfs 98, par exemple,
# est écrit à chaque démarrage en « information » (« le volume est en bon état, aucune action nécessaire ») et en
# « erreur » seulement quand une vérification est nécessaire (statistiques : alerte « ntfs » sur 4 diagnostics sur 4).
# Niveaux Windows : 1 critique, 2 erreur, 3 avertissement, 4 information, 0 toujours.
function Select-DiskProblemEvents($Events) {
    return @(@($Events) | Where-Object { $_ -and [int]$_.Level -ge 1 -and [int]$_.Level -le 3 })
}
# Température à partir de laquelle un disque « chauffe » vraiment, selon son type : un SSD NVMe monte couramment à 65-75 °C en
# charge (il ralentit de lui-même vers 80 °C et plus), un SSD SATA supporte 70 °C, un disque dur mécanique 60 °C au maximum.
function Get-DiskTempLimit([string]$MediaType, [string]$BusType) {
    if ("$BusType" -match '(?i)nvme') { return 80 }
    if ("$MediaType" -match '(?i)^HDD$') { return 60 }
    return 70
}
function Test-DiskHealth {
    try {
        $sysNum = (Get-Partition -DriveLetter $env:SystemDrive[0] -ErrorAction Stop | Get-Disk).Number
        $seen = @{}
        foreach ($pd in @(Get-PhysicalDisk -ErrorAction Stop)) {
            # Lettres de ce disque (C:, D:…) pour que tu saches de quel disque on parle
            $let = @(); try { $let = @(Get-Partition -DiskNumber ([int]"$($pd.DeviceId)") -ErrorAction Stop | Where-Object { $_.DriveLetter -and "$($_.DriveLetter)".Trim() -match '^[A-Z]$' } | ForEach-Object { "$($_.DriveLetter):" }) } catch {}
            foreach ($l in $let) { $seen[$l] = $true }
            $name = "$($pd.FriendlyName)" + $(if ($let.Count) { " (" + ($let -join ', ') + ")" } else { '' })
            Log ("   • {0} : {1}, état {2}" -f $name, $pd.MediaType, $pd.HealthStatus)
            if ($pd.HealthStatus -ne 'Healthy') {
                Add-Issue -Id "health$($pd.DeviceId)" -Sev 'crit' -Title "Le disque « $name » signale un problème" -Detail ("État : {0}" -f $pd.HealthStatus) `
                    -Cause "Le disque lui-même détecte des secteurs défectueux ou une usure importante." -Effect "Risque de perdre des fichiers, voire tout le disque." `
                    -FixLabel "Vérifier le disque" -FixAction 'Test-Disk' -Steps @("SAUVEGARDE tout de suite tes fichiers importants (clé USB, disque externe, cloud).", "Prévois de remplacer ce disque rapidement.")
                continue
            }
            $wear = $null; $temp = $null
            try { $rc = Get-StorageReliabilityCounter -PhysicalDisk $pd -ErrorAction Stop; $wear = $rc.Wear; $temp = $rc.Temperature } catch {}
            if ($wear -ge 80) {
                Add-Issue -Id "wear$($pd.DeviceId)" -Sev 'warn' -Title "Le SSD « $name » est usé à $wear %" -Detail "Durée de vie bientôt atteinte" `
                    -Cause "Un SSD supporte un nombre limité d'écritures, celui-ci approche de sa limite." -Effect "Il risque de passer en lecture seule ou de tomber en panne." `
                    -Steps @("Sauvegarde régulièrement tes fichiers importants.", "Prévois de le remplacer.")
            } elseif ($temp -gt (Get-DiskTempLimit "$($pd.MediaType)" "$($pd.BusType)")) {
                Add-Issue -Id "temp$($pd.DeviceId)" -Sev 'warn' -Title "Le disque « $name » chauffe ($temp °C)" -Detail ("Au-dessus de {0} °C, la limite normale pour {1}" -f (Get-DiskTempLimit "$($pd.MediaType)" "$($pd.BusType)"), $(if ("$($pd.BusType)" -match '(?i)nvme') { 'un SSD NVMe' } elseif ("$($pd.MediaType)" -match '(?i)^HDD$') { 'un disque dur' } else { 'un SSD' })) `
                    -Cause "Le disque est mal ventilé ou très sollicité." -Effect "Il ralentit pour se protéger et s'use plus vite." `
                    -Steps @("Dépoussière le PC et vérifie que les ventilateurs tournent.", "Pour un SSD M.2 : un petit dissipateur règle souvent le problème.")
            } else {
                $extra = @(); if ($null -ne $wear) { $extra += "usure $wear %" }; if ($temp) { $extra += "$temp °C" }
                Add-Ok ("{0} ({1}) en bonne santé{2}" -f $name, $pd.MediaType, $(if ($extra) { ' : ' + ($extra -join ', ') } else { '' }))
            }
            if ("$($pd.DeviceId)" -eq "$sysNum" -and $pd.MediaType -eq 'HDD') {
                Add-Issue -Id 'hdd' -Sev 'warn' -Title "Windows est installé sur un disque dur classique" -Detail "$name (HDD)" `
                    -Cause "Un disque dur mécanique est 5 à 10 fois plus lent qu'un SSD." -Effect "Démarrage, ouverture des logiciels et mises à jour très lents." `
                    -Steps @("Passer à un SSD est LA meilleure amélioration possible pour ce PC (à partir d'environ 40 €).", "Un réparateur peut cloner ton disque actuel sur le SSD sans rien perdre.")
            }
        }
        # Erreurs relevées par Windows sur les disques (30 jours) : secteurs illisibles (7), erreurs de lecture de la mémoire
        # virtuelle (51), opérations relancées (153), système de fichiers abîmé (Ntfs 55 / 98)
        # Une requête par source : si une source n'existe pas sur ce PC, les autres sont quand même lues
        $de = @(Select-DiskProblemEvents @(foreach ($pv in 'disk', 'Ntfs', 'Microsoft-Windows-Ntfs') { Get-EventsSafe @{ LogName = 'System'; ProviderName = $pv; Id = 7, 51, 153, 55, 98; StartTime = (Get-Date).AddDays(-30) } }))
        # Après une réparation, seules les erreurs d'après comptent
        $sB = Get-StabilitySince 'diskbad' (Get-Date).AddDays(-30); $sR = Get-StabilitySince 'diskretry' (Get-Date).AddDays(-30); $sF = Get-StabilitySince 'ntfs' (Get-Date).AddDays(-30)
        $bad = @($de | Where-Object { $_.Id -in 7, 51 -and $_.TimeCreated -gt $sB }); $retry = @($de | Where-Object { $_.Id -eq 153 -and $_.TimeCreated -gt $sR }); $fs = @($de | Where-Object { $_.Id -in 55, 98 -and $_.TimeCreated -gt $sF })
        $diskOf = { param($e) $t = (@($e.Properties | ForEach-Object { "$($_.Value)" }) -join ' ') + " $($e.Message)"; if ($t -match '(?i)harddisk(\d+)') { [int]$matches[1] } else { -1 } }
        if ($bad.Count) {
            # À quel disque appartiennent ces erreurs ? (\Device\HarddiskN dans l'événement). Une clé USB, une carte SD ou un
            # disque externe débranché depuis ne doivent pas faire croire que le disque de Windows est en train de lâcher.
            $pds = @(Get-PhysicalDisk -ErrorAction SilentlyContinue)
            $groups = @($bad | Group-Object { & $diskOf $_ } | Sort-Object Count -Descending)
            $parts = @(); $sysHit = $false; $unknown = $false; $internal = $false
            foreach ($g in $groups) {
                $n = [int]$g.Name
                if ($n -lt 0) { $unknown = $true; $parts += "disque non précisé ($($g.Count) fois)"; continue }
                $pd = @($pds | Where-Object { "$($_.DeviceId)" -eq "$n" })[0]
                if ($n -eq [int]$sysNum) { $sysHit = $true; $parts += "$($pd.FriendlyName) (disque de Windows) : $($g.Count) fois"; continue }
                if (-not $pd) { $parts += "disque n° $n, plus branché aujourd'hui (clé USB, carte mémoire ou disque externe) : $($g.Count) fois"; continue }
                $ext = ("$($pd.BusType)" -match '(?i)usb|sd|mmc') -or ("$($pd.MediaType)" -match '(?i)removable')
                if (-not $ext) { $internal = $true }
                $parts += ("{0}{1} : {2} fois" -f $pd.FriendlyName, $(if ($ext) { ' (clé ou disque externe)' } else { '' }), $g.Count)
            }
            if ($sysHit -or $internal -or $unknown) {
                Add-Issue -Id 'diskbad' -Sev 'crit' -Title ("Windows n'arrive pas à lire certains endroits d'un disque ({0} fois ce mois-ci)" -f $bad.Count) -Detail ($parts -join ' · ') `
                    -Cause ("Windows a noté des secteurs illisibles ou des erreurs de lecture" + $(if ($sysHit) { " sur le disque de Windows" } else { "" }) + " : le disque s'use ou est abîmé (ou, plus rarement, son câble / sa prise). L'état « bonne santé » affiché par le disque ne suffit pas à l'exclure.") `
                    -Effect "Risque de perdre des fichiers. Ça empire en général avec le temps." -FixLabel "Vérifier le disque" -FixAction 'Test-Disk' `
                    -Steps @("SAUVEGARDE tout de suite tes fichiers importants (clé USB, disque externe, cloud).", "Disque interne SATA : change le câble SATA ou la prise sur la carte mère.", "SSD : mets à jour son firmware avec l'outil de sa marque.", "Si les erreurs continuent : remplace le disque.")
            } else {
                Add-Issue -Id 'diskbad' -Sev 'warn' -Title ("Une clé USB ou un disque externe a eu des erreurs de lecture ({0} fois ce mois-ci)" -f $bad.Count) -Detail ($parts -join ' · ') `
                    -Cause "Ce n'est pas le disque de Windows : c'est une clé USB, une carte mémoire ou un disque externe qui a eu du mal à être lu (souvent retiré sans « éjecter », un port USB ou un câble fatigué, ou un support en fin de vie)." `
                    -Effect "Les fichiers sur ce support peuvent être abîmés ou illisibles." `
                    -Steps @("Si tu as des fichiers importants dessus, copie-les tout de suite sur le PC.", "Essaie un autre port USB (à l'arrière du PC) ou un autre câble.", "Si les erreurs reviennent avec ce support, remplace-le : une clé ou une carte mémoire, ça s'use.")
            }
        } elseif ($retry.Count -ge 5) {
            Add-Issue -Id 'diskretry' -Sev 'warn' -Title ("Le disque a dû recommencer des lectures {0} fois ce mois-ci" -f $retry.Count) -Detail 'Opérations relancées par Windows' `
                -Cause "Le disque a mis trop de temps à répondre et Windows a réessayé : câble ou prise qui fatigue, firmware du SSD à mettre à jour, ou disque qui s'use." `
                -Effect "Petits figements du PC de quelques secondes." -Steps @("Mets à jour le firmware du SSD avec l'outil de sa marque (Samsung Magician, Crucial Storage Executive, WD Dashboard…).", "Disque SATA : change le câble ou la prise.", "Sauvegarde tes fichiers importants par précaution.")
        }
        if ($fs.Count) {
            Add-Issue -Id 'ntfs' -Sev 'warn' -Title "Le système de fichiers d'un disque est à réparer" -Detail ("Signalé {0} fois ce mois-ci" -f $fs.Count) `
                -Cause "Windows a trouvé des incohérences dans le rangement des fichiers (souvent après une coupure de courant ou un arrêt forcé)." -Effect "Fichiers ou dossiers illisibles, lenteurs." `
                -FixLabel "Vérifier le disque" -FixAction 'Test-Disk' -Steps @("Lance la vérification du disque (bouton vert) : Windows répare au prochain redémarrage si besoin.")
        }
        if (-not $bad.Count -and $retry.Count -lt 5 -and -not $fs.Count) { Add-Ok "Aucune erreur de lecture des disques ce mois-ci" }
        # Disques avec une lettre que Windows ne relie à aucun disque physique (clés USB, certains boîtiers externes) : santé non lisible
        foreach ($d in @(Get-DriveList | Where-Object { -not $seen.ContainsKey($_.Id) })) {
            Log ("   • {0} : santé non lisible par Windows (souvent une clé USB ou un boîtier externe)" -f $d.Id)
        }
    } catch {}
}

# AMD Ryzen 7000 / 8000 / 9000 : ces processeurs visent VOLONTAIREMENT 95 °C en charge (c'est leur réglage d'origine, pas une surchauffe)
function Test-RyzenTarget95([string]$CpuName) { return ("$CpuName" -match '(?i)ryzen\s+(ai\s+)?([3579]\s+)?[789]\d{3}') }
# Verdict de température du processeur : '' (normal) | 'warn' | 'crit'
# - 100 °C et plus : au maximum du processeur (il ralentit déjà) -> critique
# - presque au repos (moins de 30 % d'utilisation) : 80 °C et plus -> refroidissement à vérifier
# - en charge : 95 °C et plus -> très chaud, sauf pour les Ryzen qui visent 95 °C
function Get-CpuTempVerdict([double]$Temp, [double]$Load, [string]$CpuName) {
    if ($Temp -ge 100) { return 'crit' }
    if ($Load -lt 30) { if ($Temp -ge 80) { return 'warn' } else { return '' } }
    if (Test-RyzenTarget95 $CpuName) { return '' }
    if ($Temp -ge 95) { return 'warn' }
    return ''
}
# Valeur du milieu d'une liste de mesures ($null si elle est vide)
function Get-Median($Values) { $a = @($Values | Sort-Object); if (-not $a.Count) { return $null }; return [double]$a[[int][math]::Floor($a.Count / 2)] }
# Valeur du milieu de plusieurs relevés de capteurs en direct, pris en même temps (un seul relevé peut tomber sur un pic passager).
# Renvoie une table clé -> valeur ; une clé dont le capteur ne répond pas est absente.
function Get-SensorMedian([string[]]$Keys, [int]$Count = 5, [int]$DelayMs = 800) {
    $vals = @{}; foreach ($k in $Keys) { $vals[$k] = New-Object 'System.Collections.Generic.List[double]' }
    for ($i = 0; $i -lt $Count; $i++) {
        $s = $sync.Sens
        if ($s) { foreach ($k in $Keys) { if ($null -ne $s[$k]) { $vals[$k].Add([double]$s[$k]) } } }
        if ($i -lt $Count - 1) { Start-Sleep -Milliseconds $DelayMs }
    }
    $out = @{}
    foreach ($k in $Keys) { if ($vals[$k].Count) { $out[$k] = Get-Median $vals[$k].ToArray() } }
    return $out
}
function Test-Temperatures {
    $v = $sync.Sens
    $cpuLoad = [double]$v['cpu.load']
    $issue = $false
    if ($v['cpu.temp']) {
        $t = [math]::Round([double]$v['cpu.temp'])
        $cpuName = "$((Get-CimStatic Win32_Processor -Quiet | Select-Object -First 1).Name)"
        # Un seul relevé peut tomber sur un pic passager : si le premier inquiète, on le confirme sur quelques secondes (valeur du milieu)
        if (Get-CpuTempVerdict $t $cpuLoad $cpuName) {
            $m = Get-SensorMedian @('cpu.temp', 'cpu.load')
            if ($m.ContainsKey('cpu.temp')) { $t = [math]::Round($m['cpu.temp']) }
            if ($m.ContainsKey('cpu.load')) { $cpuLoad = $m['cpu.load'] }
        }
        $verdict = Get-CpuTempVerdict $t $cpuLoad $cpuName
        if ($verdict) {
            Add-Issue -Id 'cputemp' -Sev $verdict -Title "Le processeur chauffe ($t °C)" -Detail ("Utilisation actuelle : {0} %" -f [math]::Round($cpuLoad)) `
                -Cause $(if ($cpuLoad -lt 30) { "Il est chaud alors qu'il ne travaille presque pas : poussière, ventilateur, pâte thermique ou refroidissement mal monté." } else { "Il est très sollicité et le refroidissement a du mal à suivre." }) `
                -Effect "Le processeur ralentit pour se protéger (perte de FPS) et s'use plus vite." `
                -Steps @("Dépoussière le PC (bombe d'air sec), surtout le radiateur du processeur.", "Vérifie que tous les ventilateurs tournent.", "Si le PC a plus de 4-5 ans, changer la pâte thermique fait souvent gagner 10 °C.")
            $issue = $true
        } elseif ((Test-RyzenTarget95 $cpuName) -and $cpuLoad -ge 30 -and $t -ge 90) {
            Add-Ok "Processeur à $t °C en charge : normal pour ce Ryzen (il vise volontairement 95 °C)"
        } else { Add-Ok "Processeur à $t °C, température normale" }
    }
    if ($v['gpu.temp']) {
        $t = [math]::Round([double]$v['gpu.temp'])
        if ($t -ge 85) {
            Add-Issue -Id 'gputemp' -Sev 'warn' -Title "La carte graphique chauffe ($t °C)" -Detail ($v['gpu.name']) `
                -Cause "Poussière, ventilateurs encrassés ou boîtier mal ventilé." -Effect "La carte ralentit pour se protéger (perte de FPS) et peut planter en jeu." `
                -Steps @("Dépoussière la carte graphique et le boîtier.", "Vérifie que l'air entre et sort bien du boîtier.", "Dans le logiciel de la carte, une courbe de ventilation plus agressive peut aider.")
            $issue = $true
        } else { Add-Ok "Carte graphique à $t °C, température normale" }
    }
}

# Vérification après une réparation : refait seulement le contrôle de la catégorie du problème
function Get-DiagCheckFn([string]$Cat) {
    $m = @{ 'Stockage' = 'Test-Storage'; 'Mémoire' = 'Test-Memory'; 'Système' = 'Test-SystemState'; 'Stabilité' = 'Test-Stability'; 'Mises à jour' = 'Test-Updates'
            'Pilotes' = 'Test-Drivers'; 'Écrans' = 'Test-Display'; 'Sécurité' = 'Test-Security'; 'Réseau' = 'Test-Network'; 'Démarrage' = 'Test-Startup'; 'Logiciels' = 'Test-Bloatware'
            'Santé du disque' = 'Test-DiskHealth'; 'Températures' = 'Test-Temperatures'; 'Performances' = 'Test-Performance'; 'En fond' = 'Test-BgItems'; 'Navigateurs' = 'Test-Browsers'; 'Batterie' = 'Test-Battery' }
    if ($m.ContainsKey($Cat)) { return $m[$Cat] }
    return ''
}
# Résultat dans $sync.Verify : "Id|gone" (réglé), "Id|still|nouveau détail" (toujours là) ou "Id|unknown"
function Test-IssueGone([string]$Cat, [string]$Id) {
    $res = 'unknown'; $detail = ''
    $fn = Get-DiagCheckFn $Cat
    if ($fn -and $Id) {
        $script:Issues = New-Object System.Collections.ArrayList
        $script:OkList = New-Object System.Collections.ArrayList
        $script:IgnoredList = New-Object System.Collections.ArrayList
        $script:CurrentCat = $Cat
        try {
            & $fn
            $still = @($script:Issues | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1
            if ($still) { $res = 'still'; $detail = ("{0}{1}" -f $still.Title, $(if ($still.Detail) { " · $($still.Detail)" } else { '' })) -replace '\|', '/' } else { $res = 'gone' }
        } catch {}
    }
    $sync.Verify.Enqueue(("{0}|{1}|{2}" -f $Id, $res, $detail))
}

# Infos matérielles qui ne changent pas pendant une analyse (modèle, processeur, carte graphique, barrettes…) :
# lues une seule fois par diagnostic au lieu d'une fois par vérification. Hors diagnostic : lues à chaque appel.
# -Quiet : rien (au lieu d'une erreur) si Windows ne répond pas, comme Get-CimInstance sans -ErrorAction Stop.
function Get-CimStatic([string]$Class, [switch]$Quiet) {
    $c = $script:CimCache
    if ($c -is [hashtable] -and $c.ContainsKey($Class)) { return $c[$Class] }
    try { $r = @(Get-CimInstance -ClassName $Class -ErrorAction Stop) }
    catch { if ($Quiet) { return }; throw }
    if ($c -is [hashtable]) { $c[$Class] = $r }
    return $r
}
function Invoke-Diagnostic {
    Step "Diagnostic complet"
    $script:Issues = New-Object System.Collections.ArrayList
    $script:OkList = New-Object System.Collections.ArrayList
    $script:IgnoredList = New-Object System.Collections.ArrayList
    $checks = [ordered]@{ 'Stockage' = 'Test-Storage'; 'Mémoire' = 'Test-Memory'; 'Système' = 'Test-SystemState'; 'Stabilité' = 'Test-Stability'; 'Mises à jour' = 'Test-Updates'
                          'Pilotes' = 'Test-Drivers'; 'Écrans' = 'Test-Display'; 'Sécurité' = 'Test-Security'; 'Réseau' = 'Test-Network'; 'Démarrage' = 'Test-Startup'; 'Logiciels' = 'Test-Bloatware'; 'Santé du disque' = 'Test-DiskHealth' }
    $sens = $sync.Sens
    if ($sens -and ($sens['cpu.temp'] -or $sens['gpu.temp'])) { $checks['Températures'] = 'Test-Temperatures' }
    $checks['Performances'] = 'Test-Performance'
    $checks['En fond'] = 'Test-BgItems'
    $checks['Navigateurs'] = 'Test-Browsers'
    if (@(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue).Count) { $checks['Batterie'] = 'Test-Battery' }
    $sync.Scan.Clear()
    foreach ($k in $checks.Keys) { $sync.Scan[$k] = 'wait' }
    $sync.ScanOrder = @($checks.Keys)
    $sync.ScanVer++
    $script:CimCache = @{}
    foreach ($k in $checks.Keys) {
        if ($sync.Cancel) { $script:CimCache = $null; return }
        $script:CurrentCat = $k
        $sync.Scan[$k] = 'run'; $sync.ScanVer++
        $before = $script:Issues.Count
        $failed = $false
        try { & $checks[$k] }
        catch { $failed = $true; Write-Bug -Context "Diagnostic / $k" -ErrorRecord $_; Log ("   ⚠ Vérification « {0} » incomplète : {1}" -f $k, $_.Exception.Message); Add-StatsEvent ("erreur:" + (ConvertTo-StatsId $checks[$k])) }
        $new = @($script:Issues | Select-Object -Skip $before)
        $sync.Scan[$k] = if (@($new | Where-Object { $_.Sev -eq 'crit' }).Count) { 'bad' } elseif ($new.Count -or $failed) { 'warn' } else { 'ok' }
        $sync.ScanVer++
        if ($new.Count) { foreach ($i in $new) { Log ("   {0} {1} : {2}" -f $(if ($i.Sev -eq 'crit') { '❌' } else { '⚠' }), $k, $i.Title) } }
        elseif (-not $failed) { Log ("   ✔ {0} : OK" -f $k) }
    }
    $script:CimCache = $null
    $crit = @($script:Issues | Where-Object { $_.Sev -eq 'crit' }).Count
    $sync.Diag = @{ Issues = @($script:Issues); Ok = @($script:OkList); Ignored = @($script:IgnoredList); Date = (Get-Date) }
    # Statistiques anonymes : seulement le type de chaque problème trouvé (« probleme:bsod »), rien d'autre
    Add-StatsEvent 'diag'
    foreach ($i in @($script:Issues)) { $sid = ConvertTo-StatsId $i.Id; if ($sid) { Add-StatsEvent ("probleme:" + $sid) } }
    if (-not $script:Issues.Count) { Add-StatsEvent 'diag:rien' }
    try { $sync.Diag.Snap = Get-PcSnapshot } catch {}
    if ($script:IgnoredList.Count) { Log ("   ({0} alerte(s) ignorée(s) à ta demande)" -f $script:IgnoredList.Count) }
    Step "Résultat"
    Log ("{0} problème(s) dont {1} critique(s), {2} point(s) OK" -f $script:Issues.Count, $crit, $script:OkList.Count)
}

# ---------------------------------------------------------------- NETTOYAGE
function Clear-TempFiles {
    Step "Nettoyage des fichiers temporaires"
    $before = $script:TotalFreed
    foreach ($loc in Get-TempLocations) { Clear-Location $loc.Path $loc.Label }
    $thumb = [double]0
    foreach ($p in Get-UserProfiles) {
        foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $p 'AppData\Local\Microsoft\Windows\Explorer') -Filter 'thumbcache_*.db' -Force -ErrorAction SilentlyContinue)) { $thumb += Remove-ItemSafe $f }
    }
    $script:TotalFreed += $thumb
    Log ("   ✔ Cache des miniatures : {0} libérés" -f (Format-Size $thumb))
    if (Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue) {
        try { Delete-DeliveryOptimizationCache -Force -ErrorAction Stop | Out-Null; Log "   ✔ Cache d'optimisation de distribution vidé" } catch {}
    }
    Log ("✅ Total libéré : {0}" -f (Format-Size ($script:TotalFreed - $before)))
    Add-Change -Kind 'info' -Title ("Fichiers temporaires supprimés : {0}" -f (Format-Size ($script:TotalFreed - $before))) -Detail "Fichiers inutiles : Windows les recrée si besoin."
}

# Corbeille de la personne devant l'écran, sur tous les disques (internes et externes). Celles des autres comptes
# du PC (ou d'une ancienne installation de Windows) sont comptées à part et jamais touchées.
function Get-RecycleBinSizes {
    $su = Get-SessionUser
    $sid = if ($su.Other -and $su.Sid) { $su.Sid } else { [Security.Principal.WindowsIdentity]::GetCurrent().User.Value }
    $r = @{ Mine = [double]0; Others = [double]0; Sid = $sid; Dirs = @() }
    foreach ($d in @(Get-DriveList)) {
        $root = "{0}\`$Recycle.Bin" -f $d.Id
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($sub in @(Get-ChildItem -LiteralPath $root -Directory -Force -ErrorAction SilentlyContinue)) {
            $sz = [double][AeroxNative]::FolderSize($sub.FullName)
            if ($sub.Name -eq $sid) { $r.Mine += $sz; $r.Dirs += $sub.FullName } else { $r.Others += $sz }
        }
    }
    return $r
}
function Clear-RecycleBinAll {
    Step "Vidage de la corbeille"
    $before = Get-RecycleBinSizes
    foreach ($d in @(Get-DriveList)) { try { Clear-RecycleBin -DriveLetter $d.Id.TrimEnd(':') -Force -ErrorAction Stop } catch {} }
    # Si Windows n'a pas tout vidé (ça arrive selon les disques), on vide le dossier de corbeille de la personne, sans suivre aucun lien
    $mid = Get-RecycleBinSizes
    if ($mid.Mine -gt 0) { foreach ($dir in $mid.Dirs) { $null = Remove-PathContent $dir } }
    $after = Get-RecycleBinSizes
    $size = [math]::Max([double]0, $before.Mine - $after.Mine)
    $script:TotalFreed += $size
    Log ("✅ Corbeille vidée : {0} libérés" -f (Format-Size $size))
    if ($after.Mine -gt 1MB) { Log ("   • {0} n'ont pas pu être supprimés (fichiers encore utilisés) : redémarre le PC puis relance le nettoyage." -f (Format-Size $after.Mine)) }
    if ($after.Others -gt 1MB) { Log ("   • {0} sont dans la corbeille d'autres comptes du PC (ou d'une ancienne installation de Windows) : pas touchés." -f (Format-Size $after.Others)) }
    Add-Change -Kind 'info' -Title ("Corbeille vidée : {0}" -f (Format-Size $size)) -Detail "Les fichiers de la corbeille ne sont plus récupérables."
}

function Stop-Browser([string]$Proc) {
    $ps = @(Get-Process -Name $Proc -ErrorAction SilentlyContinue)
    if (-not $ps.Count) { return }
    Log "   Fermeture de $Proc..."
    foreach ($p in $ps) { try { [void]$p.CloseMainWindow() } catch {} }
    Start-Sleep -Seconds 3
    Get-Process -Name $Proc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

function Clear-BrowserCache {
    $la = Get-SessionFolder 'Local AppData'
    Step "Nettoyage du cache des navigateurs"
    $before = $script:TotalFreed
    $found  = $false
    $browsers = @(
        @{ Name = 'Google Chrome';  Proc = 'chrome'; Dir = "$la\Google\Chrome\User Data" },
        @{ Name = 'Microsoft Edge'; Proc = 'msedge'; Dir = "$la\Microsoft\Edge\User Data" },
        @{ Name = 'Brave';          Proc = 'brave';  Dir = "$la\BraveSoftware\Brave-Browser\User Data" },
        @{ Name = 'Opera GX';       Proc = 'opera';  Dir = "$la\Opera Software\Opera GX Stable" },
        @{ Name = 'Opera';          Proc = 'opera';  Dir = "$la\Opera Software\Opera Stable" }
    )
    foreach ($b in $browsers) {
        if (-not (Test-Path -LiteralPath $b.Dir)) { continue }
        $found = $true
        if (Get-Process -Name $b.Proc -ErrorAction SilentlyContinue) {
            Add-TaskError -Title "Le cache de $($b.Name) n'a pas été vidé" -Cause "$($b.Name) est ouvert (ou tourne en arrière-plan), donc ses fichiers sont verrouillés." `
                -Effect "Rien de grave : la place n'est simplement pas libérée." -FixLabel "Fermer $($b.Name) et réessayer" -FixAction "Stop-Browser '$($b.Proc)'; Clear-BrowserCache" `
                -Confirm "$($b.Name) va être fermé. Tes onglets te seront proposés à la réouverture.`n`nContinuer ?"
            continue
        }
        $profiles = @($b.Dir) + @(Get-ChildItem -LiteralPath $b.Dir -Directory -Force -ErrorAction SilentlyContinue |
                                   Where-Object { $_.Name -match '^(Default|Profile \d+)$' } | ForEach-Object { $_.FullName })
        $freed = [double]0
        foreach ($p in $profiles) { foreach ($c in @('Cache', 'Code Cache', 'GPUCache', 'GrShaderCache', 'ShaderCache')) { $freed += Remove-PathContent (Join-Path $p $c) } }
        $script:TotalFreed += $freed
        Log ("   ✔ {0} : {1} libérés" -f $b.Name, (Format-Size $freed))
    }
    $ff = "$la\Mozilla\Firefox\Profiles"
    if (Test-Path -LiteralPath $ff) {
        $found = $true
        if (Get-Process -Name 'firefox' -ErrorAction SilentlyContinue) {
            Add-TaskError -Title "Le cache de Firefox n'a pas été vidé" -Cause "Firefox est ouvert, donc ses fichiers sont verrouillés." -Effect "Rien de grave : la place n'est simplement pas libérée." `
                -FixLabel "Fermer Firefox et réessayer" -FixAction "Stop-Browser 'firefox'; Clear-BrowserCache" -Confirm "Firefox va être fermé. Tes onglets te seront proposés à la réouverture.`n`nContinuer ?"
        } else {
            $freed = [double]0
            foreach ($p in @(Get-ChildItem -LiteralPath $ff -Directory -ErrorAction SilentlyContinue)) { $freed += Remove-PathContent (Join-Path $p.FullName 'cache2') }
            $script:TotalFreed += $freed
            Log ("   ✔ Firefox : {0} libérés" -f (Format-Size $freed))
        }
    }
    if (-not $found) { Log "   • Aucun navigateur reconnu trouvé" }
    Log "   (Tes mots de passe, favoris, historique et connexions aux sites ne sont pas touchés.)"
    Log ("✅ Total libéré : {0}" -f (Format-Size ($script:TotalFreed - $before)))
}

function Clear-WindowsUpdateCache {
    Step "Nettoyage du cache Windows Update"
    Stop-Service -Name wuauserv, bits -Force -ErrorAction SilentlyContinue
    Clear-Location "$env:SystemRoot\SoftwareDistribution\Download" "Fichiers de mise à jour téléchargés"
    Start-Service -Name bits, wuauserv -ErrorAction SilentlyContinue
}

# Mise à jour Windows qui attend un redémarrage : DISM refuse alors de nettoyer les composants (code 0x800F0806)
function Test-ComponentsPending {
    return (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
           (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending')
}
$script:PendingMsg = "   • Anciens composants : une mise à jour de Windows attend un redémarrage. Ce nettoyage-là se fera après : redémarre le PC puis relance le nettoyage approfondi."


function Enable-StorageSense {
    Step "Activation du nettoyage automatique (Assistant stockage)"
    $key = "$((Get-SessionUser).Hkcu)\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"
    if (-not (Test-Path -LiteralPath $key)) { New-Item -Path $key -Force | Out-Null }
    Set-ItemProperty -LiteralPath $key -Name '01' -Value 1 -Type DWord
    Set-ItemProperty -LiteralPath $key -Name '04' -Value 1 -Type DWord
    Log "   ✔ Windows supprimera maintenant tout seul les fichiers temporaires régulièrement."
    Add-Change -Title "Nettoyage automatique de Windows activé (Assistant stockage)" -Undo 'Disable-StorageSense'
    Open-WinUri 'ms-settings:storagesense'
}

# ---------------------------------------------------------------- LOGICIELS INSTALLÉS (conseils de désinstallation)
$script:BloatRules = @(
    @{ P = '(?i)driver ?booster|driver ?easy|driver ?updater|driverpack|driver ?support|driver ?genius|slimdrivers|smart ?driver|driver ?max|driver ?reviver'; Tag = 'reco'
       R = "Logiciel de « mise à jour de pilotes » : inutile et parfois risqué. Les pilotes s'installent via Windows Update ou le site du fabricant." },
    @{ P = '(?i)advanced ?systemcare|iobit|reimage|restoro|pc ?optimizer|mycleanpc|speedupmypc|pc ?accelerate|wise ?care|glary|winoptimizer|systweak|advanced system optimizer|outbyte|pc ?cleaner|total ?pc ?cleaner|tuneup|avast cleanup|ccleaner|razer cortex|pc ?booster|clean ?master'; Tag = 'reco'
       R = "« Optimiseur » ou nettoyeur : fait doublon avec AEROX PC Care et Windows. Certains affichent des pubs ou poussent des abonnements." },
    @{ P = '(?i)toolbar|ask\.com|conduit|babylon|wajam|segurazo|shield ?antivirus|webdiscover|onelaunch|wave ?browser|pc app store|bytefence|webadvisor|bing ?bar|browser ?assistant|search ?protect|mindspark|myway'; Tag = 'reco'
       R = "Barre d'outils ou logiciel publicitaire, souvent installé sans le vouloir avec un autre programme." },
    @{ P = '(?i)wildtangent|candy ?crush|bubble ?witch|march of empires|hidden city|farm ?heroes|disney magic kingdoms|booking\.com|dropbox promotion|amazon (assistant|shopping)|norton ?security ?scan|keeper password'; Tag = 'maybe'
       R = "Logiciel ou jeu préinstallé par le fabricant du PC, rarement utilisé." }
)
$script:AvRule = '(?i)mcafee|norton|avast|avg |avira|totalav|total av|kaspersky|bullguard|panda|eset|malwarebytes|bitdefender|sophos|trend ?micro'
$script:StoreBloat = @(
    @{ P = '(?i)^king\.com\.|CandyCrush|BubbleWitch|MarchofEmpires|HiddenCity|FarmHeroes|DisneyMagicKingdoms'; R = "Jeu préinstallé par Windows." },
    @{ P = '(?i)TikTok|Facebook|Instagram|LinkedIn|Twitter|Disney|PrimeVideo|AmazonVideo|ESPN|Hulu|iHeartRadio|Pandora|Shazam'; R = "Appli préinstallée ou de raccourci (le site web fait la même chose)." },
    @{ P = '(?i)^Microsoft\.(BingNews|BingWeather|BingSearch|BingFinance|BingSports|GetHelp|Getstarted|MicrosoftSolitaireCollection|People|MixedReality\.Portal|Microsoft3DViewer|WindowsFeedbackHub|SkypeApp|MicrosoftOfficeHub|Todos|PowerAutomateDesktop|549981C3F5F10|YourPhone|ZuneVideo|WindowsMaps|MicrosoftStickyNotes|Wallet|OneConnect|Print3D)$|Clipchamp|MicrosoftTeams|OutlookForWindows|Copilot|DevHome|Family'; R = "Appli Windows préinstallée. Se réinstalle depuis le Microsoft Store si tu en as besoin un jour." }
)
$script:StoreNames = @{ 'Microsoft.BingNews' = 'Actualités'; 'Microsoft.BingWeather' = 'Météo'; 'Microsoft.BingSearch' = 'Recherche Bing'; 'Microsoft.GetHelp' = 'Obtenir de l''aide'; 'Microsoft.Getstarted' = 'Astuces'
    'Microsoft.MicrosoftSolitaireCollection' = 'Solitaire'; 'Microsoft.People' = 'Contacts'; 'Microsoft.WindowsFeedbackHub' = 'Hub de commentaires'; 'Microsoft.SkypeApp' = 'Skype'
    'Microsoft.MicrosoftOfficeHub' = 'Microsoft 365 (Office)'; 'Microsoft.Todos' = 'To Do'; 'Microsoft.PowerAutomateDesktop' = 'Power Automate'; 'Microsoft.549981C3F5F10' = 'Cortana'
    'Microsoft.YourPhone' = 'Lien avec Windows (téléphone)'; 'Microsoft.ZuneVideo' = 'Films et TV'; 'Microsoft.WindowsMaps' = 'Cartes'; 'Microsoft.MicrosoftStickyNotes' = 'Pense-bêtes'
    'Clipchamp.Clipchamp' = 'Clipchamp (montage vidéo)'; 'MSTeams' = 'Microsoft Teams'; 'Microsoft.OutlookForWindows' = 'Outlook (nouveau)'; 'Microsoft.Copilot' = 'Copilot'; 'Microsoft.Windows.DevHome' = 'Dev Home' }

# Dossier d'installation d'un logiciel (InstallLocation, sinon déduit de l'icône ou du désinstalleur)
function Get-AppLocation($e) {
    $cands = @("$($e.InstallLocation)")
    try { if ($e.DisplayIcon) { $cands += [IO.Path]::GetDirectoryName(((("$($e.DisplayIcon)" -replace ',\s*-?\d+$', '') -replace '"', '').Trim())) } } catch {}
    try {
        $u = "$($e.UninstallString)"
        if ($u -and $u -notmatch '(?i)msiexec') {
            $exe = if ($u -match '^\s*"([^"]+)"') { $matches[1] } elseif ($u -match '^(.+?\.exe)') { $matches[1] } else { '' }
            if ($exe) { $cands += [IO.Path]::GetDirectoryName($exe) }
        }
    } catch {}
    foreach ($c in $cands) {
        try {
            $c = "$c".Trim().Trim('"').TrimEnd('\')
            if ($c -and $c -match '^[A-Za-z]:\\' -and $c -notmatch '(?i)\\(Windows\\Installer|Package Cache|Temp|system32|SysWOW64)(\\|$)' -and (Test-Path -LiteralPath $c -PathType Container)) { return $c }
        } catch {}
    }
    return ''
}

function Get-InstalledApps {
    $list = New-Object System.Collections.ArrayList; $seen = @{}
    $active = @()
    try { $active = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop | ForEach-Object { $_.displayName }) } catch {}
    $avs = @()
    # Logiciels de la machine + ceux de la personne devant l'écran (pas ceux du compte ADMIN quand on a tapé son mot de passe)
    $su = Get-SessionUser
    $userKey = "$($su.Hkcu)\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', $userKey) {
        $perUser = ($k -eq $userKey)
        foreach ($e in @(Get-ItemProperty $k -ErrorAction SilentlyContinue)) {
            if (-not $e.DisplayName -or $e.SystemComponent -eq 1 -or $e.ParentKeyName -or $e.ReleaseType -match 'Update|Hotfix') { continue }
            if (-not $e.UninstallString -and -not $e.QuietUninstallString) { continue }
            $name = "$($e.DisplayName)".Trim()
            if ($seen.ContainsKey($name)) { continue }; $seen[$name] = $true
            $date = $null; if ("$($e.InstallDate)" -match '^(\d{4})(\d{2})(\d{2})$') { try { $date = Get-Date -Year $matches[1] -Month $matches[2] -Day $matches[3] } catch {} }
            $loc = Get-AppLocation $e
            $o = @{ Kind = 'win32'; LastUsed = (Get-FolderLastUsed $loc); Name = $name; Publisher = "$($e.Publisher)"; Size = $(if ($e.EstimatedSize) { [double]$e.EstimatedSize * 1KB } else { 0 }); Date = $date
                    Cmd = "$($e.UninstallString)"; Tag = ''; Reason = ''; Location = $loc; Drive = $(if ($loc -match '^([A-Za-z]:)') { $matches[1].ToUpper() } else { '' })
                    Key = "$($e.PSPath)"; PerUser = $perUser }
            foreach ($r in $script:BloatRules) { if ($name -match $r.P -or "$($e.Publisher)" -match $r.P) { $o.Tag = $r.Tag; $o.Reason = $r.R; break } }
            if (-not $o.Tag -and $name -match $script:AvRule) { $avs += $o }
            [void]$list.Add($o)
        }
    }
    # Antivirus : en double, ou en version d'essai pas utilisée
    if ($avs.Count) {
        foreach ($a in $avs) {
            $isActive = @($active | Where-Object { $a.Name -like "*$($_.Split(' ')[0])*" }).Count -gt 0
            if (-not $isActive) { $a.Tag = 'reco'; $a.Reason = "Antivirus qui ne protège pas ce PC en ce moment (essai expiré ou désactivé). Deux antivirus se gênent et ralentissent le PC : garde-en un seul." }
            elseif (@($active | Where-Object { $_ -notmatch 'Defender' }).Count -gt 1) { $a.Tag = 'maybe'; $a.Reason = "Plusieurs antivirus sont actifs : garde-en un seul, sinon ils ralentissent le PC." }
        }
    }
    try {
        $pk = $(if ($su.Other -and $su.Sid) { @(Get-AppxPackage -User $su.Sid -ErrorAction Stop) } else { @(Get-AppxPackage -ErrorAction Stop) })
        foreach ($p in @($pk | Where-Object { -not $_.IsFramework -and -not $_.NonRemovable -and $_.SignatureKind -ne 'System' })) {
            foreach ($r in $script:StoreBloat) {
                if ($p.Name -match $r.P) {
                    $nm = if ($script:StoreNames.ContainsKey($p.Name)) { $script:StoreNames[$p.Name] } else { ($p.Name -replace '^[^.]+\.', '') -replace '([a-z])([A-Z])', '$1 $2' }
                    if ($seen.ContainsKey("store:$nm")) { break }; $seen["store:$nm"] = $true
                    $loc = "$($p.InstallLocation)"
                    [void]$list.Add(@{ Kind = 'store'; Name = $nm; Publisher = 'Microsoft Store'; Size = 0; Date = $null; Cmd = $p.PackageFullName; Tag = 'maybe'; Reason = $r.R
                                       Location = $loc; Drive = $(if ($loc -match '^([A-Za-z]:)') { $matches[1].ToUpper() } else { '' }) })
                    break
                }
            }
        }
    } catch {}
    return ,$list
}

function Get-InstalledAppsAdvice {
    Step "Analyse des logiciels installés"
    $sync.InstalledApps = $null
    $apps = Get-InstalledApps
    $sync.InstalledApps = @($apps)
    $reco = @($apps | Where-Object { $_.Tag -eq 'reco' }).Count; $maybe = @($apps | Where-Object { $_.Tag -eq 'maybe' }).Count
    Log ("   {0} logiciels trouvés : {1} conseillé(s) à désinstaller, {2} à voir selon ton usage." -f $apps.Count, $reco, $maybe)
}

function Test-Bloatware {
    $apps = Get-InstalledApps
    $reco = @($apps | Where-Object { $_.Tag -eq 'reco' })
    if ($reco.Count) {
        Add-Issue -Id 'bloat' -Sev 'warn' -Title "$($reco.Count) logiciel(s) inutile(s) ou douteux installé(s)" -Detail (($reco | Select-Object -First 4 | ForEach-Object { $_.Name }) -join ', ') `
            -Cause ($reco[0].Reason) -Effect "Ils prennent de la place, peuvent tourner en arrière-plan et afficher des pubs." `
            -FixLabel "Voir et désinstaller" -UiFix 'uninstall'
    } else { Add-Ok "Aucun logiciel douteux ou inutile repéré" }
}

# Désinstallation (lance le désinstalleur officiel du logiciel)
# Lance le désinstalleur officiel. Les applis du Store sont retirées tout de suite ;
# pour les autres, c'est la disparition de leur entrée dans Windows qui confirme la désinstallation.
function Uninstall-App([string]$Kind, [string]$Cmd, [string]$Name, [bool]$PerUser = $false) {
    $su = Get-SessionUser
    if ($Kind -eq 'store') {
        if ($su.Other -and $su.Sid) { Remove-AppxPackage -Package $Cmd -User $su.Sid -ErrorAction Stop } else { Remove-AppxPackage -Package $Cmd -ErrorAction Stop }
        return
    }
    $exe = $null; $arg = ''
    if ($Cmd -match '(?i)msiexec(\.exe)?\s.*?(\{[0-9A-F\-]+\})') { $exe = "$env:SystemRoot\System32\msiexec.exe"; $arg = "/X $($matches[2])" }
    elseif ($Cmd -match '^\s*"([^"]+)"\s*(.*)$') { $exe = $matches[1]; $arg = $matches[2] }
    elseif ($Cmd -match '^(.+?\.exe)\s*(.*)$') { $exe = $matches[1]; $arg = $matches[2] }
    else { throw "Commande de désinstallation inconnue : $Cmd" }
    # Logiciel installé pour la personne seulement (registre de son compte) : son désinstalleur tourne sur son compte,
    # SANS les droits admin. Cette entrée peut être écrite par n'importe quel programme de la personne :
    # AEROX ne doit jamais la lancer avec ses droits administrateur.
    if ($PerUser) {
        $ex2 = $exe -replace '(?i)%USERPROFILE%', (Get-SessionUser).Profile -replace '(?i)%LOCALAPPDATA%', (Get-SessionFolder 'Local AppData') -replace '(?i)%APPDATA%', (Get-SessionFolder 'AppData')
        if ($ex2 -notmatch '%' -and -not (Test-Path -LiteralPath $ex2 -PathType Leaf)) {
            throw ("Le désinstalleur de « {0} » n'est plus sur le PC ({1}). Le logiciel a sans doute déjà été supprimé à la main, ou c'est son lanceur qui le gère (Steam, Epic, Bethesda, Ubisoft…) : désinstalle-le depuis ce lanceur. Sinon : Paramètres > Applications > Applications installées." -f $Name, $ex2)
        }
        if (-not (Start-AsSessionUser $exe $arg)) { throw "Le désinstalleur n'a pas pu être lancé sur ton compte. Désinstalle-le depuis Paramètres > Applications." }
        return
    }
    # %ProgramFiles%… écrit tel quel dans le registre : Start-Process ne le remplace pas tout seul
    $exe = [Environment]::ExpandEnvironmentVariables($exe)
    # Désinstalleur rangé hors des dossiers protégés de Windows (D:\Jeux, dossier perso…) : un programme sans droits admin
    # pourrait l'avoir remplacé. Il est alors lancé sur le compte de la personne, SANS les droits admin d'AEROX
    # (il demandera lui-même l'autorisation de Windows s'il en a besoin). Relecture Gemini n° 4.
    $full = ''; try { $full = [IO.Path]::GetFullPath($exe) } catch {}
    $prot = @($env:SystemRoot, $env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\') + '\' }
    $safe = $full -and [AeroxSafeDelete]::IsDirectPath($full) -and @($prot | Where-Object { $full.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
    if (-not $safe -and (Test-Path -LiteralPath $exe -PathType Leaf)) {
        if (-not (Start-AsSessionUser $exe $arg)) { throw "Le désinstalleur n'a pas pu être lancé sur ton compte. Désinstalle-le depuis Paramètres > Applications." }
        return
    }
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        throw ("Le désinstalleur de « {0} » n'est plus sur le PC ({1}). Le logiciel a sans doute déjà été supprimé à la main, ou c'est son lanceur qui le gère (Steam, Epic, Bethesda, Ubisoft…) : désinstalle-le depuis ce lanceur. Sinon : Paramètres > Applications > Applications installées." -f $Name, $exe)
    }
    if ($arg) { Start-Process -FilePath $exe -ArgumentList $arg } else { Start-Process -FilePath $exe }
}

# ---------------------------------------------------------------- NETTOYAGE APPROFONDI (analyse + choix)
function Get-PathsSize([string[]]$Paths) {
    $t = [double]0
    foreach ($p in $Paths) {
        if (-not $p) { continue }
        if (Test-Path -LiteralPath $p -PathType Leaf) { try { $t += (Get-Item -LiteralPath $p -Force).Length } catch {} }
        else { $t += [AeroxNative]::FolderSize($p) }
    }
    return $t
}
function Get-BrowserCacheDirs {
    $la = Get-SessionFolder 'Local AppData'
    $list = @()
    $defs = @(
        @{ Name = 'Google Chrome';  Proc = 'chrome'; Dir = "$la\Google\Chrome\User Data" },
        @{ Name = 'Microsoft Edge'; Proc = 'msedge'; Dir = "$la\Microsoft\Edge\User Data" },
        @{ Name = 'Brave';          Proc = 'brave';  Dir = "$la\BraveSoftware\Brave-Browser\User Data" },
        @{ Name = 'Opera GX';       Proc = 'opera';  Dir = "$la\Opera Software\Opera GX Stable" },
        @{ Name = 'Opera';          Proc = 'opera';  Dir = "$la\Opera Software\Opera Stable" }
    )
    foreach ($b in $defs) {
        if (-not (Test-Path -LiteralPath $b.Dir)) { continue }
        $profiles = @($b.Dir) + @(Get-ChildItem -LiteralPath $b.Dir -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(Default|Profile \d+)$' } | ForEach-Object { $_.FullName })
        $dirs = foreach ($p in $profiles) { foreach ($c in 'Cache', 'Code Cache', 'GPUCache', 'GrShaderCache', 'ShaderCache', 'DawnCache', 'DawnGraphiteCache', 'DawnWebGPUCache') { Join-Path $p $c } }
        $list += @{ Name = $b.Name; Proc = $b.Proc; Dirs = @($dirs) }
    }
    $ff = "$la\Mozilla\Firefox\Profiles"
    if (Test-Path -LiteralPath $ff) { $list += @{ Name = 'Firefox'; Proc = 'firefox'; Dirs = @(Get-ChildItem -LiteralPath $ff -Directory -ErrorAction SilentlyContinue | ForEach-Object { Join-Path $_.FullName 'cache2' }) } }
    return $list
}
function Get-AppCacheDirs {
    $l = Get-SessionFolder 'Local AppData'; $r = Get-SessionFolder 'AppData'
    $epic = @(Get-ChildItem -LiteralPath "$l\EpicGamesLauncher\Saved" -Directory -Filter 'webcache*' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    return @(
        @{ Name = 'Discord';    Proc = 'discord';           Dirs = @("$r\discord\Cache", "$r\discord\Code Cache", "$r\discord\GPUCache") },
        @{ Name = 'Spotify';    Proc = 'spotify';           Dirs = @("$l\Spotify\Data", "$l\Spotify\Storage", "$l\Spotify\Browser\Cache") },
        @{ Name = 'Steam';      Proc = 'steam';             Dirs = @("$l\Steam\htmlcache") },
        @{ Name = 'Epic Games'; Proc = 'EpicGamesLauncher'; Dirs = $epic },
        @{ Name = 'Teams';      Proc = 'teams';             Dirs = @("$r\Microsoft\Teams\Cache", "$r\Microsoft\Teams\Code Cache", "$r\Microsoft\Teams\GPUCache", "$r\Microsoft\Teams\Service Worker\CacheStorage") }
    ) | Where-Object { @($_.Dirs | Where-Object { $_ -and (Test-Path -LiteralPath $_) }).Count -gt 0 }
}
function Get-ShaderCacheDirs {
    $l = Get-SessionFolder 'Local AppData'; $ll = Get-SessionFolder 'LocalLow'
    return @("$l\D3DSCache", "$l\NVIDIA\DXCache", "$l\NVIDIA\GLCache", "$ll\NVIDIA\PerDriverVersion\DXCache", "$ll\NVIDIA\PerDriverVersion\GLCache",
             "$l\AMD\DxCache", "$l\AMD\DxcCache", "$l\AMD\GLCache", "$l\AMD\VkCache", "$l\Intel\ShaderCache", "$env:ProgramData\NVIDIA Corporation\NV_Cache")
}
function Get-TempOnlyDirs {
    $d = @()
    foreach ($p in Get-UserProfiles) { $d += (Join-Path $p 'AppData\Local\Temp') }
    $d += "$env:SystemRoot\Temp"
    foreach ($p in Get-UserProfiles) { $d += @(Get-ChildItem -LiteralPath (Join-Path $p 'AppData\Local\Microsoft\Windows\Explorer') -Filter 'thumbcache_*.db' -Force -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }) }
    return $d
}
function Get-ErrorDirs {
    $d = @("$env:SystemRoot\Minidump", "$env:SystemRoot\LiveKernelReports", "$env:SystemRoot\MEMORY.DMP",
           "$env:ProgramData\Microsoft\Windows\WER\ReportArchive", "$env:ProgramData\Microsoft\Windows\WER\ReportQueue")
    foreach ($p in Get-UserProfiles) { $d += (Join-Path $p 'AppData\Local\CrashDumps') }
    return $d
}
$script:DoPath = "$env:SystemRoot\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache"
$script:WinOldPaths = @("$env:SystemDrive\Windows.old", "$env:SystemDrive\`$Windows.~BT", "$env:SystemDrive\`$Windows.~WS")
$script:CleanMgrSafe = @('Active Setup Temp Folders', 'BranchCache', 'D3D Shader Cache', 'Delivery Optimization Files', 'Device Driver Packages', 'Diagnostic Data Viewer database files',
    'Downloaded Program Files', 'Feedback Hub Archive log files', 'Internet Cache Files', 'Old ChkDsk Files', 'RetailDemo Offline Content', 'Setup Log Files',
    'System error memory dump files', 'System error minidump files', 'Temporary Files', 'Temporary Setup Files', 'Thumbnail Cache', 'Update Cleanup',
    'Upgrade Discarded Files', 'Windows Defender', 'Windows Error Reporting Files', 'Windows Upgrade Log Files')

function Get-CleanupAnalysis {
    Step "Analyse de ce qui peut être nettoyé"
    $cats = New-Object System.Collections.ArrayList
    $add = { param($h) [void]$cats.Add($h); $sz = if ($h.Size -ge 0) { Format-Size $h.Size } else { 'taille calculée par Windows' }; Log ("   • {0} : {1}" -f $h.Name, $sz) }

    & $add @{ Id = 'temp'; Name = 'Fichiers temporaires'; Default = $true; Size = (Get-PathsSize (Get-TempOnlyDirs))
              Desc = "Fichiers temporaires de Windows et des logiciels, cache des miniatures. Les fichiers en cours d'utilisation sont ignorés." }
    $b = @(Get-BrowserCacheDirs)
    if ($b.Count) {
        $open = @($b | Where-Object { Get-Process -Name $_.Proc -ErrorAction SilentlyContinue } | ForEach-Object { $_.Name })
        & $add @{ Id = 'browser'; Name = 'Cache des navigateurs'; Default = $true; Size = (Get-PathsSize ($b | ForEach-Object { $_.Dirs }))
                  Desc = ("Pages et images gardées en mémoire par " + (($b | ForEach-Object { $_.Name }) -join ', ') + ". Mots de passe, favoris et connexions ne sont pas touchés." + $(if ($open) { " Ouvert(s) en ce moment : " + ($open -join ', ') + " (ignoré(s) sauf si tu les fermes)." } else { '' })) }
    }
    $a = @(Get-AppCacheDirs)
    if ($a.Count) {
        $open = @($a | Where-Object { Get-Process -Name $_.Proc -ErrorAction SilentlyContinue } | ForEach-Object { $_.Name })
        & $add @{ Id = 'apps'; Name = 'Cache des applications'; Default = $true; Size = (Get-PathsSize ($a | ForEach-Object { $_.Dirs }))
                  Desc = ("Fichiers mis en cache par " + (($a | ForEach-Object { $_.Name }) -join ', ') + " (ils se reconstruisent tout seuls, tu restes connecté)." + $(if ($open) { " Ouvert(s) en ce moment, donc ignoré(s) : " + ($open -join ', ') + "." } else { '' })) }
    }
    & $add @{ Id = 'wupdate'; Name = 'Fichiers de mises à jour Windows'; Default = $true; Size = (Get-PathsSize @("$env:SystemRoot\SoftwareDistribution\Download", $script:DoPath))
              Desc = "Mises à jour déjà installées et cache d'optimisation de distribution. Windows les retélécharge si besoin." }
    & $add @{ Id = 'errors'; Name = "Rapports d'erreurs et de plantages"; Default = $true; Size = (Get-PathsSize (Get-ErrorDirs))
              Desc = "Fichiers créés quand un logiciel ou Windows plante (écrans bleus compris). Inutiles une fois le problème réglé." }
    & $add @{ Id = 'windows'; Name = 'Nettoyage de disque Windows'; Default = $true; Size = -1
              Desc = "L'outil officiel de Windows : journaux d'installation, anciens pilotes, fichiers de mise à niveau, cache Defender, etc. Peut prendre plusieurs minutes." }
    & $add @{ Id = 'components'; Name = 'Anciens composants Windows'; Default = $true; Size = -1
              Desc = "Anciennes versions des fichiers Windows remplacées par les mises à jour (outil DISM). Souvent plusieurs Go. 5 à 20 minutes." }
    & $add @{ Id = 'shaders'; Name = 'Cache des shaders (jeux)'; Default = $false; Size = (Get-PathsSize (Get-ShaderCacheDirs))
              Desc = "Cache graphique DirectX / NVIDIA / AMD / Intel. Il se reconstruit tout seul, mais les jeux peuvent saccader un peu au premier lancement. Utile après une mise à jour du pilote graphique ou en cas de bugs graphiques." }
    $rbs = Get-RecycleBinSizes
    & $add @{ Id = 'recycle'; Name = 'Corbeille'; Default = $false; Size = $rbs.Mine; Desc = ("Vide ta corbeille sur tous les disques. Vérifie avant qu'il n'y a rien dedans dont tu as besoin." + $(if ($rbs.Others -gt 1MB) { " ({0} dans la corbeille d'autres comptes du PC : pas touchés.)" -f (Format-Size $rbs.Others) } else { '' })) }
    & $add @{ Id = 'resetbase'; Name = 'Sauvegardes des mises à jour Windows'; Default = $false; Size = -1
              Desc = "Libère encore plus de place, mais les mises à jour déjà installées ne pourront plus être désinstallées. À cocher seulement si Windows marche bien." }
    if (@($script:WinOldPaths | Where-Object { Test-Path -LiteralPath $_ }).Count) {
        & $add @{ Id = 'winold'; Name = 'Ancienne version de Windows (Windows.old)'; Default = $false; Size = (Get-PathsSize $script:WinOldPaths)
                  Desc = "Copie de l'ancien Windows gardée après une grosse mise à jour. Après suppression, impossible de revenir à la version précédente." }
    }
    $hib = "$env:SystemDrive\hiberfil.sys"
    if (Test-Path -LiteralPath $hib) {
        $isLaptop = [bool](Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
        & $add @{ Id = 'hiber'; Name = 'Fichier de veille prolongée (hiberfil.sys)'; Default = $false; Size = (Get-PathsSize @($hib))
                  Desc = ("Désactive la veille prolongée et le « démarrage rapide ». Le PC démarre quelques secondes plus lentement, mais s'éteint vraiment." + $(if ($isLaptop) { " Déconseillé sur un portable (la veille prolongée protège la batterie)." } else { " Sur un PC fixe, on ne s'en sert presque jamais." })) }
    }
    $sync.CleanList = @($cats)
    $tot = [double]0; foreach ($c in $cats) { if ($c.Default -and $c.Size -gt 0) { $tot += $c.Size } }
    Log ("   Environ {0} à libérer avec la sélection conseillée (+ ce que trouvera Windows)." -f (Format-Size $tot))
}

function Clear-Paths([string[]]$Paths, [string]$Label) {
    $freed = [double]0
    foreach ($p in $Paths) {
        if (-not $p -or -not (Test-Path -LiteralPath $p)) { continue }
        $it = Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
        if (-not $it) { continue }
        if ($it.PSIsContainer) { $freed += Remove-PathContent $p } else { $freed += Remove-ItemSafe $it }
    }
    $script:TotalFreed += $freed
    Log ("   ✔ {0} : {1} libérés" -f $Label, (Format-Size $freed))
}

function Invoke-CleanMgr([string[]]$Handlers, [int]$Slot) {
    $root = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
    $flag = 'StateFlags{0:D4}' -f $Slot
    foreach ($k in @(Get-ChildItem $root -ErrorAction SilentlyContinue)) {
        $v = if ($Handlers -contains $k.PSChildName) { 2 } else { 0 }
        try { New-ItemProperty -Path $k.PSPath -Name $flag -Value $v -PropertyType DWord -Force -ErrorAction Stop | Out-Null } catch {}
    }
    if (-not (Wait-WindowsCleanup)) { Log "   • Un autre nettoyage de Windows tourne encore : étape passée, relance-la plus tard."; return $false }
    $p = Start-Process -FilePath "$env:SystemRoot\System32\cleanmgr.exe" -ArgumentList "/sagerun:$Slot" -PassThru
    # Jamais d'attente infinie : « Annuler » l'arrête vraiment ; au-delà de 10 minutes, Windows finit tout seul en arrière-plan
    $t0 = Get-Date; $last = 0
    while (-not $p.WaitForExit(2000)) {
        if ($sync.Cancel) {
            try { $p.Kill() } catch {}
            Log "   • Nettoyage de Windows arrêté à ta demande (ce qui était déjà supprimé l'est, rien n'est abîmé)."
            return $false
        }
        $min = [int][math]::Floor(((Get-Date) - $t0).TotalMinutes)
        if ($min -ge 10) { Log "   • Le nettoyage de Windows continue tout seul en arrière-plan, AEROX passe à la suite."; return $false }
        if ($min -gt $last) { $last = $min; Log ("   … nettoyage de Windows en cours ({0} min)" -f $min) }
    }
    return $true
}
# Deux nettoyages de Windows en même temps se bloquent (cleanmgr et DISM touchent les mêmes composants) :
# on attend que le précédent ait fini (5 minutes au plus, « Annuler » possible). Vrai si la voie est libre.
function Wait-WindowsCleanup {
    $t0 = Get-Date; $said = $false
    while (@(Get-Process -Name 'cleanmgr', 'dism', 'DismHost' -ErrorAction SilentlyContinue).Count) {
        if ($sync.Cancel -or ((Get-Date) - $t0).TotalMinutes -ge 5) { return $false }
        if (-not $said) { $said = $true; Log "   … attente de la fin du nettoyage de Windows en cours" }
        Start-Sleep -Seconds 2
    }
    return $true
}

function Invoke-DeepClean([string[]]$Ids) {
    $free0 = [double](Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'").FreeSpace
    if ($Ids -contains 'browser' -and -not $sync.Cancel) {
        Step "Cache des navigateurs"
        foreach ($b in Get-BrowserCacheDirs) {
            if (Get-Process -Name $b.Proc -ErrorAction SilentlyContinue) {
                Add-TaskError -Title "Le cache de $($b.Name) n'a pas été vidé" -Cause "$($b.Name) est ouvert (ou tourne en arrière-plan), donc ses fichiers sont verrouillés." `
                    -Effect "Rien de grave : la place n'est simplement pas libérée." -FixLabel "Fermer $($b.Name) et réessayer" -FixAction "Stop-Browser '$($b.Proc)'; Clear-BrowserCache" `
                    -Confirm "$($b.Name) va être fermé. Tes onglets te seront proposés à la réouverture.`n`nContinuer ?"
                continue
            }
            Clear-Paths $b.Dirs $b.Name
        }
    }
    if ($Ids -contains 'apps' -and -not $sync.Cancel) {
        Step "Cache des applications"
        foreach ($a in Get-AppCacheDirs) {
            if (Get-Process -Name $a.Proc -ErrorAction SilentlyContinue) { Log "   • $($a.Name) est ouvert : ignoré (ferme-le et relance pour le nettoyer)"; continue }
            Clear-Paths $a.Dirs $a.Name
        }
    }
    if ($Ids -contains 'temp' -and -not $sync.Cancel) { Step "Fichiers temporaires"; Clear-Paths (Get-TempOnlyDirs) 'Fichiers temporaires' }
    if ($Ids -contains 'shaders' -and -not $sync.Cancel) { Step "Cache des shaders"; Clear-Paths (Get-ShaderCacheDirs) 'Cache des shaders' }
    if ($Ids -contains 'errors' -and -not $sync.Cancel) { Step "Rapports d'erreurs et de plantages"; Clear-Paths (Get-ErrorDirs) "Rapports d'erreurs" }
    if ($Ids -contains 'wupdate' -and -not $sync.Cancel) {
        Step "Fichiers de mises à jour Windows"
        Stop-Service -Name wuauserv, bits -Force -ErrorAction SilentlyContinue
        Clear-Paths @("$env:SystemRoot\SoftwareDistribution\Download") 'Mises à jour téléchargées'
        Start-Service -Name bits, wuauserv -ErrorAction SilentlyContinue
        if (Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue) { try { Delete-DeliveryOptimizationCache -Force -ErrorAction Stop | Out-Null; Log "   ✔ Cache d'optimisation de distribution vidé" } catch {} }
    }
    if ($Ids -contains 'recycle' -and -not $sync.Cancel) { Clear-RecycleBinAll }
    if ($Ids -contains 'windows' -and -not $sync.Cancel) {
        Step "Nettoyage de disque Windows (peut prendre plusieurs minutes)"
        try { if (Invoke-CleanMgr $script:CleanMgrSafe 7701) { Log "   ✔ Nettoyage de disque Windows terminé" } }
        catch { Add-TaskError -Title "Le nettoyage de disque Windows n'a pas pu se lancer" -Cause $_.Exception.Message -Bug $_ }
    }
    if ($Ids -contains 'winold' -and -not $sync.Cancel) {
        Step "Suppression de l'ancienne version de Windows"
        try { if (Invoke-CleanMgr @('Previous Installations', 'Temporary Setup Files', 'Windows Upgrade Log Files') 7702) { Log "   ✔ Ancienne version de Windows supprimée" } }
        catch { Add-TaskError -Title "Windows.old n'a pas pu être supprimé" -Cause $_.Exception.Message -Bug $_ }
    }
    if (($Ids -contains 'components' -or $Ids -contains 'resetbase') -and -not $sync.Cancel) {
        Step "Anciens composants Windows (DISM, 5 à 20 minutes)"
        $dargs = @('/Online', '/Cleanup-Image', '/StartComponentCleanup')
        if ($Ids -contains 'resetbase') { $dargs += '/ResetBase' }
        $busy = -not (Wait-WindowsCleanup)
        $ec = if ($busy) { 0 } elseif (Test-ComponentsPending) { -2146498554 } else { Invoke-Native 'dism.exe' $dargs -Quiet }
        if ($busy) { Log "   • Étape passée : le nettoyage de Windows tourne encore en arrière-plan. Relance « anciens composants » plus tard." }
        elseif ($ec -eq -2146498554) { Log $script:PendingMsg }
        elseif ($ec -ne 0) {
            Add-TaskError -Title "Le nettoyage des anciens composants n'a pas pu se terminer" -Code ('0x{0:X8}' -f $ec) -Cause "Windows est peut-être en train d'installer une mise à jour, ou un redémarrage est en attente." `
                -Effect "Rien n'est cassé : les anciens composants sont juste encore là." -FixLabel "Redémarrer puis réessayer" -FixAction 'Request-Reboot'
        } else { Log "   ✔ Anciens composants Windows nettoyés" }
    }
    if ($Ids -contains 'hiber' -and -not $sync.Cancel) {
        Step "Désactivation de la veille prolongée"
        $null = Invoke-Native 'powercfg.exe' @('/hibernate', 'off')
        if (Test-Path -LiteralPath "$env:SystemDrive\hiberfil.sys") { Log "   • Le fichier disparaîtra au prochain redémarrage" } else { Log "   ✔ hiberfil.sys supprimé" }
        Add-Change -Title "Veille prolongée désactivée" -Detail "Libère la place du fichier hiberfil.sys." -Undo 'Enable-Hibernation'
    }
    $free1 = [double](Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'").FreeSpace
    Step "Résultat"
    Log ("✅ Espace libéré sur {0} : {1} (maintenant {2} libres)" -f $env:SystemDrive, (Format-Size ([math]::Max([double]0, [double]$free1 - [double]$free0))), (Format-Size $free1))
    Add-Change -Kind 'info' -Title ("Nettoyage approfondi : {0} libérés" -f (Format-Size ([math]::Max([double]0, [double]$free1 - [double]$free0)))) -Detail "Fichiers inutiles supprimés (temporaires, caches, anciennes mises à jour). Pas besoin de les récupérer : Windows et les logiciels les recréent si nécessaire."
}

# Ce qui prend de la place sur le disque (arbre des dossiers)
function Get-SpaceUsage([string]$Drive = $env:SystemDrive) {
    Step "Analyse de l'espace sur $Drive (1 à 3 minutes selon le disque)"
    $sync.SpaceScan = $null
    $lines = [AeroxNative]::ScanSizes("$Drive\", 4)
    if ($sync.Cancel) { return }
    $d = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$Drive'"
    # Vieux installateurs et archives dans les Téléchargements (plus de 30 jours) : souvent des Go oubliés
    $old = New-Object System.Collections.ArrayList
    try {
        foreach ($prof in @(Get-UserProfiles)) {
            $dl = Join-Path $prof 'Downloads'
            if (-not $dl.StartsWith($Drive, [StringComparison]::OrdinalIgnoreCase)) { continue }
            foreach ($f in @(Get-ChildItem -LiteralPath $dl -File -Force -ErrorAction SilentlyContinue)) {
                if ($f.Extension -match '(?i)^\.(exe|msi|iso|img|zip|rar|7z)$' -and $f.LastWriteTime -lt (Get-Date).AddDays(-30)) { [void]$old.Add(@{ Path = $f.FullName; Size = [double]$f.Length; Date = $f.LastWriteTime }) }
            }
        }
    } catch {}
    $scan = @{ Lines = $lines; Drive = $Drive; Size = [double]$d.Size; Free = [double]$d.FreeSpace; OldInstallers = @($old | Sort-Object { - $_.Size }); Win = @(); OneDrive = @(); Forgotten = @(); OtherDrives = @() }
    if ($Drive -eq $env:SystemDrive) {
        Log "   • Place gardée par Windows (stockage réservé, veille prolongée, points de restauration, anciens pilotes)…"
        try { $scan.Win = @(Get-WindowsSpaceItems) } catch {}
        # Autres disques avec de la place : on peut y déplacer Téléchargements, Vidéos, jeux…
        try { $scan.OtherDrives = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop | Where-Object { $_.DeviceID -ne $Drive -and [double]$_.FreeSpace -ge 20GB } | ForEach-Object { @{ Drive = $_.DeviceID; Free = [double]$_.FreeSpace } }) } catch {}
    }
    if ($sync.Cancel) { return }
    Log "   • OneDrive, jeux et logiciels pas utilisés depuis 3 mois…"
    try {
        foreach ($f in @(Get-OneDriveFolders | Where-Object { $_.StartsWith($Drive, [StringComparison]::OrdinalIgnoreCase) })) {
            $local = [double][AeroxFiles]::LocalCloudSize($f)
            if ($local -ge 1GB) { $scan.OneDrive += @{ Folder = $f; Local = $local } }
        }
    } catch {}
    if ($sync.Cancel) { return }
    try { $scan.Forgotten = @(Get-ForgottenApps $Drive $lines) } catch {}
    if ($sync.Cancel) { return }
    $sync.SpaceScan = $scan
    Log ("   ✔ Analyse terminée : {0} dossiers mesurés." -f @($lines | Where-Object { $_ -notmatch '^[FB]\|' }).Count)
}

# ---------------------------------------------------------------- ASSISTANT « LIBÉRER DE LA PLACE »
# Tout ce qui peut libérer de la place sur le disque de Windows, en une seule liste triée par gain, avec ce qui est sans
# risque coché d'office. Rien de perso n'est supprimé directement : corbeille seulement, et les jeux et logiciels passent
# par leur vrai désinstalleur (ou par Steam).

# Jeux Steam installés (toutes les bibliothèques) : nom, taille, dernière partie (notée par Steam)
function Get-SteamGames {
    $out = New-Object System.Collections.ArrayList
    $roots = New-Object System.Collections.ArrayList
    foreach ($k in @("$((Get-SessionUser).Hkcu)\Software\Valve\Steam", 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam')) {
        try {
            $v = Get-ItemProperty -LiteralPath $k -ErrorAction Stop
            foreach ($p in @($v.SteamPath, $v.InstallPath)) { if ($p) { $q = ("$p" -replace '/', '\').TrimEnd('\'); if ($roots -notcontains $q -and (Test-Path -LiteralPath $q)) { [void]$roots.Add($q) } } }
        } catch {}
    }
    $libs = New-Object System.Collections.ArrayList
    foreach ($r in $roots) {
        if ($libs -notcontains $r) { [void]$libs.Add($r) }
        $vdf = Join-Path $r 'steamapps\libraryfolders.vdf'
        if (-not (Test-Path -LiteralPath $vdf)) { continue }
        foreach ($m in [regex]::Matches([IO.File]::ReadAllText($vdf), '"path"\s+"([^"]+)"')) {
            $l = ($m.Groups[1].Value -replace '\\\\', '\').TrimEnd('\')
            if ($l -and $libs -notcontains $l -and (Test-Path -LiteralPath $l)) { [void]$libs.Add($l) }
        }
    }
    $seen = @{}
    foreach ($l in $libs) {
        foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $l 'steamapps') -Filter 'appmanifest_*.acf' -File -ErrorAction SilentlyContinue)) {
            try {
                $t = [IO.File]::ReadAllText($f.FullName)
                $g = @{}; foreach ($m in [regex]::Matches($t, '"(appid|name|installdir|SizeOnDisk|LastPlayed)"\s+"([^"]*)"')) { if (-not $g.ContainsKey($m.Groups[1].Value)) { $g[$m.Groups[1].Value] = $m.Groups[2].Value } }
                if ("$($g.appid)" -notmatch '^\d{1,10}$' -or $seen.ContainsKey($g.appid)) { continue }
                $seen[$g.appid] = $true
                if ("$($g.name)" -match '(?i)redistributable|steamworks|proton|steam linux runtime') { continue }
                $dir = Join-Path $l ("steamapps\common\{0}" -f $g.installdir)
                $last = $null
                if ("$($g.LastPlayed)" -match '^\d+$' -and [int64]$g.LastPlayed -gt 0) { $last = [DateTimeOffset]::FromUnixTimeSeconds([int64]$g.LastPlayed).LocalDateTime }
                if ($null -eq $last) { $last = Get-FolderLastUsed $dir }
                [void]$out.Add(@{ AppId = $g.appid; Name = "$($g.name)"; Size = [double]("0$($g.SizeOnDisk)" -replace '\D', ''); LastUsed = $last; Path = $dir; Manifest = $f.FullName
                                  Drive = $(if ($dir -match '^([A-Za-z]:)') { $matches[1].ToUpper() } else { '' }) })
            } catch {}
        }
    }
    return @($out | Sort-Object { - $_.Size })
}

# Une ligne de l'assistant : Id (unique), Kind (clean, win, oldinst, recycle, steam, app), T (titre), D (explication),
# S (octets, -1 si Windows le calcule), Est (estimation), Check (coché d'office), Arg, Group
# Mise à jour Windows qui attend un redémarrage (Windows refuse alors de toucher au stockage réservé)
function Test-RebootPending {
    return ((Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
            (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'))
}
function New-FreeItem([string]$Id, [string]$Kind, [string]$Group, [string]$T, [string]$D, [double]$S, [bool]$Check, $Arg = $null, [bool]$Est = $false) {
    return @{ Id = $Id; Kind = $Kind; Group = $Group; T = $T; D = $D; S = $S; Check = $Check; Arg = $Arg; Est = $Est }
}
function Get-FreeSpacePlan {
    Step ("Recherche de tout ce qui peut libérer de la place sur {0}" -f $env:SystemDrive)
    $sync.FreePlan = $null
    $sd = $env:SystemDrive
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$sd'"
    $items = New-Object System.Collections.ArrayList
    # 1. Fichiers inutiles (même analyse que le nettoyage approfondi) : une seule ligne pour tout ce qui est sans risque
    $sync.CleanList = $null
    try { Get-CleanupAnalysis } catch {}
    $cl = @($sync.CleanList | Where-Object { $_ })
    $safe = @($cl | Where-Object { $_.Id -in 'temp', 'browser', 'apps', 'wupdate', 'errors', 'windows', 'components' })
    if ($safe.Count) {
        $sz = [double](($safe | Where-Object { $_.Size -gt 0 } | ForEach-Object { $_.Size } | Measure-Object -Sum).Sum)
        $open = @(Get-BrowserCacheDirs | Where-Object { Get-Process -Name $_.Proc -ErrorAction SilentlyContinue } | ForEach-Object { $_.Name })
        [void]$items.Add((New-FreeItem 'junk' 'clean' 'auto' 'Fichiers inutiles de Windows et des logiciels' ("Temporaires, caches des navigateurs et des applis, mises à jour déjà installées, rapports de plantage, anciens composants de Windows. Aucun risque : tes fichiers, mots de passe et connexions ne sont pas touchés." + $(if ($open.Count) { " Ferme d'abord " + ($open -join ', ') + " pour que son cache soit vidé aussi." } else { '' })) $sz $true @($safe | ForEach-Object { $_.Id })))
    }
    $wo = @($cl | Where-Object { $_.Id -eq 'winold' })[0]
    if ($wo -and $wo.Size -ge 100MB) {
        [void]$items.Add((New-FreeItem 'winold' 'clean' 'auto' 'Ancienne version de Windows (Windows.old)' "Copie de l'ancien Windows gardée après une grosse mise à jour, pour revenir en arrière. Si le PC marche bien depuis, elle ne sert plus. Après, impossible de revenir à la version d'avant." ([double]$wo.Size) $true @('winold')))
    }
    if ($sync.Cancel) { return }
    # 2. Place gardée par Windows (stockage réservé, veille prolongée, points de restauration, anciens pilotes, compression)
    Log "   • Place gardée par Windows…"
    try {
        foreach ($w in @(Get-WindowsSpaceItems)) {
            $arg = if ($w.Arg) { "{0}:{1}" -f $w.Id, $w.Arg } else { $w.Id }
            $d = $w.D
            if ($w.Id -eq 'reserved' -and (Test-RebootPending)) { $d = "Une mise à jour attend un redémarrage : Windows refusera de la libérer tant que le PC n'a pas redémarré. Redémarre, puis relance l'assistant." }
            [void]$items.Add((New-FreeItem ("win-" + $w.Id) 'win' 'windows' $w.T $d ([double]$w.S) ([bool]$w.Check -and -not ($w.Id -eq 'reserved' -and (Test-RebootPending))) $arg ([bool]$w.Est)))
        }
    } catch {}
    if ($sync.Cancel) { return }
    # 3. Vieux installateurs et archives des Téléchargements (plus de 30 jours) → corbeille
    Log "   • Téléchargements…"
    $old = New-Object System.Collections.ArrayList
    try {
        $dl = Get-SessionFolder 'Downloads'
        if ($dl -and $dl.StartsWith($sd, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $dl)) {
            foreach ($f in @(Get-ChildItem -LiteralPath $dl -File -Force -ErrorAction SilentlyContinue)) {
                if ($f.Extension -match '(?i)^\.(exe|msi|iso|img|zip|rar|7z)$' -and $f.LastWriteTime -lt (Get-Date).AddDays(-30) -and [AeroxSafeDelete]::IsDirectPath($f.FullName)) { [void]$old.Add(@{ Path = $f.FullName; Size = [double]$f.Length; Date = $f.LastWriteTime }) }
            }
        }
    } catch {}
    $ot = [double](($old | ForEach-Object { $_.Size } | Measure-Object -Sum).Sum)
    if ($old.Count -and $ot -ge 20MB) {
        $names = (@($old | Sort-Object { - $_.Size } | Select-Object -First 3 | ForEach-Object { [IO.Path]::GetFileName($_.Path) }) -join ', ') + $(if ($old.Count -gt 3) { " et $($old.Count - 3) autre(s)" } else { '' })
        [void]$items.Add((New-FreeItem 'oldinst' 'oldinst' 'files' ("{0} vieux installateur(s) et archive(s) dans Téléchargements" -f $old.Count) ("Fichiers d'installation de plus d'un mois, déjà utilisés : {0}. Ils vont à la corbeille (récupérables tant qu'elle n'est pas vidée)." -f $names) $ot $false @($old)))
    }
    # 4. Corbeille
    $rc = @($cl | Where-Object { $_.Id -eq 'recycle' })[0]
    $rsz = if ($rc) { [double]$rc.Size } else { 0.0 }
    [void]$items.Add((New-FreeItem 'recycle' 'clean' 'files' 'Vider la corbeille' "Les fichiers déjà supprimés prennent encore de la place tant que la corbeille n'est pas vidée. Vérifie avant qu'il n'y a rien dedans dont tu as besoin : après, ils ne sont plus récupérables." $rsz $false @('recycle')))
    if ($sync.Cancel) { return }
    # 5. Jeux Steam et logiciels pas lancés depuis 3 mois (sur le disque de Windows)
    Log "   • Jeux et logiciels pas utilisés depuis 3 mois…"
    $limit = (Get-Date).AddDays(-90)
    $fmtLast = { param($d) if ($d) { "dernière utilisation le " + (Format-Date $d) } else { "pas lancé depuis au moins 3 mois" } }
    try {
        foreach ($g in @(Get-SteamGames | Where-Object { $_.Drive -eq $sd.ToUpper() -and $_.Size -ge 1GB })) {
            if ($null -ne $g.LastUsed -and $g.LastUsed -ge $limit) { continue }
            [void]$items.Add((New-FreeItem ("steam-" + $g.AppId) 'steam' 'apps' ("{0} (jeu Steam)" -f $g.Name) ((& $fmtLast $g.LastUsed) + ". Steam te demandera de confirmer. Tes sauvegardes restent sur ton compte Steam : tu pourras le retélécharger quand tu veux.") $g.Size $false @{ AppId = $g.AppId; Name = $g.Name; Manifest = $g.Manifest }))
        }
    } catch {}
    try {
        $inst = @(Get-InstalledApps | ForEach-Object { $_ })
        foreach ($a in @(Get-ForgottenApps $sd @() | Where-Object { $_.Kind -eq 'app' })) {
            $full = @($inst | Where-Object { $_.Name -eq $a.Name -and $_.Kind -eq 'win32' })[0]
            if (-not $full -or -not $full.Cmd) { continue }
            [void]$items.Add((New-FreeItem ("app-" + [math]::Abs($a.Name.GetHashCode())) 'app' 'apps' $a.Name ((& $fmtLast $a.LastUsed) + ". Son désinstalleur officiel s'ouvrira : suis ses étapes.") ([double]$a.Size) $false @{ Name = $full.Name; Cmd = $full.Cmd; Key = $full.Key; PerUser = [bool]$full.PerUser }))
        }
    } catch {}
    $sync.FreePlan = @{ Drive = $sd; Size = [double]$disk.Size; Free = [double]$disk.FreeSpace; Items = @($items | Sort-Object { - $_.S }); RebootPending = (Test-RebootPending) }
    $tot = [double](($items | Where-Object { $_.Check -and $_.S -gt 0 } | ForEach-Object { $_.S } | Measure-Object -Sum).Sum)
    Log ("   ✔ {0} piste(s) trouvée(s), environ {1} libérables sans risque." -f $items.Count, (Format-Size $tot))
}
# Fait le ménage choisi dans l'assistant : fichiers inutiles et place gardée par Windows (les désinstallations suivent dans la fenêtre)
function Invoke-FreeSpacePlan([string[]]$Clean = @(), [string[]]$Win = @()) {
    $free0 = [double](Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'").FreeSpace
    $Clean = @($Clean | Where-Object { $_ -in 'temp', 'browser', 'apps', 'wupdate', 'errors', 'windows', 'components', 'winold', 'recycle' })
    if ($Clean.Count -and -not $sync.Cancel) { Invoke-DeepClean -Ids $Clean }
    if (@($Win).Count -and -not $sync.Cancel) { Invoke-WindowsSpace -Items $Win }
    $free1 = [double](Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'").FreeSpace
    $sync.FreeDone = @{ Freed = [math]::Max([double]0, $free1 - $free0); Free = $free1 }
}

# ---------------------------------------------------------------- ÉTATS (affichés sur les cartes)
$script:PowerBalanced = '381b4222-f694-41f0-9685-ff5bb260df2e'
function Get-PowerStatus {
    $o = (powercfg.exe /getactivescheme 2>$null) | Out-String
    $guid = if ($o -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') { $matches[1].ToLower() } else { '' }
    $name = if ($o -match '\(([^)]+)\)\s*$') { $matches[1].Trim() } else { '' }
    $perf = ($guid -in '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c', 'e9a42b02-d5df-448d-aa00-03f14749eb61') -or ($name -match '(?i)perf|élev|optimal|ultimate|high')
    return @{ Guid = $guid; Name = $name; Perf = $perf }
}
function Set-BalancedPower {
    Step "Retour au mode d'alimentation normal"
    $prev = Get-PowerStatus
    $null = Invoke-Native 'powercfg.exe' @('/setactive', $script:PowerBalanced)
    if ($LASTEXITCODE -eq 0 -or -not (Get-PowerStatus).Perf) {
        Log "   ✔ Mode « Utilisation normale / Équilibré » activé."
        if ($prev.Guid -and $prev.Perf) { Add-Change -Title "Mode d'alimentation : Équilibré" -Detail ("Avant : {0}" -f $prev.Name) -Undo ("Set-PowerScheme {0} {1}" -f (ConvertTo-PsLiteral $prev.Guid), (ConvertTo-PsLiteral $prev.Name)) }
    }
    else { Add-TaskError -Title "Impossible de revenir au mode Équilibré" -Cause "Le mode Équilibré n'existe pas sur ce PC." -FixLabel "Ouvrir les options d'alimentation" -FixAction "Open-SystemTool 'powercfg.cpl'" }
}
function Get-VisualFxStatus {
    try { $v = (Get-ItemProperty -LiteralPath "$((Get-SessionUser).Hkcu)\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name VisualFXSetting -ErrorAction Stop).VisualFXSetting } catch { $v = 0 }
    return [int]$v
}
function Get-StorageSenseOn {
    try { return ((Get-ItemProperty -LiteralPath "$((Get-SessionUser).Hkcu)\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" -Name '01' -ErrorAction Stop).'01' -eq 1) } catch { return $false }
}
function Disable-StorageSense {
    Step "Désactivation du nettoyage automatique"
    $key = "$((Get-SessionUser).Hkcu)\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"
    if (Test-Path -LiteralPath $key) { Set-ItemProperty -LiteralPath $key -Name '01' -Value 0 -Type DWord }
    Log "   ✔ Nettoyage automatique désactivé."
    Add-Change -Title "Nettoyage automatique de Windows désactivé (Assistant stockage)" -Undo 'Enable-StorageSense'
}

# ---------------------------------------------------------------- OUTILS DE MESURE (téléchargés à la demande)
# Outils téléchargés (températures, test de débit, compteur de FPS) : lancés avec les droits admin, donc rangés
# dans le dossier protégé, jamais dans le dossier perso (modifiable par n'importe quel programme)
function Get-ToolsDir { return (Get-SecureDir 'outils') }
function Get-NvidiaSmi {
    foreach ($p in @("$env:SystemRoot\System32\nvidia-smi.exe", "$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe")) { if (Test-Path -LiteralPath $p) { return $p } }
    return $null
}
function Test-PawnIO {
    if (Get-Service -Name 'PawnIO' -ErrorAction SilentlyContinue) { return $true }
    foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*') {
        if (Get-ItemProperty $k -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match '(?i)pawnio' }) { return $true }
    }
    return $false
}
function Get-ToolStatus {
    $t = Get-ToolsDir
    return @{ PresentMon = [bool](Find-PresentMon); Lhm = (Test-Path (Join-Path $t 'lhm\LibreHardwareMonitorLib.dll')); PawnIO = (Test-PawnIO)
              Nvsmi = [bool](Get-NvidiaSmi) }
}
# Compteur de FPS (lancé avec les droits admin) : AEROX ne lance QUE la copie rangée dans le dossier protégé (écriture réservée
# aux administrateurs), et cette copie n'y entre que si Windows la reconnaît comme signée par Intel. Aucune exception, même
# juste après l'installation par winget. La signature est vérifiée sur la copie elle-même et non sur l'original, rangé dans
# un dossier de l'utilisateur : un programme du même compte aurait pu le remplacer entre la vérification et la copie.
# (Le vrai PresentMon d'Intel est signé « Intel Corporation » : vérifié sur Windows 11 et Windows Server par le test « Tester l'installation ».)
$script:PmSigOk = @{}
function Test-PresentMonCopy([string]$Path) {
    try {
        $fi = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        $k = '{0}|{1}|{2}' -f $fi.FullName, $fi.Length, $fi.LastWriteTimeUtc.Ticks
        if ($script:PmSigOk.ContainsKey($k)) { return $true }
        if (-not (Test-ToolSignature $Path 'Intel Corporation')) { return $false }
        $script:PmSigOk = @{ $k = $true }
        return $true
    } catch { return $false }
}
function Find-PresentMon {
    $safe = Join-Path (Get-ToolsDir) 'presentmon\PresentMon.exe'
    if (Test-Path -LiteralPath $safe) {
        if (Test-PresentMonCopy $safe) { return $safe }
        # Copie qui n'est pas signée par Intel (fichier remplacé, ou rangée sans vérification par une ancienne version d'AEROX) : retirée
        try { Remove-Item -LiteralPath $safe -Force -ErrorAction Stop } catch { return $null }
    }
    $tmp = Join-Path (Split-Path $safe -Parent) 'PresentMon-verif.exe'
    foreach ($src in @(Find-PresentMonInstalled -All)) {
        try {
            New-Item -ItemType Directory -Force -Path (Split-Path $safe -Parent) | Out-Null
            Copy-Item -LiteralPath $src -Destination $tmp -Force -ErrorAction Stop
            if (Test-PresentMonCopy $tmp) { Move-Item -LiteralPath $tmp -Destination $safe -Force -ErrorAction Stop; return $safe }
        } catch {}
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
    return $null
}
# Les PresentMon installés par winget (le plus récent d'abord) ; -All : tous, sinon seulement le premier
function Find-PresentMonInstalled([switch]$All) {
    $found = New-Object 'System.Collections.Generic.List[string]'
    foreach ($root in @("$env:LOCALAPPDATA\Microsoft\WinGet\Packages", "$env:ProgramFiles\WinGet\Packages")) {
        $files = @(Get-ChildItem -Path $root -Directory -Filter 'Intel.PresentMon.Console*' -ErrorAction SilentlyContinue |
                   ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Filter 'PresentMon*.exe' -Recurse -ErrorAction SilentlyContinue } |
                   Sort-Object LastWriteTime -Descending)
        foreach ($f in $files) { [void]$found.Add($f.FullName) }
    }
    foreach ($l in @("$env:LOCALAPPDATA\Microsoft\WinGet\Links\presentmon.exe", "$env:ProgramFiles\WinGet\Links\presentmon.exe")) {
        if (Test-Path -LiteralPath $l) { [void]$found.Add($l) }
    }
    if ($All) { return @($found) }
    if ($found.Count) { return $found[0] }
    return $null
}

function Install-WingetTool([string]$Id, [string]$Label) {
    $wg = Get-Winget
    if (-not $wg) { Add-WingetError "L'installation de $Label est"; return $false }
    $ec = Invoke-Native $wg (@('install', '--id', $Id, '--exact', '--silent', '--accept-package-agreements', '--accept-source-agreements') + (Get-WingetExtraArgs $wg)) ([System.Text.Encoding]::UTF8)
    return ($ec -eq 0 -or $ec -eq -1978335189 -or $ec -eq -1978335135)
}

function Install-PresentMon {
    Step "Installation du compteur de FPS (PresentMon, outil officiel d'Intel, via winget)"
    $null = Install-WingetTool 'Intel.PresentMon.Console' 'Le compteur de FPS'
    $pm = Find-PresentMon
    if ($pm) { Log "   ✔ PresentMon installé, signature d'Intel vérifiée : $pm" }
    elseif (Find-PresentMonInstalled) {
        Add-TaskError -Title "Le compteur de FPS n'a pas été activé" -Cause "PresentMon est bien présent sur le PC, mais Windows ne le reconnaît pas comme un programme signé par Intel (fichier remplacé ou abîmé, ou certificats de Windows pas à jour)." `
            -Effect "Par sécurité, AEROX ne lance pas un programme dont il ne peut pas vérifier l'origine : les FPS ne seront pas affichés." `
            -FixLabel "Réessayer" -FixAction 'Install-PresentMon' -Steps @("Mets Windows à jour (Paramètres > Windows Update), puis réessaie.", "Sinon, désinstalle le compteur dans Gaming > En direct puis réinstalle-le.", "Si le message revient, fais une analyse avec ton antivirus : le fichier a peut-être été modifié.")
    }
    else {
        Add-TaskError -Title "Le compteur de FPS n'a pas pu être installé" -Cause "winget n'a pas réussi à installer PresentMon (connexion, ou catalogue winget pas à jour)." -Effect "Les FPS ne seront pas affichés." `
            -FixLabel "Réessayer" -FixAction 'Install-PresentMon' -Steps @("Vérifie ta connexion Internet.", "Mets à jour « Programme d'installation d'application » dans le Microsoft Store, puis réessaie.")
    }
}

function Install-SensorLib {
    Step "Installation du module de températures (LibreHardwareMonitor, depuis nuget.org)"
    try {
        $dest = Join-Path (Get-ToolsDir) 'lhm'
        $n = [AeroxNuget]::Install('LibreHardwareMonitorLib', '0.9.6', $dest)
        # Ancien emplacement (dossier perso, modifiable sans droits admin) : plus jamais utilisé, on le vide
        $old = Join-Path $AppInfo.OldLogDir 'outils'
        if (Test-Path -LiteralPath $old) { $null = Remove-PathContent $old; try { [IO.Directory]::Delete($old, $false) } catch {} }
        foreach ($l in [AeroxNuget]::Log) { Log "   • $l" }
        if (-not (Test-Path (Join-Path $dest 'LibreHardwareMonitorLib.dll'))) { throw "Le module n'a pas été trouvé dans le paquet téléchargé." }
        Log ("   ✔ Module installé ({0} paquets)." -f $n)
        if (-not (Test-PawnIO)) { Log "   → Pour la température du PROCESSEUR, installe aussi le pilote PawnIO (bouton juste en dessous)." }
    } catch {
        $m = $_.Exception.Message; if ($_.Exception.InnerException) { $m = $_.Exception.InnerException.Message }
        Add-TaskError -Title "Le module de températures n'a pas pu être installé" -Cause $m -Effect "Les températures avancées ne seront pas affichées." `
            -FixLabel "Réessayer" -FixAction 'Install-SensorLib' -Steps @("Vérifie ta connexion Internet.", "Si ton antivirus a bloqué le téléchargement, autorise-le puis réessaie.")
    }
}

function Install-PawnIO {
    Step "Installation du pilote PawnIO (lecture de la température du processeur, via winget)"
    if (Test-PawnIO) { Log "   ✔ PawnIO est déjà installé."; return }
    $null = Install-WingetTool 'namazso.PawnIO' 'Le pilote PawnIO'
    if (Test-PawnIO) { Log "   ✔ Pilote PawnIO installé. La température du processeur va apparaître (relance AEROX PC Care si besoin)." }
    else {
        Add-TaskError -Title "Le pilote PawnIO n'a pas pu être installé" -Cause "winget n'a pas réussi à l'installer, ou un redémarrage est nécessaire." -Effect "La température du processeur ne sera pas affichée (celle de la carte graphique oui)." `
            -FixLabel "Ouvrir le site de PawnIO" -FixAction "[void](Open-Url 'https://pawnio.eu/')" -Steps @("Redémarre le PC puis relance AEROX PC Care.", "Sinon, télécharge l'installateur officiel sur pawnio.eu et lance-le.")
    }
}

# Désinstallation des composants de mesure (au choix de la personne : rien n'est obligatoire).
# L'interface arrête les mesures avant (processus des capteurs et compteur de FPS), sinon les fichiers seraient verrouillés.
function Uninstall-WingetTool([string]$Id) {
    $wg = Get-Winget
    if (-not $wg) { return $false }
    $ec = Invoke-Native $wg (@('uninstall', '--id', $Id, '--exact', '--silent', '--accept-source-agreements') + (Get-WingetExtraArgs $wg)) ([System.Text.Encoding]::UTF8)
    return ($ec -eq 0 -or $ec -eq -1978335212)   # 0x8A150014 : déjà plus installé
}
function Uninstall-SensorLib {
    Step "Désinstallation du module de températures (LibreHardwareMonitor)"
    $d = Join-Path (Get-ToolsDir) 'lhm'
    # Ancien emplacement aussi (sinon le module serait réinstallé tout seul au prochain lancement)
    $old = Join-Path $AppInfo.OldLogDir 'outils'
    if (Test-Path -LiteralPath $old) { $null = Remove-PathContent $old; try { [IO.Directory]::Delete($old, $false) } catch {} }
    if (Test-Path -LiteralPath $d) { $null = Remove-PathContent $d; try { [IO.Directory]::Delete($d, $false) } catch {} }
    if (Test-Path -LiteralPath (Join-Path $d 'LibreHardwareMonitorLib.dll')) {
        Add-TaskError -Title "Le module de températures n'a pas pu être entièrement retiré" -Cause "Un de ses fichiers est encore utilisé." -Effect "Il reste installé pour l'instant." `
            -FixLabel "Réessayer" -FixAction 'Uninstall-SensorLib' -Steps @("Ferme AEROX PC Care (y compris l'icône près de l'horloge), relance-le, puis réessaie.")
        return
    }
    Log "   ✔ Module de températures désinstallé. Il reste les mesures de base (processeur, mémoire) et la carte NVIDIA via son pilote."
    Add-Change -Kind 'info' -Title "Module de températures désinstallé" -Detail "Tu peux le réinstaller quand tu veux depuis Gaming > En direct."
}
function Uninstall-PresentMon {
    Step "Désinstallation du compteur de FPS (PresentMon)"
    $ok = Uninstall-WingetTool 'Intel.PresentMon.Console'
    $d = Join-Path (Get-ToolsDir) 'presentmon'
    if (Test-Path -LiteralPath $d) { $null = Remove-PathContent $d; try { [IO.Directory]::Delete($d, $false) } catch {} }
    if ((Test-Path -LiteralPath (Join-Path $d 'PresentMon.exe')) -or (Find-PresentMonInstalled)) {
        Add-TaskError -Title "Le compteur de FPS n'a pas pu être entièrement désinstallé" -Cause $(if ($ok) { "Un de ses fichiers est encore utilisé." } else { "L'outil de Microsoft (winget) n'a pas réussi à le désinstaller." }) `
            -Effect "Il reste installé pour l'instant." -FixLabel "Réessayer" -FixAction 'Uninstall-PresentMon' -Steps @("Ferme AEROX PC Care (y compris l'icône près de l'horloge), relance-le, puis réessaie.")
        return
    }
    Log "   ✔ Compteur de FPS désinstallé. Les FPS ne seront plus mesurés (ni le suivi des parties)."
    Add-Change -Kind 'info' -Title "Compteur de FPS désinstallé" -Detail "Tu peux le réinstaller quand tu veux depuis Gaming > En direct."
}
function Uninstall-PawnIO {
    Step "Désinstallation du pilote PawnIO"
    if (-not (Test-PawnIO)) { Log "   • PawnIO n'est pas installé."; return }
    $null = Uninstall-WingetTool 'namazso.PawnIO'
    if (Test-PawnIO) {
        Add-TaskError -Title "Le pilote PawnIO n'a pas pu être désinstallé d'ici" -Cause "L'outil de Microsoft (winget) n'a pas réussi à le retirer (installé autrement, ou un redémarrage est nécessaire)." `
            -Effect "Il reste installé pour l'instant." -FixLabel "Ouvrir les applications installées" -FixAction "Open-WinUri 'ms-settings:appsfeatures'" `
            -Steps @("Redémarre le PC puis réessaie.", "Sinon : Paramètres > Applications > Applications installées > PawnIO > Désinstaller.")
        return
    }
    Log "   ✔ Pilote PawnIO désinstallé. La température du processeur ne sera plus lue."
    Add-Change -Kind 'info' -Title "Pilote PawnIO désinstallé" -Detail "Tu peux le réinstaller quand tu veux depuis Gaming > En direct."
}

# ---------------------------------------------------------------- MISES À JOUR
function Open-WingetStore {
    Log "   → J'ouvre le Microsoft Store : installe ou mets à jour « Programme d'installation d'application », puis relance AEROX PC Care."
    Open-WinUri 'ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1'
}

function Update-Apps {
    Step "Recherche des mises à jour de logiciels (winget)"
    $apps = Get-AppUpdates
    if ($null -eq $apps) { Add-WingetError "La mise à jour des logiciels est"; return }
    $ign = @(Get-IgnoredApps).Count
    if ($ign) { Log "   ($ign logiciel(s) ignoré(s) à ta demande : ils ne seront pas touchés)" }
    foreach ($g in @($apps | Where-Object { $_.Ghost })) { Log ("   • « {0} » semble déjà désinstallé (il ne reste qu'une trace dans Windows) : pas mis à jour, sinon il serait réinstallé." -f $g.Name) }
    foreach ($s in @($apps | Where-Object { $_.Self -and -not $_.Ghost })) { Log ("   • « {0} » se met à jour tout seul ou par son propre lanceur : rien à faire." -f $s.Name) }
    $apps = @($apps | Where-Object { -not $_.Ghost -and -not $_.Self })
    if ($apps.Count -eq 0) { Log "✅ Tous tes logiciels sont à jour."; return }
    Update-SelectedApps -Ids @($apps | ForEach-Object { $_.Id }) -Names @($apps | ForEach-Object { $_.Name }) -Versions @($apps | ForEach-Object { "$($_.Available)" })
}

# Ordre des mises à jour : winget lui-même (Microsoft.AppInstaller) toujours en dernier, les autres dans l'ordre donné
function Get-UpdateOrder([string[]]$Ids) {
    if (-not $Ids -or -not $Ids.Count) { return @() }
    return @(@(0..($Ids.Count - 1) | Where-Object { $Ids[$_] -ne 'Microsoft.AppInstaller' }) + @(0..($Ids.Count - 1) | Where-Object { $Ids[$_] -eq 'Microsoft.AppInstaller' }))
}
function Update-SelectedApps([string[]]$Ids, [string[]]$Names, [string[]]$Versions = @()) {
    $wg = Get-Winget
    if (-not $wg) { Add-WingetError "La mise à jour des logiciels est"; return }
    $extra = Get-WingetExtraArgs $wg
    # winget lui-même (« App Installer ») en dernier : sa mise à jour remplace winget.exe, et le chemin utilisé pour les
    # logiciels suivants n'existerait plus (rapport n° 24 : « winget.exe n'a pas pu s'exécuter : Accès refusé »)
    if (-not $Ids.Count) { return }
    $order = @(Get-UpdateOrder $Ids)
    $Ids = @($order | ForEach-Object { $Ids[$_] })
    if ($Names) { $Names = @($order | ForEach-Object { if ($_ -lt $Names.Count) { $Names[$_] } else { '' } }) }
    if ($Versions) { $Versions = @($order | ForEach-Object { if ($_ -lt $Versions.Count) { $Versions[$_] } else { '' } }) }
    $failed = @(); $ok = 0; $n = 0; $self = 0; $done = New-Object System.Collections.ArrayList
    for ($k = 0; $k -lt $Ids.Count; $k++) {
        if ($sync.Cancel) { Log ("⏹ Arrêt demandé : {0} logiciel(s) restant(s) pas mis à jour." -f ($Ids.Count - $k)); break }
        $id = $Ids[$k]; $name = if ($Names -and $k -lt $Names.Count -and $Names[$k]) { $Names[$k] } else { $id }
        $ver = if ($Versions -and $k -lt $Versions.Count) { "$($Versions[$k])" } else { '' }
        $n++
        Step ("Mise à jour {0}/{1} : {2}" -f $n, $Ids.Count, $name)
        $idArgs = if ($id.EndsWith([string][char]0x2026)) { @('--id', $id.TrimEnd([char]0x2026)) } else { @('--id', $id, '--exact') }
        $ec = $null
        for ($try = 0; $try -lt 2 -and $null -eq $ec; $try++) {
            try { $ec = Invoke-Native $wg (@('upgrade') + $idArgs + @('--silent', '--accept-package-agreements', '--accept-source-agreements') + $extra) ([System.Text.Encoding]::UTF8) }
            catch {
                # winget ne démarre plus (mis à jour entre-temps, ou bloqué) : on le recherche une fois, puis on passe au suivant
                Log ("   • L'outil de mise à jour (winget) n'a pas démarré : {0}" -f $_.Exception.Message)
                $script:WingetPath = $null; $wg = Get-Winget
                if (-not $wg) { break }
                $extra = Get-WingetExtraArgs $wg
            }
        }
        if ($null -eq $ec) {
            $failed += "$name (l'outil de mise à jour de Windows n'a pas démarré)"
            Log "   ✖ $name : pas mis à jour (l'outil de mise à jour de Windows n'a pas démarré)"
            if (-not $wg) { Log "   ⚠ L'outil de mise à jour de Windows (winget) ne répond plus : les logiciels restants ne peuvent pas être mis à jour maintenant."; break }
            continue
        }
        # winget vient de se mettre à jour lui-même : son ancien chemin n'existe plus
        if ($id -eq 'Microsoft.AppInstaller') { $script:WingetPath = $null }
        if ($ec -eq 0) { $ok++; [void]$done.Add(@{ Id = $id; Ver = $ver; Name = $name }); Log "   ✔ $name mis à jour"; Add-Change -Kind 'info' -Title "« $name » mis à jour" -Detail "Pour revenir à l'ancienne version, il faut la réinstaller depuis le site du logiciel." }
        elseif ($ec -eq -1978335189) {
            # « Aucune mise à jour applicable » : winget voit une version plus récente qui ne s'applique pas à ce PC
            $self++; Add-SelfUpdating $id $ver
            Log "   • $name : déjà à jour (la version proposée ne s'applique pas à ce PC, elle ne sera plus proposée)"
        } elseif ($ec -eq -1978335090) {
            # Installé d'une autre façon que celle du catalogue (Edge, Epic Online Services…) : il se met à jour lui-même
            $self++; Add-SelfUpdating $id $ver
            Log "   • $name : se met à jour tout seul ou par son propre lanceur, l'outil de Microsoft ne peut pas le faire à sa place. Rien à faire : il ne sera plus proposé pour cette version."
        }
        else {
            $why = switch ($ec) {
                -1978334975 { "le logiciel est ouvert, ferme-le puis réessaie" }
                -1978334974 { "une autre installation est déjà en cours" }
                -1978335212 { "logiciel introuvable dans le catalogue" }
                -1978335226 { "son propre installateur a échoué" + $(if ("$id$ver" -notmatch [char]0x2026 -and (Register-InstallerFailure $id $ver)) { " deux fois : mets-le à jour depuis le logiciel lui-même (souvent Paramètres > Mises à jour), il ne sera plus proposé ici pour cette version" } else { " : réessaie plus tard, ou mets-le à jour depuis le logiciel lui-même" }) }
                default { "code 0x{0:X8}" -f $ec }
            }
            $failed += "$name ($why)"
            Log "   ✖ $name : échec ($why)"
        }
    }
    if ($failed.Count) {
        Add-TaskError -Title ("{0} mise(s) à jour n'ont pas pu s'installer" -f $failed.Count) -Cause ($failed -join ' ; ') `
            -Effect "Ces logiciels restent dans leur ancienne version. Les autres ont bien été mis à jour." `
            -Steps @("Ferme les logiciels concernés, y compris ceux près de l'horloge (Discord, Steam...), puis réessaie.", "Si un logiciel bloque toujours, mets-le à jour depuis son propre menu ou son site officiel, ou ignore-le dans « Choisir les mises à jour ».")
    }
    # Vérification : un logiciel « mis à jour » qui annonce encore la même mise à jour = le catalogue de winget installe en
    # réalité une version plus ancienne que celle qu'il affiche (vu avec VS Code). Il n'est plus proposé pour cette version.
    if ($done.Count -and -not $sync.Cancel) {
        $after = $null; try { $after = Get-AppUpdates } catch {}
        foreach ($d in $done) {
            if (-not $d.Ver) { continue }
            $again = @(@($after) | Where-Object { $_ -and $_.Id -eq $d.Id -and "$($_.Available)" -eq $d.Ver })
            if ($again.Count) {
                Add-SelfUpdating $d.Id $d.Ver
                Log ("   • {0} : installé, mais il affiche encore l'ancienne version ({1}) : le catalogue de Microsoft annonce la {2} et installe en fait une version plus ancienne. Rien à faire de ton côté (il se met à jour tout seul) : il ne sera plus proposé pour cette version." -f $d.Name, $again[0].Version, $d.Ver)
            }
        }
    }
    Log ("✅ {0} logiciel(s) mis à jour sur {1}{2}." -f $ok, $Ids.Count, $(if ($self) { " ($self se met(tent) à jour tout seul(s))" } else { '' }))
}

# Pour la fenêtre de choix : liste complète, ignorés compris
function Get-AppUpdatesForUi {
    Step "Recherche des logiciels à mettre à jour"
    $sync.AppList = $null
    $apps = Get-AppUpdates -IncludeIgnored
    if ($null -eq $apps) { Add-WingetError "La recherche des mises à jour des logiciels est"; return }
    $sync.AppList = @($apps)
    Log ("   {0} logiciel(s) ont une mise à jour (dont {1} ignoré(s))." -f $apps.Count, @($apps | Where-Object { $_.Ignored }).Count)
}

function Update-Windows {
    Step "Recherche des mises à jour Windows (ça peut prendre quelques minutes)..."
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $session.ClientApplicationID = 'AEROX PC Care'
        $result = $session.CreateUpdateSearcher().Search("IsInstalled=0 and IsHidden=0 and Type='Software'")
    } catch {
        $code = (Get-ErrorCode $_)
        $wi = Get-WuErrorInfo $code
        Add-TaskError -Title "Impossible de rechercher les mises à jour Windows" -Code $code -Cause $wi.Cause -Effect "Aucune mise à jour ne peut être installée pour l'instant." `
            -FixLabel "Débloquer Windows Update et réessayer" -FixAction 'Reset-WindowsUpdate; Update-Windows'
        return
    }
    $toInstall = New-Object -ComObject Microsoft.Update.UpdateColl
    foreach ($u in $result.Updates) {
        $isUpgrade = $false
        foreach ($c in $u.Categories) { if ($c.CategoryID -eq '3689bdc8-b205-4af4-8d4b-a63924c5e9d5') { $isUpgrade = $true } }
        if ($isUpgrade) { Log ("   • Ignorée (grosse mise à niveau, à faire depuis Paramètres) : {0}" -f $u.Title); continue }
        if (-not $u.EulaAccepted) { try { $u.AcceptEula() } catch {} }
        [void]$toInstall.Add($u)
        Log ("   • {0}" -f $u.Title)
    }
    if ($toInstall.Count -eq 0) { Log "✅ Windows est à jour !"; return }

    Step ("Téléchargement de {0} mise(s) à jour..." -f $toInstall.Count)
    try {
        $dl = $session.CreateUpdateDownloader(); $dl.Updates = $toInstall; [void]$dl.Download()
        Step "Installation en cours (n'éteins pas le PC)..."
        $inst = $session.CreateUpdateInstaller(); $inst.Updates = $toInstall
        $res = $inst.Install()
    } catch {
        $code = (Get-ErrorCode $_)
        $wi = Get-WuErrorInfo $code
        Add-TaskError -Title "Le téléchargement ou l'installation des mises à jour a échoué" -Code $code -Cause $wi.Cause -Effect "Les mises à jour ne sont pas installées." `
            -FixLabel "Débloquer et réessayer" -FixAction $wi.Fix
        return
    }
    for ($i = 0; $i -lt $toInstall.Count; $i++) {
        $r = $res.GetUpdateResult($i)
        $title = $toInstall.Item($i).Title
        if ($r.ResultCode -eq 4 -or $r.ResultCode -eq 5) {
            $code = '0x{0:X8}' -f $r.HResult
            $wi = Get-WuErrorInfo $code
            Add-TaskError -Title "La mise à jour « $title » a échoué" -Code $code -Cause $wi.Cause -Effect "Windows reste sans ce correctif et retentera en boucle." `
                -FixLabel "Débloquer et réessayer" -FixAction $wi.Fix -Confirm "Windows Update va être remis à zéro puis la mise à jour réinstallée. Ça peut prendre 10 à 30 minutes."
        } else { Log ("   ✔ Installée : {0}" -f $title) }
    }
    if ($res.RebootRequired) { Log "⚠ Un redémarrage est nécessaire pour terminer l'installation."; $sync.NeedReboot = $true }
}

# ---------------------------------------------------------------- Pilotes : vérification dans le logiciel
# Carte graphique : comparée au site du fabricant (Get-GpuDrivers). Autres pilotes : ceux que Windows Update propose
# (recherche directe, sans ouvrir la page « Mises à jour facultatives » qui mélange pilotes et grosses mises à niveau de Windows).
$script:DriverErrNames = @{ 1 = 'mal configuré'; 3 = 'pilote abîmé'; 10 = 'ne peut pas démarrer'; 28 = 'pilote non installé'; 31 = 'ne fonctionne pas correctement'; 39 = 'pilote abîmé ou manquant'; 43 = 'arrêté après une erreur'; 52 = 'pilote non signé' }
# Périphériques en panne (Gestionnaire de périphériques) avec : ce que c'est, pourquoi, quoi faire, et si AEROX peut
# réinstaller son pilote sans risque (jamais les disques, le processeur, la carte mère ou l'affichage)
$script:DeviceKinds = @{ 'USB' = 'appareil ou port USB'; 'HIDClass' = 'clavier, souris ou manette'; 'Bluetooth' = 'Bluetooth'; 'Net' = 'carte réseau ou Wi-Fi'; 'MEDIA' = 'son'; 'AudioEndpoint' = 'son'
    'Camera' = 'webcam'; 'Image' = 'webcam ou scanner'; 'Ports' = 'port série'; 'Biometric' = 'lecteur d''empreinte'; 'Printer' = 'imprimante'; 'SoftwareDevice' = 'appareil logiciel'
    'Display' = 'carte graphique'; 'DiskDrive' = 'disque'; 'SCSIAdapter' = 'contrôleur de disque'; 'HDC' = 'contrôleur de disque'; 'System' = 'composant de la carte mère'; 'Processor' = 'processeur' }
function Get-ProblemDevices([switch]$Full) {
    $out = New-Object System.Collections.ArrayList
    foreach ($d in @(Get-CimInstance Win32_PnPEntity -Filter 'ConfigManagerErrorCode <> 0' -ErrorAction SilentlyContinue | Where-Object { $_.ConfigManagerErrorCode -notin 22, 24, 45 })) {
        $code = [int]$d.ConfigManagerErrorCode
        $r = $script:DriverErrNames[$code]; if (-not $r) { $r = "code $code" }
        $cls = "$($d.PNPClass)"; $kind = $script:DeviceKinds[$cls]; if (-not $kind) { $kind = if ($cls) { $cls } else { 'type inconnu' } }
        $name = if ($d.Name) { "$($d.Name)" } else { 'Périphérique inconnu' }
        $hw = @($d.HardwareID) | Select-Object -First 1
        $why = switch ($code) {
            28 { "Windows n'a aucun pilote pour lui." }
            43 { "Il s'est arrêté après une erreur (souvent un appareil USB qui décroche, ou son pilote)." }
            10 { "Il n'arrive pas à démarrer (pilote abîmé ou pas adapté)." }
            { $_ -in 3, 31, 39 } { "Son pilote est abîmé ou manquant." }
            52 { "Son pilote n'est pas signé (installé depuis une source non officielle)." }
            default { "Son pilote ne fonctionne pas correctement." }
        }
        $step = switch ($code) {
            28 { "« $name » : clique sur « Vérifier les pilotes » (Windows Update), sinon prends le pilote sur le site du fabricant de l'appareil." }
            43 { "« $name » : débranche-le et rebranche-le sur un autre port USB (de préférence à l'arrière du PC)." }
            52 { "« $name » : réinstalle son pilote depuis le site officiel du fabricant." }
            default { "« $name » : réinstalle son pilote (bouton vert), puis redémarre le PC." }
        }
        $safe = ($cls -notin 'Display', 'DiskDrive', 'SCSIAdapter', 'HDC', 'System', 'Processor', 'Volume', 'VolumeSnapshot', 'Computer', 'Firmware', 'SecurityDevices') -and $code -in 3, 10, 31, 39, 43 -and "$($d.PNPDeviceID)"
        if ($Full) { [void]$out.Add(@{ Name = $name; Reason = $r; Code = $code; Class = $cls; Kind = $kind; Why = $why; Step = $step; HwId = $(if ($hw) { "[$hw]" } else { '' }); Id = "$($d.PNPDeviceID)"; Reinstall = $safe }) }
        else { [void]$out.Add(@{ Name = $name; Reason = $r }) }
    }
    return $out.ToArray()
}
# Réinstalle le pilote des périphériques en panne qui peuvent l'être sans risque : retiré puis Windows le retrouve tout seul
function Repair-ProblemDevices {
    Step "Réinstallation des périphériques en panne"
    $pnp = Join-Path $env:SystemRoot 'System32\pnputil.exe'
    foreach ($d in @(Get-ProblemDevices -Full | Where-Object { $_.Reinstall })) {
        $ec = Invoke-Native $pnp @('/remove-device', $d.Id) -Quiet
        Log ("   {0} {1} : {2}" -f $(if ($ec -eq 0) { '✔' } else { '•' }), $d.Name, $(if ($ec -eq 0) { 'pilote retiré' } else { "retrait refusé par Windows (code $ec)" }))
    }
    $null = Invoke-Native $pnp @('/scan-devices') -Quiet
    Start-Sleep -Seconds 3
    $left = @(Get-ProblemDevices)
    if ($left.Count) {
        Add-TaskError -Title ("{0} périphérique(s) encore en panne" -f $left.Count) -Cause (($left | ForEach-Object { "$($_.Name) ($($_.Reason))" }) -join ', ') `
            -Effect "Windows n'a pas trouvé de pilote qui marche pour eux." `
            -Steps @("Redémarre le PC : certains pilotes ne repartent qu'au redémarrage.", "Sinon : prends le pilote sur le site du fabricant de ton PC, de ta carte mère ou de l'appareil.")
    } else { Log "✅ Tous les périphériques ont de nouveau un pilote qui fonctionne." }
}

function Get-DriverReport {
    Step "Vérification des pilotes (drivers)"
    $sync.DriverScan = $null
    $rep = @{ Gpus = @(); Wu = @(); Devices = @(); WuError = '' }
    Log "   • Cartes graphiques : comparaison avec la dernière version officielle…"
    $rep.Gpus = @(Get-GpuDrivers)
    foreach ($g in $rep.Gpus) {
        $st = switch ($g.Status) { 'ok' { 'à jour' } 'old' { if ($g.Latest) { "pas à jour ($($g.Latest.Version) disponible)" } else { 'ancien' } } 'none' { 'aucun pilote' } default { 'non vérifiable' } }
        Log ("     {0} : pilote {1} → {2}" -f $g.Name, $g.Version, $st)
    }
    $rep.Devices = @(Get-ProblemDevices)
    if ($rep.Devices.Count) { Log ("   • {0} périphérique(s) avec un problème de pilote" -f $rep.Devices.Count) }
    Log "   • Recherche des pilotes proposés par Windows Update (jusqu'à 2 minutes)…"
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $session.ClientApplicationID = 'AEROX PC Care'
        $res = $session.CreateUpdateSearcher().Search("IsInstalled=0 and IsHidden=0 and Type='Driver'")
        $wu = New-Object System.Collections.ArrayList
        foreach ($u in $res.Updates) {
            $cls = "$($u.DriverClass)"
            $date = $null; try { $date = [datetime]$u.DriverVerDate } catch {}
            [void]$wu.Add(@{ Id = "$($u.Identity.UpdateID)"; Title = "$($u.Title)"; Class = $cls; Maker = "$($u.DriverManufacturer)"; Date = $date; Size = [double]$u.MaxDownloadSize; Display = ($cls -match '(?i)^display$') })
        }
        # Déjà installés une fois par AEROX mais reproposés par Windows : le réinstaller ne change rien
        $done = @{}
        try { foreach ($l in @(Get-Content -LiteralPath (Join-Path $AppInfo.LogDir 'pilotes_installes.txt') -Encoding UTF8 -ErrorAction Stop)) { $p = $l.Split('|'); if ($p.Count -ge 2) { $done[$p[0]] = $p[1] } } } catch {}
        foreach ($w in $wu) { if ($done.ContainsKey($w.Id)) { $w.Repeat = $true; $w.DoneAt = $done[$w.Id] } }
        $rep.Wu = $wu.ToArray()
        Log ("     {0} pilote(s) proposé(s)" -f $rep.Wu.Count)
    } catch {
        $rep.WuError = (Get-ErrorCode $_)
        Log ("     ⚠ Windows Update n'a pas répondu ({0})" -f $rep.WuError)
    }
    $sync.DriverScan = $rep
}

function Install-DriverUpdates([string[]]$Ids) {
    if (-not $Ids -or -not $Ids.Count) { return }
    New-RestorePoint
    Step ("Installation de {0} pilote(s) (n'éteins pas le PC)" -f $Ids.Count)
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $session.ClientApplicationID = 'AEROX PC Care'
        $res = $session.CreateUpdateSearcher().Search("IsInstalled=0 and IsHidden=0 and Type='Driver'")
        $coll = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($u in $res.Updates) {
            if ($Ids -notcontains "$($u.Identity.UpdateID)") { continue }
            if ("$($u.DriverClass)" -match '(?i)^display$') { continue }
            if (-not $u.EulaAccepted) { try { $u.AcceptEula() } catch {} }
            [void]$coll.Add($u); Log ("   • {0}" -f $u.Title)
        }
        if ($coll.Count -eq 0) { Log "✅ Rien à installer : ces pilotes sont déjà en place."; return }
        Log "   Téléchargement…"
        $dl = $session.CreateUpdateDownloader(); $dl.Updates = $coll; [void]$dl.Download()
        Log "   Installation…"
        $inst = $session.CreateUpdateInstaller(); $inst.Updates = $coll
        $r = $inst.Install()
    } catch {
        $code = (Get-ErrorCode $_)
        $wi = Get-WuErrorInfo $code
        Add-TaskError -Title "L'installation des pilotes a échoué" -Code $code -Cause $wi.Cause -Effect "Les pilotes ne sont pas installés. Ton PC reste comme avant." `
            -FixLabel "Débloquer Windows Update" -FixAction 'Reset-WindowsUpdate' -Confirm "Windows Update va être remis à zéro. Un redémarrage sera conseillé ensuite."
        return
    }
    $ok = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $coll.Count; $i++) {
        $t = $coll.Item($i).Title; $rc = $r.GetUpdateResult($i)
        if ($rc.ResultCode -eq 4 -or $rc.ResultCode -eq 5) {
            Add-TaskError -Title "Le pilote « $t » ne s'est pas installé" -Code ('0x{0:X8}' -f $rc.HResult) -Cause "Windows a refusé ce pilote (souvent : un pilote plus adapté est déjà en place, ou il faut redémarrer avant)." `
                -Effect "Ce pilote reste dans son ancienne version. Le reste n'est pas touché." -Steps @("Redémarre le PC puis relance la vérification des pilotes.", "Si ça recommence, prends ce pilote sur le site du fabricant de ton PC ou de ta carte mère.")
        } else {
            [void]$ok.Add($t); Log ("   ✔ Installé : {0}" -f $t)
            try { [IO.File]::AppendAllText((Join-Path $AppInfo.LogDir 'pilotes_installes.txt'), ("{0}|{1}|{2}`r`n" -f $coll.Item($i).Identity.UpdateID, (Get-Date).ToString('s'), ($t -replace '\|', '/')), (New-Object System.Text.UTF8Encoding($false))) } catch {}
        }
    }
    if ($ok.Count) {
        Add-Change -Kind 'info' -Title ("{0} pilote(s) installé(s) depuis Windows Update" -f $ok.Count) -Detail ((@($ok) -join ' · ') + ". Pour revenir en arrière : point de restauration créé juste avant (bouton « Restauration du système »).")
        Log ("✅ {0} pilote(s) installé(s)." -f $ok.Count)
    }
    if ($r.RebootRequired) { Log "⚠ Un redémarrage est nécessaire pour terminer l'installation."; $sync.NeedReboot = $true }
}

function Open-WindowsUpdate { Open-WinUri 'ms-settings:windowsupdate'; Log "   ✔ Windows Update ouvert" }

# ---------------------------------------------------------------- SÉCURITÉ (réparations)
function Enable-RealtimeProtection {
    Step "Réactivation de la protection en temps réel"
    try { Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop } catch {}
    Start-Sleep -Seconds 2
    $on = $false; try { $on = (Get-MpComputerStatus -ErrorAction Stop).RealTimeProtectionEnabled } catch {}
    if ($on) { Log "   ✔ Protection en temps réel réactivée" }
    else {
        Add-TaskError -Title "La protection en temps réel n'a pas pu être réactivée" -Cause "La « Protection contre les falsifications » de Windows empêche les logiciels de la modifier (c'est normal, c'est une sécurité)." `
            -Effect "Il faut la réactiver à la main, ça prend 10 secondes." -FixLabel "Ouvrir Sécurité Windows" -FixAction "Open-WinUri 'windowsdefender://threat'" `
            -Steps @("Dans Sécurité Windows > Protection contre les virus et menaces > Gérer les paramètres.", "Active « Protection en temps réel ».")
    }
}
function Update-DefenderSignatures {
    Step "Mise à jour de l'antivirus"
    try { Update-MpSignature -ErrorAction Stop; Log "   ✔ Antivirus à jour" }
    catch {
        Add-TaskError -Title "L'antivirus n'a pas pu se mettre à jour" -Cause "Pas d'accès à Internet, ou Windows Update est bloqué." -Effect "Les nouveaux virus ne sont pas reconnus." `
            -FixLabel "Débloquer Windows Update" -FixAction 'Reset-WindowsUpdate; Update-DefenderSignatures'
    }
}
function Enable-Firewall {
    Step "Réactivation du pare-feu Windows"
    try { Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled True -ErrorAction Stop; Log "   ✔ Pare-feu réactivé sur tous les réseaux" }
    catch { Add-TaskError -Title "Le pare-feu n'a pas pu être réactivé" -Cause $_.Exception.Message -FixLabel "Ouvrir les réglages du pare-feu" -FixAction "Open-WinUri 'windowsdefender://network'" }
}
function Enable-UAC {
    Step "Réactivation du contrôle de compte (UAC)"
    Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name EnableLUA -Value 1 -Type DWord
    Log "   ✔ UAC réactivé (effectif après redémarrage)"
    $sync.NeedReboot = $true
}

# ---------------------------------------------------------------- RÉPARATION
function Test-Internet {
    Step "Test de la connexion Internet"
    $n = Get-NetworkStatus
    if (-not $n.Route) {
        Add-TaskError -Title "Le PC n'est connecté à aucun réseau" -Cause "Aucun câble Ethernet branché et pas de Wi-Fi connecté (ou mode Avion activé)." `
            -Effect "Pas d'Internet." -Steps @("Vérifie le câble ou reconnecte-toi au Wi-Fi (icône en bas à droite).", "Vérifie que le mode Avion est désactivé.")
        return
    }
    if ($n.GwOk) { Log "   ✔ La box / le routeur répond ($($n.Gw))" } else { Log "   • La box ne répond pas au ping ($($n.Gw)), ce n'est pas forcément grave." }
    if ($n.Internet) { Log "   ✔ Internet fonctionne (ping moyen : $($n.Avg) ms)"; if ($n.Avg -gt 80) { Log "   ⚠ Ping élevé : ferme les téléchargements en cours, ou passe en câble Ethernet." } }
    if ($n.Dns) { Log "   ✔ Les sites sont bien trouvés (DNS OK)" }
    if ($n.Signal -ge 0) { Log "   • Signal Wi-Fi : $($n.Signal) %"; if ($n.Signal -lt 60) { Log "   ⚠ Wi-Fi faible : rapproche-toi de la box ou passe en câble Ethernet." } }
    if (-not $n.Internet -and -not $n.Dns) {
        Add-TaskError -Title "Pas d'accès à Internet" -Cause $(if ($n.GwOk) { "La box répond mais Internet ne passe pas : coupure chez ton fournisseur ou réglages réseau de Windows abîmés." } else { "La box ne répond pas : elle est éteinte, plantée, ou le PC n'est pas vraiment relié à elle." }) `
            -Effect "Pas d'Internet, pas de mises à jour." -FixLabel "Réparer la connexion" -FixAction 'Repair-Network' `
            -Confirm "Les réglages réseau de Windows vont être remis à zéro. La connexion se coupera quelques secondes et il faudra redémarrer le PC." `
            -Steps @("Redémarre la box : débranche-la 30 secondes puis rebranche-la.", "Si rien ne change, utilise « Réparer la connexion » puis redémarre le PC.", "Si ça ne marche toujours pas, appelle ton fournisseur d'accès.")
    } elseif (-not $n.Dns) {
        Add-TaskError -Title "Les sites Internet ne sont pas trouvés (DNS)" -Cause "Le service qui traduit les noms de sites ne répond plus, ou le cache DNS de Windows est abîmé." `
            -Effect "Les sites ne s'ouvrent pas alors que la connexion marche." -FixLabel "Réparer la connexion" -FixAction 'Repair-Network' -Confirm "Les réglages réseau de Windows vont être remis à zéro. Il faudra redémarrer le PC."
    }
}

function Repair-Network {
    Step "Réparation de la connexion Internet"
    $null = Invoke-Native 'ipconfig.exe' @('/flushdns')
    $null = Invoke-Native 'netsh.exe'   @('winsock', 'reset')
    # « int ip reset » remet toutes les cartes en automatique (DHCP) : une adresse IP fixe réglée à la main serait perdue
    $static = @()
    try { $static = @(Get-NetIPInterface -AddressFamily IPv4 -Dhcp Disabled -ConnectionState Connected -ErrorAction Stop | Where-Object { $_.InterfaceAlias -notmatch '(?i)loopback|vEthernet|VirtualBox|VMware' } | ForEach-Object { $_.InterfaceAlias }) } catch {}
    if ($static.Count) { Log ("   • Adresse IP fixe sur « {0} » : gardée (la remise à zéro TCP/IP est sautée)." -f ($static -join ', ')) }
    else { $null = Invoke-Native 'netsh.exe' @('int', 'ip', 'reset') }
    $null = Invoke-Native 'ipconfig.exe' @('/release')
    $null = Invoke-Native 'ipconfig.exe' @('/renew')
    Log "✅ Réseau réinitialisé. Redémarre le PC pour terminer la réparation."
    Add-Change -Kind 'info' -Title "Réglages réseau de Windows remis à zéro" -Detail "DNS, Winsock et TCP/IP réinitialisés. Les connexions Wi-Fi enregistrées sont gardées."
    $sync.NeedReboot = $true
}

function Repair-System {
    Step "Étape 1/2 : réparation de l'image Windows (DISM)"
    Log "   Ça peut être long et rester bloqué un moment sur un pourcentage, c'est normal."
    $ec = Invoke-Native 'dism.exe' @('/Online', '/Cleanup-Image', '/RestoreHealth')
    if ($ec -ne 0) {
        $code = '0x{0:X8}' -f $ec
        if ($code -match '(?i)0x800F081F|0x800F0906|0x800F0907|0x800F0950') {
            Add-TaskError -Title "DISM n'a pas trouvé les fichiers de réparation" -Code $code -Cause "Windows télécharge ces fichiers via Windows Update : soit Internet est coupé, soit Windows Update est bloqué." `
                -Effect "Les fichiers système abîmés ne peuvent pas être remplacés." -FixLabel "Débloquer Windows Update puis réessayer" -FixAction 'Reset-WindowsUpdate; Repair-System'
        } else {
            Add-TaskError -Title "La réparation de l'image Windows a échoué" -Code $code -Cause "Une mise à jour est peut-être en cours, ou un redémarrage est en attente." `
                -Effect "La vérification SFC va quand même être lancée." -FixLabel "Redémarrer puis réessayer" -FixAction 'Request-Reboot'
        }
    }
    Step "Étape 2/2 : vérification des fichiers système (SFC)"
    $sfcStart = Get-Date
    $null = Invoke-Native 'sfc.exe' @('/scannow') ([System.Text.Encoding]::Unicode)
    $out = ($script:NativeOutput -join "`n")
    # Résultat lu dans le journal technique de Windows (CBS.log), le même dans toutes les langues de Windows ;
    # le texte affiché par SFC (français / anglais) ne sert que si ce journal ne dit rien
    $cbs = Get-SfcResultFromCbs $sfcStart
    if ($cbs -eq 'unrepaired' -or (-not $cbs -and $out -match "(?i)unable to fix|n.a pas pu (en )?(réparer|corriger)|impossible de (réparer|corriger)")) {
        Add-TaskError -Title "Des fichiers système abîmés n'ont pas pu être réparés" -Cause "SFC a trouvé des fichiers corrompus mais n'a pas pu tous les remplacer." `
            -Effect "Des bugs ou plantages de Windows peuvent continuer." -FixLabel "Redémarrer puis relancer" -FixAction 'Request-Reboot' `
            -Steps @("Redémarre le PC.", "Relance « Réparer les fichiers de Windows ».", "Si l'erreur revient : Paramètres > Système > Récupération > « Résoudre les problèmes avec Windows Update » réinstalle Windows en gardant tes fichiers.")
    } elseif (-not $cbs -and $out -match "(?i)could not perform|n.a pas pu effectuer") {
        Add-TaskError -Title "La vérification SFC n'a pas pu se lancer" -Cause "Une réparation ou une mise à jour Windows est déjà en attente de redémarrage." -FixLabel "Redémarrer" -FixAction 'Request-Reboot'
    } elseif ($cbs -eq 'repaired' -or (-not $cbs -and $out -match "(?i)successfully repaired|les a réparés|a réparé")) {
        Log "✅ Des fichiers abîmés ont été trouvés et réparés. Redémarre le PC."
        $sync.NeedReboot = $true
    } elseif ($cbs -eq 'clean' -or $out -match "(?i)did not find any integrity|n.a trouvé aucune violation") { Log "✅ Réparation terminée : aucun fichier système abîmé." }
    else { Log "✅ Vérification terminée. (Windows n'a pas donné de résultat lisible : si les bugs continuent, relance-la après un redémarrage.)" }
}
# Résultat de SFC d'après CBS.log (lignes « [SR] » écrites depuis $Since) : 'unrepaired', 'repaired', 'clean' ou '' (rien lu)
function Get-SfcResultFromCbs([datetime]$Since, [string]$File = '') {
    $f = if ($File) { $File } else { Join-Path $env:SystemRoot 'Logs\CBS\CBS.log' }
    try {
        $fs = [IO.File]::Open($f, 'Open', 'Read', 'ReadWrite')
        try {
            if ($fs.Length -gt 30MB) { [void]$fs.Seek(-30MB, 'End') }
            $txt = (New-Object IO.StreamReader($fs)).ReadToEnd()
        } finally { $fs.Close() }
        $sr = @($txt -split "`r?`n" | Where-Object { $_ -match '\[SR\]' -and $_ -match '^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)' -and [datetime]::ParseExact($matches[1], 'yyyy-MM-dd HH:mm:ss', $null) -ge $Since.AddSeconds(-5) })
        if (-not $sr.Count) { return '' }
        if (@($sr | Where-Object { $_ -match '(?i)cannot repair' }).Count) { return 'unrepaired' }
        if (@($sr | Where-Object { $_ -match '(?i)repairing corrupted file|repaired file|repairing [1-9]\d* components' }).Count) { return 'repaired' }
        if (@($sr | Where-Object { $_ -match '(?i)verify complete|beginning verify and repair' }).Count) { return 'clean' }
    } catch {}
    return ''
}

function Test-Disk {
    Step "Vérification des disques"
    try {
        foreach ($pd in Get-PhysicalDisk -ErrorAction Stop) {
            if ($pd.HealthStatus -eq 'Healthy') { Log ("   ✔ {0} ({1}) : bonne santé" -f $pd.FriendlyName, $pd.MediaType) }
            else {
                Add-TaskError -Title "Le disque « $($pd.FriendlyName) » signale un problème" -Code "$($pd.HealthStatus)" -Cause "Le disque détecte lui-même des secteurs défectueux ou une usure importante." `
                    -Effect "Risque de perdre des fichiers." -Steps @("SAUVEGARDE tout de suite tes fichiers importants.", "Prévois de remplacer ce disque.")
            }
        }
    } catch {}
    # Outil officiel de Windows (Repair-Volume -Scan = chkdsk /scan, sans lancer de programme externe)
    $bad = $false; $code = ''
    try {
        Log "   Analyse du système de fichiers de $env:SystemDrive (1 à 5 minutes)..."
        $res = "$(Repair-Volume -DriveLetter $env:SystemDrive[0] -Scan -ErrorAction Stop)"
        Log "   Résultat de l'analyse : $res"
        $bad = ($res -notmatch '(?i)NoErrorsFound'); $code = "Repair-Volume $res"
    } catch {
        Log ("   • Analyse par Repair-Volume impossible ({0}), essai avec chkdsk" -f $_.Exception.Message)
        $ec = Invoke-Native 'chkdsk.exe' @($env:SystemDrive, '/scan')
        $bad = ($ec -ge 3 -or ($ec -eq 2 -and ($script:NativeOutput -join ' ') -match '(?i)/f|problems|problèmes')); $code = "chkdsk $ec"
    }
    if ($bad) {
        Add-TaskError -Title "Des erreurs ont été trouvées sur le disque $env:SystemDrive" -Code $code -Cause "Le système de fichiers a des incohérences, souvent après une coupure de courant ou un arrêt forcé." `
            -Effect "Des fichiers peuvent devenir illisibles et Windows peut buguer." -FixLabel "Réparer au prochain redémarrage" -FixAction 'Set-DiskRepairAtBoot'
    } else { Log "✅ Aucun problème trouvé sur le disque." }
}
function Set-DiskRepairAtBoot {
    Step "Programmation de la réparation du disque"
    $null = Invoke-Native 'fsutil.exe' @('dirty', 'set', $env:SystemDrive)
    Log "   ✔ La réparation se lancera au prochain démarrage (ça peut prendre quelques minutes, ne l'interromps pas)."
    $sync.NeedReboot = $true
}

function Reset-WindowsUpdate {
    Step "Déblocage de Windows Update"
    foreach ($s in 'wuauserv', 'bits', 'cryptsvc', 'msiserver') { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue }
    Log "   ✔ Services arrêtés"
    $failed = @()
    foreach ($d in @("$env:SystemRoot\SoftwareDistribution", "$env:SystemRoot\System32\catroot2")) {
        $old = "$d.old"
        if (Test-Path -LiteralPath $old) { $null = Remove-ItemSafe (Get-Item -LiteralPath $old -Force) }
        try { Rename-Item -LiteralPath $d -NewName (Split-Path $old -Leaf) -ErrorAction Stop; Log ("   ✔ Réinitialisé : {0}" -f $d) }
        catch { $failed += $d }
    }
    foreach ($s in 'cryptsvc', 'bits', 'wuauserv') { Start-Service -Name $s -ErrorAction SilentlyContinue }
    if ($failed) {
        Add-TaskError -Title "Windows Update n'a pas pu être complètement remis à zéro" -Cause ("Un dossier est en cours d'utilisation : " + ($failed -join ', ')) `
            -Effect "Le blocage peut continuer." -FixLabel "Redémarrer puis réessayer" -FixAction 'Request-Reboot' -Steps @("Redémarre le PC.", "Relance « Débloquer Windows Update ».")
    } else { Log "✅ Windows Update remis à zéro." }
}

function New-RestorePoint {
    Step "Création d'un point de restauration (sécurité)"
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
        New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' -Name 'SystemRestorePointCreationFrequency' -Value 0 -PropertyType DWord -Force | Out-Null
        Checkpoint-Computer -Description "AEROX PC Care $(Get-Date -Format 'dd/MM/yyyy HH:mm')" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Log "   ✔ Point de restauration créé : tu pourras revenir en arrière si besoin."
        Add-Change -Kind 'info' -Title "Point de restauration créé" -Detail "Permet de remettre Windows dans cet état (bouton « Restauration du système » ci-dessous)."
    } catch {
        $m = $_.Exception.Message
        Add-TaskError -Title "Le point de restauration n'a pas pu être créé" `
            -Cause $(if ($m -match '(?i)désactiv|disabled|policy|stratégie|0x80042306') { "La protection du système est désactivée ou bloquée par un réglage de Windows." } else { "Windows a refusé la création : $m" }) `
            -Effect "Tu ne pourras pas revenir en arrière avec ce point. Le reste continue normalement." -FixLabel "Réessayer" -FixAction 'New-RestorePoint' `
            -Steps @("Tape « Créer un point de restauration » dans Démarrer.", "Sélectionne le disque C:, clique sur « Configurer » puis « Activer la protection du système ».", "Reviens ici et réessaie.")
    }
}

# ---------------------------------------------------------------- PERFORMANCES

function Set-HighPerformance {
    Step "Mode d'alimentation performances maximales"
    $prev = Get-PowerStatus
    $hp = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    $list = (powercfg.exe /list) | Out-String
    $done = $false
    if ($list -match $hp) { powercfg.exe /setactive $hp | Out-Null; $done = ($LASTEXITCODE -eq 0) }
    else {
        $dup = (powercfg.exe -duplicatescheme $hp 2>$null) | Out-String
        if ($dup -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') { powercfg.exe /setactive $matches[1] | Out-Null; $done = ($LASTEXITCODE -eq 0) }
    }
    if ($done) {
        Log "   ✔ Mode « Performances élevées » activé."
        if ($prev.Guid -and -not $prev.Perf) { Add-Change -Title "Mode d'alimentation : performances maximales" -Detail ("Avant : {0}" -f $prev.Name) -Undo ("Set-PowerScheme {0} {1}" -f (ConvertTo-PsLiteral $prev.Guid), (ConvertTo-PsLiteral $prev.Name)) }
    }
    else {
        Log "   • Ce mode n'existe pas sur ce PC (normal sur beaucoup de portables récents)."
        Log "   → J'ouvre les réglages : dans « Mode d'alimentation », choisis « Meilleures performances »."
        Open-WinUri 'ms-settings:powersleep'
    }
    if (Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue) { Log "   ⚠ C'est un portable : ce mode vide la batterie plus vite. Idéal quand tu es branché." }
}

function Open-VisualEffects {
    Step "Effets visuels"
    Log "   → Coche « Ajuster afin d'obtenir les meilleures performances », puis recoche « Lisser les polices écran » et clique sur OK."
    $exe = Join-Path $env:SystemRoot 'System32\SystemPropertiesPerformance.exe'
    if ((Get-SessionUser).Other -and (Start-AsSessionUser $exe)) { return }
    Start-Process $exe
}


function Start-QuickOptimize {
    New-RestorePoint
    Clear-TempFiles
    Clear-BrowserCache
    Step "Vidage du cache DNS"
    $null = Invoke-Native 'ipconfig.exe' @('/flushdns')
    Update-Apps
    Step "Résumé de l'optimisation"
    Log ("   ✔ Espace libéré au total : {0}" -f (Format-Size $script:TotalFreed))
    Log "   → Lance aussi le Diagnostic pour voir ce qui reste à régler."
}

# ---------------------------------------------------------------- Mise à jour d'AEROX PC Care (GitHub)
# Adresse du relais des rapports de bug (fichier relais.txt du dépôt : modifiable sans nouvelle version)
function Find-BugRelay {
    try {
        if (-not $AppInfo.Repo) { return }
        $u = "$((Invoke-WebRequest -Uri ("https://raw.githubusercontent.com/{0}/main/relais.txt" -f $AppInfo.Repo) -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop).Content)".Trim()
        if ($u -match '^https://[^\s]+$') { $sync.BugRelay = $u }
    } catch {}
}
# Lien d'invitation du serveur Discord de la communauté (fichier discord.txt du dépôt : modifiable sans nouvelle version).
# Seule une vraie invitation Discord est acceptée.
function Test-DiscordInvite([string]$Url) { return ($Url -cmatch '^https://(discord\.gg|discord\.com/invite)/[A-Za-z0-9-]{2,32}\z') }
function Find-DiscordLink {
    try {
        if (-not $AppInfo.Repo) { return }
        $u = "$((Invoke-WebRequest -Uri ("https://raw.githubusercontent.com/{0}/main/discord.txt" -f $AppInfo.Repo) -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop).Content)".Trim()
        if (Test-DiscordInvite $u) { $sync.DiscordUrl = $u }
    } catch {}
}

function Find-AppUpdate {
    $sync.UpdateDone = $false
    try {
        if (-not $AppInfo.Repo) { return }
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $h = @{ 'User-Agent' = 'AeroxPCCare' }
        if ($AppInfo.Beta) {
            # Canal test : la version la plus récente, versions de test (pré-versions) comprises
            # (pas de @() autour : en PowerShell 5.1 la liste JSON arrive en un seul objet et serait emballée)
            $all = Invoke-RestMethod -Uri ("https://api.github.com/repos/{0}/releases?per_page=15" -f $AppInfo.Repo) -Headers $h -TimeoutSec 10 -ErrorAction Stop
            $r = $all | Where-Object { -not $_.draft -and ($_.tag_name -replace '^[vV]', '') -as [version] } | Sort-Object { [version]($_.tag_name -replace '^[vV]', '') } -Descending | Select-Object -First 1
            if (-not $r) { return }
        } else {
            $r = Invoke-RestMethod -Uri ("https://api.github.com/repos/{0}/releases/latest" -f $AppInfo.Repo) -Headers $h -TimeoutSec 10 -ErrorAction Stop
        }
        $v = ($r.tag_name -replace '^[vV]', '')
        if ([version]$v -gt [version]$AppInfo.Version) {
            $asset = @($r.assets | Where-Object { $_.name -match '(?i)setup.*\.exe$' }) | Select-Object -First 1
            $url = $r.html_url
            if ($AppInfo.Portable) {
                # Version portable : pas d'installateur (il installerait AEROX sur le PC), on propose le zip portable
                $zip = @($r.assets | Where-Object { $_.name -match '(?i)portable.*\.zip$' }) | Select-Object -First 1
                if ($zip) { $url = [string]$zip.browser_download_url }
                $asset = $null
            }
            $sync.UpdateInfo = @{ Version = $v; Url = $url; Notes = "$($r.body)"; Test = [bool]$r.prerelease
                                  Setup = $(if ($asset) { [string]$asset.browser_download_url } else { '' })
                                  Digest = $(if ($asset -and $asset.digest) { [string]$asset.digest } else { '' }) }
        }
    } catch {} finally { $sync.UpdateDone = $true }
}

# Télécharge l'installateur officiel de la nouvelle version ; l'interface le lance ensuite (mode mise à jour)
function Install-AppUpdate {
    $u = $sync.UpdateInfo
    $sync.UpdateReady = $null
    if (-not $u -or -not $u.Setup) {
        Add-TaskError -Title "Aucune mise à jour à installer" -Cause "La nouvelle version n'a pas d'installateur à télécharger." -FixLabel "Ouvrir la page de téléchargement" -FixAction ("[void](Open-Url {0})" -f (ConvertTo-PsLiteral "$($u.Url)"))
        return
    }
    Step ("Téléchargement d'AEROX PC Care {0} depuis GitHub" -f $u.Version)
    try {
        $sha = if ("$($u.Digest)" -match '^sha256:([0-9a-fA-F]{64})$') { $Matches[1] } else { '' }
        # Sans empreinte publiée, impossible de vérifier le fichier : il n'est pas installé (relecture complète 2.3.0)
        if (-not $sha) { throw "GitHub ne donne pas l'empreinte de sécurité de cette version : elle ne peut pas être vérifiée, donc pas installée automatiquement. Télécharge-la à la main sur la page du logiciel." }
        # Dossier du logiciel (Program Files, modifiable seulement en administrateur) : le fichier ne peut pas être échangé
        $dest = Join-Path (Get-SecureDir 'maj') ("AeroxPCCare_Setup_{0}.exe" -f $u.Version)
        [AeroxUpdate]::Download($u.Setup, $dest, $sha)
        Log ("   ✔ Installateur téléchargé{0}." -f $(if ($sha) { ' et vérifié (empreinte SHA-256 identique à celle publiée)' } else { '' }))
        $sync.UpdateReady = @{ Path = $dest; Sha = $sha }
    } catch {
        $m = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message }
        Add-TaskError -Title "La mise à jour n'a pas pu être téléchargée" -Cause $m -Effect "Tu gardes la version actuelle, rien n'a été modifié." `
            -FixLabel "Réessayer" -FixAction 'Install-AppUpdate' -Steps @("Vérifie ta connexion Internet.", "Si ton antivirus a bloqué le téléchargement, autorise-le puis réessaie.", "Sinon, télécharge AeroxPCCare_Setup.exe à la main sur la page GitHub du logiciel.")
    }
}
# =====================================================================
#  SÉCURITÉ : analyse anti-intrusion approfondie (lecture seule) et correctifs choisis
# =====================================================================
# Ce qu'AEROX ne fait JAMAIS ici (pour ne jamais ressembler à un virus) : lire les mots de passe ou les cookies des
# navigateurs, lire la mémoire d'un programme, toucher à LSASS, arrêter un antivirus, ajouter une exclusion, lancer une
# commande encodée ou du code téléchargé. Seulement les outils officiels de Windows, et le registre en lecture.

# ---------------------------------------------------------------- Règles pures (testées sans Windows)
# Dossiers qui rendent un programme sans signature suspect, et leur nom en clair
$script:SecZoneLabels = @{ temp = 'un dossier temporaire'; downloads = 'Téléchargements'; public = 'le dossier Public'; appdata = 'AppData (dossier caché de ton compte)'
                           programdata = 'ProgramData'; rootdir = 'un dossier à la racine du disque' }
# Type de dossier d'un fichier : temp, downloads, public, appdata, programdata, rootdir (dossier à la racine du disque de
# Windows), windows, programfiles, user (autre dossier d'un compte), other, ou '' (chemin incomplet)
function Get-PathZone([string]$Path, [string[]]$Downloads = @(), [string]$SysDrive = 'C:') {
    $p = ("$Path".Trim().Trim('"')) -replace '/', '\'
    if ($p -match '^\\\\\?\\') { $p = $p.Substring(4) }
    if ($p -notmatch '^[A-Za-z]:\\') { return '' }
    $l = $p.ToLowerInvariant()
    foreach ($d in @($Downloads | Where-Object { $_ })) { if ($l.StartsWith($d.TrimEnd('\').ToLowerInvariant() + '\')) { return 'downloads' } }
    if ($l -match '^[a-z]:\\users\\[^\\]+\\appdata\\local\\temp\\' -or $l -match '^[a-z]:\\windows\\temp\\' -or $l -match '^[a-z]:\\(temp|tmp)\\' -or $l -match '^[a-z]:\\\$recycle\.bin\\') { return 'temp' }
    if ($l -match '^[a-z]:\\users\\[^\\]+\\(downloads|t[ée]l[ée]chargements)\\') { return 'downloads' }
    if ($l -match '^[a-z]:\\users\\public\\') { return 'public' }
    if ($l -match '^[a-z]:\\users\\[^\\]+\\appdata\\') { return 'appdata' }
    if ($l -match '^[a-z]:\\programdata\\') { return 'programdata' }
    if ($l -match '^[a-z]:\\windows\\') { return 'windows' }
    if ($l -match '^[a-z]:\\program files( \(x86\))?\\') { return 'programfiles' }
    if ($l -match '^[a-z]:\\users\\') { return 'user' }
    $sd = $SysDrive.TrimEnd('\').ToLowerInvariant()
    if ($l.StartsWith($sd + '\') -and ($l -match '^[a-z]:\\[^\\]+$' -or $l -match '^[a-z]:\\[^\\]+\\[^\\]+$')) { return 'rootdir' }
    return 'other'
}

# Ligne de commande à risque. Level : 'strong' (technique de virus), 'weak' (à elle seule, rien d'anormal) ou ''.
function Get-CommandRisk([string]$Cmd) {
    $c = "$Cmd"; $strong = New-Object System.Collections.ArrayList; $weak = New-Object System.Collections.ArrayList
    if ($c.Trim()) {
        $ps = $c -match '(?i)(^|[\\/"''\s])(powershell|pwsh)(\.exe)?(["''\s]|$)'
        if ($ps) {
            if ($c -match '(?i)(^|\s)[-/](e|ec|en|enc|enco|encod|encode|encoded|encodedc|encodedco|encodedcom|encodedcomm|encodedcomma|encodedcomman|encodedcommand)\s+["'']?[A-Za-z0-9+/]{20,}={0,2}') { [void]$strong.Add("commande PowerShell cachée (encodée)") }
            if ($c -match '(?i)frombase64string') { [void]$strong.Add("décode du code caché") }
            if ($c -match '(?i)(^|[^\w-])(iex|invoke-expression)([^\w-]|$)') { [void]$strong.Add("exécute du code caché ou reçu d'Internet (IEX)") }
            if ($c -match '(?i)downloadstring|downloadfile|downloaddata|net\.webclient|start-bitstransfer') { [void]$strong.Add("télécharge du code ou un fichier depuis Internet") }
            elseif ($c -match '(?i)invoke-webrequest|invoke-restmethod|(^|[^\w-])(iwr|irm|wget|curl)([^\w-]|$)') { [void]$weak.Add("télécharge depuis Internet") }
            if ($c -match '(?i)(^|\s)[-/]w(i|in|ind|indo|indow|indows|indowst|indowsty|indowstyl|indowstyle)?\s+["'']?(h|hi|hid|hidd|hidde|hidden|1)(["''\s]|$)') { [void]$weak.Add("fenêtre cachée") }
        }
        if ($c -match '(?i)certutil(\.exe)?["'']?\s.*[-/](urlcache|verifyctl|decode|decodehex)(\s|$)') { [void]$strong.Add("détourne certutil pour télécharger ou décoder un fichier") }
        if ($c -match '(?i)bitsadmin(\.exe)?["'']?\s.*/(transfer|addfile)(\s|$)') { [void]$strong.Add("détourne bitsadmin pour télécharger un fichier") }
        if ($c -match '(?i)mshta(\.exe)?["'']?\s+["'']?(https?:|javascript:|vbscript:|about:)') { [void]$strong.Add("ouvre un script depuis Internet (mshta)") }
        if ($c -match '(?i)regsvr32(\.exe)?["'']?\s.*[-/]i:\s*["'']?https?:' -or $c -match '(?i)regsvr32(\.exe)?["'']?\s.*scrobj\.dll') { [void]$strong.Add("charge un script depuis Internet (regsvr32)") }
        if ($c -match '(?i)rundll32(\.exe)?["'']?\s.*(javascript:|vbscript:|mshtml,\s*runhtmlapplication)') { [void]$strong.Add("lance un script caché par rundll32") }
    }
    $lv = if ($strong.Count) { 'strong' } elseif ($weak.Count) { 'weak' } else { '' }
    return @{ Level = $lv; Reasons = @($strong) + @($weak) }
}

# Distance d'édition (une lettre ajoutée, retirée, changée ou deux lettres inversées = 1)
function Get-EditDistance([string]$A, [string]$B) {
    $n = $A.Length; $m = $B.Length
    if (-not $n) { return $m }; if (-not $m) { return $n }
    # Tableau de tableaux (Windows PowerShell 5.1 n'accepte pas « $d[$i, $j] » dans les arguments d'une méthode)
    $d = New-Object 'System.Collections.Generic.List[int[]]'
    for ($i = 0; $i -le $n; $i++) { $row = New-Object 'int[]' ($m + 1); $row[0] = $i; $d.Add($row) }
    for ($j = 0; $j -le $m; $j++) { $d[0][$j] = $j }
    for ($i = 1; $i -le $n; $i++) {
        $cur = $d[$i]; $up = $d[$i - 1]
        for ($j = 1; $j -le $m; $j++) {
            $cost = 1; if ($A[$i - 1] -eq $B[$j - 1]) { $cost = 0 }
            $del = $up[$j] + 1; $ins = $cur[$j - 1] + 1; $sub = $up[$j - 1] + $cost
            $v = $del; if ($ins -lt $v) { $v = $ins }; if ($sub -lt $v) { $v = $sub }
            if ($i -gt 1 -and $j -gt 1 -and $A[$i - 1] -eq $B[$j - 2] -and $A[$i - 2] -eq $B[$j - 1]) { $tr = $d[$i - 2][$j - 2] + 1; if ($tr -lt $v) { $v = $tr } }
            $cur[$j] = $v
        }
    }
    return $d[$n][$m]
}
# Programmes de Windows dont les virus prennent le nom (ils ne sont QUE dans C:\Windows, System32 ou SysWOW64)
$script:SysNames = @('svchost', 'lsass', 'csrss', 'smss', 'wininit', 'winlogon', 'services', 'spoolsv', 'taskhostw', 'dwm', 'conhost', 'rundll32', 'dllhost', 'sihost', 'ctfmon', 'fontdrvhost', 'explorer', 'audiodg', 'runtimebroker', 'searchindexer', 'userinit', 'wuauclt', 'lsm')
$script:SysLookalikes = @('svchost', 'lsass', 'csrss', 'wininit', 'winlogon', 'services', 'spoolsv', 'taskhostw', 'conhost', 'rundll32', 'dllhost', 'explorer', 'userinit')
$script:SysLookalikeOk = @('taskhost', 'taskhostex', 'service', 'servicehost', 'svhost64')
# '' (rien), 'exact' (nom d'un programme de Windows, hors de son dossier) ou 'like:<nom imité>' (à une lettre près)
function Test-Masquerade([string]$Name, [string]$Path, [string]$WinDir = 'C:\Windows') {
    $n = ("$Name".Trim() -replace '^.*\\', '' -replace '(?i)\.exe$', '').ToLowerInvariant()
    if (-not $n) { return '' }
    if ($script:SysNames -contains $n) {
        if (-not $Path) { return '' }
        $dir = ("$Path" -replace '\\[^\\]*$', '').TrimEnd('\').ToLowerInvariant()
        $w = $WinDir.TrimEnd('\').ToLowerInvariant()
        if ($dir -in @($w, "$w\system32", "$w\syswow64")) { return '' }
        return 'exact'
    }
    if ($n.Length -lt 4 -or $script:SysLookalikeOk -contains $n) { return '' }
    foreach ($s in $script:SysLookalikes) { if ((Get-EditDistance $n $s) -eq 1) { return "like:$s" } }
    return ''
}

# Signes de cachette d'un programme SANS signature rangé dans AppData, ProgramData ou un dossier temporaire (sinon '') :
# nom terminé par une suite aléatoire (« NetHost1dcc90 », « 00138d5f2 »), dossier camouflé par un code « {20D04FE0-…} »
# (il s'affiche comme « Ce PC »), dossier qui imite Windows (« AppData\Local\Windows », « ProgramData\Windows\Config »),
# ou nom d'un grand éditeur (« AdobeInputHost », « MicrosoftStorageWorker ») sans sa signature. Vu sur un vrai PC infecté (23/10/2026).
function Get-SuspiciousPlacement([string]$Path, [string]$Name = '') {
    $p = ("$Path".Trim().Trim('"')) -replace '/', '\'
    if (-not $p) { return '' }
    $file = ($p -split '\\')[-1]; $base = $file -replace '\.[^.]+$', ''
    if ($p -match '\.\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}(\\|$)') { return "rangé dans un dossier camouflé (il s'affiche comme « Ce PC » et ne s'ouvre pas)" }
    if ($p -match '(?i)^[a-z]:\\(users\\[^\\]+\\appdata\\(local|roaming|locallow)|programdata)\\(windows|system32|syswow64|common\\common)\\') { return "rangé dans un dossier qui imite celui de Windows" }
    if ($base -cmatch '(?i)^(?=.*\d)[0-9a-f]{6,}$' -or ($base -match '(?i)[a-z][0-9a-f]{5,}$' -and $Matches[0].Substring(1) -match '\d')) { return "nom terminé par une suite de caractères au hasard, typique des virus" }
    foreach ($n in @($base, $Name)) { if ("$n" -match '(?i)^(microsoft|windows|adobe|google|intel|nvidia|realtek|onedrive|steam|discord)') { return ("porte le nom de « {0} » sans sa signature" -f $matches[1]) } }
    return ''
}

# Exclusion de l'antivirus : 'crit' (dangereuse), 'warn' (dossier de ton compte), 'info' (à vérifier) ou '' (rien)
$script:ExclRiskExt = @('exe', 'dll', 'ps1', 'bat', 'cmd', 'js', 'jse', 'vbs', 'vbe', 'wsf', 'scr', 'hta', 'com', 'pif', 'msi', 'lnk', 'cpl')
$script:ExclRiskProc = @('powershell', 'pwsh', 'cmd', 'wscript', 'cscript', 'mshta', 'rundll32', 'regsvr32', 'svchost', 'explorer', 'msiexec', 'conhost', 'dllhost', 'certutil', 'bitsadmin', '*')
function Get-ExclusionRisk([string]$Value, [string]$Kind) {
    $v = "$Value".Trim().Trim('"')
    if (-not $v -or $v -match '^N/A') { return '' }
    if ($Kind -eq 'ext') { if ($script:ExclRiskExt -contains ($v -replace '^\*?\.', '').ToLowerInvariant()) { return 'crit' }; return 'info' }
    if ($Kind -eq 'process') {
        if ($script:ExclRiskProc -contains (($v -replace '^.*\\', '') -replace '(?i)\.exe$', '').ToLowerInvariant()) { return 'crit' }
        if ($v -match '\\') { $z = Get-PathZone $v; if ($z -in 'temp', 'downloads', 'public') { return 'crit' }; if ($z -eq 'appdata') { return 'warn' } }
        return 'info'
    }
    # Chemin (variables de Windows remplacées par un compte quelconque « x »)
    $l = $v.ToLowerInvariant() -replace '/', '\'
    $map = [ordered]@{ '%userprofile%' = 'c:\users\x'; '%homepath%' = '\users\x'; '%appdata%' = 'c:\users\x\appdata\roaming'; '%localappdata%' = 'c:\users\x\appdata\local'
                       '%temp%' = 'c:\users\x\appdata\local\temp'; '%tmp%' = 'c:\users\x\appdata\local\temp'; '%public%' = 'c:\users\public'; '%programdata%' = 'c:\programdata'
                       '%allusersprofile%' = 'c:\programdata'; '%systemroot%' = 'c:\windows'; '%windir%' = 'c:\windows'; '%systemdrive%' = 'c:'; '%programfiles%' = 'c:\program files' }
    foreach ($k in $map.Keys) { $l = $l.Replace($k, $map[$k]) }
    if ($l -match '^\\users\\') { $l = 'c:' + $l }
    $l = $l.TrimEnd('\')
    # Extension entière exclue par un chemin à joker (« C:\*.exe », « *.ps1 »)
    if ($l -match '\*\.([a-z0-9]+)$' -and $script:ExclRiskExt -contains $matches[1]) { return 'crit' }
    $l = ($l -replace '\\\*(\.\*)?$', '').TrimEnd('\')
    if ($l -in @('*', '') -or $l -match '^[a-z]:$' -or $l -match '^[a-z]:\\\*$') { return 'crit' }
    if ($l -match '^[a-z]:\\(users|users\\[^\\]+)$') { return 'crit' }
    if ($l -match '^[a-z]:\\users\\[^\\]+\\appdata\\local\\temp(\\|$)' -or $l -match '^[a-z]:\\windows\\temp(\\|$)' -or $l -match '^[a-z]:\\(temp|tmp)(\\|$)' ) { return 'crit' }
    if ($l -match '^[a-z]:\\users\\[^\\]+\\(downloads|t[ée]l[ée]chargements)(\\|$)') { return 'crit' }
    if ($l -match '^[a-z]:\\users\\(?!public\\)[^\\]+\\(desktop|bureau|documents)$') { return 'crit' }
    if ($l -match '^[a-z]:\\users\\[^\\]+\\appdata(\\(roaming|local|locallow))?$') { return 'crit' }
    if ($l -match '^[a-z]:\\programdata$' -or $l -match '^[a-z]:\\windows(\\(system32|syswow64))?$' -or $l -match '^[a-z]:\\program files( \(x86\))?$') { return 'crit' }
    if ($l -match '^[a-z]:\\users\\[^\\]+\\appdata\\' -or $l -match '^[a-z]:\\users\\public\\') { return 'warn' }
    return 'info'
}

# Logiciel de prise en main à distance (Name, Kind = 'remote') ou cheval de Troie connu (Kind = 'rat'), sinon $null
$script:RemoteTools = @(
    @('(?i)\bany ?desk\b', 'AnyDesk'), @('(?i)team ?viewer', 'TeamViewer'), @('(?i)\brust ?desk\b', 'RustDesk'), @('(?i)ultra ?viewer', 'UltraViewer'),
    @('(?i)screen ?connect|connectwise ?control', 'ScreenConnect'), @('(?i)splashtop', 'Splashtop'), @('(?i)\batera ?agent\b|\batera networks\b', 'Atera'),
    @('(?i)netsupport', 'NetSupport'), @('(?i)\b(tight|ultra|real|tiger) ?vnc\b|\bwinvnc\b|\btvnserver\b|\bvnc ?server\b', 'VNC'),
    @('(?i)\bradmin\b(?! ?vpn)|\brserver3\b', 'Radmin'), @('(?i)\bngrok\b', 'ngrok'), @('(?i)\bremoting_host\b|chrome remote desktop', 'Bureau à distance Chrome'),
    @('(?i)\blogmein\b', 'LogMeIn'), @('(?i)\bsupremo\b', 'Supremo'), @('(?i)\bdwagent\b|\bdwservice\b', 'DWService'), @('(?i)\bmeshagent\b|\bmeshcentral\b', 'MeshCentral'),
    @('(?i)\bsimplehelp\b', 'SimpleHelp')
)
$script:RatNames = '(?i)(?<![a-z0-9])(remcos|asyncrat|quasar ?rat|njrat|darkcomet|nanocore|dcrat|xworm|venom ?rat|avemaria|warzone ?rat|netwire|bitrat)(?![a-z0-9])'
function Get-RemoteToolName([string]$Text) {
    $t = "$Text"
    if (-not $t.Trim()) { return $null }
    if ($t -match $script:RatNames) { return @{ Name = $matches[1]; Kind = 'rat' } }
    foreach ($r in $script:RemoteTools) { if ($t -match $r[0]) { return @{ Name = $r[1]; Kind = 'remote' } } }
    return $null
}

# Nom de fichier téléchargé à risque : 'rlo' (caractère qui inverse le nom), 'double' (« photo.jpg.exe »), 'appat' (cheat, crack…)
$script:RiskyDlExt = '(?i)\.(exe|scr|com|bat|cmd|msi|lnk|zip|rar|7z|js|jse|vbs|vbe|wsf|hta|ps1|dll|pif|iso|img|cpl)$'
$script:BaitNames = '(?i)(?<![a-z])(cheats?|triche|hacks?|crack(ed)?|keygen|injector|executor|mod[ _.-]?menu|modest[ _.-]?menu|spoofer|free[ _.-]?robux|robux[ _.-]?(gen\w*|free)|aimbot|wallhack|kmspico|kms[ _.-]?auto|kiddions?|yim[ _.-]?menu|2take1|cherax|solara|krnl|fluxus|jjsploit|synapse[ _.-]?x)(?![a-z])'
function Test-RiskyDownloadName([string]$Name) {
    $out = New-Object System.Collections.ArrayList
    $n = "$Name"
    if ($n -match '[\u202A-\u202E\u2066-\u2069]') { [void]$out.Add('rlo') }
    if ($n -match '(?i)\.(pdf|docx?|xlsx?|pptx?|odt|txt|rtf|jpe?g|png|gif|bmp|webp|mp3|wav|mp4|avi|mkv|mov)\s*\.(exe|scr|com|bat|cmd|pif|vbs|vbe|js|jse|wsf|hta|lnk|msi|ps1|cpl)$') { [void]$out.Add('double') }
    if ($n -match $script:RiskyDlExt -and $n -match $script:BaitNames) { [void]$out.Add('appat') }
    return ,@($out)
}

# Fichier dont le nom fait penser à des mots de passe ou des codes de secours (nom JAMAIS écrit dans le journal)
$script:SecretExt = '(?i)\.(txt|rtf|docx?|odt|xlsx?|ods|csv|pdf|json|md|png|jpe?g)$'
$script:SecretNames = '(?i)(?<![a-z0-9])(mots?[ _.-]*de[ _.-]*passe|mdp|passwords?|passwd|pwd|codes?[ _.-]*(de[ _.-]*)?(secours|r[ée]cup[ée]ration)|backup[ _.-]*codes?|recovery[ _.-]*(codes?|phrase|keys?)|seed[ _.-]*(phrase|words?)|wallet|2fa|mfa|identifiants)(?![a-z0-9])'
function Test-SecretFileName([string]$Name) {
    $n = "$Name"
    if ($n -notmatch $script:SecretExt) { return $false }
    $base = $n -replace '\.[^.]+$', ''
    return ($base -match $script:SecretNames -or $base -match '(?i)^seed$')
}

# Verdict d'ensemble
function Get-SecVerdict($Items) {
    $all = @($Items | Where-Object { $_ })
    if (@($all | Where-Object { $_.Sev -eq 'crit' }).Count) { return @{ Level = 'crit'; Title = "Signes d'intrusion trouvés" } }
    if (@($all | Where-Object { $_.Sev -eq 'warn' }).Count) { return @{ Level = 'warn'; Title = 'Points à vérifier' } }
    return @{ Level = 'ok'; Title = "Aucun signe d'intrusion" }
}

# ---------------------------------------------------------------- Outils de l'analyse
$script:SecLolBins = '(?i)^(regasm|regsvcs|applaunch|installutil|msbuild|vbc|jsc|cvtres|aspnet_compiler|caspol|addinprocess|addinprocess32|addinutil)\.exe$'
$script:SecDevTools = '(?i)^(devenv|msbuild|dotnet|vbcscompiler|servicehub[\w.]*|rider64|code|unity(hub)?|vstest[\w.]*|testhost[\w.]*|msvsmon|blend|xdesproc)\.exe$'
$script:SecHostExe = '(?i)^(powershell|pwsh|cmd|wscript|cscript|mshta|rundll32|regsvr32|conhost|forfiles|bitsadmin|certutil)(\.exe)?$'
$script:SecCats = [ordered]@{ defender = 'Antivirus'; autorun = 'Lancements automatiques cachés'; process = 'Programmes en cours'; remote = 'Accès à distance et comptes'
                              download = 'Téléchargements à risque'; secret = 'Mots de passe en clair' }
$script:SecAccessibility = @('sethc', 'utilman', 'osk', 'Magnify', 'Narrator', 'DisplaySwitch', 'AtBroker')
$script:SecIfeoBases = @('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options')
$script:SecSpeBase = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit'
$script:SecPolicyBase = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'

function Add-SecItem {
    param([string]$Rule, [string]$Cat, [string]$Sev, [string]$Title, [string]$Path = '', [string]$Why = '', [string]$Todo = '', $Fix = $null, [string]$FixLabel = '', [switch]$Secret)
    $fx = @($Fix | Where-Object { $_ })
    [void]$script:SecItems.Add(@{ Id = [guid]::NewGuid().ToString('N').Substring(0, 12); Rule = $Rule; Cat = $Cat; Sev = $Sev; Title = $Title; Path = $Path; Why = $Why; Todo = $Todo
                                  Fix = $(if ($fx.Count) { $fx } else { $null }); FixLabel = $FixLabel; Default = ($Sev -eq 'crit' -and $fx.Count -gt 0); Secret = [bool]$Secret })
}
function Add-SecChecked([string]$Text) { [void]$script:SecChecked.Add($Text) }

# Variables d'un compte (%APPDATA%…) remplacées par celles de CE compte, puis celles de Windows
function Expand-SecVars([string]$Text, [string]$UserProfile = '') {
    $t = "$Text"
    if ($UserProfile) {
        $up = $UserProfile.TrimEnd('\')
        foreach ($p in @(@('%userprofile%', $up), @('%appdata%', "$up\AppData\Roaming"), @('%localappdata%', "$up\AppData\Local"), @('%temp%', "$up\AppData\Local\Temp"), @('%tmp%', "$up\AppData\Local\Temp"))) {
            $i = $t.IndexOf($p[0], [StringComparison]::OrdinalIgnoreCase)
            while ($i -ge 0) { $t = $t.Substring(0, $i) + $p[1] + $t.Substring($i + $p[0].Length); $i = $t.IndexOf($p[0], $i + $p[1].Length, [StringComparison]::OrdinalIgnoreCase) }
        }
    }
    return [Environment]::ExpandEnvironmentVariables($t)
}
# Fichier lancé par une ligne de commande (chemin complet ; '' si inconnu)
function Resolve-SecPath([string]$Cmd, [string]$UserProfile = '') {
    $c = (Expand-SecVars $Cmd $UserProfile).Trim()
    if (-not $c) { return '' }
    if ($c -match '^"([^"]+)"') { $e = $matches[1] }
    elseif ($c -match '(?i)^(.+?\.(exe|sys|dll|com|scr|bat|cmd|vbs|vbe|js|jse|wsf|ps1|hta|lnk|msi|cpl))(?=[\s,"]|$)') { $e = $matches[1] }
    else { $e = ($c -split '\s+')[0] }
    $e = $e.Trim().Trim('"') -replace '^\\\?\?\\', '' -replace '^\\\\\?\\', ''
    if ($e -match '(?i)^\\systemroot\\') { $e = $env:SystemRoot + $e.Substring(11) }
    elseif ($e -match '(?i)^(system32|syswow64)\\') { $e = Join-Path $env:SystemRoot $e }
    if ($e -notmatch '^[A-Za-z]:\\') {
        # Nom seul (« rundll32.exe », « cmd ») : programme de Windows
        if ($e -and $e -notmatch '\\') { $cand = Join-Path $env:SystemRoot ("System32\" + $e); if ($e -notmatch '\.[a-z0-9]{2,4}$') { $cand += '.exe' }; if (Test-Path -LiteralPath $cand) { return $cand } }
        return $e
    }
    if ($e -notmatch '\.[a-z0-9]{2,4}$' -and (Test-Path -LiteralPath "$e.exe")) { $e = "$e.exe" }
    return $e
}
# Script ou programme passé à un programme hôte (powershell, wscript, rundll32…)
function Get-CommandTarget([string]$Cmd, [string]$UserProfile = '') {
    $c = Expand-SecVars $Cmd $UserProfile
    $rest = if ($c -match '^\s*"[^"]*"(.*)$') { $matches[1] } elseif ($c -match '^\s*\S+(.*)$') { $matches[1] } else { '' }
    $m = [regex]::Match($rest, '(?i)([a-z]:\\[^"<>|*?\r\n]+?\.(exe|dll|js|jse|vbs|vbe|wsf|hta|ps1|bat|cmd|scr|cpl|ocx|com))(?=["''\s,;]|$)')
    if ($m.Success) { return $m.Groups[1].Value }
    # rundll32 « fichier,fonction » : le fichier peut avoir n'importe quelle extension (.dat, .tmp, aucune…)
    if ($c -match '(?i)rundll32(\.exe)?"?\s+"?([a-z]:\\[^",]+)') { return $matches[2].Trim() }
    return ''
}
# Signature Windows d'un fichier (gardée en mémoire par chemin pendant l'analyse)
function Get-SecSig([string]$Path) {
    if ($null -eq $script:SecSigCache) { $script:SecSigCache = @{} }
    $k = "$Path".ToLowerInvariant()
    if ($script:SecSigCache.ContainsKey($k)) { return $script:SecSigCache[$k] }
    $r = @{ Valid = $false; Ms = $false; Org = '' }
    try {
        $s = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
        if ($s.Status -eq 'Valid' -and $s.SignerCertificate) {
            $sub = "$($s.SignerCertificate.Subject)"
            $r.Valid = $true; $r.Ms = (Test-CertOrg $sub 'Microsoft Corporation')
            if ($sub -match '(?i)(?:^|,\s*)O=(?:"([^"]+)"|([^,]+))') { $r.Org = ("{0}{1}" -f $matches[1], $matches[2]).Trim() }
        }
    } catch {}
    $script:SecSigCache[$k] = $r
    return $r
}
# Programme lancé (au démarrage ou en ce moment) : Sev '' / 'warn' / 'crit', raisons, fichier en cause
function Get-LaunchRisk([string]$Cmd, [string]$UserProfile = '', [string]$Name = '') {
    $r = @{ Sev = ''; Why = ''; Path = ''; Exists = $false }
    $c = "$Cmd".Trim(); if (-not $c) { return $r }
    $why = New-Object System.Collections.ArrayList
    $exe = Resolve-SecPath $c $UserProfile
    $r.Path = $exe; $target = $exe
    $name = ($exe -split '\\')[-1]
    if ($name -match $script:SecHostExe) {
        $risk = Get-CommandRisk (Expand-SecVars $c $UserProfile)
        if ($risk.Level -eq 'strong') { $r.Sev = 'crit'; [void]$why.Add(("Ligne de commande à risque : {0}." -f ($risk.Reasons -join ', '))) }
        $inner = Get-CommandTarget $c $UserProfile
        if ($inner) { $target = $inner; $r.Path = $inner; $name = ($inner -split '\\')[-1] }
        else { $r.Why = ($why -join ' '); return $r }
    }
    $zone = Get-PathZone $target @() $env:SystemDrive
    $masq = Test-Masquerade $name $target $env:SystemRoot
    if (-not $masq -and -not $script:SecZoneLabels.ContainsKey($zone)) { $r.Why = ($why -join ' '); return $r }
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { $r.Why = ($why -join ' '); return $r }   # fichier absent : rien ne se lance
    $r.Exists = $true
    $sig = Get-SecSig $target
    # Installateur ou programme officiel d'AEROX (pas encore signé) : reconnu par son empreinte, jamais par son nom seul
    if (-not $sig.Valid -and (Test-AeroxOfficialFile $target)) { $r.Why = ($why -join ' '); return $r }
    if ($masq -eq 'exact' -and -not $sig.Ms) { $r.Sev = 'crit'; [void]$why.Add(("Porte le nom d'un programme de Windows ({0}) mais n'est pas dans le dossier de Windows : technique classique des virus." -f $name)) }
    elseif ($masq -like 'like:*' -and -not $sig.Valid -and $zone -notin 'programfiles', 'windows') { $r.Sev = 'crit'; [void]$why.Add(("Nom presque identique à « {0}.exe » de Windows, à une lettre près : technique classique des virus." -f $masq.Substring(5))) }
    if (-not $sig.Valid -and $script:SecZoneLabels.ContainsKey($zone)) {
        if ($zone -in 'temp', 'downloads', 'public') { $r.Sev = 'crit'; [void]$why.Add(("Programme sans signature d'éditeur lancé depuis {0}." -f $script:SecZoneLabels[$zone])) }
        else {
            $hide = Get-SuspiciousPlacement $target $Name
            if ($hide) { $r.Sev = 'crit'; [void]$why.Add(("Programme sans signature d'éditeur lancé depuis {0}, {1}." -f $script:SecZoneLabels[$zone], $hide)) }
            else {
                if (-not $r.Sev) { $r.Sev = 'warn' }
                [void]$why.Add(("Programme sans signature d'éditeur lancé depuis {0}. Beaucoup de logiciels honnêtes font ça, mais c'est aussi là que se cachent les voleurs de mots de passe." -f $script:SecZoneLabels[$zone]))
            }
        }
    }
    $r.Why = ($why -join ' ')
    return $r
}
# Fichiers officiels d'AEROX PC Care : empreintes SHA-256 publiées par GitHub pour chaque version (lecture d'une liste
# publique, rien n'est envoyé). Sans Internet, rien n'est reconnu : le fichier reste signalé comme les autres.
function Get-AeroxOfficialHashes {
    if ($null -ne $script:AeroxHashes) { return $script:AeroxHashes }
    $script:AeroxHashes = @{}
    try {
        if (-not $AppInfo.Repo) { return $script:AeroxHashes }
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $all = Invoke-RestMethod -Uri ("https://api.github.com/repos/{0}/releases?per_page=100" -f $AppInfo.Repo) -Headers @{ 'User-Agent' = 'AeroxPCCare' } -TimeoutSec 10 -ErrorAction Stop
        foreach ($rel in @($all | ForEach-Object { $_ })) {
            foreach ($a in @($rel.assets)) { if ("$($a.digest)" -match '^sha256:([0-9a-fA-F]{64})$') { $script:AeroxHashes[$Matches[1].ToUpperInvariant()] = "$($rel.tag_name)" } }
        }
    } catch {}
    return $script:AeroxHashes
}
# Version officielle d'AEROX à laquelle correspond ce fichier ('' si ce n'en est pas une, ou si on ne peut pas le vérifier)
function Test-AeroxOfficialFile([string]$Path) {
    if ((($Path -split '\\')[-1]) -notmatch '(?i)^aerox') { return '' }
    $h = ''; try { $h = (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant() } catch { return '' }
    $all = Get-AeroxOfficialHashes
    if ($h -and $all.ContainsKey($h)) { return $all[$h] }
    return ''
}
# Désinstalleur : il se copie dans Temp, se lance puis s'efface (normal, il doit pouvoir supprimer son propre dossier)
function Test-UninstallerName([string]$Name) { return ($Name -match '(?i)(uninst|unins\d{3}|^un_[a-z]\.exe$|^au_\.exe$|desinstall|désinstall)') }
# Raccourci .lnk : programme visé et arguments (lecture seule, par l'outil de Windows)
function Get-ShortcutInfo([string]$Path) {
    try {
        if (-not $script:SecShell) { $script:SecShell = New-Object -ComObject WScript.Shell }
        $s = $script:SecShell.CreateShortcut($Path)
        return @{ Target = "$($s.TargetPath)"; Args = "$($s.Arguments)" }
    } catch { return $null }
}
# Site d'où vient un fichier téléchargé (marque « Zone.Identifier » écrite par le navigateur) : seulement le nom du site
function Get-ZoneOrigin([string]$Path) {
    try {
        $z = @(Get-Content -LiteralPath $Path -Stream Zone.Identifier -ErrorAction Stop)
        foreach ($k in 'HostUrl=', 'ReferrerUrl=') {
            $l = @($z | Where-Object { $_ -like "$k*" }) | Select-Object -First 1
            if (-not $l) { continue }
            $h = ([uri]($l.Substring($k.Length).Trim())).Host.ToLowerInvariant()
            if (-not $h -or $h -eq 'localhost') { continue }
            $known = [ordered]@{ 'discord' = 'Discord'; 'mega\.(nz|io)' = 'Mega'; 'mediafire' = 'MediaFire'; 'github' = 'GitHub'; 'google(usercontent)?\.com$|drive\.google' = 'Google Drive'
                                 'dropbox' = 'Dropbox'; 'gofile' = 'Gofile'; 'wetransfer|we\.tl' = 'WeTransfer'; 'anonfiles|anonfile' = 'AnonFiles'; 'pixeldrain' = 'Pixeldrain'; 'catbox' = 'Catbox' }
            foreach ($p in $known.Keys) { if ($h -match $p) { return ("{0} ({1})" -f $known[$p], $h) } }
            return $h
        }
    } catch {}
    return ''
}
# Comptes du PC : SID -> dossier du profil
function Get-SecProfiles {
    $m = @{}
    try { foreach ($p in @(Get-CimInstance Win32_UserProfile -ErrorAction Stop | Where-Object { -not $_.Special -and $_.LocalPath })) { $m["$($p.SID)"] = "$($p.LocalPath)" } } catch {}
    return $m
}

# Heure d'ajout des exclusions (journal de Defender, événement 5007 « configuration modifiée ») : valeur en minuscules -> date
function Get-ExclusionAddTimes {
    $m = @{}
    try {
        foreach ($e in @(Get-WinEvent -LogName 'Microsoft-Windows-Windows Defender/Operational' -FilterXPath '*[System[(EventID=5007)]]' -MaxEvents 1000 -ErrorAction Stop)) {
            foreach ($x in [regex]::Matches("$($e.Message)", '(?i)Exclusions\\(?:Paths|Processes|Extensions)\\(.+?)\s*=\s*0x0')) {
                $k = $x.Groups[1].Value.Trim().ToLowerInvariant()
                if (-not $m.ContainsKey($k) -or $m[$k] -lt $e.TimeCreated) { $m[$k] = $e.TimeCreated }
            }
        }
    } catch {}
    return $m
}

# ---------------------------------------------------------------- a) Antivirus saboté
function Get-SecDefender {
    $mp = $null; try { $mp = Get-MpComputerStatus -ErrorAction Stop } catch {}
    $pref = $null; try { $pref = Get-MpPreference -ErrorAction Stop } catch {}
    $third = @(); try { $third = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop | Where-Object { $_.displayName -notmatch 'Defender' } | ForEach-Object { "$($_.displayName)" } | Select-Object -Unique) } catch {}
    if (-not $mp -and -not $pref) { Add-SecChecked $(if ($third.Count) { "Antivirus : {0} (Windows Defender est remplacé, ses réglages ne sont pas lisibles)" -f ($third -join ', ') } else { "Antivirus : Windows Defender ne répond pas" }); return }
    # Exclusions (regroupées au-delà de 3 de même gravité : un virus peut en ajouter des dizaines)
    $nEx = 0
    $byLv = @{ crit = New-Object System.Collections.ArrayList; warn = New-Object System.Collections.ArrayList; info = New-Object System.Collections.ArrayList }
    if ($pref) {
        foreach ($t in @(@('path', 'ExclusionPath'), @('ext', 'ExclusionExtension'), @('process', 'ExclusionProcess'))) {
            foreach ($v in @($pref.($t[1]) | Where-Object { $_ -and "$_" -notmatch '^N/A' })) {
                $nEx++
                $lv = Get-ExclusionRisk "$v" $t[0]
                if ($lv) { [void]$byLv[$lv].Add(@{ Type = $t[0]; Value = "$v" }) }
            }
        }
    }
    $when = @{}; if ($nEx) { $when = Get-ExclusionAddTimes }
    $txt = @{
        crit = @("exclusion", "Exclusion dangereuse dans l'antivirus", "Les virus ajoutent ce genre d'exclusion pour ne pas être détectés.", "Retire-la, sauf si tu l'as ajoutée toi-même pour une raison précise.")
        warn = @("exclusion-compte", "Exclusion d'un dossier de ton compte dans l'antivirus", "C'est un dossier où les programmes s'installent sans droits administrateur.", "Garde-la si tu l'as ajoutée toi-même (logiciel de travail, jeu). Sinon, retire-la.")
        info = @("exclusion-info", "Exclusion dans l'antivirus", "", "Normal si tu l'as ajoutée toi-même (jeu, logiciel de travail). Sinon, retire-la.")
    }
    foreach ($lv in 'crit', 'warn', 'info') {
        $l = @($byLv[$lv]); if (-not $l.Count) { continue }
        $tx = $txt[$lv]
        $describe = {
            param($e)
            switch ($e.Type) { 'ext' { "les fichiers « .{0} »" -f ($e.Value -replace '^\*?\.', '') } 'process' { "tout ce que fait le programme « {0} »" -f $e.Value } default { "le dossier « {0} »" -f $e.Value } }
        }
        $gone = @($l | Where-Object { $_.Type -ne 'ext' -and $_.Value -match '^[A-Za-z]:\\' -and -not (Test-Path -LiteralPath $_.Value) }).Count
        $dates = @($l | ForEach-Object { $when[$_.Value.ToLowerInvariant()] } | Where-Object { $_ } | Sort-Object)
        $dTxt = if ($dates.Count -gt 1) { " Ajoutées entre le {0:dd/MM à HH:mm} et le {1:dd/MM à HH:mm}." -f $dates[0], $dates[-1] } elseif ($dates.Count) { " Ajoutée le {0:dd/MM à HH:mm}." -f $dates[0] } else { '' }
        if ($l.Count -le 3) {
            foreach ($e in $l) {
                $d = $when[$e.Value.ToLowerInvariant()]
                Add-SecItem -Rule $tx[0] -Cat 'defender' -Sev $lv -Title $tx[1] -Path $e.Value -Fix @(@{ Kind = 'exclusion'; Type = $e.Type; Value = $e.Value }) -FixLabel 'Retirer cette exclusion' `
                    -Why (("Defender ne surveille plus {0}. {1}{2}" -f (& $describe $e), $tx[2], $(if ($d) { " Ajoutée le {0:dd/MM à HH:mm}." -f $d } else { '' }))).Trim() -Todo $tx[3]
            }
        } else {
            $shown = @($l | Select-Object -First 4 | ForEach-Object { $_.Value })
            Add-SecItem -Rule $tx[0] -Cat 'defender' -Sev $lv -Title ("{0} exclusions {1}dans l'antivirus" -f $l.Count, $(if ($lv -eq 'crit') { 'dangereuses ' } else { '' })) `
                -Path (($shown -join ' · ') + $(if ($l.Count -gt 4) { " · … et {0} autre(s)" -f ($l.Count - 4) } else { '' })) `
                -Fix @($l | ForEach-Object { @{ Kind = 'exclusion'; Type = $_.Type; Value = $_.Value } }) -FixLabel ("Retirer les {0} exclusions" -f $l.Count) `
                -Why (("Defender ne surveille plus ces {0} éléments. {1}{2}{3}" -f $l.Count, $tx[2], $(if ($gone) { " $gone d'entre eux n'existent plus sur le PC : ce sont des traces laissées par un programme qui s'est effacé." } else { '' }), $dTxt)).Trim() `
                -Todo $(if ($lv -eq 'crit') { "Retire-les toutes. Si elles reviennent après un redémarrage, l'infection est toujours là." } else { $tx[3] })
        }
    }
    Add-SecChecked ("Exclusions de l'antivirus : {0}" -f $(if ($nEx) { $nEx } else { 'aucune' }))
    # Réglages et stratégies qui coupent Defender (seulement s'il est le seul antivirus)
    if (-not $third.Count) {
        $pk = $script:SecPolicyBase
        $found = New-Object System.Collections.ArrayList
        foreach ($v in @(@($pk, 'DisableAntiSpyware', 1, 'Defender entier'), @($pk, 'DisableAntiVirus', 1, 'antivirus'), @("$pk\Real-Time Protection", 'DisableRealtimeMonitoring', 1, 'protection en temps réel'),
                         @("$pk\Real-Time Protection", 'DisableBehaviorMonitoring', 1, 'surveillance des comportements'), @("$pk\Real-Time Protection", 'DisableOnAccessProtection', 1, "analyse à l'ouverture des fichiers"),
                         @("$pk\Real-Time Protection", 'DisableIOAVProtection', 1, 'analyse des téléchargements'), @("$pk\Real-Time Protection", 'DisableScanOnRealtimeEnable', 1, "analyse des programmes lancés"),
                         @("$pk\Spynet", 'SpynetReporting', 0, 'protection dans le cloud'))) {
            try { $x = Get-ItemProperty -LiteralPath $v[0] -Name $v[1] -ErrorAction Stop; if ([int]$x.($v[1]) -eq $v[2]) { [void]$found.Add($v) } } catch {}
        }
        if ($found.Count) {
            Add-SecItem -Rule 'strategie' -Cat 'defender' -Sev 'crit' -Title "Une stratégie coupe des protections de l'antivirus" -Path (($found | ForEach-Object { "{0}\{1}" -f ($_[0] -replace '^HKLM:\\', 'HKLM\'), $_[1] }) -join ' · ') `
                -Why ("Une règle de « stratégie de groupe » désactive : {0}. Sur un PC personnel, c'est presque toujours un virus ou un faux « optimiseur » qui l'a mise." -f (($found | ForEach-Object { $_[3] }) -join ', ')) `
                -Todo "Remets les réglages par défaut, puis lance l'analyse hors ligne. Sur un PC d'entreprise ou d'école, ne touche à rien." `
                -Fix @(@{ Kind = 'policy'; Values = @($found | ForEach-Object { "{0}|{1}" -f $_[0], $_[1] }) }) -FixLabel 'Remettre les réglages par défaut'
        }
        if ($mp -and $mp.AntivirusEnabled) {
            # Protections coupées par un programme (Set-MpPreference), sans stratégie : la fenêtre Sécurité Windows peut rester verte
            $off = New-Object System.Collections.ArrayList
            if ($mp.RealTimeProtectionEnabled -eq $false) { [void]$off.Add('protection en temps réel') }
            if ($pref) {
                foreach ($q in @(@('DisableRealtimeMonitoring', 'protection en temps réel'), @('DisableIOAVProtection', 'analyse des téléchargements'), @('DisableScriptScanning', 'analyse des scripts'),
                                 @('DisableBehaviorMonitoring', 'surveillance des comportements'), @('DisableBlockAtFirstSeen', 'blocage des fichiers inconnus'))) {
                    if ($pref.($q[0]) -eq $true -and -not $off.Contains($q[1])) { [void]$off.Add($q[1]) }
                }
            }
            if ($off.Count) {
                Add-SecItem -Rule 'defender-coupe' -Cat 'defender' -Sev 'crit' -Title "Des protections de l'antivirus sont coupées" -Path ($off -join ' · ') `
                    -Why ("Un programme a coupé : {0}. Les virus le font pour travailler tranquilles ; la fenêtre Sécurité Windows peut quand même afficher que tout est activé." -f ($off -join ', ')) `
                    -Todo "Remets-les (case cochée), puis lance l'analyse hors ligne. Si elles se recoupent après un redémarrage, l'infection est toujours là." `
                    -Fix @(@{ Kind = 'mppref' }) -FixLabel 'Remettre les protections'
            }
            if ($mp.IsTamperProtected -eq $false) {
                Add-SecItem -Rule 'falsification' -Cat 'defender' -Sev 'warn' -Title "La protection contre les falsifications est coupée" -Why "Sans elle, un programme peut éteindre l'antivirus en douce." `
                    -Todo "Sécurité Windows > Protection contre les virus et menaces > Gérer les paramètres : active « Protection contre les falsifications »."
            }
            if ($mp.BehaviorMonitorEnabled -eq $false -and -not $off.Contains('surveillance des comportements')) {
                Add-SecItem -Rule 'comportement' -Cat 'defender' -Sev 'warn' -Title "La surveillance des comportements est coupée" -Why "Defender ne repère plus les programmes qui agissent comme des virus (même inconnus)." `
                    -Todo "Sécurité Windows > Protection contre les virus et menaces > Gérer les paramètres : réactive la protection en temps réel. Si ça reste coupé, lance l'analyse hors ligne."
            }
            if ($pref -and [int]$pref.MAPSReporting -eq 0) {
                Add-SecItem -Rule 'cloud' -Cat 'defender' -Sev 'warn' -Title "La protection dans le cloud est coupée" -Why "Defender ne peut plus demander l'avis de Microsoft sur un fichier nouveau : les virus récents passent plus facilement." `
                    -Todo "Sécurité Windows > Protection contre les virus et menaces > Gérer les paramètres : active « Protection fournie par le cloud »."
            }
        }
    }
    # SmartScreen
    $ss = $false
    try { if ([int](Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name EnableSmartScreen -ErrorAction Stop).EnableSmartScreen -eq 0) { $ss = $true } } catch {}
    try { if ("$((Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name SmartScreenEnabled -ErrorAction Stop).SmartScreenEnabled)" -eq 'Off') { $ss = $true } } catch {}
    if ($ss) {
        Add-SecItem -Rule 'smartscreen' -Cat 'defender' -Sev 'warn' -Title "SmartScreen est coupé" -Why "Windows ne prévient plus avant d'ouvrir un programme inconnu téléchargé sur Internet." `
            -Todo "Sécurité Windows > Contrôle des applications et du navigateur > Protection fondée sur la réputation : active « Vérifier les applications et les fichiers »."
    }
    Add-SecChecked "Réglages de l'antivirus et de SmartScreen"
    # Menaces des 30 derniers jours
    try {
        $since = (Get-Date).AddDays(-30)
        $th = @{}; foreach ($t in @(Get-MpThreat -ErrorAction Stop)) { $th["$($t.ThreatID)"] = $t }
        $det = @(Get-MpThreatDetection -ErrorAction Stop | Where-Object { $_.InitialDetectionTime -ge $since })
        foreach ($g in @($det | Group-Object { "$($_.ThreatID)" })) {
            $t = $th[$g.Name]
            $name = if ($t -and $t.ThreatName) { "$($t.ThreatName)" } else { "Menace n° $($g.Name)" }
            $files = @($g.Group | ForEach-Object { @($_.Resources) } | Where-Object { $_ } | ForEach-Object { "$_" -replace '^[a-z]+:_', '' } | Select-Object -Unique)
            $when = (@($g.Group | Sort-Object InitialDetectionTime -Descending)[0].InitialDetectionTime).ToString('dd/MM/yyyy')
            if ($t -and ($t.IsActive -or $t.DidThreatExecute)) {
                Add-SecItem -Rule 'menace' -Cat 'defender' -Sev 'crit' -Title ("Virus trouvé par Defender : {0}" -f $name) -Path (($files | Select-Object -First 3) -join ' · ') `
                    -Why $(if ($t.DidThreatExecute) { "Trouvé le $when. Il a eu le temps de se lancer sur le PC : il a pu voler des mots de passe ou des connexions." } else { "Trouvé le $when, et il est encore présent sur le PC." }) `
                    -Todo "Change tes mots de passe depuis ton téléphone (pas depuis ce PC), en commençant par ta boîte mail. Puis lance l'analyse hors ligne."
            } else {
                Add-SecItem -Rule 'menace-bloquee' -Cat 'defender' -Sev 'info' -Title ("Menace bloquée à temps : {0}" -f $name) -Path (($files | Select-Object -First 3) -join ' · ') `
                    -Why "Trouvée le $when. Defender l'a supprimée ou mise en quarantaine avant qu'elle se lance." -Todo "Rien à faire. Ne retélécharge pas ce fichier."
            }
        }
        Add-SecChecked ("Virus trouvés par Defender ces 30 derniers jours : {0}" -f @($det | Group-Object ThreatID).Count)
    } catch {}
}

# Correctifs d'un fichier suspect : analyse Defender (si Defender est actif au moment du traitement) puis quarantaine AEROX,
# qui marche avec n'importe quel antivirus. Jamais pour un fichier du dossier de Windows (seulement l'analyse).
function Get-FileFixes([string]$Path) {
    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
    $scan = @(); if ($script:SecDefOn -ne $false) { $scan = @(@{ Kind = 'scan'; File = $Path }) }
    $w = $env:SystemRoot.TrimEnd('\') + '\'
    if ($Path.StartsWith($w, [StringComparison]::OrdinalIgnoreCase)) { return $scan }
    return @($scan + @(@{ Kind = 'quarantine'; File = $Path }))
}
function Get-FixLabel($Fix) {
    $k = @(@($Fix) | Where-Object { $_ } | ForEach-Object { $_.Kind })
    $q = $k -contains 'quarantine'; $off = @($k | Where-Object { $_ -in 'startup', 'task' }).Count; $svc = $k -contains 'service'
    if ($q -and $svc) { return 'Mettre en quarantaine et passer le service en manuel' }
    if ($q -and $off) { return 'Mettre en quarantaine et désactiver' }
    if ($q) { return 'Mettre en quarantaine' }
    if ($svc) { return 'Passer le service en manuel' }
    if ($off) { return 'Désactiver' }
    if ($k -contains 'scan') { return 'Analyser avec Windows Defender' }
    return ''
}

# ---------------------------------------------------------------- Quarantaine AEROX
# Le fichier est déplacé dans le dossier protégé (réservé aux administrateurs) et renommé pour ne plus pouvoir se lancer.
# Rien n'est supprimé : « Annuler » dans l'historique le remet à sa place.
function Move-ToQuarantine([string]$File) {
    if ("$File" -notmatch '^[A-Za-z]:\\' -or -not (Test-Path -LiteralPath $File -PathType Leaf)) { throw "le fichier n'existe plus" }
    $full = [IO.Path]::GetFullPath($File)
    $w = $env:SystemRoot.TrimEnd('\') + '\'; $a = (Split-Path -Parent $AppInfo.Secure).TrimEnd('\') + '\'
    if ($full.StartsWith($w, [StringComparison]::OrdinalIgnoreCase) -or $full.StartsWith($a, [StringComparison]::OrdinalIgnoreCase)) { throw "fichier de Windows ou d'AEROX : jamais mis en quarantaine" }
    if (-not [AeroxSafeDelete]::IsDirectPath($full)) { throw "le chemin passe par un lien : refusé par sécurité" }
    if ((Get-SecSig $full).Ms) { throw "fichier signé par Microsoft : jamais mis en quarantaine" }
    # Programme en cours depuis ce fichier : arrêté d'abord (sinon Windows refuse de le déplacer)
    foreach ($p in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { "$($_.ExecutablePath)" -ieq $full })) {
        try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop; Log ("   • « {0} » était en marche : arrêté." -f $p.Name) } catch {}
    }
    Start-Sleep -Milliseconds 400
    $dir = Get-SecureDir 'quarantaine'
    $id = [guid]::NewGuid().ToString('N')
    $sha = ''; try { $sha = (Get-FileHash -LiteralPath $full -Algorithm SHA256 -ErrorAction Stop).Hash } catch {}
    $qpath = Join-Path $dir "$id.quarantaine"
    Move-Item -LiteralPath $full -Destination $qpath -Force -ErrorAction Stop
    # Un fichier déplacé garde les droits de son ancien dossier : il resterait modifiable sans droits admin.
    # Propriétaire = Administrateurs, droits = ceux du dossier protégé.
    Set-QuarantineAcl $qpath
    $meta = [ordered]@{ id = $id; chemin = $full; sha256 = $sha; date = (Get-Date).ToString('s') }
    [IO.File]::WriteAllText((Join-Path $dir "$id.json"), ($meta | ConvertTo-Json -Compress), (New-Object Text.UTF8Encoding($false)))
    Add-Change -Title ("Mis en quarantaine : {0}" -f (Split-Path -Leaf $full)) -Detail ("{0} · « Annuler » le remet à sa place." -f $full) -Undo ("Restore-Quarantine {0}" -f (ConvertTo-PsLiteral $id))
    return $id
}
function Set-QuarantineAcl([string]$Path) {
    $ic = Join-Path $env:SystemRoot 'System32\icacls.exe'
    try { $null = & $ic $Path '/setowner' '*S-1-5-32-544' '/q' 2>&1; $null = & $ic $Path '/reset' '/q' 2>&1 } catch {}
    $weak = ''; try { $weak = Get-AclWeakness $Path } catch { $weak = $_.Exception.Message }
    if ($weak) { Log ("   ⚠ Droits du fichier en quarantaine pas entièrement protégés ({0}) : il reste impossible à lancer." -f $weak) }
}
# Contenu de la quarantaine (fiches lues dans le dossier protégé)
$script:QuarMinHours = 24
function Get-QuarantineItems {
    $out = New-Object System.Collections.ArrayList
    $dir = Join-Path $AppInfo.Secure 'quarantaine'
    if (-not (Test-Path -LiteralPath $dir)) { return @() }
    foreach ($m in @(Get-ChildItem -LiteralPath $dir -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
        $id = $m.BaseName
        if ($id -notmatch '^[0-9a-f]{32}$') { continue }
        $q = Join-Path $dir "$id.quarantaine"
        if (-not (Test-Path -LiteralPath $q)) { continue }
        $meta = $null; try { $meta = [IO.File]::ReadAllText($m.FullName) | ConvertFrom-Json } catch {}
        $date = $m.CreationTime; try { if ($meta.date) { $date = [datetime]$meta.date } } catch {}
        [void]$out.Add(@{ Id = $id; Path = "$($meta.chemin)"; Name = (("$($meta.chemin)" -split '\\')[-1]); Sha = "$($meta.sha256)"; Date = $date; Size = [double](Get-Item -LiteralPath $q).Length
                          CanDelete = (((Get-Date) - $date).TotalHours -ge $script:QuarMinHours) })
    }
    return @($out | Sort-Object { $_.Date } -Descending)
}
# Suppression définitive (seulement ce qu'AEROX a mis lui-même en quarantaine, et après 24 heures : le temps de vérifier
# après un redémarrage que tout marche sans ces fichiers)
function Clear-Quarantine([string[]]$Ids) {
    Step "Suppression définitive des fichiers en quarantaine"
    $dir = Join-Path $AppInfo.Secure 'quarantaine'
    $items = @(Get-QuarantineItems)
    $done = @()
    foreach ($id in @($Ids)) {
        $it = @($items | Where-Object { $_.Id -eq $id })[0]
        if (-not $it) { Log ("   • {0} : n'est plus en quarantaine." -f $id); continue }
        if (-not $it.CanDelete) { Log ("   • « {0} » est en quarantaine depuis moins de {1} heures : gardé pour l'instant (annulable)." -f $it.Name, $script:QuarMinHours); continue }
        try {
            Remove-Item -LiteralPath (Join-Path $dir "$id.quarantaine") -Force -ErrorAction Stop
            Remove-Item -LiteralPath (Join-Path $dir "$id.json") -Force -ErrorAction SilentlyContinue
            $done += $it.Name; Log ("   ✔ « {0} » supprimé définitivement." -f $it.Name)
        } catch { Log ("   ⚠ « {0} » : {1}" -f $it.Name, $_.Exception.Message) }
    }
    if ($done.Count) { Add-Change -Kind 'info' -Title ("Quarantaine vidée : {0} fichier(s) supprimé(s) définitivement" -f $done.Count) -Detail ($done -join ' · ') }
    Log ("✅ {0} fichier(s) supprimé(s) définitivement." -f $done.Count)
}
function Restore-Quarantine([string]$Id) {
    Step "Sortie de quarantaine"
    $dir = Get-SecureDir 'quarantaine'
    $mf = Join-Path $dir "$Id.json"; $qf = Join-Path $dir "$Id.quarantaine"
    if ($Id -notmatch '^[0-9a-f]{32}$' -or -not (Test-Path -LiteralPath $mf) -or -not (Test-Path -LiteralPath $qf)) { Add-TaskError -Title "Ce fichier n'est plus en quarantaine" -Cause "Il a déjà été remis à sa place, ou la quarantaine a été vidée." -Effect "Rien n'a changé."; return }
    $meta = [IO.File]::ReadAllText($mf) | ConvertFrom-Json
    $dest = "$($meta.chemin)"
    if ($dest -notmatch '^[A-Za-z]:\\') { Add-TaskError -Title "Emplacement d'origine inconnu" -Cause "La fiche de quarantaine est abîmée." -Effect "Le fichier reste en quarantaine."; return }
    if (Test-Path -LiteralPath $dest) { Add-TaskError -Title "Impossible de remettre le fichier à sa place" -Cause "Un fichier porte déjà ce nom à cet endroit : $dest" -Effect "Le fichier reste en quarantaine." -Steps @("Renomme ou déplace le fichier qui est à cet endroit, puis réessaie."); return }
    # Le fichier doit être exactement celui mis en quarantaine (empreinte notée à ce moment-là)
    if ($meta.sha256) {
        $h = ''; try { $h = (Get-FileHash -LiteralPath $qf -Algorithm SHA256 -ErrorAction Stop).Hash } catch {}
        if ($h -ne "$($meta.sha256)") { Add-TaskError -Title "Le fichier en quarantaine a été modifié" -Cause "Son empreinte ne correspond plus à celle notée lors de la mise en quarantaine." -Effect "Il n'est pas remis à sa place, par sécurité."; return }
    }
    # Aucun dossier du chemin d'origine ne doit être un lien vers ailleurs (sinon le fichier pourrait atterrir dans Windows)
    $pd = Split-Path -Parent $dest
    $cur = $pd; while ($cur -and -not (Test-Path -LiteralPath $cur)) { $cur = Split-Path -Parent $cur }
    if (-not $cur -or -not [AeroxSafeDelete]::IsDirectPath($cur)) { Add-TaskError -Title "Impossible de remettre le fichier à sa place" -Cause "Le dossier d'origine passe par un lien vers un autre dossier." -Effect "Le fichier reste en quarantaine, par sécurité."; return }
    if (-not (Test-Path -LiteralPath $pd)) { New-Item -ItemType Directory -Force -Path $pd | Out-Null }
    if (-not [AeroxSafeDelete]::IsDirectPath($pd)) { Add-TaskError -Title "Impossible de remettre le fichier à sa place" -Cause "Le dossier d'origine passe par un lien vers un autre dossier." -Effect "Le fichier reste en quarantaine, par sécurité."; return }
    Move-Item -LiteralPath $qf -Destination $dest -ErrorAction Stop
    Remove-Item -LiteralPath $mf -Force -ErrorAction SilentlyContinue
    Log ("   ✔ « {0} » est revenu à sa place." -f (Split-Path -Leaf $dest))
}

# Fichier d'un composant COM : d'abord celui du compte (qui passe avant celui de Windows), puis celui du PC
function Get-ComServerPath([string]$ClassId, [string]$Hkcu = 'HKCU:') {
    $id = "$ClassId".Trim()
    if ($id -notmatch '^\{[0-9A-Fa-f-]{36}\}$') { return '' }
    foreach ($root in @("$Hkcu\Software\Classes\CLSID", 'HKLM:\SOFTWARE\Classes\CLSID')) {
        foreach ($srv in 'InprocServer32', 'LocalServer32') {
            try { $v = "$((Get-Item -LiteralPath "$root\$id\$srv" -ErrorAction Stop).GetValue(''))"; if ($v.Trim()) { return (Resolve-SecPath $(if ($v -match '^\s*"' -or $srv -eq 'LocalServer32') { $v } else { '"{0}"' -f $v.Trim() })) } } catch {}
        }
    }
    return ''
}

# ---------------------------------------------------------------- b) Lancements automatiques cachés
function Add-SecLaunch {
    param([string]$Rule, [string]$Title, $Risk, [string]$Todo = '', $Fix = @(), [string]$FixLabel = '', [switch]$Off)
    if (-not $Risk.Sev) { return }
    $sev = $Risk.Sev; $why = $Risk.Why
    if ($Off) { if ($sev -eq 'crit') { $sev = 'warn' }; $why += " (Désactivé au démarrage, mais toujours présent.)" }
    $fx = @($Fix | Where-Object { $_ })
    if ($Risk.Exists -and $Risk.Path -and ($Risk.Path -split '\\')[-1] -notmatch $script:SecHostExe) { $fx = @(Get-FileFixes $Risk.Path) + $fx }
    if (-not $FixLabel) { $FixLabel = Get-FixLabel $fx }
    if (-not $Todo) { $Todo = if ($sev -eq 'crit') { "Si tu ne le reconnais pas : coche-le (quarantaine et désactivation), puis lance l'analyse hors ligne." } else { "Si tu ne le reconnais pas : coche-le, ou envoie le rapport au développeur pour avoir son avis." } }
    Add-SecItem -Rule $Rule -Cat 'autorun' -Sev $sev -Title $Title -Path $Risk.Path -Why $why -Todo $Todo -Fix $fx -FixLabel $FixLabel
}
function Get-SecAutoruns {
    $script:SecAutoTexts = New-Object System.Collections.ArrayList
    $su = Get-SessionUser
    $sessSid = if ($su.Other) { $su.Sid } else { try { [Security.Principal.WindowsIdentity]::GetCurrent().User.Value } catch { '' } }
    $profiles = Get-SecProfiles
    $ab = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
    # 1. Clés Run / RunOnce / Policies (tout le PC et chaque compte ouvert)
    $roots = New-Object System.Collections.ArrayList
    [void]$roots.Add(@{ Hk = 'HKLM:'; Profile = $su.Profile; Machine = $true; Session = $false })
    foreach ($h in @(Get-ChildItem -LiteralPath 'Registry::HKEY_USERS' -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^S-1-5-21-[\d-]+$' })) {
        $sid = $h.PSChildName
        [void]$roots.Add(@{ Hk = "Registry::HKEY_USERS\$sid"; Profile = $(if ($profiles.ContainsKey($sid)) { $profiles[$sid] } else { '' }); Machine = $false; Session = ($sid -eq $sessSid) })
    }
    $nRun = 0
    foreach ($rt in $roots) {
        $subs = @(@('Software\Microsoft\Windows\CurrentVersion\Run', 'Run'), @('Software\Microsoft\Windows\CurrentVersion\RunOnce', ''), @('Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run', ''))
        if ($rt.Machine) { $subs += @(, @('Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run', 'Run32')); $subs += @(, @('Software\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce', '')) }
        foreach ($s in $subs) {
            $key = Get-Item -LiteralPath ("{0}\{1}" -f $rt.Hk, $s[0]) -ErrorAction SilentlyContinue
            if (-not $key) { continue }
            foreach ($n in $key.GetValueNames()) {
                if (-not $n) { continue }
                $nRun++
                $cmd = [string]$key.GetValue($n)
                [void]$script:SecAutoTexts.Add("$n $cmd")
                $risk = Get-LaunchRisk $cmd $rt.Profile $n
                if (-not $risk.Sev) {
                    # Ligne qui lance un fichier qui n'existe plus (reste d'un programme désinstallé ou d'un virus supprimé)
                    $tgt = Resolve-SecPath $cmd $rt.Profile
                    if ($tgt -match '^[A-Za-z]:\\' -and ($tgt -split '\\')[-1] -notmatch $script:SecHostExe -and (Test-Path -LiteralPath $tgt.Substring(0, 3)) -and -not (Test-Path -LiteralPath $tgt)) {
                        $fixKey = "{0}\{1}" -f $(if ($rt.Session) { $su.Hkcu } else { $rt.Hk }), $s[0]
                        $canFix = ($rt.Machine -or $rt.Session) -and $s[0] -notmatch 'Policies'
                        Add-SecItem -Rule 'demarrage-vide' -Cat 'autorun' -Sev 'info' -Title ("Ligne de démarrage vide : {0}" -f $n) -Path $tgt `
                            -Why "Elle lance un fichier qui n'existe plus (reste d'un programme désinstallé ou d'un virus supprimé). Elle ne lance rien, mais un virus pourrait la réutiliser." `
                            -Todo "Retire-la si tu ne reconnais pas ce nom." -Fix $(if ($canFix) { @(@{ Kind = 'runvalue'; Key = $fixKey; Name = $n }) } else { @() }) -FixLabel 'Retirer la ligne'
                    }
                    continue
                }
                $fix = @(); $off = $false
                if ($s[1] -and ($rt.Machine -or $rt.Session)) {
                    $appr = if ($rt.Machine) { "HKLM:\$ab\$($s[1])" } else { "$($su.Hkcu)\$ab\$($s[1])" }
                    $off = -not (Test-StartupEnabled $appr $n)
                    if (-not $off) { $fix = @(@{ Kind = 'startup'; Id = "$appr|$n" }) }
                }
                Add-SecLaunch -Rule 'demarrage' -Title ("Lancement au démarrage : {0}" -f $n) -Risk $risk -Fix $fix -Off:$off
            }
        }
    }
    # 2. Dossiers « Démarrage » (de chaque compte et de tout le PC)
    $folders = New-Object System.Collections.ArrayList
    [void]$folders.Add(@{ Dir = [Environment]::GetFolderPath('CommonStartup'); Appr = "HKLM:\$ab\StartupFolder"; Profile = $su.Profile })
    foreach ($sid in $profiles.Keys) {
        $d = Join-Path $profiles[$sid] 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup'
        [void]$folders.Add(@{ Dir = $(if ($sid -eq $sessSid) { Get-SessionFolder 'Startup' } else { $d }); Appr = $(if ($sid -eq $sessSid) { "$($su.Hkcu)\$ab\StartupFolder" } else { '' }); Profile = $profiles[$sid] })
    }
    foreach ($f in $folders) {
        if (-not $f.Dir -or -not (Test-Path -LiteralPath $f.Dir)) { continue }
        foreach ($file in @(Get-ChildItem -LiteralPath $f.Dir -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' })) {
            $nRun++
            $cmd = '"{0}"' -f $file.FullName
            if ($file.Extension -ieq '.lnk') { $sc = Get-ShortcutInfo $file.FullName; if ($sc -and $sc.Target) { $cmd = ('"{0}" {1}' -f $sc.Target, $sc.Args).Trim() } }
            [void]$script:SecAutoTexts.Add("$($file.BaseName) $cmd")
            $risk = Get-LaunchRisk $cmd $f.Profile $file.BaseName
            if (-not $risk.Sev) { continue }
            $fix = @(); $off = $false
            if ($f.Appr) { $off = -not (Test-StartupEnabled $f.Appr $file.Name); if (-not $off) { $fix = @(@{ Kind = 'startup'; Id = "$($f.Appr)|$($file.Name)" }) } }
            Add-SecLaunch -Rule 'demarrage' -Title ("Dossier Démarrage : {0}" -f $file.Name) -Risk $risk -Fix $fix -Off:$off
        }
    }
    Add-SecChecked ("Programmes au démarrage (clés Run et dossiers Démarrage de chaque compte) : {0}" -f $nRun)
    if ($sync.Cancel) { return }
    # 3. Tâches planifiées (toutes, y compris celles de Windows : elles sont lues, jamais coupées)
    $nT = 0
    $seenTasks = @{}
    foreach ($t in @(Get-ScheduledTask -ErrorAction SilentlyContinue)) {
        $seenTasks[("{0}{1}" -f $t.TaskPath, $t.TaskName).ToLowerInvariant()] = $true
        if ($t.State -eq 'Disabled' -or "$($t.TaskName)" -match '(?i)^AEROX PC Care') { continue }
        # Action « COM » : le programme lancé est la DLL du composant (un composant détourné dans le compte se lance à sa place)
        foreach ($a in @($t.Actions | Where-Object { $_ -and -not $_.Execute -and $_.ClassId })) {
            $dll = Get-ComServerPath "$($a.ClassId)" $su.Hkcu
            if (-not $dll) { continue }
            $nT++
            $risk = Get-LaunchRisk ('"{0}"' -f $dll) $su.Profile "$($t.TaskName)"
            if ($risk.Sev) { Add-SecLaunch -Rule 'tache-com' -Title ("Tâche planifiée (composant COM) : {0}" -f $t.TaskName) -Risk $risk }
        }
        foreach ($a in @($t.Actions | Where-Object { $_ -and $_.Execute })) {
            $nT++
            $cmd = ('"{0}" {1}' -f "$($a.Execute)".Trim().Trim('"'), "$($a.Arguments)").Trim()
            [void]$script:SecAutoTexts.Add("$($t.TaskName) $cmd")
            $risk = Get-LaunchRisk $cmd $su.Profile "$($t.TaskName)"
            if (-not $risk.Sev) { continue }
            $ms = "$($t.TaskPath)" -like '\Microsoft\*'
            $fix = if ($ms) { @() } else { @(@{ Kind = 'task'; Path = "$($t.TaskPath)"; Name = "$($t.TaskName)"; Label = "$($t.TaskName)" }) }
            Add-SecLaunch -Rule 'tache' -Title ("Tâche planifiée : {0}" -f $t.TaskName) -Risk $risk -Fix $fix `
                -Todo $(if ($ms) { "Cette tâche est rangée avec celles de Windows : AEROX ne la coupe pas. Analyse le fichier avec Defender, puis lance l'analyse hors ligne." } else { '' })
        }
    }
    # Tâches cachées : présentes dans C:\Windows\System32\Tasks mais invisibles pour le Planificateur (descripteur retiré du registre,
    # technique de virus). Lues directement dans leur fichier XML.
    $nH = 0
    $troot = Join-Path $env:SystemRoot 'System32\Tasks'
    foreach ($f in @(Get-ChildItem -LiteralPath $troot -Recurse -File -Force -ErrorAction SilentlyContinue)) {
        $rel = $f.FullName.Substring($troot.Length)
        if ($seenTasks.ContainsKey($rel.ToLowerInvariant())) { continue }
        $x = $null; try { $x = [xml][IO.File]::ReadAllText($f.FullName) } catch { continue }
        if (-not $x -or -not $x.Task) { continue }
        if ("$($x.Task.Settings.Enabled)" -eq 'false') { continue }
        $cmds = @(@($x.Task.Actions.Exec) | Where-Object { $_ } | ForEach-Object { ('"{0}" {1}' -f "$($_.Command)".Trim().Trim('"'), "$($_.Arguments)").Trim() })
        $cmds += @(@($x.Task.Actions.ComHandler) | Where-Object { $_ } | ForEach-Object { $d = Get-ComServerPath "$($_.ClassId)" $su.Hkcu; if ($d) { '"{0}"' -f $d } })
        foreach ($cmd in @($cmds | Where-Object { $_ })) {
            $nH++
            [void]$script:SecAutoTexts.Add("$rel $cmd")
            $risk = Get-LaunchRisk $cmd $su.Profile ($rel -split '\\')[-1]
            if (-not $risk.Sev) { continue }
            $risk.Sev = 'crit'
            $risk.Why = "Cette tâche est invisible dans le Planificateur de tâches de Windows : technique de virus pour se relancer sans être vu. " + $risk.Why
            Add-SecLaunch -Rule 'tache-cachee' -Title ("Tâche planifiée cachée : {0}" -f $rel) -Risk $risk -Todo "Coche-la : le fichier est mis en quarantaine, la tâche ne peut plus rien lancer. Puis lance l'analyse hors ligne."
        }
    }
    Add-SecChecked ("Tâches planifiées (y compris celles de Windows et les tâches cachées) : {0}" -f ($nT + $nH))
    if ($sync.Cancel) { return }
    # Composants COM détournés dans le compte : un programme se charge à la place d'un composant de Windows (sans droits admin)
    $nC = 0
    foreach ($k in @(Get-ChildItem -LiteralPath "$($su.Hkcu)\Software\Classes\CLSID" -ErrorAction SilentlyContinue)) {
        foreach ($srv in 'InprocServer32', 'LocalServer32') {
            $v = ''; try { $v = "$((Get-Item -LiteralPath (Join-Path $k.PSPath $srv) -ErrorAction Stop).GetValue(''))" } catch { continue }
            if (-not $v.Trim()) { continue }
            $nC++
            $risk = Get-LaunchRisk $(if ($v -match '^\s*"' -or $srv -eq 'LocalServer32') { $v } else { '"{0}"' -f $v.Trim() }) $su.Profile
            if ($risk.Sev) {
                $risk.Why = "Ce programme se charge à la place d'un composant de Windows, dans ton compte (détournement COM) : technique de virus pour se relancer sans droits administrateur. " + $risk.Why
                Add-SecLaunch -Rule 'com' -Title ("Composant COM détourné : {0}" -f $k.PSChildName) -Risk $risk
            }
        }
    }
    Add-SecChecked ("Composants COM du compte : {0}" -f $nC)
    if ($sync.Cancel) { return }
    # 4. Services et pilotes qui démarrent avec Windows (ou en marche)
    $nS = 0
    foreach ($cls in 'Win32_Service', 'Win32_SystemDriver') {
        foreach ($sv in @(Get-CimInstance $cls -ErrorAction SilentlyContinue | Where-Object { $_.StartMode -in 'Auto', 'Boot', 'System' -or $_.State -eq 'Running' })) {
            $nS++
            $cmd = "$($sv.PathName)"
            if ($cls -eq 'Win32_Service' -and $sv.StartMode -eq 'Auto') { [void]$script:SecAutoTexts.Add("$($sv.Name) $($sv.DisplayName) $cmd") }
            if ($cmd -match '(?i)\\svchost\.exe') {
                # Service partagé : c'est sa DLL qui compte
                $dll = ''
                foreach ($k in "HKLM:\SYSTEM\CurrentControlSet\Services\$($sv.Name)\Parameters", "HKLM:\SYSTEM\CurrentControlSet\Services\$($sv.Name)") { try { $dll = "$((Get-ItemProperty -LiteralPath $k -Name ServiceDll -ErrorAction Stop).ServiceDll)"; if ($dll) { break } } catch {} }
                if (-not $dll) { continue }
                $cmd = '"{0}"' -f [Environment]::ExpandEnvironmentVariables($dll)
            }
            $risk = Get-LaunchRisk $cmd '' "$($sv.Name)"
            if (-not $risk.Sev) { continue }
            $drv = ($cls -eq 'Win32_SystemDriver')
            $fix = if (-not $drv -and $sv.StartMode -eq 'Auto' -and "$($sv.PathName)" -notmatch '(?i)\\svchost\.exe') { @(@{ Kind = 'service'; Name = "$($sv.Name)"; Label = "$($sv.DisplayName)" }) } else { @() }
            Add-SecLaunch -Rule $(if ($drv) { 'pilote' } else { 'service' }) -Title ("{0} : {1}" -f $(if ($drv) { 'Pilote' } else { 'Service' }), $(if ($sv.DisplayName) { $sv.DisplayName } else { $sv.Name })) -Risk $risk -Fix $fix `
                -FixLabel ''
        }
    }
    Add-SecChecked ("Services et pilotes : {0}" -f $nS)
    # 5. Abonnements WMI (lancement caché sur un événement de Windows)
    $nW = 0
    try {
        foreach ($c in @(Get-CimInstance -Namespace root/subscription -ClassName __EventConsumer -ErrorAction Stop)) {
            $cls = "$($c.CimClass.CimClassName)"
            if ($cls -eq 'CommandLineEventConsumer') {
                $nW++
                $cmd = if ($c.CommandLineTemplate) { "$($c.CommandLineTemplate)" } else { "$($c.ExecutablePath)" }
                if ("$($c.Name)" -eq 'BVTConsumer' -and $cmd -match '(?i)KernCap\.vbs') { continue }   # abonnement de Windows lui-même
                $risk = Get-LaunchRisk $cmd
                $sev = if ($risk.Sev -eq 'crit' -or (Get-CommandRisk $cmd).Level -eq 'strong') { 'crit' } else { 'warn' }
                Add-SecItem -Rule 'wmi' -Cat 'autorun' -Sev $sev -Title ("Abonnement WMI : {0}" -f $c.Name) -Path $cmd `
                    -Why "Lance une commande tout seul quand un événement de Windows se produit. Méthode très utilisée par les virus pour se cacher, très rare pour un logiciel normal." `
                    -Todo "Si tu ne sais pas ce que c'est : retire-le, puis lance l'analyse hors ligne." -Fix @(@{ Kind = 'wmi'; Class = $cls; Name = "$($c.Name)" }) -FixLabel "Retirer l'abonnement"
            } elseif ($cls -eq 'ActiveScriptEventConsumer') {
                $nW++
                Add-SecItem -Rule 'wmi-script' -Cat 'autorun' -Sev 'crit' -Title ("Abonnement WMI qui lance un script : {0}" -f $c.Name) -Path "$($c.ScriptFileName)" `
                    -Why "Un script caché dans Windows se lance tout seul sur un événement. Aucun logiciel normal ne fait ça : c'est une technique de virus." `
                    -Todo "Retire-le, puis lance l'analyse hors ligne." -Fix @(@{ Kind = 'wmi'; Class = $cls; Name = "$($c.Name)" }) -FixLabel "Retirer l'abonnement"
            }
        }
    } catch {}
    Add-SecChecked ("Abonnements WMI : {0}" -f $nW)
    # 6. Détournements de programmes (IFEO « Debugger » et SilentProcessExit)
    $nI = 0
    $protect = '(?i)^(msmpeng|mpcmdrun|msascui|msascuil|securityhealth\w*|smartscreen|mbam\w*|avast\w*|avg\w*|bdagent|ekrn|egui|kav\w*|avp\w*|norton\w*|mcshield|taskmgr|regedit|procexp\w*|autoruns\w*|rstrui|mrt)\.exe$'
    foreach ($base in $script:SecIfeoBases) {
        foreach ($k in @(Get-ChildItem -LiteralPath $base -ErrorAction SilentlyContinue)) {
            $dbg = "$($k.GetValue('Debugger'))"
            if (-not $dbg.Trim()) { continue }
            $nI++
            $tgt = $k.PSChildName
            $exe = Resolve-SecPath $dbg
            $sig = if ($exe -and (Test-Path -LiteralPath $exe -PathType Leaf)) { Get-SecSig $exe } else { @{ Valid = $false; Ms = $false } }
            $acc = (($tgt -replace '(?i)\.exe$', '') -in $script:SecAccessibility)
            $bad = $acc -or (-not $sig.Valid) -or ($tgt -match $protect -and $tgt -notmatch '(?i)^(taskmgr|procexp\w*)\.exe$') -or (Get-CommandRisk $dbg).Level -eq 'strong'
            $fix = @(@{ Kind = 'ifeo'; Base = $base; Key = $tgt; Value = 'Debugger' })
            if ($bad) {
                Add-SecItem -Rule 'detournement' -Cat 'autorun' -Sev 'crit' -Title ("Détournement de {0}" -f $tgt) -Path $dbg -Fix $fix -FixLabel 'Retirer le détournement' `
                    -Why $(if ($acc) { "Quand l'outil d'accessibilité « $tgt » se lance (même depuis l'écran de connexion), Windows lance « $(($exe -split '\\')[-1]) » à la place : ça donne un accès complet au PC sans mot de passe." } else { "Quand « $tgt » se lance, Windows lance « $(($exe -split '\\')[-1]) » à la place. Les virus s'en servent pour bloquer l'antivirus ou se relancer." }) `
                    -Todo "Retire ce détournement, puis lance l'analyse hors ligne."
            } else {
                Add-SecItem -Rule 'detournement-info' -Cat 'autorun' -Sev 'info' -Title ("{0} s'ouvre avec un autre programme" -f $tgt) -Path $dbg -Fix $fix -FixLabel 'Retirer le détournement' `
                    -Why ("Quand « {0} » se lance, Windows ouvre « {1} » (signé par {2}) à la place." -f $tgt, (($exe -split '\\')[-1]), $(if ($sig.Org) { $sig.Org } else { 'un éditeur connu' })) `
                    -Todo "Normal si tu as installé un outil comme Process Explorer pour remplacer le Gestionnaire des tâches. Sinon, retire-le."
            }
        }
    }
    foreach ($k in @(Get-ChildItem -LiteralPath $script:SecSpeBase -ErrorAction SilentlyContinue)) {
        $mon = "$($k.GetValue('MonitorProcess'))"
        if (-not $mon.Trim()) { continue }
        $nI++
        $exe = Resolve-SecPath $mon
        $sig = if ($exe -and (Test-Path -LiteralPath $exe -PathType Leaf)) { Get-SecSig $exe } else { @{ Valid = $false; Ms = $false; Org = '' } }
        $fix = @(@{ Kind = 'spe'; Key = $k.PSChildName; Value = 'MonitorProcess' })
        if (-not $sig.Valid -or (Get-CommandRisk $mon).Level -eq 'strong') {
            Add-SecItem -Rule 'detournement' -Cat 'autorun' -Sev 'crit' -Title ("Programme lancé à la fermeture de {0}" -f $k.PSChildName) -Path $mon -Fix $fix -FixLabel 'Retirer le détournement' `
                -Why ("Chaque fois que « {0} » se ferme, Windows lance « {1} ». Technique de virus pour se relancer sans être vu." -f $k.PSChildName, (($exe -split '\\')[-1])) -Todo "Retire-le, puis lance l'analyse hors ligne."
        } else {
            Add-SecItem -Rule 'detournement-info' -Cat 'autorun' -Sev 'info' -Title ("Programme lancé à la fermeture de {0}" -f $k.PSChildName) -Path $mon -Fix $fix -FixLabel 'Retirer' `
                -Why ("Chaque fois que « {0} » se ferme, Windows lance « {1} » (signé par {2})." -f $k.PSChildName, (($exe -split '\\')[-1]), $(if ($sig.Org) { $sig.Org } else { 'un éditeur connu' })) -Todo "Normal pour un outil de diagnostic installé exprès. Sinon, retire-le."
        }
    }
    Add-SecChecked ("Détournements de programmes : {0}" -f $nI)
    # 7. Ouverture de session (Winlogon) et DLL chargées partout (AppInit_DLLs)
    $wl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    foreach ($v in @(@($wl, 'Shell', '(?i)^(c:\\windows\\)?explorer(\.exe)?$', 'machine'), @($wl, 'Userinit', '(?i)^(c:\\windows\\system32\\)?userinit(\.exe)?$', 'machine'),
                     @("$($su.Hkcu)\Software\Microsoft\Windows NT\CurrentVersion\Winlogon", 'Shell', '(?i)^(c:\\windows\\)?explorer(\.exe)?$', 'user'))) {
        $val = ''; try { $val = "$((Get-ItemProperty -LiteralPath $v[0] -Name $v[1] -ErrorAction Stop).($v[1]))" } catch { continue }
        foreach ($part in @($val -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
            if ($part -match $v[2]) { continue }
            $risk = Get-LaunchRisk $part
            $exe = if ($risk.Path) { $risk.Path } else { Resolve-SecPath $part }
            $sig = if ($exe -and (Test-Path -LiteralPath $exe -PathType Leaf)) { Get-SecSig $exe } else { @{ Valid = $false } }
            Add-SecItem -Rule 'winlogon' -Cat 'autorun' -Sev $(if ($sig.Valid -and $risk.Sev -ne 'crit') { 'warn' } else { 'crit' }) -Title ("Ajout à l'ouverture de session ({0})" -f $v[1]) -Path $part `
                -Why ("Windows lance « {0} » à chaque ouverture de session, en plus de son programme normal. Rare pour un logiciel honnête, fréquent pour un virus." -f (($exe -split '\\')[-1])) `
                -Todo "Si ce n'est pas un logiciel de ton entreprise ou de ton école : lance l'analyse hors ligne et fais-toi aider pour remettre Windows en état." `
                -Fix @(Get-FileFixes $exe) -FixLabel (Get-FixLabel @(Get-FileFixes $exe))
        }
    }
    foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Windows') {
        try {
            $p = Get-ItemProperty -LiteralPath $k -ErrorAction Stop
            if ([int]$p.LoadAppInit_DLLs -ne 1 -or -not "$($p.AppInit_DLLs)".Trim()) { continue }
            foreach ($d in @("$($p.AppInit_DLLs)" -split '[,; ]+' | Where-Object { $_ })) {
                $exe = Resolve-SecPath $d
                $sig = if (Test-Path -LiteralPath $exe -PathType Leaf) { Get-SecSig $exe } else { @{ Valid = $false; Org = '' } }
                Add-SecItem -Rule $(if ($sig.Valid) { 'appinit-info' } else { 'appinit' }) -Cat 'autorun' -Sev $(if ($sig.Valid) { 'info' } else { 'crit' }) -Title "DLL chargée dans tous les programmes (AppInit_DLLs)" -Path $exe `
                    -Why $(if ($sig.Valid) { "Cette DLL (signée par $($sig.Org)) est chargée dans chaque programme qui s'ouvre. Certains logiciels le font, mais c'est rare et déconseillé." } else { "Une DLL sans signature est chargée dans chaque programme qui s'ouvre : elle peut tout espionner, y compris le navigateur." }) `
                    -Todo "Si tu ne sais pas d'où elle vient : analyse-la et lance l'analyse hors ligne." -Fix @(Get-FileFixes $exe) -FixLabel (Get-FixLabel @(Get-FileFixes $exe))
            }
        } catch {}
    }
    # 8. Outils d'accessibilité de l'écran de connexion remplacés
    foreach ($n in $script:SecAccessibility) {
        $p = Join-Path $env:SystemRoot "System32\$n.exe"
        if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { continue }
        if ((Get-SecSig $p).Ms) { continue }
        Add-SecItem -Rule 'accessibilite' -Cat 'autorun' -Sev 'crit' -Title ("Outil d'accessibilité remplacé : {0}.exe" -f $n) -Path $p -Fix @(Get-FileFixes $p) -FixLabel (Get-FixLabel @(Get-FileFixes $p)) `
            -Why "Ce programme se lance depuis l'écran de connexion, avant même d'ouvrir ta session. Il n'est pas signé par Microsoft : remplacé, il donne un accès complet au PC sans mot de passe." `
            -Todo "Lance l'analyse hors ligne, puis « Réparer les fichiers de Windows » (onglet Réparation)."
    }
    Add-SecChecked "Ouverture de session, DLL chargées partout et outils d'accessibilité de l'écran de connexion"
}

# ---------------------------------------------------------------- c) Programmes en cours
function Get-SecProcesses {
    $conn = @{}
    try { foreach ($c in @(Get-NetTCPConnection -State Established -ErrorAction Stop)) { if ("$($c.RemoteAddress)" -notmatch '^(127\.|::1$|0\.0\.0\.0$|::$)') { $conn[[int]$c.OwningProcess] = $true } } } catch {}
    $script:SecProcTexts = New-Object System.Collections.ArrayList
    $seen = @{}; $n = 0
    $all = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
    $byId = @{}; foreach ($p in $all) { $byId[[int]$p.ProcessId] = $p }
    foreach ($p in $all) {
        $procId = [int]$p.ProcessId
        if ($procId -le 4 -or $procId -eq $PID) { continue }
        $n++
        $name = "$($p.Name)"; $path = "$($p.ExecutablePath)"; $cl = "$($p.CommandLine)"
        [void]$script:SecProcTexts.Add(@{ Text = "$name $path"; Path = $path })
        # Programmes .NET de Windows où les voleurs de mots de passe se cachent en mémoire (RegAsm, AppLaunch, MSBuild…) :
        # signalés quand ils tournent sans outil de développement pour les lancer
        if ($name -match $script:SecLolBins) {
            $par = $byId[[int]$p.ParentProcessId]
            $parName = if ($par) { "$($par.Name)" } else { '' }
            if ($parName -notmatch $script:SecDevTools) {
                $net = $conn.ContainsKey($procId)
                $k = "lol|$name|$procId"
                if (-not $seen.ContainsKey($k)) {
                    $seen[$k] = $true
                    Add-SecItem -Rule 'programme-detourne' -Cat 'process' -Sev $(if ($net) { 'crit' } else { 'warn' }) -Title ("Programme de Windows peut-être détourné : {0}" -f $name) -Path $path `
                        -Why ("Les voleurs de mots de passe se cachent souvent dans ce programme de Windows pour ne pas être vus. Il tourne sans outil de développement pour l'avoir lancé{0}{1}." -f $(if ($parName) { " (lancé par « $parName »)" } else { ' (son programme de départ a disparu)' }), $(if ($net) { ', et il est connecté à Internet' } else { '' })) `
                        -Todo "Si tu ne programmes pas en .NET : coche-le pour l'arrêter, redémarre le PC et relance l'analyse. S'il revient, l'infection est toujours là." `
                        -Fix @(@{ Kind = 'stop'; Pid = $procId; Name = $name }) -FixLabel 'Arrêter le programme'
                }
            }
            continue
        }
        $isHost = ($name -match $script:SecHostExe)
        if ($isHost) { if (-not $cl) { continue }; $risk = Get-LaunchRisk $cl }
        elseif ($path) { $risk = Get-LaunchRisk ('"{0}"' -f $path) }
        elseif ((Test-Masquerade $name '') -like 'like:*') { $risk = @{ Sev = 'warn'; Why = ("Nom presque identique à un programme de Windows ; son emplacement n'est pas lisible."); Path = $name; Exists = $false } }
        else { continue }
        if (-not $risk.Sev) { continue }
        $key = ("{0}|{1}" -f $risk.Path, $risk.Why).ToLowerInvariant()
        if ($seen.ContainsKey($key)) { continue }; $seen[$key] = $true
        $sev = $risk.Sev; $why = $risk.Why
        # Connexion Internet : dite clairement, mais ne rend pas « critique » à elle seule (beaucoup de logiciels honnêtes
        # sans signature sont connectés ; une fausse alerte critique ferait croire à un piratage)
        if ($conn.ContainsKey($procId)) { $why += " Il est connecté à Internet en ce moment." }
        $fix = if ($risk.Exists -and (($risk.Path -split '\\')[-1] -notmatch $script:SecHostExe)) { @(Get-FileFixes $risk.Path) } else { @() }
        Add-SecItem -Rule $(if ($isHost) { 'commande' } else { 'programme' }) -Cat 'process' -Sev $sev -Title $(if ($isHost) { "Commande à risque en cours : $name" } else { "Programme suspect en cours : $name" }) -Path $risk.Path -Why $why `
            -Todo $(if ($sev -eq 'crit') { "Si tu ne le reconnais pas : coche-le (il est arrêté et mis en quarantaine), change tes mots de passe depuis ton téléphone, puis lance l'analyse hors ligne." } else { "Si tu ne le reconnais pas : coche-le, ou envoie le rapport au développeur pour avoir son avis." }) `
            -Fix $fix -FixLabel (Get-FixLabel $fix)
    }
    Add-SecChecked ("Programmes en cours : {0}" -f $n)
}

# ---------------------------------------------------------------- c bis) Programmes lancés ces 7 derniers jours (Windows les note dans le registre « BAM »)
# Montre ce qui relance une infection même si le programme ne tourne plus pendant l'analyse, ou s'est effacé après coup.
function Convert-BamPath([string]$Device) {
    if ($Device -notmatch '^\\Device\\HarddiskVolume\d+(\\.+)$') { return '' }
    $rest = $matches[1]
    foreach ($d in @([IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' })) { $c = $d.Name.TrimEnd('\') + $rest; if (Test-Path -LiteralPath $c) { return $c } }
    return ($env:SystemDrive + $rest)   # fichier effacé depuis : très probablement sur le disque de Windows
}
function Get-SecRecent {
    $base = @('HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings', 'HKLM:\SYSTEM\CurrentControlSet\Services\bam\UserSettings') | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $base) { Add-SecChecked "Programmes lancés récemment : non disponible sur cette version de Windows"; return }
    $since = (Get-Date).AddDays(-7); $n = 0
    $known = @{}; foreach ($x in @($script:SecItems)) { if ($x.Path) { $known[("$($x.Path)" -split ' · ')[0].ToLowerInvariant()] = $true } }
    foreach ($u in @(Get-ChildItem -LiteralPath $base -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^S-1-5-21-' })) {
        foreach ($vn in @($u.GetValueNames() | Where-Object { $_ -like '\Device\*' })) {
            $data = $u.GetValue($vn)
            if ($data -isnot [byte[]] -or $data.Length -lt 8) { continue }
            $when = $null; try { $when = [DateTime]::FromFileTime([BitConverter]::ToInt64($data, 0)) } catch { continue }
            if ($when -lt $since) { continue }
            $path = Convert-BamPath $vn
            if (-not $path) { continue }
            $zone = Get-PathZone $path @() $env:SystemDrive
            if (-not $script:SecZoneLabels.ContainsKey($zone)) { continue }
            $n++
            if ($known.ContainsKey($path.ToLowerInvariant())) { continue }
            $name = ($path -split '\\')[-1]
            if (Test-Path -LiteralPath $path -PathType Leaf) {
                $risk = Get-LaunchRisk ('"{0}"' -f $path)
                if (-not $risk.Sev) { continue }
                $fix = @(Get-FileFixes $path)
                Add-SecItem -Rule 'lance-recemment' -Cat 'process' -Sev $risk.Sev -Title ("Lancé récemment : {0}" -f $name) -Path $path -Why ("{0} Dernier lancement le {1:dd/MM à HH:mm}." -f $risk.Why, $when) `
                    -Todo "Si tu ne le reconnais pas : coche-le (quarantaine), puis lance l'analyse hors ligne." -Fix $fix -FixLabel (Get-FixLabel $fix)
            } elseif (($zone -in 'temp', 'downloads', 'public' -or (Get-SuspiciousPlacement $path)) -and -not (Test-UninstallerName $name)) {
                Add-SecItem -Rule 'trace-recente' -Cat 'process' -Sev 'warn' -Title ("Trace : {0} lancé puis effacé" -f $name) -Path $path `
                    -Why ("Lancé le {0:dd/MM à HH:mm} depuis {1}, puis supprimé. C'est souvent un morceau de virus qui se télécharge, s'exécute et s'efface." -f $when, $script:SecZoneLabels[$zone]) `
                    -Todo "Si de nouvelles traces apparaissent après un redémarrage, l'infection est toujours là : lance l'analyse hors ligne, ou réinstalle Windows."
            }
        }
    }
    Add-SecChecked ("Programmes lancés ces 7 derniers jours depuis Temp, AppData ou Téléchargements : {0}" -f $n)
}

# ---------------------------------------------------------------- d) Accès à distance et comptes
function Get-SecRemote {
    $tools = [ordered]@{}
    $note = {
        param($T, [string]$What, $App, [string]$Path)
        if (-not $T) { return }
        if (-not $tools.Contains($T.Name)) { $tools[$T.Name] = @{ Name = $T.Name; Kind = $T.Kind; App = $null; Running = $false; Auto = $false; Path = '' } }
        $x = $tools[$T.Name]
        if ($What -eq 'app') { $x.App = $App } elseif ($What -eq 'run') { $x.Running = $true } elseif ($What -eq 'auto') { $x.Auto = $true }
        if ($Path -and -not $x.Path) { $x.Path = $Path }
    }
    # Logiciels installés (tout le PC + compte de la personne)
    $su = Get-SessionUser
    $userKey = "$($su.Hkcu)\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', $userKey) {
        foreach ($e in @(Get-ItemProperty $k -ErrorAction SilentlyContinue)) {
            if (-not $e.DisplayName) { continue }
            $t = Get-RemoteToolName ("{0} {1}" -f $e.DisplayName, $e.Publisher)
            if ($t) { & $note $t 'app' @{ Name = "$($e.DisplayName)".Trim(); Cmd = "$($e.UninstallString)"; PerUser = ($k -eq $userKey) } '' }
        }
    }
    foreach ($x in @($script:SecProcTexts)) { & $note (Get-RemoteToolName $x.Text) 'run' $null $x.Path }
    foreach ($x in @($script:SecAutoTexts)) { & $note (Get-RemoteToolName $x) 'auto' $null '' }
    foreach ($x in $tools.Values) {
        $st = @($(if ($x.App) { 'installé' }), $(if ($x.Running) { 'en marche' }), $(if ($x.Auto) { 'lancé au démarrage' }) | Where-Object { $_ }) -join ', '
        if ($x.Kind -eq 'rat') {
            Add-SecItem -Rule 'rat' -Cat 'remote' -Sev 'crit' -Title ("Cheval de Troie connu : {0}" -f $x.Name) -Path $x.Path `
                -Why ("C'est le nom d'un programme qui permet à un pirate de contrôler le PC et de voler tes comptes ({0})." -f $st) `
                -Todo "Change tes mots de passe depuis ton téléphone, puis lance l'analyse hors ligne." `
                -Fix @(Get-FileFixes $x.Path) -FixLabel (Get-FixLabel @(Get-FileFixes $x.Path))
            continue
        }
        $sev = if ($x.Auto -or ($x.Running -and -not $x.App)) { 'warn' } else { 'info' }
        $fix = if ($x.App -and $x.App.Cmd) { @(@{ Kind = 'uninstall'; Cmd = $x.App.Cmd; Name = $x.App.Name; PerUser = [bool]$x.App.PerUser }) } else { @() }
        Add-SecItem -Rule 'prise-en-main' -Cat 'remote' -Sev $sev -Title ("{0} : prise en main à distance ({1})" -f $x.Name, $st) -Path $x.Path `
            -Why "Ce logiciel permet à quelqu'un de contrôler ton PC à distance. Pratique pour se faire aider, mais c'est aussi l'outil n°1 des arnaques au faux support technique." `
            -Todo $(if ($x.App) { "Si ce n'est pas toi qui l'as installé, désinstalle-le." } else { "Si ce n'est pas toi qui l'as lancé, ferme-le et supprime son fichier." }) -Fix $fix -FixLabel 'Désinstaller'
    }
    Add-SecChecked ("Logiciels de prise en main à distance : {0}" -f $(if ($tools.Count) { $tools.Count } else { 'aucun' }))
    # Bureau à distance
    try {
        if ([int](Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -ErrorAction Stop).fDenyTSConnections -eq 0) {
            Add-SecItem -Rule 'bureau-distance' -Cat 'remote' -Sev 'warn' -Title "Le Bureau à distance est activé" -Why "Quelqu'un qui connaît le mot de passe d'un compte peut prendre la main sur le PC depuis le réseau." `
                -Todo "Si tu ne t'en sers pas : Paramètres > Système > Bureau à distance > Désactivé."
        }
    } catch {}
    # Comptes
    try {
        foreach ($u in @(Get-LocalUser -ErrorAction Stop | Where-Object { $_.Enabled })) {
            $sid = "$($u.SID)"
            if ($sid -match '-500$') { Add-SecItem -Rule 'compte-admin' -Cat 'remote' -Sev 'warn' -Title "Le compte Administrateur intégré est activé" -Why "Ce compte caché a tous les droits et il est la cible n°1 des attaques par mot de passe." -Todo "Si tu ne l'as pas activé exprès : invite de commandes en administrateur, « net user administrateur /active:no »." }
            elseif ($sid -match '-501$') { Add-SecItem -Rule 'compte-invite' -Cat 'remote' -Sev 'warn' -Title "Le compte Invité est activé" -Why "N'importe qui peut ouvrir une session sur le PC sans mot de passe." -Todo "Si tu ne l'as pas activé exprès : invite de commandes en administrateur, « net user invité /active:no »." }
        }
    } catch {}
    try {
        $adm = @(Get-LocalGroupMember -SID 'S-1-5-32-544' -ErrorAction Stop | ForEach-Object { ("$($_.Name)" -split '\\')[-1] })
        if ($adm.Count) {
            Add-SecItem -Rule 'admins' -Cat 'remote' -Sev 'info' -Title ("Comptes administrateurs : {0}" -f $adm.Count) -Path ($adm -join ', ') `
                -Why "Ces comptes peuvent tout modifier sur le PC." -Todo "Vérifie que tu les connais tous. Un compte inconnu ici est un très mauvais signe."
        }
    } catch {}
    Add-SecChecked "Bureau à distance et comptes du PC"
}

# ---------------------------------------------------------------- e) Téléchargements à risque (Téléchargements + Bureau, 60 jours)
function Get-SecDownloads([string[]]$Dirs = @()) {
    if (-not @($Dirs | Where-Object { $_ }).Count) { $Dirs = @(@((Get-SessionFolder 'Downloads'), (Get-SessionFolder 'Desktop'), (Get-SessionFolder 'Personal')) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique) }
    $since = (Get-Date).AddDays(-60); $n = 0
    foreach ($d in $Dirs) {
        $files = New-Object System.Collections.ArrayList
        foreach ($f in @(Get-ChildItem -LiteralPath $d -File -Force -ErrorAction SilentlyContinue)) { [void]$files.Add($f) }
        foreach ($sub in @(Get-ChildItem -LiteralPath $d -Directory -Force -ErrorAction SilentlyContinue | Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) } | Select-Object -First 300)) {
            # Dossier récent au nom de cheat, de crack ou de mod menu (souvent une archive décompressée)
            if (($sub.LastWriteTime -ge $since -or $sub.CreationTime -ge $since) -and $sub.Name -match $script:BaitNames) {
                Add-SecItem -Rule 'dossier-appat' -Cat 'download' -Sev 'warn' -Title ("Dossier de cheat, crack ou mod menu : {0}" -f $sub.Name) -Path $sub.FullName `
                    -Why "Ce dossier récent porte le nom d'un cheat, d'un crack ou d'un mod menu : le piège n°1 des voleurs de mots de passe (le virus est souvent caché dedans)." `
                    -Todo "Si tu as lancé un programme de ce dossier : change tes mots de passe depuis ton téléphone et lance l'analyse hors ligne. Dans tous les cas, supprime ce dossier sans rien ouvrir."
            }
            foreach ($f in @(Get-ChildItem -LiteralPath $sub.FullName -File -Force -ErrorAction SilentlyContinue | Select-Object -First 500)) { [void]$files.Add($f) }
        }
        foreach ($f in $files) {
            if ($f.Name -notmatch $script:RiskyDlExt) { continue }
            if ($f.LastWriteTime -lt $since -and $f.CreationTime -lt $since) { continue }
            $n++
            $flags = @(Test-RiskyDownloadName $f.Name | ForEach-Object { $_ })
            $sev = ''; $why = New-Object System.Collections.ArrayList; $rule = ''
            if ($f.Extension -ieq '.lnk') {
                $sc = Get-ShortcutInfo $f.FullName
                if ($sc -and (($sc.Target -split '\\')[-1]) -match $script:SecHostExe) {
                    $risk = Get-CommandRisk ('"{0}" {1}' -f $sc.Target, $sc.Args)
                    if ($risk.Level -or $sc.Args -match '(?i)https?:|\\\\[a-z0-9.-]+\\') {
                        $sev = 'crit'; $rule = 'raccourci-piege'
                        [void]$why.Add(("Ce raccourci lance « {0} » avec une commande cachée{1}. Un vrai raccourci ne fait jamais ça." -f (($sc.Target -split '\\')[-1]), $(if ($risk.Reasons.Count) { ' (' + ($risk.Reasons -join ', ') + ')' } else { '' })))
                    }
                }
            }
            $big = ($f.Extension -match '(?i)^\.(exe|scr|msi)$' -and $f.Length -gt 400MB)
            $sig = if ($flags -contains 'double' -or $flags -contains 'rlo' -or $big) { Get-SecSig $f.FullName } else { @{ Valid = $false } }
            if (($flags -contains 'rlo' -or $flags -contains 'double') -and -not $sig.Valid) {
                $sev = 'crit'; if (-not $rule) { $rule = 'fausse-extension' }
                [void]$why.Add("Le nom cache la vraie extension : ça ressemble à un document ou une image, mais c'est un programme.")
            }
            if ($flags -contains 'appat') {
                if (-not $sev) { $sev = 'warn' }; if (-not $rule) { $rule = 'appat' }
                [void]$why.Add("Le nom fait penser à un cheat, un crack ou un générateur : c'est le piège n°1 des voleurs de mots de passe (comme les faux cheats GTA).")
            }
            if ($big -and -not $sig.Valid) {
                if (-not $sev) { $sev = 'warn' }; if (-not $rule) { $rule = 'gonfle' }
                [void]$why.Add("Programme sans signature de plus de 400 Mo : les virus se gonflent exprès pour que les antivirus ne les analysent pas.")
            }
            if (-not $sev) { continue }
            $org = Get-ZoneOrigin $f.FullName
            if ($org) { [void]$why.Add("Téléchargé depuis : $org.") }
            Add-SecItem -Rule $rule -Cat 'download' -Sev $sev -Title $f.Name -Path $f.FullName -Why ($why -join ' ') -Fix @(Get-FileFixes $f.FullName) -FixLabel 'Mettre en quarantaine' `
                -Todo "Si tu l'as ouvert : mets-le en quarantaine, change tes mots de passe depuis ton téléphone et lance l'analyse hors ligne. Sinon, mets-le en quarantaine sans l'ouvrir."
        }
    }
    Add-SecChecked ("Téléchargements, Bureau et Documents (60 derniers jours) : {0} programme(s), archive(s) ou raccourci(s)" -f $n)
}

# ---------------------------------------------------------------- f) Mots de passe en clair (le nom des fichiers n'est JAMAIS écrit dans le journal)
function Get-SecSecrets([string[]]$Dirs = @()) {
    if (-not @($Dirs | Where-Object { $_ }).Count) { $Dirs = @(@((Get-SessionFolder 'Desktop'), (Get-SessionFolder 'Personal'), (Get-SessionFolder 'Downloads')) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique) }
    $n = 0; $seen = 0; $t0 = Get-Date
    $queue = New-Object System.Collections.Queue
    foreach ($d in $Dirs) { $queue.Enqueue(@($d, 0)) }
    while ($queue.Count -and $seen -lt 30000 -and ((Get-Date) - $t0).TotalSeconds -lt 25) {
        $x = $queue.Dequeue()
        foreach ($e in @(Get-ChildItem -LiteralPath $x[0] -Force -ErrorAction SilentlyContinue)) {
            $seen++
            if ($e.PSIsContainer) { if ($x[1] -lt 2 -and -not ($e.Attributes -band [IO.FileAttributes]::ReparsePoint)) { $queue.Enqueue(@($e.FullName, ($x[1] + 1))) }; continue }
            if (-not (Test-SecretFileName $e.Name)) { continue }
            $n++
            Add-SecItem -Rule 'mots-de-passe' -Cat 'secret' -Sev 'warn' -Title $e.Name -Path $e.FullName -Secret `
                -Why "Le nom de ce fichier fait penser à des mots de passe ou des codes de secours. Les voleurs de mots de passe cherchent exactement ce genre de fichier." `
                -Todo "Range ces infos dans un gestionnaire de mots de passe (Bitwarden, celui de ton navigateur ou de ton téléphone), supprime le fichier puis vide la corbeille."
        }
    }
    Add-SecChecked ("Fichiers de mots de passe en clair (Bureau, Documents, Téléchargements) : {0}" -f $n)
}

# ---------------------------------------------------------------- Analyse complète
function Invoke-SecurityScan {
    Step "Analyse de sécurité approfondie (lecture seule : rien n'est modifié)"
    $sync.SecReport = $null
    $script:SecItems = New-Object System.Collections.ArrayList
    $script:SecChecked = New-Object System.Collections.ArrayList
    $script:SecSigCache = @{}
    $script:AeroxHashes = $null
    $script:SecAutoTexts = New-Object System.Collections.ArrayList
    $script:SecProcTexts = New-Object System.Collections.ArrayList
    $script:SecDefOn = Test-DefenderActive
    $steps = @(@('Antivirus', 'Get-SecDefender'), @('Lancements automatiques cachés', 'Get-SecAutoruns'), @('Programmes en cours', 'Get-SecProcesses'), @('Programmes lancés récemment', 'Get-SecRecent'),
               @('Accès à distance et comptes', 'Get-SecRemote'), @('Téléchargements à risque', 'Get-SecDownloads'), @('Mots de passe en clair', 'Get-SecSecrets'))
    $i = 0
    foreach ($s in $steps) {
        if ($sync.Cancel) { return }
        $sync.Progress = [math]::Round(100 * $i / $steps.Count); $i++
        Log ("   … {0}" -f $s[0])
        try { & $s[1] }
        catch { Write-Bug -Context "Sécurité / $($s[0])" -ErrorRecord $_; Log ("   ⚠ Vérification « {0} » incomplète : {1}" -f $s[0], $_.Exception.Message); Add-SecChecked ("{0} : vérification incomplète" -f $s[0]) }
    }
    # Système détourné : déjà vérifié par le diagnostic (onglet Diagnostic), seulement résumé ici
    try { $h = @(Get-HostsHijacks); Add-SecChecked $(if ($h.Count) { "Fichier hosts : {0} site(s) détourné(s), voir le diagnostic" -f $h.Count } else { 'Fichier hosts : aucun site important détourné' }) } catch {}
    try { $px = Get-UserProxy; if ($px) { Add-SecChecked $(if (($px.Enable -eq 1 -and $px.Server) -or $px.Pac) { 'Proxy : actif, voir le diagnostic' } else { 'Proxy : aucun, connexion directe' }) } } catch {}
    $sync.Progress = 100
    # Numéros dans l'ordre d'affichage (catégorie, puis gravité) : le développeur peut répondre « coche 2, 5 et 7 »
    $items = @(foreach ($c in $script:SecCats.Keys) { @($script:SecItems | Where-Object { $_.Cat -eq $c } | Sort-Object @{ Expression = { @{ crit = 0; warn = 1; info = 2 }[$_.Sev] } }) })
    $k = 0; foreach ($x in $items) { $k++; $x.Num = $k }
    $v = Get-SecVerdict $items
    $sync.SecReport = @{ Items = $items; Checked = @($script:SecChecked); Verdict = $v; Date = (Get-Date); Code = (New-SecCode) }
    # Statistiques anonymes : seulement le type de signe trouvé (« probleme:secu-tache »)
    foreach ($r in @($items | Where-Object { $_.Sev -ne 'info' } | ForEach-Object { $_.Rule } | Select-Object -Unique)) { Add-StatsEvent ("probleme:secu-" + (ConvertTo-StatsId $r)) }
    # Journal : des nombres seulement (jamais de nom de fichier)
    foreach ($c in $script:SecCats.Keys) {
        $g = @($items | Where-Object { $_.Cat -eq $c -and $_.Sev -ne 'info' })
        if ($g.Count) { Log ("   {0} {1} : {2} élément(s)" -f $(if (@($g | Where-Object { $_.Sev -eq 'crit' }).Count) { '❌' } else { '⚠' }), $script:SecCats[$c], $g.Count) }
    }
    Log ("{0} : {1} critique(s), {2} à vérifier, {3} pour info." -f $v.Title, @($items | Where-Object { $_.Sev -eq 'crit' }).Count, @($items | Where-Object { $_.Sev -eq 'warn' }).Count, @($items | Where-Object { $_.Sev -eq 'info' }).Count)
}

# Code du rapport (6 caractères sans 0/O ni 1/I) : la personne le donne au développeur sur Discord
function New-SecCode { $a = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; $r = New-Object Random; return (-join (1..6 | ForEach-Object { $a[$r.Next($a.Length)] })) }
# Rapport à copier ou à envoyer : les chemins des comptes sont masqués, les fichiers de mots de passe seulement comptés
function Get-SecReportText($Report) {
    if (-not $Report) { return '' }
    $mask = { param([string]$T) return ("$T" -replace '(?i)([a-z]:\\users\\)(?!public\\)[^\\]+', '$1…') }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine(("AEROX PC Care {0} : analyse de sécurité du {1}" -f $AppInfo.Version, $Report.Date.ToString('dd/MM/yyyy HH:mm')))
    [void]$sb.AppendLine(("Verdict : {0}" -f $Report.Verdict.Title))
    if ($Report.Code) { [void]$sb.AppendLine(("Code du rapport : {0}" -f $Report.Code)) }
    foreach ($c in $script:SecCats.Keys) {
        $g = @($Report.Items | Where-Object { $_.Cat -eq $c })
        if (-not $g.Count) { continue }
        [void]$sb.AppendLine(''); [void]$sb.AppendLine(("== {0}" -f $script:SecCats[$c]))
        if ($c -eq 'secret') { [void]$sb.AppendLine(("{0} fichier(s) dont le nom fait penser à des mots de passe (noms non copiés)." -f $g.Count)); continue }
        foreach ($x in $g) {
            $lab = @{ crit = 'CRITIQUE'; warn = 'À VÉRIFIER'; info = 'INFO' }[$x.Sev]
            $title = if ($x.Rule -eq 'admins') { 'Comptes administrateurs (noms non copiés)' } else { & $mask $x.Title }
            [void]$sb.AppendLine(("{0}[{1}] {2}" -f $(if ($x.Num) { "n° $($x.Num) " } else { '' }), $lab, $title))
            if ($x.Path -and $x.Rule -ne 'admins') { [void]$sb.AppendLine(("   {0}" -f (& $mask $x.Path))) }
            if ($x.Why) { [void]$sb.AppendLine(("   Pourquoi : {0}" -f (& $mask $x.Why))) }
            if ($x.Todo) { [void]$sb.AppendLine(("   Quoi faire : {0}" -f $x.Todo)) }
            if ($x.Fix -and $x.FixLabel) { [void]$sb.AppendLine(("   Correction possible : {0}" -f $x.FixLabel)) }
        }
    }
    [void]$sb.AppendLine(''); [void]$sb.AppendLine('== Ce qui a été vérifié')
    foreach ($t in @($Report.Checked)) { [void]$sb.AppendLine(("- {0}" -f $t)) }
    return $sb.ToString()
}

# ---------------------------------------------------------------- Correctifs choisis (AEROX ne supprime jamais de fichier)
function Repair-SecurityItems([string[]]$Ids) {
    Step ("Traitement de {0} élément(s) de sécurité" -f @($Ids).Count)
    $rep = $sync.SecReport
    if (-not $rep) { Add-TaskError -Title "Rien à traiter" -Cause "Le résultat de l'analyse de sécurité n'est plus en mémoire." -FixLabel "Relancer l'analyse" -FixAction 'Invoke-SecurityScan'; return }
    $sel = @($rep.Items | Where-Object { $_ -and $Ids -contains $_.Id -and $_.Fix })
    $acts = @(foreach ($it in $sel) { foreach ($fx in @($it.Fix)) { @{ Item = $it; Fix = $fx } } })
    $crit = @($sel | Where-Object { $_.Sev -eq 'crit' }).Count -gt 0
    # 1. D'abord les analyses Defender, s'il est actif (Defender met en quarantaine ce qui est un virus connu)
    $files = @($acts | Where-Object { $_.Fix.Kind -eq 'scan' } | ForEach-Object { $_.Fix.File } | Select-Object -Unique)
    if ($files.Count -and -not (Test-DefenderActive)) {
        Log "   • Windows Defender n'est pas actif sur ce PC (un autre antivirus le remplace peut-être) : pas d'analyse Defender. La quarantaine AEROX empêche quand même les fichiers de se lancer."
        $files = @()
    }
    if ($files.Count) {
        $t0 = (Get-Date).AddSeconds(-5); $ok = 0
        foreach ($f in $files) {
            if ($sync.Cancel) { return }
            $nm = ($f -split '\\')[-1]
            if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { Log ("   • « {0} » n'existe plus : rien à analyser." -f $nm); continue }
            Log ("   Analyse Defender de « {0} »…" -f $nm)
            try { Start-MpScan -ScanType CustomScan -ScanPath $f -ErrorAction Stop; $ok++ } catch { Log ("   ⚠ Analyse impossible : {0}" -f $_.Exception.Message) }
        }
        $found = @(); try { $found = @(Get-MpThreatDetection -ErrorAction Stop | Where-Object { $_.InitialDetectionTime -ge $t0 }) } catch {}
        if ($found.Count) {
            $crit = $true
            Log ("   ❌ Defender a trouvé {0} menace(s) et s'en occupe (quarantaine). Change tes mots de passe depuis ton téléphone." -f @($found | Group-Object ThreatID).Count)
            Add-Change -Kind 'info' -Title ("Analyse de sécurité : Defender a trouvé {0} menace(s)" -f @($found | Group-Object ThreatID).Count)
        } elseif ($ok) { Log ("   ✔ {0} fichier(s) analysé(s) : Defender n'a rien trouvé. Un virus très récent peut encore passer inaperçu : en cas de doute, ne les ouvre pas et supprime-les." -f $ok) }
    }
    # 2. Quarantaine AEROX : avec n'importe quel antivirus (annulable dans l'historique)
    $quar = @($acts | Where-Object { $_.Fix.Kind -eq 'quarantine' } | ForEach-Object { $_.Fix.File } | Select-Object -Unique)
    if ($quar.Count -and -not $sync.Cancel) { Step ("Mise en quarantaine de {0} fichier(s)" -f $quar.Count) }
    foreach ($f in $quar) {
        if ($sync.Cancel) { return }
        $nm = ($f -split '\\')[-1]
        if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { Log ("   • « {0} » n'est plus là (déjà traité par l'antivirus ?) : rien à mettre en quarantaine." -f $nm); continue }
        try { [void](Move-ToQuarantine $f); Log ("   ✔ « {0} » est en quarantaine : il ne peut plus se lancer." -f $nm) }
        catch { Add-TaskError -Title ("Impossible de mettre « {0} » en quarantaine" -f $nm) -Cause $_.Exception.Message -Effect "Le fichier est toujours à sa place." -Steps @("Redémarre le PC, puis relance l'analyse de sécurité et réessaie.", "Si ça bloque toujours, lance l'analyse hors ligne (onglet Sécurité).") }
    }
    # 3. Désactivations (annulables dans l'historique)
    $st = @($acts | Where-Object { $_.Fix.Kind -eq 'startup' } | ForEach-Object { $_.Fix.Id } | Select-Object -Unique)
    if ($st.Count -and -not $sync.Cancel) { Set-StartupApps -Disable $st }
    $bg = @($acts | Where-Object { $_.Fix.Kind -in 'task', 'service' } | ForEach-Object { if ($_.Fix.Kind -eq 'task') { "task|{0}|{1}|{2}" -f $_.Fix.Path, $_.Fix.Name, ($_.Fix.Label -replace '\|', '/') } else { "service||{0}|{1}" -f $_.Fix.Name, ($_.Fix.Label -replace '\|', '/') } } | Select-Object -Unique)
    if ($bg.Count -and -not $sync.Cancel) { Disable-BgItems -Items $bg }
    # 4. Retraits sans annulation : notés dans l'historique, jamais dans la liste des annulations
    $other = @($acts | Where-Object { $_.Fix.Kind -in 'exclusion', 'wmi', 'ifeo', 'spe', 'policy', 'mppref', 'runvalue', 'stop' })
    if ($other.Count) { Step "Retrait des réglages dangereux" }
    foreach ($a in $other) {
        if ($sync.Cancel) { return }
        $fx = $a.Fix
        try {
            switch ($fx.Kind) {
                'exclusion' {
                    $prop = @{ path = 'ExclusionPath'; ext = 'ExclusionExtension'; process = 'ExclusionProcess' }[$fx.Type]
                    if (-not $prop) { throw "type d'exclusion inconnu" }
                    $p = @{}; $p[$prop] = $fx.Value
                    Remove-MpPreference @p -ErrorAction Stop
                    if (@((Get-MpPreference -ErrorAction Stop).$prop) -contains $fx.Value) { throw "Windows a gardé l'exclusion (protection contre les falsifications, ou réglage imposé par une entreprise)." }
                    Log ("   ✔ Exclusion retirée : {0}" -f $fx.Value)
                    Add-Change -Kind 'info' -Title "Exclusion retirée de l'antivirus" -Detail $fx.Value
                }
                'wmi' {
                    if ($fx.Class -notin 'CommandLineEventConsumer', 'ActiveScriptEventConsumer') { throw "type d'abonnement inconnu" }
                    $cons = @(Get-CimInstance -Namespace root/subscription -ClassName $fx.Class -ErrorAction Stop | Where-Object { "$($_.Name)" -eq $fx.Name })
                    if (-not $cons.Count) { Log ("   • Abonnement « {0} » déjà retiré." -f $fx.Name); break }
                    $binds = @(Get-CimInstance -Namespace root/subscription -ClassName __FilterToConsumerBinding -ErrorAction SilentlyContinue)
                    $mine = @($binds | Where-Object { "$($_.Consumer.Name)" -eq $fx.Name })
                    $filters = @($mine | ForEach-Object { "$($_.Filter.Name)" } | Where-Object { $_ } | Select-Object -Unique)
                    $detail = @($cons | ForEach-Object { if ($_.CommandLineTemplate) { "$($_.CommandLineTemplate)" } else { "$($_.ScriptFileName)" } }) -join ' · '
                    foreach ($b in $mine) { Remove-CimInstance -InputObject $b -ErrorAction Stop }
                    foreach ($c in $cons) { Remove-CimInstance -InputObject $c -ErrorAction Stop }
                    foreach ($fn in $filters) {
                        if (@($binds | Where-Object { "$($_.Filter.Name)" -eq $fn -and "$($_.Consumer.Name)" -ne $fx.Name }).Count) { continue }
                        foreach ($fi in @(Get-CimInstance -Namespace root/subscription -ClassName __EventFilter -ErrorAction SilentlyContinue | Where-Object { "$($_.Name)" -eq $fn })) { Remove-CimInstance -InputObject $fi -ErrorAction SilentlyContinue }
                    }
                    Log ("   ✔ Abonnement WMI retiré : {0}" -f $fx.Name)
                    Add-Change -Kind 'info' -Title ("Abonnement WMI retiré : {0}" -f $fx.Name) -Detail $detail
                }
                { $_ -in 'ifeo', 'spe' } {
                    $base = if ($fx.Kind -eq 'spe') { $script:SecSpeBase } else { $fx.Base }
                    if ($fx.Kind -eq 'ifeo' -and $script:SecIfeoBases -notcontains $base) { throw "emplacement inattendu" }
                    if (-not $fx.Key -or $fx.Key -match '[\\/]' -or $fx.Value -notin 'Debugger', 'MonitorProcess') { throw "élément inattendu" }
                    $k = Join-Path $base $fx.Key
                    $old = "$((Get-ItemProperty -LiteralPath $k -Name $fx.Value -ErrorAction Stop).($fx.Value))"
                    Remove-ItemProperty -LiteralPath $k -Name $fx.Value -ErrorAction Stop
                    Log ("   ✔ Détournement de « {0} » retiré." -f $fx.Key)
                    Add-Change -Kind 'info' -Title ("Détournement de « {0} » retiré" -f $fx.Key) -Detail ("{0} = {1}" -f $fx.Value, $old)
                }
                'mppref' {
                    Set-MpPreference -DisableRealtimeMonitoring $false -DisableIOAVProtection $false -DisableScriptScanning $false -DisableBehaviorMonitoring $false -DisableBlockAtFirstSeen $false -ErrorAction Stop
                    Start-Sleep -Seconds 2
                    $st = Get-MpComputerStatus -ErrorAction Stop
                    if (-not $st.RealTimeProtectionEnabled) { throw "Windows a gardé la protection coupée (stratégie d'entreprise, ou réglage verrouillé)." }
                    Log "   ✔ Protections de l'antivirus remises."
                    Add-Change -Kind 'info' -Title "Protections de Windows Defender remises" -Detail "Protection en temps réel, analyse des téléchargements et des scripts, surveillance des comportements, blocage des fichiers inconnus."
                }
                'runvalue' {
                    # Ligne de démarrage dont le programme n'existe plus : seulement dans les clés Run connues, et si le fichier manque toujours
                    $okKeys = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce',
                                "$((Get-SessionUser).Hkcu)\Software\Microsoft\Windows\CurrentVersion\Run", "$((Get-SessionUser).Hkcu)\Software\Microsoft\Windows\CurrentVersion\RunOnce")
                    if ($okKeys -notcontains $fx.Key) { throw "emplacement inattendu" }
                    $cmd = "$((Get-ItemProperty -LiteralPath $fx.Key -Name $fx.Name -ErrorAction Stop).($fx.Name))"
                    $tgt = Resolve-SecPath $cmd
                    if ($tgt -match '^[A-Za-z]:\\' -and (Test-Path -LiteralPath $tgt)) { throw "le programme existe de nouveau : la ligne est gardée" }
                    Remove-ItemProperty -LiteralPath $fx.Key -Name $fx.Name -ErrorAction Stop
                    Log ("   ✔ Ligne de démarrage vide retirée : {0}" -f $fx.Name)
                    Add-Change -Kind 'info' -Title ("Ligne de démarrage vide retirée : {0}" -f $fx.Name) -Detail ("{0} : {1} = {2}" -f $fx.Key, $fx.Name, $cmd)
                }
                'stop' {
                    $pr = Get-CimInstance Win32_Process -Filter ("ProcessId={0}" -f [int]$fx.Pid) -ErrorAction SilentlyContinue
                    if (-not $pr -or "$($pr.Name)" -ne $fx.Name) { Log ("   • « {0} » ne tourne plus." -f $fx.Name); break }
                    Stop-Process -Id ([int]$fx.Pid) -Force -ErrorAction Stop
                    Log ("   ✔ « {0} » arrêté." -f $fx.Name)
                    Add-Change -Kind 'info' -Title ("Programme suspect arrêté : {0}" -f $fx.Name)
                }
                'policy' {
                    foreach ($pv in @($fx.Values)) {
                        $kp = $pv.Split('|', 2)
                        if ($kp.Count -ne 2 -or -not ($kp[0] -eq $script:SecPolicyBase -or $kp[0].StartsWith($script:SecPolicyBase + '\'))) { throw "emplacement inattendu" }
                        Remove-ItemProperty -LiteralPath $kp[0] -Name $kp[1] -ErrorAction Stop
                        Log ("   ✔ Stratégie retirée : {0}" -f $kp[1])
                    }
                    Add-Change -Kind 'info' -Title "Stratégies qui coupaient l'antivirus retirées" -Detail (@($fx.Values) -join ' · ')
                }
            }
        } catch {
            Add-TaskError -Title ("Impossible de corriger « {0} »" -f $a.Item.Title) -Cause $_.Exception.Message -Effect "Cet élément est toujours là." `
                -FixLabel 'Ouvrir Sécurité Windows' -FixAction "Open-WinUri 'windowsdefender:'" -Steps @("Relance l'analyse de sécurité pour revoir l'élément.", "Si ça bloque toujours, lance l'analyse hors ligne.")
        }
    }
    # 5. Désinstallations (le désinstalleur du logiciel s'ouvre)
    foreach ($a in @($acts | Where-Object { $_.Fix.Kind -eq 'uninstall' })) {
        if ($sync.Cancel) { return }
        try { Uninstall-App 'win32' $a.Fix.Cmd $a.Fix.Name ([bool]$a.Fix.PerUser); Log ("   ✔ Désinstalleur de « {0} » ouvert : suis ses étapes." -f $a.Fix.Name); Add-Change -Kind 'info' -Title ("Désinstallation de « {0} » lancée" -f $a.Fix.Name) }
        catch { Add-TaskError -Title ("Impossible de désinstaller « {0} »" -f $a.Fix.Name) -Cause $_.Exception.Message -FixLabel 'Ouvrir les applications' -FixAction "Open-WinUri 'ms-settings:appsfeatures'" }
    }
    Log "✅ Traitement terminé. La quarantaine et les désactivations s'annulent dans l'historique."
    $sync.SecReport = $null   # résultat traité : une nouvelle analyse montrera ce qui reste
    if ($crit) { Log "👉 Des signes d'intrusion ont été trouvés : lance maintenant l'analyse hors ligne (onglet Sécurité), et change tes mots de passe depuis ton téléphone." }
}

# ---------------------------------------------------------------- Analyses Windows Defender
function Get-DefenderTool {
    $exe = Join-Path $env:ProgramFiles 'Windows Defender\MpCmdRun.exe'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf) -or -not (Test-ToolSignature $exe 'Microsoft Corporation')) { return '' }
    return $exe
}
function Test-DefenderActive {
    try { $mp = Get-MpComputerStatus -ErrorAction Stop; if ($mp.AntivirusEnabled -or $mp.AMServiceEnabled) { return $true } } catch {}
    # Deuxième avis : le Centre de sécurité de Windows (ce qu'affiche « Sécurité Windows »)
    try { foreach ($a in @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop | Where-Object { $_.displayName -match 'Defender' })) { if (([int]$a.productState -band 0x1000) -ne 0) { return $true } } } catch {}
    return $false
}
function Start-DefenderFullScan {
    Step "Analyse complète Windows Defender"
    $exe = Get-DefenderTool
    if (-not $exe -or -not (Test-DefenderActive)) {
        Add-TaskError -Title "Windows Defender ne peut pas analyser ce PC" -Cause "Defender est désactivé (un autre antivirus le remplace peut-être), ou son outil d'analyse est introuvable." `
            -Effect "L'analyse complète n'a pas été lancée." -FixLabel 'Ouvrir Sécurité Windows' -FixAction "Open-WinUri 'windowsdefender:'" -Steps @("Si tu as un autre antivirus, lance son analyse complète à la place.")
        return
    }
    $t0 = (Get-Date).AddSeconds(-5)
    Log "   Tous les fichiers du PC sont analysés : 30 minutes à 2 heures. Tu peux continuer à utiliser le PC (un peu plus lent). « Annuler » arrête l'analyse."
    $p = Start-Process -FilePath $exe -ArgumentList '-Scan', '-ScanType', '2' -WindowStyle Hidden -PassThru
    $null = $p.Handle
    $last = Get-Date
    while (-not $p.HasExited) {
        if ($sync.Cancel) {
            Log "   ⏹ Arrêt de l'analyse demandé…"
            try { Start-Process -FilePath $exe -ArgumentList '-Scan', '-Cancel' -WindowStyle Hidden -Wait } catch {}
            try { [void]$p.WaitForExit(30000) } catch {}
            Log "   Analyse arrêtée. Rien n'a été modifié."
            return
        }
        Start-Sleep -Seconds 2
        if (((Get-Date) - $last).TotalMinutes -ge 5) { $last = Get-Date; Log ("   … analyse en cours depuis {0:N0} min" -f ((Get-Date) - $t0).TotalMinutes) }
    }
    $code = $p.ExitCode
    $found = @(); try { $found = @(Get-MpThreatDetection -ErrorAction Stop | Where-Object { $_.InitialDetectionTime -ge $t0 }) } catch {}
    if ($found.Count) {
        $names = @(); try { $th = @{}; foreach ($t in @(Get-MpThreat -ErrorAction Stop)) { $th["$($t.ThreatID)"] = "$($t.ThreatName)" }; $names = @($found | ForEach-Object { $th["$($_.ThreatID)"] } | Where-Object { $_ } | Select-Object -Unique) } catch {}
        Log ("❌ Defender a trouvé {0} menace(s){1} et les a mises en quarantaine ou supprimées." -f @($found | Group-Object ThreatID).Count, $(if ($names.Count) { ' : ' + ($names -join ', ') } else { '' }))
        Log "👉 Change tes mots de passe depuis ton téléphone, puis lance l'analyse hors ligne pour finir le travail."
        Add-Change -Kind 'info' -Title ("Analyse complète Defender : {0} menace(s) traitée(s)" -f @($found | Group-Object ThreatID).Count)
    } elseif ($code -eq 0) { Log "✅ Analyse complète terminée : aucune menace trouvée." }
    else {
        Add-TaskError -Title "L'analyse complète ne s'est pas terminée" -Cause ("Windows Defender s'est arrêté avec le code {0}." -f $code) -Effect "Le PC n'a pas été entièrement analysé." `
            -FixLabel 'Ouvrir Sécurité Windows' -FixAction "Open-WinUri 'windowsdefender:'" -Steps @("Relance l'analyse complète depuis Sécurité Windows > Protection contre les virus et menaces > Options d'analyse.")
    }
}
function Start-DefenderOffline {
    Step "Analyse hors ligne de Windows Defender"
    if (-not (Test-DefenderActive) -or -not (Get-Command Start-MpWDOScan -ErrorAction SilentlyContinue)) {
        Add-TaskError -Title "L'analyse hors ligne n'est pas disponible" -Cause "Windows Defender est désactivé sur ce PC (un autre antivirus le remplace peut-être)." `
            -Effect "Le PC n'a pas redémarré." -FixLabel 'Ouvrir Sécurité Windows' -FixAction "Open-WinUri 'windowsdefender:'" -Steps @("Si tu as un autre antivirus, utilise son « disque de secours » ou son analyse au démarrage.")
        return
    }
    Add-Change -Kind 'info' -Title "Analyse hors ligne de Windows Defender lancée" -Detail "Le PC a redémarré pour analyser Windows avant son démarrage (environ 15 minutes)."
    Log "   Le PC va redémarrer dans quelques secondes pour l'analyse (environ 15 minutes). Le résultat sera dans Sécurité Windows > Historique de protection."
    Start-MpWDOScan -ErrorAction Stop
}

# ---------------------------------------------------------------- Diagnostic : signes forts et rapides
function Test-SecQuickSigns {
    $n = 0
    try {
        $pref = Get-MpPreference -ErrorAction Stop
        $bad = @()
        foreach ($t in @(@('path', 'ExclusionPath'), @('ext', 'ExclusionExtension'), @('process', 'ExclusionProcess'))) {
            foreach ($v in @($pref.($t[1]) | Where-Object { $_ -and "$_" -notmatch '^N/A' })) { if ((Get-ExclusionRisk "$v" $t[0]) -eq 'crit') { $bad += "$v" } }
        }
        if ($bad.Count) {
            $n++
            Add-Issue -Id 'secu-exclusion' -Sev 'crit' -Title $(if ($bad.Count -gt 1) { "$($bad.Count) exclusions dangereuses aveuglent l'antivirus" } else { "Une exclusion dangereuse aveugle l'antivirus" }) -Detail ((@($bad | Select-Object -First 3) -join ', ') + $(if ($bad.Count -gt 3) { " et $($bad.Count - 3) autre(s)" } else { '' })) `
                -Cause "Windows Defender a reçu l'ordre de ne pas surveiller une partie importante du PC. Les virus ajoutent ce genre d'exclusion pour ne pas être détectés." `
                -Effect "Un virus caché là n'est jamais repéré." -FixLabel "Analyser la sécurité" -UiFix 'secscan'
        }
    } catch {}
    try {
        $since = (Get-Date).AddDays(-30)
        $ids = @(Get-MpThreatDetection -ErrorAction Stop | Where-Object { $_.InitialDetectionTime -ge $since } | ForEach-Object { "$($_.ThreatID)" } | Select-Object -Unique)
        $bad = @(Get-MpThreat -ErrorAction Stop | Where-Object { $ids -contains "$($_.ThreatID)" -and ($_.IsActive -or $_.DidThreatExecute) })
        if ($bad.Count) {
            $n++
            Add-Issue -Id 'secu-menace' -Sev 'crit' -Title "Un virus a eu le temps de se lancer sur le PC" -Detail (@($bad | ForEach-Object { "$($_.ThreatName)" }) -join ', ') `
                -Cause "Windows Defender a trouvé ces derniers jours un virus encore présent ou qui s'est déjà exécuté." `
                -Effect "Tes mots de passe et tes connexions (Discord, Instagram, Amazon…) ont pu être volés." -FixLabel "Analyser la sécurité" -UiFix 'secscan' `
                -Steps @("Change tes mots de passe depuis ton téléphone, en commençant par ta boîte mail.", "Lance l'analyse de sécurité, puis l'analyse hors ligne (onglet Sécurité).")
        }
    } catch {}
    try {
        $fake = @()
        foreach ($p in @(Get-CimInstance Win32_Process -ErrorAction Stop)) {
            $m = Test-Masquerade "$($p.Name)" "$($p.ExecutablePath)" $env:SystemRoot
            if (-not $m -or -not $p.ExecutablePath) { continue }
            $sig = Get-SecSig "$($p.ExecutablePath)"
            if (($m -eq 'exact' -and -not $sig.Ms) -or ($m -like 'like:*' -and -not $sig.Valid -and (Get-PathZone "$($p.ExecutablePath)") -notin 'programfiles', 'windows')) { $fake += "$($p.Name)" }
        }
        $fake = @($fake | Select-Object -Unique)
        if ($fake.Count) {
            $n++
            Add-Issue -Id 'secu-faux-programme' -Sev 'crit' -Title "Un programme se fait passer pour un programme de Windows" -Detail ($fake -join ', ') `
                -Cause "Un programme en cours porte le nom d'un programme de Windows (ou presque) mais n'est pas à sa place : technique classique des virus." `
                -Effect "Il peut voler tes mots de passe ou laisser quelqu'un prendre la main sur le PC." -FixLabel "Analyser la sécurité" -UiFix 'secscan'
        }
    } catch {}
    if (-not $n) { Add-Ok "Aucun signe fort d'intrusion (exclusions, virus récents, faux programmes de Windows)" }
}
}
