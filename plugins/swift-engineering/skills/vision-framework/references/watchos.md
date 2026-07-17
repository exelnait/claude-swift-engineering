# Vision on watchOS

> These capabilities are part of the 2026 releases and newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

Vision is now available on **watchOS** — image understanding is no longer limited to iPhone, iPad, and Mac. Use it to enhance watch apps where the small screen makes raw photos hard to read.

## Example: crop-to-subject on the small screen

A watch app that shows a photo of a local animal on a hike has a problem: the watch screen is so small that the subject is hard to see. Vision's **saliency analysis** solves it — identify the subject of interest, then crop the image to feature it prominently, giving the user a zoomed-in view.

The code is identical to the saliency crop in `image-analysis.md`; the same request runs on watchOS:

```swift
import Vision

let handler = ImageRequestHandler(image)
let request = GenerateObjectnessBasedSaliencyImageRequest()
let observation = try await handler.perform(request)          // saliency observation

let salientObjects = observation.salientObjects               // confirm exact property name
guard let mostProminent = salientObjects
    .max(by: { $0.confidence < $1.confidence }) else { return }   // confirm exact prominence API

let cropRect = mostProminent.boundingBox                      // normalized 0...1, lower-left origin
// Convert to pixels (flip Y) and display only the salient portion — a zoomed-in view.
```

## Notes

- The request/handler flow, normalized lower-left coordinates, and Y-flip-before-crop are the same as on other platforms — see `image-analysis.md`.
- Saliency crop is a natural fit for the watch, but any Vision request works here; favor the fast, fixed CV APIs given the watch's constraints.
- **Sample app:** Apple ships the watchOS sample shown in the talk on the developer website.
