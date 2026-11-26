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
const GA_CONFIGURED = /^G-[A-Z0-9]+$/.test(MEASUREMENT_ID);
const POSTHOG_TOKEN = process.env.NEXT_PUBLIC_POSTHOG_PROJECT_TOKEN;
const POSTHOG_HOST = process.env.NEXT_PUBLIC_POSTHOG_HOST;
const SITE_HOST = new URL(SITE_URL).hostname;
let postHogInitialized = false;
type Gtag = (...args: unknown[]) => void;

export function googleAnalyticsEnabledForHost(hostname: string) {
  return GA_CONFIGURED && (
    process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID !== undefined || hostname === SITE_HOST
  );
}

function postHogEnabledForHost(hostname: string) {
  return Boolean(POSTHOG_TOKEN && POSTHOG_HOST && hostname === SITE_HOST);
}

export function analyticsEnabledForHost(hostname: string) {
  return googleAnalyticsEnabledForHost(hostname) || postHogEnabledForHost(hostname);
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

function hasWebsiteConsent() {
  return !/^\/app(?:\/|$)/.test(window.location.pathname) && readAnalyticsConsent()?.choice === "accepted";
}

function cleanUrl(value: unknown, originOnly = false) {
  if (typeof value !== "string") return undefined;
  try {
    const url = new URL(value);
    if (url.protocol === "http:" || url.protocol === "https:") {
      return originOnly ? url.origin : url.origin + url.pathname;
    }
  } catch { /* Direct visits can have a non-URL referrer. */ }
  return undefined;
}

function startPostHog() {
  if (postHogInitialized || !POSTHOG_TOKEN || !POSTHOG_HOST) return;
  posthog.init(POSTHOG_TOKEN, {
    api_host: POSTHOG_HOST,
    defaults: "2026-08-30",
    person_profiles: "never",
    persistence: "localStorage",
    opt_out_persistence_by_default: true,
    autocapture: false,
    capture_pageview: false,
    capture_pageleave: false,
    capture_dead_clicks: false,
    capture_exceptions: false,
    capture_performance: false,
    disable_session_recording: true,
    disable_surveys: true,
    disable_external_dependency_loading: true,
    advanced_disable_flags: true,
    enable_heatmaps: false,
    mask_personal_data_properties: true,
    property_denylist: ["$set", "$set_once"],
    before_send: (event) => {
      if (!event?.properties || !hasWebsiteConsent()) return null;
      for (const key of ["$current_url", "$session_entry_url", "$referrer", "$session_entry_referrer"]) {
        if (key in event.properties) event.properties[key] = cleanUrl(event.properties[key], key.endsWith("referrer"));
      }
      return event;
    },
  });
  if (posthog.has_opted_out_capturing()) posthog.opt_in_capturing({ captureEventName: false });
  postHogInitialized = true;
}

export function stopPostHog() {
  if (postHogInitialized) posthog.opt_out_capturing();
}

export function trackWebsiteEvent(name: string, properties: Record<string, string>) {
  if (!hasWebsiteConsent()) return;
  const { hostname, pathname } = window.location;
  const eventProperties = {
    ...properties,
    locale: /^\/es(?:\/|$)/.test(pathname) ? "es" : "en",
    page_location: pageLocation(pathname),
  };
  try {
    if (googleAnalyticsEnabledForHost(hostname)) window.gtag?.("event", name, {
      ...eventProperties,
      ...(process.env.NEXT_PUBLIC_GA_DEBUG === "true" ? { debug_mode: true } : {}),
    });
  } catch { /* A blocked Google tag should not affect the other provider. */ }
  try {
    if (!postHogEnabledForHost(hostname)) return;
    startPostHog();
    posthog.capture(name === "page_view" ? "$pageview" : name, eventProperties,
      name === "page_view" ? undefined : { send_instantly: true, transport: "sendBeacon" });
  } catch { /* Download and navigation work when analytics is unavailable. */ }
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
