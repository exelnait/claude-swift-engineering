# Text Attachments — Inline Content & Reuse

> Parts of this (notably the viewport rendering-surface APIs) are recent-release additions newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

Text views display more than text — inline photos and stickers in Messages, drawings and document scans in Notes. That non-text content lives **inside** the text view, managed by TextKit, as **text attachments**, and follows the **same four-layer architecture** as regular text (see `architecture.md`).

## How an attachment flows through the layers

- **Storage:** an attachment is stored in the text storage **just like any other character**, as an `NSTextAttachment`.
- **Layout:** when the layout manager encounters the attachment, it asks for an `NSTextAttachmentViewProvider` — the corresponding object in the layout layer. The view provider supplies the information needed to render the attachment onto the text view.

## The problem: immutable objects restart on every edit

Like paragraphs and fragments, these objects are **immutable**. Edit the text in a paragraph and every instance for that paragraph is **discarded and recreated** — including the view provider. In a messaging app with an **inline animation**, that recreation **restarts the animation on every keystroke** in the paragraph.

## The fix: register a view-provider reuse policy

On `UITextView`, register a **reuse policy** for a specific `NSTextAttachmentViewProvider` subclass so the text view preserves (rather than recreates) the provider.

```swift
let textView = UITextView()

// Per the talk, the argument order is: reuse policy first, then the view-provider subclass.
// Exact method name and argument labels are approximate — confirm against current Apple documentation.
textView.registerForTextAttachmentViewProviderType(          // confirm exact API against current Apple documentation
    .onEditingInlineParagraphs,                              // reuse policy (see below)
    forViewProviderType: AnimatedStickerViewProvider.self    // NSTextAttachmentViewProvider subclass the text view will manage
)
```

| Reuse policy | Effect |
|--------------|--------|
| `onEditingInlineParagraphs` | **Preserves the view provider across paragraph edits**, so keystrokes don't tear it down — the animation keeps running while you type. |
| `onScrollingOutOfViewport` | **Caches the attachment's rendering surface when it scrolls off screen** and restores it when it comes back (builds on the rendering-surface APIs — see `rendering-surfaces.md`). |

You can **combine both policies** depending on your scenario — e.g. an attachment that both animates and scrolls should survive edits *and* be cached off-screen.

```swift
// Combining policies (exact shape — OptionSet vs. separate registrations — confirm against current Apple documentation).
textView.registerForTextAttachmentViewProviderType(
    [.onEditingInlineParagraphs, .onScrollingOutOfViewport],
    forViewProviderType: AnimatedStickerViewProvider.self
)
```

With a policy registered, `UITextView` reuses the view provider on editing, **maintaining its state and avoiding animation glitches**.

## Rules of thumb

- If an attachment **animates or holds state**, register `onEditingInlineParagraphs` — otherwise typing in the same paragraph restarts it.
- If attachments are **expensive to build** and scroll on/off screen, add `onScrollingOutOfViewport` to cache their rendering surface.
- The policy targets a **subclass type**, not an instance — the text view then manages every attachment of that class.
