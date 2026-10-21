# Le compteur de FPS d'AEROX avec le VRAI PresentMon installé par winget (Windows PowerShell 5.1, machine de test GitHub).
# Reprend telles quelles les fonctions du programme construit (Find-PresentMon…) et vérifie qu'elles rangent dans le dossier
# protégé une copie signée par Intel, qu'elles refusent un fichier remplacé, et qu'elles se réparent toutes seules.
# Paramètre : le dossier « build » construit par ./build.sh. À lancer APRÈS l'installation de PresentMon par winget.
param([Parameter(Mandatory = $true)][string]$Build)
. (Join-Path $PSScriptRoot 'outils.ps1')
$Script = Join-Path (Join-Path $Build 'AEROX PC Care') 'AeroxPCCare.ps1'
Exiger (Test-Path -LiteralPath $Script) 'script construit introuvable'

Invoke-Expression (Get-CodeAerox $Script @('Test-CertOrg', 'Test-ToolSignature', 'Test-PresentMonCopy', 'Find-PresentMon', 'Find-PresentMonInstalled', 'Get-ToolsDir', 'Get-SecureDir', 'Get-AclWeakness', 'Test-AdminOnlyPath') @('$script:PmSigOk', '$script:AdminSids'))
$AppInfo = @{ Secure = (Join-Path $env:ProgramFiles 'AeroxPCCare\protege') }
$sure = Join-Path (Get-ToolsDir) 'presentmon\PresentMon.exe'

Note ("Machine : {0}" -f (Get-CimInstance Win32_OperatingSystem).Caption)
$installes = @(Find-PresentMonInstalled -All)
foreach ($i in $installes) { Note ("  PresentMon installé par winget : {0}" -f $i) }
if (-not $installes.Count) {
    Note 'PresentMon n''est pas installé par winget sur cette machine : test sauté (voir « PresentMon réel » pour la raison).'
    Envoyer 'PresentMon intégré'
    exit 0
}

Verifier 'Find-PresentMon range une copie signée par Intel dans le dossier protégé' {
    Remove-Item -LiteralPath $sure -Force -ErrorAction SilentlyContinue
    $pm = Find-PresentMon
    Exiger $pm 'aucun PresentMon accepté alors que le vrai est installé'
    Exiger ($pm -eq $sure) "chemin renvoyé : $pm"
    $sig = Get-AuthenticodeSignature -LiteralPath $pm
    Note ("  signature : {0} / {1}" -f $sig.Status, $sig.SignerCertificate.Subject)
    Exiger ($sig.Status -eq 'Valid') "signature $($sig.Status)"
    Exiger (Test-CertOrg $sig.SignerCertificate.Subject 'Intel Corporation') 'organisation du certificat différente'
    Exiger (Test-AdminOnlyPath $pm) ("copie modifiable par un autre compte : {0}" -f (Get-AclWeakness $pm))
    Exiger (-not (Test-Path -LiteralPath (Join-Path (Split-Path $sure -Parent) 'PresentMon-verif.exe'))) 'copie de vérification laissée dans le dossier protégé'
    Exiger ((Find-PresentMon) -eq $sure) 'deuxième appel différent du premier'
}
Verifier 'Un fichier remplacé dans le dossier protégé est refusé, puis la bonne copie est remise' {
    Copy-Item -LiteralPath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -Destination $sure -Force
    Exiger (-not (Test-ToolSignature $sure 'Intel Corporation')) 'le faux fichier (signé par Microsoft) est reconnu comme étant d''Intel'
    $pm = Find-PresentMon
    Exiger ($pm -eq $sure) "chemin renvoyé : $pm"
    Exiger (Test-ToolSignature $sure 'Intel Corporation') 'la copie remise n''est pas signée par Intel'
}
Verifier 'Fichier sans signature rangé par une ancienne version : retiré, jamais lancé' {
    [IO.File]::WriteAllBytes($sure, [byte[]](0x4D, 0x5A, 0x90, 0, 3, 0, 0, 0))
    $pm = Find-PresentMon
    Exiger ($pm -eq $sure) "chemin renvoyé : $pm"
    Exiger (Test-ToolSignature $sure 'Intel Corporation') 'le fichier non signé est resté en place'
}

Remove-Item -LiteralPath (Split-Path $sure -Parent) -Recurse -Force -ErrorAction SilentlyContinue
Note ''
Note ("RÉSUMÉ : {0} échec(s)" -f $script:Echecs.Count)
foreach ($e in $script:Echecs) { Note ("  - " + $e) }
Envoyer 'PresentMon intégré'
exit $(if ($script:Echecs.Count) { 1 } else { 0 })
