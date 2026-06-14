# Metrics

> The `MetricManager` Swift API is iOS 27+ and newer than this guidance's training data. Confirm exact symbols against current Apple documentation.

Metrics are your app's **ongoing health signal** — they tell you whether an area of performance is trending better or worse across all your users.

## What MetricKit measures

| Area | Metrics | Why it matters |
|------|---------|----------------|
| Responsiveness | Launch time (e.g., time to first draw), **hangs**, animation/**scroll hitches** | How responsive and smooth the app feels; a slow launch loses users |
| Resource use | CPU, **GPU**, disk writes, network transfers | How hard the app works and its effect on device/battery health |
| Games (iOS 27) | **Metal frame rate** | Render performance — key for games |

Many metrics arrive as **histograms** (counts bucketed by range). Example: a "time to first draw" histogram shows how many launches fell in each time bucket over the day (e.g., most launches 510–540 ms, with a few outliers).

## Report structure

```
MetricReport
└── intervalEntries        // a full-day aggregated entry + smaller (≈few-hour) breakdown windows
     └── metric groups     // .cpu, .memory, .display, .gpu, …  (a breakdown appears only if it has data)
          └── metrics      // individual values for that group
```

## Receiving reports (set up at launch, keep alive)

`MetricManager` is the entry point. Subscribe **at app startup** in a long-lived owner so you don't lose early data, and process off the main actor.

```swift
import MetricKit

actor MetricsService {
    private let manager = MetricManager()      // hold a strong, long-lived reference

    func start() {
        Task.detached { [manager] in
            for await report in manager.metricReports {
                await Self.handle(report)
            }
        }
    }
}
```

Kick this off as early as possible (e.g., from your `App` init / a startup service). If the manager is deallocated, the stream stops delivering.

## Export to a server (Codable)

`MetricReport` is `Codable`. The simplest correct path is to encode the whole report and upload it:

```swift
let data = try JSONEncoder().encode(report)
// upload `data` to your analytics endpoint
```

Sending the full report keeps the door open for any analysis later. Cross-device aggregation is where the signal is — a single device is anecdote.

## Reading specific values

When you only want one group/metric, walk the structure:

```swift
for interval in report.intervalEntries {
    let memoryMetrics = interval.metrics(in: .memory)   // filter to a group
    for metric in memoryMetrics {
        switch metric {
        case .peakMemory(let value):
            record("peakMemory", value)
        default:
            break
        }
    }
}
```

## Deriving your own insights

Combine raw values into rates that are comparable over time. Example from the session: total hang time of ~3 s over 30 min of use → a **hang rate of ~6 s/hour**. Aggregated across devices, derived rates like this become a measurable trend you can watch.

## Analyze & monitor (server side)

Analyzing across all devices is a data-science problem:

1. **Ingest** every report into a store.
2. **Aggregate** along the dimensions you care about (app version, device class, state — see `state-reporting.md`).
3. **Choose statistics** that fit the question (percentiles for latency, rates for hangs/hitches, histograms for distributions).
4. **Baseline**, then **monitor** to detect regressions and improvements.

Once you've established a baseline and spot a problem, move to the triage phase with **diagnostics** (`diagnostics.md`).
