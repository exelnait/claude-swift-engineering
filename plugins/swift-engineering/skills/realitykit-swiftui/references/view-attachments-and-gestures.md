# View Attachments, Gestures & Presentations

> These components ship in the 2025 (visionOS 26) release and are newer than this guidance's training data. Confirm exact type names, initializers, and availability against current Apple documentation.

Before visionOS 26, putting SwiftUI content into a 3D scene meant declaring an `attachments` view builder up front in `RealityView`'s initializer, then waiting for the `update` closure to hand you back the corresponding entities to position. That pattern still works, but three new components turn it inside out: you can now attach a view, a gesture, or a modal presentation **directly to an entity, from anywhere** — no pre-declared attachment closure required.

## ViewAttachmentComponent

```swift
let nameSign = ViewAttachmentComponent(rootView: NameSignView(name: "Sparky"))   // confirm exact API
sparkyEntity.components.set(nameSign)
```

Give it any SwiftUI `View`, set it on an entity's `components` collection, and it renders in 3D space right there — positioned like any other entity content (make it a child entity, offset it in front of the robot's head, whatever the scene calls for). This directly replaces the old flow of declaring the view in `RealityView`'s `attachments:` builder and waiting for `update` to hand you an entity for it: build the component wherever your code already is, no round trip through the view builder.

## GestureComponent

```swift
let tapToToggle = GestureComponent(TapGesture().onEnded { toggleNameSign() })   // confirm exact API
sparkyEntity.components.set(tapToToggle)
```

Same idea, for gestures: hand it an ordinary SwiftUI gesture (`TapGesture`, `DragGesture`, …) and set it on the entity directly, instead of attaching `.gesture(_:targetedToEntity:)` to the surrounding `RealityView`. Gesture values are reported, **by default, in the entity's own coordinate space** — usually exactly what you want ("how far did this move relative to me"), not the window's. (For composing multiple gestures together — simultaneous, sequenced, exclusive — the mechanics are the same as any SwiftUI gesture; see `swiftui-advanced`.)

> **Pro tip:** any entity that's the target of a gesture — through `GestureComponent` *or* the older `.targetedToEntity` gesture modifiers — also needs an `InputTargetComponent` and a `CollisionComponent`, or it will never receive the gesture. This is the single most common reason a gesture silently does nothing.

## PresentationComponent

```swift
let outfitPicker = PresentationComponent(isPresented: $showOutfitPicker, configuration: .popover) {  // confirm exact API
    OutfitPickerView(catalog: catalog)
}
boltsEntity.components.set(outfitPicker)
```

Presents a SwiftUI modal — a popover, in this shape — anchored to an entity, directly from RealityKit. It takes a `Bool` binding that both controls presentation and gets updated when the person dismisses it, plus a `configuration` describing the presentation style (`.popover`, and likely others — confirm exact cases). The content closure is an ordinary SwiftUI view; it's common to show `ConfigurationCatalog` options here so someone can change an entity's look live from a popover that lives conceptually on the entity, not on some ancestor view.

## Putting all three together

A robot entity can simultaneously carry a name sign (`ViewAttachmentComponent`), respond to a tap that toggles it (`GestureComponent`), and offer an outfit-picker popover (`PresentationComponent`) — three independent components, no shared closure, addable and removable at runtime like any other component.

## Common mistakes

1. **Forgetting `InputTargetComponent` + `CollisionComponent` on a `GestureComponent` target.** Without both, the gesture never fires — this applies equally to `.targetedToEntity`.
2. **Reaching for the old `attachments` closure out of habit.** In visionOS 26+, `ViewAttachmentComponent` is simpler and works from anywhere in your code; you don't need to pre-declare every attachment in `RealityView`'s initializer.
3. **Treating gesture values as window/screen-relative.** `GestureComponent` reports values in the entity's coordinate space by default — porting screen-space gesture math over unchanged will be wrong.
4. **Hand-rolling a `.popover` on a parent SwiftUI view for content that's really about one entity.** `PresentationComponent` keeps that presentation colocated with the entity it's about, instead of threading state up through ancestor views.
