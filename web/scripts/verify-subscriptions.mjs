import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";

const context = vm.createContext({});
vm.runInContext(readFileSync(new URL("../public/app/subscriptions.js", import.meta.url), "utf8"), context);
const { summarize, isSubscription, membershipArgs } = context.PocketSubscriptions;
const base = { id: "music", amount: -9.99, label: "Music", cadence: "monthly", active: true, once: false, remaining: null, category: "subscriptions" };
assert.equal(isSubscription(base), true);
assert.equal(isSubscription({ ...base, subscription: false }), false);
assert.equal(isSubscription({ ...base, category: "apps", subscription: true }), true);
assert.equal(isSubscription({ ...base, amount: 9.99 }), false);
assert.equal(isSubscription({ ...base, once: true }), false);
assert.equal(isSubscription({ ...base, remaining: 0 }), false);

const rules = [
  ...Object.entries({ weekly: 52, biweekly: 26, monthly: 12, quarterly: 4, yearly: 1 }).map(([cadence]) => ({ ...base, id: cadence, amount: -1, cadence })),
  { ...base, id: "paused", amount: -100, active: false },
  { ...base, id: "rent", category: "bills", amount: -500 },
];
const renewals = [1, 8, 15, 22, 29].map((day) => ({ recurring_id: "weekly", label: "Weekly", amount: -1, due_on: `2026-11-${String(day).padStart(2, "0")}` }));
renewals.push({ recurring_id: "paused", label: "Paused", amount: -100, due_on: "2026-11-10" });
renewals.push({ recurring_id: "rent", label: "Rent", amount: -500, due_on: "2026-11-10" });
const before = JSON.stringify({ rules, renewals });
const summary = summarize(rules, renewals, "2026-11-01", "2026-11-30");
assert.equal(summary.active.length, 5);
assert.equal(summary.paused.length, 1);
assert.equal(summary.other.length, 1);
assert.equal(summary.annual, 9500);
assert.equal(summary.monthly, 792);
assert.equal(summary.upcomingTotal, 500);
assert.equal(summarize(rules, renewals, "2026-11-01", "2026-11-08").upcomingTotal, 200);
assert.equal(JSON.stringify({ rules, renewals }), before, "Viewing Subscriptions must not change payments");
assert.equal(Object.keys(membershipArgs(null, false)).length, 0);
assert.throws(() => membershipArgs(true, false), /Subscriptions update/);
assert.equal(membershipArgs(false, true).p_subscription, false);
console.log("Passed: subscription membership, category independence, cost equivalents, renewal windows, paused exclusion and older-server protection.");
