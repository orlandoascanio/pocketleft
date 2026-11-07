import type { Metadata, Viewport } from "next";
import { Bricolage_Grotesque } from "next/font/google";
import { DESCRIPTION, SITE_URL } from "@/lib/site";
import { WebsiteAnalytics } from "@/components/WebsiteAnalytics";
import "./globals.css";

const display = Bricolage_Grotesque({
  subsets: ["latin"],
  weight: "variable",
  axes: ["opsz"],
  variable: "--display-font",
});

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

export const viewport: Viewport = {
  viewportFit: "cover",
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#f6f5f2" },
    { media: "(prefers-color-scheme: dark)", color: "#121212" },
  ],
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={display.variable}>
      <body>{children}<WebsiteAnalytics /></body>
    </html>
  );
}
