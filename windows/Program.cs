namespace Pocket.Windows;

internal static class Program
{
    private const string InstanceName = "PocketLeft.Windows.0565FA1A-EFFD-45A3-AC83-D182CFABB2B7";

    [STAThread]
    private static void Main(string[] args)
    {
        var background = args.Contains("--background", StringComparer.OrdinalIgnoreCase);
        using var showRequest = new EventWaitHandle(false, EventResetMode.AutoReset, InstanceName + ".Show");
        using var instance = new Mutex(false, InstanceName);
        try
        {
            if (!instance.WaitOne(0))
            {
                if (!background) showRequest.Set();
                return;
            }
        }
        catch (AbandonedMutexException)
        {
            // The previous process exited without releasing ownership.
        }

        try
        {
            ApplicationConfiguration.Initialize();
            using var pocket = new TrayApplication(showRequest, background);
            Application.Run(pocket);
        }
        finally
        {
            instance.ReleaseMutex();
        }
        WindowsUpdates.LaunchPendingSetup();
    }
}
