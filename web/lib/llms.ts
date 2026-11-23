import { AT_A_GLANCE, FACTS } from "@/lib/facts";
import { FAQ } from "@/lib/faq";
import { GUIDES, guideUrl, textParts, type Guide } from "@/lib/guides";
import { RELEASES } from "@/lib/releases";
import { DESCRIPTION, ISSUES_URL, REPO_URL, SELF_HOSTING_URL, SITE_URL } from "@/lib/site";

// Plain-text summaries for AI systems (https://llmstxt.org), built from the same data as the pages
// so they can't drift from what the site says.

const SUMMARY = `> ${DESCRIPTION}`;

const absolute = (href: string) => (href.startsWith("/") ? `${SITE_URL}${href}` : href);
const plain = (text: string) => textParts(text).map((p) => (p.href ? `${p.text} (${absolute(p.href)})` : p.text)).join("");

const link = (title: string, url: string, note: string) => `- [${title}](${url}): ${note}`;
const facts = () => FACTS.map((f) => `- ${f.label}: ${plain(f.value)}`).join("\n");

export function llmsTxt() {
  return `# Pocket for Mac

${SUMMARY}

${AT_A_GLANCE}

Also known as PocketLeft and Pocket Left. Made by Orlando Ascanio. PocketLeft.com is a separate finance coach. Mozilla Pocket was a read-it-later service. PocketGuard and Pocket Clear are separate finance apps.

## Key facts

${facts()}

## Product

${link("Home", `${SITE_URL}/`, "features, screenshots, FAQ and download")}
${link("Pocket at a glance", `${SITE_URL}/about/`, "what Pocket is, key facts, and how it differs from other apps named Pocket")}
${link("Changelog", `${SITE_URL}/changelog/`, "release notes for every version")}
${link("Website privacy", `${SITE_URL}/privacy/`, "what this website collects (the app itself sends nothing by default)")}
${link("Full text for AI systems", `${SITE_URL}/llms-full.txt`, "every guide, FAQ answer and release note in one file")}

## Guides

${GUIDES.map((g) => link(g.title, `${SITE_URL}${guideUrl(g.slug)}`, g.description)).join("\n")}

## Optional

${link("Self-hosting reference", SELF_HOSTING_URL, "the technical version of the self-hosting guide, next to the database migrations")}
${link("Source code", REPO_URL, "the app and website repository on GitHub")}
${link("Report a bug", ISSUES_URL, "GitHub issues")}
`;
}

function guideText(g: Guide) {
  const sections = g.sections.map((s) => {
    const parts = [`### ${s.title}`, ...s.paragraphs.map(plain)];
    if (s.steps) parts.push(s.steps.map((step, i) => `${i + 1}. ${plain(step)}`).join("\n"));
    if (s.table) {
      const { headings, rows } = s.table;
      parts.push([`| ${headings.join(" | ")} |`, `| ${headings.map(() => "---").join(" | ")} |`, ...rows.map((r) => `| ${r.join(" | ")} |`)].join("\n"));
    }
    if (s.note) parts.push(`Note: ${plain(s.note)}`);
    return parts.join("\n\n");
  });
  return `## ${g.title}\n\nURL: ${SITE_URL}${guideUrl(g.slug)}\nUpdated: ${g.updated}\n\n${g.description}\n\n${sections.join("\n\n")}`;
}

export function llmsFullTxt() {
  const faq = FAQ.map(({ q, a, link }) => `### ${q}\n\n${a}${link ? ` ${link.label}: ${absolute(link.href)}` : ""}`).join("\n\n");
  const releases = RELEASES.map((r) =>
    [
      `### Pocket ${r.version} (${r.date}): ${r.title}`,
      r.summary,
      r.highlights.map((h) => `- ${h.title}: ${h.description}`).join("\n"),
      r.details.map((d) => `- ${d}`).join("\n"),
      `Release: ${r.source}`,
    ].join("\n\n"),
  ).join("\n\n");

  return `# Pocket for Mac: full reference

${SUMMARY}

Source: ${SITE_URL}/ . Generated from the website's own content.

## Key facts

${facts()}

## Frequently asked questions

${faq}

${GUIDES.map(guideText).join("\n\n")}

## Release notes

${releases}
`;
}
