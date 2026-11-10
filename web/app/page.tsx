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
import { HeroScene } from "@/components/HeroScene";
import { SiteFooter } from "@/components/SiteFooter";
import { FAQ } from "@/lib/faq";
import { ALTERNATE_NAMES, AUTHOR, DISAMBIGUATION, PROFILES, PUBLISHER } from "@/lib/schema";
import "./home.css";
import "./guides/guides.css";
import { RELEASES } from "@/lib/releases";
import {
  DESCRIPTION,
  DMG_SIZE,
  DOWNLOAD_URL,
  REPO_URL,
  SELF_HOSTING_GUIDE_URL,
  SITE_URL,
  VERSION,
} from "@/lib/site";

const jsonLd = [
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
    <a className="pill pill-dark" href={DOWNLOAD_URL} data-download>
      <DownloadIcon />
      Download for Mac
    </a>
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
              <a className="announce" href="/changelog/">
                <span className="announce-tag">New</span>
                <b>Pocket {VERSION.replace(/\.0$/, "")}</b>
                <span className="announce-text">Your subscriptions, costs and renewals in one place.</span>
                <span className="announce-arrow" aria-hidden="true">
                  ↗
                </span>
              </a>
            </HeroAnnounce>
            <h1>How much money you have left,<br /><span>always in your menu bar.</span></h1>
            <p className="lead">Type in what you have today, then log what you spend and what comes in. Pocket keeps the number up to date at the top of your screen.</p>
            <div className="cta" id="hero-cta">
              <DownloadButton />
              <a className="pill pill-soft" href="#tour">
                Take the tour
              </a>
            </div>
            <ul className="meta">
              <li>Free</li>
              <li>No account</li>
              <li>macOS 14+</li>
              <li>Apple Silicon &amp; Intel</li>
              <li>Developer signed · Apple notarized</li>
              <li>
                <a href="/changelog/">
                  v{VERSION}
                </a>
              </li>
            </ul>
          </div>
          <HeroScene />
        </section>

        <section className="section wrap" id="tour">
          <h2>Everything happens in one small window.</h2>
          <p className="section-lead">
            Your balance sits in the menu bar. Open the window to add entries, confirm payments and look ahead.
          </p>
          <Tour initialView="overview" />
          <div className="tour-download">
            <DownloadButton />
            <p>Free, and no account needed. Your money data stays on your Mac unless you set up sync.</p>
          </div>
        </section>

        <div className="wrap wrap-wide home-demos">
          <Bento />
        </div>

        <section className="section wrap" id="plan">
          <div className="feature">
            <div className="copy">
              <h2>See your balance after rent, before rent is due.</h2>
              <p>
                Add your bills, subscriptions and expected pay once. Pocket shows what your balance will be after
                each one, up to 12 months ahead, and takes out what you usually spend in between.
              </p>
              <ul className="dots">
                <li>A chart of where your balance is heading, 1 to 12 months out</li>
                <li>Counts your usual everyday spending, learned from your recent weeks</li>
                <li>Every upcoming payment, with your balance right after it</li>
                <li>Weekly to yearly, including every 3 months. Pause, skip or stop any of it</li>
              </ul>
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
              <h2>Made for money that doesn&apos;t arrive on schedule.</h2>
              <p>
                Freelance pay, a refund, the $40 a friend owes you. Mark it as waiting, and when it lands, click Got
                it and enter what actually arrived, even if it came late or short.
              </p>
              <ul className="dots">
                <li>Waiting payments sit in Overview until you click Got it or Skip</li>
                <li>Your balance moves only when you confirm</li>
                <li>A reminder on the day it&apos;s due</li>
              </ul>
              <a className="feature-guide" href="/guides/expected-income/">
                Guide: track expected income before it arrives <span aria-hidden="true">→</span>
              </a>
            </div>
            <PocketCharacter id="waiting" mood="excited" bubble="Can't wait!" style={{ width: "min(280px, 64vw)" }} />
          </div>

          <div className="feature quick-add-feature" id="quick-add">
            <div className="copy">
              <h2>Log your usual coffee in one keystroke.</h2>
              <p>
                Add a coffee once and choose Save as Button. After that it&apos;s one click, or ⌘1 to ⌘9 from the menu
                bar panel or the Pocket window, and your balance updates right away.
              </p>
              <a className="feature-guide" href="/guides/quick-add-spending/">
                Guide: set up quick-add buttons <span aria-hidden="true">→</span>
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
              <h2>See where each month went.</h2>
              <p>
                Pocket totals your spending by category and shows where your income came from. Switch between
                Month and All time, or click a category to see every entry in it. Search History by name or amount,
                and export what you find as a CSV spreadsheet.
              </p>
            </div>
            <figure className="categories-recording">
              <video
                controls
                muted
                playsInline
                preload="none"
                width={1540}
                height={1200}
                poster="/media/categories-2026-10-12.webp"
                aria-label="Pocket Categories: monthly spending, all-time totals, and purchases by category"
              >
                <source src="/media/categories-2026-10-12.mp4" type="video/mp4" />
                <a href="/media/categories-2026-10-12.mp4">Watch the Categories demonstration</a>
              </video>
            </figure>
          </div>
        </section>

        <section className="section wrap" id="private">
          <h2 className="two-tone">
            Free, <span>with every feature.</span>
            <br />
            <span>Your data lives in</span> one file on your Mac.
          </h2>
          <div className="local-default plan">
            <div className="local-copy">
              <h3>On your Mac</h3>
              <p>Download Pocket, type in today&apos;s balance, and add your first entry. Everything runs on your Mac.</p>
              <DownloadButton />
              <a className="feature-guide plan-guide" href="/guides/back-up-your-data/">
                Back up or move to a new Mac <span aria-hidden="true">→</span>
              </a>
            </div>
            <ul className="checks">
              <Check>One file on your Mac holds all your money data</Check>
              <Check>Works offline</Check>
              <Check>Seven daily backups you can restore</Check>
              <Check>Export a backup or a CSV spreadsheet any time</Check>
            </ul>
          </div>
          <details className="sync-details">
            <summary>
              <span>Want your balance on your phone too?</span>
              <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m6 9 6 6 6-6" /></svg>
            </summary>
            <div className="sync-content">
              <p>Connect Pocket to your own free Supabase project, then pair your phone with a 6-digit code. Your Mac keeps a full copy and keeps working offline.</p>
              <ul className="checks">
                <Check>The Pocket web app on your phone or any computer</Check>
                <Check>Pair a device with a 6-digit code</Check>
                <Check>Your Mac keeps a full copy and works offline</Check>
              </ul>
              <a className="pill pill-line" href={SELF_HOSTING_GUIDE_URL}>
                Read the self-hosting guide
              </a>
            </div>
          </details>
        </section>

        <section className="home-guides wrap" id="guides">
          <h2>Learn Pocket in three short guides.</h2>
          <p className="section-lead">Set your starting balance, turn your usual purchases into one-keystroke buttons, and track money you&apos;re still waiting for.</p>
          <GuideCards slugs={["getting-started", "quick-add-spending", "expected-income"]} />
          <a href="/guides/">All Pocket guides <span aria-hidden="true">↗</span></a>
        </section>

        <section className="section wrap" id="faq">
          <h2>Straight answers.</h2>
          <Faq items={FAQ} />
        </section>

        <section className="closing wrap home-closing">
          <img className="closing-sculpture" src="/pocket-sculpture.webp" alt="" width={200} height={200} loading="lazy" />
          <h2>Know what&apos;s left before you spend it.</h2>
          <p>Free for macOS 14 or later, on Apple Silicon and Intel. A {DMG_SIZE} download.</p>
          <div className="cta">
            <DownloadButton />
            <a className="pill pill-soft" href={REPO_URL}>
              View the source
            </a>
          </div>
        </section>
      </main>

      <SiteFooter />

      <DownloadDialog />
      <ButtonFx />
    </>
  );
}
