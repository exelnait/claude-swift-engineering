# Scene Understanding & Environment Blending

> `SceneUnderstandingFlags` and `EnvironmentBlendingComponent` shipped in the 2025 RealityKit update and are newer than this guidance's training data. Confirm exact names and available cases against current Apple documentation.

Both capabilities in this reference are **visionOS-only** — they depend on the room mesh visionOS builds from its sensors, which has no equivalent on iOS's camera-passthrough style of AR. If you're deciding whether a feature belongs here or in `anchoring-and-arkit.md`, the test is: does it need a mesh of the *whole room*, or just a single detected surface/object? Anchoring is the latter and runs on iOS too; everything on this page is the former and is visionOS-only.

## The scene understanding mesh

Through the same `SpatialTrackingSession` used for anchoring (see `anchoring-and-arkit.md`), RealityKit can generate a mesh of your surroundings — walls, floor, furniture, whatever visionOS's sensors have reconstructed. This is the **scene understanding mesh**. On its own it's just geometry; you opt it into your simulation with flags on the session configuration.

## Colliding with the real room: SceneUnderstandingFlags

Set **`SceneUnderstandingFlags`** on the `SpatialTrackingSession.Configuration` before running (or re-running) the session:

```swift
var configuration = SpatialTrackingSession.Configuration(tracking: [.plane])
configuration.sceneUnderstandingFlags = [.collision, .physics]  // confirm exact property/case names
_ = await session.run(configuration)
```

visionOS currently supports two flags:

- **`.collision`** — the mesh participates in collision detection, so `CollisionEvents` fire when your entities touch real geometry.
- **`.physics`** — the mesh participates in the physics simulation itself, so objects with a `PhysicsBodyComponent` actually rest on, bounce off, and are blocked by real walls/floors/tables instead of passing through them.

With both flags set, a game object with ordinary `PhysicsBodyComponent` + `CollisionComponent` (see `realitykit-physics-interaction`) dropped in mid-air falls and lands on the real floor or table exactly like it would on virtual geometry — no special-casing required in your own physics code. The room mesh is, from the physics system's point of view, just another collidable body.

## Occlusion by real objects: EnvironmentBlendingComponent

`EnvironmentBlendingComponent` is the visual counterpart to scene-understanding collision: instead of *colliding* with the real world, entities with this component are *hidden by* it.

```swift
var blending = EnvironmentBlendingComponent()
blending.preferredBlendingMode = .occluded(by: .surroundings)  // confirm exact API
entity.components.set(blending)
```

Behavior to know before you rely on it:

- Occlusion is realistic and **partial-aware** — an entity half-covered by a real object is occluded exactly where it's covered, not all-or-nothing.
- Only **static** real-world objects occlude. A person or pet walking through the scene will not hide an entity with this component — the mesh scene understanding builds is of the static room, not of moving obstacles.
- Entities using this component are treated as part of the **background environment**. They are always drawn **behind** other virtual objects in your scene, regardless of actual depth — this is a deliberate rendering-order rule, not a bug, but it means you shouldn't rely on normal depth sorting between a blended entity and other virtual content.

## What else this mesh powers

The scene understanding mesh isn't only for physics and occlusion — it's also what RealityKit's **physical-space lighting** uses to let virtual lights (spotlights, point lights) spill realistically onto real walls and floors (a `SurroundingsLight` component on the light entity). That feature lives in `realitykit-rendering`; the mesh itself is configured exactly as described above.

## Common mistakes

1. **Enabling `.collision` and expecting physical response, or `.physics` and expecting collision events.** They're independent flags covering independent behaviors — detecting a touch versus actually simulating one. Set both if you want objects to both report contact *and* believably bounce/rest against the room.
2. **Changing `sceneUnderstandingFlags` on a configuration without re-running the session.** The flags take effect when the (re-)run configuration is applied, not by mutating a struct that's already in flight.
3. **Expecting `EnvironmentBlendingComponent` to hide content behind a walking person.** It won't — only static geometry occludes. Don't build a game mechanic ("hide behind your friend") on top of this component; it's for furniture and walls, not people or pets.
4. **Being surprised an occluded entity still "wins" a depth sort against other virtual content.** Entities with `EnvironmentBlendingComponent` always draw behind other virtual objects by design — treat them as background, not as a normal member of your scene's depth ordering.
5. **Assuming this whole reference applies to iOS.** It doesn't — scene understanding mesh and environment blending are visionOS-only. On iOS, stick to plane/image anchoring from `anchoring-and-arkit.md` and ordinary `realitykit-physics-interaction` collision against virtual geometry.
