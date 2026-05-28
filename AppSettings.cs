using System;
using System.IO;
using System.Text.Json;

namespace WrapTune;

public sealed class AppSettings
{
    public string? ExePath { get; set; }
    public string? SourceFolder { get; set; }
    public string? OutputFolder { get; set; }

    /// <summary>"Daylight" (default) or "Midnight".</summary>
    public string Theme { get; set; } = "Daylight";

    /// <summary>Persist the Overwrite checkbox state across runs.</summary>
    public bool Overwrite { get; set; } = true;

    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    // Per-user settings under %LOCALAPPDATA%\WrapTune\settings.json.
    // This lets WrapTune run as a normal (non-admin) user even when the app
    // itself is installed per-machine under Program Files. Each Windows user
    // gets their own settings, which matches every other Windows convention
    // (VS Code, Office, etc.).
    public static string GetSettingsPath()
    {
        var dir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "WrapTune");
        return Path.Combine(dir, "settings.json");
    }

    public static AppSettings Load()
    {
        var path = GetSettingsPath();
        if (!File.Exists(path)) return new AppSettings();
        try
        {
            var json = File.ReadAllText(path);
            return JsonSerializer.Deserialize<AppSettings>(json) ?? new AppSettings();
        }
        catch
        {
            return new AppSettings();
        }
    }

    public void Save()
    {
        var path = GetSettingsPath();
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            var json = JsonSerializer.Serialize(this, JsonOptions);
            File.WriteAllText(path, json);
        }
        catch
        {
            // Settings persistence is best-effort. If AppData is locked,
            // the disk is full, or some AV intercepts the write, swallow
            // the error so the app doesn't crash on exit. Worst case the
            // user re-picks their paths next launch.
        }
    }
}
