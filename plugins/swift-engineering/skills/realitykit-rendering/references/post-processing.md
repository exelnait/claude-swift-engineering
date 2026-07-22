# Post-Processing Effects

> Some APIs here ship in 2025–2026 releases. Confirm exact names against current Apple documentation.

SceneKit let you flip on a camera bloom effect by setting a couple of properties. RealityKit **deliberately** ships no such shortcut — a simple one-property bloom is intentionally not available, in favor of an API where you write (or assemble) the effect yourself. That buys tight control over both performance and look, at the cost of some setup.

## customPostProcessing on RealityView

Post-processing hooks into a `RealityView` through the **`customPostProcessing`** API, supported on **iOS, iPadOS, macOS, and tvOS**.

```swift
RealityView { content in
    // ... build your scene ...
}
.customPostProcessing { effects in     // confirm exact API shape
    effects.append(BloomPostProcess())
}
```

## Defining an effect: PostProcessEffect

An effect is a type you write that conforms to **`PostProcessEffect`**, implementing a **`postProcess`** method. RealityKit calls it with the rendered frame each pass, handing you the source texture (and a place to write the result).

```swift
import RealityKit
import MetalPerformanceShaders

struct BloomPostProcess: PostProcessEffect {                    // confirm exact protocol requirements
    func postProcess(context: PostProcessEffectContext) {      // confirm exact method signature
        let device = context.device                             // confirm exact context API
        let sourceTexture = context.sourceColorTexture

        // 1. Extract the brightest pixels into a temporary texture — this is where bloom "comes from".
        let highlights = extractHighlights(from: sourceTexture, device: device)

        // 2. Feather the highlights with a Gaussian blur (Metal Performance Shaders).
        let blur = MPSImageGaussianBlur(device: device, sigma: 8)
        blur.encode(commandBuffer: context.commandBuffer, sourceTexture: highlights, destinationTexture: highlights)

        // 3. Composite the blurred highlights back on top of the original frame.
        composite(blurred: highlights, onto: sourceTexture, in: context)
    }
}
```

The three-step shape — **extract → blur → composite** — is bloom specifically; other effects (color grading, a vignette, a custom stylized look) are a single pass or a different pipeline, but they plug into `postProcess` the same way.

You're not limited to Metal Performance Shaders — **CIFilters** or **your own Metal shaders** work too; MPS is just the fastest path to a good first result, since Apple ships optimized kernels (Gaussian blur among them) you don't have to write from scratch. Effects compose: append more than one to `customPostProcessing` to build a multi-pass pipeline (bloom, then a color grade, for example).

## Common mistakes

1. **Looking for a one-property bloom toggle.** It doesn't exist by design; implement `PostProcessEffect` and add it via `customPostProcessing`.
2. **Doing the whole effect in a single blur pass.** Bloom specifically needs the highlight-extraction step first — blurring the entire frame indiscriminately blurs everything, not just the bright spots.
3. **Hand-writing every kernel.** Reach for Metal Performance Shaders (e.g., Gaussian blur) or CIFilters before hand-rolling Metal; they're optimized and already battle-tested.
4. **Assuming post-processing is available everywhere.** `customPostProcessing` is documented for iOS/iPadOS/macOS/tvOS; confirm current visionOS support before depending on it there.
5. **Forgetting effects run every frame.** An expensive multi-pass effect (a large blur radius, several composited passes) is a recurring per-frame cost — profile it like any other render pass, not as a one-time setup cost.
