# Image Analysis with Vision

> These capabilities are part of the 2026 releases and newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

Vision offers **over 30** fine-tuned image-analysis capabilities. They all share one shape — the request/handler pattern — so once you know it, every capability is the same three steps with a different request type.

## The request / handler pattern (general)

In Vision, images are processed using **requests**. You never call a bare function; you:

1. **Hold the image** in an `ImageRequestHandler`.
2. **Create a request** for the task (a saliency request, a feature-print request, a detector, a classifier…).
3. **Perform** the request on the handler to get an **observation/result**.

```swift
import Vision

let handler = ImageRequestHandler(image)                 // confirm exact initializer
let request = /* some Generate...Request or Detect...Request */
let observation = try await handler.perform(request)
// Read results off `observation` — coordinates are normalized, origin lower-left.
```

Because it's the same shape everywhere, the two capabilities below (feature prints, saliency) are representative; swap the request type for detection, classification, face/pose analysis, tracking, etc.

## Feature prints & image similarity

A **feature print** is a **compact numeric representation** of an image — a fingerprint you can compare against other images' fingerprints to measure how similar they look, without any labels or training.

Generate one with **`GenerateImageFeaturePrintRequest`**, then compare prints by **distance**:

- **Smaller distance = more similar.** (This is the classic pitfall — sort *ascending*.)
- **Precompute** a feature print for every image in your catalog once and store it; comparing prints is cheap, regenerating them is not.
- To find matches for a query image, compute its print, measure the distance to each stored print, **sort by similarity** (ascending distance), and keep those under a **distance threshold**.

```swift
// Note: this specific capability wasn't detailed in "Bring image understanding to your app";
// confirm the exact type/method names against current Apple documentation.

func featurePrint(for image: ImageSource) async throws -> ImageFeaturePrint {   // confirm exact types
    let handler = ImageRequestHandler(image)
    let request = GenerateImageFeaturePrintRequest()          // confirm exact API against current Apple documentation
    return try await handler.perform(request)                 // a feature-print observation
}

// Precompute once for the catalog; store alongside each item.
let catalog: [(id: String, print: ImageFeaturePrint)] = /* precomputed */

// Rank catalog items by similarity to a query image.
let query = try await featurePrint(for: queryImage)
let ranked = try catalog
    .map { (id: $0.id, distance: try query.distance(to: $0.print)) }   // confirm exact distance API
    .sorted { $0.distance < $1.distance }                              // smaller = more similar
    .filter { $0.distance < similarityThreshold }                     // tune the threshold empirically
```

Good for de-duplication, "find similar photos", clustering, and reverse-image lookup over a local catalog — all on-device.

## Saliency-based cropping

**Saliency** finds the subjects of interest in an image so you can **crop to what matters** — especially valuable on small screens where the full frame is hard to read.

Use **`GenerateObjectnessBasedSaliencyImageRequest`**. Performing it yields a **saliency observation**, from which you read the **bounding boxes of the salient objects**. Take the **most prominent** one and crop to it.

```swift
let handler = ImageRequestHandler(image)
let request = GenerateObjectnessBasedSaliencyImageRequest()
let observation = try await handler.perform(request)          // a saliency observation

// Bounding boxes of salient objects (normalized, origin lower-left).
let salientObjects = observation.salientObjects               // confirm exact property name
guard let mostProminent = salientObjects
    .max(by: { $0.confidence < $1.confidence }) else { return }   // confirm exact prominence API

let cropRect = mostProminent.boundingBox                      // normalized 0...1, lower-left origin
// Convert to pixels (flip Y) and crop the image to feature the subject.
```

Because the box is **normalized with a lower-left origin**, convert and flip Y before cropping a top-left pixel image. This is the technique used to zoom a photo to its subject on watchOS — see `watchos.md`.

> Objectness-based saliency highlights *likely objects*. Vision also has attention-based saliency (what draws the eye); pick objectness when you want to crop to a discrete subject. Confirm the exact request name for the attention variant against current docs.

## The broader Vision catalog (30+ capabilities)

Segmentation and saliency are two of many. Vision also does, among others:

- **Facial analysis** — face detection and facial-landmark analysis.
- **Pose estimation** — human (and other) body/hand pose.
- **Detection & image classification** — locate objects/rectangles/text and classify image content.
- **Trajectory analysis** — track the path of a moving object across frames.
- **Object tracking** — follow a chosen object through a video sequence.
- Plus text recognition (OCR), barcode/QR detection, horizon detection, and more.

All of them use the same request → `ImageRequestHandler.perform` → observation flow shown above, and all are **fast enough to run on video frames in real time**, which is what makes Vision the right tool when you need precise, repeatable results at speed.

For the complete, current list and Swift API details, see Apple's **"Discover Swift enhancements in the Vision framework"** session.

## Vision vs. Foundation Models

Use a **Vision request** when the task is specific, precise, and possibly real-time (segmentation, saliency, detection, OCR, tracking). Use **Foundation Models** when the task is open-ended and descriptive (captioning, suggestions, generating text from an image). To get both at once, expose a Vision request as a **tool** the model can call — see `foundation-models-image-tools.md`.
