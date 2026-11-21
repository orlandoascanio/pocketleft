# Pocket for Windows preview

1. On Windows 11, run `Pocket-Setup.exe`. On **Choose Install Location**, select a folder on your SSD or HDD, such as `D:\Apps\PocketLeft`. You can also add a desktop shortcut and start Pocket at sign-in. Setup adds a Start menu shortcut by default.
2. Choose **Start local ledger** to use Pocket offline. To open an existing synced ledger, choose **Use your own server**, enter the HTTPS server details, and enter a six-digit pairing code from a connected device.
3. Click the Pocket icon near the Windows clock for your balance, quick-add buttons, and the entry form. Select **Open Pocket** for History, Plan, Subscriptions, and Categories.

Right-click the Pocket tray icon and open **Balance display** to switch between **Balance on hover** and **Floating panel**. Click the icon or floating panel for Quick Entry.

If Pocket is under **Show hidden icons**, drag it into the visible tray or enable it under **Settings → Personalization → Taskbar → Other system tray icons**. Right-click the tray icon to enable **Start at sign-in** or choose **Quit Pocket**. Closing the window keeps Pocket in the tray.

Switch between the local ledger and Pocket Sync in Settings. Each ledger keeps its own entries and currency display. Search or filter History, export CSV, and check Categories and the everyday-spending forecast in the full window. Settings can export a Pocket JSON backup and import or restore an offline ledger. Pocket can notify you when payments are due and before subscriptions renew while it runs in the tray.

A synced ledger keeps an offline copy of the last server balance. Changes made while offline wait in Settings and take effect after syncing. Review any change whose response was interrupted before retrying it. Settings can also copy a local ledger to a new self-hosted sync server, or keep a local copy of a synced ledger.

Windows Settings → Apps → Installed apps can remove Pocket. The local database and pairing stay in `%LOCALAPPDATA%\PocketLeft\WebView2` after reinstalling or uninstalling.

If Setup stops, it shows the destination and which step failed. The same details are saved to `%TEMP%\Pocket-Setup.log`.

## Build the installer

Use Node.js, npm, the .NET 10 SDK, and NSIS. Run from the repository root on macOS or Linux.

```sh
windows/build-installer.sh
```

Setup is written to `windows/bin/installer/Pocket-Setup.exe` and bundles both x64 and ARM64 builds, .NET, the shared web client, and the local database engine. Pocket uses the [Microsoft Edge WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/) available on Windows 11. The preview installer is unsigned.
