
# =====================================================================
#  Fonctions natives : dans AeroxPCCare.Native.dll (à côté du script)
#  tailles de dossiers, overlay, raccourci clavier, compteur de FPS, capteurs, paquets NuGet
# =====================================================================
$AppRoot = if ($PSScriptRoot) { $PSScriptRoot } elseif ($AeroxRoot) { $AeroxRoot } else { (Get-Location).Path }
$AppInfo.Root = $AppRoot
$NativeDll = Join-Path $AppRoot 'AeroxPCCare.Native.dll'
Set-SplashStep 40 'Chargement des modules…'
function Get-FileSha256([byte[]]$Bytes) {
    $h = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($h.ComputeHash($Bytes)) -replace '-', '') } finally { $h.Dispose() }
}
function Get-VerifiedNative([string]$Source, [string]$Sha, [string]$Dir) {
    $bytes = $null; $err = $null
    for ($i = 0; $i -lt 40 -and $null -eq $bytes; $i++) { try { $bytes = [IO.File]::ReadAllBytes($Source) } catch { $err = $_; Start-Sleep -Milliseconds 500 } }
    if ($null -eq $bytes) { throw "Impossible de lire AeroxPCCare.Native.dll : $($err.Exception.Message)" }
    if ((Get-FileSha256 $bytes) -ne $Sha.ToUpperInvariant()) { throw "Le module AeroxPCCare.Native.dll ne correspond pas à cette version d'AEROX PC Care : il a été modifié ou abîmé. Par sécurité, il n'est pas chargé.`n`nRetélécharge AEROX PC Care depuis sa page officielle (GitHub)." }
    New-Item -ItemType Directory -Force -Path $Dir | Out-Null
    $copy = Join-Path $Dir ("AeroxPCCare.Native.{0}.dll" -f $Sha.Substring(0, 16).ToLowerInvariant())
    $ok = $false
    try { if (Test-Path -LiteralPath $copy) { $ok = ((Get-FileSha256 ([IO.File]::ReadAllBytes($copy))) -eq $Sha.ToUpperInvariant()) } } catch {}
    if (-not $ok) {
        [IO.File]::WriteAllBytes($copy, $bytes)
        if ((Get-FileSha256 ([IO.File]::ReadAllBytes($copy))) -ne $Sha.ToUpperInvariant()) { throw "La copie vérifiée du module AeroxPCCare.Native.dll n'a pas pu être écrite." }
    }
    # Anciennes versions du module : plus utilisées
    foreach ($o in @(Get-ChildItem -LiteralPath $Dir -Filter 'AeroxPCCare.Native.*.dll' -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -ne $copy })) { try { Remove-Item -LiteralPath $o.FullName -Force -ErrorAction Stop } catch {} }
    return $copy
}
if (-not ('AeroxNative' -as [type])) {
    if (-not (Test-Path -LiteralPath $NativeDll)) { throw "Le fichier AeroxPCCare.Native.dll est introuvable. Dézippe tout le dossier (pas seulement le programme) puis relance." }
    # Lancé par AeroxPCCare.exe : le module chargé en administrateur doit être exactement celui de cette version
    # (empreinte gravée dans le lanceur). Il est vérifié puis copié dans le dossier protégé (modifiable seulement par
    # un administrateur), et c'est cette copie qui est chargée : rien ne peut le remplacer entre la vérification et le
    # chargement, même en version portable dans un dossier modifiable.
    $loadPath = $NativeDll
    if ($AeroxNativeSha) { $loadPath = Get-VerifiedNative $NativeDll $AeroxNativeSha (Join-Path $SecureRoot 'module') }
    # L'antivirus peut verrouiller la DLL quelques secondes pendant son analyse : on réessaie
    $loaded = $false; $lastErr = $null
    for ($try = 0; $try -lt 40 -and -not $loaded; $try++) {
        try { Add-Type -Path $loadPath -ErrorAction Stop; $loaded = $true }
        catch { $lastErr = $_; Start-Sleep -Milliseconds 500 }
    }
    if (-not $loaded) {
        # 0x800711C7 : bloqué par une stratégie de contrôle des applications de Windows (le plus souvent le « Contrôle
        # intelligent des applications » de Windows 11, qui refuse les fichiers non signés encore peu connus). Ce n'est
        # pas l'antivirus : le dire clairement, avec quoi faire.
        $txt = ''; $e = $lastErr.Exception; while ($e) { $txt += ' ' + $e.Message + ' ' + ('0x{0:X8}' -f $e.HResult); $e = $e.InnerException }
        if ($txt -match '(?i)800711C7|contr[ôo]le d.application|application control') {
            throw "Windows a bloqué un module d'AEROX PC Care avec son « Contrôle intelligent des applications » (sécurité de Windows 11 qui refuse les logiciels pas encore signés numériquement). Ce n'est pas un virus ni ton antivirus.`n`nPour l'instant : Sécurité Windows > Contrôle des applications et du navigateur > Paramètres du Contrôle intelligent des applications. S'il est « Activé », AEROX ne peut pas démarrer sur ce PC tant que le logiciel n'est pas signé (c'est en cours). Tu peux le désactiver si tu le souhaites, en connaissance de cause.`n`nDétail : $($lastErr.Exception.Message)"
        }
        throw "Impossible de charger AeroxPCCare.Native.dll (ton antivirus la bloque peut-être : ajoute le dossier AEROX PC Care à ses exceptions). Détail : $($lastErr.Exception.Message)"
    }
}
