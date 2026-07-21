# Transforms & Coordinates

> Some APIs here ship in 2025–2026 releases. Confirm exact names against current Apple documentation.

## The coordinate system

RealityKit uses a **right-handed** system, in **meters**:

- **+X** points right
- **+Y** points up
- **−Z** points forward (away from the camera); **+Z** points toward the camera

This is identical to SceneKit's coordinate system, so spatial intuition carries over. Units are meters — a `0.2` box is 20 cm. (Content imported from tools using Z-up, like Blender, arrives rotated; fix it on import in Reality Composer Pro or Preview.)

## The Transform component

Placement is a `Transform` component. The common properties are sugar on top of it:

```swift
entity.position = [0, 1, -0.5]                                   // SIMD3<Float>, meters
entity.orientation = simd_quatf(angle: .pi/2, axis: [0, 1, 0])   // quaternion
entity.scale = [1, 1, 1]

// Or set the whole thing:
entity.transform = Transform(scale: [1,1,1],
                             rotation: simd_quatf(angle: 0, axis: [0,1,0]),
                             translation: [0, 0, -0.5])
```

`Transform` also exposes a `matrix` (a `float4x4`) when you need to compose transforms directly.

## Hierarchy: transforms compose

An entity's **final placement is its own transform composed with every ancestor's**. Position/orientation/scale are relative to the parent. This is powerful and the source of the most common "why is my object in the wrong place / squished" bug:

- Scaling a parent scales **all** descendants.
- Rotating a parent orbits all descendants around the parent's origin.
- A stray translation on an ancestor offsets the whole subtree.

**Fix pattern:** if an entity is distorted, its own `Transform` and mesh are often fine — an ancestor is the culprit. Either correct the ancestor, or **re-parent** the entity so it's a *sibling* of the transformed node rather than a child. Two entities can still look connected in the scene while no longer sharing a transform. (The `realitykit-debugging` skill walks exactly this hunt with the RealityKit debugger.)

```swift
// Move `ball` out from under a Y-scaled `support` so the scale stops squishing it.
support.parent?.addChild(ball)     // ball becomes a sibling of `support`
```

## World vs local space

- `entity.position` is **relative to the parent**.
- `entity.position(relativeTo: nil)` gives the **world** position; `position(relativeTo: other)` gives it in another entity's space.
- `entity.transformMatrix(relativeTo:)` returns the composed matrix in a chosen space. Use these when reasoning across the hierarchy.

```swift
let worldPos = entity.position(relativeTo: nil)
let posInOther = entity.position(relativeTo: otherEntity)
```

For converting between a RealityKit entity's space and a SwiftUI view's space (points ↔ meters, axis direction), use the unified `CoordinateSpace3D` conversion — see the `realitykit-swiftui` skill.

## Look-at and facing

To orient an entity toward a target:

```swift
entity.look(at: targetWorldPosition,
            from: entity.position(relativeTo: nil),
            relativeTo: nil)                 // confirm exact signature
```

Note RealityKit's `look(at:)` orients −Z toward the target (forward). Double-check the facing if content appears to point backward.

## Common mistakes

1. **Blaming the mesh for an inherited transform.** Preview the entity's own transform in isolation; if it's clean, walk up the hierarchy. The distortion is almost always an ancestor's scale/rotation.
2. **Confusing local and world position.** `entity.position` is parent-relative. Comparing two entities' `.position` values only makes sense if they share a parent — otherwise convert with `position(relativeTo:)`.
3. **Non-uniform scale on parents of physics/interaction entities.** Non-uniform ancestor scale distorts child geometry and can wreck collision shapes. Prefer uniform scale, and bake sizing into the asset when you can.
4. **Assuming Z-up.** RealityKit is Y-up, −Z-forward. Assets from Z-up DCC tools import rotated — correct on import, not with a scattering of runtime rotations.
