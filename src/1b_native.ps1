
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
    if (-not $loaded) { throw "Impossible de charger AeroxPCCare.Native.dll (ton antivirus la bloque peut-être : ajoute le dossier AEROX PC Care à ses exceptions). Détail : $($lastErr.Exception.Message)" }
}
