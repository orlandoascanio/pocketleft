import { REPO_URL, SELF_HOSTING_GUIDE_URL, SELF_HOSTING_URL } from "@/lib/site";

// Guide text can link with [label](/path/). Pages render real links; llms.txt spells out the URL.
const LINK = /\[([^\]]+)\]\(([^)\s]+)\)/g;
export type TextPart = { text: string; href?: string };

export function textParts(text: string): TextPart[] {
  const parts: TextPart[] = [];
  let last = 0;
  for (const match of text.matchAll(LINK)) {
    if (match.index > last) parts.push({ text: text.slice(last, match.index) });
    parts.push({ text: match[1], href: match[2] });
    last = match.index + match[0].length;
  }
  if (last < text.length) parts.push({ text: text.slice(last) });
  return parts;
}

export type GuideSection = {
  id: string;
  title: string;
  paragraphs: string[];
  steps?: string[];
  note?: string;
  table?: { label: string; headings: string[]; rows: string[][] };
};

export type Guide = {
  slug: string;
  title: string;
  /** Shown on the page as the lead paragraph. */
  description: string;
  /** Search-result description when `description` runs past 160 characters. */
  metaDescription?: string;
  category: string;
  minutes: number;
  published: string;
  updated: string;
  image: string;
  imageAlt: string;
  imageWidth?: number;
  imageHeight?: number;
  video?: string;
  poster?: string;
  related: string[];
  sections: GuideSection[];
};

export const GUIDES: Guide[] = [
  {
    slug: "getting-started",
    title: "Get started with Pocket for Mac",
    description: "Set your starting balance, record your first purchase and add a bill in Pocket for Mac.",
    category: "Start here",
    minutes: 4,
    published: "2026-10-13",
    updated: "2026-10-13",
    image: "/screenshot-overview.png",
    imageAlt: "Pocket Overview with the recorded balance, the entry field, a payment waiting for confirmation and history",
    related: ["quick-add-spending", "expected-income", "back-up-your-data"],
    sections: [
      {
        id: "starting-balance",
        title: "Start with the money you have today",
        paragraphs: [
          "Pocket is a manual money tracker for macOS. Its menu bar balance comes from your starting amount and the entries you record. It does not read your bank account.",
          "Choose which money you want to track, such as the balance in your everyday spending account. Record money coming into and going out of that account, and use one currency.",
        ],
        steps: [
          "Download Pocket from pocketleft.app, open the disk image and drag Pocket into Applications. Open the app.",
          "Enter your current amount. Choose “I'm below zero by” if you are starting with a negative balance. An empty amount starts at zero.",
          "Choose your currency. Pocket uses one currency at a time. Changing it later changes the label without converting the amounts.",
          "Choose whether Pocket should open when you log in, then click Start. Your recorded balance appears in the menu bar.",
        ],
        note: "If today's balance already includes an old purchase or paycheck, entering that transaction again changes the balance twice. Start from today and record changes from that point onward.",
      },
      {
        id: "first-entry",
        title: "Record one purchase and check the balance",
        paragraphs: ["Click the menu bar balance to open Pocket, or use the entry field in Overview. Keep the minus button selected for spending, then enter the amount and describe the purchase. Choose a category from the icon to the left of the description. Press Return to save."],
        table: {
          label: "Balance after each entry",
          headings: ["Entry", "Change", "Recorded balance"],
          rows: [["Starting amount", "$500.00", "$500.00"], ["Coffee", "−$4.50", "$495.50"], ["Money received", "+$120.00", "$615.50"]],
        },
        note: "A missing or duplicate entry can make Pocket's balance differ from your bank's.",
      },
      {
        id: "first-plan",
        title: "Add one upcoming bill",
        paragraphs: [
          "Click Date & repeat under the description, or press Command-N in the Pocket window. It opens the full entry form, where you can set the date, category and repeat schedule. Enter the bill's amount, description and next date. Choose Repeat for a weekly, every-two-weeks, monthly or yearly payment. Leave the number of payments empty if it has no end date.",
          "An automatic payment counts on its date. Turn on Confirm each payment if you want to record the actual amount and date yourself. Those payments wait under Waiting for you in Overview, with Paid and Skip buttons. For income that might arrive late or smaller, see [Track expected income before it arrives](/guides/expected-income/).",
          "Open Plan to see your projected balance after each scheduled payment. The chart includes only the money you have recorded or planned.",
        ],
      },
      {
        id: "keep-current",
        title: "Check for missing or duplicate entries",
        paragraphs: [
          "Compare Pocket's balance with the account you used for your starting amount. If they differ, check for missing entries, duplicates and incorrect dates. Click an entry in History to edit or delete it.",
          "When you add a purchase you make often, choose Save as Button in the confirmation under the entry field. The [quick-add guide](/guides/quick-add-spending/) covers fixed and variable amounts. Then add your remaining upcoming bills and income.",
        ],
      },
    ],
  },
  {
    slug: "quick-add-spending",
    title: "Track everyday spending with quick-add buttons",
    description: "Turn a frequent purchase into a quick-add button in Pocket, use Command-1 through Command-9 and choose when a button should ask for the amount.",
    category: "Everyday spending",
    minutes: 3,
    published: "2026-10-13",
    updated: "2026-10-13",
    image: "/media/quick-add-2026-10-12.jpg",
    imageAlt: "Pocket quick-add buttons above the spending entry field",
    video: "/media/quick-add-2026-10-12.mp4",
    poster: "/media/quick-add-2026-10-12.webp",
    related: ["getting-started", "expected-income"],
    sections: [
      {
        id: "fixed-amount",
        title: "Save a purchase you make often",
        paragraphs: [
          "Quick-add buttons reuse an entry's description, type and category. Save an amount to record the purchase immediately, or leave it empty to enter a price each time.",
          "A Coffee button with an amount of 4.50 records a 4.50 purchase each time you use it. Create it when you record your next coffee.",
        ],
        steps: [
          "Record the purchase as usual: enter 4.50, describe it as Coffee, choose a category from the icon to the left of the description and press Return.",
          "In the confirmation under the entry field, choose Save as Button. Pocket makes a Coffee button with the same amount and category.",
          "Use the button for your next coffee. A button with a fixed amount adds the entry immediately.",
        ],
        note: "Save as Button doesn't record another purchase. You can also right-click an entry in History and choose Save as Quick-Add Button, or turn on Also save as a quick-add button in the full entry form.",
      },
      {
        id: "variable-amount",
        title: "Ask for the amount when the price changes",
        paragraphs: [
          "For groceries, rides or anything with a changing price, open Settings and edit its quick-add button. Leave the amount empty and save the button.",
          "The next time you use it, Pocket fills in the description and category and asks you for the amount. Enter what you actually spent, then save the entry.",
          "To make a button from scratch, open Settings, find Quick-add buttons and choose Add Button, then Spending Button or Money In Button. Use a Money In button for income such as client payments whose amounts vary. For a payment you expect on a particular date, [schedule it as expected income](/guides/expected-income/) instead.",
        ],
      },
      {
        id: "keyboard",
        title: "Use Command-1 through Command-9",
        paragraphs: [
          "Command-1 through Command-9 use the first nine quick-add buttons, from the menu bar panel or any page of the Pocket window. The Quick Add menu at the top of the screen lists every button with its shortcut.",
          "Drag buttons in Settings to change their order. If you press the wrong shortcut, click Edit in the confirmation, or find the new entry in History and edit or delete it.",
        ],
      },
      {
        id: "review",
        title: "Review the entries behind the total",
        paragraphs: [
          "A quick-add button records one entry per use. If the price changes, update its saved amount in Settings.",
          "In Categories, Where it went breaks down your spending and Where it came from breaks down your income. Click a category to see its entries. The breakdown uses the categories you assigned.",
        ],
      },
    ],
  },
  {
    slug: "expected-income",
    title: "Track expected income before it arrives",
    description: "Schedule a client payment in Pocket, then confirm the amount and date when it arrives. Follow a $300 payment that arrives late as $280.",
    category: "Upcoming money",
    minutes: 4,
    published: "2026-10-13",
    updated: "2026-10-13",
    image: "/screenshot-plan.png",
    imageAlt: "Pocket Plan with scheduled payments and a projected balance chart",
    related: ["getting-started", "quick-add-spending"],
    sections: [
      {
        id: "two-numbers",
        title: "Keep today's balance and the forecast separate",
        paragraphs: [
          "Schedule a client payment for its expected amount and date, and turn on confirmation. Pocket will wait for you to confirm it before adding the income to your recorded balance.",
          "Your menu bar balance shows recorded money. Plan includes scheduled payments, including income you are still waiting for.",
        ],
      },
      {
        id: "schedule-income",
        title: "Schedule a payment that needs confirmation",
        paragraphs: ["Click Date & repeat under the description to open the full entry form. Set a future date or choose a repeating schedule to see the confirmation setting."],
        steps: [
          "Choose Got money and enter the expected amount, such as 300.00, with a description such as Client payment.",
          "Set the expected date. Leave Repeat at Once for a single payment, or choose how often it repeats.",
          "Check that Confirm when money arrives is on. It starts on for new income. Save, then check Plan for the scheduled payment.",
          "When the payment is due, it appears under Waiting for you in Overview, and the menu bar panel shows how many payments are waiting. Leave it there until you receive the money.",
        ],
        note: "If confirmation is turned off, Pocket counts the scheduled amount automatically on its date. Choose confirmation for payments whose arrival or amount is uncertain.",
      },
      {
        id: "already-due",
        title: "Track money that is already owed",
        paragraphs: [
          "Some money has no future date: a friend who owes you, or a refund that should have arrived. Open the full entry form, choose Got money, keep today's date (or the day it was due) and turn on I'm still waiting for this money. Choose Add to Waiting.",
          "It goes straight to Waiting for you, and your recorded balance stays the same until you confirm it. For a bill you owe but haven't paid yet, choose Spent and turn on I haven't paid this yet.",
        ],
      },
      {
        id: "late-payment",
        title: "Confirm what actually arrived",
        paragraphs: [
          "Suppose you start with $500 and expect $300 on October 20. With confirmation enabled and no other entries, your recorded balance stays at $500 until you confirm the payment.",
          "If $280 arrives on October 23, click Got it on the waiting payment in Overview. Change the amount to 280.00 and the date to October 23, then click Log It. Pocket records the actual amount and date. If the money never comes, click Skip instead.",
        ],
        table: {
          label: "Recorded balance before and after confirming income",
          headings: ["Event", "Recorded balance"],
          rows: [["Starting amount", "$500.00"], ["$300 expected for October 20", "$500.00"], ["Due, still waiting for confirmation", "$500.00"], ["Confirm $280 received on October 23", "$780.00"]],
        },
        note: "Confirming the waiting payment creates the income entry. Do not also add a separate Got money entry for the same payment, or you will count it twice.",
      },
      {
        id: "forecast-limits",
        title: "Update the plan when expectations change",
        paragraphs: [
          "If a payment will come later, click it in Plan and change its date. To skip the next payment, pause a repeating one or stop it, use the ⋯ button next to it in Plan.",
          "Check uncertain income and [missing or duplicate entries](/guides/getting-started/#keep-current) before relying on the forecast. Pocket projects the amounts and dates you enter. Once you have two weeks of entries, Plan also takes out your usual everyday spending (you can turn that off under the chart); one-off purchases you have not recorded or planned are left out.",
        ],
      },
    ],
  },
  {
    slug: "menu-bar-balance",
    title: "Keep your money balance in the Mac menu bar",
    description: "Pocket puts the money you have left in the Mac menu bar. See what the number counts, add spending from the menu bar panel and keep it visible on a Mac with a notch.",
    metaDescription: "Pocket puts the money you have left in the Mac menu bar. See what the number counts, add spending from the panel and keep it visible on a notched Mac.",
    category: "Start here",
    minutes: 3,
    published: "2026-10-13",
    updated: "2026-10-13",
    image: "/screenshot-overview.png",
    imageAlt: "Pocket for Mac with the recorded balance that also appears in the menu bar",
    related: ["getting-started", "mac-menu-bar-money-apps", "manual-vs-bank-sync"],
    sections: [
      {
        id: "what-it-shows",
        title: "What the menu bar number counts",
        paragraphs: [
          "Pocket is a free Mac app that shows your balance as a number in the menu bar, next to the clock. The number is your recorded balance: the starting amount you entered, plus income and minus spending you have recorded since.",
          "Repeating bills and paychecks that you set to count automatically are added on their day. Payments that wait for confirmation leave the number unchanged until you click Got it. Pocket never reads your bank account, so the number includes only what you record.",
        ],
        note: "If Pocket can't open its data file, the menu bar shows “Pocket ⚠︎” instead of an amount. Open Settings to restore a daily backup.",
      },
      {
        id: "panel",
        title: "Add spending from the menu bar",
        paragraphs: [
          "Click the number to open the menu bar panel. The amount field is ready as soon as it opens: type the amount, a description and press Return. Your quick-add buttons sit above it, and Command-1 through Command-9 use the first nine.",
          "Under Money left, a forecast line says “Runs out on” or “Lasts past” a date, based on the payments you have scheduled and your usual everyday spending. Click it to open Plan. The panel also shows how many payments are waiting for you and your three most recent entries.",
        ],
        table: {
          label: "Keyboard shortcuts in the menu bar panel",
          headings: ["Shortcut", "What it does"],
          rows: [
            ["Command-1 to Command-9", "Use one of the first nine quick-add buttons"],
            ["Command-N", "Clear the entry field to start a new entry"],
            ["Command-O", "Open the Pocket window"],
            ["Command-comma", "Open Settings"],
            ["Command-Q", "Quit Pocket"],
          ],
        },
      },
      {
        id: "login",
        title: "Keep the balance there after a restart",
        paragraphs: ["Pocket asks whether to open at login the first time you start it. To change your answer later:"],
        steps: [
          "Click the number in the menu bar, then press Command-O to open the Pocket window.",
          "Open Settings and turn Open at login on or off.",
        ],
      },
      {
        id: "notch",
        title: "If the number is hidden behind the notch",
        paragraphs: [
          "On MacBooks with a camera notch, macOS hides menu bar items that don't fit, starting with the ones furthest from the right. Pocket keeps running; you just can't see it.",
          "Hold Command and drag menu bar items to reorder them. Move Pocket closer to Control Center, or remove items you don't use, until the number fits. Recent versions of macOS also let you switch items off in System Settings → Menu Bar.",
        ],
      },
      {
        id: "screen-sharing",
        title: "When other people can see your screen",
        paragraphs: [
          "The amount is visible to anyone who can see your menu bar. Pocket has no setting to hide it. Before presenting or sharing your screen, choose Quit Pocket from the ⋯ menu in the panel. Your entries are saved, and the balance comes back when you open Pocket again.",
        ],
      },
    ],
  },
  {
    slug: "manual-vs-bank-sync",
    title: "Manual money tracking vs bank sync: which one fits",
    description: "Bank-sync apps import transactions for you. Manual trackers like Pocket count only what you enter. When each works better, and how to keep a manual budget accurate without a bank connection.",
    metaDescription: "Bank-sync apps import transactions; manual trackers like Pocket count only what you enter. When each works better, and how to stay accurate without a bank.",
    category: "Choosing an approach",
    minutes: 5,
    published: "2026-10-13",
    updated: "2026-10-13",
    image: "/screenshot-overview.png",
    imageAlt: "Pocket for Mac Overview, where every entry was typed by hand",
    related: ["getting-started", "quick-add-spending", "expected-income"],
    sections: [
      {
        id: "difference",
        title: "What's the difference?",
        paragraphs: [
          "A bank-sync app connects to your bank, usually through a third-party data provider, and imports transactions automatically. A manual money tracker has no bank connection: you record each purchase and payment yourself, and the balance comes from those entries. Pocket for Mac is a manual tracker.",
          "Neither is more accurate by default. Bank sync misses what its connection misses; a manual tracker misses what you forget to enter.",
        ],
        table: {
          label: "Manual tracking compared with bank sync",
          headings: ["Compared on", "Manual tracking", "Bank sync"],
          rows: [
            ["How transactions arrive", "You type them, or a saved button or repeating payment adds them", "Imported from the bank, often a day or more after the purchase"],
            ["What you share", "Nothing, unless you choose to", "Bank sign-in access or a token for your accounts, held by the app and its data provider"],
            ["When it goes wrong", "A forgotten or duplicate entry", "A broken connection, a missing account or a misread category"],
            ["Cash and informal money", "Recorded like anything else", "Not seen unless you add it by hand"],
            ["Money not yet received", "Can be marked as waiting", "Usually appears only once it clears"],
            ["Effort", "A few seconds per purchase", "Mostly reviewing and fixing categories"],
          ],
        },
      },
      {
        id: "when-manual",
        title: "When manual tracking works better",
        paragraphs: [
          "Manual tracking suits people who watch one balance, such as an everyday spending account, rather than every account they own. It also fits if you would rather not give a bank-sync app access to your bank, if bank-sync apps don't support your bank or country, or if a lot of your money moves outside the bank: cash, transfers between friends, or client payments that arrive at unpredictable times.",
          "You also see the new balance the moment you spend, rather than when the transaction clears.",
        ],
      },
      {
        id: "when-sync",
        title: "When bank sync works better",
        paragraphs: [
          "Choose bank sync if you need a full history across many accounts and cards, if you make so many transactions that typing them would be a chore, or if you need categorized records for taxes or bookkeeping.",
          "If you know you won't record purchases, a manual tracker's balance will drift from your bank's, and a bank-sync app will serve you better.",
        ],
      },
      {
        id: "keep-accurate",
        title: "How to keep a manual tracker accurate with little effort",
        paragraphs: ["Most of the work in manual tracking can be set up once. In Pocket:"],
        steps: [
          "Track one account. Start from that account's balance today and don't re-enter older transactions.",
          "Schedule bills, subscriptions and paychecks as repeating payments, so they log themselves on their day.",
          "Turn the purchases you make often into [quick-add buttons](/guides/quick-add-spending/), then use Command-1 to Command-9.",
          "Mark uncertain money as waiting, so it only counts once you [confirm it arrived](/guides/expected-income/).",
          "Once a week, compare Pocket's balance with your bank's. If they differ, look for a missing or duplicate entry and fix it in History.",
        ],
      },
      {
        id: "pocket",
        title: "Where Pocket fits",
        paragraphs: [
          "Pocket is manual only. It keeps one balance in one currency, saves it in a file on your Mac and doesn't ask for an account. It shows that balance in the menu bar, and Plan forecasts when it would run out. It doesn't import bank statements, convert currencies or combine several accounts.",
          "If that matches how you want to track money, [get started with Pocket](/guides/getting-started/).",
        ],
      },
    ],
  },
  {
    slug: "mac-menu-bar-money-apps",
    title: "Mac menu bar money apps compared",
    description: "Three Mac apps keep money in the menu bar: simplebanking shows a German or EU bank balance, Up Only tracks net worth, and Pocket counts what you enter. What each one does, what it costs and which fits.",
    metaDescription: "Three Mac apps keep money in the menu bar: simplebanking, Up Only and Pocket. What each one shows, what it costs and which one fits you.",
    category: "Choosing an approach",
    minutes: 5,
    published: "2026-10-17",
    updated: "2026-10-17",
    image: "/screenshot-overview.png",
    imageAlt: "Pocket for Mac Overview, showing the balance that also appears in the menu bar",
    related: ["menu-bar-balance", "manual-vs-bank-sync", "getting-started"],
    sections: [
      {
        id: "short-answer",
        title: "The short answer",
        paragraphs: [
          "Few Mac apps put money in the menu bar. As of October 2026, three are available: simplebanking, Up Only and Pocket. simplebanking shows a live bank balance for German and some other European banks. Up Only tracks cash flow and net worth, and you build it yourself. Pocket shows the money you have left from entries you type, in any country and currency.",
          "Pocket is made by the author of this page, so read the comparison with that in mind. Facts about the other apps come from their public pages, linked below, checked on October 17, 2026.",
        ],
        table: {
          label: "Mac menu bar money apps compared, October 2026",
          headings: ["Feature", "Pocket", "simplebanking", "Up Only"],
          rows: [
            ["In the menu bar", "Money left", "Bank balance", "Cash flow, net worth"],
            ["How entries arrive", "You type them", "Bank connection", "You type them or import CSV"],
            ["Banks and countries", "Any, no bank needed", "Germany, some EU banks, UK", "Any, no bank needed"],
            ["Price", "Free", "Free download", "Free, MIT license"],
            ["How to install", "Signed .dmg", "Download from its website", "Build with Xcode"],
            ["macOS", "14 or later", "13 or later", "26 or later"],
            ["Data", "One file on your Mac", "Read-only via YAXI", "Encrypted vault on your Mac"],
            ["Looks ahead", "12-month forecast, runs-out date", "Bills, recurring debits", "Not described"],
          ],
        },
      },
      {
        id: "simplebanking",
        title: "simplebanking: a live bank balance in Germany and the EU",
        paragraphs: [
          "[simplebanking](https://www.producthunt.com/products/simplebanking) shows your bank balance in the menu bar and lists recent transactions when you click it. It connects through YAXI, a regulated open-banking provider with read-only access. It covers nearly all German banks, a growing list in Austria, France, Italy, Spain, the Netherlands, Belgium, Luxembourg and the UK, and PayPal. It detects recurring debits, and version 2.0 added bills.",
          "It's a free download from simplebanking.de, its source code is on GitHub, and it needs macOS 13 or later, according to [its launch coverage](https://www.mobiflip.de/simplebanking-bringt-den-kontostand-auf-den-mac/amp/). Choose it if your bank is supported and you want transactions to appear without typing them.",
        ],
      },
      {
        id: "up-only",
        title: "Up Only: cash flow and net worth, built from source",
        paragraphs: [
          "[Up Only](https://github.com/rileytonkin/uponly) is an open-source menu bar app for monthly cash flow and net worth. You add bank balances, crypto, gold and silver, and single income or expense entries by hand, or import bank statements as CSV files. Everything sits in one encrypted vault on your Mac, unlocked with Touch ID or your password, with no account or cloud sync.",
          "It has no published release yet: you build it with Xcode 26.6 on macOS 26 or later. Choose it if you want net worth across several kinds of assets and you're comfortable building an app yourself.",
        ],
      },
      {
        id: "pocket",
        title: "Pocket: the money you have left, from what you enter",
        paragraphs: [
          "Pocket shows your recorded balance in the menu bar: the amount you started with, plus income and minus spending you've recorded. Bills and paychecks can repeat on their own, and money you're still waiting for stays out of the balance until you [confirm what arrived](/guides/expected-income/). Plan forecasts your balance for up to 12 months and shows the date it would run out.",
          "It's free, signed and notarized by Apple, and runs on macOS 14 or later, on Apple Silicon and Intel. Your data stays in one file on your Mac. Choose it if you want one number you can always see, your bank isn't covered by sync services, or you'd rather not link a bank account.",
          "The tradeoff: Pocket imports nothing. If you forget to record a purchase, the number is off until you add it. [Quick-add buttons](/guides/quick-add-spending/) keep that to one keystroke for things you buy often.",
        ],
      },
      {
        id: "balance",
        title: "What happened to Balance?",
        paragraphs: [
          "[Balance](https://www.macstories.net/reviews/balance-brings-financial-accounts-to-the-macs-menu-bar/) was the best-known Mac menu bar finance app. It connected bank, card and brokerage accounts through Plaid and charged by the number of accounts. It's [no longer available](https://www.makeuseof.com/tag/monitor-bank-balance-mac-menu-bar/), so it isn't in the table.",
        ],
      },
      {
        id: "not-included",
        title: "Apps that aren't in this comparison",
        paragraphs: [
          "My Pockets and Money Counter track money on a Mac, but their App Store listings don't mention a menu bar item. Full budgeting apps such as YNAB work in a window or a browser. If you're deciding between typing entries and importing them from your bank, read [manual tracking vs bank sync](/guides/manual-vs-bank-sync/).",
        ],
        note: `Something here out of date, or a menu bar money app missing? [Open an issue on GitHub](${REPO_URL}/issues) and this page will be corrected.`,
      },
    ],
  },
  {
    slug: "freelance-income",
    title: "Plan around irregular freelance income on a Mac",
    description: "A weekly routine for irregular income: spend from money that has arrived, keep unpaid invoices in the forecast, and see the date your balance would run out if a client pays late.",
    metaDescription: "A weekly routine for irregular income: spend only money that has arrived, keep unpaid invoices in the forecast and see when a late payment would run you dry.",
    category: "Upcoming money",
    minutes: 5,
    published: "2026-10-13",
    updated: "2026-10-13",
    image: "/screenshot-plan.png",
    imageAlt: "Pocket Plan with expected client payments, bills and a projected balance chart",
    related: ["expected-income", "manual-vs-bank-sync", "quick-add-spending"],
    sections: [
      {
        id: "two-numbers",
        title: "Keep two numbers: received and expected",
        paragraphs: [
          "When income is irregular, the money you have and the money you're owed are different numbers. Spend only from money you've received, and plan with both.",
          "In Pocket, the menu bar shows only money you've recorded as received. Unpaid invoices go into Plan as expected payments, and they count toward your balance only after you confirm them.",
        ],
      },
      {
        id: "set-up",
        title: "Set up your bills and invoices",
        paragraphs: [],
        steps: [
          "Start Pocket with the balance of the account your clients pay into.",
          "Add rent, subscriptions and other fixed costs as repeating payments. Leave Confirm each payment off for bills that are always the same.",
          "For each invoice you send, open the full entry form with Date & repeat, choose Got money, enter the amount and the date you expect it, and keep Confirm when money arrives on.",
          "For a retainer, choose Repeat → Monthly with confirmation on, so each month's payment waits for you to confirm the actual amount.",
        ],
      },
      {
        id: "read-plan",
        title: "Read the forecast, then test a late payment",
        paragraphs: [
          "Plan's header says “Runs out on” a date if your balance would drop below zero in the range you chose, or “Lasts past” a date if it wouldn't. The line below it shows the balance at the end of the range and the lowest point on the way. Choose 3M or 6M for freelance work.",
          "The forecast assumes every invoice arrives on time. To see what a late client would do, click an upcoming payment in Plan and move its date. In this example, it's early October, the balance is $700 and Client A's $1,200 invoice is due October 15:",
        ],
        table: {
          label: "Forecast balance when one client pays late",
          headings: ["Date and payment", "Client A pays Oct 15", "Client A pays Nov 20"],
          rows: [
            ["Oct 15: Client A due, +$1,200", "$1,900.00", "$700.00"],
            ["Oct 28: Software −$30", "$1,870.00", "$670.00"],
            ["Nov 1: Rent −$900", "$970.00", "−$230.00"],
            ["Nov 5: Client B +$800", "$1,770.00", "$570.00"],
            ["Nov 20: Client A +$1,200 (late)", "$1,770.00", "$1,770.00"],
          ],
        },
        note: "With the late date, Plan says “Runs out on Nov 1”. That gives you time to chase the invoice, move a bill or hold off on spending. Set the date back if the client confirms they'll pay on time.",
      },
      {
        id: "weekly",
        title: "A weekly check",
        paragraphs: [],
        steps: [
          "Open Overview. For each payment under Waiting for you that has arrived, click Got it and enter the amount and date that actually landed. Click Skip for any that won't come.",
          "An invoice that is past due stays under Waiting for you, and Plan counts it as arriving today. If you don't expect it soon, click Skip and add it again with the new expected date, so the forecast no longer counts it as arriving today.",
          "Add any invoices you sent this week.",
          "Compare Pocket's balance with your bank. Fix missing or duplicate entries in History.",
          "Check the Plan header. If it says “Runs out on”, decide what to change before that date.",
        ],
        note: "Pocket sends a reminder at 10 a.m. on the day a payment that needs confirmation is due, asking whether it paid. Allow notifications when Pocket asks, or turn reminders on in Settings.",
      },
      {
        id: "limits",
        title: "What the forecast leaves out",
        paragraphs: [
          "Pocket projects only what you've entered. Everyday spending you haven't planned, taxes you haven't scheduled and invoices you haven't added aren't in the chart. If you set money aside for taxes in another account, leave it out of the balance you track, or schedule the tax payment so the forecast includes it.",
        ],
      },
    ],
  },
  {
    slug: "back-up-your-data",
    title: "Back up Pocket and move to a new Mac",
    description: "Find Pocket's data file, restore a daily backup, export a JSON backup and import it on another Mac. See how optional sync changes the setup.",
    category: "Your data",
    minutes: 3,
    published: "2026-10-13",
    updated: "2026-10-13",
    image: "/screenshot-overview.png",
    imageAlt: "Pocket for Mac, whose local entries can be exported from Settings",
    related: ["getting-started", "self-hosting"],
    sections: [
      {
        id: "local-file",
        title: "Find your data file",
        paragraphs: [
          "Pocket saves your money data on your Mac by default. You can use the local app without an account. Entries, planned payments and quick-add buttons are saved together.",
          "Open Settings and click Show in Finder next to Data file. In local mode, the file is normally ~/Library/Application Support/Pocket/ledger.json.",
          "Pocket keeps seven daily backups in its data folder on the same Mac. Keep an exported copy elsewhere so you can recover it if you lose the computer or its drive.",
        ],
      },
      {
        id: "restore",
        title: "Restore a daily backup",
        paragraphs: ["Use a daily backup to undo a mistake, such as an import or an erase you didn't mean to do. Each backup is a copy of your data from the first change Pocket saved that day."],
        steps: [
          "Open Settings and find Daily backups under Your data.",
          "Click Restore… and choose a day. Show Backups in Finder opens the folder.",
          "Review the prompt, then confirm Restore. Check your balance and recent entries afterward.",
        ],
        note: "Restoring replaces what's in Pocket now. If Pocket couldn't open its data file, it keeps that file next to the new one, with “couldn't open” in its name, instead of overwriting it.",
      },
      {
        id: "export",
        title: "Export a backup",
        paragraphs: ["Export saves a JSON copy of your money data. Choose a storage location you control."],
        steps: [
          "Open Settings and find Backup.",
          "Click Export and choose a filename and destination. A dated filename makes copies easier to distinguish.",
          "Keep the file somewhere you can access if this Mac stops working, such as an external backup drive.",
        ],
        note: "Export leaves your current data in Pocket.",
      },
      {
        id: "new-mac",
        title: "Import on a new Mac",
        paragraphs: ["Import replaces Pocket's local data. If you already have entries on the new Mac, export them before importing another file."],
        steps: [
          "Install Pocket on the new Mac and open it in local mode.",
          "Transfer your exported JSON file to that Mac.",
          "Open Settings, click Import and select the file. Review the replacement prompt, then confirm Replace.",
          "Check your balance, recent entries, planned payments and quick-add buttons after importing.",
        ],
        note: "Import replaces all local data instead of merging entries. The two Macs keep separate copies unless you set up sync.",
      },
      {
        id: "optional-sync",
        title: "Use sync for a shared balance across devices",
        paragraphs: [
          "With optional self-hosted sync, your chosen server stores the shared main copy. Your Mac keeps a copy in account-ledger.json and queues changes while offline.",
          "You can export while connected. Import and Restore are available only in local mode and replace only the local data.",
          "To use the same balance on your phone or another computer, [follow the self-hosting guide](/guides/self-hosting/) and pair devices in Settings under Sync. You will need a server you run.",
        ],
      },
    ],
  },
  {
    slug: "self-hosting",
    title: "Pair Pocket with your phone using your own server",
    description: "Connect Pocket for Mac to a free Supabase project you run, then pair your phone with a 6-digit code to see the same balance in the Pocket web app.",
    category: "Your data",
    minutes: 6,
    published: "2026-10-13",
    updated: "2026-10-13",
    image: "/screenshot-overview.png",
    imageAlt: "Pocket for Mac Overview, the balance that sync shares with your other devices",
    related: ["back-up-your-data", "getting-started"],
    sections: [
      {
        id: "how-sync-works",
        title: "How sync works",
        paragraphs: [
          "Pocket for Mac works fine on its own: your money stays in one file on your Mac. If you also want your balance on your phone or another computer, give Pocket a server of your own. It's a free Supabase project that only you can read, and setting it up takes about five minutes.",
          "Your Mac keeps a full copy and keeps working offline. The server holds the main copy, so every device agrees.",
          `The same steps, next to the files they refer to, are in the [technical reference on GitHub](${SELF_HOSTING_URL}).`,
        ],
      },
      {
        id: "supabase-project",
        title: "Make a Supabase project",
        paragraphs: [],
        steps: [
          "Create a free account at [supabase.com](https://supabase.com) and make a new project. Any name and region work.",
          "Wait until it says the project is ready.",
        ],
        note: "You can also run Supabase yourself with Docker ([Supabase's self-hosting guide](https://supabase.com/docs/guides/self-hosting)). Pocket only needs the database and its REST API.",
      },
      {
        id: "database",
        title: "Load Pocket's database",
        paragraphs: [
          `Run the files in [supabase/migrations](${REPO_URL}/tree/main/supabase/migrations) in order, oldest first. Use either method:`,
        ],
        steps: [
          "SQL editor: in your project, open SQL Editor, paste each file and click Run.",
          "Supabase CLI: from a copy of the Pocket repository, run “supabase link --project-ref <your-project-ref>”, then “supabase db push”.",
        ],
        note: "All tables are locked. Apps can only call Pocket's pocket_* functions, and every function except setup and pairing needs a key that only your devices hold.",
      },
      {
        id: "connect-mac",
        title: "Set up the server from your Mac",
        paragraphs: [],
        steps: [
          "In your Supabase project, open Project Settings → API and copy the Project URL and the publishable key (sb_publishable_…, also called the anon key). Never use the secret or service-role key.",
          "In Pocket for Mac, open Settings → Sync → Connect…, expand Server, and paste both.",
          "Click Set Up This Server.",
        ],
        note: "Pocket creates your account on that server with a random key that never leaves your Mac (it's stored in the Keychain), then uploads everything already on your Mac. Do this right after loading the database: until it's done, the first app to set up an empty server claims it. Once set up, a server refuses any other setup.",
      },
      {
        id: "pair-phone",
        title: "Add your phone",
        paragraphs: [
          "On the Mac, open Settings → Sync → Pair…. You get a 6-digit code and a link. Open the link on your phone: it opens the Pocket web app already pointed at your server, with the code filled in. Tap Pair, then Add to Home Screen so it works like an app.",
          `You can also open the [Pocket web app](/app/) on any device, choose Use your own server, enter the same URL and publishable key, and type a code.`,
          `To host the web app yourself as well, publish the [docs folder](${REPO_URL}/tree/main/docs) anywhere that serves static files, for example GitHub Pages on your fork.`,
        ],
      },
      {
        id: "keep-awake",
        title: "Keep the project awake",
        paragraphs: [
          "Free Supabase projects pause after a week with no requests. Pocket for Mac checks in every 30 seconds while it's running, so a Mac that's on most days keeps the project awake.",
          `For a safety net, copy [the keepalive workflow](${REPO_URL}/blob/main/.github/workflows/keepalive.yml) into your fork and change the URL and apikey to yours. It calls pocket_ping once a day, which reveals nothing.`,
        ],
      },
      {
        id: "remove-device",
        title: "Remove a device or start over",
        paragraphs: [],
        table: {
          label: "Removing devices and leaving a server",
          headings: ["To", "Do this"],
          rows: [
            ["Remove a device", "Settings → Sync → Devices on the Mac, or Settings → Devices in the web app. A removed device is locked out right away."],
            ["Leave the server", "On the Mac, Settings → Sync → Disconnect. The Mac keeps everything as a local copy."],
            ["Start over", "Delete the Supabase project, or run the migrations on a new one, and set up again."],
          ],
        },
      },
    ],
  },
];

export const guideUrl = (slug: string) => `/guides/${slug}/`;
