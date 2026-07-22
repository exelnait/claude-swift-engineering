# Cloth Simulation

> This is a 2026-era RealityKit capability, newer than this guidance's training data. Confirm exact type names, initializers, and availability against current Apple documentation.

RealityKit's cloth simulation treats fabric as a mesh where **vertices are particles and edges are springs** — pull it, drop it, or brush against it, and the mesh deforms as those particles and springs settle, producing realistic creasing, folding, and drape in real time (curtains, a flowing dress, bed covers being pulled back).

## The three components

Three components work together, mirroring the physics-body/collision split elsewhere in RealityKit:

- **`ClothBodyComponent`** — represents the cloth itself. References a **material** (spring stiffness, friction, and other cloth-specific properties) and a **cloth mesh resource** describing the particle/spring layout (`// confirm exact resource type name`).
- **`ClothColliderComponent`** — represents a **rigid object** the cloth can collide with (a bed frame, a mannequin). Like the cloth body, it references its own material properties plus the collider's geometry.
- **`ClothSimulationComponent`** — actually **runs** the simulation. It holds an array of materials referenced by the cloth bodies and colliders involved, plus simulation-wide properties that apply to every descendant entity in the simulation: which **solver** to use, the **gravity** to apply, and the simulation's **time step**.

```swift
cloth.components.set(ClothBodyComponent(material: clothMaterial, mesh: clothMeshResource))          // confirm exact API
bedFrame.components.set(ClothColliderComponent(material: colliderMaterial, shape: colliderShape))    // confirm exact API
simulationRoot.components.set(ClothSimulationComponent(materials: [clothMaterial, colliderMaterial]))
```

Cloth-body materials and cloth-collider materials are **different property sets** — stiffness and friction mean something different for a piece of fabric than for the rigid object it rubs against — so don't reuse one where the other is expected.

## Pinning: making part of the cloth immovable

Curtains need to hang from something; a dress needs a collar that doesn't flop. RealityKit's answer is the same trick used elsewhere in physics: set the relevant **vertices to kinematic**. A kinematic vertex is moved only by an entity's transform, never by the cloth simulation itself — effectively pinning it in place while the rest of the cloth continues to simulate normally.

The pattern, as used to hang curtains from hoops in Apple's Chaparral Village demo: for each pin point, take the pin entity's position, build a small sphere around it, gather every cloth vertex that falls inside that sphere, and set those vertices' mode to kinematic:

```swift
for (pin, pinEntity) in pins {
    let pinSphere = BoundingSphere(center: pinEntity.position, radius: pin.radius)   // confirm exact API
    let affectedVertices = clothMesh.vertices(in: pinSphere)                        // confirm exact API
    clothBody.setVertices(affectedVertices, mode: .kinematic)                        // confirm exact API
}
```

Because pinned vertices still belong to the same mesh, they stay correctly connected — via springs — to the rest of the simulated cloth; only their own position stops being driven by the solver.

## Getting believable results

The simulation is only as good as the input mesh: **enough vertices** are needed for creases and folds to read as real cloth rather than a stiff, faceted surface. A coarse mesh (too few particles/springs) will still simulate — RealityKit won't error — but it will look wrong no matter how the material properties are tuned.

## Common mistakes

1. **Too few vertices in the cloth mesh.** Folding and draping need enough particles/springs to resolve; a coarse mesh looks faceted and unrealistic regardless of material settings.
2. **Adding `ClothBodyComponent`/`ClothColliderComponent` but no `ClothSimulationComponent`.** Nothing simulates until a `ClothSimulationComponent` is present and references the materials in play — the body/collider components alone are inert data.
3. **Swapping cloth-material and collider-material properties.** The two material kinds have different property sets (e.g. spring stiffness belongs to cloth materials); using one where the other is expected won't produce the intended behavior.
4. **Re-positioning pin vertices every frame instead of setting them kinematic.** Fighting the solver by writing positions manually each frame is unnecessary and fragile — kinematic mode is the supported way to anchor part of a cloth.
5. **Forgetting collider geometry/material for objects the cloth should drape over.** A bed or mannequin needs its own `ClothColliderComponent` (geometry + material) or the cloth simply passes through it.
6. **Blaming material settings for jitter that's actually a simulation-wide problem.** Instability often traces back to `ClothSimulationComponent`'s solver/time-step/gravity settings, which affect every entity in the simulation, not just one troublesome material.
