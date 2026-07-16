# Instruments & xctrace

Instruments is the GUI; `xctrace` is its command-line engine. Learn to record with the right template, read the Time Profiler correctly, and script traces so profiling is repeatable and CI-friendly.

## Profile the right build, on the right hardware

- **Release build, real device** (Common Mistake #1). Debug is unoptimized; the Simulator runs on your Mac. Neither reflects shipping performance. In Xcode: Product ▸ Profile (⌘I) builds Release and launches Instruments.
- Profile the **specific repro**, warmed up (ignore first-launch/JIT noise unless launch is what you're measuring).

## The instrument templates

| Template | Answers |
|----------|---------|
| **Time Profiler** | Where is CPU time spent? (sampled call stacks) |
| **CPU Profiler** / **CPU Counters** | Deeper CPU/core behavior |
| **Allocations** | What's allocated, and what persists? |
| **Leaks** | What's leaked, and who allocated it? |
| **Animation Hitches** | Which frames were late, and why? |
| **Hangs** | When was the main thread blocked? |
| **SwiftUI** | Which view updates cost, and why? |
| **os_signpost** | Your signpost intervals / Points of Interest |
| **Metal / GPU** | GPU-bound rendering cost |

Start from the symptom (see the skill's Quick Reference), add complementary instruments to one trace document when useful (e.g. Time Profiler + os_signpost).

## Reading the Time Profiler call tree

The raw tree is mostly framework frames. Two settings make it usable (Common Mistake #3):

- **Invert Call Tree** — put the leaf (hottest) functions on top, so the code actually burning CPU rises up.
- **Hide System Libraries** — collapse Apple frames so *your* functions dominate.
- **Separate by Thread** — isolate the main thread (UI cost) from background work.
- Expand the heaviest branch; the self-weight (ms / %) points at the function to fix. Double-click to jump to source with per-line samples.

Look for: work on the main thread that isn't UI, unexpectedly hot functions, repeated calls (an O(n²) hiding in a "cheap" helper), and synchronous I/O.

## Memory: Allocations & generations

- **Allocations** → total/persistent bytes, allocation call trees.
- **Generations** (Common Mistake #6): mark a generation, perform one cycle of the action (open→close a screen), mark again. Objects that **persist** each cycle are your accumulation/leak-like growth — far more useful than absolute footprint.
- **Leaks** → truly-unreachable blocks + the responsible allocation stack; fix retain cycles (often a closure capturing `self` — use `[weak self]`, or break delegate cycles).

## xctrace — record & export from the CLI

`xctrace` makes profiling scriptable, repeatable, and CI-capable (Common Mistake #8):

```bash
# List available templates and devices:
xcrun xctrace list templates
xcrun xctrace list devices

# Record a fixed duration against a device + app:
xcrun xctrace record \
  --template "Time Profiler" \
  --device "00008120-0011..." \
  --launch -- com.example.trips \
  --time-limit 20s \
  --output trace.trace

# Or attach to a running process:
xcrun xctrace record --template "Animation Hitches" --attach 1234 --output hitches.trace

# Export the recorded data to structured XML for analysis/diffing:
xcrun xctrace export --input trace.trace --toc                       # table of contents
xcrun xctrace export --input trace.trace --xpath '/trace-toc/run/data/table[@schema="time-profile"]' > profile.xml
```

- `record` captures a trace headlessly; `export` pulls a schema's rows out as XML you can parse.
- A thin **scripted toolchain** — a `record` wrapper that runs a scenario and an `export`+parse step that summarizes the hot frames / hitch count as JSON — lets an agent or CI job "record a new trace or analyse an existing one end-to-end" and compare against a baseline. This is the repeatable alternative to click-by-click profiling.
- Open any `.trace` in Instruments.app for the visual view when you need it.

## Correlate with signposts

Emit `OSSignposter` intervals/Points of Interest (see the `observability` skill) around suspect regions, then add the **os_signpost** instrument to the same trace. Your named phases line up against the samples so you can see *which* phase was expensive, not just *that* something was.

## Pitfalls

- **Debug/Simulator numbers** → meaningless; Release on device.
- **Un-inverted call tree** → drowned in framework frames; invert + hide system.
- **Total memory instead of generations** → misses per-cycle growth.
- **Only manual runs** → no regression guard; script `xctrace` for key scenarios.
