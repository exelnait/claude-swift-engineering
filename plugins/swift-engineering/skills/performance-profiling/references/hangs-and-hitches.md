# Hangs & Hitches

Two distinct UI-responsiveness problems, often confused (Common Mistake #4):

- **Hang** — the **main thread is blocked**, so the app can't respond. Duration: hundreds of ms to seconds. Symptom: frozen UI, spinner, "app not responding."
- **Hitch** — a **single frame (or few) is late** during otherwise-smooth animation/scrolling. Duration: milliseconds. Symptom: a stutter/jank in motion.

Different instruments, different fixes. Both trace back to doing too much on the main thread at the wrong time.

## The render loop (why hitches happen)

Each frame the system must **commit** (SwiftUI/Core Animation build the update), **render** (GPU draws), and **present** (show on the display) within the frame budget (~8.3 ms at 120 Hz ProMotion, ~16.7 ms at 60 Hz). Miss the deadline → the previous frame is shown again → a hitch. Hitches are usually **commit-phase** cost (too much layout/updating on the main thread) or occasionally GPU-bound render cost.

## Diagnosing hitches

Use the **Animation Hitches** instrument (or Core Animation):

- **Hitch ratio** — ms of hitch time per second of animation; the headline metric. Lower is better; Apple's guidance targets keeping it small. Track it before/after.
- Find the late frames on the timeline; expand to see whether the overrun is in **commit** (your code — layout, `body`, expensive updates) or **render** (GPU/offscreen passes, blurs, shadows, large blends).
- Cross-reference the **SwiftUI** instrument (see `swiftui-updates.md`) — a hitch during scrolling is frequently an over-expensive `body` or too many view updates that frame.

Fixes:
- Move non-UI work off the main thread (async/`@ModelActor`, background queues) so the commit phase is lean.
- Reduce per-frame layout: prefer transform animations (`scaleEffect`/`opacity`/`offset`) over animating intrinsic size (re-runs layout) — see the `swiftui-animations` performance reference.
- Cut expensive render effects (large shadows, blurs, `drawingGroup` misuse, offscreen passes) on animating content.
- For lists/grids: lighter cells, stable identity, avoid recomputing per row; page/aggregate large data.

## Diagnosing hangs

Use the **Hangs** instrument (or Time Profiler filtered to the main thread). Also: Xcode's **Thread Performance Checker** and on-device **Hang detection** (Settings ▸ Developer, and MetricKit's `MXHangDiagnostic` from the `metrickit` skill) surface hangs from real use.

A hang is main-thread synchronous work that should be elsewhere:
- **Synchronous I/O / network** on the main thread → make it `async`.
- **Heavy computation** (parsing, image processing, big sorts) on the main thread → move to a background task/actor, return results to the main actor.
- **Large SwiftData/Core Data fetches** on the main context → use a `@ModelActor` (see `swiftdata`).
- **Blocking locks / semaphores** on the main thread → restructure with async/await; never `DispatchSemaphore.wait()` on main.
- **Main-thread `Data(contentsOf:)`** or synchronous file reads → async file APIs / background.

The pattern is always the same: identify the blocking call in the main-thread stack, move it off, and hop back to the main actor only to apply results.

## Off-main-thread, the modern way

```swift
// Heavy work off the main actor, UI update back on it:
Task {
    let processed = await Task.detached(priority: .userInitiated) {
        expensiveTransform(rawData)          // runs off the main actor
    }.value
    self.result = processed                  // back on MainActor (self is @MainActor)
}
```

Prefer structured concurrency and actors over manual GCD; annotate UI types `@MainActor` and let heavy work live in `nonisolated`/detached contexts or dedicated actors (see the `modern-swift` skill).

## Verify with numbers

- Record the hitch ratio / hang duration for the repro **before** the fix.
- Apply one change; re-record the same scenario.
- Confirm the number dropped and no new hitches/hangs appeared elsewhere (Common Mistake #5).

## Pitfalls

- **Treating a hang like a hitch** (or vice-versa) → wrong instrument, wasted time. Freeze = hang; stutter-in-motion = hitch.
- **Animating layout-driving properties** → per-frame layout → hitches; animate transforms.
- **Moving work off-main but hopping back too often** → main-thread churn; batch results.
- **No baseline** → can't prove improvement.
