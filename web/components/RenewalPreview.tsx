"use client";

import { useState } from "react";

const renewals = [
  { name: "Music", days: 2, cents: 1099 },
  { name: "Cloud storage", days: 6, cents: 299 },
  { name: "Design tools", days: 18, cents: 1500 },
];

const dollars = (cents: number) => `$${(cents / 100).toFixed(2)}`;

export function RenewalPreview() {
  const [days, setDays] = useState(7);
  const upcoming = renewals.filter((entry) => entry.days <= days);
  const total = upcoming.reduce((sum, entry) => sum + entry.cents, 0);

  return (
    <div className="renewal-preview">
      <div className="renewal-label">Example renewals</div>
      <div className="renewal-summary">
        <strong>{dollars(total)}</strong>
        <div className="renewal-switch" role="group" aria-label="Renewal window">
          {[7, 30].map((window) => (
            <button key={window} type="button" aria-pressed={days === window} onClick={() => setDays(window)}>{window} days</button>
          ))}
        </div>
      </div>
      <ul>{upcoming.map((entry) => (
        <li key={entry.name}><span>{entry.name}<small>In {entry.days} days</small></span><b>{dollars(entry.cents)}</b></li>
      ))}</ul>
      <span className="sr-only" role="status">{upcoming.length} renewals totaling {dollars(total)} in the next {days} days.</span>
    </div>
  );
}
