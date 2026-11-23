# Release and deployment

Run the commands from the repository root unless a section says otherwise. Commit the version changes before building from a clean checkout of the release commit. Replace the example versions, commit SHA, and notes paths with values for the release.

## macOS

### Set up signing once

Install Xcode, Python 3 for disk image packaging, and the GitHub CLI. Install the project's Developer ID Application certificate and private key in your keychain. Save a notarization profile with an Apple app-specific password.

```sh
xcrun notarytool store-credentials pocket-notary \
  --apple-id 'YOUR_APPLE_ID' --team-id 'YOUR_APPLE_TEAM_ID'
```

Keep the production signing identity and bundle ID compatible with the installed app. [`mac/build.sh`](../mac/build.sh) uses the project's identity and bundle ID by default. Keep signing credentials and the notarization password in Keychain.

### Build and publish

1. Set the version and build defaults in [`mac/build.sh`](../mac/build.sh) and run `(cd mac && swift test)`. Use a higher version for an in-app update. The updater compares the release tag with the installed version, so a build-number-only bump requires a manual reinstall.
2. Build and test the disk image. The release script builds for Apple Silicon and Intel, signs the app and disk image, notarizes and staples both, then checks them with Gatekeeper.

   ```sh
   pocket_version=1.6.0
   pocket_build=1
   VERSION="$pocket_version" BUILD_NUMBER="$pocket_build" \
     NOTARY_PROFILE=pocket-notary ./mac/build.sh --release
   ```

   Open `mac/dist/Pocket-$pocket_version.dmg` on macOS. Test installation and launch, then verify an upgrade from the previous version with a test ledger.
3. Publish the tested image against its pushed commit. The public asset name `Pocket.dmg` is used by the website and the in-app updater.

   ```sh
   pocket_release_commit='FULL_GIT_COMMIT_SHA'
   pocket_release_dir="$(mktemp -d "${TMPDIR:-/tmp}/pocket-release.XXXXXX")"
   cp "mac/dist/Pocket-$pocket_version.dmg" "$pocket_release_dir/Pocket.dmg"
   gh release create "v$pocket_version" "$pocket_release_dir/Pocket.dmg" \
     --repo orlandoascanio/pocketleft --target "$pocket_release_commit" --latest \
     --title "Pocket for Mac $pocket_version" --notes-file /path/to/release-notes.md
   ```

4. Verify the [latest Mac download](https://github.com/orlandoascanio/pocketleft/releases/latest/download/Pocket.dmg) and **Check for Updates** from the previous version. Update `VERSION` and `DMG_SIZE` in [`web/lib/site.ts`](../web/lib/site.ts) and add the published release to [`web/lib/releases.ts`](../web/lib/releases.ts). When the interface changes, refresh the affected tour screenshots. Set `POCKET_SNAPSHOT_DIR` to an output directory when running `swift test` in `mac/` to render native previews.

## Windows preview

1. Set the same new version in `<Version>` in `windows/Pocket.Windows.csproj` and `SETUP_VERSION` in `windows/PocketSetup.nsi`.
2. Run the **Windows setup** GitHub Actions workflow on the release commit. It builds one installer and checks installation and removal on x64 and ARM64. To build locally on macOS or Linux, use Node.js, npm, the .NET 10 SDK, and NSIS. Run `windows/build-installer.sh` to produce `windows/bin/installer/Pocket-Setup.exe`. See the [Windows guide](../windows/README.md).
3. On Windows 11, smoke-test a fresh install and an upgrade with a test ledger. Check tray launch, Quick Entry, and ledger persistence.
4. Publish `Pocket-Setup.exe` as a GitHub prerelease. The Windows updater expects a tag in the format `windows-preview-N`, a title beginning with `Pocket for Windows X.Y.Z`, and a SHA-256 digest on the installer asset. Reserve GitHub’s **Latest** label for the Mac release.

   ```sh
   pocket_windows_version=0.2.0
   pocket_windows_tag=windows-preview-7
   pocket_release_commit='FULL_GIT_COMMIT_SHA'
   gh release create "$pocket_windows_tag" windows/bin/installer/Pocket-Setup.exe \
     --repo orlandoascanio/pocketleft --target "$pocket_release_commit" \
     --prerelease --latest=false --title "Pocket for Windows $pocket_windows_version preview" \
     --notes-file /path/to/windows-release-notes.md
   ```

5. Verify the published installer and digest on GitHub. Check the updater from the previous Windows preview. Update `WINDOWS_VERSION` and `WINDOWS_SETUP_URL` in [`web/lib/site.ts`](../web/lib/site.ts) to point the website to the new preview.

## Website and browser app

Netlify deploys `main` with `web` as the base directory and `npm run build` as the build command. In Netlify, verify that the production deploy corresponds to the intended commit.

1. When shipping changes to the static browser client, keep `APP_VERSION` in `web/public/app/app.js`, the version in `web/public/app/version.json`, and the asset query versions in `web/public/app/index.html` in sync.
2. Before deploying, run the website checks and production build.

   ```sh
   npm --prefix web ci
   npm --prefix web run check
   npm --prefix web run build
   ```

3. On [pocketleft.app](https://pocketleft.app/), verify the Mac and Windows download links on their respective platforms, the changelog, and the browser app at `/app/`. Check that `/app/` and `/app/index.html` both serve a robots `noindex` meta tag. For changes affecting sync, pair a test device and confirm a test entry appears on a second paired device.

### Website environment variables

The default site runs without local environment overrides. [`web/.env.example`](../web/.env.example) lists optional settings. Set local overrides in `web/.env.local` and production overrides in the Netlify site's environment variables. Redeploy to apply changes to `NEXT_PUBLIC_*` build settings.

| Setting | Behavior |
| --- | --- |
| `NEXT_PUBLIC_GA_MEASUREMENT_ID` | Leave unset to use the built-in GA4 stream on `pocketleft.app`. Set it to a different stream ID to override the default, or set an empty value to disable analytics. Analytics requires visitor consent. |
| `NEXT_PUBLIC_GA_DEBUG` | Set to `true` when testing GA4 in a test deployment. |
| `NEXT_PUBLIC_SENTRY_DSN` | Enables Sentry when set. |
| `NEXT_PUBLIC_SENTRY_ENVIRONMENT` | Labels events by environment, such as `production`. |
| `SENTRY_ORG`, `SENTRY_PROJECT`, `SENTRY_AUTH_TOKEN` | Optional build-time source map uploads. Store the auth token as a private build variable. |

Keep real credentials in the local ignored environment files or the deployment provider’s secret settings. See [website integrations](../web/SEO-SETUP.md) for analytics and monitoring verification.

## Sync database

Use [the self-hosting guide](../SELF-HOSTING.md) for the initial Supabase setup. Before deploying a client that requires new database behavior, apply the pending [migrations](../supabase/migrations/) to a test Supabase project. Back up the production database before applying migrations there.

```sh
supabase link --project-ref 'TEST_PROJECT_REF'
supabase db push
./supabase/tests/run.sh
```

The test script runs against the linked project and rolls back its changes. After the tests pass, confirm the production project reference and apply the required migrations there before deploying the dependent clients.

Synced subscription edits require [the subscriptions migration](../supabase/migrations/20261109120000_subscriptions.sql). It preserves the older clients’ RPC arguments and category behavior. Local ledgers work independently of the sync database.

## Mobile builds

Follow the [mobile guide](../mobile/README.md) for JavaScript tests, type checking, and simulator builds. For store distribution, configure the Expo EAS project and store credentials, then run `npx eas-cli@latest build` from `mobile/`. Test the resulting build before submitting with `npx eas-cli@latest submit`.
