import type { Locale } from "@/lib/locale";
import type { ReactNode } from "react";

// A slice of the macOS menu bar with Pocket's balance item highlighted.
export function MenuBarStrip({ amount, children, locale = "en" }: { amount?: string; children?: ReactNode; locale?: Locale }) {
  return (
    <div className="mb">
      <span className="mb-item mb-pocket">{children ?? amount}</span>
      <svg className="mb-glyph" viewBox="0 0 20 14" aria-hidden="true">
        <path d="M10 12.5 1.6 5.2a12 12 0 0 1 16.8 0Z" />
      </svg>
      <svg className="mb-glyph mb-battery" viewBox="0 0 26 12" aria-hidden="true">
        <rect x=".75" y=".75" width="21.5" height="10.5" rx="3" fill="none" strokeWidth="1.2" />
        <rect x="2.5" y="2.5" width="15" height="7" rx="1.6" />
        <rect x="23.4" y="4" width="1.8" height="4" rx=".9" />
      </svg>
      <span className="mb-item mb-clock">{locale === "es" ? "Lun 9:41" : "Mon 9:41"}</span>
    </div>
  );
}
