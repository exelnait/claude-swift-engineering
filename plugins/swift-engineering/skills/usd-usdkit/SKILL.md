---
name: usd-usdkit
description: Use when working with USD/OpenUSD and the USDKit framework — USD concepts (layers, stages, prims, schemas, attributes), composition and references, choosing between USDA/USDC/USDZ, the USDKit Swift API for loading/traversing/editing/exporting stages, MaterialX and OpenPBR materials, mesh/texture compression, USD accessibility metadata, conversion tooling, and the Safari Model tag for 3D on the web.
---

# USD & USDKit: Universal Scene Description on Apple Platforms

USD (Universal Scene Description) is the data model and file format behind nearly every spatial experience Apple platforms render — the scenes Reality Composer Pro edits, the assets RealityKit loads, the thumbnails Quick Look and AR Quick Look generate, App Store Tags, and now 3D embedded directly in a web page. Created by Pixar and developed since as the open-source **OpenUSD** project, USD is Apple's chosen 3D interchange standard across iOS, iPadOS, macOS, tvOS, and visionOS. It's the substrate the rest of this plugin's spatial-computing skills sit on top of: Reality Composer Pro scenes are USD, what `object-capture` scans becomes USD, and what `3d-asset-optimization` tunes is USD. **USDKit** is Apple's system framework (2026) for working with USD natively in Swift.

> Because integrating USD can get complex, Apple offers three ways in, all reading and writing the same files: **USDKit** (system-provided, deeply integrated with RealityKit and Spatial Preview — start here for app development), **SwiftUSD** (open-source Swift bindings via Swift Package Manager, for needs USDKit doesn't cover), or embedding **OpenUSD** directly as a C++ framework for cross-platform codebases. Pick based on where your code lives, not format lock-in — a USD asset moves freely between all three.

> Several APIs referenced across these skills ship in the 2025–2026 releases and are newer than this guidance's training data. Confirm exact type names, initializers, and availability against current Apple documentation. Inline `// confirm exact API` markers flag the spots most worth checking.

## Overview

USD models a scene as layers that compose into a stage:

```
Layer          →  a single data file (.usda / .usdc)
Composition    →  the mechanism that combines layers together (references, and more)
Stage          →  the composed result — your window into the full scene
Prim           →  an object in the scene; has a Schema that defines its type
Attributes     →  the actual data a prim carries
Metadata       →  information describing the prim itself
```

The reason this model has taken over so much of the 3D industry — film, games, AR, manufacturing, robotics simulation — is **composition**: an artist, a tool, or you can each work on your own layer, and USD combines them into one stage. Reference someone else's asset instead of copying it, and their future updates show up in your stage automatically, with no re-export or re-import. USDKit brings exactly this model to Swift: a `USDStage` you open, traverse, edit, and export, ready to hand straight to RealityKit or preview live on Vision Pro through Spatial Preview.

Same underlying data, three container formats depending on the job: **USDA** (text, collaborative), **USDC** (binary, efficient for geometry), **USDZ** (zipped, self-contained for distribution). See `file-formats.md` for which to pick.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** It's better to have the context than to miss a pattern or make a mistake.

| Reference | Load When |
|-----------|-----------|
| **[USD Fundamentals](references/usd-fundamentals.md)** | The conceptual model — layers, composition, stages, prims, schemas, attributes/metadata, how references let teams collaborate, and how MaterialX/OpenVDB integrate with USD |
| **[File Formats](references/file-formats.md)** | Choosing USDA vs. USDC vs. USDZ for a scene, an asset, or a distributable package, and why Reality Composer Pro standardizes on one of them |
| **[USDKit API](references/usdkit-api.md)** | Writing Swift against USD — `USDStage()` / `.open(url)`, traversing a stage, defining prims, `addReference`, moving a prim with `addTransformOperation`, `exportPackage`, and how USDKit relates to SwiftUSD and embedding OpenUSD directly |
| **[Materials, OpenPBR & Splats](references/materials-openpbr-and-splats.md)** | OpenPBR materials, choosing a Preview/Quick Look renderer (RealityKit, Storm, the new Raytracer), and the new Particle Fields prim type for Gaussian Splats |
| **[Compression & Accessibility](references/compression-and-accessibility.md)** | Shrinking assets with mesh + AVIF texture compression (`exportPackage`, Preview, `usdcrush`), and adding standardized USD accessibility metadata (`AccessibilityAPI`, label/description) |
| **[Conversion & Web](references/conversion-and-web.md)** | Getting existing assets (DCC exports, legacy SceneKit `.scn` files) into USD, and shipping USD to the web with Safari's Model tag and the Spatial Preview framework |

Cross-skill: authoring scenes visually → **`reality-composer-pro`**. Loading a USD/RCP scene as a RealityKit entity → **`realitykit-core`**. Shader Graph materials, lighting, and rendering Gaussian Splats → **`realitykit-rendering`**. Triangle/texture budgets for spatial computing → **`3d-asset-optimization`**. Scanning a real object into USD via photogrammetry → **`object-capture`**.

## Core Workflow

1. **Create or open a stage** — `USDStage()` for a fresh in-memory stage, or `USDStage.open(url)` (throws) for an existing file (see `usdkit-api.md`).
2. **Traverse the hierarchy** to see what's already there before adding anything.
3. **Define new prims** at the path where they belong, or **`addReference`** an external asset instead of copying its data in — composition, not duplication.
4. **Position prims** with `addTransformOperation`, then set the resulting translation/rotation/scale.
5. **Add accessibility metadata** — apply `AccessibilityAPI`, then author `label`/`description` (see `compression-and-accessibility.md`).
6. **Export**, enabling mesh + texture compression through `exportPackage`'s options — or do it with no code, in Preview or `usdcrush`.
7. **Choose the right container** for how the result will be used — USDA, USDC, or USDZ (see `file-formats.md`).

## A Complete USDKit Pass

```swift
import USDKit

// Open an existing scene. Touches the filesystem, so it throws.
let stage = try USDStage.open(sceneURL)          // confirm exact API — throws vs. async throws unconfirmed

// Look for an asset that should already be here.
let alreadyPresent = stage.traverse()                          // confirm exact traversal API
    .contains { $0.path == "/Bench/Oscilloscope" }              // confirm exact Prim path accessor

if !alreadyPresent {
    // Define where the new prim will live, then compose in the external
    // asset as a lightweight reference — not a copy. Its author's future
    // edits flow into this stage automatically.
    let oscilloscope = stage.defineTransform(at: "/Bench/Oscilloscope")  // confirm exact API — unconfirmed name/signature
    oscilloscope.addReference(oscilloscopeAssetURL)                       // confirm exact signature

    // Move it onto the workbench.
    oscilloscope.addTransformOperation(.translate)                        // confirm exact API — enum case unconfirmed
    oscilloscope.translation = SIMD3<Float>(0.2, 0.9, -0.4)                // confirm exact property name/type
}

// Ship it, compressed.
var options = USDExportOptions()                 // confirm exact type name
options.meshCompression = true
options.textureCompression = true
try stage.exportPackage(to: outputURL, options: options)
```

## Common Mistakes

1. **Copying an external asset into your stage instead of referencing it.** Composition is USD's core superpower: reference the asset (`addReference`) and its author's future edits flow into your stage automatically. Copy the data instead, and you've silently forked it from day one.

2. **Hand-writing transform attributes instead of using `addTransformOperation`.** It creates the right attributes and maintains the transform op order for you; hand-authoring risks a malformed or misordered transform stack that other USD tools disagree on how to interpret.

3. **Picking a file format for the wrong job.** A large collaborative scene authored as USDC can't be merge-resolved by two artists editing at once; a heavy asset shipped as loose USDA (instead of USDZ) arrives without its textures bundled. Match the format to the job — see `file-formats.md`.

4. **Assuming USDKit has a typed convenience API for every schema.** It doesn't — yet. For `AccessibilityAPI`, USDKit gets you as far as applying the schema; the `label` and `description` attributes have to be authored directly, using the exact attribute names the specification defines.

5. **Shipping an uncompressed multi-gigabyte scene.** Production USD scenes get big fast. Mesh compression (up to ~90% smaller) plus AVIF texture compression make the average asset ~7x smaller with no visible quality loss — enable both through `exportPackage`'s options, Preview, or `usdcrush`, and don't skip it just because it "already works" on a fast dev connection.

6. **Treating Gaussian Splats as a separate pipeline from "real" 3D content.** The new Particle Fields prim type describes splats as first-class USD data, composable in the very same stage as your meshes and materials — not a special case bolted on afterward.

7. **Skipping accessibility because it's "just a 3D model."** USD accessibility metadata is standardized specifically so assistive technologies can describe spatial content, and it's authorable from any USD API (including directly in Blender/Maya). Treat `AccessibilityAPI` label/description as a normal part of finishing an asset, not an optional extra.
