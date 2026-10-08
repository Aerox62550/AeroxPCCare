
# =====================================================================
#  Bibliothèque des tâches (exécutée en arrière-plan : l'interface ne fige pas)
# =====================================================================
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
function Remove-ItemSafe($Item) {
    $freed = [double]0
    if ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) { return $freed }
    if ($Item.PSIsContainer) {
        foreach ($child in @(Get-ChildItem -LiteralPath $Item.FullName -Force -ErrorAction SilentlyContinue)) { $freed += Remove-ItemSafe $child }
        try { [IO.Directory]::Delete($Item.FullName, $false) } catch {}
    } else {
        $len = [double]$Item.Length
        try {
            if ($Item.IsReadOnly) { $Item.IsReadOnly = $false }
            [IO.File]::Delete($Item.FullName)
            $freed += $len
        } catch {}
    }
    return $freed
}

function Remove-PathContent([string]$Path) {
    $freed = [double]0
    if (-not (Test-Path -LiteralPath $Path)) { return $freed }
    foreach ($item in @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue)) { $freed += Remove-ItemSafe $item }
    return $freed
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

function Get-Winget {
    $w = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($w) { return $w.Source }
    $p = Get-ChildItem "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue |
         Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($p) { return $p.FullName }
    return $null
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
    try { if ([Console]::BufferWidth -lt 300) { [Console]::BufferWidth = 400 } } catch {}
    $null = Invoke-Native $wg (@('upgrade', '--accept-source-agreements') + (Get-WingetExtraArgs $wg)) ([System.Text.Encoding]::UTF8) -Quiet
    return ,(ConvertFrom-WingetTable @($script:NativeOutput) -IncludeIgnored:$IncludeIgnored)
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
        if ($l -match '^-{5,}' -or $l -match '(?i)upgrades? available|mises? à (jour|niveau)|package\(s\)|packages? (have|ont)|^\d+ ') { break }
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
function ConvertTo-PsLiteral([string]$Text) { return "'" + ($Text -replace "'", "''") + "'" }
function Add-Change {
    param([string]$Title, [string]$Detail = '', [string]$Undo = '', [string]$Kind = 'reglage')
    if ($script:AeroxUndo) { return }
    try {
        $o = [ordered]@{ id = [guid]::NewGuid().ToString('N').Substring(0, 12); date = (Get-Date).ToString('s'); title = $Title; detail = $Detail; undo = $Undo; kind = $Kind; version = $AppInfo.Version }
        $f = Join-Path $AppInfo.LogDir 'changements.jsonl'
        [IO.File]::AppendAllText($f, (($o | ConvertTo-Json -Compress) + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
    } catch {}
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
    else { Add-TaskError -Title "Impossible de rétablir le mode « $Name »" -Cause "Ce mode d'alimentation n'existe plus sur ce PC." -FixLabel "Ouvrir les options d'alimentation" -FixAction "Start-Process 'powercfg.cpl'" }
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
    $list = New-Object System.Collections.ArrayList
    $ab = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
    $sources = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';             Approved = "HKCU:\$ab\Run" },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run';             Approved = "HKLM:\$ab\Run" },
        @{ Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Approved = "HKLM:\$ab\Run32" }
    )
    foreach ($s in $sources) {
        $key = Get-Item -LiteralPath $s.Path -ErrorAction SilentlyContinue
        if (-not $key) { continue }
        foreach ($n in $key.GetValueNames()) {
            if (-not $n) { continue }
            [void]$list.Add(@{ Id = "$($s.Approved)|$n"; Name = $n; Command = [string]$key.GetValue($n); Approved = $s.Approved; ValueName = $n; Enabled = (Test-StartupEnabled $s.Approved $n) })
        }
    }
    foreach ($f in @(@{ Dir = [Environment]::GetFolderPath('Startup'); Approved = "HKCU:\$ab\StartupFolder" },
                     @{ Dir = [Environment]::GetFolderPath('CommonStartup'); Approved = "HKLM:\$ab\StartupFolder" })) {
        if (-not $f.Dir -or -not (Test-Path -LiteralPath $f.Dir)) { continue }
        foreach ($file in @(Get-ChildItem -LiteralPath $f.Dir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' })) {
            [void]$list.Add(@{ Id = "$($f.Approved)|$($file.Name)"; Name = $file.BaseName; Command = $file.FullName; Approved = $f.Approved; ValueName = $file.Name; Enabled = (Test-StartupEnabled $f.Approved $file.Name) })
        }
    }
    return $list
}
function Get-StartupKind($Entry) {
    $t = "$($Entry.Name) $($Entry.Command)"
    if ($t -match $script:StartupKeepPattern) { return 'keep' }
    if ($t -match $script:StartupDisablePattern) { return 'optional' }
    return 'other'
}
function Set-StartupApps([string[]]$Disable = @(), [string[]]$Enable = @()) {
    Step "Modification des programmes au démarrage"
    $entries = Get-StartupEntries
    foreach ($e in $entries) {
        $want = $null
        if ($Disable -contains $e.Id) { $want = 3 } elseif ($Enable -contains $e.Id) { $want = 2 }
        if ($null -eq $want) { continue }
        try {
            if (-not (Test-Path -LiteralPath $e.Approved)) { New-Item -Path $e.Approved -Force | Out-Null }
            New-ItemProperty -LiteralPath $e.Approved -Name $e.ValueName -PropertyType Binary -Value ([byte[]]($want,0,0,0,0,0,0,0,0,0,0,0)) -Force -ErrorAction Stop | Out-Null
            Log ("   ✔ {0} : {1}" -f $e.Name, $(if ($want -eq 3) { 'ne se lance plus au démarrage' } else { 'se lance de nouveau au démarrage' }))
            if ($want -eq 3) { Add-Change -Title ("« {0} » ne se lance plus au démarrage" -f $e.Name) -Detail "L'appli reste installée." -Undo ("Set-StartupApps -Enable @({0})" -f (ConvertTo-PsLiteral $e.Id)) }
            else { Add-Change -Title ("« {0} » se lance de nouveau au démarrage" -f $e.Name) -Undo ("Set-StartupApps -Disable @({0})" -f (ConvertTo-PsLiteral $e.Id)) }
        } catch {
            Add-TaskError -Title "Impossible de modifier « $($e.Name) » au démarrage" -Cause $_.Exception.Message `
                -FixLabel "Ouvrir le Gestionnaire des tâches" -FixAction "Start-Process taskmgr.exe -ArgumentList '/0 /startup'"
        }
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
    [void]$script:Issues.Add(@{ Id = $Id; Sev = $Sev; Cat = $script:CurrentCat; Title = $Title; Detail = $Detail; Code = $Code; Cause = $Cause; Effect = $Effect;
                                FixLabel = $FixLabel; FixAction = $FixAction; Confirm = $Confirm; Steps = $Steps; UiFix = $UiFix; OpenOnly = [bool]$OpenOnly; Status = 'open' })
}
function Add-Ok([string]$Text) { [void]$script:OkList.Add($Text) }

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
    foreach ($o in Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3') {
        if ($o.DeviceID -eq $env:SystemDrive -or -not $o.Size) { continue }
        $p = [math]::Round($o.FreeSpace / $o.Size * 100)
        if ($p -lt 5) {
            Add-Issue -Id "disk$($o.DeviceID)" -Sev 'warn' -Title "Le disque $($o.DeviceID) est plein" -Detail ("{0} libres ({1} %)" -f (Format-Size $o.FreeSpace), $p) `
                -Cause "Ce disque n'a presque plus de place." -Effect "Les jeux ou fichiers dessus ne pourront plus se mettre à jour ni s'enregistrer." `
                -Steps @("Supprime ou déplace ce dont tu n'as plus besoin sur ce disque.", "Pour les jeux : désinstalle ceux auxquels tu ne joues plus depuis Steam / Epic.")
        }
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
                -Effect "Certaines options de personnalisation sont bloquées et un message s'affiche en permanence." -FixLabel "Ouvrir l'activation" -FixAction "Start-Process 'ms-settings:activation'" -OpenOnly `
                -Steps @("Ouvre Paramètres > Système > Activation.", "Clique sur « Résolution des problèmes » si tu avais une licence avant.", "Sinon, une licence s'achète sur le Microsoft Store.")
        }
    } catch {}
}

function Test-Stability {
    $since = (Get-Date).AddDays(-30)
    $bsod = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting'; Id = 1001; StartTime = $since } -ErrorAction SilentlyContinue)
    if ($bsod.Count -gt 0) {
        $codes = foreach ($e in $bsod) {
            $txt = (($e.Properties | ForEach-Object { "$($_.Value)" }) -join ' ') + ' ' + $e.Message
            if ($txt -match '0x([0-9a-fA-F]{1,8})') { '0x' + $matches[1].PadLeft(8, '0').ToUpper() }
        }
        $main = $codes | Group-Object | Sort-Object Count -Descending | Select-Object -First 1
        $info = if ($main -and $script:BugChecks.ContainsKey($main.Name)) { $script:BugChecks[$main.Name] } else { @('Erreur système', "Un pilote ou un composant matériel a provoqué un arrêt brutal de Windows.", 'drv') }
        $codeTxt = if ($main) { "{0} ({1})" -f $info[0], $main.Name } else { '' }
        $steps = switch ($info[2]) {
            'hw'  { @("Si tu as overclocké le PC ou activé XMP / EXPO dans le BIOS, remets les réglages par défaut.", "Teste la mémoire : tape « Diagnostic de mémoire Windows » dans Démarrer et redémarre.", "Vérifie que le PC ne chauffe pas (poussière, ventilateurs).", "Mets à jour Windows et tes pilotes (onglet Mises à jour).") }
            'gpu' { @("Mets à jour le pilote de la carte graphique avec l'outil officiel (onglet Mises à jour > Pilotes).", "Si tu as overclocké la carte graphique, remets-la par défaut.", "Vérifie que la carte graphique ne chauffe pas (poussière, ventilateurs).") }
            default { @("Mets à jour le pilote de la carte graphique et du Wi-Fi / réseau (onglet Mises à jour > Pilotes).", "Installe toutes les mises à jour Windows.", "Si les écrans bleus continuent, désinstalle le dernier logiciel ou pilote installé avant qu'ils commencent.") }
        }
        Add-Issue -Id 'bsod' -Sev 'crit' -Title "$($bsod.Count) écran(s) bleu(s) ces 30 derniers jours" -Detail 'Code' -Code $codeTxt -Cause $info[1] `
            -Effect "Le PC peut planter n'importe quand, avec un risque de perdre ce qui n'est pas enregistré." `
            -FixLabel "Réparer les fichiers Windows" -FixAction 'Repair-System' -Confirm "La réparation des fichiers Windows prend 15 à 45 minutes. Laisse le PC branché et le logiciel ouvert.`n`nElle corrige les fichiers système abîmés ; pour les pilotes, suis aussi les étapes « Voir comment faire »." `
            -Steps $steps
    } else { Add-Ok "Aucun écran bleu ces 30 derniers jours" }

    $kp = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-Power'; Id = 41; StartTime = $since } -ErrorAction SilentlyContinue |
            Where-Object { "$($_.Properties[0].Value)" -eq '0' })
    if ($kp.Count -ge 2) {
        Add-Issue -Id 'power41' -Sev 'warn' -Title "Le PC s'est éteint brutalement $($kp.Count) fois" -Detail "Ces 30 derniers jours" `
            -Cause "Windows s'est coupé sans s'arrêter proprement : coupure de courant, bouton maintenu, surchauffe ou alimentation fatiguée." `
            -Effect "Risque de fichiers abîmés et de perte de travail." `
            -Steps @("Évite d'éteindre en maintenant le bouton : passe par Démarrer > Arrêter.", "Si ça arrive en jeu : vérifie la poussière et les ventilateurs (surchauffe).", "Si ça continue, l'alimentation du PC est peut-être fatiguée : fais-la vérifier.")
    }

    $crashes = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; Id = 1000; StartTime = (Get-Date).AddDays(-7) } -ErrorAction SilentlyContinue)
    $groups = @($crashes | Group-Object { "$($_.Properties[0].Value)" } | Where-Object { $_.Count -ge 3 } | Sort-Object Count -Descending)
    if ($groups.Count -gt 0) {
        $g = $groups[0]
        $module = ($g.Group | Group-Object { "$($_.Properties[3].Value)" } | Sort-Object Count -Descending | Select-Object -First 1).Name
        $cause = if ($module -match '(?i)^(nvwgf|nvogl|nvd3d|nvcuda|atiu|amdx|atidx|igd|ig\d)') { "Le plantage vient du pilote de la carte graphique ($module)." }
                 elseif ($module -match '(?i)^(ntdll|kernelbase|ucrtbase|msvcp|vcruntime|clr|coreclr)') { "Le plantage vient du logiciel lui-même ($module) : souvent une version ancienne ou des fichiers abîmés." }
                 else { "Plantages répétés dans « $module » : souvent une version ancienne ou des fichiers du logiciel abîmés." }
        $others = if ($groups.Count -gt 1) { " Autres : " + (($groups | Select-Object -Skip 1 -First 3 | ForEach-Object { "$($_.Name) ($($_.Count))" }) -join ', ') + "." } else { '' }
        Add-Issue -Id 'crash' -Sev 'warn' -Title "$($g.Name) a planté $($g.Count) fois cette semaine" -Detail ("Module en cause : {0}" -f $module) -Cause ($cause + $others) `
            -Effect "Fermetures soudaines et perte de ce qui n'était pas enregistré." -FixLabel "Mettre à jour mes logiciels" -FixAction 'Update-Apps' `
            -Steps @("Mets à jour le logiciel (bouton vert) et le pilote graphique (onglet Mises à jour > Pilotes).", "Si ça continue : désinstalle-le puis réinstalle-le depuis son site officiel.")
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
    if ($null -eq $apps) {
        Add-Issue -Id 'winget' -Sev 'warn' -Title "L'outil de mise à jour des logiciels est absent" -Detail 'winget introuvable' `
            -Cause "Le « Programme d'installation d'application » de Microsoft n'est pas installé ou trop ancien." -Effect "AEROX PC Care ne peut pas mettre tes logiciels à jour automatiquement." `
            -FixLabel "L'installer (Microsoft Store)" -FixAction 'Open-WingetStore' -OpenOnly
    } elseif ($apps.Count -gt 0) {
        $shown = ($apps | Select-Object -First 4 | ForEach-Object { $_.Name }) -join ', '
        if ($apps.Count -gt 4) { $shown += " et $($apps.Count - 4) autre(s)" }
        $ign = @(Get-IgnoredApps).Count
        Add-Issue -Id 'apps' -Sev 'warn' -Title "$($apps.Count) logiciel(s) ne sont pas à jour" -Detail $shown `
            -Cause ("Ces logiciels ne se mettent pas à jour tout seuls." + $(if ($ign) { " ($ign logiciel(s) ignoré(s) à ta demande ne sont pas comptés.)" } else { '' })) `
            -Effect "Les anciennes versions ont des bugs et des failles de sécurité connues." `
            -FixLabel "Choisir les mises à jour" -UiFix 'apps'
    } else { Add-Ok $(if (@(Get-IgnoredApps).Count) { "Logiciels à jour ($(@(Get-IgnoredApps).Count) ignoré(s) à ta demande)" } else { "Tous les logiciels sont à jour" }) }
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

function Get-GpuDrivers {
    $laptop = $false
    try { $laptop = [bool](@((Get-CimInstance Win32_SystemEnclosure).ChassisTypes | Where-Object { $_ -in 8, 9, 10, 11, 14, 30, 31, 32 }).Count) } catch {}
    $list = New-Object System.Collections.ArrayList
    foreach ($g in @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)) {
        if ($g.Name -match '(?i)remote|virtual|parsec|meta virtual|citrix|dameware|mirage') { continue }
        $vendor = if ("$($g.PNPDeviceID)" -match 'VEN_10DE' -or $g.Name -match 'NVIDIA') { 'NVIDIA' } elseif ("$($g.PNPDeviceID)" -match 'VEN_1002' -or $g.Name -match 'AMD|Radeon') { 'AMD' } elseif ("$($g.PNPDeviceID)" -match 'VEN_8086' -or $g.Name -match 'Intel') { 'Intel' } else { '' }
        $o = @{ Name = $g.Name; Vendor = $vendor; Raw = "$($g.DriverVersion)"; Version = "$($g.DriverVersion)"; Date = (ConvertTo-DateSafe $g.DriverDate); AgeDays = $null; Basic = ($g.Name -match '(?i)basic display|de base'); Latest = $null; Status = 'unknown' }
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
            Add-Issue -Id 'gpunone' -Sev 'crit' -Title "Aucun pilote de carte graphique installé" -Detail $o.Name `
                -Cause "Windows utilise un pilote d'affichage de secours, sans accélération graphique." -Effect "Jeux et vidéos saccadent ou ne se lancent pas, résolution parfois limitée." `
                -FixLabel "Rechercher les pilotes" -FixAction 'Open-DriverUpdates' -OpenOnly -Steps @("Installe le pilote depuis le site du fabricant : NVIDIA App, AMD Adrenalin ou Intel Driver & Support Assistant.")
            continue
        }
        $page = if ($o.Latest -and $o.Latest.Url) { $o.Latest.Url } else { $o.Page }
        $fix = if ($page) { "Start-Process " + (ConvertTo-PsLiteral $page) + "; Log '   ✔ Page officielle ouverte dans le navigateur'" } else { 'Open-DriverUpdates' }
        if ($o.Vendor -eq 'NVIDIA' -and $o.Latest) {
            $rel = if ($o.Latest.Date) { " (sortie le " + (Format-Date $o.Latest.Date) + ")" } else { '' }
            $late = if ($o.Latest.Date) { [int]((Get-Date) - $o.Latest.Date).TotalDays } else { 0 }
            if ($o.Status -eq 'old' -and ($late -ge 21 -or ($o.AgeDays -ge 120))) {
                Add-Issue -Id 'gpu' -Sev 'warn' -Title ("Pilote NVIDIA pas à jour : {0} installé, {1} disponible" -f $o.Version, $o.Latest.Version) -Detail ("{0}{1}" -f $o.Name, $rel) `
                    -Cause "NVIDIA sort régulièrement des pilotes qui corrigent des plantages et améliorent les performances des jeux récents." -Effect "Crashs ou bugs graphiques possibles dans certains jeux, performances un peu plus faibles." `
                    -FixLabel "Télécharger le pilote officiel" -FixAction $fix -OpenOnly `
                    -Steps @("Clique sur le bouton : le pilote officiel se télécharge depuis nvidia.com.", "Lance le fichier téléchargé et choisis l'installation « Express ».", "Ou, plus simple : installe la « NVIDIA App » qui fait les mises à jour toute seule.", "Redémarre le PC à la fin.")
            } else { Add-Ok ("Pilote NVIDIA à jour : {0}{1}" -f $o.Version, $(if ($o.Status -eq 'old') { " (la {0} vient de sortir{1})" -f $o.Latest.Version, $rel } else { '' })) }
            continue
        }
        if ($o.Status -eq 'old' -and $o.Date) {
            $steps = if ($o.Tool) { @("Télécharge « $($o.Tool) » sur la page officielle.", "Installe-le, ouvre-le et lance la mise à jour du pilote.", "Sur un PC portable, le site du fabricant du portable (rubrique Support) a parfois un pilote plus adapté.", "Redémarre le PC.") } else { @("Ouvre Windows Update > Options avancées > Mises à jour facultatives > Pilotes.") }
            Add-Issue -Id 'gpu' -Sev 'warn' -Title ("Le pilote de la carte graphique date de {0}" -f (Format-Date $o.Date 'MMMM yyyy')) -Detail ("{0} (version {1})" -f $o.Name, $o.Version) `
                -Cause "Un pilote graphique ancien cause des plantages en jeu, des bugs d'affichage et des performances plus faibles." -Effect "Jeux moins fluides, crashs possibles et écrans bleus." `
                -FixLabel "Télécharger le pilote officiel" -FixAction $fix -OpenOnly -Steps $steps
        } else { Add-Ok ("Pilote graphique récent : {0}" -f $o.Name) }
    }
    $errNames = @{ 1 = 'mal configuré'; 3 = 'pilote abîmé'; 10 = 'ne peut pas démarrer'; 28 = 'pilote non installé'; 31 = 'ne fonctionne pas correctement'; 39 = 'pilote abîmé ou manquant'; 43 = 'arrêté après une erreur'; 52 = 'pilote non signé' }
    $bad = @(Get-CimInstance Win32_PnPEntity -Filter 'ConfigManagerErrorCode <> 0' -ErrorAction SilentlyContinue | Where-Object { $_.ConfigManagerErrorCode -notin 22, 24, 45 })
    if ($bad.Count -gt 0) {
        $desc = ($bad | Select-Object -First 3 | ForEach-Object { $n = if ($_.Name) { $_.Name } else { 'Périphérique inconnu' }; $r = $errNames[[int]$_.ConfigManagerErrorCode]; if (-not $r) { $r = "code $($_.ConfigManagerErrorCode)" }; "$n ($r)" }) -join ', '
        Add-Issue -Id 'devices' -Sev 'warn' -Title "$($bad.Count) périphérique(s) ont un problème de pilote" -Detail $desc `
            -Cause "Windows n'a pas de pilote fonctionnel pour ces éléments (pilote manquant, abîmé ou incompatible)." -Effect "L'élément concerné peut ne pas marcher (son, Wi-Fi, Bluetooth, USB...)." `
            -FixLabel "Rechercher les pilotes" -FixAction 'Open-DriverUpdates' -OpenOnly `
            -Steps @("Dans Windows Update > Mises à jour facultatives > Pilotes, installe ce qui est proposé.", "Sinon, télécharge le pilote sur le site du fabricant de ton PC ou de ta carte mère.", "Pour voir le détail : clic droit sur Démarrer > Gestionnaire de périphériques.")
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
                -FixLabel "Ouvrir Sécurité Windows" -FixAction "Start-Process 'windowsdefender:'" -OpenOnly `
                -Steps @("Dans Sécurité Windows > Protection contre les virus et menaces, active la protection.", "Si un antivirus payant a expiré, désinstalle-le : Windows Defender reprendra la main gratuitement.")
        }
        if ($thirdAv.Count -gt 1) {
            Add-Issue -Id 'multiav' -Sev 'warn' -Title "Plusieurs antivirus sont installés" -Detail ($thirdAv -join ', ') `
                -Cause "Plusieurs antivirus surveillent les mêmes fichiers en même temps." -Effect "Ils ralentissent le PC et peuvent se bloquer entre eux." `
                -FixLabel "Ouvrir les applications" -FixAction "Start-Process 'ms-settings:appsfeatures'" -OpenOnly -Steps @("Garde-en un seul (Windows Defender suffit largement).", "Désinstalle les autres dans Paramètres > Applications.")
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
}

function Get-StartupKey($Entry) { return ("$($Entry.ValueName)").ToLowerInvariant() }
function Test-StartupKept($Entry) { return (@($AppInfo.StartupKept) -contains (Get-StartupKey $Entry)) }

function Test-Startup {
    $all  = @(Get-StartupEntries | Where-Object { $_.Enabled })
    # Ce que tu as validé (« je le garde ») et l'essentiel (antivirus, pilotes) ne sont plus signalés
    $kept = @($all | Where-Object { Test-StartupKept $_ })
    $rest = @($all | Where-Object { -not (Test-StartupKept $_) -and (Get-StartupKind $_) -ne 'keep' })
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
}

function Test-DiskHealth {
    try {
        $sysNum = (Get-Partition -DriveLetter $env:SystemDrive[0] -ErrorAction Stop | Get-Disk).Number
        foreach ($pd in @(Get-PhysicalDisk -ErrorAction Stop)) {
            $name = $pd.FriendlyName
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

function Invoke-Diagnostic {
    Step "Diagnostic complet"
    $script:Issues = New-Object System.Collections.ArrayList
    $script:OkList = New-Object System.Collections.ArrayList
    $checks = [ordered]@{ 'Stockage' = 'Test-Storage'; 'Mémoire' = 'Test-Memory'; 'Système' = 'Test-SystemState'; 'Stabilité' = 'Test-Stability'; 'Mises à jour' = 'Test-Updates'
                          'Pilotes' = 'Test-Drivers'; 'Sécurité' = 'Test-Security'; 'Réseau' = 'Test-Network'; 'Démarrage' = 'Test-Startup'; 'Logiciels' = 'Test-Bloatware'; 'Santé du disque' = 'Test-DiskHealth' }
    $sens = $sync.Sens
    if ($sens -and ($sens['cpu.temp'] -or $sens['gpu.temp'])) { $checks['Températures'] = 'Test-Temperatures' }
    $sync.Scan.Clear()
    foreach ($k in $checks.Keys) { $sync.Scan[$k] = 'wait' }
    $sync.ScanOrder = @($checks.Keys)
    $sync.ScanVer++
    foreach ($k in $checks.Keys) {
        $script:CurrentCat = $k
        $sync.Scan[$k] = 'run'; $sync.ScanVer++
        $before = $script:Issues.Count
        try { & $checks[$k] }
        catch { Write-Bug -Context "Diagnostic / $k" -ErrorRecord $_; Log ("   ⚠ Vérification « {0} » impossible : {1}" -f $k, $_.Exception.Message) }
        $new = @($script:Issues | Select-Object -Skip $before)
        $sync.Scan[$k] = if (@($new | Where-Object { $_.Sev -eq 'crit' }).Count) { 'bad' } elseif ($new.Count) { 'warn' } else { 'ok' }
        $sync.ScanVer++
        if ($new.Count) { foreach ($i in $new) { Log ("   {0} {1} : {2}" -f $(if ($i.Sev -eq 'crit') { '❌' } else { '⚠' }), $k, $i.Title) } }
        else { Log ("   ✔ {0} : OK" -f $k) }
    }
    $crit = @($script:Issues | Where-Object { $_.Sev -eq 'crit' }).Count
    $sync.Diag = @{ Issues = @($script:Issues); Ok = @($script:OkList); Date = (Get-Date) }
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

function Clear-RecycleBinAll {
    Step "Vidage de la corbeille"
    $size = [double]0
    foreach ($d in Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3') { $size += Get-FolderSize ("{0}\`$Recycle.Bin" -f $d.DeviceID) }
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    $script:TotalFreed += $size
    Log ("✅ Corbeille vidée : {0} libérés" -f (Format-Size $size))
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
    Step "Nettoyage du cache des navigateurs"
    $before = $script:TotalFreed
    $found  = $false
    $browsers = @(
        @{ Name = 'Google Chrome';  Proc = 'chrome'; Dir = "$env:LOCALAPPDATA\Google\Chrome\User Data" },
        @{ Name = 'Microsoft Edge'; Proc = 'msedge'; Dir = "$env:LOCALAPPDATA\Microsoft\Edge\User Data" },
        @{ Name = 'Brave';          Proc = 'brave';  Dir = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data" },
        @{ Name = 'Opera GX';       Proc = 'opera';  Dir = "$env:LOCALAPPDATA\Opera Software\Opera GX Stable" },
        @{ Name = 'Opera';          Proc = 'opera';  Dir = "$env:LOCALAPPDATA\Opera Software\Opera Stable" }
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
    $ff = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
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

function Start-DeepClean {
    Step "Nettoyage profond des composants Windows (DISM)"
    Log "   Ça peut prendre un moment, laisse le logiciel ouvert..."
    $free0 = [double](Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'").FreeSpace
    $ec = Invoke-Native 'dism.exe' @('/Online', '/Cleanup-Image', '/StartComponentCleanup')
    $free1 = [double](Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'").FreeSpace
    $gain = [math]::Max(0, $free1 - $free0)
    $script:TotalFreed += $gain
    if ($ec -ne 0) {
        Add-TaskError -Title "Le nettoyage profond n'a pas pu se terminer" -Code ('0x{0:X8}' -f $ec) -Cause "Windows est peut-être en train d'installer une mise à jour, ou un redémarrage est en attente." `
            -Effect "Rien n'est cassé : les anciens composants sont juste encore là." -FixLabel "Redémarrer puis réessayer" -FixAction 'Request-Reboot' -Steps @("Redémarre le PC.", "Relance « Nettoyage profond » dans l'onglet Nettoyage.")
    } else { Log ("✅ Nettoyage profond terminé : environ {0} libérés" -f (Format-Size $gain)) }
}

function Enable-StorageSense {
    Step "Activation du nettoyage automatique (Assistant stockage)"
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy'
    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    Set-ItemProperty -Path $key -Name '01' -Value 1 -Type DWord
    Set-ItemProperty -Path $key -Name '04' -Value 1 -Type DWord
    Log "   ✔ Windows supprimera maintenant tout seul les fichiers temporaires régulièrement."
    Add-Change -Title "Nettoyage automatique de Windows activé (Assistant stockage)" -Undo 'Disable-StorageSense'
    Start-Process 'ms-settings:storagesense'
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
    foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*') {
        foreach ($e in @(Get-ItemProperty $k -ErrorAction SilentlyContinue)) {
            if (-not $e.DisplayName -or $e.SystemComponent -eq 1 -or $e.ParentKeyName -or $e.ReleaseType -match 'Update|Hotfix') { continue }
            if (-not $e.UninstallString -and -not $e.QuietUninstallString) { continue }
            $name = "$($e.DisplayName)".Trim()
            if ($seen.ContainsKey($name)) { continue }; $seen[$name] = $true
            $date = $null; if ("$($e.InstallDate)" -match '^(\d{4})(\d{2})(\d{2})$') { try { $date = Get-Date -Year $matches[1] -Month $matches[2] -Day $matches[3] } catch {} }
            $loc = Get-AppLocation $e
            $o = @{ Kind = 'win32'; Name = $name; Publisher = "$($e.Publisher)"; Size = $(if ($e.EstimatedSize) { [double]$e.EstimatedSize * 1KB } else { 0 }); Date = $date
                    Cmd = "$($e.UninstallString)"; Tag = ''; Reason = ''; Location = $loc; Drive = $(if ($loc -match '^([A-Za-z]:)') { $matches[1].ToUpper() } else { '' }) }
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
        foreach ($p in @(Get-AppxPackage -ErrorAction Stop | Where-Object { -not $_.IsFramework -and -not $_.NonRemovable -and $_.SignatureKind -ne 'System' })) {
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
function Uninstall-App([string]$Kind, [string]$Cmd, [string]$Name) {
    if ($Kind -eq 'store') {
        Remove-AppxPackage -Package $Cmd -ErrorAction Stop
        return
    }
    if ($Cmd -match '(?i)msiexec(\.exe)?\s.*?(\{[0-9A-F\-]+\})') {
        Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList '/X', $matches[2]
    } elseif ($Cmd -match '^\s*"([^"]+)"\s*(.*)$') {
        if ($matches[2]) { Start-Process -FilePath $matches[1] -ArgumentList $matches[2] } else { Start-Process -FilePath $matches[1] }
    } elseif ($Cmd -match '^(.+?\.exe)\s*(.*)$') {
        if ($matches[2]) { Start-Process -FilePath $matches[1] -ArgumentList $matches[2] } else { Start-Process -FilePath $matches[1] }
    } else { throw "Commande de désinstallation inconnue : $Cmd" }
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
    $list = @()
    $defs = @(
        @{ Name = 'Google Chrome';  Proc = 'chrome'; Dir = "$env:LOCALAPPDATA\Google\Chrome\User Data" },
        @{ Name = 'Microsoft Edge'; Proc = 'msedge'; Dir = "$env:LOCALAPPDATA\Microsoft\Edge\User Data" },
        @{ Name = 'Brave';          Proc = 'brave';  Dir = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data" },
        @{ Name = 'Opera GX';       Proc = 'opera';  Dir = "$env:LOCALAPPDATA\Opera Software\Opera GX Stable" },
        @{ Name = 'Opera';          Proc = 'opera';  Dir = "$env:LOCALAPPDATA\Opera Software\Opera Stable" }
    )
    foreach ($b in $defs) {
        if (-not (Test-Path -LiteralPath $b.Dir)) { continue }
        $profiles = @($b.Dir) + @(Get-ChildItem -LiteralPath $b.Dir -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(Default|Profile \d+)$' } | ForEach-Object { $_.FullName })
        $dirs = foreach ($p in $profiles) { foreach ($c in 'Cache', 'Code Cache', 'GPUCache', 'GrShaderCache', 'ShaderCache', 'DawnCache', 'DawnGraphiteCache', 'DawnWebGPUCache') { Join-Path $p $c } }
        $list += @{ Name = $b.Name; Proc = $b.Proc; Dirs = @($dirs) }
    }
    $ff = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
    if (Test-Path -LiteralPath $ff) { $list += @{ Name = 'Firefox'; Proc = 'firefox'; Dirs = @(Get-ChildItem -LiteralPath $ff -Directory -ErrorAction SilentlyContinue | ForEach-Object { Join-Path $_.FullName 'cache2' }) } }
    return $list
}
function Get-AppCacheDirs {
    $l = $env:LOCALAPPDATA; $r = $env:APPDATA
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
    $l = $env:LOCALAPPDATA; $ll = Join-Path $env:USERPROFILE 'AppData\LocalLow'
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
    $rb = [double]0; foreach ($d in Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3') { $rb += [AeroxNative]::FolderSize(("{0}\`$Recycle.Bin" -f $d.DeviceID)) }
    & $add @{ Id = 'recycle'; Name = 'Corbeille'; Default = $false; Size = $rb; Desc = "Vide la corbeille de tous les disques. Vérifie avant qu'il n'y a rien dedans dont tu as besoin." }
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
    $p = Start-Process -FilePath "$env:SystemRoot\System32\cleanmgr.exe" -ArgumentList "/sagerun:$Slot" -PassThru
    $p.WaitForExit()
}

function Invoke-DeepClean([string[]]$Ids) {
    $free0 = [double](Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'").FreeSpace
    if ($Ids -contains 'browser') {
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
    if ($Ids -contains 'apps') {
        Step "Cache des applications"
        foreach ($a in Get-AppCacheDirs) {
            if (Get-Process -Name $a.Proc -ErrorAction SilentlyContinue) { Log "   • $($a.Name) est ouvert : ignoré (ferme-le et relance pour le nettoyer)"; continue }
            Clear-Paths $a.Dirs $a.Name
        }
    }
    if ($Ids -contains 'temp') { Step "Fichiers temporaires"; Clear-Paths (Get-TempOnlyDirs) 'Fichiers temporaires' }
    if ($Ids -contains 'shaders') { Step "Cache des shaders"; Clear-Paths (Get-ShaderCacheDirs) 'Cache des shaders' }
    if ($Ids -contains 'errors') { Step "Rapports d'erreurs et de plantages"; Clear-Paths (Get-ErrorDirs) "Rapports d'erreurs" }
    if ($Ids -contains 'wupdate') {
        Step "Fichiers de mises à jour Windows"
        Stop-Service -Name wuauserv, bits -Force -ErrorAction SilentlyContinue
        Clear-Paths @("$env:SystemRoot\SoftwareDistribution\Download") 'Mises à jour téléchargées'
        Start-Service -Name bits, wuauserv -ErrorAction SilentlyContinue
        if (Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue) { try { Delete-DeliveryOptimizationCache -Force -ErrorAction Stop | Out-Null; Log "   ✔ Cache d'optimisation de distribution vidé" } catch {} }
    }
    if ($Ids -contains 'recycle') { Clear-RecycleBinAll }
    if ($Ids -contains 'windows') {
        Step "Nettoyage de disque Windows (peut prendre plusieurs minutes)"
        try { Invoke-CleanMgr $script:CleanMgrSafe 7701; Log "   ✔ Nettoyage de disque Windows terminé" }
        catch { Add-TaskError -Title "Le nettoyage de disque Windows n'a pas pu se lancer" -Cause $_.Exception.Message -Bug $_ }
    }
    if ($Ids -contains 'winold') {
        Step "Suppression de l'ancienne version de Windows"
        try { Invoke-CleanMgr @('Previous Installations', 'Temporary Setup Files', 'Windows Upgrade Log Files') 7702; Log "   ✔ Ancienne version de Windows supprimée" }
        catch { Add-TaskError -Title "Windows.old n'a pas pu être supprimé" -Cause $_.Exception.Message -Bug $_ }
    }
    if ($Ids -contains 'components' -or $Ids -contains 'resetbase') {
        Step "Anciens composants Windows (DISM, 5 à 20 minutes)"
        $dargs = @('/Online', '/Cleanup-Image', '/StartComponentCleanup')
        if ($Ids -contains 'resetbase') { $dargs += '/ResetBase' }
        $ec = Invoke-Native 'dism.exe' $dargs -Quiet
        if ($ec -ne 0) {
            Add-TaskError -Title "Le nettoyage des anciens composants n'a pas pu se terminer" -Code ('0x{0:X8}' -f $ec) -Cause "Windows est peut-être en train d'installer une mise à jour, ou un redémarrage est en attente." `
                -Effect "Rien n'est cassé : les anciens composants sont juste encore là." -FixLabel "Redémarrer puis réessayer" -FixAction 'Request-Reboot'
        } else { Log "   ✔ Anciens composants Windows nettoyés" }
    }
    if ($Ids -contains 'hiber') {
        Step "Désactivation de la veille prolongée"
        $null = Invoke-Native 'powercfg.exe' @('/hibernate', 'off')
        if (Test-Path -LiteralPath "$env:SystemDrive\hiberfil.sys") { Log "   • Le fichier disparaîtra au prochain redémarrage" } else { Log "   ✔ hiberfil.sys supprimé" }
        Add-Change -Title "Veille prolongée désactivée" -Detail "Libère la place du fichier hiberfil.sys." -Undo 'Enable-Hibernation'
    }
    $free1 = [double](Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'").FreeSpace
    Step "Résultat"
    Log ("✅ Espace libéré sur {0} : {1} (maintenant {2} libres)" -f $env:SystemDrive, (Format-Size ([math]::Max(0, $free1 - $free0))), (Format-Size $free1))
    Add-Change -Kind 'info' -Title ("Nettoyage approfondi : {0} libérés" -f (Format-Size ([math]::Max(0, $free1 - $free0)))) -Detail "Fichiers inutiles supprimés (temporaires, caches, anciennes mises à jour). Pas besoin de les récupérer : Windows et les logiciels les recréent si nécessaire."
}

# Ce qui prend de la place sur le disque (arbre des dossiers)
function Get-SpaceUsage([string]$Drive = $env:SystemDrive) {
    Step "Analyse de l'espace sur $Drive (1 à 3 minutes selon le disque)"
    $sync.SpaceScan = $null
    $lines = [AeroxNative]::ScanSizes("$Drive\", 4)
    $d = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$Drive'"
    $sync.SpaceScan = @{ Lines = $lines; Drive = $Drive; Size = [double]$d.Size; Free = [double]$d.FreeSpace }
    Log ("   ✔ Analyse terminée : {0} dossiers mesurés." -f $lines.Count)
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
    else { Add-TaskError -Title "Impossible de revenir au mode Équilibré" -Cause "Le mode Équilibré n'existe pas sur ce PC." -FixLabel "Ouvrir les options d'alimentation" -FixAction "Start-Process 'powercfg.cpl'" }
}
function Get-VisualFxStatus {
    try { $v = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name VisualFXSetting -ErrorAction Stop).VisualFXSetting } catch { $v = 0 }
    return [int]$v
}
function Get-StorageSenseOn {
    try { return ((Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' -Name '01' -ErrorAction Stop).'01' -eq 1) } catch { return $false }
}
function Disable-StorageSense {
    Step "Désactivation du nettoyage automatique"
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy'
    if (Test-Path $key) { Set-ItemProperty -Path $key -Name '01' -Value 0 -Type DWord }
    Log "   ✔ Nettoyage automatique désactivé."
    Add-Change -Title "Nettoyage automatique de Windows désactivé (Assistant stockage)" -Undo 'Enable-StorageSense'
}

# ---------------------------------------------------------------- OUTILS DE MESURE (téléchargés à la demande)
function Get-ToolsDir { $d = Join-Path $AppInfo.LogDir 'outils'; New-Item -ItemType Directory -Force -Path $d | Out-Null; return $d }
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
              Nvsmi = [bool]((Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue) -or (Test-Path "$env:SystemRoot\System32\nvidia-smi.exe")) }
}
function Find-PresentMon {
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
    if (-not $wg) {
        Add-TaskError -Title "L'outil d'installation de Microsoft (winget) est absent" -Cause "Le « Programme d'installation d'application » de Microsoft n'est pas installé ou trop ancien." `
            -Effect "$Label ne peut pas être installé automatiquement." -FixLabel "L'installer (Microsoft Store)" -FixAction 'Open-WingetStore'
        return $false
    }
    $ec = Invoke-Native $wg (@('install', '--id', $Id, '--exact', '--silent', '--accept-package-agreements', '--accept-source-agreements') + (Get-WingetExtraArgs $wg)) ([System.Text.Encoding]::UTF8)
    return ($ec -eq 0 -or $ec -eq -1978335189 -or $ec -eq -1978335135)
}

function Install-PresentMon {
    Step "Installation du compteur de FPS (PresentMon, outil officiel d'Intel, via winget)"
    $null = Install-WingetTool 'Intel.PresentMon.Console' 'Le compteur de FPS'
    $pm = Find-PresentMon
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
            -FixLabel "Ouvrir le site de PawnIO" -FixAction "Start-Process 'https://pawnio.eu/'" -Steps @("Redémarre le PC puis relance AEROX PC Care.", "Sinon, télécharge l'installateur officiel sur pawnio.eu et lance-le.")
    }
}

# ---------------------------------------------------------------- MISES À JOUR
function Open-WingetStore {
    Log "   → J'ouvre le Microsoft Store : installe ou mets à jour « Programme d'installation d'application », puis relance AEROX PC Care."
    Start-Process 'ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1'
}

function Update-Apps {
    Step "Recherche des mises à jour de logiciels (winget)"
    $apps = Get-AppUpdates
    if ($null -eq $apps) {
        Add-TaskError -Title "L'outil de mise à jour des logiciels (winget) est absent" -Cause "Le « Programme d'installation d'application » de Microsoft n'est pas installé ou trop ancien." `
            -Effect "Les logiciels ne peuvent pas être mis à jour automatiquement." -FixLabel "L'installer (Microsoft Store)" -FixAction 'Open-WingetStore'
        return
    }
    $ign = @(Get-IgnoredApps).Count
    if ($ign) { Log "   ($ign logiciel(s) ignoré(s) à ta demande : ils ne seront pas touchés)" }
    if ($apps.Count -eq 0) { Log "✅ Tous tes logiciels sont à jour."; return }
    Update-SelectedApps -Ids @($apps | ForEach-Object { $_.Id }) -Names @($apps | ForEach-Object { $_.Name })
}

function Update-SelectedApps([string[]]$Ids, [string[]]$Names) {
    $wg = Get-Winget
    if (-not $wg) {
        Add-TaskError -Title "L'outil de mise à jour des logiciels (winget) est absent" -Cause "Le « Programme d'installation d'application » de Microsoft n'est pas installé ou trop ancien." `
            -FixLabel "L'installer (Microsoft Store)" -FixAction 'Open-WingetStore'
        return
    }
    $extra = Get-WingetExtraArgs $wg
    $failed = @(); $ok = 0; $n = 0
    for ($k = 0; $k -lt $Ids.Count; $k++) {
        $id = $Ids[$k]; $name = if ($Names -and $k -lt $Names.Count -and $Names[$k]) { $Names[$k] } else { $id }
        $n++
        Step ("Mise à jour {0}/{1} : {2}" -f $n, $Ids.Count, $name)
        $idArgs = if ($id.EndsWith([string][char]0x2026)) { @('--id', $id.TrimEnd([char]0x2026)) } else { @('--id', $id, '--exact') }
        $ec = Invoke-Native $wg (@('upgrade') + $idArgs + @('--silent', '--accept-package-agreements', '--accept-source-agreements') + $extra) ([System.Text.Encoding]::UTF8)
        if ($ec -eq 0) { $ok++; Log "   ✔ $name mis à jour"; Add-Change -Kind 'info' -Title "« $name » mis à jour" -Detail "Pour revenir à l'ancienne version, il faut la réinstaller depuis le site du logiciel." }
        elseif ($ec -eq -1978335189) { $ok++; Log "   • $name : déjà à jour" }
        else {
            $why = switch ($ec) {
                -1978334975 { "le logiciel est ouvert, ferme-le puis réessaie" }
                -1978334974 { "une autre installation est déjà en cours" }
                -1978335212 { "logiciel introuvable dans le catalogue" }
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
    Log ("✅ {0} logiciel(s) mis à jour sur {1}." -f $ok, $Ids.Count)
}

# Pour la fenêtre de choix : liste complète, ignorés compris
function Get-AppUpdatesForUi {
    Step "Recherche des logiciels à mettre à jour"
    $sync.AppList = $null
    $apps = Get-AppUpdates -IncludeIgnored
    if ($null -eq $apps) {
        Add-TaskError -Title "L'outil de mise à jour des logiciels (winget) est absent" -Cause "Le « Programme d'installation d'application » de Microsoft n'est pas installé ou trop ancien." `
            -FixLabel "L'installer (Microsoft Store)" -FixAction 'Open-WingetStore'
        return
    }
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
        $code = '0x{0:X8}' -f $_.Exception.HResult
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
        $code = '0x{0:X8}' -f $_.Exception.HResult
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

function Open-DriverUpdates {
    Step "Pilotes (drivers)"
    foreach ($g in Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue) {
        Log ("   • Carte graphique : {0} (pilote {1})" -f $g.Name, $g.DriverVersion)
        if     ($g.Name -match 'NVIDIA')     { Log "     → Mets-la à jour avec « NVIDIA App » (site officiel nvidia.com)." }
        elseif ($g.Name -match 'AMD|Radeon') { Log "     → Mets-la à jour avec « AMD Software: Adrenalin Edition » (site officiel amd.com)." }
        elseif ($g.Name -match 'Intel')      { Log "     → Mets-la à jour avec « Intel Driver & Support Assistant » (site officiel intel.com)." }
    }
    Log "   → J'ouvre les mises à jour facultatives de Windows : regarde dans « Mises à jour des pilotes »."
    Log "   ⚠ N'utilise jamais de « logiciel de mise à jour de pilotes » trouvé sur Internet : souvent des arnaques."
    Start-Process 'ms-settings:windowsupdate-optionalupdates'
}

function Open-WindowsUpdate { Start-Process 'ms-settings:windowsupdate'; Log "   ✔ Windows Update ouvert" }

# ---------------------------------------------------------------- SÉCURITÉ (réparations)
function Enable-RealtimeProtection {
    Step "Réactivation de la protection en temps réel"
    try { Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop } catch {}
    Start-Sleep -Seconds 2
    $on = $false; try { $on = (Get-MpComputerStatus -ErrorAction Stop).RealTimeProtectionEnabled } catch {}
    if ($on) { Log "   ✔ Protection en temps réel réactivée" }
    else {
        Add-TaskError -Title "La protection en temps réel n'a pas pu être réactivée" -Cause "La « Protection contre les falsifications » de Windows empêche les logiciels de la modifier (c'est normal, c'est une sécurité)." `
            -Effect "Il faut la réactiver à la main, ça prend 10 secondes." -FixLabel "Ouvrir Sécurité Windows" -FixAction "Start-Process 'windowsdefender://threat'" `
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
    catch { Add-TaskError -Title "Le pare-feu n'a pas pu être réactivé" -Cause $_.Exception.Message -FixLabel "Ouvrir les réglages du pare-feu" -FixAction "Start-Process 'windowsdefender://network'" }
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
    $null = Invoke-Native 'netsh.exe'   @('int', 'ip', 'reset')
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
    $null = Invoke-Native 'sfc.exe' @('/scannow') ([System.Text.Encoding]::Unicode)
    $out = ($script:NativeOutput -join "`n")
    if ($out -match "(?i)unable to fix|n.a pas pu (en )?(réparer|corriger)|impossible de (réparer|corriger)") {
        Add-TaskError -Title "Des fichiers système abîmés n'ont pas pu être réparés" -Cause "SFC a trouvé des fichiers corrompus mais n'a pas pu tous les remplacer." `
            -Effect "Des bugs ou plantages de Windows peuvent continuer." -FixLabel "Redémarrer puis relancer" -FixAction 'Request-Reboot' `
            -Steps @("Redémarre le PC.", "Relance « Réparer les fichiers de Windows ».", "Si l'erreur revient : Paramètres > Système > Récupération > « Résoudre les problèmes avec Windows Update » réinstalle Windows en gardant tes fichiers.")
    } elseif ($out -match "(?i)could not perform|n.a pas pu effectuer") {
        Add-TaskError -Title "La vérification SFC n'a pas pu se lancer" -Cause "Une réparation ou une mise à jour Windows est déjà en attente de redémarrage." -FixLabel "Redémarrer" -FixAction 'Request-Reboot'
    } elseif ($out -match "(?i)successfully repaired|les a réparés|a réparé") {
        Log "✅ Des fichiers abîmés ont été trouvés et réparés. Redémarre le PC."
        $sync.NeedReboot = $true
    } else { Log "✅ Réparation terminée : aucun fichier système abîmé." }
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
        Start-Process 'ms-settings:powersleep'
    }
    if (Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue) { Log "   ⚠ C'est un portable : ce mode vide la batterie plus vite. Idéal quand tu es branché." }
}

function Open-VisualEffects {
    Step "Effets visuels"
    Log "   → Coche « Ajuster afin d'obtenir les meilleures performances », puis recoche « Lisser les polices écran » et clique sur OK."
    Start-Process 'SystemPropertiesPerformance.exe'
}

function Open-AppsSettings {
    Step "Logiciels installés"
    Log "   → Désinstalle ce que tu n'utilises plus : barres d'outils, « optimiseurs » douteux, antivirus en double, jeux d'essai..."
    Log "   → Dans le doute (pilote, Microsoft Visual C++, .NET), n'y touche pas."
    Start-Process 'ms-settings:appsfeatures'
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

function Find-AppUpdate {
    $sync.UpdateDone = $false
    try {
        if (-not $AppInfo.Repo) { return }
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $r = Invoke-RestMethod -Uri ("https://api.github.com/repos/{0}/releases/latest" -f $AppInfo.Repo) -Headers @{ 'User-Agent' = 'AeroxPCCare' } -TimeoutSec 10 -ErrorAction Stop
        $v = ($r.tag_name -replace '^[vV]', '')
        if ([version]$v -gt [version]$AppInfo.Version) {
            $asset = @($r.assets | Where-Object { $_.name -match '(?i)setup.*\.exe$' }) | Select-Object -First 1
            $sync.UpdateInfo = @{ Version = $v; Url = $r.html_url; Notes = "$($r.body)"
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
        Add-TaskError -Title "Aucune mise à jour à installer" -Cause "La nouvelle version n'a pas d'installateur à télécharger." -FixLabel "Ouvrir la page de téléchargement" -FixAction "Start-Process '$($u.Url)'"
        return
    }
    Step ("Téléchargement d'AEROX PC Care {0} depuis GitHub" -f $u.Version)
    try {
        $sha = if ("$($u.Digest)" -match '^sha256:([0-9a-fA-F]{64})$') { $Matches[1] } else { '' }
        $dest = Join-Path (Join-Path $AppInfo.LogDir 'maj') ("AeroxPCCare_Setup_{0}.exe" -f $u.Version)
        [AeroxUpdate]::Download($u.Setup, $dest, $sha)
        Log ("   ✔ Installateur téléchargé{0}." -f $(if ($sha) { ' et vérifié (empreinte SHA-256 identique à celle publiée)' } else { '' }))
        $sync.UpdateReady = $dest
    } catch {
        $m = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message }
        Add-TaskError -Title "La mise à jour n'a pas pu être téléchargée" -Cause $m -Effect "Tu gardes la version actuelle, rien n'a été modifié." `
            -FixLabel "Réessayer" -FixAction 'Install-AppUpdate' -Steps @("Vérifie ta connexion Internet.", "Si ton antivirus a bloqué le téléchargement, autorise-le puis réessaie.", "Sinon, télécharge AeroxPCCare_Setup.exe à la main sur la page GitHub du logiciel.")
    }
}
}
