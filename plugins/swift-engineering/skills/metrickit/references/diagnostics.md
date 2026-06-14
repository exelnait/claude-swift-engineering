# Diagnostics

> iOS 27+ `MetricManager` API. Confirm exact symbols against current Apple documentation.

Where metrics tell you *that* something is trending wrong, **diagnostics tell you which code path caused it** — so they drive the **triage** phase. When something goes wrong (a crash, a hang), the system captures a diagnostic **on device** and delivers it to your app **immediately** through MetricKit.

## What's inside a diagnostic

Diagnostics are structured and typically include a **backtrace** — the exact call stack at the time of the event — plus type-specific detail.

| Diagnostic | Key detail |
|------------|------------|
| **Crash** | Backtrace, **reason** (why terminated), **exception type** (what kind of failure), and (iOS 27) a **termination category** indicating how the crash was accounted for in metrics |
| **Hang** | Backtrace of the main-thread stall |
| **Memory exception** (iOS 27) | Insight into a termination for exceeding the memory limit |
| CPU / disk-write exceptions | Backtrace + the offending resource usage |

The **termination category** (iOS 27) lets you correlate a rise in abnormal terminations in your *metrics* directly with individual *diagnostics*.

## Receiving diagnostics (same discipline as metrics)

Await `diagnosticReports` on your `MetricManager`, started at launch on a detached task / dedicated service.

```swift
Task.detached { [manager] in
    for await report in manager.diagnosticReports {
        let data = try? JSONEncoder().encode(report)   // DiagnosticReport is Codable
        // upload `data` to your analytics server
    }
}
```

## Routing by diagnostic type

Reports are structured, so switch on the cases and process each kind differently:

```swift
for diagnostic in report.diagnostics {
    switch diagnostic {
    case .crash(let crash):
        let backtrace = crash.backtrace
        let reason    = crash.terminationReason
        let category  = crash.terminationCategory   // iOS 27
        upload(crash: backtrace, reason, category)
    case .hang(let hang):
        process(hang)                                // handle hangs differently
    default:
        break
    }
}
```

## Reading a backtrace to find the fault

A symbolicated backtrace starts in the system (e.g., thread start) and flows downward into your app's code. Follow the frames down to the deepest point in *your* code where execution stopped — that's the failure site.

```
thread start (system)
  …
  ExpenseApp.ReportsView.body
  ExpenseApp.submitReport()    ← execution reaches here and stops → point of failure
```

Target your fix at that function, then go back to monitoring its metrics to confirm the fix.

## Best practices

- **Symbolicate** crash/hang backtraces (keep your dSYMs) so frames are actionable.
- **Correlate with metrics:** when a metric like abnormal terminations trends up, use the termination category to tie it to specific diagnostics.
- **Group by app state** (see `state-reporting.md`) to learn *under what conditions* the crash/hang happened, not just where in the code.
- **Don't block on delivery:** diagnostics arrive immediately and possibly in bursts — encode and hand off to the network/service quickly, off the main actor.
