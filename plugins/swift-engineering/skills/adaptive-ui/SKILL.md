---
name: adaptive-ui
description: >-
  Use when a layout must adapt to arbitrary window/scene sizes instead of a fixed device — iPhone fold (folded vs unfolded inner display), iPad Split View / Slide Over / Stage Manager, resizable iPhone-only apps on iPad, or iPhone Mirroring on Mac. Covers the WWDC 26 shift from size classes to available space: geometry-driven breakpoints (onGeometryChange, containerRelativeFrame, ViewThatFits, AnyLayout), Tab↔Sidebar navigation morphing, scene-geometry APIs (windowResizability, effective geometry, onInteractiveResizeChange, orientation preferences), and why horizontalSizeClass, userInterfaceIdiom, orientation, and UIScreen.main are no longer reliable layout inputs.
---

# Adaptive UI: From Size Class to Available Space

The fixed-canvas era is over. An app no longer owns a screen of a known size and aspect ratio — it renders into a **scene** whose size the user can change at any moment. iPhone apps are now resizable (iPhone Mirroring on Mac, iPhone-only apps on iPad), iPad apps float and split, and foldables switch between a narrow outer display and a wide inner one mid-session.

**Core principle: lay out against the space you actually have, not against a guess about the device.** Read the size of your root view, container, or scene and choose a layout from *that*. Traits like `horizontalSizeClass` still describe system container *semantics* (should menus collapse? are system Tabs/Sidebars offered?) but they are **not** a width sensor — a wide iPhone window can stay `.compact` forever, by design.

Based on Fatbobman's ["From Size Class to Available Space"](https://fatbobman.com/en/posts/from-size-class-to-available-space/) and WWDC 26 Session 278 *Modernize your UIKit app*.

## The one rule that prevents most bugs

> **Your own breakpoints** ("switch to two columns", "show side navigation", "wider grid") → decide from **measured available size**.
> **System container behavior** ("collapse a menu", "offer a system sidebar") → `horizontalSizeClass` is still fine.

If your layout query answers "how much room do I have right now?", it must read geometry — never `horizontalSizeClass`, `userInterfaceIdiom`, `UIScreen.main`, or device orientation.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** It's better to have the context than to miss a pattern or make a mistake.

| Reference | Load When |
|-----------|-----------|
| **[Available-Space Principles](references/available-space-principles.md)** | Understanding *why* traits are unreliable, the WWDC 26 contract, the 2014→2026 evolution, and the "express preferences, not control" mental model |
| **[Geometry-Driven Layout](references/geometry-driven-layout.md)** | Building breakpoints with `onGeometryChange`, `containerRelativeFrame`, `ViewThatFits`, `AnyLayout`, custom `Layout`, or a constrained `GeometryReader` — the practical SwiftUI toolkit |
| **[Navigation Adaptation](references/navigation-adaptation.md)** | Morphing Tab Bar ↔ Sidebar ↔ split columns as space changes; the custom-sidebar strategy; `NavigationSplitView`, `.tabViewStyle(.sidebarAdaptable)`, iPhone fold / iPad / macOS behavior |
| **[Toolbar Adaptation](references/toolbar-adaptation.md)** | Reflowing a toolbar across a dynamic size range — rank items with `visibilityPriority`, collapse secondary actions into the overflow "⋯" menu, pin with `topBarPinnedTrailing`, and the prominent `tabRole` (WWDC 26 resizability toolbar story) |
| **[Scene Geometry](references/scene-geometry.md)** | Scene/window APIs: `windowResizability`, effective geometry, `onInteractiveResizeChange`, `isInteractivelyResizing`, orientation & size-restriction preferences, injecting a size class, `UIRequiresFullScreen`/`UIScreen.main` deprecation |
| **[Migration & Testing](references/migration-and-testing.md)** | Auditing an existing app for unreliable inputs, the migration checklist, Info.plist cleanup, and how to test iPhone fold / iPad multitasking / resizable iPhone in Xcode 27 previews and Device Hub |

## Core Workflow

1. **Identify the query.** Is the code asking "how much space do I have?" (→ geometry) or "what kind of container am I in?" (→ trait)? Get this right first.
2. **Measure available space** at the layer that owns the decision — root view for app shell, container for a component, scene for window-level choices.
3. **Choose a layout tool** (decision tree below) and drive it from the measured value or a derived breakpoint.
4. **Express preferences, not control** — minimum sizes and resizability, not fixed frames or full-screen locks.
5. **Verify** across the real matrix: iPhone fold folded/unfolded, iPad full/50%/33%/Slide Over/Stage Manager, resizable iPhone, and macOS mirroring.

## Decision Trees

### Which input should drive this?
```
"What is my layout reacting to?"

AMOUNT OF SPACE (my own breakpoint) ── measure geometry
  ├─ Pick the best-fitting variant?        → ViewThatFits
  ├─ Animate an H↔V (or column) switch?    → AnyLayout + a geometry-derived flag
  ├─ Compute columns / sizes from width?   → onGeometryChange
  └─ Size a child relative to its parent?  → containerRelativeFrame

SYSTEM CONTAINER SEMANTICS ── trait is still correct
  ├─ Should a system menu/toolbar collapse? → horizontalSizeClass
  └─ Offer a system Sidebar/Tab morph?      → horizontalSizeClass / .sidebarAdaptable

TOOLBAR RUNNING OUT OF ROOM ── rank + overflow, don't measure width (see toolbar-adaptation.md)
  ├─ Keep a primary action visible longest?  → .visibilityPriority(.high)
  ├─ Tuck secondary actions away when tight?  → toolbar overflow "⋯" menu container
  └─ Anchor one action to the trailing edge?  → .topBarPinnedTrailing

NEVER drive layout from:
  UIScreen.main.bounds · userInterfaceIdiom · UIDevice.orientation · a hardcoded device check
```

### Where do I read the size?
```
App shell (tab bar vs sidebar)?     → geometry at the ROOT view (reflects the scene)
One component (card, grid, header)? → geometry at THAT container
Window-level policy / restrictions? → scene effective geometry (didUpdateEffectiveGeometry / onInteractiveResizeChange)
```

## Common Mistakes

1. **Treating `horizontalSizeClass` as a width sensor.** It is a coarse trait, not pixels. On an iPhone host it can stay `.compact` at *any* window width — WWDC 26 made this intentional. Breakpoints that read the size class silently stop firing on resizable iPhone and foldables. Read geometry instead.

2. **Branching on `userInterfaceIdiom` / device model.** `phone` idiom no longer means "narrow": an iPhone-only app on iPad or in Mac mirroring runs under the phone idiom in a large window. `if idiom == .pad` fails in every multitasking and mirroring case. Respond to space, not identity.

3. **Reading `UIScreen.main.bounds` for layout.** It returns the physical display, not your scene. In Split View, Slide Over, Stage Manager, a resized iPhone window, or a foldable's inner display, it is simply wrong. Use the view/container size or the scene's effective geometry.

4. **Trusting device orientation.** In a resizable environment supported orientations are *preferences* — the system may keep portrait even as the aspect ratio changes. Derive "landscape-ish" from `width > height` of the actual container, never from `UIDevice.current.orientation`.

5. **Unconstrained `GeometryReader` as a size probe.** It greedily fills all offered space and collapses its children's intrinsic sizing, breaking the very layout you're measuring. Prefer `onGeometryChange`; if you must use `GeometryReader`, constrain it (`.frame(height:)`) or keep it in a background/overlay.

6. **Geometry-read feedback loops.** Writing a size into `@State` that changes the layout, which changes the size, which fires again → jitter. Map geometry to a *coarse, Equatable* value (a `Bool` flag, an `Int` column count, an enum), so the action only fires when the meaningful bucket changes — not on every sub-point wobble.

7. **Locking the canvas.** `UIRequiresFullScreen` is deprecated and will be ignored; hardcoded frames and forced orientation fight the user. Express a **minimum** content size and `windowResizability`, then let the layout adapt to whatever the user chooses.

8. **Injecting `\.horizontalSizeClass = .regular` as a global fix.** It's an escape hatch, not a strategy — it changes behavior for *every* descendant that reads the value, and "phone idiom + injected regular" is not fully controllable. Prefer an explicit geometry-driven decision you own (see Navigation Adaptation).
