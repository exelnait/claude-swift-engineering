# Interactive Workflow: Preview, Adjust, Refine

> Confirm the exact `geometry` parameter type and its field names against current Apple documentation — the source material describes this capability without giving its literal Swift signature.

## Why bother with an interactive pass

The two-phase Setup → Process workflow (see `getting-started.md`) is enough for a batch job: point at a folder, request a model, get a file back. But a GUI app can do better — let the person who took the photos **see and correct** the reconstruction before committing to an expensive final request. Done well, this can eliminate the need for post-production model edits and optimize memory use: you trim what you don't want and fix scale/orientation *before* paying for a Full or Raw reconstruction, not after.

## Where it sits in the pipeline

Setup (create the session, connect `session.outputs`) and the final model request are identical to the basic workflow. What's new is an editing loop in between:

```
Setup  →  request .preview + .bounds  →  [ user adjusts volume/transform ]  →  request refined .preview  →  (repeat)  →  request final .full model
```

## Requesting a preview and its bounds together

```swift
try session.process(requests: [
    .modelEntity(detail: .preview),   // a live RealityKit ModelEntity — or use .modelFile to write+load it yourself
    .bounds,
])
```

Make both requests in the same `process` call, so the model and its estimated capture volume arrive together. `.preview` is intentionally the fastest, lowest-quality level — it exists purely so the loop feels responsive, not to look good.

## Editing the capture volume and root transform

The `.bounds` request's `requestComplete` message carries a `BoundingBox` — the session's estimate of the object's capture volume. Show it in your own 3D UI and let the user:

- **Shrink the bounding box** to cut out geometry the scan doesn't need — the common case is a **turntable pedestal** used to hold the object upright during the shoot.
- **Scale, translate, and rotate** the model via its root transform.

## Feeding edits back in with `geometry`

`.modelFile` and `.modelEntity` both accept an optional `geometry` argument — unused in the basic workflow — which is exactly where the edited bounding box and root transform go on the *next* request:

```swift
let geometry = PhotogrammetrySession.Request.Geometry(   // confirm exact type/initializer
    boundingBox: editedBounds,
    transform: editedRootTransform)

try session.process(requests: [
    .modelEntity(detail: .preview, geometry: geometry),   // a refined preview, clipped to the new volume
])
```

This is the same shape as trimming a scanned rock so it reads as embedded in the ground: crop the bounding box, hit refine, and see the clipped result *at preview quality* before spending real computation on it. Loop adjust → refine as many times as needed.

## Committing to the final model

Once the refined preview looks right, make the real request — same `geometry`, now at a production detail level:

```swift
try session.process(requests: [
    .modelFile(url: finalUSDZURL, detail: .full, geometry: geometry),
])
```

Because the crop and transform were already validated interactively, the result is ready to use immediately — no follow-up trip through a DCC just to trim a pedestal or fix scale.

## Common mistakes

1. **Requesting `.preview` without a paired `.bounds` request.** You get geometry to look at but nothing to edit against — request them together.
2. **Treating a `.preview` model as a deliverable.** It's deliberately low quality so the loop stays fast; ship `.reduced`/`.medium`/`.full`, never `.preview`.
3. **Losing the edited `geometry` between the refine step and the final request.** The crop/transform only takes effect if you pass the same (or further-adjusted) `geometry` into the production-detail request — it isn't remembered by the session on its own.
4. **Doing in post-production what this loop already solves.** Pedestal removal and scale/orientation fixes belong in the interactive pass, before the final request — not as a DCC cleanup step afterward.
