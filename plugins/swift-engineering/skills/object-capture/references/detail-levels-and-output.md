# Detail Levels & Output: Choosing What Object Capture Produces

> Confirm exact enum case names and the file-vs-directory output mechanism against current Apple documentation.

Every model-producing request (`.modelFile`, `.modelEntity`) takes a **detail level**, and the level you choose determines both visual quality and what the request is even useful for. Requesting the wrong one is the easiest way to ship an asset too heavy for its use case, or a "finished" asset that's actually meant for further processing.

## The five detail levels

| Level | Materials baked | Meant for |
|---|---|---|
| **preview** | none / minimal | Interactive workflows only — fastest possible, deliberately low quality, never a deliverable (see `interactive-workflow.md`) |
| **reduced** | diffuse, normal, ambient occlusion | Web/mobile/AR Quick Look when **many** models share one scene — fewer triangles, smaller memory/file footprint |
| **medium** | diffuse, normal, ambient occlusion | Web/mobile/AR Quick Look when displaying **one** scan and you want to maximize its quality against file size |
| **full** | diffuse, normal, ambient occlusion, roughness, displacement | Pro / high-end interactive use (games, offline rendering) — highest baked detail, ready to use out of the box |
| **raw** | none baked — max poly count + max diffuse texture only | Custom pipelines that do their own material baking / post-production (see `usd-usdkit`) |

Reduced, Medium, and Full are **all ready to use out of the box** — no post-production required. Raw is deliberately unfinished: maximum geometric and diffuse-texture detail, handed to you to bake and process yourself.

**Reduced vs. Medium** is the choice worth remembering: same material channels, but Reduced trades quality for a smaller footprint when several scans appear together (a shelf of products, a room full of objects), while Medium spends more of the budget on a single hero scan. Selecting **USDZ output at the Medium detail level** is, quite literally, the shipping path — it's what you view directly in **AR Quick Look** on iPhone or iPad.

## Requesting for both iOS and macOS

If the same capture needs to serve both a mobile AR Quick Look experience and a heavier macOS/pro use, request **multiple detail levels from the same capture** rather than re-running photogrammetry per target:

```swift
try session.process(requests: [
    .modelFile(url: mobileURL, detail: .medium),
    .modelFile(url: proURL,    detail: .full),
])
```

Requesting them together (see `getting-started.md`) also means the engine shares computation across the two, rather than reconstructing the object twice.

## USDZ vs. USDA/OBJ output

A `.modelFile` request normally points at a **file URL with a `.usdz` extension** — a single-file, self-contained archive that's exactly what AR Quick Look expects and what `realitykit-core` loads directly. For post-production pipelines that need to get inside the asset — retexturing in a DCC, combining with other USD layers — point the same request at an **output directory URL instead of a file URL**; the session writes **USDA** (human-readable USD) and **OBJ**, plus every referenced texture and material file, into that folder. `// confirm exact API: whether directory-vs-file output is inferred from the URL or a separate parameter`

```swift
// AR Quick Look / RealityKit — single-file USDZ
try session.process(requests: [.modelFile(url: heroUSDZ, detail: .medium)])

// Post-production — a directory of USDA + OBJ + referenced textures/materials
try session.process(requests: [.modelFile(url: outputDirectory, detail: .full)])
```

Feed that directory into a DCC-based finishing pass (touch-up in ZBrush, relighting/rendering in Houdini, assembly in Maya) and bring the result back into USD — see `usd-usdkit` for working with USD/USDA at that stage. If even a Medium export is heavier than a target actually needs, `3d-asset-optimization` covers trimming an already-exported asset further.

## The other request types, briefly

`.modelEntity` produces the same detail levels as `.modelFile` but hands back a live RealityKit `ModelEntity` instead of writing to disk — the shape used for in-app preview. `.bounds` returns an estimated capture-volume `BoundingBox` instead of a model at all. Both are central to the interactive workflow — see `interactive-workflow.md`.

## Common mistakes

1. **Shipping `.raw` (or even `.full`) straight to a mobile app.** Raw has no baked materials at all; Full is sized for pro/interactive use. Mobile/web/AR Quick Look wants `.reduced` or `.medium`.
2. **Using `.reduced` for a single hero object.** You're leaving quality on the table for a file-size budget you don't need when only one model is in the scene — use `.medium` instead.
3. **Re-running the capture per target platform.** Request every detail level a project needs (mobile *and* pro) in one `process` call against the same image set.
4. **Expecting a directory-output request to hand you a `.usdz`.** Pointing at an output directory gets you USDA/OBJ/textures for post-production, not an AR-ready archive — request a `.usdz` file URL separately if you need both.
