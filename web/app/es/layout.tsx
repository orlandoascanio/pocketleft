import type { Metadata } from "next";
import { SiteDocument } from "@/components/SiteDocument";
import { HOMEPAGE_PATHS, SPANISH_DESCRIPTION } from "@/lib/locale";
import { SITE_URL } from "@/lib/site";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: "PocketLeft en español | Control de gastos gratis para Mac y Windows",
  description: SPANISH_DESCRIPTION,
  applicationName: "Pocket",
  alternates: {
    canonical: HOMEPAGE_PATHS.es,
    languages: { ...HOMEPAGE_PATHS, "x-default": HOMEPAGE_PATHS.en },
  },
  icons: { icon: "/icon.svg", apple: "/apple-touch-icon.png" },
  openGraph: {
    type: "website",
    locale: "es",
    url: HOMEPAGE_PATHS.es,
    siteName: "PocketLeft",
    title: "Pocket para Mac y Windows",
    description: SPANISH_DESCRIPTION,
    images: [{ url: "/screenshot-overview.png", width: 1600, height: 1283, alt: "Ventana principal de Pocket en una Mac" }],
  },
  twitter: { card: "summary_large_image" },
};

export { viewport } from "@/lib/site-viewport";

export default function SpanishLayout({ children }: { children: React.ReactNode }) {
  return <SiteDocument locale="es">{children}</SiteDocument>;
}
