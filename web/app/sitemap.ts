import type { MetadataRoute } from "next";
import { SITE_URL } from "@/lib/site";
import { ABOUT_PATHS, DOWNLOAD_PATHS, HOMEPAGE_PATHS, alternateLanguages } from "@/lib/locale";
import { GUIDES, guideUrl } from "@/lib/guides";

export default function sitemap(): MetadataRoute.Sitemap {
  const localizedPages = [
    { paths: HOMEPAGE_PATHS, priority: 1 },
    { paths: DOWNLOAD_PATHS, priority: 0.9 },
    { paths: ABOUT_PATHS, priority: 0.8 },
  ] as const;

  return [
    ...localizedPages.flatMap(({ paths, priority }) => Object.values(paths).map((path) => ({
      url: SITE_URL + path,
      alternates: { languages: alternateLanguages(paths, SITE_URL) },
      changeFrequency: "monthly" as const,
      priority,
    }))),
    { url: `${SITE_URL}/changelog/`, changeFrequency: "monthly", priority: 0.7 },
    { url: `${SITE_URL}/privacy/` },
    { url: `${SITE_URL}/guides/`, changeFrequency: "monthly", priority: 0.8 },
    ...GUIDES.map((guide) => ({ url: `${SITE_URL}${guideUrl(guide.slug)}`, lastModified: guide.updated, priority: 0.7 })),
  ];
}
