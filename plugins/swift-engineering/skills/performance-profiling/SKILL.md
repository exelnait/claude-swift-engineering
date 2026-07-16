---
name: performance-profiling
description: >-
  Use when investigating a performance problem with Instruments — profiling CPU/memory/animation, driving `xctrace` from the command line to record and export traces, reading a Time Profiler call tree, diagnosing main-thread hangs and animation hitches (frame drops, hitch ratio), and using the SwiftUI instrument's update lanes / cause-and-effect to find expensive `body` re-evaluations and over-invalidation. Complements `metrickit` (aggregated field metrics from real users) and `observability` (the `OSSignposter` markers this reads) and `swift-diagnostics` (build-time issues) — this skill is the interactive/scriptable *profiling* layer. Load when something is slow, janky, hangs, or uses too much memory, and you need to measure the cause rather than guess.
---

# Performance Profiling (Instruments & xctrace)

Performance work has one rule: **measure, don't guess.** Instruments (and its CLI, `xctrace`) records what the app actually does — where CPU goes, what blocks the main thread, why frames drop, which SwiftUI views re-render — so you fix the real bottleneck instead of the one you assumed. This skill is the profiling loop that turns "it feels slow" into a specific, evidenced cause.

The core principle: **reproduce the slow path under a trace, read the evidence (call tree, hitches, update lanes), fix the top cause, and re-measure.** Signposts (`observability`) annotate your traces; MetricKit tells you *which* problems matter in the field; this skill finds *why* they happen.

## Quick Reference

| Symptom | Instrument | Look for |
|---------|-----------|----------|
| High CPU / slow operation | **Time Profiler** | Heaviest stack frames in the call tree |
| UI freezes / beachball | **Hangs** / Time Profiler (main thread) | Synchronous work on the main thread |
| Janky scrolling/animation | **Animation Hitches** | Hitch ratio, long commits, frame overruns |
| SwiftUI re-rendering too much | **SwiftUI** | Update lanes, long `body`, cause & effect |
| Memory growth | **Allocations** | Persistent growth, generations |
| Leaks | **Leaks** | Leaked blocks + responsible frame |
| Your own phase boundaries | **os_signpost / Points of Interest** | Signpost intervals (from `observability`) |

## Core Workflow

1. **Reproduce reliably.** Find the exact steps that trigger the slowness; profiling noise-free repro is half the battle. Profile a **Release** build on a **real device** for realistic numbers.
2. **Pick the instrument** matching the symptom (table above) and record while you perform the slow action.
3. **Read the evidence** — the Time Profiler call tree (invert + hide system to find your heaviest code), the hitch timeline, the SwiftUI update lanes.
4. **Correlate with your signposts** (`observability`) to line up "what the app was doing" with the spike.
5. **Fix the top cause** — usually main-thread work to move off, an algorithm to change, allocations to cut, or SwiftUI invalidation to narrow.
6. **Re-measure** the same repro to confirm the fix and catch regressions. Script it with `xctrace` for repeatability/CI.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.**

| Reference | Load When |
|-----------|-----------|
| **[Instruments & xctrace](references/instruments-xctrace.md)** | Recording and reading traces — the instrument templates, profiling a Release build on device, reading/inverting the Time Profiler call tree, and driving `xctrace record`/`export` from the CLI (a scriptable, CI-friendly, repeatable profiling toolchain) |
| **[Hangs & Hitches](references/hangs-and-hitches.md)** | UI freezes and dropped frames — main-thread hangs (definition, detection, fixing), animation hitches and the hitch ratio, the render loop (commit/render/present), and moving work off the main thread |
| **[SwiftUI Updates](references/swiftui-updates.md)** | SwiftUI re-rendering cost — the SwiftUI instrument's update lanes & cause-and-effect graph, expensive `body`, over-invalidation, `Observation` and fine-grained updates, `Self._printChanges()`, and structural fixes |

## Common Mistakes

1. **Profiling a Debug build in the Simulator.** Debug builds are unoptimized and the Simulator uses your Mac's CPU/GPU — numbers are meaningless for real performance. Always profile a **Release** (optimized) build on a **real device**.

2. **Guessing instead of measuring.** "It must be the network / the loop / SwiftData" — profile first. The bottleneck is routinely somewhere you didn't suspect; the call tree tells the truth.

3. **Reading the call tree without inverting / hiding system libraries.** The raw tree is dominated by framework frames. **Invert** the call tree and **hide system libraries** so your heaviest *own* code rises to the top.

4. **Confusing a hang with a hitch.** A **hang** is the main thread blocked (seconds; UI frozen); a **hitch** is a missed frame during otherwise-fine animation (milliseconds; jank). They have different instruments and fixes — see the hangs & hitches reference.

5. **Optimizing without a baseline.** Without a recorded before-number you can't prove the change helped (or that it didn't regress elsewhere). Measure, change one thing, re-measure the same repro.

6. **Ignoring memory generations.** Chasing "total memory" instead of using **generations** in Allocations (mark, do the action, mark) to find what *persists* per cycle. Growth-per-cycle is the leak-like signal, not absolute footprint.

7. **No signposts to orient the trace.** A trace with no markers is hard to read. Emit `OSSignposter` intervals (`observability`) around suspect regions so Instruments shows *your* phases against the samples.

8. **One-off manual profiling only.** Manual runs don't catch regressions. Script `xctrace record`/`export` so a key scenario can be profiled repeatably (and in CI) with comparable output.
