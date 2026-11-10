"use client";

import { gsap } from "gsap";
import Image, { type StaticImageData } from "next/image";
import { type KeyboardEvent, useEffect, useLayoutEffect, useRef, useState } from "react";
import { MenuBarStrip } from "@/components/MenuBar";
import menuBarDark from "@/public/media/menu-bar-dark-2026-10-14.png";
import menuBar from "@/public/media/menu-bar-2026-10-14.png";
import overviewDark from "@/public/media/overview-dark-2026-10-14.png";
import overview from "@/public/media/overview-2026-10-14.png";
import planDark from "@/public/media/plan-dark-2026-10-14.png";
import plan from "@/public/media/plan-2026-10-14.png";
import subscriptions from "@/public/media/subscriptions-light-2026-11-09.png";
import subscriptionsDark from "@/public/media/subscriptions-dark-2026-11-09.png";

const VIEWS = [
  { id: "menu", label: "Menu bar", caption: "One click from anywhere, all day." },
  { id: "overview", label: "Overview", caption: "What came in, what went out." },
  { id: "plan", label: "Plan", caption: "Where your balance is heading." },
  { id: "subscriptions", label: "Subscriptions", caption: "What renews, and what it adds up to." },
] as const;

// A screenshot of the app in the visitor's appearance. CSS shows one of the two captures; the
// other is display: none and lazy, so it's never downloaded. (Both stay direct children of the
// stage, so the screenshot sizing rules apply to them.)
function Shot({ light, dark, sizes, alt, className }: {
  light: StaticImageData;
  dark: StaticImageData;
  sizes: string;
  alt: string;
  className: string;
}) {
  return (
    <>
      <Image className={`${className} shot-light`} src={light} sizes={sizes} alt={alt} />
      <Image className={`${className} shot-dark`} src={dark} sizes={sizes} alt={alt} />
    </>
  );
}

export function Tour({ initialView = "menu" }: { initialView?: (typeof VIEWS)[number]["id"] }) {
  const [view, setViewState] = useState(initialView);
  // +1 when the new view is to the right of the old tab, -1 to the left: the content arrives
  // from that side, so the panel moves the way the selection did.
  const [dir, setDir] = useState(0);
  function setView(next: (typeof VIEWS)[number]["id"]) {
    const from = VIEWS.findIndex((v) => v.id === view);
    const to = VIEWS.findIndex((v) => v.id === next);
    if (from !== to) setDir(Math.sign(to - from));
    setViewState(next);
  }
  const current = VIEWS.find((v) => v.id === view)!;
  const tabs = useRef<HTMLDivElement>(null);
  const ind = useRef<HTMLSpanElement>(null);
  const moved = useRef(false);

  // The selected tab's fill is one shape that slides between tabs. Until it has been placed
  // (and with no JS at all), the selected button paints its own fill instead.
  useLayoutEffect(() => {
    const box = tabs.current;
    const fill = ind.current;
    const tab = box?.querySelector<HTMLElement>('[aria-selected="true"]');
    if (!box || !fill || !tab) return;
    const to = { x: tab.offsetLeft, width: tab.offsetWidth };
    if (!moved.current || matchMedia("(prefers-reduced-motion: reduce)").matches) gsap.set(fill, to);
    else gsap.to(fill, { ...to, duration: 0.55, ease: "expo.out", overwrite: true });
    moved.current = true;
    box.dataset.ready = "";
  }, [view]);

  // Late font loads and wrapping change the tabs' widths, so the fill follows without animating.
  useEffect(() => {
    const box = tabs.current;
    if (!box) return;
    const ro = new ResizeObserver(() => {
      const tab = box.querySelector<HTMLElement>('[aria-selected="true"]');
      if (tab && ind.current) gsap.set(ind.current, { x: tab.offsetLeft, width: tab.offsetWidth });
    });
    ro.observe(box);
    return () => ro.disconnect();
  }, []);

  // Arrow keys move between tabs, as in any tab list; only the selected one is in the tab order.
  function onKey(e: KeyboardEvent) {
    const i = VIEWS.findIndex((v) => v.id === view);
    const next = { ArrowRight: i + 1, ArrowLeft: i - 1, Home: 0, End: VIEWS.length - 1 }[e.key];
    if (next === undefined) return;
    e.preventDefault();
    const n = (next + VIEWS.length) % VIEWS.length;
    setView(VIEWS[n].id);
    tabs.current?.querySelectorAll("button")[n]?.focus();
  }

  return (
    <div className="tour">
      <div
        className="tour-stage"
        id="tour-panel"
        role="tabpanel"
        aria-label={current.label}
        style={{ "--dir": dir } as React.CSSProperties}
      >
        {view === "menu" && (
          <div className="tour-menu">
            <Shot className="tour-behind" light={overview} dark={overviewDark} sizes="(max-width: 720px) 0px, 620px" alt="" />
            <MenuBarStrip amount="$2,431.08" />
            <Shot
              className="tour-panel"
              light={menuBar}
              dark={menuBarDark}
              sizes="(max-width: 720px) 100vw, 390px"
              alt="Pocket's menu bar panel: the balance, quick-add buttons, a form to add an entry, a payment waiting to be confirmed, and recent entries."
            />
          </div>
        )}
        {view === "overview" && (
          <Shot
            className="tour-shot"
            light={overview}
            dark={overviewDark}
            sizes="(max-width: 1080px) 100vw, 1000px"
            alt="Pocket's main window: the balance, quick-add buttons, a form to add an entry, a payment waiting to be confirmed, and history."
          />
        )}
        {view === "plan" && (
          <Shot
            className="tour-shot"
            light={plan}
            dark={planDark}
            sizes="(max-width: 1080px) 100vw, 1000px"
            alt="The Plan view: a step chart of the projected balance and the list of payments coming up."
          />
        )}
        {view === "subscriptions" && (
          <Shot
            className="tour-shot"
            light={subscriptions}
            dark={subscriptionsDark}
            sizes="(max-width: 1080px) 100vw, 1000px"
            alt="Pocket for Mac's Subscriptions tab: monthly and annual costs, active services with their prices, and upcoming renewal dates. Example data."
          />
        )}
      </div>
      <div className="tour-bar">
        <p className="tour-caption">
          <b>{current.label}</b> <i>{current.caption}</i>
        </p>
        <div className="tour-tabs" role="tablist" aria-label="Views" ref={tabs} onKeyDown={onKey}>
          <span className="tour-tabs-fill" ref={ind} aria-hidden="true" />
          {VIEWS.map((v) => (
            <button
              key={v.id}
              type="button"
              role="tab"
              aria-selected={v.id === view}
              tabIndex={v.id === view ? 0 : -1}
              aria-controls="tour-panel"
              onClick={() => setView(v.id)}
            >
              {v.label}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
