import type { Metadata } from "next";
import { ButtonFx } from "@/components/ButtonFx";
import { Changelog } from "@/components/Changelog";
import { DownloadDialog } from "@/components/DownloadDialog";
import { PocketCharacter } from "@/components/PocketCharacter";
import { SiteNav } from "@/components/SiteNav";
import { SiteFooter } from "@/components/SiteFooter";
import { ISSUES_URL, REPO_URL, SITE_URL } from "@/lib/site";
import "./changelog.css";

export const metadata: Metadata = {
  title: "Changelog · Pocket for Mac and Windows",
  description: "Read release notes for Pocket for Mac and the Windows preview.",
  alternates: { canonical: "/changelog/" },
  openGraph: {
    type: "website",
    siteName: "Pocket",
    title: "What’s new in Pocket",
    description: "Read release notes for Pocket for Mac and the Windows preview.",
    url: "/changelog/",
    images: [{ url: `${SITE_URL}/screenshot-overview.png`, width: 1600, height: 1283, alt: "Pocket for Mac" }],
  },
};

export default function ChangelogPage() {
  return (
    <>
      <a className="changes-skip" href="#releases">Skip to release notes</a>
      <SiteNav />
      <main className="changes wrap">
        <header className="changes-intro">
          <div>
            <h1>What’s new<br />in Pocket<span>.</span></h1>
            <p>Release notes for Pocket for Mac and the Windows preview.</p>
            <p className="changes-start">New to Pocket? <a href="/guides/getting-started/">Start with the setup guide</a>.</p>
          </div>
          <div className="changes-character" aria-hidden="true">
            <PocketCharacter id="changelog" mood="happy" bubble="New in my pocket!" style={{ width: "180px" }} />
          </div>
        </header>
        <Changelog />
        <div className="changes-close">
          <div><h2>Something we can improve?</h2><p>Tell us what happened, or what would help. Like Pocket? <a href={REPO_URL} data-star>Star it on GitHub</a>.</p></div>
          <a className="pill pill-line" href={ISSUES_URL}>Share feedback <span aria-hidden="true">↗</span></a>
        </div>
      </main>
      <SiteFooter />
      <DownloadDialog />
      <ButtonFx />
    </>
  );
}
