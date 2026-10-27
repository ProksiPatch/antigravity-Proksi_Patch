using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.InteropServices;
using System.ServiceProcess;
using System.Threading;
using System.Windows.Forms;

namespace ProksiFiApp {
    public class TrayAppContext : ApplicationContext {
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        private static extern bool DestroyIcon(IntPtr handle);

        public const string AppMutexName = @"Local\ProksiFi_v2.0_SingleInstance_Mutex";
        public const string AppWakeEventName = @"Local\ProksiFi_v2.0_WakeUpEvent";

        private const string ServiceName = "ProksiFiService";
        private const string LegacyServiceName = "AntigravityBypassService";
        private const string InstallPath = @"C:\Program Files\ProksiFi";
        private const string DataPath = @"C:\ProgramData\ProksiFi";

        // Tray Components
        private NotifyIcon trayIcon;
        private ContextMenuStrip trayMenu;
        private ToolStripMenuItem miStatus;
        private ToolStripMenuItem miNode;
        private ToolStripSeparator sepHeader;
        private ToolStripMenuItem miInstall;
        private ToolStripMenuItem miEnable;
        private ToolStripMenuItem miDisable;
        private ToolStripMenuItem miTest;
        private ToolStripMenuItem miRestart;
        private ToolStripSeparator sepActions;
        private ToolStripMenuItem miDiag;
        private ToolStripMenuItem miLogs;
        private ToolStripSeparator sepLogs;
        private ToolStripMenuItem miUninstall;
        private ToolStripMenuItem miExit;

        private System.Windows.Forms.Timer timerStatus;
        private bool isBusy = false;
        private Icon iconActive = null;
        private Icon iconStopped = null;
        private Icon iconChecking = null;
        private SynchronizationContext syncContext;

        public TrayAppContext() {
            syncContext = SynchronizationContext.Current ?? new SynchronizationContext();

            LoadCachedIcons();
            InitializeTray();
            UpdateServiceStatus();

            // Status polling timer (every 3 seconds)
            timerStatus = new System.Windows.Forms.Timer();
            timerStatus.Interval = 3000;
            timerStatus.Tick += (s, e) => {
                if (!isBusy) UpdateServiceStatus();
            };
            timerStatus.Start();

            // If not installed on initial launch, offer quick installation
            if (!CheckServiceExists()) {
                DialogResult dr = MessageBox.Show(
                    "Служба ProksiFi v2.0 не установлена в системе.\n\nЗапустить установку прямо сейчас?",
                    "Установка ProksiFi v2.0",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Question
                );
                if (dr == DialogResult.Yes) {
                    RunConsoleScript("install.ps1", "");
                }
            } else {
                trayIcon.ShowBalloonTip(2500, "ProksiFi v2.0", "Обход активен в системном трее Windows.", ToolTipIcon.Info);
            }
        }

        private void InitializeTray() {
            trayMenu = new ContextMenuStrip();
            try {
                trayMenu.Font = new Font("Segoe UI Variable Text", 9.25f, FontStyle.Regular);
            } catch {
                trayMenu.Font = new Font("Segoe UI", 9.25f, FontStyle.Regular);
            }
            trayMenu.ShowImageMargin = false;
            trayMenu.Padding = new Padding(3, 4, 3, 4);
            trayMenu.DropShadowEnabled = false;

            // 1. Informative Header (Non-interactive)
            miStatus = new ToolStripMenuItem("● СТАТУС: ПРОВЕРКА...");
            miStatus.Font = new Font(trayMenu.Font.FontFamily, 9.25f, FontStyle.Bold);
            miStatus.ForeColor = Color.FromArgb(249, 226, 175);
            miStatus.Padding = new Padding(12, 6, 12, 2);
            trayMenu.Items.Add(miStatus);

            miNode = new ToolStripMenuItem("  Сервер: Европа (Франкфурт)");
            miNode.Font = new Font(trayMenu.Font.FontFamily, 8.5f, FontStyle.Regular);
            miNode.ForeColor = Color.FromArgb(150, 150, 150);
            miNode.Padding = new Padding(12, 0, 12, 6);
            trayMenu.Items.Add(miNode);

            // Connect Windows 11 Dark Fluent Renderer
            trayMenu.Renderer = new Win11TrayMenuRenderer(miStatus, miNode);

            sepHeader = new ToolStripSeparator();
            trayMenu.Items.Add(sepHeader);

            // 2. Install (Only visible if service is not installed)
            miInstall = new ToolStripMenuItem("Установить службу ProksiFi");
            miInstall.Font = new Font(trayMenu.Font.FontFamily, 9.25f, FontStyle.Bold);
            miInstall.ForeColor = Color.FromArgb(137, 180, 250);
            miInstall.Padding = new Padding(12, 5, 12, 5);
            miInstall.Visible = false;
            miInstall.Click += (s, e) => RunConsoleScript("install.ps1", "");
            trayMenu.Items.Add(miInstall);

            // 3. Actions
            miEnable = new ToolStripMenuItem("Включить обход");
            miEnable.ForeColor = Color.FromArgb(240, 240, 240);
            miEnable.Padding = new Padding(12, 5, 12, 5);
            miEnable.Click += (s, e) => RunSetupOperation("manage.ps1", "-Action start", "Включение обхода...");
            trayMenu.Items.Add(miEnable);

            miDisable = new ToolStripMenuItem("Выключить обход");
            miDisable.ForeColor = Color.FromArgb(240, 240, 240);
            miDisable.Padding = new Padding(12, 5, 12, 5);
            miDisable.Click += (s, e) => RunSetupOperation("manage.ps1", "-Action stop", "Выключение обхода...");
            trayMenu.Items.Add(miDisable);

            miTest = new ToolStripMenuItem("Тест подключения (Gemini, TG, IP)");
            miTest.ForeColor = Color.FromArgb(240, 240, 240);
            miTest.Padding = new Padding(12, 5, 12, 5);
            miTest.Click += (s, e) => RunConsoleScript("manage.ps1", "-Action test");
            trayMenu.Items.Add(miTest);

            miRestart = new ToolStripMenuItem("Перезапустить службу");
            miRestart.ForeColor = Color.FromArgb(240, 240, 240);
            miRestart.Padding = new Padding(12, 5, 12, 5);
            miRestart.Click += (s, e) => RunSetupOperation("manage.ps1", "-Action restart", "Перезапуск службы...");
            trayMenu.Items.Add(miRestart);

            sepActions = new ToolStripSeparator();
            trayMenu.Items.Add(sepActions);

            // 4. Advanced Diagnostics & Logs
            miDiag = new ToolStripMenuItem("Диагностика и анализ ошибок");
            miDiag.Font = new Font(trayMenu.Font.FontFamily, 9.25f, FontStyle.Bold);
            miDiag.ForeColor = Color.FromArgb(137, 180, 250); // Soft Blue #89b4fa
            miDiag.Padding = new Padding(12, 5, 12, 5);
            miDiag.Click += (s, e) => RunConsoleScript("manage.ps1", "-Action diag");
            trayMenu.Items.Add(miDiag);

            miLogs = new ToolStripMenuItem("Журнал событий (Логи)");
            miLogs.ForeColor = Color.FromArgb(240, 240, 240);
            miLogs.Padding = new Padding(12, 5, 12, 5);
            miLogs.Click += (s, e) => RunConsoleScript("manage.ps1", "-Action logs");
            trayMenu.Items.Add(miLogs);

            sepLogs = new ToolStripSeparator();
            trayMenu.Items.Add(sepLogs);

            // 5. Full Uninstall & Exit
            miUninstall = new ToolStripMenuItem("Полное удаление программы...");
            miUninstall.ForeColor = Color.FromArgb(243, 139, 168);
            miUninstall.Padding = new Padding(12, 5, 12, 5);
            miUninstall.Click += (s, e) => ConfirmAndUninstall();
            trayMenu.Items.Add(miUninstall);

            miExit = new ToolStripMenuItem("Выход");
            miExit.ForeColor = Color.FromArgb(240, 240, 240);
            miExit.Padding = new Padding(12, 5, 12, 5);
            miExit.Click += (s, e) => ExitApplication();
            trayMenu.Items.Add(miExit);

            // Create NotifyIcon
            trayIcon = new NotifyIcon();
            trayIcon.ContextMenuStrip = trayMenu;
            trayIcon.Text = "ProksiFi v2.0: Запуск...";
            trayIcon.Visible = true;

            // Left click immediately displays context menu (native Win11 experience)
            trayIcon.MouseClick += (s, e) => {
                if (e.Button == MouseButtons.Left) {
                    MethodInfo mi = typeof(NotifyIcon).GetMethod("ShowContextMenu", BindingFlags.Instance | BindingFlags.NonPublic);
                    if (mi != null) {
                        mi.Invoke(trayIcon, null);
                    }
                }
            };
        }

        private bool CheckServiceExists() {
            try {
                using (ServiceController sc = new ServiceController(ServiceName)) {
                    var s = sc.Status;
                    return true;
                }
            } catch {
                try {
                    using (ServiceController scLegacy = new ServiceController(LegacyServiceName)) {
                        var s = scLegacy.Status;
                        return true;
                    }
                } catch {
                    return false;
                }
            }
        }

        private void UpdateServiceStatus() {
            try {
                ServiceControllerStatus status = ServiceControllerStatus.Stopped;
                bool serviceFound = false;

                try {
                    using (ServiceController sc = new ServiceController(ServiceName)) {
                        status = sc.Status;
                        serviceFound = true;
                    }
                } catch {
                    try {
                        using (ServiceController scLegacy = new ServiceController(LegacyServiceName)) {
                            status = scLegacy.Status;
                            serviceFound = true;
                        }
                    } catch { }
                }

                if (!serviceFound) {
                    SetTrayState("Не установлена", Color.FromArgb(149, 165, 166), "НЕ УСТАНОВЛЕНА", false, false);
                    return;
                }

                if (status == ServiceControllerStatus.Running) {
                    SetTrayState("Обход ВКЛЮЧЕН", Color.FromArgb(166, 227, 161), "ОБХОД ВКЛЮЧЕН", true, true);
                } else if (status == ServiceControllerStatus.Stopped) {
                    SetTrayState("Обход ВЫКЛЮЧЕН", Color.FromArgb(243, 139, 168), "ОБХОД ВЫКЛЮЧЕН", false, true);
                } else {
                    SetTrayState("Служба: " + status.ToString(), Color.FromArgb(249, 226, 175), status.ToString(), false, true);
                }
            } catch { }
        }

        private void SetTrayState(string title, Color color, string statusText, bool isRunning, bool installed) {
            try {
                Icon targetIcon = !installed ? iconChecking : (isRunning ? iconActive : iconStopped);
                if (targetIcon != null && trayIcon.Icon != targetIcon) {
                    trayIcon.Icon = targetIcon;
                }
            } catch { }

            string text = "ProksiFi v2.0: " + title;
            if (text.Length > 63) text = text.Substring(0, 63);
            trayIcon.Text = text;

            miStatus.Text = "● СТАТУС: " + statusText.ToUpper();
            miStatus.ForeColor = color;

            miInstall.Visible = !installed;
            miEnable.Visible = installed;
            miDisable.Visible = installed;

            miEnable.Enabled = !isRunning && !isBusy;
            miDisable.Enabled = isRunning && !isBusy;
            miRestart.Enabled = installed && !isBusy;
            miTest.Enabled = !isBusy;
            miDiag.Enabled = !isBusy;
            miLogs.Enabled = !isBusy;
        }

        private void LoadCachedIcons() {
            try {
                iconActive = GetTrayIcon("active");
                iconStopped = GetTrayIcon("stopped");
                iconChecking = GetTrayIcon("checking");
            } catch { }
        }

        private Icon GetTrayIcon(string state) {
            try {
                string resName = "IconActive";
                if (state == "stopped") resName = "IconStopped";
                else if (state == "checking") resName = "IconChecking";

                Assembly asm = Assembly.GetExecutingAssembly();
                using (Stream stream = asm.GetManifestResourceStream(resName)) {
                    if (stream != null) {
                        return new Icon(stream, SystemInformation.SmallIconSize);
                    }
                }
            } catch { }

            Color fallbackColor = state == "active" ? Color.FromArgb(0, 230, 118) :
                                  (state == "stopped" ? Color.FromArgb(148, 163, 184) : Color.FromArgb(251, 191, 36));
            return CreateVectorShieldIcon(fallbackColor);
        }

        private Icon CreateVectorShieldIcon(Color statusColor) {
            Size sz = SystemInformation.SmallIconSize;
            int w = Math.Max(16, sz.Width);
            int h = Math.Max(16, sz.Height);
            using (Bitmap bmp = new Bitmap(w, h)) {
                using (Graphics g = Graphics.FromImage(bmp)) {
                    g.SmoothingMode = SmoothingMode.AntiAlias;
                    g.PixelOffsetMode = PixelOffsetMode.HighQuality;

                    float cx = w / 2f;
                    PointF[] leftShield = new PointF[] {
                        new PointF(cx, 1f),
                        new PointF(2f, 3f),
                        new PointF(2f, 8f),
                        new PointF(cx, h - 2f)
                    };
                    PointF[] rightShield = new PointF[] {
                        new PointF(cx, 1f),
                        new PointF(w - 2f, 3f),
                        new PointF(w - 2f, 8f),
                        new PointF(cx, h - 2f)
                    };

                    using (Brush bLeft = new SolidBrush(statusColor)) {
                        g.FillPolygon(bLeft, leftShield);
                    }
                    using (Brush bRight = new SolidBrush(Color.FromArgb(
                        Math.Max(0, (int)statusColor.R - 40),
                        Math.Max(0, (int)statusColor.G - 40),
                        Math.Max(0, (int)statusColor.B - 40)))) {
                        g.FillPolygon(bRight, rightShield);
                    }

                    // Center white bolt
                    PointF[] bolt = new PointF[] {
                        new PointF(cx + 0.5f, 2.5f),
                        new PointF(cx - 2.5f, 7f),
                        new PointF(cx - 0.2f, 7f),
                        new PointF(cx - 1.2f, 12f),
                        new PointF(cx + 2.5f, 6.5f),
                        new PointF(cx + 0.2f, 6.5f)
                    };
                    using (Brush bBolt = new SolidBrush(Color.White)) {
                        g.FillPolygon(bBolt, bolt);
                    }
                }
                IntPtr hIcon = bmp.GetHicon();
                try {
                    using (Icon temp = Icon.FromHandle(hIcon)) {
                        return (Icon)temp.Clone();
                    }
                } finally {
                    DestroyIcon(hIcon);
                }
            }
        }

        private string EnsureExtractedPayload() {
            string extractDir = Path.Combine(Path.GetTempPath(), "ProksiFi_Setup");
            if (!Directory.Exists(extractDir)) {
                Directory.CreateDirectory(extractDir);
            }

            Assembly asm = Assembly.GetExecutingAssembly();
            using (Stream resStream = asm.GetManifestResourceStream("PayloadArchive")) {
                if (resStream == null) {
                    throw new InvalidOperationException("Встроенный архив компонентов не найден в сборке программы!");
                }
                using (ZipArchive archive = new ZipArchive(resStream, ZipArchiveMode.Read)) {
                    foreach (ZipArchiveEntry entry in archive.Entries) {
                        string fullPath = Path.Combine(extractDir, entry.FullName);
                        if (string.IsNullOrEmpty(entry.Name)) {
                            Directory.CreateDirectory(fullPath);
                        } else {
                            Directory.CreateDirectory(Path.GetDirectoryName(fullPath));
                            entry.ExtractToFile(fullPath, true);
                        }
                    }
                }
            }
            return extractDir;
        }

        // Runs a PowerShell script in an interactive visible Console window, ending with "Press any key to continue"
        private void RunConsoleScript(string scriptName, string scriptArgs) {
            ThreadPool.QueueUserWorkItem(_ => {
                try {
                    string scriptPath = Path.Combine(InstallPath, scriptName);
                    string workDir = InstallPath;

                    // If not installed yet, extract payload to run installer
                    if (!File.Exists(scriptPath)) {
                        string stagingDir = EnsureExtractedPayload();
                        scriptPath = Path.Combine(stagingDir, scriptName);
                        workDir = stagingDir;
                    }

                    // Format interactive PowerShell command that conducts execution and waits for any key press
                    string psCommand = string.Format(
                        "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; & '{0}' {1}; Write-Host ''; Write-Host 'Нажмите любую клавишу для продолжения...' -ForegroundColor Yellow; $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')",
                        scriptPath.Replace("'", "''"),
                        scriptArgs
                    );

                    ProcessStartInfo psi = new ProcessStartInfo();
                    psi.FileName = "powershell.exe";
                    psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command \"" + psCommand + "\"";
                    psi.WorkingDirectory = workDir;
                    psi.UseShellExecute = true;

                    using (Process proc = Process.Start(psi)) {
                        if (proc != null) {
                            proc.WaitForExit();
                        }
                    }

                    syncContext.Post(__ => UpdateServiceStatus(), null);
                } catch (Exception ex) {
                    MessageBox.Show("Ошибка запуска: " + ex.Message, "ProksiFi v2.0", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            });
        }

        // Silent background operations (start, stop, restart)
        private void RunSetupOperation(string scriptName, string scriptArgs, string operationTitle, Action<string> onCompleted = null) {
            if (isBusy) return;
            isBusy = true;
            SetMenuItemsEnabled(false);

            ThreadPool.QueueUserWorkItem(_ => {
                string accumulatedOutput = "";
                try {
                    string scriptPath = Path.Combine(InstallPath, scriptName);
                    string workDir = InstallPath;

                    // If not installed yet, extract payload
                    if (!File.Exists(scriptPath)) {
                        string stagingDir = EnsureExtractedPayload();
                        scriptPath = Path.Combine(stagingDir, scriptName);
                        workDir = stagingDir;
                    }

                    ProcessStartInfo psi = new ProcessStartInfo();
                    psi.FileName = "powershell.exe";
                    psi.Arguments = "-NoProfile -ExecutionPolicy Unrestricted -File \"" + scriptPath + "\" " + scriptArgs;
                    psi.WorkingDirectory = workDir;
                    psi.StandardOutputEncoding = System.Text.Encoding.UTF8;
                    psi.StandardErrorEncoding = System.Text.Encoding.UTF8;
                    psi.RedirectStandardOutput = true;
                    psi.RedirectStandardError = true;
                    psi.UseShellExecute = false;
                    psi.CreateNoWindow = true;

                    using (Process proc = new Process()) {
                        proc.StartInfo = psi;
                        proc.OutputDataReceived += (s, ev) => {
                            if (!string.IsNullOrEmpty(ev.Data)) {
                                accumulatedOutput += ev.Data + "\n";
                            }
                        };
                        proc.ErrorDataReceived += (s, ev) => {
                            if (!string.IsNullOrEmpty(ev.Data)) {
                                accumulatedOutput += ev.Data + "\n";
                            }
                        };

                        proc.Start();
                        proc.BeginOutputReadLine();
                        proc.BeginErrorReadLine();
                        proc.WaitForExit();
                    }
                } catch { }
                finally {
                    syncContext.Post(__ => {
                        isBusy = false;
                        SetMenuItemsEnabled(true);
                        UpdateServiceStatus();
                        if (onCompleted != null) {
                            onCompleted(accumulatedOutput);
                        }
                    }, null);
                }
            });
        }

        private void SetMenuItemsEnabled(bool enabled) {
            miInstall.Enabled = enabled;
            miEnable.Enabled = enabled;
            miDisable.Enabled = enabled;
            miTest.Enabled = enabled;
            miRestart.Enabled = enabled;
            miDiag.Enabled = enabled;
            miLogs.Enabled = enabled;
            miUninstall.Enabled = enabled;
        }

        private void ConfirmAndUninstall() {
            DialogResult dr = MessageBox.Show(
                "Вы уверены, что хотите полностью удалить ProksiFi v2.0 из системы?\n\n" +
                "• Служба ProksiFiService будет остановлена и удалена\n" +
                "• Сетевой адаптер WinTun будет отключен\n" +
                "• Рабочие файлы в Program Files и ProgramData будут удалены\n" +
                "• Настройки прокси браузеров будут сброшены\n\n" +
                "(Файл установщика ProksiFi_v2.0_Setup.exe удален НЕ будет).",
                "Подтверждение удаления ProksiFi",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Warning
            );

            if (dr == DialogResult.Yes) {
                int currentPid = Process.GetCurrentProcess().Id;
                RunSetupOperation("uninstall.ps1", "-FullClean -CallerPID " + currentPid, "Полное удаление службы и очистка системы...", (res) => {
                    try {
                        if (timerStatus != null) {
                            timerStatus.Stop();
                            timerStatus.Dispose();
                            timerStatus = null;
                        }
                        if (trayIcon != null) {
                            trayIcon.Visible = false;
                            trayIcon.Icon = null;
                            trayIcon.Dispose();
                            trayIcon = null;
                        }
                        Application.DoEvents();
                    } catch { }

                    MessageBox.Show(
                        "Служба и все компоненты ProksiFi v2.0 успешно удалены из системы.\n\nНастройки сети и браузеров восстановлены.",
                        "Удаление завершено",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Information
                    );
                    ExitApplication();
                });
            }
        }

        public void ShowTrayMenu() {
            try {
                trayIcon.ShowBalloonTip(2000, "ProksiFi v2.0", "Программа работает в системном трее.", ToolTipIcon.Info);
                MethodInfo mi = typeof(NotifyIcon).GetMethod("ShowContextMenu", BindingFlags.Instance | BindingFlags.NonPublic);
                if (mi != null) {
                    mi.Invoke(trayIcon, null);
                }
            } catch { }
        }

        private void ExitApplication() {
            try {
                if (timerStatus != null) {
                    timerStatus.Stop();
                    timerStatus.Dispose();
                    timerStatus = null;
                }
                if (trayIcon != null) {
                    trayIcon.Visible = false;
                    trayIcon.Icon = null;
                    trayIcon.Dispose();
                    trayIcon = null;
                }
                if (iconActive != null) { iconActive.Dispose(); iconActive = null; }
                if (iconStopped != null) { iconStopped.Dispose(); iconStopped = null; }
                if (iconChecking != null) { iconChecking.Dispose(); iconChecking = null; }
                Application.DoEvents();
            } catch { }
            ExitThread();
            Environment.Exit(0);
        }

        [STAThread]
        static void Main() {
            bool isNewInstance = false;
            using (Mutex mutex = new Mutex(true, AppMutexName, out isNewInstance)) {
                if (!isNewInstance) {
                    try {
                        using (var wakeEvent = EventWaitHandle.OpenExisting(AppWakeEventName)) {
                            wakeEvent.Set();
                        }
                    } catch {
                        MessageBox.Show(
                            "ProksiFi v2.0 уже запущен и работает в системном трее (рядом с часами).",
                            "ProksiFi v2.0",
                            MessageBoxButtons.OK,
                            MessageBoxIcon.Information
                        );
                    }
                    return;
                }

                using (EventWaitHandle wakeEvent = new EventWaitHandle(false, EventResetMode.AutoReset, AppWakeEventName)) {
                    Application.EnableVisualStyles();
                    Application.SetCompatibleTextRenderingDefault(false);

                    TrayAppContext context = new TrayAppContext();

                    Thread wakeListener = new Thread(() => {
                        while (true) {
                            try {
                                if (wakeEvent.WaitOne()) {
                                    context.syncContext.Post(__ => context.ShowTrayMenu(), null);
                                }
                            } catch {
                                break;
                            }
                        }
                    });
                    wakeListener.IsBackground = true;
                    wakeListener.Start();

                    Application.Run(context);
                }
            }
        }
    }

    // =========================================================================
    // NATIVE WINDOWS 11 FLUENT DARK RENDERER FOR TRAY CONTEXT MENU
    // =========================================================================
    public class Win11TrayMenuRenderer : ToolStripProfessionalRenderer {
        [DllImport("gdi32.dll")]
        private static extern IntPtr CreateRoundRectRgn(int x1, int y1, int x2, int y2, int cx, int cy);

        [DllImport("gdi32.dll")]
        private static extern bool DeleteObject(IntPtr hObject);

        // Native Windows 11 Fluent Dark Colors
        private static readonly Color BgColor = Color.FromArgb(32, 32, 32);             // Win11 Deep Dark #202020
        private static readonly Color HoverBgColor = Color.FromArgb(48, 48, 48);        // Win11 Subtle Dark Hover Pill #303030
        private static readonly Color PressedBgColor = Color.FromArgb(40, 40, 40);      // Win11 Active Pressed #282828
        private static readonly Color MenuBorderColor = Color.FromArgb(56, 56, 56);     // 1px Subtle Outline #383838
        private static readonly Color SeparatorColor = Color.FromArgb(46, 46, 46);      // Subtle Divider #2E2E2E
        private static readonly Color TextDisabledColor = Color.FromArgb(120, 120, 120);// Muted Disabled Gray

        private ToolStripItem statusItemRef;
        private ToolStripItem nodeItemRef;

        public Win11TrayMenuRenderer(ToolStripItem statusItem = null, ToolStripItem nodeItem = null) 
            : base(new Win11DarkColorTable()) {
            this.statusItemRef = statusItem;
            this.nodeItemRef = nodeItem;
        }

        protected override void OnRenderToolStripBackground(ToolStripRenderEventArgs e) {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;

            try {
                if (e.ToolStrip.IsHandleCreated && e.ToolStrip.Region == null) {
                    IntPtr rgn = CreateRoundRectRgn(0, 0, e.ToolStrip.Width + 1, e.ToolStrip.Height + 1, 8, 8);
                    if (rgn != IntPtr.Zero) {
                        e.ToolStrip.Region = Region.FromHrgn(rgn);
                        DeleteObject(rgn);
                    }
                }
            } catch { }

            using (SolidBrush bgBrush = new SolidBrush(BgColor)) {
                e.Graphics.FillRectangle(bgBrush, e.AffectedBounds);
            }
        }

        protected override void OnRenderToolStripBorder(ToolStripRenderEventArgs e) {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            using (Pen borderPen = new Pen(MenuBorderColor, 1f)) {
                DrawRoundedRect(e.Graphics, borderPen, new Rectangle(0, 0, e.ToolStrip.Width - 1, e.ToolStrip.Height - 1), 8);
            }
        }

        protected override void OnRenderMenuItemBackground(ToolStripItemRenderEventArgs e) {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;

            // 1. Always paint clean menu background first to avoid stale pixels
            Rectangle fullBounds = new Rectangle(0, 0, e.Item.Width, e.Item.Height);
            using (SolidBrush bgBrush = new SolidBrush(BgColor)) {
                e.Graphics.FillRectangle(bgBrush, fullBounds);
            }

            // 2. Informational header status items should not highlight as buttons
            if (e.Item == statusItemRef || e.Item == nodeItemRef) {
                return;
            }

            // 3. Render subtle rounded pill highlight for interactive items
            if (e.Item.Selected && e.Item.Enabled) {
                Rectangle pillRect = new Rectangle(4, 2, e.Item.Width - 8, e.Item.Height - 4);
                Color fill = e.Item.Pressed ? PressedBgColor : HoverBgColor;
                using (SolidBrush hoverBrush = new SolidBrush(fill)) {
                    FillRoundedRect(e.Graphics, hoverBrush, pillRect, 4);
                }
            }
        }

        protected override void OnRenderSeparator(ToolStripSeparatorRenderEventArgs e) {
            Rectangle rc = e.Item.ContentRectangle;
            int y = rc.Top + rc.Height / 2;
            using (Pen sepPen = new Pen(SeparatorColor, 1f)) {
                e.Graphics.DrawLine(sepPen, 12, y, e.Item.Width - 12, y);
            }
        }

        protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e) {
            Color textColor = e.Item.ForeColor;

            if (!e.Item.Enabled) {
                textColor = TextDisabledColor;
            }

            e.Graphics.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
            TextRenderer.DrawText(
                e.Graphics,
                e.Text,
                e.TextFont,
                e.TextRectangle,
                textColor,
                Color.Transparent,
                TextFormatFlags.Left | TextFormatFlags.VerticalCenter
            );
        }

        private static void FillRoundedRect(Graphics g, Brush brush, Rectangle bounds, int radius) {
            if (bounds.Width <= 0 || bounds.Height <= 0) return;
            using (GraphicsPath path = CreateRoundedPath(bounds, radius)) {
                g.FillPath(brush, path);
            }
        }

        private static void DrawRoundedRect(Graphics g, Pen pen, Rectangle bounds, int radius) {
            if (bounds.Width <= 0 || bounds.Height <= 0) return;
            using (GraphicsPath path = CreateRoundedPath(bounds, radius)) {
                g.DrawPath(pen, path);
            }
        }

        private static GraphicsPath CreateRoundedPath(Rectangle bounds, int radius) {
            int d = radius * 2;
            Rectangle arc = new Rectangle(bounds.Location, new Size(d, d));
            GraphicsPath path = new GraphicsPath();

            if (radius <= 0) {
                path.AddRectangle(bounds);
                return path;
            }

            path.AddArc(arc, 180, 90);
            arc.X = bounds.Right - d;
            path.AddArc(arc, 270, 90);
            arc.Y = bounds.Bottom - d;
            path.AddArc(arc, 0, 90);
            arc.X = bounds.Left;
            path.AddArc(arc, 90, 90);
            path.CloseFigure();
            return path;
        }
    }

    public class Win11DarkColorTable : ProfessionalColorTable {
        public override Color MenuBorder { get { return Color.FromArgb(56, 56, 56); } }
        public override Color MenuItemBorder { get { return Color.Transparent; } }
        public override Color MenuItemSelected { get { return Color.FromArgb(48, 48, 48); } }
        public override Color ToolStripDropDownBackground { get { return Color.FromArgb(32, 32, 32); } }
        public override Color ImageMarginGradientBegin { get { return Color.FromArgb(32, 32, 32); } }
        public override Color ImageMarginGradientMiddle { get { return Color.FromArgb(32, 32, 32); } }
        public override Color ImageMarginGradientEnd { get { return Color.FromArgb(32, 32, 32); } }
        public override Color SeparatorDark { get { return Color.FromArgb(46, 46, 46); } }
        public override Color SeparatorLight { get { return Color.Transparent; } }
    }
}
