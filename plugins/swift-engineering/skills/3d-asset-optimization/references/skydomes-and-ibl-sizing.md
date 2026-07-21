# Skydomes and IBL Sizing

A fully immersive scene needs something behind everything else, or the viewer sees their real passthrough environment past the edge of your content. That's the **skydome** (or skybox). Lighting your PBR materials to *look like* they belong in that environment is a separate job, handled by a much smaller **image-based-lighting (IBL)** texture. The two have almost opposite sizing rules, and it's easy to conflate them.

## The skydome/skybox

- **Geometry**: any large enclosing mesh works — an inverted sphere is a common choice. Make it large enough (or far enough from the user) that scale/parallax don't give it away; a diameter on the order of ~500 meters is a reasonable reference point.
- **Material**: always **unlit**. The skydome should never be shaded by scene lighting — it *is* the backdrop.
- **Texture resolution**: skydomes want **high-resolution** textures — **8K horizontal or more** for imagery with fine detail, to avoid visible blurriness. This single texture can dominate the screen (the whole visible background), so it's one of the highest-value — and one of the **first** — assets to optimize.
- **Crop what won't be seen.** If the skydome only needs to show what's above the horizon (or whatever region the viewer can actually reach with their gaze), crop the source texture down to that region before shipping it — there's no reason to pay for pixels no one will see.

## Image-based lighting (IBL) is the opposite: small

A skydome mesh is **just geometry** — on its own, it does not contribute any shading to PBR materials. To have PBR assets look lit by your environment (instead of the real-world environment around the user), you need a **separate** IBL setup:

1. Create an entity to hold the IBL (a plain transform entity, named clearly, e.g. `"IBL"`).
2. Attach an **`ImageBasedLightComponent`** (confirm exact type name) referencing a pre-rendered **HDR** image in **lat/long (equirectangular)** format. This is one of the few textures in a scene that actually needs to be HDR.
3. Attach an **`ImageBasedLightReceiverComponent`** (confirm exact type name) to the **parent** of your PBR objects — it applies to the whole child hierarchy — and link it to the IBL entity created in step 1.

Unlike the skydome, the IBL texture should usually be **small** — **512 pixels across** is a reasonable default. HDR textures are expensive to load and to render, and unless your scene has mirror-like, highly reflective surfaces, you won't be able to tell the difference between a 512px IBL and a much larger one. Reserve a bigger IBL texture for scenes that genuinely need sharp reflections.

## When unlit isn't quite enough

Some assets need *some* dynamic lighting response — a metal rim that should show reflections as the viewer moves — without paying for a full PBR shader. The **`EnvironmentRadiance`** node (Shader Graph) lets an **unlit** graph read shading information from the IBL: its specular output gives you view-angle-dependent reflections that you can add on top of a baked/unlit texture. This is more expensive than a plain unlit material, but still cheaper than switching the asset to full PBR. See `realitykit-rendering` for the full PBR/lighting/shadow picture and more on `EnvironmentRadiance`.

## Common mistakes

1. **Expecting the skydome to light PBR assets.** It's an unlit mesh — assets will look flat, or lit by the wrong (real-world) environment, until you add both an `ImageBasedLightComponent` and an `ImageBasedLightReceiverComponent`.
2. **Adding only one of the two IBL components.** Both are required: the light component provides the environment texture, the receiver component (on the PBR hierarchy) opts objects into using it. Either one missing means no effect.
3. **Sizing the IBL texture like the skydome.** The skydome wants 8K+; the IBL usually wants ~512px. Treating them the same wastes load time and render cost on the IBL for no visible benefit outside mirror-like surfaces.
4. **Shipping an unlit skydome without cropping.** A skydome this large and high-resolution is one of the most expensive single textures in the scene — crop out any region the viewer will never actually see.
5. **Reaching for full PBR when `EnvironmentRadiance` would do.** If an unlit asset just needs believable view-dependent reflections (not full physically-based shading), the `EnvironmentRadiance` node is the cheaper middle ground.
