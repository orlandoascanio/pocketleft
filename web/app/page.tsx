import { ButtonFx } from "@/components/ButtonFx";
import { DownloadDialog } from "@/components/DownloadDialog";
import { Faq } from "@/components/Faq";
import { DownloadIcon, SiteNav } from "@/components/SiteNav";
import { Tour } from "@/components/Tour";
import { HeroAnnounce } from "@/components/HeroAnnounce";
import { QuickEntryPreview } from "@/components/QuickEntryPreview";
import { RenewalPreview } from "@/components/RenewalPreview";
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
          </div>
          <HeroScene />
          <div className="hero-details"><HeroDownloadDetails /></div>
        </section>

        <section className="section wrap" id="tour">
          <div className="tour-intro">
            <div className="story-copy" id="waiting">
              <h2>Inside Pocket for Mac</h2>
              <p>Overview puts your balance, recent purchases, and payments you’re waiting for in one window.</p>
              <p>If a client pays late or sends a different amount, choose <strong>Got it</strong> when the money arrives. Enter the amount and date to update your balance.</p>
              <a className="feature-guide" href="/guides/expected-income/">Track expected income <span aria-hidden="true">→</span></a>
            </div>
            <figure className="pocket-film" id="video">
              <video controls playsInline preload="none" width={1920} height={1080}
                poster="/media/pocket-for-mac-demo.webp" aria-label="Pocket for Mac demo">
                <source src="/media/pocket-for-mac-demo.mp4" type="video/mp4" />
                <a href="/media/pocket-for-mac-demo.mp4">Watch the Pocket for Mac demo</a>
              </video>
            </figure>
          </div>
          <Tour initialView="overview" />
        </section>

        <div className="wrap product-stories">
          <section className="product-story" id="quick-add">
            <div className="story-copy">
              <h2>Your usual coffee, one click away</h2>
              <p>Open Quick Entry from the Mac menu bar or the Windows tray to record a purchase without leaving what you’re doing.</p>
              <p>On Mac, save your usual coffee as a button. Next time, click it or press its keyboard shortcut. If you add it twice, choose <strong>Undo</strong> on the confirmation.</p>
              <a className="feature-guide" href="/guides/quick-add-spending/">Set up quick-add buttons <span aria-hidden="true">→</span></a>
            </div>
            <QuickEntryPreview />
          </section>

          <section className="product-story story-reverse" id="plan">
            <div className="story-copy">
              <h2>Will Thursday’s rent leave room for dinner?</h2>
              <p>In Plan on Mac, choose your next payday and the minimum balance you want to keep. Pocket finds the lowest projected balance before payday, even if rent comes out the day before you get paid.</p>
              <p>With enough spending history, the forecast also accounts for everyday purchases between bills.</p>
              <a className="feature-guide" href="/guides/freelance-income/#before-payday">Set your payday and cushion <span aria-hidden="true">→</span></a>
            </div>
            <picture className="story-screen">
              <source media="(prefers-color-scheme: dark)" srcSet="/media/plan-1-5-5-dark.webp" />
              <img src="/media/plan-1-5-5-light.webp" width={1640} height={1270} loading="lazy" alt="Pocket’s Plan view shows $319.54 available before payday above a chart of the projected balance." />
            </picture>
          </section>

          <section className="product-story" id="subscriptions">
            <div className="story-copy">
              <h2>See what renews before the bill lands</h2>
              <p>A music subscription renews this week. Your design tools renew later in the month. Switch between 7 and 30 days to see which charges are coming and how much they add up to.</p>
              <p>In Pocket for Mac, you can also compare monthly and yearly costs and set a reminder before a renewal.</p>
              <a className="feature-guide" href="/guides/track-subscriptions/">Track subscriptions on Mac <span aria-hidden="true">→</span></a>
            </div>
            <RenewalPreview />
          </section>

          <section className="product-story story-reverse" id="categories">
            <div className="story-copy">
              <h2>Where did this month’s money go?</h2>
              <p>Categories breaks down spending by month. Open a category to see the purchases behind its total, or compare two completed months to see what changed.</p>
              <p>Use <strong>Review</strong> to find entries that still need a category.</p>
            </div>
            <picture className="story-screen">
              <source media="(prefers-color-scheme: dark)" srcSet="/media/categories-1-5-3-dark.webp" />
              <img src="/media/categories-1-5-3-light.webp" width={1640} height={910} loading="lazy" alt="Pocket’s Categories view shows $22.49 spent in November, split between Games and Food." />
            </picture>
          </section>
        </div>

        <section className="section wrap home-help" aria-label="Data and help">
          <div id="private">
            <h2>Your ledger starts on your device</h2>
            <p>Pocket saves entries on your computer and works offline. On Mac, it keeps seven daily backups. To see your balance on your phone, connect your own Supabase project and pair the web app.</p>
            <a className="feature-guide" href={SELF_HOSTING_GUIDE_URL}>Set up phone pairing</a>
          </div>
          <div id="guides">
            <h2>Get started with Pocket</h2>
            <p>Set your starting balance, record your first purchase, and plan one upcoming bill.</p>
            <a className="feature-guide" href="/guides/getting-started/">Get started on Mac</a>
            <a className="feature-guide" href="/guides/">Browse all guides</a>
            <div id="faq"><Faq items={FAQ} /></div>
          </div>
        </section>

        <section className="wrap home-platforms" id="downloads" aria-labelledby="downloads-heading">
          <div className="download-invitation">
            <div>
              <h2 id="downloads-heading">Start with today’s balance</h2>
              <p>Get Pocket for macOS 14 or later, or try the Windows 11 preview. Enter your starting amount and you’re ready for your next purchase.</p>
              <div className="home-platform-links">
                <a className="pill pill-dark" href={DOWNLOAD_PAGE}><DownloadIcon />Choose a download</a>
                <a className="feature-guide" id="windows" href={DOWNLOAD_PAGE + "#windows"}>Windows preview and setup</a>
              </div>
            </div>
            <img src="/pocket-sculpture.webp" width={180} height={180} loading="lazy" alt="" />
          </div>
        </section>
      </main>

      <SiteFooter />

      <ForDesktopPlatform platform="mac"><DownloadDialog /></ForDesktopPlatform>
      <ButtonFx />
    </>
  );
}
