---
name: observability
description: >-
  Use when adding logging, tracing, or diagnostics to app code — the unified logging system (`OSLog`/`Logger`), subsystems & categories, log levels (`debug`/`info`/`notice`/`error`/`fault`), string-interpolation privacy (`.public`/`.private`/`.private(mask:.hash)`) and why dynamic values are redacted by default, viewing logs in Console/`log` CLI/sysdiagnose, and performance tracing with `OSSignposter`/`os_signpost` intervals and Points of Interest visible in Instruments. This is production-grade instrumentation — not `print()`. For field metrics/crash-hang aggregation use `metrickit`; for profiling sessions use `performance-profiling`; this is the logging & signpost layer they build on. Load whenever code should record what happened, redact sensitive data in logs, or mark regions for the profiler.
---

# Observability (Unified Logging & Signposts)

`print()` is invisible in production, unstructured, and leaks data. The unified logging system (`Logger`/`OSLog`) is the real tool: structured, level-filtered, privacy-aware, low-overhead, and viewable live or after the fact via Console and sysdiagnose. Pair it with **signposts** to measure and visualize timed regions in Instruments.

The core principle: **log through a `Logger` with a subsystem/category, at the right level, marking dynamic values `.public` only when you're sure they're safe — and mark timed regions with `OSSignposter` so the profiler can see them.** Never `print()` in shipping code.

## Quick Reference

| Need | Use | Not |
|------|-----|-----|
| A log channel | `Logger(subsystem:category:)` | `print()` / `NSLog` |
| Routine event | `logger.notice("…")` / `.info` | ad-hoc strings |
| Debug-only detail | `logger.debug("…")` | left-in prints |
| Recoverable problem | `logger.error("…")` | swallowing it |
| Serious bug / invariant broken | `logger.fault("…")` | crashing blindly |
| Safe dynamic value in a log | `\(value, privacy: .public)` | assuming it shows |
| Sensitive value | default (redacted) or `.private(mask: .hash)` | `.public` on PII |
| Measure a code region | `OSSignposter` interval | `Date()` diffs |
| Mark a notable moment | signpost event / Points of Interest | scattered logs |

## Core Workflow

1. **Create one `Logger` per subsystem+category** (e.g. subsystem = bundle id, category = feature) — ideally a small shared set so filtering is meaningful.
2. **Log at the right level**: `debug` (dev only, not persisted by default), `info` (persisted while streaming), `notice`/default (persisted), `error` (recoverable), `fault` (bug/invariant). Levels drive what's stored and surfaced.
3. **Interpolate values with privacy in mind** — dynamic strings/numbers are **redacted by default**; add `privacy: .public` only for non-sensitive values, `.private(mask: .hash)` to correlate without exposing.
4. **View logs** in Console.app, the `log` CLI, or a sysdiagnose — filter by subsystem/category/level.
5. **Instrument hot paths** with `OSSignposter` intervals and Points-of-Interest events so Instruments shows durations and correlation.
6. **Hand off to the right skill**: aggregate field data with `metrickit`, profile a session with `performance-profiling` — both read the signposts/logs you emit here.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.**

| Reference | Load When |
|-----------|-----------|
| **[Logging](references/logging.md)** | Setting up `Logger`/`OSLog`, choosing subsystems/categories and levels, format specifiers, performance of logging, and viewing logs in Console / `log` CLI / sysdiagnose |
| **[Privacy & Redaction](references/privacy-redaction.md)** | Controlling what appears — the `.public`/`.private`/`.sensitive` specifiers, `.private(mask: .hash)`, default redaction of dynamic values, PII/secret handling, and audit habits |
| **[Signposts & Instruments](references/signposts-instruments.md)** | Measuring timed regions — `OSSignposter` intervals & events, `os_signpost`, the Points of Interest instrument, correlating signposts with logs, and handing off to `performance-profiling`/`metrickit` |

## Common Mistakes

1. **`print()`/`NSLog` in shipping code.** Prints don't appear in Console for release builds, aren't level-filterable, carry no metadata, and don't respect privacy. Replace every one with a `Logger` call at an appropriate level.

2. **Marking sensitive values `.public`.** Dynamic interpolations are redacted by default *for a reason*. Slapping `privacy: .public` on tokens, emails, file paths, or user content leaks PII into logs that sync to sysdiagnose. Only make genuinely non-sensitive values public; use `.private(mask: .hash)` when you need to correlate.

3. **Everything at one level.** Logging all at `debug` (invisible in prod) or all at `error` (noise, and `error`/`fault` may trigger extra capture) defeats filtering. Match the level to severity.

4. **One giant subsystem/category.** With no structure you can't filter. Use your bundle id as subsystem and a per-feature category so Console queries are useful.

5. **Timing with `Date()` subtraction.** Manual timestamps don't show in Instruments and add measurement error. Use `OSSignposter` intervals so durations appear on the timeline alongside system events.

6. **Logging in hot loops without care.** Even cheap, logging inside a tight per-frame/per-row loop adds up. Gate verbose logging to `debug`, or use signposts (designed for high-frequency) instead of `notice`/`info` spam.

7. **Treating logs as analytics.** Unified logging is for diagnostics, not product metrics; it's not guaranteed-delivery telemetry. For aggregated field metrics use `metrickit`; for product analytics use a proper analytics pipeline.
