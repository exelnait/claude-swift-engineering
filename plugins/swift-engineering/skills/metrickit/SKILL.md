---
name: metrickit
description: Use when collecting real-world app performance metrics and diagnostics correctly — launch time, hangs, scroll/animation hitches, CPU/GPU/memory/disk/network, Metal frame rate, and crash/hang/memory diagnostics — with the modern MetricKit (iOS 27+) `MetricManager` Swift API, and contextualizing them with the StateReporting framework. Covers correct setup (at launch, kept alive), Codable export to a server, and migrating off `MXMetricManager`.
---

# MetricKit (Performance Metrics & Diagnostics)

MetricKit is the **collection** piece of the performance workflow: it gives you real insight into the quality of your app's experience on real devices, in the field. Use it to monitor whether performance is improving or worsening (metrics) and to find which code path caused a problem (diagnostics).

```
collect ──► analyze ──► triage ──► fix ──► (monitor) ──► collect …
  ▲                                                         │
  └──────────────────────  MetricKit is "collect"  ◄────────┘
```

- **Metrics** = your app's ongoing health signal (trends): launch time, hangs, hitches, CPU/GPU/memory/disk/network, Metal frame rate.
- **Diagnostics** = which code path caused a problem (call this when something goes wrong): crashes, hangs, memory exceptions — with backtraces.

## Modern API — iOS 27+ (verify against current docs)

In iOS 27 MetricKit was rebuilt with a **Swift-first `MetricManager` API**, and all the new capabilities (state-aware metrics, Metal frame rate, memory-exception diagnostics, termination categories) are **exclusive to it**. This is newer than this guidance's training data — confirm exact symbols and the minimum OS against current Apple documentation. **Migrate off the legacy `MXMetricManager`** to the new `MetricManager` to get these features. This plugin targets iOS 26+; gate the new API on its actual availability rather than assuming it everywhere.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.**

| Reference | Load When |
|-----------|-----------|
| **[Metrics](references/metrics.md)** | Receiving `metricReports`, metric groups, interval entries, specific metrics (launch/hang/hitch/CPU/GPU/memory/Metal), deriving insights, Codable export & server aggregation |
| **[Diagnostics](references/diagnostics.md)** | Receiving `diagnosticReports`, crash/hang/memory diagnostics, backtraces, termination category, symbolication, sending to a server |
| **[State Reporting](references/state-reporting.md)** | Contextualizing metrics by app state — `StateReporting`, domains, transitions, `ReportableMetadata`, `stateEntries`, encoding by domain, best practices |

## Collecting Correctly (the rules)

1. **Subscribe at app startup.** Create the `MetricManager` and start awaiting `metricReports` / `diagnosticReports` **as early as possible** in launch — delayed subscription loses data.
2. **Keep the manager alive.** Hold a strong reference (a dedicated long-lived service / app-level owner). Reports stream in over time; if the manager is deallocated, the streams stop.
3. **Do it off the main actor.** Process reports in a detached `Task` or a dedicated service so you never block UI; never parse reports on the main thread during launch.
4. **Export, don't just read.** Reports are `Codable` — encode to JSON and send to a server so you can see health across many devices. A single device tells you little.
5. **Aggregate on the server.** Cross-device analysis is a data-science problem: define the dimensions you care about, pick the right statistics, establish a baseline, then watch for regressions.
6. **Contextualize with states.** Blended, app-wide averages hide where problems live. Report meaningful app **states** so metrics/diagnostics are intersected with them (e.g., per tab). See `state-reporting.md`.
7. **Don't over-granularize.** Narrowly-scoped domains and stable, meaningful states only — too many states make the data harder to interpret and add overhead. Validate with the Points of Interest instrument before shipping.

## Connections

- **`swift-diagnostics`** — *development-time* debugging (build issues, memory, navigation). MetricKit is the *production* counterpart: real-device telemetry. Use both.
- **`evaluations`** — the same "collect → analyze → hill-climb on data" discipline, applied to AI feature *quality* rather than runtime performance.
- **`architecture-keeper`** — feed MetricKit baselines/trends into the feature's performance ledger.

## Common Mistakes

1. **Subscribing late.** Creating the `MetricManager` after launch (e.g., in a view that appears later) drops early reports. Subscribe at startup and keep it alive.

2. **Letting the manager deallocate.** A `MetricManager` created in a local scope stops delivering. Own it at app/service scope for the process lifetime.

3. **Only looking at on-device data.** One device's report is anecdote, not signal. Encode the `Codable` reports and aggregate server-side across devices.

4. **Reporting transient UI events as states.** States should be stable, meaningful phases (which tab, which mode), not every momentary UI change. Transient states produce noise and overhead.

5. **Too many states/domains.** Over-granular data is as useless as blended data — and there are upper limits. Scope domains narrowly and plan how you'll interpret each.

6. **Blending metrics across states.** A 15 ms/s average hitch rate can hide a smooth tab (1 ms/s) and a broken one (71 ms/s). Use StateReporting to localize the problem.

7. **Staying on `MXMetricManager`.** The legacy API doesn't expose the new state-aware metrics, Metal frame rate, or memory-exception diagnostics. Migrate to `MetricManager`.
