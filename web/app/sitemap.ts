import type { MetadataRoute } from "next";
import { DOWNLOAD_PAGE, SITE_URL } from "@/lib/site";
import { GUIDES, guideUrl } from "@/lib/guides";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: `${SITE_URL}/`, changeFrequency: "monthly", priority: 1 },
    { url: `${SITE_URL}${DOWNLOAD_PAGE}`, changeFrequency: "monthly", priority: 0.9 },
    { url: `${SITE_URL}/about/`, changeFrequency: "monthly", priority: 0.8 },
    { url: `${SITE_URL}/changelog/`, changeFrequency: "monthly", priority: 0.7 },
    { url: `${SITE_URL}/privacy/` },
    { url: `${SITE_URL}/guides/`, changeFrequency: "monthly", priority: 0.8 },
    ...GUIDES.map((guide) => ({ url: `${SITE_URL}${guideUrl(guide.slug)}`, lastModified: guide.updated, priority: 0.7 })),
  ];
}
