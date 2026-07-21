# Systems & Actions: Driving Behavior Over Time

> Some APIs here ship in 2025–2026 releases. Confirm exact names against current Apple documentation.

There are three ways to make things happen over time in RealityKit: **Systems** (per-frame logic you write), **animations** (authored clips and property animations), and **entity actions** (small pre-built behaviors). Reach for the lightest one that fits.

## Systems: per-frame logic

A `System`'s `update` runs every frame. Query the entities you care about and mutate them:

```swift
struct SpinSystem: System {
    static let query = EntityQuery(where: .has(SpinComponent.self))
    init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let spin = entity.components[SpinComponent.self] else { continue }
            entity.orientation *= simd_quatf(angle: spin.rate * dt, axis: [0, 1, 0])
        }
    }
}
SpinSystem.registerSystem()      // once at launch; confirm exact API
```

Use `context.deltaTime` to stay frame-rate independent. A system's `update` is **outside** the SwiftUI view-body observation scope, so it's a safe place to mutate observed entities (see `realitykit-swiftui`).

## Animations from an AnimationLibraryComponent

When a USD ships with animations (e.g. walk, jump, spin authored in a DCC and appended with the USD tooling), RealityKit exposes them on the loaded entity via an **`AnimationLibraryComponent`**. Playing one is concise:

```swift
guard let character = scene.findEntity(named: "Max"),
      let library = character.components[AnimationLibraryComponent.self],
      let spin = library.animations["spin"] else { return }

character.playAnimation(spin)              // confirm exact playback API
```

This replaces the old multi-step SceneKit dance (find node → load separate animation → traverse → attach a player). Reference clips by the names set in Reality Composer Pro.

`playAnimation` returns an `AnimationPlaybackController` you can pause, resume, seek, and (in 2025+) observe — it's `Observable`, so a SwiftUI view can bind to its `time`/`isPlaying` for scrubbers and controls (see `realitykit-swiftui`).

## Entity actions

Entity **actions** are small, composable behaviors that minimize code for one-off events — great for "on jump, play this sound", "move to here", "fade out". A built-in example is `PlayAudioAction`, which finds the named clip on the target's `AudioLibraryComponent` for you:

```swift
let action = PlayAudioAction(audioResourceName: "ambience")   // confirm exact API
let animation = try AnimationResource.makeActionAnimation(for: action)  // confirm exact API
terrain.playAnimation(animation)
```

Actions are run *as animations* (you convert the action into an `AnimationResource` and play it), which lets them slot into the same playback and sequencing machinery. Reality Composer Pro can author custom `EntityAction`s onto a timeline too (see `reality-composer-pro`).

## Choosing among them

| Need | Use |
|------|-----|
| Recurring logic over many entities each frame | **System** + `EntityQuery` |
| Play an authored clip (walk/idle/celebrate) | **AnimationLibraryComponent** + `playAnimation` |
| One-shot behavior tied to an event (sound, move, fade) | **Entity action** |
| Blend/transition between animation states, autonomous routines | Reality Composer Pro **Animation Graph** / **Behavior Tree** (see `reality-composer-pro`) |

## Common mistakes

1. **Timers instead of systems.** Ad-hoc `Timer`/`Task` loops that poke entities fight the engine and drift from the render loop. Put recurring behavior in a `System`.
2. **Ignoring `deltaTime`.** Frame-rate-dependent motion (rotate by a fixed amount per frame) runs at different speeds on 60/90/120 Hz displays. Multiply by `context.deltaTime`.
3. **Re-finding entities every update.** Resolve `findEntity(named:)` once; store the reference (or better, drive from a component + query).
4. **Hand-coding state machines for character animation.** Blending idle↔walk with conditions is what the Animation Graph is for — author it in Reality Composer Pro instead of threading booleans through code.
