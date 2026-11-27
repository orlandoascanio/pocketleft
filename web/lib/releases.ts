import type { Locale } from "@/lib/locale";
export type Release = {
  version: string;
  date: string;
  title: string;
  summary: string;
  theme: "sync" | "launch" | "findable" | "update" | "share" | "subscriptions";
  highlights: { title: string; description: string }[];
  detailsTitle: string;
  details: string[];
  source: string;
  relatedSources?: { title: string; url: string }[];
  guideLinks?: { title: string; url: string }[];
};

// Curated from the published GitHub releases. Add a new entry here when shipping,
// and update VERSION in site.ts. Dates are publication dates, not commit dates.
export const RELEASES: Release[] = [
  {
    version: "1.6.0",
    date: "2026-11-26",
    title: "Try a purchase before you make it.",
    summary: "Pocket for Mac shows how a purchase would change your lowest balance before payday, and catches you up from a bank statement in one step you can undo.",
    theme: "update",
    highlights: [
      { title: "Try a purchase", description: "In Plan, type something like “$200 on Wednesday”. Pocket shows your new lowest balance, whether you’d drop below zero, and what’s left until payday. Nothing is saved unless you choose Save as Planned Expense." },
      { title: "Import a bank statement", description: "In Settings, choose Import Statement and pick a CSV from your bank or card. Preview the rows first. Rows that look like entries you already recorded start unchecked, and Undo Import removes everything the import added." },
      { title: "Quick entry on your phone", description: "The Pocket web app can open straight to the amount from your home screen. After you add an entry, it shows whether the entry is saved on your phone, waiting in your account, or on your Mac." },
    ],
    detailsTitle: "Also in this release",
    details: [
      "Pocket for Mac sends anonymous usage counts and crash reports. They never include amounts, names, categories, balances or currency. You can turn them off in Settings.",
      "Statement import reads common bank and card formats, including separate money-in and money-out columns, and asks whether dates are day-first when a file could be read either way.",
      "Confirming that an entry reached your Mac requires the latest sync database update from the migrations folder.",
    ],
    source: "https://github.com/orlandoascanio/pocketleft/releases/tag/v1.6.0",
  },
  {
    version: "1.5.5",
    date: "2026-11-22",
    title: "See what you can spend before payday.",
    summary: "Pocket for Mac helps you plan what you can spend today, undo an accidental entry, and hide your balance before sharing your screen.",
    theme: "update",
    highlights: [
      { title: "Available until payday", description: "Choose a payday and a minimum balance to keep. Pocket uses the lowest projected balance before that date and includes usual spending when you have enough history." },
      { title: "Undo a quick entry", description: "Click Undo on the confirmation to reverse the entry you just added, including an entry that’s still waiting to sync." },
      { title: "Hide your balance", description: "Choose Hide Balance from the menu bar panel’s More menu. The balance in the menu bar and panel is hidden while Quick Entry stays available." },
    ],
    detailsTitle: "How the payday estimate works",
    details: [
      "Pocket leaves out income awaiting confirmation and ends the estimate the day before your selected payday.",
    ],
    source: "https://github.com/orlandoascanio/pocketleft/releases/tag/v1.5.5",
    guideLinks: [
      { title: "Set your payday and cushion", url: "/guides/freelance-income/#before-payday" },
      { title: "Undo a quick entry", url: "/guides/quick-add-spending/#undo" },
      { title: "Hide the menu bar balance", url: "/guides/menu-bar-balance/#screen-sharing" },
    ],
  },
  {
    version: "1.5.4",
    date: "2026-11-22",
    title: "See what overdue income changes.",
    summary: "Plan shows how much overdue income your forecast counts as arriving today. Preview your balance without it to see whether your upcoming bills are covered.",
    theme: "update",
    highlights: [
      { title: "See what Plan assumes", description: "When income is past due and still waiting for confirmation, Plan shows how much it counts as arriving today." },
      { title: "Preview without overdue income", description: "Turn on the preview in Plan to update the chart and projected balance. Your recorded balance and saved payment dates stay intact." },
    ],
    detailsTitle: "Everyday spending in Plan",
    details: [
      "A new ledger starts with scheduled payments. Once Pocket has enough history to estimate everyday spending, you can include it in Plan.",
    ],
    source: "https://github.com/orlandoascanio/pocketleft/releases/tag/v1.5.4",
  },
  {
    version: "1.5.3",
    date: "2026-11-19",
    title: "See where your money went.",
    summary: "Pocket for Mac makes it easier to check spending by category, review uncategorized entries, and get back to the month you were viewing.",
    theme: "update",
    highlights: [
      { title: "A clearer breakdown", description: "Each bar shows its share of spending or money in. The summary puts spending first and shows how much your balance changed over the selected period." },
      { title: "Compare completed months", description: "See how spending changed from the previous full month. The current month shows totals to date." },
      { title: "Review uncategorized entries", description: "Purchases and payments without a category have their own Review rows. Entries assigned to Other stay in Other." },
      { title: "Open the entries behind each total", description: "Select a category to open its History, then go back to the same month or All time view." },
    ],
    detailsTitle: "Also in this release",
    details: [
      "Click the month name to jump to another month.",
      "History highlights active filters and labels the CSV export.",
      "Use Back to Categories or ⌘[ to return from category History.",
    ],
    source: "https://github.com/orlandoascanio/pocketleft/releases/tag/v1.5.3",
  },
  {
    version: "1.5.2",
    date: "2026-11-18",
    title: "Know when each subscription renews.",
    summary: "Pocket for Mac shows when each subscription renews, how much is due soon, and what will go into History when you save.",
    theme: "subscriptions",
    highlights: [
      { title: "Renewal dates on every row", description: "See what renews soonest. Select a countdown or date to see the exact renewal date and charge." },
      { title: "A clearer view of upcoming charges", description: "Compare your monthly equivalent with the highlighted total for charges due in the next 7 or 30 days." },
      { title: "Reminders on your schedule", description: "Add more than one reminder. Set a date and time for this renewal, or a time and number of days before every renewal. Pocket tells you when the reminder time for the next renewal has passed." },
      { title: "A form just for subscriptions", description: "Enter the name, price, billing cycle and next renewal. If saving will record a payment in History right away, the form tells you before you save." },
    ],
    detailsTitle: "Good to know",
    details: [
      "The built-in reminder is two days before renewal at 10:00 AM. Your saved custom timings still apply.",
      "Pause or resume tracking from the subscription menu. Deleting a schedule removes future tracking and keeps past charges in History.",
      "Renewal reminders are scheduled on this Mac. Synced subscriptions use the existing Pocket server support.",
      "Already on 1.5.2? Download Pocket again to install build 2.",
    ],
    source: "https://github.com/orlandoascanio/pocketleft/releases/tag/v1.5.2",
  },
  {
    "version": "1.5.1",
    "date": "2026-11-15",
    "title": "Less work in the background.",
    "summary": "Pocket now syncs less often in the background, formats amounts faster, and opens History in smaller pages as your records grow.",
    "theme": "update",
    "highlights": [
      {
        "title": "Quieter background sync",
        "description": "Pocket checks for changes every five minutes in the background, or every fifteen minutes in Low Power Mode. While active, it checks every thirty seconds. Your own edits still sync immediately."
      },
      {
        "title": "Smaller History pages",
        "description": "History starts with your latest 100 entries. Choose Show more to see older entries. Search, totals and CSV export still cover your full history."
      },
      {
        "title": "Faster amounts",
        "description": "Amounts take less work to display throughout Pocket, while keeping your currency, locale and recorded precision."
      },
      {
        "title": "Fewer failed retries",
        "description": "Connection problems now increase the time between automatic retries. If account access was removed, Pocket pauses automatic retries until you reconnect or explicitly try again."
      }
    ],
    "detailsTitle": "Good to know",
    "details": [
      "Changes made on another device can take up to five minutes to appear while Pocket is in the background, or fifteen minutes in Low Power Mode. Failed connections may take longer; you can still retry manually.",
      "This update changes the Mac app. Your existing entries, subscriptions and sync server remain compatible; no new server migration is required for 1.5.1.",
      "These changes reduce background work. Battery savings have not been measured."
    ],
    "source": "https://github.com/orlandoascanio/pocketleft/releases/tag/v1.5.1"
  },
  {
    version: "1.5.0",
    date: "2026-11-09",
    title: "Know what you're subscribed to.",
    summary: "The new Subscriptions tab brings your recurring services together, with monthly and annual cost equivalents, upcoming renewals, and optional reminders before the next charge.",
    theme: "subscriptions",
    highlights: [
      { title: "All your subscriptions", description: "See active and paused subscriptions in one place. Existing repeating payments in the Subscriptions category appear automatically; include other repeating expenses without changing their category or logging them twice." },
      { title: "See what it adds up to", description: "Compare monthly and annual cost equivalents at current prices, and see the actual charges planned over the next 7 or 30 days. Paused subscriptions are excluded from totals." },
      { title: "A reminder before renewal", description: "Turn on renewal reminders to receive a notification on this Mac at 10 AM the day before the next charge. Open it to review your subscriptions." },
      { title: "Manage tracking", description: "Add or edit a subscription, pause or resume tracking, or remove future payments from Pocket while keeping past payments in History. Cancel with the provider separately to stop being charged." },
    ],
    detailsTitle: "Good to know",
    details: [
      "Subscriptions uses the same repeating payments as Plan, so each charge counts once.",
      "Subscriptions is available in the Mac app and, in the follow-up website update, the paired browser app. Renewal notifications are available on the Mac; the mobile app keeps its existing screens.",
      "For synced accounts, apply supabase/migrations/20261109120000_subscriptions.sql to your server first. The Mac protects subscription edits until the server supports them; local use needs no server update.",
      "Renewal reminders are optional and apply to the next scheduled charge. Pocket needs permission to send macOS notifications.",
    ],
    source: "https://github.com/orlandoascanio/pocketleft/releases/tag/v1.5.0",
  },
  {
    version: "1.4.1",
    date: "2026-10-17",
    title: "Updates install themselves.",
    summary: "Check for Updates now downloads the new version inside Pocket, checks it, swaps it in and reopens. No browser, no disk image to drag.",
    theme: "update",
    highlights: [
      { title: "Install and Relaunch", description: "When a new version is out, click Install and Relaunch. Pocket shows the download's progress, replaces itself and opens again, usually in a few seconds." },
      { title: "Checked before it's installed", description: "Pocket only installs a download that is signed with Pocket's Developer ID and is the version it offered. If anything doesn't match, this copy stays exactly as it was." },
      { title: "Still works from anywhere", description: "If Pocket is running from Downloads or the disk image, where it can't replace itself, it downloads the update and opens it for you to drag into Applications." },
    ],
    detailsTitle: "Good to know",
    details: [
      "This first update to 1.4.1 still opens your browser, because 1.4.0 has the old Check for Updates. From 1.4.1 on, updates install inside Pocket.",
      "Your data lives in its own folder, so updating never touches your money.",
      "Pocket still asks GitHub for the latest release only when you click Check for Updates.",
    ],
    source: "https://github.com/orlandoascanio/pocketleft/releases/tag/v1.4.1",
  },
  {
    version: "1.4.0",
    date: "2026-10-16",
    title: "Forecasts that count your everyday spending.",
    summary: "Plan now includes what you usually spend day to day, History has search and filters, you can export a CSV spreadsheet, payments can repeat every 3 months, and you can tell a friend about Pocket from its menus.",
    theme: "share",
    highlights: [
      { title: "Everyday spending in the forecast", description: "Plan now takes out what you usually spend on things nobody scheduled, like food and shopping, based on a typical week from your recent entries. “Runs out on” gets closer to real life, and Plan says roughly how many months of money you have at that pace. You can turn it off under the chart." },
      { title: "Search and filter History", description: "Press ⌘F to find any entry by name, category or amount. Show only spending or money in, one category, or a date range, and see the total of what you found above the list." },
      { title: "Export a CSV spreadsheet", description: "Settings → Export CSV… saves every entry for Numbers, Excel or Google Sheets. The share button in History exports only what you searched for." },
      { title: "Every 3 months", description: "Repeating payments can be quarterly now, for insurance, taxes or anything else billed each quarter." },
      { title: "Share Pocket…", description: "Choose Share Pocket… from the Pocket menu or the ⋯ menu in the menu bar panel to send a short message and a link to pocketleft.app. Pocket asks once, at a good moment, if you know someone who'd like it, and the About window links to Pocket on GitHub." },
    ],
    detailsTitle: "How the everyday estimate works",
    details: [
      "Pocket looks at up to the last 12 full weeks of spending that a repeating payment didn't log, and uses the middle week (the median), so one big purchase doesn't throw it off.",
      "It starts once you have two full weeks of entries. Scheduled payments still count on their own dates.",
      "If you sync, update every connected Mac to 1.4 to see quarterly payments there.",
      "The share message is fixed text and a link. It never includes your balance, your entries or anything else from Pocket.",
    ],
    source: "https://github.com/orlandoascanio/pocketleft/releases/tag/v1.4.0",
  },
  {
    version: "1.2.3",
    date: "2026-10-13",
    title: "Know when there's a new Pocket.",
    summary: "Check for updates from inside Pocket, see which version you have in a proper About window, and install from a cleaner download.",
    theme: "update",
    highlights: [
      { title: "Check for Updates", description: "Choose Check for Updates… from the Pocket menu, the ⋯ menu in the menu bar panel, or Settings → About. If there's a newer version, Download gets it in one click." },
      { title: "About Pocket", description: "The standard Mac About window shows your version, with links to pocketleft.app and the source code." },
      { title: "A clearer install", description: "The download opens to a Pocket window that shows exactly where to drag the app." },
    ],
    detailsTitle: "How the check works",
    details: [
      "Pocket asks GitHub for the latest release only when you click Check for Updates. It never checks in the background.",
      "Nothing about your money is sent. Your data stays where it is when you install the new version.",
    ],
    source: "https://github.com/orlandoascanio/pocketleft/releases/tag/v1.2.3",
  },
  {
    version: "1.2.0",
    date: "2026-10-13",
    title: "Everything in reach.",
    summary: "The things Pocket could already do are now where you'd look for them: money you're waiting for, quick-add buttons, and your daily backups.",
    theme: "findable",
    highlights: [
      { title: "Got it, right there", description: "Payments you're waiting for sit in Overview with Got it and Skip buttons. Mark money someone already owes you as still waiting, and your balance only moves once it arrives." },
      { title: "Buttons from what you buy", description: "Choose Save as Button after adding an entry. The new Quick Add menu gives ⌘1 to ⌘9 on every page of the window." },
      { title: "Restore a daily backup", description: "Settings → Daily backups restores any of the last seven days. A file Pocket can't open is kept, never overwritten." },
    ],
    detailsTitle: "Also in this release",
    details: [
      "A ⋯ button on every planned payment in Plan to skip the next one, pause it or stop it.",
      "Categories shows where your money came from, not just where it went.",
      "No instant reminder for a payment added after its reminder time.",
      "The sidebar's keyboard focus follows the page you're on.",
    ],
    source: "https://github.com/orlandoascanio/pocketleft/releases/tag/v1.2.0",
  },
  {
    version: "1.1.0",
    date: "2026-10-12",
    title: "Your balance, on your phone too.",
    summary: "Optional sync joins Pocket. Keep using it entirely on your Mac, or connect your own server to take your balance with you.",
    theme: "sync",
    highlights: [
      { title: "Connect your own server", description: "Use a free Supabase project. Connect it in Settings → Sync, then move the money already on your Mac over with Set Up This Server." },
      { title: "Pair your phone", description: "Choose Pair in Settings → Sync. The link opens the Pocket web app with your server and pairing code ready to go." },
      { title: "Keep going offline", description: "Your Mac keeps a full copy and sends changes in order when you’re back online. Uncertain requests wait for review, so a payment isn’t added twice." },
    ],
    detailsTitle: "A cleaner Pocket for Mac",
    details: [
      "A bigger amount field comes first. Date, category and repeat options open in a separate sheet.",
      "Categories have their own colors. Red now means below zero.",
      "A simpler menu bar panel shows a one-line notice when payments are waiting for you.",
      "History includes day totals, alongside a native sidebar and tidier Plan, Insights and Settings.",
    ],
    source: "https://github.com/orlandoascanio/pocketleft/releases/tag/v1.1.0",
  },
  {
    version: "1.0.0",
    date: "2026-10-11",
    title: "Hello, Pocket.",
    summary: "The first release for Mac. A balance in your menu bar, a plan for what’s ahead, and your money stored on your own computer.",
    theme: "launch",
    highlights: [
      { title: "Know what’s left", description: "Your balance lives in the menu bar, with quick adds and recent entries one click away. Customize quick-add buttons and use ⌘1 through ⌘9." },
      { title: "See what’s ahead", description: "Schedule bills, subscriptions and paychecks. Plan forecasts the next 1, 3, 6 or 12 months, including when your balance runs out or comes back above zero." },
      { title: "Confirm money when it arrives", description: "Freelance pay and refunds can wait for confirmation. Got it records the actual amount and date, with a reminder on the day it’s due." },
    ],
    detailsTitle: "More in the first release",
    details: [
      "Weekly, every two weeks, monthly and yearly repeating payments, with an optional end.",
      "Categories and a monthly breakdown of spending in Insights.",
      "One local data file, seven daily backups, and export, import and erase controls.",
      "A pocket character that reacts to your money.",
      "Free, signed and notarized for macOS 14 or later, on Apple Silicon and Intel.",
    ],
    source: "https://github.com/orlandoascanio/pocketleft/releases/tag/v1.0.0",
  },
];

export const releaseId = (version: string) => `v${version.replaceAll(".", "-")}`;

export function groupReleasesByDay(releases: Release[]) {
  const days = new Map<string, Release[]>();
  const newestFirst = [...releases].sort((a, b) =>
    b.date.localeCompare(a.date) || b.version.localeCompare(a.version, "en", { numeric: true }));
  for (const release of newestFirst) {
    const sameDay = days.get(release.date) ?? [];
    sameDay.push(release);
    days.set(release.date, sameDay);
  }
  return [...days.values()].map(([release, ...earlier]) => ({ release, earlier }));
}

// These previews all shipped on November 20 in America/Caracas.
export const WINDOWS_RELEASES: Release[] = [
  {
    version: "0.1.4",
    date: "2026-11-20",
    title: "Keep your balance by the Windows clock.",
    summary: "Pocket for Windows 11 opens from the tray. Check your balance, log an expense or income, or open Pocket for History, Plan, Subscriptions and Categories.",
    theme: "update",
    highlights: [
      { title: "Choose how your balance appears", description: "Right-click Pocket and choose Balance display. Balance on hover shows the exact amount on the tray icon. Floating panel keeps it visible above the clock. Click either to open Quick Entry." },
      { title: "Search and export History", description: "Filter your entries, export all entries or the current results as CSV, compare completed months, and choose your display currency." },
      { title: "Plan ahead and back up", description: "See spending and income by category, include everyday spending in your forecast, manage quick-add buttons, and export or restore a Pocket JSON backup." },
      { title: "Keep using Pocket offline", description: "A synced ledger keeps a copy on your PC. Changes made offline wait in Settings and sync when you reconnect. Pocket can remind you about payments and subscription renewals while it runs in the tray." },
      { title: "Choose where to install", description: "One unsigned Setup works for Windows 11 on Intel, AMD and ARM. Choose an install folder, add a desktop shortcut, or start Pocket at sign-in. Setup adds a Start menu shortcut and keeps your ledger in your Windows profile." },
    ],
    detailsTitle: "Earlier previews and installation",
    details: [
      "The first preview offered separate x64 and ARM64 ZIPs, a local offline ledger, and amounts displayed in USD.",
      "The installer replaced the ZIPs and added install location and shortcut options. If Setup stops, look for the operation and folder in %TEMP%\\Pocket-Setup.log.",
      "Early builds introduced the balance above the clock and tried an abbreviated tray number and an icon-only mode. The 0.1.4 preview offers balance on hover and a floating panel.",
      "To remove Pocket, open Settings → Apps → Installed apps.",
    ],
    source: "https://github.com/orlandoascanio/pocketleft/releases/tag/windows-preview-6",
    relatedSources: [
      { title: "Display options preview", url: "https://github.com/orlandoascanio/pocketleft/releases/tag/windows-preview-5" },
      { title: "Balance above the clock", url: "https://github.com/orlandoascanio/pocketleft/releases/tag/windows-preview-4" },
      { title: "Setup with install options", url: "https://github.com/orlandoascanio/pocketleft/releases/tag/windows-preview-3" },
      { title: "Preview installer", url: "https://github.com/orlandoascanio/pocketleft/releases/tag/windows-preview-2" },
      { title: "First Windows preview", url: "https://github.com/orlandoascanio/pocketleft/releases/tag/windows-preview-1" },
    ],
  },
];

export const releaseDate = (date: string, locale: Locale = "en") => new Intl.DateTimeFormat(locale, {
  month: "long", day: "numeric", year: "numeric", timeZone: "UTC",
}).format(new Date(`${date}T12:00:00Z`));
