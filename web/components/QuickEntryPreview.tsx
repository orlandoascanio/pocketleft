"use client";

import Image from "next/image";
import { useState } from "react";
import { useDownloadPlatform } from "@/components/PlatformDownload";
import macPanel from "@/public/media/menu-bar-2026-10-14.png";
import windowsPanel from "@/public/media/windows-0-1-4-quick-entry.webp";

const panels = {
  mac: {
    label: "Mac menu bar",
    image: macPanel,
    alt: "Pocket’s Mac menu bar panel with a $2,431.08 balance, Coffee and Lunch shortcuts, and the latest purchases.",
  },
  windows: {
    label: "Windows tray",
    image: windowsPanel,
    alt: "Quick Entry in the Windows preview with a $442 balance, a spending form, and a Saved on this PC indicator.",
  },
} as const;

export function QuickEntryPreview() {
  const detected = useDownloadPlatform();
  const [choice, setChoice] = useState<keyof typeof panels | null>(null);
  const platform = choice ?? detected ?? "mac";
  const panel = panels[platform];
  return (
    <div className="entry-preview" data-platform={platform}>
      <div className="entry-preview-stage">
        <Image src={panel.image} alt={panel.alt} sizes="(max-width: 420px) 75vw, 314px" loading="eager" fetchPriority="high" />
      </div>
      <div className="entry-preview-options" role="group" aria-label="Preview Quick Entry by platform">
        {(["mac", "windows"] as const).map((id) => (
          <button key={id} type="button" aria-pressed={platform === id} onClick={() => setChoice(id)}>
            {panels[id].label}
          </button>
        ))}
      </div>
    </div>
  );
}
