# The USDKit API

> Some APIs here ship in 2025–2026 releases. Confirm exact names against current Apple documentation.

USDKit is Apple's system framework for working with USD directly in Swift, with first-class integration into RealityKit and the Spatial Preview framework built in. It's designed to work for everyone: developers who already know USD will find the concepts immediately familiar, and Swift developers meeting USD for the first time get patterns they already know — initializers, throwing calls, value-ish accessors — rather than a foreign API surface.

> USDKit is new for 2026. The names below are grounded in Apple's own USDKit walkthrough; exact signatures (parameter labels, throws vs. async throws, return types) are called out as unconfirmed wherever the source didn't spell them out.

## Creating or opening a stage

```swift
import USDKit

// A fresh, empty stage, entirely in memory.
let stage = USDStage()

// An existing scene, from disk. This touches the filesystem, so it throws.
let stage = try USDStage.open(sceneURL)      // confirm exact API — parameter label, throws vs. async throws
```

## Traversing the hierarchy

Before adding anything, walk the stage to see what's already there — for example, checking whether an asset already exists somewhere in the scene before adding a duplicate:

```swift
for prim in stage.traverse() {                // confirm exact traversal API — method/property name unconfirmed
    print(prim.path)                           // confirm exact Prim accessors
}
```

## Defining a new prim, and referencing in an asset

Two different operations that are easy to conflate: **defining** creates a new node at a path on *your* stage; **referencing** pulls in someone else's asset without copying its data.

```swift
// Create a new transform prim at the path where the asset should live.
let oscilloscope = stage.defineTransform(at: "/Bench/Oscilloscope")   // confirm exact API — name/signature unconfirmed

// Rather than copying the referenced asset's data into this stage, compose
// it in as a lightweight reference. It stays a separate file (layer),
// authored by whoever owns it — and their future edits reach your stage
// automatically, because you're referencing, not copying.
oscilloscope.addReference(oscilloscopeAssetURL)   // confirm exact signature — arguments/throws unconfirmed
```

This is composition in one call: everyone works on their own layer, and `addReference` brings it together on yours (see `usd-fundamentals.md`).

## Moving a prim

Don't hand-write transform attributes. `addTransformOperation` creates the correct attributes on the prim *and* keeps the transform op order consistent, so other USD tools interpret the stack the way you intended:

```swift
oscilloscope.addTransformOperation(.translate)             // confirm exact API — sets up the op + op order
oscilloscope.translation = SIMD3<Float>(0.2, 0.9, -0.4)    // confirm exact property name/type
```

Once set, the asset moves — in this example, up onto the workbench.

## Exporting, with compression

```swift
var options = USDExportOptions()          // confirm exact type name
options.meshCompression = true            // confirm exact option name
options.textureCompression = true         // confirm exact option name

try stage.exportPackage(to: outputURL, options: options)   // confirm exact signature
```

See `compression-and-accessibility.md` for what these options buy you and the no-code equivalents (Preview, `usdcrush`).

## USDKit vs. SwiftUSD vs. embedding OpenUSD

Three ways to work with USD on Apple platforms, all reading and writing the same files:

- **USDKit** — system-provided, deeply integrated with RealityKit and Spatial Preview. Start here for app development on Apple platforms.
- **SwiftUSD** — open-source Swift bindings, distributed via Swift Package Manager, for needs that go beyond what USDKit covers.
- **Embedding OpenUSD directly** — for cross-platform C++ codebases that want OpenUSD as a framework rather than going through a Swift layer.

Whichever you pick, USD files interchange freely across all three — a stage authored through SwiftUSD opens in USDKit and vice versa. Choose based on where the rest of your codebase lives, not on any format lock-in.

## Common mistakes

1. **Copying an asset's data instead of calling `addReference`.** Copying forks the asset immediately; referencing keeps you connected to the source layer and its future updates.
2. **Hand-authoring transform attributes.** Use `addTransformOperation` — it manages attribute creation and transform-op ordering for you.
3. **Forgetting `USDStage.open` can throw.** It touches the filesystem — a missing file or bad URL fails at open, not silently later.
4. **Assuming every capability has a typed USDKit wrapper.** Some schemas (accessibility, for one) need attributes authored directly rather than through a dedicated USDKit convenience API — see `compression-and-accessibility.md`.
5. **Reaching for SwiftUSD or embedded OpenUSD "just in case."** USDKit is the recommended starting point for app developers precisely because of its RealityKit/Spatial Preview integration — reach for the others only once you hit a concrete need USDKit doesn't cover.
