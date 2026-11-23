(() => {
  if (window !== window.top || location.origin !== "https://pocketleft.example" || location.pathname !== "/index.html") return;
  const host = window.chrome?.webview;
  if (!host) return;
  const modeKey = "pocket.windows.ledgerMode";
  const readyKey = "pocket.windows.localReady";
  const ledgerMode = localStorage.getItem(modeKey);
  const currencyKey = `pocket.windows.currency.${ledgerMode === "local" ? "local" : "sync"}`;
  const currencies = Intl.supportedValuesOf("currency");
  const savedCurrency = localStorage.getItem(currencyKey);
  const localModule = () => import("./local-ledger.js");
  const history = { text: "", direction: "", category: "", from: "", to: "" };
  const ledgerWrites = new Set([
    "pocket_add", "pocket_update", "pocket_delete", "pocket_recurring_add", "pocket_recurring_update",
    "pocket_recurring_delete", "pocket_recurring_set_active", "pocket_recurring_settle", "pocket_recurring_skip",
    "pocket_subscription_set", "pocket_preset_save", "pocket_preset_delete",
  ]);
  let focusHistory = false;
  let writeWork = Promise.resolve();
  let journalAccount;
  let undoableQueuedAdd;
  window.PocketDesktop = {
    ledgerMode,
    isQuickEntry: () => document.documentElement.dataset.pocketView === "quick",
    isQuickBalanceHidden() {
      return this.isQuickEntry() && document.documentElement.hasAttribute("data-pocket-hide-balance");
    },
    currency: currencies.includes(savedCurrency) ? savedCurrency : "USD",
    lastMonth: localStorage.getItem("pocket.windows.categoryMonth"),
    showCategoryMonth(month, first, last, all) {
      const input = document.getElementById("pocketCategoryMonth");
      if (!input) return;
      input.min = first;
      input.max = last;
      input.value = month;
      input.disabled = all;
      localStorage.setItem("pocket.windows.categoryMonth", month);
    },
    filterHistory: (entries) => {
      const normalize = (text) => text.normalize("NFD").replace(/\p{M}/gu, "").toLowerCase();
      const words = normalize(history.text.trim()).split(/\s+/).filter(Boolean);
      return entries.filter((entry) => {
        if (history.from && entry.occurred_on < history.from || history.to && entry.occurred_on > history.to) return false;
        if (history.category && (entry.category || "uncategorized") !== history.category) return false;
        if (history.direction && (entry.category === "start" || Math.sign(Number(entry.amount)) !== Number(history.direction))) return false;
        const text = normalize(`${entry.label} ${catName(entry.category)} ${Number(entry.amount).toFixed(2)}`);
        return words.every((word) => text.includes(word));
      });
    },
    clearHistoryFilters: () => {
      const period = document.querySelector(".pocket-history-controls [data-period]");
      if (period) period.value = "";
      for (const field of document.querySelectorAll(".pocket-history-controls [data-filter]")) {
        field.value = "";
        history[field.dataset.filter] = "";
      }
    },
    includeEveryday: localStorage.getItem("pocket.windows.projectSpending") !== "no",
    everyday: (entries, today) => {
      if (!entries.length) return 0;
      const daysSince = (day) => Math.round((asDate(today) - asDate(day)) / 86400000);
      const weeks = Math.min(12, Math.floor(daysSince(entries.at(-1).occurred_on) / 7));
      if (weeks < 2) return 0;
      const totals = Array(weeks).fill(0);
      for (const entry of entries) {
        const days = daysSince(entry.occurred_on);
        if (entry.amount < 0 && !entry.recurring_id && entry.category !== "start" && days > 0 && days <= weeks * 7) {
          totals[Math.floor((days - 1) / 7)] -= Math.round(Number(entry.amount) * 100);
        }
      }
      totals.sort((a, b) => a - b);
      return Math.floor((totals[Math.floor(weeks / 2)] + totals[Math.floor((weeks - 1) / 2)]) / 2);
    },
    onRender: (entries) => {
      renderPayday();
      const note = document.getElementById("pocket-spending-note");
      if (!note) return;
      const weekly = window.PocketDesktop.everyday(entries, todayISO());
      note.textContent = weekly ? `Typical spending: ${fmt(weekly / 100)} per week` : "Needs two weeks of spending history to estimate.";
    },
    onLoaded: () => checkReminders(),
    async saveSyncCopy(url, token, state) { await (await localModule()).cacheSyncState(await cacheId(url, token), state); },
    async readSyncCopy(url, token) { return (await localModule()).cachedSyncState(await cacheId(url, token)); },
    isLedgerWrite: (name) => ledgerWrites.has(name),
    queueWrite,
    cancelQueuedAdd,
    flushWrites,
    localRpc: async (name, args) => (await localModule()).rpc(name, args),
  };

  const paydayKey = `${currencyKey}.payday`;
  const cushionKey = `${currencyKey}.cushion`;

  function renderPayday() {
    const date = document.getElementById("pocketPayday");
    if (!date || !proj) return;
    const today = todayISO();
    date.min = addDays(today, 1);
    date.max = addDays(today, 30);
    const saved = ls.get(paydayKey);
    const suggested = upcoming.find((item) => Number(item.amount) > 0 && item.due_on >= date.min && item.due_on <= date.max);
    date.value = saved >= date.min && saved <= date.max ? saved : suggested?.due_on || "";
    const cushion = document.getElementById("pocketPaydayCushion");
    const result = document.getElementById("pocketPaydayResult");
    const detail = document.getElementById("pocketPaydayDetail");
    if (!date.value || !cushion.validity.valid) {
      result.textContent = !date.value ? "Choose your next payday within 30 days." : "Enter a cushion of zero or more.";
      result.classList.remove("warn");
      detail.textContent = "";
      return;
    }
    const days = Math.round((asDate(date.value) - asDate(today)) / 86400000) - 1;
    const p = project(proj.start, { days, beforePayday: true });
    const extra = Math.round(p.low.bal * 100) - Math.round(Number(cushion.value) * 100);
    result.textContent = extra < 0 ? `${fmt(-extra / 100)} short of your cushion` : `${fmt(extra / 100)} available to spend today`;
    result.classList.toggle("warn", extra < 0);
    const usual = p.daily > 0 ? `Includes ${fmt(p.daily / 100)} per day of usual spending.` : "Usual spending needs more history.";
    detail.textContent = `Lowest projected balance is ${fmt(p.low.bal)} on ${shortFmt.format(asDate(p.low.date))}. ${usual} Income awaiting confirmation is excluded.`;
  }

  function addPaydayCard() {
    const card = document.createElement("section");
    card.className = "section card pocket-payday";
    card.innerHTML = `<h2>Available until payday</h2>
      <div class="fields2">
        <label>Payday<input id="pocketPayday" type="date"></label>
        <label>Keep at least<input id="pocketPaydayCushion" type="number" min="0" max="999999999.99" step="0.01"></label>
      </div>
      <div id="pocketPaydayResult" class="plan-title" role="status"></div>
      <p id="pocketPaydayDetail" class="fine-print"></p>`;
    const date = card.querySelector("#pocketPayday");
    date.addEventListener("change", () => {
      if (date.validity.valid) ls.set(paydayKey, date.value);
      renderPayday();
    });
    const cushion = card.querySelector("#pocketPaydayCushion");
    cushion.value = ls.get(cushionKey) || "0";
    cushion.addEventListener("input", () => {
      if (cushion.validity.valid) ls.set(cushionKey, cushion.value);
      renderPayday();
    });
    document.getElementById("panel-plan").prepend(card);
    renderPayday();
  }

  async function cacheId(url, token) {
    const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`${url}\n${token}`));
    return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
  }

  function serializeWrite(operation) {
    const result = writeWork.then(operation);
    writeWork = result.catch(() => {});
    return result;
  }

  async function currentJournal() {
    const access = key, url = server.url;
    const account = await cacheId(url, access);
    const current = () => access === key && url === server.url;
    if (!current()) throw new Error("Pocket changed accounts.");
    journalAccount = account;
    const journal = readQueue().map((entry) => entry.id
      ? { ...entry, state: entry.state === "sending" ? "review" : entry.state }
      : { ...entry, account, id: crypto.randomUUID(), state: "review" });
    return { journal, current, account };
  }

  function writeJournal(journal) {
    saveQueue(journal);
    renderSyncJournal(journal);
  }

  async function sendWrite(entry, context) {
    const { journal, current } = context;
    if (!current()) throw new Error("Pocket changed accounts.");
    entry.state = "sending";
    writeJournal(journal);
    try {
      if (entry.due) {
        const state = await rpc("pocket_state", { p_today: todayISO(), p_days: 1 });
        if (!current()) throw new Error("Pocket changed accounts.");
        const rule = state.recurring.find((item) => item.id === entry.args.p_id);
        if (rule?.next_on !== entry.due) throw new Error("The next payment changed. Review it in Plan.");
      }
      if (entry.dependsOn) throw new Error("The previous change needs review.");
      const result = await rpc(entry.fn, entry.args, { fromQueue: true });
      if (current()) {
        if (undoableQueuedAdd?.id === entry.id) undoableQueuedAdd.remoteID = result?.id;
        for (const dependent of journal.filter((item) => item.dependsOn === entry.id)) {
          if (typeof result?.id !== "string") {
            dependent.state = "review";
            continue;
          }
          dependent.args.p_id = result.id;
          delete dependent.dependsOn;
        }
        writeJournal(journal.filter((item) => item.id !== entry.id));
      }
      return result;
    } catch (error) {
      if (current()) {
        entry.state = "review";
        writeJournal(journal);
      }
      if (error.badKey) throw error;
      return { queued: true, review: true };
    }
  }

  function queueWrite(fn, args, { quickEntry = false } = {}) {
    const access = key, target = server;
    return serializeWrite(async () => {
      if (access !== key || target !== server) throw new Error("Pocket changed accounts.");
      const context = await currentJournal();
      const { journal, account } = context;
      const existing = journal.find((entry) => args.p_id && entry.account === account && entry.args.p_id === args.p_id);
      if (existing) throw new Error("That item has a change waiting in Settings.");
      const due = ["pocket_recurring_settle", "pocket_recurring_skip"].includes(fn)
        ? rules.find((rule) => rule.id === args.p_id)?.next_on : undefined;
      const entry = { id: crypto.randomUUID(), account, fn, args, state: "queued", due };
      journal.push(entry);
      writeJournal(journal);
      if (!navigator.onLine || journal.some((item) => item !== entry && item.account === account)) {
        setSync("off", `${journal.length} waiting to sync`);
        if (quickEntry) {
          undoableQueuedAdd = { id: entry.id, account };
          return { queued: true, queueID: entry.id };
        }
        toast("Change saved on this PC. It will sync when Pocket can connect.");
        return { queued: true };
      }
      const result = await sendWrite(entry, context);
      if (result?.review) {
        setSync("off", "A change needs review");
        toast("Check the pending change in Settings before retrying.");
      }
      return result;
    });
  }

  function cancelQueuedAdd(id) {
    return serializeWrite(async () => {
      const { journal, account } = await currentJournal();
      if (undoableQueuedAdd?.id !== id || undoableQueuedAdd.account !== account) {
        throw new Error("This entry is no longer available to undo.");
      }
      const entry = journal.find((item) => item.id === id && item.account === account);
      if (entry?.state === "review") {
        throw new Error("Check this entry in Sync settings before undoing it.");
      }
      if (entry) writeJournal(journal.filter((item) => item.id !== id));
      return undoableQueuedAdd.remoteID;
    });
  }

  function flushWrites() {
    return serializeWrite(async () => {
      if (!navigator.onLine || !readQueue().length || !key) return;
      const context = await currentJournal();
      const { current, journal, account } = context;
      writeJournal(journal);
      for (const entry of journal.filter((item) => item.account === account)) {
        if (!current() || !navigator.onLine || entry.state !== "queued") break;
        const result = await sendWrite(entry, context);
        if (result?.review) break;
        journal.splice(journal.indexOf(entry), 1);
      }
    });
  }

  function renderSyncJournal(journal = readQueue()) {
    const box = document.getElementById("pocketSyncJournal");
    if (!box) return;
    journal = journal.filter((entry) => entry.account === journalAccount && entry.id);
    box.replaceChildren();
    box.hidden = !journal.length;
    if (!journal.length) return;
    box.append(mk("h3", null, "Pending sync changes"));
    for (const entry of journal) {
      const row = mk("div", "pocket-desktop-settings");
      const name = entry.args.p_label || "Ledger change";
      row.append(mk("p", "fine-print", `${name} · ${entry.state === "queued" ? "Waiting to sync" : "Review before retrying"}`));
      const retry = mk("button", "btn ghost", "Retry");
      const discard = mk("button", "btn ghost", "Discard");
      retry.type = discard.type = "button";
      retry.hidden = entry.state === "queued";
      retry.disabled = discard.disabled = entry.state === "sending";
      const modify = (keep) => {
        if (keep && !confirm("Check your synced account for this change first. Retry could apply it twice if it already went through. Retry now?")) return;
        if (!keep && !confirm("Discard this pending change?")) return;
        void serializeWrite(async () => {
          if (!key) return;
          const { journal, account } = await currentJournal();
          const index = journal.findIndex((item) => item.id === entry.id);
          if (index < 0 || journal[index].account !== account) return;
          if (keep) journal[index].state = "queued";
          else {
            const [removed] = journal.splice(index, 1);
            for (const dependent of journal.filter((item) => item.dependsOn === removed.id)) {
              journal.splice(journal.indexOf(dependent), 1);
            }
          }
          writeJournal(journal);
        }).then(() => load({ quiet: true })).catch(() => toast("Couldn't change the sync queue."));
      };
      retry.addEventListener("click", () => modify(true));
      discard.addEventListener("click", () => modify(false));
      row.append(retry, discard);
      box.append(row);
    }
  }

  function addHistoryControls() {
    const box = document.createElement("div");
    box.className = "pocket-history-controls";
    box.innerHTML = `
      <label>Search history<input type="search" placeholder="Description, category, amount" data-filter="text"></label>
      <label>Type<select data-filter="direction"><option value="">In and out</option><option value="-1">Spending</option><option value="1">Money in</option></select></label>
      <label>Category<select data-filter="category"><option value="">All categories</option></select></label>
      <label>Period<select data-period><option value="">Any time</option><option value="this">This month</option>
        <option value="previous">Last month</option><option value="three">Last 3 months</option><option value="year">This year</option></select></label>
      <label>From<input type="date" data-filter="from"></label>
      <label>To<input type="date" data-filter="to"></label>
      <button type="button" class="btn ghost" data-action="clear">Clear filters</button>
      <button type="button" class="btn ghost" data-action="export">Export visible CSV</button>`;
    const category = box.querySelector('[data-filter="category"]');
    for (const code of ["uncategorized", ...Object.keys(CATS)]) category.add(new Option(catName(code), code));
    box.addEventListener("input", (event) => {
      const field = event.target.dataset.filter;
      if (field) {
        history[field] = event.target.value;
        if (field === "from" || field === "to") box.querySelector("[data-period]").value = "";
      } else if (event.target.hasAttribute("data-period")) {
        const today = todayISO(), month = today.slice(0, 7);
        const periods = {
          "": ["", ""], this: [`${month}-01`, today],
          previous: [`${shiftMonth(month, -1)}-01`, addDays(`${month}-01`, -1)],
          three: [`${shiftMonth(month, -2)}-01`, today], year: [`${today.slice(0, 4)}-01-01`, today],
        };
        [history.from, history.to] = periods[event.target.value];
        box.querySelector('[data-filter="from"]').value = history.from;
        box.querySelector('[data-filter="to"]').value = history.to;
      } else return;
      renderHistory();
    });
    box.querySelector('[data-action="export"]').addEventListener("click", () => exportCSV(historyEntries()));
    box.querySelector('[data-action="clear"]').addEventListener("click", () => {
      filter = null;
      window.PocketDesktop.clearHistoryFilters();
      renderHistory();
    });
    document.getElementById("filterSlot").before(box);
    window.addEventListener("keydown", (event) => {
      if (!event.ctrlKey || event.key.toLowerCase() !== "f" || document.getElementById("home").hidden ||
          document.querySelector("dialog[open]")) return;
      event.preventDefault();
      setTab("activity");
      if (document.documentElement.dataset.pocketView === "quick") {
        focusHistory = true;
        host.postMessage("open-pocket");
      } else box.querySelector('input[type="search"]').focus();
    });
  }

  function exportCSV(entries) {
    const csvText = (value) => {
      let text = String(value);
      if (/^\s*[=+@-]|^[\t\r]/.test(text)) text = "'" + text;
      return /[,"\r\n]/.test(text) ? '"' + text.replaceAll('"', '""') + '"' : text;
    };
    const rows = ["Date,Description,Category,Amount,Currency,Type,Scheduled"];
    for (const entry of [...entries].reverse()) {
      const amount = Number(entry.amount);
      const type = entry.category === "start" ? "Starting balance" : amount < 0 ? "Spent" : "Money in";
      rows.push([entry.occurred_on, csvText(entry.label), csvText(entry.category ? catName(entry.category) : ""),
        amount.toFixed(2), window.PocketDesktop.currency, type, entry.recurring_id ? "Yes" : "No"].join(","));
    }
    downloadFile(`Pocket-${todayISO()}.csv`, "\uFEFF" + rows.join("\r\n") + "\r\n", "text/csv;charset=utf-8");
  }

  function downloadFile(name, data, mimeType) {
    const url = URL.createObjectURL(new Blob([data], { type: mimeType }));
    const link = document.createElement("a");
    link.download = name;
    link.href = url;
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 60_000);
  }

  function addMoneySettings(settings) {
    const box = document.createElement("section");
    box.className = "pocket-desktop-settings";
    box.innerHTML = `
      <h3>Money</h3>
      <label for="pocketCurrency">Display currency</label>
      <select id="pocketCurrency"></select>
      <p class="fine-print">Changes how amounts are shown. Your entries keep their values.</p>
      <button class="btn ghost" type="button">Export all entries as CSV</button>`;
    const picker = box.querySelector("select");
    const names = new Intl.DisplayNames(navigator.languages, { type: "currency" });
    for (const code of currencies) picker.add(new Option(`${code} · ${names.of(code)}`, code));
    picker.value = window.PocketDesktop.currency;
    picker.addEventListener("change", () => {
      localStorage.setItem(currencyKey, picker.value);
      window.PocketDesktop.currency = picker.value;
      setCurrency(picker.value);
      document.querySelector("#txForm .cur").textContent = money.formatToParts(0).find((part) => part.type === "currency").value;
      render();
      if (shownBalance !== null) setOdometer(document.getElementById("balance"), shownBalance);
      updateFormText();
      updatePreview();
    });
    box.querySelector("button").addEventListener("click", () => exportCSV(txs));
    settings.querySelector(".sheet-in").append(box);
    document.querySelector("#txForm .cur").textContent = money.formatToParts(0).find((part) => part.type === "currency").value;
  }

  function addBackupSettings(settings, isLocal) {
    const box = document.createElement("section");
    box.className = "pocket-desktop-settings";
    box.innerHTML = `
      <h3>Backups</h3>
      <button type="button" class="btn ghost" data-action="export">Export Pocket backup</button>
      <button type="button" class="btn ghost" data-action="import">Import Pocket backup</button>
      <input type="file" accept=".json,application/json" hidden>
      <label>Daily backups<select><option value="">Choose a day</option></select></label>
      <button type="button" class="btn ghost" data-action="restore">Restore selected day</button>
      <button type="button" class="btn ghost" data-action="erase">Erase local ledger</button>
      <p class="form-msg" role="status"></p>`;
    const file = box.querySelector("input");
    const days = box.querySelector("select");
    const message = box.querySelector("[role=status]");
    const action = (name) => box.querySelector(`[data-action="${name}"]`);
    const replace = async (ledger) => {
      if (!confirm("Replace the local ledger? Export your current data first if you want to keep a copy.")) return;
      await (await localModule()).replaceLedger(ledger);
      location.reload();
    };
    const run = async (task) => {
      if (box.inert) return;
      box.inert = true;
      message.textContent = "";
      try { await task(); }
      catch { message.textContent = "Pocket could not complete the backup action. Check the file or try again."; }
      finally { box.inert = false; }
    };
    action("export").addEventListener("click", () => run(async () => {
      const data = isLocal ? await (await localModule()).exportLedger() : syncedBackup();
      downloadFile(`Pocket-${todayISO()}.json`, JSON.stringify(data, null, 2), "application/json");
    }));
    action("import").addEventListener("click", () => file.click());
    file.addEventListener("change", () => {
      const selected = file.files[0];
      file.value = "";
      if (selected) void run(async () => replace(JSON.parse(await selected.text())));
    });
    action("restore").addEventListener("click", () => run(async () => {
      if (days.value) await replace(await (await localModule()).readBackup(days.value));
    }));
    action("erase").addEventListener("click", () => run(() => replace({
      version: 1, currency: window.PocketDesktop.currency, entries: [], rules: [], presets: [],
    })));
    if (isLocal) {
      settings.addEventListener("beforetoggle", ({ newState }) => {
        if (newState !== "open") return;
        void run(async () => {
          const dates = await (await localModule()).backupDays();
          days.replaceChildren(new Option("Choose a day", ""), ...dates.map((day) => new Option(day, day)));
        });
      });
    } else {
      for (const name of ["import", "restore", "erase"]) action(name).hidden = true;
      days.closest("label").hidden = true;
    }
    settings.querySelector(".sheet-in").append(box);
  }

  function syncedBackup() {
    const stamp = (value) => new Date(value).toISOString().replace(/\.\d{3}Z$/, "Z");
    return {
      version: 1,
      currency: window.PocketDesktop.currency,
      entries: txs.map((entry) => ({
        id: entry.id, cents: Math.round(Number(entry.amount) * 100), label: entry.label, day: entry.occurred_on,
        category: entry.category, ruleID: entry.recurring_id, created: stamp(entry.created_at),
      })),
      rules: rules.map((rule) => ({
        id: rule.id, cents: Math.round(Number(rule.amount) * 100), label: rule.label, cadence: rule.cadence,
        anchor: rule.next_on, posted: 0, total: rule.remaining, active: rule.active, auto: rule.auto,
        category: rule.category, subscription: rule.subscription, once: rule.once, created: stamp(Date.now()),
      })),
      presets: presets.map((preset) => ({
        id: preset.id, label: preset.label, cents: preset.amount == null ? null : Math.round(Number(preset.amount) * 100),
        sign: preset.sign, category: preset.category,
      })),
    };
  }

  function addSyncActions(settings, isLocal) {
    if (isLocal) {
      const setup = document.createElement("details");
      setup.className = "pocket-desktop-settings";
      setup.innerHTML = `
        <summary>Set up a new sync server</summary>
        <form>
          <p class="fine-print">Use an empty Supabase project with Pocket's SQL installed. Pocket copies this ledger to that server and keeps the original on this PC.</p>
          <label>Server address<input name="address" required placeholder="https://your-project.supabase.co"></label>
          <label>Publishable key<input name="publishable" required autocomplete="off" spellcheck="false"></label>
          <button type="submit" class="btn ghost">Set up sync and copy ledger</button>
          <p class="form-msg" role="status"></p>
        </form>`;
      const form = setup.querySelector("form");
      const button = form.querySelector("button");
      const status = form.querySelector("[role=status]");
      form.addEventListener("submit", async (event) => {
        event.preventDefault();
        const fields = new FormData(form);
        const target = cleanServer(fields.get("address"), fields.get("publishable"));
        if (!target?.url.startsWith("https://") || target.url === DEFAULT_SERVER.url) {
          status.textContent = "Enter your self-hosted server's HTTPS address and its publishable key.";
          return;
        }
        if (!confirm("Copy this ledger to the new sync server?")) return;
        button.disabled = true;
        status.textContent = "Setting up Pocket Sync…";
        try {
          await setUpSync(target);
        } catch (error) {
          status.textContent = error instanceof TypeError ? "Pocket could not reach the server. Check the address and try again." : error.message;
          button.disabled = false;
        }
      });
      settings.querySelector(".sheet-in").append(setup);
    } else {
      const disconnect = mk("button", "btn ghost wide", "Stop syncing and keep a local copy");
      disconnect.type = "button";
      disconnect.addEventListener("click", async () => {
        if (!loaded || !key) return;
        if (!confirm("Copy the last synced ledger to this PC? This replaces your local ledger. Any changes still waiting to sync will stay in the sync queue.")) return;
        disconnect.disabled = true;
        try {
          await (await localModule()).replaceLedger(syncedBackup());
          localStorage.setItem(readyKey, "yes");
          switchLedger("local");
        } catch {
          disconnect.disabled = false;
          toast("Pocket could not save the local copy.");
        }
      });
      document.getElementById("forget").after(disconnect);
    }
  }

  async function setUpSync(target) {
    const pendingKey = "pocket.windows.pendingSyncSetup";
    let pending = readSettings(pendingKey, null);
    if (pending?.url !== target.url || pending?.publishable !== target.key) {
      if (readQueue().length) throw new Error("Review the pending changes on your current sync server first.");
      const token = Array.from(crypto.getRandomValues(new Uint8Array(32)), (byte) => byte.toString(16).padStart(2, "0")).join("");
      const account = await cacheId(target.url, token);
      const local = await localModule();
      const state = await local.rpc("pocket_state", { p_today: todayISO(), p_days: 1 });
      const operations = [];
      const queue = (fn, args, dependsOn) => {
        const id = crypto.randomUUID();
        operations.push({ id, account, fn, args, state: "queued", dependsOn });
        return id;
      };
      for (const entry of [...state.transactions].reverse()) {
        queue("pocket_add", { p_amount: Number(entry.amount), p_label: entry.label, p_on: entry.occurred_on, p_category: entry.category });
      }
      for (const rule of state.recurring) {
        const id = queue("pocket_recurring_add", {
          p_amount: Number(rule.amount), p_label: rule.label, p_cadence: rule.cadence, p_start: rule.next_on,
          p_today: rule.active ? todayISO() : "0001-01-01", p_times: rule.remaining, p_category: rule.category,
          p_auto: rule.auto, ...PocketSubscriptions.membershipArgs(rule.subscription, true),
        });
        if (!rule.active) queue("pocket_recurring_set_active", { p_active: false, p_today: todayISO() }, id);
      }
      for (const preset of state.presets) {
        queue("pocket_preset_save", { p_label: preset.label, p_amount: preset.amount, p_sign: preset.sign, p_category: preset.category });
      }
      pending = { url: target.url, publishable: target.key, token, operations };
      localStorage.setItem(pendingKey, JSON.stringify(pending));
    }
    const request = (name, args) => fetch(`${target.url}/rest/v1/rpc/${name}`, {
      method: "POST", headers: { apikey: target.key, "Content-Type": "application/json" }, body: JSON.stringify(args),
    });
    const claim = await request("pocket_setup", { p_key: pending.token });
    if (!claim.ok) throw new Error("Pocket could not set up this server. Confirm Pocket's SQL is installed.");
    const result = await claim.json();
    if (result?.ok !== true) {
      if (result?.error !== "already_set_up") throw new Error("Pocket could not set up this server.");
      const resume = await request("pocket_state", { k: pending.token, p_today: todayISO(), p_days: 1 });
      if (!resume.ok) throw new Error("This server already has a Pocket. Join with a pairing code.");
    }
    setServer(target);
    saveQueue(pending.operations);
    ls.set(KEY_STORE, pending.token);
    localStorage.removeItem(pendingKey);
    switchLedger("sync");
  }

  const remindersKey = "pocket.windows.reminders";
  const deliveriesKey = "pocket.windows.reminderDeliveries";
  function readSettings(key, fallback) {
    try { return JSON.parse(localStorage.getItem(key)) ?? fallback; }
    catch { return fallback; }
  }
  function reminderPreferences() {
    return readSettings(remindersKey, {
      payments: true, renewals: false, days: 2, time: "10:00", subscriptions: {},
    });
  }
  function checkReminders() {
    if (!loaded || document.getElementById("home").hidden) return;
    const preferences = reminderPreferences();
    const now = new Date();
    const today = todayISO();
    const account = localLedger ? "local" : server.url;
    const sent = readSettings(deliveriesKey, {});
    const send = (id, title, body) => {
      const key = `${account}/${id}`;
      if (sent[key]) return;
      sent[key] = today;
      host.postMessage({ type: "pocket-reminder", title, body });
    };
    for (const rule of rules) {
      if (!rule.active) continue;
      if (preferences.payments && !rule.auto && rule.next_on === today && now >= new Date(`${today}T10:00`)) {
        send(`payment/${rule.id}/${today}`, Number(rule.amount) > 0 ? `Did ${rule.label} pay?` : `Was ${rule.label} paid?`,
          "Open Pocket to confirm the payment.");
      }
      if (!preferences.renewals || !PocketSubscriptions.isSubscription(rule)) continue;
      const timing = preferences.subscriptions?.[rule.id] ?? preferences;
      if (timing.kind === "off") continue;
      for (const occurrence of upcoming) {
        if (occurrence.recurring_id !== rule.id || occurrence.due_on < today) continue;
        const target = timing.kind === "exact" ? timing.date : addDays(occurrence.due_on, -timing.days);
        if (target !== today || target > occurrence.due_on || now < new Date(`${target}T${timing.time}`)) continue;
        send(`renewal/${rule.id}/${occurrence.due_on}/${target}/${timing.time}`,
          `${rule.label} renews ${shortFmt.format(asDate(occurrence.due_on))}`, "Open Subscriptions in Pocket to review the charge.");
        if (timing.kind === "exact") break;
      }
    }
    for (const [key, day] of Object.entries(sent)) if (day < addDays(today, -7)) delete sent[key];
    localStorage.setItem(deliveriesKey, JSON.stringify(sent));
  }

  function addGeneralSettings(settings) {
    const box = document.createElement("section");
    box.className = "pocket-desktop-settings";
    box.innerHTML = `
      <h3>Reminders</h3>
      <label><span><input data-pref="payments" type="checkbox"> Remind me when a payment is due</span></label>
      <label><span><input data-pref="renewals" type="checkbox"> Remind me about subscription renewals</span></label>
      <div class="fields2">
        <label>Days before renewal<input type="number" min="1" max="365" data-pref="days"></label>
        <label>Reminder time<input type="time" data-pref="time"></label>
      </div>
      <p class="fine-print">Pocket sends Windows notifications while it runs in the tray.</p>
      <button class="btn ghost" type="button" data-command="test">Send test reminder</button>
      <h3>About Pocket</h3>
      <button class="btn ghost" type="button" data-command="check-updates">Check for updates</button>
      <button class="btn ghost" type="button" data-command="about-pocket">About Pocket</button>
      <button class="btn ghost" type="button" data-command="open-data-folder">Open data folder</button>
      <button class="btn ghost" type="button" data-command="share-pocket">Copy Pocket link</button>
      <p class="form-msg" role="status"></p>`;
    const fields = [...box.querySelectorAll("[data-pref]")];
    const settingsAtOpen = reminderPreferences();
    for (const field of fields) {
      const value = settingsAtOpen[field.dataset.pref];
      if (field.type === "checkbox") field.checked = value;
      else field.value = value;
    }
    box.addEventListener("change", (event) => {
      if (!event.target.dataset.pref) return;
      const prefs = reminderPreferences();
      const days = Number(box.querySelector('[data-pref="days"]').value);
      const time = box.querySelector('[data-pref="time"]').value;
      if (!Number.isInteger(days) || days < 1 || days > 365 || !time) return;
      prefs.payments = box.querySelector('[data-pref="payments"]').checked;
      prefs.renewals = box.querySelector('[data-pref="renewals"]').checked;
      prefs.days = days;
      prefs.time = time;
      localStorage.setItem(remindersKey, JSON.stringify(prefs));
      checkReminders();
    });
    box.addEventListener("click", (event) => {
      const command = event.target.dataset.command;
      if (!command) return;
      const message = box.querySelector("[role=status]");
      if (command === "test") {
        message.textContent = "Test reminder scheduled for five seconds from now.";
        setTimeout(() => host.postMessage({ type: "pocket-reminder", title: "Pocket test reminder",
          body: "Windows reminders are working." }), 5000);
      } else {
        host.postMessage(command);
        if (command === "share-pocket") message.textContent = "Pocket link copied.";
      }
    });
    settings.querySelector(".sheet-in").append(box);
  }

  window.PocketDesktop.addRenewalControls = (rule, item) => {
    const form = document.createElement("details");
    form.className = "pocket-renewal-settings";
    form.innerHTML = `<summary>Renewal reminders</summary>
      <label>Schedule<select><option value="">Use default</option><option value="relative">Days before each renewal</option>
        <option value="exact">Specific day and time</option><option value="off">Off</option></select></label>
      <div class="fields2"><label>Days before<input type="number" min="1" max="365" value="2"></label>
        <label>Day<input type="date"></label><label>Time<input type="time" value="10:00"></label></div>
      <button class="btn ghost" type="button">Save reminder</button><p class="form-msg" role="status"></p>`;
    const mode = form.querySelector("select");
    const days = form.querySelector('[type="number"]');
    const date = form.querySelector('[type="date"]');
    const time = form.querySelector('[type="time"]');
    const prior = reminderPreferences().subscriptions?.[rule.id];
    mode.value = prior?.kind || "";
    days.value = prior?.days ?? 2;
    date.value = prior?.date ?? "";
    time.value = prior?.time ?? "10:00";
    const showFields = () => {
      date.closest("label").hidden = mode.value !== "exact";
      days.closest("label").hidden = mode.value !== "relative";
      time.closest("label").hidden = !["relative", "exact"].includes(mode.value);
    };
    mode.addEventListener("change", showFields);
    showFields();
    form.querySelector("button").addEventListener("click", () => {
      const message = form.querySelector("[role=status]");
      if (mode.value === "relative" && (!Number.isInteger(Number(days.value)) || !days.validity.valid || !days.value || !time.value) ||
          mode.value === "exact" && (!date.value || date.value < todayISO() || date.value > rule.next_on || !time.value)) {
        message.textContent = "Choose a valid time before the renewal.";
        return;
      }
      const prefs = reminderPreferences();
      prefs.subscriptions ??= {};
      if (mode.value) prefs.subscriptions[rule.id] = { kind: mode.value, days: Number(days.value), date: date.value, time: time.value };
      else delete prefs.subscriptions[rule.id];
      if (["relative", "exact"].includes(mode.value)) prefs.renewals = true;
      localStorage.setItem(remindersKey, JSON.stringify(prefs));
      document.querySelector('[data-pref="renewals"]').checked = prefs.renewals;
      message.textContent = "Reminder saved.";
      checkReminders();
    });
    item.append(form);
  };

  window.PocketDesktop.presetOptions = (preset, row, save) => {
    const direction = document.createElement("select");
    direction.setAttribute("aria-label", `Direction for ${preset.label}`);
    direction.add(new Option("Spending", "-1"));
    direction.add(new Option("Money in", "1"));
    direction.value = String(preset.sign);
    const category = document.createElement("select");
    category.setAttribute("aria-label", `Category for ${preset.label}`);
    const categories = () => {
      category.replaceChildren(new Option("Uncategorized", ""));
      for (const code of direction.value === "1" ? IN_CATS : SPEND_CATS) category.add(new Option(catName(code), code));
    };
    categories();
    category.value = preset.category || "";
    if (!category.value) category.value = "";
    direction.addEventListener("change", () => { categories(); void save(); });
    category.addEventListener("change", save);
    const options = document.createElement("div");
    options.className = "fields2 pocket-preset-options";
    options.append(direction, category);
    if (localLedger) {
      const index = presets.findIndex(({ id }) => id === preset.id);
      for (const offset of [-1, 1]) {
        const move = mk("button", "btn ghost", offset < 0 ? "Move up" : "Move down");
        move.type = "button";
        move.disabled = !presets[index + offset];
        move.addEventListener("click", async () => {
          const ids = presets.map(({ id }) => id);
          [ids[index], ids[index + offset]] = [ids[index + offset], ids[index]];
          move.disabled = true;
          try {
            await (await localModule()).reorderPresets(ids);
            await load({ quiet: true });
            renderPresetList();
          } catch { move.disabled = false; toast("Pocket could not reorder the buttons."); }
        });
        options.append(move);
      }
    }
    row.append(options);
    return () => ({ p_sign: Number(direction.value), p_category: category.value });
  };

  function addPresetControls() {
    const buttons = document.createElement("div");
    buttons.className = "pocket-desktop-settings";
    for (const [direction, label] of [[-1, "Add spending button"], [1, "Add money-in button"]]) {
      const button = mk("button", "btn ghost", label);
      button.type = "button";
      button.addEventListener("click", async () => {
        button.disabled = true;
        try {
          await rpc("pocket_preset_save", { p_label: direction < 0 ? "New spending" : "New income", p_sign: direction });
          await load({ quiet: true });
          renderPresetList();
        } catch { toast("Pocket could not add the button."); }
        finally { button.disabled = false; }
      });
      buttons.append(button);
    }
    document.getElementById("presetList").after(buttons);
  }

  function switchLedger(mode) {
    localStorage.setItem(modeKey, mode);
    location.reload();
  }

  function addLedgerControls() {
    const lock = document.getElementById("lock");
    for (const element of lock.querySelectorAll("[data-browser-onboarding]")) element.hidden = true;
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
      <p class="fine-print" id="pocketOpeningBalanceHelp">Use today’s balance for the money you want to track. Leave it empty to start at zero.</p>
      <button class="btn wide" type="submit"></button>
      <p class="form-msg" role="alert"></p>`;
    const input = form.querySelector("input");
    input.setAttribute("aria-describedby", "pocketOpeningBalanceHelp");
    input.hidden = exists;
    form.querySelector("label").hidden = exists;
    form.querySelector("#pocketOpeningBalanceHelp").hidden = exists;
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
    if (!isLocal) {
      const journal = document.createElement("section");
      journal.id = "pocketSyncJournal";
      document.getElementById("deviceSettings").after(journal);
      settings.addEventListener("beforetoggle", ({ newState }) => {
        if (newState !== "open" || !key) return;
        void serializeWrite(async () => {
          const { journal } = await currentJournal();
          writeJournal(journal);
        }).catch(() => {});
      });
    }
    addMoneySettings(settings);
    addBackupSettings(settings, isLocal);
    addGeneralSettings(settings);
    addSyncActions(settings, isLocal);
  }

  document.addEventListener("DOMContentLoaded", () => {
    const root = document.documentElement;
    const home = document.getElementById("home");
    const balance = document.getElementById("balance");
    const sync = document.getElementById("sync");
    let lastBalance;
    let refreshing = false;
    function publishBalance() {
      const amount = !home.hidden && Number.isFinite(shownBalance) ? fmt(shownBalance) : null;
      const stale = amount !== null && sync.classList.contains("off");
      const display = { type: "clock-balance", amount, stale };
      const serialized = JSON.stringify(display);
      if (serialized === lastBalance) return;
      lastBalance = serialized;
      host.postMessage(display);
    }
    const balanceChanges = new MutationObserver(publishBalance);
    balanceChanges.observe(home, { attributes: true, attributeFilter: ["hidden"] });
    balanceChanges.observe(balance, { attributes: true, attributeFilter: ["aria-label"] });
    balanceChanges.observe(sync, { attributes: true, attributeFilter: ["class"] });
    publishBalance();
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
      if (data === "hide-balance" || data === "show-balance") {
        root.toggleAttribute("data-pocket-hide-balance", data === "hide-balance");
        if (shownBalance !== null) document.title = window.PocketDesktop.isQuickBalanceHidden() ? "Pocket" : `${fmt(shownBalance)} · Pocket`;
        return;
      }
      if (data === "refresh-balance") {
        // Leave queued writes to the visible window so a background read can't replay them.
        if (document.hidden && !refreshing && (ledgerMode === "local" || readQueue().length === 0)) {
          refreshing = true;
          void load({ quiet: true }).finally(() => { refreshing = false; });
        }
        return;
      }
      if (data !== "quick" && data !== "full") return;
      const changed = data !== root.dataset.pocketView;
      const focusExpand = document.activeElement === expand;
      root.dataset.pocketView = data;
      if (shownBalance !== null) document.title = window.PocketDesktop.isQuickBalanceHidden() ? "Pocket" : `${fmt(shownBalance)} · Pocket`;
      expand.hidden = data !== "quick";
      if (changed) window.scrollTo({ top: 0, behavior: "instant" });
      if (focusExpand && data === "full") document.querySelector("#settingsBtn").focus();
      if (focusHistory && data === "full") {
        focusHistory = false;
        document.querySelector('.pocket-history-controls input[type="search"]').focus();
      }
      if (data === "quick" && document.activeElement?.closest(".tabs, .panel")) document.querySelector("#amount").focus();
      host.postMessage("view-ready");
    });

    window.addEventListener("keydown", (event) => {
      if (event.key !== "Escape" || event.defaultPrevented || document.querySelector("dialog[open]")) return;
      event.preventDefault();
      host.postMessage("hide");
    });
    addLedgerControls();
    addHistoryControls();
    addPresetControls();
    addPaydayCard();
    document.querySelector("#panel-subscriptions > .fine-print").textContent =
      "Use Renewal reminders on a subscription to change when Pocket notifies you. To cancel a subscription, contact the provider.";
    const spending = document.createElement("div");
    spending.className = "pocket-desktop-settings";
    spending.innerHTML = '<label><span><input type="checkbox"> Include everyday spending in the forecast</span></label><p id="pocket-spending-note" class="fine-print"></p>';
    const spendingToggle = spending.querySelector("input");
    spendingToggle.checked = window.PocketDesktop.includeEveryday;
    spendingToggle.addEventListener("change", () => {
      window.PocketDesktop.includeEveryday = spendingToggle.checked;
      localStorage.setItem("pocket.windows.projectSpending", spendingToggle.checked ? "yes" : "no");
      render();
    });
    document.getElementById("chart").after(spending);
    const incomeCategories = document.createElement("section");
    incomeCategories.className = "section";
    incomeCategories.innerHTML = '<div class="section-head"><h2>Where money came from</h2></div><div id="pocketIncomeBars" class="rows bars"></div>';
    document.getElementById("panel-insights").append(incomeCategories);
    document.getElementById("tab-insights").textContent = "Categories";
    const monthPicker = document.createElement("input");
    monthPicker.type = "month";
    monthPicker.id = "pocketCategoryMonth";
    monthPicker.setAttribute("aria-label", "Categories month");
    monthPicker.addEventListener("change", () => {
      if (monthPicker.validity.valid && monthPicker.value) {
        insight.month = monthPicker.value;
        renderInsights();
      }
    });
    document.querySelector("#panel-insights .scope").after(monthPicker);
    renderInsights();
    stylesheet.addEventListener("load", () => host.postMessage("ready"), { once: true });
    stylesheet.addEventListener("error", () => host.postMessage("client-error"), { once: true });
    document.head.append(stylesheet);
  }, { once: true });
})();
