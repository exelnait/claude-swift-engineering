# State Reporting (Contextualized Metrics)

> The `StateReporting` framework pairs with the iOS 27+ `MetricManager` API. Confirm exact symbols against current Apple documentation.

By default, MetricKit metrics and diagnostics are the **overall** picture — blended across all usage. That hides where problems actually live. The **StateReporting** framework lets you report meaningful states so MetricKit aggregates metrics/diagnostics **as a function of those states**.

## Why it matters

> An expense app reports an app-wide scroll-hitch rate of **15 ms/s** — a blended average over the Reports tab and the Spending tab. After reporting per-tab states, the truth emerges: **Spending = 1 ms/s** (smooth), **Reports = 71 ms/s** (critical). Now you know exactly where to optimize.

## Core concepts

- **State** — information *you define* describing the app's configuration/behavior (e.g., which tab is active).
- **Domain** — an area/function of the app. **A domain has exactly one active state at a time.** Use **separate domains** for things that vary independently (so multiple states can be "in flight" together).
- **Transition model** — there are no start/end pairs. Your app reports *the state it is moving to*; MetricKit tracks how long it stays there.

> Example of independent domains: a **tab** domain (Reports / Spending) and an **experiment** domain (small-batch vs large-batch fetch). Putting them in separate domains yields separate metrics per tab *and* per batch size.

## Reporting states

```swift
import StateReporting

// 1. Define a domain (reverse-DNS) and register it when you set up MetricManager.
let tabDomain = StateDomain("com.example.expense.tab")
let reporter = StateReporter(domain: tabDomain)

// 2. Report the transition as the app enters a state.
reporter.transition(to: "Reports")
```

### Adding structured metadata

Attach richer detail with a `ReportableMetadata` type:

```swift
@ReportableMetadata
struct ViewConfiguration {
    var listSize: ListSize     // .small / .medium / .large
    var isSorted: Bool
}

let reporter = StateReporter(domain: tabDomain, metadataType: ViewConfiguration.self)

reporter.transition(
    to: "Reports",
    metadata: ViewConfiguration(listSize: .large, isSorted: true)
)
```

## Reading state-aware metrics

`MetricReport` gains a `stateEntries` property (empty until you report states). Each state gets its own `StateEntry` with metric values aggregated over the time spent in that state — alongside the existing `intervalEntries`.

## Exporting grouped by domain

Configure the encoder to group state entries by reporting domain:

```swift
let encoder = JSONEncoder()
encoder.userInfo[.encodingFormatKey] = MetricReport.EncodingFormat.byStateReportingDomain
let data = try encoder.encode(report)
// both stateEntries and intervalEntries are grouped by each domain/state
```

## Best practices

- **Scope domains narrowly** — one app area per domain, so each area's data is interpretable on its own.
- **States = stable, meaningful phases**, not transient UI events. Ask: if a regression appears in this state, does it tell me enough to target a fix?
- **Plan the number of states/domains.** Too many → over-granular data that's *harder* to interpret, plus overhead. There are upper limits on the number of states.
- **Validate before shipping** with the **Points of Interest** instrument — confirm the states you report match what you expect.
