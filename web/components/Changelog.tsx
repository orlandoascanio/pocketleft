"use client";

import { useEffect, useRef, useState, type MouseEvent } from "react";
import Image from "next/image";
import { DownloadIcon } from "@/components/SiteNav";
import { DOWNLOAD_URL, SELF_HOSTING_URL, WINDOWS_SETUP_URL } from "@/lib/site";
import { RELEASES, WINDOWS_RELEASES, groupReleasesByDay, releaseDate, releaseId, type Release } from "@/lib/releases";

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

function ReleaseNotes({ release, earlier = false }: { release: Release; earlier?: boolean }) {
  const Heading = earlier ? "h5" : "h4";
  return <>
    <p className="release-summary">{release.summary}</p>
    {(release.theme === "sync" || release.theme === "findable") && <figure className="release-visual">
      {release.theme === "sync"
        ? <div className="release-visual-copy"><span className="release-visual-mark"><img src="/pocket-icon.webp" alt="" width={32} height={32} />Pocket 1.1</span><p>Your Mac.<br />Your phone.<br /><span>Your server.</span></p><span className="release-visual-note">Sync is optional. You’re in control.</span></div>
        : <div className="release-visual-copy"><span className="release-visual-mark"><img src="/pocket-icon.webp" alt="" width={32} height={32} />Pocket 1.2</span><p>Got it.<br />Skip it.<br /><span>Save it.</span></p><span className="release-visual-note">Every action, one click away.</span></div>}
      <div className="release-visual-screen"><Image src="/screenshot-overview.png" alt="Pocket for Mac’s Overview window with balance, history and quick-add buttons" width={1600} height={1283} sizes="(max-width: 700px) 80vw, 440px" /></div>
    </figure>}
    <ul className="release-highlights">{release.highlights.map(item => <li key={item.title}><span className="release-bullet" aria-hidden="true" /><div><Heading>{item.title}</Heading><p>{item.description}</p></div></li>)}</ul>
    <ReleaseDetails title={release.detailsTitle} items={release.details} />
  </>;
}

const macHistory = groupReleasesByDay(RELEASES);
const windowsHistory = groupReleasesByDay(WINDOWS_RELEASES);

function ReleaseHistory({ platform, groups }: { platform: "Mac" | "Windows"; groups: typeof macHistory }) {
  const windows = platform === "Windows";
  const sectionId = windows ? "windows" : "mac";
  const articleId = (release: Release) => `${windows ? "windows-" : ""}${releaseId(release.version)}`;
  const [active, setActive] = useState(articleId(groups[0].release));
  const section = useRef<HTMLElement>(null);
  useEffect(() => {
    const observer = new IntersectionObserver(entries => {
      for (const entry of entries) if (entry.isIntersecting) setActive(entry.target.id);
    }, { rootMargin: "-15% 0px -65% 0px" });
    section.current?.querySelectorAll(".release").forEach(el => observer.observe(el));
    return () => observer.disconnect();
  }, []);
  return <section className="changes-layout" ref={section} id={sectionId} aria-labelledby={`${sectionId}-release-heading`}>
    <aside className="changes-rail">
      <nav aria-label={`${platform} release history`}><h2 id={`${sectionId}-release-heading`}>{platform} releases</h2>
        {groups.map(({ release }, i) => <a href={`#${articleId(release)}`} key={release.version} aria-current={active === articleId(release) ? "location" : undefined}>
          <span className="rail-dot" aria-hidden="true" /><span>v{release.version}<small>{releaseDate(release.date)}</small></span>{i === 0 && <span className="rail-latest">Latest</span>}
        </a>)}
      </nav>
      <p>{windows ? <>Windows 11 preview.<br />Intel, AMD &amp; ARM.</> : <>Free for macOS 14+.<br />Apple Silicon &amp; Intel.</>}</p>
      <a className="changes-home" href={windows ? "#mac" : "#windows"}>{windows ? "Mac releases" : "Windows releases"} <span aria-hidden="true">{windows ? "↑" : "↓"}</span></a>
    </aside>
    <div className="release-list">
      {groups.map(({ release, earlier }, i) => <article className="release" id={articleId(release)} key={release.version} aria-labelledby={`${articleId(release)}-title`}>
        {earlier.map(previous => <span className="release-anchor" id={articleId(previous)} key={previous.version} aria-hidden="true" />)}
        <div className="release-meta"><a className="release-version" href={`#${articleId(release)}`}>v{release.version}</a>{i === 0 && <span className="release-latest"><span aria-hidden="true" />{windows ? "Latest preview" : "Latest release"}</span>}<time dateTime={release.date}>{releaseDate(release.date)}</time><Permalink id={articleId(release)} version={release.version} /></div>
        <h3 className="release-title" id={`${articleId(release)}-title`}>{release.title}</h3>
        <ReleaseNotes release={release} />
        {earlier.map(previous => <div className="release-earlier" key={previous.version}>
          <h4>{previous.title}</h4>
          <ReleaseNotes release={previous} earlier />
          <a className="release-text-link" href={previous.source}>Original v{previous.version} notes on GitHub <span aria-hidden="true">↗</span></a>
        </div>)}
        {release.relatedSources && <ul className="release-related">
          {release.relatedSources.map(source => <li key={source.url}><a className="release-text-link" href={source.url}>{source.title} <span aria-hidden="true">↗</span></a></li>)}
        </ul>}
        <div className="release-actions">{i === 0 ? <><a className="pill pill-dark" href={windows ? WINDOWS_SETUP_URL : DOWNLOAD_URL} data-download><DownloadIcon />Download v{release.version}</a>{!windows && <a className="release-text-link" href={SELF_HOSTING_URL}>Set up sync <span aria-hidden="true">↗</span></a>}</> : i === groups.length - 1 ? <span className="release-first">The first chapter.</span> : null}<a className="release-source" href={release.source}>On GitHub <span aria-hidden="true">↗</span></a></div>
      </article>)}
    </div>
  </section>;
}

export function Changelog() {
  return <div id="releases" tabIndex={-1}>
    <nav className="changes-platforms" aria-label="Changelog by platform">
      <a href="#mac">Mac releases</a>
      <a href="#windows">Windows releases</a>
    </nav>
    <ReleaseHistory platform="Mac" groups={macHistory} />
    <ReleaseHistory platform="Windows" groups={windowsHistory} />
  </div>;
}
