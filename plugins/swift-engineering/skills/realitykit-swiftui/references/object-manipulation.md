# Object Manipulation

> Object Manipulation and its supporting APIs ship in the 2025 (visionOS 26) release and are newer than this guidance's training data. Confirm exact type names, initializers, and availability against current Apple documentation.

Object Manipulation is a system that lets someone pick up, move, rotate, and scale a virtual object with their hands: move with one hand, rotate with one or both, scale by pinching and dragging with both — and hand the object off from one hand to the other mid-interaction. It ships in two forms, depending on whether the object is a SwiftUI view or a RealityKit entity, backed by the same underlying interaction system.

## The `.manipulable` modifier (SwiftUI)

```swift
Model3D(named: "Sparky")
    .manipulable(operations: [.move, .rotate], inertia: .high)   // confirm exact API — no .scale, feels heavy
```

Works on `Model3D`, or on any `View` you attach it to — it applies to the whole view. `operations:` restricts which gestures are allowed (drop `.scale` to keep an object a fixed size, for instance — confirm the exact `Operations` type). `inertia:` tunes how the object keeps moving after release; higher inertia reads as heavier.

## ManipulationComponent (RealityKit)

```swift
ManipulationComponent.configureEntity(sparkyEntity)   // confirm exact API
```

One line. It adds four components for you: `CollisionComponent` (so the interaction system knows the entity was tapped), `InputTargetComponent` (so it responds to gestures at all), `HoverEffectComponent` (a visual highlight on gaze/hover), and the `ManipulationComponent` itself. That's the entire setup required to make an entity in a `RealityView` pickable, rotatable, and scalable.

### Customizing

```swift
ManipulationComponent.configureEntity(
    sparkyEntity,
    hoverEffect: .spotlight(color: .purple),           // confirm exact API
    allowedInputTypes: [.direct, .indirect],            // touch, and gaze + pinch — confirm exact case names
    collisionShapes: [.generateBox(size: robotBounds)]  // outer interaction volume
)
```

`configureEntity` accepts parameters for the hover/spotlight appearance, which input classes to accept (direct touch vs. indirect gaze-and-pinch), and explicit collision shapes when the entity's render geometry isn't the volume you want people to grab.

## ManipulationEvents

The system raises events at each interaction milestone — `WillBegin`, `WillEnd`, `WillRelease`, `DidUpdateTransform`, and `DidHandOff` (fired when the object passes between hands). Subscribe the same way as any RealityKit event, through `content.subscribe(to:)`.

The canonical use is gating physics on manipulation state. An entity with both a `PhysicsBodyComponent` and a `ManipulationComponent` will otherwise fight itself, so subscribe to `WillBegin` to flip `PhysicsBodyComponent.mode` to `.kinematic` (physics stops interfering while a hand moves it) and to `WillEnd` to flip it back to `.dynamic` (so it falls and collides normally once released). The physics side of this interplay — modes, gravity, collision response — is covered in `realitykit-physics-interaction`; this reference covers only the manipulation-event trigger.

## Release behavior

By default, a released object **animates smoothly back to where it started**. Set `releaseBehavior = .stay` on the `ManipulationComponent` to leave it wherever it was released instead — required if you want it to drop via physics, or to drive your own custom release animation.

## Custom release and audio

Standard sounds play automatically at begin, handoff, and release. To substitute your own: set `audioConfiguration = .none` first to silence the defaults, then subscribe to the relevant event (`DidHandOff` for a handoff sound, `WillRelease` for a release sound) and play your own audio resource in the closure.

Combine `.stay` + a `WillRelease` subscription + `Entity.animate(_:)` to build a fully custom "snap back to origin" release — set the entity's `transform` to `.identity` inside the animate block so the reset is smooth rather than instant. See `swiftui-driven-animation.md` for the animate-block half of that recipe.

## Common mistakes

1. **Building a custom drag/rotate/scale gesture stack from scratch.** Object Manipulation already implements move, rotate, scale, and hand-off — check `.manipulable` / `ManipulationComponent` before writing gesture math by hand.
2. **Manually adding Collision/InputTarget/HoverEffect before calling `configureEntity`.** It adds all three itself; let it, then layer customization on top instead of pre-empting it.
3. **Expecting a released object to stay where it was left.** The default snaps back to the start position — you must opt in to `releaseBehavior = .stay`.
4. **Leaving default audio on while adding your own.** The standard begin/handoff/release sounds keep playing until `audioConfiguration` is explicitly set to `.none`.
5. **Not gating physics on manipulation state.** Combining `PhysicsBodyComponent` and `ManipulationComponent` without toggling the physics mode on `WillBegin`/`WillEnd` lets the physics system and the manipulation system fight over the entity's transform.
