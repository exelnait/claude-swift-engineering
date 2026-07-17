# Framework Text Views — Embedding & Extending

> Parts of this (notably the viewport rendering-surface APIs) are recent-release additions newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

`UITextView` (UIKit) and `NSTextView` (AppKit) power long-form text across Apple's apps. This reference covers **embedding** them in SwiftUI and **extending** them through the new viewport delegate hooks — without giving up input, selection, accessibility, undo, or dictation.

## Embedding UITextView / NSTextView in SwiftUI

In SwiftUI, the most convenient long-form editor is `TextEditor`. When you need the extra control of the underlying text view, wrap `UITextView`/`NSTextView` (or your subclass) in a `ViewRepresentable`. Make a single `TextViewRepresentable` that is an `NSViewRepresentable` on macOS and a `UIViewRepresentable` otherwise.

```swift
struct MyTextView: View {
    var body: some View {
        TextViewRepresentable()
    }
}

#if os(macOS)
struct TextViewRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> MyNSTextView {   // MyNSTextView: NSTextView subclass
        MyNSTextView()
    }
    func updateNSView(_ view: MyNSTextView, context: Context) { /* push SwiftUI state in */ }
}
#else
struct TextViewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> MyUITextView {   // MyUITextView: UITextView subclass
        MyUITextView()
    }
    func updateUIView(_ view: MyUITextView, context: Context) { /* push SwiftUI state in */ }
}
#endif
```

Inside `makeNSView` / `makeUIView` you simply call the initializer for your text view (or subclass). Everything below applies to that subclass.

## Extending via viewport delegate hooks (new)

Starting with the 2027 releases, **`UITextView` and `NSTextView` conform to `NSTextViewportLayoutControllerDelegate`.** Subclass the framework text view and override the delegate methods to add your own behavior on each viewport layout process:

| Hook | Purpose |
|------|---------|
| `willLayout` | Setup before the pass — clear per-pass state, compute anything you need up front |
| `configureRenderingSurface(for:)` | Called **once per paragraph** in the viewport — capture that fragment's bounds/surface |
| `didLayout` | Teardown/publish — hand the accumulated per-viewport info to your surrounding view |

**Always call `super` first** in every hook, or you lose the default text view layout and rendering.

> Method spellings below follow the `NSTextViewportLayoutControllerDelegate` naming used by the framework text views; confirm exact selectors against current Apple documentation.

## Worked example 1 — line numbers for a code editor

Goal: an iPad code editor built on a `UITextView` subclass (monospaced system font) with a line-number gutter. A `ContainerView` holds the text view subclass and a plain `UIView` gutter; the subclass reports, on every viewport change, the paragraph index and bounds of each visible line.

```swift
final class CodeTextView: UITextView {
    // Per-pass state (the talk: an array of fragment bounds, a starting line number, a closure up to the container).
    private var lineFrames: [CGRect] = []
    private var startingLineNumber = 0
    var onLayout: ((_ startLine: Int, _ viewportFrames: [CGRect]) -> Void)?

    // 1) Setup: reset per-pass state and compute the first visible line number.
    override func textViewportLayoutControllerWillLayout(       // "willLayout"
        _ controller: NSTextViewportLayoutController
    ) {
        super.textViewportLayoutControllerWillLayout(controller)   // always call super
        lineFrames.removeAll()
        startingLineNumber = startingLine(before: controller)
    }

    // 2) Per paragraph in the viewport: collect its frame (text-container coordinates).
    override func textViewportLayoutController(                 // "configureRenderingSurface(for:)"
        _ controller: NSTextViewportLayoutController,
        configureRenderingSurfaceFor fragment: NSTextLayoutFragment
    ) {
        super.textViewportLayoutController(controller, configureRenderingSurfaceFor: fragment)
        lineFrames.append(fragment.layoutFragmentFrame)          // bounds of the paragraph
    }

    // 3) Publish: convert to viewport coordinates and hand up to the container.
    override func textViewportLayoutControllerDidLayout(        // "didLayout"
        _ controller: NSTextViewportLayoutController
    ) {
        super.textViewportLayoutControllerDidLayout(controller)
        let origin = controller.viewportBounds.origin           // confirm exact API against current Apple documentation
        // Fragment frames are in text-container coordinates — subtract the viewport origin.
        let viewportFrames = lineFrames.map { $0.offsetBy(dx: -origin.x, dy: -origin.y) }
        onLayout?(startingLineNumber, viewportFrames)
    }
}
```

The starting line number is the count of **all paragraphs before the viewport starts**. Enumerate text elements from the document start until the viewport range, and **cache it** — recomputing on every pass is wasteful (the talk notes the sample code adds caching here).

```swift
private func startingLine(before controller: NSTextViewportLayoutController) -> Int {
    guard let contentManager = textLayoutManager?.textContentManager,   // confirm exact accessor
          let viewportRange = controller.viewportRange else { return 0 }
    var count = 0
    // enumerateTextElements(from:) — walk elements, incrementing until we reach the viewport.
    _ = contentManager.enumerateTextElements(from: contentManager.documentRange.location) { element in  // confirm exact API against current Apple documentation
        guard let range = element.elementRange,
              range.endLocation.compare(viewportRange.location) == .orderedAscending else {
            return false   // reached the viewport → stop
        }
        count += 1
        return true        // keep counting
    }
    return count
}
```

In the `ContainerView`, set `codeTextView.onLayout`; for each frame, the actual line number is `index + startLine`, drawn at the frame's position in the gutter view. That is the whole feature — line numbers in a `UITextView` with a few lines of code.

## Worked example 2 — collapsible sections in a recipe app

Goal: collapse each multi-paragraph recipe down to just its heading. Start from the same three viewport hooks (to know which paragraphs actually laid out), and additionally **skip layout entirely for collapsed paragraphs** by conforming the text view to `NSTextContentStorageDelegate`.

```swift
final class RecipeTextView: UITextView {
    // Paragraph offsets currently collapsed. Ints uniquely identify each paragraph.
    private var collapsed: Set<Int> = []

    // On tap of a section's disclosure triangle.
    func toggleSection(paragraphOffset: Int) {
        if collapsed.contains(paragraphOffset) { collapsed.remove(paragraphOffset) }
        else { collapsed.insert(paragraphOffset) }
        // Invalidate layout so TextKit re-enumerates and re-lays out — confirm exact invalidation API.
    }
}

extension RecipeTextView: NSTextContentStorageDelegate {
    // Return false to skip layout on a collapsed paragraph entirely.
    // (NSTextContentManager / NSTextElement are the abstract forms of
    //  NSTextContentStorage / NSTextParagraph — the delegate speaks in the abstract types.)
    func textContentManager(                                       // confirm exact signature against current Apple documentation
        _ manager: NSTextContentManager,
        shouldEnumerate element: NSTextElement,
        options: NSTextContentManager.EnumerationOptions
    ) -> Bool {
        guard let offset = paragraphOffset(of: element) else { return true }
        return !collapsed.contains(offset)
    }
}
```

Wire the storage delegate onto the content storage (e.g. `(textLayoutManager?.textContentManager as? NSTextContentStorage)?.delegate = self` — confirm exact accessor). The three pieces together: **skip layout** via the content-storage delegate, **process every paragraph that did lay out** via the viewport hooks, and **handle the tap** on each section's disclosure button.

## When to go fully custom instead

These hooks cover decorations, gutters, and layout skipping while keeping the framework text view intact. If you need to own the drawing surface itself — bespoke glyph rendering, a non-standard drawable — build a custom text view (see `architecture.md`) and use the rendering-surface APIs (see `rendering-surfaces.md`).
