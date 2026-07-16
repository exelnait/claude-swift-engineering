---
name: swiftui-animations
description: >-
  Use when animating SwiftUI — implicit `.animation(_:value:)` vs explicit `withAnimation`, choosing an `Animation` curve (`.spring`/`.bouncy`/`.smooth`/`.snappy`, easing, delays, `repeatForever`), `Transaction` for scoping/overriding, view insertion/removal `.transition`s, `matchedGeometryEffect` and the iOS 18 zoom `navigationTransition`/`matchedTransitionSource`, `contentTransition` (`.numericText`, symbol effects), phase animations (`phaseAnimator`) and keyframe animations (`keyframeAnimator`), plus performance (`drawingGroup`, `geometryGroup`) and honoring Reduce Motion. Load whenever motion, a transition, a spring, a looping/complex sequence, or an animated value change is involved.
---

# SwiftUI Animations (iOS 26+)

SwiftUI animates the *difference between two states*: you change a value, and SwiftUI interpolates the affected views from old to new over an `Animation`. Everything follows from that model — implicit vs explicit is just *who* declares the animation, transitions are how views enter/leave, and phase/keyframe animators are how you script multi-step motion.

The core principle: **animate state changes, not view properties directly.** Decide *what* value drives the motion, choose the lightest tool that expresses it, prefer springs for anything interactive, and always give Reduce Motion an escape hatch.

## Quick Reference

| Need | Use |
|------|-----|
| Animate whenever a value changes | `.animation(_:value:)` (implicit, scoped to a subtree) |
| Animate a specific mutation | `withAnimation(_) { state = … }` (explicit) |
| Natural, interruptible motion | `.spring`, `.bouncy`, `.smooth`, `.snappy` (prefer over fixed-duration easing) |
| View enters/leaves | `.transition(_)` + the change wrapped in an animation |
| Element flies between layouts | `matchedGeometryEffect` (same hierarchy) |
| Zoom nav/detail transition (iOS 18) | `.matchedTransitionSource` + `.navigationTransition(.zoom)` |
| Animate text/number/symbol change | `.contentTransition(.numericText())`, `.symbolEffect` |
| Fixed multi-step sequence on trigger | `phaseAnimator` |
| Complex, independent property tracks | `keyframeAnimator` |
| Override/scope an in-flight animation | `Transaction` / `.transaction { }` |
| Respect accessibility | `@Environment(\.accessibilityReduceMotion)` |

## Core Workflow

1. **Identify the driving value.** Motion happens because some `Equatable` state changed — name it. Everything hangs off that.
2. **Pick implicit or explicit.** `.animation(_:value:)` when a view should always animate that value; `withAnimation { }` when a specific event should animate whatever it touches. Prefer explicit for anything triggered by user action.
3. **Choose a spring first.** `.spring`/`.bouncy`/`.smooth`/`.snappy` feel right and interrupt gracefully. Reach for fixed-duration easing only for precise, non-interactive timing.
4. **For enter/leave, add a `.transition`;** for shared-element motion, `matchedGeometryEffect` or the zoom `navigationTransition`.
5. **For scripted motion,** use `phaseAnimator` (discrete steps) or `keyframeAnimator` (parallel property tracks) — not a pile of nested `withAnimation`s.
6. **Guard performance and accessibility** — measure before `drawingGroup`, isolate layout with `geometryGroup`, and provide a reduced/none variant under Reduce Motion.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.**

| Reference | Load When |
|-----------|-----------|
| **[Implicit & Explicit](references/implicit-explicit.md)** | The animation engine — `.animation(_:value:)`, `withAnimation`, the `Animation` curves (spring family, easing, `delay`, `speed`, `repeatCount`/`repeatForever`), and `Transaction`/`.transaction` for scoping and overriding |
| **[Transitions & Matched Geometry](references/transitions.md)** | Views entering/leaving and shared-element motion — `.transition` (`.move`/`.opacity`/`.scale`/`.push`/`.asymmetric`/`.combined`), custom transitions, `matchedGeometryEffect`, iOS 18 `matchedTransitionSource` + `.navigationTransition(.zoom)`, `contentTransition`, `.symbolEffect` |
| **[Phase & Keyframe Animators](references/keyframes-phases.md)** | Scripted motion — `phaseAnimator` for a sequence of discrete states, `keyframeAnimator` for independent timed tracks, and how to choose between them |
| **[Performance & Accessibility](references/performance-and-accessibility.md)** | When motion janks or must adapt — `drawingGroup`, `geometryGroup`, avoiding over-animation and feedback loops, animation with `@Observable`, and honoring `accessibilityReduceMotion` |

## Common Mistakes

1. **`.animation(_)` without a value (deprecated form).** The old `.animation(_)` animated *everything* and is deprecated. Always scope with `.animation(_:value:)` so only changes to that value animate — otherwise unrelated state changes animate unexpectedly.

2. **Fixed-duration easing for interactive UI.** `.easeInOut(duration:)` can't be interrupted gracefully — a second gesture mid-animation snaps. Use the spring family (`.spring`/`.bouncy`/`.snappy`) for anything the user can re-trigger; springs retarget smoothly.

3. **Missing a stable `.id`/identity for transitions.** `.transition` only fires when a view is truly inserted/removed from the hierarchy (usually via a conditional or a `ForEach` identity change). Toggling a property on a view that stays present won't transition it.

4. **`matchedGeometryEffect` across different hierarchies.** It matches views in the **same** namespace and view tree. For pushing to a detail screen / full-screen zoom, use iOS 18's `.matchedTransitionSource` + `.navigationTransition(.zoom)`, not `matchedGeometryEffect`.

5. **Animating layout without `geometryGroup`.** When a parent's geometry changes, children can animate from surprising positions. Wrap a subtree in `.geometryGroup()` so it resolves layout as a unit and animates coherently.

6. **Reaching for `withAnimation` chains to script a sequence.** Nested/delayed `withAnimation` calls are fragile. Use `phaseAnimator` (steps) or `keyframeAnimator` (tracks) for multi-stage motion — they're declarative and interruptible.

7. **Ignoring Reduce Motion.** Large moves, zooms, and parallax can trigger motion sickness. Read `@Environment(\.accessibilityReduceMotion)` and swap to a cross-fade or no animation. This is a HIG requirement, not a nicety — see the accessibility reference.

8. **`drawingGroup()` as a reflex.** It flattens a subtree into a single Metal layer — great for many overlapping shapes, but it breaks some effects and isn't free. Measure first; most jank is over-animation or layout thrash, not rasterization.
