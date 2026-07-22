# Physics Bodies & Collision

> Some APIs here ship in 2025–2026 releases. Confirm exact names against current Apple documentation.

An entity only participates in the physics simulation once you attach a `PhysicsBodyComponent`. On its own, an entity with just a `ModelComponent` is a pure visual — it does not fall, collide, or block anything.

## PhysicsBodyComponent: three modes, three jobs

```swift
entity.components.set(PhysicsBodyComponent(mode: .dynamic))
```

- **`.dynamic`** — the physics simulation fully drives the entity: gravity pulls it down, forces move it, and it reacts to collisions with other bodies. This is "normal" physics.
- **`.kinematic`** — the entity can only be moved by *you* — setting its `Transform` directly, or another system driving it (a pinch/drag). It still collides with and can push dynamic bodies, but nothing — not gravity, not an impact — moves it on its own. Use this while something is actively being held or animated by hand.
- **`.static`** — the entity never moves and is comparatively cheap to simulate against. Use it for the floor, walls, furniture — anything dynamic bodies should collide with but that should never itself be pushed.

The biggest reason to reach for `.kinematic` over `.dynamic` is exactly the scenario in Apple's puzzle-game demo: an object is being picked up and dragged by a pinch gesture, and gravity or a stray collision shouldn't fight that motion (see "Coordinating physics with manipulation" below).

## PhysicsMotionComponent and applying forces

`PhysicsMotionComponent` holds a dynamic body's current **linear and angular velocity** — read it to inspect how fast something is moving, or write it to impart an initial velocity (a thrown object, a launched projectile):

```swift
var motion = entity.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
motion.linearVelocity = [0, 2, -1]              // confirm exact property name
entity.components.set(motion)
```

To push a body continuously rather than set its velocity outright, apply a **force** (or torque) to it — the same capability Reality Composer Pro's Script Graph exposes as an "Add Force" node for driving a physics body straight from a drag gesture, no code required:

```swift
entity.addForce([0, 0, -5], relativeTo: nil)    // confirm exact method signature
```

`PhysicsBodyComponent` also carries **damping** (`linearDamping`/`angularDamping` — confirm exact names): raising it adds drag so a force-driven object settles instead of feeling jittery or sliding forever — exactly how Reality Composer Pro tunes a drag-and-toss interaction by hand.

## CollisionComponent and collision shapes

`CollisionComponent` is what makes an entity **hit-testable** — for physics contacts, for gesture/manipulation targeting (see `hover-and-input.md`), and for collision events. It's independent of `PhysicsBodyComponent`: an entity can have collision without simulated motion (a static gaze target), and vice versa.

```swift
entity.components.set(CollisionComponent(shapes: [.generateBox(size: [0.2, 0.2, 0.2])]))
```

`ShapeResource` provides generators for common shapes — `.generateBox`, `.generateSphere(radius:)`, `.generateCapsule(height:radius:)` — plus `.generateConvex(from:)` for a tight hull around arbitrary geometry, and a concave static-mesh generator for large, non-moving geometry like terrain or a room scan (`// confirm exact API`). Reach for convex/primitive shapes on anything dynamic; concave shapes are typically restricted to `.static` bodies for performance.

## Coordinating physics with manipulation

The core pattern: **subscribe to the manipulation lifecycle and swap the physics mode**, so the two systems never fight over the same transform.

```swift
_ = content.subscribe(to: ManipulationEvents.WillBegin.self) { event in
    // Picked up: hand the transform fully to the pinch/drag.
    guard var body = event.entity.components[PhysicsBodyComponent.self] else { return }
    body.mode = .kinematic
    event.entity.components.set(body)
}

_ = content.subscribe(to: ManipulationEvents.WillEnd.self) { event in
    // Released: physics (and gravity) take back over.
    guard var body = event.entity.components[PhysicsBodyComponent.self] else { return }
    body.mode = .dynamic
    event.entity.components.set(body)
}
```

`ManipulationEvents` also includes `WillRelease`, `DidUpdateTransform`, and `DidHandOff` (confirm the exact nested-type shape, and whether `subscribe` can additionally scope `on:` a single entity). The Object Manipulation API that raises these events — `ManipulationComponent`, `configureEntity(_:)`, `releaseBehavior` — lives in `realitykit-swiftui`; this file only covers the physics side of the handoff.

An alternative to a hard mode switch, seen in Reality Composer Pro's Script Graph: keep the body `.dynamic` (so a continuous force, like a drag, keeps driving it) but toggle `isAffectedByGravity` off and raise `linearDamping` for the duration of the hold (`// confirm exact API`). Use the mode switch when the manipulation system owns the transform outright (`ManipulationComponent`); use the gravity/damping toggle when you're driving motion with forces instead.

## Colliding with the room

Dropped objects only land on real furniture if the room itself participates in the physics simulation. On visionOS, RealityKit can generate a live **scene understanding mesh** of the surroundings from a `SpatialTrackingSession`, and feed it into physics/collision by enabling the relevant flags on the session's `SceneUnderstandingFlags` before running it:

```swift
var config = SpatialTrackingSession.Configuration()
config.sceneUnderstandingFlags = [.collision, .physics]   // confirm exact property name on Configuration
try await session.run(config)
```

Once enabled, the scene mesh collides with your dynamic bodies automatically — no manual `CollisionComponent` needed on the room itself. `SpatialTrackingSession`, `AnchorEntity`, and the rest of the ARKit-through-RealityKit anchoring story live in `realitykit-spatial-ar`; this is the one flag set you need from that world to make physics room-aware.

## Common mistakes

1. **Leaving `mode` on `.dynamic` while an entity is being manipulated.** Gravity and the physics solver fight the pinch/drag every frame — the object lags, jitters, or gets yanked away. Swap to `.kinematic` on `WillBegin`, back to `.dynamic` on `WillEnd`.
2. **Forgetting the write-back.** `components[PhysicsBodyComponent.self]` is a copy; mutate `.mode` and forget `components.set(_:)` and the change never takes effect (see `realitykit-core`).
3. **Using a concave/static-mesh shape on a dynamic body.** Concave collision shapes are built for immovable geometry (terrain, a room scan); putting one on a `.dynamic` body is expensive or unsupported. Use a convex hull or primitive instead.
4. **Assuming `CollisionComponent` alone makes something move.** Collision is about detection and hit-testing; only `PhysicsBodyComponent` (plus, for continuous motion, forces or `PhysicsMotionComponent`) actually simulates movement.
5. **Skipping the scene-understanding flags.** Without `.collision`/`.physics` enabled on the `SpatialTrackingSession` configuration, dropped virtual objects fall straight through a real table even though the room is visibly tracked.
6. **Never releasing back to `.dynamic`.** If the `WillEnd`/`WillRelease` subscription is missing or fails silently, the object stays frozen in whatever pose it was left in — it looks like physics is broken when it's actually just still `.kinematic`.
