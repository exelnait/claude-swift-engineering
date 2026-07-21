# Compression & Accessibility

> Some APIs here ship in 2025–2026 releases. Confirm exact names against current Apple documentation.

Two finishing touches that turn a working USD asset into one that's ready to ship to everyone: shrinking it, and making sure assistive technologies can describe it.

## Mesh and texture compression

Production USD scenes get big — Apple's own ALab reference scene (used in USDKit's own demos) runs to many gigabytes, which makes it impractical to just hand someone the file. Two compression technologies address this together:

- **Mesh compression** — developed in collaboration with the **Alliance for Open Media**, a state-of-the-art codec capable of reducing mesh sizes by **up to 90%**.
- **Texture compression** — **AVIF**, already in use for USD textures.

Combined, the average asset comes out **~7x smaller**, without a visible drop in visual quality. Smaller assets mean faster delivery, lower storage costs, and a better experience on every platform you ship to.

Enable both wherever you export:

```swift
var options = USDExportOptions()       // confirm exact type name
options.meshCompression = true         // confirm exact option name
options.textureCompression = true      // confirm exact option name
try stage.exportPackage(to: outputURL, options: options)   // confirm exact signature
```

No code required: Preview's export/convert flow and the **`usdcrush`** command-line tool both produce the same compressed result — reach for either when you're processing assets outside a Swift app (batch jobs, a build script, a one-off export). Apple is working with Pixar to bring this compression support into the OpenUSD project itself, so it won't stay Apple-platform-only for long.

## USD accessibility metadata

Great 3D experiences should be accessible to everyone — accessibility is a core value at Apple, and that includes spatial content. That's why Apple has driven the standardization of **accessibility metadata directly in USD**: a shared way to define assistive labels and descriptions on 3D objects, designed with room to evolve. Because it's native to USD rather than an Apple-only bolt-on, it's authorable from **any** USD API, and there's direct support already in **Blender** and **Maya** — a label written in Blender is readable the same way through USDKit, and vice versa.

Adding it to a prim is two steps:

```swift
// 1. Apply the schema — this records (in the prim's metadata) that
//    accessibility data is present on this prim.
prim.applySchema(AccessibilityAPI.self)              // confirm exact API — method name unconfirmed

// 2. USDKit doesn't (yet) provide a typed, schema-specific convenience
//    API for AccessibilityAPI's own data — author the attributes
//    directly, using the exact names the specification defines.
prim.set(attribute: "label", to: "Oscilloscope")                 // confirm exact attribute name/API
prim.set(attribute: "description", to:
    "A vintage bench oscilloscope with a round CRT display and analog dials.")  // confirm exact attribute name/API
```

The label should be concise — how you'd name the object out loud. The description should be rich enough that assistive technology can convey the object's context, not just its name. Treat this the way you'd treat alt text on an image: expected for anything meant for a general audience, not an optional extra.

## Common mistakes

1. **Shipping uncompressed because "it already works."** A fast dev connection hides what a real user's download (or a Vision Pro's storage budget) will feel like. Enable both compression options by default, and only disable them for a specific reason.
2. **Expecting a typed accessibility API.** Applying `AccessibilityAPI` marks the schema as present; it doesn't hand you `prim.accessibilityLabel` to set. You author `label`/`description` as attributes yourself, using the spec's exact names.
3. **Treating accessibility as USDKit-only, or optional.** It's a USD-level standard — readable and writable from Blender, Maya, or any USD API — specifically so it travels with the asset everywhere. Skipping it because "this app doesn't use a screen reader" ignores every downstream consumer of the file.
4. **Forgetting compression is available with zero code**, too — Preview and `usdcrush` cover the same ground for anyone not exporting through USDKit directly.
