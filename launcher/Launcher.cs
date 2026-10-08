// AEROX PC Care - programme de lancement
// Demande les droits administrateur, puis exécute AeroxPCCare.ps1 dans le moteur PowerShell de Windows,
// à l'intérieur de ce programme (pas de fenêtre PowerShell cachée, pas de contournement des règles de sécurité).
using System;
using System.IO;
using System.Text;
using System.Threading;
using System.Reflection;
using System.Diagnostics;
using System.Collections;
using System.Collections.Generic;
using System.Security.Principal;
using System.Runtime.InteropServices;
using System.Windows.Forms;

[assembly: AssemblyTitle("AEROX PC Care")]
[assembly: AssemblyDescription("Diagnostic, nettoyage, mises à jour et optimisation de Windows")]
[assembly: AssemblyProduct("AEROX PC Care")]
[assembly: AssemblyCompany("AEROX")]
[assembly: AssemblyCopyright("AEROX")]

static class Program {
    [DllImport("kernel32.dll")] static extern bool AllocConsole();
    [DllImport("kernel32.dll")] static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool DeleteFileW(string path);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);

    // Une seule fenêtre du logiciel à la fois : si elle est déjà ouverte, on la ramène au premier plan
    static bool AlreadyRunning() {
        try {
            System.Threading.Mutex m = System.Threading.Mutex.OpenExisting(@"Local\AeroxPCCare_Instance");
            m.Close();
        } catch (System.Threading.WaitHandleCannotBeOpenedException) { return false; }
        catch (UnauthorizedAccessException) { }
        catch { return false; }
        try {
            IntPtr h = FindWindow(null, Title);
            if (h != IntPtr.Zero) { if (IsIconic(h)) ShowWindow(h, 9); SetForegroundWindow(h); }
        } catch { }
        return true;
    }
    static System.Threading.Mutex instance;

    // Retire la marque « téléchargé depuis Internet » (Zone.Identifier) des fichiers du logiciel,
    // comme le bouton « Débloquer » des propriétés d'un fichier : sinon .NET refuse de charger la DLL.
    static void UnblockFolder(string dir) {
        try {
            foreach (string f in Directory.GetFiles(dir, "*", SearchOption.AllDirectories)) { try { DeleteFileW(f + ":Zone.Identifier"); } catch { } }
        } catch { }
    }

    const string Title = "AEROX PC Care";

    [STAThread]
    static int Main(string[] args) {
        if (args.Length >= 3 && args[0] == "--capteurs") return Sensors.Run(args[1], args[2]);
        AeroxSplash splash = null;
        try {
            if (AlreadyRunning()) return 0;
            if (!new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator)) {
                try {
                    ProcessStartInfo psi = new ProcessStartInfo(Assembly.GetExecutingAssembly().Location);
                    psi.UseShellExecute = true; psi.Verb = "runas";
                    Process.Start(psi);
                } catch {
                    MessageBox.Show("AEROX PC Care a besoin des droits administrateur pour analyser et réparer Windows.\n\nRelance-le et clique sur « Oui » quand Windows te le demande.", Title, MessageBoxButtons.OK, MessageBoxIcon.Warning);
                }
                return 0;
            }

            string dir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
            bool created;
            instance = new System.Threading.Mutex(true, @"Local\AeroxPCCare_Instance", out created);
            if (!created) { AlreadyRunning(); return 0; }

            // Écran de chargement tout de suite, le temps que le logiciel démarre
            splash = new AeroxSplash();
            splash.Show(Path.Combine(dir, "aerox.ico"));

            string script = Path.Combine(dir, "AeroxPCCare.ps1");
            if (!File.Exists(script)) {
                MessageBox.Show("Le fichier AeroxPCCare.ps1 est introuvable à côté du programme.\n\nDézippe tout le dossier puis relance.\n(Si ton antivirus l'a mis en quarantaine, restaure-le.)", Title, MessageBoxButtons.OK, MessageBoxIcon.Error);
                return 1;
            }

            // Console invisible : les outils Windows lancés par le logiciel (winget, DISM...) l'utilisent sans ouvrir de fenêtre
            if (AllocConsole()) { IntPtr h = GetConsoleWindow(); if (h != IntPtr.Zero) ShowWindow(h, 0); }

            string code = ReadWithRetry(script);
            UnblockFolder(dir);
            UnblockFolder(Path.Combine(LogDir(), "outils"));

            Assembly sma = Assembly.Load("System.Management.Automation, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35");
            Type rsFactory = sma.GetType("System.Management.Automation.Runspaces.RunspaceFactory", true);
            Type psType = sma.GetType("System.Management.Automation.PowerShell", true);
            Type optType = sma.GetType("System.Management.Automation.Runspaces.PSThreadOptions", true);

            object rs = FindMethod(rsFactory, "CreateRunspace", 0).Invoke(null, null);
            rs.GetType().GetProperty("ApartmentState").SetValue(rs, ApartmentState.STA, null);
            rs.GetType().GetProperty("ThreadOptions").SetValue(rs, Enum.Parse(optType, "UseCurrentThread"), null);
            FindMethod(rs.GetType(), "Open", 0).Invoke(rs, null);
            object ssp = rs.GetType().GetProperty("SessionStateProxy").GetValue(rs, null);
            ssp.GetType().GetMethod("SetVariable", new Type[] { typeof(string), typeof(object) }).Invoke(ssp, new object[] { "AeroxRoot", dir });
            ssp.GetType().GetMethod("SetVariable", new Type[] { typeof(string), typeof(object) }).Invoke(ssp, new object[] { "AeroxLauncher", Assembly.GetExecutingAssembly().Location });
            ssp.GetType().GetMethod("SetVariable", new Type[] { typeof(string), typeof(object) }).Invoke(ssp, new object[] { "AeroxSplash", splash });

            object ps = FindMethod(psType, "Create", 0).Invoke(null, null);
            psType.GetProperty("Runspace").SetValue(ps, rs, null);
            FindMethod(psType, "AddScript", 1).Invoke(ps, new object[] { code });
            try {
                FindMethod(psType, "Invoke", 0).Invoke(ps, null);
            } catch (TargetInvocationException tie) {
                splash.Close();
                Exception inner = tie.InnerException ?? tie;
                if (inner.GetType().Name != "ExitException") Report(dir, inner.ToString());
            }
            splash.Close();

            // Erreurs non attrapées par le script
            object streams = psType.GetProperty("Streams").GetValue(ps, null);
            IList errors = (IList)streams.GetType().GetProperty("Error").GetValue(streams, null);
            if (errors.Count > 0) {
                StringBuilder sb = new StringBuilder();
                foreach (object e in errors) sb.AppendLine(e.ToString());
                File.WriteAllText(Path.Combine(LogDir(), "erreurs_lanceur.txt"), sb.ToString(), Encoding.UTF8);
            }
            return 0;
        } catch (Exception ex) {
            if (splash != null) splash.Close();
            Report(AppDomain.CurrentDomain.BaseDirectory, ex.ToString());
            return 1;
        }
    }

    // Méthode non générique avec ce nom et ce nombre de paramètres (évite les surcharges ambiguës)
    static MethodInfo FindMethod(Type t, string name, int nParams) {
        foreach (MethodInfo m in t.GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.Static)) {
            if (m.Name != name || m.IsGenericMethodDefinition) continue;
            ParameterInfo[] p = m.GetParameters();
            if (p.Length != nParams) continue;
            if (nParams == 1 && p[0].ParameterType != typeof(string)) continue;
            return m;
        }
        throw new MissingMethodException(t.FullName, name);
    }

    // Lit le script même si l'antivirus est en train de l'analyser (il le verrouille quelques secondes)
    static string ReadWithRetry(string path) {
        Exception last = null;
        for (int i = 0; i < 60; i++) {
            try {
                using (FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
                using (StreamReader sr = new StreamReader(fs, Encoding.UTF8, true)) { return sr.ReadToEnd(); }
            } catch (IOException ex) { last = ex; Thread.Sleep(500); }
            catch (UnauthorizedAccessException ex) { last = ex; Thread.Sleep(500); }
        }
        throw new IOException("Impossible de lire AeroxPCCare.ps1 depuis 30 secondes : ton antivirus le bloque peut-être. Ajoute le dossier AEROX PC Care à ses exceptions.", last);
    }

    static string LogDir() {
        string d = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AeroxPCCare");
        Directory.CreateDirectory(d);
        return d;
    }

    static void Report(string dir, string text) {
        try { File.WriteAllText(Path.Combine(LogDir(), "plantage.txt"), "[" + DateTime.Now + "] Lanceur AEROX PC Care\r\n" + text, Encoding.UTF8); } catch { }
        string first = text.Split('\n')[0];
        MessageBox.Show("AEROX PC Care a rencontré une erreur :\n\n" + first + "\n\nLe détail est enregistré dans :\n" + Path.Combine(LogDir(), "plantage.txt"), Title, MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
}


// Mode « capteurs » : lit LibreHardwareMonitor dans un processus séparé et écrit les valeurs chaque seconde.
// Si la bibliothèque plante, seul ce processus s'arrête : le logiciel principal continue.
static class Sensors {
    static string dir;
    [ThreadStatic] static bool resolving;

    static Assembly Resolve(object sender, ResolveEventArgs args) {
        if (resolving) return null;
        resolving = true;
        try {
            string name = new AssemblyName(args.Name).Name;
            foreach (Assembly a in AppDomain.CurrentDomain.GetAssemblies()) { if (a.GetName().Name == name) return a; }
            string p = Path.Combine(dir, name + ".dll");
            if (File.Exists(p)) return Assembly.LoadFrom(p);
#pragma warning disable 618
            return Assembly.LoadWithPartialName(name);
#pragma warning restore 618
        } catch { return null; }
        finally { resolving = false; }
    }

    public static int Run(string lhmDir, string parentPid) {
        dir = lhmDir;
        AppDomain.CurrentDomain.AssemblyResolve += Resolve;
        // Pas de console dans ce programme : on écrit directement dans la sortie redirigée par le logiciel
        UTF8Encoding utf8 = new UTF8Encoding(false);
        StreamWriter outw = new StreamWriter(Console.OpenStandardOutput(), utf8);
        StreamWriter errw = new StreamWriter(Console.OpenStandardError(), utf8);
        Process parent = null;
        try { parent = Process.GetProcessById(int.Parse(parentPid)); } catch { }
        try {
            Assembly asm = Assembly.LoadFrom(Path.Combine(lhmDir, "LibreHardwareMonitorLib.dll"));
            Type tComputer = asm.GetType("LibreHardwareMonitor.Hardware.Computer", true);
            Type tHw = asm.GetType("LibreHardwareMonitor.Hardware.IHardware", true);
            Type tSensor = asm.GetType("LibreHardwareMonitor.Hardware.ISensor", true);
            object pc = Activator.CreateInstance(tComputer);
            tComputer.GetProperty("IsCpuEnabled").SetValue(pc, true, null);
            tComputer.GetProperty("IsGpuEnabled").SetValue(pc, true, null);
            tComputer.GetMethod("Open", Type.EmptyTypes).Invoke(pc, null);
            PropertyInfo pHardware = tComputer.GetProperty("Hardware");
            PropertyInfo hName = tHw.GetProperty("Name"), hType = tHw.GetProperty("HardwareType"), hSensors = tHw.GetProperty("Sensors"), hSub = tHw.GetProperty("SubHardware");
            MethodInfo hUpdate = tHw.GetMethod("Update", Type.EmptyTypes);
            PropertyInfo sName = tSensor.GetProperty("Name"), sType = tSensor.GetProperty("SensorType"), sValue = tSensor.GetProperty("Value");
            outw.Write("OK\n");
            outw.Flush();
            while (true) {
                if (parent != null) { try { if (parent.HasExited) break; } catch { break; } }
                StringBuilder sb = new StringBuilder();
                foreach (object hw in (IEnumerable)pHardware.GetValue(pc, null)) {
                    try { hUpdate.Invoke(hw, null); } catch { }
                    List<object> all = new List<object>();
                    foreach (object sub in (IEnumerable)hSub.GetValue(hw, null)) { try { hUpdate.Invoke(sub, null); } catch { } all.Add(sub); }
                    string hn = Clean(hName.GetValue(hw, null)), ht = Clean(hType.GetValue(hw, null));
                    List<object> srcs = new List<object>(); srcs.Add(hw); srcs.AddRange(all);
                    foreach (object h in srcs) {
                        foreach (object sn in (IEnumerable)hSensors.GetValue(h, null)) {
                            object v = sValue.GetValue(sn, null);
                            if (v == null) continue;
                            sb.Append(ht).Append('|').Append(hn).Append('|').Append(Clean(sType.GetValue(sn, null))).Append('|').Append(Clean(sName.GetValue(sn, null))).Append('|')
                              .Append(Convert.ToDouble(v).ToString(System.Globalization.CultureInfo.InvariantCulture)).Append('\n');
                        }
                    }
                }
                sb.Append("---\n");
                try { outw.Write(sb.ToString()); outw.Flush(); } catch { break; }
                Thread.Sleep(1000);
            }
            try { tComputer.GetMethod("Close", Type.EmptyTypes).Invoke(pc, null); } catch { }
            return 0;
        } catch (Exception ex) {
            Exception e = ex is TargetInvocationException && ex.InnerException != null ? ex.InnerException : ex;
            try { errw.Write("ERREUR|" + e.GetType().Name + ": " + e.Message.Replace('\n', ' ').Replace('\r', ' ') + "\n"); errw.Flush(); } catch { }
            return 2;
        }
    }
    static string Clean(object o) { return o == null ? "" : o.ToString().Replace('|', '/').Replace('\n', ' '); }
}


// Écran de chargement : petite fenêtre affichée pendant que le logiciel démarre (fil séparé).
// Le script la ferme dès que la fenêtre principale est affichée ($AeroxSplash.Close()).
public class AeroxSplash {
    Form f;
    readonly System.Threading.ManualResetEvent ready = new System.Threading.ManualResetEvent(false);
    volatile bool closed = false;

    public void Show(string icoPath) {
        Thread t = new Thread(delegate() {
            try {
                f = new Form();
                f.Text = "AEROX PC Care"; f.FormBorderStyle = FormBorderStyle.None; f.StartPosition = FormStartPosition.CenterScreen;
                f.Size = new System.Drawing.Size(400, 140); f.BackColor = System.Drawing.Color.FromArgb(20, 23, 32); f.ShowInTaskbar = true;
                try { f.Icon = new System.Drawing.Icon(icoPath); } catch { }
                PictureBox pb = new PictureBox(); pb.Size = new System.Drawing.Size(56, 56); pb.Location = new System.Drawing.Point(24, 32); pb.SizeMode = PictureBoxSizeMode.Zoom;
                try { pb.Image = new System.Drawing.Icon(icoPath, 64, 64).ToBitmap(); } catch { }
                Label t1 = new Label(); t1.Text = "AEROX PC Care"; t1.ForeColor = System.Drawing.Color.White; t1.Font = new System.Drawing.Font("Segoe UI", 15f, System.Drawing.FontStyle.Bold);
                t1.Location = new System.Drawing.Point(96, 30); t1.AutoSize = true;
                Label t2 = new Label(); t2.Text = "Démarrage en cours…"; t2.ForeColor = System.Drawing.Color.FromArgb(169, 176, 194); t2.Font = new System.Drawing.Font("Segoe UI", 10f);
                t2.Location = new System.Drawing.Point(98, 64); t2.AutoSize = true;
                ProgressBar bar = new ProgressBar(); bar.Style = ProgressBarStyle.Marquee; bar.MarqueeAnimationSpeed = 30;
                bar.Location = new System.Drawing.Point(98, 94); bar.Size = new System.Drawing.Size(270, 8);
                f.Controls.Add(pb); f.Controls.Add(t1); f.Controls.Add(t2); f.Controls.Add(bar);
                System.Windows.Forms.Timer safety = new System.Windows.Forms.Timer(); safety.Interval = 120000;
                safety.Tick += delegate { safety.Stop(); f.Close(); }; safety.Start();
                f.Shown += delegate { ready.Set(); if (closed) f.Close(); };
                Application.Run(f);
            } catch { }
            ready.Set();
        });
        t.SetApartmentState(ApartmentState.STA); t.IsBackground = true; t.Start();
        ready.WaitOne(2000);
    }

    public void Close() {
        closed = true;
        try { if (f != null && f.IsHandleCreated && !f.IsDisposed) f.BeginInvoke((MethodInvoker)delegate { try { f.Close(); } catch { } }); } catch { }
    }
}
