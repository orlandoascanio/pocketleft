import type { Metadata } from "next";
import { GuideCards } from "@/components/GuideCards";
import { SiteFooter } from "@/components/SiteFooter";
import { DownloadDialog } from "@/components/DownloadDialog";
import { DownloadIcon, SiteNav } from "@/components/SiteNav";
import { AT_A_GLANCE, FACTS } from "@/lib/facts";
import { textParts } from "@/lib/guides";
import { RELEASES, releaseDate } from "@/lib/releases";
import { AUTHOR, PUBLISHER } from "@/lib/schema";
import { DOWNLOAD_URL, ISSUES_URL, REPO_URL, SITE_URL } from "@/lib/site";
import "../guides/guides.css";

// The "official" page answer engines look for: what Pocket is, in plain facts, and which Pocket it is.
const title = "What is Pocket for Mac? PocketLeft at a glance";
const description = "Pocket (PocketLeft) is a free Mac menu bar app that shows the money you have left. Price, requirements, where data lives and how it differs from Mozilla Pocket.";
const updated = RELEASES[0].date;

export const metadata: Metadata = {
  title,
  description,
  alternates: { canonical: "/about/" },
  openGraph: { title, description, url: "/about/", images: [{ url: "/screenshot-overview.png", alt: "Pocket for Mac Overview" }] },
  twitter: { card: "summary_large_image", title, description, images: ["/screenshot-overview.png"] },
};

function Text({ children }: { children: string }) {
  return textParts(children).map((part, index) => part.href ? <a href={part.href} key={index}>{part.text}</a> : part.text);
}

const OTHER_POCKETS = [
  ["Mozilla Pocket", "A read-it-later app for saving articles, made by Mozilla. It has nothing to do with money."],
  ["PocketGuard", "A budgeting app that links to your bank accounts."],
  ["Pocket Clear", "A separate expense tracker for Mac and Android, from a different developer."],
  ["Left Pocket", "A poker bankroll tracker app."],
];

export default function AboutPage() {
  const schema = [
    {
      "@context": "https://schema.org",
      "@type": "AboutPage",
      name: "Pocket at a glance",
      description,
      url: `${SITE_URL}/about/`,
      dateModified: updated,
      inLanguage: "en",
      mainEntity: { "@id": `${SITE_URL}/#software` },
      author: AUTHOR,
      publisher: PUBLISHER,
    },
    { "@context": "https://schema.org", "@type": "BreadcrumbList", itemListElement: [
      { "@type": "ListItem", position: 1, name: "Pocket", item: `${SITE_URL}/` },
      { "@type": "ListItem", position: 2, name: "Pocket at a glance", item: `${SITE_URL}/about/` },
    ] },
  ];
  return <>
    <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }} />
    <SiteNav />
    <main className="wrap guide-page">
      <nav className="guide-breadcrumb" aria-label="Breadcrumb"><a href="/">Pocket</a><span aria-hidden="true">/</span><span aria-current="page">Pocket at a glance</span></nav>
      <article>
        <header className="guide-header">
          <p className="guide-eyebrow">Pocket at a glance</p>
          <h1>What is Pocket for Mac?</h1>
          <p className="guide-lead">{AT_A_GLANCE}</p>
          <p className="guide-date">Updated <time dateTime={updated}>{releaseDate(updated)}</time> · By <a href={AUTHOR.url}>{AUTHOR.name}</a></p>
        </header>
        <div className="guide-body about-body">
          <section id="facts">
            <h2>Key facts</h2>
            <dl className="about-facts">
              {FACTS.map((fact) => <div key={fact.label}><dt>{fact.label}</dt><dd><Text>{fact.value}</Text></dd></div>)}
            </dl>
          </section>
          <section id="what-it-does">
            <h2>What does Pocket do?</h2>
            <p>Pocket answers one question: how much money do you have left? You enter the amount you have today. After that, every purchase and payment you record changes the number in the menu bar.</p>
            <p>Bills, subscriptions and paychecks can repeat on their own. Income you're still waiting for stays out of the balance until you confirm what arrived. Plan shows your balance for the next 1, 3, 6 or 12 months, and the date it would run out. Insights shows where each month's money went.</p>
          </section>
          <section id="who-its-for">
            <h2>Who is Pocket for?</h2>
            <p>People with a Mac who want to always know how much money they have left, without linking a bank account. Because every entry is typed, Pocket works the same with any bank, in any country and in any currency.</p>
            <p><Text>{"It helps most when income doesn't arrive on a fixed schedule, for example [freelance pay](/guides/freelance-income/). If you'd rather have transactions imported automatically, a bank-sync app will suit you better. Read [manual tracking vs bank sync](/guides/manual-vs-bank-sync/) to decide."}</Text></p>
          </section>
          <section id="other-pockets">
            <h2>Is this the same as Mozilla Pocket?</h2>
            <p>No. Pocket for Mac is a money app published at pocketleft.app and on GitHub as <a href={REPO_URL}>orlandoascanio/pocketleft</a>. It's sometimes written as Pocket Left or pocketleft. These apps have similar names but are unrelated:</p>
            <dl className="about-facts">
              {OTHER_POCKETS.map(([name, what]) => <div key={name}><dt>{name}</dt><dd>{what}</dd></div>)}
            </dl>
          </section>
          <section id="maker">
            <h2>Who makes Pocket?</h2>
            <p><Text>{`[Orlando Ascanio](${AUTHOR.url}), an independent developer. The source code for the app and this website is on [GitHub](${REPO_URL}), every release is listed in the [changelog](/changelog/), and you can [report a bug](${ISSUES_URL}) there too.`}</Text></p>
            <p>Download Pocket only from pocketleft.app or its GitHub page.</p>
          </section>
        </div>
      </article>
      <section className="guide-related"><h2>Learn more</h2><GuideCards slugs={["mac-menu-bar-money-apps", "getting-started", "manual-vs-bank-sync"]} /></section>
      <section className="guide-download">
        <div><h2>Put your balance in the menu bar.</h2><p>Free for macOS 14 or later, on Apple Silicon and Intel.</p></div>
        <a className="pill pill-dark" href={DOWNLOAD_URL} data-download><DownloadIcon />Download for Mac</a>
      </section>
    </main>
    <SiteFooter />
    <DownloadDialog />
  </>;
}
