"use client";

import { gsap } from "gsap";
import Image, { type StaticImageData } from "next/image";
import { type KeyboardEvent, useEffect, useLayoutEffect, useRef, useState } from "react";
import type { Locale } from "@/lib/locale";
import { MenuBarStrip } from "@/components/MenuBar";
import menuBarDark from "@/public/media/menu-bar-dark-2026-10-14.png";
import menuBar from "@/public/media/menu-bar-2026-10-14.png";
import overviewDark from "@/public/media/overview-dark-2026-10-14.png";
import overview from "@/public/media/overview-2026-10-14.png";
import planDark from "@/public/media/plan-1-5-5-dark.webp";
import plan from "@/public/media/plan-1-5-5-light.webp";
import subscriptions from "@/public/media/subscriptions-light-2026-11-18.png";
import subscriptionsDark from "@/public/media/subscriptions-dark-2026-11-18.png";

const VIEWS = [
  { id: "menu", label: { en: "Menu bar", es: "Barra de menús" }, caption: { en: "Click your balance to log an entry.", es: "Haz clic en tu saldo para registrar un movimiento." }, light: menuBar, dark: menuBarDark, alt: { en: "Pocket’s menu bar panel shows the balance, quick-add buttons, an entry form and recent activity.", es: "El panel de Pocket en la barra de menús muestra el saldo, los botones de registro rápido, un formulario y los movimientos recientes." } },
  { id: "overview", label: { en: "Overview", es: "Resumen" }, caption: { en: "What came in, what went out.", es: "Lo que ingresaste y lo que gastaste." }, light: overview, dark: overviewDark, alt: { en: "Pocket’s main window shows the balance, spending and income entries, and payments waiting for confirmation.", es: "La ventana principal de Pocket muestra el saldo, los gastos, los ingresos y los pagos por confirmar." } },
  { id: "plan", label: { en: "Plan", es: "Plan" }, caption: { en: "See what you can spend before payday and how your balance could change.", es: "Mira cuánto puedes gastar antes de cobrar y cómo podría cambiar tu saldo." }, light: plan, dark: planDark, alt: { en: "Pocket Plan shows the selected payday, the minimum balance to keep, the amount available today, and the projected balance chart.", es: "La vista Plan muestra la fecha de cobro, el saldo mínimo, el monto disponible hoy y un gráfico del saldo previsto." } },
  { id: "subscriptions", label: { en: "Subscriptions", es: "Suscripciones" }, caption: { en: "See when each subscription renews and what’s due soon.", es: "Consulta cuándo se renueva cada suscripción y qué cobros se acercan." }, light: subscriptions, dark: subscriptionsDark, alt: { en: "Example subscription renewals with monthly and yearly costs and charges due in the next 30 days.", es: "Ejemplo de renovaciones con costos mensuales y anuales y cobros previstos para los próximos 30 días." } },
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

export function Tour({ initialView = "menu", locale }: { initialView?: (typeof VIEWS)[number]["id"]; locale: Locale }) {
  const spanish = locale === "es";
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
  const dialog = useRef<HTMLDialogElement>(null);
  const [inspecting, setInspecting] = useState(false);
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
      <div className="tour-bar">
        <div className="tour-tabs" role="tablist" aria-label={spanish ? "Vistas" : "Views"} ref={tabs} onKeyDown={onKey}>
          <span className="tour-tabs-fill" ref={ind} aria-hidden="true" />
          {VIEWS.map((v) => (
            <button
              key={v.id}
              id={`tour-tab-${v.id}`}
              type="button"
              role="tab"
              aria-selected={v.id === view}
              tabIndex={v.id === view ? 0 : -1}
              aria-controls="tour-panel"
              onClick={() => setView(v.id)}
            >
              {v.label[locale]}
            </button>
          ))}
        </div>
        <button className="tour-expand" type="button" aria-haspopup="dialog" onClick={() => {
          setInspecting(true);
          dialog.current?.showModal();
        }}>
          <span aria-hidden="true">⤢</span> {spanish ? "Ampliar vista" : "Enlarge view"}
        </button>
      </div>
      <div
        className="tour-stage"
        id="tour-panel"
        role="tabpanel"
        aria-labelledby={`tour-tab-${current.id}`}
        style={{ "--dir": dir } as React.CSSProperties}
      >
        {view === "menu" && (
          <div className="tour-menu">
            <Shot className="tour-behind" light={overview} dark={overviewDark} sizes="(max-width: 720px) 0px, 620px" alt="" />
            <MenuBarStrip locale={locale} amount="$2,431.08" />
            <Shot className="tour-panel" light={current.light} dark={current.dark} alt={current.alt[locale]} sizes="(max-width: 720px) 100vw, 390px" />
          </div>
        )}
        {view !== "menu" && (
          <Shot key={view} className="tour-shot" light={current.light} dark={current.dark} alt={current.alt[locale]} sizes="(max-width: 1080px) 100vw, 1000px" />
        )}
      </div>
      <p className="tour-caption">{current.caption[locale]}</p>
      <dialog ref={dialog} className="tour-dialog" aria-labelledby="tour-dialog-title"
        onClose={() => setInspecting(false)}
        onClick={(event) => { if (event.target === event.currentTarget) dialog.current?.close(); }}>
        {inspecting && (
          <div className="tour-viewer">
            <div className="tour-viewer-tools">
              <h3 id="tour-dialog-title">{current.label[locale]}</h3>
              <button type="button" autoFocus onClick={() => dialog.current?.close()}>{spanish ? "Cerrar" : "Close"}</button>
            </div>
            <picture className="tour-viewport" style={{ "--shot-ratio": current.light.width / current.light.height } as React.CSSProperties}>
              <source media="(prefers-color-scheme: dark)" srcSet={current.dark.src} />
              <img src={current.light.src} alt={current.alt[locale]} width={current.light.width} height={current.light.height} />
            </picture>
          </div>
        )}
      </dialog>
    </div>
  );
}
