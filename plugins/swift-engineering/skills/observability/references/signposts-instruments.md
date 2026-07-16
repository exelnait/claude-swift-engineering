# Signposts & Instruments

Signposts mark **timed regions** and **notable moments** in your code so they appear on the Instruments timeline, correlated with system activity. They're the right tool for "how long did this take?" (Common Mistake #5) and for high-frequency marking where logs would be noise.

## `OSSignposter` — modern intervals

```swift
import OSLog

let signposter = OSSignposter(subsystem: "com.example.trips", category: "sync")

func sync() async {
    let state = signposter.beginInterval("Sync", id: signposter.makeSignpostID())
    defer { signposter.endInterval("Sync", state) }

    let fetchState = signposter.beginInterval("Fetch")
    let data = await fetch()
    signposter.endInterval("Fetch", fetchState)

    signposter.emitEvent("Decoded", "count: \(data.count)")   // a point-in-time marker
}
```

- **`beginInterval`/`endInterval`** bracket a region; its duration shows as a bar in Instruments. Pair with `defer` so it always ends.
- **`emitEvent`** drops an instantaneous marker (a phase boundary, a cache miss).
- Give related intervals a shared **`OSSignpostID`** (`makeSignpostID()`) when you have concurrent/overlapping intervals of the same name so Instruments pairs begin/end correctly.
- The convenience wrapper runs a closure as an interval:
  ```swift
  let result = signposter.withIntervalSignpost("Decode") { decode(data) }
  ```

## Points of Interest

Emitting to the special **Points of Interest** category makes your markers appear in that dedicated Instruments track, ideal for annotating a Time Profiler / SwiftUI trace with your own phase boundaries:

```swift
let poi = OSSignposter(subsystem: "com.example.trips", category: .pointsOfInterest)
poi.emitEvent("Did finish first paint")
```

Line these up against Time Profiler samples or Animation Hitches to see *what your code was doing* when a spike occurred — the bridge to the `performance-profiling` skill.

## `os_signpost` (older API)

Pre-`OSSignposter` code uses `os_signpost` with an `OSLog` of type `.pointsOfInterest`:

```swift
let log = OSLog(subsystem: "com.example.trips", category: .pointsOfInterest)
let id = OSSignpostID(log: log)
os_signpost(.begin, log: log, name: "Sync", signpostID: id)
os_signpost(.end,   log: log, name: "Sync", signpostID: id)
```

Prefer `OSSignposter` in new code; recognize `os_signpost` in existing code.

## Viewing in Instruments

1. Profile the app (Instruments → e.g. **Time Profiler**, **Animation Hitches**, or a **os_signpost** instrument).
2. Your intervals appear as named regions; events as flags; Points of Interest in their own track.
3. Correlate a slow interval with the sampled call tree / hitch to find the cause.

Signposts are low-overhead and safe to leave in production builds (they're inert unless a trace is recording), so you can ship them and profile real devices.

## Signposts vs logs vs metrics

- **Signposts** → durations & markers for *profiling* (Instruments). High-frequency-friendly.
- **Logs** (`Logger`) → discrete diagnostic events for *after-the-fact* reading (Console/sysdiagnose).
- **MetricKit** → aggregated *field* metrics (launch time, hangs, memory) across users — see the `metrickit` skill.
- **performance-profiling** skill → driving Instruments/`xctrace` sessions that read these signposts.

Use each for its job: emit signposts around suspect regions, log meaningful events, and let MetricKit/Instruments do the aggregation and visualization.

## Pitfalls

- **Unbalanced intervals** → missing `endInterval`; always `defer` the end.
- **Reusing a plain name for overlapping intervals** → mispaired in Instruments; use distinct `OSSignpostID`s.
- **Signposting everything** → noisy traces; mark the regions you actually investigate.
- **Manual `Date()` timing** → not on the timeline, adds error; use intervals.
