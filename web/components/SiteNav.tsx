"use client";

import { gsap } from "gsap";
import { usePathname } from "next/navigation";
import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { BalanceChip } from "@/components/BalanceChip";
import { DOWNLOAD_URL } from "@/lib/site";

const LINKS = [
  { href: "#tour", label: "Features" },
  { href: "#plan", label: "Plan ahead" },
  { href: "#subscriptions", label: "Subscriptions" },
  { href: "#private", label: "Data & privacy" },
  { href: "#faq", label: "FAQ" },
  { href: "/guides/", label: "Guides" },
  { href: "/changelog/", label: "Changelog" },
];

const reduced = () => matchMedia("(prefers-reduced-motion: reduce)").matches;

// A floating pill. It firms up once the page scrolls, steps out of the way while you read down,
// and comes back as soon as you scroll up. The Download button joins it once the hero's own
// button has scrolled away. On wide screens a grey highlight follows the pointer across the links
// and a green dot marks the section you're in; on narrow ones the links move into a menu.
export function SiteNav() {
  const pathname = usePathname();
  const home = pathname === "/";
  // Guide articles sit under the Guides link.
  const page = LINKS.find((l) => !l.href.startsWith("#") && pathname.startsWith(l.href))?.href ?? null;
  const linkTo = (href: string) => !home && href.startsWith("#") ? `/${href}` : href;
  const [past, setPast] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const [away, setAway] = useState(false);
  const [section, setSection] = useState<string | null>(null);
  const [hover, setHover] = useState<string | null>(null);
  const [menu, setMenu] = useState(false);
  const shell = useRef<HTMLElement>(null);
  const links = useRef<HTMLDivElement>(null);
  const hl = useRef<HTMLSpanElement>(null);
  const dot = useRef<HTMLSpanElement>(null);
  const toggle = useRef<HTMLButtonElement>(null);
  const name = useRef<HTMLSpanElement>(null);
  const sweeping = useRef(false);

  // A rainbow passes through the name. On the first load it also carries the old word away:
  // the balance from the menu bar turns into "Pocket" right behind the band.
  function sweep(intro: boolean) {
    const el = name.current;
    if (!el || sweeping.current || reduced()) return;
    sweeping.current = true;
    const was = el.firstElementChild as HTMLElement;
    const is = el.lastElementChild as HTMLElement;
    const band = { p: -40 };
    // The name keeps Pocket's width, so nothing after it moves; the rest of the old word slides
    // left to butt up against the seam and runs over where "Mac" sits (hidden until the swap ends).
    if (intro) el.dataset.intro = "";
    const from = was.offsetWidth;
    const to = is.offsetWidth;
    const paint = () => {
      el.style.setProperty("--p", `${band.p}`);
      if (!intro) return;
      const c = Math.min(100, Math.max(0, band.p)) / 100;
      el.style.setProperty("--c", `${c * 100}`);
      was.style.translate = `${(to - from) * c}px 0`;
    };
    paint();
    gsap.to(band, {
      p: 140,
      duration: intro ? 1.7 : 1.1,
      delay: intro ? 0.55 : 0,
      ease: "power2.inOut",
      onUpdate: paint,
      onComplete: () => {
        delete el.dataset.intro;
        for (const prop of ["--p", "--c"]) el.style.removeProperty(prop);
        was.style.removeProperty("translate");
        sweeping.current = false;
      },
    });
  }

  useLayoutEffect(() => sweep(true), []);

  useEffect(() => {
    const target = document.getElementById("hero-cta");
    if (!target) { setPast(true); return; }
    // The top margin is the nav's height, so the button counts as gone once it slides under the nav.
    const io = new IntersectionObserver(([e]) => setPast(!e.isIntersecting && e.boundingClientRect.top < 80), {
      rootMargin: "-80px 0px 0px 0px",
    });
    io.observe(target);
    return () => io.disconnect();
  }, []);

  useEffect(() => {
    // Small jitters don't count: it takes a deliberate 10px either way to hide or bring it back.
    let anchor = scrollY;
    let frame = 0;
    function onScroll() {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        const y = scrollY;
        setScrolled(y > 8);
        if (y < 160) setAway(false);
        else if (y - anchor > 10) setAway(true);
        else if (anchor - y > 10) setAway(false);
        else return;
        anchor = y;
      });
    }
    onScroll();
    addEventListener("scroll", onScroll, { passive: true });
    return () => {
      removeEventListener("scroll", onScroll);
      cancelAnimationFrame(frame);
    };
  }, []);

  useEffect(() => {
    // A section is current while it crosses a thin band just above the middle of the screen.
    const sections = LINKS.flatMap((l) => (l.href.startsWith("#") ? [document.querySelector(l.href)] : []));
    const io = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting) setSection(`#${e.target.id}`);
          else if (e.boundingClientRect.top > 0) setSection((s) => (s === `#${e.target.id}` ? null : s));
        }
      },
      { rootMargin: "-40% 0px -55% 0px" },
    );
    sections.forEach((s) => s && io.observe(s));
    return () => io.disconnect();
  }, []);

  // The hover highlight: appears in place, then slides from link to link.
  useEffect(() => {
    const pill = hl.current;
    if (!pill) return;
    const link = hover ? links.current?.querySelector<HTMLElement>(`a[href="${linkTo(hover)}"]`) : null;
    if (!link) {
      gsap.to(pill, { opacity: 0, scale: 0.92, duration: reduced() ? 0 : 0.25, ease: "power2.out", overwrite: true });
      return;
    }
    const to = { x: link.offsetLeft, width: link.offsetWidth };
    if (+gsap.getProperty(pill, "opacity") < 0.05) gsap.set(pill, { ...to, scale: 0.92 });
    gsap.to(pill, { ...to, opacity: 1, scale: 1, duration: reduced() ? 0 : 0.45, ease: "expo.out", overwrite: true });
  }, [hover]);

  // The section dot inches along: it stretches to reach the next link, then lets go of the last.
  useEffect(() => {
    const d = dot.current;
    if (!d) return;
    const current = home ? section : page;
    const link = current ? links.current?.querySelector<HTMLElement>(`a[href="${linkTo(current)}"]`) : null;
    if (!link) {
      gsap.to(d, { opacity: 0, scale: 0, duration: reduced() ? 0 : 0.25, overwrite: true });
      return;
    }
    const to = link.offsetLeft + link.offsetWidth / 2 - 2;
    const from = +gsap.getProperty(d, "x");
    if (reduced() || +gsap.getProperty(d, "opacity") < 0.05) {
      gsap.set(d, { x: to, width: 4, scale: reduced() ? 1 : 0 });
      gsap.to(d, { opacity: 1, scale: 1, duration: reduced() ? 0 : 0.5, ease: "back.out(3)", overwrite: true });
      return;
    }
    gsap
      .timeline({ overwrite: true })
      .to(d, { x: Math.min(from, to), width: Math.abs(to - from) + 4, duration: 0.2, ease: "power2.in" })
      .to(d, { x: to, width: 4, duration: 0.45, ease: "expo.out" });
  }, [section, home, page]);

  // The menu closes on Escape, on a click outside it, and when the screen grows past it.
  useEffect(() => {
    if (!menu) return;
    const mq = matchMedia("(min-width: 821px)");
    const close = () => setMenu(false);
    function onKey(e: KeyboardEvent) {
      if (e.key !== "Escape") return;
      setMenu(false);
      toggle.current?.focus();
    }
    function onDown(e: PointerEvent) {
      if (!shell.current?.contains(e.target as Node)) setMenu(false);
    }
    document.addEventListener("keydown", onKey);
    document.addEventListener("pointerdown", onDown);
    mq.addEventListener("change", close);
    return () => {
      document.removeEventListener("keydown", onKey);
      document.removeEventListener("pointerdown", onDown);
      mq.removeEventListener("change", close);
    };
  }, [menu]);

  return (
    <header
      className="nav-shell"
      ref={shell}
      data-scrolled={scrolled || undefined}
      data-away={(away && !menu) || undefined}
      data-menu={menu || undefined}
      onFocusCapture={() => setAway(false)}
    >
      <nav className="nav" aria-label="Main">
        <a className="brand" href="/" onPointerEnter={() => sweep(false)}>
          <img src="/pocket-icon.webp" alt="" width={28} height={28} />
          <span className="brand-name" ref={name}>
            <span className="brand-was" aria-hidden="true">
              $337.03
            </span>
            <span className="brand-is">Pocket</span>
          </span>
          <span className="brand-sub">Mac</span>
        </a>
        <div className="nav-links" ref={links} onPointerLeave={() => setHover(null)}>
          <span className="nav-hl" ref={hl} aria-hidden="true" />
          {LINKS.map(({ href, label }, i) => (
            <a
              key={href}
              href={linkTo(href)}
              style={{ "--i": i } as React.CSSProperties}
              aria-current={href === pathname ? "page" : href === page || href === section ? "location" : undefined}
              onPointerEnter={() => setHover(href)}
              onFocus={() => setHover(href)}
              onBlur={() => setHover(null)}
            >
              {label}
            </a>
          ))}
          <span className="nav-dot" ref={dot} aria-hidden="true" />
        </div>
        <div className="nav-end">
          <BalanceChip off={past} />
          <a className="nav-cta" data-download data-shown={past || undefined} href={DOWNLOAD_URL}>
            <DownloadIcon />
            Download
          </a>
        </div>
        <button
          className="nav-toggle"
          ref={toggle}
          type="button"
          aria-expanded={menu}
          aria-controls="nav-menu"
          aria-label={menu ? "Close menu" : "Open menu"}
          onClick={() => setMenu(!menu)}
        >
          <span />
          <span />
        </button>
      </nav>
      <div className="nav-menu" id="nav-menu" inert={!menu}>
        {LINKS.map(({ href, label }, i) => (
          <a
            key={href}
            href={linkTo(href)}
            style={{ "--i": i } as React.CSSProperties}
            aria-current={href === pathname ? "page" : href === page || href === section ? "location" : undefined}
            onClick={() => setMenu(false)}
          >
            {label}
            <span aria-hidden="true">{href.startsWith("#") && home ? "↓" : "↗"}</span>
          </a>
        ))}
      </div>
    </header>
  );
}

export function DownloadIcon() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path className="i-arrow" d="M12 4v11M7 10l5 5 5-5" />
      <path d="M5 20h14" />
    </svg>
  );
}
