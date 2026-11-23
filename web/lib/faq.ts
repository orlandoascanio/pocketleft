import { SELF_HOSTING_GUIDE_URL } from "@/lib/site";

export type FaqItem = { q: string; a: string; link?: { href: string; label: string } };

// Shared by the homepage, its FAQPage schema, and /llms.txt.
export const FAQ: FaqItem[] = [
  { q: "Is Pocket free?", a: "You can use every feature for free, without an account. The source code is on GitHub." },
  {
    q: "Is there a Mac app that shows my balance in the menu bar?",
    a: "Pocket shows your recorded balance beside the Mac clock. Click the balance to log an expense or income.",
    link: { href: "/guides/menu-bar-balance/", label: "Set up your Mac menu bar balance" },
  },
  {
    q: "Does Pocket connect to my bank?",
    a: "Pocket does not connect to banks. You enter income and spending by hand, and Pocket can record repeating payments on their due dates. On Mac, use ⌘1 through ⌘9 to log purchases you’ve saved as quick-add buttons.",
    link: { href: "/guides/manual-vs-bank-sync/", label: "Compare manual tracking with bank sync" },
  },
  {
    q: "Can Pocket forecast what I'll have left after bills?",
    a: "Yes. Plan estimates your balance for the next 1, 3, 6 or 12 months using the bills and income you schedule. An invoice can appear in Plan while your recorded balance stays the same until you confirm it arrived. If a payment date or amount changes, update it to see the effect on your forecast.",
    link: { href: "/guides/freelance-income/", label: "See a forecast with a late invoice" },
  },
  {
    q: "Is Pocket a YNAB alternative?",
    a: "YNAB lets you set spending and savings targets by category. Pocket adds up the entries you log and uses planned payments to forecast your balance.",
  },
  {
    q: "Where is my money data stored?",
    a: "On Mac, Pocket stores your ledger in ~/Library/Application Support/Pocket/ledger.json and keeps seven daily backups. On Windows, your local ledger stays in your Windows user profile. In Settings, you can restore a local backup, import a ledger, export JSON or CSV, or erase your local ledger.",
  },
  {
    q: "Can I see my balance on my phone?",
    a: "Connect Pocket to your own free Supabase project and pair your phone from Settings → Sync. Your balance appears in the Pocket web app. Your Mac keeps a copy you can use offline.",
    link: { href: SELF_HOSTING_GUIDE_URL, label: "Read the self-hosting guide" },
  },
  {
    q: "Which currencies does it support?",
    a: "Choose a standard currency for each ledger. Switching currency changes the labels and keeps the amounts you entered.",
  },
  {
    q: "Which Macs does it run on?",
    a: "Pocket runs on macOS 14 Sonoma or later, on Apple Silicon and Intel Macs. The Mac app is developer-signed and Apple-notarized. To update, choose Check for Updates… in the Pocket menu or Settings → About, then Install and Relaunch.",
  },
  {
    q: "How do I move Pocket to a new Mac?",
    a: "Export your data from Settings on the old Mac, then import that file on the new one.",
    link: { href: "/guides/back-up-your-data/", label: "Read the backup and move guide" },
  },
  {
    q: "Is Pocket for Mac related to Mozilla Pocket?",
    a: "Orlando Ascanio makes Pocket, the money app at pocketleft.app. Mozilla’s Pocket was an app for saving articles to read later.",
    link: { href: "/about/", label: "About Pocket" },
  },
  {
    q: "Is there a Windows or iPhone app?",
    a: "Pocket has a Windows 11 preview. On iPhone, you can use the Pocket web app once you’ve set up sync and add it to your home screen.",
    link: { href: "/download/", label: "See download and pairing options" },
  },
];
