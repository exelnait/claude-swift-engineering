# Tap-to-Segment (Interactive Segmentation)

> These capabilities are part of the 2026 releases and newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

Vision already has fixed segmentation capabilities — for example **person segmentation**, which isolates all the people in an image. The new **tap-to-segment** API removes the "person only" limit: the user can isolate **any** object — a coffee cup, a plate, a croissant, an item of clothing, even the floor — just by selecting it.

The request is **iterative**: you seed it with a selection, get a mask back, and can then refine that mask by adding or subtracting more input without starting over.

## The request / handler flow

Segmentation uses the standard Vision shape (see `image-analysis.md` for the general pattern):

1. Start with an image and create an `ImageRequestHandler` to hold it.
2. Create a `GenerateIterativeSegmentationRequest`, seeded with a **point inside the object** you want to segment.
3. Use the handler to **perform** the request.
4. You get back a **mask** — a `PixelBuffer` marking which pixels belong to the segmented object.

```swift
import Vision

let handler = ImageRequestHandler(image)                 // confirm exact initializer

// Seed with a normalized point inside the target object (origin lower-left).
var request = GenerateIterativeSegmentationRequest()     // confirm exact API against current Apple documentation
request.addPoint(x: 0.42, y: 0.55, isIncluded: true)     // shape only — confirm exact selection API

let mask = try await handler.perform(request)            // mask is a PixelBuffer of the object
```

The exact way you attach the seed (initializer argument vs. a configuration/selection property) and the exact result type need confirming against current docs — but the flow (**handler → perform → mask PixelBuffer**) is the stable part.

## Selection modes

There are several ways to tell the request what to segment. Offer whichever fits the interaction:

| Mode | Good for | Notes |
|------|----------|-------|
| **Point** | Simple, single objects — one tap on the object | Fast; may be too coarse for complex or multi-part subjects |
| **Bounding box** | Grouping several objects at once (e.g. a cup *and* its plate) | Draw a box around everything to include |
| **Lasso** | Tracing a single irregular object (e.g. a croissant) | Freehand outline; mind the stroke width (below) |
| **Scribble** | Segmenting several objects in one gesture | Scribble across multiple objects to grab them all at once |

A single point works well for simple objects; switch to a box, lasso, or scribble when one point isn't enough to capture a complex or multi-part subject.

## Refining a mask (add / subtract)

Once you have a mask, refine it **iteratively** by feeding more input into the request and performing it again — no need to restart:

- **Add** a region: include a new point on something the mask missed (e.g. tap the plate to add it to the already-segmented cup).
- **Subtract** a region: mark a point to **exclude** (e.g. tap the cup to remove it, leaving just the coffee inside).

```swift
// Add the plate to the existing selection, then re-run on the same handler.
request.addPoint(x: 0.61, y: 0.48, isIncluded: true)     // shape only — confirm exact API
let expandedMask = try await handler.perform(request)

// Subtract: exclude a region from the mask.
request.addPoint(x: 0.50, y: 0.52, isIncluded: false)    // exclude
let refinedMask = try await handler.perform(request)
```

Each refinement is another point (include or exclude) carried on the request, followed by another `perform`. Keep the same request/handler so the model refines the existing mask rather than segmenting from scratch.

## The mask output

The result is a **`PixelBuffer`** — a per-pixel mask indicating which pixels belong to the segmented object. Use it to composite the object out (alpha matte), tint a highlight, or crop to the object's bounds. It is not a set of vector paths.

## Coordinate system

Vision uses a **normalized** coordinate system with the **origin in the lower-left** corner:

- Normalize seed points to the image **width and height**, with each coordinate value between **0 and 1**.
- Because the origin is lower-left, you must **flip the Y axis** when converting from UIKit/SwiftUI touch coordinates (which are top-left). A tap at pixel `(px, py)` in an image of size `(w, h)` becomes `(px / w, 1 - py / h)`.

```swift
// UIKit touch (top-left, pixels) → Vision point (lower-left, normalized 0...1)
func visionPoint(from touch: CGPoint, imageSize: CGSize) -> CGPoint {
    CGPoint(x: touch.x / imageSize.width,
            y: 1 - touch.y / imageSize.height)
}
```

## Lasso / scribble stroke width

When the user draws a **lasso**, the stroke must be wide enough — **thin strokes may not produce the best result**. Make the line width **at least 1% of the total image width**. Scale it to the image dimensions, not to on-screen points, so it stays correct across zoom levels and image sizes.

```swift
let minLassoWidth = imageSize.width * 0.01   // ≥ 1% of image width
```

## Downloading the on-device model

The first time you perform a segmentation request on a device, the on-device model must be **downloaded**:

- Kick off the download with the **`downloadAssets`** API.
- If you're unsure whether the model is present, check **`assetStatus`** to see whether it's ready to use.

Gate the segmentation UI on this: begin the download early (e.g. when the editor opens), show progress, and only allow a tap-to-segment once `assetStatus` reports the model is ready. Performing before the model exists will fail.

```swift
// Ensure the model is available before the first segmentation.
if assetStatus != .ready {                 // confirm exact status API
    try await downloadAssets()             // confirm exact download API
}
let mask = try await handler.perform(request)
```

## Best practices

- **Download early, segment later.** Trigger `downloadAssets` before the user's first tap so the interaction feels instant.
- **Normalize + flip Y** on every point you pass in; a mask on the wrong object is almost always a coordinate bug.
- **Match the mode to the gesture** — point for a tap, box for a drag-rect, lasso for a freehand loop, scribble for a swipe across several objects.
- **Refine, don't restart.** Additional include/exclude points on the same request are cheaper and more predictable than re-seeding.
- **Sample app:** Apple ships a tap-to-segment sample on the developer website.
