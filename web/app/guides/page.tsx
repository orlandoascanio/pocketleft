import type { Metadata } from "next";
import { GuideCards } from "@/components/GuideCards";
import { SiteFooter } from "@/components/SiteFooter";
import { DownloadDialog } from "@/components/DownloadDialog";
import { DownloadIcon, SiteNav } from "@/components/SiteNav";
import { DOWNLOAD_URL, SITE_URL } from "@/lib/site";
import { GUIDES, guideUrl } from "@/lib/guides";
import "./guides.css";

const description = "Pocket for Mac guides: keep your balance in the menu bar, log spending with shortcuts, plan around freelance income and back up your data.";
export const metadata: Metadata = {
  title: "Guides · Pocket for Mac",
  description,
  alternates: { canonical: "/guides/" },
  openGraph: { title: "Guides · Pocket for Mac", description, url: "/guides/", images: [{ url: "/screenshot-overview.png", alt: "Pocket for Mac Overview" }] },
  twitter: { card: "summary_large_image", title: "Guides · Pocket for Mac", description, images: ["/screenshot-overview.png"] },
};

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
          <p className="guide-eyebrow">Pocket guides</p>
          <h1>Make the balance<br />part of your day.</h1>
          <p className="guide-lead">Start with the money you have, make spending easy to record, and keep upcoming payments in view.</p>
        </div>
        <img src="/pocket-sculpture.webp" alt="" width={260} height={260} />
      </header>
      <section aria-labelledby="all-guides">
        <h2 className="sr-only" id="all-guides">All Pocket guides</h2>
        <GuideCards />
      </section>
      <section className="guide-download">
        <div><h2>Put your balance in the menu bar.</h2><p>Pocket is free for macOS, on Apple Silicon and Intel.</p></div>
        <a className="pill pill-dark" href={DOWNLOAD_URL} data-download><DownloadIcon />Download for Mac</a>
      </section>
    </main>
    <SiteFooter />
    <DownloadDialog />
  </>;
}
