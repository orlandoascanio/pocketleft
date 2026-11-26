# Pocket for Mac (PocketLeft)

PocketLeft is a free, offline expense tracker at pocketleft.app. On Mac, your recorded balance stays visible in the menu bar. Enter income and expenses by hand and estimate how upcoming bills and expected payments could affect your balance. Local use requires neither a bank connection nor a Pocket account. The Mac app sends anonymous usage counts, which never include your money data and can be turned off in Settings ([details](https://pocketleft.app/privacy/#mac-app)).

[Download Pocket](https://pocketleft.app/) · [Open the web app](https://pocketleft.app/app/) · [Read the guides](https://pocketleft.app/guides/) · [Changelog](https://pocketleft.app/changelog/)

<img src="web/public/media/overview-2026-10-14.png" alt="Pocket for Mac showing the current balance, quick-entry controls, and transaction history" width="720">

## Get started

| Platform | How to get started |
| --- | --- |
| macOS 14 or later | Download [Pocket.dmg](https://github.com/orlandoascanio/pocketleft/releases/latest/download/Pocket.dmg), drag Pocket into Applications, and launch it to add it to the menu bar. Supports Apple Silicon and Intel. |
| Windows 11 | Download the Windows preview from [GitHub Releases](https://github.com/orlandoascanio/pocketleft/releases). Open Pocket from the system tray to check your balance or record an entry. See the [Windows guide](windows/README.md). |
| Web | Open the [web app](https://pocketleft.app/app/) and enter a six-digit pairing code from a connected device. You can add it to your phone’s home screen. |
| iOS and Android | See the [mobile development guide](mobile/README.md) to run the React Native app from source. |

Use a local ledger in the desktop or mobile app, or pair your devices to share a ledger through Pocket Sync. You can [run your own sync server](SELF-HOSTING.md) with Supabase.

## What Pocket does

- Log one-time or recurring transactions and confirm income when it arrives.
- Review spending by category, search your history, and export transactions as CSV on supported clients.
- Forecast your balance using scheduled income and bills. The Mac and mobile apps can also factor in typical everyday spending.
- Track subscriptions, see upcoming renewals, and set renewal reminders on desktop.

## Local development

Use Node.js 24 for the Next.js website and paired browser client. Run both commands from the repository root.

```sh
npm --prefix web ci
npm --prefix web run dev
```

Open [localhost:3000](http://localhost:3000) for the site or [localhost:3000/app/](http://localhost:3000/app/) for the browser client.

For the Mac app, use Xcode or its command-line tools on macOS 14 or later. The launch command opens a separate demo ledger.

```sh
cd mac
swift test
POCKET_DATA_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pocket-dev.XXXXXX")" POCKET_OPEN=main swift run Pocket
```

## Repository layout

| Directory | Contents |
| --- | --- |
| [`mac/`](mac/) | SwiftUI menu bar app, money engine, and tests |
| [`windows/`](windows/) | Windows tray app and build files |
| [`mobile/`](mobile/) | React Native and Expo app for iOS and Android |
| [`web/`](web/) | Next.js website and [paired browser client](web/public/app/) |
| [`supabase/`](supabase/) | Pocket Sync migrations and database tests |

## Releasing a new version

See the [release and deployment runbook](docs/RELEASING.md) for desktop installers, the Netlify website, mobile builds, and sync migrations.

Report bugs and request features through [GitHub Issues](https://github.com/orlandoascanio/pocketleft/issues).
