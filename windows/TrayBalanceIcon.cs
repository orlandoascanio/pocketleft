using System.Globalization;
using System.Runtime.InteropServices;

namespace Pocket.Windows;

internal static class TrayBalanceIcon
{
    private const int GridSize = 16;
    private const int MaxTextWidth = 14;
    private const string Suffixes = " KMBTQ";
    private static readonly CultureInfo UsCurrency = CultureInfo.GetCultureInfo("en-US");

    // Seven rows painted on the small icon grid, one bit per pixel.
    private static readonly IReadOnlyDictionary<char, byte[]> Glyphs = new Dictionary<char, byte[]>
    {
        ['0'] = [7, 5, 5, 5, 5, 5, 7],
        ['1'] = [2, 6, 2, 2, 2, 2, 7],
        ['2'] = [7, 1, 1, 7, 4, 4, 7],
        ['3'] = [7, 1, 1, 7, 1, 1, 7],
        ['4'] = [5, 5, 5, 7, 1, 1, 1],
        ['5'] = [7, 4, 4, 7, 1, 1, 7],
        ['6'] = [7, 4, 4, 7, 5, 5, 7],
        ['7'] = [7, 1, 1, 2, 2, 4, 4],
        ['8'] = [7, 5, 5, 7, 5, 5, 7],
        ['9'] = [7, 5, 5, 7, 1, 1, 7],
        ['K'] = [5, 5, 6, 4, 6, 5, 5],
        ['M'] = [5, 7, 7, 5, 5, 5, 5],
        ['B'] = [6, 5, 5, 6, 5, 5, 6],
        ['T'] = [7, 2, 2, 2, 2, 2, 2],
        ['Q'] = [7, 5, 5, 5, 5, 7, 1],
        ['c'] = [0, 0, 7, 4, 4, 4, 7],
        ['-'] = [0, 0, 0, 3, 0, 0, 0],
        ['.'] = [0, 0, 0, 0, 0, 0, 1],
        ['>'] = [0, 4, 2, 1, 2, 4, 0],
    };

    public static string? Format(string amount)
    {
        if (!decimal.TryParse(amount, NumberStyles.Currency, UsCurrency, out decimal value)) return null;
        if (value == 0) return "0";
        string sign = value < 0 ? "-" : "";
        decimal magnitude = Math.Abs(value);
        if (magnitude < 1)
            return sign + decimal.Truncate(magnitude * 100).ToString("0", CultureInfo.InvariantCulture) + "c";

        int unit = 0;
        while (magnitude >= 1000 && unit < Suffixes.Length - 1)
        {
            magnitude /= 1000;
            unit++;
        }
        if (magnitude >= 1000) return sign + ">Q";
        if (unit == 0) return sign + decimal.Truncate(magnitude).ToString("0", CultureInfo.InvariantCulture);

        string suffix = Suffixes[unit].ToString();
        if (magnitude < 10)
        {
            string fractional = sign + (decimal.Truncate(magnitude * 10) / 10).ToString("0.#", CultureInfo.InvariantCulture) + suffix;
            if (TextWidth(fractional) <= MaxTextWidth) return fractional;
        }
        string whole = sign + decimal.Truncate(magnitude).ToString("0", CultureInfo.InvariantCulture) + suffix;
        if (TextWidth(whole) <= MaxTextWidth) return whole;

        // Keep a pixel of breathing room on each side by using the next unit for wide labels.
        if (unit + 1 == Suffixes.Length) return sign + ">Q";
        string precision = sign.Length == 0 ? "0.0" : ".0";
        return sign + (decimal.Truncate(magnitude / 100) / 10).ToString(precision, CultureInfo.InvariantCulture) + Suffixes[unit + 1];
    }

    public static Icon Create(string label, bool stale, Size size)
    {
        var mask = new bool[GridSize, GridSize];
        int x = (GridSize - TextWidth(label)) / 2;
        foreach (char character in label)
        {
            int width = GlyphWidth(character);
            byte[] rows = Glyphs[character];
            for (int row = 0; row < rows.Length; row++)
            {
                for (int column = 0; column < width; column++)
                    mask[x + column, 4 + row] = (rows[row] & (1 << (width - column - 1))) != 0;
            }
            x += width + 1;
        }

        bool highContrast = SystemInformation.HighContrast;
        Color background = highContrast ? SystemColors.Window : stale ? Color.FromArgb(62, 73, 68)
            : label[0] == '-' ? Color.FromArgb(126, 44, 54) : Color.FromArgb(29, 83, 58);
        Color foreground = highContrast ? SystemColors.WindowText : Color.White;
        using var bitmap = new Bitmap(size.Width, size.Height);
        for (int pixelY = 0; pixelY < size.Height; pixelY++)
        {
            int gridY = pixelY * GridSize / size.Height;
            for (int pixelX = 0; pixelX < size.Width; pixelX++)
            {
                int gridX = pixelX * GridSize / size.Width;
                int edgeX = Math.Min(gridX, GridSize - 1 - gridX);
                int edgeY = Math.Min(gridY, GridSize - 1 - gridY);
                if (edgeX + edgeY >= 2)
                    bitmap.SetPixel(pixelX, pixelY, mask[gridX, gridY] ? foreground : background);
            }
        }

        IntPtr handle = bitmap.GetHicon();
        try
        {
            using Icon borrowed = Icon.FromHandle(handle);
            return (Icon)borrowed.Clone();
        }
        finally
        {
            DestroyIcon(handle);
        }
    }

    private static int TextWidth(string text) => text.Sum(GlyphWidth) + text.Length - 1;
    private static int GlyphWidth(char character) => character switch { '.' => 1, '-' => 2, _ => 3 };

    [DllImport("user32.dll", ExactSpelling = true)]
    private static extern bool DestroyIcon(IntPtr icon);
}
