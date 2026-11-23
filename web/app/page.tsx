import { ButtonFx } from "@/components/ButtonFx";
import { DownloadDialog } from "@/components/DownloadDialog";
import { Faq } from "@/components/Faq";
import { DownloadIcon, SiteNav } from "@/components/SiteNav";
import { Tour } from "@/components/Tour";
import { HeroAnnounce } from "@/components/HeroAnnounce";
import { HeroScene } from "@/components/HeroScene";
import { ForDesktopPlatform, HeroActions, HeroDownloadDetails, HeroPlatformHeadline } from "@/components/PlatformDownload";
import { SiteFooter } from "@/components/SiteFooter";
import { FAQ } from "@/lib/faq";
import { ALTERNATE_NAMES, AUTHOR, DISAMBIGUATION, PROFILES, PUBLISHER } from "@/lib/schema";
import "./home.css";
import { RELEASES, releaseId } from "@/lib/releases";
import {
  DESCRIPTION,
  DOWNLOAD_PAGE,
  DOWNLOAD_URL,
  SELF_HOSTING_GUIDE_URL,
  SITE_URL,
  VERSION,
} from "@/lib/site";

const jsonLd = [
  {
    "@context": "https://schema.org",
    "@type": "WebSite",
    name: "PocketLeft",
    alternateName: ["Pocket for Mac", "pocketleft.app"],
    url: `${SITE_URL}/`,
  },
  {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    "@id": `${SITE_URL}/#software`,
    name: "Pocket for Mac",
    alternateName: ALTERNATE_NAMES,
    description: DESCRIPTION,
    disambiguatingDescription: DISAMBIGUATION,
    url: `${SITE_URL}/`,
    downloadUrl: DOWNLOAD_URL,
    softwareVersion: VERSION,
    image: `${SITE_URL}/screenshot-overview.png`,
    datePublished: RELEASES[RELEASES.length - 1].date,
    dateModified: RELEASES[0].date,
    releaseNotes: `${SITE_URL}/changelog/#mac`,
    author: AUTHOR,
    publisher: PUBLISHER,
    sameAs: PROFILES,
    featureList: [
      "Recorded balance in the Mac menu bar",
      "Manual spending and income entries with categories",
      "Quick-add buttons with Command-1 through Command-9",
      "Undo the last quick entry from its confirmation",
      "Hide the balance in the menu bar and Quick Entry",
      "Weekly, every-two-weeks, monthly, quarterly and yearly repeating payments",
      "Subscription renewal countdowns and custom macOS reminders",
      "Expected payments that wait for confirmation",
      "Balance forecast for the next 1, 3, 6 or 12 months, including usual everyday spending",
      "Estimate what you can spend before payday after setting a minimum balance",
      "History search and filters by name, category, amount and date",
      "Local data file with seven daily backups, JSON export/import and CSV export",
      "One-click updates that download, check and install inside the app",
      "Optional self-hosted sync with a Pocket web app for phones",
    ],
    operatingSystem: "macOS 14 or later",
    applicationCategory: "FinanceApplication",
    offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
    isAccessibleForFree: true,
    screenshot: [`${SITE_URL}/screenshot-overview.png`, `${SITE_URL}/screenshot-plan.png`],
  },
  {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: FAQ.map(({ q, a }) => ({ "@type": "Question", name: q, acceptedAnswer: { "@type": "Answer", text: a } })),
  },
];

export default function Home() {
  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <SiteNav />

      <main>
        <section className="hero hero-dimensional wrap">
          <div className="hero-copy">
            <HeroAnnounce>
              <a className="announce" href={"/changelog/#" + releaseId(VERSION)}>
                <span className="announce-tag">New</span>
                <b>Pocket {VERSION.replace(/\.0$/, "")}</b>
                <span className="announce-text">See what you can spend before payday.</span>
                <span className="announce-arrow" aria-hidden="true">
                  ↗
                </span>
              </a>
            </HeroAnnounce>
            <HeroPlatformHeadline />
            <HeroActions downloadIcon={<DownloadIcon />} />
            <HeroDownloadDetails />
          </div>
          <HeroScene />
        </section>

        <section className="section wrap" id="tour">
          <h2>Inside Pocket for Mac</h2>
          <p className="section-lead">
            Click your balance in the menu bar to add an entry. In the main window, review your history, confirm payments and see what’s coming up.
          </p>
          <figure className="pocket-film" id="video">
            <video controls playsInline preload="none" width={1920} height={1080}
              poster="/media/pocket-for-mac-demo.webp" aria-label="Pocket for Mac demo">
              <source src="/media/pocket-for-mac-demo.mp4" type="video/mp4" />
              <a href="/media/pocket-for-mac-demo.mp4">Watch the Pocket for Mac demo</a>
            </video>
          </figure>
          <Tour initialView="overview" />
        </section>

        <section className="section wrap" aria-labelledby="workflows-heading">
          <h2 id="workflows-heading">From today’s coffee to next month’s bills</h2>
          <div className="workflow-grid">
            <article className="workflow-card" id="quick-add">
              <h3>Log spending in a tap</h3>
              <p>Save frequent purchases as quick-add buttons. On Mac, click a button or use Command-1 through Command-9. If you add an entry by mistake, click Undo on the confirmation.</p>
              <a className="feature-guide" href="/guides/quick-add-spending/">Set up quick-add buttons <span aria-hidden="true">→</span></a>
              <div className="workflow-detail" id="categories">
                <h4>See where your money went</h4>
                <p>Use Categories to compare completed months and open the entries behind each total.</p>
              </div>
            </article>
            <article className="workflow-card" id="plan">
              <h3>See what’s available before payday</h3>
              <p>In Pocket for Mac, choose a payday and a minimum balance to keep. Plan uses the lowest projected balance before payday and includes usual spending once you have enough history.</p>
              <a className="feature-guide" href="/guides/freelance-income/#before-payday">Set your payday and cushion <span aria-hidden="true">→</span></a>
              <div className="workflow-detail" id="waiting">
                <h4>Track money you’re waiting for</h4>
                <p>Confirm the amount and date when it arrives to add it to your recorded balance.</p>
                <a href="/guides/expected-income/">Track expected income</a>
              </div>
            </article>
            <article className="workflow-card" id="subscriptions">
              <h3>Know what renews next</h3>
              <p>See which subscriptions are due over the next 7 or 30 days. On Mac, set reminders before a renewal and compare monthly and yearly costs.</p>
              <a className="feature-guide" href="/guides/track-subscriptions/">Track subscriptions on Mac <span aria-hidden="true">→</span></a>
            </article>
          </div>
        </section>

        <section className="section wrap home-help" aria-label="Data and help">
          <div id="private">
            <h2>Your data stays on your device</h2>
            <p>Pocket works offline by default. On Mac, it keeps seven daily backups and lets you export your ledger. For phone access, set up optional sync and pair your device.</p>
            <a className="feature-guide" href="/guides/back-up-your-data/">Back up or move to a new Mac</a>
            <a className="feature-guide" href={SELF_HOSTING_GUIDE_URL}>Set up phone pairing</a>
          </div>
          <div id="guides">
            <h2>Get started with Pocket</h2>
            <p>Set your starting balance, record your first purchase, and plan one upcoming bill.</p>
            <a className="feature-guide" href="/guides/getting-started/">Get started on Mac</a>
            <a className="feature-guide" href="/guides/">Browse all guides</a>
          </div>
        </section>

        <section className="section wrap" id="faq">
          <h2>Questions about Pocket</h2>
          <Faq items={FAQ} />
        </section>

        <section className="section wrap home-platforms" id="downloads" aria-labelledby="downloads-heading">
          <div>
            <h2 id="downloads-heading">Get Pocket for your device</h2>
            <p>Free for macOS 14 or later and available as a Windows 11 preview. Use the web app after setting up sync.</p>
          </div>
          <div className="home-platform-links">
            <a className="pill pill-dark" href={DOWNLOAD_PAGE}><DownloadIcon />All download options</a>
            <a className="feature-guide" id="windows" href={DOWNLOAD_PAGE + "#windows"}>Windows preview and setup</a>
          </div>
        </section>
      </main>

      <SiteFooter />

      <ForDesktopPlatform platform="mac"><DownloadDialog /></ForDesktopPlatform>
      <ButtonFx />
    </>
  );
}
