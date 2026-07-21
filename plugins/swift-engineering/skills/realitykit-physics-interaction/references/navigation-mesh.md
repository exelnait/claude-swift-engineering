# Navigation Mesh & Pathfinding

> These are 2026-era RealityKit APIs, newer than this guidance's training data. Confirm exact type names, initializers, and availability against current Apple documentation.

RealityKit can move a character across a level autonomously — avoiding obstacles, preferring easy ground over rough terrain, and crossing gaps it can't literally walk across — using a **navigation mesh**: a description of which parts of a scene are walkable, and how.

## NavigationMeshResource: the walkable world

A `NavigationMeshResource` holds the geometric data for the walkable surface: **labeled areas**, **custom flags** on those areas, and the **connections** between them. Build one with the Swift API, or author it visually as a Navigation Mesh component in **Reality Composer Pro** (see `reality-composer-pro`) — the same resource either way.

Authoring it in Reality Composer Pro breaks into three pieces worth knowing even if you only consume the result in code:

- **Shapes** — a bounding box that determines which scene geometry is included when the mesh is generated. Geometry outside the box is silently excluded from the walkable area.
- **Generation Parameters** — controls for how the scene geometry is sampled into a mesh, e.g. **cell size** (the voxel size used during sampling): smaller values capture finer detail at a higher generation cost, larger values produce a coarser, cheaper approximation.
- **Off-Mesh Connections** — explicit links between regions the mesh can't naturally connect (see below), each with a start and end point you position with a viewport gizmo.

## Off-mesh connections: bridges, ladders, jumps

Sometimes the walkable surface is genuinely disconnected — a rift splits the level, or a rooftop is only reachable by ladder. An **off-mesh connection** links two such regions explicitly (a bridge, a ladder, a jump) so a computed path can cross the gap even though there's no continuous walkable geometry between them. When you consume a path in code, an off-mesh connection is a distinct kind of node from a normal on-mesh position — see "Computing and consuming a path" below.

## NavigationComponent: filtering and traversal cost

A `NavigationComponent` wraps a `NavigationMeshResource` for a specific character. It carries a **filter** that defines:

- the **cost** of traversing each labeled area, and
- which areas to **include or exclude** based on their flags.

Traversal cost is what lets a character *prefer* easy ground without making rough terrain impassable — label a forest with a higher cost than open ground, and a computed path avoids it when a cheaper route exists, but will still route through it rather than fail if that's the only way across.

## Computing and consuming a path

A `NavigationController` computes paths for an entity that carries a `NavigationComponent`, either synchronously or with `async`:

```swift
let controller = NavigationController(entity: character)            // confirm exact initializer
guard let path = try await controller.computePath(to: destination) else {
    return   // no valid path exists
}
guard !path.isEmpty else {
    return   // already at the destination
}

for node in path {
    if node.isOnMesh {                       // confirm exact API
        waypoints.append(node.position)
    } else {
        handleOffMeshConnection(node)        // climb the ladder, cross the bridge, etc.
    }
}
```

`computePath` returns an **optional array of path nodes**: `nil` means no path could be found at all; an **empty array** means the entity has already arrived. Both are valid "stop" conditions but mean different things — don't collapse them into identical handling. Iterate the remaining nodes and branch on whether each is a normal on-mesh position (walk to it) or an off-mesh connection (a distinct traversal — climbing, crossing — that your game logic drives separately).

Once set up, a `NavigationComponent` can be driven from a Reality Composer Pro **Behavior Tree** or **Animation Graph**, or from your own custom Swift system — all three consume the same navigation component and controller.

## Common mistakes

1. **Treating `nil` and an empty path array the same.** They mean different things — no path exists vs. already arrived — and usually call for different follow-up logic.
2. **Walking every path node the same way.** Off-mesh connection nodes need distinct handling (ladder climb, bridge crossing) from ordinary on-mesh waypoints; branch on the node kind while iterating.
3. **Excluding costly terrain instead of pricing it.** Flags are for hard include/exclude; if an area should merely be *avoided when possible* (a forest, shallow water), give it a higher traversal cost rather than excluding it outright.
4. **Drawing too tight a bounding box in the Shapes section.** Scene geometry outside the box is silently left out of the generated mesh — a character can't path onto ground the mesh was never generated for.
5. **Over- or under-sizing cell size for the scene.** Very fine sampling on a large level is slow to generate; very coarse sampling loses the detail needed to navigate tight spaces. Tune it to the scene's scale.
6. **Forgetting an off-mesh connection across a genuine gap.** Without one, `computePath` correctly returns no path — the mesh has no way to know a bridge or ladder exists unless you author the connection.
