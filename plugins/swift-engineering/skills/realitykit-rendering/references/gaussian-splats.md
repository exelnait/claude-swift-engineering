# 3D Gaussian Splats

> Some APIs here ship in 2025–2026 releases. Confirm exact names against current Apple documentation.

**3D gaussian splats** are a technique for rendering real-world volumetric captures at high fidelity and high performance. Instead of a textured mesh, a scene is represented as a dense collection of 3D gaussians — think of them as ellipsoids, each with its own opacity. Rendering evaluates a ray through the overlapping gaussians at every pixel; RealityKit's gaussian-splat API applies the necessary rendering optimizations for you, so you get GPU-efficient rendering of a technique that would otherwise be expensive to evaluate naively. This is the technology behind capturing something like a potted plant — down to the texture of the soil — and dropping it directly into a virtual scene at high fidelity.

## The data model

RealityKit doesn't assume any particular gaussian-splat **file format**. Instead, you supply raw **buffers** describing every splat's:

- **Position**
- **Scale**
- **Rotation**
- **Opacity**
- **Spherical harmonics**, plus a **degree** — spherical harmonics let a single splat's color vary by viewing direction. Degree 0 means a flat, view-independent color; higher degrees add progressively more view-dependent color variation.

This is the same data a capture/reconstruction pipeline produces; RealityKit's job starts once those buffers are in hand.

## Assembling and rendering

```swift
import RealityKit

// 1. Wrap your raw per-splat buffers (position, scale, rotation, opacity, spherical harmonics).
let splatBuffers = BufferResource(/* ... */)  // confirm exact initializer/API surface

// 2. Build the gaussian-splat resource from those buffers, specifying the spherical-harmonics degree.
let splatResource = try GaussianSplatResource(buffers: splatBuffers, sphericalHarmonicsDegree: 0)  // confirm exact initializer

// 3. Wrap the resource in a component…
let splatComponent = GaussianSplatComponent(resource: splatResource)  // confirm exact initializer

// 4. …and attach it to an entity, same as any other renderable component.
let plant = Entity()
plant.components.set(splatComponent)
content.add(plant)
```

The pipeline is deliberately symmetrical with `ModelComponent`: a resource holds the heavy data, a component attaches it to an entity, and the entity is what you actually place, move, and parent in your scene.

## USD representation

Gaussian splats have a home in USD too: a new **Particle Fields** primitive (introduced this cycle with Alliance for OpenUSD partners including NVIDIA, Adobe, and Pixar) describes splats — and other emerging point-cloud-like representations — inside the same scene graph as ordinary meshes and materials, putting captured volumetric data and traditional 3D content side by side in one USD file for the first time. See `usd-usdkit` for the USD/OpenUSD side of this.

## Common mistakes

1. **Looking for a standard splat file loader.** There isn't one; RealityKit consumes buffers you assemble yourself (position/scale/rotation/opacity/spherical harmonics), not a specific on-disk splat format.
2. **Guessing at the spherical-harmonics degree.** Degree 0 is a flat per-splat color; mismatching the degree against what your capture pipeline actually produced either drops view-dependent color data or misreads the buffer layout.
3. **Treating a `GaussianSplatComponent` like a `ModelComponent` for physics or collision.** Splats are a rendering representation of captured volumetric data, not collision geometry — pair with your own collision shapes if the object needs to be physically interactive.
4. **Expecting to hand-author splats in Reality Composer Pro the way you'd model a mesh.** Splats come from a capture/reconstruction pipeline, not manual modeling; Reality Composer Pro and RealityKit consume the result, they don't create it.
5. **Forgetting the USD side.** If splat data needs to move between DCC tools or USD pipelines, use the new Particle Fields prim rather than inventing a custom schema (see `usd-usdkit`).
