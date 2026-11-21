using System.Diagnostics;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Pocket.Windows;

internal static partial class WindowsUpdates
{
    private const string Repository = "orlandoascanio/pocketleft";
    private static readonly HttpClient Client = new() { Timeout = TimeSpan.FromSeconds(90) };
    private static bool checking;
    public static string? PendingSetup { get; private set; }
    private static Version Current => typeof(WindowsUpdates).Assembly.GetName().Version!;
    public static string VersionLabel => Current.ToString(3);

    static WindowsUpdates()
    {
        Client.DefaultRequestHeaders.UserAgent.ParseAdd($"Pocket-for-Windows/{VersionLabel}");
        Client.DefaultRequestHeaders.Accept.ParseAdd("application/vnd.github+json");
    }

    public static async Task CheckAsync(Form owner, Action quit)
    {
        if (checking) return;
        checking = true;
        string? destination = null;
        try
        {
            using var releases = JsonDocument.Parse(await Client.GetStringAsync(
                $"https://api.github.com/repos/{Repository}/releases?per_page=50"));
            if (owner.IsDisposed) return;
            var latest = releases.RootElement.EnumerateArray()
                .Select(ReadRelease)
                .OfType<Release>()
                .OrderByDescending(release => release.Version)
                .FirstOrDefault();
            if (latest is null)
            {
                MessageBox.Show(owner, "No Windows releases are available right now.", "Pocket updates");
                return;
            }
            if (latest.Version <= new Version(VersionLabel))
            {
                MessageBox.Show(owner, $"Pocket {VersionLabel} is up to date.", "Pocket updates");
                return;
            }
            var consent = MessageBox.Show(owner,
                $"Pocket {latest.Version} is available. Download the verified installer and close Pocket to run Setup?",
                "Pocket updates", MessageBoxButtons.YesNo, MessageBoxIcon.Information);
            if (consent != DialogResult.Yes) return;

            string folder = Path.Combine(Path.GetTempPath(), $"PocketUpdate-{Guid.NewGuid():N}");
            Directory.CreateDirectory(folder);
            destination = Path.Combine(folder, "Pocket-Setup.exe");
            using var response = await Client.GetAsync(latest.Url, HttpCompletionOption.ResponseHeadersRead);
            response.EnsureSuccessStatusCode();
            using var timeout = new CancellationTokenSource(TimeSpan.FromMinutes(5));
            await using (var output = new FileStream(destination, FileMode.CreateNew, FileAccess.ReadWrite, FileShare.None, 81920, true))
            {
                await response.Content.CopyToAsync(output, timeout.Token);
                output.Position = 0;
                string digest = Convert.ToHexString(await SHA256.HashDataAsync(output, timeout.Token));
                if (!digest.Equals(latest.Digest, StringComparison.OrdinalIgnoreCase))
                    throw new IOException("The installer checksum did not match.");
            }
            if (owner.IsDisposed) return;
            PendingSetup = destination;
            destination = null;
            quit();
        }
        catch (Exception error) when (error is HttpRequestException or IOException or UnauthorizedAccessException
            or OperationCanceledException or JsonException)
        {
            if (!owner.IsDisposed)
                MessageBox.Show(owner, "Pocket could not verify or download the update. Try again later.", "Pocket updates");
        }
        finally
        {
            checking = false;
            if (destination is not null)
            {
                try { Directory.Delete(Path.GetDirectoryName(destination)!, recursive: true); }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
            }
        }
    }

    public static void LaunchPendingSetup()
    {
        if (PendingSetup is not { } setup) return;
        try { Process.Start(new ProcessStartInfo(setup) { UseShellExecute = true }); }
        catch (System.ComponentModel.Win32Exception)
        {
            MessageBox.Show($"Windows could not start Pocket Setup. Open it from {setup}.", "Pocket updates");
        }
    }

    private static Release? ReadRelease(JsonElement release)
    {
        string? tag = release.GetProperty("tag_name").GetString();
        if (tag is null || !WindowsTag().IsMatch(tag)) return null;
        var match = WindowsVersion().Match(release.GetProperty("name").GetString() ?? "");
        if (!match.Success || !Version.TryParse(match.Groups[1].Value, out var version)) return null;
        string url = $"https://github.com/{Repository}/releases/download/{tag}/Pocket-Setup.exe";
        foreach (var asset in release.GetProperty("assets").EnumerateArray())
        {
            if (!asset.GetProperty("browser_download_url").ValueEquals(url) ||
                !asset.TryGetProperty("digest", out var digest) || digest.GetString() is not { } checksum ||
                !AssetDigest().IsMatch(checksum)) continue;
            return new Release(version, url, checksum[7..]);
        }
        return null;
    }

    private sealed record Release(Version Version, string Url, string Digest);
    [GeneratedRegex(@"^windows-preview-\d+$")] private static partial Regex WindowsTag();
    [GeneratedRegex(@"^Pocket for Windows (\d+\.\d+\.\d+)\b")] private static partial Regex WindowsVersion();
    [GeneratedRegex(@"^sha256:[a-fA-F0-9]{64}$")] private static partial Regex AssetDigest();
}
