"use client";

import { useSyncExternalStore, type ReactNode } from "react";
import { DOWNLOAD_PAGE, DOWNLOAD_URL, VERSION, WEB_APP_URL, WINDOWS_SETUP_URL, WINDOWS_VERSION } from "@/lib/site";

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

export function ForDesktopPlatform({ platform, children }: {
  platform: NonNullable<Platform>;
  children: ReactNode;
}) {
  const detected = useDownloadPlatform();
  return detected === null || detected === platform ? children : null;
}

export function PlatformDownloadLink({ className, children }: {
  className?: string;
  children?: ReactNode;
}) {
  const platform = useDownloadPlatform();
  const label = platform === "mac" ? "Download for Mac" : platform === "windows" ? "Download for Windows" : "View desktop downloads";
  const href = platform === "mac" ? DOWNLOAD_URL : platform === "windows" ? WINDOWS_SETUP_URL : DOWNLOAD_PAGE;
  return (
    <a className={className} href={href} data-download={platform === "mac" || undefined}>
      {children}
      {label}
    </a>
  );
}

export function HeroPlatformHeadline() {
  const platform = useDownloadPlatform();
  return (
    <>
      <h1>Know what’s<br /><span>left.</span></h1>
      <p className="lead">{platform === "windows"
        ? "PocketLeft is a free expense tracker for Windows. Log spending by hand and see your balance beside the clock, even offline."
        : "PocketLeft is a free offline expense tracker for Mac and Windows. Log income and spending by hand and see your balance in the Mac menu bar or Windows tray."}</p>
    </>
  );
}

export function HeroActions({ downloadIcon }: { downloadIcon: ReactNode }) {
  const platform = useDownloadPlatform();
  return (
    <div className="cta" id="hero-cta">
      {platform ? (
        <>
          <PlatformDownloadLink className="pill pill-dark">{downloadIcon}</PlatformDownloadLink>
          <a className="pill pill-soft" href={platform === "mac" ? "#tour" : DOWNLOAD_PAGE + "#windows"}>
            {platform === "mac" ? "Take the Mac tour" : "See the Windows preview"}
          </a>
        </>
      ) : (
        <>
          <a className="pill pill-dark" href="#try-pocket">Try the sample ledger</a>
          <PlatformDownloadLink className="pill pill-soft">{downloadIcon}</PlatformDownloadLink>
        </>
      )}
    </div>
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
          <li><a href="/changelog/#mac">v{VERSION}</a></li>
        </> : platform === "windows" ? <>
          <li>Windows 11</li>
          <li>Intel, AMD, and ARM</li>
          <li><a href="/changelog/#windows">v{WINDOWS_VERSION} preview</a></li>
        </> : <li><a href={DOWNLOAD_PAGE + "#windows"}>Windows 11 preview</a></li>}
      </ul>
      {platform ? (
        <a className="hero-downloads-link" href={DOWNLOAD_PAGE}>All download options <span aria-hidden="true">↗</span></a>
      ) : (
        <a className="hero-downloads-link" href={WEB_APP_URL}>Already synced? Open the web app <span aria-hidden="true">↗</span></a>
      )}
    </>
  );
}
