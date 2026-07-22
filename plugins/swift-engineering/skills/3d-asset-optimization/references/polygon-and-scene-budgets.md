# Polygon and Scene Budgets

Triangle count is the first thing to plan for, and the right number depends entirely on how your scene will be viewed. There's no single "safe" polygon count — there's a budget for total scene complexity and a (smaller, more important) budget for what's actually visible at once.

## Why viewing context sets the budget

On visionOS, the GPU is only responsible for pixels you actually render — **not passthrough video**. A windowed or shared-space app renders a modest region of the frame; a fully immersive app renders the *entire* view, every frame, with no passthrough to offset the cost. That means the same asset can be cheap in one context and expensive in another — the geometry didn't change, but how much of the viewer's world is now virtual did.

Because this scales with device, scene complexity, and exactly what's on screen, you can't derive a hard performance number from triangle count alone. **Test early, on real hardware**, rather than relying on a desktop preview or a rule of thumb.

## Target triangle counts

| Context | Triangle budget | Notes |
|---|---|---|
| Fully immersive scene | ~500,000 total | Upper bound for the whole scene |
| Shared space app | ~250,000 total | Lower, since your app draws less of the frame |
| Visible at any one time | ~100,000 | The number that actually matters — leaves headroom regardless of total scene size |

A real example: a full sample environment (skydome, terrain, foliage, props, all optimized per this skill) landed at 108,000 triangles total — on budget for an immersive scene — and because the scene was chunked, users typically only saw about half of that in any single frame.

## Budget what's visible, not what exists

The total-scene numbers above are a ceiling; the number that actually determines frame time is what's in view. Two techniques make that number much smaller than the scene's total:

- **Chunk large objects.** Terrain, building interiors, and other big single meshes should be split into multiple pieces so RealityKit can cull the pieces that are off-camera. A single monolithic terrain mesh can't be partially culled — chunking it can.
- **Model to apparent size, not absolute size.** Judge polycount by how large an object will actually appear to the viewer, not by habit. A practical technique: place a camera in your DCC tool at average eye height (~1.5m) at the center of the scene, then rotate it around to see what the viewer will actually see before committing to a polygon budget for each asset.

## Common mistakes

1. **Quoting the total-scene budget as if it were the per-frame budget.** 500k/250k are ceilings for the whole scene; design toward the ~100k visible-at-once target for real headroom.
2. **Shipping one giant terrain/environment mesh.** Without chunking, RealityKit has nothing to cull — the entire mesh renders even when most of it is behind the viewer.
3. **Setting a budget before testing on device.** Thermal state, scene complexity, and viewing context all move the real ceiling; validate on hardware early rather than late (see `level-of-detail-and-thermal.md` for reacting to thermal pressure once you're there).
4. **Ignoring immersion level when reusing assets across contexts.** An asset built for a shared-space app may need a lower LOD or smaller footprint if reused in a fully immersive scene, since the fully immersive budget carries much more total load elsewhere in the frame.
