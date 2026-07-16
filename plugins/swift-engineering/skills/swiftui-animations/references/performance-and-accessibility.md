# Performance & Accessibility

Two ways animation goes wrong beyond looking off: it janks, or it excludes users who need less motion. Both have concrete fixes.

## Reduce Motion — non-negotiable

Large movement, zooms, parallax, and spins can cause motion sickness. Read the environment flag and degrade to a cross-fade or nothing (Common Mistake #7 in the skill):

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

// Swap the animation:
.animation(reduceMotion ? nil : .spring, value: isExpanded)

// Or swap the transition:
.transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))

// Strip animation from a whole subtree via transaction:
.transaction { txn in if reduceMotion { txn.animation = nil } }
```

Rules of thumb:
- **Motion that conveys meaning** (a checkmark confirming success) → keep a subtle/opacity version.
- **Decorative motion** (parallax, big zooms) → replace with a fade or remove.
- Prefer opacity/cross-fades as the reduced fallback; they're rarely a problem.
- This is a Human Interface Guidelines requirement — see the `accessibility` and `ios-hig` skills for the broader contract.

## `geometryGroup` — coherent layout animation

When a parent's size/position changes, children may animate from unexpected places because each resolves layout independently. `.geometryGroup()` (iOS 17+) makes a subtree resolve its geometry as a single unit, so it animates coherently (Common Mistake #5 in the skill):

```swift
CardStack()
    .geometryGroup()          // children animate together with the parent's frame change
    .animation(.spring, value: layout)
```

Cheap and layout-only — reach for it whenever a container reshapes and its contents animate oddly.

## `drawingGroup` — rasterize, but measure first

`.drawingGroup()` flattens a subtree into one Metal-rendered layer. It helps when you have **many overlapping shapes/effects** animating together (particles, complex `Canvas`-like art), but it:
- isn't free (an offscreen render pass),
- can break blend modes, some effects, and text crispness,
- should be applied only after profiling shows rasterization is the bottleneck.

```swift
ExpensiveParticleField()
    .drawingGroup()           // only after Instruments confirms it's the win
```

Most jank is **not** rasterization — it's over-animation or layout thrash (below). Use the `performance-profiling` and `metrickit` skills to confirm the cause before adding `drawingGroup`.

## Avoid over-animation and feedback loops

- **Animating huge subtrees** on every change → the compositor works too hard. Scope `.animation(_:value:)` to the smallest view that needs it, not a whole screen.
- **Geometry-read feedback loops** — writing a measured size into state that changes the layout that changes the size re-fires forever, causing jitter. Reduce geometry to a coarse `Equatable` bucket before acting on it (see the `adaptive-ui` skill's `onGeometryChange` guidance).
- **Animating layout-driving values in a `List`/`LazyVStack`** at scale can thrash cell layout; animate transforms (`scaleEffect`, `opacity`, `offset`) rather than intrinsic size where possible — transforms don't re-run layout.
- **`repeatForever` timers left running offscreen** keep the render loop busy; stop them when the view isn't visible (`.onDisappear`, or gate on `scenePhase`).

## Prefer transform animations over layout animations

Transform modifiers (`opacity`, `scaleEffect`, `rotationEffect`, `offset`) animate on the render side without re-running layout. Frame/padding/font-size changes re-run layout every frame. When you have a choice, animate the transform:

```swift
// Cheaper: transform
.scaleEffect(pressed ? 0.96 : 1.0).animation(.snappy, value: pressed)
// Costlier: layout
.frame(width: pressed ? 96 : 100)
```

## Checklist

- [ ] Reduce Motion path provided (fade/none) for anything beyond a subtle change.
- [ ] `.animation(_:value:)` scoped to the smallest affected view.
- [ ] `.geometryGroup()` where a reshaping container animates its children.
- [ ] Transform animations preferred over layout animations where equivalent.
- [ ] `drawingGroup()` only after profiling; `repeatForever` stopped offscreen.
