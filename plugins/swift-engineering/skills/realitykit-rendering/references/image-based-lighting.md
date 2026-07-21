# Image-Based Lighting

> Some APIs here ship in 2025–2026 releases. Confirm exact names against current Apple documentation.

**Image-based lighting (IBL)** shades a surface using a 2D image of its surrounding environment, instead of (or alongside) discrete lights. RealityKit's **PBR materials** (`PhysicallyBasedMaterial`, and PBR-family Shader Graph surfaces) use IBL as their baseline shading model — it's what lets a metal or rough-plastic surface pick up believable ambient color and reflections. The payoff over baked lighting is that a PBR material lit by IBL can react **live** to a changing environment — e.g., the user turning on a real lamp near their Vision Pro.

## A skydome does not light your PBR assets

It's tempting to assume that once you've built a skydome or skybox — the large inverted sphere or distant geometry that hides passthrough beyond the edges of your content — your PBR objects are lit by it. **They are not.** A skydome is a mesh with a material; it doesn't feed any lighting information to anything else in the scene. If PBR assets look like they're lit from the wrong direction, or are missing highlights you'd expect from the "sun" in your skydome image, this is almost always why. Skyboxes should in fact be **unlit** — lighting PBR content requires a separate, explicit IBL setup.

## Setting up custom IBL

1. Create an entity to host the environment image (a plain entity is enough) and give it a name you'll recognize — you link to it by reference later.
2. Attach an **`ImageBasedLightComponent`** carrying a pre-rendered **HDR image in Lat/Long (equirectangular) format**. This is one of the few textures in a RealityKit scene that genuinely needs to be HDR.
3. Attach an **Image Based Light Receiver component** // confirm exact type name (`ImageBasedLightReceiverComponent`) to the **parent** of the PBR objects you want lit — it cascades to every child — and point it at the IBL entity from step 2.

```swift
let ibl = Entity()
ibl.components.set(ImageBasedLightComponent(source: .single(hdrEnvironmentResource)))  // confirm exact initializer
content.add(ibl)

pbrObjectsParent.components.set(
    ImageBasedLightReceiverComponent(imageBasedLight: ibl)  // confirm exact API — links the receiver to the IBL entity
)
```

Nothing changes in your scene until **both** components exist and are linked — a common early mistake is stopping after step 2 and wondering why lighting looks unaffected.

Keep the IBL texture **small**. Unless the scene has mirror-like surfaces, **512px across is usually enough** — a fraction of the resolution a good skydome texture needs, because IBL drives soft ambient shading and blurry reflections rather than anything the eye resolves sharply. HDR textures are expensive to load and render, so don't oversize this one just because "HDR" sounds like it wants to be big.

## EnvironmentRadiance: specular reflections without full PBR

Sometimes an asset needs *a hint* of environment reflection — a metal wagon-wheel rim, say — but doesn't warrant the cost of a full PBR material. Shader Graph's **`EnvironmentRadiance`** node exposes the same shading data an IBL would feed a PBR material, but usable **inside an unlit graph**. Read its **specular** output for view-dependent reflections that shift realistically as the camera moves; if your diffuse lighting is already baked into a texture, skip the node's diffuse output entirely and just add specular on top of the baked color.

`EnvironmentRadiance` costs more than a plain unlit material, but less than switching the whole material to PBR. Reach for it specifically when unlit-alone isn't convincing — not as a default upgrade to every unlit material.

## Recap

- **Skybox** — large, relatively low-dynamic-range texture, **unlit** material.
- **IBL** — small HDR lat/long image, via an `ImageBasedLightComponent` **and** a receiver component, linked together.
- **EnvironmentRadiance** — a shader-graph shortcut for specular-only reflections inside an otherwise unlit graph.

## Common mistakes

1. **Assuming the skydome lights PBR objects.** It's just geometry; PBR lighting requires an explicit `ImageBasedLightComponent` plus a receiver.
2. **Adding the IBL component but forgetting the receiver.** Nothing lights up until both exist and the receiver references the IBL entity.
3. **Oversizing the IBL HDR texture.** 512px is usually plenty; that resolution budget belongs to the skydome, not the IBL image.
4. **Reaching for full PBR when `EnvironmentRadiance` would do.** It's meaningfully cheaper and lives inside an unlit graph — use it for "just needs a reflective highlight" assets.
5. **Using an LDR image as the IBL source.** IBL specifically wants HDR data to represent bright light sources correctly; an LDR texture clips the highlights that make reflections look convincing.
6. **Attaching the receiver to individual PBR objects instead of their shared parent.** Attach it once, on the parent, so the whole subtree inherits it.
