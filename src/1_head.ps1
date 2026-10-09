<#
    AEROX PC Care
    Diagnostic, nettoyage, mises à jour, réparation et optimisation de Windows 10 / 11.
    Interface guidée pour tout le monde.
#>

# =====================================================================
#  RÉGLAGES (à modifier par le développeur)
# =====================================================================
$AppName    = 'AEROX PC Care'
$AppVersion = '1.2.1'
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
if (-not $isAdmin -or -not $isSTA) {
    Close-Splash
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show("Lance AEROX PC Care avec le programme « AeroxPCCare.exe » (ou le raccourci AEROX PC Care du Bureau).`n`nIl demandera les droits administrateur nécessaires pour analyser et réparer Windows.", $AppName, 'OK', 'Information') | Out-Null
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

$LogDir = Join-Path $env:LOCALAPPDATA 'AeroxPCCare'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

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

$AppInfo = [hashtable]::Synchronized(@{ Name = $AppName; Version = $AppVersion; LogDir = $LogDir; BugFile = $BugFile; Repo = $GitHubRepo; IgnoredApps = @(); StartupKept = @(); Beta = $false; Launcher = $AeroxLauncher })

# Objet partagé entre l'interface et les tâches en arrière-plan
$sync = [hashtable]::Synchronized(@{
    Queue      = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
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
    AppList    = $null
    CleanList  = $null
    SpaceScan  = $null
    InstalledApps = $null
    Sens       = $null
    SensStop   = $false
    SensMode   = ''
    SensError  = ''
})
