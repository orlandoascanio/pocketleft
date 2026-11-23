import { RELEASES } from "@/lib/releases";
import { DMG_SIZE, DOWNLOAD_PAGE, REPO_URL, VERSION, WINDOWS_VERSION } from "@/lib/site";

// The plain facts about Pocket, shared by /about/ and /llms.txt so they can't disagree.
// Values can link with [label](url), like guide text.
export type Fact = { label: string; value: string };

export const FACTS: Fact[] = [
  { label: "Price", value: "Free. Every feature, with no account and no trial." },
  { label: "Mac", value: "macOS 14 Sonoma or later on Apple Silicon and Intel. Developer-signed and Apple-notarized." },
  { label: "Latest Mac version", value: `${VERSION} (${RELEASES[0].date}) · ${DMG_SIZE}. [Mac installer and setup](${DOWNLOAD_PAGE}#mac)` },
  { label: "Windows", value: `[Pocket ${WINDOWS_VERSION} preview](${DOWNLOAD_PAGE}#windows) for Windows 11 on Intel, AMD, and ARM PCs. The preview installer is unsigned.` },
  { label: "How it works", value: "You record money in and out by hand. Pocket does not connect to banks." },
  {
    label: "Balance forecast",
    value: "Plan estimates how your balance could change over 1, 3, 6 or 12 months based on the bills and income you've scheduled. On Mac, it can include a typical week of everyday spending from your recent entries.",
  },
  {
    label: "Available until payday",
    value: "On Mac, choose a payday and a minimum balance to keep. Pocket subtracts your cushion from the lowest projected balance before payday. The estimate includes usual spending when you have enough history and leaves out income awaiting confirmation. [Set your payday and cushion](/guides/freelance-income/#before-payday).",
  },
  {
    label: "Quick Entry on Mac",
    value: "Click Undo on the confirmation to reverse the entry you just added. Choose Hide Balance from the menu bar panel’s More menu to keep the amount private while you log entries. [Hide the menu bar balance](/guides/menu-bar-balance/#screen-sharing).",
  },
  {
    label: "Subscription reminders",
    value: "Mac renewal reminders are free. Enter a service by hand and enable notifications. The default is two days before renewal at 10 a.m. Choose 1–365 days and a time, or set a one-time reminder for a particular renewal. [Set up renewal reminders](/guides/track-subscriptions/#renewal-reminders).",
  },
  {
    label: "Data",
    value: "The ledger stays on your device by default. On Mac, Pocket stores it in ~/Library/Application Support/Pocket/ledger.json, keeps seven daily backups, and supports JSON import and export and CSV export.",
  },
  {
    label: "Optional sync",
    value: "Set up a Supabase project you run and [pair your phone](/guides/self-hosting/) to use the same ledger in the Pocket web app. Local use on Mac works offline without a Pocket account.",
  },
  { label: "Currencies", value: "Any standard currency, one per ledger. Changing it relabels amounts; it does not convert them." },
  {
    label: "Phone access",
    value: "Pair your phone to use the Pocket web app once you've set up sync. [Web app setup and pairing](/download/#web).",
  },
  { label: "Made by", value: "[Orlando Ascanio](https://www.orlandoascanio.com), an independent developer." },
  { label: "Source code", value: `View Pocket's public source on [GitHub](${REPO_URL}).` },
];

// Answer-first summary for /about/: the passage an answer engine is most likely to quote.
export const AT_A_GLANCE =
  "Pocket for Mac (PocketLeft) is a free, offline expense tracker at pocketleft.app. Enter income and expenses by hand to see your recorded balance beside the Mac clock. Plan estimates what you'll have left after upcoming bills and income. Pocket keeps your ledger on your Mac by default and works without a bank connection or account.";
