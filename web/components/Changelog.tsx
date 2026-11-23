"use client";

import { useEffect, useRef, useState, type MouseEvent } from "react";
import Image from "next/image";
import { DownloadIcon } from "@/components/SiteNav";
import { DOWNLOAD_URL, SELF_HOSTING_URL } from "@/lib/site";
import { RELEASES, releaseDate, releaseId } from "@/lib/releases";

function LinkIcon({ check = false }: { check?: boolean }) {
  return <svg viewBox="0 0 24 24" aria-hidden="true">{check ? <path d="m5 12 4 4L19 6" /> : <><path d="m10 13 4-4M8 16l-1 1a4.2 4.2 0 0 1-6-6l4-4a4.2 4.2 0 0 1 6 0M16 8l1-1a4.2 4.2 0 0 1 6 6l-4 4a4.2 4.2 0 0 1-6 0" transform="translate(1 0) scale(.9)" /></>}</svg>;
}

function Permalink({ id, version }: { id: string; version: string }) {
  const [status, setStatus] = useState<"idle" | "copying" | "copied" | "error">("idle");
  useEffect(() => {
    if (status !== "copied" && status !== "error") return;
    const timer = setTimeout(() => setStatus("idle"), 3500);
    return () => clearTimeout(timer);
  }, [status]);
  async function copy() {
    setStatus("copying");
    try {
      const url = new URL(location.href);
      url.hash = id;
      await navigator.clipboard.writeText(url.href);
      setStatus("copied");
    } catch { setStatus("error"); }
  }
  return <div className="release-copy-wrap">
    <button className="release-copy" type="button" onClick={copy} disabled={status === "copying"} aria-label={`Copy link to Pocket ${version}`}>
      <LinkIcon check={status === "copied"} /><span>{status === "copied" ? "Copied" : status === "copying" ? "Copying…" : "Copy link"}</span>
    </button>
    <span className={status === "error" ? "release-copy-error" : "sr-only"} role="status">{status === "copied" ? "Release link copied." : status === "error" ? "Couldn’t copy. Use the version link instead." : ""}</span>
  </div>;
}

// Native disclosure semantics, with interruptible height motion. The notes still
// open without JavaScript, and reduced motion uses the browser's default toggle.
function ReleaseDetails({ title, items }: { title: string; items: string[] }) {
  const root = useRef<HTMLDetailsElement>(null);
  const animation = useRef<Animation | null>(null);
  const closing = useRef(false);
  useEffect(() => () => animation.current?.cancel(), []);
  function toggle(event: MouseEvent<HTMLElement>) {
    const details = root.current;
    const body = details?.querySelector<HTMLElement>(".release-details-body");
    if (!details || !body || matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    event.preventDefault();
    const height = details.open ? body.getBoundingClientRect().height : 0;
    const close = details.open && !closing.current;
    animation.current?.cancel();
    closing.current = close;
    details.dataset.closing = String(close);
    details.open = true;
    const next = body.animate({ height: [`${height}px`, `${close ? 0 : body.scrollHeight}px`] }, {
      duration: close ? 280 : 480, easing: "cubic-bezier(.16, 1, .3, 1)", fill: "both",
    });
    animation.current = next;
    next.onfinish = () => {
      details.open = !close;
      delete details.dataset.closing;
      closing.current = false;
      next.cancel();
      animation.current = null;
    };
  }
  return <details className="release-details" ref={root}>
    <summary onClick={toggle}><span>{title}<small>{items.length} more {items.length === 1 ? "change" : "changes"}</small></span><span className="release-chevron" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="m7 10 5 5 5-5" /></svg></span></summary>
    <div className="release-details-body"><ul>{items.map(item => <li key={item}>{item}</li>)}</ul></div>
  </details>;
}

export function Changelog() {
  const [active, setActive] = useState(releaseId(RELEASES[0].version));
  useEffect(() => {
    const elements = RELEASES.map(release => document.getElementById(releaseId(release.version))).filter((el): el is HTMLElement => !!el);
    const observer = new IntersectionObserver(entries => {
      for (const entry of entries) if (entry.isIntersecting) setActive(entry.target.id);
    }, { rootMargin: "-15% 0px -65% 0px" });
    elements.forEach(el => observer.observe(el));
    return () => observer.disconnect();
  }, []);
  return <div className="changes-layout" id="releases" tabIndex={-1}>
    <aside className="changes-rail">
      <nav aria-label="Release history"><h2>Changelog</h2>
        {RELEASES.map((release, i) => <a href={`#${releaseId(release.version)}`} key={release.version} aria-current={active === releaseId(release.version) ? "location" : undefined}>
          <span className="rail-dot" aria-hidden="true" /><span>v{release.version}<small>{releaseDate(release.date)}</small></span>{i === 0 && <span className="rail-latest">Latest</span>}
        </a>)}
      </nav>
      <p>Free for macOS 14+.<br />Apple Silicon &amp; Intel.</p>
      <a className="changes-home" href="/">Back to Pocket <span aria-hidden="true">↗</span></a>
    </aside>
    <div className="release-list">
      {RELEASES.map((release, i) => <article className="release" id={releaseId(release.version)} key={release.version} aria-labelledby={`${releaseId(release.version)}-title`}>
        <div className="release-meta"><a className="release-version" href={`#${releaseId(release.version)}`}>v{release.version}</a>{i === 0 && <span className="release-latest"><span aria-hidden="true" />Latest release</span>}<time dateTime={release.date}>{releaseDate(release.date)}</time><Permalink id={releaseId(release.version)} version={release.version} /></div>
        <h2 id={`${releaseId(release.version)}-title`}>{release.title}</h2>
        <p className="release-summary">{release.summary}</p>
        {(release.theme === "sync" || release.theme === "findable") && <figure className="release-visual">
          {release.theme === "sync"
            ? <div className="release-visual-copy"><span className="release-visual-mark"><img src="/pocket-icon.webp" alt="" width={32} height={32} />Pocket 1.1</span><p>Your Mac.<br />Your phone.<br /><span>Your server.</span></p><span className="release-visual-note">Sync is optional. You’re in control.</span></div>
            : <div className="release-visual-copy"><span className="release-visual-mark"><img src="/pocket-icon.webp" alt="" width={32} height={32} />Pocket 1.2</span><p>Got it.<br />Skip it.<br /><span>Save it.</span></p><span className="release-visual-note">Every action, one click away.</span></div>}
          <div className="release-visual-screen"><Image src="/screenshot-overview.png" alt="Pocket for Mac’s Overview window with balance, history and quick-add buttons" width={1600} height={1283} sizes="(max-width: 700px) 80vw, 440px" /></div>
        </figure>}
        <ul className="release-highlights">{release.highlights.map(item => <li key={item.title}><span className="release-bullet" aria-hidden="true" /><div><h3>{item.title}</h3><p>{item.description}</p></div></li>)}</ul>
        <ReleaseDetails title={release.detailsTitle} items={release.details} />
        <div className="release-actions">{i === 0 ? <><a className="pill pill-dark" href={DOWNLOAD_URL} data-download><DownloadIcon />Download v{release.version}</a><a className="release-text-link" href={SELF_HOSTING_URL}>Set up sync <span aria-hidden="true">↗</span></a></> : i === RELEASES.length - 1 ? <span className="release-first">The first chapter.</span> : null}<a className="release-source" href={release.source}>On GitHub <span aria-hidden="true">↗</span></a></div>
      </article>)}
      <div className="release-end"><span aria-hidden="true" /><p>You’re all caught up.</p><span>That’s every release of Pocket for Mac.</span></div>
    </div>
  </div>;
}
