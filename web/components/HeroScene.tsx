"use client";

import Image from "next/image";
import { useEffect, useRef, useState, type PointerEvent } from "react";
import { useDownloadPlatform } from "@/components/PlatformDownload";

const INITIAL_CENTS = 33703;

function CoffeeIcon() {
  return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 8h12v7a5 5 0 0 1-5 5h-2a5 5 0 0 1-5-5V8Zm12 1h2a3 3 0 0 1 0 6h-2M8 3v2m5-2v2M3 22h17" /></svg>;
}

/** A small, local-only demo. The illustrated balance never reads or writes a ledger. */
export function HeroScene() {
  const platform = useDownloadPlatform();
  const [spent, setSpent] = useState(false);
  const [moving, setMoving] = useState(true);
  const scene = useRef<HTMLDivElement>(null);
  const frame = useRef(0);
  const reduced = useRef(false);
  const amount = ((INITIAL_CENTS - (spent ? 650 : 0)) / 100).toFixed(2);

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
    <div className="pocket-scene" ref={scene} onPointerMove={move} onPointerLeave={resetTilt} data-moving={moving} data-active="true" data-spent={spent}>
      <div className="scene-backdrop" aria-hidden="true"><span className="scene-orbit" /><span className="scene-orbit second" /></div>
      <div className="scene-world">
        <div className="scene-menubar" aria-hidden="true">
          <svg viewBox="0 0 24 24"><path d="M5 9h14v8l-7 4-7-4V9Z" /><path d="M9 9V6a3 3 0 0 1 6 0v3" /></svg>
          <span>${amount}</span>
          <span className="scene-wifi"><svg viewBox="0 0 24 24"><path d="M3 8a14 14 0 0 1 18 0M6 12a9 9 0 0 1 12 0m-9 4a4 4 0 0 1 6 0" /><circle cx="12" cy="20" r="1" /></svg></span>
          <span>9:41</span>
        </div>
        <div className="scene-mascot" aria-hidden="true">
          <Image src="/pocket-sculpture.webp" alt="" width={900} height={900} sizes="(max-width: 600px) 85vw, (max-width: 1000px) 500px, 560px" preload fetchPriority="high" />
        </div>
        <div className="scene-balance">
          <div className="scene-balance-head"><span>Money left</span><span className="scene-status">
            {platform === "mac" ? "On your Mac" : platform === "windows" ? "On your PC" : "On your device"}
          </span></div>
          <p className="scene-amount" key={amount}>${amount}<span>USD</span></p>
          <div className="scene-balance-bottom"><span className="scene-check" aria-hidden="true">✓</span><span>Your day. At a glance.</span></div>
        </div>
        <div className="scene-receipt" aria-hidden="true"><CoffeeIcon /><span>Coffee added</span><b>−$6.50</b></div>
      </div>
      <div className="scene-controls">
        <button className="scene-coffee" type="button" onClick={() => setSpent(!spent)}><CoffeeIcon />{spent ? "Undo coffee" : "Try adding a coffee"}<span>{spent ? "+$6.50" : "−$6.50"}</span></button>
        <span className="scene-demo-note">Interactive demo · example balance</span>
      </div>
      <button className="scene-motion" type="button" aria-label={moving ? "Pause scene motion" : "Resume scene motion"} aria-pressed={!moving} onClick={() => { setMoving(!moving); resetTilt(); }}>
        {moving ? <svg viewBox="0 0 20 20" aria-hidden="true"><path d="M7 5v10m6-10v10" /></svg> : <svg viewBox="0 0 20 20" aria-hidden="true"><path d="m7 4 8 6-8 6Z" /></svg>}
      </button>
      <span className="sr-only" role="status">{spent ? "Coffee added: minus $6.50. Example balance: $330.53." : "Example balance: $337.03."}</span>
    </div>
  );
}
