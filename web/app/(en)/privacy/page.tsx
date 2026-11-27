import type { Metadata } from "next";
import { SiteNav } from "@/components/SiteNav";
import { SiteFooter } from "@/components/SiteFooter";
import { REPO_URL } from "@/lib/site";

export const metadata: Metadata = {
  title: "Privacy · Pocket for Mac",
  description: "How Pocket’s website handles optional analytics and error reports, separately from your money data.",
  alternates: { canonical: "/privacy/" },
  openGraph: { title: "Website privacy · Pocket", description: "Optional website analytics and error reports, separately from your money data.", url: "/privacy/" },
};

export default function PrivacyPage() {
  const isVercel = process.env.VERCEL === "1";
  const hostingProvider = isVercel ? "Vercel" : "Netlify";
  const hostingPrivacyUrl = isVercel
    ? "https://vercel.com/legal/privacy-notice"
    : "https://www.netlify.com/privacy/";

  return <>
    <SiteNav />
    <main className="section wrap" style={{ paddingTop: 140, maxWidth: 760 }}>
      <h1>Privacy</h1>
      <p>This page describes pocketleft.app and the anonymous usage data in Pocket for Mac. Measurement is separate from the money you enter in Pocket.</p>
      <h2>Your money data</h2>
      <p>Pocket stores your money on your Mac by default. If you enable optional sync, your chosen server stores the shared copy. The paired web app at /app/ runs without website analytics or error reporting.</p>
      <h2 id="mac-app">Usage data and crash reports in Pocket for Mac</h2>
      <p>Pocket for Mac sends anonymous usage data and crash reports by default. To stop both, turn off Share anonymous usage data and crash reports in Settings.</p>
      <p>While it’s on, the app sends PostHog a count the first time it runs with a new ID, when the app is used on a given day, after an update, and when you add an entry, schedule a payment, or connect sync. Each count includes the app version, macOS version, and system language. Amounts, entry and payment names, categories, balances, currency, and sync details are never included. PostHog location lookup is turned off for these events, though PostHog can still receive your IP address as part of the request.</p>
      <p>Counts are grouped by a random ID stored on your Mac. Turning sharing off stops sending and deletes that ID. Turning it on again starts a new ID. PostHog retains counts it already received according to its retention settings.</p>
      <p>When the app crashes or hits an unexpected error, Sentry receives a report to help fix it. Reports include the error, stack trace, app version, Mac model, and macOS version. They exclude your money data, your Mac’s name, user identity, activity history, and network details, and Sentry discards IP addresses for these reports.</p>
      <h2>Optional website analytics</h2>
      <p>When configured, Google Analytics and PostHog start collecting website analytics after you choose Allow analytics. They measure public page visits and actions such as opening the download page, clicking the Mac or Windows installer, and viewing installation help. A download click measures interest in the installer.</p>
      <p>Google Analytics uses first-party cookies, and PostHog uses browser storage to group visits. These services may process technical information about your browser, device, and visit. Website events use cleaned URLs, and PostHog can use standard campaign tags for attribution. Your balances, entries, and pairing details stay outside website analytics.</p>
      <p>Your choice is saved in this browser for 180 days. We ask again when it expires or this site’s saved data is cleared. Use Analytics preferences in the footer to change it anytime. Choosing No thanks stops analytics and clears this site’s Google Analytics cookies and active PostHog tracking storage. The services retain measurements they already received according to their retention settings.</p>
      <h2>Website error reports</h2>
      <p>When configured, Sentry receives errors from the public website to help fix broken pages. Reports can include the error, stack trace, browser information, and website version. Request headers, cookies, bodies, user identity, and URL query parameters are excluded. Session replay and performance tracing are disabled. Sentry error reporting operates independently of the analytics choice.</p>
      <h2>Hosting and downloads</h2>
      <p>{hostingProvider} hosts the website and GitHub hosts downloads. These services can process requests and technical information such as IP addresses under their own policies.</p>
      <p><a href="https://policies.google.com/privacy">Google privacy policy</a> · <a href="https://sentry.io/privacy/">Sentry privacy policy</a> · <a href={hostingPrivacyUrl}>{hostingProvider} privacy policy</a> · <a href="https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement">GitHub privacy policy</a></p>
      <p>Questions or corrections: <a href={`${REPO_URL}/issues`}>open an issue on GitHub</a>. Don’t include private money data in a public issue.</p>
    </main>
    <SiteFooter />
  </>;
}
