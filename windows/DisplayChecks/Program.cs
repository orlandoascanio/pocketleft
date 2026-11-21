using Pocket.Windows;

(string Amount, string Label)[] cases =
[
    ("$0.00", "0"),
    ("$0.01", "1c"),
    ("-$0.99", "-99c"),
    ("$87.40", "87"),
    ("-$999.99", "-999"),
    ("$1,240.50", "1.2K"),
    ("-$9,990.00", "-9K"),
    ("$999,999.99", "0.9M"),
    ("-$999,999.99", "-.9M"),
    ("$1,250,000.00", "1.2M"),
    ("-$100,000,000,000,000,000.00", "->Q"),
];
if (TrayBalanceIcon.Format("Unavailable") is not null)
    throw new InvalidOperationException("An unavailable balance should retain the Pocket icon.");

Color foreground = SystemInformation.HighContrast ? SystemColors.WindowText : Color.White;
foreach (var (amount, expected) in cases)
{
    string? label = TrayBalanceIcon.Format(amount);
    if (label != expected)
        throw new InvalidOperationException($"Expected {amount} to display as {expected}, got {label}.");

    foreach (int pixels in new[] { 16, 20, 24, 32 })
    {
        using var icon = TrayBalanceIcon.Create(label, stale: false, new Size(pixels, pixels));
        using var bitmap = icon.ToBitmap();
        if (bitmap.Size != new Size(pixels, pixels) || bitmap.GetPixel(0, 0).A != 0)
            throw new InvalidOperationException($"The {pixels}px icon must retain its transparent corner.");

        int visiblePixels = 0;
        for (int y = 0; y < pixels; y++)
        {
            for (int x = 0; x < pixels; x++)
            {
                if (bitmap.GetPixel(x, y).ToArgb() == foreground.ToArgb()) visiblePixels++;
            }
        }
        if (visiblePixels < 7)
            throw new InvalidOperationException($"The {pixels}px tray label {label} has no readable glyphs.");
    }
}
Console.WriteLine("Verified positive, negative, cent and large balance icons at 16, 20, 24 and 32 pixels.");
