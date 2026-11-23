"use client";

import { useEffect, useRef, useState, type CSSProperties, type PointerEvent } from "react";

const INITIAL_CENTS = 33703;
const COFFEE_CENTS = 650;

const COINS = [
  "    .-======-.      ",
  "   (  .----.  )     ",
  "   |='------'=|     ",
  "  .|==========|-.   ",
  " (  '--------'   )  ",
  " |='----------'=|   ",
  "  '------------'    ",
].join("\n");

const COFFEE = [
  "      (  )  )       ",
  "       )(  (        ",
  "    .--------.      ",
  "    |        |==.   ",
  "    |        |  )   ",
  "     \\______/=='    ",
  "   '------------'   ",
].join("\n");

function CoffeeIcon() {
  return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 8h12v7a5 5 0 0 1-5 5h-2a5 5 0 0 1-5-5V8Zm12 1h2a3 3 0 0 1 0 6h-2M8 3v2m5-2v2M3 22h17" /></svg>;
}

/** A small, local-only demo. The illustrated balance never reads or writes a ledger. */
export function HeroScene() {
  const [spent, setSpent] = useState(false);
  const [moving, setMoving] = useState(true);
  const scene = useRef<HTMLDivElement>(null);
  const frame = useRef(0);
  const reduced = useRef(false);
  const amount = ((INITIAL_CENTS - (spent ? COFFEE_CENTS : 0)) / 100).toFixed(2);

  useEffect(() => {
    const el = scene.current;
    if (!el) return;
    const mq = matchMedia("(prefers-reduced-motion: reduce)");
    const preference = () => {
      reduced.current = mq.matches;
      if (mq.matches) {
        cancelAnimationFrame(frame.current);
        el.style.setProperty("--rx", "0deg");
        el.style.setProperty("--ry", "0deg");
      }
    };
    preference();
    let visible = true;
    const activity = () => { el.dataset.active = String(visible && !document.hidden); };
    const observer = new IntersectionObserver(([entry]) => { visible = entry.isIntersecting; activity(); });
    observer.observe(el);
    document.addEventListener("visibilitychange", activity);
    mq.addEventListener("change", preference);
    return () => {
      cancelAnimationFrame(frame.current);
      observer.disconnect();
      mq.removeEventListener("change", preference);
      document.removeEventListener("visibilitychange", activity);
    };
  }, []);

  function move(event: PointerEvent<HTMLDivElement>) {
    if (reduced.current || !moving || event.pointerType !== "mouse") return;
    const rect = event.currentTarget.getBoundingClientRect();
    const x = (event.clientX - rect.left) / rect.width - .5;
    const y = (event.clientY - rect.top) / rect.height - .5;
    cancelAnimationFrame(frame.current);
    frame.current = requestAnimationFrame(() => {
      scene.current?.style.setProperty("--rx", `${-y * 8}deg`);
      scene.current?.style.setProperty("--ry", `${x * 10}deg`);
    });
  }

  function resetTilt() {
    cancelAnimationFrame(frame.current);
    scene.current?.style.setProperty("--rx", "0deg");
    scene.current?.style.setProperty("--ry", "0deg");
  }

  return (
    <div id="try-pocket" className="pocket-scene" ref={scene} onPointerMove={move} onPointerLeave={resetTilt} data-moving={moving} data-active="true" data-spent={spent}>
      <div className="printer-stage">
        <div className="engraving" aria-hidden="true">
          {Array.from({ length: 32 }, (_, i) => (
            <i key={i} style={{ "--turn": `${i * 180 / 32}deg` } as CSSProperties} />
          ))}
        </div>
        <div className="scene-world" aria-hidden="true">
          <div className="printer-body">
            <div className="printer-top"><b>Pocket</b><i className="printer-vents" /></div>
            <div className="printer-slot" />
            <div className="printer-paper" key={amount}>
              <div className="receipt-title">Balance receipt</div>
              <pre>{spent ? COFFEE : COINS}</pre>
              <div className="receipt-row"><span>Opening</span><span>$337.03</span></div>
              <div className="receipt-row"><span>Coffee</span><span>{spent ? "−$6.50" : "—"}</span></div>
              <div className="receipt-total"><small>Money left</small><b>${amount}</b></div>
              <div className="receipt-barcode" />
            </div>
          </div>
        </div>
        <span className="stage-caption">{spent ? "After coffee" : "Before coffee"}</span>
        <button className="scene-motion" type="button" aria-label={moving ? "Pause scene motion" : "Resume scene motion"} onClick={() => { setMoving(!moving); resetTilt(); }}>
          {moving ? <svg viewBox="0 0 20 20" aria-hidden="true"><path d="M7 5v10m6-10v10" /></svg> : <svg viewBox="0 0 20 20" aria-hidden="true"><path d="m7 4 8 6-8 6Z" /></svg>}
        </button>
      </div>
      <div className="scene-controls">
        <span>Example ledger</span>
        <button className="scene-coffee" type="button" onClick={() => setSpent(!spent)}>
          <CoffeeIcon />{spent ? "Undo coffee" : "Add a coffee"}<span>{spent ? "+$6.50" : "−$6.50"}</span>
        </button>
      </div>
      <span className="sr-only" role="status">{spent ? "Coffee added. " : ""}Example balance: ${amount}.</span>
    </div>
  );
}
