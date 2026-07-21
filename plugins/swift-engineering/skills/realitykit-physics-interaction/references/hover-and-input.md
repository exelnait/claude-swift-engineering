# Hover Effects & Input Targeting

> Some APIs here (HoverEffectComponent GroupIDs) ship in 2025. Confirm exact names against current Apple documentation.

Before an entity can be gazed at, hovered, tapped, or dragged, RealityKit needs to know two things: that it *can* receive input at all, and *what shape* to hit-test against. Get those two components in place first; visual feedback (`HoverEffectComponent`) and gesture handling build on top of them.

## The two-component rule

**`InputTargetComponent` and `CollisionComponent` are both required on any entity that is the target of a gesture or manipulation.** This applies whether the interaction is driven by `GestureComponent`, a SwiftUI targeted-gesture modifier, or the Object Manipulation API (all covered in `realitykit-swiftui`) — miss either component and the entity silently never responds. There's no error; it just never receives the input.

```swift
entity.components.set(CollisionComponent(shapes: [.generateBox(size: [0.1, 0.1, 0.1])]))
entity.components.set(InputTargetComponent())
entity.components.set(HoverEffectComponent())   // optional: visual feedback on gaze/hover
```

`CollisionComponent` supplies the *shape* input targeting hit-tests against — it does double duty for physics contacts and for "did the person's gaze/pinch/tap land on this entity." `InputTargetComponent` is the flag that says the entity participates in that hit-testing at all.

If you'd rather not assemble these by hand, `ManipulationComponent.configureEntity(_:)` (see `realitykit-swiftui`) adds `InputTargetComponent`, `CollisionComponent`, `HoverEffectComponent`, and `ManipulationComponent` all in one call — the fast path when the entity should also be pickable, not just hoverable or tappable.

## HoverEffectComponent

`HoverEffectComponent` applies a visual highlight when a person looks at (gaze, visionOS) or hovers a pointer over (mouse/trackpad) the entity — a lightweight affordance that says "this is interactive" before any gesture fires.

```swift
entity.components.set(HoverEffectComponent())
```

By default, hover effects apply **hierarchically**: a hover effect on a parent is inherited by its children, so hovering any part of a composed object highlights the whole thing.

## GroupIDs: sharing activation across (and breaking) the hierarchy

`HoverEffectComponent` supports **GroupIDs** — an explicit way to say which hover effects should activate together, independent of parent/child structure:

```swift
entityA.components.set(HoverEffectComponent(groupID: sharedGroup))   // confirm exact initializer
entityB.components.set(HoverEffectComponent(groupID: sharedGroup))
```

Any entities whose hover effects share a GroupID **share activations** — hover over one and both highlight, even if they're unrelated in the hierarchy (e.g. two separate parts of one logical object that aren't parent/child of each other).

The important side effect: **an entity with a GroupID does not propagate its hover effect to its children** — assigning a GroupID *overrides* the normal hierarchical inheritance described above. If you group a parent entity, its children stop automatically inheriting its hover effect; give the children their own `HoverEffectComponent` (with the same or a different GroupID) if they should still highlight.

## Common mistakes

1. **Adding `HoverEffectComponent` or a gesture without `InputTargetComponent` + `CollisionComponent`.** Both are required together; the entity otherwise never receives the gaze/tap/drag at all, with no error to explain why.
2. **Assuming hover always follows the hierarchy once GroupIDs are involved.** GroupIDs override inheritance — a grouped parent's children no longer automatically pick up its hover effect. Add `HoverEffectComponent` explicitly to any child that should still highlight.
3. **Hand-rolling the four-component setup for a pickable object.** If the entity should also support Object Manipulation, call `ManipulationComponent.configureEntity(_:)` once instead of assembling `InputTargetComponent`/`CollisionComponent`/`HoverEffectComponent`/`ManipulationComponent` separately.
4. **Sizing the collision shape to the render mesh instead of the intended target area.** The collision shape *is* the hit-test target — a shape much smaller or larger than the visible model makes the entity feel unresponsive or too sensitive to gaze/tap.
5. **Expecting hover/input targeting to require a `PhysicsBodyComponent`.** It doesn't — a purely kinematic or non-simulated entity can be a full gesture/hover target with just `CollisionComponent` + `InputTargetComponent`.
