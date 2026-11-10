"use strict";
// The original Pocket server. Anyone can point Pocket at their own (see SELF-HOSTING.md).
const DEFAULT_SERVER = { url: "https://upmymrrfpwnqmnaclpyt.supabase.co", key: "sb_publishable_0QeYqlwAKI0Eit1nTB5vFw_PK1fxCaB" };
const SERVER_STORE = "pocket.server";
const POLL_MS = 15000;
const KEY_STORE = "pocket.key";
const QUEUE_STORE = "pocket.queue";
const RANGE_STORE = "pocket.range";
const TAB_STORE = "pocket.tab";
const GREET_STORE = "pocket.greeted";

const CADENCE = {
  weekly:   { name: "Weekly",        perMonth: 52 / 12, unit: "week" },
  biweekly: { name: "Every 2 weeks", perMonth: 26 / 12, unit: "2 weeks" },
  monthly:  { name: "Monthly",       perMonth: 1,       unit: "month" },
  quarterly: { name: "Every 3 months", perMonth: 1 / 3, unit: "3 months" },
  yearly:   { name: "Yearly",        perMonth: 1 / 12,  unit: "year" },
};
const RANGE_NAME = { 30: "month", 91: "3 months", 182: "6 months", 365: "year" };

const $ = (id) => document.getElementById(id);
const money = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" });
const compactMoney = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD", notation: "compact", maximumFractionDigits: 1 });
const fmt = (n) => money.format(n);
const signed = (n) => (n > 0 ? "+" : "") + fmt(n);
const dayFmt = new Intl.DateTimeFormat("en-US", { weekday: "short", month: "short", day: "numeric" });
const shortFmt = new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric" });
const monthFmt = new Intl.DateTimeFormat("en-US", { month: "long", year: "numeric" });
const monthOnly = new Intl.DateTimeFormat("en-US", { month: "long" });
const monthTick = new Intl.DateTimeFormat("en-US", { month: "short" });
const asDate = (iso) => new Date(iso + "T12:00:00");
const isoOf = (d) => new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 10);
const todayISO = () => isoOf(new Date());
const addDays = (iso, n) => { const d = asDate(iso); d.setDate(d.getDate() + n); return isoOf(d); };
const monthDate = (ym) => new Date(ym + "-15T12:00:00");
const shiftMonth = (ym, n) => { const d = monthDate(ym); d.setMonth(d.getMonth() + n); return isoOf(d).slice(0, 7); };
const pick = (list) => list[Math.floor(Math.random() * list.length)];

const motionQuery = matchMedia("(prefers-reduced-motion: reduce)");
const calm = () => motionQuery.matches;
const EASE_OUT = "cubic-bezier(0.16, 1, 0.3, 1)";

// Browser storage can be blocked (private mode); nothing here is required to work.
const ls = {
  get(k) { try { return localStorage.getItem(k); } catch { return null; } },
  set(k, v) { try { localStorage.setItem(k, v); } catch { /* ignore */ } },
  del(k) { try { localStorage.removeItem(k); } catch { /* ignore */ } },
};

// ---------- icons (one stroke family) ----------
const ICONS = {
  in: '<path d="M17 7 7 17"/><path d="M16 17H7V8"/>',
  out: '<path d="M7 17 17 7"/><path d="M8 7h9v9"/>',
  repeat: '<path d="m17 2 4 4-4 4"/><path d="M3 11v-1a4 4 0 0 1 4-4h14"/><path d="m7 22-4-4 4-4"/><path d="M21 13v1a4 4 0 0 1-4 4H3"/>',
  clock: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
  check: '<path d="M5 12.5 10 17 19 7"/>',
  lock: '<rect x="5" y="11" width="14" height="9" rx="2.5"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
  trend: '<path d="m3 17 6-6 4 4 8-8"/><path d="M15 7h6v6"/>',
  minus: '<path d="M6 12h12"/>',
  plus: '<path d="M12 6v12"/><path d="M6 12h12"/>',
};
function icon(name, cls = "") {
  return `<svg class="ic ${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[name]}</svg>`;
}

function mk(tag, cls, text) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text != null) e.textContent = text;
  return e;
}

// ---------- the pocket character ----------
const COIN_HTML =
  [-2, -1, 0, 1, 2].map((z) => `<span class="coin-edge" style="transform:translateZ(${z}px)"></span>`).join("") +
  '<span class="coin-face">$</span><span class="coin-face back">$</span>';
const INK = "#3b2a1a";
const POCKET_SVG = `
<svg class="pk-front" viewBox="0 0 560 430" aria-hidden="true">
  <defs><linearGradient id="__ID__" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fffdf7"/><stop offset="1" stop-color="#ebe0c8"/></linearGradient></defs>
  <path d="M0 0H560V256Q560 292 528 308L308 416Q280 430 252 416L32 308Q0 292 0 256Z" fill="url(#__ID__)"/>
  <rect width="560" height="14" fill="#000" opacity=".08"/>
  <path d="M42 48H518V242Q518 268 495 280L294 378Q280 385 266 378L65 280Q42 268 42 242Z" fill="none" stroke="#cdb68c" stroke-width="10" stroke-dasharray="26 18" stroke-linecap="round"/>
  <ellipse cx="160" cy="236" rx="32" ry="16" fill="#f4a6a0" opacity=".55"/>
  <ellipse cx="400" cy="236" rx="32" ry="16" fill="#f4a6a0" opacity=".55"/>
  <g class="part brows" stroke="${INK}" stroke-width="12" stroke-linecap="round"><path d="M178 136 232 116"/><path d="M382 136 328 116"/></g>
  <g class="look"><g class="blink">
    <g class="part e-dot" fill="${INK}"><circle cx="210" cy="172" r="25"/><circle cx="350" cy="172" r="25"/><circle cx="219" cy="163" r="8" fill="#fff"/><circle cx="359" cy="163" r="8" fill="#fff"/></g>
    <g class="part e-joy" fill="none" stroke="${INK}" stroke-width="13" stroke-linecap="round"><path d="M184 184Q210 148 236 184"/><path d="M324 184Q350 148 376 184"/></g>
    <g class="part e-oof" fill="none" stroke="${INK}" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"><path d="M190 152 230 172 190 192"/><path d="M370 152 330 172 370 192"/></g>
    <g class="part e-star" fill="${INK}"><path d="M210 138Q216 166 244 172Q216 178 210 206Q204 178 176 172Q204 166 210 138Z"/><path d="M350 138Q356 166 384 172Q356 178 350 206Q344 178 316 172Q344 166 350 138Z"/></g>
    <g class="part e-sleep" fill="none" stroke="${INK}" stroke-width="12" stroke-linecap="round"><path d="M186 170Q210 192 234 170"/><path d="M326 170Q350 192 374 170"/></g>
  </g></g>
  <path class="part m-smile" d="M248 234Q280 266 312 234" fill="none" stroke="${INK}" stroke-width="12" stroke-linecap="round"/>
  <g class="part m-grin"><path d="M238 228Q280 232 322 228Q318 284 280 286Q242 284 238 228Z" fill="${INK}"/><path d="M256 266Q280 250 304 266Q298 284 280 285Q262 284 256 266Z" fill="#f07c7c"/></g>
  <path class="part m-wavy" d="M244 254Q262 236 280 254Q298 272 316 254" fill="none" stroke="${INK}" stroke-width="12" stroke-linecap="round"/>
  <ellipse class="part m-o" cx="280" cy="252" rx="17" ry="21" fill="${INK}"/>
  <path class="part m-sleep" d="M264 248Q280 258 296 248" fill="none" stroke="${INK}" stroke-width="11" stroke-linecap="round"/>
  <path class="part sweat" d="M446 92Q466 124 459 140Q452 156 437 152Q422 146 428 128Q434 110 446 92Z" fill="#8fd0f5"/>
</svg>`;

let pocketCount = 0;
function makePocket(extra = "") {
  const el = mk("div", "pk " + extra);
  el.setAttribute("aria-hidden", "true");
  const gradId = "pkShade" + (++pocketCount); // unique per instance so a hidden copy can't break the other
  el.innerHTML = `<div class="pk-slot"><div class="coin"><div class="coin-body">${COIN_HTML}</div></div></div>${POCKET_SVG.replaceAll("__ID__", gradId)}<div class="pk-fx"></div>`;
  el.dataset.face = "happy";
  return el;
}

const pk = { el: null, base: "happy", transient: null, preview: null, timer: 0, blinkTimer: 0, pokes: 0, focusLook: false };
const part = (sel) => pk.el?.querySelector(sel);

function applyFace() { if (pk.el) pk.el.dataset.face = pk.transient || pk.preview || pk.base; }
function face(name, ms = 1500) {
  pk.transient = name;
  applyFace();
  clearTimeout(pk.timer);
  pk.timer = setTimeout(() => { pk.transient = null; applyFace(); }, ms);
}

function say(text) {
  const fx = part(".pk-fx");
  if (!fx) return;
  fx.querySelector(".bubble")?.remove();
  const b = mk("div", "bubble", text);
  fx.append(b);
  const still = "translateY(0) scale(1)";
  const frames = calm()
    ? [{ opacity: 0 }, { opacity: 1, offset: .12 }, { opacity: 1, offset: .85 }, { opacity: 0 }]
    : [{ opacity: 0, transform: "translateY(8px) scale(.7)" }, { opacity: 1, transform: still, offset: .12 },
       { opacity: 1, transform: still, offset: .85 }, { opacity: 0, transform: "translateY(-4px) scale(.96)" }];
  b.animate(frames, { duration: 2000, easing: EASE_OUT }).finished.then(() => b.remove(), () => {});
}

function blink(el = pk.el) {
  el?.querySelector(".blink")?.animate(
    [{ transform: "scaleY(1)" }, { transform: "scaleY(.08)" }, { transform: "scaleY(1)" }],
    { duration: 170, easing: "ease-in-out" });
}
function scheduleBlink() {
  clearTimeout(pk.blinkTimer);
  if (calm()) return;
  pk.blinkTimer = setTimeout(() => {
    const f = pk.el?.dataset.face;
    if (!document.hidden && (f === "happy" || f === "worried" || f === "hope")) {
      blink();
      if (Math.random() < .25) setTimeout(blink, 240); // the occasional double blink
    }
    scheduleBlink();
  }, 2400 + Math.random() * 3400);
}

function look(dx, dy) { const g = part(".look"); if (g) g.style.transform = `translate(${dx}px, ${dy}px)`; }
function lookAt(x, y, reach = 300) {
  if (!pk.el) return;
  const r = pk.el.getBoundingClientRect();
  const dx = x - (r.left + r.width / 2), dy = y - (r.top + r.height * .6);
  const d = Math.hypot(dx, dy) || 1, k = Math.min(1, d / reach);
  look((dx / d) * 24 * k, (dy / d) * 16 * k);
}

function squish() {
  if (calm()) return;
  part(".pk-front")?.animate(
    [{ transform: "scale(1, 1)" }, { transform: "scale(1.06, .9)" }, { transform: "scale(.98, 1.03)" }, { transform: "scale(1, 1)" }],
    { duration: 420, easing: EASE_OUT });
}

function flyingCoin() {
  const c = part(".coin").cloneNode(true);
  c.classList.add("coin-fly");
  part(".pk-slot").append(c);
  return c;
}

function floatAmount(amount) {
  if (calm()) return;
  const t = mk("div", "float-amt" + (amount < 0 ? " neg" : ""), signed(amount));
  part(".pk-fx").append(t);
  t.animate([{ transform: "translate(-50%, 6px)", opacity: 0 }, { transform: "translate(-50%, -10px)", opacity: 1, offset: .25 },
             { transform: "translate(-50%, -44px)", opacity: 0 }], { duration: 1300, easing: EASE_OUT })
    .finished.then(() => t.remove(), () => {});
}

// Money in: a coin falls into the pocket, which gulps it.
function coinDrop(amount, showAmount) {
  if (calm() || !pk.el) return;
  const c = flyingCoin();
  c.animate([
    { transform: "translateY(-120px) rotateY(0deg)", opacity: 0 },
    { opacity: 1, offset: .2 },
    { transform: "translateY(44px) rotateY(720deg)", opacity: 1 },
  ], { duration: 640, easing: "cubic-bezier(0.55, 0, 0.9, 0.4)" }).finished.then(() => {
    c.remove();
    squish();
    part(".coin")?.animate([{ transform: "translateY(0)" }, { transform: "translateY(5px)" }, { transform: "translateY(0)" }],
      { duration: 360, easing: EASE_OUT });
  }, () => c.remove());
  if (showAmount) setTimeout(() => floatAmount(amount), 380);
}

// Money out: a coin pops out and tumbles away.
function coinPop(amount) {
  if (calm() || !pk.el) return;
  squish();
  const c = flyingCoin();
  c.animate([
    { transform: "translate(0, 40px) rotateY(0deg) rotateZ(0deg)", opacity: 1, easing: "cubic-bezier(0.2, 0.7, 0.4, 1)" },
    { transform: "translate(-30px, -70px) rotateY(420deg) rotateZ(-25deg)", opacity: 1, offset: .5, easing: "cubic-bezier(0.5, 0, 0.9, 0.5)" },
    { transform: "translate(-64px, 10px) rotateY(760deg) rotateZ(-50deg)", opacity: 0, filter: "blur(2px)" },
  ], { duration: 820 }).finished.then(() => c.remove(), () => c.remove());
  floatAmount(amount);
}

// Out of the red: a little shower of coins.
function burst() {
  if (calm() || !pk.el) return;
  const fx = part(".pk-fx");
  for (let i = 0; i < 9; i++) {
    const m = mk("div", "mini-coin");
    fx.append(m);
    const dx = (Math.random() - .5) * 150, up = 50 + Math.random() * 60;
    m.animate([
      { transform: "translate(0, 0) scale(.4)", opacity: 0 },
      { transform: `translate(${dx * .55}px, ${-up}px) scale(1)`, opacity: 1, offset: .4 },
      { transform: `translate(${dx}px, ${40 + Math.random() * 30}px) scale(.8) rotate(${dx * 3}deg)`, opacity: 0 },
    ], { duration: 950 + Math.random() * 300, delay: i * 25, easing: "cubic-bezier(0.25, 0.6, 0.6, 1)" })
      .finished.then(() => m.remove(), () => m.remove());
  }
}

function coinArrive() {
  if (calm() || !pk.el) return;
  part(".coin")?.animate([
    { transform: "translateY(-90px) rotateY(-540deg)", opacity: 0 },
    { opacity: 1, offset: .3 },
    { transform: "translateY(0) rotateY(0deg)", opacity: 1 },
  ], { duration: 1000, delay: 250, easing: EASE_OUT, fill: "backwards" }).finished.then(squish, () => {});
}

// The amount you just entered arcs from the button into its destination.
function flyChip({ amount, from }, target, done) {
  const to = target?.getBoundingClientRect();
  if (calm() || !from || !to || !to.width || to.bottom < 0 || to.top > innerHeight) { done(); return; }
  const outer = mk("div", "fly");
  const chip = mk("div", "fly-chip" + (amount > 0 ? " pos" : ""), signed(amount));
  outer.append(chip);
  document.body.append(outer);
  const w = chip.offsetWidth, h = chip.offsetHeight;
  const x0 = from.left + from.width / 2 - w / 2, y0 = from.top + from.height / 2 - h / 2;
  const x1 = to.left + to.width / 2 - w / 2, y1 = to.top + Math.min(to.height / 2, 30) - h / 2;
  const peak = Math.min(y0, y1) - 60;
  const dur = 720;
  outer.animate([{ transform: `translateX(${x0}px)` }, { transform: `translateX(${x1}px)` }], { duration: dur, easing: "cubic-bezier(0.4, 0, 0.6, 1)" });
  chip.animate([
    { transform: `translateY(${y0}px) scale(.85)`, opacity: 0, easing: "cubic-bezier(0.2, 0.8, 0.4, 1)" },
    { transform: `translateY(${peak}px) scale(1.08)`, opacity: 1, offset: .42, easing: "cubic-bezier(0.6, 0, 0.9, 0.6)" },
    { transform: `translateY(${y1}px) scale(.3)`, opacity: .3 },
  ], { duration: dur }).finished.then(() => outer.remove(), () => outer.remove());
  setTimeout(done, dur - 140);
}


// ---------- odometer balance ----------
function setOdometer(el, value) {
  const text = fmt(value);
  el.setAttribute("aria-label", `Money left: ${text}`);
  let odo = el.querySelector(".odo");
  if (!odo) {
    el.textContent = "";
    odo = mk("span", "odo");
    odo.setAttribute("aria-hidden", "true");
    el.append(odo);
  }
  const shape = text.replace(/\d/g, "0");
  if (odo.dataset.shape !== shape) {
    odo.textContent = "";
    for (const ch of text) {
      if (/\d/.test(ch)) {
        const col = mk("span", "odo-col"), strip = mk("span", "odo-strip");
        for (let i = 0; i < 10; i++) strip.append(mk("span", null, String(i)));
        col.append(strip);
        odo.append(col);
      } else {
        odo.append(mk("span", "odo-sym", ch));
      }
    }
    odo.dataset.shape = shape;
    void odo.offsetWidth; // commit the zero position so the digits roll in
  }
  const digits = text.replace(/\D/g, "");
  const strips = odo.querySelectorAll(".odo-strip");
  strips.forEach((s, i) => {
    s.style.transitionDelay = calm() ? "0ms" : `${(strips.length - 1 - i) * 45}ms`;
    s.style.transform = `translateY(${-Number(digits[i]) * 10}%)`;
  });
}


Object.assign(ICONS, {
  game: '<path d="M6 11h4"/><path d="M8 9v4"/><path d="M15 12h.01"/><path d="M18 10h.01"/><path d="M17.3 5H6.7a4 4 0 0 0-3.96 3.43l-.73 5.1A3 3 0 0 0 5 17c1 0 1.8-.5 2.3-1.3L8.5 14h7l1.2 1.7c.5.8 1.3 1.3 2.3 1.3a3 3 0 0 0 2.98-3.47l-.72-5.1A4 4 0 0 0 17.3 5z"/>',
  bolt: '<path d="M13 2 4 14h7l-1 8 9-12h-7z"/>',
  apps: '<rect x="4" y="4" width="6.5" height="6.5" rx="1.6"/><rect x="13.5" y="4" width="6.5" height="6.5" rx="1.6"/><rect x="4" y="13.5" width="6.5" height="6.5" rx="1.6"/><rect x="13.5" y="13.5" width="6.5" height="6.5" rx="1.6"/>',
  food: '<path d="M5 8h12v5a5 5 0 0 1-5 5h-2a5 5 0 0 1-5-5z"/><path d="M17 9h1a3 3 0 0 1 0 6h-1"/><path d="M9 2.5v3"/><path d="M13 2.5v3"/>',
  bag: '<path d="M4.5 8.5h15l-1 11a1.5 1.5 0 0 1-1.5 1.5H7a1.5 1.5 0 0 1-1.5-1.5z"/><path d="M8.5 11V7a3.5 3.5 0 0 1 7 0v4"/>',
  spark: '<path d="M12 3v4"/><path d="M12 17v4"/><path d="M3 12h4"/><path d="M17 12h4"/><path d="m6 6 2.5 2.5"/><path d="m15.5 15.5 2.5 2.5"/><path d="m6 18 2.5-2.5"/><path d="m15.5 8.5 2.5-2.5"/>',
  bus: '<rect x="5" y="3" width="14" height="15" rx="3"/><path d="M5 11h14"/><path d="M8 21v-3"/><path d="M16 21v-3"/><path d="M8.5 14.5h.01"/><path d="M15.5 14.5h.01"/>',
  dots: '<circle cx="12" cy="12" r="8.5"/><path d="M8.5 12h.01"/><path d="M12 12h.01"/><path d="M15.5 12h.01"/>',
  wallet: '<path d="M4 7a2 2 0 0 1 2-2h11v3"/><rect x="4" y="8" width="16" height="11" rx="2"/><path d="M16 13.5h.01"/>',
  gift: '<rect x="4" y="9" width="16" height="11" rx="1.5"/><path d="M3 9h18"/><path d="M12 9v11"/><path d="M12 9c-2-4-6-4-6-1.5S9 9 12 9z"/><path d="M12 9c2-4 6-4 6-1.5S15 9 12 9z"/>',
  undo: '<path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>',
  gear: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>',
  phone: '<rect x="7" y="2.5" width="10" height="19" rx="2.5"/><path d="M11 18h2"/>',
  laptop: '<rect x="4" y="5" width="16" height="11" rx="1.5"/><path d="M2 19h20"/>',
  x: '<path d="M6 6l12 12"/><path d="M18 6 6 18"/>',
  chevL: '<path d="m15 6-6 6 6 6"/>',
  chevR: '<path d="m9 6 6 6-6 6"/>',
  down: '<path d="m3 7 6 6 4-4 8 8"/><path d="M15 17h6v-6"/>',
  pause: '<path d="M9 5v14"/><path d="M15 5v14"/>',
});

// ---------- categories ----------
const CATS = {
  games:         { name: "Games",         icon: "game",   hue: "purple" },
  subscriptions: { name: "Subscriptions", icon: "repeat", hue: "blue" },
  bills:         { name: "Bills",         icon: "bolt",   hue: "orange" },
  apps:          { name: "Apps",          icon: "apps",   hue: "indigo" },
  food:          { name: "Food",          icon: "food",   hue: "brown" },
  shopping:      { name: "Shopping",      icon: "bag",    hue: "pink" },
  fun:           { name: "Fun",           icon: "spark",  hue: "orange" },
  transport:     { name: "Transport",     icon: "bus",    hue: "teal" },
  other:         { name: "Other",         icon: "dots",   hue: "gray" },
  pay:           { name: "Pay",           icon: "wallet", hue: "green" },
  gift:          { name: "Gift",          icon: "gift",   hue: "green" },
  refund:        { name: "Refund",        icon: "undo",   hue: "green" },
  otherin:       { name: "Other",         icon: "in",     hue: "green" },
  start:         { name: "Starting balance", icon: "wallet", hue: "green" },
};
const SPEND_CATS = ["games", "subscriptions", "bills", "apps", "food", "shopping", "fun", "transport", "other"];
const IN_CATS = ["pay", "gift", "refund", "otherin"];
const catName = (c) => CATS[c]?.name || "Uncategorized";
const catIcon = (c, amount) => CATS[c]?.icon || (amount > 0 ? "in" : "out");
// Each category keeps one hue everywhere; red is saved for "below zero".
const catHue = (c, amount) => CATS[c]?.hue || (amount > 0 ? "green" : "gray");

// ---------- what the pocket says ----------
// Pools by context; each is drawn like a shuffled deck, so lines don't repeat until it runs out.
const LINES = {
  in: ["Yum!", "Ooh, shiny!", "Thank you!", "Mmm, coins", "More, please", "Cha-ching!", "Feeling richer", "Into the pocket!", "Coin acquired", "Jingle jingle"],
  inBig: ["Payday!", "Big money!", "Whoa, nice!", "We're rich! (ish)", "Look at all these coins", "So heavy now"],
  gift: ["A gift? How lovely", "Someone likes you", "Free money!", "Say thank you!"],
  refund: ["Money back!", "Refund secured", "It came back home"],
  out: ["Oof", "Bye-bye, coin", "There it goes", "Spent!", "Hope it was worth it", "See you, coin", "Lighter pocket", "And it's gone"],
  outBig: ["Whoa, big one", "That was a lot of coins", "Ouch", "My pocket felt that"],
  outSmall: ["Just a tiny one", "Pocket change", "Barely felt it"],
  games: ["Another game? Have fun", "Game on!", "GG", "Add it to the backlog", "Player one ready", "Just one more game…"],
  subscriptions: ["Another subscription…", "Monthly friend added", "Subscribed!", "Renewing, renewing"],
  bills: ["Adulting", "Bills, bills, bills", "Responsible!", "Lights stay on"],
  apps: ["New app, new me", "Installed!", "Shiny new app"],
  food: ["Bon appétit", "Snack time", "Was it tasty?"],
  shopping: ["Ooh, what did you get?", "Retail therapy", "Show me later"],
  fun: ["Have fun!", "Treat yourself", "Enjoy it!"],
  transport: ["Safe travels", "Vroom", "Off you go"],
  waiting: ["Can't wait!", "Counting the days", "Soon…", "I'll keep an eye out"],
  planned: ["I'll remember it", "Noted", "On the calendar"],
  poke: ["Hehe", "That tickles!", "Still here!", "Hi there", "Boop", "Careful, I'm full of coins", "Need something?", "*jingle*", "Again!", "You found me"],
  morning: ["Morning!", "Good morning", "Rise and shine"],
  night: ["Up late?", "Night owl!", "Sleep soon"],
  undo: ["Undone!", "Never happened", "Put it back"],
  paired: ["New friend!", "Hi, new device!", "We're connected"],
};
const decks = {};
function line(pool) {
  if (!decks[pool]?.length) {
    const d = [...LINES[pool]];
    for (let i = d.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [d[i], d[j]] = [d[j], d[i]]; }
    decks[pool] = d;
  }
  return decks[pool].pop();
}
function lineFor(diff, category) {
  if (diff > 0) {
    if (category === "gift" || category === "refund") return line(category);
    return line(diff >= 200 ? "inBig" : "in");
  }
  if (category && LINES[category] && Math.random() < .6) return line(category);
  const spent = -diff;
  return line(spent >= 50 ? "outBig" : spent < 2 ? "outSmall" : "out");
}

// ---------- state ----------
let key = null;
let txs = [], rules = [], upcoming = [], presets = [];
let loaded = false, lastSig = "";
let sign = -1, cadence = "once", cat = null, catTouched = false, confirmTouched = false;
let editing = null; // { kind: "tx" | "rule", id }
let subscriptionChoice = null, subscriptionTracking = false, subscriptionDays = 30;
const TAB_NAMES = ["activity", "plan", "subscriptions", "insights"];
let pollTimer = null;
let shownBalance = null;
let knownTx = null, knownRules = null;
let fresh = { tx: new Set(), rules: new Set() };
let pendingFlight = null;  // { amount, from, scheduled } from a local add
let pendingReason = null;  // "delete" | "undo"
let range = [30, 91, 182, 365].includes(Number(ls.get(RANGE_STORE))) ? Number(ls.get(RANGE_STORE)) : 91;
let tab = TAB_NAMES.includes(ls.get(TAB_STORE)) ? ls.get(TAB_STORE) : "activity";
let filter = null;        // { cat, month|null } narrowing History
let insight = { scope: "month", month: todayISO().slice(0, 7) };
let openOcc = new Set();  // expanded "Got it / Skip" rows, kept across re-renders
let showAllUpcoming = false;
let proj = null;
let chartDirty = true;
let pairTimer = 0, pairWatch = 0;

// ---------- server ----------
function cleanServer(url, key) {
  let u = String(url || "").trim().replace(/\/+$/, "");
  if (u && !/^https?:\/\//.test(u)) u = "https://" + u;
  try { const p = new URL(u); if (!/^https?:$/.test(p.protocol) || !p.host) return null; u = p.origin; } catch { return null; }
  key = String(key || "").trim();
  return key.length >= 20 ? { url: u, key } : null;
}
function readServer() {
  try { const s = JSON.parse(ls.get(SERVER_STORE) || "null"); return cleanServer(s?.url, s?.key) || DEFAULT_SERVER; }
  catch { return DEFAULT_SERVER; }
}
let server = readServer();
const isDefaultServer = () => server.url === DEFAULT_SERVER.url;
// Switching servers signs this device out: its key and unsent entries belong to the old one.
function setServer(next) {
  next = next || DEFAULT_SERVER;
  if (next.url === server.url && next.key === server.key) return;
  server = next;
  if (next.url === DEFAULT_SERVER.url) ls.del(SERVER_STORE); else ls.set(SERVER_STORE, JSON.stringify(next));
  ls.del(KEY_STORE); ls.del(QUEUE_STORE);
}

// ---------- network ----------
async function rpc(fn, args = {}, { noKey = false } = {}) {
  const res = await fetch(`${server.url}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: { apikey: server.key, "Content-Type": "application/json" },
    body: JSON.stringify(noKey ? args : { k: key, ...args }),
  });
  const body = res.status === 204 ? null : await res.json().catch(() => null);
  if (!res.ok) {
    const err = new Error(body?.message || `HTTP ${res.status}`);
    err.badKey = body?.code === "28000";
    throw err;
  }
  return body;
}

const isNetErr = (e) => e instanceof TypeError || !navigator.onLine;
function readQueue() { try { return JSON.parse(ls.get(QUEUE_STORE) || "[]"); } catch { return []; } }
function saveQueue(q) { if (q.length) ls.set(QUEUE_STORE, JSON.stringify(q)); else ls.del(QUEUE_STORE); }

// New entries survive being offline: they wait here and go out on the next sync.
async function rpcAdd(fn, args) {
  try { return await rpc(fn, args); }
  catch (e) {
    if (!isNetErr(e)) throw e;
    const q = readQueue();
    q.push({ fn, args });
    saveQueue(q);
    return { queued: true };
  }
}
async function flushQueue() {
  const q = readQueue();
  if (!q.length) return;
  while (q.length) {
    try { await rpc(q[0].fn, q[0].args); q.shift(); }
    catch (e) {
      if (isNetErr(e) || e.badKey) { saveQueue(q); throw e; }
      q.shift(); // the server refused it for good; don't retry forever
    }
  }
  saveQueue(q);
}

function setSync(state, text) {
  const el = $("sync");
  el.className = "sync" + (state ? " " + state : "");
  el.textContent = text;
}

async function load({ quiet = false } = {}) {
  if (!key) return;
  if (!quiet) setSync("busy", "Syncing…");
  try {
    await flushQueue();
    const s = await rpc("pocket_state", { p_today: todayISO(), p_days: range });
    subscriptionTracking = s.subscription_tracking === true;
    const sig = JSON.stringify(s);
    if (sig !== lastSig) {
      lastSig = sig;
      txs = s.transactions; rules = s.recurring; upcoming = s.upcoming; presets = s.presets;
      const txIds = txs.map((t) => t.id), ruleIds = rules.map((r) => r.id);
      fresh = {
        tx: new Set(knownTx ? txIds.filter((id) => !knownTx.has(id)) : []),
        rules: new Set(knownRules ? ruleIds.filter((id) => !knownRules.has(id)) : []),
      };
      const newest = txs.find((t) => fresh.tx.has(t.id));
      knownTx = new Set(txIds); knownRules = new Set(ruleIds);
      loaded = true;
      $("home").removeAttribute("aria-busy");
      render();
      setBalance(txs.reduce((sum, t) => sum + Number(t.amount), 0), newest);
    }
    if (pendingFlight) landScheduled();
    const waiting = readQueue().length;
    const t = new Date().toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
    setSync(waiting ? "off" : "", waiting ? `${waiting} waiting to sync` : `Synced ${t}`);
  } catch (e) {
    if (e.badKey) return lock("This device was removed or its access changed. Pair it again.");
    const waiting = readQueue().length;
    setSync("off", waiting ? `Offline · ${waiting} waiting` : "Offline, retrying");
  }
}

// ---------- balance + reactions ----------
function setBalance(raw, newest) {
  const total = Math.round(raw * 100) / 100;
  const prev = shownBalance;
  shownBalance = total;
  setOdometer($("balance"), total);
  $("balance").classList.toggle("neg", total < 0);
  pk.base = total < 0 ? "worried" : "happy";
  applyFace();
  updatePreview();
  if (prev === null) { coinArrive(); setTimeout(greet, 1400); return; }
  const diff = Math.round((total - prev) * 100) / 100;
  if (!diff) return;

  const flight = pendingFlight && pendingFlight.amount > 0 && diff > 0 ? pendingFlight : null;
  pendingFlight = null;
  const reason = pendingReason;
  pendingReason = null;
  const outOfRed = prev < 0 && total >= 0;
  const intoRed = prev >= 0 && total < 0;

  const land = () => {
    if (diff > 0) coinDrop(diff, !flight); else coinPop(diff);
    if (reason === "delete") { face(diff > 0 ? "joy" : "oof", 1200); say("Poof!"); }
    else if (reason === "undo") { face("happy", 1000); say(line("undo")); }
    else if (outOfRed) { face("joy", 2600); say("We're out of the red!"); burst(); }
    else if (intoRed) { face("oof", 1200); setTimeout(() => say("Uh oh, we're in the red"), 500); }
    else { face(diff > 0 ? "joy" : "oof"); say(lineFor(diff, newest?.category)); }
    if (!calm()) navigator.vibrate?.(diff > 0 ? [8, 40, 8] : 14);
  };
  if (flight) flyChip(flight, part(".pk-slot"), land); else land();
}

// A local add that didn't change the balance yet: it's planned, so it flies to the plan.
function landScheduled() {
  const f = pendingFlight;
  pendingFlight = null;
  if (!f?.scheduled) return;
  const target = tab === "plan" && !$("upcomingSec").hidden ? $("upcomingSec") : $("tab-plan");
  flyChip(f, target, () => {
    face(f.amount > 0 ? "hope" : "happy", 1800);
    say(line(f.amount > 0 ? "waiting" : "planned"));
  });
}

function greet() {
  const overdue = upcoming.filter((u) => u.overdue);
  if (overdue.length) {
    face("hope", 2200);
    say(overdue[0].amount > 0 ? `Did ${overdue[0].label} pay yet?` : `Was ${overdue[0].label} paid?`);
    return;
  }
  const h = new Date().getHours();
  const slot = h >= 5 && h < 11 ? "morning" : h >= 23 || h < 5 ? "night" : null;
  const stamp = todayISO() + slot;
  if (!slot || ls.get(GREET_STORE) === stamp) return;
  ls.set(GREET_STORE, stamp);
  say(line(slot));
}

// ---------- forecast ----------
function project(total) {
  const today = todayISO(), end = addDays(today, range);
  const ev = upcoming
    .map((u) => ({ date: u.overdue ? today : u.due_on, amount: Number(u.amount), label: u.label, id: u.recurring_id, overdue: u.overdue }))
    .filter((e) => e.date <= end)
    .sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : 0));
  const start = Math.round(total * 100) / 100;
  let bal = start;
  const pts = [{ date: today, bal, events: [] }];
  let hitZero = null, backAbove = null, backAboveBy = null, low = { date: today, bal };
  for (const e of ev) {
    const before = bal;
    bal = Math.round((bal + e.amount) * 100) / 100;
    e.after = bal;
    const last = pts[pts.length - 1];
    if (pts.length > 1 && last.date === e.date) { last.bal = bal; last.events.push(e); }
    else pts.push({ date: e.date, bal, events: [e] });
    if (before >= 0 && bal < 0 && !hitZero) hitZero = e.date;
    if (before < 0 && bal >= 0 && !backAbove) { backAbove = e.date; backAboveBy = e; }
    if (bal < low.bal) low = { date: e.date, bal };
  }
  return { today, end, start, endBal: bal, pts, ev, hitZero, backAbove, backAboveBy, low };
}

function runway(p) {
  const d = (iso) => shortFmt.format(asDate(iso));
  if (p.start < 0) {
    if (p.backAboveBy?.overdue) return { lead: "Back above $0 once", strong: `${p.backAboveBy.label} pays`, warn: false };
    return p.backAbove
      ? { lead: "Back above $0 on", strong: d(p.backAbove), warn: false }
      : { lead: "Below $0 for the next", strong: RANGE_NAME[range], warn: true };
  }
  return p.hitZero
    ? { lead: "Runs out on", strong: d(p.hitZero), warn: true }
    : { lead: "Lasts past", strong: d(p.end), warn: false };
}

function niceTicks(lo, hi, n) {
  if (hi - lo < 1) { lo -= 10; hi += 10; }
  const raw = (hi - lo) / (n - 1);
  const mag = 10 ** Math.floor(Math.log10(raw));
  const norm = raw / mag;
  const step = (norm <= 1 ? 1 : norm <= 2 ? 2 : norm <= 5 ? 5 : 10) * mag;
  const out = [];
  for (let v = Math.floor(lo / step) * step; v <= Math.ceil(hi / step) * step + step / 2; v += step) out.push(Math.round(v * 100) / 100);
  return out;
}

const SVGNS = "http://www.w3.org/2000/svg";
function svgEl(tag, attrs = {}, parent) {
  const e = document.createElementNS(SVGNS, tag);
  for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, v);
  parent?.append(e);
  return e;
}

// Step chart of the projected balance: it only changes when a payment lands.
function renderChart({ animate = true } = {}) {
  const box = $("chart");
  if ($("panel-plan").hidden || !proj) { chartDirty = true; return; }
  chartDirty = false;
  const p = proj;
  const W = Math.max(260, box.clientWidth - 16), H = 176, m = { l: 50, r: 16, t: 16, b: 26 };
  const t0 = asDate(p.today).getTime(), t1 = asDate(p.end).getTime();
  const X = (iso) => m.l + ((asDate(iso).getTime() - t0) / (t1 - t0)) * (W - m.l - m.r);
  const vals = p.pts.map((q) => q.bal).concat(0);
  const ticks = niceTicks(Math.min(...vals), Math.max(...vals), 4);
  const lo = ticks[0], hi = ticks[ticks.length - 1];
  const Y = (v) => m.t + ((hi - v) / (hi - lo)) * (H - m.t - m.b);

  const svg = svgEl("svg", {
    viewBox: `0 0 ${W} ${H}`, role: "img", tabindex: "0",
    "aria-label": `Projected balance until ${dayFmt.format(asDate(p.end))}, ending at ${fmt(p.endBal)}. Use the arrow keys to step through payments.`,
  });
  if (lo < 0) svgEl("rect", { class: "redzone", x: m.l, y: Y(0), width: W - m.l - m.r, height: Y(lo) - Y(0) }, svg);
  for (const t of ticks) {
    svgEl("line", { class: t === 0 ? "zero" : "grid", x1: m.l, x2: W - m.r, y1: Y(t), y2: Y(t) }, svg);
    const label = svgEl("text", { class: "tick", x: m.l - 8, y: Y(t) + 4, "text-anchor": "end" }, svg);
    label.textContent = compactMoney.format(t);
  }
  // x labels: today, month starts that have room, the end date
  const xs = [{ iso: p.today, text: "Today", anchor: "start" }];
  if (range >= 91) {
    let mth = shiftMonth(p.today.slice(0, 7), 1);
    while (`${mth}-01` < p.end) {
      const x = X(`${mth}-01`);
      if (x - X(p.today) > 52 && X(p.end) - x > 52) xs.push({ iso: `${mth}-01`, text: monthTick.format(monthDate(mth)), anchor: "middle" });
      mth = shiftMonth(mth, range >= 365 ? 2 : 1);
    }
  }
  xs.push({ iso: p.end, text: shortFmt.format(asDate(p.end)), anchor: "end" });
  for (const x of xs) {
    const t = svgEl("text", { class: "tick", x: X(x.iso), y: H - 6, "text-anchor": x.anchor }, svg);
    t.textContent = x.text;
  }

  let d = `M${X(p.pts[0].date)},${Y(p.pts[0].bal)}`;
  for (let i = 1; i < p.pts.length; i++) d += `H${X(p.pts[i].date)}V${Y(p.pts[i].bal)}`;
  d += `H${X(p.end)}`;
  svgEl("path", { class: "wash", d: `${d}V${Y(0)}H${X(p.today)}Z` }, svg);
  const path = svgEl("path", { class: "line" + (animate && !calm() ? " draw" : ""), d }, svg);
  if (p.pts.length <= 80) {
    p.pts.slice(1).forEach((q) => svgEl("circle", { class: "dot" + (q.bal < 0 ? " neg" : ""), cx: X(q.date), cy: Y(q.bal), r: 4 }, svg));
  }
  const endLabel = svgEl("text", { class: "endlabel", x: W - m.r, y: Y(p.endBal) - 8, "text-anchor": "end" }, svg);
  endLabel.textContent = fmt(p.endBal);
  const xhair = svgEl("line", { class: "xhair", y1: m.t, y2: H - m.b, visibility: "hidden" }, svg);

  const tip = mk("div", "tip");
  tip.hidden = true;
  box.replaceChildren(svg, tip);
  path.style.setProperty("--len", path.getTotalLength());

  let idx = -1;
  const show = (i) => {
    idx = Math.max(0, Math.min(p.pts.length - 1, i));
    const q = p.pts[idx];
    const x = X(q.date);
    xhair.setAttribute("x1", x); xhair.setAttribute("x2", x); xhair.setAttribute("visibility", "visible");
    tip.replaceChildren(mk("b", q.bal < 0 ? "neg" : "", fmt(q.bal)), mk("span", null, idx === 0 ? "Today" : dayFmt.format(asDate(q.date))));
    for (const e of q.events) tip.append(mk("span", null, `${e.label} ${signed(e.amount)}`));
    tip.hidden = false;
    const sx = svg.getBoundingClientRect().width / W;
    const left = 8 + x * sx, top = 10 + Y(q.bal) * sx;
    const tw = tip.offsetWidth, th = tip.offsetHeight;
    tip.style.transform = `translate(${Math.min(Math.max(left - tw / 2, 4), box.clientWidth - tw - 4)}px, ${Math.max(top - th - 12, -th + 8)}px)`;
  };
  const hide = () => { tip.hidden = true; xhair.setAttribute("visibility", "hidden"); };
  svg.addEventListener("pointermove", (e) => {
    const r = svg.getBoundingClientRect();
    const x = ((e.clientX - r.left) / r.width) * W;
    let best = 0;
    p.pts.forEach((q, i) => { if (Math.abs(X(q.date) - x) < Math.abs(X(p.pts[best].date) - x)) best = i; });
    show(best);
  });
  svg.addEventListener("pointerleave", hide);
  svg.addEventListener("blur", hide);
  svg.addEventListener("keydown", (e) => {
    if (e.key === "ArrowRight" || e.key === "ArrowLeft") { e.preventDefault(); show(idx + (e.key === "ArrowRight" ? 1 : -1)); }
    if (e.key === "Escape") hide();
  });
}

// ---------- rendering ----------
function row({ id, title, iconName, hue, amount, noteLeft, noteRight, noteRightNeg, onClick, active, isFresh, tag, tagCls, cls }) {
  const r = mk(onClick ? "button" : "div", "tx" + (active ? " editing" : "") + (isFresh ? " fresh" : "") + (cls ? " " + cls : ""));
  if (id) r.dataset.id = id;
  if (onClick) { r.type = "button"; r.addEventListener("click", onClick); }
  const ico = mk("span", "ico");
  ico.dataset.hue = hue || "gray";
  ico.innerHTML = icon(iconName);
  const what = mk("span", "what", title);
  if (tag) what.append(mk("span", "tag" + (tagCls ? " " + tagCls : ""), tag));
  r.append(ico, what, mk("span", "amt num" + (amount > 0 ? " pos" : ""), signed(amount)));
  if (noteLeft != null || noteRight != null) {
    r.append(mk("span", "note", noteLeft || ""), mk("span", "note right num" + (noteRightNeg ? " neg" : ""), noteRight || ""));
  }
  return r;
}

function render() {
  if (!loaded) return;
  const total = txs.reduce((s, t) => s + Number(t.amount), 0);
  document.title = `${fmt(total)} · Pocket`;

  const month = todayISO().slice(0, 7);
  const monthTx = txs.filter((t) => t.occurred_on.startsWith(month) && t.category !== "start");
  const spent = monthTx.filter((t) => t.amount < 0).reduce((s, t) => s - Number(t.amount), 0);
  const got = monthTx.filter((t) => t.amount > 0).reduce((s, t) => s + Number(t.amount), 0);
  $("sub").textContent = `This month: ${fmt(spent)} spent` + (got ? ` · ${fmt(got)} in` : "");

  proj = project(total);
  const rw = runway(proj);
  const rEl = $("runway");
  rEl.hidden = !upcoming.length && proj.start >= 0;
  rEl.className = "runway num" + (rw.warn ? " warn" : "");
  rEl.innerHTML = icon(rw.warn ? "down" : "trend");
  rEl.append(`${rw.lead} `, mk("b", null, rw.strong));

  renderQuick();
  renderWaiting();
  renderHistory();
  renderPlan();
  renderSubscriptions();
  renderInsights();
  fresh = { tx: new Set(), rules: new Set() }; // play each arrival once
}

function renderQuick() {
  const box = $("quick");
  box.textContent = "";
  presets.forEach((p, i) => {
    const b = mk("button", "qchip" + (p.sign > 0 ? " in" : ""));
    b.type = "button";
    const qi = mk("span", "qi");
    qi.dataset.hue = catHue(p.category, p.sign);
    qi.innerHTML = icon(catIcon(p.category, p.sign));
    b.append(qi, mk("span", null, p.label));
    if (p.amount != null) b.append(mk("span", "qa", (p.sign > 0 ? "+" : "") + fmt(p.amount)));
    if (i < 9) b.append(mk("kbd", null, String(i + 1)));
    b.setAttribute("aria-label", p.amount != null
      ? `Add ${p.label}, ${signed(p.sign * p.amount)}`
      : `Start a ${p.sign > 0 ? "money in" : "spending"} entry for ${p.label}`);
    b.addEventListener("click", () => usePreset(p, b));
    box.append(b);
  });
}

function occKey(u) { return u.recurring_id + "@" + u.due_on; }

// A planned payment row. The next one of each repeating payment can be marked
// "Got it" (with the real amount and date) or skipped.
function occRow(u, { actionable, balanceAfter, startOpen = false }) {
  const wrap = mk("div", "occ");
  const amt = Number(u.amount);
  const k = occKey(u);
  const due = dayFmt.format(asDate(u.due_on));
  const rowEl = row({
    title: u.label,
    iconName: u.overdue ? "clock" : catIcon(u.category, amt),
    hue: u.overdue ? "orange" : catHue(u.category, amt),
    amount: amt,
    tag: u.overdue ? "waiting" : null, tagCls: "due",
    noteLeft: u.overdue ? `Was due ${due}` : due,
    noteRight: balanceAfter != null ? `then ${fmt(balanceAfter)}` : "",
    noteRightNeg: balanceAfter < 0,
    onClick: actionable ? () => {
      const open = !panel.classList.contains("open");
      setOpen(panel, open);
      if (open) openOcc.add(k); else openOcc.delete(k);
    } : null,
  });
  wrap.append(rowEl);
  if (!actionable) return wrap;

  const panel = mk("div", "reveal");
  const inner = mk("div");
  const body = mk("div", "occ-in");
  const aWrap = mk("div"), dWrap = mk("div");
  const aIn = mk("input"); aIn.className = "num"; aIn.inputMode = "decimal"; aIn.value = Math.abs(amt).toFixed(2); aIn.setAttribute("aria-label", "Amount");
  const dIn = mk("input"); dIn.type = "date"; dIn.value = todayISO(); dIn.setAttribute("aria-label", "Date it happened");
  aWrap.append(mk("label", "cap", "Amount"), aIn);
  dWrap.append(mk("label", "cap", amt > 0 ? "Arrived on" : "Paid on"), dIn);
  const acts = mk("div", "acts");
  const got = mk("button", "btn", amt > 0 ? "Got it" : "Paid"); got.type = "button";
  const skip = mk("button", "btn ghost", "Skip this one"); skip.type = "button";
  acts.append(got, skip);
  body.append(aWrap, dWrap, acts);
  inner.append(body);
  panel.append(inner);
  wrap.append(panel);
  setOpen(panel, startOpen || openOcc.has(k));

  got.addEventListener("click", async () => {
    const n = parseAmount(aIn.value);
    if (!n) { aIn.focus(); return; }
    got.disabled = skip.disabled = true;
    try {
      pendingFlight = { amount: Math.sign(amt) * n, from: got.getBoundingClientRect(), scheduled: false };
      await rpc("pocket_recurring_settle", { p_id: u.recurring_id, p_amount: Math.sign(amt) * n, p_on: dIn.value || todayISO(), p_today: todayISO() });
      openOcc.delete(k);
      await load({ quiet: true });
      if (n !== Math.abs(amt)) toast(`Logged ${u.label} at ${fmt(n)} this time. The plan stays at ${fmt(Math.abs(amt))}.`);
    } catch (e) {
      pendingFlight = null;
      if (e.badKey) return lock("This device was removed or its access changed. Pair it again.");
      toast("Couldn't save that. Check your connection.");
      got.disabled = skip.disabled = false;
    }
  });
  skip.addEventListener("click", async () => {
    got.disabled = skip.disabled = true;
    try {
      await rpc("pocket_recurring_skip", { p_id: u.recurring_id });
      openOcc.delete(k);
      face("oof", 900);
      await load({ quiet: true });
      toast(`Skipped ${u.label} on ${shortFmt.format(asDate(u.due_on))}`);
    } catch {
      toast("Couldn't skip it. Check your connection.");
      got.disabled = skip.disabled = false;
    }
  });
  return wrap;
}

function renderWaiting() {
  const overdue = upcoming.filter((u) => u.overdue);
  const firsts = new Set();
  const box = $("waiting");
  box.textContent = "";
  $("waitingSec").hidden = !overdue.length;
  for (const u of overdue) {
    const first = !firsts.has(u.recurring_id);
    firsts.add(u.recurring_id);
    box.append(occRow(u, { actionable: first, startOpen: first }));
  }
  const tabBtn = $("tab-activity");
  tabBtn.textContent = "Activity";
  if (overdue.length) tabBtn.append(mk("span", "count", String(overdue.length)));
}

function renderHistory() {
  // txs arrive newest first; walk oldest -> newest to get the balance after each entry
  const after = new Map();
  let run = 0;
  for (let i = txs.length - 1; i >= 0; i--) {
    run += Number(txs[i].amount);
    after.set(txs[i].id, run);
  }
  const slot = $("filterSlot");
  slot.textContent = "";
  let shown = txs;
  if (filter) {
    shown = txs.filter((t) => (t.category || "other") === filter.cat && (!filter.month || t.occurred_on.startsWith(filter.month)));
    const chip = mk("span", "filter", `${catName(filter.cat)} · ${filter.month ? monthOnly.format(monthDate(filter.month)) : "all time"}`);
    const x = mk("button");
    x.type = "button";
    x.setAttribute("aria-label", "Show everything");
    x.innerHTML = icon("x");
    x.addEventListener("click", () => { filter = null; renderHistory(); });
    chip.append(x);
    slot.append(chip);
  }
  const list = $("list");
  list.textContent = "";
  if (!shown.length) {
    list.append(mk("p", "empty", filter ? "Nothing here for that filter." : "Nothing here yet. Add your first entry above."));
    return;
  }
  const groups = new Map();
  for (const t of shown) {
    if (!groups.has(t.occurred_on)) groups.set(t.occurred_on, []);
    groups.get(t.occurred_on).push(t);
  }
  for (const [day, items] of groups) {
    const sec = mk("div", "day");
    const net = Math.round(items.reduce((s, t) => s + Number(t.amount), 0) * 100) / 100;
    const head = mk("div", "day-head");
    head.append(mk("h3", "", day === todayISO() ? "Today" : day === addDays(todayISO(), -1) ? "Yesterday" : dayFmt.format(asDate(day))),
                mk("span", "day-net num" + (net > 0 ? " pos" : ""), signed(net)));
    sec.append(head);
    const rows = mk("div", "rows");
    for (const t of items) {
      const amt = Number(t.amount), v = after.get(t.id);
      rows.append(row({
        id: t.id,
        title: t.label,
        iconName: catIcon(t.category, amt),
        hue: catHue(t.category, amt),
        amount: amt,
        noteLeft: (t.category ? catName(t.category) : "") + (t.recurring_id ? (t.category ? " · " : "") + "Automatic" : ""),
        noteRight: `left ${fmt(v)}`,
        noteRightNeg: v < 0,
        active: editing?.kind === "tx" && editing.id === t.id,
        isFresh: fresh.tx.has(t.id),
        onClick: () => startEditTx(t),
      }));
    }
    sec.append(rows);
    list.append(sec);
  }
}

function renderPlan() {
  const p = proj;
  const rw = runway(p);
  $("planTitle").textContent = `${rw.lead} ${rw.strong}`;
  $("planTitle").className = "plan-title" + (rw.warn ? " warn" : "");
  const d = (iso) => shortFmt.format(asDate(iso));
  $("planSub").textContent = `On ${d(p.end)}: ${fmt(p.endBal)}` + (p.low.bal < p.start ? ` · lowest ${fmt(p.low.bal)} on ${d(p.low.date)}` : "");
  document.querySelectorAll("[data-range]").forEach((b) => b.setAttribute("aria-pressed", String(Number(b.dataset.range) === range)));
  $("chart").classList.remove("loading");
  renderChart();

  // Coming up, with the balance after each payment (the chart's table view)
  const box = $("upcoming");
  box.textContent = "";
  const future = p.ev.filter((e) => !e.overdue);
  $("upcomingSec").hidden = !future.length;
  $("upcomingMeta").textContent = `Next ${RANGE_NAME[range]}`;
  const firsts = new Set(upcoming.filter((u) => u.overdue).map((u) => u.recurring_id));
  const limit = showAllUpcoming ? future.length : 8;
  future.slice(0, limit).forEach((e) => {
    const u = upcoming.find((x) => x.recurring_id === e.id && x.due_on === e.date);
    const first = !firsts.has(e.id);
    firsts.add(e.id);
    box.append(occRow(u, { actionable: first, balanceAfter: e.after }));
  });
  if (future.length > 8) {
    const more = mk("button", "more", showAllUpcoming ? "Show less" : `Show all ${future.length}`);
    more.type = "button";
    more.addEventListener("click", () => { showAllUpcoming = !showAllUpcoming; renderPlan(); });
    box.append(more);
  }

  const rbox = $("rules");
  rbox.textContent = "";
  $("rulesSec").hidden = !rules.length;
  $("planEmpty").hidden = !!rules.length;
  let outM = 0, inM = 0;
  for (const r of rules) {
    const amt = Number(r.amount);
    const m = r.once || !r.active ? 0 : Math.abs(amt) * CADENCE[r.cadence].perMonth;
    if (amt < 0) outM += m; else inM += m;
    const when = r.once ? `One time · ${dayFmt.format(asDate(r.next_on))}`
      : `${CADENCE[r.cadence].name} · next ${shortFmt.format(asDate(r.next_on))}` +
        (r.remaining != null ? ` · ${r.remaining === 1 ? "last one" : r.remaining + " left"}` : "");
    rbox.append(row({
      id: r.id,
      title: r.label,
      iconName: r.once ? "clock" : catIcon(r.category, amt) === "in" || !r.category ? "repeat" : catIcon(r.category, amt),
      hue: catHue(r.category, amt),
      amount: amt,
      tag: !r.active ? "paused" : !r.auto ? "you confirm" : null,
      cls: r.active ? "" : "paused",
      noteLeft: when,
      noteRight: r.once ? "expected" : `per ${CADENCE[r.cadence].unit}`,
      active: editing?.kind === "rule" && editing.id === r.id,
      isFresh: fresh.rules.has(r.id),
      onClick: () => startEditRule(r),
    }));
  }
  const whole = (n) => fmt(Math.round(n)).replace(/\.00$/, "");
  const parts = [];
  if (outM) parts.push(`${whole(outM)} out`);
  if (inM) parts.push(`${whole(inM)} in`);
  $("rulesMeta").textContent = parts.length ? `≈ ${parts.join(" · ")} a month` : "";
}

function renderSubscriptions() {
  const summary = PocketSubscriptions.summarize(rules, upcoming, todayISO(), addDays(todayISO(), subscriptionDays));
  $("subscriptionCount").textContent = `${summary.active.length} active` + (summary.paused.length ? ` · ${summary.paused.length} paused` : "");
  const stats = $("subscriptionStats");
  stats.replaceChildren();
  for (const [title, cents] of [["Per month", summary.monthly], ["Per year", summary.annual], [`Next ${subscriptionDays} days`, summary.upcomingTotal]]) {
    const box = mk("div", "stat");
    box.append(mk("div", "k", title), mk("div", "v num", fmt(cents / 100)));
    stats.append(box);
  }
  const active = $("subscriptionList"), paused = $("pausedSubscriptions"), other = $("otherSubscriptions");
  active.replaceChildren(); paused.replaceChildren(); other.replaceChildren();
  $("subscriptionEmpty").hidden = !!summary.active.length;
  $("pausedSubscriptionsSection").hidden = !summary.paused.length;
  $("otherSubscriptionsSection").hidden = !summary.other.length;
  for (const rule of [...summary.active, ...summary.paused]) {
    const item = mk("div", "subscription-item");
    item.append(row({ title: rule.label, iconName: catIcon(rule.category, -1), hue: catHue(rule.category, -1),
      amount: Number(rule.amount), tag: rule.active ? null : "paused", cls: rule.active ? "" : "paused",
      noteLeft: `${CADENCE[rule.cadence].name} · ${rule.active ? "next" : "was due"} ${shortFmt.format(asDate(rule.next_on))}`,
      noteRight: `per ${CADENCE[rule.cadence].unit}`, onClick: () => startEditRule(rule) }));
    const actions = mk("div", "subscription-actions");
    const pause = mk("button", "btn ghost", rule.active ? "Pause tracking" : "Resume tracking");
    pause.type = "button"; pause.setAttribute("aria-label", `${rule.active ? "Pause" : "Resume"} tracking ${rule.label}`);
    pause.addEventListener("click", async () => {
      pause.disabled = true;
      try {
        await rpc("pocket_recurring_set_active", { p_id: rule.id, p_active: !rule.active, p_today: todayISO() });
        $("subscriptionMessage").textContent = "";
        await load({ quiet: true });
      } catch { $("subscriptionMessage").textContent = "Couldn't change tracking. Check your connection and try again."; }
      finally { pause.disabled = false; }
    });
    const remove = mk("button", "btn ghost", "Remove from list");
    remove.type = "button"; remove.setAttribute("aria-label", `Remove ${rule.label} from Subscriptions`);
    remove.addEventListener("click", () => changeSubscription(rule, false, remove));
    actions.append(pause, remove); item.append(actions);
    (rule.active ? active : paused).append(item);
  }
  for (const rule of summary.other) {
    const item = mk("div", "subscription-item");
    item.append(row({ title: rule.label, iconName: catIcon(rule.category, -1), hue: catHue(rule.category, -1),
      amount: Number(rule.amount), noteLeft: CADENCE[rule.cadence].name, onClick: () => startEditRule(rule) }));
    const actions = mk("div", "subscription-actions"), include = mk("button", "btn ghost", "Include in Subscriptions");
    include.type = "button"; include.setAttribute("aria-label", `Include ${rule.label} in Subscriptions`);
    include.addEventListener("click", () => changeSubscription(rule, true, include));
    actions.append(include); item.append(actions); other.append(item);
  }
  const renewals = $("subscriptionRenewals"); renewals.replaceChildren();
  for (const renewal of summary.renewals) {
    renewals.append(row({ title: renewal.label, iconName: catIcon(renewal.category, -1), hue: catHue(renewal.category, -1),
      amount: Number(renewal.amount), noteLeft: renewal.due_on === todayISO() ? "Today" : dayFmt.format(asDate(renewal.due_on)),
      onClick: () => { const rule = rules.find((r) => r.id === renewal.recurring_id); if (rule) startEditRule(rule); } }));
  }
  $("subscriptionRenewalsEmpty").hidden = !!summary.renewals.length;
  $("subscriptionRenewalsEmpty").textContent = `No renewals in the next ${subscriptionDays} days.`;
  document.querySelectorAll("[data-subscription-days]").forEach((button) => button.setAttribute("aria-pressed", String(Number(button.dataset.subscriptionDays) === subscriptionDays)));
}

async function changeSubscription(rule, included, button) {
  if (!subscriptionTracking) {
    $("subscriptionMessage").textContent = "This sync server needs the Subscriptions update to change list membership. Existing subscriptions and tracking still work.";
    return;
  }
  button.disabled = true;
  try {
    await rpc("pocket_subscription_set", { p_id: rule.id, p_subscription: included });
    $("subscriptionMessage").textContent = "";
    await load({ quiet: true });
  } catch { $("subscriptionMessage").textContent = "Couldn't update the list. Check your connection and try again."; }
  finally { button.disabled = false; }
}

function monthsWithData() {
  const first = txs.length ? txs[txs.length - 1].occurred_on.slice(0, 7) : todayISO().slice(0, 7);
  return { first, last: todayISO().slice(0, 7) };
}

function renderInsights() {
  const { first, last } = monthsWithData();
  if (insight.month < first) insight.month = first;
  if (insight.month > last) insight.month = last;
  const all = insight.scope === "all";
  const inScope = (t, ym) => t.category !== "start" && (ym ? t.occurred_on.startsWith(ym) : true);
  const sums = (ym) => {
    let spent = 0, inn = 0;
    const by = new Map();
    for (const t of txs) {
      if (!inScope(t, ym)) continue;
      const a = Number(t.amount);
      if (a > 0) { inn += a; continue; }
      spent -= a;
      const c = t.category || "other";
      const cur = by.get(c) || { sum: 0, n: 0 };
      cur.sum -= a; cur.n++;
      by.set(c, cur);
    }
    return { spent, inn, by };
  };
  const now = sums(all ? null : insight.month);

  document.querySelectorAll("[data-scope]").forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.scope === insight.scope)));
  $("monthName").textContent = all ? `Since ${monthFmt.format(monthDate(first))}` : monthFmt.format(monthDate(insight.month));
  $("monthPrev").disabled = all || insight.month <= first;
  $("monthNext").disabled = all || insight.month >= last;

  const net = now.inn - now.spent;
  const stats = $("stats");
  stats.textContent = "";
  for (const [k, v, neg] of [["Spent", fmt(now.spent)], ["Money in", fmt(now.inn)], ["Net", signed(Math.round(net * 100) / 100), net < 0]]) {
    const s = mk("div", "stat");
    s.append(mk("div", "k", k), mk("div", "v num" + (neg ? " neg" : ""), v));
    stats.append(s);
  }

  const delta = $("delta");
  delta.textContent = "";
  if (!all) {
    const prevYm = shiftMonth(insight.month, -1);
    if (prevYm >= first) {
      const prev = sums(prevYm);
      const diff = Math.round((now.spent - prev.spent) * 100) / 100;
      const name = monthOnly.format(monthDate(prevYm));
      delta.innerHTML = icon(diff > 0 ? "trend" : "down");
      delta.append(diff === 0 ? `Same spending as ${name}` : `${fmt(Math.abs(diff))} ${diff > 0 ? "more" : "less"} than ${name} (${fmt(prev.spent)})`);
    }
  }

  const bars = $("bars");
  bars.textContent = "";
  const rows = [...now.by.entries()].sort((a, b) => b[1].sum - a[1].sum);
  if (!rows.length) {
    bars.append(mk("p", "empty", all ? "No spending yet." : `No spending in ${monthOnly.format(monthDate(insight.month))}.`));
    return;
  }
  const max = rows[0][1].sum;
  rows.forEach(([c, v], i) => {
    const b = mk("button", "bar-row");
    b.type = "button";
    const name = mk("span", "bar-name");
    const ico = mk("span", "ico");
    ico.dataset.hue = catHue(c, -1);
    ico.innerHTML = icon(catIcon(c, -1));
    name.append(ico, catName(c));
    const track = mk("span", "bar-track");
    track.dataset.hue = catHue(c, -1);
    const fill = mk("span", "bar-fill");
    fill.style.width = `${Math.max(1.5, (v.sum / max) * 100)}%`;
    fill.style.animationDelay = `${Math.min(i, 8) * 50}ms`;
    track.append(fill);
    const pct = Math.round((v.sum / now.spent) * 100);
    b.append(name, mk("span", "bar-val", fmt(v.sum)), track, mk("span", "bar-meta", `${pct}% of spending · ${v.n} ${v.n === 1 ? "purchase" : "purchases"}`));
    b.setAttribute("aria-label", `${catName(c)}: ${fmt(v.sum)}, ${pct}% of spending. Show these purchases.`);
    b.addEventListener("click", () => {
      filter = { cat: c, month: all ? null : insight.month };
      setTab("activity");
      renderHistory();
      $("panel-activity").scrollIntoView({ behavior: calm() ? "auto" : "smooth", block: "start" });
    });
    bars.append(b);
  });
}

// ---------- tabs ----------
function setTab(name) {
  tab = name;
  ls.set(TAB_STORE, name);
  const names = TAB_NAMES;
  names.forEach((n) => {
    $(`tab-${n}`).setAttribute("aria-selected", String(n === name));
    $(`tab-${n}`).tabIndex = n === name ? 0 : -1;
    $(`panel-${n}`).hidden = n !== name;
  });
  document.querySelector(".tab-ink").style.transform = `translateX(${names.indexOf(name) * 100}%)`;
  if (name === "plan" && chartDirty) renderChart();
}

// ---------- form ----------
function setOpen(el, open) { el.classList.toggle("open", open); el.inert = !open; }

function setSign(s) {
  sign = s;
  document.querySelector(".seg").dataset.sign = String(s);
  document.querySelectorAll(".seg button").forEach((b) => b.setAttribute("aria-pressed", String(Number(b.dataset.sign) === s)));
  renderCats();
  updateFormText();
  updatePreview();
}

function setCadence(c) {
  cadence = c;
  document.querySelectorAll("#chips button").forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.cadence === c)));
  updateFormText();
}

function renderCats() {
  const list = sign > 0 ? IN_CATS : SPEND_CATS;
  if (cat && !list.includes(cat)) cat = null;
  const box = $("cats");
  box.textContent = "";
  for (const c of list) {
    const b = mk("button", "cat");
    b.type = "button";
    b.setAttribute("aria-pressed", String(c === cat));
    b.dataset.hue = CATS[c].hue;
    b.innerHTML = icon(CATS[c].icon);
    b.append(CATS[c].name);
    b.addEventListener("click", () => { cat = cat === c ? null : c; catTouched = true; renderCats(); });
    box.append(b);
  }
  $("subscriptionBox").checked = subscriptionChoice ?? (cat === "subscriptions");
}

// Typing a name you've used before picks its category for you.
function guessCategory() {
  if (catTouched || editing) return;
  const l = $("label").value.trim().toLowerCase();
  if (l.length < 3) return;
  const list = sign > 0 ? IN_CATS : SPEND_CATS;
  const hit = [...presets, ...txs].find((t) => t.category && list.includes(t.category) && t.label.toLowerCase().startsWith(l));
  if (hit && hit.category !== cat) { cat = hit.category; renderCats(); }
}

// While you type, the pocket reacts: starry-eyed for money coming in,
// nervous when a purchase is bigger than what's left.
function updatePreview() {
  const a = parseAmount($("amount").value);
  let p = null;
  if (a && editing?.kind !== "tx") {
    if (sign > 0) p = "hope";
    else if (shownBalance !== null && a > Math.max(shownBalance, 0)) p = "worried";
  }
  if (p !== pk.preview) { pk.preview = p; applyFace(); }
}

function setDetails(open) {
  setOpen($("details"), open);
  $("detailsBtn").setAttribute("aria-expanded", String(open));
}

function updateFormText() {
  const repeating = cadence !== "once";
  const editingRule = editing?.kind === "rule";
  const date = $("date").value || todayISO();
  const future = !repeating && date > todayISO();
  $("timesRow").hidden = !(repeating && editing?.kind !== "tx");
  const when = date === todayISO() ? "Today" : date === addDays(todayISO(), -1) ? "Yesterday" : shortFmt.format(asDate(date));
  $("detailsSummary").textContent = `${when} · ${repeating ? CADENCE[cadence].name : "Once"}`;
  $("timesCap").textContent = editingRule ? "Payments left (including the next one)" : "How many payments?";
  $("label").placeholder = repeating
    ? (sign < 0 ? "e.g. Netflix, rent" : "e.g. Paycheck")
    : (sign < 0 ? "What was it?" : "Where's it from?");
  $("dateCap").textContent = editingRule ? (repeating ? "Next payment" : "Expected on") : repeating ? (sign < 0 ? "First payment" : "First payday") : "Date";

  const planned = (repeating || future) && editing?.kind !== "tx";
  $("confirmRow").hidden = !planned;
  if (planned && !confirmTouched && !editingRule) $("confirmBox").checked = sign > 0;
  $("presetRow").hidden = !!editing || repeating || future;
  $("subscriptionRow").hidden = !(repeating && sign < 0 && editing?.kind !== "tx");
  $("subscriptionBox").checked = subscriptionChoice ?? (cat === "subscriptions");

  let hint = "";
  if (repeating && !editing) {
    hint = $("confirmBox").checked
      ? `Each ${CADENCE[cadence].unit} it waits in Activity until you tap “Got it”, so you can log the real amount.`
      : `Counts automatically every ${CADENCE[cadence].unit}, starting on this date.`;
  } else if (future && editing?.kind !== "tx") {
    hint = `Shows in Plan until ${dayFmt.format(asDate($("date").value))}` +
      ($("confirmBox").checked ? `, then waits for you to confirm it.` : `, then counts automatically.`);
  }
  if (hint) $("hint").textContent = hint;
  setOpen($("hintWrap"), !!hint);
  if (!editing) {
    $("formTitle").textContent = repeating
      ? (sign < 0 ? "New subscription or bill" : "New repeating income")
      : future ? (sign < 0 ? "Planned payment" : "Expected money") : "New entry";
  }
}

function enterEdit(title, deleteLabel) {
  $("formTitle").textContent = title;
  $("submitBtn").textContent = "Save";
  setDetails(editing?.kind === "rule" || $("date").value !== todayISO());
  $("deleteBtn").textContent = deleteLabel;
  setOpen($("editActions"), true);
  $("txForm").classList.add("is-editing");
  $("formMsg").textContent = "";
  renderCats();
  updateFormText();
  updatePreview();
  render();
  $("txForm").scrollIntoView({ behavior: calm() ? "auto" : "smooth", block: "center" });
}

function startEditTx(t) {
  subscriptionChoice = null;
  editing = { kind: "tx", id: t.id };
  const amt = Number(t.amount);
  cat = t.category === "start" ? null : t.category;
  setSign(amt < 0 ? -1 : 1);
  cat = t.category === "start" ? null : t.category;
  setCadence("once");
  $("chips").hidden = true;
  $("pauseBtn").hidden = true;
  $("amount").value = Math.abs(amt).toFixed(2);
  $("label").value = t.label;
  $("date").value = t.occurred_on;
  enterEdit("Edit entry", "Delete");
}

function startEditRule(r) {
  subscriptionChoice = r.subscription ?? null;
  editing = { kind: "rule", id: r.id };
  const amt = Number(r.amount);
  cat = r.category;
  setSign(amt < 0 ? -1 : 1);
  cat = r.category;
  $("chips").hidden = false;
  setCadence(r.once ? "once" : r.cadence);
  $("times").value = r.once || r.remaining == null ? "" : r.remaining;
  $("confirmBox").checked = !r.auto;
  $("pauseBtn").hidden = !!r.once;
  $("pauseBtn").textContent = r.active ? "Pause" : "Resume";
  $("amount").value = Math.abs(amt).toFixed(2);
  $("label").value = r.label;
  $("date").value = r.next_on;
  enterEdit(r.once ? "Edit expected payment" : "Edit repeating", r.once ? "Remove" : "Stop");
}

function resetForm() {
  editing = null;
  subscriptionChoice = null;
  $("txForm").reset();
  $("txForm").classList.remove("is-editing");
  $("chips").hidden = false;
  $("pauseBtn").hidden = true;
  cat = null; catTouched = false; confirmTouched = false;
  setSign(-1);
  setCadence("once");
  $("date").value = todayISO();
  if (!$("submitBtn").dataset.busy) $("submitBtn").textContent = "Add";
  setOpen($("editActions"), false);
  setDetails(false);
  $("formMsg").textContent = "";
  updateFormText();
  updatePreview();
  render();
}

function parseAmount(raw) {
  const n = Number(String(raw).replace(/[$\s]/g, "").replace(",", "."));
  return Number.isFinite(n) && n !== 0 ? Math.round(Math.abs(n) * 100) / 100 : null;
}

function formError(msg, field) {
  $("formMsg").textContent = msg;
  field?.focus();
  const card = $("txForm");
  card.classList.remove("shake");
  void card.offsetWidth;
  card.classList.add("shake");
  face("oof", 900);
}

function flashDone(btn) {
  btn.dataset.busy = "1";
  btn.style.minWidth = btn.offsetWidth + "px";
  btn.innerHTML = icon("check", "check-draw");
  btn.setAttribute("aria-label", "Saved");
  setTimeout(() => {
    delete btn.dataset.busy;
    btn.style.minWidth = "";
    btn.removeAttribute("aria-label");
    btn.textContent = editing ? "Save" : "Add";
  }, 950);
}

async function onSubmit(e) {
  e.preventDefault();
  const amount = parseAmount($("amount").value);
  const label = $("label").value.trim();
  const date = $("date").value || todayISO();
  if (!amount) return formError("Enter an amount, like 9.99", $("amount"));
  if (!label) return formError("Say what it was", $("label"));
  const timesRaw = $("times").value.trim();
  const times = timesRaw === "" ? null : Number(timesRaw);
  if (cadence !== "once" && times !== null && !(Number.isInteger(times) && times >= 1)) {
    return formError("Payments must be a whole number, like 3", $("times"));
  }
  const btn = $("submitBtn");
  const from = btn.getBoundingClientRect();
  btn.disabled = true;
  try {
    const today = todayISO();
    // A one-time entry dated in the future is stored as a rule with a single payment,
    // so it only counts once its day arrives.
    const once = cadence === "once";
    const planned = !once || date > today;
    const auto = !$("confirmBox").checked;
    const saveAsPreset = !editing && !planned && $("presetBox").checked;
    const choice = sign < 0 && !once ? subscriptionChoice : subscriptionChoice == null ? null : false;
    const membership = PocketSubscriptions.membershipArgs(choice, subscriptionTracking);
    let res = null;
    if (editing?.kind === "rule") {
      await rpc("pocket_recurring_update", {
        p_id: editing.id, p_amount: sign * amount, p_label: label, p_cadence: once ? "monthly" : cadence, p_next: date,
        p_today: today, p_left: once ? 1 : times, p_category: cat || "", p_auto: auto, ...membership,
      });
    } else if (editing?.kind === "tx") {
      await rpc("pocket_update", { p_id: editing.id, p_amount: sign * amount, p_label: label, p_on: date, p_category: cat || "" });
    } else if (planned) {
      res = await rpcAdd("pocket_recurring_add", {
        p_amount: sign * amount, p_label: label, p_cadence: once ? "monthly" : cadence, p_start: date,
        p_today: today, p_times: once ? 1 : times, p_category: cat, p_auto: auto, ...membership,
      });
    } else {
      res = await rpcAdd("pocket_add", { p_amount: sign * amount, p_label: label, p_on: date, p_category: cat });
    }
    if (saveAsPreset) {
      await rpcAdd("pocket_preset_save", { p_label: label, p_sign: sign, p_amount: amount, p_category: cat });
    }
    if (res?.queued) {
      resetForm();
      face("hope", 1500);
      toast("You're offline. Saved here, and it'll sync when you're back.");
      setSync("off", `${readQueue().length} waiting to sync`);
      return;
    }
    if (!editing) pendingFlight = { amount: sign * amount, from, scheduled: planned };
    resetForm();
    flashDone(btn);
    await load({ quiet: true });
    if (saveAsPreset) toast(`"${label}" is now a quick-add button`);
    $("amount").focus({ preventScroll: true });
  } catch (err) {
    pendingFlight = null;
    if (err.badKey) return lock("This device was removed or its access changed. Pair it again.");
    formError(err.message?.includes("Subscriptions update") ? err.message : "Couldn't save. Check your connection and try again.");
  } finally {
    btn.disabled = false;
  }
}

async function collapseRow(node) {
  if (!node || calm()) return;
  await node.animate([{ opacity: 1, transform: "translateX(0)" }, { opacity: 0, transform: "translateX(-24px)" }],
    { duration: 180, easing: "ease-in", fill: "forwards" }).finished;
  await node.animate([{ height: node.offsetHeight + "px" }, { height: "0px", paddingTop: "0px", paddingBottom: "0px" }],
    { duration: 220, easing: EASE_OUT, fill: "forwards" }).finished;
}

async function onDelete() {
  if (!editing) return;
  const isRule = editing.kind === "rule";
  const item = (isRule ? rules : txs).find((x) => x.id === editing.id);
  const question = isRule
    ? (item?.once ? `Remove expected “${item?.label}”?` : `Stop “${item?.label}”? Payments already logged stay in your history.`)
    : `Delete “${item?.label}” (${fmt(Number(item?.amount))})?`;
  if (!confirm(question)) return;
  try {
    await rpc(isRule ? "pocket_recurring_delete" : "pocket_delete", { p_id: editing.id });
    await collapseRow(document.querySelector(`${isRule ? "#rules" : "#list"} [data-id="${editing.id}"]`));
    if (isRule) { face("oof", 1000); say("Poof!"); } else pendingReason = "delete";
    resetForm();
    await load({ quiet: true });
  } catch {
    formError("Couldn't do that. Try again.");
  }
}

async function onPause() {
  const r = rules.find((x) => x.id === editing?.id);
  if (!r) return;
  try {
    await rpc("pocket_recurring_set_active", { p_id: r.id, p_active: !r.active, p_today: todayISO() });
    face(r.active ? "sleep" : "joy", 1400);
    say(r.active ? "Taking a nap" : "Back at it!");
    toast(r.active ? `Paused ${r.label}. Nothing is logged until you resume it.` : `Resumed ${r.label}. It picks up from the next date, without the missed ones.`);
    resetForm();
    await load({ quiet: true });
  } catch {
    formError("Couldn't do that. Try again.");
  }
}

// ---------- quick add ----------
async function usePreset(p, chip) {
  if (p.amount == null) {
    // Different price every time: fill the form and ask for the amount.
    resetForm();
    setSign(p.sign);
    cat = p.category; catTouched = true; renderCats();
    $("label").value = p.label;
    $("amount").focus({ preventScroll: true });
    $("txForm").scrollIntoView({ behavior: calm() ? "auto" : "smooth", block: "center" });
    face("hope", 1200);
    say("How much?");
    return;
  }
  const amount = p.sign * Number(p.amount);
  chip.disabled = true;
  try {
    const res = await rpcAdd("pocket_add", { p_amount: amount, p_label: p.label, p_on: todayISO(), p_category: p.category });
    if (res?.queued) {
      toast(`You're offline. ${p.label} is saved here and will sync later.`);
      setSync("off", `${readQueue().length} waiting to sync`);
      return;
    }
    pendingFlight = { amount, from: chip.getBoundingClientRect(), scheduled: false };
    await load({ quiet: true });
    toast(`Added ${p.label} ${signed(amount)}`, "Undo", async () => {
      try {
        pendingReason = "undo";
        await rpc("pocket_delete", { p_id: res.id });
        await load({ quiet: true });
      } catch { toast("Couldn't undo. Delete it from History."); }
    });
  } catch (e) {
    if (e.badKey) return lock("This device was removed or its access changed. Pair it again.");
    toast("Couldn't add that. Check your connection.");
  } finally {
    chip.disabled = false;
  }
}

// ---------- toast ----------
let toastTimer = 0;
function toast(msg, actionLabel, onAction, ms = 5200) {
  $("toastMsg").textContent = msg;
  const b = $("toastBtn");
  b.textContent = actionLabel || "";
  b.onclick = actionLabel ? () => { hideToast(); onAction(); } : null;
  $("toast").classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(hideToast, ms);
}
function hideToast() { $("toast").classList.remove("show"); }

// ---------- loading skeletons ----------
function skelRows(n) {
  const f = document.createDocumentFragment();
  for (let i = 0; i < n; i++) {
    const r = mk("div", "skel-row");
    r.setAttribute("aria-hidden", "true");
    r.append(mk("span", "skel c"), mk("span", "skel l1"), mk("span", "skel a"), mk("span", "skel l2"));
    f.append(r);
  }
  return f;
}

// Shown until the first sync answers, so the page has its shape instead of looking empty.
function renderSkeleton() {
  $("home").setAttribute("aria-busy", "true");
  $("balance").replaceChildren(mk("span", "skel"));
  $("balance").setAttribute("aria-label", "Loading your balance");
  $("sub").replaceChildren(mk("span", "skel"));
  $("runway").hidden = true;
  $("quick").textContent = "";
  const rows = mk("div", "rows");
  rows.append(skelRows(4));
  $("list").replaceChildren(rows);
  $("chart").replaceChildren(mk("span", "skel"));
  $("bars").replaceChildren(skelRows(3));
  $("stats").textContent = "";
}

// ---------- settings: devices, pairing, quick-add buttons ----------
function deviceIcon(name) { return /iphone|android|phone|ipad/i.test(name) ? "phone" : "laptop"; }
function ago(iso) {
  const s = (Date.now() - new Date(iso).getTime()) / 1000;
  if (s < 90) return "active now";
  if (s < 3600) return `${Math.round(s / 60)} min ago`;
  if (s < 86400) return `${Math.round(s / 3600)} h ago`;
  return `${Math.round(s / 86400)} days ago`;
}

async function loadDevices({ quiet = false } = {}) {
  const box = $("devices");
  if (!quiet) box.replaceChildren(skelRows(2));
  try {
    const d = await rpc("pocket_devices");
    box.textContent = "";
    if (d.master) {
      const r = mk("div", "dev-row");
      const ico = mk("span", "ico"); ico.innerHTML = icon("lock");
      r.append(ico, mk("span", "what", "This device (main key)"), mk("span"), mk("span", "note", "Set up with the main key. It can't be removed here."));
      box.append(r);
    }
    for (const dev of d.devices) {
      const r = mk("div", "dev-row");
      const ico = mk("span", "ico"); ico.innerHTML = icon(deviceIcon(dev.name));
      const name = mk("span", "what", dev.name);
      if (dev.this) name.append(mk("span", "tag", "this device"));
      const rm = mk("button", "icon-btn");
      rm.type = "button";
      rm.innerHTML = icon("x");
      rm.setAttribute("aria-label", `Remove ${dev.name}`);
      rm.addEventListener("click", () => confirmRemove(r, rm, dev));
      r.append(ico, name, rm, mk("span", "note", `Added ${shortFmt.format(new Date(dev.created_at))} · ${ago(dev.last_seen)}`));
      box.append(r);
    }
    if (!d.master && !d.devices.length) box.append(mk("p", "empty", "No devices yet."));
    return d.devices.length;
  } catch {
    box.replaceChildren(mk("p", "empty", "Couldn't load devices. Check your connection."));
    return null;
  }
}

async function startPairing() {
  const btn = $("pairStart");
  btn.disabled = true;
  btn.replaceChildren(mk("span", "spin"), " Making a code…");
  const restore = () => { btn.textContent = "Make a new code"; };
  try {
    const before = await loadDevices({ quiet: true });
    const { code, expires_at } = await rpc("pocket_pair_start");
    restore();
    $("pairBox").hidden = false;
    $("pairShow").textContent = `${code.slice(0, 3)} ${code.slice(3)}`;
    const end = new Date(expires_at).getTime();
    const tick = () => {
      const left = Math.max(0, Math.round((end - Date.now()) / 1000));
      if (!left) {
        $("pairShow").textContent = "Expired";
        $("pairNote").textContent = "Make a new code when you're ready.";
        clearInterval(pairTimer); clearInterval(pairWatch);
        btn.disabled = false;
        return;
      }
      $("pairNote").textContent = `On the new device, open ${isDefaultServer() ? "pocketleft.app/app" : "Pocket with “Use your own server” set to " + new URL(server.url).host} and type this code. Expires in ${Math.floor(left / 60)}:${String(left % 60).padStart(2, "0")}.`;
    };
    clearInterval(pairTimer); clearInterval(pairWatch);
    tick();
    pairTimer = setInterval(tick, 1000);
    // Notice when the new device shows up.
    pairWatch = setInterval(async () => {
      if (!$("settings").open) { clearInterval(pairWatch); return; }
      const n = await loadDevices({ quiet: true });
      if (n != null && before != null && n > before) {
        clearInterval(pairTimer); clearInterval(pairWatch);
        $("pairShow").textContent = "Paired!";
        $("pairNote").textContent = "The new device is ready.";
        btn.disabled = false;
        face("joy", 1800);
        say(line("paired"));
      }
    }, 3000);
  } catch {
    btn.disabled = false;
    restore();
    $("pairBox").hidden = false;
    $("pairShow").textContent = "";
    $("pairNote").textContent = "Couldn't make a code. Check your connection and try again.";
  }
}

// Removing a device: ask in place, show progress, then say what happened.
function confirmRemove(r, rmBtn, dev) {
  if (r.querySelector(".dev-confirm")) return;
  r.classList.add("confirming");
  rmBtn.hidden = true;
  const box = mk("div", "dev-confirm");
  box.setAttribute("role", "group");
  const msg = mk("p", null, dev.this
    ? "Remove this device? It will lock right away, and you'll need a new pairing code to get back in."
    : `Remove ${dev.name}? It will be locked out right away. You can pair it again later with a new code.`);
  const acts = mk("div", "acts");
  const cancel = mk("button", "btn ghost", "Cancel"); cancel.type = "button";
  const go = mk("button", "btn danger-solid", "Remove"); go.type = "button";
  const err = mk("span", "inline-err");
  err.setAttribute("role", "alert");
  acts.append(cancel, go);
  box.append(msg, acts, err);
  r.append(box);
  go.focus();
  cancel.addEventListener("click", () => {
    box.remove();
    r.classList.remove("confirming");
    rmBtn.hidden = false;
    rmBtn.focus();
  });
  go.addEventListener("click", async () => {
    go.disabled = cancel.disabled = true;
    go.replaceChildren(mk("span", "spin"), " Removing…");
    err.textContent = "";
    try {
      await rpc("pocket_device_remove", { p_id: dev.id });
      if (dev.this) {
        $("settings").close();
        lock("This device was removed. Pair it again with a new code to get back in.");
        return;
      }
      await collapseRow(r);
      r.remove();
      toast(`${dev.name} was removed. It can't open Pocket anymore.`);
      face("oof", 900);
      say("Bye-bye, device");
      loadDevices({ quiet: true });
    } catch {
      go.disabled = cancel.disabled = false;
      go.textContent = "Try again";
      err.textContent = "Couldn't remove it. Check your connection and try again.";
    }
  });
}

function renderPresetList() {
  const box = $("presetList");
  box.textContent = "";
  if (!presets.length) {
    box.append(mk("p", "empty", "No buttons yet. Tick “Also save as a quick-add button” when you add something."));
    return;
  }
  for (const p of presets) {
    const r = mk("div", "preset-row");
    const ic = mk("span"); ic.innerHTML = icon(catIcon(p.category, p.sign));
    const name = mk("input"); name.value = p.label; name.maxLength = 120; name.setAttribute("aria-label", "Button name");
    const amt = mk("input"); amt.className = "num"; amt.inputMode = "decimal"; amt.placeholder = "Ask";
    amt.value = p.amount != null ? Number(p.amount).toFixed(2) : ""; amt.setAttribute("aria-label", "Amount (empty to ask each time)");
    const del = mk("button", "icon-btn"); del.type = "button"; del.innerHTML = icon("x"); del.setAttribute("aria-label", `Delete ${p.label}`);
    const save = async () => {
      const label = name.value.trim();
      if (!label) { name.value = p.label; return; }
      const a = amt.value.trim() === "" ? null : parseAmount(amt.value);
      if (label === p.label && a === (p.amount != null ? Number(p.amount) : null)) return;
      await rpc("pocket_preset_save", { p_id: p.id, p_label: label, p_sign: p.sign, p_amount: a, p_category: p.category || "" });
      await load({ quiet: true });
      renderPresetList();
    };
    name.addEventListener("change", save);
    amt.addEventListener("change", save);
    del.addEventListener("click", async () => {
      await rpc("pocket_preset_delete", { p_id: p.id });
      await load({ quiet: true });
      renderPresetList();
    });
    r.append(ic, name, amt, del);
    box.append(r);
  }
}

function openSettings() {
  $("serverName").textContent = isDefaultServer() ? "Pocket" : new URL(server.url).host;
  $("pairBox").hidden = true;
  $("pairStart").disabled = false;
  $("pairStart").textContent = "Pair a new device";
  renderPresetList();
  loadDevices();
  $("settings").showModal();
}

// ---------- lock / unlock / pair ----------
function deviceName() {
  const ua = navigator.userAgent;
  const os = /iPhone/.test(ua) ? "iPhone" : /iPad/.test(ua) ? "iPad" : /Android/.test(ua) ? "Android phone"
    : /Mac/.test(ua) ? (navigator.maxTouchPoints > 1 ? "iPad" : "Mac") : /Windows/.test(ua) ? "Windows PC" : /Linux/.test(ua) ? "Linux" : "Device";
  const app = matchMedia("(display-mode: standalone)").matches || navigator.standalone;
  const browser = /Edg\//.test(ua) ? "Edge" : /Firefox|FxiOS/.test(ua) ? "Firefox" : /Chrome|CriOS/.test(ua) ? "Chrome" : /Safari/.test(ua) ? "Safari" : "";
  return app ? `${os} (home screen app)` : browser ? `${os} · ${browser}` : os;
}

function startPolling() {
  clearInterval(pollTimer);
  pollTimer = setInterval(() => { if (!document.hidden) load({ quiet: true }); }, POLL_MS);
}

function shake(el) { el.classList.remove("shake"); void el.offsetWidth; el.classList.add("shake"); }

function lock(msg = "") {
  key = null;
  loaded = false; lastSig = ""; shownBalance = null; knownTx = null; knownRules = null;
  ls.del(KEY_STORE);
  clearInterval(pollTimer);
  $("home").hidden = true;
  $("lock").hidden = false;
  $("lockMsg").textContent = msg;
  $("keyInput").value = "";
  $("pairCode").value = "";
  showServer();
  $("pairCode").focus();
  if (msg) shake($("pairForm"));
}

function showServer() {
  $("serverNow").textContent = isDefaultServer() ? "Using the Pocket server." : `Using ${new URL(server.url).host}.`;
  $("serverUrl").value = isDefaultServer() ? "" : server.url;
  $("serverKey").value = isDefaultServer() ? "" : server.key;
  $("serverReset").hidden = isDefaultServer();
}

async function unlock(k) {
  key = k;
  lastSig = "";
  $("lock").hidden = true;
  $("home").hidden = false;
  setTab(tab);
  resetForm();
  if (!loaded) renderSkeleton();
  await load();
  if (key) { ls.set(KEY_STORE, key); startPolling(); }
}

async function onPair(e) {
  e.preventDefault();
  const code = $("pairCode").value.replace(/\D/g, "");
  if (code.length !== 6) { $("lockMsg").textContent = "The code has 6 digits."; shake($("pairForm")); return; }
  const btn = $("pairForm").querySelector("button");
  btn.disabled = true;
  btn.replaceChildren(mk("span", "spin"), " Pairing…");
  $("lockMsg").textContent = "";
  try {
    const res = await rpc("pocket_pair_finish", { p_code: code, p_name: deviceName() }, { noKey: true });
    if (res?.token) { $("lockMsg").textContent = ""; await unlock(res.token); return; }
    $("lockMsg").textContent = {
      wrong: "That code didn't match. Check it and try again.",
      expired: "That code expired or was already used. Make a new one on your Mac.",
      too_many: "Too many tries. Make a new code on your Mac.",
    }[res?.error] || "Couldn't pair. Try again.";
    shake($("pairForm"));
    const sleeper = $("lockPocket").firstChild;
    if (sleeper) { sleeper.dataset.face = "oof"; setTimeout(() => { sleeper.dataset.face = "sleep"; }, 900); }
  } catch {
    $("lockMsg").textContent = "Couldn't reach the server. Check your connection.";
  } finally {
    btn.disabled = false;
    btn.textContent = "Pair";
  }
}

// ---------- keyboard ----------
document.addEventListener("keydown", (e) => {
  if (e.metaKey || e.ctrlKey || e.altKey || $("home").hidden) return;
  if (e.key === "Escape") {
    if (editing && !document.querySelector("dialog[open]")) { resetForm(); e.preventDefault(); }
    return;
  }
  if (e.target.closest?.("input, textarea, select, [contenteditable], dialog[open]") || document.querySelector("dialog[open]")) return;
  const k = e.key.toLowerCase();
  if (k === "n" || k === "/") {
    e.preventDefault();
    $("amount").focus({ preventScroll: true });
    $("txForm").scrollIntoView({ behavior: calm() ? "auto" : "smooth", block: "center" });
  } else if (/^[1-9]$/.test(e.key)) {
    const i = Number(e.key) - 1;
    const chip = $("quick").children[i];
    if (presets[i] && chip) { e.preventDefault(); usePreset(presets[i], chip); }
  } else if (k === "a") setTab("activity");
  else if (k === "p") setTab("plan");
  else if (k === "i") setTab("insights");
  else if (k === "s") openSettings();
  else if (e.key === "?") $("keys").showModal();
});

// ---------- wiring ----------
document.querySelector('.seg [data-sign="-1"]').innerHTML = icon("minus") + "Spent";
document.querySelector('.seg [data-sign="1"]').innerHTML = icon("plus") + "Got money";
$("settingsBtn").innerHTML = icon("gear");
$("monthPrev").innerHTML = icon("chevL");
$("monthNext").innerHTML = icon("chevR");
document.querySelectorAll(".close-sheet").forEach((b) => {
  b.innerHTML = icon("x");
  b.addEventListener("click", () => b.closest("dialog").close());
});
document.querySelectorAll("dialog.sheet").forEach((d) => {
  d.addEventListener("click", (e) => { if (e.target === d) d.close(); }); // tap outside closes
  d.addEventListener("close", () => { clearInterval(pairTimer); clearInterval(pairWatch); });
});

pk.el = makePocket();
$("pocketBtn").append(pk.el);
const sleeper = makePocket("pk-sleep");
sleeper.dataset.face = "sleep";
sleeper.querySelector(".pk-fx").innerHTML = '<div class="zz"><span>z</span><span>z</span><span>z</span></div>';
$("lockPocket").append(sleeper);

$("pocketBtn").addEventListener("click", () => {
  pk.pokes++;
  face("joy", 1100);
  say(line("poke"));
  if (!calm()) {
    part(".coin")?.animate([
      { transform: "translateY(0) rotateY(0deg)" },
      { transform: "translateY(-26px) rotateY(360deg)", offset: .5, easing: "cubic-bezier(0.5, 0, 0.9, 0.5)" },
      { transform: "translateY(0) rotateY(720deg)" },
    ], { duration: 700, easing: "cubic-bezier(0.2, 0.7, 0.4, 1)" }).finished.then(squish, () => {});
  }
});

// Pause the idle loops whenever the pocket is offscreen.
new IntersectionObserver(([e]) => pk.el.classList.toggle("paused", !e.isIntersecting)).observe(pk.el);

// Eyes follow the mouse on desktop, and look at whatever field you're typing in.
let lookFrame = 0;
window.addEventListener("pointermove", (e) => {
  if (calm() || pk.focusLook || e.pointerType !== "mouse" || lookFrame) return;
  const { clientX: x, clientY: y } = e;
  lookFrame = requestAnimationFrame(() => { lookFrame = 0; lookAt(x, y); });
});
$("txForm").addEventListener("focusin", (e) => {
  pk.focusLook = true;
  const r = e.target.getBoundingClientRect();
  lookAt(r.left + r.width / 2, r.top + r.height / 2, 120);
});
$("txForm").addEventListener("focusout", () => { pk.focusLook = false; look(0, 0); });

$("pairForm").addEventListener("submit", onPair);
$("serverForm").addEventListener("submit", (e) => {
  e.preventDefault();
  const next = cleanServer($("serverUrl").value, $("serverKey").value);
  if (!next) { $("serverMsg").textContent = "Enter the server address and its publishable key."; return; }
  $("serverMsg").textContent = "";
  setServer(next);
  showServer();
  $("lockMsg").textContent = "";
  $("pairCode").focus();
});
$("serverReset").addEventListener("click", () => { setServer(DEFAULT_SERVER); showServer(); });
$("pairCode").addEventListener("input", () => {
  const d = $("pairCode").value.replace(/\D/g, "").slice(0, 6);
  $("pairCode").value = d.length > 3 ? `${d.slice(0, 3)} ${d.slice(3)}` : d;
});
$("lockForm").addEventListener("submit", (e) => {
  e.preventDefault();
  const k = $("keyInput").value.trim();
  if (k) unlock(k);
});
$("txForm").addEventListener("submit", onSubmit);
$("deleteBtn").addEventListener("click", onDelete);
$("pauseBtn").addEventListener("click", onPause);
$("cancelBtn").addEventListener("click", resetForm);
$("detailsBtn").addEventListener("click", () => setDetails(!$("details").classList.contains("open")));
$("forget").addEventListener("click", () => { $("settings").close(); lock(); });
$("settingsBtn").addEventListener("click", openSettings);
$("pairStart").addEventListener("click", startPairing);
$("amount").addEventListener("input", updatePreview);
$("label").addEventListener("input", guessCategory);
$("date").addEventListener("input", updateFormText);
$("confirmBox").addEventListener("change", () => { confirmTouched = true; updateFormText(); });
$("subscriptionBox").addEventListener("change", () => { subscriptionChoice = $("subscriptionBox").checked; });
$("addSubscription").addEventListener("click", () => {
  resetForm();
  subscriptionChoice = subscriptionTracking ? true : null;
  cat = "subscriptions"; catTouched = true;
  setCadence("monthly"); renderCats(); setDetails(true);
  $("txForm").scrollIntoView({ behavior: calm() ? "auto" : "smooth", block: "center" });
  $("amount").focus({ preventScroll: true });
});
document.querySelectorAll("[data-subscription-days]").forEach((button) => button.addEventListener("click", () => {
  subscriptionDays = Number(button.dataset.subscriptionDays);
  renderSubscriptions();
}));
document.querySelectorAll(".seg button").forEach((b) => b.addEventListener("click", () => setSign(Number(b.dataset.sign))));
document.querySelectorAll("#chips button").forEach((b) => b.addEventListener("click", () => setCadence(b.dataset.cadence)));
document.querySelectorAll(".tab").forEach((b) => b.addEventListener("click", () => setTab(b.id.slice(4))));
document.querySelector(".tabs").addEventListener("keydown", (e) => {
  if (!["ArrowRight", "ArrowLeft", "Home", "End"].includes(e.key)) return;
  const names = TAB_NAMES;
  const index = e.key === "Home" ? 0 : e.key === "End" ? names.length - 1
    : (names.indexOf(tab) + (e.key === "ArrowRight" ? 1 : names.length - 1)) % names.length;
  const next = names[index];
  setTab(next);
  $(`tab-${next}`).focus();
});
document.querySelectorAll("[data-range]").forEach((b) => b.addEventListener("click", () => {
  range = Number(b.dataset.range);
  ls.set(RANGE_STORE, String(range));
  showAllUpcoming = false;
  document.querySelectorAll("[data-range]").forEach((x) => x.setAttribute("aria-pressed", String(x === b)));
  $("chart").classList.add("loading"); // keep the old chart while the longer range loads
  load({ quiet: true }).then(() => { if (loaded) render(); }); // the plan depends on the range even if the data didn't change
}));
document.querySelectorAll("[data-scope]").forEach((b) => b.addEventListener("click", () => {
  insight.scope = b.dataset.scope;
  renderInsights();
}));
$("monthPrev").addEventListener("click", () => { insight.month = shiftMonth(insight.month, -1); renderInsights(); });
$("monthNext").addEventListener("click", () => { insight.month = shiftMonth(insight.month, 1); renderInsights(); });
let chartW = 0;
new ResizeObserver(([e]) => {
  const w = Math.round(e.contentRect.width);
  if (w && w !== chartW) { const first = !chartW; chartW = w; if (!first && proj) renderChart({ animate: false }); }
}).observe($("chart"));
document.addEventListener("visibilitychange", () => { if (!document.hidden) load({ quiet: true }); });
window.addEventListener("focus", () => load({ quiet: true }));
window.addEventListener("online", () => load({ quiet: true }));
motionQuery.addEventListener?.("change", scheduleBlink);
scheduleBlink();

// Browsers sometimes keep an old copy of this page. Ask for the current version (never cached)
// and reload into it when it changed, so nobody gets stuck on an old release.
const APP_VERSION = "10";
async function checkForUpdate() {
  try {
    const res = await fetch(`version.json?t=${Date.now()}`, { cache: "no-store" });
    const { version } = await res.json();
    if (version && version !== APP_VERSION && sessionStorage.getItem("pocket.reloadedFor") !== version) {
      sessionStorage.setItem("pocket.reloadedFor", version);
      location.replace(`${location.pathname}?v=${encodeURIComponent(version)}${location.hash}`);
    }
  } catch { /* offline or blocked: keep running this copy */ }
}
checkForUpdate();
document.addEventListener("visibilitychange", () => { if (!document.hidden) checkForUpdate(); });

// A link from Pocket for Mac can carry the server and a pairing code: #server=…&apikey=…&code=…
const linked = new URLSearchParams(location.hash.slice(1));
let linkedCode = null;
if (linked.has("server") || linked.has("code")) {
  const next = linked.has("server") ? cleanServer(linked.get("server"), linked.get("apikey")) : null;
  if (next && (next.url !== server.url || next.key !== server.key)) setServer(next);
  linkedCode = (linked.get("code") || "").replace(/\D/g, "").slice(0, 6) || null;
  history.replaceState(null, "", location.pathname + location.search);
}

const saved = ls.get(KEY_STORE);
if (saved && !linkedCode) unlock(saved);
else {
  lock();
  if (linkedCode) { $("pairCode").value = `${linkedCode.slice(0, 3)} ${linkedCode.slice(3)}`; $("pairForm").querySelector("button").focus(); }
}
