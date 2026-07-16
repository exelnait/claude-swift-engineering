# Implicit & Explicit Animation

SwiftUI animates the transition between two renderings of a view. You control it two ways — attach an animation to a view (implicit) or wrap the state change (explicit) — and shape it with an `Animation` curve and, when needed, a `Transaction`.

## Implicit: `.animation(_:value:)`

Attach to a view; it animates whenever the given value changes. **Always pass a `value`** — the value-less `.animation(_)` is deprecated and animates everything (Common Mistake #1).

```swift
Circle()
    .fill(isOn ? .green : .gray)
    .scaleEffect(isOn ? 1.2 : 1.0)
    .animation(.spring, value: isOn)     // only changes driven by `isOn` animate
```

- Scope matters: `.animation(_:value:)` affects the view it's on and its subtree, for that value. Place it precisely so unrelated changes don't animate.
- Multiple values: chain multiple `.animation(_:value:)` modifiers, each scoped to its own value.

## Explicit: `withAnimation`

Wrap the mutation; SwiftUI animates every view affected by the state you changed. Best for user-triggered changes.

```swift
withAnimation(.snappy) {
    isExpanded.toggle()
}

// With completion (iOS 17+):
withAnimation(.bouncy) { items.append(newItem) } completion: {
    hapticFeedback()      // runs when the animation finishes
}
```

Explicit wins when *one event* should animate whatever it touches; implicit wins when *a view* should always animate a particular value.

## The `Animation` curves

Prefer the **spring family** for anything interactive — springs are interruptible and retarget smoothly (Common Mistake #2):

```swift
.spring                                   // default spring
.spring(response: 0.4, dampingFraction: 0.8)
.bouncy                                    // springy, visible overshoot
.smooth                                    // no bounce, gentle
.snappy                                    // quick, minimal bounce
```

Fixed-duration easing is for precise, non-interactive timing only:

```swift
.easeInOut(duration: 0.3)
.easeIn / .easeOut / .linear
.timingCurve(0.2, 0.0, 0.2, 1.0, duration: 0.3)   // custom cubic-bezier
```

Modifiers compose onto any curve:

```swift
.spring.delay(0.1)
.easeInOut(duration: 0.5).repeatCount(3, autoreverses: true)
.linear(duration: 1).repeatForever(autoreverses: false)   // e.g. a spinner
.spring.speed(2)                                            // run at 2× rate
```

## `Transaction` — scope and override in-flight animation

A `Transaction` carries the animation context through an update. Use it to **override** or **disable** animation for part of a change, or to attach a completion.

```swift
// Disable animation for one specific mutation even if a parent animates:
var txn = Transaction()
txn.disablesAnimations = true
withTransaction(txn) { scrollPosition = .top }

// Override the animation for a subtree regardless of who triggered the change:
content
    .transaction { txn in
        txn.animation = reduceMotion ? nil : .spring
    }
```

- `.transaction { }` on a view lets you inspect/rewrite the transaction flowing through it — e.g. strip animation under Reduce Motion (see the accessibility reference), or force a specific curve.
- `withTransaction(_:)` is the explicit sibling of `withAnimation`, giving full control over the transaction (animation + flags).

## `@Observable` and animation

Changes to `@Observable` model properties animate the same way — wrap the mutation in `withAnimation`, or put `.animation(_:value:)` on the view observing the property. Because observation is fine-grained, only views reading the changed property re-render and animate.

```swift
withAnimation(.smooth) { model.selection = newSelection }   // model is @Observable
```

## Pitfalls

- **Value-less `.animation()`** → deprecated, over-animates. Always scope with `value:`.
- **Fixed easing on re-triggerable UI** → snapping on interruption. Use springs.
- **Animation attached too high in the tree** → unrelated changes animate. Scope tightly.
- **Forgetting `disablesAnimations`** for things that should jump (scroll position, immediate resets) → unwanted motion.
