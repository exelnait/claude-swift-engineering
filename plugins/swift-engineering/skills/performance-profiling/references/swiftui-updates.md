# SwiftUI Updates

Most SwiftUI performance problems are **too many, or too expensive, view updates**. The SwiftUI instrument makes them visible; `Self._printChanges()` makes them debuggable; structuring state well fixes them.

## The SwiftUI instrument

Profile with the **SwiftUI** template (add it alongside Time Profiler / Animation Hitches). It shows:

- **Update lanes / groups** — how long view updates take per frame, bucketed. Long bars = expensive updates that can cause hitches.
- **Cause & Effect** — what *caused* an update (a state/observed change) and what views it re-evaluated. This is the key view: it links the mutation to the `body` re-runs it triggered.
- **Long `body` evaluations** — individual views whose `body` is expensive.

Correlate a scroll/interaction hitch (from Animation Hitches) with the SwiftUI lanes to see which view updated too much or too slowly during that frame.

## `Self._printChanges()` — why did this view re-render?

Drop this at the top of a `body` to log, in the console, exactly which input caused the re-evaluation:

```swift
var body: some View {
    let _ = Self._printChanges()      // prints the property/state that triggered this update
    // …
}
```

If it prints `@self` it re-rendered because its own value changed; a property name tells you which input invalidated it. Use it to catch views re-rendering on inputs they don't actually depend on (over-invalidation).

## Over-invalidation — the usual culprit

SwiftUI re-evaluates a view's `body` when something it reads changes. Problems come from a view depending on **more** than it needs:

- **State too high in the tree.** A `@State` that changes on every keystroke placed on a big parent re-runs the whole subtree's `body`. Push state down to the smallest view that needs it.
- **Passing whole models where a value would do.** A view that takes an entire `@Observable` object re-renders when *any* of its properties change, even ones it doesn't display. With `Observation`, reading only the properties you use narrows this — but passing a leaf value (or a small view that reads just what it needs) is tighter still.
- **Recomputing in `body`.** Expensive work (sorting, formatting, filtering) inside `body` runs every update. Hoist it into the model, memoize, or compute once — `body` should assemble views, not do work.
- **Unstable identity in `ForEach`.** Non-stable ids force teardown/rebuild of rows. Use stable `Identifiable` ids so SwiftUI can diff instead of recreate.

## `Observation` and fine-grained updates

With `@Observable` (the plugin default — see `swiftui-patterns`), SwiftUI tracks the *specific properties* a view reads and updates only when those change. Leverage it:

- Read the minimal set of properties in each view; don't funnel a fat model through a view that only shows one field.
- Split large views so each observes a small slice of state — a change to one field updates only the small view that shows it.
- Avoid forcing dependencies via `id(...)` on large subtrees unless you intend a full rebuild.

## Structural fixes (from the trace to the code)

Once the SwiftUI instrument or `_printChanges` points at a hot/over-updating view:

1. **Narrow the dependency** — read fewer properties; split the view; pass a value instead of the whole model.
2. **Hoist work out of `body`** — precompute in the `@Observable` model; cache formatters.
3. **Stabilize identity** — proper `Identifiable` ids in `ForEach`.
4. **Isolate expensive subviews** — `@Observable` + small views so a change doesn't cascade.
5. **Use `.equatable()` / `EquatableView`** for a subtree that's expensive to diff and whose inputs rarely change, so SwiftUI can skip it when equal.
6. **`.geometryGroup()`** where layout changes cause children to animate/relayout oddly (see `swiftui-animations`).

Then re-profile the same interaction to confirm fewer/cheaper updates.

## Pitfalls

- **Guessing which view is hot** → use the SwiftUI instrument / `_printChanges()`.
- **Passing fat models everywhere** → broad invalidation; read the minimum.
- **Work in `body`** → runs every update; move it to the model.
- **Unstable `ForEach` ids** → rebuild instead of diff; stabilize identity.
