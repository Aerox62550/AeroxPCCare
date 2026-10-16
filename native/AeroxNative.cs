// AEROX PC Care - fonctions natives (compilées en DLL pour ne pas mettre de code Windows dans le script)
// Tailles de dossiers, fenêtre au premier plan, overlay « clic au travers », raccourci clavier global
// (RegisterHotKey), compteur de FPS (PresentMon), téléchargement de paquets NuGet.
using System;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Xml;
using System.Text;
using System.Text.RegularExpressions;
using System.Diagnostics;
using System.Globalization;
using System.Reflection;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

[assembly: AssemblyTitle("AEROX PC Care - Native")]
[assembly: AssemblyProduct("AEROX PC Care")]

public static class AeroxNative {
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] static extern IntPtr GetWindowLongPtr64(IntPtr h, int i);
    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW")] static extern IntPtr SetWindowLongPtr64(IntPtr h, int i, IntPtr v);

    public static int ForegroundPid() {
        uint pid = 0;
        try { GetWindowThreadProcessId(GetForegroundWindow(), out pid); } catch { }
        return (int)pid;
    }

    // Overlay : fenêtre outil, non activable ; « clic au travers » quand on ne la déplace pas
    public static void SetClickThrough(IntPtr h, bool clickThrough) {
        const int GWL_EXSTYLE = -20;
        long s = GetWindowLongPtr64(h, GWL_EXSTYLE).ToInt64();
        s |= 0x80000L | 0x80L | 0x08000000L;
        if (clickThrough) s |= 0x20L; else s &= ~0x20L;
        SetWindowLongPtr64(h, GWL_EXSTYLE, new IntPtr(s));
    }

    // Taille d'un dossier (ne suit jamais les liens / jonctions, ignore les accès refusés)
    public static long FolderSize(string path) {
        long total = 0;
        if (string.IsNullOrEmpty(path) || !Directory.Exists(path)) return 0;
        Stack<string> st = new Stack<string>();
        st.Push(path);
        while (st.Count > 0) {
            string d = st.Pop();
            try {
                foreach (FileSystemInfo fi in new DirectoryInfo(d).EnumerateFileSystemInfos()) {
                    try {
                        if ((fi.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                        if ((fi.Attributes & FileAttributes.Directory) != 0) st.Push(fi.FullName);
                        else total += ((FileInfo)fi).Length;
                    } catch { }
                }
            } catch { }
        }
        return total;
    }

    // Tailles des dossiers jusqu'à une profondeur : "profondeur|octets|chemin" ; gros fichiers à la racine : "F|octets|chemin" ;
    // plus gros fichiers du disque (>= 500 Mo, 60 max) : "B|octets|date(ticks)|chemin" ; chaque jeu Steam est détaillé quelle que soit la profondeur.
    public static volatile bool StopScan = false;   // remis à false au lancement de chaque tâche (Start-AeroxTask)
    const long BigMin = 500L * 1024 * 1024;
    public static string[] ScanSizes(string root, int maxDepth) {
        List<string> outp = new List<string>();
        List<KeyValuePair<long, string>> big = new List<KeyValuePair<long, string>>();
        try {
            foreach (FileInfo f in new DirectoryInfo(root).EnumerateFiles()) {
                try { if (f.Length >= 100L * 1024 * 1024) outp.Add("F|" + f.Length + "|" + f.FullName); } catch { }
            }
        } catch { }
        ScanDir(root, 0, maxDepth, outp, big);
        big.Sort(delegate(KeyValuePair<long, string> a, KeyValuePair<long, string> b) { return b.Key.CompareTo(a.Key); });
        for (int i = 0; i < big.Count && i < 60; i++) outp.Add("B|" + big[i].Key + "|" + big[i].Value);
        return outp.ToArray();
    }
    static bool IsGamesDir(string d) {
        string p = Path.GetDirectoryName(d);
        return p != null && p.EndsWith("\\steamapps\\common", StringComparison.OrdinalIgnoreCase);
    }
    static long ScanDir(string d, int depth, int maxDepth, List<string> outp, List<KeyValuePair<long, string>> big) {
        long total = 0;
        try {
            foreach (FileSystemInfo fi in new DirectoryInfo(d).EnumerateFileSystemInfos()) {
                if (StopScan) return total;
                try {
                    if ((fi.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                    if ((fi.Attributes & FileAttributes.Directory) != 0) total += ScanDir(fi.FullName, depth + 1, maxDepth, outp, big);
                    else {
                        long len = ((FileInfo)fi).Length;
                        total += len;
                        if (len >= BigMin && depth >= 1) big.Add(new KeyValuePair<long, string>(len, fi.LastWriteTimeUtc.Ticks + "|" + fi.FullName));
                    }
                } catch { }
            }
        } catch { }
        if (depth >= 1 && (depth <= maxDepth || IsGamesDir(d))) outp.Add(depth + "|" + total + "|" + d);
        return total;
    }

    // Charge une bibliothèque .NET (et ses dépendances du même dossier) et crée un objet
    static string libDir = null;
    static bool resolverOn = false;
    [ThreadStatic] static bool resolving;
    static Assembly ResolveLib(object sender, ResolveEventArgs args) {
        if (resolving || libDir == null) return null;
        resolving = true;
        try {
            string name = new AssemblyName(args.Name).Name;
            foreach (Assembly a in AppDomain.CurrentDomain.GetAssemblies()) { if (a.GetName().Name == name) return a; }
            string p = Path.Combine(libDir, name + ".dll");
            if (File.Exists(p)) return Assembly.LoadFrom(p);
            return null;
        } catch { return null; }
        finally { resolving = false; }
    }
    public static object CreateFromLibrary(string dllPath, string typeName) {
        libDir = Path.GetDirectoryName(dllPath);
        if (!resolverOn) { resolverOn = true; AppDomain.CurrentDomain.AssemblyResolve += ResolveLib; }
        Assembly asm = Assembly.LoadFrom(dllPath);
        return Activator.CreateInstance(asm.GetType(typeName, true));
    }
}

// Capteurs : lance « AeroxPCCare.exe --capteurs » (processus séparé) et garde la dernière mesure.
// Si le module de températures plante, seul ce processus s'arrête : le logiciel reste ouvert.
public class AeroxSensorProc {
    Process proc;
    readonly object lk = new object();
    List<string> cur = new List<string>();
    string[] latest = null;
    DateTime latestAt = DateTime.MinValue;
    public string LastError = "";
    public bool Ready = false;
    public int Restarts = 0;
    public bool Running { get { try { return proc != null && !proc.HasExited; } catch { return false; } } }

    public bool Start(string launcherExe, string lhmDir) {
        Stop();
        try {
            ProcessStartInfo psi = new ProcessStartInfo(launcherExe,
                "--capteurs \"" + lhmDir.TrimEnd('\\') + "\" " + Process.GetCurrentProcess().Id);
            psi.UseShellExecute = false; psi.CreateNoWindow = true;
            psi.RedirectStandardOutput = true; psi.RedirectStandardError = true;
            psi.StandardOutputEncoding = Encoding.UTF8; psi.StandardErrorEncoding = Encoding.UTF8;
            proc = new Process(); proc.StartInfo = psi; proc.EnableRaisingEvents = true;
            proc.OutputDataReceived += OnLine;
            proc.ErrorDataReceived += delegate(object s, DataReceivedEventArgs e) {
                if (string.IsNullOrEmpty(e.Data)) return;
                LastError = e.Data.StartsWith("ERREUR|") ? e.Data.Substring(7) : e.Data;
            };
            proc.Exited += delegate(object s, EventArgs e) {
                try {
                    int code = ((Process)s).ExitCode;
                    if (code != 0 && LastError == "") LastError = "Le module de températures s'est arrêté (code 0x" + code.ToString("X8") + ").";
                } catch { }
            };
            proc.Start(); proc.BeginOutputReadLine(); proc.BeginErrorReadLine();
            return true;
        } catch (Exception ex) { LastError = ex.Message; return false; }
    }

    void OnLine(object s, DataReceivedEventArgs e) {
        string l = e.Data;
        if (l == null) return;
        lock (lk) {
            if (l == "OK") { Ready = true; return; }
            if (l == "---") { latest = cur.ToArray(); latestAt = DateTime.UtcNow; cur = new List<string>(); return; }
            if (cur.Count < 2000) cur.Add(l);
        }
    }

    // Dernière mesure ("Type|Matériel|TypeCapteur|Capteur|Valeur"), null si trop ancienne (> 5 s)
    public string[] Latest() {
        lock (lk) {
            if (latest == null || (DateTime.UtcNow - latestAt).TotalSeconds > 5) return null;
            return latest;
        }
    }

    public void Stop() {
        try { if (proc != null && !proc.HasExited) proc.Kill(); } catch { }
        try { if (proc != null) proc.Dispose(); } catch { }
        proc = null;
        lock (lk) { latest = null; cur = new List<string>(); Ready = false; }
    }
}

// Raccourci clavier global Ctrl + Maj + O via l'API officielle (RegisterHotKey)
public class AeroxHotkey : NativeWindow {
    [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    const int Id = 0xA370;
    static AeroxHotkey inst;
    public static int Presses = 0;
    // Essaie Ctrl+Maj+O, puis Ctrl+Alt+O, puis Ctrl+Maj+F10 ; renvoie le raccourci retenu ("" si aucun)
    public static string Register() {
        if (inst == null) { inst = new AeroxHotkey(); inst.CreateHandle(new CreateParams()); }
        uint[] mods = { 0x0002 | 0x0004, 0x0002 | 0x0001, 0x0002 | 0x0004 };
        uint[] keys = { 0x4F, 0x4F, 0x79 };
        string[] names = { "Ctrl + Maj + O", "Ctrl + Alt + O", "Ctrl + Maj + F10" };
        for (int i = 0; i < keys.Length; i++) { if (RegisterHotKey(inst.Handle, Id, mods[i] | 0x4000, keys[i])) return names[i]; }
        return "";
    }
    public static void Unregister() { if (inst != null) { UnregisterHotKey(inst.Handle, Id); inst.DestroyHandle(); inst = null; } }
    protected override void WndProc(ref Message m) {
        if (m.Msg == 0x0312 && m.WParam.ToInt32() == Id) Presses++;
        base.WndProc(ref m);
    }
}

// Compteur de FPS : lit la sortie de PresentMon (outil officiel d'Intel, sans injection dans les jeux)
public class AeroxFps {
    Process proc;
    readonly object lk = new object();
    Dictionary<int, List<double[]>> frames = new Dictionary<int, List<double[]>>();
    Dictionary<int, string> names = new Dictionary<int, string>();
    int cApp = -1, cPid = -1, cMs = -1;
    long lines = 0;
    Stopwatch sw = Stopwatch.StartNew();
    // Partie en cours (carnet de jeu) : toutes les images du jeu suivi, du début à la fin
    int sPid = 0;
    long sFrames = 0; int sStut = 0;
    double sMs = 0, sClock = 0, sEma = 0;
    int[] sHist = new int[2001];               // temps d'image par pas de 0,1 ms (dernière case : 200 ms et plus)
    List<double> minMs = new List<double>(); List<int> minN = new List<int>();
    public string LastError = "";
    public bool Running { get { try { return proc != null && !proc.HasExited; } catch { return false; } } }

    public bool Start(string exe) {
        Stop();
        try {
            ProcessStartInfo psi = new ProcessStartInfo(exe,
                "--output_stdout --no_console_stats --v1_metrics --stop_existing_session --session_name AeroxPCCareFps");
            psi.UseShellExecute = false; psi.CreateNoWindow = true;
            psi.RedirectStandardOutput = true; psi.RedirectStandardError = true;
            proc = new Process(); proc.StartInfo = psi;
            proc.OutputDataReceived += OnLine;
            proc.ErrorDataReceived += delegate(object s, DataReceivedEventArgs e) { if (!string.IsNullOrEmpty(e.Data)) LastError = e.Data; };
            proc.Start(); proc.BeginOutputReadLine(); proc.BeginErrorReadLine();
            return true;
        } catch (Exception ex) { LastError = ex.Message; return false; }
    }

    public void Feed(string l) { OnLineText(l); }
    void OnLine(object s, DataReceivedEventArgs e) { OnLineText(e.Data); }
    void OnLineText(string l) {
        if (string.IsNullOrEmpty(l)) return;
        string[] p = l.Split(',');
        if (cMs < 0 || l.StartsWith("Application,")) {
            for (int i = 0; i < p.Length; i++) {
                string hl = p[i].Trim().ToLowerInvariant();
                if (hl == "application") cApp = i;
                else if (hl == "processid") cPid = i;
                else if (hl == "msbetweenpresents") cMs = i;
                else if (cMs < 0 && (hl == "frametime" || hl == "msbetweendisplaychange")) cMs = i;
            }
            return;
        }
        if (cPid < 0 || cMs < 0 || p.Length <= Math.Max(cPid, cMs)) return;
        int pid; double ms;
        if (!int.TryParse(p[cPid], out pid)) return;
        if (!double.TryParse(p[cMs], NumberStyles.Float, CultureInfo.InvariantCulture, out ms) || ms <= 0 || ms > 5000) return;
        double now = sw.Elapsed.TotalMilliseconds;
        lock (lk) {
            List<double[]> lst;
            if (!frames.TryGetValue(pid, out lst)) { lst = new List<double[]>(); frames[pid] = lst; }
            lst.Add(new double[] { now, ms });
            if (pid == sPid && sPid != 0) SessionAdd(ms);
            if (cApp >= 0 && cApp < p.Length) names[pid] = p[cApp];
            if (lst.Count > 4000) lst.RemoveRange(0, lst.Count - 3000);
            // Ménage régulier : programmes qui n'affichent plus rien depuis 10 s (fermés, en veille…)
            if (++lines % 5000 == 0) {
                List<int> dead = new List<int>();
                foreach (KeyValuePair<int, List<double[]>> kv in frames) { if (kv.Key != sPid && (kv.Value.Count == 0 || now - kv.Value[kv.Value.Count - 1][0] > 10000)) dead.Add(kv.Key); }
                foreach (int k in dead) { frames.Remove(k); names.Remove(k); }
            }
        }
    }

    // [fps, 1% low, temps d'image moyen] ; null si le programme n'affiche rien
    public double[] Get(int pid) {
        double now = sw.Elapsed.TotalMilliseconds;
        lock (lk) {
            List<double[]> lst;
            if (!frames.TryGetValue(pid, out lst) || lst.Count == 0) return null;
            lst.RemoveAll(delegate(double[] f) { return now - f[0] > 10000; });
            if (lst.Count == 0 || now - lst[lst.Count - 1][0] > 1500) return null;
            double sum = 0; int n = 0;
            List<double> all = new List<double>();
            foreach (double[] f in lst) { all.Add(f[1]); if (now - f[0] <= 1000) { sum += f[1]; n++; } }
            if (n == 0) return null;
            double avg = sum / n;
            all.Sort();
            double p99 = all[Math.Min(all.Count - 1, (int)Math.Floor(all.Count * 0.99))];
            return new double[] { 1000.0 / avg, 1000.0 / p99, avg };
        }
    }
    public string AppName(int pid) { lock (lk) { string n; return names.TryGetValue(pid, out n) ? n : ""; } }

    public void BeginSession(int pid) {
        lock (lk) {
            sPid = pid; sFrames = 0; sStut = 0; sMs = 0; sClock = 0; sEma = 0;
            Array.Clear(sHist, 0, sHist.Length); minMs.Clear(); minN.Clear();
        }
    }
    public void EndSession() { lock (lk) { sPid = 0; } }
    public int SessionPid { get { return sPid; } }

    // Horloge du jeu = somme des temps d'image (identique au temps réel pendant que le jeu tourne)
    void SessionAdd(double ms) {
        sClock += ms;
        if (ms > 1000) return;                  // écran de chargement ou jeu en pause : pas une image jouée
        sFrames++; sMs += ms;
        int b = (int)Math.Round(ms * 10); if (b > 2000) b = 2000; sHist[b]++;
        // Saccade : une image nettement plus longue que les précédentes (après 15 s, le temps que le jeu charge)
        if (sClock > 15000 && sEma > 0 && ms > Math.Max(2.5 * sEma, sEma + 20)) sStut++;
        sEma = sEma <= 0 ? ms : sEma * 0.95 + ms * 0.05;
        int mi = (int)(sClock / 60000);
        if (mi > 1440) mi = 1440;
        while (minMs.Count <= mi) { minMs.Add(0); minN.Add(0); }
        minMs[mi] += ms; minN[mi]++;
    }
    double SessionPct(double q) {
        long target = (long)Math.Ceiling(sFrames * q), acc = 0;
        for (int i = 0; i < sHist.Length; i++) { acc += sHist[i]; if (acc >= target) return Math.Max(0.1, i / 10.0); }
        return 200;
    }
    // [images, secondes de jeu, FPS moyen, 1 % low, 0,1 % low, saccades]
    public double[] SessionStats() {
        lock (lk) {
            if (sFrames == 0 || sMs <= 0) return new double[] { 0, sClock / 1000.0, 0, 0, 0, 0 };
            return new double[] { sFrames, sClock / 1000.0, 1000.0 * sFrames / sMs, 1000.0 / SessionPct(0.99), 1000.0 / SessionPct(0.999), sStut };
        }
    }
    // FPS moyen de chaque minute de la partie (0 = pas d'image cette minute-là)
    public double[] SessionMinutes() {
        lock (lk) {
            double[] r = new double[minMs.Count];
            for (int i = 0; i < r.Length; i++) r[i] = (minN[i] > 0 && minMs[i] > 0) ? 1000.0 * minN[i] / minMs[i] : 0;
            return r;
        }
    }

    public void Stop() {
        try { if (proc != null && !proc.HasExited) proc.Kill(); } catch { }
        proc = null;
        lock (lk) { frames.Clear(); names.Clear(); }
        cApp = -1; cPid = -1; cMs = -1;
    }
}

// Jeux : programme au premier plan (plein écran ou non), chemin du programme, programme toujours ouvert
public static class AeroxGame {
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int L, T, R, B; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] struct MONITORINFO { public int cbSize; public RECT rcMonitor; public RECT rcWork; public int dwFlags; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string szDevice; }
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern IntPtr MonitorFromWindow(IntPtr h, uint flags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern bool GetMonitorInfo(IntPtr m, ref MONITORINFO mi);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder sb, int n);
    [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool QueryFullProcessImageName(IntPtr h, int flags, StringBuilder sb, ref int size);
    [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr h, uint ms);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    const uint QUERY_LIMITED = 0x1000, SYNCHRONIZE = 0x100000;

    static string ImagePath(IntPtr h) {
        StringBuilder sb = new StringBuilder(1024); int n = sb.Capacity;
        return QueryFullProcessImageName(h, 0, sb, ref n) ? sb.ToString(0, n) : "";
    }
    public static string ProcessPath(int pid) {
        IntPtr h = OpenProcess(QUERY_LIMITED, false, pid);
        if (h == IntPtr.Zero) return "";
        try { return ImagePath(h); } finally { CloseHandle(h); }
    }

    // « pid|chemin|1 si la fenêtre couvre tout son écran|classe de la fenêtre|écran (\\.\DISPLAY2) » ; vide si rien
    public static string Foreground() {
        try {
            IntPtr w = GetForegroundWindow(); if (w == IntPtr.Zero) return "";
            uint pid; GetWindowThreadProcessId(w, out pid); if (pid == 0) return "";
            StringBuilder cls = new StringBuilder(256); GetClassName(w, cls, 256);
            bool full = false; RECT r; string dev = "";
            if (GetWindowRect(w, out r)) {
                MONITORINFO mi = new MONITORINFO(); mi.cbSize = Marshal.SizeOf(typeof(MONITORINFO));
                IntPtr m = MonitorFromWindow(w, 2);
                if (m != IntPtr.Zero && GetMonitorInfo(m, ref mi)) {
                    full = r.L <= mi.rcMonitor.L && r.T <= mi.rcMonitor.T && r.R >= mi.rcMonitor.R && r.B >= mi.rcMonitor.B;
                    dev = mi.szDevice ?? "";
                }
            }
            return pid + "|" + ProcessPath((int)pid) + "|" + (full ? "1" : "0") + "|" + cls.ToString().Replace("|", "/") + "|" + dev;
        } catch { return ""; }
    }

    // Le programme tourne-t-il encore ? (même numéro ET même chemin : Windows réutilise les numéros)
    public static bool Alive(int pid, string path) {
        if (pid <= 0) return false;
        IntPtr h = OpenProcess(QUERY_LIMITED | SYNCHRONIZE, false, pid);
        if (h == IntPtr.Zero) return Marshal.GetLastWin32Error() == 5;   // accès refusé (anti-triche) : il est encore là
        try {
            if (WaitForSingleObject(h, 0) == 0) return false;
            if (!string.IsNullOrEmpty(path)) {
                string p = ImagePath(h);
                if (p.Length > 0 && !string.Equals(p, path, StringComparison.OrdinalIgnoreCase)) return false;
            }
            return true;
        } finally { CloseHandle(h); }
    }

    // Fenêtre principale cachée dans la zone de notification, puis réaffichée
    public static void Hide(IntPtr h) { if (h != IntPtr.Zero) ShowWindow(h, 0); }
    public static void Show(IntPtr h) { if (h == IntPtr.Zero) return; ShowWindow(h, 5); ShowWindow(h, 9); SetForegroundWindow(h); }
    public static bool Visible(IntPtr h) { return h != IntPtr.Zero && IsWindowVisible(h); }

    // Mode discret : rend à Windows la mémoire dont AEROX ne se sert plus (elle revient toute seule si besoin)
    [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
    [DllImport("kernel32.dll")] static extern bool SetProcessWorkingSetSize(IntPtr h, IntPtr min, IntPtr max);
    public static void TrimMemory() { try { SetProcessWorkingSetSize(GetCurrentProcess(), new IntPtr(-1), new IntPtr(-1)); } catch { } }
}

// Téléchargement d'un paquet NuGet officiel (nuget.org) et de ses dépendances, DLL pour .NET Framework
public static class AeroxNuget {
    static readonly string[] Tfms = { "net472", "net471", "net47", "net462", "net461", "net46", "net452", "net451", "net45", "netstandard2.0", "net40", "net35", "net20" };
    static readonly string[] Groups = { ".NETFramework4.7.2", "net472", ".NETFramework4.7.1", ".NETFramework4.7", ".NETFramework4.6.2", "net462", ".NETFramework4.6.1",
                                         ".NETFramework4.6", ".NETFramework4.5", ".NETStandard2.0", "netstandard2.0", ".NETFramework4.0", ".NETFramework3.5" };
    public static List<string> Log = new List<string>();

    public static int Install(string id, string version, string destDir) {
        ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
        Directory.CreateDirectory(destDir);
        Log.Clear();
        HashSet<string> seen = new HashSet<string>();
        Get(id, version, destDir, seen);
        return seen.Count;
    }

    static void Get(string id, string version, string dest, HashSet<string> seen) {
        string key = id.ToLowerInvariant();
        if (!seen.Add(key)) return;
        string v = version.ToLowerInvariant();
        string url = "https://api.nuget.org/v3-flatcontainer/" + key + "/" + v + "/" + key + "." + v + ".nupkg";
        byte[] data;
        using (WebClient wc = new WebClient()) { wc.Headers.Add("User-Agent", "AeroxPCCare"); data = wc.DownloadData(url); }
        Log.Add(id + " " + version + " (" + (data.Length / 1024) + " Ko)");
        ExtractPackage(data, dest, seen);
    }

    public static void ExtractPackage(byte[] data, string dest, HashSet<string> seen) {
        Directory.CreateDirectory(dest);
        using (ZipArchive zip = new ZipArchive(new MemoryStream(data), ZipArchiveMode.Read)) {
            bool done = false;
            foreach (string root in new string[] { "runtimes/win-x64/lib/", "lib/" }) {
                foreach (string t in Tfms) {
                    string prefix = root + t + "/";
                    List<ZipArchiveEntry> sel = new List<ZipArchiveEntry>();
                    foreach (ZipArchiveEntry e in zip.Entries) { if (e.FullName.Replace('\\', '/').StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) sel.Add(e); }
                    if (sel.Count == 0) continue;
                    foreach (ZipArchiveEntry e in sel) {
                        if (e.Name.EndsWith(".dll", StringComparison.OrdinalIgnoreCase)) { e.ExtractToFile(Path.Combine(dest, e.Name), true); Log.Add("   -> " + e.Name); }
                    }
                    done = true;
                    break;
                }
                if (done) break;
            }
            ZipArchiveEntry ns = null;
            foreach (ZipArchiveEntry e in zip.Entries) { if (e.FullName.EndsWith(".nuspec", StringComparison.OrdinalIgnoreCase) && e.FullName.IndexOf('/') < 0) { ns = e; break; } }
            if (ns == null) return;
            XmlDocument x = new XmlDocument();
            using (Stream s = ns.Open()) { x.Load(s); }
            XmlNodeList groups = x.SelectNodes("//*[local-name()='dependencies']/*[local-name()='group']");
            XmlNode grp = null;
            foreach (string g in Groups) {
                foreach (XmlNode n in groups) { XmlAttribute a = n.Attributes["targetFramework"]; if (a != null && a.Value == g) { grp = n; break; } }
                if (grp != null) break;
            }
            XmlNodeList deps = grp != null ? grp.SelectNodes("*[local-name()='dependency']") : x.SelectNodes("//*[local-name()='dependencies']/*[local-name()='dependency']");
            foreach (XmlNode d in deps) {
                if (d.Attributes["id"] == null || d.Attributes["version"] == null) continue;
                string dv = Regex.Match(d.Attributes["version"].Value, @"\d+(\.\d+)*(-[\w\.]+)?").Value;
                if (dv.Length > 0) Get(d.Attributes["id"].Value, dv, dest, seen);
            }
        }
    }
}

// Mise à jour du logiciel : télécharge l'installateur officiel de la nouvelle version (GitHub) et vérifie
// son empreinte SHA-256. Le logiciel lance ensuite cet installateur, comme un utilisateur le ferait.
public static class AeroxUpdate {
    public static void Download(string url, string path, string sha256) {
        ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
        Directory.CreateDirectory(Path.GetDirectoryName(path));
        string tmp = path + ".part";
        using (WebClient wc = new WebClient()) { wc.Headers.Add("User-Agent", "AeroxPCCare"); wc.DownloadFile(url, tmp); }
        if (!string.IsNullOrEmpty(sha256)) {
            string h;
            using (FileStream fs = File.OpenRead(tmp))
            using (System.Security.Cryptography.SHA256 sh = System.Security.Cryptography.SHA256.Create()) {
                h = BitConverter.ToString(sh.ComputeHash(fs)).Replace("-", "");
            }
            if (!string.Equals(h, sha256, StringComparison.OrdinalIgnoreCase)) {
                try { File.Delete(tmp); } catch { }
                throw new Exception("Le fichier téléchargé ne correspond pas à celui publié (empreinte différente). Mise à jour annulée par sécurité.");
            }
        }
        if (File.Exists(path)) File.Delete(path);
        File.Move(tmp, path);
    }
}

// Test de débit.
// 1) Moteur principal : Speedtest® CLI d'Ookla (l'outil officiel de speedtest.net, mêmes serveurs et
//    même méthode que le site : résultats comparables). Téléchargé à la demande depuis install.speedtest.net.
// 2) Secours : serveurs publics de Cloudflare (speed.cloudflare.com) si Ookla est indisponible.
public static class AeroxSpeed {
    const string CfBase = "https://speed.cloudflare.com/";
    public const string OoklaZip = "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-win64.zip";
    public static volatile string Phase = "";      // install, meta, ping, down, up, done, error, stopped
    public static volatile bool Stop = false;
    public static double Ping = -1, Jitter = -1, Down = -1, Up = -1, Live = 0, Percent = 0, Loss = -1;
    public static string Error = "", Isp = "", City = "", Colo = "", Engine = "", Server = "", ResultUrl = "", Note = "";
    static Thread th;
    static Process proc;
    static long bytes;
    public static bool Running { get { return th != null && th.IsAlive; } }

    static void Reset() {
        Phase = "meta"; Stop = false; Ping = -1; Jitter = -1; Down = -1; Up = -1; Live = 0; Percent = 0; Loss = -1;
        Error = ""; Isp = ""; City = ""; Colo = ""; Engine = ""; Server = ""; ResultUrl = ""; Note = "";
    }

    // ookla : dossier où se trouve (ou sera installé) speedtest.exe ; null = Cloudflare directement
    public static void Start(string ooklaDir) {
        if (Running) return;
        Reset();
        th = new Thread(delegate() { Run(ooklaDir); }); th.IsBackground = true; th.Start();
    }

    public static void Cancel() {
        Stop = true;
        try { if (proc != null && !proc.HasExited) proc.Kill(); } catch { }
    }

    static void Run(string ooklaDir) {
        ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
        string ooklaErr = null;
        if (!string.IsNullOrEmpty(ooklaDir)) {
            try { if (RunOokla(ooklaDir)) return; }
            catch (Exception ex) { ooklaErr = Inner(ex).Message; }
            if (Stop) { Phase = "stopped"; return; }
            if (ooklaErr == null) ooklaErr = Error;
        }
        // Secours : Cloudflare
        Ping = -1; Jitter = -1; Down = -1; Up = -1; Live = 0; Percent = 0; Error = ""; Server = ""; ResultUrl = "";
        if (ooklaErr != null) Note = "Speedtest d'Ookla indisponible (" + ooklaErr + ") : test fait avec les serveurs de Cloudflare.";
        try { RunCloudflare(); }
        catch (Exception ex) {
            Exception e = Inner(ex);
            Error = e.Message;
            if (e is WebException && ((WebException)e).Response is HttpWebResponse && (int)((HttpWebResponse)((WebException)e).Response).StatusCode == 429)
                Error = "le serveur de test limite le nombre d'essais d'affilée. Réessaie dans une à deux minutes.";
            Phase = "error";
        }
    }
    static Exception Inner(Exception e) { while (e.InnerException != null) e = e.InnerException; return e; }

    // ------------------------------------------------------------------ Ookla
    static bool RunOokla(string dir) {
        string exe = Path.Combine(dir, "speedtest.exe");
        if (!File.Exists(exe)) {
            Phase = "install";
            Directory.CreateDirectory(dir);
            string zip = Path.Combine(dir, "speedtest.zip");
            using (WebClient wc = new WebClient()) { wc.Headers.Add("User-Agent", "AeroxPCCare"); wc.DownloadFile(OoklaZip, zip); }
            using (ZipArchive z = ZipFile.OpenRead(zip)) {
                foreach (ZipArchiveEntry e in z.Entries) {
                    if (e.Name.Length == 0) continue;
                    e.ExtractToFile(Path.Combine(dir, e.Name), true);
                }
            }
            try { File.Delete(zip); } catch { }
            if (!File.Exists(exe)) throw new Exception("speedtest.exe introuvable dans le paquet d'Ookla");
        }
        Phase = "meta"; Engine = "ookla";
        ProcessStartInfo psi = new ProcessStartInfo(exe, "--accept-license --accept-gdpr --format=jsonl --progress=yes");
        psi.UseShellExecute = false; psi.CreateNoWindow = true;
        psi.RedirectStandardOutput = true; psi.RedirectStandardError = true;
        psi.StandardOutputEncoding = Encoding.UTF8; psi.StandardErrorEncoding = Encoding.UTF8;
        psi.WorkingDirectory = dir;
        proc = new Process(); proc.StartInfo = psi;
        string lastErr = null; bool gotResult = false;
        proc.ErrorDataReceived += delegate(object s, DataReceivedEventArgs e) {
            if (string.IsNullOrEmpty(e.Data)) return;
            string m = Str(e.Data, "message"); if (m.Length == 0) m = e.Data.Trim();
            if (m.Length > 0 && (e.Data.IndexOf("\"error\"", StringComparison.OrdinalIgnoreCase) >= 0 || e.Data.IndexOf("[error]", StringComparison.OrdinalIgnoreCase) >= 0 || !e.Data.StartsWith("{"))) lastErr = m;
        };
        proc.Start(); proc.BeginErrorReadLine();
        string line;
        while ((line = proc.StandardOutput.ReadLine()) != null) {
            if (Stop) break;
            string type = Str(line, "type");
            switch (type) {
                case "testStart":
                    Isp = Str(line, "isp");
                    Server = Str(Obj(line, "server"), "name"); City = Str(Obj(line, "server"), "location");
                    Phase = "ping"; break;
                case "ping": {
                    string o = Obj(line, "ping");
                    Ping = Num(o, "latency", Ping); Jitter = Num(o, "jitter", Jitter);
                    Percent = 10 * Num(o, "progress", 0); Phase = "ping"; break; }
                case "download": {
                    string o = Obj(line, "download");
                    double bw = Num(o, "bandwidth", -1); if (bw >= 0) Live = bw * 8 / 1e6;
                    Percent = 10 + 45 * Num(o, "progress", 0); Phase = "down"; break; }
                case "upload": {
                    string o = Obj(line, "upload");
                    if (Phase == "down" && Live > 0 && Down < 0) Down = Live;
                    double bw = Num(o, "bandwidth", -1); if (bw >= 0) Live = bw * 8 / 1e6;
                    Percent = 55 + 45 * Num(o, "progress", 0); Phase = "up"; break; }
                case "result": {
                    string pg = Obj(line, "ping"), dn = Obj(line, "download"), up = Obj(line, "upload");
                    Ping = Num(pg, "latency", Ping); Jitter = Num(pg, "jitter", Jitter);
                    double b = Num(dn, "bandwidth", -1); if (b >= 0) Down = b * 8 / 1e6;
                    b = Num(up, "bandwidth", -1); if (b >= 0) Up = b * 8 / 1e6;
                    Loss = Num(line, "packetLoss", -1);
                    if (Isp.Length == 0) Isp = Str(line, "isp");
                    if (Server.Length == 0) { Server = Str(Obj(line, "server"), "name"); City = Str(Obj(line, "server"), "location"); }
                    ResultUrl = Str(Obj(line, "result"), "url");
                    gotResult = true; break; }
                case "log":
                    if (Str(line, "level") == "error") lastErr = Str(line, "message");
                    break;
            }
        }
        try { proc.WaitForExit(5000); } catch { }
        if (Stop) { Phase = "stopped"; return true; }
        if (gotResult && Down >= 0) { Live = 0; Percent = 100; Phase = "done"; return true; }
        Error = string.IsNullOrEmpty(lastErr) ? "pas de résultat" : lastErr;
        return false;
    }

    // Petits lecteurs JSON (sans dépendance) : objet "nom":{...} de premier niveau, champ texte ou nombre
    static string Obj(string j, string name) {
        int i = j.IndexOf("\"" + name + "\":{", StringComparison.Ordinal);
        if (i < 0) return "";
        int start = j.IndexOf('{', i), depth = 0;
        for (int k = start; k < j.Length; k++) {
            if (j[k] == '{') depth++;
            else if (j[k] == '}') { depth--; if (depth == 0) return j.Substring(start, k - start + 1); }
        }
        return j.Substring(start);
    }
    static string Str(string j, string k) {
        Match m = Regex.Match(j, "\"" + k + "\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\"");
        return m.Success ? Regex.Unescape(m.Groups[1].Value) : "";
    }
    static double Num(string j, string k, double def) {
        Match m = Regex.Match(j, "\"" + k + "\"\\s*:\\s*(-?[0-9.]+(?:[eE][-+]?[0-9]+)?)");
        double v;
        if (m.Success && double.TryParse(m.Groups[1].Value, NumberStyles.Float, CultureInfo.InvariantCulture, out v)) return v;
        return def;
    }

    // ------------------------------------------------------------------ Cloudflare (secours)
    static void RunCloudflare() {
        Engine = "cloudflare";
        ServicePointManager.DefaultConnectionLimit = Math.Max(ServicePointManager.DefaultConnectionLimit, 32);
        ServicePointManager.Expect100Continue = false;
        Phase = "meta"; CfMeta();
        if (Stop) { Phase = "stopped"; return; }
        Phase = "ping"; IcmpPing();
        if (Stop) { Phase = "stopped"; return; }
        Phase = "down"; Down = Transfer(true, 4, 9000);
        if (Stop) { Phase = "stopped"; return; }
        Phase = "up"; Up = Transfer(false, 4, 9000);
        Live = 0; Percent = 100;
        Phase = Stop ? "stopped" : "done";
    }

    static HttpWebRequest Req(string url, string method) {
        HttpWebRequest r = (HttpWebRequest)WebRequest.Create(url);
        r.Method = method; r.UserAgent = "AeroxPCCare"; r.KeepAlive = true; r.Timeout = 15000; r.ReadWriteTimeout = 15000;
        r.Proxy = WebRequest.DefaultWebProxy; r.AutomaticDecompression = DecompressionMethods.None;
        return r;
    }
    static void CfMeta() {
        try {
            using (HttpWebResponse resp = (HttpWebResponse)Req(CfBase + "meta", "GET").GetResponse())
            using (StreamReader sr = new StreamReader(resp.GetResponseStream())) {
                string j = sr.ReadToEnd();
                Isp = Str(j, "asOrganization"); City = Str(j, "city"); Colo = Str(j, "colo"); Server = "Cloudflare";
            }
        } catch { }
    }
    // Ping réseau (ICMP) vers 1.1.1.1, servi par le centre Cloudflare le plus proche
    static void IcmpPing() {
        List<double> t = new List<double>();
        using (System.Net.NetworkInformation.Ping p = new System.Net.NetworkInformation.Ping()) {
            for (int i = 0; i < 12 && !Stop; i++) {
                try {
                    System.Net.NetworkInformation.PingReply r = p.Send("1.1.1.1", 2000);
                    if (r.Status == System.Net.NetworkInformation.IPStatus.Success) t.Add(r.RoundtripTime);
                } catch { }
                Percent = i * 100.0 / 12;
                Thread.Sleep(100);
            }
        }
        if (t.Count == 0) return;
        List<double> sorted = new List<double>(t); sorted.Sort();
        Ping = sorted[sorted.Count / 2];
        double j = 0; for (int i = 1; i < t.Count; i++) j += Math.Abs(t[i] - t[i - 1]);
        Jitter = t.Count > 1 ? j / (t.Count - 1) : 0;
    }

    static double Transfer(bool down, int streams, int durationMs) {
        bytes = 0; Live = 0; Percent = 0;
        Stopwatch clock = Stopwatch.StartNew();
        long warmBytes = -1; double warmT = 0; const int warm = 2000;
        List<Thread> ts = new List<Thread>();
        List<HttpWebRequest> live = new List<HttpWebRequest>();
        object lk = new object();
        Exception err = null;
        for (int n = 0; n < streams; n++) {
            Thread t = new Thread(delegate() {
                byte[] buf = new byte[131072];
                if (!down) new Random().NextBytes(buf);
                while (!Stop && clock.ElapsedMilliseconds < durationMs) {
                    HttpWebRequest r = null;
                    try {
                        if (down) {
                            r = Req(CfBase + "__down?bytes=100000000", "GET");
                            lock (lk) live.Add(r);
                            using (HttpWebResponse resp = (HttpWebResponse)r.GetResponse())
                            using (Stream s = resp.GetResponseStream()) {
                                int k;
                                while ((k = s.Read(buf, 0, buf.Length)) > 0) {
                                    Interlocked.Add(ref bytes, k);
                                    if (Stop || clock.ElapsedMilliseconds >= durationMs) break;
                                }
                                if (k > 0) r.Abort();
                            }
                        } else {
                            const int size = 50 * 1024 * 1024;
                            r = Req(CfBase + "__up", "POST");
                            r.ContentType = "application/octet-stream"; r.ContentLength = size; r.AllowWriteStreamBuffering = false; r.SendChunked = false;
                            lock (lk) live.Add(r);
                            bool cut = false;
                            using (Stream s = r.GetRequestStream()) {
                                int sent = 0;
                                while (sent < size) {
                                    int k = Math.Min(buf.Length, size - sent);
                                    s.Write(buf, 0, k); sent += k;
                                    Interlocked.Add(ref bytes, k);
                                    if (Stop || clock.ElapsedMilliseconds >= durationMs) { cut = true; break; }
                                }
                                if (cut) r.Abort();
                            }
                            if (!cut) { using (HttpWebResponse resp = (HttpWebResponse)r.GetResponse()) { } }
                        }
                    } catch (Exception ex) {
                        if (!Stop && clock.ElapsedMilliseconds < durationMs) { lock (lk) { if (err == null) err = ex; } Thread.Sleep(500); }
                    } finally {
                        if (r != null) { lock (lk) live.Remove(r); try { r.Abort(); } catch { } }
                    }
                }
            });
            t.IsBackground = true; ts.Add(t); t.Start();
        }
        Queue<double[]> win = new Queue<double[]>();
        while (clock.ElapsedMilliseconds < durationMs && !Stop) {
            Thread.Sleep(200);
            double now = clock.Elapsed.TotalMilliseconds; long b = Interlocked.Read(ref bytes);
            win.Enqueue(new double[] { now, b });
            while (win.Count > 1 && now - win.Peek()[0] > 1000) win.Dequeue();
            double[] first = win.Peek();
            if (now - first[0] > 0) Live = (b - first[1]) * 8 / ((now - first[0]) / 1000.0) / 1e6;
            if (warmBytes < 0 && now >= warm) { warmBytes = b; warmT = now; }
            Percent = Math.Min(100, now * 100.0 / durationMs);
        }
        double endT = clock.Elapsed.TotalMilliseconds; long endB = Interlocked.Read(ref bytes);
        lock (lk) { foreach (HttpWebRequest r in live) { try { r.Abort(); } catch { } } }
        foreach (Thread t in ts) t.Join(3000);
        if (Stop) return -1;
        if (endB == 0 && err != null) throw err;
        if (warmBytes < 0) { warmBytes = 0; warmT = 0; }
        return (endB - warmBytes) * 8 / ((endT - warmT) / 1000.0) / 1e6;
    }
}

// Écrans : fréquence actuelle et fréquence maximale possible à la résolution actuelle, et changement
// de fréquence (API officielle de Windows, la même que Paramètres > Affichage > Affichage avancé).
// Son et micro : volume et sourdine du périphérique par défaut (API Core Audio de Windows)
public static class AeroxAudio {
    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumeratorCom { }
    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDeviceEnumerator {
        [PreserveSig] int EnumAudioEndpoints(int dataFlow, int stateMask, out IntPtr devices);
        [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint);
    }
    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDevice {
        [PreserveSig] int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object iface);
    }
    [ComImport, Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioEndpointVolume {
        [PreserveSig] int RegisterControlChangeNotify(IntPtr p);
        [PreserveSig] int UnregisterControlChangeNotify(IntPtr p);
        [PreserveSig] int GetChannelCount(out uint c);
        [PreserveSig] int SetMasterVolumeLevel(float level, ref Guid ctx);
        [PreserveSig] int SetMasterVolumeLevelScalar(float level, ref Guid ctx);
        [PreserveSig] int GetMasterVolumeLevel(out float level);
        [PreserveSig] int GetMasterVolumeLevelScalar(out float level);
        [PreserveSig] int SetChannelVolumeLevel(uint ch, float level, ref Guid ctx);
        [PreserveSig] int SetChannelVolumeLevelScalar(uint ch, float level, ref Guid ctx);
        [PreserveSig] int GetChannelVolumeLevel(uint ch, out float level);
        [PreserveSig] int GetChannelVolumeLevelScalar(uint ch, out float level);
        [PreserveSig] int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, ref Guid ctx);
        [PreserveSig] int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
    }
    static IAudioEndpointVolume Get(bool capture) {
        IMMDeviceEnumerator en = (IMMDeviceEnumerator)(new MMDeviceEnumeratorCom());
        IMMDevice dev;
        if (en.GetDefaultAudioEndpoint(capture ? 1 : 0, 1, out dev) != 0 || dev == null) return null;
        Guid iid = typeof(IAudioEndpointVolume).GUID;
        object o;
        if (dev.Activate(ref iid, 23, IntPtr.Zero, out o) != 0 || o == null) return null;
        return (IAudioEndpointVolume)o;
    }
    // "volume|sourdine(0/1)" du haut-parleur (capture=false) ou du micro (capture=true) par défaut ; "" si aucun
    public static string Info(bool capture) {
        try {
            IAudioEndpointVolume v = Get(capture);
            if (v == null) return "";
            float l; bool m;
            v.GetMasterVolumeLevelScalar(out l); v.GetMute(out m);
            return ((int)Math.Round(l * 100)).ToString() + "|" + (m ? "1" : "0");
        } catch { return ""; }
    }
    // Enlève la sourdine et remonte le volume au minimum demandé (sans jamais le baisser)
    public static bool Fix(bool capture, int minPercent) {
        try {
            IAudioEndpointVolume v = Get(capture);
            if (v == null) return false;
            Guid g = Guid.Empty;
            v.SetMute(false, ref g);
            float l; v.GetMasterVolumeLevelScalar(out l);
            if (l * 100 < minPercent) v.SetMasterVolumeLevelScalar(minPercent / 100f, ref g);
            return true;
        } catch { return false; }
    }
}

public static class AeroxDisplay {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct DISPLAY_DEVICE {
        public int cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
        public int StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
        public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra;
        public int dmFields;
        public int dmPositionX, dmPositionY, dmDisplayOrientation, dmDisplayFixedOutput;
        public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
        public short dmLogPixels;
        public int dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency;
        public int dmICMMethod, dmICMIntent, dmMediaType, dmDitherType, dmReserved1, dmReserved2, dmPanningWidth, dmPanningHeight;
    }
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern bool EnumDisplayDevices(string lpDevice, int iDevNum, ref DISPLAY_DEVICE dd, int flags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern bool EnumDisplaySettings(string name, int mode, ref DEVMODE dm);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int ChangeDisplaySettingsEx(string name, ref DEVMODE dm, IntPtr hwnd, int flags, IntPtr lParam);
    const int ENUM_CURRENT_SETTINGS = -1, DM_DISPLAYFREQUENCY = 0x400000, DM_INTERLACED = 2;
    const int CDS_UPDATEREGISTRY = 1, CDS_TEST = 2;
    const int DISPLAY_DEVICE_ATTACHED_TO_DESKTOP = 1, DISPLAY_DEVICE_PRIMARY_DEVICE = 4;

    // Une ligne par écran : "nom_windows|nom_écran|largeur|hauteur|Hz_actuel|Hz_max|principal(0/1)"
    public static string[] List() {
        List<string> outp = new List<string>();
        for (int i = 0; i < 16; i++) {
            DISPLAY_DEVICE ad = new DISPLAY_DEVICE(); ad.cb = Marshal.SizeOf(ad);
            if (!EnumDisplayDevices(null, i, ref ad, 0)) break;
            if ((ad.StateFlags & DISPLAY_DEVICE_ATTACHED_TO_DESKTOP) == 0) continue;
            DEVMODE cur = NewMode();
            if (!EnumDisplaySettings(ad.DeviceName, ENUM_CURRENT_SETTINGS, ref cur)) continue;
            int max = cur.dmDisplayFrequency;
            DEVMODE m = NewMode();
            for (int k = 0; EnumDisplaySettings(ad.DeviceName, k, ref m); k++) {
                if (m.dmPelsWidth == cur.dmPelsWidth && m.dmPelsHeight == cur.dmPelsHeight && m.dmBitsPerPel == cur.dmBitsPerPel
                    && (m.dmDisplayFlags & DM_INTERLACED) == 0 && m.dmDisplayFrequency > max && m.dmDisplayFrequency < 1000) max = m.dmDisplayFrequency;
                m = NewMode();
            }
            string mon = "";
            DISPLAY_DEVICE md = new DISPLAY_DEVICE(); md.cb = Marshal.SizeOf(md);
            if (EnumDisplayDevices(ad.DeviceName, 0, ref md, 0)) mon = md.DeviceString;
            outp.Add(Clean(ad.DeviceName) + "|" + Clean(mon) + "|" + cur.dmPelsWidth + "|" + cur.dmPelsHeight + "|" + cur.dmDisplayFrequency + "|" + max + "|" + ((ad.StateFlags & DISPLAY_DEVICE_PRIMARY_DEVICE) != 0 ? "1" : "0"));
        }
        return outp.ToArray();
    }

    // Change la fréquence de l'écran (même résolution). Renvoie 0 si c'est fait, un code Windows sinon.
    // persist = false : essai seulement (rien n'est enregistré, un redémarrage remet l'ancien réglage)
    // persist = true  : réglage enregistré
    public static int SetFrequency(string device, int hz, bool persist) {
        DEVMODE cur = NewMode();
        if (!EnumDisplaySettings(device, ENUM_CURRENT_SETTINGS, ref cur)) return -100;
        cur.dmDisplayFrequency = hz; cur.dmFields = DM_DISPLAYFREQUENCY;
        int t = ChangeDisplaySettingsEx(device, ref cur, IntPtr.Zero, CDS_TEST, IntPtr.Zero);
        if (t != 0) return t;
        return ChangeDisplaySettingsEx(device, ref cur, IntPtr.Zero, persist ? CDS_UPDATEREGISTRY : 0, IntPtr.Zero);
    }

    static DEVMODE NewMode() { DEVMODE d = new DEVMODE(); d.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE)); return d; }
    static string Clean(string s) { return (s ?? "").Replace('|', '/').Trim(); }
}

// =====================================================================
//  Lecture / modification chirurgicale d'un fichier JSON (réglages des navigateurs)
//  Le fichier n'est jamais réécrit en entier : on ne remplace que la valeur visée,
//  tout le reste reste identique, octet pour octet.
// =====================================================================
public static class AeroxJson {
    static char At(string s, int i) { return (i >= 0 && i < s.Length) ? s[i] : '\0'; }
    static int Ws(string s, int i) { while (i < s.Length && (s[i] == ' ' || s[i] == '\t' || s[i] == '\r' || s[i] == '\n')) i++; return i; }

    // Lit la chaîne qui commence à i (s[i] == '"'), renvoie l'index juste après (-1 si invalide)
    static int ReadString(string s, int i, StringBuilder sb) {
        if (At(s, i) != '"') return -1;
        i++;
        while (i < s.Length) {
            char c = s[i];
            if (c == '"') return i + 1;
            if (c == '\\') {
                char e = At(s, i + 1);
                if (e == 'u') {
                    if (i + 6 > s.Length) return -1;
                    int code;
                    if (!int.TryParse(s.Substring(i + 2, 4), NumberStyles.HexNumber, CultureInfo.InvariantCulture, out code)) return -1;
                    if (sb != null) sb.Append((char)code);
                    i += 6; continue;
                }
                if (sb != null) {
                    switch (e) {
                        case 'n': sb.Append('\n'); break; case 't': sb.Append('\t'); break; case 'r': sb.Append('\r'); break;
                        case 'b': sb.Append('\b'); break; case 'f': sb.Append('\f'); break;
                        case '"': case '\\': case '/': sb.Append(e); break;
                        default: return -1;
                    }
                }
                i += 2; continue;
            }
            if (sb != null) sb.Append(c);
            i++;
        }
        return -1;
    }

    // Saute la valeur qui commence à i, renvoie l'index juste après (-1 si invalide)
    static int SkipValue(string s, int i, int depth) {
        if (depth > 200) return -1;
        i = Ws(s, i);
        char c = At(s, i);
        if (c == '"') return ReadString(s, i, null);
        if (c == '{' || c == '[') {
            char close = c == '{' ? '}' : ']';
            i = Ws(s, i + 1);
            if (At(s, i) == close) return i + 1;
            while (true) {
                if (c == '{') {
                    i = ReadString(s, Ws(s, i), null); if (i < 0) return -1;
                    i = Ws(s, i); if (At(s, i) != ':') return -1; i++;
                }
                i = SkipValue(s, i, depth + 1); if (i < 0) return -1;
                i = Ws(s, i);
                if (At(s, i) == ',') { i++; continue; }
                if (At(s, i) == close) return i + 1;
                return -1;
            }
        }
        int st = i;
        while (i < s.Length && "-+.0123456789eEtrufalsn".IndexOf(s[i]) >= 0) i++;
        return i > st ? i : -1;
    }

    // Position [début, fin[ de la valeur au chemin donné, null si absente
    public static int[] Find(string s, string[] path) {
        if (s == null) return null;
        int i = Ws(s, 0);
        if (path != null) {
            foreach (string key in path) {
                i = Ws(s, i);
                if (At(s, i) != '{') return null;
                i = Ws(s, i + 1);
                if (At(s, i) == '}') return null;
                bool found = false;
                while (true) {
                    StringBuilder sb = new StringBuilder();
                    i = ReadString(s, Ws(s, i), sb); if (i < 0) return null;
                    i = Ws(s, i); if (At(s, i) != ':') return null; i = Ws(s, i + 1);
                    if (sb.ToString() == key) { found = true; break; }
                    i = SkipValue(s, i, 0); if (i < 0) return null;
                    i = Ws(s, i);
                    if (At(s, i) == ',') { i++; continue; }
                    break;
                }
                if (!found) return null;
            }
        }
        int e = SkipValue(s, i, 0);
        if (e < 0) return null;
        return new int[] { i, e };
    }

    // Valeur au chemin : texte décodé pour une chaîne, texte brut sinon (nombre, true, objet...), null si absente
    public static string Get(string s, string[] path) {
        int[] r = Find(s, path);
        if (r == null) return null;
        if (s[r[0]] == '"') { StringBuilder sb = new StringBuilder(); ReadString(s, r[0], sb); return sb.ToString(); }
        return s.Substring(r[0], r[1] - r[0]);
    }

    // Clés directes de l'objet au chemin
    public static string[] Keys(string s, string[] path) {
        List<string> outp = new List<string>();
        int[] r = Find(s, path);
        if (r == null || s[r[0]] != '{') return outp.ToArray();
        int i = Ws(s, r[0] + 1);
        if (At(s, i) == '}') return outp.ToArray();
        while (true) {
            StringBuilder sb = new StringBuilder();
            i = ReadString(s, Ws(s, i), sb); if (i < 0) break;
            outp.Add(sb.ToString());
            i = Ws(s, i); if (At(s, i) != ':') break;
            i = SkipValue(s, i + 1, 0); if (i < 0) break;
            i = Ws(s, i);
            if (At(s, i) == ',') { i++; continue; }
            break;
        }
        return outp.ToArray();
    }

    // Éléments texte du tableau au chemin
    public static string[] Items(string s, string[] path) {
        List<string> outp = new List<string>();
        int[] r = Find(s, path);
        if (r == null || s[r[0]] != '[') return outp.ToArray();
        int i = Ws(s, r[0] + 1);
        if (At(s, i) == ']') return outp.ToArray();
        while (true) {
            i = Ws(s, i);
            if (At(s, i) == '"') { StringBuilder sb = new StringBuilder(); int e = ReadString(s, i, sb); if (e < 0) break; outp.Add(sb.ToString()); i = e; }
            else { i = SkipValue(s, i, 0); if (i < 0) break; }
            i = Ws(s, i);
            if (At(s, i) == ',') { i++; continue; }
            break;
        }
        return outp.ToArray();
    }

    // Remplace la valeur au chemin par un texte JSON brut ; null si le chemin n'existe pas
    public static string Replace(string s, string[] path, string raw) {
        int[] r = Find(s, path);
        if (r == null) return null;
        return s.Substring(0, r[0]) + raw + s.Substring(r[1]);
    }

    // Le texte entier est-il un JSON valide ?
    public static bool Valid(string s) {
        if (s == null) return false;
        int e = SkipValue(s, 0, 0);
        return e > 0 && Ws(s, e) == s.Length;
    }
}

// =====================================================================
//  Fichiers : doublons et place gardée sur le PC par OneDrive
// =====================================================================
// Suppression sûre avec les droits admin : jamais à travers un lien (jonction, lien symbolique), même si un lien
// est glissé entre l'analyse et la suppression. Chaque élément est ouvert SANS suivre les liens, son vrai chemin
// est vérifié (il doit rester dans le dossier nettoyé), puis il est supprimé par ce même accès : impossible de
// le rediriger entre la vérification et la suppression.
public static class AeroxSafeDelete {
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern Microsoft.Win32.SafeHandles.SafeFileHandle CreateFileW(string name, uint access, uint share, IntPtr sec, uint disp, uint flags, IntPtr tmpl);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern uint GetFinalPathNameByHandleW(Microsoft.Win32.SafeHandles.SafeFileHandle h, StringBuilder sb, uint n, uint flags);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern uint GetLongPathNameW(string shortPath, StringBuilder sb, uint n);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool GetFileInformationByHandle(Microsoft.Win32.SafeHandles.SafeFileHandle h, out FileInfoH info);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool SetFileInformationByHandle(Microsoft.Win32.SafeHandles.SafeFileHandle h, int cls, ref uint info, int size);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool SetFileInformationByHandle(Microsoft.Win32.SafeHandles.SafeFileHandle h, int cls, ref byte info, int size);
    [StructLayout(LayoutKind.Sequential, Pack = 4)]   // FILETIME = 2 × 32 bits : pas d'alignement sur 8
    struct FileInfoH { public uint Attr; public long Created, Accessed, Written; public uint Vol, SizeHigh, SizeLow, Links, IdxHigh, IdxLow; }
    const uint DELETE = 0x10000, READ_ATTR = 0x80, SHARE_ALL = 7, OPEN_EXISTING = 3, BACKUP = 0x02000000, OPEN_REPARSE = 0x00200000;
    const uint ATTR_DIR = 0x10, ATTR_REPARSE = 0x400;

    static Microsoft.Win32.SafeHandles.SafeFileHandle Open(string path, uint access) {
        return CreateFileW(path, access, SHARE_ALL, IntPtr.Zero, OPEN_EXISTING, BACKUP | OPEN_REPARSE, IntPtr.Zero);
    }
    static string Final(Microsoft.Win32.SafeHandles.SafeFileHandle h) {
        StringBuilder sb = new StringBuilder(1024);
        uint n = GetFinalPathNameByHandleW(h, sb, (uint)sb.Capacity, 0);
        if (n == 0 || n >= sb.Capacity) return null;
        string f = sb.ToString(0, (int)n);
        if (f.StartsWith(@"\\?\UNC\")) return @"\\" + f.Substring(8);
        if (f.StartsWith(@"\\?\")) return f.Substring(4);
        return f;
    }
    // Chemin complet en noms longs (les dossiers Windows sont parfois donnés en noms courts : SAMUEL~1)
    static string Long(string path) {
        string full = Path.GetFullPath(path).TrimEnd('\\');
        StringBuilder sb = new StringBuilder(1024);
        uint n = GetLongPathNameW(full, sb, (uint)sb.Capacity);
        return (n > 0 && n < sb.Capacity) ? sb.ToString(0, (int)n).TrimEnd('\\') : full;
    }
    static bool Under(string p, string root) { return p.StartsWith(root.TrimEnd('\\') + "\\", StringComparison.OrdinalIgnoreCase); }

    // Vrai si le chemin mène directement à l'élément, sans aucun lien sur le trajet
    public static bool IsDirectPath(string path) {
        try {
            using (Microsoft.Win32.SafeHandles.SafeFileHandle h = CreateFileW(path, READ_ATTR, SHARE_ALL, IntPtr.Zero, OPEN_EXISTING, BACKUP, IntPtr.Zero)) {
                if (h.IsInvalid) return false;
                string f = Final(h);
                return f != null && string.Equals(f.TrimEnd('\\'), Long(path), StringComparison.OrdinalIgnoreCase);
            }
        } catch { return false; }
    }
    // Dossier racine sûr : pas un lien, et son vrai chemin est bien celui demandé (aucun lien plus haut)
    static string SafeRoot(string dir) {
        if (string.IsNullOrEmpty(dir)) return null;
        try {
            using (Microsoft.Win32.SafeHandles.SafeFileHandle h = Open(dir, READ_ATTR)) {
                if (h.IsInvalid) return null;
                FileInfoH fi; if (!GetFileInformationByHandle(h, out fi)) return null;
                if ((fi.Attr & ATTR_REPARSE) != 0 || (fi.Attr & ATTR_DIR) == 0) return null;
                string f = Final(h);
                if (f == null || !string.Equals(f.TrimEnd('\\'), Long(dir), StringComparison.OrdinalIgnoreCase)) return null;
                return f.TrimEnd('\\');
            }
        } catch { return null; }
    }
    public static string LastRefused = "";

    // Vide un dossier (le dossier lui-même reste). Renvoie les octets libérés.
    public static double CleanDir(string dir) {
        string root = SafeRoot(dir);
        if (root == null) { LastRefused = dir; return 0; }
        return Inner(dir, root, 0);
    }
    // Supprime un élément (fichier ou dossier et son contenu) de son dossier parent
    public static double DeleteItem(string path) {
        string parent = Path.GetDirectoryName(Path.GetFullPath(path).TrimEnd('\\'));
        string root = SafeRoot(parent);
        if (root == null) { LastRefused = path; return 0; }
        return DeleteOne(path, root, 0);
    }
    static double Inner(string dir, string root, int depth) {
        if (depth > 64) return 0;
        string[] entries;
        try { entries = Directory.GetFileSystemEntries(dir); } catch { return 0; }
        double freed = 0;
        foreach (string e in entries) {
            if (AeroxNative.StopScan) break;
            freed += DeleteOne(e, root, depth);
        }
        return freed;
    }
    static double DeleteOne(string path, string root, int depth) {
        try {
            using (Microsoft.Win32.SafeHandles.SafeFileHandle h = Open(path, DELETE | READ_ATTR)) {
                if (h.IsInvalid) return 0;
                FileInfoH fi; if (!GetFileInformationByHandle(h, out fi)) return 0;
                if ((fi.Attr & ATTR_REPARSE) != 0) return 0;            // lien : jamais suivi, laissé en place
                string f = Final(h);
                if (f == null || !Under(f, root)) return 0;             // en dehors du dossier nettoyé : on n'y touche pas
                if ((fi.Attr & ATTR_DIR) != 0) {
                    double freed = Inner(f, root, depth + 1);
                    MarkDelete(h);                                      // ne réussit que si le dossier est vide
                    return freed;
                }
                double size = (double)fi.SizeHigh * 4294967296.0 + fi.SizeLow;
                return MarkDelete(h) ? size : 0;
            }
        } catch { return 0; }
    }
    static bool MarkDelete(Microsoft.Win32.SafeHandles.SafeFileHandle h) {
        uint ex = 0x1 | 0x2 | 0x10;   // supprimer, tout de suite (POSIX), même en lecture seule
        if (SetFileInformationByHandle(h, 21, ref ex, 4)) return true;
        byte d = 1;                   // Windows plus ancien : sans les options
        return SetFileInformationByHandle(h, 4, ref d, 1);
    }

    // Lien vers un autre endroit (jonction / lien symbolique) ? Les fichiers OneDrive « en ligne » sont aussi des
    // points d'analyse, mais d'un autre type : ceux-là ne sont pas des liens.
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode, Pack = 4)]
    struct FindData { public uint Attr; public long C, A, W; public uint SizeHigh, SizeLow, Reserved0, Reserved1;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] public string Name; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 14)] public string Alt; }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern IntPtr FindFirstFileW(string name, out FindData data);
    [DllImport("kernel32.dll")] static extern bool FindClose(IntPtr h);
    public static bool IsLink(string path) {
        FindData d; IntPtr h = FindFirstFileW(path.TrimEnd('\\'), out d);
        if (h == new IntPtr(-1)) return true;   // illisible : traité comme un lien (on n'y va pas)
        FindClose(h);
        if ((d.Attr & ATTR_REPARSE) == 0) return false;
        return d.Reserved0 == 0xA0000003 || d.Reserved0 == 0xA000000C;   // jonction / lien symbolique
    }
}

public static class AeroxFiles {
    const int RecallOnData = 0x400000, RecallOnOpen = 0x40000, Offline = 0x1000;
    static bool CloudOnly(FileSystemInfo f) { int a = (int)f.Attributes; return (a & (RecallOnData | RecallOnOpen | Offline)) != 0; }

    // Taille des fichiers d'un dossier OneDrive réellement présents sur le PC (ceux « uniquement en ligne » ne comptent pas)
    // OneDrive « uniquement en ligne » : tout passe en ligne SAUF ce que la personne a choisi de garder sur le PC
    // (« Toujours conserver sur cet appareil » = attribut Pinned) : ces fichiers et dossiers ne sont jamais touchés.
    // Renvoie [éléments passés en ligne, éléments gardés sur le PC à la demande de la personne]
    const FileAttributes PinnedAttr = (FileAttributes)0x80000, UnpinnedAttr = (FileAttributes)0x100000;
    const FileAttributes Settable = FileAttributes.ReadOnly | FileAttributes.Hidden | FileAttributes.System | FileAttributes.Archive | FileAttributes.Temporary | FileAttributes.Offline | FileAttributes.NotContentIndexed;
    public static int[] SetOnlineOnly(string root) { int[] c = new int[2]; Online(root, 0, c); return c; }
    static void Online(string d, int depth, int[] c) {
        if (depth > 40) return;
        try {
            foreach (FileSystemInfo fi in new DirectoryInfo(d).EnumerateFileSystemInfos()) {
                if (AeroxNative.StopScan) return;
                try {
                    FileAttributes a = fi.Attributes;
                    if ((a & PinnedAttr) != 0) { c[1]++; continue; }
                    if ((a & FileAttributes.ReparsePoint) != 0 && AeroxSafeDelete.IsLink(fi.FullName)) continue;   // lien vers ailleurs : jamais suivi
                    if ((a & FileAttributes.Directory) != 0) Online(fi.FullName, depth + 1, c);
                    if ((a & UnpinnedAttr) == 0) { File.SetAttributes(fi.FullName, (a & Settable) | UnpinnedAttr); c[0]++; }
                } catch { }
            }
        } catch { }
    }
    public static long LocalCloudSize(string root) {
        return LocalSize(root, 0);
    }
    static long LocalSize(string d, int depth) {
        long t = 0;
        if (depth > 40) return 0;
        try {
            foreach (FileSystemInfo fi in new DirectoryInfo(d).EnumerateFileSystemInfos()) {
                if (AeroxNative.StopScan) return t;
                try {
                    if ((fi.Attributes & FileAttributes.Directory) != 0) t += LocalSize(fi.FullName, depth + 1);
                    else if (!CloudOnly(fi)) t += ((FileInfo)fi).Length;
                } catch { }
            }
        } catch { }
        return t;
    }

    // Fichiers identiques (même taille puis même contenu) : "D|groupe|octets|date(ticks)|chemin"
    // Les fichiers « uniquement en ligne » (OneDrive) sont ignorés : les lire les téléchargerait.
    public static string[] FindDuplicates(string[] roots, long minSize, int maxGroups) {
        Dictionary<long, List<FileInfo>> bySize = new Dictionary<long, List<FileInfo>>();
        HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (string r in roots) { if (!string.IsNullOrEmpty(r) && Directory.Exists(r)) Collect(r, minSize, bySize, seen, 0); }
        List<List<FileInfo>> groups = new List<List<FileInfo>>();
        foreach (KeyValuePair<long, List<FileInfo>> kv in bySize) {
            if (AeroxNative.StopScan) break;
            if (kv.Value.Count < 2) continue;
            // 1er tri rapide : début et fin du fichier ; puis contenu complet
            foreach (List<FileInfo> g1 in Split(kv.Value, true)) {
                foreach (List<FileInfo> g2 in Split(g1, false)) groups.Add(g2);
            }
        }
        groups.Sort(delegate(List<FileInfo> a, List<FileInfo> b) { return (b[0].Length * (b.Count - 1)).CompareTo(a[0].Length * (a.Count - 1)); });
        List<string> outp = new List<string>();
        for (int i = 0; i < groups.Count && i < maxGroups; i++) {
            foreach (FileInfo f in groups[i]) outp.Add("D|" + i + "|" + f.Length + "|" + f.LastWriteTimeUtc.Ticks + "|" + f.FullName);
        }
        return outp.ToArray();
    }
    static void Collect(string d, long minSize, Dictionary<long, List<FileInfo>> bySize, HashSet<string> seen, int depth) {
        if (depth > 40 || AeroxNative.StopScan) return;
        try {
            foreach (FileSystemInfo fi in new DirectoryInfo(d).EnumerateFileSystemInfos()) {
                if (AeroxNative.StopScan) return;
                try {
                    if ((fi.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                    if ((fi.Attributes & FileAttributes.Directory) != 0) { Collect(fi.FullName, minSize, bySize, seen, depth + 1); continue; }
                    if ((fi.Attributes & FileAttributes.System) != 0 || CloudOnly(fi)) continue;
                    FileInfo f = (FileInfo)fi;
                    if (f.Length < minSize || !seen.Add(f.FullName)) continue;
                    List<FileInfo> l;
                    if (!bySize.TryGetValue(f.Length, out l)) { l = new List<FileInfo>(); bySize[f.Length] = l; }
                    l.Add(f);
                } catch { }
            }
        } catch { }
    }
    static List<List<FileInfo>> Split(List<FileInfo> files, bool quick) {
        Dictionary<string, List<FileInfo>> m = new Dictionary<string, List<FileInfo>>();
        foreach (FileInfo f in files) {
            if (AeroxNative.StopScan) break;
            string h = Hash(f.FullName, quick);
            if (h == null) continue;
            List<FileInfo> l;
            if (!m.TryGetValue(h, out l)) { l = new List<FileInfo>(); m[h] = l; }
            l.Add(f);
        }
        List<List<FileInfo>> r = new List<List<FileInfo>>();
        foreach (List<FileInfo> l in m.Values) if (l.Count > 1) r.Add(l);
        return r;
    }
    static string Hash(string path, bool quick) {
        try {
            using (FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete, 1 << 16))
            using (System.Security.Cryptography.SHA1 sha = System.Security.Cryptography.SHA1.Create()) {
                if (!quick) return BitConverter.ToString(sha.ComputeHash(fs));
                const int part = 65536;
                byte[] buf = new byte[part * 2];
                int n = fs.Read(buf, 0, part);
                if (fs.Length > part * 2) { fs.Seek(-part, SeekOrigin.End); n += fs.Read(buf, n, part); }
                else if (fs.Length > n) { n += fs.Read(buf, n, (int)Math.Min(part, fs.Length - n)); }
                return BitConverter.ToString(sha.ComputeHash(buf, 0, n));
            }
        } catch { return null; }
    }
}
