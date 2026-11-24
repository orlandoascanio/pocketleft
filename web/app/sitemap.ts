import type { MetadataRoute } from "next";
import { DOWNLOAD_PAGE, SITE_URL } from "@/lib/site";
import { HOMEPAGE_PATHS } from "@/lib/locale";
import { GUIDES, guideUrl } from "@/lib/guides";

export default function sitemap(): MetadataRoute.Sitemap {
  const en = SITE_URL + HOMEPAGE_PATHS.en;
  const es = SITE_URL + HOMEPAGE_PATHS.es;
  const alternates = { languages: { en, es, "x-default": en } };

  return [
    { url: en, alternates, changeFrequency: "monthly", priority: 1 },
    { url: es, alternates, changeFrequency: "monthly", priority: 1 },
    { url: `${SITE_URL}${DOWNLOAD_PAGE}`, changeFrequency: "monthly", priority: 0.9 },
    { url: `${SITE_URL}/about/`, changeFrequency: "monthly", priority: 0.8 },
    { url: `${SITE_URL}/changelog/`, changeFrequency: "monthly", priority: 0.7 },
    { url: `${SITE_URL}/privacy/` },
    { url: `${SITE_URL}/guides/`, changeFrequency: "monthly", priority: 0.8 },
    ...GUIDES.map((guide) => ({ url: `${SITE_URL}${guideUrl(guide.slug)}`, lastModified: guide.updated, priority: 0.7 })),
  ];
}
