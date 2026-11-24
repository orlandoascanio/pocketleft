import type { Metadata } from "next";
import { GuideCards } from "@/components/GuideCards";
import { SiteFooter } from "@/components/SiteFooter";
import { DownloadDialog } from "@/components/DownloadDialog";
import { DownloadIcon, SiteNav } from "@/components/SiteNav";
import { AT_A_GLANCE, AT_A_GLANCE_ES, FACTS, FACTS_ES } from "@/lib/facts";
import { textParts } from "@/lib/guides";
import { ABOUT_PATHS, HOMEPAGE_PATHS, alternateLanguages, type Locale } from "@/lib/locale";
import { RELEASES, releaseDate } from "@/lib/releases";
import { AUTHOR, PUBLISHER } from "@/lib/schema";
import { DOWNLOAD_URL, ISSUES_URL, REPO_URL, SITE_URL } from "@/lib/site";
import "@/app/(en)/guides/guides.css";

// The "official" page answer engines look for: what Pocket is, in plain facts, and which Pocket it is.
const aboutCopy = {
  en: {
    title: "What is Pocket for Mac? PocketLeft at a glance",
    description: "Pocket (PocketLeft) is a free Mac menu bar app that shows the money you have left. Price, requirements, where data lives and how it differs from Mozilla Pocket.",
    imageAlt: "Pocket for Mac Overview",
    breadcrumb: "Breadcrumb",
    atAGlance: "Pocket at a glance",
    heading: "What is Pocket for Mac?",
    updated: "Updated",
    by: "By",
    facts: "Key facts",
    features: "What does Pocket do?",
    featuresIntro: "Pocket answers one question: how much money do you have left? You enter the amount you have today. After that, every purchase and payment you record changes the number in the menu bar.",
    featuresBody: "Bills, subscriptions and paychecks can repeat on their own. Income you're still waiting for stays out of the balance until you confirm what arrived. Plan estimates when your balance could run out using the dates and amounts you've entered. Insights shows where each month's money went.",
    audience: "Who is Pocket for?",
    audienceIntro: "People with a Mac who want to always know how much money they have left, without linking a bank account. Because every entry is typed, Pocket works the same with any bank, in any country and in any currency.",
    audienceBody: "It helps most when income doesn't arrive on a fixed schedule, for example [freelance pay](/guides/freelance-income/). If you'd rather have transactions imported automatically, a bank-sync app will suit you better. Read [manual tracking vs bank sync](/guides/manual-vs-bank-sync/) to decide.",
    which: "Which Pocket app is this?",
    maker: "Who makes Pocket?",
    safeDownload: "Download Pocket only from pocketleft.app or its GitHub page.",
    learn: "Learn more",
    downloadPitch: "Put your balance in the menu bar.",
    availability: "Free for macOS 14 or later, on Apple Silicon and Intel.",
    download: "Download for Mac",
  },
  es: {
    title: "¿Qué es Pocket para Mac? Conoce PocketLeft",
    description: "Pocket (PocketLeft) es una app gratuita que muestra tu saldo en la barra de menús de Mac. Conoce sus requisitos, dónde guarda tus datos y cómo funciona.",
    imageAlt: "Vista de resumen de Pocket para Mac",
    breadcrumb: "Ruta de navegación",
    atAGlance: "Pocket de un vistazo",
    heading: "¿Qué es Pocket para Mac?",
    updated: "Actualizado el",
    by: "Por",
    facts: "Datos clave",
    features: "¿Qué hace Pocket?",
    featuresIntro: "Pocket te muestra cuánto dinero te queda. Primero ingresas el saldo de hoy. A partir de ahí, cada compra y cada pago que registras actualiza el monto de la barra de menús.",
    featuresBody: "Puedes programar pagos, suscripciones y cobros recurrentes. Los ingresos pendientes se suman al saldo cuando confirmas cuánto recibiste. La vista Plan estima cuándo podría agotarse tu saldo con las fechas y los montos que ingresaste. Las estadísticas muestran en qué gastaste tu dinero cada mes.",
    audience: "¿Para quién es Pocket?",
    audienceIntro: "Pocket es para quienes tienen una Mac y quieren saber cuánto les queda sin vincular una cuenta bancaria. Como ingresas cada movimiento a mano, puedes usarlo con cualquier banco, en cualquier país y con cualquier moneda.",
    audienceBody: "Es especialmente práctico cuando tus ingresos llegan en fechas variables, como los [cobros por trabajo independiente](/guides/freelance-income/). Si prefieres importar los movimientos de forma automática, te conviene una app con sincronización bancaria. Lee la [comparación entre el registro manual y la sincronización bancaria](/guides/manual-vs-bank-sync/) para decidir.",
    which: "¿Cuál de todas las apps Pocket es esta?",
    maker: "¿Quién desarrolla Pocket?",
    safeDownload: "Descarga Pocket solo desde pocketleft.app o su página de GitHub.",
    learn: "Más sobre Pocket",
    downloadPitch: "Consulta tu saldo en la barra de menús.",
    availability: "Gratis para macOS 14 o posterior en Apple Silicon e Intel.",
    download: "Descargar para Mac",
  },
};

const factsUpdated = "2026-11-22";
const updated = RELEASES[0].date > factsUpdated ? RELEASES[0].date : factsUpdated;

export function aboutMetadata(locale: Locale): Metadata {
  const { title, description, imageAlt } = aboutCopy[locale];
  const url = ABOUT_PATHS[locale];
  return {
    title,
    description,
    alternates: { canonical: url, languages: alternateLanguages(ABOUT_PATHS) },
    openGraph: { title, description, url, images: [{ url: "/screenshot-overview.png", alt: imageAlt }] },
    twitter: { card: "summary_large_image", title, description, images: ["/screenshot-overview.png"] },
  };
}

function Text({ children }: { children: string }) {
  return textParts(children).map((part, index) => part.href ? <a href={part.href} key={index}>{part.text}</a> : part.text);
}

const OTHER_POCKETS = [
  ["PocketLeft.com", { en: "A separate personal finance coach website.", es: "Un sitio de asesoría en finanzas personales." }],
  ["Mozilla Pocket", { en: "A read-it-later app for saving articles, made by Mozilla. It has nothing to do with money.", es: "La app de Mozilla para guardar artículos y leerlos después." }],
  ["PocketGuard", { en: "A budgeting app that links to your bank accounts.", es: "Una app de presupuestos que se conecta a tus cuentas bancarias." }],
  ["Pocket Clear", { en: "A separate expense tracker for Mac and Android, from a different developer.", es: "Una app de control de gastos para Mac y Android de otro desarrollador." }],
  ["Left Pocket", { en: "A poker bankroll tracker app.", es: "Una app para llevar el control del dinero destinado al póquer." }],
] as const;

const relatedGuides = ["mac-menu-bar-money-apps", "getting-started", "manual-vs-bank-sync"];

const relatedGuidesSpanish = {
  "mac-menu-bar-money-apps": {
    category: "Elige una app",
    title: "Comparación de apps de finanzas para la barra de menús de Mac",
    description: "Compara qué saldo muestran simplebanking, Up Only y Pocket, cuánto cuestan y cuál se ajusta a lo que buscas.",
  },
  "getting-started": {
    category: "Empieza aquí",
    title: "Empieza a usar Pocket para Mac",
    description: "Ingresa tu saldo inicial, registra tu primera compra y agrega un pago en Pocket para Mac.",
  },
  "manual-vs-bank-sync": {
    category: "Elige cómo registrar tus gastos",
    title: "Registro manual o sincronización bancaria",
    description: "Compara cuándo conviene cada método y aprende a mantener tu saldo al día sin vincular un banco.",
  },
};

export function AboutPage({ locale }: { locale: Locale }) {
  const copy = aboutCopy[locale];
  const spanish = locale === "es";
  const url = SITE_URL + ABOUT_PATHS[locale];
  const home = HOMEPAGE_PATHS[locale];
  const facts = spanish ? FACTS_ES : FACTS;
  const schema = [
    {
      "@context": "https://schema.org",
      "@type": "AboutPage",
      name: copy.atAGlance,
      description: copy.description,
      url,
      dateModified: updated,
      inLanguage: locale,
      mainEntity: { "@id": `${SITE_URL}/#software` },
      author: AUTHOR,
      publisher: PUBLISHER,
    },
    { "@context": "https://schema.org", "@type": "BreadcrumbList", itemListElement: [
      { "@type": "ListItem", position: 1, name: "Pocket", item: SITE_URL + home },
      { "@type": "ListItem", position: 2, name: copy.atAGlance, item: url },
    ] },
  ];
  return <>
    <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }} />
    <SiteNav locale={locale} />
    <main className="wrap guide-page">
      <nav className="guide-breadcrumb" aria-label={copy.breadcrumb}><a href={home}>Pocket</a><span aria-hidden="true">/</span><span aria-current="page">{copy.atAGlance}</span></nav>
      <article>
        <header className="guide-header">
          <p className="guide-eyebrow">{copy.atAGlance}</p>
          <h1>{copy.heading}</h1>
          <p className="guide-lead">{spanish ? AT_A_GLANCE_ES : AT_A_GLANCE}</p>
          <p className="guide-date">{copy.updated} <time dateTime={updated}>{releaseDate(updated, locale)}</time> · {copy.by} <a href={AUTHOR.url}>{AUTHOR.name}</a></p>
        </header>
        <div className="guide-body about-body">
          <section id="facts">
            <h2>{copy.facts}</h2>
            <dl className="about-facts">
              {facts.map((fact) => <div key={fact.label}><dt>{fact.label}</dt><dd><Text>{fact.value}</Text></dd></div>)}
            </dl>
          </section>
          <section id="what-it-does">
            <h2>{copy.features}</h2>
            <p>{copy.featuresIntro}</p>
            <p>{copy.featuresBody}</p>
          </section>
          <section id="who-its-for">
            <h2>{copy.audience}</h2>
            <p>{copy.audienceIntro}</p>
            <p><Text>{copy.audienceBody}</Text></p>
          </section>
          <section id="other-pockets">
            <h2>{copy.which}</h2>
            <p>{spanish
              ? <>Pocket para Mac es la app de control de gastos de pocketleft.app, también conocida como PocketLeft o Pocket Left. Orlando Ascanio publica el código fuente en <a href={REPO_URL}>orlandoascanio/pocketleft</a>. Las siguientes apps tienen nombres parecidos y pertenecen a otros proyectos.</>
              : <>Pocket for Mac is the money tracker at pocketleft.app, also known as PocketLeft or Pocket Left. Orlando Ascanio publishes the source code as <a href={REPO_URL}>orlandoascanio/pocketleft</a>. These apps have similar names but are unrelated.</>}</p>
            <dl className="about-facts">
              {OTHER_POCKETS.map(([name, what]) => <div key={name}><dt>{name}</dt><dd>{what[locale]}</dd></div>)}
            </dl>
          </section>
          <section id="maker">
            <h2>{copy.maker}</h2>
            <p><Text>{spanish
              ? `[Orlando Ascanio](${AUTHOR.url}), desarrollador independiente. El código fuente de la app y este sitio está en [GitHub](${REPO_URL}). Consulta todas las versiones en las [notas de cambios](/changelog/) o [reporta un problema](${ISSUES_URL}).`
              : `[Orlando Ascanio](${AUTHOR.url}), an independent developer. The source code for the app and this website is on [GitHub](${REPO_URL}), every release is listed in the [changelog](/changelog/), and you can [report a bug](${ISSUES_URL}) there too.`}</Text></p>
            <p>{copy.safeDownload}</p>
          </section>
        </div>
      </article>
      <section className="guide-related"><h2>{copy.learn}</h2><GuideCards slugs={relatedGuides} spanishCopy={spanish ? relatedGuidesSpanish : undefined} /></section>
      <section className="guide-download">
        <div><h2>{copy.downloadPitch}</h2><p>{copy.availability}</p></div>
        <a className="pill pill-dark" href={DOWNLOAD_URL} data-download><DownloadIcon />{copy.download}</a>
      </section>
    </main>
    <SiteFooter locale={locale} />
    <DownloadDialog locale={locale} />
  </>;
}
