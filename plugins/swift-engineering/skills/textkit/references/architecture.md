# TextKit Architecture — The Four Layers

> Parts of this (notably the viewport rendering-surface APIs) are recent-release additions newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

Understanding TextKit's architecture is pivotal to a great custom text experience. TextKit uses a **four-layer architecture**, bottom to top:

| Layer | Responsibility | Key types |
|-------|----------------|-----------|
| **Text storage** | Encapsulates all the text data to render; breaks it into paragraphs | `NSTextContentStorage` / `NSTextParagraph` (concrete), `NSTextContentManager` / `NSTextElement` (abstract) |
| **Layout** | Breaks the text into chunks (fragments) and computes their layout | `NSTextLayoutManager`, `NSTextLayoutFragment` |
| **Viewport** | Tracks which chunks are currently visible and coordinates rendering | `NSTextViewportLayoutController` |
| **View** | Where the text actually appears on screen | any `UIView` / `NSView` / `CALayer` |

The **storage, layout, and viewport layers are shared across all of Apple's UI frameworks** (UIKit, AppKit, SwiftUI). You can use these shared layers to render text onto any view — or any view-like drawable visual element — a framework provides. Only the top view layer is framework-specific.

The running example below is rendering a long `NSAttributedString` in a custom text view.

## Text storage layer

Text content storage is responsible for breaking the attributed string into paragraphs. For an `NSAttributedString`, `NSTextContentStorage` creates an `NSTextParagraph` object for each paragraph.

- `NSTextContentStorage` and `NSTextParagraph` are **concrete** types that work with `NSAttributedString`.
- If you have a **different backing storage** type, subclass the corresponding **abstract** classes: `NSTextContentManager` (abstract of `NSTextContentStorage`) and `NSTextElement` (abstract of `NSTextParagraph`). Keep this pairing in mind — delegate protocols like `NSTextContentStorageDelegate` are expressed in the abstract vocabulary (`NSTextContentManager`, `NSTextElement`).

## Layout layer

Once storage has produced paragraphs, `NSTextLayoutManager` prepares them for rendering. It performantly measures the metrics of the glyphs that make up the represented text and dynamically creates an `NSTextLayoutFragment` that stores the calculated layout information for the paragraph.

**Fragments and paragraphs are immutable.** If a paragraph is edited, its `NSTextParagraph` and `NSTextLayoutFragment` are **recreated** — e.g. replacing the word "sandwich" with "slider" produces a brand-new `NSTextParagraph` for that paragraph and a corresponding new `NSTextLayoutFragment` with new layout information.

> This immutability is the root cause of a common bug: anything you attach to a fragment (a view provider, an animation, cached state) is torn down and rebuilt on every edit to that paragraph. See `attachments.md` for the reuse-policy fix.

## Viewport and view layers

The text view is a **dynamically sized** view — it grows as text is laid out into it and shrinks as text is removed. The **viewport** is the part of the text view that is visible to the user. TextKit organizes all of its work around the viewport, **only rendering text the user can see**. So one of your core tasks is enhancing the user's interaction based on the layout information the viewport provides.

`NSTextViewportLayoutController` (the "viewport controller") coordinates the layout manager and the view to efficiently lay out and render paragraphs:

1. The text view knows the scroll position and size of the viewport relative to the whole document, and provides this to the viewport controller.
2. The viewport controller asks the layout manager for all layout fragments that **intersect the viewport**, and sends them to the text view for rendering.
3. This coordination repeats on **any change of viewport state** — any scroll, edit, or selection event. This is the **viewport layout process**, central to TextKit's performant layout and rendering.

## Building a fully custom text view

Instantiate the three shared layers and render through the viewport controller into a drawable the framework provides. The "text view" can be any drawable visual element — in UIKit, a `UIView` or a `CALayer`.

```swift
// Storage layer.
let contentStorage = NSTextContentStorage()
contentStorage.attributedString = myAttributedString

// Layout layer, connected to storage.
let layoutManager = NSTextLayoutManager()
contentStorage.addTextLayoutManager(layoutManager)          // confirm exact API against current Apple documentation

// Viewport layer, driving a drawable you own (UIView / NSView / CALayer).
let viewportController = NSTextViewportLayoutController(textLayoutManager: layoutManager)  // confirm exact API against current Apple documentation
viewportController.delegate = self                          // your view/layer implements the delegate

// Your delegate feeds the viewport bounds in, and renders the fragments the
// controller hands back — that is the viewport layout process, run on every
// scroll / edit / selection. The new rendering-surface APIs (see
// rendering-surfaces.md) let you track and cache the drawables per fragment.
```

## Multiple presentations of one document

A framework text view may not fit an app that shows the **same text in multiple presentations**. Connect **multiple layout managers to the same content storage**; edits in one propagate through the shared storage to the others, so two views stay in sync automatically.

```swift
let contentStorage = NSTextContentStorage()
contentStorage.addTextLayoutManager(layoutManagerA)         // confirm exact API against current Apple documentation
contentStorage.addTextLayoutManager(layoutManagerB)
// Edit through the shared contentStorage → both presentations update in lockstep.
```

With this flexibility you can build a custom text view whose layering is right for your scenario.

## Further reading

- "Meet TextKit 2" (WWDC21) — in-depth introduction to the architecture and custom text views.
- "What's new in TextKit and text views" (WWDC22) — how the framework text views adopted TextKit.
