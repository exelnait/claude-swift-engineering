---
name: reality-composer-pro
description: Use when authoring RealityKit content in Reality Composer Pro 3 — composing scenes from entities/components and import bundles, prototypes and instancing, Shader Graph materials, Script Graph (no-code interactivity), Animation Graph state machines, Behavior Trees, Compute Graph particle systems, navigation-mesh authoring, lightmap baking, live preview on device, the Reality Composer Pro Assistant, and extending the editor with custom components/systems/actions/nodes via an Xcode plugin.
---

# Reality Composer Pro: Visual Authoring for RealityKit

Reality Composer Pro is Apple's visual editor for building RealityKit content — scenes, materials, particle systems, character animation, and no-code interactivity — without writing Swift for every detail. Reality Composer Pro 3 is a **standalone app** (downloaded from developer.apple.com, launched from Applications — no longer an Xcode-bundled tool) built around one goal: get you as far as possible before you ever need to touch Xcode.

> Reality Composer Pro 3 and several capabilities described here (Live Preview / Preview on Device, the editor plugin system) shipped in the 2025–2026 cycle, and the source material notes some ship "later in the year." Confirm exact node names, type names, and current availability against current Apple documentation.

## Overview

Reality Composer Pro is the visual front end to the same Entity Component System that `realitykit-core` covers in code. Every entity, component, material node, particle graph, animation state machine, behavior tree, and script graph you build here compiles down to ordinary RealityKit data — nothing authored visually is "special" at runtime. The editor's job is to get you there faster: a **Play** button and dockable **simulation tab** for instant iteration, **prototypes** for reusable objects, **Live Preview** to run live on a Vision Pro while you keep editing, **Lightmaps** to bake expensive lighting once, and an **AI Assistant** that generates 3D content on demand. When the visual tools aren't enough — a Script Graph has grown unwieldy, or you need an API only Swift can reach — an **Xcode plugin** lets you add custom components, systems, animation actions, and even new Script Graph nodes that run live inside the editor itself.

The output is always the same regardless of how it was authored: the Reality Composer Pro project is a **Swift package** you add to Xcode as a local dependency, or a **Reality File** you export — either way, your app loads it as an `Entity` and hosts it in a `RealityView` (see `realitykit-core`).

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** It's better to have the context than to miss a pattern or make a mistake.

| Reference | Load When |
|-----------|-----------|
| **[Scene Composition](references/scene-composition.md)** | Importing USD as an optimized import bundle, building a scene from entities/components, hierarchy and transform editing, prototypes and instancing (overrides, reset, propagate), the dockable simulation tab, and adding the RCP project's Swift package to Xcode |
| **[Shader Graph](references/shader-graph.md)** | Node-based materials — RealityKit PBR Surface 2 (sheen, subsurface scattering), the Hair surface shader, Portal surface / Portal Geometry Modifier, Normal Map Decode vs. the NormalMap node, the EnvironmentRadiance node, and Promote to Input + Material Instances |
| **[Script Graph](references/script-graph.md)** | No-code visual scripting — event nodes (On Initialize / On Drag / On Tap / Update), Set nodes that write into components, public input variables and per-instance overrides, custom events via a Custom Node Library, (Prototyped) Subgraphs, and Scene Events that cross into Swift/SwiftUI |
| **[Animation Graph & Behavior Trees](references/animation-graph-and-behavior-trees.md)** | Blending character animation with a State Machine and transition conditions, authoring autonomous routines with Behavior Tree Composite/Action nodes, and pathfinding with the Navigation Mesh |
| **[Compute Graph & Particles](references/compute-graph-particles.md)** | GPU-driven particle/simulation systems — the Emitter/Initialize/Simulate/Output phases, the Compute Simulation component, and custom Compute Graph nodes |
| **[Lightmaps & Live Preview](references/lightmaps-and-live-preview.md)** | Baking indirect lighting/ambient occlusion/beauty for static lights, previewing and authoring live on a connected Vision Pro, and the Reality Composer Pro Assistant |
| **[Plugins & Custom Components](references/plugins-custom-components.md)** | Extending the editor from Xcode — `RealityComposerProPlugin`, custom `Component` / `System` / `EntityAction`, exposing custom Script Graph nodes with `@Scriptable`, and the team workflow (git, JSON, the trust-plugin dialog, Reality File export) |

Cross-skill: entity/component/system fundamentals, `RealityView`, and loading a scene in code → **`realitykit-core`**. Deeper materials/lighting/shadows → **`realitykit-rendering`**. Physics, collision, and consuming a Navigation Mesh at runtime → **`realitykit-physics-interaction`**. SwiftUI attachments, gestures, manipulation → **`realitykit-swiftui`**. Mesh/texture budgets and performance → **`3d-asset-optimization`**. USD authoring and interchange → **`usd-usdkit`**. Scanning real objects into USD → **`object-capture`**. AR anchoring and scene understanding → **`realitykit-spatial-ar`**. Diagnosing a broken or missing scene → **`realitykit-debugging`**.

## Core Workflow

1. **Get the editor.** Download Reality Composer Pro 3 from developer.apple.com and launch it from Applications — it's a standalone app now, not a panel inside Xcode.
2. **Import assets.** Bring in USD files from your DCC tool (Blender, Maya, …); each import becomes an optimized **import bundle** in the Project Browser. Drag it into the viewport to create an entity.
3. **Compose the scene.** Build hierarchy by nesting entities; add components (lights, physics, audio, Compute Simulation, and more) via **Add Component**; position everything with the Transform component (see `references/scene-composition.md`).
4. **Turn reused objects into prototypes.** Drag an entity into the Project Browser to make it a reusable prototype; instantiate it as many times as you like and override per-instance properties without touching the source.
5. **Author behavior visually.** Reach for Shader Graph for materials, Script Graph for event-driven interactivity, Animation Graph + Behavior Trees for character motion and autonomy, and Compute Graph for GPU particle/simulation effects.
6. **Iterate without leaving the editor.** Press Play and dock the simulation tab to keep authoring while it runs; switch to Live Preview / Preview on Device to run the same session live on a connected Vision Pro.
7. **Bake what's static.** Use the Lightmap component to precompute indirect lighting/ambient occlusion for lights that don't move; reach for the RCP Assistant to generate quick 3D content on demand.
8. **Ship it.** Add the RCP project as a local Swift package dependency in Xcode (or export a Reality File), load it with `Entity(named:in:)` inside a `RealityView` (see `realitykit-core`).
9. **Extend the editor when you outgrow no-code.** Build an Xcode plugin implementing `RealityComposerProPlugin` to add custom components, systems, animation actions, and Script Graph nodes that artists can use without writing Swift themselves (see `references/plugins-custom-components.md`).

## From Editor to App

Whatever you build in Reality Composer Pro reaches your app the same way any RealityKit content does — there is no special loading API for "stuff made in the editor."

```swift
import RealityKit
import RealityKitContent   // the RCP project's generated Swift package module

struct GameView: View {
    var body: some View {
        RealityView { content in
            if let scene = try? await Entity(named: "AlchemyArea", in: realityKitContentBundle) {
                content.add(scene)
            }
        }
    }
}
```

Everything you authored — the prototypes, the Script Graphs, the Animation Graph's State Machine, the Compute Graph particle effect, the baked Lightmap — comes along as ordinary components on the loaded entity tree. Code only needs to find the entities it cares about (`scene.findEntity(named:)`) and react to the Scene Events it sends; see `realitykit-core`'s `entities-and-resources.md` and `realityview.md`.

## Common Mistakes

1. **Expecting Reality Composer Pro inside Xcode.** RCP 3 is a standalone download and app. If your muscle memory says "open it from Xcode," that habit is stale — get it from developer.apple.com.

2. **Confusing a prototype override with an edit to the source.** Tweaking an instance's property creates a per-instance override (Script Graph public variables behave identically — the field goes bold). Right-click → **Reset** discards an override back to the source value; propagate it back to the source if you actually want every instance to change. Nothing is permanent until you choose that.

3. **Authoring GPU/simulation-only behavior and expecting to see it in the static scene view.** Compute Graphs, physics, and Script Graphs that respond to Update/gesture events only run during simulation — press Play, or dock the simulation tab so you can keep editing values while it runs.

4. **Forgetting to re-bake Lightmaps after moving a static light.** A Lightmap is a snapshot of indirect lighting. Relight a scene and skip the re-bake, and the old bounced light stops matching the new lighting — a scene that "looked fine yesterday" is almost always this.

5. **Hand-rolling in Script Graph what Animation Graph or Behavior Tree already solve.** Blending idle/walk animations by hand, or threading a patrol routine through booleans and Update nodes, works — but it's what the State Machine and Behavior Tree composite/action nodes exist to do visually, with live debugging (the active state highlights as it runs).

6. **Growing a Script Graph until it's unmaintainable instead of reaching for a plugin.** Script Graph and a custom Swift `Component`/`System` can solve the same problem; a very large graph is a legitimate signal to move that logic into code you can test, review, and call other APIs (like SwiftUI) from — see `references/plugins-custom-components.md`.

7. **Forgetting custom editor extensions need a rebuild + restart to take effect.** A custom component, system, action, or Script Graph node lives in a dynamic library the editor loads once at launch. Change the Swift code, rebuild the plugin scheme, and restart the editor (expect the trust-plugin dialog again) — it will not hot-reload.
