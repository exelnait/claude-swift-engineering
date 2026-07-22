# Textures and Compression

> The AVIF and mesh-compression export options here ship in 2025–2026 releases. Confirm exact export-option names against current Apple documentation.

Texture memory is one of the cheapest wins in the whole optimization pass — most of it comes from combining files that were never going to look different once compressed, and picking the color space that matches what you actually authored.

## Texture packing

A typical PBR asset ships separate grayscale textures for roughness, metallic, and ambient occlusion. Shader Graph correctly treats these as **data** (no color-space transform), but that has a cost: **grayscale textures don't get compressed when the app builds.** They ship close to full size.

The fix is **texture packing**: combine three grayscale textures into the **R, G, and B channels of one color texture** (e.g. roughness → R, metallic → G, AO → B). The packed RGB texture *does* get compressed at build time. Just packing your grayscale textures together can shrink a PBR asset's total size by **up to 40%**.

To wire this up in Shader Graph:

1. Bring in the packed texture and set its node's type to **`Vector3`** (data), not `Color` — this tells the shader not to apply any color-space transform to it.
2. Feed it into a **channel-separate node** (referred to as "separate three" — likely `Separate3` in the node library; confirm the exact node name) to split it back into individual scalar channels.
3. Wire each output to the matching input (roughness, AO, etc.) on your PBR shader.

## Color spaces

When you assign a color texture (e.g. base color), Shader Graph shows a color space as two terms separated by a dash, like `sRGB - Display P3`:

- **Transfer function** (first term) — the encoding curve. Use **sRGB** for *perceptual* textures you look at directly (base color, unlit color). Use **Linear** for *data* or HDR images (normal maps, packed roughness/metallic/AO, IBL textures).
- **Gamut** (second term) — the color space's outer extents. Vision Pro's native display gamut is **Display P3**; textures authored in other gamuts are converted to Display P3 when you build in Xcode.

Always pick the color space matching your texture's **authored intent**, not just what looks right in the editor — mismatches are silent until you compare against the source render.

## Normal maps

Normal maps are also **data** (`Vector3` type, no color-space transform), but they fail in two independent, easy-to-confuse ways:

- **Format.** RealityKit expects **OpenGL**-format normal maps. **DirectX**-format normal maps look similar but have an **inverted green channel** — know which format your source textures were authored in.
- **Range.** A normal map material expects values from **-1 to 1**, but the texture file only stores **0 to 1**. Remap with `(sample * 2) - 1`, or use Shader Graph's **`Normal Map Decode`** node to do it in one step.

Watch out for the node literally called **`NormalMap`** — despite sharing a name with Blender's normal-map node, RealityKit's `NormalMap` node does **not** remap the range. Read node tooltips; don't assume a name matches behavior from another tool.

## AVIF and mesh compression

RealityKit supports **AVIF**-encoded textures: quality comparable to JPEG, support for **10-bit color**, at a significantly smaller file size. Export AVIF textures via the **Preview** app on Mac or the **`usdcrush`** command-line tool.

Pair texture compression with the newer **mesh compression** codec (built with the Alliance for Open Media), which can reduce mesh sizes by **up to 90%**. Combined, AVIF texture compression and mesh compression bring the *average* asset down to roughly **7x smaller**, with no visible quality loss. In code, this is exposed through a USD stage's `exportPackage` API — pass export options that enable texture and mesh compression (see `usd-usdkit` for the full API). Without writing code, Preview and `usdcrush` apply the same compression.

## Scale resolution by distance and screen size

Texture resolution should follow where the viewer will actually be looking, not be uniform across the scene. In a stationary-viewer scene, it's common for **more than half** of your total texture resolution to be dedicated to just the 5–10 meters immediately around the viewer. If the viewer isn't going to move much, scale texture resolution down for objects that are far away or small on screen — they don't need full resolution to look correct.

## Common mistakes

1. **Shipping unpacked grayscale textures.** Roughness/metallic/AO as three separate files miss out on both packing's size reduction *and* compression, since standalone grayscale textures don't compress.
2. **Picking the wrong color space for a texture's intent.** sRGB on a data texture (or Linear on a perceptual one) silently distorts values — always match what the texture was authored as.
3. **Assuming `NormalMap` fixes the range problem.** It doesn't — use `Normal Map Decode`, or do the multiply-by-2-minus-1 math yourself.
4. **Mixing normal map formats.** Applying an OpenGL-expecting pipeline to a DirectX-authored normal map (or vice versa) inverts surface detail — check the green channel if a normal map looks subtly wrong.
5. **Leaving every texture at full resolution regardless of distance.** Most of a scene's texture budget should go to what's close/large on screen; scale everything else down.
