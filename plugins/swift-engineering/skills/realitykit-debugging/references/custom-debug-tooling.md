# Custom Debug Tooling

Everything that makes RealityKit's ECS good for building apps also makes it good for **debugging** them. When a bug is specific to your own system's logic — a state machine, a targeting algorithm, anything the built-in inspector has no concept of — build debug-only entities, components, and visualizations out of the same primitives you already use, and the RealityKit debugger displays them for free.

## Making the invisible visible

Many systems drive entities that have no mesh of their own — an attractor point, a spawn location, a trigger volume. Add plain visible model entities at those positions purely for debugging, so you can see where the system thinks things are instead of inferring it from behavior.

## Custom components as inspector panels

Give each debug entity a component that stores exactly the values you want to see — state, counters, references to other entities:

```swift
#if DEBUG
struct AttractorDebugComponent: Component {
    enum State { case vacant, attracting, occupied }
    var state: State = .vacant
    var target: Entity?          // the debugger renders entity references as clickable links
}
#endif
```

The debugger can display most of the types you'll regularly reach for: numbers and enums show up as plain values, and an **entity reference becomes a clickable link** straight to that entity's own inspector. That link is exactly how you'd chase a targeting bug end to end — an attractor's debug component says which robot it's targeting; click through to the robot and inspect *its* components to find out why it's still tagged as a valid target when it shouldn't be. Richer data works too: render a Swift Chart to a `UIImage` and store that as a property to see it inline in the inspector.

## Grouping debug entities

Put every debug-only entity under a single **invisible parent entity**, so none of it appears in normal play. Give that parent its own custom component to surface **system-wide** state (counts, aggregate status) alongside the per-instance state on each child. From the hierarchy outline, secondary-click the parent to open its context menu and toggle the whole visualization's visibility on or off without touching code.

## Compiling it out of release

Wrap the entities, components, and any systems that only exist to support them in `#if DEBUG` / `#endif`:

```swift
#if DEBUG
// debug-only entities, components, and the system that updates them
#endif
```

This removes the whole apparatus from release builds at compile time — no runtime performance cost, no code-size cost, and no need to gate any of it behind a runtime flag.

## Profiling with RealityKit Trace

The entity-hierarchy debugger answers "what's wrong" — it's not built for "what's slow." When you need to profile rendering and performance (frame time, GPU cost, where time is actually going), use **RealityKit Trace** instead. `// confirm exact tool name/location and current capabilities against Apple documentation` For the general Instruments recording/reading workflow — templates, call trees, correlating with your own signposts — see the `performance-profiling` skill; RealityKit Trace is the RealityKit-specific counterpart to that same discipline.

## Common mistakes

1. **Shipping debug visualizations in release builds.** Always gate the entities, components, and any supporting systems behind `#if DEBUG`.
2. **Leaving debug entities loose in the hierarchy instead of grouped under one invisible parent.** Grouping is what makes the whole visualization toggleable in one click and keeps it out of the way of your real scene.
3. **Storing debug state in local variables instead of a `Component`.** Only component data shows up in the inspector — a local variable is invisible to the debugger no matter how useful it would be to see.
4. **Reaching for the entity-hierarchy debugger to investigate a performance problem.** That's what it's not for — use RealityKit Trace (or `performance-profiling`) when the question is about speed, not correctness.
