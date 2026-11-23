export type FaqItem = { q: string; a: string; link?: { href: string; label: string } };

// Shared by the homepage, its FAQPage schema, and /llms.txt.
export const FAQ: FaqItem[] = [
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
