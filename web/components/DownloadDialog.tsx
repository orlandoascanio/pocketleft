"use client";

import { useEffect, useRef } from "react";
import { DMG_SIZE, DOWNLOAD_URL, ISSUES_URL } from "@/lib/site";
import { MenuBarStrip } from "@/components/MenuBar";
import { trackWebsiteEvent } from "@/lib/analytics";

const reduced = () => matchMedia("(prefers-reduced-motion: reduce)").matches;

// Any link marked `data-download` still downloads as usual; this also opens the install steps.
// The dialog moves gently toward the button that was pressed when it opens and closes.
// Closing mid-open (or opening mid-close) turns around from wherever it is.
export function DownloadDialog() {
  const ref = useRef<HTMLDialogElement>(null);
  const origin = useRef<{ x: number; y: number } | null>(null);
  const anim = useRef<Animation | null>(null);
  const opener = useRef<HTMLElement | null>(null);
  const closeButton = useRef<HTMLButtonElement>(null);
  const openedAt = useRef(0);
  const closing = useRef(false);

  // A small directional nudge toward the button it came from.
  function collapsed(d: HTMLDialogElement) {
    const o = origin.current;
    const r = d.getBoundingClientRect();
    if (!o || !r.width) return "translate(0, 16px) scale(.97)";
    const dx = o.x - (r.left + r.width / 2);
    const dy = o.y - (r.top + r.height / 2);
    return `translate(${dx * .15}px, ${dy * .15}px) scale(.92)`;
  }

  // The dimmed page behind fades with the dialog. `from` null means "from where it is now".
  const backdrop = useRef<Animation | null>(null);
  function fadeBackdrop(d: HTMLDialogElement, from: number | null, to: number, duration: number) {
    try {
      const now = from ?? +getComputedStyle(d, "::backdrop").opacity;
      backdrop.current?.cancel();
      backdrop.current = d.animate({ opacity: [now, to] }, { duration, easing: "ease-out", fill: "forwards", pseudoElement: "::backdrop" });
      if (to === 1) backdrop.current.onfinish = () => backdrop.current?.cancel();
    } catch {
      // Browsers that can't animate ::backdrop just show and hide it.
    }
  }

  function open(from: HTMLElement) {
    const d = ref.current;
    if (!d) return;
    if (d.open && !closing.current) return;
    closing.current = false;
    opener.current = from;
    const b = from.getBoundingClientRect();
    origin.current = { x: b.left + b.width / 2, y: b.top + b.height / 2 };
    const running = anim.current;
    if (!d.open) d.showModal();
    closeButton.current?.focus({ preventScroll: true });
    openedAt.current = performance.now();
    trackWebsiteEvent("install_help_viewed", { trigger: "download_click" });
    // Start from what's on screen now, so a reopen during the close turns around in place.
    const { transform, opacity } = getComputedStyle(d);
    running?.cancel();
    if (reduced()) {
      anim.current = d.animate({ opacity: [running ? opacity : "0", "1"] }, { duration: 180, easing: "ease-out" });
    } else {
      anim.current = d.animate(
        { transform: [running ? transform : collapsed(d), "none"], opacity: [running ? opacity : "0", "1"] },
        { duration: 380, easing: "cubic-bezier(.16, 1, .3, 1)" },
      );
    }
    fadeBackdrop(d, running ? null : 0, 1, reduced() ? 180 : 400);
    anim.current.onfinish = () => (anim.current = null);
  }

  function close(reason: "close_button" | "done" | "escape" | "outside") {
    const d = ref.current;
    if (!d?.open || closing.current) return;
    closing.current = true;
    const seconds = (performance.now() - openedAt.current) / 1000;
    trackWebsiteEvent("install_help_dismissed", {
      reason, time_open: seconds < 5 ? "under_5s" : seconds < 15 ? "5_to_15s" : "over_15s",
    });
    const { transform, opacity } = getComputedStyle(d);
    anim.current?.cancel();
    const a = reduced()
      ? d.animate({ opacity: [opacity, "0"] }, { duration: 150, easing: "ease-in", fill: "forwards" })
      : d.animate(
          { transform: [transform, collapsed(d)], opacity: [opacity, "0"] },
          // Same path as the way in, but moving from the first frame: a strong ease-in would sit
          // still for the first 100ms and read as lag.
          { duration: 320, easing: "cubic-bezier(.4, 0, .2, 1)", fill: "forwards" },
        );
    anim.current = a;
    fadeBackdrop(d, null, 0, reduced() ? 150 : 320);
    a.onfinish = () => {
      d.close();
      a.cancel();
      backdrop.current?.cancel();
      anim.current = null;
      closing.current = false;
    };
  }

  useEffect(() => {
    function onClick(e: MouseEvent) {
      const link = e.target instanceof Element ? e.target.closest<HTMLAnchorElement>("a[data-download]") : null;
      if (!link || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || e.button !== 0 || (link.target && link.target !== "_self")) return;
      // The link's own navigation still starts the download; the steps open on the next frame.
      requestAnimationFrame(() => open(link));
    }
    document.addEventListener("click", onClick);
    return () => {
      document.removeEventListener("click", onClick);
      anim.current?.cancel();
      backdrop.current?.cancel();
    };
  }, []);

  return (
    <dialog
      ref={ref}
      className="dl"
      aria-labelledby="dl-title"
      aria-describedby="dl-description"
      onClose={() => opener.current?.focus({ preventScroll: true })}
      onKeyDown={(e) => {
        if (e.key !== "Tab") return;
        const controls = e.currentTarget.querySelectorAll<HTMLElement>("a[href], button:not(:disabled)");
        const first = controls[0];
        const last = controls[controls.length - 1];
        if (e.shiftKey && document.activeElement === first) {
          e.preventDefault();
          last?.focus();
        } else if (!e.shiftKey && document.activeElement === last) {
          e.preventDefault();
          first?.focus();
        }
      }}
      onCancel={(e) => {
        // Escape: animate out instead of vanishing.
        e.preventDefault();
        close("escape");
      }}
      onClick={(e) => {
        if (e.target !== e.currentTarget) return;
        const bounds = e.currentTarget.getBoundingClientRect();
        if (e.clientX < bounds.left || e.clientX > bounds.right || e.clientY < bounds.top || e.clientY > bounds.bottom) close("outside");
      }}
    >
      <div className="dl-inner">
        <div className="dl-head">
          <div>
            <span className="dl-eyebrow">Pocket for Mac</span>
            <h2 id="dl-title">Install Pocket.</h2>
            <p id="dl-description">After Pocket.dmg downloads, follow these three steps.</p>
          </div>
          <button ref={closeButton} className="dl-close" type="button" aria-label="Close installation guide" onClick={() => close("close_button")}>
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M6 6l12 12M18 6 6 18" />
            </svg>
          </button>
        </div>
        <ol className="dl-steps">
          <li>
            <div className="dl-art" aria-hidden="true">
              <div className="dl-file">
                <img src="/pocket-icon.webp" alt="" width={72} height={72} />
                <span className="dl-filename">Pocket.dmg</span>
                <span className="dl-size">{DMG_SIZE}</span>
              </div>
            </div>
            <div className="dl-step-copy">
              <span className="dl-step">01</span>
              <h3>Open the download</h3>
              <p>Find Pocket.dmg in your Downloads folder and open it.</p>
            </div>
          </li>
          <li>
            <div className="dl-art" aria-hidden="true">
              <img className="dl-app" src="/pocket-icon.webp" alt="" width={84} height={84} />
              <svg className="dl-arrow" viewBox="0 0 48 24">
                <path d="M2 12h40M34 4l8 8-8 8" />
              </svg>
              <svg className="dl-folder" viewBox="0 0 96 76">
                <path d="M4 14a8 8 0 0 1 8-8h22l8 8h42a8 8 0 0 1 8 8v42a8 8 0 0 1-8 8H12a8 8 0 0 1-8-8Z" />
                <path className="dl-folder-a" d="M48 26 34 58M48 26l14 32M39 48h18" />
              </svg>
            </div>
            <div className="dl-step-copy">
              <span className="dl-step">02</span>
              <h3>Move to Applications</h3>
              <p>Drag the Pocket icon into the Applications folder.</p>
            </div>
          </li>
          <li>
            <div className="dl-art" aria-hidden="true">
              <MenuBarStrip amount="$337.03" />
            </div>
            <div className="dl-step-copy">
              <span className="dl-step">03</span>
              <h3>Set your starting balance</h3>
              <p>Open Pocket from Applications and set your balance. Record your next purchase to see the menu bar balance update.</p>
            </div>
          </li>
        </ol>
        <div className="dl-foot">
          <div>
            <a className="dl-retry" href={DOWNLOAD_URL} onClick={() => trackWebsiteEvent("install_help_retry", { action: "download_again" })}>Download again <span aria-hidden="true">↓</span></a>
            <a href="/guides/getting-started/">Read the getting started guide <span aria-hidden="true">↗</span></a>
            <a className="dl-help" href={ISSUES_URL} target="_blank" rel="noopener noreferrer" onClick={() => trackWebsiteEvent("install_help_support", { action: "report_problem" })}>Report a problem <span aria-hidden="true">↗</span></a>
          </div>
          <button className="pill pill-dark" type="button" onClick={() => close("done")}>Got it</button>
        </div>
      </div>
    </dialog>
  );
}
