# Reading & Long-Form Text Accessibility

Best practices for making long-form / reading content accessible on Apple
platforms. Reading content is fundamentally different from navigating UI: it's
about moving fluidly *through* text (by line, word, character, sentence), not
just hopping between controls. The three goals to design for are **granular
text navigation**, a **continuous reading experience**, and **comprehensive
text selection** — for VoiceOver, Speak Screen, and the Accessibility Reader.

## Critical Rules

- **Prefer system text views first.** `UITextView` (UIKit), `NSTextView`
  (AppKit), and SwiftUI `TextEditor` / `Text` with selection enabled adopt
  `UITextInput` and give you line/word/character navigation, rotor support, and
  accessible text selection for free. Reach for custom text only when layout
  truly requires it.
- **Link separate text elements** so VoiceOver can navigate by line *across*
  paragraph boundaries. Separate views (one per paragraph) otherwise trap
  navigation inside a single view.
- **Support continuous read-all across pages.** Paginated content must advance
  automatically during a Speak Screen / VoiceOver "read all" using
  `causesPageTurn` + `accessibilityScroll`.
- **Expose text-selection actions via the edit rotor** using a custom action
  with the `.edit` category — not a generic action.
- **For custom / rendered text (including scanned images), adopt `UITextInput`
  in its entirety.** Partial adoption loses the reading benefits.
- **Audit with assistive tech on:** run the read-all gesture, navigate with the
  lines rotor, and select text — with VoiceOver and Speak Screen.

## Granular navigation across separate text elements

When each paragraph is its own view, VoiceOver gets stuck navigating by line
*within* that view. Connect adjacent elements so it can cross the boundary.

### UIKit — text navigation element APIs (iOS 18+)

For each text element, return the next/previous element VoiceOver should move
to. These are available on the iOS 26 baseline (no availability guard needed).

```swift
// ✅ Link paragraph views so line navigation flows between them
final class ParagraphTextView: UITextView {
    weak var nextParagraph: UIView?
    weak var previousParagraph: UIView?

    override func accessibilityNextTextNavigationElement() -> Any? {
        nextParagraph
    }

    override func accessibilityPreviousTextNavigationElement() -> Any? {
        previousParagraph
    }
}

// During setup, wire each direction where applicable:
func configureNavigationElements(_ paragraphs: [ParagraphTextView]) {
    for (index, paragraph) in paragraphs.enumerated() {
        paragraph.previousParagraph = index > 0 ? paragraphs[index - 1] : nil
        paragraph.nextParagraph =
            index < paragraphs.count - 1 ? paragraphs[index + 1] : nil
    }
}
```

```swift
// ❌ Separate paragraph views with no linkage — VoiceOver plays the
//    "edge" sound at the end of each paragraph and can't continue by line.
let p1 = UITextView()
let p2 = UITextView()
// (no next/previous navigation element configured)
```

### SwiftUI — accessibilityLinkedGroup (iOS 27+)

Linking text elements with the same `id` and `namespace` gives the same
cross-element navigation behavior. This API is iOS 27+, so guard it (the plugin
baseline is iOS 26).

```swift
// ✅ Link selectable text elements into one navigable group
struct PageView: View {
    @Namespace private var readingNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            paragraph(morningText)
            paragraph(middayText)
        }
    }

    @ViewBuilder
    private func paragraph(_ text: String) -> some View {
        let content = Text(text).textSelection(.enabled)
        if #available(iOS 27, *) {
            content.accessibilityLinkedGroup(id: "page", in: readingNamespace)
        } else {
            content
        }
    }
}
```

### AppKit

On macOS, use `accessibilitySharedTextUIElements` to associate the related text
elements for an equivalent result.

## Continuous reading across paginated content

A "read all" (Speak Screen: two-finger swipe down from the top) should move
through every page like an audiobook, not stop at the bottom of the current
page. Apply the `causesPageTurn` trait to the last element on the page and
implement scrolling.

### UIKit

```swift
// ✅ Mark the last paragraph so read-all turns the page, and scroll on demand
final class PageViewController: UIViewController {
    var lastParagraph: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        lastParagraph.accessibilityTraits.insert(.causesPageTurn)
    }

    override func accessibilityScroll(
        _ direction: UIAccessibilityScrollDirection
    ) -> Bool {
        advanceToNextPage()   // move focus / content to the next page
        return true
    }
}
```

### SwiftUI

```swift
// ✅ Equivalent traits + scroll action in SwiftUI
lastParagraphView
    .accessibilityAddTraits(.causesPageTurn)

containerView
    .accessibilityScrollAction { edge in
        advanceToNextPage()
    }
```

```swift
// ❌ No causesPageTurn / scroll action — Speak Screen stops dead at the
//    bottom of the page; the reader has to manually swipe to continue.
```

## Comprehensive text selection & the edit rotor

System text views already provide accessible selection. To make a
selection-related action (e.g. "Save recommendation") discoverable, add a
custom action with the **edit** category so it appears in VoiceOver's edit
rotor — not as a generic action.

### UIKit

```swift
// ✅ Text-selection action surfaced through the edit rotor
final class ParagraphTextView: UITextView {
    override var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
        get {
            let save = UIAccessibilityCustomAction(name: "Save Recommendation") {
                [weak self] _ in
                self?.saveCurrentSelection()
                return true
            }
            save.category = .edit          // <- edit rotor, not generic actions
            return (super.accessibilityCustomActions ?? []) + [save]
        }
        set { super.accessibilityCustomActions = newValue }
    }
}
```

Use `.edit` only for actions associated with text selection; keep unrelated
actions in the default category.

## Custom / rendered text — adopt UITextInput

If you render text yourself (advanced typography, shared rendering code, or
scanned/OCR'd images), you lose the built-in reading behavior — including
basic "read the text aloud." Re-gain line touch exploration, rotor navigation,
Speak Screen, and selection by adopting `UITextInput` **fully** on your
accessibility element. To do this you must:

- **Compute geometry** — return selection rectangles for a range in
  `selectionRects(for:)` (for image-backed text, derive rects from the known
  line height/width).
- **Return substrings** — `text(in:)` must return just the queried portion.
- **Provide a tokenizer** — drive line/sentence/word/character navigation;
  subclassing `UITextInputStringTokenizer` is a common starting point.
- Implement the remaining `UITextInput` requirements; the benefits only arrive
  with complete adoption.
- **(Recommended)** Add a `UITextInteraction` and notify the input delegate on
  selection changes so selection handles/highlights match a standard text view.

`UITextInput` composes with `causesPageTurn` and the text-navigation element
APIs above — implement all three for a full custom-text reading experience.

> For full-page content you can also adopt `UIAccessibilityReadingContent`
> (see "Creating an Accessible Reading Experience"). `UITextInput` is the
> higher-fidelity protocol and is preferred for granular reading.

## Accessibility Reader (iOS 26+)

Since iOS 26, the **Accessibility Reader** displays text content for easier
consumption, and users can open it from a Control Center control. You don't get
this for free by accident — implementing the practices above (system views or
full `UITextInput`) is exactly what makes content render well in the Reader.
Audit your content there too.

## Summary

**Key Principles**:
1. Use system text views (`UITextView` / `NSTextView` / `TextEditor` / selectable
   `Text`) before anything custom.
2. Link separate text elements: `accessibilityNext/PreviousTextNavigationElement`
   (UIKit, iOS 18+), `accessibilityLinkedGroup` (SwiftUI, iOS 27+),
   `accessibilitySharedTextUIElements` (AppKit).
3. Support read-all across pages with `causesPageTurn` + `accessibilityScroll`.
4. Surface text-selection actions through the edit rotor via a `.edit`-category
   custom action.
5. For custom/rendered text, adopt `UITextInput` in its entirety (geometry,
   substrings, tokenizer, plus `UITextInteraction` for visuals).
6. Verify in the Accessibility Reader (iOS 26+) and audit with VoiceOver and
   Speak Screen: read-all, lines rotor, and text selection.
