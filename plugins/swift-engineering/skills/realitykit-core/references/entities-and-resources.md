# Entities & Resources: Loading and Building Content

> Some APIs here ship in 2025–2026 releases. Confirm exact names against current Apple documentation.

## Loading a scene authored in Reality Composer Pro

The default workflow: compose the scene in Reality Composer Pro (a Swift package), then load it as an `Entity`. RCP projects expose a generated bundle.

```swift
import RealityKit
import RealityKitContent          // your RCP package's generated module

let scene = try await Entity(named: "AlchemyArea", in: realityKitContentBundle)
content.add(scene)
```

Loading is `async` and `throws` — it reads from disk and can fail. Do it in `make` (or a `Task`), and handle the error.

## Loading from USD, a URL, or in-memory Data

RealityKit reads **USD** (`.usd`, `.usdc`, `.usda`, `.usdz`) and Reality Files.

```swift
// From a bundled/asset URL
let model = try await Entity(contentsOf: url)          // confirm exact initializer

// From in-memory Data (2025+) — stream a scene/USD from the network, then load it
let data: Data = try await download(remoteModelURL)
let streamed = try await Entity(from: data)            // confirm exact initializer; same formats as file loaders
```

The `Data` initializer is what lets you fetch or stream USDs from a server instead of bundling everything.

`ModelEntity` is a convenience `Entity` subclass that comes with a `ModelComponent` (and can generate collision shapes). Use it for a quick single model; use a plain `Entity` + components for everything composed.

## ModelComponent, meshes, and materials

Geometry + appearance live in a `ModelComponent`:

```swift
let mesh = MeshResource.generateBox(size: 0.2)
let material = SimpleMaterial(color: .blue, isMetallic: false)
entity.components.set(ModelComponent(mesh: mesh, materials: [material]))
```

`MeshResource` and material types are **resources** — reference types loaded/generated once and shared. Reuse a resource across entities instead of regenerating it. (Materials, PBR/unlit/Shader Graph, and instancing are covered in `realitykit-rendering` and `3d-asset-optimization`.)

## Finding entities in a loaded hierarchy

Loaded scenes are trees. Locate a specific entity by name:

```swift
guard let cauldron = scene.findEntity(named: "Cauldron") else { return }
```

Prefer stable names set in Reality Composer Pro. Cache the result — `findEntity(named:)` walks the subtree each call, so don't run it every frame (put the reference in a component or a stored property).

## Cloning

To place many copies of a template:

```swift
let copy = template.clone(recursive: true)   // deep-copies the subtree
```

Cloning duplicates the `ModelComponent` per copy. For **many identical** meshes (decoration, foliage, tiles), that's wasteful — use `MeshInstancesComponent` instead to draw one mesh many times from a single entity (see `3d-asset-optimization`).

## Attaching to another entity's pin (skeletons)

To fasten one entity to a specific joint of an animated skeleton, use the pin-attach API instead of manual per-frame alignment:

```swift
// Attach `sword` to a named pin/joint on `character` (2025+)
character.attach(sword, to: pinID)           // confirm exact API
```

This avoids expensive hierarchical transform updates and keeps the attached mesh locked to the joint as the skeleton animates.

## Animations from USD

When a USD carries animations, RealityKit surfaces them via an `AnimationLibraryComponent` on the loaded entity — see `systems-and-actions.md` for playback.

## Common mistakes

1. **Regenerating resources per entity.** Generate a `MeshResource`/material once and share it. Resources are reference-counted; duplicating them wastes memory and load time.
2. **Cloning where instancing belongs.** Hundreds of clones = hundreds of `ModelComponent`s and draw setups. Use `MeshInstancesComponent` for large numbers of identical meshes.
3. **Calling `findEntity(named:)` every frame.** It traverses the subtree. Resolve once, store the reference.
4. **Ignoring load errors.** `Entity(named:in:)` / `Entity(contentsOf:)` throw. A missing asset or wrong bundle throws at load — don't `try?`-swallow it silently during development.
