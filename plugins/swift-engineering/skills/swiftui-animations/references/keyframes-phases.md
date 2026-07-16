# Phase & Keyframe Animators

For motion with more than one step, don't nest `withAnimation`s (Common Mistake #6). Two declarative tools cover it: **`phaseAnimator`** for a sequence of discrete states, **`keyframeAnimator`** for several properties on independent timelines.

## `phaseAnimator` — a sequence of discrete phases

You give an ordered list of phases; SwiftUI walks through them, animating between each with the curve you specify per transition. Great for attention bounces, multi-step reveals, loading pulses.

**Self-running loop** (cycles through phases forever):

```swift
Image(systemName: "bell.fill")
    .phaseAnimator([1.0, 1.3, 1.0]) { view, scale in
        view.scaleEffect(scale)
    } animation: { scale in
        .spring(duration: 0.3)
    }
```

**Trigger-driven** (runs the sequence once each time `trigger` changes):

```swift
enum Shake: CaseIterable { case center, left, right }

LoginButton()
    .phaseAnimator(Shake.allCases, trigger: failedAttempt) { view, phase in
        view.offset(x: phase == .left ? -8 : phase == .right ? 8 : 0)
    } animation: { _ in
        .snappy(duration: 0.1)
    }
```

- The closure receives `(content, phase)` and returns the styled view for that phase.
- `animation:` returns the curve for entering each phase (can differ per phase).
- Use an enum of `CaseIterable` phases when steps are named states; an array of values when it's a numeric sweep.

## `keyframeAnimator` — independent property tracks

When several properties animate on **different timelines** (scale peaks early, rotation runs the whole time, vertical offset does a bounce), keyframes give each its own track over a shared clock.

```swift
struct JumpValues { var scale = 1.0; var yOffset = 0.0; var rotation = Angle.zero }

Avatar()
    .keyframeAnimator(initialValue: JumpValues(), trigger: didWin) { view, value in
        view
            .scaleEffect(value.scale)
            .rotationEffect(value.rotation)
            .offset(y: value.yOffset)
    } keyframes: { _ in
        KeyframeTrack(\.yOffset) {
            SpringKeyframe(-60, duration: 0.3)
            SpringKeyframe(0, duration: 0.4, spring: .bouncy)
        }
        KeyframeTrack(\.scale) {
            CubicKeyframe(1.2, duration: 0.3)
            CubicKeyframe(1.0, duration: 0.4)
        }
        KeyframeTrack(\.rotation) {
            LinearKeyframe(.degrees(360), duration: 0.7)
        }
    }
```

- Each `KeyframeTrack` targets one key path of your value type and defines its own keyframes; tracks run in parallel over the combined duration.
- Keyframe types: `LinearKeyframe`, `CubicKeyframe` (smooth), `SpringKeyframe`, `MoveKeyframe` (jump, no interpolation).
- Provide a `trigger:` to re-run on change, or omit it (with a repeating context) for continuous motion.

## Choosing between them

| Situation | Tool |
|-----------|------|
| Ordered states, each a full look (A → B → C) | `phaseAnimator` |
| One value swept through steps | `phaseAnimator` |
| Multiple properties, different timing each | `keyframeAnimator` |
| Precise, designer-specified multi-track motion | `keyframeAnimator` |

If a single spring on a single value does the job, use plain implicit/explicit animation — reach for these only when the motion genuinely has multiple steps or tracks.

## Pitfalls

- **`keyframeAnimator` running continuously by mistake** — without a `trigger`, it animates on appearance; pair with a trigger for event-driven motion.
- **Very long/large keyframe runs** — they can't be interrupted mid-flight as gracefully as a spring; keep them short and non-blocking.
- **Using phases for parallel tracks** (or keyframes for simple sequences) — match the tool to the shape of the motion.
- **Heavy work in the content closure** — it's evaluated per frame; keep it to view modifiers, not computation.
