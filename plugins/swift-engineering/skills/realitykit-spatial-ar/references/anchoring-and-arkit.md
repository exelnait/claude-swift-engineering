# Anchoring & ARKit

> `AnchorStateEvents` and `ARKitAnchorComponent` shipped in the 2025 RealityKit update and are newer than this guidance's training data. Confirm exact type names, initializers, and event names against current Apple documentation.

This is the one capability in this skill that isn't visionOS-only: `SpatialTrackingSession`, `AnchorEntity`, `AnchorStateEvents`, and `ARKitAnchorComponent` all run on **iOS/iPadOS as well as visionOS**. On iOS this is how a `RealityView`-hosted scene gets ARKit-backed anchoring without you standing up a full `ARSession`/`ARView` yourself; on visionOS it's the standard way any RealityKit content becomes locked to the room. Everything else in this skill (scene understanding, environment blending, immersive audio, immersive media, spatial accessories) is visionOS-only.

## Why a SpatialTrackingSession

An `AnchorEntity` on its own describes *what surface you want*; it doesn't run ARKit. A **`SpatialTrackingSession`** is the thing that turns ARKit tracking on and routes results to your `AnchorEntity`s. Without a running session configured for the tracking you need, an `AnchorEntity` sits at the scene origin, unanchored, forever.

```swift
import RealityKit

let session = SpatialTrackingSession()
let configuration = SpatialTrackingSession.Configuration(tracking: [.plane])  // confirm exact Configuration shape
_ = await session.run(configuration)
```

Configure only the tracking you actually use — plane tracking here, since the example anchors content to a tabletop. Other tracking types (image, body, world anchors) follow the same shape: add them to the configuration, and give your `AnchorEntity`s matching criteria. `// confirm exact tracking option names`

## Describing the surface: AnchorEntity classification and bounds

Set up an `AnchorEntity` with a **classification** and a **minimum size**, and RealityKit finds the best real-world match for you:

```swift
let chestAnchor = AnchorEntity(
    .plane(.horizontal, classification: .table, minimumBounds: [0.15, 0.15])
)
content.add(chestAnchor)
```

This entity starts **unanchored**. It becomes anchored the moment ARKit finds a horizontal plane classified as a table that's at least 15cm × 15cm. Everything you want positioned on that surface should be a **child** of this anchor entity — position them once, relative to the anchor, and they move together when the anchor updates.

## Reacting to the anchor lifecycle: AnchorStateEvents

`AnchorStateEvents` is the 2025 addition that lets you subscribe to what's happening to an anchor over time, instead of polling:

- **`DidAnchor`** — the entity just became anchored to a real surface.
- **`WillUnanchor`** — the surface is about to be lost (tracking degraded, surface out of view) — pause or hide dependent content before it happens.
- A **failed-to-anchor** event — no matching surface was ever found. `// confirm exact event type name`

```swift
let didAnchor = content.subscribe(to: AnchorStateEvents.DidAnchor.self) { event in   // confirm exact API
    // event.entity is now anchored — safe to reveal/position dependent content.
}

let willUnanchor = content.subscribe(to: AnchorStateEvents.WillUnanchor.self) { event in  // confirm exact API
    // Surface about to be lost — pause interaction, don't just let content float unanchored.
}
```

Retain both subscription tokens for as long as you care about the anchor — dropping them tears down the subscription, same as any other RealityKit event (`CollisionEvents`, `ManipulationEvents`, and so on).

## Reading raw ARKit data: ARKitAnchorComponent

Once `DidAnchor` fires, the anchored entity carries a new **`ARKitAnchorComponent`**. Its `anchor` property holds the underlying ARKit anchor as a general value — cast it to the concrete type that matches what you configured tracking for:

```swift
guard let plane = event.entity.components[ARKitAnchorComponent.self]?.anchor as? PlaneAnchor else { return }

let originFromAnchor = plane.originFromAnchorTransform          // anchor space → world/origin space
let anchorFromExtent = plane.geometry.extent.anchorFromExtentTransform  // confirm exact property path
```

`PlaneAnchor` gives you the raw extents and transforms RealityKit's own convenience APIs are built on. The reason to reach for this over just trusting `AnchorEntity`'s position: the anchor's own origin isn't necessarily the visual center of the detected surface. Composing `originFromAnchorTransform * anchorFromExtentTransform` gives you a transform straight from the *extent's* local frame to world space, which is what you want to center content on the surface rather than on an arbitrary corner.

```swift
chestAnchor.setTransformMatrix(originFromAnchor * anchorFromExtent, relativeTo: nil)
```

For the general mental model of composing transforms and converting between local/world/other-entity spaces, see `realitykit-core`'s `transforms-and-coordinates.md`. If you need to convert an anchored entity's position into a SwiftUI view's coordinate space (or vice versa), that's the unified `CoordinateSpace3D` conversion covered in `realitykit-swiftui`.

## Common mistakes

1. **Creating an `AnchorEntity` without ever running a matching `SpatialTrackingSession`.** The entity compiles, adds to the scene, and never anchors — there's no error, just silence.
2. **Setting scene understanding or other configuration flags after the session is already running.** Update the `Configuration` and re-run the session; don't expect an in-flight session to pick up new flags on its own.
3. **Treating `AnchorEntity`'s position as authoritative when you need the true surface bounds.** The convenience position is enough for casual placement; for precise centering, drop down to `ARKitAnchorComponent`'s raw transforms.
4. **Forgetting the cast on `ARKitAnchorComponent.anchor`, or casting to a type that doesn't match your tracking configuration.** Plane tracking yields `PlaneAnchor`; other tracking types yield their own ARKit anchor types. A mismatched cast just returns `nil`.
5. **Dropping the `AnchorStateEvents` subscription tokens.** Same rule as every other RealityKit event subscription — if the token isn't retained, the subscription is torn down and your handler stops firing.
6. **Not handling `WillUnanchor`.** Content that was positioned relative to a now-lost anchor doesn't disappear on its own; decide what "the table went away" should look like in your app instead of leaving orphaned content floating in place.
