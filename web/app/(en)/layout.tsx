import type { Metadata } from "next";
import { DESCRIPTION, SITE_URL } from "@/lib/site";
import { SiteDocument } from "@/components/SiteDocument";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: "Pocket for Mac: Free Menu Bar Money Tracker | PocketLeft",
  description: DESCRIPTION,
  applicationName: "Pocket",
  alternates: { canonical: "/" },
  icons: { icon: "/icon.svg", apple: "/apple-touch-icon.png" },
  openGraph: {
    type: "website",
    url: "/",
    siteName: "PocketLeft",
    title: "Pocket for Mac",
    description: "See how much money you have left, right in your Mac menu bar. Free, and your data stays on your Mac.",
    images: [{ url: "/screenshot-overview.png", width: 1600, height: 1283, alt: "Pocket's main window on a Mac" }],
  },
  twitter: { card: "summary_large_image" },
};

export { viewport } from "@/lib/site-viewport";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <SiteDocument locale="en">{children}</SiteDocument>;
}
