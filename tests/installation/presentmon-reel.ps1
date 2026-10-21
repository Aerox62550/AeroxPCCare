# Le VRAI PresentMon d'Intel est-il signé par Intel ? (téléchargement officiel sur GitHub, et copie installée par winget si winget existe)
# Sert à savoir si AEROX peut exiger la signature d'Intel avant de lancer le compteur de FPS en administrateur.
# Windows PowerShell 5.1, machine de test GitHub (rien d'autre n'est touché).
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$script:Lignes = New-Object 'System.Collections.Generic.List[string]'
function Note([string]$t) { $script:Lignes.Add($t); Write-Host $t }
function Envoyer([string]$Titre) {
    $L = @($script:Lignes)
    for ($i = 0; $i -lt $L.Count; $i += 45) {
        $n = [int][math]::Floor($i / 45) + 1
        $fin = [math]::Min($i + 44, $L.Count - 1)
        $chunk = (($L[$i..$fin]) -join "`n").Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A')
        Write-Host "::notice title=$Titre $n::$chunk"
    }
}
function Decrire([string]$f) {
    $sig = Get-AuthenticodeSignature -LiteralPath $f
    $h = (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.Substring(0, 16)
    Note ("  {0} : statut = {1} ; sha256 = {2}…" -f (Split-Path $f -Leaf), $sig.Status, $h)
    if ($sig.SignerCertificate) {
        Note ("    sujet   : {0}" -f $sig.SignerCertificate.Subject)
        Note ("    valide  : du {0:yyyy-MM-dd} au {1:yyyy-MM-dd}" -f $sig.SignerCertificate.NotBefore, $sig.SignerCertificate.NotAfter)
        Note ("    horodatage : {0}" -f $(if ($sig.TimeStamperCertificate) { $sig.TimeStamperCertificate.Subject } else { 'aucun' }))
    }
    if ($sig.StatusMessage) { Note ("    message : {0}" -f $sig.StatusMessage) }
    # Même test que Test-ToolSignature dans AEROX
    $ok = ($sig.Status -eq 'Valid' -and "$($sig.SignerCertificate.Subject)" -match ('O=' + [regex]::Escape('Intel Corporation')))
    Note ("    accepté par le test d'AEROX (signature valide + O=Intel Corporation) : {0}" -f $ok)
    return $ok
}

Note ("Machine : {0}" -f (Get-CimInstance Win32_OperatingSystem).Caption)
$resultat = @{}
try {
    $h = @{ 'User-Agent' = 'aerox-ci'; 'Accept' = 'application/vnd.github+json' }
    if ($env:GH_TOKEN) { $h['Authorization'] = "Bearer $env:GH_TOKEN" }
    $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/GameTechDev/PresentMon/releases/latest' -Headers $h
    Note ("Dernière version officielle : {0} (publiée le {1})" -f $rel.tag_name, $rel.published_at)
    foreach ($a in $rel.assets) { Note ("  fichier : {0} ({1:N0} o)" -f $a.name, $a.size) }
    $dir = Join-Path $env:RUNNER_TEMP 'pm-officiel'; New-Item -ItemType Directory -Force $dir | Out-Null
    foreach ($a in @($rel.assets | Where-Object { $_.name -match '(?i)\.exe$' })) {
        $dest = Join-Path $dir $a.name
        Invoke-WebRequest -Uri $a.browser_download_url -OutFile $dest -UseBasicParsing -Headers @{ 'User-Agent' = 'aerox-ci' }
        $resultat[$a.name] = Decrire $dest
    }
} catch { Note ("ERREUR (téléchargement officiel) : {0}" -f $_.Exception.Message) }

Note ''
$wg = Get-Command winget -ErrorAction SilentlyContinue
if (-not $wg) { Note 'winget absent sur cette machine : copie installée par winget non testée.' }
else {
    Note ("winget présent : {0} ({1})" -f $wg.Source, ((& winget --version) -join ' '))
    $out = & winget install --id Intel.PresentMon.Console --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-String
    Note ("winget install : code {0}" -f $LASTEXITCODE)
    foreach ($l in @($out -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 8)) { Note ("    " + $l.Trim()) }
    foreach ($root in @("$env:LOCALAPPDATA\Microsoft\WinGet\Packages", "$env:ProgramFiles\WinGet\Packages", "$env:LOCALAPPDATA\Microsoft\WinGet\Links", "$env:ProgramFiles\WinGet\Links")) {
        if (-not (Test-Path -LiteralPath $root)) { Note ("  (absent) {0}" -f $root); continue }
        $f = @(Get-ChildItem -LiteralPath $root -Recurse -Filter 'PresentMon*.exe' -ErrorAction SilentlyContinue)
        Note ("  {0} : {1} fichier(s)" -f $root, $f.Count)
        foreach ($x in $f) { Note ("    {0}" -f $x.FullName); $resultat["winget:" + $x.FullName] = Decrire $x.FullName }
    }
}
Note ''
Note ("RÉSUMÉ : fichiers acceptés par le test d'AEROX = {0} sur {1}" -f @($resultat.Values | Where-Object { $_ }).Count, $resultat.Count)
Envoyer 'PresentMon réel'
