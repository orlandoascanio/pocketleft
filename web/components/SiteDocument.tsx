import { Bricolage_Grotesque } from "next/font/google";
import { WebsiteAnalytics } from "@/components/WebsiteAnalytics";
import type { Locale } from "@/lib/locale";
import "@/app/globals.css";

const display = Bricolage_Grotesque({
  subsets: ["latin"],
  weight: "variable",
  axes: ["opsz"],
  variable: "--display-font",
});

export function SiteDocument({ children, locale }: { children: React.ReactNode; locale: Locale }) {
  return (
    <html lang={locale} className={display.variable}>
      <body>{children}<WebsiteAnalytics locale={locale} /></body>
    </html>
  );
}
