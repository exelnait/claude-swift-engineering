# Model3D vs RealityView

> Some APIs here ship in the 2025 (visionOS 26) release and are newer than this guidance's training data. Confirm exact type names, initializers, and availability against current Apple documentation.

Think of `Model3D` as **the Image view for 3D**: point it at a self-contained asset and it renders, resizes, and participates in SwiftUI layout — no entity, no `RealityView`, no scene to manage. `RealityView` is the general-purpose engine view: real entities, components, and systems, with more control and more responsibility. Most 3D content should start as a `Model3D`; move to `RealityView` only when you outgrow it.

## When to use which

Use **`Model3D`** to display a self-contained 3D asset on its own — a product preview, a character portrait, anything where the model *is* the view.

Use **`RealityView`** when you're building a game or interactive experience, need fine-grained control over entities, or need a component `Model3D` doesn't expose. The hard line: **`Model3D` does not support adding components at runtime.** The moment you need one — a `ParticleEmitterComponent` for a spark effect is the canonical example (see `realitykit-rendering` for configuring the emitter itself) — that's your signal to switch.

Two additions in visionOS 26 push a lot of former `RealityView`-only use cases back into `Model3D`'s reach: animation playback and configuration switching.

## Animating with Model3DAsset

`Model3DAsset` loads a 3D asset's animations and lets you pick which one plays, without leaving `Model3D`:

```swift
struct RobotView: View {
    @State private var asset: Model3DAsset?

    var body: some View {
        VStack {
            if let asset {
                Model3D(asset: asset)                          // confirm exact initializer
                Picker("Animation", selection: Binding(
                    get: { asset.selectedAnimation },           // confirm exact property
                    set: { asset.selectedAnimation = $0 }
                )) {
                    ForEach(asset.availableAnimations, id: \.self) { anim in   // confirm exact API
                        Text(anim.name).tag(anim)
                    }
                }
                if let controller = asset.animationPlaybackController {       // confirm exact property
                    RobotAnimationControls(controller: controller)
                }
            }
        }
        .task {
            asset = try? await Model3DAsset(named: "Sparky", in: .main)       // confirm exact initializer
        }
    }
}
```

Setting `selectedAnimation` to a new value tells the asset to create an `AnimationPlaybackController` for that animation, vended back through `animationPlaybackController`. In visionOS 26, the existing RealityKit `AnimationPlaybackController` class is now **`Observable`** — hold it as a view's data model with `@Bindable` and read `.time`/`.isPlaying` directly, no manual notification plumbing:

```swift
struct RobotAnimationControls: View {
    @Bindable var controller: AnimationPlaybackController   // now Observable — confirm exact API

    var body: some View {
        Slider(value: .init(get: { controller.time }, set: { controller.time = $0 }),
               in: 0...controller.duration)                   // confirm exact scrub/duration API
        Button(controller.isPlaying ? "Pause" : "Play") {
            controller.isPlaying ? controller.pause() : controller.resume()
        }
    }
}
```

Because the controller is Observable, a change to `isPlaying` alone re-evaluates this view — you didn't have to wire that up by hand.

## Switching looks with ConfigurationCatalog

`ConfigurationCatalog` stores alternative representations of an entity — different mesh geometries, component values, or material properties, authored once (often visually in `reality-composer-pro` — e.g. an artist bundles several body types or outfits into one reality file). Initialize a `Model3D` with a catalog to switch live between its representations:

```swift
let catalog = try await ConfigurationCatalog(named: "SparkyOutfits", in: .main)  // confirm exact initializer
Model3D(configuration: catalog)                                                  // confirm exact initializer

// Presenting a picker/popover over the catalog's configuration options
// and setting the chosen one changes the model's look immediately.
```

## Transitioning smoothly to RealityView

When you do need to switch, load the same asset inside `RealityView`'s `make` closure and `add` it to `content` — but expect a layout surprise. By default, `RealityView` consumes **all** the space SwiftUI offers it, with the scene origin at the view's center; `Model3D`, by contrast, sizes itself to the model's intrinsic bounds. A sign or label that was laid out around a tightly-sized `Model3D` gets shoved aside the instant you swap in a bare `RealityView`.

Fix it with **`realityViewLayoutBehavior`**:

```swift
RealityView { content in
    let sparky = try await Entity(named: "Sparky", in: realityKitContentBundle)
    content.add(sparky)
}
.realityViewLayoutBehavior(.fixedSize)   // wrap the content's bounds, just like Model3D did
```

- **`.flexible`** — behaves as if unset; origin stays at the view's center.
- **`.centered`** — moves the origin so the contents are centered in the view.
- **`.fixedSize`** — tightly wraps the content's visual bounds, making `RealityView` size (and origin-place) like `Model3D`.

Sizing is evaluated **once**, immediately after `make` runs — not continuously. And critically: **none of these options move or scale your entities.** They only reposition the `RealityView`'s own origin point relative to its contents. If you need the entities themselves recentered, that's a transform change you make yourself.

## Common mistakes

1. **Trying to add a component to `Model3D`.** It isn't supported — that limitation is the actual decision boundary between `Model3D` and `RealityView`, not a workaround waiting to be found.
2. **Skipping `realityViewLayoutBehavior` after the switch.** The shift from intrinsic sizing to "fill all available space" is easy to miss until a sibling view visibly jumps.
3. **Expecting layout behavior to recenter or rescale entities.** It repositions the view's origin only — actual entity transforms are untouched.
4. **Expecting layout behavior to react to later content changes.** It's computed once, right after `make`; adding entities in `update` afterward doesn't reevaluate sizing.
5. **Confusing "model" the data structure with "model" the 3D object.** RealityKit's `ModelComponent` (mesh + materials) and a SwiftUI app's data model share a name and nothing else — say which one you mean, especially in code you'll revisit later.
