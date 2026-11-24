"use client";

import type { Locale } from "@/lib/locale";
import { useState } from "react";

const renewals = [
  { name: { en: "Music", es: "Música" }, days: 2, cents: 1099 },
  { name: { en: "Cloud storage", es: "Almacenamiento en la nube" }, days: 6, cents: 299 },
  { name: { en: "Design tools", es: "Herramientas de diseño" }, days: 18, cents: 1500 },
];

const dollars = (cents: number) => `$${(cents / 100).toFixed(2)}`;

export function RenewalPreview({ locale }: { locale: Locale }) {
  const spanish = locale === "es";
  const [days, setDays] = useState(7);
  const upcoming = renewals.filter((entry) => entry.days <= days);
  const total = upcoming.reduce((sum, entry) => sum + entry.cents, 0);

  return (
    <div className="renewal-preview">
      <div className="renewal-label">{spanish ? "Renovaciones de ejemplo" : "Example renewals"}</div>
      <div className="renewal-summary">
        <strong>{dollars(total)}</strong>
        <div className="renewal-switch" role="group" aria-label={spanish ? "Período de renovación" : "Renewal window"}>
          {[7, 30].map((window) => (
            <button key={window} type="button" aria-pressed={days === window} onClick={() => setDays(window)}>{window} {spanish ? "días" : "days"}</button>
          ))}
        </div>
      </div>
      <ul>{upcoming.map((entry) => (
        <li key={entry.name.en}><span>{entry.name[locale]}<small>{spanish ? `En ${entry.days} días` : `In ${entry.days} days`}</small></span><b>{dollars(entry.cents)}</b></li>
      ))}</ul>
      <span className="sr-only" role="status">{spanish
      ? `${upcoming.length} renovaciones por un total de ${dollars(total)} en los próximos ${days} días.`
      : `${upcoming.length} renewals totaling ${dollars(total)} in the next ${days} days.`}</span>
    </div>
  );
}
