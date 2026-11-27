# Pocket website: SEO, GA4, and Sentry

Audit date: October 12, 2026 (America/Caracas). Website: https://pocketleft.app.
Search Console ownership already exists, as confirmed by the owner. Its private reports were not accessed in this audit.

## What was checked on the deployed site

| Check | Observed result |
| --- | --- |
| Homepage and changelog | HTTP 200; separate titles and self-referencing canonical URLs |
| Server-rendered content | Descriptions, headings, links, and JSON-LD present; schema also confirmed in a rendered browser |
| robots.txt | Allows crawling and points to the sitemap |
| sitemap.xml | Contains homepage and changelog, excludes the paired web app |
| Paired web app | HTTP 200 with `X-Robots-Tag: noindex` |
| Redirects | HTTP and www redirect to HTTPS non-www; `/mac/` redirects to `/` |
| Missing page | Real HTTP 404 |
| Layout | No horizontal overflow at desktop or 390px mobile viewport |
| Download | Old GitHub repo name redirects to pocketleft, then to the v1.1.0 asset; transfer completion was not tested |
| Measurement | No GA4 or Sentry integration in the existing website source |

These checks establish public accessibility, not Google's indexed status, rankings, Core Web Vitals, or dashboard ingestion.

## Changes prepared in code

- Clearer homepage title and description for “free Mac menu bar money tracker,” with accurate optional sync wording.
- Direct GitHub repository/download links using `pocketleft`; richer app schema using real screenshots, version, OS, and free price.
- Complete changelog Open Graph metadata, including the screenshot previously lost when that page overrode the layout's Open Graph object.
- A `/privacy/` page, linked from the homepage and included in the sitemap.
- Opt-in GA4 for public website pages. No Google script loads before acceptance. Both choices are remembered for 180 days, including across visits and page navigation; existing saved choices migrate without another prompt. Preferences can be changed from each public page's footer, including withdrawing consent and clearing this site's GA cookies. If storage or analytics is blocked, links still work.
- Sentry client, server, edge, and App Router error capture. Request headers, cookies, bodies, user identity, and query parameters are excluded; breadcrumbs, replay, logs, and tracing are disabled.
- The standalone paired `/app/` stays outside both integrations and outside the sitemap. Keep its `noindex` header and let crawlers fetch it: disallowing it in robots.txt would prevent Google seeing `noindex`.
- Optional build-time Sentry source map uploads. The upload token is a private build variable.

The existing FAQ markup remains valid descriptive schema, but [Google removed FAQ rich results in May 2026](https://developers.google.com/search/updates). Do not expect FAQ enhancements in Search Console. Google's [software app rich result](https://developers.google.com/search/docs/appearance/structured-data/software-app) requires a real rating or review. Pocket currently has neither in its source. A missing-rating error in Rich Results Test is a limitation of that enhanced display, not a blocker for ordinary indexing. Never fabricate ratings to satisfy it.

## Your manual steps: Search Console

1. Select your existing Pocket property. Confirm it covers `https://pocketleft.app/`; a Domain property covers all variants.
2. Open **Sitemaps** and submit `https://pocketleft.app/sitemap.xml` if it is not already submitted. Check for **Success**. After this code is deployed, the sitemap will also include `/privacy/`.
3. In **URL Inspection**, inspect `https://pocketleft.app/` and `https://pocketleft.app/changelog/`. Run **Test live URL**. Confirm crawling/indexing are allowed and inspect the rendered page. In the indexed result, compare user-declared and Google-selected canonical; each should be its own URL. Request indexing if a public page is missing or after a meaningful update. Inspect `/privacy/` after deployment too.
4. In **Page indexing**, investigate exclusions for those public pages: server errors, unexpected `noindex`, duplicate/canonical issues, or “Crawled/Discovered — currently not indexed.” `/app/` being excluded by `noindex` and redirect URLs being excluded are expected.
5. Check **Manual actions** and **Security issues**. There should be no active issues.
6. In **Performance → Search results**, enable clicks, impressions, CTR, and average position. Review Queries and Pages over 28 days, with device/country filters as needed. Start with branded searches and terms such as “Mac menu bar money tracker” and “Mac balance tracker”; these are positioning candidates, not measured keyword-volume findings.
7. Check **Core Web Vitals** when enough field data exists. Run [PageSpeed Insights](https://pagespeed.web.dev/) on mobile and desktop to get lab diagnostics now. No field-data result on a new site is not a failing score. No Lighthouse or PageSpeed score was measured in this audit.

Use Google's [URL Inspection guide](https://support.google.com/webmasters/answer/9012289), [indexing report guide](https://support.google.com/webmasters/answer/7440203), and [reports overview](https://support.google.com/webmasters/answer/9133276). Sitemap submission and indexing requests do not guarantee inclusion or ranking.

Pocket is an ordinary software download website. The AMP report in the supplied resources does not apply to its current implementation; there is no AMP site to configure. No special news, retail, or scholarly submission is needed for the current pages.

## Your manual steps: Google Analytics

1. Open the existing GA4 property containing the supplied stream **G-6LLJJ52MDL**. Choose **America/Caracas** for the reporting timezone if that is how you want to read daily reports. Google's [property setup guide](https://support.google.com/analytics/answer/9304153) describes these settings.
2. In **Admin → Data streams**, select that **Web** stream and confirm its website URL is `https://pocketleft.app`.
3. The code defaults to **G-6LLJJ52MDL** on `pocketleft.app` when `NEXT_PUBLIC_GA_MEASUREMENT_ID` is unset. Set an empty value to disable analytics or a stream ID to enable it on the deployment’s host. Keep the variable unset on previews unless you are testing. Redeploy after changing it because Next.js embeds public variables at build time.
4. In the Web stream's **Enhanced measurement** settings, open Page views → Advanced settings and disable browser-history page views, since the code already sends them manually. Scrolls and Outbound clicks can stay on if useful; their `scroll` and `click` events do not themselves duplicate the `download_clicked` key event. Disable unused search/form/video measurement and optional automatic file downloads: the code handles Pocket's `.dmg` link explicitly. Automatic events may collect additional URL information beyond the custom event contract below. Do not install a second gtag/GTM snippet.
5. Keep Google Signals and ads personalization off unless you later make a deliberate product decision to enable them. Select the shortest retention that meets your reporting needs in **Admin → Data retention**.
6. Open the deployed website in a fresh browser session. Choose **No thanks**: there should be no Google Analytics script or collection request. Change **Analytics preferences → Allow analytics**. Confirm `page_view` in **Realtime**, then click a download and confirm `download_clicked`. The click must still work with an ad blocker.
7. In **Admin → Data display → Events**, [mark `download_clicked` as a key event](https://support.google.com/analytics/answer/13128484). Count once per session if you want a visitor/session-oriented funnel. Do not create a second derived download event; the code already sends it.
8. Add an event-scoped custom dimension for parameter `location` if you want hero/navigation/footer comparisons in reports. For debugging only, set `NEXT_PUBLIC_GA_DEBUG=true` in a test deployment and use **DebugView**; keep it false in normal production.
9. In **Admin → Product links → Search Console links**, link the existing Pocket Search Console property to this web stream. You need the appropriate permissions in both accounts. See [Google's linking guide](https://support.google.com/analytics/answer/10737381).

| Event | Trigger | Parameters |
| --- | --- | --- |
| `page_view` | Accepted analytics, public page loaded or route changed | `page_title`, clean `page_location` |
| `download_page_opened` | Link to the English or Spanish download page clicked from another page | `location` |
| `download_clicked` | Mac or Windows installer link clicked, including the install-dialog fallback | `location`, `platform` (`mac` or `windows`), `download_target` (`latest` or `windows`) |
| `self_hosting_opened` | On-site self-hosting guide (`/guides/self-hosting/`) or GitHub reference clicked | `location` |
| `web_app_opened` | Public website link to `/app/` clicked | `location` |
| `source_opened` | Repository link clicked | `location` |

`location` is `hero`, `navigation`, `footer`, `install_dialog`, or `content`. Events measure consenting visitors only. Downloads are click intent, not verified file transfers or installations. Arbitrary query strings, fragments, and referrer paths are omitted; campaign parameters are not explicitly forwarded. GA4's built-in session and engagement events may also appear.

## PostHog website analytics

Set the Pocket project's public capture token and ingestion host in Vercel's Production environment. Verify the deployed site in a fresh browser before and after choosing **Allow analytics**. Check PostHog's Live Events for one `$pageview` per visited page and one `download_clicked` per installer link click. Each event includes `locale` (`en` or `es`) and the clean `page_location`. PostHog uses the website events above with `$pageview` in place of `page_view`.

| Question | PostHog report |
| --- | --- |
| Which landing pages lead to installer interest? | Funnel from `$pageview` to `download_clicked`. Break down by locale or filter the first step to a landing page. |
| Which installers and placements get clicks? | Trend of unique visitors who triggered `download_clicked`, broken down by `platform` or `location`. Filter out `location=install_dialog` for first-click analysis. |
| Where do Mac visitors need installation help? | Compare `install_help_viewed`, `install_help_retry`, and `install_help_support` by page and locale. |

The consent banner covers the public site, including download pages, about pages, and guides. The paired browser app stays outside PostHog, and replay and automatic click capture are disabled.

## Your manual steps: Sentry

1. Create or select a Sentry organization. Create a **Next.js** project named **pocket-web**; keep the native Mac app in a separate project if you add native reporting later.
2. In **Project Settings → Client Keys (DSN)**, copy the DSN. In Vercel's Production environment, set `NEXT_PUBLIC_SENTRY_DSN` to the DSN and `NEXT_PUBLIC_SENTRY_ENVIRONMENT` to `production`.
3. For readable source-mapped errors, copy your organization and project **slugs** into `SENTRY_ORG` and `SENTRY_PROJECT`. Create a Sentry auth token with the source-map and release upload permissions required for the organization. Save it as a sensitive `SENTRY_AUTH_TOKEN` variable in Vercel.
4. Redeploy. Check the build log for successful source map upload. Without the token, error capture can still work, but readable source-mapped stacks are not established.
5. In a test deployment, trigger a browser error after the page has loaded, for example using DevTools: `setTimeout(() => { throw new Error("Pocket website setup test"); }, 0)`. Find it in Sentry Issues and confirm the environment and absence of query strings, cookies, headers, and user data. This verifies ingestion; verify source mapping separately on an error originating from app source. Resolve the test issue afterwards.
6. Configure an alert for a new production issue and another for a recurring error spike. Use your preferred notification destination. Enable IP-address scrubbing in the project's security/privacy settings: providers still receive network information when processing requests.
7. Keep Session Replay and performance tracing off for this initial setup. They are not enabled by this implementation. Sentry is debugging infrastructure; installing it does not improve rankings by itself.

Implementation follows [Sentry's Next.js manual setup](https://docs.sentry.io/platforms/javascript/guides/nextjs/manual-setup/) and [data collection options](https://docs.sentry.io/platforms/javascript/guides/nextjs/configuration/options/#dataCollection).

## Deployment and validation

See the [release runbook](../docs/RELEASING.md#website-environment-variables) for environment settings and Vercel deployment checks. Run `npm run check` in `web/` to check TypeScript and the consent, failure tolerance, and Sentry redaction helpers. Run `npm run build` to verify production compilation. Use your account dashboards to verify event ingestion, Google-selected canonicals, and indexing.

Validation completed locally: production builds passed both without IDs and with synthetic GA4/Sentry IDs; TypeScript and helper checks passed. At 390px, browser checks confirmed no Google tag before consent or after rejection, one page view after acceptance, one download event per tested click, working install instructions, sanitized query/hash values, withdrawal unloading the tag, correct changelog/website-privacy canonicals, and no horizontal overflow. The Google script was deliberately blocked during synthetic-ID testing; no real GA4 or Sentry account delivery or source map upload was verified. `/app/` still returned `noindex` and its HTML contained neither integration.

After the production deploy, verify the title, `/privacy/`, sitemap, download target, and `noindex` on `/app/` again. Add a link to pocketleft.app from the repository's website/About field and your portfolio if missing; useful links help discovery. No public posts or external account settings were changed in this audit.
