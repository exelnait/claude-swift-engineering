# RealityView: Hosting a Scene in SwiftUI

> Some APIs here ship in 2025–2026 releases. Confirm exact names against current Apple documentation.

`RealityView` is the SwiftUI view that hosts and renders a RealityKit scene. It replaces SceneKit's `SCNView`/`ARSCNView`. One view renders fully virtual scenes *and* places content in the real world, and it deploys across every RealityKit platform — performing stereoscopic rendering on visionOS automatically, with no code changes.

## The closures

```swift
import SwiftUI
import RealityKit

struct GameView: View {
    var body: some View {
        RealityView { content in
            // make: runs ONCE when the view first appears. Build the scene here.
            let scene = try? await Entity(named: "AlchemyArea", in: realityKitContentBundle)
            if let scene { content.add(scene) }
        } update: { content in
            // update: runs when observed SwiftUI state changes. Sync SwiftUI → scene here.
            // Optional — omit it entirely if you drive the scene from systems/gestures.
        }
    }
}
```

- **`make`** — asynchronous, runs **once** on first appearance. Load and assemble the scene. Reading an observable value here does **not** create a SwiftUI dependency, and `make` is never re-run.
- **`update`** — runs whenever state the surrounding view body depends on changes. Treat it as an extension of the view's `body`. Keep it cheap and idempotent.
- **`attachments`** — a view builder for SwiftUI views you want to place in 3D space (older pattern). In visionOS 26+, prefer `ViewAttachmentComponent` to attach SwiftUI from anywhere (see `realitykit-swiftui`).

`content` is a `RealityViewContent`: `add(_:)` / `remove(_:)` entities, and `subscribe(to:)` for RealityKit events.

## Sizing: `realityViewLayoutBehavior`

By default a `RealityView` takes **all** the space SwiftUI offers it, and its scene origin sits at the view's center. Control this with the modifier:

```swift
RealityView { content in … }
    .realityViewLayoutBehavior(.fixedSize)   // wrap the content's initial bounds (like Model3D)
```

- `.flexible` — behaves as if unset; origin stays at the view's center.
- `.centered` — moves the origin so contents are centered in the view.
- `.fixedSize` — tightly wraps the content's visual bounds; makes `RealityView` size like a `Model3D`.

Sizing is evaluated **once**, right after `make`. None of these options move or scale your entities — they only reposition the `RealityView`'s own origin. (See `realitykit-swiftui` for choosing `Model3D` vs `RealityView`.)

## Reacting to events with `subscribe`

```swift
RealityView { content in
    content.add(scene)
    _ = content.subscribe(to: CollisionEvents.Began.self) { event in
        // event.entityA / event.entityB
    }
}
```

Keep the returned subscription token alive (store it) or the subscription is torn down. Common event types: `CollisionEvents`, `AnimationEvents`, `ManipulationEvents`, `SceneEvents.Update`, and anchor state events.

## Camera controls

For non-AR viewing, add a camera control so users can orbit/inspect:

```swift
RealityView { content in … }
    .realityViewCameraControls(.orbit)       // confirm exact modifier/case names
```

On visionOS in an immersive space, the person moves through the scene physically; on iOS/macOS/tvOS you typically drive an interactive camera or animate one.

## Avoiding the infinite update loop

`update` is tied to the view body's observation scope. If you both *read* an observable entity property in the body **and** *write* that same property inside `update`, you create a cycle: write → body invalidates → `update` runs → write → … Rules:

- Don't modify observed state inside `update`.
- Modifying entities you are **not** observing is safe.
- If you must write an observed property, read the current value first and skip writing an unchanged value.
- Systems' `update` and gesture closures run **outside** the view-body scope, so they're safe places to mutate observed entities.

Details and the full two-way data-flow story are in the `realitykit-swiftui` skill (`observation-and-data-flow.md`).

## Common mistakes

1. **Putting scene construction in `update`.** Build once in `make`. `update` runs repeatedly; recreating entities there thrashes the scene.
2. **Letting the RealityView eat the whole layout.** If a name sign or sibling view gets shoved aside, apply `.realityViewLayoutBehavior(.fixedSize)`.
3. **Dropping the subscription token.** `subscribe(to:)` returns a token you must retain, or events stop arriving.
4. **Creating an update ↔ observation loop.** See above — never write observed state in `update`.
