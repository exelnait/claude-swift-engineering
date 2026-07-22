# USD Fundamentals

> Some APIs here ship in 2025–2026 releases. Confirm exact names against current Apple documentation.

USD started at Pixar, built to represent the enormously complex scenes inside a feature film — a set with thousands of props, cameras, lights, and characters, all authored in parallel by hundreds of artists. That heritage is why USD scales the way it does, and why "many people editing the same scene at once, safely" is a first-class feature rather than an afterthought. Apple recognized USD's potential early and has worked with Pixar on it for years. Today USD is the backbone of every spatial experience Apple platforms create — RealityKit content, Reality Composer Pro scenes, Quick Look and AR Quick Look, App Store Tags, and 3D embedded directly on the web.

The open source project behind USD is called **OpenUSD** — the industry-standard library for describing 3D scenes. USD has become the common 3D language well beyond film: award-winning games, factory floors, surgical suites, autonomous vehicles, and AI-driven simulation all build on it now, and the reach keeps expanding.

Apple is a founding member of the **Alliance for OpenUSD (AOUSD)**, the body working to make USD a true industry standard on paper, not just in practice — this year saw the first formal specification for USD's core released, with domain specifications for geometry, materials, and physics already underway. These working groups are an open effort; if you want a voice in how the industry builds and exchanges 3D content, that's where it happens. Separately, Apple is a member of the **Academy Software Foundation**, home to open source projects like MaterialX and OpenVDB (below).

## The core model: Layer, Composition, Stage, Prim

Five concepts carry almost all of USD:

- **Layer** — a single data file. The unit of authorship: one artist, one tool, one file.
- **Composition** — the mechanism that combines layers together into one whole. This is USD's signature feature.
- **Stage** — the *composed result* of one or more layers. This is your window into the full scene — what you traverse, query, and render.
- **Prim** — everything in a scene is a Prim (short for "primitive"): a mesh, a light, a camera, a group, a material. Each Prim has a **Schema**, which defines its type.
- **Attributes** and **Metadata** — a Prim's Attributes hold its actual data (a mesh's points, a light's intensity); its Metadata describes information about the Prim itself, rather than scene content.

The relationship to keep straight: you *author* Layers, you *compose* them, and you *look through* the resulting Stage. A single Prim on the Stage you see may have contributions arriving from several different Layers at once — that's composition working as intended, not a conflict to resolve.

## Composition and references: everyone works on their own layer

The payoff of this model is collaborative by design. Rather than copying an asset's data into your scene, you add a lightweight **reference** to it — the asset keeps living in its own file (its own layer), authored by whoever owns it, and you simply pull it in. Two consequences follow directly:

1. **Multiple people (or tools) can contribute to one scene concurrently**, each owning their own layer — layout in one file, sculpting in another, lighting and effects in a third — all composed together on the final stage.
2. **Updates propagate automatically.** Because you referenced the file rather than copying its contents, any change its author makes shows up in your stage the next time it's loaded — no re-export, no re-import, no asking someone to send you the latest version.

This is why real USD pipelines look like a web of small, focused files referencing each other rather than one monolithic scene file — and it's why USDKit's `addReference` (see `usdkit-api.md`) is the tool you reach for whenever you're pulling in an asset you don't own, rather than copying its data into your own prim.

## MaterialX and OpenVDB: USD doesn't work alone

USD composes with sibling open standards for the data it doesn't model itself:

- **MaterialX** (originally from Lucasfilm) — rich, portable material and shader descriptions. OpenPBR, the material model behind Apple's newest renderers, is built on top of this integration (see `materials-openpbr-and-splats.md`).
- **OpenVDB** (originally from DreamWorks, new this year) — volumetric data: smoke, clouds, fire, fluids.

Each of these came out of a world-class visual effects studio, and together with USD they form a composable foundation for 3D that spans authoring, materials, and volumetric effects. Apple updated its support for all three this year.

Gaussian Splats — scenes captured as millions of position/color/opacity particles rather than traditional geometry — are the newest addition to this foundation, arriving as a native USD prim type called Particle Fields. See `materials-openpbr-and-splats.md` for details, and `realitykit-rendering` for how RealityKit renders them.

## Common mistakes

1. **Treating a Stage like a file.** It isn't one — it's the *computed result* of composing potentially many Layers. "Editing the stage" really means editing one specific layer (often an explicit edit target); know which layer your edits are landing in.
2. **Copying data instead of referencing it.** This throws away composition's main benefit — collaborators' updates stop reaching you the moment you copy instead of reference.
3. **Forgetting a Prim's type lives in its Schema**, not in some separate enum or string you track yourself — the Schema is what other tools (and USDKit) use to know what kind of object they're looking at.
4. **Conflating Metadata with Attributes.** Applying a schema (like `AccessibilityAPI`) records that fact in the prim's *metadata* — it doesn't hand you usable data by itself. The actual values (a `label`, a `description`) still have to be authored as *attributes* in their own right (see `compression-and-accessibility.md`).
