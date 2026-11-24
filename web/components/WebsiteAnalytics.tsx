"use client";

import { usePathname } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { ANALYTICS_CONFIGURED, ANALYTICS_PREFERENCE, MEASUREMENT_ID, analyticsEnabledForHost, pageLocation, readAnalyticsConsent, saveAnalyticsConsent, removeAnalyticsCookies, trackWebsiteEvent, type AnalyticsConsent, type AnalyticsChoice } from "@/lib/analytics";
import { HOMEPAGE_PATHS, type Locale } from "@/lib/locale";
import { DOWNLOAD_URL, REPO_URL, SELF_HOSTING_GUIDE_URL, SELF_HOSTING_URL, WINDOWS_SETUP_URL } from "@/lib/site";
import "./website-analytics.css";

const OPEN_PREFERENCES = "pocket:analytics-preferences";

export function AnalyticsPreferences({ locale }: { locale: Locale }) {
  const [enabled, setEnabled] = useState(false);
  useEffect(() => { setEnabled(analyticsEnabledForHost(window.location.hostname)); }, []);
  if (!enabled) return null;
  return <button className="analytics-preferences" type="button" aria-controls="website-consent"
    onClick={(event) => window.dispatchEvent(new CustomEvent(OPEN_PREFERENCES, { detail: event.currentTarget }))}>
    {locale === "es" ? "Preferencias de analítica" : "Analytics preferences"}
  </button>;
}

export function WebsiteAnalytics({ locale }: { locale: Locale }) {
  const spanish = locale === "es";
  const route = usePathname();
  const pathname = route === "/" ? "/" : `${route.replace(/\/$/, "")}/`;
  const [consent, setConsent] = useState<AnalyticsConsent | null>(null);
  const preference = consent?.choice;
  const [ready, setReady] = useState(false);
  const [editing, setEditing] = useState(false);
  const initialized = useRef(false);
  const lastPage = useRef("");
  const opener = useRef<HTMLElement | null>(null);
  const firstChoice = useRef<HTMLButtonElement>(null);
  const marketing = pathname === HOMEPAGE_PATHS[locale] || pathname === "/changelog/" || pathname === "/privacy/" || pathname === "/share/";

  useEffect(() => {
    function refresh() {
      const saved = readAnalyticsConsent();
      if (initialized.current && saved?.choice !== "accepted") {
        removeAnalyticsCookies();
        window.location.reload();
      } else setConsent(saved);
    }
    refresh();
    setReady(analyticsEnabledForHost(window.location.hostname));
    function onStorage(event: StorageEvent) {
      if (event.key !== ANALYTICS_PREFERENCE && event.key !== null) return;
      refresh();
    }
    function open(event: Event) {
      opener.current = (event as CustomEvent<HTMLElement>).detail;
      setEditing(true);
    }
    window.addEventListener("storage", onStorage);
    window.addEventListener("focus", refresh);
    window.addEventListener(OPEN_PREFERENCES, open);
    return () => {
      window.removeEventListener("storage", onStorage);
      window.removeEventListener("focus", refresh);
      window.removeEventListener(OPEN_PREFERENCES, open);
    };
  }, []);

  useEffect(() => {
    if (!consent) return;
    // Browser timeouts are limited to about 25 days; recheck long-lived tabs in chunks.
    const timer = window.setTimeout(() => {
      const saved = readAnalyticsConsent();
      if (initialized.current && saved?.choice !== "accepted") {
        removeAnalyticsCookies();
        window.location.reload();
      } else setConsent(saved);
    }, Math.min(Math.max(0, consent.expiresAt - Date.now()), 2_147_483_647));
    return () => window.clearTimeout(timer);
  }, [consent]);

  useEffect(() => {
    if (!editing) return;
    firstChoice.current?.focus();
    function close(event: KeyboardEvent) {
      if (event.key === "Escape") dismiss();
    }
    window.addEventListener("keydown", close);
    return () => window.removeEventListener("keydown", close);
  }, [editing]);

  useEffect(() => {
    if (!ready || !ANALYTICS_CONFIGURED || !marketing || preference !== "accepted") return;
    if (!initialized.current) {
      initialized.current = true;
      window.dataLayer = window.dataLayer || [];
      window.gtag = function () { window.dataLayer?.push(arguments); };
      window.gtag("consent", "default", {
        analytics_storage: "granted", ad_storage: "denied",
        ad_user_data: "denied", ad_personalization: "denied",
      });
      window.gtag("js", new Date());
      let referrer = "";
      try { referrer = new URL(document.referrer).origin; } catch { /* Direct visit. */ }
      window.gtag("config", MEASUREMENT_ID, {
        send_page_view: false, allow_google_signals: false, allow_ad_personalization_signals: false,
        page_location: pageLocation(pathname), page_referrer: referrer,
      });
      const script = document.createElement("script");
      script.id = "pocket-ga";
      script.async = true;
      script.src = `https://www.googletagmanager.com/gtag/js?id=${MEASUREMENT_ID}`;
      document.head.appendChild(script);
    }
    if (lastPage.current !== pathname) {
      lastPage.current = pathname;
      window.gtag?.("set", { page_location: pageLocation(pathname), page_title: document.title });
      trackWebsiteEvent("page_view", { page_title: document.title });
    }

    function onClick(event: MouseEvent) {
      const link = event.target instanceof Element ? event.target.closest("a") : null;
      if (!link) return;
      const location = link.closest(".dl") ? "install_dialog" : link.closest(".nav-shell") ? "navigation" : link.closest(".hero") ? "hero" : link.closest("footer") ? "footer" : "content";
      if (link.hasAttribute("data-star")) trackWebsiteEvent("star_link_opened", { location });
      else if (link.href === DOWNLOAD_URL) trackWebsiteEvent("download_clicked", { location, download_target: "latest" });
      else if (link.href === WINDOWS_SETUP_URL) trackWebsiteEvent("download_clicked", { location, download_target: "windows" });
      else if (link.href === SELF_HOSTING_URL || (link.origin === window.location.origin && link.pathname === SELF_HOSTING_GUIDE_URL)) trackWebsiteEvent("self_hosting_opened", { location });
      else if (link.pathname === "/app/") trackWebsiteEvent("web_app_opened", { location });
      else if (link.href === REPO_URL) trackWebsiteEvent("source_opened", { location });
    }
    document.addEventListener("click", onClick);
    return () => document.removeEventListener("click", onClick);
  }, [pathname, preference, marketing, ready]);

  function dismiss() {
    setEditing(false);
    opener.current?.focus();
  }

  function choose(value: AnalyticsChoice) {
    setConsent(saveAnalyticsConsent(value));
    dismiss();
    if (value === "rejected") {
      window.gtag?.("consent", "update", { analytics_storage: "denied" });
      removeAnalyticsCookies();
      // Unload an already accepted tag so no further automatic events can run.
      if (initialized.current) window.location.reload();
    }
  }

  if (!ANALYTICS_CONFIGURED || !ready || !marketing) return null;
  const prompt = (preference !== "accepted" && preference !== "rejected") || editing;

  return <>
    {prompt && <aside id="website-consent" className="website-consent" aria-labelledby="website-consent-title">
      <p id="website-consent-title">{spanish ? "¿Permites la analítica del sitio?" : "Allow website analytics?"}</p>
      <span>{spanish ? "Ayúdanos a entender las visitas y los clics de descarga. No recopilamos tus saldos ni movimientos de Pocket." : "Help us understand visits and download clicks. Your Pocket balances and entries aren’t collected."} <a href="/privacy/">{spanish ? "Más información" : "Details"}</a></span>
      <small>{spanish ? "Guardaremos tu elección durante 180 días." : "We’ll remember your choice for 180 days."}</small>
      <div>
        <button ref={firstChoice} className="pill pill-line" type="button" onClick={() => choose("rejected")}>{spanish ? "No, gracias" : "No thanks"}</button>
        <button className="pill pill-line" type="button" onClick={() => choose("accepted")}>{spanish ? "Permitir analítica" : "Allow analytics"}</button>
        {editing && <button className="website-consent-cancel" type="button" onClick={dismiss}>{spanish ? "Cancelar" : "Cancel"}</button>}
      </div>
    </aside>}
  </>;
}
