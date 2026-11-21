using System.Diagnostics;
using System.Text.Json;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

namespace Pocket.Windows;

internal enum PocketView { Quick, Full }

internal sealed class PocketWindow : Form
{
    private const string ClientHost = "pocketleft.example";
    private const string ClientUrl = "https://" + ClientHost + "/index.html";
    private const string WebViewDownload = "https://developer.microsoft.com/microsoft-edge/webview2/";
    private const string SelfHostingGuide = "https://github.com/orlandoascanio/pocket/blob/main/SELF-HOSTING.md";
    private readonly string clientDirectory = Path.Combine(AppContext.BaseDirectory, "Client");
    private readonly string profileDirectory = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PocketLeft", "WebView2");

    private readonly WebView2 browser = new() { Dock = DockStyle.Fill, Visible = false };
    private readonly Label status = new() { AutoSize = true, Text = "Opening Pocket…" };
    private readonly FlowLayoutPanel loading = new()
    {
        Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false,
        Padding = new Padding(18)
    };
    private PocketView mode;
    private bool initializing;
    private bool pageReady;
    private Rectangle? fullBounds;

    public event Action<ClockBalance?>? BalanceChanged;
    public event Action<string, string>? ReminderRequested;
    public event Action? QuitRequested;

    public PocketWindow(Icon icon)
    {
        Text = "Pocket";
        Icon = icon;
        AutoScaleMode = AutoScaleMode.Dpi;
        StartPosition = FormStartPosition.Manual;
        ShowInTaskbar = false;
        MinimizeBox = false;
        MaximizeBox = false;
        KeyPreview = true;
        Font = SystemFonts.MessageBoxFont ?? Font;
        loading.Controls.Add(status);
        Controls.Add(browser);
        Controls.Add(loading);
    }

    public void Open(PocketView view)
    {
        bool wasVisible = Visible;
        if (wasVisible && mode == PocketView.Full && view == PocketView.Quick) RememberFullBounds();
        bool reposition = !wasVisible || view != mode;
        Point anchor = Cursor.Position;
        int previousDpi = DeviceDpi;
        if (reposition) Place(view, anchor);
        mode = view;
        if (!wasVisible) Show();
        if (reposition && previousDpi != DeviceDpi) Place(view, anchor);
        Activate();
        if (pageReady)
        {
            SendMode();
            browser.Focus();
        }
        else StartBrowser();
    }

    public void StartBrowser()
    {
        if (browser.CoreWebView2 is null && !initializing) _ = InitializeBrowserAsync();
    }

    public void RefreshHiddenBalance()
    {
        var core = browser.CoreWebView2;
        if (!Visible && pageReady && core is not null && IsClient(core.Source))
            core.PostWebMessageAsJson("\"refresh-balance\"");
    }

    private void Place(PocketView view, Point anchor)
    {
        Rectangle area = Screen.FromPoint(anchor).WorkingArea;
        int gap = LogicalToDeviceUnits(10);
        if (view == PocketView.Full && fullBounds is { } previous)
        {
            // Keep the user's window position as long as its monitor is still available.
            Rectangle previousArea = Screen.FromRectangle(previous).WorkingArea;
            if (previousArea.Contains(previous))
            {
                Bounds = previous;
                return;
            }
        }

        int width = Math.Min(LogicalToDeviceUnits(view == PocketView.Quick ? 420 : 1050), area.Width - 2 * gap);
        int height = Math.Min(LogicalToDeviceUnits(view == PocketView.Quick ? 570 : 800), area.Height - 2 * gap);
        int x = view == PocketView.Quick ? anchor.X - width + gap : area.Left + (area.Width - width) / 2;
        int y = view == PocketView.Quick
            ? (anchor.Y < area.Top + area.Height / 2 ? anchor.Y + gap : anchor.Y - height - gap)
            : area.Top + (area.Height - height) / 2;
        Bounds = new Rectangle(
            Math.Clamp(x, area.Left + gap, area.Right - width - gap),
            Math.Clamp(y, area.Top + gap, area.Bottom - height - gap), width, height);
    }

    private void RememberFullBounds()
    {
        if (mode == PocketView.Full) fullBounds = Bounds;
    }

    private void HideToTray()
    {
        RememberFullBounds();
        Hide();
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        base.OnFormClosing(e);
        if (e.CloseReason == CloseReason.UserClosing)
        {
            e.Cancel = true;
            HideToTray();
        }
    }

    protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
    {
        if (keyData != Keys.Escape || browser.ContainsFocus) return base.ProcessCmdKey(ref msg, keyData);
        HideToTray();
        return true;
    }

    private async Task InitializeBrowserAsync()
    {
        initializing = true;
        try
        {
            var environment = await CoreWebView2Environment.CreateAsync(userDataFolder: profileDirectory);
            if (IsDisposed) return;
            _ = browser.Handle;
            await browser.EnsureCoreWebView2Async(environment);
            if (IsDisposed) return;
            var core = browser.CoreWebView2;
            core.Settings.AreHostObjectsAllowed = false;
            core.Settings.AreDevToolsEnabled = false;
            core.Settings.IsStatusBarEnabled = false;
            core.SetVirtualHostNameToFolderMapping(ClientHost, clientDirectory, CoreWebView2HostResourceAccessKind.Deny);
            core.NavigationStarting += (_, e) =>
            {
                if (IsClient(e.Uri))
                {
                    pageReady = false;
                    BalanceChanged?.Invoke(null);
                    browser.Hide();
                    status.Text = "Opening Pocket…";
                    loading.Show();
                    return;
                }
                e.Cancel = true;
                if (e.IsUserInitiated && e.Uri == SelfHostingGuide) OpenLink(SelfHostingGuide);
            };
            core.NewWindowRequested += (_, e) =>
            {
                e.Handled = true;
                if (e.IsUserInitiated && e.Uri == SelfHostingGuide) OpenLink(SelfHostingGuide);
            };
            core.WebMessageReceived += OnWebMessage;
            core.NavigationCompleted += (_, e) =>
            {
                if (!e.IsSuccess && e.WebErrorStatus != CoreWebView2WebErrorStatus.OperationCanceled)
                    ShowError("Pocket could not open its app files.", () => core.Navigate(ClientUrl));
            };
            string script = await File.ReadAllTextAsync(Path.Combine(clientDirectory, "windows.js"));
            if (IsDisposed) return;
            await core.AddScriptToExecuteOnDocumentCreatedAsync(script);
            if (!IsDisposed) core.Navigate(ClientUrl);
        }
        catch (WebView2RuntimeNotFoundException)
        {
            if (!IsDisposed) ShowError("Pocket needs the Microsoft Edge WebView2 Runtime.", null, WebViewDownload);
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or InvalidOperationException
            or System.Runtime.InteropServices.COMException)
        {
            if (!IsDisposed) ShowError("Pocket could not open. Quit Pocket from the tray and try again, or reinstall using Pocket Setup.");
        }
        finally { initializing = false; }
    }

    private void OnWebMessage(object? sender, CoreWebView2WebMessageReceivedEventArgs e)
    {
        if (!IsClient(e.Source)) return;
        string message = e.WebMessageAsJson;
        switch (message)
        {
            case "\"client-error\"":
                ShowError("Pocket could not open its app files. Reinstall using Pocket Setup.");
                break;
            case "\"ready\"":
                pageReady = true;
                SendMode();
                break;
            case "\"view-ready\"":
                loading.Hide();
                browser.Show();
                if (Visible) browser.Focus();
                break;
            case "\"open-pocket\"":
                Open(PocketView.Full);
                break;
            case "\"hide\"":
                HideToTray();
                break;
            case "\"check-updates\"":
                _ = WindowsUpdates.CheckAsync(this, () => QuitRequested?.Invoke());
                break;
            case "\"about-pocket\"":
                MessageBox.Show(this, $"Pocket for Windows {WindowsUpdates.VersionLabel}", "About Pocket");
                break;
            case "\"open-data-folder\"":
                OpenLink(profileDirectory);
                break;
            case "\"share-pocket\"":
                try { Clipboard.SetText("https://pocketleft.app/"); }
                catch (System.Runtime.InteropServices.ExternalException)
                {
                    MessageBox.Show(this, "Windows could not copy the Pocket link.", "Pocket");
                }
                break;
            default:
                ReadBalance(message);
                break;
        }
    }

    private void ReadBalance(string message)
    {
        if (message.Length is 0 or > 1_024 || message[0] != '{') return;
        using var json = JsonDocument.Parse(message);
        JsonElement data = json.RootElement;
        if (!data.TryGetProperty("type", out var type) || type.ValueKind != JsonValueKind.String) return;
        if (type.ValueEquals("pocket-reminder"))
        {
            string? title = ReadText("title", 150);
            string? body = ReadText("body", 180);
            if (title is not null && body is not null) ReminderRequested?.Invoke(title, body);
            return;
        }
        if (!type.ValueEquals("clock-balance") || !data.TryGetProperty("amount", out var amount)) return;
        if (amount.ValueKind == JsonValueKind.Null)
        {
            BalanceChanged?.Invoke(null);
            return;
        }
        if (amount.ValueKind != JsonValueKind.String || amount.GetString() is not { Length: > 0 and <= 48 } display
            || display.Any(char.IsControl)) return;
        bool stale = data.TryGetProperty("stale", out var flag) && flag.ValueKind == JsonValueKind.True;
        BalanceChanged?.Invoke(new ClockBalance(display, stale));

        string? ReadText(string property, int maxLength) =>
            data.TryGetProperty(property, out var field) && field.ValueKind == JsonValueKind.String &&
            field.GetString() is { Length: > 0 } value && value.Length <= maxLength && !value.Any(char.IsControl) ? value : null;
    }

    private void SendMode()
    {
        var core = browser.CoreWebView2;
        if (core is not null && IsClient(core.Source))
            core.PostWebMessageAsJson(mode == PocketView.Quick ? "\"quick\"" : "\"full\"");
    }

    private static bool IsClient(string? source) => Uri.TryCreate(source, UriKind.Absolute, out var uri)
        && uri.Scheme == Uri.UriSchemeHttps && uri.Host == ClientHost && uri.IsDefaultPort
        && uri.UserInfo.Length == 0 && uri.AbsolutePath == "/index.html";

    private void ShowError(string message, Action? retry = null, string? link = null)
    {
        pageReady = false;
        BalanceChanged?.Invoke(null);
        browser.Hide();
        loading.Show();
        status.Text = message;
        status.MaximumSize = new Size(Math.Max(180, loading.ClientSize.Width - LogicalToDeviceUnits(40)), 0);
        while (loading.Controls.Count > 1) loading.Controls[1].Dispose();
        if (retry is not null || link is not null)
        {
            var button = new Button { AutoSize = true, Text = retry is not null ? "Retry" : "Get WebView2" };
            button.Click += (_, _) => { if (retry is not null) retry(); else OpenLink(link!); };
            loading.Controls.Add(button);
        }
    }

    private void OpenLink(string url)
    {
        try { Process.Start(new ProcessStartInfo(url) { UseShellExecute = true }); }
        catch (System.ComponentModel.Win32Exception)
        {
            MessageBox.Show(this, "Windows could not open the link in your browser.", "Pocket", MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
    }
}
