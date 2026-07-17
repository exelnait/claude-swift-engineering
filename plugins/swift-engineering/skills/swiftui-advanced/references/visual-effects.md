# Visual Effects: Shaders, Timelines & Alignment

> Several of these effect APIs (Metal shader effects, `TimelineView` schedules, alignment-guide overrides) are relatively recent additions and the exact signatures move between OS versions. Type names hedged with `// confirm exact API against current Apple documentation` should be checked against current Apple docs before shipping.

## Core Principle: the creative pipeline

Advanced graphics in SwiftUI are not one complex API — they're **simple pipes composed in series**. Each modifier is a stage that takes data in, transforms it, and passes it along; each stage's output feeds the next stage's input. "Advanced" is the *construction*, not the complexity.

```
cover art ──▶ .blur ──▶ .layerEffect(shader) ──▶ TimelineView(.animation) ──▶ animated background
transcript ──▶ current-line calc (playhead) ──▶ onChange + scrollTo ──▶ time-synced scroll
line + timestamp ──▶ overlay(alignment:) + alignmentGuide ──▶ floating attachment
```

The APIs are fixed; *what you feed in and how you connect them* is where the effect comes from. Swap audio for gyroscope, a twist shader for a ripple, a scroll view for a `Canvas` — same pipes, different result.

> Time-driven **interpolation** animation (springs, transitions, `phaseAnimator`/`keyframeAnimator`, `Transaction`) lives in the **`swiftui-animations`** skill. This file is about GPU shaders, effect *composition*, and *alignment* — the graphics side of the pipeline.

## Metal shaders from SwiftUI

A shader is a program that runs on the GPU **per pixel, in parallel** — each pixel executes independently with no awareness of its neighbors. After SwiftUI rasterizes a view to pixels, a shader decides the color. Metal shader functions are called from SwiftUI's shader-effect modifiers; required parameters differ by kind, and you can **append extra parameters** to forward data from SwiftUI (a vector, the view size, an image).

### The three shader effects — pick by what each pixel needs

```
Transform each pixel's color on its own (no neighbors)?  -> .colorEffect
Move where a pixel samples from (geometry only, no color)? -> .distortionEffect
Need adjacent pixels / the whole layer?                    -> .layerEffect   (most flexible)
```

| Effect | Shader gets | Shader returns | Use for |
|--------|-------------|----------------|---------|
| **`.colorEffect`** | pixel position + original color | a new color | per-pixel color transforms — desaturate, tint, threshold |
| **`.distortionEffect`** | pixel position | a *new position* to sample from (no color) | geometric effects — shear, warp, ripple |
| **`.layerEffect`** | pixel position + the whole layer | a color (may sample many input pixels) | blur, glow, domain warp — output depends on multiple inputs |

`.colorEffect` transforms one color to another (e.g. color image → black and white). `.distortionEffect` says "I want *this* position's color to come from *that* position" — SwiftUI samples the original image there. `.layerEffect` is the most flexible: it hands the shader the entire view layer, so a pixel can sample its neighbors or the whole region.

### Pattern: `layerEffect` + domain warping

The cover-art background uses `.layerEffect` for maximum flexibility. Start from an identity shader that just resamples the layer, then build up.

**SwiftUI side** — reference the Metal function by name and forward parameters:

```swift
Image("coverArt")
    .resizable()
    .layerEffect(
        ShaderLibrary.backgroundWarp(   // reference a stitchable Metal fn by name; confirm exact API against current Apple documentation
            .float2(size),              // forward the view size (a float2)
            .image(noiseImage)          // forward a precomputed NoiseTexture; arrives Metal-side as texture2d
        ),
        maxSampleOffset: .init(width: 40, height: 40)  // how far the shader may sample; confirm exact API against current Apple documentation
    )
```

Forward the *view size* by measuring it first — read it with `.onGeometryChange` (see `adaptive-layout.md`) and pass the `CGSize` in.

**Metal side** — a `layerEffect` function receives `position` and the layer, plus your extra args:

```metal
#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>              // confirm exact header/type names against current Apple documentation
using namespace metal;

[[ stitchable ]]                          // marks the fn callable from SwiftUI; confirm exact API against current Apple documentation
half4 backgroundWarp(float2 position, SwiftUI::Layer layer,   // half4 / SwiftUI::Layer: confirm against current docs
                     float2 size, texture2d<float> noise) {
    float2 uv = position / size;          // uv = where I am, independent of absolute size
    constexpr sampler s(address::repeat); // repeat mode so the noise tiles

    // Domain warping: sample noise once for an offset, then sample AGAIN
    // at a position shifted by that first offset -> organic, flowing blobs.
    float2 warp = noise.sample(s, uv).rg;         // r,g channels = two independent noise patterns
    warp = noise.sample(s, uv + warp).rg;         // second sample, offset by the first

    return layer.sample(position + warp * 40.0);  // sample the ORIGINAL view at the warped position
}
```

Key ideas from this shader, kept small on purpose:
- **`uv = position / size`** lets you sample textures relative to the view instead of by absolute pixel.
- A `NoiseTexture` is a precomputed image of smooth random values; its **red and green channels each hold a different noise pattern**, a natural fit for an (x, y) offset that varies per pixel.
- **Domain warping** = sampling the noise twice, the second time offset by the first result. One sample gives a uniform-looking shift; two gives organic flow. Scale the offset to taste.

## Animating shaders with time

Shaders are **stateless** — no memory of the previous frame; output depends *only* on the parameters. So you can't `withAnimation` a shader into motion. To animate, **feed in a value that changes over time**.

`TimelineView(.animation)` is exactly that pipe: the `.animation` schedule fires **every frame** with a timestamp. Pass the timestamp into the shader and the pattern flows.

```swift
TimelineView(.animation) { context in                 // fires ~every frame
    let t = context.date.timeIntervalSinceReferenceDate

    Image("coverArt")
        .resizable()
        .layerEffect(
            ShaderLibrary.backgroundWarp(              // confirm exact API against current Apple documentation
                .float2(size),
                .image(noiseImage),
                .float(t)                              // the changing value that drives motion
            ),
            maxSampleOffset: .init(width: 40, height: 40)
        )
}
```

Metal-side, add `t` into the noise lookup (e.g. `uv + t * speed`) so the sampled pattern moves each frame.

> Contrast with the rest of SwiftUI: normal animation is **transaction-based** — SwiftUI interpolates between two states over an `Animation` (see `swiftui-animations`). A shader has no states to interpolate; it re-runs from scratch each frame, so it needs a live value, which is what `TimelineView(.animation)` supplies.

## Composing effects

Because each modifier is a pipe, composing effects is just chaining — and **order matters**, because each stage transforms the previous stage's output:

```swift
Image("coverArt")
    .resizable()
    .blur(radius: 20)             // stage 1: soften so it doesn't compete with foreground
    .layerEffect(warpShader, maxSampleOffset: .init(width: 40, height: 40))  // stage 2: warp the softened result
```

Blur-then-warp warps an already-soft image; warp-then-blur softens the warp. Same two pipes, different look. Think of the whole visual as stages flowing into one another, not a single monolithic effect.

## Alignment guides for precise placement

Every view has an **alignment point on each axis** — the point the layout system uses to position it. When you place one view relative to another (an overlay, a stack, a container), the system **pins the two views' alignment points together** — picture a pin punched through both views at that point.

### Container alignment pins the points

```swift
Text(line.text)
    .overlay(alignment: .bottomLeading) {   // pin runs through each view's bottom-leading point
        Timestamp(line.time)
    }
```

Default overlay alignment is `.center` (pin through both centers). `.bottomLeading` moves the pin to each view's bottom-leading point, locking them there.

### Override a guide to float an attachment — no manual offsets

Goal: the timestamp's **top edge** should touch the container's **bottom edge** (float it just below). `.offset` can't do this without knowing both view sizes. Instead, override what the subview *reports* as its `.bottom` alignment:

```swift
Timestamp(line.time)
    // When the layout system asks for my BOTTOM, hand back my TOP instead.
    // Now "bottom-to-bottom" pinning lands my top edge on the container's bottom edge.
    .alignmentGuide(.bottom) { dimensions in dimensions[.top] }
```

`.alignmentGuide(_:computeValue:)` gives you `ViewDimensions`; subscripting it (`dimensions[.top]`) returns a point *in this view's coordinates*. Moving the `.bottom` guide to `[.top]` is a **purely semantic** override — the view floats without any hand-tuned offset, and it stays correct at any size.

### Custom alignments computed from `ViewDimensions`

Define your own alignment and compute its point from the view's actual size:

```swift
extension VerticalAlignment {
    private enum LineCenter: AlignmentID {                 // AlignmentID: confirm exact API against current Apple documentation
        static func defaultValue(in d: ViewDimensions) -> CGFloat { d[VerticalAlignment.center] }
    }
    static let lineCenter = VerticalAlignment(LineCenter.self)
}

// Usage: compute a point from the real size in the guide closure
.alignmentGuide(.lineCenter) { d in d.height * 0.5 }
```

See Apple's "SwiftUI Alignment" documentation for the full picture.

## Applied example: time-synced scrolling

Use the playback timestamp to pick the current line, then let `onChange` keep it centered — the same "time pipe" that drives the shader also drives the scroll.

```swift
// Current line = last line whose start time is at or before the playhead.
var currentID: Line.ID? { transcript.last { $0.start <= playhead }?.id }

ScrollViewReader { proxy in
    ScrollView {
        LazyVStack {                                   // each line is its own view
            ForEach(transcript) { line in
                TranscriptLine(line, isCurrent: line.id == currentID)  // current bold/opaque, rest fade
            }
        }
    }
    .onChange(of: currentID) { _, id in                // watch the current line change
        guard let id else { return }
        withAnimation { proxy.scrollTo(id, anchor: .center) }  // scrollTo(_:anchor:): confirm exact API against current Apple documentation
    }
}
```

The floating timestamp from the alignment section lives in each line's `.overlay`, but is only made visible on the current line — always present (so layout is stable), just waiting to be shown.

## Pitfalls

**Trying to animate a shader with state / `withAnimation`:**
```swift
// WRONG — shaders are stateless; there's no old→new to interpolate
withAnimation { shaderPhase += 1 }

// CORRECT — feed a changing value every frame
TimelineView(.animation) { ctx in view.layerEffect(shader(.float(ctx.date.timeIntervalSinceReferenceDate)), ...) }
```

**Wrong shader kind for the job:**
```
Blurring with .colorEffect            -> impossible; it can't see neighbors. Use .layerEffect.
Pure geometric warp with .layerEffect -> works but heavier than needed. Use .distortionEffect (position -> position).
```

**Manual offsets instead of alignment guides:**
```swift
// WRONG — needs both view sizes, breaks when either changes
.offset(y: containerHeight / 2 + labelHeight / 2)

// CORRECT — semantic, size-independent
.overlay(alignment: .bottomLeading) { label.alignmentGuide(.bottom) { $0[.top] } }
```

**Heavy work inside `TimelineView(.animation)`:** the closure re-evaluates every frame. Keep it to cheap view construction and the shader call — move formatters/calculations out (see `performance.md`). Keep the shader itself cheap; it runs per pixel per frame on the GPU.

**Under-declaring `maxSampleOffset`:** `.layerEffect`/`.distortionEffect` sample beyond the pixel; if the shader reaches farther than the declared offset the result can clip. Size it to your largest warp. (Confirm exact parameter behavior against current Apple documentation.)
