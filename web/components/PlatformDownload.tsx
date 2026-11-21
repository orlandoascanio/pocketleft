"use client";

import { useSyncExternalStore, type ReactNode } from "react";
import { DOWNLOAD_URL, VERSION, WINDOWS_SETUP_URL, WINDOWS_VERSION } from "@/lib/site";

type Platform = "mac" | "windows" | null;

function browserPlatform(): Platform {
  const browser = navigator as Navigator & { userAgentData?: { platform: string; mobile: boolean } };
  const { userAgent, platform, maxTouchPoints, userAgentData } = browser;
  if (userAgentData?.mobile || /Android|iPhone|iPad|iPod|Windows Phone|Mobile/i.test(userAgent)) return null;

  const hint = userAgentData?.platform.toLowerCase();
  if (hint === "windows") return "windows";
  if (hint === "macos") return maxTouchPoints > 1 ? null : "mac";
  if (hint) return null;

  if (/Windows NT/i.test(userAgent) || /^Win/i.test(platform)) return "windows";
  // iPadOS can identify itself as a Mac when requesting the desktop site.
  if (/Macintosh|Mac OS X/i.test(userAgent) || /^Mac/i.test(platform)) return maxTouchPoints > 1 ? null : "mac";
  return null;
}

const subscribe = () => () => {};
const serverPlatform = () => null;

export function useDownloadPlatform(): Platform {
  return useSyncExternalStore(subscribe, browserPlatform, serverPlatform);
}

export function PlatformDownloadLink({ className, compact, shown, children }: {
  className?: string;
  compact?: boolean;
  shown?: boolean;
  children?: ReactNode;
}) {
  const platform = useDownloadPlatform();
  const label = platform === "mac" ? "Download for Mac" : platform === "windows" ? "Download for Windows" : "Download Pocket";
  const href = platform === "mac" ? DOWNLOAD_URL : platform === "windows" ? WINDOWS_SETUP_URL : "/#downloads";
  return (
    <a className={className} href={href} data-download={platform === "mac" || undefined} data-shown={shown || undefined}
      aria-label={compact ? label : undefined}>
      {children}
      {compact ? "Download" : label}
    </a>
  );
}

export function HeroPlatformHeadline() {
  const platform = useDownloadPlatform();
  return (
    <h1>How much money you have left,<br /><span>
      {platform === "mac" ? "always in your menu bar." : platform === "windows" ? "right by your Windows clock." : "always within reach."}
    </span></h1>
  );
}

export function HeroDownloadDetails() {
  const platform = useDownloadPlatform();
  return (
    <>
      <ul className="meta">
        <li>Free</li>
        <li>No account</li>
        {platform === "mac" ? <>
          <li>macOS 14+</li>
          <li>Apple Silicon &amp; Intel</li>
          <li>Developer signed · Apple notarized</li>
          <li><a href="/changelog/">v{VERSION}</a></li>
        </> : platform === "windows" ? <>
          <li>Windows 11</li>
          <li>Intel, AMD, and ARM</li>
          <li><a href="#windows">v{WINDOWS_VERSION} preview</a></li>
        </> : <li>Mac and Windows</li>}
      </ul>
      {platform && <a className="hero-downloads-link" href="#downloads">All downloads <span aria-hidden="true">↓</span></a>}
    </>
  );
}
