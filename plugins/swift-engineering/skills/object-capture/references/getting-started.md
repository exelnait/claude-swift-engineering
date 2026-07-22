# Getting Started: Session, Output Stream, and Requests

> Object Capture's core API (`PhotogrammetrySession` and friends) dates to its 2021 introduction. The shapes below are reconstructed from the API's described behavior, not quoted verbatim — confirm exact initializer signatures, parameter labels, and case shapes against current Apple documentation.

## PhotogrammetrySession lives in RealityKit

`PhotogrammetrySession` is the primary, top-level type in Object Capture — think of it as a **container for a fixed set of input images** that photogrammetry algorithms run against to produce a 3D model. It's part of the `RealityKit` module, but it only runs on **macOS**: recent Intel Macs are supported, and Apple silicon is fastest because the Neural Engine accelerates the underlying computer-vision models.

```swift
import RealityKit

let session = try PhotogrammetrySession(input: imagesFolderURL)   // confirm exact initializer/label
```

The initializer throws if the folder doesn't exist or can't be read. It also accepts an optional advanced `Configuration` for tuning the reconstruction — the defaults are fine to start with. A session is bound to the image set it was created with; to reconstruct a different set of photos, create a new session rather than mutating this one.

## Two ways to provide images

- **A folder `URL`** is the common case — point at a directory of photos (HEIC, JPEG, etc.) and the session ingests them one by one, reporting any it couldn't load. If the images are HEICs with embedded depth data (as produced by an iPhone/iPad with a dual/LiDAR camera), that depth is **used automatically** to recover the object's true physical scale.
- **A sequence of `PhotogrammetrySample`s** is the advanced path, for pipelines with their own capture rig or custom masking. Each sample is one image plus optional extras you supply yourself — a depth map, a gravity vector, a segmentation mask — instead of relying on what's embedded in a HEIC. `// confirm exact initializer for the sample-sequence input`

## Connecting the output message stream

A session reports everything — progress, results, errors — on `session.outputs`, an `AsyncSequence`. Connect it with a `for try await` loop **before** you process anything: nothing arrives until the first `process` call, and the sequence keeps running for the life of the session (it only ends when the session deinitializes or hits a fatal error) — plan to `return`/`break` yourself once you see the message that means you're done.

```swift
Task {
    for try await output in session.outputs {
        switch output {
        case .requestProgress(let request, let fractionComplete):
            print("\(request): \(Int(fractionComplete * 100))%")   // drive a progress bar per request

        case .requestComplete(let request, let result):
            if case .modelFile(let url) = result {                  // confirm exact Result case shape
                print("wrote model for \(request) to \(url)")
            }

        case .requestError(let request, let error):
            print("\(request) failed: \(error)")

        case .processingComplete:
            return   // every queued request has finished — safe to exit a CLI tool here

        default:
            break    // other status messages exist too (e.g. a warning that one image in the
                     // folder couldn't be loaded) — confirm the full case list against current docs
        }
    }
}
```

Each case handles one message type; most of what's here is dispatching, not custom logic — that's normal for this loop.

## Making a request

Once the stream is connected, call `session.process(requests:)` with an array of `Request`s. `process` can throw immediately for a request that's invalid on its face (e.g. an unwritable output path); everything else — progress, success, failure — comes back asynchronously on `outputs`.

```swift
try session.process(requests: [
    .modelFile(url: reducedURL, detail: .reduced),
    .modelFile(url: mediumURL,  detail: .medium),
])
```

Request **every** detail level you need from this capture in the same array. The engine shares computation across requests made together, so two (or five) detail levels requested at once finish faster than the same requests made one call at a time. See `detail-levels-and-output.md` for what each level produces, and `interactive-workflow.md` for the `.modelEntity`/`.bounds` requests used in a live preview UI.

## Common mistakes

1. **Processing before connecting the output stream.** Attach the `for try await` loop first; a `process` call made without a listener still runs, but you'll miss whatever arrived before you started reading.
2. **Assuming the loop exits on its own.** It won't — `session.outputs` runs for the session's lifetime. Return on `.processingComplete` (or whatever condition means "done") rather than waiting for the sequence itself to finish.
3. **One `process` call per detail level.** Batch every level you want into a single `requests:` array to get the shared-computation speedup.
4. **Silently swallowing `requestError`.** A failed request reports through the stream, not by throwing out of `process` — a dispatcher that only handles `requestComplete` will drop failures on the floor.
