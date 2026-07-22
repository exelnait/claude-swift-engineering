# Cross-Platform Deployment

> Some APIs here ship in 2025–2026 releases. Confirm exact names against current Apple documentation.

RealityKit's headline strength: **write once, deploy across iOS, iPadOS, macOS, tvOS, and visionOS** with minimal code changes. The same `RealityView`, entities, components, and systems run everywhere. This plugin's focus is **iOS 26+**, with visionOS as a natural extension.

## What's shared

- The **ECS** (entities/components/systems) is identical on every platform.
- **`RealityView`** hosts the scene everywhere and adapts to the host's layout system.
- Scenes authored in **Reality Composer Pro** load the same way on all platforms.
- Most rendering — materials, lighting, shadows, particles, **post-processing** (iOS/iPadOS/macOS/tvOS) — is shared.

On **visionOS**, `RealityView` performs **stereoscopic rendering automatically** — the same scene that renders flat on iOS renders in true 3D per-eye with no code change.

## What differs per platform

| Concern | iOS / iPadOS | macOS | tvOS | visionOS |
|---|---|---|---|---|
| Primary input | Touch, gestures | Mouse/trackpad, keyboard | **Game controller**, remote | Eyes + hands, gaze/pinch |
| Camera | Interactive/orbit camera, or AR passthrough | Interactive camera | Interactive camera | Person moves physically |
| Real-world blending | ARKit anchoring (passthrough AR) | — | — | Full anchoring, scene understanding, environment blending |
| Immersion | On-screen window | Window | Big screen | Windowed / volumetric / immersive space, portals |

Features like `SpatialTrackingSession`, scene-understanding mesh, `EnvironmentBlendingComponent`, spatial accessories, and immersive audio are **visionOS-centric** (ARKit anchoring also applies on iOS). Keep those behind the platform boundary — see `realitykit-spatial-ar`.

## Structuring a multi-platform app

- Put **shared** scene setup, components, and systems in a common target/module. This is the bulk of the code.
- Gate **platform-specific** input, camera, and immersion behind `#if os(...)` or separate view layers.

```swift
#if os(visionOS)
// Immersive space, spatial tracking, hand input
#elseif os(tvOS)
// Game-controller input, focus engine
#else   // iOS, iPadOS, macOS
// Touch/pointer input, interactive camera or AR
#endif
```

- Reuse one `RealityView`; swap only the **input-handling** and **camera** layer per platform.
- For visionOS, you can wrap the *same* scene in a progressive-immersion or portal presentation to render it in 3D in front of the user — no changes to the scene itself.

## tvOS notes (new in 2025)

RealityKit runs on all generations of Apple TV 4K. Design for the **10-foot experience**: game-controller/remote input and the focus engine rather than touch. Otherwise the scene, assets, and systems are the same code you ship on iOS.

## Common mistakes

1. **Assuming visionOS-only.** RealityKit is genuinely cross-platform; don't gate an entire feature to visionOS when only the *input/immersion* differs.
2. **Hard-coding touch input.** Touch handling won't compile or won't work on tvOS/macOS. Abstract input behind a platform layer.
3. **Bringing AR/anchoring APIs to platforms that lack them.** `SpatialTrackingSession`/scene understanding are visionOS (and iOS ARKit) concepts. Guard them; don't reference them unconditionally in shared code.
4. **Forgetting the controller on tvOS.** tvOS has no touchscreen — plan for `GameController` input and focus-based navigation from the start.
5. **Sprinkling `@available(iOS <26)` guards.** Not needed — iOS 26+ is the floor. Use `#if os(...)` for *platform* differences, not OS-version fallbacks.
