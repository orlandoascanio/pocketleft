import { HOMEPAGE_PATHS, type Locale } from "@/lib/locale";
import { AnalyticsPreferences } from "@/components/WebsiteAnalytics";
import {
  DOWNLOAD_PAGE,
  ISSUES_URL,
  RELEASES_URL,
  REPO_URL,
  SELF_HOSTING_GUIDE_URL,
  VERSION,
  WEB_APP_URL,
} from "@/lib/site";

// One footer for every public page, so the changelog, source and help links never disappear
// once a visitor leaves the homepage. Section links point to the homepage for the current language.
export function SiteFooter({ locale = "en" }: { locale?: Locale }) {
  const spanish = locale === "es";
  const home = HOMEPAGE_PATHS[locale];
  return (
    <footer className="foot">
      <div className="wrap foot-grid">
        <div className="foot-brand">
          <a className="brand" href={home}>
            <img src="/pocket-icon.webp" alt="" width={28} height={28} />
            Pocket
          </a>
          <p>{spanish ? "Tu saldo en la barra de menús y hasta cuándo te alcanza." : "Your balance in the menu bar, and how long it will last."}</p>
          <a className="foot-ver" href="/changelog/">
            v{VERSION} · {spanish ? "Notas de la versión" : "Release notes"}
          </a>
          <span className="foot-badge">
            <svg viewBox="0 0 16 16" aria-hidden="true">
              <path d="m3 8.5 3.2 3L13 4.5" />
            </svg>
            {spanish ? "App para Mac firmada y notarizada por Apple" : "Mac app signed and notarized by Apple"}
          </span>
        </div>
        <nav className="foot-col" aria-label={spanish ? "Producto" : "Product"}>
          <h3>{spanish ? "Producto" : "Product"}</h3>
          <a href={`${home}#tour`}>{spanish ? "Funciones" : "Features"}</a>
          <a href={DOWNLOAD_PAGE}>{spanish ? "Descargar" : "Download"}</a>
          <a href={WEB_APP_URL}>{spanish ? "App web" : "Web app"}</a>
        </nav>
        <nav className="foot-col" aria-label={spanish ? "Ayuda" : "Help"}>
          <h3>{spanish ? "Ayuda" : "Help"}</h3>
          <a href="/guides/">{spanish ? "Guías" : "Guides"}</a>
          <a href={SELF_HOSTING_GUIDE_URL}>{spanish ? "Vinculación y sincronización con el celular" : "Phone pairing and sync"}</a>
          <a href={ISSUES_URL}>{spanish ? "Reportar un problema" : "Report a bug"}</a>
        </nav>
        <nav className="foot-col" aria-label={spanish ? "Proyecto" : "Project"}>
          <h3>{spanish ? "Proyecto" : "Project"}</h3>
          <a href="/about/">{spanish ? "Acerca de Pocket" : "About Pocket"}</a>
          <a href={REPO_URL}>{spanish ? "Código fuente" : "Source code"}</a>
          <a href={REPO_URL} data-star>
            {spanish ? "Dale una estrella en GitHub" : "Star on GitHub"}
          </a>
          <a href="/changelog/">{spanish ? "Novedades" : "Changelog"}</a>
          <a href={RELEASES_URL}>{spanish ? "Todas las versiones" : "All releases"}</a>
          <a href="https://www.orlandoascanio.com">{spanish ? "Creado por Orlando Ascanio" : "Made by Orlando Ascanio"}</a>
        </nav>
      </div>
      <div className="wrap foot-base">
        <span>
          {spanish
            ? <>Descarga Pocket solo desde <b>pocketleft.app</b> o su página de GitHub.</>
            : <>Download Pocket only from <b>pocketleft.app</b> or its GitHub page.</>}
        </span>
        <nav className="foot-legal" aria-label={spanish ? "Preferencias del sitio" : "Website preferences"}>
          <a href="/privacy/">{spanish ? "Privacidad del sitio" : "Website privacy"}</a>
          <AnalyticsPreferences locale={locale} />
        </nav>
      </div>
      <div className="foot-word" aria-hidden="true">Pocket</div>
    </footer>
  );
}
