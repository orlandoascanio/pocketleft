import type { Metadata } from "next";
import { DownloadDialog } from "@/components/DownloadDialog";
import { SiteFooter } from "@/components/SiteFooter";
import { DownloadIcon, SiteNav } from "@/components/SiteNav";
import { AUTHOR, PUBLISHER } from "@/lib/schema";
import {
  DMG_SIZE, DOWNLOAD_PAGE, DOWNLOAD_URL, SELF_HOSTING_GUIDE_URL, SITE_URL, VERSION,
  WEB_APP_URL, WINDOWS_SETUP_URL, WINDOWS_VERSION,
} from "@/lib/site";
import "./download.css";

const title = "Download PocketLeft for Mac and Windows";
const description = "Download PocketLeft for macOS 14 or later or get the Windows 11 preview. See installation steps and learn how to pair a phone with the Pocket web app.";

export const metadata: Metadata = {
  title,
  description,
  alternates: { canonical: DOWNLOAD_PAGE },
  openGraph: { title, description, url: DOWNLOAD_PAGE },
};

const downloadPageUrl = SITE_URL + DOWNLOAD_PAGE;
const windowsApp = {
  "@type": "SoftwareApplication",
  "@id": downloadPageUrl + "#windows",
  name: "Pocket for Windows",
  description: "A free manual expense tracker for Windows 11 that shows your balance in the system tray and works offline.",
  url: downloadPageUrl + "#windows",
  applicationCategory: "FinanceApplication",
  operatingSystem: "Windows 11",
  softwareVersion: WINDOWS_VERSION,
  downloadUrl: WINDOWS_SETUP_URL,
  releaseNotes: SITE_URL + "/changelog/#windows",
  author: AUTHOR,
  publisher: PUBLISHER,
  offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
};

export default function DownloadPage() {
  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify({
        "@context": "https://schema.org",
        "@type": "WebPage",
        "@id": downloadPageUrl,
        name: title,
        description,
        url: downloadPageUrl,
        mainEntity: [{ "@id": SITE_URL + "/#software" }, windowsApp],
      }) }} />
      <SiteNav />
      <main className="wrap download-page">
        <header className="download-intro">
          <h1>Download PocketLeft</h1>
          <p>PocketLeft is a free manual expense tracker. Install the Mac app or the Windows 11 preview to track your balance offline. You can open the same ledger in your browser after setting up sync.</p>
          <nav aria-label="Download platforms">
            <a className="pill pill-soft" href="#mac">Mac</a>
            <a className="pill pill-soft" href="#windows">Windows preview</a>
            <a className="pill pill-soft" href="#web">Web app</a>
          </nav>
        </header>

        <section className="download-card" id="mac" aria-labelledby="download-mac">
          <div>
            <h2 id="download-mac">Pocket for Mac</h2>
            <p className="download-requirements">Version {VERSION} · macOS 14 or later · Apple Silicon and Intel</p>
            <a className="pill pill-dark" href={DOWNLOAD_URL} data-download><DownloadIcon />Download for Mac</a>
            <p className="download-file">Pocket.dmg · {DMG_SIZE} · Developer-signed and Apple-notarized</p>
          </div>
          <div>
            <h3>Install on Mac</h3>
            <ol>
              <li>Open Pocket.dmg from Downloads.</li>
              <li>Drag Pocket into Applications and open it.</li>
              <li>Set your starting balance. Click Pocket in the menu bar to log your first entry.</li>
            </ol>
            <div className="download-related">
              <a href="/guides/getting-started/">Mac setup guide</a>
              <a href="/changelog/#mac">Mac release notes</a>
            </div>
          </div>
        </section>

        <section className="download-card" id="windows" aria-labelledby="download-windows">
          <div>
            <h2 id="download-windows">Pocket for Windows</h2>
            <p className="download-requirements">Version {WINDOWS_VERSION} preview · Windows 11 · Intel, AMD, and ARM</p>
            <a className="pill pill-dark" href={WINDOWS_SETUP_URL}><DownloadIcon />Download for Windows</a>
            <p className="download-file">Pocket-Setup.exe · Unsigned preview</p>
          </div>
          <div>
            <h3>Install on Windows</h3>
            <ol>
              <li>Run Pocket-Setup.exe and choose an installation folder.</li>
              <li>Open Pocket, enter a starting balance, and choose Start local ledger to use it offline.</li>
              <li>Click Pocket in the tray beside the clock to log an expense or income.</li>
            </ol>
            <p>Right-click the tray icon and open Balance display to switch between Balance on hover and Floating panel.</p>
            <div className="download-related"><a href="/changelog/#windows">Windows release notes</a></div>
          </div>
        </section>

        <section className="download-card" id="web" aria-labelledby="download-web">
          <div>
            <h2 id="download-web">Pocket web app</h2>
            <p className="download-requirements">For phones and desktop browsers with an existing synced ledger</p>
            <a className="pill pill-dark" href={WEB_APP_URL}>Open the web app</a>
          </div>
          <div>
            <h3>Pair your device</h3>
            <p>Set up Pocket Sync with your own Supabase project. From a connected device, generate a six-digit pairing code, then enter it in the web app.</p>
            <div className="download-related"><a href={SELF_HOSTING_GUIDE_URL}>Set up sync and pair a phone</a></div>
          </div>
        </section>
      </main>
      <SiteFooter />
      <DownloadDialog />
    </>
  );
}
