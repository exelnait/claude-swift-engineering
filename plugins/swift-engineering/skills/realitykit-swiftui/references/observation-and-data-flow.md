# Observation and Two-Way Data Flow

> Observable entities ship in the 2025 (visionOS 26) release and are newer than this guidance's training data. Confirm exact type names and property names against current Apple documentation.

Before visionOS 26, data flowed one direction: SwiftUI → RealityKit, through `RealityView`'s `update` closure. You could push SwiftUI state onto entities, but an entity had no way to tell SwiftUI it had changed on its own. Observable entities close the loop: a RealityKit `Entity` can now act as a model object and drive SwiftUI views directly — RealityKit → SwiftUI, no `update` closure involved.

## Reading entity.observable

```swift
struct MinimapDot: View {
    var robot: Entity

    var body: some View {
        let position = robot.observable.position   // confirm exact API — reading this creates a SwiftUI dependency
        DotView().offset(x: CGFloat(position.x) * scale, y: CGFloat(position.z) * scale)
    }
}
```

Read an entity's `observable` property to watch its `position`, `scale`, and `rotation`, its `children` collection, and its full `components` set — including your own custom components. Two ways to observe: lean on SwiftUI's built-in observation tracking (just read the property inside a view's `body`, as above), or call `withObservationTracking` directly for non-view code.

As the entity's transform changes — a robot walking a greenhouse, driven entirely by RealityKit systems or physics — every dependent SwiftUI view (a minimap dot, a HUD readout) re-renders on its own. SwiftUI → RealityKit still works exactly as before: set values on entities/components inside `update`, or in any gesture/event handler.

## The infinite-loop hazard

Reading an observable property inside a view's `body` creates a dependency: when it changes, SwiftUI reruns `body`. `RealityView`'s `update` closure is special — treat it **as an extension of the containing view's body**. SwiftUI calls `update` whenever *any* state the view depends on changes, not only the state the closure itself happens to read.

So: write to an observed property inside `update` → that changes state the view depends on → SwiftUI invalidates the view → `update` runs again → it writes again → infinite loop.

Rules that avoid it:

- **Don't modify observed state inside `update`.**
- Modifying entities you are **not** observing is always safe — no dependency, no loop.
- If you must write an observed property from `update`, read the current value first and skip the write when it's unchanged. That breaks the cycle.
- `make` is **not** in the view's observation scope — reading an observable property there creates no dependency — and `make` never reruns after first appearance anyway, so it's inherently safe, not dangerous.
- A **system's** `update(context:)` and **gesture closures** run entirely outside the view-body observation scope. Both are safe places to mutate observed entities.

## You may not need `update` at all

Since an `Entity` can now be a view's state directly, code that used to live in `update` purely to push SwiftUI state onto entities can often instead mutate the entity right where that state naturally changes — a button action, a gesture closure, a system's per-frame update. Fewer reasons to write an `update` closure means fewer chances to build the loop above.

## Splitting views

If you do hit a loop — or just excess re-rendering — split large views into small, self-contained views that each depend on only the state they actually use. A change to an entity one sibling view never reads then can't invalidate it. Good for correctness, good for performance.

## Common mistakes

1. **Writing an observed property inside `update`.** The single most common way to build this loop by accident; see the rules above.
2. **Treating `make` with the same caution as `update`.** It's the opposite: reads there don't establish dependencies and it never reruns, making it the *safe* closure, not a risky one.
3. **One giant view observing an entire scene's worth of entities.** Any single change re-evaluates all of it. Split into focused subviews that each read only what they need.
4. **Keeping an `update` closure "just in case."** With observable entities, many apps no longer need one — a vestigial `update` is one more place a loop can sneak in.
5. **Over-applying the caution to non-observed entities.** Mutating an entity your view isn't reading from is always fine; the loop risk only exists for state the view actually depends on.
