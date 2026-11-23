import type { ReactNode } from "react";
import { Bento } from "@/components/Bento";
import { ButtonFx } from "@/components/ButtonFx";
import { DownloadDialog } from "@/components/DownloadDialog";
import { Faq } from "@/components/Faq";
import { GuideCards } from "@/components/GuideCards";
import { PocketCharacter } from "@/components/PocketCharacter";
import { DownloadIcon, SiteNav } from "@/components/SiteNav";
import { Tour } from "@/components/Tour";
import { HeroAnnounce } from "@/components/HeroAnnounce";
import { RenewalPreview } from "@/components/RenewalPreview";
import { HeroScene } from "@/components/HeroScene";
import { ForDesktopPlatform, HeroActions, HeroDownloadDetails, HeroPlatformHeadline, PlatformDownloadLink } from "@/components/PlatformDownload";
import { SiteFooter } from "@/components/SiteFooter";
import { FAQ } from "@/lib/faq";
import { ALTERNATE_NAMES, AUTHOR, DISAMBIGUATION, PROFILES, PUBLISHER } from "@/lib/schema";
import "./home.css";
import "./guides/guides.css";
import { RELEASES, releaseId } from "@/lib/releases";
import {
  DESCRIPTION,
  DOWNLOAD_URL,
  WEB_APP_URL,
  REPO_URL,
  SELF_HOSTING_GUIDE_URL,
  SITE_URL,
  VERSION,
  WINDOWS_SETUP_URL,
  WINDOWS_VERSION,
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
    releaseNotes: `${SITE_URL}/changelog/`,
    author: AUTHOR,
    publisher: PUBLISHER,
    sameAs: PROFILES,
    featureList: [
      "Recorded balance in the Mac menu bar",
      "Manual spending and income entries with categories",
      "Quick-add buttons with Command-1 through Command-9",
      "Weekly, every-two-weeks, monthly, quarterly and yearly repeating payments",
      "Subscription renewal countdowns and custom macOS reminders",
      "Expected payments that wait for confirmation",
      "Balance forecast for the next 1, 3, 6 or 12 months, including usual everyday spending",
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

function DownloadButton() {
  return (
    <PlatformDownloadLink className="pill pill-dark">
      <DownloadIcon />
    </PlatformDownloadLink>
  );
}

function Check({ children }: { children: ReactNode }) {
  return (
    <li>
      <svg viewBox="0 0 16 16" aria-hidden="true">
        <path d="m3 8.5 3.2 3L13 4.5" />
      </svg>
      {children}
    </li>
  );
}

const COMING_UP = [
  { what: "Client A", when: "Mon, Nov 9", amount: "+$750.00", after: "$1,837.03", income: true },
  { what: "AI subscription", when: "Wed, Nov 11", amount: "−$20.00", after: "$1,817.03" },
  { what: "Client A", when: "Wed, Dec 9", amount: "+$750.00", after: "$2,567.03", income: true },
  { what: "AI subscription", when: "Fri, Dec 11", amount: "−$20.00", after: "$2,547.03" },
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
          <div className="tour-download">
            <DownloadButton />
          </div>
        </section>

        <div className="wrap wrap-wide home-demos">
          <Bento />
        </div>

        <section className="section wrap" id="subscriptions">
          <div className="renewal-layout">
            <div>
              <h2>See what renews next</h2>
              <p className="section-lead">Check which subscriptions are due in the next 7 or 30 days, then see what they cost you each month and year.</p>
              <p className="subscriptions-local">Set renewal reminders on your Mac. Pocket flags charges that would go straight into History. With sync, your subscriptions also appear in the browser app.</p>
              <div className="cta subscriptions-cta">
                <DownloadButton />
                <a className="pill pill-soft" href={WEB_APP_URL}>Open the browser app</a>
              </div>
              <a className="feature-guide" href="/guides/track-subscriptions/">
                How to track subscriptions on Mac <span aria-hidden="true">→</span>
              </a>
            </div>
            <RenewalPreview />
          </div>
        </section>

        <section className="section wrap" id="plan">
          <div className="feature">
            <div className="copy">
              <h2>See your balance after rent, before rent is due.</h2>
              <p>
                Start with your balance and schedule your bills and expected pay. See what you’ll have left after each payment.
                Once you have at least two weeks of entries with everyday purchases, Pocket for Mac can also estimate what you spend between bills.
              </p>
              <ul className="dots">
                <li>See what you can spend before payday after setting a cushion on Mac</li>
                <li>Choose a forecast of 1, 3, 6 or 12 months</li>
                <li>Schedule payments weekly, every two weeks, monthly, quarterly or yearly</li>
                <li>Pause or stop a payment, or skip a single occurrence</li>
              </ul>
              <a className="feature-guide" href="/guides/freelance-income/">
                See how a late payment changes your forecast <span aria-hidden="true">→</span>
              </a>
            </div>
            <div className="upcoming" aria-label="Example of payments coming up">
              <div className="upcoming-head">
                <span>Coming up</span>
                <span>next 3 months</span>
              </div>
              {COMING_UP.map((p) => (
                <div className="upcoming-row" key={p.what + p.when}>
                  <span className={p.income ? "upcoming-ic in" : "upcoming-ic"} aria-hidden="true">
                    {p.income ? "↓" : "↻"}
                  </span>
                  <span className="upcoming-what">
                    {p.what}
                    <small>{p.when}</small>
                  </span>
                  <span className="upcoming-amt">
                    <b className={p.income ? "in" : undefined}>{p.amount}</b>
                    <small>then {p.after}</small>
                  </span>
                </div>
              ))}
            </div>
          </div>

          <div className="feature flip" id="waiting">
            <div className="copy">
              <h2>Count a payment when it arrives</h2>
              <p>
                Freelance pay, a refund, the $40 a friend owes you. Mark the payment as waiting. When it arrives,
                click <strong>Got it</strong> and enter the amount you received, even if it came late or short.
              </p>
              <p>Waiting payments stay in Overview. Turn on reminders to get a prompt on the due date. Click <strong>Skip</strong> to leave a payment out.</p>
              <a className="feature-guide" href="/guides/expected-income/">
                Track expected income <span aria-hidden="true">→</span>
              </a>
            </div>
            <PocketCharacter id="waiting" mood="excited" bubble="Can't wait!" style={{ width: "min(280px, 64vw)" }} />
          </div>

          <div className="feature quick-add-feature" id="quick-add">
            <div className="copy">
              <h2>Log your usual coffee in one keystroke.</h2>
              <p>
                Log a coffee and choose <strong>Save as Button</strong>. Next time, click the button or use ⌘1 through ⌘9 in
                the Mac menu bar panel or the Pocket window.
              </p>
              <p>Added an entry by mistake? Click <strong>Undo</strong> on the confirmation.</p>
              <a className="feature-guide" href="/guides/quick-add-spending/">
                Set up quick-add buttons <span aria-hidden="true">→</span>
              </a>
            </div>
            <figure className="quick-add-recording">
              <video
                controls
                muted
                playsInline
                preload="none"
                width={1660}
                height={1080}
                poster="/media/quick-add-2026-10-12.webp"
                aria-label="Pocket quick-add keyboard shortcuts demonstration"
              >
                <source src="/media/quick-add-2026-10-12.mp4" type="video/mp4" />
                <a href="/media/quick-add-2026-10-12.mp4">Watch the quick-add demonstration</a>
              </video>
            </figure>
          </div>

          <div className="feature categories-feature" id="categories">
            <div className="copy">
              <h2>Compare spending by month</h2>
              <p>
                See what you spent, what came in and how much your balance changed. Compare completed months or
                open a category to see its entries. Use <strong>Review</strong> to find purchases and payments without a category.
              </p>
            </div>
            <figure className="categories-recording">
              <picture>
                <source media="(prefers-color-scheme: dark)" srcSet="/media/categories-1-5-3-dark.webp" />
                <img
                  src="/media/categories-1-5-3-light.webp"
                  width={1640}
                  height={910}
                  loading="lazy"
                  alt="Pocket for Mac Categories showing month-to-date spending, money in, balance change and spending by category. Example data."
                />
              </picture>
            </figure>
          </div>
        </section>

        <section className="section wrap" id="private">
          <h2 className="two-tone">Keep your ledger <span>on your device.</span></h2>
          <div className="local-default plan">
            <div className="local-copy">
              <h3>Local storage on Mac</h3>
              <ForDesktopPlatform platform="mac">
                <a className="pill pill-dark" href={DOWNLOAD_URL} data-download><DownloadIcon />Download for Mac</a>
              </ForDesktopPlatform>
              <a className="feature-guide plan-guide" href="/guides/back-up-your-data/">
                Back up or move to a new Mac <span aria-hidden="true">→</span>
              </a>
            </div>
            <ul className="checks">
                <Check>One file holds your ledger</Check>
              <Check>Works offline</Check>
              <Check>Seven daily backups you can restore</Check>
                <Check>Export a backup or a CSV spreadsheet</Check>
            </ul>
          </div>
          <details className="sync-details">
            <summary>
              <span>Sync with your phone</span>
              <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m6 9 6 6 6-6" /></svg>
            </summary>
            <div className="sync-content">
              <p>Connect Pocket to your own free Supabase project, then pair your phone with a six-digit code. You’ll see the same ledger in the web app. Your Mac keeps a local copy you can use offline.</p>
              <a className="pill pill-line" href={SELF_HOSTING_GUIDE_URL}>
                Read the self-hosting guide
              </a>
            </div>
          </details>
        </section>

        <section className="home-guides wrap" id="guides">
          <h2>Three guides to get started</h2>
          <GuideCards slugs={["getting-started", "quick-add-spending", "expected-income"]} />
          <a href="/guides/">All Pocket guides <span aria-hidden="true">↗</span></a>
        </section>

        <section className="section wrap" id="faq">
          <h2>Questions about Pocket</h2>
          <Faq items={FAQ} />
        </section>

        <div id="downloads" className="download-options">
          <ForDesktopPlatform platform="mac">
            <section className="wrap desktop-download" aria-labelledby="mac-heading">
              <div>
                <h2 id="mac-heading">Pocket for Mac</h2>
                <p>See your balance and log spending from the menu bar.</p>
              </div>
              <div>
                <div className="cta">
                  <a className="pill pill-dark" href={DOWNLOAD_URL} data-download><DownloadIcon />Download for Mac</a>
                </div>
                <p className="desktop-download-note">v{VERSION} · macOS 14+ · Apple Silicon and Intel</p>
              </div>
            </section>
          </ForDesktopPlatform>
          <ForDesktopPlatform platform="windows">
            <section className="wrap desktop-download" id="windows" aria-labelledby="windows-heading">
              <div>
                <h2 id="windows-heading">Pocket for Windows</h2>
                <p>Hover over Pocket in the tray to see your balance. To keep it above the clock, right-click the tray icon and choose <strong>Floating panel</strong> under <strong>Balance display</strong>.</p>
              </div>
              <div>
                <div className="cta">
                  <a className="pill pill-dark" href={WINDOWS_SETUP_URL}><DownloadIcon />Download for Windows</a>
                </div>
                <p className="desktop-download-note">v{WINDOWS_VERSION} preview · Windows 11 · Intel, AMD, and ARM</p>
              </div>
              <p className="desktop-download-note desktop-install">Run <strong>Pocket-Setup.exe</strong> and choose an install folder. When Pocket opens, enter a starting balance and choose <strong>Start local ledger</strong>. Record your next purchase from the Pocket icon near the clock. This preview is unsigned.</p>
            </section>
          </ForDesktopPlatform>
        </div>

        <section className="closing wrap home-closing">
          <img className="closing-sculpture" src="/pocket-sculpture.webp" alt="" width={200} height={200} loading="lazy" />
          <h2>Set your starting balance</h2>
          <div className="cta">
            <DownloadButton />
            <a className="pill pill-soft" href={REPO_URL}>
              View the source
            </a>
          </div>
        </section>
      </main>

      <SiteFooter />

      <ForDesktopPlatform platform="mac"><DownloadDialog /></ForDesktopPlatform>
      <ButtonFx />
    </>
  );
}
