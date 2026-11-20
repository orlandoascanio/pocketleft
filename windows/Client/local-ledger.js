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
  const { rows } = await db.query(`select to_json(public.${name}(${parameters.join(", ")})) as result`,
    [localKey, ...entries.map(([, value]) => value)]);
  return rows[0].result;
}
