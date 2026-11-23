export type FaqItem = { q: string; a: string; link?: { href: string; label: string } };

// Shared by the homepage, its FAQPage schema, and /llms-full.txt.
export const FAQ: FaqItem[] = [
  {
    q: "What starting balance should I enter?",
    a: "Use today’s balance for the account or cash you want to track. Then record purchases and income from that point forward. Older transactions are already included in your starting amount.",
  },
  {
    q: "What if my Pocket balance differs from my bank’s?",
    a: "Compare recent entries in History with your bank transactions. Add a missing purchase, correct an amount, or remove a duplicate.",
    link: { href: "/guides/manual-vs-bank-sync/", label: "Read the manual tracking guide" },
  },
  {
    q: "Can I use Pocket on my phone?",
    a: "Yes. Set up your own Supabase project, then pair your phone to open the same ledger in the Pocket web app.",
    link: { href: "/guides/self-hosting/", label: "See the pairing steps" },
  },
  {
    q: "Which currencies does it support?",
    a: "Choose a standard currency for each ledger. Switching currency changes the labels and keeps the amounts you entered.",
  },
  {
    q: "How do I move Pocket to a new Mac?",
    a: "Export your data from Settings on the old Mac, then import that file on the new one.",
    link: { href: "/guides/back-up-your-data/", label: "Read the backup and move guide" },
  },
];
