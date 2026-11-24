import { GUIDES, guideUrl, type Guide } from "@/lib/guides";

type CardCopy = Pick<Guide, "category" | "title" | "description">;

export function GuideCards({ slugs, spanishCopy }: { slugs?: string[]; spanishCopy?: Record<string, CardCopy> }) {
  const guides = slugs ? slugs.map((slug) => GUIDES.find((guide) => guide.slug === slug)!) : GUIDES;
  return <div className="guide-list">
    {guides.map((guide, index) => {
      const translated = spanishCopy?.[guide.slug];
      const copy = translated ?? guide;
      return <a className="guide-card" href={guideUrl(guide.slug)} hrefLang={translated ? "en" : undefined} key={guide.slug}>
        <span className="guide-number" aria-hidden="true">{String(index + 1).padStart(2, "0")}</span>
        <div>
          <span className="guide-eyebrow">{copy.category} · {guide.minutes} {translated ? "min de lectura" : "min read"}</span>
          <h3>{copy.title}</h3>
          <p>{copy.description}</p>
        </div>
        <span className="guide-arrow" aria-hidden="true">↗</span>
      </a>;
    })}
  </div>;
}
