---
name: realitykit-core
description: Use when building 3D content with RealityKit — the Entity Component System (entities, components, systems), RealityView setup and its make/update closures, loading entities and mesh/material resources, transforms and the coordinate system, entity actions and animation playback, or deploying one RealityKit codebase across iOS, iPadOS, macOS, tvOS, and visionOS. RealityKit is Apple's recommended 3D engine; SceneKit is deprecated, so use RealityKit for all new 3D work.
---

# RealityKit Core: Entity Component System

RealityKit is Apple's modern, general-purpose, high-level 3D engine. It powers Quick Look, App Store Tags, Swift Charts' 3D charts, and the entire visionOS interface, and it runs on **iOS, iPadOS, macOS, tvOS, and visionOS** from one codebase. This is the foundational skill for every other RealityKit skill in this plugin.

> **SceneKit is deprecated** (soft deprecation, 2025 — maintenance mode, no new features). Do **not** start new 3D work in SceneKit. Use RealityKit. If you're staring at an existing SceneKit app, the concepts still map (node → entity, node properties → components, same coordinate system), but new features belong in RealityKit.

> Several APIs referenced across these skills ship in the 2025–2026 releases and are newer than this guidance's training data. Confirm exact type names, initializers, and availability against current Apple documentation. Inline `// confirm exact API` markers flag the spots most worth checking.

## Overview

The single most important mental shift: RealityKit is **not node-based**. Every object in a scene is an **`Entity`**, and you change what an entity *is* and *does* by attaching **`Component`**s to it. A component is a plain data container. **`System`**s hold the logic — each frame a system finds every entity that has the components it cares about and updates them. This is the **Entity Component System (ECS)** pattern.

```
Entity        →  an object in the scene (a handle + a set of components)
Component     →  data attached to an entity (Transform, ModelComponent, PhysicsBody, …)
System        →  per-frame logic that operates on entities with specific components
RealityView   →  the SwiftUI view that hosts and renders a RealityKit scene
```

Everything else — physics, particles, audio, lighting, portals, gestures, manipulation — is *just another component*. New components arrive every year; the model never changes.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** It's better to have the context than to miss a pattern or make a mistake.

| Reference | Load When |
|-----------|-----------|
| **[ECS Fundamentals](references/ecs-fundamentals.md)** | Understanding entities/components/systems, writing a custom `Component` or `System`, `EntityQuery`, component registration, and the write-back rule for mutated components |
| **[RealityView](references/realityview.md)** | Hosting a scene in SwiftUI — the `make`/`update`/`attachments` closures, `RealityViewContent`, when `update` runs, `content.subscribe`, camera controls, and `realityViewLayoutBehavior` sizing |
| **[Entities & Resources](references/entities-and-resources.md)** | Loading entities (from a Reality Composer Pro package, USD, a URL, or in-memory `Data`), `ModelComponent`, mesh/material resources, cloning, finding entities by name, and attaching to another entity's pin |
| **[Transforms & Coordinates](references/transforms-and-coordinates.md)** | Positioning content — the `Transform` component, the +Y-up/−Z-forward coordinate system, parent↔child transform inheritance, and converting between coordinate spaces |
| **[Systems & Actions](references/systems-and-actions.md)** | Driving behavior over time — the `System` update loop, `AnimationLibraryComponent` playback, entity actions (`PlayAudioAction`), and playing an action as an animation |
| **[Cross-Platform Deployment](references/cross-platform.md)** | Shipping one RealityKit codebase to iOS/iPadOS/macOS/tvOS/visionOS, what differs per platform (stereoscopic rendering, immersion, input), and platform-gating patterns |

Cross-skill: SwiftUI ↔ RealityKit bridging (Model3D, attachments, gestures, manipulation, observation) → **`realitykit-swiftui`**. Materials, lighting, shadows, effects → **`realitykit-rendering`**. Physics, collision, nav mesh, cloth → **`realitykit-physics-interaction`**. AR anchoring & scene understanding → **`realitykit-spatial-ar`**. Authoring scenes visually → **`reality-composer-pro`**. Finding entities that vanished or misbehaved → **`realitykit-debugging`**.

## Core Workflow

1. **Host a scene** with a `RealityView { content in … }` (see `realityview.md`).
2. **Load or build entities** — usually load a scene authored in Reality Composer Pro from its Swift-package bundle, then add it to `content` (see `entities-and-resources.md`).
3. **Attach components** to give entities behavior — a `ModelComponent` for geometry, a `Transform` for placement, plus physics/audio/particles/etc. as needed.
4. **Add systems** for per-frame logic that operates across entities (see `systems-and-actions.md`).
5. **Position content** with transforms, respecting the parent/child hierarchy (see `transforms-and-coordinates.md`).
6. **Deploy** the same code across platforms; only input and immersion differ (see `cross-platform.md`).

## The ECS Mental Model in One Example

```swift
import RealityKit

// An entity is a handle. On its own it's empty — no geometry, at its parent's origin.
let robot = Entity()

// Give it geometry + placement by attaching components.
robot.components.set(ModelComponent(mesh: .generateBox(size: 0.2), materials: [SimpleMaterial()]))
robot.position = [0, 0, -0.5]        // Transform component, sugar for components[Transform.self]

// Behavior lives in Systems (built-in or custom), not on the entity.
// A PhysicsBodyComponent makes the physics System start simulating this entity.
robot.components.set(PhysicsBodyComponent())
```

You never subclass `Entity` to add behavior (the SceneKit reflex). You **compose** behavior from components and let systems act on them.

## Common Mistakes

1. **Reaching for a node-based / inheritance mindset.** Coming from SceneKit (or most engines), the instinct is "subclass the object and override." In RealityKit you *add a component* and *write a system*. Behavior is data + systems, not inheritance. Model your feature as "which component holds the data, which system reads it."

2. **Mutating a component without writing it back.** `components[MyComponent.self]` returns a **value-type copy**. Changing a field on that copy does nothing until you assign it back: `entity.components.set(copy)`. Forgetting the write-back is the single most common ECS bug — the app compiles, runs, and silently ignores your change (see `realitykit-debugging`).

3. **Fighting inherited transforms.** An entity's final placement is *its own transform composed with every ancestor's*. A scale or rotation on a parent silently distorts all descendants. When something appears squished or offset, walk up the hierarchy — the culprit is usually an ancestor (see `transforms-and-coordinates.md`).

4. **Doing heavy per-frame work off the ECS.** Ad-hoc timers or view-body loops that mutate entities every frame fight the engine. Put recurring logic in a `System`; its `update` runs each frame with an efficient `EntityQuery` over exactly the entities that matter.

5. **Positioning complex scenes in code.** Hand-authoring layout, materials, and lighting in Swift is slow and error-prone. Compose scenes in **Reality Composer Pro**, load the result as an entity, and reserve code for behavior (see `reality-composer-pro`).

6. **Assuming RealityKit is visionOS-only.** It's cross-platform — iOS, iPadOS, macOS, tvOS (new in 2025), and visionOS. The same `RealityView` and entities deploy everywhere; write once, adapt input/immersion per platform (see `cross-platform.md`).

7. **Adding `@available` guards for pre-iOS-26.** This plugin targets iOS 26+ exclusively. Write RealityKit APIs directly; no fallback paths, no availability checks for older OSes.
