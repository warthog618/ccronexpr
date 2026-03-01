# Timezone Scan Findings

`ccronexpr_test` is deterministic in UTC builds, but local-time builds (`CRON_USE_LOCAL_TIME`) expose timezone-specific behavior around DST transitions and historical offset changes.

## Repro

Run:

```bash
make test-scan-timezones
```

This compiles test variants and scans `/usr/share/zoneinfo` (excluding `posix/` and `right/` mirrors), printing failing `(setting, timezone)` pairs and the last failing test context.

## Current Canonical Warning Zones

- `Africa/Cairo`
- `America/Asuncion`
- `America/Coyhaique`
- `America/Punta_Arenas`
- `America/Santiago`
- `Antarctica/Palmer`
- `Pacific/Apia`

These zones no longer fail tests by default. They emit warnings in `check_fn_line` when an expected local timestamp is nonexistent and libc normalizes it.

## Warning Classes

1. Missing local-midnight instants:
- Expected `..._00:00:00`, got `..._01:00:00` (example: `Africa/Cairo`, `Pacific/Apia`, `America/Asuncion`).
- These zones have DST jumps around local midnight in affected years.

2. Date skip around midnight cron:
- Example (`America/Santiago` family), `0 0 0 * * *` from `2012-09-01_14:42:43` returns `2012-09-03_00:00:00` instead of `2012-09-02_00:00:00`.
- Transition at `2012-09-01 23:59:59 -> 2012-09-02 01:00:00` (no `00:xx` on Sep 2 local clock).

3. Invalid-date backwards search bug:
- fixed by hardening `find_day()` loop exhaustion:
  - impossible schedules such as `0 0 0 31 6 *` now correctly return `CRON_INVALID_INSTANT` for both `cron_next` and `cron_prev`.

## Engine Behavior

Strict candidate validation is available in scheduler evaluation (compile with `-DCRON_STRICT_MATCH`):

- After `do_nextprev`, validate that produced local calendar still matches expression fields.
- If not, advance by one second in timeline and retry.
- Ensure monotonic progress (`next > seed` for `cron_next`, `prev < seed` for `cron_prev`) to avoid loops.
- Keep an explicit guard counter and return `CRON_INVALID_INSTANT` on exhaustion.
