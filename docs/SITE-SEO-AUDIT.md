# PocketLeft SEO and AI search audit

November 22, 2026 · Built locally on top of production commit `d345d10`

The revised site gives downloads a permanent destination, presents platform details in the initial HTML, and links current release features to their instructions. The crawl found no broken indexed routes or fragment links in the revised build. The largest content gaps were inconsistent platform paths, outdated Mac instructions, and AI reference files that omitted Windows release history and the new download page.

## Findings and fixes

| Priority | Finding | Fix |
| --- | --- | --- |
| High | The Windows hero and its installer had separate paths. Mac visitors could lose the Windows section after platform detection, making the shared `/#windows` link unreliable. | Built a permanent download page where Mac, Windows, and web details are visible for every visitor. The Windows hero leads to Windows setup and release notes. The homepage keeps its existing shortcuts, and desktop users still have one-click installer links in the hero. |
| High | The AI manifest omitted the new download destination. The full reference described Mac releases only, even though the changelog already included Windows. | Added the official download page, distinct Mac and Windows release links, Windows preview history, and links from release notes to relevant guide sections. About and both reference files now share the same facts about the Mac features and Windows installer. |
| High | The menu bar guide told readers to quit Pocket to hide the amount. The quick-add and forecast guides lacked instructions for Undo and Available until payday. | Updated the existing guides in place and linked to the precise steps from the product page and the Mac 1.5.5 notes. Added a worked payday example. |
| Medium | The guide index headline did little to describe the destination. Machine-readable platform metadata had no Windows application entry. | Named and grouped the guide index by task, aligned its title and description, and added structured data for the Windows 11 preview using the same version, installer, and release links as the visible card. Updated the existing Mac application markup with the shipped workflows. |
| Medium | The download header overflowed at a 320-pixel viewport. Lighthouse also flagged a low-contrast decorative footer word on all four tested pages. | Applied the compact header sizing across the site and removed the decorative word while keeping the footer’s product identity and links. |

## Technical SEO verification

- All 16 URLs in the revised sitemap returned HTTP 200 with self-referencing canonical URLs, unique titles and descriptions, and one main H1 each. The rendered link crawl found no orphaned sitemap pages, unresolved internal destinations, or missing linked fragments in the audited set.
- Both app entry URLs and the share page retained their noindex directives. The Mac and Windows public installer endpoints responded to range requests. The download page exposes both installers and the two web setup links with JavaScript disabled.
- Browser checks covered the desktop Mac and Windows paths, iPhone-sized pages, and 320-pixel viewports. The demo played at its original link, the mobile sample ledger was preserved, and the earlier changelog links still reached their grouped releases.
- The homepage measured 5,434 pixels tall on the tested Mac viewport and 6,339 on the iPhone viewport, down from 9,486 and 12,174 respectively in the architecture baseline. The download chooser is reachable from the top navigation.
- Lighthouse 13.5.0 returned 100 for SEO and 100 for automated accessibility on the homepage, download page, guides index, and changelog after the footer fix.
- In one simulated mobile Lighthouse run per page, the homepage scored 90 for performance with a 3.7 s Largest Contentful Paint. The download page scored 94 with a 3.1 s Largest Contentful Paint. Both recorded zero layout shift. These lab results identify above-the-fold rendering as the remaining performance concern.
- Production serves HTTP and www redirects to the canonical HTTPS origin and sends HSTS. Those checks covered the live host configuration. The revised page and navigation checks used the local production build.

## AI search verification

- Sent 45 requests to the current production homepage, About page, robots file and both AI reference files with nine browser or crawler user agents. All returned HTTP 200. This checks response behavior from the audit network. It leaves crawler-origin verification and indexing status open.
- Checked the generated `llms.txt` and `llms-full.txt` for the canonical download page, distinct release histories, current payday instructions, and the removal of the outdated Hide Balance instruction. Parsed the rendered JSON-LD to check the Windows operating system, version and installer against the visible page.
- Sampled 12 public search queries covering the brand, official downloads, the menu bar, forecasts, renewals, Windows, and pairing. The public results surfaced the maker’s Pocket page for a menu bar query, while broad forecast and subscription queries surfaced other tools in the sample. Earlier November 22 assistant checks found the menu bar query was Pocket’s strongest recommendation path. These are discovery observations. The revised build is local, so recommendation rate and recrawl effects remain unmeasured.

Field Core Web Vitals, Search Console coverage, and post-deployment changes in clicks or AI recommendations remain unmeasured. The checks here cover crawlability, semantic structure, workflow accuracy, and mobile usability in the tested build. [Google Search guidance for AI features](https://developers.google.com/search/docs/fundamentals/ai-optimization-guide) · [Maker’s Pocket page](https://www.orlandoascanio.com/products/pocket)
