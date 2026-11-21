using Microsoft.Win32;

namespace Pocket.Windows;

internal sealed class TrayApplication : ApplicationContext
{
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string RunValue = "PocketLeft";
    private const string PreferencesKey = @"Software\PocketLeft";
    private const string BalanceModeValue = "BalanceDisplay";
    private const int RefreshIntervalMs = 60_000;
    private enum BalanceDisplay { Hover, Panel }

    private readonly Icon icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath) ?? (Icon)SystemIcons.Application.Clone();
    private readonly ContextMenuStrip menu = new();
    private readonly NotifyIcon tray;
    private readonly PocketWindow window;
    private readonly ClockBalanceWindow clockWindow;
    private readonly Dictionary<BalanceDisplay, ToolStripMenuItem> displayItems = new();
    private readonly System.Windows.Forms.Timer clockTimer = new();
    private readonly RegisteredWaitHandle instanceRequests;
    private ClockBalance? clockBalance;
    private BalanceDisplay balanceDisplay;
    private long nextRefresh;

    public TrayApplication(EventWaitHandle showRequest, bool background)
    {
        window = new PocketWindow(icon);
        clockWindow = new ClockBalanceWindow(icon, () => window.Open(PocketView.Quick));
        balanceDisplay = ReadBalanceDisplay();
        menu.Items.Add("Quick entry", null, (_, _) => window.Open(PocketView.Quick));
        menu.Items.Add("Open Pocket", null, (_, _) => window.Open(PocketView.Full));
        menu.Items.Add(new ToolStripSeparator());
        var displayMenu = new ToolStripMenuItem("Balance display");
        AddMode(BalanceDisplay.Hover, "Balance on hover");
        AddMode(BalanceDisplay.Panel, "Floating panel");
        menu.Items.Add(displayMenu);
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
        tray.BalloonTipClicked += (_, _) => window.Open(PocketView.Full);
        window.ReminderRequested += (title, body) => tray.ShowBalloonTip(5_000, title, body, ToolTipIcon.None);
        window.QuitRequested += ExitThread;
        window.BalanceChanged += balance =>
        {
            clockBalance = balance;
            UpdateBalanceDisplay();
        };
        clockTimer.Tick += (_, _) =>
        {
            if (balanceDisplay == BalanceDisplay.Panel) clockWindow.UpdatePosition();
            if (Environment.TickCount64 < nextRefresh) return;
            nextRefresh = Environment.TickCount64 + RefreshIntervalMs;
            window.RefreshHiddenBalance();
        };

        _ = window.Handle;
        instanceRequests = ThreadPool.RegisterWaitForSingleObject(showRequest, (_, _) =>
        {
            try { window.BeginInvoke(() => window.Open(PocketView.Quick)); }
            catch (InvalidOperationException) { /* The window is shutting down. */ }
        }, null, Timeout.Infinite, executeOnlyOnce: false);

        if (!background) window.Open(PocketView.Quick);
        window.BeginInvoke(ApplyBalanceDisplay);

        void AddMode(BalanceDisplay mode, string name)
        {
            var item = new ToolStripMenuItem(name) { Checked = balanceDisplay == mode };
            item.Click += (_, _) => SetBalanceDisplay(mode);
            displayItems.Add(mode, item);
            displayMenu.DropDownItems.Add(item);
        }
    }

    private static BalanceDisplay ReadBalanceDisplay()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(PreferencesKey);
            return key?.GetValue(BalanceModeValue) switch
            {
                "Panel" => BalanceDisplay.Panel,
                "Hover" or "TrayNumber" or "IconOnly" => BalanceDisplay.Hover,
                _ => key?.GetValue("ShowClockBalance") is 0 ? BalanceDisplay.Hover : BalanceDisplay.Panel
            };
        }
        catch (Exception error) when (error is UnauthorizedAccessException or IOException or System.Security.SecurityException)
        {
            return BalanceDisplay.Panel;
        }
    }

    private void ApplyBalanceDisplay()
    {
        UpdateBalanceDisplay();
        clockTimer.Stop();
        clockTimer.Interval = balanceDisplay == BalanceDisplay.Panel ? 2_000 : RefreshIntervalMs;
        window.StartBrowser();
        window.RefreshHiddenBalance();
        nextRefresh = Environment.TickCount64 + RefreshIntervalMs;
        clockTimer.Start();
    }

    private void SetBalanceDisplay(BalanceDisplay mode)
    {
        if (mode == balanceDisplay) return;
        try
        {
            using var key = Registry.CurrentUser.CreateSubKey(PreferencesKey);
            key.SetValue(BalanceModeValue, mode.ToString());
        }
        catch (Exception error) when (error is UnauthorizedAccessException or IOException or System.Security.SecurityException)
        {
            MessageBox.Show(window, "Windows could not save the balance display setting.", "Pocket",
                MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        displayItems[balanceDisplay].Checked = false;
        balanceDisplay = mode;
        displayItems[mode].Checked = true;
        ApplyBalanceDisplay();
    }

    private void UpdateBalanceDisplay()
    {
        var balance = clockBalance;
        string tooltip = balance is null ? "Pocket"
            : balance.Stale ? $"Pocket · {balance.Amount} · Last known" : $"Pocket · {balance.Amount}";
        if (tray.Text != tooltip) tray.Text = tooltip;

        clockWindow.ShowBalance(balanceDisplay == BalanceDisplay.Panel ? balance : null);
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
