# Compute Graph: GPU Particle & Simulation Systems

> Compute Graph shipped as part of Reality Composer Pro 3 (2025–2026 cycle). Confirm exact node names against current Apple documentation.

Compute Graph is Reality Composer Pro's visual, node-based tool for building GPU-driven particle and simulation systems, backed by Metal, directly in the editor. It gives full control over spawning, per-frame simulation, and rendering, with support for custom nodes — capable of anything from a simple particle effect to a complex fluid simulation. (For a much simpler one-off effect, RealityKit also has a basic `ParticleEmitterComponent` with built-in presets — see `realitykit-rendering`. Reach for Compute Graph when you need custom per-particle logic or GPU simulation beyond what a preset offers.)

A Compute Graph only evaluates during the **simulation stage** — it's invisible in the plain scene view. Press Play, or dock the simulation tab (see `scene-composition.md`), to see it run.

## The four phases

Every Compute Graph starts from a four-phase template:

1. **Emitter** — how and when particles are born: **Continuous Emit** (a steady stream, with each frame's spawn count kept in check), a burst, or a one-shot.
2. **Initialize** — runs once per particle, at birth. Set starting values here: size (with randomized variation so particles aren't uniform), randomized lifetime (so particles don't all disappear at the same instant), and initial position — e.g. a **Spawn in Sphere** node distributes particles inside a spherical volume, and a **Set Position** node can clamp an axis (e.g. clamp Y to 0 to flatten a sphere's spawn volume down to a circle on a surface).
3. **Simulate** — runs every frame, applying forces that evolve particles over time: gravity, turbulence, or a **negative gravity** force to make particles drift upward (rising smoke/steam).
4. **Output** — appearance over the particle's lifetime: fade in/out, scale down, shift color by height or age. Rendering itself goes through a **Shader Graph material** (see `shader-graph.md`) — for instance, a material that draws a circle on a billboard for a rounder particle silhouette.

## Attaching it to a scene

Add a **Compute Simulation** component to the entity that should host the effect, then pick a graph from its **Compute Graph picker**, which lists every Compute Graph asset in the project (see `scene-composition.md` for the picker and per-prototype-instance overrides of which graph is assigned).

## Custom Compute Graph nodes

Project-specific nodes (like a Spawn in Sphere node) are authored in a **Compute Graph bundle** and then appear alongside the built-in phase nodes. `// confirm exact bundle authoring API/structure against current Apple documentation` — the source material points to a separate guide for writing one rather than detailing its structure.

## Common mistakes

1. **Expecting a Compute Graph to animate in the plain scene view.** It only evaluates during simulation — press Play or dock the simulation tab.
2. **Not randomizing per-particle lifetime and size.** Uniform values make every particle spawn, live, and die in visible lockstep, killing the "natural" look (smoke, sparks, rain) even when the simulation itself is correct.
3. **Putting per-frame logic in Initialize, or one-time values in Simulate.** Birth-time values (starting size, lifetime, spawn position) belong in Initialize; anything that evolves over the particle's life (forces, fading, color-by-age) belongs in Simulate/Output. Swapping them either freezes a value that should evolve or reapplies a value needlessly every frame.
4. **Forgetting Output still needs a Shader Graph material.** Compute Graph handles spawning and motion; how a particle actually renders is an ordinary material, same as any other surface.
5. **Reaching for a positive gravity value and expecting particles to rise.** A rising-smoke look is **negative** gravity, not a dedicated "rise" node.
