"use client";

import { gsap } from "gsap";
import { usePathname } from "next/navigation";
import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { useDownloadPlatform } from "@/components/PlatformDownload";
import { HOMEPAGE_PATHS, type Locale } from "@/lib/locale";
import { DOWNLOAD_PAGE } from "@/lib/site";

const LINKS = [
  { href: "#tour", label: { en: "Features", es: "Funciones" } },
  { href: "#plan", label: { en: "Plan ahead", es: "Planifica" } },
  { href: "#subscriptions", label: { en: "Subscriptions", es: "Suscripciones" } },
  { href: "/guides/", label: { en: "Guides", es: "Guías" } },
  { href: "/changelog/", label: { en: "Changelog", es: "Novedades" } },
];

const reduced = () => matchMedia("(prefers-reduced-motion: reduce)").matches;

export function SiteNav({ locale = "en" }: { locale?: Locale }) {
  const pathname = usePathname();
  const platform = useDownloadPlatform();
  const spanish = locale === "es";
  const homePath = HOMEPAGE_PATHS[locale];
  const home = pathname === homePath || `${pathname}/` === homePath;
  const otherLocale = spanish ? "en" : "es";
  // Guide articles sit under the Guides link.
  const page = LINKS.find((l) => !l.href.startsWith("#") && pathname.startsWith(l.href))?.href ?? null;
  const linkTo = (href: string) => !home && href.startsWith("#") ? `${homePath}${href}` : href;
  const [scrolled, setScrolled] = useState(false);
  const [section, setSection] = useState<string | null>(null);
  const [hover, setHover] = useState<string | null>(null);
  const [menu, setMenu] = useState(false);
  const shell = useRef<HTMLElement>(null);
  const progress = useRef<HTMLProgressElement>(null);
  const links = useRef<HTMLDivElement>(null);
  const hl = useRef<HTMLSpanElement>(null);
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
    let frame = 0;
    function onScroll() {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        const y = scrollY;
        const root = document.documentElement;
        const distance = root.scrollHeight - root.clientHeight;
        if (progress.current) {
          progress.current.hidden = distance <= 0;
          progress.current.value = distance > 0 ? Math.min(1, Math.max(0, y / distance)) : 0;
        }
        setScrolled(y > 8);
      });
    }
    const observer = new ResizeObserver(onScroll);
    observer.observe(document.body);
    onScroll();
    addEventListener("resize", onScroll);
    addEventListener("scroll", onScroll, { passive: true });
    return () => {
      observer.disconnect();
      removeEventListener("resize", onScroll);
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
          else setSection((s) => (s === `#${e.target.id}` ? null : s));
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
      data-menu={menu || undefined}
    >
      <nav className="nav" aria-label={spanish ? "Principal" : "Main"}>
        <a className="brand" href={homePath} onPointerEnter={() => sweep(false)}>
          <img src="/pocket-icon.webp" alt="" width={28} height={28} />
          <span className="brand-name" ref={name}>
            <span className="brand-was" aria-hidden="true">
              $337.03
            </span>
            <span className="brand-is">Pocket</span>
          </span>
          {platform && <span className="brand-sub">{platform === "mac" ? "Mac" : "Windows"}</span>}
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
              {label[locale]}
            </a>
          ))}
        </div>
        <div className="nav-end">
          <a className="nav-language" href={HOMEPAGE_PATHS[otherLocale]} lang={otherLocale} hrefLang={otherLocale}>
            {spanish ? "English" : "Español"}
          </a>
          <a className="nav-cta" href={DOWNLOAD_PAGE} aria-current={pathname === DOWNLOAD_PAGE ? "page" : undefined}>
            <DownloadIcon />
            <span className="nav-cta-label">{spanish ? "Descargar" : "Download"}</span>
          </a>
        </div>
        <button
          className="nav-toggle"
          ref={toggle}
          type="button"
          aria-expanded={menu}
          aria-controls="nav-menu"
          aria-label={menu ? (spanish ? "Cerrar menú" : "Close menu") : (spanish ? "Abrir menú" : "Open menu")}
          onClick={() => setMenu(!menu)}
        >
          <span />
          <span />
        </button>
        <progress className="reading-progress" ref={progress} max={1} value={0} aria-label={spanish ? "Progreso de lectura" : "Page scroll progress"} />
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
            {label[locale]}
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
