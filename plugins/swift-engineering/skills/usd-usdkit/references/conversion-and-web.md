# Getting Assets Into USD, and Onto the Web

> Some APIs here ship in 2025–2026 releases. Confirm exact names against current Apple documentation.

## Getting a DCC asset into USD

The best path into USD is the most direct one: **export straight from the tool you modeled in**. Blender, Autodesk Maya, SideFX Houdini, and most other modern DCCs have solid, native USD export — that's the option to reach for first, and the one that gives you the most control over the result (geometry vs. materials, which USD file type to target — see `file-formats.md`).

Historically, when the original authoring file wasn't available, Apple shipped **Reality Converter** — a standalone utility that packaged collections of USD files, `.obj`, Alembic, and other 3D formats into a self-contained USDZ, plus command-line tools for batch-processing many assets at once. For a modern pipeline, prefer exporting from the DCC directly, or use `usdcrush` when compression-aware export is the goal (see `compression-and-accessibility.md`) — but Reality Converter–produced USDZs still open fine, since they're just USD.

For assets that only exist as legacy SceneKit `.scn` files — SceneKit itself is deprecated; see `realitykit-core` — Xcode converts them directly: select the asset, **File → Export…**, and choose "Universal Scene Description Package" (a zipped USDZ) as the output type. For batch conversion, or to carry over animations that live in separate `.scn` files (a common SceneKit pattern), the `scntool` CLI does the same conversion with more control:

```
xcrun scntool --convert Max.scn --format usdz --append-animation Max_spin.scn --output ~/Desktop/Max.usdz
```

*(Flags reconstructed from Apple's own walkthrough — confirm exact flag names and ordering with `xcrun scntool --help`.)* `--append-animation` folds an animation-only `.scn` (no geometry) into the converted asset, which RealityKit then exposes through an `AnimationLibraryComponent` — see `realitykit-core`.

## USD on the web: the Safari Model tag

Safari's new **Model tag** embeds a USD model in a web page as naturally as an `<img>` or `<video>` — no plugin, no separate viewer app. On **macOS and iOS**, that gives visitors a fully interactive 3D experience right in the browser. On **visionOS**, it goes further: the model doesn't stay flat in the page — it breaks out and is presented spatially, right in the user's own space.

```html
<model src="oscilloscope.usdz"></model>   <!-- confirm exact tag/attribute names -->
```

Practically, this means a USDZ you already export for AR Quick Look or App Store Tags is very often the same file you'd drop into a web page — one asset, several destinations.

## Spatial Preview: live from Mac to Vision Pro

The new **Spatial Preview** framework (macOS 27) connects your Mac directly to Quick Look on Vision Pro. Edit a USD scene in Preview, and the changes appear live in Quick Look on the headset, right in the user's own space — and with SharePlay, a whole team can join the same session, walking around the scene together to review lighting, composition, and spatial scale in real time. Spatial Preview isn't limited to Preview itself — it's also available to build this kind of collaborative, live-linked workflow into your **own** Mac apps; see the dedicated Spatial Preview session for the framework's API.

## Common mistakes

1. **Reaching for a converter tool before checking DCC export first.** If the asset's source file is available, native DCC export is almost always the better result than converting after the fact.
2. **Assuming Reality Converter is still the primary recommended path.** It's still useful for orphaned assets in other formats, but for a modern pipeline, export from the DCC, or use `usdcrush` when compression is the goal.
3. **Forgetting `--append-animation` when converting split SceneKit animation files.** Without it, a converted character asset arrives with geometry but no motion.
4. **Not testing the Model tag on visionOS specifically.** Behavior there (breaking out into the user's space) is materially different from macOS/iOS (staying embedded in the page) — verify both.
5. **Building a custom live-preview pipeline from scratch.** If the goal is "see my Mac edits on Vision Pro immediately," check whether **Spatial Preview** already covers it before building bespoke networking/sync.
