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

    // Tailles des dossiers jusqu'à une profondeur : "profondeur|octets|chemin" ; gros fichiers à la racine : "F|octets|chemin"
    public static string[] ScanSizes(string root, int maxDepth) {
        List<string> outp = new List<string>();
        try {
            foreach (FileInfo f in new DirectoryInfo(root).EnumerateFiles()) {
                try { if (f.Length >= 100L * 1024 * 1024) outp.Add("F|" + f.Length + "|" + f.FullName); } catch { }
            }
        } catch { }
        ScanDir(root, 0, maxDepth, outp);
        return outp.ToArray();
    }
    static long ScanDir(string d, int depth, int maxDepth, List<string> outp) {
        long total = 0;
        try {
            foreach (FileSystemInfo fi in new DirectoryInfo(d).EnumerateFileSystemInfos()) {
                try {
                    if ((fi.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                    if ((fi.Attributes & FileAttributes.Directory) != 0) total += ScanDir(fi.FullName, depth + 1, maxDepth, outp);
                    else total += ((FileInfo)fi).Length;
                } catch { }
            }
        } catch { }
        if (depth >= 1 && depth <= maxDepth) outp.Add(depth + "|" + total + "|" + d);
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

// Capteurs : lance « AEROX PC Care.exe --capteurs » (processus séparé) et garde la dernière mesure.
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
    Stopwatch sw = Stopwatch.StartNew();
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
            if (cApp >= 0 && cApp < p.Length) names[pid] = p[cApp];
            if (lst.Count > 4000) lst.RemoveRange(0, lst.Count - 3000);
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

    public void Stop() {
        try { if (proc != null && !proc.HasExited) proc.Kill(); } catch { }
        proc = null;
        lock (lk) { frames.Clear(); names.Clear(); }
        cApp = -1; cPid = -1; cMs = -1;
    }
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

// Mise à jour du logiciel : télécharge le zip de la nouvelle version (GitHub), vérifie son empreinte,
// le dézippe, puis lance « AEROX PC Care.exe --maj » de la nouvelle version qui remplace les fichiers.
public static class AeroxUpdate {
    public static string Prepare(string url, string workDir, string sha256) {
        ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
        Directory.CreateDirectory(workDir);
        string zip = Path.Combine(workDir, "maj.zip");
        string ex = Path.Combine(workDir, "fichiers");
        try { if (Directory.Exists(ex)) Directory.Delete(ex, true); } catch { }
        using (WebClient wc = new WebClient()) { wc.Headers.Add("User-Agent", "AeroxPCCare"); wc.DownloadFile(url, zip); }
        if (!string.IsNullOrEmpty(sha256)) {
            string h;
            using (FileStream fs = File.OpenRead(zip))
            using (System.Security.Cryptography.SHA256 sh = System.Security.Cryptography.SHA256.Create()) {
                h = BitConverter.ToString(sh.ComputeHash(fs)).Replace("-", "");
            }
            if (!string.Equals(h, sha256, StringComparison.OrdinalIgnoreCase)) {
                try { File.Delete(zip); } catch { }
                throw new Exception("Le fichier téléchargé ne correspond pas à celui publié (empreinte différente). Mise à jour annulée par sécurité.");
            }
        }
        ZipFile.ExtractToDirectory(zip, ex);
        try { File.Delete(zip); } catch { }
        foreach (string f in Directory.GetFiles(ex, "AEROX PC Care.exe", SearchOption.AllDirectories)) {
            string d = Path.GetDirectoryName(f);
            if (File.Exists(Path.Combine(d, "AeroxPCCare.ps1")) && File.Exists(Path.Combine(d, "AeroxPCCare.Native.dll"))) return d;
        }
        throw new Exception("Le paquet téléchargé est incomplet (fichiers du logiciel introuvables).");
    }

    public static void Launch(string newDir, string installDir) {
        ProcessStartInfo psi = new ProcessStartInfo(Path.Combine(newDir, "AEROX PC Care.exe"),
            "--maj \"" + newDir.TrimEnd('\\') + "\" \"" + installDir.TrimEnd('\\') + "\" " + Process.GetCurrentProcess().Id);
        psi.UseShellExecute = false; psi.WorkingDirectory = newDir;
        Process.Start(psi);
    }
}

// Test de débit (comme Speedtest) avec les serveurs publics de Cloudflare (speed.cloudflare.com).
// Plusieurs connexions en parallèle pendant ~8 s dans chaque sens, comme les vrais tests de débit.
public static class AeroxSpeed {
    const string Base = "https://speed.cloudflare.com/";
    public static volatile string Phase = "";      // meta, ping, down, up, done, error, stopped
    public static volatile bool Stop = false;
    public static double Ping = -1, Jitter = -1, Down = -1, Up = -1, Live = 0, Percent = 0;
    public static string Error = "", Isp = "", City = "", Colo = "";
    static Thread th;
    static long bytes;
    public static bool Running { get { return th != null && th.IsAlive; } }

    public static void Start() {
        if (Running) return;
        Phase = "meta"; Stop = false; Ping = -1; Jitter = -1; Down = -1; Up = -1; Live = 0; Percent = 0; Error = ""; Isp = ""; City = ""; Colo = "";
        th = new Thread(Run); th.IsBackground = true; th.Start();
    }

    static void Run() {
        try {
            ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
            ServicePointManager.DefaultConnectionLimit = Math.Max(ServicePointManager.DefaultConnectionLimit, 32);
            ServicePointManager.Expect100Continue = false;
            Meta();
            if (Stop) { Phase = "stopped"; return; }
            Phase = "ping"; PingTest();
            if (Stop) { Phase = "stopped"; return; }
            Phase = "down"; Down = Transfer(true, 6, 8000);
            if (Stop) { Phase = "stopped"; return; }
            Phase = "up"; Up = Transfer(false, 4, 8000);
            Live = 0; Percent = 100;
            Phase = Stop ? "stopped" : "done";
        } catch (Exception ex) {
            Exception e = ex; while (e.InnerException != null) e = e.InnerException;
            Error = e.Message; Phase = "error";
        }
    }

    static HttpWebRequest Req(string url, string method) {
        HttpWebRequest r = (HttpWebRequest)WebRequest.Create(url);
        r.Method = method; r.UserAgent = "AeroxPCCare"; r.KeepAlive = true; r.Timeout = 15000; r.ReadWriteTimeout = 15000;
        r.Proxy = WebRequest.DefaultWebProxy;
        r.AutomaticDecompression = DecompressionMethods.None;
        return r;
    }

    static void Meta() {
        try {
            HttpWebRequest r = Req(Base + "meta", "GET");
            using (HttpWebResponse resp = (HttpWebResponse)r.GetResponse())
            using (StreamReader sr = new StreamReader(resp.GetResponseStream())) {
                string j = sr.ReadToEnd();
                Isp = JsonField(j, "asOrganization"); City = JsonField(j, "city"); Colo = JsonField(j, "colo");
            }
        } catch { }
    }
    static string JsonField(string j, string k) {
        Match m = Regex.Match(j, "\"" + k + "\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\"");
        return m.Success ? Regex.Unescape(m.Groups[1].Value) : "";
    }

    // Latence : temps de réponse d'une requête vide (connexion déjà ouverte), 15 mesures
    static void PingTest() {
        List<double> t = new List<double>();
        for (int i = 0; i < 16 && !Stop; i++) {
            Stopwatch sw = Stopwatch.StartNew();
            HttpWebRequest r = Req(Base + "__down?bytes=0", "GET");
            using (HttpWebResponse resp = (HttpWebResponse)r.GetResponse()) { using (Stream s = resp.GetResponseStream()) { s.ReadByte(); } }
            sw.Stop();
            if (i > 0) t.Add(sw.Elapsed.TotalMilliseconds);   // la 1re mesure inclut l'ouverture de la connexion
            Percent = i * 100.0 / 16;
            Thread.Sleep(60);
        }
        if (t.Count == 0) return;
        List<double> sorted = new List<double>(t); sorted.Sort();
        Ping = sorted[Math.Max(0, sorted.Count / 4)];          // 1er quartile : robuste aux pics
        double j = 0; for (int i = 1; i < t.Count; i++) j += Math.Abs(t[i] - t[i - 1]);
        Jitter = t.Count > 1 ? j / (t.Count - 1) : 0;
    }

    static double Transfer(bool down, int streams, int durationMs) {
        bytes = 0; Live = 0; Percent = 0;
        Stopwatch clock = Stopwatch.StartNew();
        long warmBytes = -1; double warmT = 0; const int warm = 1500;
        List<Thread> ts = new List<Thread>();
        List<HttpWebRequest> live = new List<HttpWebRequest>();
        object lk = new object();
        string err = null;
        for (int n = 0; n < streams; n++) {
            Thread t = new Thread(delegate() {
                byte[] buf = new byte[65536];
                if (!down) new Random().NextBytes(buf);
                while (!Stop && clock.ElapsedMilliseconds < durationMs) {
                    HttpWebRequest r = null;
                    try {
                        if (down) {
                            r = Req(Base + "__down?bytes=25000000", "GET");
                            lock (lk) live.Add(r);
                            using (HttpWebResponse resp = (HttpWebResponse)r.GetResponse())
                            using (Stream s = resp.GetResponseStream()) {
                                int k;
                                while ((k = s.Read(buf, 0, buf.Length)) > 0) {
                                    Interlocked.Add(ref bytes, k);
                                    if (Stop || clock.ElapsedMilliseconds >= durationMs) break;
                                }
                                // Arrêt en cours de route : on coupe la connexion (sinon .NET lit la fin du fichier)
                                if (k > 0) r.Abort();
                            }
                        } else {
                            const int size = 8 * 1024 * 1024;
                            r = Req(Base + "__up", "POST");
                            r.ContentType = "application/octet-stream"; r.ContentLength = size; r.AllowWriteStreamBuffering = false; r.SendChunked = false;
                            lock (lk) live.Add(r);
                            using (Stream s = r.GetRequestStream()) {
                                int sent = 0;
                                while (sent < size) {
                                    int k = Math.Min(buf.Length, size - sent);
                                    s.Write(buf, 0, k); sent += k;
                                    Interlocked.Add(ref bytes, k);
                                    if (Stop || clock.ElapsedMilliseconds >= durationMs) break;
                                }
                                if (sent < size) { r.Abort(); continue; }
                            }
                            using (HttpWebResponse resp = (HttpWebResponse)r.GetResponse()) { }
                        }
                    } catch (Exception ex) {
                        if (!Stop && clock.ElapsedMilliseconds < durationMs) { lock (lk) { if (err == null) err = ex.Message; } Thread.Sleep(300); }
                    } finally {
                        if (r != null) { lock (lk) live.Remove(r); try { r.Abort(); } catch { } }
                    }
                }
            });
            t.IsBackground = true; ts.Add(t); t.Start();
        }
        // Suivi en direct (débit sur la dernière seconde)
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
        if (warmBytes < 0) { warmBytes = 0; warmT = 0; }
        double mbps = (endB - warmBytes) * 8 / ((endT - warmT) / 1000.0) / 1e6;
        if (endB == 0 && err != null) throw new Exception(err);
        return mbps;
    }
}
