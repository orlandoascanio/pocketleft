import type { Metadata } from "next";
import { DownloadDialog } from "@/components/DownloadDialog";
import { SiteFooter } from "@/components/SiteFooter";
import { DownloadIcon, SiteNav } from "@/components/SiteNav";
import { DOWNLOAD_PATHS, alternateLanguages, type Locale } from "@/lib/locale";
import { AUTHOR, PUBLISHER } from "@/lib/schema";
import {
  DMG_SIZE, DOWNLOAD_URL, SELF_HOSTING_GUIDE_URL, SITE_URL, VERSION,
  WEB_APP_URL, WINDOWS_SETUP_URL, WINDOWS_VERSION,
} from "@/lib/site";
import "@/app/download.css";

const downloadCopy = {
  en: {
    title: "Download PocketLeft for Mac and Windows",
    description: "Download PocketLeft for macOS 14 or later or get the Windows 11 preview. See installation steps and learn how to pair a phone with the Pocket web app.",
    windowsDescription: "A free manual expense tracker for Windows 11 that shows your balance in the system tray and works offline.",
    heading: "Download PocketLeft",
    intro: "PocketLeft is a free manual expense tracker. Install the Mac app or the Windows 11 preview to track your balance offline. You can open the same ledger in your browser after setting up sync.",
    platforms: "Download platforms",
    windowsPreview: "Windows preview",
    web: "Web app",
    macName: "Pocket for Mac",
    windowsName: "Pocket for Windows",
    macDownload: "Download for Mac",
    windowsDownload: "Download for Windows",
    macSignature: "Developer-signed and Apple-notarized",
    macInstall: "Install on Mac",
    macOpen: "Open Pocket.dmg from Downloads.",
    macMove: "Drag Pocket into Applications and open it.",
    macStart: "Set your starting balance. Click Pocket in the menu bar to log your first entry.",
    macGuide: "Mac setup guide",
    macNotes: "Mac release notes",
    windowsSignature: "Unsigned preview",
    windowsInstall: "Install on Windows",
    windowsRun: "Run Pocket-Setup.exe and choose an installation folder.",
    windowsEntry: "Click Pocket in the tray beside the clock to log an expense or income.",
    windowsNotes: "Windows release notes",
    webName: "Pocket web app",
    webRequirements: "For phones and desktop browsers with an existing synced ledger",
    webOpen: "Open the web app",
    webPair: "Pair your device",
    webSteps: "Set up Pocket Sync with your own Supabase project. From a connected device, generate a six-digit pairing code, then enter it in the web app.",
    webGuide: "Set up sync and pair a phone",
    macRequirements: <>Version {VERSION} · macOS 14 or later · Apple Silicon and Intel</>,
    windowsRequirements: <>Version {WINDOWS_VERSION} preview · Windows 11 · Intel, AMD, and ARM</>,
    windowsStart: <>Open Pocket, enter a starting balance, and choose Start local ledger to use it offline.</>,
    windowsDisplay: <>Right-click the tray icon and open Balance display to switch between Balance on hover and Floating panel.</>,
  },
  es: {
    title: "Descarga PocketLeft para Mac y Windows",
    description: "Descarga PocketLeft para macOS 14 o posterior o prueba la versión preliminar para Windows 11. Aprende a instalarlo y a vincular tu celular con la app web.",
    windowsDescription: "App gratuita para registrar gastos a mano en Windows 11. Funciona sin conexión y muestra tu saldo en la bandeja del sistema.",
    heading: "Descarga PocketLeft",
    intro: "PocketLeft es una app gratuita para registrar gastos a mano. Instala la app para Mac o la versión preliminar para Windows 11 y consulta tu saldo sin conexión. Si configuras la sincronización, también puedes abrir el mismo registro en tu navegador.",
    platforms: "Plataformas de descarga",
    windowsPreview: "Versión preliminar para Windows",
    web: "App web",
    macName: "Pocket para Mac",
    windowsName: "Pocket para Windows",
    macDownload: "Descargar para Mac",
    windowsDownload: "Descargar para Windows",
    macSignature: "Con firma del desarrollador y notarización de Apple",
    macInstall: "Instala Pocket en Mac",
    macOpen: "Abre Pocket.dmg desde la carpeta Descargas.",
    macMove: "Arrastra Pocket a la carpeta Aplicaciones y ábrelo.",
    macStart: "Ingresa tu saldo inicial. Haz clic en Pocket en la barra de menús para registrar tu primer movimiento.",
    macGuide: "Guía de instalación en Mac",
    macNotes: "Notas de la versión para Mac",
    windowsSignature: "Versión preliminar sin firma",
    windowsInstall: "Instala Pocket en Windows",
    windowsRun: "Ejecuta Pocket-Setup.exe y elige una carpeta de instalación.",
    windowsEntry: "Haz clic en Pocket en la bandeja del sistema, junto al reloj, para registrar un gasto o un ingreso.",
    windowsNotes: "Notas de la versión para Windows",
    webName: "App web de Pocket",
    webRequirements: "Para celulares y navegadores de escritorio con un registro ya sincronizado",
    webOpen: "Abre la app web",
    webPair: "Vincula tu dispositivo",
    webSteps: "Configura Pocket Sync con tu propio proyecto de Supabase. Desde un dispositivo conectado, genera un código de seis dígitos e introdúcelo en la app web.",
    webGuide: "Configura la sincronización y vincula tu celular",
    macRequirements: <>Versión {VERSION} · macOS 14 o posterior · Apple Silicon e Intel</>,
    windowsRequirements: <>Versión preliminar {WINDOWS_VERSION} · Windows 11 · Intel, AMD y ARM</>,
    windowsStart: <>Abre Pocket, ingresa tu saldo inicial y elige <span lang="en">Start local ledger</span> para usarlo sin conexión.</>,
    windowsDisplay: <>Haz clic derecho en el ícono de la bandeja y abre <span lang="en">Balance display</span>. Puedes mostrar el saldo al pasar el cursor (<span lang="en">Balance on hover</span>) o en un panel flotante (<span lang="en">Floating panel</span>).</>,
  },
};

export function downloadMetadata(locale: Locale): Metadata {
  const { title, description } = downloadCopy[locale];
  const url = DOWNLOAD_PATHS[locale];
  return {
    title,
    description,
    alternates: { canonical: url, languages: alternateLanguages(DOWNLOAD_PATHS) },
    openGraph: { title, description, url },
  };
}

export function DownloadPage({ locale }: { locale: Locale }) {
  const copy = downloadCopy[locale];
  const downloadPageUrl = SITE_URL + DOWNLOAD_PATHS[locale];
  const windowsApp = {
    "@type": "SoftwareApplication",
    "@id": SITE_URL + DOWNLOAD_PATHS.en + "#windows",
    name: copy.windowsName,
    description: copy.windowsDescription,
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

  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify({
        "@context": "https://schema.org",
        "@type": "WebPage",
        "@id": downloadPageUrl,
        name: copy.title,
        description: copy.description,
        inLanguage: locale,
        url: downloadPageUrl,
        mainEntity: [{ "@id": SITE_URL + "/#software" }, windowsApp],
      }) }} />
      <SiteNav locale={locale} />
      <main className="wrap download-page">
        <header className="download-intro">
          <h1>{copy.heading}</h1>
          <p>{copy.intro}</p>
          <nav aria-label={copy.platforms}>
            <a className="pill pill-soft" href="#mac">Mac</a>
            <a className="pill pill-soft" href="#windows">{copy.windowsPreview}</a>
            <a className="pill pill-soft" href="#web">{copy.web}</a>
          </nav>
        </header>

        <section className="download-card" id="mac" aria-labelledby="download-mac">
          <div>
            <h2 id="download-mac">{copy.macName}</h2>
            <p className="download-requirements">{copy.macRequirements}</p>
            <a className="pill pill-dark" href={DOWNLOAD_URL} data-download><DownloadIcon />{copy.macDownload}</a>
            <p className="download-file">Pocket.dmg · {DMG_SIZE} · {copy.macSignature}</p>
          </div>
          <div>
            <h3>{copy.macInstall}</h3>
            <ol>
              <li>{copy.macOpen}</li>
              <li>{copy.macMove}</li>
              <li>{copy.macStart}</li>
            </ol>
            <div className="download-related">
              <a href="/guides/getting-started/">{copy.macGuide}</a>
              <a href="/changelog/#mac">{copy.macNotes}</a>
            </div>
          </div>
        </section>

        <section className="download-card" id="windows" aria-labelledby="download-windows">
          <div>
            <h2 id="download-windows">{copy.windowsName}</h2>
            <p className="download-requirements">{copy.windowsRequirements}</p>
            <a className="pill pill-dark" href={WINDOWS_SETUP_URL}><DownloadIcon />{copy.windowsDownload}</a>
            <p className="download-file">Pocket-Setup.exe · {copy.windowsSignature}</p>
          </div>
          <div>
            <h3>{copy.windowsInstall}</h3>
            <ol>
              <li>{copy.windowsRun}</li>
              <li>{copy.windowsStart}</li>
              <li>{copy.windowsEntry}</li>
            </ol>
            <p>{copy.windowsDisplay}</p>
            <div className="download-related"><a href="/changelog/#windows">{copy.windowsNotes}</a></div>
          </div>
        </section>

        <section className="download-card" id="web" aria-labelledby="download-web">
          <div>
            <h2 id="download-web">{copy.webName}</h2>
            <p className="download-requirements">{copy.webRequirements}</p>
            <a className="pill pill-dark" href={WEB_APP_URL}>{copy.webOpen}</a>
          </div>
          <div>
            <h3>{copy.webPair}</h3>
            <p>{copy.webSteps}</p>
            <div className="download-related"><a href={SELF_HOSTING_GUIDE_URL}>{copy.webGuide}</a></div>
          </div>
        </section>
      </main>
      <SiteFooter locale={locale} />
      <DownloadDialog locale={locale} />
    </>
  );
}
