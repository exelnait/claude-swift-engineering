# Scene Composition: Entities, Components & Import Bundles

> Reality Composer Pro 3 shipped in the 2025–2026 cycle. Confirm exact menu names and APIs against current Apple documentation.

## Reality Composer Pro 3 is a standalone app

Older guidance (and muscle memory) may say Reality Composer Pro ships inside Xcode. As of version 3 that's no longer true: download it from developer.apple.com and launch it straight from your Applications folder. It still links back to an Xcode project — set that link up from the simulation toolbar's **Run with Xcode** option — but the editor itself is independent, built for fast, iterative, and collaborative workflows that don't require a build cycle for every change.

## Importing assets: USD → import bundle

Bring a model in with the import-asset icon in the Project Browser (or drag a file in directly) and point it at a USD file exported from your DCC tool. On import, its contents get reorganized and **optimized into an import bundle** — expand the bundle in the Project Browser to inspect the geometry, materials, and textures it contains before you build on it. Drag the bundle into the viewport to add it to the scene; this creates an **entity**, visible in the Hierarchy panel with a Transform component already in the Inspector.

## Entities & components are the core building blocks

Entities and components are what everything in Reality Composer Pro is made of — the same ECS model `realitykit-core` covers in Swift. An entity on its own is just a Transform; every capability comes from a component you attach with the **Add Component** button: lights, physics, audio, Compute Simulation, and many more.

Two grounded examples:

- **A point light.** Add a child entity (context menu → **Add Child Entity**), name it, add a **Point Light** component, then adjust its position, color, intensity, and attenuation falloff directly in the Inspector.
- **A Compute Simulation.** Add a **Compute Simulation** component to an entity, then pick one of the project's Compute Graph assets from its **Compute Graph picker** (a project can hold several — e.g. a "Magic Graph" and a "Brewing Graph" — and the picker lists all of them). See `compute-graph-particles.md` for what the graph itself does.

## Hierarchy & transform editing

The Hierarchy panel lists every entity in the scene; drag to reorder or nest entities as children (e.g. moving a prop underneath the piece of furniture it sits on). Select an entity and edit its Transform component's fields to position, rotate, and scale it. Press **f** to frame the selected entity in the viewport, and use **Focus Mode** (View menu) to isolate part of a large scene while you work on it.

## Prototypes & instancing

Drag any entity from the Hierarchy into the Project Browser to turn it into a **prototype** — a reusable asset. Drag the prototype into the viewport to **instantiate** it; instantiate it as many times as you like.

Each instance can diverge from its source without touching it:

- Changing a property on an instance (which Compute Graph it uses, a light's color, an attenuation falloff, …) creates a per-instance **override**.
- Right-click an overridden property → **Reset** to discard the override and fall back to the source's value.
- An override can also be pushed ("propagated") back to the source, which updates every instance that shares it.

Edit the shared logic once; customize what needs to differ per instance; nothing is permanent unless you choose that.

## The simulation tab

Pressing **Play** (via the launch control at the top of the workspace) starts simulating the scene — physics, Script Graphs, Animation Graphs, and Compute Graphs all run live. **Dock the simulation tab** next to the scene tab to keep authoring while the simulation runs: drag an effect into place, tweak a graph parameter, and see the result immediately, with no deploy step between an edit and seeing it. This is the same tab Live Preview extends onto a physical Vision Pro (see `lightmaps-and-live-preview.md`).

## From editor to app: the Swift package

A Reality Composer Pro project *is* a Swift package. Add it to your Xcode project as a local dependency (Package Dependencies → **Add Local…** → choose your app target), then load its scene from a `RealityView`:

```swift
import RealityKit
import RealityKitContent   // the RCP project's generated package module

RealityView { content in
    if let scene = try? await Entity(named: "AlchemyArea", in: realityKitContentBundle) {
        content.add(scene)
    }
}
```

Loading is `async`/`throws` — do it in `make` (or a `Task`) and handle failure. See `realitykit-core`'s `entities-and-resources.md` and `realityview.md` for the full loading, `findEntity(named:)`, and cloning story.

## Common mistakes

1. **Looking for Reality Composer Pro inside Xcode.** It's a standalone app now — download and launch it independently, and link it to your Xcode project via **Run with Xcode** rather than expecting it to appear as an Xcode panel.
2. **Skipping the import bundle inspection.** The import step optimizes a USD into geometry/materials/textures you can expand and check — don't assume an import "just worked" without a quick look inside the bundle.
3. **Being surprised that editing one prototype instance doesn't change the others.** That's an override, scoped to the instance. Reset it to discard, or propagate it if you want the change everywhere.
4. **Expecting Compute Graphs (or other simulation-only behavior) to animate in the plain scene view.** They only evaluate during simulation — press Play or open the simulation tab.
5. **Not docking the simulation tab.** Undocked, you lose the ability to keep tweaking values while the scene runs — dock it next to the scene tab for the fast edit-while-playing loop the whole editor is built around.
