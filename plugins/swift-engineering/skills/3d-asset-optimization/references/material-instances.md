# Material Instances

Once you've built one PBR material correctly in Shader Graph — texture packing, color spaces, normal-map decoding all wired up — you don't want to redo that setup for every new asset that needs the same *kind* of material with different textures. **Material Instances** solve exactly this: they let you reuse one material's logic while varying a set of exposed parameters per instance.

## Why it's not just a convenience feature

Material Instances save authoring time — you stop rebuilding the same graph over and over — but they also **improve runtime performance**: the engine doesn't need to load redundant copies of the same shader graph. Ten assets sharing one base material via instances is cheaper to load and render than ten independently authored (but logically identical) materials.

## Setting one up

1. **Author the base material once**, fully wired (packed textures split out, color spaces set, normal map decoded, and so on).
2. **Promote the parameters you want to vary per asset to inputs.** Select the relevant nodes — typically the file-reference nodes for base color, normal map, and packed roughness/metallic/AO — right-click, and choose **Promote to Input**. Those parameters now appear in the inputs panel.
3. **Create an instance.** Right-click the base material and choose **Create Instance**. The instance exposes the promoted parameters as editable fields, but you cannot edit the base graph's logic from an instance — only its inputs.
4. **Swap in per-asset textures on the instance** (base color, normal map, packed texture). Everything downstream — the packing unpack, the color-space handling, the normal-map decode — is already built into the shared graph, so a new asset only needs its three or four textures dropped in.
5. **Name each instance for the asset it belongs to.** With many instances of one base material, an unclear name is the only thing distinguishing them.

If a material has no promoted parameters, every instance of it is identical — there's nothing yet to vary. Promote at least the textures you expect to change per asset before creating instances.

## When to reach for this

Any time you have multiple assets that share a *shading approach* (e.g. "packed PBR opaque prop," "unlit baked-lighting prop") but need different textures, build the approach once as a base material and make an instance per asset — rather than duplicating the graph, or hand-editing texture references on copies of the same material.

## Common mistakes

1. **Forgetting to promote a parameter before creating instances.** Without promoted inputs, instances have nothing to vary — you'll find yourself editing the base material again, which defeats the point.
2. **Duplicating the whole material graph per asset instead of instancing.** This reintroduces the redundant-shader-graph cost Material Instances exist to avoid, and multiplies the maintenance burden if the base shading approach ever needs a fix.
3. **Leaving instances unnamed or ambiguously named.** When an instance's name doesn't match its asset, swapping textures on the wrong instance is an easy mistake to make and a hard one to spot visually.
4. **Expecting to edit base-graph logic from an instance.** Instances only expose promoted inputs; structural changes (new nodes, different wiring) belong on the base material and propagate to every instance automatically.
