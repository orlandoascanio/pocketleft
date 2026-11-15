# Memory and energy: 1.5.1

The November 15, 2026 review found a physical footprint of about 74 MB, a lifetime peak of 128 MB
after five days, and approximately 0.8% average CPU in a short sample of the running 1.4.1 app.
Pocket held no sleep-prevention assertions. These observations did not establish exact battery
drain or prove the absence of memory leaks; inspection of the hardened executable was restricted.

## Changes

- Sync uses one timer scheduled after each completed attempt, with tolerance to let macOS coalesce work.
  Normal intervals are 30 seconds while active, five minutes in the background, and 15 minutes in
  Low Power Mode. Failures double the interval up to 30 minutes. A revoked key stops automatic
  retries until reconnecting or an explicit retry. Edits and explicit retries sync immediately;
  activation and day checks also sync immediately when no failure delay is in effect.
  Local-only accounts have no sync timer. The daily payment check also has timer tolerance.
- Currency formatters are reused through a bounded, locked cache with separate formatting modes,
  currencies, and locales. Mutable formatter state cannot bleed between whole-unit, fractional,
  and compact amounts or between concurrent callers.
- Overview prepares sorted history and running balances when entries change, and filters when the
  search query changes. Sync status updates do not repeat that work. History initially renders
  100 entries, with a button to show more. Filtering, counts, CSV export, and running balances
  continue to use the complete ledger.

## Focused formatting benchmark

On the same development machine, optimized Swift builds and three iterations per size gave these
median times for `Money.string` with en_US/USD amounts:

| Calls | Before | After |
| --- | --- | --- |
| 1,000 | 48.35 ms | 1.31 ms |
| 10,000 | 461.54 ms | 9.34 ms |

This is a formatting microbenchmark, not a measurement of whole-app performance or battery savings.
To repeat it from `mac/`:

```sh
swiftc -O Sources/PocketCore/Money.swift Benchmarks/main.swift -o /tmp/pocket-money-benchmark
/tmp/pocket-money-benchmark
```

The benchmark also prints a reused-formatter reference and checks output-length checksums. The
functional tests separately check currencies, locales, precision, formatting modes, and concurrent use.

## Verification and remaining work

The full Swift suite reports 30 core tests and 85 app tests, with no failures; two native-preview tests
are opt-in and skipped in the normal run. Coverage includes duplicate-safe offline sync, revoked-key
automatic retries and reconnecting, polling intervals and retry caps, concurrent currency formatting,
and history filtering with full-ledger running balances across page boundaries.

The server still returns full account history on a state request. A revision check or delta protocol
would further reduce transfer and decoding for large accounts and requires coordinated server/client
work. Decorative mascot blinking has not changed. A controlled release-build comparison of open and
closed windows, large ledgers, allocation growth, and energy use is still needed to quantify the
whole-app effect. The earlier desktop inspection timed out.
