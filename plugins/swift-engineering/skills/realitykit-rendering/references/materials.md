# Materials: PBR, Unlit, and Shader Graph

> Some APIs here ship in 2025–2026 releases. Confirm exact names against current Apple documentation.

Every `ModelComponent` pairs a mesh with one or more materials. RealityKit gives you three built-in Swift material types, plus a fourth path — Shader Graph — for materials authored visually in Reality Composer Pro. Picking the cheapest one that looks right is the single biggest lever you have over rendering performance.

## The three built-in material types

- **`UnlitMaterial`** — a color or texture with **no lighting computation at all**. Cheapest option by far. Correct choice for anything whose shading is already baked into its texture, and mandatory for skydomes/skyboxes.
- **`SimpleMaterial`** — a lightweight PBR-ish material: a solid or textured color, scalar roughness, and a boolean `isMetallic`. Good for placeholders and simple props that don't need full per-channel PBR control.
- **`PhysicallyBasedMaterial`** — full PBR control over **base color (diffuse), normal, roughness, metallic, and ambient occlusion**, each settable as a constant or a texture:

```swift
var material = PhysicallyBasedMaterial()
material.baseColor = .init(texture: .init(try .load(named: "diffuse")))        // confirm exact API surface
material.normal = .init(texture: .init(try .load(named: "normal")))
material.roughness = .init(floatLiteral: 0.6)
material.metallic = .init(floatLiteral: 0.0)
material.ambientOcclusion = .init(texture: .init(try .load(named: "ao")))
```

PBR materials are the ones that read **image-based lighting** (see `image-based-lighting.md`) — that's what lets them react live to a changing environment. That capability is also what makes them more expensive than `UnlitMaterial` or `SimpleMaterial`.

## Shader Graph materials, loaded by name

Materials built visually in Reality Composer Pro's Shader Graph — node graphs mixing textures, math, and surface shaders (PBR, unlit, hair, portal) — compile into an asset you load by name from your app, the same way you load an entity from the package bundle:

```swift
// Shader Graph materials aren't shown loading from Swift verbatim in the source sessions;
// confirm the exact type/initializer against current Apple documentation.
let lavaMaterial = try await ShaderGraphMaterial(named: "LavaMaterial", from: "PyroPanda", in: realityKitContentBundle)  // confirm exact API
model.model?.materials = [lavaMaterial]
```

Author the graph itself in Reality Composer Pro — see `reality-composer-pro`.

## Why unlit + baked wins on performance

RealityKit's own guidance for spatial content: light the scene once in a DCC tool (Blender, Maya, etc.), **bake all of the shading down into a single texture per object**, and apply it with an `UnlitMaterial`. Use **realtime/dynamic lights sparingly** — they have real performance implications, especially in an immersive scene where the GPU renders every visible pixel every frame. Skydomes and skyboxes in particular should always be unlit; they're one of the first assets worth optimizing this way, since a PBR skydome buys you nothing (the viewer never sees it move or react) at real cost.

## Material instances and texture packing

Two companion techniques squeeze more performance and reuse out of PBR/Shader Graph materials:

- **Material instances** reuse one Shader Graph's compiled logic across many assets while only its exposed parameters (textures, colors, scalars) vary per instance — a workflow win (promote inputs once, then just swap textures per asset) and a performance win (the engine doesn't load a redundant copy of the graph).
- **Texture packing** folds separate grayscale data textures (roughness, metallic, AO) into the R/G/B channels of one texture, which then benefits from compression at build time — cutting the memory footprint of a PBR asset substantially.

Both are covered in depth in `3d-asset-optimization`, including the normal-map format/range gotchas (OpenGL vs. DirectX, and the 0…1 → −1…1 remap) that trip people up when wiring a packed texture into a `PhysicallyBasedMaterial`.

## 2026 Shader Graph surface additions

Shader Graph's built-in surface nodes grew this cycle:

- **RealityKit PBR Surface 2** extends the original PBR surface node with **sheen**, **subsurface scattering**, plus more accurate diffuse and occlusion shading.
- **Hair surface** is a dedicated shader for strand-based hair/fur, modeling how light reflects along and scatters through fine strands.
- **Portal surface** and **Portal Geometry Modifier** let you drive a portal's per-pixel opacity and vertex-animate its geometry.

All are nodes inside Shader Graph, authored visually — see `reality-composer-pro`.

## Common mistakes

1. **Reaching for `PhysicallyBasedMaterial` by default.** Full PBR shading (and any lights driving it) costs meaningfully more than unlit. Only pay for it where the material must react to a changing environment.
2. **Shipping unpacked grayscale data textures.** Separate roughness/metallic/AO textures don't compress at build time; pack them into one RGB texture (see `3d-asset-optimization`).
3. **Wrong normal-map format or range.** RealityKit expects **OpenGL-format** normal maps (not DirectX — the green channel is inverted) in a **−1…1** range; if your source texture is 0…1, use the **Normal Map Decode** node — the plain **NormalMap** node does *not* remap the range, unlike its Blender namesake.
4. **Missing or wrong color space on textures.** Perceptual textures (base color, unlit color) need a color space like sRGB matching their authored gamut; grayscale data textures (roughness, AO, normal) should stay untransformed data.
5. **Re-authoring the same Shader Graph per asset.** Use a material instance instead, so only the exposed parameters vary and the engine isn't loading duplicate graph logic per object.
6. **Treating a skybox/skydome as just another PBR surface.** It should be unlit, and large/high-resolution (8K+ horizontal is a reasonable target) since the viewer sees it fill most of the frame — but crop out anything below the visible horizon rather than paying for detail no one sees.
