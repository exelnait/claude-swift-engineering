---
name: 3d-asset-optimization
description: Use when optimizing 3D assets and scenes for performance on iOS and visionOS — polygon/triangle budgets and what's visible at once, texture packing and compression, color spaces and normal-map setup, material instances, mesh instancing with MeshInstancesComponent, skydome and IBL texture sizing, AVIF and mesh compression, and level-of-detail (LOD) with thermal-state adaptation.
---

# 3D Asset Optimization for Spatial Computing

Getting a 3D scene to look great *and* run well comes down to matching your asset budget to how the scene is actually seen, then spending your triangle and texture budget where the viewer is actually looking. This skill covers the practical levers, in roughly the order you'd apply them: modeling and export, texture setup, material reuse, instancing repeated geometry, lighting the scene cheaply, and degrading gracefully under thermal pressure.

> Several APIs referenced here — `MeshInstancesComponent`, `LevelOfDetailComponent`, and the AVIF/mesh-compression export options — ship in the 2025–2026 releases and are newer than this guidance's training data. Confirm exact type names, initializers, and availability against current Apple documentation. Inline `// confirm exact API` markers flag the spots most worth checking.

## Overview

The one fact that drives almost every decision in this skill: **the GPU is only responsible for pixels you actually draw, not passthrough.** GPU cost scales with how large and how immersive your app appears, not with some fixed device budget:

```
Windowed / volume    →  smallest GPU cost — mostly passthrough, a modest window of virtual content
Shared space         →  moderate cost — other apps share the frame, but yours still renders every frame
Fully immersive      →  largest cost — your app renders the ENTIRE view, every frame, no passthrough at all
```

This framing is visionOS-centric (windowed/shared-space/immersive are visionOS constructs), but the underlying principle holds everywhere: on iOS, the equivalent question is simply how much of the screen is RealityKit content versus 2D UI. Because the exact ceiling depends on device, scene complexity, and what's on screen, **test early and often on real hardware** rather than trusting a desktop preview.

The second fact: budgets are about what's **visible at any one time**, not the size of the whole scene. Chunk large content so off-camera parts cull, and spend texture/geometry detail where the viewer will actually be looking.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** It's better to have the context than to miss a pattern or make a mistake.

| Reference | Load When |
|-----------|-----------|
| **[Polygon and Scene Budgets](references/polygon-and-scene-budgets.md)** | Setting a triangle budget for a scene, deciding immersive vs. shared-space targets, chunking large objects (terrain) for culling, or planning on-device performance testing |
| **[Textures and Compression](references/textures-and-compression.md)** | Texture packing (roughness/metallic/AO into one RGB texture), choosing transfer function/gamut color spaces, normal-map format and range, AVIF export, mesh compression, and scaling texture resolution by distance |
| **[Material Instances](references/material-instances.md)** | Reusing one Shader Graph material's logic across many assets by promoting parameters to inputs and creating instances, instead of authoring/duplicating a full material per asset |
| **[Mesh Instancing](references/mesh-instancing.md)** | Drawing the same mesh many times cheaply with `MeshInstancesComponent` and `LowLevelInstanceData` instead of cloning entities, and when to split instanced content across entities for culling |
| **[Skydomes and IBL Sizing](references/skydomes-and-ibl-sizing.md)** | Building a skydome/skybox, sizing and cropping its texture, and setting up a *separate*, much smaller image-based-lighting (IBL) texture so PBR assets pick up scene lighting |
| **[Level of Detail and Thermal State](references/level-of-detail-and-thermal.md)** | Setting up `LevelOfDetailComponent` (by camera distance or by screen area) and reacting to `ProcessInfo` thermal-state changes by degrading quality gracefully |

Cross-skill: authoring scenes, materials, and Shader Graph visually → **`reality-composer-pro`**. Full PBR shading, lighting, shadows, and the `EnvironmentRadiance` node in depth → **`realitykit-rendering`**. USD composition, layers, and the `exportPackage` compression API → **`usd-usdkit`**. Turning real-world scans into source assets → **`object-capture`**. Profiling a scene and chasing down what's actually slow → **`realitykit-debugging`**. The entity/component fundamentals everything here builds on → **`realitykit-core`**.

## Core Workflow

1. **Decide your viewing context first** — windowed/volume, shared space, or fully immersive — since it sets your triangle and texture budgets before you model anything (see `polygon-and-scene-budgets.md`).
2. **Model at the right polycount for viewing distance**, then export from your DCC tool as USD, watching for coordinate (-Z forward, +Y up) and unit (meters) differences on import.
3. **Set up textures and materials** in Shader Graph: pack grayscale channels together, pick the color space that matches authored intent, and decode normal maps correctly (see `textures-and-compression.md`).
4. **Turn a one-off material into a Material Instance** so every new asset reuses the same Shader Graph logic instead of a fresh copy (see `material-instances.md`).
5. **Decorate with repeated meshes** using `MeshInstancesComponent` instead of cloning entities one by one (see `mesh-instancing.md`).
6. **Build a skydome** and a separate, much smaller IBL texture, then wire up both the image-based-light and receiver components so PBR assets actually pick up the lighting (see `skydomes-and-ibl-sizing.md`).
7. **Add LOD and react to thermal state** so quality degrades gracefully under load instead of dropping frames (see `level-of-detail-and-thermal.md`).
8. **Profile continuously** — RealityKit Trace and the RealityKit Debugger (see `realitykit-debugging`) — and check the Statistics panel in Reality Composer Pro against your budget.

## Triangle Budgets by Viewing Context

| Context | Triangle budget | Why |
|---|---|---|
| Fully immersive scene | ~500,000 total | The GPU renders the entire view, every frame — no passthrough |
| Shared space app | ~250,000 total | Other apps share the frame; yours draws a smaller portion of it |
| Visible at any one time (either context) | ~100,000 | A safe target that leaves headroom regardless of total scene size |

These are guidelines, not hard limits — Apple's own sample scene landed at 108,000 triangles total and, because it was chunked, rendered roughly half of that per frame.

## LOD + Thermal State in Practice

```swift
import RealityKit
import Foundation

// LODs are arrays of entities; index 0 is the highest detail.
var lod = LevelOfDetailComponent(levels: [highDetail, mediumDetail, lowDetail])   // confirm exact initializer
lod.addByCameraDistance(maxDistances: [4.0, 12.0, .infinity])                     // confirm exact API; last LOD always gets .infinity
cauldron.components.set(lod)

// React to thermal pressure by making LOD switching more aggressive.
NotificationCenter.default.addObserver(
    forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main
) { _ in
    switch ProcessInfo.processInfo.thermalState {
    case .nominal, .fair:
        break                          // mitigation is working (or none needed) — keep current settings
    case .serious, .critical:
        applyAggressiveLODThresholds() // e.g. shrink each maxDistance, drop shadow quality
    @unknown default:
        break
    }
}
```

## Common Mistakes

1. **Budgeting the whole scene instead of what's actually on screen.** The ~500k/~250k numbers are totals, but the real target is triangles *visible at once* (~100k for headroom). Split large single objects — terrain, environments — into chunks so off-camera pieces can be culled.

2. **Assuming a fixed performance budget without testing on device.** GPU cost scales with how large or immersive your app appears — passthrough is free, virtual pixels aren't — so a windowed app and a fully immersive one have very different headroom. Test early on real hardware rather than guessing from a desktop preview.

3. **Leaving grayscale textures unpacked.** Roughness/metallic/AO shipped as separate grayscale files don't get compressed on their own. Pack them into the R/G/B channels of one texture (up to ~40% smaller PBR asset) and unpack with a data-typed image node plus a channel-separate node in Shader Graph.

4. **Getting normal maps backwards.** Two independent failure modes: wrong format (RealityKit expects OpenGL-style normal maps; DirectX inverts the green channel) and wrong range (the texture stores 0...1, the shader needs -1...1). Use the `Normal Map Decode` node for the range remap — the similarly named `NormalMap` node does *not* do this, unlike Blender's node of the same name.

5. **Expecting a skydome to light PBR assets.** A skydome/skybox is just an unlit mesh — it doesn't shade anything. PBR materials need an explicit image-based-light component (a small HDR lat/long texture) *and* an image-based-light-receiver component on the receiving hierarchy, linked to that IBL entity. Skip either one and lighting/reflections won't appear.

6. **Cloning instead of instancing repeated geometry.** Cloning an entity many times duplicates its `ModelComponent` — and the GPU upload that goes with it — per copy. Use `MeshInstancesComponent` for repeated decoration, but remember all of its instances belong to *one* entity: split a large decorated area into several instanced entities so culling keeps working.

7. **Treating alpha transparency as free.** Overlapping transparent layers force the GPU to shade the same pixel repeatedly (overdraw). Prefer opaque geometry where you can afford the triangles — e.g. modeling grass blades instead of alpha-cutout cards — it's usually a better trade within your triangle budget than stacked transparency.
