# Materials, OpenPBR & Gaussian Splats

> Some APIs here ship in 2025–2026 releases. Confirm exact names against current Apple documentation.

## OpenPBR: a shared, richer material model

**OpenPBR** is a significant upgrade over **USDPreviewSurface** (USD's older baseline material model) — it brings richer, more physically accurate materials to the workflow. It isn't a Preview-only feature: all of Apple's renderers (below) support it, so a material authored once looks consistent regardless of which renderer draws it. If you've been shading against USDPreviewSurface, treat OpenPBR as the model to move toward — it's what the current generation of Apple's rendering tools is built around.

## Choosing a renderer in Preview and Quick Look

Underneath all of this is **Hydra**, USD's high-performance rendering architecture, built to get scenes with millions of objects on screen fast. Preview and Quick Look on Mac now let you pick between three renderers on top of it, each suited to a different need:

- **RealityKit** — the same renderer used on iPhone, iPad, and Vision Pro. Pick this when you want what you see in Preview to match what ships on-device, across the board.
- **Storm** — Hydra's own Metal-accelerated renderer, already part of the core USD open-source distribution. Pick this if your pipeline already targets Storm elsewhere (other DCCs' USD viewports, for instance) and you want visual consistency with it.
- **Raytracer** (new) — a ground-truth, production-quality renderer built for scenes that demand more: accurate reflections, precise shadows, physically correct lighting. Use it for architectural visualization, product imagery, or any time you need a high-fidelity reference render rather than a fast preview.

All three read OpenPBR materials, so switching renderers to compare results doesn't mean re-authoring shaders — and since OpenPBR is a USD/MaterialX-level standard rather than a RealityKit-only feature, any Hydra-based renderer (Storm included) can pick it up too.

## Particle Fields: Gaussian Splats as native USD data

**Gaussian Splats** reconstruct a real-world scene not from traditional geometry but from millions of overlapping "splats" — particles that each encode a position, a color, and an opacity — captured from photographs. The result can reproduce subtle, view-dependent lighting responses that are difficult to get from a textured mesh, which is what makes splats so good at faithfully capturing complex real-world environments.

Apple, working with Alliance for OpenUSD partners including NVIDIA, Adobe, and Pixar, introduced a new USD primitive type for this: **Particle Fields**. It describes Gaussian Splats — and other representations from this still fast-moving area of research — as a native prim, which means, for the first time, splats compose into the **same stage** as your ordinary meshes and materials, rather than needing a separate viewer or pipeline.

For how RealityKit actually renders a Particle Fields prim in your app — performance characteristics, combining splats with lit geometry, and so on — see `realitykit-rendering`. This file covers the USD side: splats are scene data like anything else, referenceable and composable the same way a mesh prim is (see `usd-fundamentals.md`).

## Common mistakes

1. **Assuming USDPreviewSurface and OpenPBR are interchangeable.** OpenPBR is the newer, richer model current renderers are built around — don't keep authoring against USDPreviewSurface out of habit if OpenPBR is available to you.
2. **Picking Storm by default.** It exists for compatibility with existing production pipelines, not because it's the recommended default — for consistency with what ships on-device, RealityKit is usually the better Preview choice.
3. **Reaching for the Raytracer for everyday iteration.** It's a ground-truth, high-fidelity renderer, not necessarily the fastest to iterate with — use it for final reference images, not every save.
4. **Treating a Gaussian Splat capture as something that lives outside USD.** With Particle Fields, splats are a first-class prim type — they belong in the same stage, referenced and composed the same way as any other asset.
