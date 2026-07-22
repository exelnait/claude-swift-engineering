# Particle Emitters

> Some APIs here ship in 2025–2026 releases. Confirm exact names against current Apple documentation.

RealityKit's built-in particle system is the **`ParticleEmitterComponent`** — attach it to any entity and that entity becomes an emission point. It ships with ready-made **presets** (e.g. **Impact**, a good starting point for smoke) that you tune rather than building an emitter from scratch.

```swift
let smoke = Entity()
var emitter = ParticleEmitterComponent.Presets.impact  // confirm exact API — preset namespace/case name
emitter.mainEmitter.birthRate = 200                    // confirm exact property path
emitter.mainEmitter.lifeSpan = 3
smoke.components.set(emitter)
content.add(smoke)
```

You can configure every property of a `ParticleEmitterComponent` from Swift, or skip code entirely and author it in **Reality Composer Pro**: add the component to an entity, press the workspace's Play button to preview the default particles live, then dial in birth rate, lifetime, size, and color-over-life visually. Particle effects are often kept as their own standalone USD file (e.g. a `volcano_smoke` file) and dragged into the main scene once they look right.

## When ParticleEmitterComponent isn't enough: Compute Graph

`ParticleEmitterComponent` covers most emit-and-forget effects, but it doesn't give you custom per-particle simulation logic. For **fully GPU-driven, Metal-backed particle simulations** — custom spawn shapes, forces, and a custom shader for rendering each particle — Reality Composer Pro's **Compute Graph** is the tool. It organizes a simulation into four phases, wired up visually:

- **Emitter** — how and when particles are born (continuous, burst, single-shot).
- **Initialize** — runs once per particle at birth, setting starting values (velocity, lifetime, size), usually with some randomization so particles don't look identical.
- **Simulate** — runs every frame, applying forces (gravity, turbulence) that evolve particles over time.
- **Output** — the particle's final look as it ages: fade in/out, scale over lifetime, color shifts, and the Shader Graph material used to render it (e.g. a billboarded circle).

Compute Graph is authored entirely inside Reality Composer Pro, with support for custom nodes distributed as bundles — see `reality-composer-pro` for the full workflow.

## Particles and overdraw

Most particle effects (smoke, fire, sparks) are dense stacks of small, alpha-blended, billboarded cards — exactly the pattern that causes **overdraw**: the GPU recomputing the same screen pixel once per transparent layer on top of it. A single sparse emitter is cheap; a thick, layered smoke column asking for hundreds of overlapping particles per pixel is not. Treat particle density the same way you'd treat any other transparency budget — favor a moderate birth rate and shorter lifetime over "more particles" as the default way to make an effect read as denser, and check it at the distance and angle it's actually viewed from before committing to a heavy setting.

## Common mistakes

1. **Building an emitter from a blank slate.** Start from a preset (Impact for smoke, for instance) and tune it — it covers most of the way to many common effects already.
2. **Reaching for custom Metal/compute work the ParticleEmitterComponent's presets and properties already cover.** Check the built-in system before escalating.
3. **Reaching for `ParticleEmitterComponent` when you actually need custom per-particle simulation forces or a per-particle shader.** That's Compute Graph territory, not the emitter component.
4. **Forgetting particles are just another component.** They compose with the rest of ECS — parent an effect under the entity it should move with rather than hand-tracking its position separately.
5. **Letting an off-screen particle effect keep simulating.** Like any other content, an emitter that isn't culled with the rest of its chunk keeps costing GPU time even when nobody can see it.
6. **Not treating particle density as an overdraw cost.** Dense, layered alpha-blended particles are one of the easiest ways to quietly tank frame rate — tune birth rate and lifetime with the same care you'd give any other transparent material.
