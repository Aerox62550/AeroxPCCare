
# =====================================================================
#  Fonctions natives : dans AeroxPCCare.Native.dll (à côté du script)
#  tailles de dossiers, overlay, raccourci clavier, compteur de FPS, capteurs, paquets NuGet
# =====================================================================
$AppRoot = if ($PSScriptRoot) { $PSScriptRoot } elseif ($AeroxRoot) { $AeroxRoot } else { (Get-Location).Path }
$AppInfo.Root = $AppRoot
$NativeDll = Join-Path $AppRoot 'AeroxPCCare.Native.dll'
Set-SplashStep 40 'Chargement des modules…'
if (-not ('AeroxNative' -as [type])) {
    if (-not (Test-Path -LiteralPath $NativeDll)) { throw "Le fichier AeroxPCCare.Native.dll est introuvable. Dézippe tout le dossier (pas seulement le programme) puis relance." }
    # L'antivirus peut verrouiller la DLL quelques secondes pendant son analyse : on réessaie
    $loaded = $false; $lastErr = $null
    for ($try = 0; $try -lt 40 -and -not $loaded; $try++) {
        try { Add-Type -Path $NativeDll -ErrorAction Stop; $loaded = $true }
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
