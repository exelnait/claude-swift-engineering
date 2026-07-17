# Rendering Surfaces (New in the 2027 Releases)

> Parts of this (notably the viewport rendering-surface APIs) are recent-release additions newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

**Everything in this file is new API introduced in the 2027 releases and is described at a conceptual level in the talk. Treat every type name, protocol requirement, initializer, and method signature below as unconfirmed — verify against current Apple documentation before relying on it.**

## The problem it solves

The **viewport layout process** renders a layout fragment's text into a destination view. Before the 2027 releases, TextKit had **no way to refer to those destination views** across the framework: it helped you keep track of layout fragments, but not of the views they were drawn into. The rendering-surface APIs close that gap so you can track, reuse, and customize the drawables in the viewport — primarily when building **custom text views** (see `architecture.md`).

## The two protocols

**`NSTextViewportRenderingSurface`** — a protocol representing a visual element inside the viewport that you can draw into: the thing that actually renders a layout fragment's text, exposed through a common abstraction. Conform your `UIView`, `NSView`, or `CALayer` to it, then use it in the viewport controller's delegate methods to keep track of which views are visible in the viewport.

**`NSTextViewportRenderingSurfaceKey`** — a companion **key** protocol. A rendering-surface key is any class that can **uniquely identify a surface across viewport layout process cycles**. `NSTextLayoutFragment` is such a key — so you can use a fragment as a key to **cache** rendering surfaces in map tables or dictionaries. The viewport layout process uses this key → surface mapping extensively, internally.

```swift
// 1) Make your drawable a rendering surface.
final class GlyphSurfaceLayer: CALayer, NSTextViewportRenderingSurface {   // or a UIView / NSView
    // protocol requirements TBD — confirm exact API against current Apple documentation
}

// 2) NSTextLayoutFragment already acts as a stable key (NSTextViewportRenderingSurfaceKey),
//    so it can index a cache that survives across layout cycles.
let surfaceCache = NSMapTable<NSTextLayoutFragment, GlyphSurfaceLayer>.strongToStrongObjects()  // confirm exact API
```

## Lifecycle within the viewport layout process

- The key → surface mappings are **cleared at the beginning of each viewport layout process**.
- **Assign** a surface to a key **during** the process, via the `renderingSurfaceFor` **delegate** method.
- **Query** the surface for a key **inside `didLayout`**, via the viewport controller's `renderingSurfaceFor` method.

```swift
// Assign during the process (delegate method) — return the surface for this fragment/key.
func textViewportLayoutController(                                  // confirm exact delegate method
    _ controller: NSTextViewportLayoutController,
    renderingSurfaceFor fragment: NSTextLayoutFragment              // the key
) -> NSTextViewportRenderingSurface? {
    surfaceCache.object(forKey: fragment) ?? makeSurface(for: fragment)   // reuse or create
}

// Query inside didLayout via the controller.
override func textViewportLayoutControllerDidLayout(
    _ controller: NSTextViewportLayoutController
) {
    super.textViewportLayoutControllerDidLayout(controller)
    let surface = controller.renderingSurface(for: someFragment)    // confirm exact API against current Apple documentation
    // ... position / update the surface ...
}
```

## Why it matters

Because a fragment is a stable key, you can **cache and reuse the same drawable** for a paragraph across scrolls and layout passes instead of rebuilding it each cycle — the foundation the attachment reuse policies build on (see `attachments.md`, e.g. caching a surface when it scrolls out of the viewport). These APIs empower you to use and customize your own rendering surfaces when building custom text views with TextKit.
