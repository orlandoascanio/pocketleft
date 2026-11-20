using Microsoft.Win32;

namespace Pocket.Windows;

internal sealed class TrayApplication : ApplicationContext
{
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string RunValue = "PocketLeft";
    private readonly Icon icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath) ?? (Icon)SystemIcons.Application.Clone();
    private readonly ContextMenuStrip menu = new();
    private readonly NotifyIcon tray;
    private readonly PocketWindow window;
    private readonly RegisteredWaitHandle instanceRequests;

    public TrayApplication(EventWaitHandle showRequest, bool background)
    {
        window = new PocketWindow(icon);
        menu.Items.Add("Quick entry", null, (_, _) => window.Open(PocketView.Quick));
        menu.Items.Add("Open Pocket", null, (_, _) => window.Open(PocketView.Full));
        menu.Items.Add(new ToolStripSeparator());
        var launch = new ToolStripMenuItem("Start at sign-in");
        launch.Click += (_, _) => ToggleStartup(launch);
        menu.Opening += (_, _) => UpdateStartupMenu(launch);
        menu.Items.Add(launch);
        menu.Items.Add("Quit Pocket", null, (_, _) => ExitThread());

        tray = new NotifyIcon { Icon = icon, Text = "Pocket", ContextMenuStrip = menu, Visible = true };
        tray.MouseClick += (_, e) =>
        {
            if (e.Button == MouseButtons.Left) window.Open(PocketView.Quick);
        };

        _ = window.Handle;
        instanceRequests = ThreadPool.RegisterWaitForSingleObject(showRequest, (_, _) =>
        {
            try { window.BeginInvoke(() => window.Open(PocketView.Quick)); }
            catch (InvalidOperationException) { /* The window is shutting down. */ }
        }, null, Timeout.Infinite, executeOnlyOnce: false);

        if (!background) window.Open(PocketView.Quick);
    }

    private static string StartupCommand => $"\"{Environment.ProcessPath}\" --background";

    private static void UpdateStartupMenu(ToolStripMenuItem item)
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKey);
            item.Checked = string.Equals(key?.GetValue(RunValue) as string, StartupCommand, StringComparison.OrdinalIgnoreCase);
        }
        catch (Exception error) when (error is UnauthorizedAccessException or IOException or System.Security.SecurityException)
        {
            item.Enabled = false;
        }
    }

    private void ToggleStartup(ToolStripMenuItem item)
    {
        try
        {
            using var key = Registry.CurrentUser.CreateSubKey(RunKey);
            if (item.Checked) key.DeleteValue(RunValue, throwOnMissingValue: false);
            else key.SetValue(RunValue, StartupCommand);
            item.Checked = !item.Checked;
        }
        catch (Exception error) when (error is UnauthorizedAccessException or IOException or System.Security.SecurityException)
        {
            MessageBox.Show(window, "Windows could not change the sign-in setting.", "Pocket", MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            instanceRequests.Unregister(null);
            tray.Dispose();
            menu.Dispose();
            window.Dispose();
            icon.Dispose();
        }
        base.Dispose(disposing);
    }
}
