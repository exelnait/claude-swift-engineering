---
name: realitykit-debugging
description: Use when debugging RealityKit apps — capturing an entity-hierarchy snapshot with the RealityKit debugger in Xcode, diagnosing rogue/inherited transforms, misconfigured or missing components, and rendering pitfalls (occlusion, clipping, inside-out meshes, disabled entities, missing anchors, broken or absent meshes, misconfigured materials, bad normals), building custom debug components and visualizations, and profiling with RealityKit Trace.
---

# RealityKit Debugging: Finding What Went Wrong

RealityKit apps rarely crash when something goes wrong — an entity is squished into the wrong shape, a system quietly stops updating, or an object that should be on screen just isn't there, with no exception and no log line. The **RealityKit debugger** in Xcode captures a 3D snapshot of your running app's actual scene graph so you can inspect real entities, real hierarchy, and real component values instead of guessing from the source. This skill covers the debugger's workflow, the transform/component bugs it's built to expose, the "why isn't this rendering" taxonomy, and how to extend the debugger with your own debug-only tooling.

> The RealityKit debugger shipped in Xcode 16 (2024); RealityKit has grown new components and behaviors in the 2025–2026 releases that now surface inside it. Confirm exact button labels, menu names, and inspector fields against current Xcode documentation — UI details are the most likely thing to have moved since this guidance's training data.

## Overview

RealityKit's ECS model (`realitykit-core`) makes almost every bug fall into one of two shapes, and the debugger is built around both:

- **Structural bugs** — an entity's *placement* or a system's *data* is wrong, and the fix is to inspect the entity hierarchy and component values directly: walk the ancestor chain to find a rogue transform, or watch a component's fields across a run to catch a mutation that never got written back.
- **Rendering pitfalls** — an entity that should be visible just isn't, and there's no single cause. RealityKit is deliberately selective about what it spends time drawing (culling, clipping, opacity, disabled state, missing anchors…), so "why isn't this showing up" is a **process of elimination** you work through with the viewport, the inspector, and the hierarchy filter — not a single check.

The debugger is itself just another consumer of your entities and components, so it's extensible: add debug-only entities, visualizations, and components (gated behind `#if DEBUG`) to make your own app-specific systems every bit as inspectable as RealityKit's built-in ones.

Nothing here is visionOS-specific — the debugger works identically for an iOS, macOS, or visionOS target. (The sample used to demonstrate it happens to run as a visionOS volumetric app; every technique applies verbatim on iOS.)

The debugger answers *"what's wrong."* When the question is instead *"what's slow,"* reach for **RealityKit Trace** (see `custom-debug-tooling.md` and the general `performance-profiling` skill).

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** It's better to have the context than to miss a pattern or make a mistake.

| Reference | Load When |
|-----------|-----------|
| **[Debugger Workflow](references/debugger-workflow.md)** | Capturing an entity-hierarchy snapshot, reading the debug navigator / entity hierarchy outline / reconstructed 3D viewport, the per-entity inspector, the preview viewport that renders a mesh *without* ancestor transforms, the statistics inspector, the preview's rendering-mode dropdown (e.g. Normals), and the hierarchy filter bar |
| **[Transform & Component Bugs](references/transform-and-component-bugs.md)** | An entity is misplaced, squished, or rotated wrong (rogue/inherited transforms up the ancestor chain); a system seems to do nothing or a value never changes (the component write-back rule); missing/misconfigured components making a system's behavior unpredictable |
| **[Rendering Pitfalls](references/rendering-pitfalls.md)** | Content that should be visible simply isn't — the "missing content" taxonomy: occlusion, out-of-bounds clipping, inside-out meshes, disabled entities, stray anchors, a missing `ModelComponent`, opacity/threshold misconfiguration, broken normals, or an entity never added to the scene |
| **[Custom Debug Tooling](references/custom-debug-tooling.md)** | Debugging app-specific systems the built-in inspector can't explain — visible debug entities and visualizations, custom components that surface state (and entity references) in the inspector, `#if DEBUG` gating, and profiling with RealityKit Trace |

Cross-skill: the ECS model and the transform-composition mental model these bugs violate → **`realitykit-core`**. Correctly configuring the materials, opacity, and normal maps that `rendering-pitfalls.md` diagnoses → **`realitykit-rendering`**. Authoring scene layout visually to avoid most of this skill's bugs before they ship → **`reality-composer-pro`**. Scripted, repeatable performance investigation beyond RealityKit Trace → **`performance-profiling`**.

## Core Workflow

1. **Reproduce the bug**, then pause the app and click **Capture Entity Hierarchy** in Xcode's debug area to snapshot the live scene (see `debugger-workflow.md`).
2. **Open the capture** from the debug navigator and explore the entity hierarchy outline alongside the reconstructed 3D viewport — selecting an entity in one selects it in the other.
3. **For a placement/distortion bug**, select the suspect entity and compare its inspector's preview viewport (mesh alone, no ancestor transforms) against the main viewport (mesh with every ancestor's transform composed in). If the preview looks correct, the bug is inherited — walk up the hierarchy one ancestor at a time until you find the one with a non-identity transform.
4. **For a system that seems to do nothing**, inspect the components of the entities it should be touching. Confirm they're actually present, then watch the data-holding component's fields — a value frozen at its initial state while the app runs is the signature of a mutated copy that was never written back.
5. **For "why isn't this rendering,"** work the elimination checklist in `rendering-pitfalls.md` — transform/bounds, `isEnabled`, `AnchoringComponent`, `ModelComponent` presence, material opacity, normals, and scene membership (the filter bar).
6. **For app-specific systems**, extend the debugger: add visible debug entities/visualizations and custom components under `#if DEBUG` so your own state shows up in the inspector too (see `custom-debug-tooling.md`).

## A Worked Example: The Missing Write-Back

The single most common RealityKit bug looks like this in the debugger: a system is clearly running, but one of its components never changes.

```swift
struct ControlCenterComponent: Component {
    var countdown: Float = 5
}

struct TeleportationSystem: System {
    static let query = EntityQuery(where: .has(ControlCenterComponent.self))

    init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var control = entity.components[ControlCenterComponent.self] else { continue }
            control.countdown -= Float(context.deltaTime)
            if control.countdown <= 0 {
                // ...find a TeleporterComponent entity, spawn a robot, reset control.countdown...
            }
            // BUG: `control` is a local copy. Without this line, the entity's stored
            // component never changes, so nothing ever spawns:
            // entity.components.set(control)
        }
    }
}
```

Captured in the debugger, `ControlCenterComponent.countdown` sits at exactly its initial value no matter when you pause — a live counter that never moves is the tell. The fix is one line: `entity.components.set(control)`. See `transform-and-component-bugs.md` for the general rule.

## Common Mistakes

1. **Assuming a misplaced or distorted entity is a mesh problem.** Check the inspector's preview viewport first — it renders the `ModelComponent` alone, with zero inherited transform. If the mesh looks correct there, the entity isn't the problem; an ancestor is.

2. **Scaling or rotating a parent that has unrelated content hanging off it.** A parent's transform composes onto every descendant. If you scaled a "support" entity to get its own shape right, but something else (a light fixture, a disco ball) sits underneath it in the hierarchy purely for scene organization, it inherits that scale too. Re-parent the affected entity to be a **sibling** instead — it can still look connected in the scene without sharing a transform.

3. **Mutating a component's copy and never writing it back.** `entity.components[T.self]` returns a value-type copy. Changing a field on it does nothing until `entity.components.set(_:)`. This is the classic "the countdown/state never updates" bug, and it's silent — no crash, no warning, just a system that appears to do nothing.

4. **Treating "not rendering" as one bug instead of a checklist.** There are at least nine independent reasons a RealityKit entity fails to render — see `rendering-pitfalls.md`. Guessing at one cause and stopping there wastes time; work the elimination checklist in order.

5. **Leaving stray components from a removed feature.** An `AnchoringComponent` left over from a cut prototype silently blocks rendering forever, waiting for an ARKit anchor that will never arrive. When you remove a feature, audit the components you added for it, not just the code that used them.

6. **Debugging app-specific systems with only the built-in inspector.** Built-in components can't explain your own state machines or targeting logic. Add debug-only visible entities and custom components (`custom-debug-tooling.md`) so app-specific bugs are just as inspectable as engine-level ones.

7. **Hand-authoring scene layout, placement, and materials directly in code.** Most rendering pitfalls trace back to content positioned, scaled, or materially configured by hand in Swift. Compose layout in **Reality Composer Pro** and load the result; reserve code for behavior (see `reality-composer-pro`).
