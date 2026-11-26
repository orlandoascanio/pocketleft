import posthog from "posthog-js";
import { SITE_URL } from "./site";

export const ANALYTICS_PREFERENCE = "pocket-website-analytics";
export const ANALYTICS_CONSENT_DURATION = 180 * 24 * 60 * 60 * 1000;
export type AnalyticsChoice = "accepted" | "rejected";
export type AnalyticsConsent = { choice: AnalyticsChoice; expiresAt: number };
let sessionConsent: AnalyticsConsent | null = null;

export function saveAnalyticsConsent(choice: AnalyticsChoice, now = Date.now()): AnalyticsConsent {
  const consent = { choice, expiresAt: now + ANALYTICS_CONSENT_DURATION };
  sessionConsent = consent;
  try { localStorage.setItem(ANALYTICS_PREFERENCE, JSON.stringify(consent)); } catch { /* Keep the choice for this page when storage is unavailable. */ }
  return consent;
}

export function readAnalyticsConsent(now = Date.now()): AnalyticsConsent | null {
  let raw: string | null;
  try {
    raw = localStorage.getItem(ANALYTICS_PREFERENCE);
  } catch {
    return sessionConsent && sessionConsent.expiresAt > now ? sessionConsent : null;
  }
  // Migrate existing choices once, without asking returning visitors again.
  if (raw === "accepted" || raw === "rejected") return saveAnalyticsConsent(raw, now);
  if (raw) {
    try {
      const saved = JSON.parse(raw);
      if (saved && (saved.choice === "accepted" || saved.choice === "rejected") &&
          typeof saved.expiresAt === "number" && Number.isFinite(saved.expiresAt) && saved.expiresAt > now) {
        sessionConsent = saved;
        return saved;
      }
    } catch { /* Malformed data is not consent. */ }
    try { localStorage.removeItem(ANALYTICS_PREFERENCE); } catch { /* Storage may be read-only. */ }
  }
  sessionConsent = null;
  return null;
}
// The Measurement ID is public. An explicit env value overrides it; blank disables tracking.
export const MEASUREMENT_ID = process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID ?? "G-6LLJJ52MDL";
export const ANALYTICS_CONFIGURED = /^G-[A-Z0-9]+$/.test(MEASUREMENT_ID);
const POSTHOG_CONFIGURED = Boolean(
  process.env.NEXT_PUBLIC_POSTHOG_PROJECT_TOKEN && process.env.NEXT_PUBLIC_POSTHOG_HOST,
);
type Gtag = (...args: unknown[]) => void;

export function analyticsEnabledForHost(hostname: string) {
  // Keep preview and localhost visits out of the live stream unless explicitly configured.
  return ANALYTICS_CONFIGURED && (
    process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID !== undefined || hostname === new URL(SITE_URL).hostname
  );
}

declare global {
  interface Window {
    dataLayer?: unknown[];
    gtag?: Gtag;
  }
}

// Keep arbitrary query strings, hashes, and pairing parameters out of analytics.
export function pageLocation(pathname: string) {
  return `${SITE_URL}${pathname}`;
}

export function trackWebsiteEvent(name: string, properties: Record<string, string>) {
  try {
    if (!analyticsEnabledForHost(window.location.hostname) || readAnalyticsConsent()?.choice !== "accepted") return;
    const eventProperties = {
      ...properties,
      page_location: pageLocation(window.location.pathname),
    };
    window.gtag?.("event", name, {
      ...eventProperties,
      ...(process.env.NEXT_PUBLIC_GA_DEBUG === "true" ? { debug_mode: true } : {}),
    });
    if (POSTHOG_CONFIGURED && name !== "page_view") posthog.capture(name, eventProperties);
  } catch { /* Download and navigation always work, even with blocked storage or tags. */ }
}

export function removeAnalyticsCookies() {
  const hostname = window.location.hostname;
  const domains = ["", hostname, ...hostname.split(".").map((_, i, parts) => `.${parts.slice(i).join(".")}`)];
  for (const cookie of document.cookie.split(";")) {
    const name = cookie.split("=")[0].trim();
    if (!/^_ga(?:_|$)/.test(name)) continue;
    for (const domain of domains) {
      document.cookie = `${name}=; Max-Age=0; path=/;${domain ? ` domain=${domain};` : ""} SameSite=Lax`;
    }
  }
}
