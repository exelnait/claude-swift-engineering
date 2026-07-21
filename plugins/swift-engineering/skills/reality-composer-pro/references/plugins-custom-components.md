# Extending the Editor: Plugins, Custom Components & Systems

> This extensibility mechanism ships later in the 2025–2026 cycle. Confirm exact protocol/type names, attributes, and signatures against current Apple documentation — several are marked below.

Script Graph and a Swift plugin can often do the same job, and which you reach for is frequently a matter of preference — but very large Script Graphs get hard to maintain, and code can call APIs Script Graph can't (SwiftUI, project-specific systems). When a team wants artists and designers to tune project-specific data live in the editor, or a behavior needs to tie into other systems in code, build a **plugin**: an Xcode target that registers custom components, systems, animation actions, and Script Graph nodes with Reality Composer Pro.

## Project shape and team workflow

A typical project has both a Reality Composer Pro project (artists/designers) and an Xcode project (engineers), linked together — set up from the **Run with Xcode** option in the simulation toolbar — and living in the **same git repository**. Everything you import or author in Reality Composer Pro is saved to disk as **JSON**; a **custom merge tool** ships with the editor and resolves conflicts in that JSON with fewer conflicts than a plain `git merge`. Content reaches the app as an exported **Reality File** (RealityKit's serialization format), linked into the build.

The Xcode project typically carries (at least) two schemes sharing the same custom component/system code: one that builds the real app, and one — e.g. an **`RCPCustomComponents`** framework — that builds the **plugin** the editor loads. Rebuild the app when code changes; export a new Reality File when content changes.

## The plugin protocol

Implement **`RealityComposerProPlugin`**, a protocol from the `RealityComposerPro` Swift package (added to your Xcode project automatically once you link it via Run with Xcode):

```swift
import RealityComposerPro

final class GamePlugin: RealityComposerProPlugin {
    // confirm exact context type name and registration method signatures
    func setup(context: RealityComposerProContext) {
        context.register(component: CauldronComponent.self)
        context.register(system: CauldronSystem.self)
    }
}

@_cdecl("createRealityComposerProPlugin")   // confirm exact attribute/export mechanism
public func createRealityComposerProPlugin() -> UnsafeMutableRawPointer {
    Unmanaged.passRetained(GamePlugin()).toOpaque()
}
```

`setup` receives a **context** from the editor; register your components and systems on it so the editor knows about them. `createRealityComposerProPlugin` must be exported as a C symbol (with an explicit exported name) so the editor's plugin loader can find it in the built dynamic library — it returns your plugin as a raw pointer.

Build the plugin scheme to produce that library, then open the project in the editor. Reality Composer Pro shows a **"trust this plugin"** dialog before loading it (with a "don't ask again" option). Imported components/systems then show up in a **Custom Components** folder and in the project's build settings, which also let you point at a custom plugin directory.

## Custom Component

A plain `Component`, made `Codable` so the editor can represent, edit, and serialize it into a Reality File:

```swift
struct CauldronComponent: Component, Codable {
    var waterLevel: Float = 0
}
```

If a component has runtime-only properties that shouldn't be editable or saved, add `CodingKeys` that omit them; a fully-authorable component like the one above needs no explicit `CodingKeys` at all.

## Custom System — runs *inside* the editor

A system queries entities with your component and updates them each frame, exactly like any RealityKit system (see `realitykit-core`). The key difference here: once registered with the plugin context, **your system runs inside the editor process itself**, not just in the shipped app. Change a property in the Inspector and watch your system react live in the viewport — no build-and-relaunch cycle — which is what lets artists tune project-specific behavior (a cauldron's water level, tied to other systems like floating ingredients) without touching code. Because it's real Swift running in the editor, you can set a breakpoint and **attach the Xcode debugger to the running editor application** to step through it directly.

A custom system can reach into other authored content too — e.g. reading a Shader Graph material's parameters, computing new values from your component's properties (a vortex shape from a rotation-speed property), setting them back on the material, and reassigning it to the model (see `shader-graph.md`).

Whenever plugin code changes: rebuild the plugin scheme and **restart the editor**. It reloads the dynamic library, re-shows the trust dialog (unless dismissed), and — if your component's shape changed — a summary of what changed before applying it.

## Custom EntityAction — sequencer timeline animations

Implement `EntityAction`, made `Codable` so it can be saved into a Reality File. An action typically carries the parameters it animates between (e.g. a start and end `waterLevel`) and declares the value type the protocol needs to reach the target entity in the animation executor (e.g. `Transform`) (`// confirm exact associated-type/requirement names`).

Execution is wired up via a static `subscribe()` you call from your plugin's `setup`: inside it, subscribe to `EntityAction`'s `.updated` event (fired whenever RealityKit runs animations), read the elapsed time as a normalized `0...1` value, interpolate your start/end values, and write the result back onto your component — read, mutate, `components.set(_:)`, the same write-back rule as any RealityKit component (see `realitykit-core`'s `ecs-fundamentals.md`). Register the action with the plugin context **and** call `subscribe()`, or it will show up in the editor but never actually execute.

Once registered, the action appears in the animation sequencer: create a Sequence, set its root entity, add an animation track targeting your entity, drag your custom action onto the track's timeline, and set its parameters (e.g. start/end water level) in the Inspector. `realitykit-core`'s `systems-and-actions.md` covers built-in actions like `PlayAudioAction` — a custom `EntityAction` slots into the exact same animation/playback machinery.

## Custom Script Graph nodes via `@Scriptable`

The fastest way to expose a custom component to Script Graph authors is the **`@Scriptable`** macro, from the `RealityKitScripting` / `RealityKitScriptingMacros` modules (added automatically alongside the `RealityComposerPro` package). Tag the component:

```swift
import RealityKitScripting
import RealityKitScriptingMacros

@Scriptable
struct CauldronComponent: Component, Codable {
    var waterLevel: Float = 0
}
```

The macro expands to a schema describing the component for the scripting system. Register it in `setup`, **on the main thread**: build a scripting configuration whose initializer lists your scripting module(s) — each wrapping the `@Scriptable`-generated schema — and add that configuration to `RealityKitScripting`. `// confirm exact configuration/module type names`

Once rebuilt, add a **Scripting Component** to an entity carrying your custom component and open its Script Graph — your component's data is available to nodes exactly like a built-in one (an Update node → an If node gated on a keypress → a Set node writing your property; see `script-graph.md`).

## Common mistakes

1. **Forgetting `Codable` (or the right `CodingKeys`) on a custom `Component`.** Without it, the editor can't represent or serialize the component, and it won't survive export to a Reality File.
2. **Registering the type but skipping its supporting call.** An `EntityAction` needs both a context registration *and* its `subscribe()` call; a `@Scriptable` component needs both the macro *and* a scripting-module registration on the main thread. Half-registering leaves the feature silently inert.
3. **Expecting hot reload.** The editor loads a built dynamic library, not your live source — rebuild the plugin scheme and restart the editor after every code change; expect the trust dialog again.
4. **Leaving runtime-only fields fully `Codable` with no `CodingKeys`.** They leak into the editor as editable, saved properties even though they're meant to be computed/transient.
5. **Debugging a custom system only via a full app build.** It runs inside the editor process too — attach Xcode's debugger to the running editor and breakpoint it directly, which is faster than a build-deploy-repro loop.
6. **Resorting straight to a plain-text git merge on RCP's JSON when conflicts get hairy.** Reach for the editor's own custom merge tool first; it understands the format and produces fewer conflicts than treating it as generic text.
7. **Choosing Script Graph vs. a plugin by habit instead of fit.** Reach for a plugin once a Script Graph is unwieldy, needs an API Script Graph can't call, or needs real code review/testing; otherwise Script Graph's no-build iteration loop is usually faster (see `script-graph.md`).
