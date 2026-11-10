# Pocket

<img src="design/icon-mac-preview.png" width="96" align="right" alt="">

How much money is left, everywhere.

## Pocket for Mac

`mac/` is the Mac app. By default your money stays on your Mac in one JSON file
(`~/Library/Application Support/Pocket/ledger.json`, with 7 daily backups), with no account and no server.

To use Pocket on a phone or another computer too, connect it to a server (Settings → Sync). Anyone can run
their own: a free Supabase project with this repo's SQL. See **[SELF-HOSTING.md](SELF-HOSTING.md)**.
While connected, the server is the main copy. The Mac keeps a full copy (`account-ledger.json`), works offline,
and sends changes in order once it's back online (`account-sync.json` holds the outbox). Requests that time out
wait for review instead of being sent again, so nothing posts twice. The access key lives in the Keychain.

- Menubar balance, plus a window with Overview (history you can search and filter, ⌘F), Plan (forecast chart), Insights and Settings.
- Check for Updates downloads the latest GitHub release, checks it is Pocket signed with the Developer ID at the offered
  version (`codesign` with a team and bundle ID requirement), replaces the app and relaunches. When the app can't be
  replaced in place (Downloads, the disk image), it opens the downloaded disk image instead.
- Repeating money that can wait for confirmation, quick-add buttons (⌘1–⌘9), categories, reminders when money is due.
- Subscriptions: active and paused services, monthly/annual cost equivalents, renewals in the next 7/30 days,
  and optional 10 AM reminders the day before the next charge. Include existing repeating expenses without
  changing their category or recording a second payment. Stopping tracking in Pocket does not cancel a provider.
- `swift test` (in `mac/`) runs the money-logic tests and the app tests, including sync against a mock server
  (`Tests/PocketAppTests/AccountSyncTests.swift`). Set `POCKET_SNAPSHOT_DIR` to also render screen previews.
- `./mac/build.sh` builds a universal app signed with Developer ID; `NOTARY_PROFILE=<name> ./mac/build.sh --release`
  also notarizes, staples and makes `dist/Pocket-<version>.dmg`.
- Development only: `open mac/dist/Pocket.app --env POCKET_DATA_DIR=/tmp/demo --env POCKET_OPEN=main --env POCKET_SECTION=Plan`
  runs against a separate data folder (and an in-memory key) and opens a window at launch.

### Releasing a new version

Version 1.5.0 adds a nullable subscription marker to repeating payments. Before using subscription edits with
sync, apply `supabase/migrations/20261109120000_subscriptions.sql` to the server. It preserves the older clients'
RPC arguments and category behavior. The Mac checks the server's capability before saving subscription changes;
local use does not need a migration. The browser and mobile apps retain their existing screens.

One-time setup: save your notarization login in the keychain (needs an app-specific password from account.apple.com):

```bash
xcrun notarytool store-credentials "pocket-notary" --apple-id YOUR_APPLE_ID_EMAIL --team-id VW98Z8698B
```

Then, for each release:

1. Bump the version and build. This builds, signs, notarizes and staples the app and the DMG, then checks both with Gatekeeper:

   ```bash
   NOTARY_PROFILE=pocket-notary VERSION=1.0.1 ./mac/build.sh --release
   ```

2. Publish it. The asset must be named `Pocket.dmg` so the download page's "latest" link keeps working:

   ```bash
   cp mac/dist/Pocket-1.0.1.dmg /tmp/Pocket.dmg
   gh release create v1.0.1 /tmp/Pocket.dmg --repo orlandoascanio/pocket --title "Pocket for Mac 1.0.1" --notes "What changed…

If Pocket helps you, a star on GitHub helps other people find it." --latest
   ```

3. Check it: `https://github.com/orlandoascanio/pocket/releases/latest/download/Pocket.dmg` should download the new version.

## Pocket for iPhone and Android

`mobile/` is the phone app, built with React Native and Expo. Like the Mac, it keeps your money in one JSON file
on the phone (the same format, so exports move between them), or connects to a Pocket server with a 6-digit
pairing code. Overview, Plan, Categories and Settings, with the same money logic as the Mac
(`mobile/src/core/`, tested against the Mac's cases). See **[mobile/README.md](mobile/README.md)**.

## Web app and server

- `web/`: the website at [pocketleft.app](https://pocketleft.app), a Next.js site hosted on Vercel (project Root Directory: `web`).
  `/` is the Pocket for Mac download page. `npm run dev` in `web/` runs it locally.
  See [web/SEO-SETUP.md](web/SEO-SETUP.md) for the SEO audit and Google Search Console, GA4, and Sentry setup.
- `web/public/app/`: the web app, served as-is at [pocketleft.app/app](https://pocketleft.app/app/). Works on a phone and any
  computer; add it to your home screen. It talks to the original Pocket server unless you choose **Use your own server**
  (or open a pairing link from the Mac, which fills in the server and code).
- `docs/`: redirects only. GitHub Pages still serves `orlandoascanio.github.io/pocket`, which Pocket for Mac 1.1.0 opens
  for pairing; it forwards to pocketleft.app and keeps the pairing code.
- `supabase/migrations/`: the database. Tables are locked; everything goes through key-gated `pocket_*` functions.
  `pocket_setup` claims an empty database once, for self-hosting.
- `supabase/tests/`: database tests. Run `./supabase/tests/run.sh` (everything is rolled back).
- `design/`: the icon source. `swift design/make-icons.swift` regenerates every icon.

What it does:
- One-time spending and income on any date; future dates count when the day arrives.
- Repeating bills, subscriptions and income (weekly, every 2 weeks, monthly, every 3 months, yearly), with or without an end.
  Income can wait for you to confirm it arrived, then "Got it" logs the real amount and date. Pause, skip, or stop any of them.
- Categories, a monthly breakdown, and a forecast (1, 3, 6 or 12 months) of when the money runs out. On the Mac and phone
  the forecast also takes out your usual everyday spending (the median week of the last 12 full weeks of unscheduled
  spending, once there are two weeks of entries) and estimates how many months of money are left.
- History search and filters (words, money in or out, category, date range) and CSV export, on the Mac and phone.
- Quick-add buttons (keys 1–9 on the web, ⌘1–⌘9 on the Mac) and keyboard shortcuts (press ? on the web).
- New entries made offline wait on the device and sync when it's back online.
- Devices pair with a 6-digit code from one that's already set up, and can be removed from Settings.
- A daily GitHub Action pings the database so the free Supabase project never pauses (see SELF-HOSTING.md to do the same).

The secret key is never stored in this repo.
