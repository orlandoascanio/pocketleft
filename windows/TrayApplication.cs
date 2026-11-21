using Microsoft.Win32;

namespace Pocket.Windows;

internal sealed class TrayApplication : ApplicationContext
{
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string RunValue = "PocketLeft";
    private const string PreferencesKey = @"Software\PocketLeft";
    private const string ClockBalanceValue = "ShowClockBalance";
    private const int RefreshIntervalMs = 60_000;
    private readonly Icon icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath) ?? (Icon)SystemIcons.Application.Clone();
    private readonly ContextMenuStrip menu = new();
    private readonly NotifyIcon tray;
    private readonly PocketWindow window;
    private readonly ClockBalanceWindow clockWindow;
    private readonly ToolStripMenuItem clockMenuItem = new("Show balance above clock");
    private readonly System.Windows.Forms.Timer clockTimer = new() { Interval = 2_000 };
    private readonly RegisteredWaitHandle instanceRequests;
    private ClockBalance? clockBalance;
    private long nextRefresh;

    public TrayApplication(EventWaitHandle showRequest, bool background)
    {
        window = new PocketWindow(icon);
        clockWindow = new ClockBalanceWindow(icon, () => window.Open(PocketView.Quick));
        clockMenuItem.Checked = ReadClockPreference();
        clockMenuItem.Click += (_, _) => ToggleClock();
        window.BalanceChanged += balance =>
        {
            clockBalance = balance;
            if (clockMenuItem.Checked) clockWindow.ShowBalance(balance);
        };
        clockTimer.Tick += (_, _) =>
        {
            clockWindow.UpdatePosition();
            if (Environment.TickCount64 < nextRefresh) return;
            nextRefresh = Environment.TickCount64 + RefreshIntervalMs;
            window.RefreshHiddenBalance();
        };
        menu.Items.Add("Quick entry", null, (_, _) => window.Open(PocketView.Quick));
        menu.Items.Add("Open Pocket", null, (_, _) => window.Open(PocketView.Full));
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(clockMenuItem);
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
        if (clockMenuItem.Checked) window.BeginInvoke(ShowClock);
    }

    private static bool ReadClockPreference()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(PreferencesKey);
            return key?.GetValue(ClockBalanceValue) is not 0;
        }
        catch (Exception error) when (error is UnauthorizedAccessException or IOException or System.Security.SecurityException)
        {
            return true;
        }
    }

    private void ShowClock()
    {
        clockWindow.ShowBalance(clockBalance);
        window.StartBrowser();
        window.RefreshHiddenBalance();
        nextRefresh = Environment.TickCount64 + RefreshIntervalMs;
        clockTimer.Start();
    }

    private void ToggleClock()
    {
        bool show = !clockMenuItem.Checked;
        try
        {
            using var key = Registry.CurrentUser.CreateSubKey(PreferencesKey);
            key.SetValue(ClockBalanceValue, show ? 1 : 0);
        }
        catch (Exception error) when (error is UnauthorizedAccessException or IOException or System.Security.SecurityException)
        {
            MessageBox.Show(window, "Windows could not save the balance display setting.", "Pocket",
                MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        clockMenuItem.Checked = show;
        if (show) ShowClock();
        else
        {
            clockTimer.Stop();
            clockWindow.ShowBalance(null);
        }
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
            clockTimer.Dispose();
            tray.Dispose();
            window.Dispose();
            clockWindow.Dispose();
            menu.Dispose();
            icon.Dispose();
        }
        base.Dispose(disposing);
    }
}
