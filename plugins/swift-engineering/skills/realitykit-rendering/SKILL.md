---
name: realitykit-rendering
description: Use when working on RealityKit visuals — PBR vs unlit materials and Shader Graph materials, image-based lighting (IBL) and the EnvironmentRadiance node, lights (directional/point/spot/image-based), soft (area) shadows, baked lightmaps, projective textures and physical-space lighting, post-processing effects like bloom (via Metal Performance Shaders), particle emitters, and rendering 3D gaussian splats.
---

# RealityKit Rendering: Materials, Lighting & Visual Effects

RealityKit's look and feel comes from a handful of composable rendering systems layered on top of the entities and components covered in `realitykit-core`: materials that decide how a surface responds to light, lights and shadows that illuminate a scene, image-based lighting that grounds physically based materials in an environment, baked lightmaps and soft shadows for realism you don't pay for every frame, a post-processing pass over the finished frame, GPU particle emitters, and — new this cycle — real-time rendering of captured 3D gaussian splats.

> Soft shadows, lightmaps, projective textures, physical-space lighting, and gaussian splats ship in the 2025–2026 releases and are newer than this guidance's training data. Confirm exact type names, initializers, and availability against current Apple documentation. Inline `// confirm exact API` markers flag the spots most worth checking.

## Overview

Treat a scene's visual budget as a stack of choices, each opting into more realism at more cost:

```
Unlit material + baked texture   →  cheapest: no lighting math at runtime at all
PhysicallyBasedMaterial + IBL    →  reacts to a live environment, costs more than unlit
+ dynamic lights                 →  realtime shading — use sparingly
+ shadows (hard → soft)          →  soft shadows cost more samples (quality: medium/high)
+ lightmaps                      →  bakes complex *static* lighting back down to "free" textures
+ post-processing                →  a full-frame pass after everything else (bloom, grading, …)
+ particles / gaussian splats    →  additional scene content, not a lighting mode
```

The RealityKit team's own guidance for Vision Pro content is blunt about where to start: use unlit materials and baked lighting whenever possible, and use realtime/dynamic lights sparingly. Reach for PBR, IBL, soft shadows, and post-processing deliberately — for the specific objects or moments that need them — rather than as the default for a whole scene.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** It's better to have the context than to miss a pattern or make a mistake.

| Reference | Load When |
|-----------|-----------|
| **[Materials](references/materials.md)** | Choosing a material type — `SimpleMaterial`, `PhysicallyBasedMaterial` (base color/normal/roughness/metallic/AO), `UnlitMaterial`, or a Shader Graph material authored in Reality Composer Pro; why unlit + baked lighting is the default for performance; 2026 Shader Graph surface additions (PBR Surface 2, Hair surface, Portal surface) |
| **[Lighting & Shadows](references/lighting-and-shadows.md)** | Adding `DirectionalLightComponent` / `PointLightComponent` / `SpotLightComponent` (+ shadow components); soft/area shadows (`lightSize`, `quality`); baked lightmaps (indirect/AO/beauty); projective textures (patterned spotlights); physical-space lighting onto the real room (visionOS) |
| **[Image-Based Lighting](references/image-based-lighting.md)** | Setting up custom IBL (`ImageBasedLightComponent` + a receiver) so PBR materials are actually lit; why a skydome mesh alone does nothing for PBR; using the `EnvironmentRadiance` shader-graph node for cheap specular reflections inside an unlit material |
| **[Post-Processing](references/post-processing.md)** | Adding a full-frame effect (bloom, color grade, custom look) to a `RealityView` via `customPostProcessing` and `PostProcessEffect` — iOS/iPadOS/macOS/tvOS |
| **[Particles](references/particles.md)** | Adding a `ParticleEmitterComponent` (presets like Impact), authoring particles in Reality Composer Pro, or escalating to GPU-driven simulation via Compute Graph |
| **[Gaussian Splats](references/gaussian-splats.md)** | Rendering a captured real-world object/scene as a 3D gaussian splat — assembling buffers into a `BufferResource` → `GaussianSplatResource` → `GaussianSplatComponent` |

Cross-skill: entities/components/`RealityView` basics → **`realitykit-core`**. Texture packing, material instances, polygon/texture budgets → **`3d-asset-optimization`**. Authoring Shader Graph, Compute Graph, and the light baker visually → **`reality-composer-pro`**. Gaussian splats' USD representation (the Particle Fields prim) → **`usd-usdkit`**. AR anchoring and the scene-understanding mesh that physical-space lighting projects onto → **`realitykit-spatial-ar`**.

## Core Workflow

1. **Choose the cheapest material that looks right** — default to `UnlitMaterial` + baked lighting; reserve `PhysicallyBasedMaterial`/PBR Shader Graph materials for content that must react to a live environment (see `materials.md`).
2. **If using PBR, ground it in image-based lighting** — an `ImageBasedLightComponent` + receiver, or the `EnvironmentRadiance` node inside an unlit graph for a cheaper middle ground (see `image-based-lighting.md`).
3. **Light dynamically only where it matters** — `DirectionalLightComponent`/`PointLightComponent`/`SpotLightComponent`, sparingly; add the matching shadow, and soften it with `lightSize`/`quality` only where a hard shadow looks wrong (see `lighting-and-shadows.md`).
4. **Bake everything static** — indirect lighting, AO, and beauty lightmaps for lights and geometry that never move, generated with Reality Composer Pro's light baker (see `lighting-and-shadows.md`).
5. **Layer post-processing last** — bloom or a custom look via `customPostProcessing`/`PostProcessEffect`, applied after the scene itself is composed (see `post-processing.md`).
6. **Add particle emitters for atmosphere** — `ParticleEmitterComponent` presets from code or Reality Composer Pro; escalate to Compute Graph only for custom GPU simulation (see `particles.md`).
7. **Bring in real-world captures as gaussian splats** when a textured mesh isn't the right representation for the content (see `gaussian-splats.md`).

## Why Unlit + Baked Comes First

On Vision Pro, the GPU renders every pixel of what's visible, and an immersive scene can spend that budget on millions of pixels a frame — lighting cost is not academic. Apple's own asset-optimization guidance for a Vision Pro scene used **unlit materials on nearly every asset**, with lighting authored once in a DCC tool and **baked down to a single texture per object**, reserving realtime PBR and dynamic lights for the few objects that actually needed to react to the environment:

```swift
// Static environment art: bake lighting in your DCC tool, ship one texture, use UnlitMaterial.
let rockMaterial = UnlitMaterial(color: .white)   // the baked texture carries all the shading
rock.components.set(ModelComponent(mesh: rockMesh, materials: [rockMaterial]))

// A hero object whose material should react live to the world around it: opt into PBR + IBL.
var potMaterial = PhysicallyBasedMaterial()
potMaterial.baseColor = .init(texture: .init(try .load(named: "pot_diffuse")))  // confirm exact API surface
```

That same scene's skydome — the large sphere/dome that hides passthrough beyond your content — was itself unlit, and was called out as one of the very first things worth optimizing that way. Default to unlit + baked; opt individual objects into PBR, dynamic lights, and soft shadows only when they specifically need it.

## Common Mistakes

1. **Defaulting every material to PBR with realtime lights.** RealityKit's own guidance for Vision Pro content is the opposite: use unlit materials and baked textures wherever possible, and use dynamic lights sparingly. Profile before reaching for full PBR + realtime lighting across a whole scene.

2. **Assuming a skydome lights your PBR assets.** A skydome/skybox is just a mesh with a material — it contributes nothing to PBR shading. PBR objects need an explicit `ImageBasedLightComponent` plus a receiver component; without both, they light as if the environment contributed nothing.

3. **Setting a soft shadow's `lightSize` and forgetting `quality`.** Soft shadows require `quality` to be `.medium` or `.high`; at `.low` the shadow stays hard no matter how large `lightSize` is.

4. **Baking a lightmap for a light that moves.** Lightmaps (indirect/AO/beauty) freeze lighting into a texture at bake time — they're for **static** lights and geometry only. A light that animates needs realtime lighting instead.

5. **Expecting a one-property bloom toggle like SceneKit's camera.** RealityKit deliberately ships no such shortcut; implement `PostProcessEffect` and wire it up via `customPostProcessing`. It's more setup, but it's fully under your control, and you can lean on Metal Performance Shaders instead of writing shaders from scratch.

6. **Treating `EnvironmentRadiance` or PBR Shader Graph nodes as free.** They're cheaper than a full PBR material but still cost more than plain unlit — reach for them only for the assets where unlit-alone visibly isn't enough (e.g., a metal highlight that needs to catch the light).

7. **Looking for a gaussian-splat file loader.** RealityKit's gaussian-splat API doesn't assume any file format — you assemble raw per-splat buffers (position, scale, rotation, opacity, spherical harmonics + degree) into a `BufferResource` → `GaussianSplatResource` → `GaussianSplatComponent` yourself.
