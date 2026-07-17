---
name: textkit
description: Use when building custom or extended text experiences with TextKit — the four-layer architecture (content storage / layout / viewport / view), custom text views, the new viewport rendering-surface APIs, and extending UITextView/NSTextView via viewport delegate hooks for line numbers, collapsible sections, and inline attachment reuse; also embedding NS/UITextView in SwiftUI via a ViewRepresentable.
---

# TextKit: Custom & Extended Text Views

> Parts of this (notably the viewport rendering-surface APIs) are recent-release additions newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

TextKit is Apple's text engine — the foundation of text layout and rendering across every Apple platform. Every text control in SwiftUI, UIKit, and AppKit (`TextEditor`, `UITextView`, `NSTextView`) lays out and renders its content through TextKit.

## Overview

Building a text editing experience on Apple platforms is a tension between **convenience** and **control**. As of the 2027 releases there is also a middle path that captures most of both.

**Path 1 — framework text views (convenience).** `UITextView` (UIKit), `NSTextView` (AppKit), `TextEditor` (SwiftUI). You get an enormous amount for free: text input, selection, accessibility, undo/redo, dictation, inline predictions, and more. They use TextKit internally, but that implementation is mostly hidden — historically you had limited ability to customize how text is drawn or how the viewport manages its visual elements. These power thousands of long-form experiences (Messages, TextEdit, Notes, Journal). **This is the right default.**

**Path 2 — custom text views (control).** Drive TextKit yourself: stand up the storage, layout, and viewport layers and render into a view or a layer directly. You get total control over storage, layout, and the viewport layout process — but you give up everything the framework views provide, and a production-quality editor from scratch is a lot of work. Reach for this only when you genuinely need control the framework can't give.

**The middle path (new).** `UITextView` and `NSTextView` now conform to `NSTextViewportLayoutControllerDelegate`. You can **subclass a framework text view and override its viewport hooks** — `willLayout` / `configureRenderingSurface(for:)` / `didLayout` — to add behavior (line numbers, collapsible sections, inline attachment reuse) while keeping input, selection, accessibility, undo, and dictation. Prefer this over going fully custom.

All four TextKit layers — **text storage → layout → viewport → view** — are shared across UIKit, AppKit, and SwiftUI, so one mental model applies everywhere. See `architecture.md`.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** It's better to have the context than to miss a pattern or make a mistake.

| Reference | Load When |
|-----------|-----------|
| **[Architecture](references/architecture.md)** | Understanding the four layers (content storage / layout / viewport / view), the immutable-fragment model, wiring up a fully custom text view, or sharing one content storage across multiple layout managers for synced presentations |
| **[Framework Text Views](references/framework-text-views.md)** | Embedding `UITextView`/`NSTextView` in SwiftUI via a `ViewRepresentable`, or extending a framework text view through the new viewport delegate hooks — worked examples: line numbers for a code editor, collapsible sections in a recipe app |
| **[Rendering Surfaces](references/rendering-surfaces.md)** | The new `NSTextViewportRenderingSurface` / `NSTextViewportRenderingSurfaceKey` protocols — assigning and caching drawable surfaces per layout fragment across viewport layout cycles (new APIs — hedge exact names) |
| **[Attachments](references/attachments.md)** | Inline non-text content (`NSTextAttachment` / `NSTextAttachmentViewProvider`), and preserving attachment state/animation across edits and scrolling with view-provider reuse policies |

## Core Workflow

1. **Pick the lightest path.** Default to a framework text view — `TextEditor` in SwiftUI, or `UITextView`/`NSTextView` embedded via a `ViewRepresentable`. Choose a fully custom text view only when the viewport hooks below can't express what you need.
2. **To extend a framework text view,** subclass `UITextView`/`NSTextView` (the `NSTextViewportLayoutControllerDelegate` conformance is built in) and override `willLayout` / `configureRenderingSurface(for:)` / `didLayout`. **Always call `super` first** in each.
3. **Work relative to the viewport.** The hooks fire on every scroll, edit, and selection. Enumerate and measure only what's visible, and **convert fragment frames from text-container to viewport coordinates** (subtract the viewport origin) before drawing against them.
4. **To skip layout for hidden content** (e.g. collapsed sections), conform to `NSTextContentStorageDelegate` and return `false` from `textContentManager(_:shouldEnumerate:)` — don't lay out then hide.
5. **For inline attachments that animate or hold state,** register a view-provider reuse policy so keystrokes and scrolling don't recreate the provider (see `attachments.md`).
6. **To build a fully custom text view,** instantiate `NSTextContentStorage` + `NSTextLayoutManager`, drive an `NSTextViewportLayoutController`, and render fragments into a `UIView`/`NSView` or `CALayer` (see `architecture.md`).

## Common Mistakes

1. **Going fully custom too early.** A custom text view throws away input, selection, accessibility, undo/redo, dictation, and inline predictions — all of which are expensive to rebuild well. If subclassing + viewport hooks can do the job (line numbers, gutters, collapsing, decorations), do that instead.

2. **Forgetting `super` in the delegate hooks.** `willLayout`, `configureRenderingSurface(for:)`, and `didLayout` must each call `super` or you lose the framework text view's default layout and rendering behavior.

3. **Treating fragments/paragraphs as mutable or stable.** `NSTextParagraph` and `NSTextLayoutFragment` are **immutable** and are **recreated on every edit** to their paragraph. Don't hold a reference expecting it to survive a keystroke — this is exactly what restarts inline attachment animations. Use the fragment as a lookup key, not as durable state.

4. **Confusing text-container and viewport coordinates.** `layoutFragmentFrame` is in text-container space. To position a gutter, decoration, or overlay you must subtract the viewport origin first.

5. **Doing expensive work on every layout pass.** The viewport layout process repeats on every scroll, edit, and selection. Counting paragraphs before the viewport, building tables, etc. must be **cached** — don't recompute from the document start each pass.

6. **Laying out content you then hide.** To collapse or hide content, skip its layout via `textContentManager(_:shouldEnumerate:)` rather than laying it out and drawing over it.
