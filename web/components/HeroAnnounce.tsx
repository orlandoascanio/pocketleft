"use client";

import type { ReactNode } from "react";
import { usePathname } from "next/navigation";
import { useDownloadPlatform } from "@/components/PlatformDownload";
import { WINDOWS_VERSION } from "@/lib/site";

// /share/ is the homepage reached from someone's "Share Pocket…" link. It greets the visitor
// in place of the release announcement; everything else on the page stays the same.
export function HeroAnnounce({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const platform = useDownloadPlatform();
  if (pathname !== "/share/") return platform === "windows" ? (
    <a className="announce" href="/changelog/#windows">
      <b>Windows {WINDOWS_VERSION} preview</b>
      <span className="announce-text">See what’s new for Windows.</span>
      <span className="announce-arrow" aria-hidden="true">↗</span>
    </a>
  ) : children;
  return (
    <p className="announce">
      <span className="announce-tag">Shared</span>
      <span className="announce-text">A friend thought you’d like Pocket.</span>
    </p>
  );
}
