# Shader Graph: Node-Based Materials

> Shader Graph node names below are drawn directly from Apple's Reality Composer Pro sessions. Confirm exact node names and parameters against current Apple documentation — Shader Graph's node catalog grows every release.

Shader Graph is Reality Composer Pro's node-based material editor: wire nodes together into a surface output instead of hand-writing a shader. This reference covers the newer surface shaders and a handful of nodes worth knowing by name; for the broader PBR/lighting/performance picture (texture packing, image-based lighting setup, unlit-vs-PBR budget tradeoffs) see `realitykit-rendering` and `3d-asset-optimization`.

## Surface shaders: RealityKit PBR Surface 2, Hair, Portal

- **RealityKit PBR Surface 2** expands the original PBR surface node with new properties: **sheen**, **subsurface scattering**, and more accurate diffuse and occlusion shading. Reach for it as the default surface node for a physically based material — it's what an environment like translucent ice relies on for realism.
- **Hair surface** is a dedicated surface shader for hair and fur. It models how light reflects along and scatters through fine strands, rather than treating hair as an ordinary opaque or alpha-tested surface.
- **Portal surface** and **Portal Geometry Modifier** give shader-level control over a portal's look: Portal surface lets you drive the portal's per-pixel opacity, and Portal Geometry Modifier drives vertex-animated portal geometry. (The portal's runtime behavior — the component that actually opens a view into another scene — is covered in `realitykit-rendering`; these Shader Graph nodes control its surface and geometry, not its placement.)

## Normal maps: Normal Map Decode vs. NormalMap

Normal-map textures are **data**, not color — pick the data/vector3 texture type so Shader Graph doesn't apply a color-space transformation to them. Two format details commonly break a normal map:

- **Format.** RealityKit expects **OpenGL**-format normal maps, not DirectX — the two look similar but invert the green channel. If a normal map looks subtly wrong (not obviously broken), suspect this first.
- **Range.** A raw normal-map texture stores values from 0...1, but shading math needs a **-1...1** range. The **Normal Map Decode** node remaps 0...1 to -1...1 in one step, so you don't have to do the multiply-by-2-and-subtract-1 math by hand.

Watch out for a second, similarly-named node: Shader Graph also has a node called **NormalMap**. Unlike the node of the same name in some DCC tools (e.g. Blender), it does **not** remap the texture's range — read node tooltips rather than assuming parity with your modeling tool's node of the same name.

## EnvironmentRadiance: cheap dynamic reflections on unlit materials

Sometimes a fully unlit, baked material almost looks right but is missing believable reflections (a metal rim on an otherwise baked/unlit asset, for example) — and a full PBR material is more than you want to pay for. The **EnvironmentRadiance** node, used inside an otherwise-unlit material graph, reads shading information from the scene's image-based lighting and exposes specular (and diffuse) radiance you can add on top of a baked texture. It's more expensive than a plain unlit material but cheaper than full PBR — use it when unlit alone isn't convincing but the asset doesn't need full physically based shading.

## Promote to Input + Material Instances

To make one material reusable across many similar assets instead of rebuilding the graph each time:

1. Select the file/texture reference nodes you want to vary per asset, right-click, and choose **Promote to Input** — this exposes them as parameters in the Inspector.
2. Right-click the material and choose **Create Instance** to make a **Material Instance**. An instance reuses the parent graph's compiled logic but lets you swap the promoted inputs (base color, normal map, a packed texture, …) per asset — you can't edit the base graph itself from the instance.

This is both a workflow win (no re-wiring per asset) and a performance one: RealityKit doesn't load or compile redundant copies of the same Shader Graph for every instance. At runtime, a Script Graph **Set Material Parameter** node (see `script-graph.md`) writes into exactly these promoted inputs.

## Common mistakes

1. **Reaching for full PBR Surface 2 everywhere.** It's the right default for physically based looks, but unlit materials with baked lighting are cheaper — reserve PBR (or EnvironmentRadiance on an unlit graph) for where dynamic shading actually matters.
2. **Wiring NormalMap where Normal Map Decode was needed.** Only Normal Map Decode remaps the 0...1 texture range to the -1...1 range shading expects; a normal map that looks "off" after wiring the wrong node is a range problem, not a bad texture.
3. **Missing the OpenGL/DirectX normal-map mismatch.** A subtly wrong normal map is often an inverted green channel from a DirectX-format source, not a range issue — check the source format before reaching for Normal Map Decode.
4. **Rebuilding a material graph from scratch per asset.** Promote the varying inputs once and use Material Instances — it saves authoring time and avoids the engine loading/compiling redundant copies of the same graph.
5. **Treating Portal surface / Portal Geometry Modifier as component settings.** They're Shader Graph nodes that shape a portal's per-pixel opacity and vertex-animated geometry; the portal's runtime placement and behavior live on the component itself (`realitykit-rendering`).
