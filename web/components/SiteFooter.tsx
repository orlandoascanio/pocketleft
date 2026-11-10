import { AnalyticsPreferences } from "@/components/WebsiteAnalytics";
import {
  DOWNLOAD_URL,
  ISSUES_URL,
  RELEASES_URL,
  REPO_URL,
  SELF_HOSTING_GUIDE_URL,
  VERSION,
  WEB_APP_URL,
} from "@/lib/site";

// One footer for every public page, so the changelog, source and help links never disappear
// once a visitor leaves the homepage. Section links are absolute (/#tour) so they work anywhere.
export function SiteFooter() {
  return (
    <footer className="foot">
      <div className="wrap foot-grid">
        <div className="foot-brand">
          <a className="brand" href="/">
            <img src="/pocket-icon.webp" alt="" width={28} height={28} />
            Pocket
          </a>
          <p>Your balance in the menu bar, and how long it will last.</p>
          <a className="foot-ver" href="/changelog/">
            v{VERSION} · Release notes
          </a>
          <span className="foot-badge">
            <svg viewBox="0 0 16 16" aria-hidden="true">
              <path d="m3 8.5 3.2 3L13 4.5" />
            </svg>
            Signed and notarized by Apple
          </span>
        </div>
        <nav className="foot-col" aria-label="Product">
          <h3>Product</h3>
          <a href={DOWNLOAD_URL} data-download>
            Download
          </a>
          <a href="/#tour">Features</a>
          <a href="/#plan">Plan ahead</a>
          <a href="/#subscriptions">Subscriptions</a>
          <a href={WEB_APP_URL}>Web app</a>
        </nav>
        <nav className="foot-col" aria-label="Help">
          <h3>Help</h3>
          <a href="/guides/">Guides</a>
          <a href="/#faq">Questions</a>
          <a href={SELF_HOSTING_GUIDE_URL}>Self-hosting</a>
          <a href={ISSUES_URL}>Report a bug</a>
        </nav>
        <nav className="foot-col" aria-label="Project">
          <h3>Project</h3>
          <a href="/about/">About Pocket</a>
          <a href={REPO_URL}>Source code</a>
          <a href={REPO_URL} data-star>
            Star on GitHub
          </a>
          <a href="/changelog/">Changelog</a>
          <a href={RELEASES_URL}>All releases</a>
          <a href="https://www.orlandoascanio.com">Made by Orlando Ascanio</a>
        </nav>
      </div>
      <div className="wrap foot-base">
        <span>
          Download Pocket only from <b>pocketleft.app</b> or its GitHub page.
        </span>
        <nav className="foot-legal" aria-label="Website preferences">
          <a href="/privacy/">Website privacy</a>
          <AnalyticsPreferences />
        </nav>
      </div>
      <div className="foot-word" aria-hidden="true">
        Pocket
      </div>
    </footer>
  );
}
