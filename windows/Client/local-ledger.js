import { PGlite } from "./vendor/pglite/index.js";
import { pgcrypto } from "./vendor/pglite/contrib/pgcrypto.js";

const migrations = [
  "20261011000000_pocket.sql",
  "20261011010000_recurring.sql",
  "20261011020000_limited_and_scheduled.sql",
  "20261011030000_state_once_flag.sql",
  "20261011040000_v2.sql",
  "20261012000000_self_host_setup.sql",
  "20261016000000_quarterly.sql",
  "20261109120000_subscriptions.sql",
];
const commands = new Set([
  "pocket_state", "pocket_add", "pocket_update", "pocket_delete",
  "pocket_recurring_add", "pocket_recurring_update", "pocket_recurring_delete",
  "pocket_recurring_set_active", "pocket_recurring_settle", "pocket_recurring_skip",
  "pocket_subscription_set", "pocket_preset_save", "pocket_preset_delete",
]);
// The client and database live in the same private WebView profile. This value is never sent to a server.
const localKey = "Pocket Windows internal local ledger key";
let connection;

function database() {
  connection ??= openDatabase().catch((error) => {
    connection = undefined;
    throw error;
  });
  return connection;
}

async function openDatabase() {
  const db = await PGlite.create({ dataDir: "idb://pocket-windows-ledger", extensions: { pgcrypto } });
  try {
    await db.transaction(async (tx) => {
      await tx.exec(`
        create schema if not exists pocket_windows;
        create table if not exists pocket_windows.migrations (name text primary key);
        create table if not exists pocket_windows.setup (started boolean primary key check (started));
        create table if not exists pocket_windows.backups (day date primary key, ledger jsonb not null);
        create table if not exists pocket_windows.sync_cache (account text primary key, state jsonb not null);
      `);
      const { rows } = await tx.query("select name from pocket_windows.migrations");
      const applied = new Set(rows.map(({ name }) => name));
      if (!applied.size) await tx.exec("create schema extensions; create role anon; create role authenticated;");
      for (const name of migrations) {
        if (applied.has(name)) continue;
        const script = await fetch(new URL(`migrations/${name}`, import.meta.url));
        if (!script.ok) throw new Error(`Pocket is missing a ledger migration (${name}).`);
        await tx.exec(await script.text());
        await tx.query("insert into pocket_windows.migrations values ($1)", [name]);
      }
      if (!applied.size) await tx.query("select public.pocket_setup($1)", [localKey]);
    });
    await db.syncToFs();
    return db;
  } catch (error) {
    await db.close();
    throw error;
  }
}

export async function initializeLedger(openingBalance, date) {
  const db = await database();
  await db.transaction(async (tx) => {
    const { rows } = await tx.query("insert into pocket_windows.setup values (true) on conflict do nothing returning started");
    if (rows.length && openingBalance !== 0) {
      await tx.query("select public.pocket_add($1, $2, 'Starting balance', $3, 'start')", [localKey, openingBalance, date]);
    }
  });
  // Persist the committed transaction before onboarding reloads the app.
  await db.syncToFs();
}

export async function rpc(name, args) {
  const entries = Object.entries(args);
  if (!commands.has(name) || entries.some(([param]) => !/^p_[a-z_]+$/.test(param))) {
    throw new Error("This action requires Pocket Sync.");
  }
  const parameters = ["k => $1", ...entries.map(([param], index) => `${param} => $${index + 2}`)];
  const db = await database();
  return db.transaction(async (tx) => {
    await backupToday(tx);
    const { rows } = await tx.query(`select to_json(public.${name}(${parameters.join(", ")})) as result`,
      [localKey, ...entries.map(([, value]) => value)]);
    return rows[0].result;
  });
}

const toCents = (value) => Math.round(Number(value) * 100);
const dateForBackup = (value) => new Date(value).toISOString().replace(/\.\d{3}Z$/, "Z");
const currencyStorage = "pocket.windows.currency.local";

async function snapshot(tx) {
  const entries = (await tx.query("select *, occurred_on::text as day from public.transactions order by occurred_on, created_at")).rows;
  const rules = (await tx.query("select *, anchor_on::text as anchor from public.recurring order by created_at")).rows;
  const presets = (await tx.query("select * from public.presets order by sort, created_at")).rows;
  return {
    version: 1,
    currency: localStorage.getItem(currencyStorage) || "USD",
    entries: entries.map((entry) => ({
      id: entry.id, cents: toCents(entry.amount), label: entry.label, day: entry.day,
      category: entry.category, ruleID: entry.recurring_id, created: dateForBackup(entry.created_at),
    })),
    rules: rules.map((rule) => ({
      id: rule.id, cents: toCents(rule.amount), label: rule.label, cadence: rule.cadence, anchor: rule.anchor,
      posted: rule.posted_count, total: rule.total_count, active: rule.active, auto: rule.auto,
      category: rule.category, subscription: rule.subscription, once: rule.total_count === 1,
      created: dateForBackup(rule.created_at),
    })),
    presets: presets.map((preset) => ({
      id: preset.id, label: preset.label, cents: preset.amount === null ? null : toCents(preset.amount),
      sign: preset.sign, category: preset.category,
    })),
  };
}

async function backupToday(tx) {
  const now = new Date();
  const day = new Date(now - now.getTimezoneOffset() * 60_000).toISOString().slice(0, 10);
  const { rows } = await tx.query("select 1 from pocket_windows.backups where day = $1::date", [day]);
  if (rows.length) return;
  await tx.query("insert into pocket_windows.backups values ($1::date, $2::jsonb)", [day, JSON.stringify(await snapshot(tx))]);
  await tx.exec("delete from pocket_windows.backups where day not in (select day from pocket_windows.backups order by day desc limit 7)");
}

export async function exportLedger() {
  const db = await database();
  return db.transaction(snapshot);
}

export async function backupDays() {
  const db = await database();
  return (await db.query("select day::text as day from pocket_windows.backups order by day desc")).rows.map(({ day }) => day);
}

export async function readBackup(day) {
  const db = await database();
  const { rows } = await db.query("select ledger from pocket_windows.backups where day = $1::date", [day]);
  if (!rows.length) throw new Error("This daily backup is no longer available.");
  return rows[0].ledger;
}

export async function reorderPresets(ids) {
  const db = await database();
  await db.transaction(async (tx) => {
    await backupToday(tx);
    await tx.query(`
      update public.presets set sort = positions.ordinality - 1
      from unnest($1::uuid[]) with ordinality as positions(id, ordinality)
      where presets.id = positions.id
    `, [ids]);
  });
}

export async function cacheSyncState(account, state) {
  const db = await database();
  await db.query(`
    insert into pocket_windows.sync_cache values ($1, $2::jsonb)
    on conflict (account) do update set state = excluded.state
  `, [account, JSON.stringify(state)]);
}

export async function cachedSyncState(account) {
  const db = await database();
  return (await db.query("select state from pocket_windows.sync_cache where account = $1", [account])).rows[0]?.state;
}

export async function replaceLedger(ledger) {
  if (ledger?.version !== 1 || !Intl.supportedValuesOf("currency").includes(ledger.currency) ||
      !Array.isArray(ledger.entries) || !Array.isArray(ledger.rules) || !Array.isArray(ledger.presets)) {
    throw new Error("Choose a valid Pocket JSON backup.");
  }
  const amount = (cents) => {
    if (!Number.isSafeInteger(cents) || cents === 0 || Math.abs(cents) > 99_999_999_999) {
      throw new Error("This backup has an invalid amount.");
    }
    return cents / 100;
  };
  const date = (value) => {
    if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value) ||
        !Number.isFinite(Date.parse(value)) || new Date(value).toISOString().slice(0, 10) !== value) {
      throw new Error("This backup has an invalid calendar date.");
    }
    return value;
  };
  const id = (value) => {
    if (typeof value !== "string" || !/^[a-f\d]{8}(?:-[a-f\d]{4}){3}-[a-f\d]{12}$/i.test(value)) {
      throw new Error("This backup has an invalid entry identifier.");
    }
    return value;
  };
  const record = (item) => ({ id: id(item.id), label: item.label, category: item.category ?? null });
  const ruleIds = new Set(ledger.rules.map((rule) => id(rule.id).toLowerCase()));
  const transactions = ledger.entries.map((entry) => ({
    ...record(entry), amount: amount(entry.cents), occurred_on: date(entry.day), created_at: dateForBackup(entry.created),
    recurring_id: entry.ruleID && ruleIds.has(id(entry.ruleID).toLowerCase()) ? entry.ruleID : null,
  }));
  const recurring = ledger.rules.map((rule) => {
    if (!Number.isInteger(rule.posted) || rule.posted < 0 || rule.posted > 1_000_000 ||
        (rule.total != null && (!Number.isInteger(rule.total) || rule.total < Math.max(1, rule.posted) || rule.total > 1_000_000)) ||
        typeof rule.active !== "boolean" || typeof rule.auto !== "boolean") throw new Error("This backup has an invalid schedule.");
    return {
      ...record(rule), amount: amount(rule.cents), cadence: rule.cadence, anchor_on: date(rule.anchor),
      posted_count: rule.posted, total_count: rule.total ?? null, active: rule.active, auto: rule.auto,
      subscription: rule.subscription ?? null, created_at: dateForBackup(rule.created),
    };
  });
  const presets = ledger.presets.map((preset, index) => ({
    ...record(preset), sort: index, sign: preset.sign, amount: preset.cents == null ? null : amount(preset.cents),
    created_at: new Date(0).toISOString(),
  }));
  const db = await database();
  await db.transaction(async (tx) => {
    await backupToday(tx);
    await tx.exec("delete from public.transactions; delete from public.recurring; delete from public.presets;");
    for (const [table, rows] of [["recurring", recurring], ["transactions", transactions], ["presets", presets]]) {
      await tx.query(`insert into public.${table} select * from json_populate_recordset(null::public.${table}, $1::json)`,
        [JSON.stringify(rows)]);
    }
  });
  await db.syncToFs();
  localStorage.setItem(currencyStorage, ledger.currency);
}
