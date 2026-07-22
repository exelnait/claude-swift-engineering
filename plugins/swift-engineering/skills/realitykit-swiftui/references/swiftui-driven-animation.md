# SwiftUI-Driven Animation of RealityKit Components

> This animation bridge ships in the 2025 (visionOS 26) release and is newer than this guidance's training data. Confirm exact type names and APIs against current Apple documentation.

SwiftUI already animates ordinary view-property changes implicitly: wrap a state change in `withAnimation`, or attach `.animation(_:value:)`, and SwiftUI interpolates for you (curve choice, springs, etc. are covered in `swiftui-animations`). In visionOS 26, that same implicit-animation model reaches into RealityKit — set a supported component's value inside a RealityKit animation block, driven by a SwiftUI `Animation`, and RealityKit interpolates the change. No manual per-frame tweening.

## Inside a RealityView: content.animate()

```swift
RealityView { content in
    // ...
} update: { content in
    content.animate {                                    // confirm exact API
        sparky.position = isOffset ? [-0.3, 0, 0] : .zero
    }
}
.animation(.bouncy, value: isOffset)   // an ordinary SwiftUI animation modifier
```

`content.animate()` takes no explicit animation argument — it uses whichever SwiftUI `Animation` is attached to the **transaction** that triggered this `update` call (here, `.bouncy`, from the `.animation(_:value:)` modifier around `isOffset`). Set values inside the block; RealityKit picks up the ambient animation and interpolates them.

## Anywhere else: Entity.animate(_:)

```swift
sparky.animate(.bouncy) {                // confirm exact API — animation passed explicitly this time
    sparky.position = isOffset ? [-0.3, 0, 0] : .zero
}
```

Call this directly on an `Entity`, passing an explicit SwiftUI `Animation` plus a closure that sets component values. It doesn't require being inside a `RealityView`'s `update` at all — reach for it once state changes have moved out of `update` entirely (see `observation-and-data-flow.md`). Setting `position` (or any part of `Transform`) inside the block begins an implicit animation of the `Transform` component: the entity glides to the new value instead of jumping.

## Supported components

**Transform**, **Audio** components, **Model** (materials/parameters), and **Light** (color) all support implicit animation this way — set a value on any of them inside an animate block and get free interpolation.

## Combining with Object Manipulation's custom release

```swift
// releaseBehavior = .stay first (see object-manipulation.md), then:
_ = content.subscribe(to: ManipulationEvents.WillRelease.self) { event in
    sparky.animate(.bouncy) {
        sparky.transform = .identity     // resets scale, translation, and rotation together
    }
}
```

Set `releaseBehavior = .stay` to disable the built-in snap-back animation, subscribe to `WillRelease`, and animate the entity's `transform` back to `.identity` yourself inside the animate block — so the reset is smooth instead of an instant jump. This is the standard recipe for a fully custom "snap back to origin" release feel.

## Common mistakes

1. **Expecting `content.animate()` to take an animation parameter.** It implicitly uses the triggering transaction's animation (from `.animation(_:value:)`/`withAnimation`); it isn't a `withAnimation`-alike with its own curve argument.
2. **Hand-writing per-frame interpolation for Transform/Audio/Model/Light changes.** Wrap the value assignment in `content.animate()` or `Entity.animate(_:)` instead and let RealityKit do it.
3. **Setting the value outside the animate block "to keep it simple."** A plain assignment still works — it just jumps instantly. The animate block is what makes the same assignment implicit-animate.
4. **Forgetting `releaseBehavior = .stay` before wiring a custom release animation.** With the default release behavior left on, RealityKit's built-in snap-back animation fights your custom one.
