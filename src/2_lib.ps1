
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
        $user = "$((Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).UserName)"
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
        $user = "$((Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).UserName)"
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
function Open-WinUri {
    [CmdletBinding()] param([string]$Uri)
    if ($Uri -notmatch '^(ms-settings|windowsdefender|ms-windows-store|ms-availablenetworks|shell|steam):') { throw "Lien non autorisé : $Uri" }
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
function Format-Size([double]$Bytes) {
    if ($Bytes -ge 1GB) { return ("{0:N2} Go" -f ($Bytes / 1GB)) }
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
# Programme signé par l'éditeur attendu (signature Windows valide) ?
function Test-ToolSignature([string]$Path, [string]$Publisher) {
    try {
        $sig = Get-AuthenticodeSignature -FilePath $Path -ErrorAction Stop
        return ($sig.Status -eq 'Valid' -and "$($sig.SignerCertificate.Subject)" -match ('O=' + [regex]::Escape($Publisher)))
    } catch { return $false }
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
        $console = "$((Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).UserName)"
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
            $name = "$((Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).UserName)"
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
    $allowed = 'Set-UserProxy', 'Restore-HostsBackup', 'Set-StartupApps', 'Set-PowerScheme', 'Enable-StorageSense', 'Disable-StorageSense', 'Enable-Hibernation', 'Set-DisplayHz', 'Set-NetAdapterSleep', 'Restore-Dns', 'Set-CpuMaxState', 'Set-BgItem', 'Restore-RegBackup', 'Set-ReservedStorage', 'Set-HiberType', 'Set-RestoreSpace', 'Set-CompactOS'
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
# Changements notés avant la 2.1.3 (sans sceau) : seulement les réglages sans risque.
function Test-UndoAuthorized([string]$Id, [string]$Undo) {
    if (-not (Test-SafeUndo $Undo)) { return $false }
    $f = Join-Path $AppInfo.Secure 'annulations.txt'
    if ((Test-Path -LiteralPath $f) -and (@(Get-Content -LiteralPath $f -ErrorAction SilentlyContinue) -contains (Get-UndoSeal $Id $Undo))) { return $true }
    return (($Undo.Trim() -split '\s+')[0] -notin 'Set-BgItem', 'Restore-RegBackup', 'Set-StartupApps')
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
function Get-SystemInfo {
    $i = @{ Ready = $true }
    try {
        $cs = Get-CimInstance Win32_ComputerSystem; $bb = Get-CimInstance Win32_BaseBoard; $bios = Get-CimInstance Win32_BIOS
        $os = Get-CimInstance Win32_OperatingSystem; $csp = Get-CimInstance Win32_ComputerSystemProduct
        $i.PcMaker = "$($cs.Manufacturer)".Trim(); $i.PcModel = "$($cs.Model)".Trim()
        if ($i.PcMaker -match '(?i)lenovo' -and $csp.Version) { $i.PcModel = "$($csp.Version)".Trim() }
        $i.BoardMaker = "$($bb.Manufacturer)".Trim(); $i.BoardModel = "$($bb.Product)".Trim()
        $chassis = @((Get-CimInstance Win32_SystemEnclosure).ChassisTypes)
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
        $i.Cpu = ("$((Get-CimInstance Win32_Processor | Select-Object -First 1).Name)".Trim() -replace '\s+', ' ')
        $i.CpuAmd = ($i.Cpu -match '(?i)amd|ryzen')
        $i.Gpu = @(Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name } | Where-Object { $_ -notmatch '(?i)basic display|remote|virtual|parsec|meta' })
        $i.Ram = [double]$cs.TotalPhysicalMemory
        $mods = @(Get-CimInstance Win32_PhysicalMemory)
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
    try { $owner = "$((Get-CimInstance Win32_ComputerSystem).UserName)" } catch {}
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
    $domain = $false; try { $domain = [bool](Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).PartOfDomain } catch {}
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
    try { $laptop = [bool](@((Get-CimInstance Win32_SystemEnclosure).ChassisTypes | Where-Object { $_ -in 8, 9, 10, 11, 14, 30, 31, 32 }).Count) } catch {}
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
        $ram = [double](Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
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
# Mémoire : type (DDR3/4/5), barrettes et emplacements libres, pour un conseil d'ajout précis
function Get-RamLayout {
    $r = @{ Type = ''; Modules = 0; Slots = 0; ModuleSize = 0.0 }
    try {
        $mods = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop)
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
        if ($pc -lt 10 -or $fr -lt 10GB) {
            [void]$f.Add(@{ Id = 'disque-plein'; Sev = $(if ($pc -lt 5) { 'bad' } else { 'warn' }); Title = "Le disque $env:SystemDrive est presque plein ($(Format-Size $fr) libres)"; Text = "Sous 10 % d'espace libre, Windows ralentit et les mises à jour échouent."; Advice = "Regarde ce qui prend de la place et supprime ce qui ne sert plus (jeux finis, vieux téléchargements)."; Action = 'space' })
        }
        [void]$chk.Add(@{ Ok = -not ($pc -lt 10 -or $fr -lt 10GB); T = "Place libre sur $($env:SystemDrive) : $(Format-Size $fr) ($pc %)" })
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
        $cs = Get-CimInstance Win32_ComputerSystem
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
    $laptop = $false; try { $laptop = [bool](@((Get-CimInstance Win32_SystemEnclosure).ChassisTypes | Where-Object { $_ -in 8, 9, 10, 11, 14, 30, 31, 32 }).Count) } catch {}
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
function Add-StatsEvent([string]$Key) {
    try {
        $q = $AppInfo.StatsQueue
        if ($AppInfo.StatsOff -or $null -eq $q -or $Key -cnotmatch '^[a-z]+(:[a-z0-9][a-z0-9-]{0,39})?$') { return }
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
        if (Test-Path -LiteralPath $p) { foreach ($l in [IO.File]::ReadAllLines($p)) { if ($q.Count -lt 300 -and $l -cmatch '^[a-z]+(:[a-z0-9][a-z0-9-]{0,39})?$') { [void]$q.Add($l) } } }
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
        $last = $null; $lastMonth = ''
        if (Test-Path -LiteralPath $stamp) {
            $p = ([IO.File]::ReadAllText($stamp)).Trim().Split('|')
            try { $last = [datetime]::ParseExact($p[0], 's', [Globalization.CultureInfo]::InvariantCulture) } catch {}
            if ($p.Count -gt 1) { $lastMonth = $p[1] }
        }
        $month = (Get-Date).ToString('yyyy-MM')
        $newMonth = ($lastMonth -ne $month)
        $q = $AppInfo.StatsQueue
        $keys = @()
        [System.Threading.Monitor]::Enter($q.SyncRoot); try { $keys = @($q.ToArray()) } finally { [System.Threading.Monitor]::Exit($q.SyncRoot) }
        if (-not $newMonth -and -not $keys.Count) { return }
        if (-not $newMonth -and -not $Force -and $last -and ((Get-Date) - $last).TotalHours -lt 6) { return }
        # Le relais sait-il recevoir les statistiques ? Sinon les compteurs attendent (rien n'est envoyé ailleurs)
        $cap = Invoke-RestMethod -Uri "$relay/stats" -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop
        if ($cap.aerox -ne 'stats' -or -not $cap.ok) { return }
        $ev = @{}
        foreach ($k in $keys) { if ($ev.ContainsKey($k)) { if ($ev[$k] -lt 50) { $ev[$k]++ } } elseif ($ev.Count -lt 60) { $ev[$k] = 1 } }
        $body = @{ v = "$($AppInfo.Version)"; nouveau_mois = [bool]$newMonth; ev = $ev } | ConvertTo-Json -Compress
        $r = Invoke-RestMethod -Uri "$relay/stats" -Method Post -Body ([Text.Encoding]::UTF8.GetBytes($body)) -ContentType 'application/json; charset=utf-8' -Headers @{ 'X-Aerox' = '1' } -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
        if ($r.ok) {
            [System.Threading.Monitor]::Enter($q.SyncRoot)
            try { $q.RemoveRange(0, [math]::Min($keys.Count, $q.Count)); Save-StatsQueue } finally { [System.Threading.Monitor]::Exit($q.SyncRoot) }
            [IO.File]::WriteAllText($stamp, ("{0}|{1}" -f (Get-Date).ToString('s'), $month))
            $AppInfo.StatsLastError = ''
        } else { $AppInfo.StatsLastError = "réponse du relais : $($r | ConvertTo-Json -Compress)" }
    } catch { $AppInfo.StatsLastError = $_.Exception.Message } finally { [System.Threading.Monitor]::Exit($AppInfo.StatsLock) }
}

# Diagnostic : causes de fond des lenteurs (réglages), sans mesure longue
function Test-Performance {
    $laptop = $false
    try { $laptop = [bool](@((Get-CimInstance Win32_SystemEnclosure).ChassisTypes | Where-Object { $_ -in 8, 9, 10, 11, 14, 30, 31, 32 }).Count) } catch {}
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
        $cs = Get-CimInstance Win32_ComputerSystem
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
function Test-Storage {
    $d = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
    $pct = [math]::Round($d.FreeSpace / $d.Size * 100)
    $detail = "{0} libres sur {1} ({2} %)" -f (Format-Size $d.FreeSpace), (Format-Size $d.Size), $pct
    if ($pct -lt 15) {
        $tmp = [double]0; foreach ($loc in Get-TempLocations) { $tmp += Get-FolderSize $loc.Path }
        $wu  = Get-FolderSize "$env:SystemRoot\SoftwareDistribution\Download"
        $rb  = Get-FolderSize ("{0}\`$Recycle.Bin" -f $env:SystemDrive)
        $parts = @()
        if ($tmp -gt 100MB) { $parts += "$(Format-Size $tmp) de fichiers temporaires" }
        if ($wu  -gt 100MB) { $parts += "$(Format-Size $wu) de mises à jour déjà installées" }
        if ($rb  -gt 100MB) { $parts += "$(Format-Size $rb) dans la corbeille" }
        $cause = if ($parts) { ($parts -join ', ') + " prennent de la place pour rien." } else { "Le disque est rempli par tes fichiers, jeux et logiciels." }
        Add-Issue -Id 'disk' -Sev $(if ($pct -lt 10) { 'crit' } else { 'warn' }) -Title "Le disque $env:SystemDrive est presque plein" -Detail $detail -Cause $cause `
            -Effect "Windows ralentit fortement sous 10 % d'espace libre et les mises à jour peuvent échouer." `
            -FixLabel "Nettoyer en profondeur" -UiFix 'clean' `
            -Steps @("Lance le nettoyage approfondi (bouton vert) : tu choisis quoi supprimer, avec la taille de chaque catégorie.", "Onglet Nettoyage > « Ce qui prend de la place » : trouve les plus gros dossiers (jeux, vidéos, téléchargements).", "Désinstalle les jeux et logiciels que tu n'utilises plus, déplace vidéos et photos sur un autre disque.")
    } else { Add-Ok "Disque $env:SystemDrive : $detail" }
    Log "   • Disque $env:SystemDrive (Windows) : $detail"
    # Les autres disques : internes et externes (USB), chacun affiché ; alerte si un disque interne ou externe fixe est plein
    foreach ($o in @(Get-DriveList | Where-Object { $_.Id -ne $env:SystemDrive })) {
        $lbl = "{0}{1}{2}" -f $o.Id, $(if ($o.Name) { " ($($o.Name))" } else { '' }), $(if ($o.Removable) { ', amovible' } else { '' })
        $det = "{0} libres sur {1} ({2} %)" -f (Format-Size $o.Free), (Format-Size $o.Size), $o.Pct
        Log "   • Disque $lbl : $det"
        if ($o.Pct -lt 5 -and -not $o.Removable) {
            Add-Issue -Id "disk$($o.Id)" -Sev 'warn' -Title "Le disque $($o.Id) est plein" -Detail $det `
                -Cause "Ce disque n'a presque plus de place." -Effect "Les jeux ou fichiers dessus ne pourront plus se mettre à jour ni s'enregistrer." `
                -Steps @("Supprime ou déplace ce dont tu n'as plus besoin sur ce disque.", "Pour les jeux : désinstalle ceux auxquels tu ne joues plus depuis Steam / Epic.")
        } else { Add-Ok "Disque $lbl : $det" }
    }
}

function Test-Memory {
    $os = Get-CimInstance Win32_OperatingSystem; $cs = Get-CimInstance Win32_ComputerSystem
    $total = [double]$cs.TotalPhysicalMemory
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
    if ($total -lt 7.5GB) {
        Add-Issue -Id 'ramsize' -Sev 'warn' -Title "Peu de mémoire vive (moins de 8 Go)" -Detail ("{0} installés" -f (Format-Size $total)) `
            -Cause "Windows 11 et les logiciels actuels ont besoin d'au moins 8 Go pour être à l'aise." -Effect "Le PC sera vite lent dès que plusieurs logiciels sont ouverts." `
            -Steps @("Évite d'ouvrir trop de logiciels en même temps.", "Si le PC le permet, ajoute une barrette de RAM (c'est souvent peu cher).")
        $issue = $true
    }
    if (-not $issue) { Add-Ok ("Mémoire : {0}, utilisation normale ({1} %)" -f (Format-Size $total), $pct) }
}

function Test-SystemState {
    $os = Get-CimInstance Win32_OperatingSystem
    $build = [int]$os.BuildNumber
    if ($build -lt 22000) {
        Add-Issue -Id 'win10' -Sev 'warn' -Title "Windows 10 n'a plus de mises à jour de sécurité" -Detail "$($os.Caption) (build $build)" `
            -Cause "Microsoft a arrêté le support de Windows 10 le 14 octobre 2025 (sauf abonnement aux mises à jour étendues ESU)." `
            -Effect "Les nouvelles failles de sécurité ne sont plus corrigées sur ce PC." -FixLabel "Ouvrir Windows Update" -FixAction 'Open-WindowsUpdate' -OpenOnly `
            -Steps @("Dans Windows Update, regarde si ton PC peut passer à Windows 11 : la mise à niveau est gratuite.", "Si le PC n'est pas compatible, Windows Update propose de s'inscrire aux mises à jour étendues (ESU).")
    } elseif ($build -lt 26100 -and $os.Caption -notmatch '(?i)entreprise|enterprise|education|éducation') {
        Add-Issue -Id 'win11old' -Sev 'warn' -Title "Ta version de Windows 11 n'est plus prise en charge" -Detail "$($os.Caption) (build $build)" `
            -Cause "Les anciennes versions de Windows 11 Famille et Pro ne reçoivent plus de correctifs de sécurité." `
            -Effect "Les nouvelles failles ne sont plus corrigées." -FixLabel "Ouvrir Windows Update" -FixAction 'Open-WindowsUpdate' -OpenOnly `
            -Steps @("Dans Windows Update, installe la « mise à jour des fonctionnalités » proposée (version 24H2 ou plus récente).")
    } else { Add-Ok "$($os.Caption) (build $build), version prise en charge" }

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
        $m = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop)
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

    # Le pilote graphique qui « cesse de répondre et récupère » (écran noir une seconde, jeu qui se fige ou se ferme)
    $tdr = @(Get-EventsSafe @{ LogName = 'System'; ProviderName = 'Display'; Id = 4101; StartTime = (Get-StabilitySince 'tdr' (Get-Date).AddDays(-7)) })
    if ($tdr.Count -ge 2) {
        $drvName = ("$($tdr[0].Properties[0].Value)" -replace '[^\w.\-]', '')
        Add-Issue -Id 'tdr' -Sev 'warn' -Title "Le pilote graphique a décroché $($tdr.Count) fois cette semaine" -Detail $(if ($drvName) { "Pilote : $drvName" } else { 'Carte graphique' }) `
            -Cause "Windows a dû relancer le pilote de la carte graphique (écran noir une seconde, jeu qui se fige ou se ferme). Causes classiques : pilote abîmé ou trop vieux/trop récent, overclocking de la carte, surchauffe, ou alimentation trop juste." `
            -Effect "Écrans noirs, jeux qui plantent, parfois écran bleu." -FixLabel "Vérifier les pilotes" -UiFix 'drivers' `
            -Steps @("Installe le dernier pilote de ta carte graphique en « installation propre » (option de l'installateur NVIDIA / AMD).", "Enlève tout overclocking de la carte graphique (MSI Afterburner…).", "Regarde les températures en jeu (Gaming > En direct) : au-dessus de 85 °C, dépoussière.", "Si ça continue : l'alimentation du PC est peut-être trop faible pour la carte.")
    }

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
    try { $laptop = [bool](@((Get-CimInstance Win32_SystemEnclosure).ChassisTypes | Where-Object { $_ -in 8, 9, 10, 11, 14, 30, 31, 32 }).Count) } catch {}
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
        $g = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | Where-Object { $_.Name -notmatch '(?i)remote|virtual|parsec|basic display|de base|hyper-v|vmware|virtualbox|parallels|qxl|red hat|citrix|dameware|mirage' })
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
    try { $laptop = [bool](@((Get-CimInstance Win32_SystemEnclosure).ChassisTypes | Where-Object { $_ -in 8, 9, 10, 11, 14, 30, 31, 32 }).Count) } catch {}
    $list = New-Object System.Collections.ArrayList
    foreach ($g in @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)) {
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
                -Cause "Un pilote graphique ancien cause des plantages en jeu, des bugs d'affichage et des performances plus faibles." -Effect "Jeux moins fluides, crashs possibles et écrans bleus." `
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

function Test-Security {
    $thirdAv = @()
    try {
        $av = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop)
        $active = @($av | Where-Object { ($_.productState -band 0x1000) -ne 0 })
        $thirdAv = @($av | Where-Object { $_.displayName -notmatch 'Defender' } | ForEach-Object { $_.displayName } | Select-Object -Unique)
        if ($active.Count -eq 0) {
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
        $mp = Get-MpComputerStatus -ErrorAction Stop
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
            } elseif ($temp -gt 65) {
                Add-Issue -Id "temp$($pd.DeviceId)" -Sev 'warn' -Title "Le disque « $name » chauffe ($temp °C)" -Detail "Au-dessus de 65 °C" `
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
        $de = @(foreach ($pv in 'disk', 'Ntfs', 'Microsoft-Windows-Ntfs') { Get-EventsSafe @{ LogName = 'System'; ProviderName = $pv; Id = 7, 51, 153, 55, 98; StartTime = (Get-Date).AddDays(-30) } })
        # Après une réparation, seules les erreurs d'après comptent
        $sB = Get-StabilitySince 'diskbad' (Get-Date).AddDays(-30); $sR = Get-StabilitySince 'diskretry' (Get-Date).AddDays(-30); $sF = Get-StabilitySince 'ntfs' (Get-Date).AddDays(-30)
        $bad = @($de | Where-Object { $_.Id -in 7, 51 -and $_.TimeCreated -gt $sB }); $retry = @($de | Where-Object { $_.Id -eq 153 -and $_.TimeCreated -gt $sR }); $fs = @($de | Where-Object { $_.Id -in 55, 98 -and $_.TimeCreated -gt $sF })
        $diskOf = { param($e) $t = (@($e.Properties | ForEach-Object { "$($_.Value)" }) -join ' ') + " $($e.Message)"; if ($t -match '(?i)harddisk(\d+)') { [int]$matches[1] } else { -1 } }
        if ($bad.Count) {
            $nums = @($bad | ForEach-Object { & $diskOf $_ } | Where-Object { $_ -ge 0 } | Select-Object -Unique)
            $names = @($nums | ForEach-Object { $n = $_; $pd = @(Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { "$($_.DeviceId)" -eq "$n" })[0]; if ($pd) { $pd.FriendlyName } else { "disque n° $n" } })
            Add-Issue -Id 'diskbad' -Sev 'crit' -Title ("Windows n'arrive pas à lire certains endroits du disque ({0} fois ce mois-ci)" -f $bad.Count) -Detail $(if ($names.Count) { $names -join ', ' } else { 'Disque' }) `
                -Cause "Windows a noté des secteurs illisibles ou des erreurs de lecture : le disque s'use ou est abîmé (ou, plus rarement, son câble / sa prise)." `
                -Effect "Risque de perdre des fichiers. Ça empire en général avec le temps." -FixLabel "Vérifier le disque" -FixAction 'Test-Disk' `
                -Steps @("SAUVEGARDE tout de suite tes fichiers importants (clé USB, disque externe, cloud).", "Disque interne SATA : change le câble SATA ou la prise sur la carte mère.", "Si ça continue : remplace le disque.")
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

function Test-Temperatures {
    $v = $sync.Sens
    $cpuLoad = [double]$v['cpu.load']
    $issue = $false
    if ($v['cpu.temp']) {
        $t = [math]::Round([double]$v['cpu.temp'])
        $lim = if ($cpuLoad -lt 30) { 80 } else { 95 }
        if ($t -ge $lim) {
            Add-Issue -Id 'cputemp' -Sev $(if ($t -ge 95) { 'crit' } else { 'warn' }) -Title "Le processeur chauffe ($t °C)" -Detail ("Utilisation actuelle : {0} %" -f [math]::Round($cpuLoad)) `
                -Cause $(if ($cpuLoad -lt 30) { "Il est chaud alors qu'il ne travaille presque pas : poussière, ventilateur, pâte thermique ou refroidissement mal monté." } else { "Il est très sollicité et le refroidissement a du mal à suivre." }) `
                -Effect "Le processeur ralentit pour se protéger (perte de FPS) et s'use plus vite." `
                -Steps @("Dépoussière le PC (bombe d'air sec), surtout le radiateur du processeur.", "Vérifie que tous les ventilateurs tournent.", "Si le PC a plus de 4-5 ans, changer la pâte thermique fait souvent gagner 10 °C.")
            $issue = $true
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
    foreach ($k in $checks.Keys) {
        if ($sync.Cancel) { return }
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

function Start-DeepClean {
    Step "Nettoyage profond des composants Windows (DISM)"
    Log "   Ça peut prendre un moment, laisse le logiciel ouvert..."
    if (Test-ComponentsPending) { Log $script:PendingMsg; return }
    $free0 = [double](Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'").FreeSpace
    $ec = Invoke-Native 'dism.exe' @('/Online', '/Cleanup-Image', '/StartComponentCleanup')
    $free1 = [double](Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'").FreeSpace
    $gain = [math]::Max([double]0, [double]$free1 - [double]$free0)
    $script:TotalFreed += $gain
    if ($ec -eq -2146498554) { Log $script:PendingMsg }
    elseif ($ec -ne 0) {
        Add-TaskError -Title "Le nettoyage profond n'a pas pu se terminer" -Code ('0x{0:X8}' -f $ec) -Cause "Windows est peut-être en train d'installer une mise à jour, ou un redémarrage est en attente." `
            -Effect "Rien n'est cassé : les anciens composants sont juste encore là." -FixLabel "Redémarrer puis réessayer" -FixAction 'Request-Reboot' -Steps @("Redémarre le PC.", "Relance « Nettoyage profond » dans l'onglet Nettoyage.")
    } else { Log ("✅ Nettoyage profond terminé : environ {0} libérés" -f (Format-Size $gain)) }
}

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
# Compteur de FPS : on ne lance que la copie rangée dans le dossier protégé. Elle n'y est copiée que si le programme
# installé est signé par Intel (ou juste après son installation par AEROX lui-même, $Fresh)
function Find-PresentMon([bool]$Fresh = $false) {
    $safe = Join-Path (Get-ToolsDir) 'presentmon\PresentMon.exe'
    if (Test-Path -LiteralPath $safe) { return $safe }
    $src = Find-PresentMonInstalled
    if (-not $src) { return $null }
    if (-not $Fresh -and -not (Test-ToolSignature $src 'Intel Corporation')) { return $null }
    try {
        New-Item -ItemType Directory -Force -Path (Split-Path $safe -Parent) | Out-Null
        Copy-Item -LiteralPath $src -Destination $safe -Force -ErrorAction Stop
        return $safe
    } catch { return $null }
}
function Find-PresentMonInstalled {
    foreach ($root in @("$env:LOCALAPPDATA\Microsoft\WinGet\Packages", "$env:ProgramFiles\WinGet\Packages")) {
        $f = Get-ChildItem -Path $root -Directory -Filter 'Intel.PresentMon.Console*' -ErrorAction SilentlyContinue |
             ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Filter 'PresentMon*.exe' -Recurse -ErrorAction SilentlyContinue } |
             Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($f) { return $f.FullName }
    }
    foreach ($l in @("$env:LOCALAPPDATA\Microsoft\WinGet\Links\presentmon.exe", "$env:ProgramFiles\WinGet\Links\presentmon.exe")) {
        if (Test-Path -LiteralPath $l) { return $l }
    }
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
    $pm = Find-PresentMon $true
    if ($pm) { Log "   ✔ PresentMon installé : $pm" }
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

function Update-SelectedApps([string[]]$Ids, [string[]]$Names, [string[]]$Versions = @()) {
    $wg = Get-Winget
    if (-not $wg) { Add-WingetError "La mise à jour des logiciels est"; return }
    $extra = Get-WingetExtraArgs $wg
    $failed = @(); $ok = 0; $n = 0; $self = 0; $done = New-Object System.Collections.ArrayList
    for ($k = 0; $k -lt $Ids.Count; $k++) {
        if ($sync.Cancel) { Log ("⏹ Arrêt demandé : {0} logiciel(s) restant(s) pas mis à jour." -f ($Ids.Count - $k)); break }
        $id = $Ids[$k]; $name = if ($Names -and $k -lt $Names.Count -and $Names[$k]) { $Names[$k] } else { $id }
        $ver = if ($Versions -and $k -lt $Versions.Count) { "$($Versions[$k])" } else { '' }
        $n++
        Step ("Mise à jour {0}/{1} : {2}" -f $n, $Ids.Count, $name)
        $idArgs = if ($id.EndsWith([string][char]0x2026)) { @('--id', $id.TrimEnd([char]0x2026)) } else { @('--id', $id, '--exact') }
        $ec = Invoke-Native $wg (@('upgrade') + $idArgs + @('--silent', '--accept-package-agreements', '--accept-source-agreements') + $extra) ([System.Text.Encoding]::UTF8)
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
function Open-SystemRestore { Start-Process 'rstrui.exe'; Log "   ✔ Restauration du système ouverte : choisis un point et suis les étapes." }

# ---------------------------------------------------------------- PERFORMANCES
function Show-Startup {
    Step "Programmes lancés au démarrage"
    $items = @(Get-StartupEntries | Sort-Object { $_.Name })
    foreach ($i in $items) { Log ("   {0} {1}" -f $(if ($i.Enabled) { '•' } else { '○ (désactivé)' }), $i.Name) }
    Log ("   {0} programme(s) actif(s) au démarrage." -f @($items | Where-Object { $_.Enabled }).Count)
    Log "   → J'ouvre le Gestionnaire des tâches, onglet « Applications de démarrage » : clic droit > Désactiver sur ce qui ne sert pas."
    Log "   → Ne désactive PAS : l'antivirus, les pilotes audio / graphiques."
    Start-Process taskmgr.exe -ArgumentList '/0 /startup'
}

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

function Open-AppsSettings {
    Step "Logiciels installés"
    Log "   → Désinstalle ce que tu n'utilises plus : barres d'outils, « optimiseurs » douteux, antivirus en double, jeux d'essai..."
    Log "   → Dans le doute (pilote, Microsoft Visual C++, .NET), n'y touche pas."
    Open-WinUri 'ms-settings:appsfeatures'
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
function Test-DiscordInvite([string]$Url) { return ($Url -cmatch '^https://(discord\.gg|discord\.com/invite)/[A-Za-z0-9-]{2,32}$') }
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
}
