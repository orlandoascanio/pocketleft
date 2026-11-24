"use client";

import Image from "next/image";
import type { Locale } from "@/lib/locale";
import { useState } from "react";
import { useDownloadPlatform } from "@/components/PlatformDownload";
import macPanel from "@/public/media/menu-bar-2026-10-14.png";
import windowsPanel from "@/public/media/windows-0-1-4-quick-entry.webp";

const panels = {
  mac: {
    label: { en: "Mac menu bar", es: "Barra de menús de Mac" },
    image: macPanel,
    alt: { en: "Pocket’s Mac menu bar panel with a $2,431.08 balance, Coffee and Lunch shortcuts, and the latest purchases.", es: "El panel de Pocket en la barra de menús de Mac muestra un saldo de $2,431.08, atajos para café y almuerzo y las compras recientes." },
  },
  windows: {
    label: { en: "Windows tray", es: "Bandeja de Windows" },
    image: windowsPanel,
    alt: { en: "Quick Entry in the Windows preview with a $442 balance, a spending form, and a Saved on this PC indicator.", es: "El registro rápido de Windows muestra un saldo de $442, un formulario de gastos y un aviso de que los datos se guardan en esta PC." },
  },
} as const;

export function QuickEntryPreview({ locale }: { locale: Locale }) {
  const detected = useDownloadPlatform();
  const [choice, setChoice] = useState<keyof typeof panels | null>(null);
  const platform = choice ?? detected ?? "mac";
  const panel = panels[platform];
  return (
    <div className="entry-preview" data-platform={platform}>
      <div className="entry-preview-stage">
        <Image src={panel.image} alt={panel.alt[locale]} sizes="(max-width: 420px) 75vw, 314px" />
      </div>
      <div className="entry-preview-options" role="group" aria-label={locale === "es" ? "Registro rápido por plataforma" : "Preview Quick Entry by platform"}>
        {(["mac", "windows"] as const).map((id) => (
          <button key={id} type="button" aria-pressed={platform === id} onClick={() => setChoice(id)}>
            {panels[id].label[locale]}
          </button>
        ))}
      </div>
    </div>
  );
}
