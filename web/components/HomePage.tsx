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
import { FAQ, FAQ_ES } from "@/lib/faq";
import { HOME_COPY } from "@/lib/home-copy";
import { HOMEPAGE_PATHS, SPANISH_DESCRIPTION, type Locale } from "@/lib/locale";
import { ALTERNATE_NAMES, AUTHOR, DISAMBIGUATION, PROFILES, PUBLISHER } from "@/lib/schema";
import "@/app/home.css";
import { RELEASES, releaseId } from "@/lib/releases";
import {
  DESCRIPTION,
  DOWNLOAD_PAGE,
  DOWNLOAD_URL,
  SELF_HOSTING_GUIDE_URL,
  SITE_URL,
  VERSION,
} from "@/lib/site";

const englishJsonLd = [
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
];

export function HomePage({ locale }: { locale: Locale }) {
  const copy = HOME_COPY[locale];
  const spanish = locale === "es";
  const faq = spanish ? FAQ_ES : FAQ;
  const url = SITE_URL + HOMEPAGE_PATHS[locale];
  const [website, software] = englishJsonLd;
  const jsonLd = [
    { ...website, url, inLanguage: locale },
    spanish ? {
      ...software,
      description: SPANISH_DESCRIPTION,
      url,
      disambiguatingDescription: undefined,
      featureList: undefined,
    } : software,
    {
      "@context": "https://schema.org",
      "@type": "FAQPage",
      inLanguage: locale,
      mainEntity: faq.map(({ q, a }) => ({ "@type": "Question", name: q, acceptedAnswer: { "@type": "Answer", text: a } })),
    },
  ];

  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <SiteNav locale={locale} />

      <main>
        <section className="hero hero-dimensional wrap">
          <div className="hero-copy">
            <HeroAnnounce>
              <a className="announce" href={"/changelog/#" + releaseId(VERSION)}>
                <span className="announce-tag">{copy.newRelease}</span>
                <b>Pocket {VERSION.replace(/\.0$/, "")}</b>
                <span className="announce-text">{copy.releaseSummary}</span>
                <span className="announce-arrow" aria-hidden="true">
                  ↗
                </span>
              </a>
            </HeroAnnounce>
            <HeroPlatformHeadline locale={locale} />
            <HeroActions locale={locale} downloadIcon={<DownloadIcon />} />
          </div>
          <HeroScene locale={locale} />
          <div className="hero-details"><HeroDownloadDetails locale={locale} /></div>
        </section>

        <section className="section wrap" id="tour">
          <div className="tour-intro">
            <div className="story-copy" id="waiting">
              <h2>{copy.tourHeading}</h2>
              <p>{copy.tourIntro}</p>
              <p>{copy.incomeAction}</p>
              <a className="feature-guide" href="/guides/expected-income/">{copy.incomeGuide} <span aria-hidden="true">→</span></a>
            </div>
            <figure className="pocket-film" id="video">
              <video controls playsInline preload="none" width={1920} height={1080}
                poster="/media/pocket-for-mac-demo.webp" aria-label={copy.videoLabel}>
                <source src="/media/pocket-for-mac-demo.mp4" type="video/mp4" />
                <a href="/media/pocket-for-mac-demo.mp4">{copy.videoLink}</a>
              </video>
            </figure>
          </div>
          <div className="tour-gallery">
            <h3>{copy.tourGallery}</h3>
            {spanish && <p className="tour-language-note">Las capturas, el video y las guías enlazadas están en inglés.</p>}
            <Tour initialView="overview" locale={locale} />
          </div>
        </section>

        <div className="wrap product-stories">
          <section className="product-story" id="quick-add">
            <div className="story-copy">
              <h2>{copy.quickHeading}</h2>
              <p>{copy.quickIntro}</p>
              <p>{copy.quickDetails}</p>
              <a className="feature-guide" href="/guides/quick-add-spending/">{copy.quickGuide} <span aria-hidden="true">→</span></a>
            </div>
            <QuickEntryPreview locale={locale} />
          </section>

          <section className="product-story story-reverse" id="plan">
            <div className="story-copy">
              <h2>{copy.planHeading}</h2>
              <p>{copy.planIntro}</p>
              <p>{copy.planDetails}</p>
              <a className="feature-guide" href="/guides/freelance-income/#before-payday">{copy.planGuide} <span aria-hidden="true">→</span></a>
            </div>
            <picture className="story-screen">
              <source media="(prefers-color-scheme: dark)" srcSet="/media/plan-1-5-5-dark.webp" />
              <img src="/media/plan-1-5-5-light.webp" width={1640} height={1270} loading="lazy" alt={copy.planImage} />
            </picture>
          </section>

          <section className="product-story" id="subscriptions">
            <div className="story-copy">
              <h2>{copy.renewalHeading}</h2>
              <p>{copy.renewalIntro}</p>
              <p>{copy.renewalDetails}</p>
              <a className="feature-guide" href="/guides/track-subscriptions/">{copy.renewalGuide} <span aria-hidden="true">→</span></a>
            </div>
            <RenewalPreview locale={locale} />
          </section>

          <section className="product-story story-reverse" id="categories">
            <div className="story-copy">
              <h2>{copy.categoriesHeading}</h2>
              <p>{copy.categoriesIntro}</p>
              <p>{copy.categoriesAction}</p>
            </div>
            <picture className="story-screen">
              <source media="(prefers-color-scheme: dark)" srcSet="/media/categories-1-5-3-dark.webp" />
              <img src="/media/categories-1-5-3-light.webp" width={1640} height={910} loading="lazy" alt={copy.categoriesImage} />
            </picture>
          </section>
        </div>

        <section className="section wrap home-help" aria-label={copy.helpLabel}>
          <div id="private">
            <h2>{copy.privacyHeading}</h2>
            <p>{copy.privacyBody}</p>
            <a className="feature-guide" href={SELF_HOSTING_GUIDE_URL}>{copy.pairingGuide}</a>
          </div>
          <div id="guides">
            <h2>{copy.helpHeading}</h2>
            <p>{copy.helpBody}</p>
            <a className="feature-guide" href="/guides/getting-started/">{copy.startGuide}</a>
            <a className="feature-guide" href="/guides/">{copy.allGuides}</a>
            <div id="faq"><Faq items={faq} /></div>
          </div>
        </section>

        <section className="wrap home-platforms" id="downloads" aria-labelledby="downloads-heading">
          <div className="download-invitation">
            <div>
              <h2 id="downloads-heading">{copy.downloadHeading}</h2>
              <p>{copy.downloadBody}</p>
              <div className="home-platform-links">
                <a className="pill pill-dark" href={DOWNLOAD_PAGE}><DownloadIcon />{copy.downloadChoose}</a>
                <a className="feature-guide" id="windows" href={DOWNLOAD_PAGE + "#windows"}>{copy.windowsSetup}</a>
              </div>
            </div>
            <img src="/pocket-sculpture.webp" width={180} height={180} loading="lazy" alt="" />
          </div>
        </section>
      </main>

      <SiteFooter locale={locale} />

      <ForDesktopPlatform platform="mac"><DownloadDialog locale={locale} /></ForDesktopPlatform>
      <ButtonFx />
    </>
  );
}
