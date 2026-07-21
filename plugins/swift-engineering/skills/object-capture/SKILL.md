---
name: object-capture
description: Use when generating 3D models from photographs with Apple's Object Capture / photogrammetry API — creating a PhotogrammetrySession from a folder of images, handling its async output message stream, requesting models at different detail levels, the interactive bounding-box refinement workflow, image-capture best practices, and producing USDZ assets for RealityKit apps.
---

# Object Capture: Photogrammetry to USDZ

Object Capture turns a folder of ordinary photographs of a real-world object into a textured 3D model — a geometric mesh plus PBR material maps — using photogrammetry. It's the `PhotogrammetrySession` API, and it ships as part of **RealityKit**, but it's a **macOS-side asset-creation tool**, not something you call at runtime from an iOS app: you (or a build pipeline) run it once, on a Mac, to produce a USDZ (or USDA/OBJ) file, and that file ships inside — or is downloaded into — your iOS, iPadOS, or visionOS app like any other 3D asset. Apple also ships `HelloPhotogrammetry`, a sample command-line app, so you can try building a model from a folder of images before writing any code at all.

> Object Capture's shape — `PhotogrammetrySession`, `PhotogrammetrySample`, its `Request`/`Output` enums — has been stable since its 2021 introduction, so it predates most of this plugin's newer material. Even so, confirm exact type names, initializers, and availability against current Apple documentation before shipping; Apple has continued to extend detail levels and capture options since, and the inline `// confirm exact API` markers below flag the spots most worth double-checking.

## Overview

Every Object Capture pipeline has the same two phases:

1. **Setup** — create a `PhotogrammetrySession` from a folder of images (or, for advanced pipelines, a sequence of `PhotogrammetrySample`s you build yourself), then connect its async output stream so you can see progress and results as they arrive.
2. **Process** — make one or more requests on the session (a finished `.usdz` file, a live `ModelEntity`, or the estimated `BoundingBox`), each at a chosen detail level, and let the session report back on the stream.

A third, optional phase sits between them for interactive apps: request a fast, low-quality **preview** model plus its bounding box, let the user trim unwanted geometry and fix scale/orientation, refine, and only then pay for the expensive final reconstruction.

The API runs on recent Intel Macs but is **fastest on Apple silicon**, where it uses the Neural Engine to accelerate the underlying computer-vision models. Nothing about `PhotogrammetrySession` itself runs on iOS — think of this skill as "how to build the assets," and `realitykit-core` as "how to load and show them."

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** It's better to have the context than to miss a pattern or make a mistake.

| Reference | Load When |
|-----------|-----------|
| **[Getting Started](references/getting-started.md)** | Creating a `PhotogrammetrySession` from a folder of images (or an advanced `PhotogrammetrySample` sequence), connecting the async output message stream, dispatching `requestProgress`/`requestComplete`/`requestError`/`processingComplete`, and calling `session.process([...])` for one or more detail levels at once |
| **[Capture Best Practices](references/capture-best-practices.md)** | Shooting the source photographs — object selection, lighting and background, camera technique and image count, and using the CaptureSample sample app to capture HEIC images with embedded depth and gravity |
| **[Detail Levels & Output](references/detail-levels-and-output.md)** | Choosing preview/reduced/medium/full/raw, what materials each bakes, USDZ vs. USDA/OBJ output for post-production, and targeting both iOS and macOS from one capture |
| **[Interactive Workflow](references/interactive-workflow.md)** | Building a preview-and-refine UI — requesting a `.preview` model with a `.bounds` request, adjusting the capture volume and root transform, and committing to the final full-detail model |

Cross-skill: the USDZ this produces is an ordinary asset for **`realitykit-core`** to load (`Entity(contentsOf:)`) and for AR Quick Look on iOS — see `realitykit-spatial-ar`. To assemble the captured object into a larger authored scene (lighting, other objects, behaviors) before shipping, see `reality-composer-pro`. For the pro/raw path — editing the reconstruction in a DCC pipeline before final delivery, or working with the USDA it writes out — see **`usd-usdkit`**.

## Core Workflow

1. **Shoot the photos** following capture best practices — 20–200 close-up images, uniform coverage of every side, flipped to capture the bottom (see `capture-best-practices.md`).
2. **Create a `PhotogrammetrySession`** from the folder's `URL` (see `getting-started.md`). Try it first with `HelloPhotogrammetry` if you just want a model, not an app.
3. **Connect the output stream** with `for try await output in session.outputs` *before* processing — nothing arrives until the first `process` call, and the stream never ends on its own.
4. **Call `session.process(requests:)`** with every detail level you actually need in one array — computation is shared across requests made together, so it's faster than one call per level (see `detail-levels-and-output.md`).
5. **(Optional) Preview, adjust, refine** for interactive apps — request `.preview` + `.bounds`, let the user edit the capture volume and root transform, refine, repeat (see `interactive-workflow.md`).
6. **Ship the result** — USDZ into `realitykit-core` / AR Quick Look, or USDA/OBJ into a `usd-usdkit` pipeline for further editing.

## Setup and Process, End to End

```swift
import RealityKit

let session = try PhotogrammetrySession(input: imagesFolderURL)   // confirm exact initializer

Task {
    for try await output in session.outputs {
        if case .processingComplete = output { return }   // full dispatch pattern: see getting-started.md
    }
}

try session.process(requests: [
    .modelFile(url: outputFolder.appendingPathComponent("model-reduced.usdz"), detail: .reduced),
    .modelFile(url: outputFolder.appendingPathComponent("model-medium.usdz"),  detail: .medium),
])
```

Requesting **reduced** and **medium** together like this produces both models faster than two separate `process` calls — the engine shares computation across requests made in the same call.

## Common Mistakes

1. **Expecting the output stream to end on its own.** `session.outputs` keeps producing messages until the session is deinitialized or hits a fatal error — it does not complete just because one batch of requests finished. Dispatch on `.processingComplete` yourself (return/break in a CLI tool; just stop acting on messages in a long-lived app) rather than waiting for the `for try await` loop to exit.

2. **Requesting detail levels sequentially.** Calling `process` once for `.reduced`, waiting, then again for `.medium` throws away shared computation. Put every detail level you need into **one** `process(requests:)` array; it produces all of them faster than requesting them one at a time.

3. **Picking a bad subject.** Textureless, transparent, or highly reflective regions starve the reconstruction of detail. If reflection is unavoidable, diffuse the lighting. If you intend to flip the object mid-capture, it must be rigid, or the two halves of the capture won't agree with each other.

4. **Too few images, too little overlap, or skipping the flip.** Sparse or non-overlapping coverage leaves holes; skipping the flip leaves you with no bottom. Aim for 20–200 close-up images (more for fine surface detail) with high overlap, moving slowly and uniformly around the object.

5. **Reaching for `.full` or `.raw` when shipping straight to mobile.** `.full` and `.raw` target pro/VFX pipelines — `.raw` in particular has no baked materials and expects your own post-production. For AR Quick Look and mobile, `.reduced` (many objects sharing one scene) or `.medium` (one hero object) are the ones designed to be used out of the box.

6. **Skipping the interactive preview and fixing problems in post.** The preview → adjust → refine loop exists specifically so pedestal removal, cropping, and scale/rotation fixes happen *before* the expensive final request, leaving nothing left to clean up afterward. Reach for it before reaching for a DCC.

7. **Forgetting this is a macOS-only API.** `PhotogrammetrySession` lives in the RealityKit module but does not run on iOS. In a shared multiplatform target, gate the actual capture-processing code behind `#if os(macOS)`; only the USDZ it produces travels on to iOS/visionOS.
