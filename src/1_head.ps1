<#
    AEROX PC Care
    Diagnostic, nettoyage, mises à jour, réparation et optimisation de Windows 10 / 11.
    Interface guidée pour tout le monde.
#>

# =====================================================================
#  RÉGLAGES (à modifier par le développeur)
# =====================================================================
$AppName    = 'AEROX PC Care'
$AppVersion = '2.8.0'
# Dépôt GitHub pour les rapports de bug et les nouvelles versions, ex : 'TonPseudo/AeroxPCCare'
# Laisse vide pour désactiver l'envoi sur GitHub et la recherche de mise à jour.
$GitHubRepo = 'Aerox62550/AeroxPCCare'

# =====================================================================
#  Démarrage : droits administrateur + mode STA (obligatoire pour WPF)
# =====================================================================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isSTA   = [Threading.Thread]::CurrentThread.GetApartmentState() -eq 'STA'

# Le logiciel se lance avec « AeroxPCCare.exe », qui demande les droits administrateur
function Close-Splash { try { if ($AeroxSplash) { $AeroxSplash.Close() } } catch {} }
# Avancement de l'écran de chargement (barre violette) : ne bloque jamais le démarrage
function Set-SplashStep([int]$Percent, [string]$Text) { try { if ($AeroxSplash) { $AeroxSplash.SetProgress($Percent, $Text) } } catch {} }
Set-SplashStep 32 'Préparation…'
if (-not $isAdmin -or -not $isSTA) {
    Close-Splash
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show("Lance AEROX PC Care avec le programme « AeroxPCCare.exe » (ou le raccourci AEROX PC Care du Bureau).`n`nIl demandera les droits administrateur nécessaires pour analyser et réparer Windows.", $AppName, 'OK', 'Information') | Out-Null
    exit
}

# Droits admin : modules PowerShell et programmes appelés par leur nom ne sont jamais cherchés dans un dossier
# modifiable sans droits admin (Documents, PATH de l'utilisateur) : un programme malveillant ne pourrait pas s'y glisser
try {
    $env:PSModulePath = (@("$env:ProgramFiles\WindowsPowerShell\Modules", "$env:SystemRoot\System32\WindowsPowerShell\v1.0\Modules") | Where-Object { Test-Path -LiteralPath $_ }) -join ';'
    $sysDirs = @("$env:SystemRoot\System32", $env:SystemRoot, "$env:SystemRoot\System32\Wbem", "$env:SystemRoot\System32\WindowsPowerShell\v1.0", "$env:SystemRoot\System32\OpenSSH")
    $machine = @(([Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';') | ForEach-Object { [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\') } |
                 Where-Object { $_ -and $_ -notlike "$env:SystemDrive\Users\*" -and $_ -notlike "$env:SystemDrive\ProgramData\*" -and ($_ -like "$env:SystemRoot*" -or $_ -like "$env:ProgramFiles*" -or $_ -like "${env:ProgramFiles(x86)}*") })
    $env:Path = (@($sysDirs + $machine) | Select-Object -Unique) -join ';'
} catch {}
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

# Dossier protégé (Program Files : modifiable seulement en administrateur) : outils lancés avec les droits admin,
# sauvegardes remises en administrateur, installateurs de mise à jour, et (2.3.0) toutes les données d'AEROX
$SecureRoot = Join-Path $env:ProgramFiles 'AeroxPCCare\protege'
# Ancien dossier des données (jusqu'à la 2.2) : modifiable par n'importe quel programme du compte, alors qu'AEROX y écrit
# en administrateur (un programme malveillant pouvait y glisser un lien pour lui faire écraser un fichier de Windows)
$OldLogDir = Join-Path $env:LOCALAPPDATA 'AeroxPCCare'
$LogDir = $OldLogDir
# Version portable (clé USB) : un fichier « portable.txt » à côté du programme.
# Réglages, journaux et historique restent sur la clé, dans un dossier par PC
# (l'historique et les annulations d'un PC ne doivent jamais s'appliquer à un autre).
$Portable = $false
$PortRoot = if ($PSScriptRoot) { $PSScriptRoot } elseif ($AeroxRoot) { $AeroxRoot } else { '' }
if ($PortRoot -and (Test-Path -LiteralPath (Join-Path $PortRoot 'portable.txt'))) {
    $pd = Join-Path (Join-Path $PortRoot 'donnees') ($env:COMPUTERNAME -replace '[^\w.-]', '_')
    try {
        New-Item -ItemType Directory -Force -Path $pd -ErrorAction Stop | Out-Null
        $probe = Join-Path $pd '.ecriture'
        [IO.File]::WriteAllText($probe, 'ok'); Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
        $LogDir = $pd
    } catch {}   # clé protégée en écriture : on garde le dossier du PC
    $Portable = $true
}
if (-not $Portable) {
    # Données dans le dossier protégé, une par compte Windows (comme avant dans le dossier de chaque compte)
    $sidDir = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $LogDir = Join-Path (Join-Path $SecureRoot 'donnees') $sidDir
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    # Reprise unique des anciennes données (réglages, historique, bilans, fiches de jeux, journaux) : fichiers ordinaires
    # seulement, aucun lien suivi, pas les anciens outils ni installateurs. Elles sont recopiées, l'ancien dossier reste.
    $mark = Join-Path $LogDir '.reprise'
    if (-not (Test-Path -LiteralPath $mark) -and (Test-Path -LiteralPath $OldLogDir)) {
        try {
            $stack = New-Object System.Collections.Stack; $stack.Push(@($OldLogDir, $LogDir, 0))
            while ($stack.Count) {
                $x = $stack.Pop(); $src = $x[0]; $dst = $x[1]; $depth = $x[2]
                $di = New-Object IO.DirectoryInfo $src
                if (($di.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $depth -gt 4) { continue }
                [void][IO.Directory]::CreateDirectory($dst)
                foreach ($f in $di.GetFiles()) {
                    if (($f.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $f.Length -gt 50MB) { continue }
                    $to = Join-Path $dst $f.Name
                    if (-not (Test-Path -LiteralPath $to)) { try { [IO.File]::WriteAllBytes($to, [IO.File]::ReadAllBytes($f.FullName)) } catch {} }
                }
                foreach ($d in $di.GetDirectories()) { if ($d.Name -notin 'outils', 'maj') { $stack.Push(@($d.FullName, (Join-Path $dst $d.Name), ($depth + 1))) } }
            }
        } catch {}
        try { [IO.File]::WriteAllText($mark, (Get-Date).ToString('s')) } catch {}
    }
} else { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }

# Filet de sécurité : si le logiciel plante, l'erreur est écrite dans plantage.txt et affichée
trap {
    Close-Splash
    $msg = "{0}`r`n{1}`r`n{2}" -f $_.Exception.Message, ($_.InvocationInfo.PositionMessage), $_.ScriptStackTrace
    try { [IO.File]::WriteAllText((Join-Path $LogDir 'plantage.txt'), ("[{0}] AEROX PC Care {1}`r`n{2}" -f (Get-Date), $AppVersion, $msg)) } catch {}
    try { [System.Windows.MessageBox]::Show("AEROX PC Care a rencontré une erreur au démarrage :`n`n$($_.Exception.Message)`n`nLe détail est enregistré dans :`n$LogDir\plantage.txt", 'AEROX PC Care', 'OK', 'Error') | Out-Null } catch {}
    exit 1
}
$LogFile        = Join-Path $LogDir ("journal_{0}.txt" -f (Get-Date -Format 'yyyy-MM-dd'))
$BugFile        = Join-Path $LogDir 'bugs.jsonl'
$LastReportFile = Join-Path $LogDir 'dernier_rapport.txt'
$SettingsFile   = Join-Path $LogDir 'reglages.json'
$OldSettings    = Join-Path $LogDir 'reglages.txt'

$AppInfo = [hashtable]::Synchronized(@{ Secure = $SecureRoot; OldLogDir = $OldLogDir; Name = $AppName; Version = $AppVersion; LogDir = $LogDir; BugFile = $BugFile; Repo = $GitHubRepo; IgnoredApps = @(); IgnoredIssues = @(); StartupKept = @(); StartupOff = @(); StabilityFixAt = @{}; StatsOff = $false; StatsQueue = $null; StatsLock = (New-Object Object); Beta = $false; Launcher = $AeroxLauncher; Portable = $Portable })

# Objet partagé entre l'interface et les tâches en arrière-plan
$sync = [hashtable]::Synchronized(@{
    Queue      = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
    Verify     = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
    Progress   = -1.0
    NeedReboot = $false
    Errors     = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
    Diag       = $null
    Scan       = [hashtable]::Synchronized(@{})
    ScanOrder  = @()
    ScanVer    = 0
    UpdateInfo = $null
    UpdateDone = $false
    UpdateReady = $null
    SysInfo    = $null
    BugRelay   = ''
    DiscordUrl = ''
    Drives     = @()
    DrivesNew  = $false
    AppList    = $null
    CleanList  = $null
    SpaceScan  = $null
    InstalledApps = $null
    Sens       = $null
    SensStop   = $false
    SensMode   = ''
    SensError  = ''
    GameCtx    = $null
})
