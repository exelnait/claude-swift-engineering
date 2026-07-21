---
name: realitykit-spatial-ar
description: Use when integrating RealityKit with the real world — anchoring content with SpatialTrackingSession and AnchorEntity, reacting to AnchorStateEvents and reading ARKitAnchorComponent data, scene understanding (colliding the room mesh with physics), EnvironmentBlendingComponent occlusion, immersive and spatial audio with a custom reverb mesh, presenting spatial photos/scenes and immersive video (ImagePresentationComponent, VideoPlayerComponent), spatial accessories, and object tracking. visionOS-leaning, with iOS ARKit anchoring where noted.
---

# RealityKit Spatial AR: Anchoring, Scene Understanding, and Immersive Media

RealityKit content doesn't have to float in a void. This skill covers everything that ties a RealityKit scene to the physical world it's rendered into: finding and anchoring to a real surface or object, making content collide with and hide behind the room, giving audio a room to reverberate in, presenting spatial photos and immersive video, and reading 6-degrees-of-freedom input from real objects and paired accessories.

> Nearly everything in this skill shipped in the 2025–2026 releases and is newer than this guidance's training data. Confirm exact type names, initializers, and availability against current Apple documentation. Inline `// confirm exact API` markers flag the spots most worth checking.

## Overview

Two distinct capabilities do the "grounding," and it's worth keeping them separate in your head:

- **Anchoring** answers *where* — finding a real surface or object and locking virtual content to it. This is `SpatialTrackingSession` + `AnchorEntity` + the newer `AnchorStateEvents`/`ARKitAnchorComponent`, and it runs on **iOS/iPadOS as well as visionOS**.
- **Scene understanding and blending** answers *how convincingly* — colliding with, getting occluded by, and lighting up real walls, floors, and tables. This is **visionOS-only**, because it depends on the room mesh visionOS builds from its sensors.

On top of that foundation sit three more visionOS-centric areas this skill also covers: **immersive audio** (a custom reverb mesh that makes a sound acoustically belong to a room), **immersive media presentation** (photos, generated spatial scenes, and video that go beyond a flat rectangle), and **6DoF input beyond hands** (spatial accessories, and object tracking — which, like anchoring, now reaches iOS too).

This skill assumes you're already comfortable with the ECS basics and hosting a scene in a `RealityView` — see `realitykit-core`. It doesn't cover picking up/rotating entities with hands (`ManipulationComponent`, `GestureComponent`) or SwiftUI↔RealityKit data flow — see `realitykit-swiftui`. Colliding with the scene understanding mesh reuses the same `PhysicsBodyComponent`/`CollisionComponent` machinery as ordinary object physics — see `realitykit-physics-interaction`. And the same mesh that enables collision also feeds RealityKit's physical-space lighting (virtual lights spilling onto real walls) — see `realitykit-rendering`.

## iOS vs. visionOS

| Capability | iOS / iPadOS | visionOS |
|---|---|---|
| Anchoring (`SpatialTrackingSession`, `AnchorEntity`, `AnchorStateEvents`, `ARKitAnchorComponent`) | Yes | Yes |
| Scene understanding mesh (collision/physics) | No | Yes |
| `EnvironmentBlendingComponent` occlusion | No | Yes — immersive space only |
| Custom reverb mesh / immersive audio | No | Yes — immersive space only |
| Spatial photos/scenes, immersive video | No practical use* | Yes |
| Spatial accessories | No | Yes — Shared *and* Full Space |
| Object tracking | Yes (new 2026 ARKit API) | Yes |

*`ImagePresentationComponent`/`VideoPlayerComponent` are ordinary RealityKit components that load anywhere RealityKit runs, but their spatial/immersive viewing modes need visionOS's stereo displays.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** It's better to have the context than to miss a pattern or make a mistake.

| Reference | Load When |
|-----------|-----------|
| **[Anchoring & ARKit](references/anchoring-and-arkit.md)** | Locking content to a real surface — `SpatialTrackingSession` setup, classifying an `AnchorEntity` with bounds, subscribing to `AnchorStateEvents` (`DidAnchor`/`WillUnanchor`/failure), and reading `ARKitAnchorComponent` (casting to a concrete ARKit type like `PlaneAnchor` for raw extents/transforms). iOS and visionOS. |
| **[Scene Understanding](references/scene-understanding.md)** | Colliding game content with the real room — `SceneUnderstandingFlags` (collision/physics) on the tracking session configuration, and `EnvironmentBlendingComponent` for occlusion by static real-world objects. visionOS only. |
| **[Immersive Audio](references/immersive-audio.md)** | Making a sound source belong to a room — `ReverbMeshResource` (shoebox convenience or a custom mesh), audio materials (presets, `scalingAbsorption`, fully custom absorption/scattering), attaching a reverb component, and coordinated multi-source playback. Immersive space only. |
| **[Immersive Media](references/immersive-media.md)** | Presenting photos and video beyond a flat rectangle — `ImagePresentationComponent` (2D images, spatial photos, generated spatial scenes) and `VideoPlayerComponent` (spatial video, Apple Projected Media Profile, Apple Immersive Video, wide-aspect-ratio portals). visionOS only. |
| **[Spatial Accessories & Object Tracking](references/spatial-accessories-and-object-tracking.md)** | 6DoF input beyond hands — pairing spatial accessories (Logitech Muse, PSVR2 Sense, or a custom LED/IMU/Bluetooth build) via the Game Controller framework, and object tracking (a Create ML-trained reference object for pose/orientation, now on iOS too). |

Cross-skill: ECS fundamentals and hosting a scene → **`realitykit-core`**. Manipulation gestures, `ViewAttachmentComponent`/`GestureComponent`, observable entities, and `CoordinateSpace3D` conversion between RealityKit and SwiftUI → **`realitykit-swiftui`**. Ordinary (non-room-mesh) physics, collision shapes, and cloth → **`realitykit-physics-interaction`**. Materials, shadows, and physical-space lighting → **`realitykit-rendering`**. Authoring the scenes you anchor, visually → **`reality-composer-pro`**.

## Core Workflow

1. **Start a `SpatialTrackingSession`** configured for the tracking you need (e.g. plane tracking) and run it (see `anchoring-and-arkit.md`).
2. **Describe the surface you want** with a classified, bounded `AnchorEntity` — it starts unanchored and becomes anchored once a match is found.
3. **Subscribe to `AnchorStateEvents`** and, on `DidAnchor`, read the entity's `ARKitAnchorComponent` — cast `.anchor` to the concrete ARKit type to get raw extents/transforms for positioning content.
4. **(visionOS)** Opt into `SceneUnderstandingFlags` for room-mesh collision/physics, and add `EnvironmentBlendingComponent` where content should be occluded by real objects (see `scene-understanding.md`).
5. **(visionOS, immersive space)** Give the scene a custom reverb mesh so audio acoustically belongs to the room (see `immersive-audio.md`).
6. **(visionOS)** Present photos, generated spatial scenes, and video beyond a flat rectangle with `ImagePresentationComponent`/`VideoPlayerComponent` (see `immersive-media.md`).
7. **Add 6DoF input** — pair a spatial accessory, or track a real object trained in Create ML — for iOS and visionOS where noted (see `spatial-accessories-and-object-tracking.md`).

## Anchoring a Scene to a Real Surface, End to End

```swift
import RealityKit
import ARKit

// 1. Let AnchorEntities receive live ARKit tracking data.
let session = SpatialTrackingSession()
let configuration = SpatialTrackingSession.Configuration(tracking: [.plane])  // confirm exact Configuration API
_ = await session.run(configuration)

// 2. Describe the surface: a table-classified horizontal plane, at least 15cm x 15cm.
let chestAnchor = AnchorEntity(.plane(.horizontal, classification: .table, minimumBounds: [0.15, 0.15]))
content.add(chestAnchor)   // starts unanchored, at the scene origin

// 3. React to the anchor lifecycle.
let didAnchor = content.subscribe(to: AnchorStateEvents.DidAnchor.self) { event in   // confirm exact API
    guard let plane = event.entity.components[ARKitAnchorComponent.self]?.anchor as? PlaneAnchor else { return }

    // Raw ARKit data. Composing these centers content on the detected surface
    // rather than on the anchor's (arbitrary) own origin.
    let originFromAnchor = plane.originFromAnchorTransform
    let anchorFromExtent = plane.geometry.extent.anchorFromExtentTransform   // confirm exact property path
    chestAnchor.setTransformMatrix(originFromAnchor * anchorFromExtent, relativeTo: nil)
}
```

Keep the returned subscription tokens alive for as long as you care about the anchor's lifecycle — the same rule as any other RealityKit event subscription (see `realitykit-core`'s `realityview.md`). Everything under the anchor (chest, key, puzzle pieces) is positioned as children of `chestAnchor`, so it only needs to move once.

## Common Mistakes

1. **No running `SpatialTrackingSession` — the `AnchorEntity` just sits unanchored.** An `AnchorEntity` with a classification and bounds does nothing until a session configured for matching tracking (e.g. `.plane`) exists *and* is running. This is the most common "why won't my content anchor" bug in this area.

2. **Enabling `.collision` without `.physics` on `SceneUnderstandingFlags` (or vice versa).** Decide what you actually want from the room mesh — contact detection, physical response, or both — and set the flags accordingly before running the session. Adding the flags after the session is already running won't retroactively apply them; update the configuration and re-run.

3. **Expecting `EnvironmentBlendingComponent` to occlude against anything that moves.** Only **static** real-world geometry occludes; a person or pet walking in front of your content will not hide it. And entities using this component are always drawn **behind** other virtual content, by design — don't be surprised when it loses a sorting fight against something that should visually sit behind it.

4. **Testing a custom reverb mesh in the Shared Space.** `ReverbMeshResource` and custom audio materials only take effect in an **immersive space**. In the Shared Space, visionOS substitutes its own system room-sense reverb built from your real surroundings, so a carefully tuned custom reverb will appear to do nothing until the app actually goes immersive.

5. **Setting a `desiredViewingMode` without checking support first.** If the image doesn't support the mode you asked for (or you never set one), `ImagePresentationComponent` silently falls back to flat 2D/monoscopic presentation. Check the available modes before assuming a spatial photo or a generated spatial scene will show up in 3D.

6. **Forgetting to cast `ARKitAnchorComponent.anchor`, or casting to the wrong type.** The `anchor` property is a general ARKit anchor value — cast it to the concrete type matching what you configured tracking for (`PlaneAnchor` for plane tracking, an object anchor type for object tracking). Skipping the cast, or casting to the wrong type, silently yields `nil` instead of a clear error.

7. **Conflating object tracking with spatial accessories.** Object tracking recognizes an arbitrary real object via a Create ML-trained reference model and the camera — no electronics involved. A spatial accessory is a paired **electronic device** (LED constellation + IMU + Bluetooth) read through the Game Controller framework. They solve different problems — recognizing *any* trained object versus getting 6DoF plus buttons and haptics from a *specific paired device* — so reach for the one your use case actually needs.
