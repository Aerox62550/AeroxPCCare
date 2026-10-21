# Outils communs des tests d'installation (Windows PowerShell 5.1, machine de test GitHub : rien d'autre n'y est touché).
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch {}
$script:Lignes = New-Object 'System.Collections.Generic.List[string]'
$script:Echecs = New-Object 'System.Collections.Generic.List[string]'

function Note([string]$t) { $script:Lignes.Add($t); Write-Host $t }

# Résultat lisible via l'API GitHub (annotations). GitHub ne garde que 10 annotations par étape et coupe chacune vers 4 000 octets :
# la première est le résumé (les échecs), les neuf autres portent le détail, découpé par blocs de 3 000 caractères au plus
# (la fin du détail est coupée s'il est vraiment trop long).
function Envoyer([string]$Titre) {
    $L = @($script:Lignes)
    $resume = "{0} échec(s)" -f $script:Echecs.Count
    foreach ($e in $script:Echecs) { $resume += "`n  - " + $e }
    if ($resume.Length -gt 3000) { $resume = $resume.Substring(0, 3000) + '…' }
    Write-Host ("::notice title=$Titre résumé::" + $resume.Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A'))
    $blocs = New-Object 'System.Collections.Generic.List[string]'
    $cur = ''
    foreach ($ligne in $L) {
        $l = "$ligne"; if ($l.Length -gt 2000) { $l = $l.Substring(0, 2000) + '…' }
        if ($cur.Length -gt 0 -and ($cur.Length + $l.Length + 1) -gt 3000) { $blocs.Add($cur); $cur = '' }
        $cur = $(if ($cur.Length) { $cur + "`n" + $l } else { $l })
    }
    if ($cur.Length) { $blocs.Add($cur) }
    for ($i = 0; $i -lt $blocs.Count -and $i -lt 9; $i++) {
        $chunk = $blocs[$i].Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A')
        Write-Host ("::notice title=$Titre {0}::{1}" -f ($i + 1), $chunk)
    }
}

# Un test : une phrase qui dit ce qui est vérifié, un bloc qui lève une erreur si ce n'est pas le cas
function Verifier([string]$Nom, [scriptblock]$Code) {
    Note ''
    Note ("--- {0}" -f $Nom)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try { & $Code; Note ("[OK   ] {0} ({1:n1} s)" -f $Nom, $sw.Elapsed.TotalSeconds) }
    catch {
        $m = ("{0} : {1}" -f $Nom, $_.Exception.Message)
        $script:Echecs.Add($m)
        Note ("[ECHEC] {0} ({1:n1} s)" -f $m, $sw.Elapsed.TotalSeconds)
    }
}
function Exiger($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }

# Fenêtres d'un processus : « visible | classe | titre | pos=G,H taille=LxH || texte des boîtes de dialogue »
if (-not ('AeroxTestWin' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class AeroxTestWin {
    delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc p, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr h, EnumProc p, IntPtr l);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr SendMessageTimeout(IntPtr h, int msg, int wp, StringBuilder lp, int flags, int timeout, out IntPtr result);
    public static string[] ForPid(int pid) {
        List<string> res = new List<string>();
        EnumWindows(delegate (IntPtr h, IntPtr l) {
            uint p; GetWindowThreadProcessId(h, out p);
            if (p != (uint)pid) return true;
            bool vis = IsWindowVisible(h);
            StringBuilder t = new StringBuilder(512); GetWindowText(h, t, 512);
            StringBuilder c = new StringBuilder(256); GetClassName(h, c, 256);
            if (!vis && t.Length == 0) return true;
            List<string> kids = new List<string>();
            EnumChildWindows(h, delegate (IntPtr k, IntPtr l2) {
                StringBuilder kc = new StringBuilder(256); GetClassName(k, kc, 256);
                string cn = kc.ToString();
                if (cn == "Static" || cn == "Button") {
                    StringBuilder kt = new StringBuilder(2048); IntPtr r;
                    SendMessageTimeout(k, 0x000D, 2048, kt, 2, 500, out r);
                    if (kt.Length > 0) kids.Add(cn + ":" + kt.ToString().Replace("\r", " ").Replace("\n", " "));
                }
                return true;
            }, IntPtr.Zero);
            RECT rc; GetWindowRect(h, out rc);
            string line = (vis ? "visible" : "cachee") + " | " + c.ToString() + " | " + t.ToString() + " | pos=" + rc.L + "," + rc.T + " taille=" + (rc.R - rc.L) + "x" + (rc.B - rc.T);
            if (kids.Count > 0) line += " || " + string.Join(" // ", kids.ToArray());
            res.Add(line);
            return true;
        }, IntPtr.Zero);
        return res.ToArray();
    }
}
'@
}

function Stop-Aerox {
    foreach ($pr in @(Get-Process -Name 'AeroxPCCare' -ErrorAction SilentlyContinue)) { try { $pr.Kill() } catch {} }
    for ($i = 0; $i -lt 30; $i++) { if (-not (Get-Process -Name 'AeroxPCCare' -ErrorAction SilentlyContinue)) { break }; Start-Sleep -Milliseconds 500 }
}

function Start-Exe([string]$Exe, [string]$Arguments = '') {
    $psi = New-Object System.Diagnostics.ProcessStartInfo $Exe
    $psi.WorkingDirectory = Split-Path $Exe -Parent
    $psi.UseShellExecute = $false
    if ($Arguments) { $psi.Arguments = $Arguments }
    return [System.Diagnostics.Process]::Start($psi)
}

# Attend qu'une fenêtre dont la ligne correspond au motif apparaisse, ou que le processus se termine
function Wait-Fenetre($P, [string]$Motif, [int]$Max = 90) {
    $t0 = Get-Date
    while (((Get-Date) - $t0).TotalSeconds -lt $Max) {
        $sorti = $false; try { $sorti = $P.HasExited } catch { $sorti = $true }
        if ($sorti) { $code = $null; try { $code = $P.ExitCode } catch {}; return @{ Sorti = $true; Code = $code; Delai = $false; Fenetres = @() } }
        $w = @([AeroxTestWin]::ForPid($P.Id))
        if (@($w | Where-Object { $_ -match $Motif }).Count) { return @{ Sorti = $false; Code = $null; Delai = $false; Fenetres = $w } }
        Start-Sleep -Milliseconds 700
    }
    return @{ Sorti = $false; Code = $null; Delai = $true; Fenetres = @([AeroxTestWin]::ForPid($P.Id)) }
}

function Note-Fenetres($R) {
    if ($R.Sorti) { Note ("  processus terminé tout seul, code de sortie = {0}" -f $R.Code) }
    elseif ($R.Delai) { Note '  délai dépassé sans la fenêtre attendue' }
    foreach ($w in $R.Fenetres) { Note ('  fenêtre : ' + $w) }
}

# Lance l'installateur (ou le désinstalleur) et attend qu'il ait fini : renvoie son code de sortie
function Lancer-Programme([string]$Exe, [string]$Arguments, [int]$SecondesMax = 240) {
    $p = Start-Process -FilePath $Exe -ArgumentList $Arguments -PassThru
    $null = $p.Handle   # sinon ExitCode reste vide
    if (-not $p.WaitForExit($SecondesMax * 1000)) { try { $p.Kill() } catch {}; throw "programme bloqué (plus de $SecondesMax s) : $Exe $Arguments" }
    return $p.ExitCode
}

# Reprend telles quelles des fonctions (et variables) du programme construit, pour les tester sans lancer l'interface.
# Utilisation : Invoke-Expression (Get-CodeAerox $script @('Fonction1', 'Fonction2') @('$script:Variable'))   (au niveau du script de test)
function Get-CodeAerox([string]$ScriptPath, [string[]]$Fonctions, [string[]]$Variables = @()) {
    $src = [IO.File]::ReadAllText($ScriptPath)
    $tok = $null; $err = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($src, [ref]$tok, [ref]$err)
    $parts = New-Object 'System.Collections.Generic.List[string]'
    foreach ($v in $Variables) {
        $x = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq $v }, $true)) | Select-Object -First 1
        if (-not $x) { throw "variable introuvable dans le programme : $v" }
        $parts.Add($x.Extent.Text)
    }
    foreach ($f in $Fonctions) {
        $x = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $f }, $true)) | Select-Object -First 1
        if (-not $x) { throw "fonction introuvable dans le programme : $f" }
        $parts.Add($x.Extent.Text)
    }
    return ($parts -join "`n")
}

# Tâche planifiée « mode discret » : même définition que Set-AutoStart du programme (droits les plus élevés, à l'ouverture de session)
function Register-TacheDiscret([string]$Exe, [string]$Nom) {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $a = New-ScheduledTaskAction -Execute $Exe -Argument '--discret'
    $t = New-ScheduledTaskTrigger -AtLogOn -User $user; $t.Delay = 'PT45S'
    $p = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
    $s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $Nom -Action $a -Trigger $t -Principal $p -Settings $s -Description 'Test AEROX' -Force -ErrorAction Stop | Out-Null
}

# Programme visé par la tâche (sans guillemets), ses paramètres, son niveau d'exécution
function Get-TacheInfo([string]$Nom) {
    $t = Get-ScheduledTask -TaskName $Nom -ErrorAction Stop
    $a = @($t.Actions)[0]
    return @{ Cible = ("$($a.Execute)".Trim().Trim('"')); Arguments = "$($a.Arguments)"; Niveau = "$($t.Principal.RunLevel)"; Declencheurs = @($t.Triggers).Count }
}
