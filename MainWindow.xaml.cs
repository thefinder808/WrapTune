using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using Microsoft.Win32;
using Forms = System.Windows.Forms;

namespace WrapTune;

public partial class MainWindow : Window
{
    private Process? _runningProcess;

    [DllImport("dwmapi.dll", PreserveSig = true)]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);

    public MainWindow()
    {
        InitializeComponent();
        SourceInitialized += (_, _) => ApplyDarkTitleBar();
        LoadSettings();
    }

    private void ApplyDarkTitleBar()
    {
        var hwnd = new WindowInteropHelper(this).Handle;
        if (hwnd == IntPtr.Zero) return;
        int value = 1;
        // DWMWA_USE_IMMERSIVE_DARK_MODE = 20 (Win10 20H1+ / Win11)
        if (DwmSetWindowAttribute(hwnd, 20, ref value, sizeof(int)) != 0)
        {
            // Fallback for older Win10 builds (attribute 19)
            DwmSetWindowAttribute(hwnd, 19, ref value, sizeof(int));
        }
    }

    // ── Settings & exe detection ───────────────────────────────────────────

    private void LoadSettings()
    {
        var settings = AppSettings.Load();
        var detected = FindIntuneWinAppUtil();

        if (detected != null)
            TxtExePath.Text = detected;

        if (!string.IsNullOrEmpty(settings.ExePath) && File.Exists(settings.ExePath))
            TxtExePath.Text = settings.ExePath;

        if (!string.IsNullOrEmpty(settings.SourceFolder))
            TxtSourceFolder.Text = settings.SourceFolder;

        if (!string.IsNullOrEmpty(settings.OutputFolder))
            TxtOutputFolder.Text = settings.OutputFolder;
    }

    private static string? FindIntuneWinAppUtil()
    {
        // 1. App directory
        var appDir = Path.GetDirectoryName(Environment.ProcessPath) ?? AppContext.BaseDirectory;
        var local = Path.Combine(appDir, "IntuneWinAppUtil.exe");
        if (File.Exists(local)) return local;

        // 2. PATH
        var pathDirs = Environment.GetEnvironmentVariable("PATH")?.Split(';') ?? [];
        foreach (var dir in pathDirs)
        {
            if (string.IsNullOrWhiteSpace(dir)) continue;
            var candidate = Path.Combine(dir.Trim(), "IntuneWinAppUtil.exe");
            if (File.Exists(candidate)) return candidate;
        }

        // 3. Saved setting
        var settings = AppSettings.Load();
        if (!string.IsNullOrEmpty(settings.ExePath) && File.Exists(settings.ExePath))
            return settings.ExePath;

        return null;
    }

    private void SaveCurrentSettings()
    {
        new AppSettings
        {
            ExePath = TxtExePath.Text,
            SourceFolder = TxtSourceFolder.Text,
            OutputFolder = TxtOutputFolder.Text
        }.Save();
    }

    // ── Browse handlers ────────────────────────────────────────────────────

    private void BtnBrowseExe_Click(object sender, RoutedEventArgs e)
    {
        var dlg = new OpenFileDialog
        {
            Title = "Select IntuneWinAppUtil.exe",
            Filter = "IntuneWinAppUtil|IntuneWinAppUtil.exe|All files|*.*"
        };
        if (dlg.ShowDialog() == true)
            TxtExePath.Text = dlg.FileName;
    }

    private void BtnBrowseSource_Click(object sender, RoutedEventArgs e)
    {
        var path = BrowseFolder("Select the source folder containing your setup files", TxtSourceFolder.Text);
        if (path != null)
        {
            TxtSourceFolder.Text = path;
            AutoPopulateSetupFile(path);
        }
    }

    private void BtnBrowseSetup_Click(object sender, RoutedEventArgs e)
    {
        var initDir = Directory.Exists(TxtSourceFolder.Text) ? TxtSourceFolder.Text : null;
        var dlg = new OpenFileDialog
        {
            Title = "Select the setup file",
            Filter = "Installers (*.exe;*.msi)|*.exe;*.msi|All files|*.*"
        };
        if (initDir != null) dlg.InitialDirectory = initDir;
        if (dlg.ShowDialog() == true)
            TxtSetupFile.Text = dlg.FileName;
    }

    private void BtnBrowseOutput_Click(object sender, RoutedEventArgs e)
    {
        var path = BrowseFolder("Select the output folder for the .intunewin file", TxtOutputFolder.Text);
        if (path != null)
            TxtOutputFolder.Text = path;
    }

    private void BtnBrowseCatalog_Click(object sender, RoutedEventArgs e)
    {
        var path = BrowseFolder("Select the catalog folder (optional, for Win10 S mode)", TxtCatalogFolder.Text);
        if (path != null)
            TxtCatalogFolder.Text = path;
    }

    private static string? BrowseFolder(string description, string? initialDir)
    {
        using var dlg = new Forms.FolderBrowserDialog { Description = description };
        if (!string.IsNullOrEmpty(initialDir) && Directory.Exists(initialDir))
            dlg.SelectedPath = initialDir;
        return dlg.ShowDialog() == Forms.DialogResult.OK ? dlg.SelectedPath : null;
    }

    private void AutoPopulateSetupFile(string folderPath)
    {
        if (!Directory.Exists(folderPath)) return;
        var installers = Directory.GetFiles(folderPath)
            .Where(f =>
            {
                var ext = Path.GetExtension(f);
                return ext.Equals(".exe", StringComparison.OrdinalIgnoreCase)
                    || ext.Equals(".msi", StringComparison.OrdinalIgnoreCase);
            })
            .ToArray();

        TxtSetupFile.Text = installers.Length == 1 ? installers[0] : string.Empty;
    }

    // ── Open Output Folder ─────────────────────────────────────────────────

    private void BtnOpenOutput_Click(object sender, RoutedEventArgs e)
    {
        if (Directory.Exists(TxtOutputFolder.Text))
            Process.Start("explorer.exe", $"\"{TxtOutputFolder.Text}\"");
    }

    // ── Drag-and-drop handlers ─────────────────────────────────────────────

    private void FolderDrag_PreviewDragOver(object sender, DragEventArgs e)
    {
        e.Handled = true;
        e.Effects = GetSingleDropPath(e, foldersOnly: true) != null
            ? DragDropEffects.Link
            : DragDropEffects.None;
    }

    private void FileDrag_PreviewDragOver(object sender, DragEventArgs e)
    {
        e.Handled = true;
        e.Effects = GetSingleDropPath(e, foldersOnly: false) != null
            ? DragDropEffects.Link
            : DragDropEffects.None;
    }

    private void FolderDrop_Drop(object sender, DragEventArgs e)
    {
        var path = GetSingleDropPath(e, foldersOnly: true);
        if (path != null && sender is System.Windows.Controls.TextBox tb)
            tb.Text = path;
    }

    private void SourceFolderDrop_Drop(object sender, DragEventArgs e)
    {
        var path = GetSingleDropPath(e, foldersOnly: true);
        if (path != null)
        {
            TxtSourceFolder.Text = path;
            AutoPopulateSetupFile(path);
        }
    }

    private void FileDrop_Drop(object sender, DragEventArgs e)
    {
        var path = GetSingleDropPath(e, foldersOnly: false);
        if (path != null && sender is System.Windows.Controls.TextBox tb)
            tb.Text = path;
    }

    private static string? GetSingleDropPath(DragEventArgs e, bool foldersOnly)
    {
        if (!e.Data.GetDataPresent(DataFormats.FileDrop)) return null;
        var files = e.Data.GetData(DataFormats.FileDrop) as string[];
        if (files is not { Length: 1 }) return null;
        var path = files[0];
        var isDir = Directory.Exists(path);
        if (foldersOnly && !isDir) return null;
        if (!foldersOnly && isDir) return null;
        return path;
    }

    // ── Validation ─────────────────────────────────────────────────────────

    private string? ValidateInputs()
    {
        if (string.IsNullOrWhiteSpace(TxtExePath.Text) || !File.Exists(TxtExePath.Text))
            return "IntuneWinAppUtil.exe path is missing or invalid.";
        if (string.IsNullOrWhiteSpace(TxtSourceFolder.Text) || !Directory.Exists(TxtSourceFolder.Text))
            return "Source folder is missing or does not exist.";
        if (string.IsNullOrWhiteSpace(TxtSetupFile.Text) || !File.Exists(TxtSetupFile.Text))
            return "Setup file is missing or does not exist.";
        if (string.IsNullOrWhiteSpace(TxtOutputFolder.Text))
            return "Output folder is not specified.";
        if (!string.IsNullOrWhiteSpace(TxtCatalogFolder.Text) && !Directory.Exists(TxtCatalogFolder.Text))
            return "Catalog folder specified but does not exist.";
        return null;
    }

    // ── Package button ─────────────────────────────────────────────────────

    private void BtnPackage_Click(object sender, RoutedEventArgs e)
    {
        var error = ValidateInputs();
        if (error != null)
        {
            MessageBox.Show(error, "Validation Error", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        SaveCurrentSettings();

        if (!Directory.Exists(TxtOutputFolder.Text))
            Directory.CreateDirectory(TxtOutputFolder.Text);

        // Build arguments
        var args = $"-c \"{TxtSourceFolder.Text}\" -s \"{TxtSetupFile.Text}\" -o \"{TxtOutputFolder.Text}\"";
        if (!string.IsNullOrWhiteSpace(TxtCatalogFolder.Text))
            args += $" -a \"{TxtCatalogFolder.Text}\"";
        if (ChkOverwrite.IsChecked == true)
            args += " -q";

        // Reset UI
        TxtOutput.Text = string.Empty;
        BtnOpenOutput.Visibility = Visibility.Collapsed;
        BtnPackage.IsEnabled = false;
        TxtStatus.Text = "Packaging...";
        TxtStatus.Foreground = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#2d8b8b"));

        AppendOutput($"Executing: IntuneWinAppUtil.exe {args}");
        AppendOutput(new string('-', 60));

        // Launch process
        var psi = new ProcessStartInfo
        {
            FileName = TxtExePath.Text,
            Arguments = args,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };

        var process = new Process { StartInfo = psi, EnableRaisingEvents = true };
        _runningProcess = process;

        process.OutputDataReceived += (_, dataArgs) =>
        {
            if (dataArgs.Data != null)
                Dispatcher.InvokeAsync(() => AppendOutput(dataArgs.Data));
        };

        process.ErrorDataReceived += (_, dataArgs) =>
        {
            if (dataArgs.Data != null)
                Dispatcher.InvokeAsync(() => AppendOutput($"ERROR  {dataArgs.Data}"));
        };

        process.Exited += (_, _) =>
        {
            var exitCode = process.ExitCode;
            Dispatcher.InvokeAsync(() =>
            {
                AppendOutput(new string('-', 60));
                if (exitCode == 0)
                {
                    AppendOutput("Package created successfully!");
                    TxtStatus.Text = "Done \u2014 .intunewin file created.";
                    TxtStatus.Foreground = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#52c7a0"));
                    BtnOpenOutput.Visibility = Visibility.Visible;
                }
                else
                {
                    AppendOutput($"Process exited with code: {exitCode}");
                    TxtStatus.Text = $"Failed \u2014 exit code {exitCode}";
                    TxtStatus.Foreground = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#e06c60"));
                }
                BtnPackage.IsEnabled = true;
            });
            _runningProcess = null;
            process.Dispose();
        };

        try
        {
            process.Start();
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();
        }
        catch (Exception ex)
        {
            AppendOutput($"Failed to start process: {ex.Message}");
            TxtStatus.Text = "Failed to launch IntuneWinAppUtil.exe";
            TxtStatus.Foreground = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#e06c60"));
            BtnPackage.IsEnabled = true;
            _runningProcess = null;
            process.Dispose();
        }
    }

    // ── Output helper ──────────────────────────────────────────────────────

    private void AppendOutput(string text)
    {
        TxtOutput.AppendText(text + Environment.NewLine);
        TxtOutput.ScrollToEnd();
    }

    // ── Cleanup on close ───────────────────────────────────────────────────

    protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
    {
        if (_runningProcess is { HasExited: false } proc)
        {
            try { proc.Kill(); } catch { }
            proc.Dispose();
            _runningProcess = null;
        }
        base.OnClosing(e);
    }
}
