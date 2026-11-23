import type { Metadata } from "next";
import { GuideCards } from "@/components/GuideCards";
import { SiteFooter } from "@/components/SiteFooter";
import { DownloadDialog } from "@/components/DownloadDialog";
import { DownloadIcon, SiteNav } from "@/components/SiteNav";
import { DOWNLOAD_PAGE, SITE_URL } from "@/lib/site";
import { GUIDES, guideUrl } from "@/lib/guides";
import "./guides.css";

const description = "Set up Pocket for Mac, log spending in the menu bar, plan for payday, track renewals, and learn how to back up your ledger or pair your phone.";
export const metadata: Metadata = {
  title: "Guides · Pocket for Mac",
  description,
  alternates: { canonical: "/guides/" },
  openGraph: { title: "Guides · Pocket for Mac", description, url: "/guides/", images: [{ url: "/screenshot-overview.png", alt: "Pocket for Mac Overview" }] },
  twitter: { card: "summary_large_image", title: "Guides · Pocket for Mac", description, images: ["/screenshot-overview.png"] },
};

const groups = [
  { id: "setup", name: "Setup and data", slugs: ["getting-started", "back-up-your-data", "self-hosting"] },
  { id: "tracking", name: "Tracking and planning", slugs: ["menu-bar-balance", "quick-add-spending", "track-subscriptions", "expected-income", "freelance-income"] },
  { id: "comparisons", name: "Comparisons", slugs: ["manual-vs-bank-sync", "mac-menu-bar-money-apps"] },
];

export default function GuidesPage() {
  const schema = {
    "@context": "https://schema.org",
    "@type": "CollectionPage",
    name: "Pocket for Mac guides",
    description,
    url: `${SITE_URL}/guides/`,
    hasPart: GUIDES.map((guide) => ({ "@type": "Article", headline: guide.title, url: `${SITE_URL}${guideUrl(guide.slug)}` })),
  };
  return <>
    <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }} />
    <SiteNav />
    <main className="wrap guides-index">
      <header className="guides-intro">
        <div>
          <h1>Pocket guides</h1>
          <p className="guide-lead">Start with the money you have, make spending easy to record, and keep upcoming payments in view.</p>
          <a className="pill pill-dark guide-start" href="/guides/getting-started/">Get started on Mac</a>
        </div>
        <img src="/pocket-sculpture.webp" alt="" width={260} height={260} />
      </header>
      <nav className="guide-topics" aria-label="Guide topics">
        {groups.map(group => <a key={group.id} href={`#${group.id}`}>{group.name}</a>)}
      </nav>
      {groups.map(group => (
        <section className="guide-group" id={group.id} key={group.id} aria-labelledby={`guides-${group.id}`}>
          <h2 id={`guides-${group.id}`}>{group.name}</h2>
          <GuideCards slugs={group.slugs} />
        </section>
      ))}
      <section className="guide-download">
        <div><h2>Put your balance in the menu bar.</h2><p>Pocket is free for macOS, on Apple Silicon and Intel.</p></div>
        <a className="pill pill-dark" href={DOWNLOAD_PAGE}><DownloadIcon />Download options</a>
      </section>
    </main>
    <SiteFooter />
    <DownloadDialog />
  </>;
}
