(() => {
  if (window !== window.top || location.origin !== "https://pocketleft.example" || location.pathname !== "/index.html") return;
  const host = window.chrome?.webview;
  if (!host) return;
  const modeKey = "pocket.windows.ledgerMode";
  const readyKey = "pocket.windows.localReady";
  const ledgerMode = localStorage.getItem(modeKey);
  const localModule = () => import("./local-ledger.js");
  window.PocketDesktop = {
    ledgerMode,
    localRpc: async (name, args) => (await localModule()).rpc(name, args),
  };

  function switchLedger(mode) {
    localStorage.setItem(modeKey, mode);
    location.reload();
  }

  function addLedgerControls() {
    const lock = document.getElementById("lock");
    lock.querySelector("h1").textContent = "Set up Pocket";
    const isLocal = ledgerMode === "local";
    const exists = isLocal || localStorage.getItem(readyKey) === "yes";
    const form = document.createElement("form");
    form.className = "pocket-local-form card";
    form.innerHTML = `
      <h2>Local ledger</h2>
      <p>Record expenses and income on this PC.</p>
      <label class="cap" for="pocketOpeningBalance">Starting balance (USD)</label>
      <input id="pocketOpeningBalance" inputmode="decimal" placeholder="0.00" autocomplete="off">
      <button class="btn wide" type="submit"></button>
      <p class="form-msg" role="alert"></p>`;
    const input = form.querySelector("input");
    input.hidden = exists;
    form.querySelector("label").hidden = exists;
    const submit = form.querySelector("button");
    submit.textContent = exists ? "Open local ledger" : "Start local ledger";
    lock.querySelector("h1").after(form);
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      const raw = input.value.trim().replace(/^−/, "-");
      const alert = form.querySelector("[role=alert]");
      if (raw && !/^[+-]?\d{1,10}(?:[.,]\d{1,2})?$/.test(raw)) {
        alert.textContent = "Enter an amount like 125.50 or −25.00.";
        input.focus();
        return;
      }
      submit.disabled = true;
      alert.textContent = "Opening your ledger…";
      try {
        const openingBalance = Number(raw.replace(",", "."));
        await (await localModule()).initializeLedger(openingBalance, todayISO());
        localStorage.setItem(readyKey, "yes");
        switchLedger("local");
      } catch (error) {
        console.error("Pocket local ledger setup failed", error.message);
        alert.textContent = "Pocket could not open the local ledger. Try again.";
        submit.disabled = false;
      }
    });

    if (ledgerMode === "setup") {
      for (const element of lock.querySelectorAll(":scope > :is(ol, details, #pairForm)")) element.hidden = true;
      const back = document.createElement("button");
      back.type = "button";
      back.className = "link fine-print";
      back.textContent = "Return to Pocket Sync";
      back.addEventListener("click", () => switchLedger("sync"));
      form.after(back);
    } else {
      const syncTitle = document.createElement("h2");
      syncTitle.textContent = "Pair with Pocket Sync";
      form.after(syncTitle);
    }
    if (!lock.hidden && ledgerMode !== "sync") (exists ? submit : input).focus({ preventScroll: true });

    const settings = document.getElementById("settings");
    if (isLocal) {
      for (const id of ["deviceSettings", "serverDetails", "forget"]) document.getElementById(id).hidden = true;
      const note = document.createElement("p");
      note.className = "lead";
      note.textContent = "Your local ledger is saved on this PC.";
      document.getElementById("serverDetails").after(note);
    }
    const switchButton = document.createElement("button");
    switchButton.type = "button";
    switchButton.className = "btn wide ghost";
    switchButton.textContent = isLocal ? "Open Pocket Sync" : exists ? "Open local ledger" : "Set up a local ledger";
    switchButton.addEventListener("click", () => switchLedger(isLocal ? "sync" : exists ? "local" : "setup"));
    settings.querySelector(".sheet-in").append(switchButton);
  }

  document.addEventListener("DOMContentLoaded", () => {
    const root = document.documentElement;
    const stylesheet = document.createElement("link");
    stylesheet.rel = "stylesheet";
    stylesheet.href = "windows.css";

    const expand = document.createElement("button");
    expand.type = "button";
    expand.className = "link pocket-expand";
    expand.textContent = "Open Pocket";
    expand.hidden = true;
    expand.addEventListener("click", () => host.postMessage("open-pocket"));
    document.querySelector("#home .top-right").prepend(expand);

    host.addEventListener("message", ({ data }) => {
      if (data !== "quick" && data !== "full") return;
      const changed = data !== root.dataset.pocketView;
      const focusExpand = document.activeElement === expand;
      root.dataset.pocketView = data;
      expand.hidden = data !== "quick";
      if (changed) window.scrollTo({ top: 0, behavior: "instant" });
      if (focusExpand && data === "full") document.querySelector("#settingsBtn").focus();
      if (data === "quick" && document.activeElement?.closest(".tabs, .panel")) document.querySelector("#amount").focus();
      host.postMessage("view-ready");
    });

    window.addEventListener("keydown", (event) => {
      if (event.key !== "Escape" || event.defaultPrevented || document.querySelector("dialog[open]")) return;
      event.preventDefault();
      host.postMessage("hide");
    });
    addLedgerControls();
    stylesheet.addEventListener("load", () => host.postMessage("ready"), { once: true });
    stylesheet.addEventListener("error", () => host.postMessage("client-error"), { once: true });
    document.head.append(stylesheet);
  }, { once: true });
})();
