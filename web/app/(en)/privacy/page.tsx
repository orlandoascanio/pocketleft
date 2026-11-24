import type { Metadata } from "next";
import { SiteNav } from "@/components/SiteNav";
import { SiteFooter } from "@/components/SiteFooter";
import { REPO_URL } from "@/lib/site";

export const metadata: Metadata = {
  title: "Website Privacy · Pocket for Mac",
  description: "How Pocket’s website handles optional analytics and error reports, separately from your money data.",
  alternates: { canonical: "/privacy/" },
  openGraph: { title: "Website privacy · Pocket", description: "Optional website analytics and error reports, separately from your money data.", url: "/privacy/" },
};

export default function PrivacyPage() {
  return <>
    <SiteNav />
    <main className="section wrap" style={{ paddingTop: 140, maxWidth: 760 }}>
      <h1>Website privacy</h1>
      <p>This page describes pocketleft.app. Website measurement is separate from the money you enter in Pocket.</p>
      <h2>Your money data</h2>
      <p>Pocket stores your money on your Mac by default. If you enable optional sync, your chosen server stores the shared copy. The paired web app at /app/ has no Google Analytics or Sentry integration.</p>
      <h2>Optional website analytics</h2>
      <p>When configured, Google Analytics loads only after you choose Allow analytics. It measures public page visits and clicks on downloads, the source code, Star on GitHub links, the self-hosting guide, and the web app link. A download click records intent; it does not confirm a completed download or installation.</p>
      <p>Analytics can use first-party cookies and process technical information about your browser, device, and visit. The website omits URL query strings and fragments from its analytics events. It does not send your balances, entries, or pairing details.</p>
      <p>Your choice is saved in this browser for 180 days. We ask again when it expires or this site’s saved data is cleared. Use Analytics preferences in the footer to change it anytime. Choosing No thanks stops analytics and removes this site’s Google Analytics cookies. It does not delete measurements already received by Google.</p>
      <h2>Website error reports</h2>
      <p>When configured, Sentry receives errors from the public website to help fix broken pages. Reports can include the error, stack trace, browser information, and website version. Request headers, cookies, bodies, user identity, and URL query parameters are excluded. Session replay and performance tracing are disabled. The analytics choice controls Google Analytics; it does not control error reporting.</p>
      <h2>Hosting and downloads</h2>
      <p>Vercel hosts the website and GitHub hosts downloads. These services can process requests and technical information such as IP addresses under their own policies.</p>
      <p><a href="https://policies.google.com/privacy">Google privacy policy</a> · <a href="https://sentry.io/privacy/">Sentry privacy policy</a> · <a href="https://vercel.com/legal/privacy-policy">Vercel privacy policy</a> · <a href="https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement">GitHub privacy policy</a></p>
      <p>Questions or corrections: <a href={`${REPO_URL}/issues`}>open an issue on GitHub</a>. Don’t include private money data in a public issue.</p>
    </main>
    <SiteFooter />
  </>;
}
