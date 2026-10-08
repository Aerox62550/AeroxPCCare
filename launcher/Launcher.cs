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
        try {
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

            object ps = FindMethod(psType, "Create", 0).Invoke(null, null);
            psType.GetProperty("Runspace").SetValue(ps, rs, null);
            FindMethod(psType, "AddScript", 1).Invoke(ps, new object[] { code });
            try {
                FindMethod(psType, "Invoke", 0).Invoke(ps, null);
            } catch (TargetInvocationException tie) {
                Exception inner = tie.InnerException ?? tie;
                if (inner.GetType().Name != "ExitException") Report(dir, inner.ToString());
            }

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
