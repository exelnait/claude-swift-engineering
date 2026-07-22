# Rendering Pitfalls: Why an Entity Isn't Rendering

3D renderers stay fast partly by being selective about what they spend time drawing — something might be too far away, occluded, clipped, too transparent, waiting on an anchor, or simply missing its assets. In every one of these cases your content silently doesn't render, and there's no single symptom that tells you which one you're looking at. Working it out is a **process of elimination**, using the viewport, the inspector, and the hierarchy filter bar together.

The best fix is to never hit most of this list: compose placement, materials, and hierarchy in **Reality Composer Pro** (`reality-composer-pro`) rather than hand-authoring them in Swift. But when content still goes missing, work through the following causes — roughly in the order you'd naturally discover them while inspecting an entity.

## The "missing content" checklist

1. **Occluded by a bad transform.** The entity is genuinely in the scene, but a wrong translation puts it under or behind something else. Its selection highlight is still visible in the viewport (highlights show through occlusion) even though the rendered content isn't — check the `Transform` for an unexpected value, e.g. a negative axis that puts it below the surface it should sit on.

2. **Translated outside the scene bounds → clipped.** No selection highlight visible anywhere. Double-click the entity in the hierarchy to fly the camera to it — if it's way outside where you expect, it's likely beyond the scene's bounds, shown in the viewport as a **yellow bounds box**. Content outside those bounds is clipped by the renderer and never drawn. Fix the translation.

3. **Scaled so large the camera ends up inside the mesh.** Flying to the entity reveals it's enormous — you're actually inside its geometry. Mesh triangles are typically visible from one side only, so from inside an "inside-out" mesh there's nothing to see. Reduce the scale.

4. **Entity disabled (`isEnabled == false`).** The hierarchy outline marks disabled entities with an indicator; a disabled entity and its whole subtree stop rendering (and updating). Check the inspector for *why* — it may be intentional (e.g. a custom "out of stock" flag disabling an item on purpose) rather than a bug. Confirm the intent before "fixing" it.

5. **A stray `AnchoringComponent` with no matching ARKit anchor.** An entity waiting on an anchor that never arrives simply never renders — no error, no timeout. This is a common leftover from a cut feature, e.g. a prototype that anchored content to something you later removed. When you remove a feature, audit the components you added for it, not just the code that used them.

6. **No `ModelComponent`.** The viewport shows only an axis gizmo where the entity should be — no selection outline shape, because there's no geometry to outline. The inspector confirms there's no `ModelComponent` at all. The debugger tells you *what's* missing; finding out *why* (a failed load, or the component attached to the wrong entity) means checking the loading code.

7. **A material with a contradictory opacity/threshold setup.** Nothing shows in either viewport, but the selection *shape* is correct — so the mesh is fine and the material is the suspect. A material set to semi-transparent (opacity below 1) *and* given an **opacity threshold of 1** tells the renderer "don't draw anything below full opacity" while simultaneously making the whole surface below full opacity — net effect, the entire model is invisible. Reconcile the opacity value against the threshold (see `realitykit-rendering`).

8. **Broken or inverted normals.** The entity is partially visible and nothing in the inspector's fields looks obviously wrong. Switch the preview viewport's rendering-mode dropdown to **visualize Normals** — it colors the mesh by per-point normal direction. Compare against a known-good entity in the same mode: a broken mesh reads as a visible "mess" where a good one reads as a smooth gradient. This is an asset problem — fix it in the DCC tool that authored the mesh, not in RealityKit.

9. **Never added to the scene.** There's nothing to select because the entity doesn't exist in the capture. Confirm with the hierarchy's **filter bar** — filter to a substring you expect the name to contain and see whether anything matches. If nothing does, the entity was simply never created or added — a common outcome of copy-pasted creation code that skipped one iteration.

## Common mistakes

1. **Assuming "invisible" means "not in the scene."** Most of the causes above are entities that *are* present. Reach for the filter bar specifically to test cause 9 rather than assuming it whenever something's missing.
2. **Fixing the wrong layer.** Tweaking material color when the real issue is the opacity/threshold combination, or second-guessing the mesh when the real issue is scale — localize the cause with the checklist before changing anything.
3. **Judging normals from a single mesh.** A normals-mode render is hard to interpret alone; compare it against a known-good entity in the same mode to make a broken one obvious.
4. **Treating a disabled entity as automatically broken.** Check the inspector for a component that explains *why* it's disabled — disabling can be intentional application logic, not a bug.
5. **Hand-placing, hand-scaling, and hand-materializing content in code.** Nearly every cause on this list originates in manual Swift setup. Reality Composer Pro's authoring tools catch most of them before the app ever runs (see `reality-composer-pro`).
