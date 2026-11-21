using System.Runtime.InteropServices;

namespace Pocket.Windows;

internal sealed record ClockBalance(string Amount, bool Stale);

internal sealed class ClockBalanceWindow : Form
{
    private readonly Icon pocketIcon;
    private readonly Action openPocket;
    private ClockBalance? balance;

    public ClockBalanceWindow(Icon pocketIcon, Action openPocket)
    {
        this.pocketIcon = pocketIcon;
        this.openPocket = openPocket;
        Text = "Pocket balance";
        AutoScaleMode = AutoScaleMode.Dpi;
        FormBorderStyle = FormBorderStyle.None;
        StartPosition = FormStartPosition.Manual;
        ShowInTaskbar = false;
        TopMost = true;
        DoubleBuffered = true;
        Font = SystemFonts.MessageBoxFont ?? Font;
        BackColor = SystemColors.Window;
        ForeColor = SystemColors.WindowText;
        Cursor = Cursors.Hand;
    }

    protected override bool ShowWithoutActivation => true;

    protected override CreateParams CreateParams
    {
        get
        {
            const int ToolWindow = 0x80;
            const int NoActivate = 0x08000000;
            var settings = base.CreateParams;
            settings.ExStyle |= ToolWindow | NoActivate;
            return settings;
        }
    }

    public void ShowBalance(ClockBalance? value)
    {
        if (balance != value)
        {
            balance = value;
            Text = value is null ? "Pocket balance" : $"Pocket balance {BalanceText(value)}";
            AccessibleName = Text;
            Invalidate();
        }
        UpdatePosition();
    }

    public void UpdatePosition()
    {
        var screen = Screen.PrimaryScreen;
        if (balance is null || screen is null || IsFullScreenOrPresenting())
        {
            if (Visible) Hide();
            return;
        }

        Rectangle area = screen.WorkingArea;
        int gap = LogicalToDeviceUnits(8);
        int iconSize = LogicalToDeviceUnits(18);
        int inset = LogicalToDeviceUnits(10);
        int width = Math.Max(1, Math.Min(area.Width - gap * 2,
            TextRenderer.MeasureText(BalanceText(balance), Font).Width + iconSize + inset * 3));
        int height = Math.Max(LogicalToDeviceUnits(34), Font.Height + inset);
        int x = area.Left > screen.Bounds.Left ? area.Left + gap : area.Right - width - gap;
        int y = area.Top > screen.Bounds.Top ? area.Top + gap : area.Bottom - height - gap;
        var bounds = new Rectangle(x, y, width, height);
        if (Bounds != bounds) Bounds = bounds;
        if (!Visible) Show();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        if (balance is null) return;
        ControlPaint.DrawBorder(e.Graphics, ClientRectangle, SystemColors.ActiveBorder, ButtonBorderStyle.Solid);
        int iconSize = LogicalToDeviceUnits(18);
        int inset = LogicalToDeviceUnits(10);
        e.Graphics.DrawIcon(pocketIcon, new Rectangle(inset, (Height - iconSize) / 2, iconSize, iconSize));
        int textLeft = iconSize + inset * 2;
        var textBounds = new Rectangle(textLeft, 0, Math.Max(0, Width - textLeft - inset), Height);
        TextRenderer.DrawText(e.Graphics, BalanceText(balance), Font, textBounds, ForeColor,
            TextFormatFlags.SingleLine | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
    }

    protected override void OnMouseUp(MouseEventArgs e)
    {
        base.OnMouseUp(e);
        if (e.Button == MouseButtons.Left) openPocket();
    }

    private static string BalanceText(ClockBalance value) => value.Stale ? $"{value.Amount} · Last known" : value.Amount;

    private static bool IsFullScreenOrPresenting() => SHQueryUserNotificationState(out var state) == 0
        && state is NotificationState.Busy or NotificationState.FullScreenDirect3D or NotificationState.Presentation;

    private enum NotificationState { Busy = 2, FullScreenDirect3D = 3, Presentation = 4 }

    [DllImport("shell32.dll", ExactSpelling = true)]
    private static extern int SHQueryUserNotificationState(out NotificationState state);
}
