# Lightmaps, Live Preview & the Reality Composer Pro Assistant

> Live Preview / Preview on Device is called out in the source material as shipping "later in the year." Confirm current availability and exact API/menu names against current Apple documentation.

## Lightmap component: baking indirect lighting

Indirect lighting is light that bounces around a scene and reaches areas no light directly illuminates — the space under a table, say. Simulating it live is expensive, but if a scene's lights are **static** (they don't move), you can precompute it once and store the result as a texture instead: a **Lightmap**.

Attach a **Lightmap component** to the entity (typically a scene's root) you want baked. It controls which lighting term(s) to bake and the quality under **Bake Settings** (e.g. low → high — higher quality costs more time to bake). Three lighting terms are available:

- **Indirect Lighting** — the bounced-light term itself.
- **Ambient Occlusion** — how visible each point is to its surroundings (contact shadowing).
- **Beauty** — the final combined color per point, direct and indirect lighting together.

Open the **Lightmap Preview** tab (Tab menu) to see the baked result update in real time as you tune settings, before committing to a full bake. Because a Lightmap is a snapshot, **re-bake whenever static lighting changes** — move, recolor, or re-intensity a static light after baking, and the old Lightmap stops matching until you regenerate it.

## Live Preview / Preview on Device

Live Preview lets you keep authoring in Reality Composer Pro on your Mac while a companion app on a connected **Vision Pro** shows the result instantly — closing the loop between an edit and seeing (or feeling) it in a real spatial experience. It ships later in the year; confirm current availability.

Start it from the launch control / simulation toolbar: switch the simulation mode to **Preview on Device**, choose the connected Vision Pro, and press Play. It pairs well with **Mac Virtual Display**, so you can keep your hands on the Mac's keyboard/mouse — tuning a value, a Script Graph override, a light — while watching the effect live on the headset. Because it's the actual runtime on the actual device, effects that are hard to judge on a flat monitor (lighting reacting to physical space, an interaction's felt "weight," animation timing) become obvious immediately.

## Reality Composer Pro Assistant

An AI assistant available from the editor's right-hand panel, driven by plain-language prompts. It:

- **Generates 3D content on demand** — models and materials — directly into your project (e.g. "add a few more items to the workbench," "add some candles").
- **Answers Reality Composer Pro questions**, functioning as a built-in help/Q&A surface as well as a generator.

Treat what it produces as a fast draft: great for unblocking "I need *something* here to keep iterating" moments and set-dressing, but give generated models and materials the same review and optimization pass you'd give any placeholder asset (see `3d-asset-optimization`) before shipping.

## Common mistakes

1. **Judging a lighting change from the flat editor viewport alone.** When a Lightmap is involved, the true test is the (re-)baked result — check the Lightmap Preview tab, and for spatial work, Live Preview on an actual device.
2. **Forgetting to regenerate a Lightmap after moving a static light.** This is the most common "why does my scene suddenly look wrong" moment — if static lights moved, the indirect lighting is stale until you re-bake.
3. **Baking at high quality on every iteration.** Use a lower quality setting (or the Lightmap Preview tab) while tuning, and reserve a full high-quality bake for once the lighting is settled, since cost scales with quality.
4. **Using the Lightmap workflow on a light that moves or reacts to gameplay.** It's explicitly for static lights; anything that animates or responds at runtime needs real-time lighting, not a bake.
5. **Assuming Live Preview / Preview on Device is already available.** The source material flags it as arriving later in the year — confirm current availability before a workflow depends on it.
6. **Shipping Assistant-generated content unreviewed.** It's fast for iteration, but a generated model or material deserves the same scrutiny (poly count, texture budget) as any other asset before it ships.
