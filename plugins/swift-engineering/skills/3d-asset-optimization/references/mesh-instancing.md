# Mesh Instancing with MeshInstancesComponent

> `MeshInstancesComponent` and `LowLevelInstanceData` are 2025+ APIs. Confirm exact initializers, subscript syntax, and property names against current Apple documentation.

Decorating a scene with many copies of the same prop — foliage, tiles, rocks, crates — has an obvious naive approach: clone the entity for every copy. Don't. Cloning duplicates the `ModelComponent` for every copy, which means duplicating the model and material data the GPU has to be told about — a real memory and processing cost as the count grows.

## The component

`MeshInstancesComponent` draws **one mesh many times from a single entity**. Instead of many entities each carrying their own `ModelComponent`, you supply one entity with a **list of transforms** to draw the mesh at. RealityKit sends the model and material to the GPU **once**, rather than once per copy — a significant win over cloning at any real count.

## Setting it up

`LowLevelInstanceData` follows the same reference-type, GPU-backed-buffer shape as `LowLevelMesh`/`LowLevelTexture` — you assign the (empty) handle into the component first, then populate it in place:

```swift
import RealityKit

// 1. Load the mesh you want to repeat.
let decoration = try await Entity(named: "Rock", in: realityKitContentBundle)

// 2. Create the instance-data container, sized to how many copies you need.
let instanceCount = 20
let instanceData = LowLevelInstanceData(instanceCount: instanceCount)   // confirm exact initializer

// 3. Assign it to the component, subscripted by the mesh-part index you're instancing.
//    A single-part mesh uses partIndex: 0.
var meshInstances = MeshInstancesComponent()                            // confirm exact initializer
meshInstances[partIndex: 0] = instanceData                              // confirm exact subscript API

// 4. Populate a transform per instance — randomize scale/rotation/position for variety.
for i in 0..<instanceCount {
    let transform = Transform(
        scale: .init(repeating: Float.random(in: 0.8...1.2)),
        rotation: simd_quatf(angle: Float.random(in: 0...(2 * .pi)), axis: [0, 1, 0]),
        translation: randomPositionInPlayArea()
    )
    instanceData[i] = transform.matrix                                  // confirm exact API
}

// 5. Attach it. RealityKit draws all instances whenever this entity draws.
decoration.components.set(meshInstances)
```

## The culling caveat

All of the instances drawn by one `MeshInstancesComponent` are still, as far as culling is concerned, **part of a single entity**. If you use it to cover a large area — decorating an entire outdoor space, for example — RealityKit can't cull individual instances out of view; the whole entity is either in or out. For anything covering a large area, **split the decoration across several entities**, each with its own `MeshInstancesComponent` over a smaller region, so distant/off-camera regions can still cull normally.

## Varying instances individually

By default every instance shares the same material. On **iOS, iPadOS, macOS, and tvOS**, you can pass a `LowLevelBuffer` of per-instance data to a `CustomMaterial` so each instance can look unique (tinted differently, textured differently, etc.) without needing separate materials per instance. Note this specific path is scoped to those platforms in the source material — confirm current visionOS support before relying on it there.

## Common mistakes

1. **Cloning for large counts of identical geometry.** Each clone is a full `ModelComponent` copy; at any real scale this costs meaningfully more memory and GPU upload than one `MeshInstancesComponent`.
2. **Instancing over a huge area with one entity.** Because all instances belong to one entity for culling purposes, an unsplit large-area instance never partially culls — you pay for every instance's draw setup even when most are off camera.
3. **Forgetting the mesh-part index.** `LowLevelInstanceData` is assigned to the component **subscripted by mesh part**; a simple single-part mesh uses `partIndex: 0`, but a multi-part mesh needs instance data assigned per part you intend to instance.
4. **Expecting per-instance material variation for free.** Varying appearance per instance needs the `LowLevelBuffer` → `CustomMaterial` path (and is platform-scoped); a plain `MeshInstancesComponent` alone draws every instance with the same material.
