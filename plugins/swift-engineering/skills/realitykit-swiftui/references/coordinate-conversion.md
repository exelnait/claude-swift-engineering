# Unified Coordinate Conversion

> CoordinateSpace3D and its SwiftUI/RealityKit conformances ship in the 2025 (visionOS 26) release and are newer than this guidance's training data. Confirm exact type names and APIs against current Apple documentation.

SwiftUI and RealityKit used to speak different coordinate languages — SwiftUI in points, RealityKit in meters, each with its own hierarchy and axis conventions. Getting a distance or relative position across the two meant hand-rolling the conversion. The Spatial framework's **`CoordinateSpace3D`** protocol removes that: it's an abstract 3D coordinate space that both frameworks now conform to, so you convert directly between them.

## Who conforms

- RealityKit's **`Entity`** and **`Scene`** types conform to `CoordinateSpace3D` directly.
- SwiftUI's **`GeometryProxy3D`** gets a new **`.coordinateSpace3D()`** function that returns its coordinate space.
- Several SwiftUI `Gesture` types can report their values relative to any `CoordinateSpace3D` you supply, not just the default view-local space. (confirm exact gesture APIs/modifier names)

Converting a value from one conforming space to another actually routes through a space shared by both frameworks — first into the shared space, then out into the destination — while handling the low-level details for you: **points-to-meters** scaling and **axis-direction** differences between SwiftUI and RealityKit.

## onGeometryChange3D

```swift
Model3D(named: "Sparky")
    .onGeometryChange3D { geometry in                                     // confirm exact API/signature
        let sparkySpace = geometry.coordinateSpace3D()
        let sparkyOrigin = sparkySpace.convert(.zero, to: boltsEntity)     // confirm exact convert API
        let distance = length(sparkyOrigin - boltsEntity.position)
        sparkIntensity = intensity(for: distance)
    }
```

Called whenever the view's geometry changes. It hands you a `GeometryProxy3D`; call `.coordinateSpace3D()` on it, then convert a point from that space into any other `CoordinateSpace3D` — including a RealityKit entity living in a completely separate `RealityView`, or even a different window. This is exactly how to answer "how close is this `Model3D` view to that RealityKit entity," e.g. driving a particle effect's intensity from the live distance between a SwiftUI-hosted object and a RealityKit-hosted one.

## Common mistakes

1. **Hand-computing points↔meters conversion or flipping axes yourself.** `CoordinateSpace3D` conversion already accounts for both — let it do the arithmetic instead of re-deriving scale factors.
2. **Assuming conversion only works within one framework.** The entire point is that `Entity`/`Scene` (RealityKit) and `GeometryProxy3D` (SwiftUI) conform to the same protocol — convert directly between a SwiftUI view's space and a RealityKit entity's space, no intermediate framework needed.
3. **Recomputing geometry from scratch every frame instead of using `onGeometryChange3D`.** Let SwiftUI tell you when the geometry actually changed rather than polling it.
4. **Forgetting you still need live references to both spaces.** The protocol removes the manual math, not the requirement to actually hold both the SwiftUI geometry and the RealityKit entity/scene you're converting between.
