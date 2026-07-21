---
name: realitykit-swiftui
description: Use when integrating RealityKit with SwiftUI — choosing Model3D vs RealityView, playing animations and switching configurations on Model3D (Model3DAsset, ConfigurationCatalog), sizing a RealityView with realityViewLayoutBehavior, adding SwiftUI views/gestures/popovers to entities (ViewAttachmentComponent, GestureComponent, PresentationComponent), Object Manipulation (the manipulable modifier and ManipulationComponent), observable entities and two-way SwiftUI↔RealityKit data flow, unified coordinate conversion (CoordinateSpace3D), and driving RealityKit component changes with SwiftUI animation.
---

# RealityKit + SwiftUI: Two-Way Integration

RealityKit and SwiftUI have always cooperated through `RealityView`, but visionOS 26 tightens the seam from both sides at once. `Model3D` — SwiftUI's one-line 3D view — gained animation and configuration-switching powers that used to require a full `RealityView`. And RealityKit entities gained SwiftUI-shaped components — views, gestures, popovers, pick-up-and-move manipulation — that work from anywhere, not just inside a `RealityView`'s closures. Data now flows in both directions, coordinate spaces convert directly across frameworks, and SwiftUI's animation system can drive RealityKit component changes. This skill covers that seam; for the RealityKit fundamentals underneath it (entities, components, systems, `RealityView` itself), see `realitykit-core`.

> Several APIs referenced in this skill shipped in visionOS 26 (2025) and are newer than this guidance's training data. Confirm exact type names, initializers, and availability against current Apple documentation. Inline `// confirm exact API` markers flag the spots most worth checking.

## Overview

Two decisions shape most of this skill:

**Model3D or RealityView?** `Model3D` is "the Image view for 3D" — hand it a self-contained asset and it renders, lays out, resizes, and (now) animates and switches looks, all in one line, with no entities to manage. `RealityView` is the escape hatch: real entities, real components, real systems, full control — at the cost of owning more of the plumbing (sizing, positioning, lifecycle). Reach for `Model3D` first; move to `RealityView` the moment you need a capability `Model3D` structurally can't offer, like adding a `ParticleEmitterComponent`.

**Which side owns the SwiftUI-shaped behavior?** A `RealityView` could always host SwiftUI attachments declared up front in its initializer. Now, three components — `ViewAttachmentComponent`, `GestureComponent`, `PresentationComponent` — let you attach a view, a gesture, or a popover directly to an *entity*, from anywhere, without pre-declaring anything in a view builder. `ManipulationComponent` (and its SwiftUI twin, the `.manipulable` modifier) does the same for a whole interaction system: pick up, rotate, scale, hand off between hands.

Underneath both decisions: entities are now `Observable`, so information can flow RealityKit → SwiftUI as naturally as it always flowed SwiftUI → RealityKit; a shared `CoordinateSpace3D` protocol converts positions between a SwiftUI view and a RealityKit entity without manual math; and SwiftUI's implicit animation system reaches directly into RealityKit component values.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** It's better to have the context than to miss a pattern or make a mistake.

| Reference | Load When |
|-----------|-----------|
| **[Model3D vs RealityView](references/model3d-vs-realityview.md)** | Choosing between `Model3D` and `RealityView`; playing animations on `Model3D` via `Model3DAsset`/`selectedAnimation`/`AnimationPlaybackController`; switching looks with `ConfigurationCatalog`; transitioning `Model3D` → `RealityView` without breaking layout; sizing with `realityViewLayoutBehavior` |
| **[View Attachments & Gestures](references/view-attachments-and-gestures.md)** | Adding a SwiftUI view to an entity (`ViewAttachmentComponent`), attaching a gesture directly to an entity (`GestureComponent`), or presenting a popover/modal from RealityKit (`PresentationComponent`) |
| **[Object Manipulation](references/object-manipulation.md)** | Letting someone pick up, move, rotate, scale, or hand off a virtual object — the `.manipulable` modifier, `ManipulationComponent.configureEntity`, customizing hover/input/collision, `ManipulationEvents`, and custom release behavior |
| **[Observation & Data Flow](references/observation-and-data-flow.md)** | Reading `entity.observable` to drive SwiftUI from RealityKit (a minimap, a HUD), two-way data flow, and avoiding the SwiftUI↔RealityKit infinite update loop |
| **[Coordinate Conversion](references/coordinate-conversion.md)** | Converting a position between a SwiftUI view and a RealityKit entity — `CoordinateSpace3D`, `GeometryProxy3D.coordinateSpace3D()`, gestures reporting values in a given coordinate space, `onGeometryChange3D` |
| **[SwiftUI-Driven Animation](references/swiftui-driven-animation.md)** | Animating a RealityKit component change (Transform, Audio, Model, Light) using a SwiftUI `Animation` — `content.animate()` and `Entity.animate(_:)` |

Cross-skill: Entity Component System fundamentals and `RealityView`'s `make`/`update` closures → **`realitykit-core`** (read first if you haven't). Particle emitters, materials, lighting → **`realitykit-rendering`**. The physics half of Object Manipulation — toggling `PhysicsBodyComponent` mode while an entity is held → **`realitykit-physics-interaction`**. AR anchoring and scene understanding → **`realitykit-spatial-ar`**. Authoring the reality files, bundled animations, and `ConfigurationCatalog` variants this skill loads → **`reality-composer-pro`**. Tracking down a misbehaving entity or component → **`realitykit-debugging`**.

## Core Workflow

1. **Default to `Model3D`** for a self-contained 3D asset. If all you need is display, animation playback (`Model3DAsset`), or switching between authored looks (`ConfigurationCatalog`), stay here — see `model3d-vs-realityview.md`.
2. **Move to `RealityView`** the moment you need something `Model3D` can't do — add a component, run a custom system, use physics. Preserve the layout you had with `.realityViewLayoutBehavior(.fixedSize)`.
3. **Bring SwiftUI-shaped capabilities to entities directly**, wherever they live: `ViewAttachmentComponent` for views, `GestureComponent` for gestures, `PresentationComponent` for popovers/modals, `ManipulationComponent`/`.manipulable` for pick-up-and-move interaction.
4. **Let data flow both ways.** SwiftUI → RealityKit in `update` (or any gesture/event handler); RealityKit → SwiftUI by reading `entity.observable` from a SwiftUI view.
5. **Guard against the observation loop**: never write an observed property inside `update`; systems and gesture closures are always safe places to mutate observed entities.
6. **Convert positions with `CoordinateSpace3D`** instead of hand-rolling points-to-meters or axis conversions between a SwiftUI view and a RealityKit entity.
7. **Animate component changes the SwiftUI way** — wrap the value assignment in `content.animate()` or `Entity.animate(_:)` instead of writing manual interpolation.

## SwiftUI Capabilities, Directly on an Entity

```swift
import SwiftUI
import RealityKit

// Model3D: "the Image view for 3D." One line, self-contained, no entities.
Model3D(named: "Sparky", bundle: realityKitContentBundle)   // confirm exact initializer/parameter labels
    .manipulable(operations: [.move, .rotate])                // confirm exact API — pick up without a RealityView

// The moment you need a component Model3D can't provide (particles, physics,
// a custom system), move to RealityView — and bring the same SwiftUI-shaped
// capabilities to the entity itself, not the surrounding view:
RealityView { content in
    let sparky = try await Entity(named: "Sparky", in: realityKitContentBundle)

    sparky.components.set(ViewAttachmentComponent(rootView: NameSign(text: "Sparky")))  // confirm exact API
    sparky.components.set(GestureComponent(TapGesture().onEnded { toggleNameSign() }))    // confirm exact API
    ManipulationComponent.configureEntity(sparky)   // adds Collision + InputTarget + HoverEffect + Manipulation

    content.add(sparky)
}
```

## Common Mistakes

1. **Reaching for `RealityView` out of habit.** `Model3D` now handles animation playback and look-switching on its own (`Model3DAsset`, `ConfigurationCatalog`). Only switch to `RealityView` when you need something structural — a component `Model3D` doesn't expose, direct entity/system access, or physics.

2. **Forgetting `realityViewLayoutBehavior` after switching from `Model3D` to `RealityView`.** A bare `RealityView` takes all the space SwiftUI offers it, with its origin at the view's center — unlike `Model3D`'s intrinsic sizing. Sibling views (a name sign, a HUD label) get shoved out of place until you apply `.fixedSize` (or `.centered`).

3. **Assuming layout behavior moves your entities.** `.flexible`/`.centered`/`.fixedSize` only reposition the `RealityView`'s own origin point — they never reposition or scale the entities inside `RealityViewContent`. It's also evaluated once, right after `make`, not on every update.

4. **Adding a `GestureComponent` without `InputTargetComponent` + `CollisionComponent`.** Any entity that's a gesture target — via `GestureComponent` or the older `.targetedToEntity` modifier — needs both, or it silently never receives input. (`ManipulationComponent.configureEntity` adds all of this for you automatically; a bare `GestureComponent` does not.)

5. **Writing to observed state inside `RealityView`'s `update` closure.** Treat `update` as an extension of the view's `body`: it reruns on *any* state the view depends on, not just what the closure itself reads. Writing an observed property there triggers another `body` evaluation, which reruns `update`, which writes again — an infinite loop. Systems' `update(context:)` and gesture closures are outside this scope and are safe to mutate observed entities from.

6. **Leaving Object Manipulation's defaults on while customizing.** Released objects snap back to their start position unless you set `releaseBehavior = .stay`; standard begin/handoff/release sounds keep playing until you set `audioConfiguration = .none`. Both default *on* — opt out explicitly before layering custom behavior.

7. **Hand-writing interpolation for a component value that already supports implicit animation.** `Transform`, `Audio`, `Model`, and `Light` components all animate implicitly when set inside `content.animate()` or `Entity.animate(_:)`. Wrap the assignment instead of tweening it by hand.
