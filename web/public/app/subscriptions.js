"use strict";

// The same schedules as Plan; this view never creates a second charge.
globalThis.PocketSubscriptions = (() => {
  const perYear = { weekly: 52, biweekly: 26, monthly: 12, quarterly: 4, yearly: 1 };
  const isSubscription = (rule) => Number(rule.amount) < 0 && !rule.once && rule.remaining !== 0
    && (rule.subscription ?? (rule.category === "subscriptions"));

  function summarize(rules, upcoming, today, end) {
    const subscriptions = rules.filter(isSubscription);
    const active = subscriptions.filter((rule) => rule.active);
    const paused = subscriptions.filter((rule) => !rule.active);
    const ids = new Set(active.map((rule) => rule.id));
    const renewals = upcoming.filter((item) => ids.has(item.recurring_id) && item.due_on >= today && item.due_on <= end)
      .sort((a, b) => a.due_on.localeCompare(b.due_on) || a.label.localeCompare(b.label));
    const annual = active.reduce((total, rule) => total + Math.round(-Number(rule.amount) * 100) * (perYear[rule.cadence] ?? 0), 0);
    return {
      active, paused, renewals, annual, monthly: Math.round(annual / 12),
      upcomingTotal: renewals.reduce((total, item) => total + Math.round(-Number(item.amount) * 100), 0),
      other: rules.filter((rule) => Number(rule.amount) < 0 && !rule.once && rule.remaining !== 0 && !isSubscription(rule)),
    };
  }

  // Undefined leaves membership untouched, allowing older servers/clients to keep working.
  function membershipArgs(choice, supported) {
    if (choice == null) return {};
    if (!supported) throw new Error("This sync server needs the Subscriptions update before it can save membership changes.");
    return { p_subscription: choice };
  }

  return { isSubscription, summarize, membershipArgs };
})();
