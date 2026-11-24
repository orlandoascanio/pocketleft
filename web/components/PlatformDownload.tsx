"use client";

import { useSyncExternalStore, type ReactNode } from "react";
import type { Locale } from "@/lib/locale";
import { DOWNLOAD_PAGE, DOWNLOAD_URL, VERSION, WEB_APP_URL, WINDOWS_SETUP_URL, WINDOWS_VERSION } from "@/lib/site";

type Platform = "mac" | "windows" | null;

function browserPlatform(): Platform {
  const browser = navigator as Navigator & { userAgentData?: { platform: string; mobile: boolean } };
  const { userAgent, platform, maxTouchPoints, userAgentData } = browser;
  if (userAgentData?.mobile || /Android|iPhone|iPad|iPod|Windows Phone|Mobile/i.test(userAgent)) return null;

  const hint = userAgentData?.platform.toLowerCase();
  if (hint === "windows") return "windows";
  if (hint === "macos") return maxTouchPoints > 1 ? null : "mac";
  if (hint) return null;

  if (/Windows NT/i.test(userAgent) || /^Win/i.test(platform)) return "windows";
  // iPadOS can identify itself as a Mac when requesting the desktop site.
  if (/Macintosh|Mac OS X/i.test(userAgent) || /^Mac/i.test(platform)) return maxTouchPoints > 1 ? null : "mac";
  return null;
}

const subscribe = () => () => {};
const serverPlatform = () => null;

export function useDownloadPlatform(): Platform {
  return useSyncExternalStore(subscribe, browserPlatform, serverPlatform);
}

export function ForDesktopPlatform({ platform, children }: {
  platform: NonNullable<Platform>;
  children: ReactNode;
}) {
  const detected = useDownloadPlatform();
  return detected === null || detected === platform ? children : null;
}

const downloadLabels = {
  en: { mac: "Download for Mac", windows: "Download for Windows", desktop: "View desktop downloads" },
  es: { mac: "Descargar para Mac", windows: "Descargar para Windows", desktop: "Ver descargas" },
};

const descriptions = {
  en: {
    windows: "A free offline expense tracker for Windows. Enter purchases by hand and see your balance beside the clock. Your bank account stays unlinked.",
    desktop: "A free offline expense tracker for Mac and Windows. Enter purchases by hand and see your balance in the menu bar or tray. Your bank account stays unlinked.",
  },
  es: {
    windows: "Controla tus gastos en Windows gratis y sin conexión. Registra tus compras a mano y consulta tu saldo junto al reloj, sin vincular tu cuenta bancaria.",
    desktop: "Controla tus gastos en Mac y Windows gratis y sin conexión. Registra tus compras a mano y consulta tu saldo en la barra de menús o la bandeja del sistema, sin vincular tu cuenta bancaria.",
  },
};

export function PlatformDownloadLink({ className, children, locale }: {
  locale: Locale;
  className?: string;
  children?: ReactNode;
}) {
  const platform = useDownloadPlatform();
  const label = downloadLabels[locale][platform ?? "desktop"];
  const href = platform === "mac" ? DOWNLOAD_URL : platform === "windows" ? WINDOWS_SETUP_URL : DOWNLOAD_PAGE;
  return (
    <a className={className} href={href} data-download={platform === "mac" || undefined}>
      {children}
      {label}
    </a>
  );
}

export function HeroPlatformHeadline({ locale }: { locale: Locale }) {
  const platform = useDownloadPlatform();
  return (
    <>
      <h1>{locale === "es" ? "Mira cuánto" : "Know what’s"}<br /><span>{locale === "es" ? "te queda." : "left."}</span></h1>
      <p className="lead">{descriptions[locale][platform === "windows" ? "windows" : "desktop"]}</p>
    </>
  );
}

export function HeroActions({ downloadIcon, locale }: { downloadIcon: ReactNode; locale: Locale }) {
  const spanish = locale === "es";
  const platform = useDownloadPlatform();
  return (
    <div className="cta" id="hero-cta">
      {platform ? (
        <>
          <PlatformDownloadLink locale={locale} className="pill pill-dark">{downloadIcon}</PlatformDownloadLink>
          <a className="pill pill-soft" href={platform === "mac" ? "#tour" : DOWNLOAD_PAGE + "#windows"}>
            {platform === "mac"
              ? (spanish ? "Explora la app para Mac" : "Take the Mac tour")
              : (spanish ? "Ver la versión para Windows" : "See the Windows preview")}
          </a>
        </>
      ) : (
        <>
          <a className="pill pill-dark" href="#try-pocket">{spanish ? "Prueba el registro de ejemplo" : "Try the sample ledger"}</a>
          <PlatformDownloadLink locale={locale} className="pill pill-soft">{downloadIcon}</PlatformDownloadLink>
        </>
      )}
    </div>
  );
}

export function HeroDownloadDetails({ locale }: { locale: Locale }) {
  const spanish = locale === "es";
  const platform = useDownloadPlatform();
  return (
    <>
      <ul className="meta">
        <li>{spanish ? "Gratis" : "Free"}</li>
        <li>{spanish ? "Sin cuenta" : "No account"}</li>
        {platform === "mac" ? <>
          <li>macOS 14+</li>
          <li>{spanish ? "Apple Silicon e Intel" : "Apple Silicon & Intel"}</li>
          <li>{spanish ? "Firma del desarrollador · Notarización de Apple" : "Developer signed · Apple notarized"}</li>
          <li><a href="/changelog/#mac">v{VERSION}</a></li>
        </> : platform === "windows" ? <>
          <li>Windows 11</li>
          <li>{spanish ? "Intel, AMD y ARM" : "Intel, AMD, and ARM"}</li>
          <li><a href="/changelog/#windows">v{WINDOWS_VERSION} {spanish ? "preliminar" : "preview"}</a></li>
        </> : <li><a href={DOWNLOAD_PAGE + "#windows"}>{spanish ? "Versión preliminar para Windows 11" : "Windows 11 preview"}</a></li>}
      </ul>
      {platform ? (
        <a className="hero-downloads-link" href={DOWNLOAD_PAGE}>{spanish ? "Todas las opciones de descarga" : "All download options"} <span aria-hidden="true">↗</span></a>
      ) : (
        <a className="hero-downloads-link" href={WEB_APP_URL}>{spanish ? "¿Ya vinculaste tu dispositivo? Abre la app web" : "Already synced? Open the web app"} <span aria-hidden="true">↗</span></a>
      )}
    </>
  );
}
