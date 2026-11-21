# Pocket for Windows preview

1. On Windows 11, run `Pocket-Setup.exe`. On **Choose Install Location**, select a folder on your SSD or HDD, such as `D:\Apps\PocketLeft`. You can also add a desktop shortcut and start Pocket at sign-in. Setup adds a Start menu shortcut by default.
2. Choose **Start local ledger** to use Pocket offline. To open an existing synced ledger, choose **Use your own server**, enter the HTTPS server details, and enter a six-digit pairing code from a connected device.
3. Click the Pocket icon near the Windows clock for your balance, quick-add buttons, and the entry form. Select **Open Pocket** for History, Plan, Subscriptions, and Insights.

Right-click the Pocket tray icon and open **Balance display** to switch between **Number in tray**, **Balance on hover**, **Floating panel**, and **Icon only**. The small tray number uses abbreviated amounts. Hover for dollars and cents. Click the icon or floating panel for Quick Entry.

If Pocket is under **Show hidden icons**, drag it into the visible tray or enable it under **Settings → Personalization → Taskbar → Other system tray icons**. Right-click the tray icon to enable **Start at sign-in** or choose **Quit Pocket**. Closing the window keeps Pocket in the tray.

Switch between the local ledger and Pocket Sync in Pocket's Settings. Each ledger keeps its own entries. The Windows preview displays amounts in USD and uses the same History, Plan, Subscriptions, and Insights screens as the web app. Windows Settings → Apps → Installed apps can remove Pocket. The local database and pairing stay in `%LOCALAPPDATA%\PocketLeft\WebView2` after reinstalling or uninstalling.

If Setup stops, it shows the destination and which step failed. The same details are saved to `%TEMP%\Pocket-Setup.log`.

## Build the installer

Use Node.js, npm, the .NET 10 SDK, and NSIS. Run from the repository root on macOS or Linux.

```sh
windows/build-installer.sh
```

Setup is written to `windows/bin/installer/Pocket-Setup.exe` and bundles both x64 and ARM64 builds, .NET, the shared web client, and the local database engine. Pocket uses the [Microsoft Edge WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/) available on Windows 11. The preview installer is unsigned.
