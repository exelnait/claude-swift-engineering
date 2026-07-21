# Immersive Media: Spatial Photos, Spatial Scenes, and Video

> `ImagePresentationComponent`, `Spatial3DImage`, and the spatial/immersive `VideoPlayerComponent` updates shipped in the 2025–2026 RealityKit updates and are newer than this guidance's training data. Confirm exact type names, initializers, and property names against current Apple documentation.

Both components here are ordinary RealityKit components that load wherever RealityKit runs, but their spatial and immersive viewing modes are what they're for — and those need visionOS's stereo displays and immersive space. Treat this reference as **visionOS-only** in practice.

## ImagePresentationComponent: three kinds of image

`ImagePresentationComponent` presents images on an entity, and it understands three distinct kinds of source image:

1. **Traditional 2D images/photos.**
2. **Spatial photos** — stereoscopic photos captured on iPhone or Vision Pro (two eyes' worth of image data).
3. **Spatial scenes** — a new kind of 3D image *generated* from an existing 2D photo: a "diorama" version of the photo with real depth, showing motion parallax as the viewer's head moves relative to it. This is the same technology behind spatial scenes in the Photos app on visionOS.

## Presenting a 2D image or a spatial photo

Both of these load directly from a file on disk. Initialization is **async** because loading the image takes a moment:

```swift
import RealityKit

let component = try await ImagePresentationComponent(contentsOf: imageURL)  // confirm exact initializer
entity.components.set(component)
```

That's the whole story for a plain 2D image. A **spatial photo** needs one more step: set a **`desiredViewingMode`** on the component *before* assigning it to the entity, and check that the image actually supports the mode you want first:

```swift
var component = try await ImagePresentationComponent(contentsOf: spatialPhotoURL)  // confirm exact initializer
if component.availableViewingModes.contains(.spatialStereoImmersive) {             // confirm exact API
    component.desiredViewingMode = .spatialStereoImmersive                          // confirm exact API
}
entity.components.set(component)
```

If you never set a `desiredViewingMode`, or the image doesn't support the one you asked for, the component falls back to a flat **2D/monoscopic** presentation — even for a genuine spatial photo. Creating the component from a spatial photo makes both spatial-stereo viewing modes (windowed and immersive) available to choose from.

## Spatial scenes: generating a diorama from a 2D photo

Spatial scenes need to be **generated** before they can be presented — they aren't just loaded like the other two kinds. You can generate one from either a plain 2D image or a spatial photo (if from a spatial photo, only one eye's channel is used as the source 2D image for the conversion).

```swift
let spatialImage = try await Spatial3DImage(contentsOf: imageURL)         // confirm exact initializer
var component = ImagePresentationComponent(spatial3DImage: spatialImage)  // confirm exact initializer

component.desiredViewingMode = .spatial3D    // set BEFORE generate() to show a progress animation, confirm exact API
entity.components.set(component)

try await spatialImage.generate()   // confirm exact API; takes a few seconds
// component.availableViewingModes now includes .spatial3D and .spatial3DImmersive
```

Two ways to sequence this, both valid:

- **Generate up front**, then present — fine if you don't mind the wait happening before anything is shown.
- **Set `desiredViewingMode` to `.spatial3D` before calling `generate()`.** This is the pattern the Photos app itself uses: the component shows a progress animation *during* generation, then automatically displays the finished spatial scene the moment it's ready — you don't have to poll or manually swap in the result.

You don't have to generate a spatial scene eagerly on load; it's common to wait until the person taps a button to convert (again, exactly what Photos does), rather than generating every photo up front.

## VideoPlayerComponent: beyond a flat rectangle

`VideoPlayerComponent` plays a wide range of immersive video formats, not just ordinary flat video:

- **Spatial video** (the stereoscopic video format iPhone captures), with full spatial styling, in both **portal** and **immersive** presentation modes.
- **Apple Projected Media Profile (APMP)** video — 180°, 360°, and wide-field-of-view formats. RealityKit automatically adjusts playback to respect the person's configured **comfort settings** for these.
- **Apple Immersive Video (AIV)** — Apple's highest-fidelity immersive video format.

All of these can be configured for a variety of viewing modes (portal vs. immersive, aspect ratio). One 2026 addition worth knowing: **wide-aspect-ratio portals** for Apple Immersive Video — this lets a very wide slice of the immersive video experience stay in view when switching from full immersion down to portal mode, instead of cropping to a narrow window. Set a custom aspect ratio through `VideoPlayerComponent` directly in RealityKit apps, or through `AVPlayerViewController` in AVKit-based apps. `// confirm exact property name for the aspect ratio override`

## Common mistakes

1. **Assuming a spatial photo will present in 3D by default.** It won't — without an explicit `desiredViewingMode`, `ImagePresentationComponent` presents even a spatial photo as flat 2D/monoscopic.
2. **Setting `desiredViewingMode` without checking `availableViewingModes` first.** An unsupported mode request silently falls back rather than erroring — always check support before assuming the immersive/spatial presentation will actually happen.
3. **Initializing `ImagePresentationComponent` directly from a URL when you actually want a spatial scene.** That path is for 2D images and spatial photos only. Spatial scenes go through `Spatial3DImage` first, then `generate()` — skipping this produces a component that's stuck with no spatial-scene viewing modes available.
4. **Calling `generate()` without first deciding whether you want the progress-animation experience.** If you want the "shows progress, then the result appears" behavior like Photos, set `desiredViewingMode` to `.spatial3D` *before* calling `generate()` — not after.
5. **Regenerating a spatial scene on every appearance instead of caching the result.** Generation takes a few seconds; treat it like any other expensive derived asset and avoid redoing it for content that hasn't changed.
6. **Hard-cropping Apple Immersive Video to a narrow portal.** Use the wide-aspect-ratio portal support instead of accepting a default crop when a person steps down from full immersion — it's there specifically so AIV content doesn't lose its scale in portal mode.
