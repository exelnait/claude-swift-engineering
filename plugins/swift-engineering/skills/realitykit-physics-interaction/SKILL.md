---
name: realitykit-physics-interaction
description: Use when adding physics, collision, and world interaction to RealityKit — PhysicsBodyComponent modes (dynamic/kinematic/static) and gravity, collision shapes and CollisionComponent, applying forces, coordinating physics with Object Manipulation, hover effects and HoverEffectComponent GroupIDs, character pathfinding with a navigation mesh (NavigationComponent), and cloth simulation.
---

# RealityKit Physics & Interaction: Collision, Manipulation, Navigation, and Cloth

RealityKit doesn't just render 3D content — it can simulate it. This skill covers everything that makes entities behave like physical, interactive objects: falling under gravity, colliding with each other and with the real room, reacting to a pinch or a gaze, finding a walkable path through a level, and draping like real fabric. It's all ordinary ECS — a handful of components plus the systems RealityKit already ships to drive them (see `realitykit-core` for the ECS foundation itself).

> Several APIs referenced across these files ship in the 2025–2026 releases and are newer than this guidance's training data. Confirm exact type names, initializers, and availability against current Apple documentation. Inline `// confirm exact API` markers flag the spots most worth checking.

## Overview

Three layers matter, and they build on each other:

1. **Simulated physics** — `PhysicsBodyComponent` (and `PhysicsMotionComponent`) make an entity fall, collide, and respond to forces. A body's `mode` (`.dynamic`, `.kinematic`, `.static`) decides who's driving: the physics simulation, your code, or nobody.
2. **Collision & targeting** — `CollisionComponent` gives an entity a shape to be hit, hovered, or gestured on. `InputTargetComponent` and `HoverEffectComponent` build on that same shape for input and visual feedback.
3. **Purpose-built solvers** — `NavigationComponent` pathfinds characters across a `NavigationMeshResource`; the cloth components (`ClothBodyComponent`, `ClothColliderComponent`, `ClothSimulationComponent`) simulate fabric as a mesh of particles and springs.

The seam all three share is **manipulation**. When a person picks something up, physics needs to step aside (`.kinematic`) so the pinch/drag is in full control; when they let go, physics needs to take back over (`.dynamic`) so gravity and collisions resume. That handoff — driven by `ManipulationEvents` — is the single most important pattern in this skill.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** It's better to have the context than to miss a pattern or make a mistake.

| Reference | Load When |
|-----------|-----------|
| **[Physics Bodies & Collision](references/physics-bodies-collision.md)** | `PhysicsBodyComponent` modes (dynamic/kinematic/static) and gravity, `PhysicsMotionComponent`, applying forces, `CollisionComponent` and collision shapes, coordinating physics with manipulation (toggling mode on `ManipulationEvents`), or colliding with the real room via scene-understanding flags |
| **[Hover Effects & Input Targeting](references/hover-and-input.md)** | `HoverEffectComponent` and GroupIDs, or making sure an entity actually receives gestures/manipulation (`InputTargetComponent` + `CollisionComponent`, both required together) |
| **[Navigation Mesh & Pathfinding](references/navigation-mesh.md)** | `NavigationMeshResource`, `NavigationComponent`, computing and walking a path with `NavigationController`, traversal cost, or off-mesh connections (bridges/ladders/jumps) |
| **[Cloth Simulation](references/cloth-simulation.md)** | `ClothBodyComponent`, `ClothColliderComponent`, `ClothSimulationComponent`, cloth/collider material properties, or pinning cloth vertices kinematic |

Cross-skill: the Object Manipulation API itself — SwiftUI's `.manipulable`, `ManipulationComponent`, `configureEntity(_:)`, `releaseBehavior`, and the full `ManipulationEvents` set — lives in **`realitykit-swiftui`**. ARKit anchoring, `SpatialTrackingSession`, and the scene-understanding mesh live in **`realitykit-spatial-ar`**. Authoring navigation meshes and cloth visually belongs to **`reality-composer-pro`**. Level-of-detail and thermal-state adaptation live in **`3d-asset-optimization`**, not here. Foundational ECS (entities/components/systems, the write-back rule) is **`realitykit-core`**.

## Core Workflow

1. Decide whether the entity moves under simulation at all, and attach a `PhysicsBodyComponent` with the matching `mode` — `.dynamic` (reacts to gravity/forces), `.kinematic` (moved only by your code/transform), or `.static` (never moves; others collide against it).
2. Give it a shape with `CollisionComponent` (+ a `ShapeResource`) so it can be hit-tested, collided with, or targeted at all (see `physics-bodies-collision.md`).
3. If it's grabbable, wire up Object Manipulation (`realitykit-swiftui`) and subscribe to `ManipulationEvents.WillBegin`/`WillEnd` to swap the physics mode so gravity doesn't fight the hand.
4. If it should highlight on gaze/hover or respond to a gesture, add `HoverEffectComponent` (with a GroupID if the effect should cross the hierarchy) and confirm both `InputTargetComponent` and `CollisionComponent` are present (`hover-and-input.md`).
5. If it should collide with the real room, enable the collision/physics scene-understanding flags on the `SpatialTrackingSession` (`realitykit-spatial-ar`).
6. For characters that need to walk a level, build or author a `NavigationMeshResource`, feed it into a `NavigationComponent`, and drive movement through a `NavigationController` (`navigation-mesh.md`).
7. For fabric, add `ClothBodyComponent`/`ClothColliderComponent` to the cloth and its colliders, then tie them together with a `ClothSimulationComponent` (`cloth-simulation.md`).

## Physics That Steps Aside While You're Holding It

The pattern behind Apple's 2025 puzzle-game demo — a key that must be picked up, rotated, and inspected, then realistically dropped once released:

```swift
key.components.set(PhysicsBodyComponent(mode: .dynamic))

_ = content.subscribe(to: ManipulationEvents.WillBegin.self) { event in
    // Picked up: hand the transform fully to the pinch/drag, not gravity.
    guard var body = event.entity.components[PhysicsBodyComponent.self] else { return }
    body.mode = .kinematic
    event.entity.components.set(body)          // write the mutated copy back
}

_ = content.subscribe(to: ManipulationEvents.WillEnd.self) { event in
    // Released: physics (and gravity) take back over.
    guard var body = event.entity.components[PhysicsBodyComponent.self] else { return }
    body.mode = .dynamic
    event.entity.components.set(body)
}
```

Getting this swap right prevents the two classic bugs: gravity yanking the object mid-drag because it's still `.dynamic`, or the object staying frozen after release because it never went back. See `physics-bodies-collision.md` for the full pattern — including `PhysicsMotionComponent`, applying forces, and an alternative (`isAffectedByGravity` + damping) for entities driven by continuous forces rather than a direct transform handoff.

## Common Mistakes

1. **Leaving `mode` on `.dynamic` while an entity is being manipulated.** Without swapping to `.kinematic` on `WillBegin` (and back on `WillEnd`), physics and the pinch/drag fight over the same transform every frame — the object jitters, lags, or gets yanked out of the hand. This is the single most common physics+manipulation bug (see `physics-bodies-collision.md`).

2. **Adding `HoverEffectComponent` or a gesture without `CollisionComponent` + `InputTargetComponent`.** Hover and gesture/manipulation targeting are hit-tested against the collision shape; skip either component and the entity silently never responds — there's no error, it just never receives input (see `hover-and-input.md`).

3. **Forgetting the component write-back.** Like every RealityKit component, `PhysicsBodyComponent`, `CollisionComponent`, and the cloth components are value types — `components[T.self]` hands you a copy. Mutate a field and forget `components.set(_:)` and nothing happens (see `realitykit-core`).

4. **Expecting collision detection to mean physics simulation.** A bare `CollisionComponent` lets an entity be hit-tested and detect overlaps — it does not make anything move. Motion requires `PhysicsBodyComponent`; a purely kinematic or non-simulated entity can have collision without ever being simulated.

5. **Skipping scene-understanding flags and expecting objects to land on real furniture.** Room collision/physics are opt-in on the `SpatialTrackingSession` configuration; without them, dropped objects fall straight through a real table even though the room is visibly tracked (see `physics-bodies-collision.md` and `realitykit-spatial-ar`).

6. **Not distinguishing an off-mesh connection from a normal path node.** Iterating a computed `NavigationController` path the same way for every node breaks the moment the path crosses a bridge or ladder — those nodes need distinct traversal logic (see `navigation-mesh.md`).

7. **Under-tessellating cloth, or forgetting `ClothSimulationComponent`.** A cloth mesh with too few vertices creases unrealistically no matter how the material is tuned, and a `ClothBodyComponent`/`ClothColliderComponent` pair does nothing until a `ClothSimulationComponent` is actually running the simulation (see `cloth-simulation.md`).
