---
name: macos-multiplatform
description: >-
  Use whenever writing or changing SwiftUI feature code that could run on a Mac — new views, navigation, toolbars, models, or any iOS-specific capability (camera, haptics, motion, `UIKit` types, `#if os`, `.navigationBarTitleDisplayMode`, `.listStyle(.insetGrouped)`, `.keyboardType`, `.fullScreenCover`, `UIScreen`/`UIApplication`/`UIColor`/`UIImage`). Enforces the contract that the macOS target ALWAYS builds and launches (minimum) and is adapted natively where it matters (maximum). Covers the divergence ladder (unify → bridge → adapt → exclude), conditional compilation done right (`canImport` over `os()`, pushing `#if` down into typealiases and view modifiers), the catalog of iOS-only APIs that break the Mac build and their cross-platform replacements, macOS scenes/windows/menus/pointer adaptation, and multiplatform project structure. Load this by default when architecting any new feature — the house rule is that components are designed with macOS in mind, not retrofitted later.
---

# macOS Multiplatform: Build for Mac by Default

SwiftUI lets one codebase target iPhone, iPad, **and Mac** — but only if you treat the Mac as a first-class destination from the first line, not a port you attempt later. The moment an unguarded `UIScreen.main`, `.navigationBarTitleDisplayMode(.inline)`, or `UIColor` lands in shared code, the macOS target stops compiling, and every feature built on top of it inherits a broken build. This skill exists to prevent that and to push each feature up the quality ladder toward a Mac app that feels native.

**Three commitments, in priority order:**

1. **Minimum — the macOS target always compiles and launches.** This is non-negotiable and verifiable. Every change keeps `xcodebuild -destination 'platform=macOS'` green. A feature that only builds on iOS is an unfinished feature.
2. **Maximum — adapt to macOS idioms where it matters.** Sidebars over bottom tab bars, real menu-bar commands and keyboard shortcuts, hover and right-click, resizable windows, a `Settings` scene. Not every feature reaches the top rung, but you always know where it sits.
3. **Default — architect new features with macOS in mind.** Reach for cross-platform APIs first, isolate platform differences behind shared seams, and never let an iOS assumption ossify into shared code. Retrofitting Mac support later costs far more than designing for it now.

Grounded in Sébastien Lato's *SwiftUI Multi-Platform Architecture*, Jesus Perez Mojica's *Building Once, Running Everywhere*, Jesse Squires' *Sharing / Improving multiplatform SwiftUI code*, Antoine van der Lee's *SwiftUI-Agent-Skill* (macOS scene/window/control APIs), and Apple's multiplatform guidance (Food Truck & Backyard Birds samples). See the reference files for the specifics from each.

## Share behavior, specialize presentation

Multiplatform SwiftUI is an **architecture** problem, not a UI problem — and the architectural rule is one sentence: **share behavior, specialize presentation.** Your code describes *intent* once; each platform *adapts the execution* to its own strengths. You never force platforms to run identical UI (that is the old cross-platform trap — apps that "work everywhere but feel native nowhere"); you express what a feature does and let each platform present it natively.

That means every feature is a layered stack with a fixed, high line between shared and specialized:

```
Business Logic     ─┐  SHARED — zero platform code, ever
State Management    ─┘  (@Observable models; no #if, no UIKit, no UIScreen)
────────────────────
Navigation Model    ─┐
Layout System        │  per platform — the ONLY layers that specialize
Input Model          │  (stack/split/sidebar/spatial · metrics · touch/pointer/keyboard)
Presentation        ─┘
```

**The cardinal rule: nothing platform-specific lives above the presentation layers.** No `#if os()`, no `UIKit`/`AppKit` import, no `UIScreen`/`UIDevice`, no platform check inside a model, ViewModel, or service. A ViewModel that knows which platform it is on is two ViewModels wearing a trenchcoat. When a difference leaks upward, push it *down* into a shared seam — a platform-metrics value injected via the Environment, a `PlatformContainer` that picks the navigation shell, or named model actions that each platform's UI wires to its own affordances. The full patterns are in **[Layered Architecture](references/layered-architecture.md)**; the divergence ladder below governs each individual specialization within the lower layers.

## The divergence ladder

When iOS and macOS differ, climb to the **highest rung that works**. The rung you land on is a deliberate choice, not an accident.

```
1. UNIFY   Use a semantic, cross-platform API that already works on both.
           .navigationTitle · .toolbar{ ToolbarItem(placement:.primaryAction) }
           Color · Image(systemName:) · ShareLink · .sensoryFeedback · .fileImporter
           →  Zero #if. First thing to try, every time.

2. BRIDGE  Same concept, different type/modifier per platform. Hide the #if
           INSIDE a typealias or a custom view modifier so call sites stay clean.
           PlatformImage (UIImage/NSImage) · PlatformViewRepresentable
           .inlineNavigationBarTitle()  // no-op on macOS, applies on iOS
           →  #if lives in ONE place; feature code never sees it.

3. ADAPT   The *experience* should differ. Branch to a macOS-native treatment
           behind a shared entry point — same feature, platform-right UX.
           Sidebar vs. bottom TabView · Settings scene vs. settings screen
           .fileImporter vs. camera capture · MenuBarExtra
           →  Both platforms fully supported; each feels correct.

4. EXCLUDE No Mac analog exists at all (CoreMotion, ARKit, true camera capture).
           Gate with #if os(iOS). The macOS build MUST still compile, and the
           surrounding UI must still make sense (hide the control, offer an
           alternative) — never ship a dead button or an empty screen.
           →  Last resort. If you reach here, confirm rungs 1–3 truly don't apply.
```

The **minimum contract** means rung 4 is *always* satisfied: the Mac compiles no matter what. **Architecting with macOS in mind** means defaulting to rung 1 and only descending when a real difference forces it.

## The one rule that prevents most broken builds

> **Never leave a platform-specific symbol unguarded in shared code.** If a type, modifier, or framework exists on only one platform, it must be reached through a rung — a cross-platform API, a bridge, an adapted branch, or an `#if`. An unguarded `UIKit`/`AppKit` symbol in a file the macOS target compiles is a build break waiting for the next `xcodebuild`.

Corollary: **compiling for iOS proves nothing about the Mac.** The only proof the minimum contract holds is building the macOS target. Do it before you call a feature done.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** It is better to have the context than to miss a pattern, break the Mac build, or ship an un-Mac-like feature.

| Reference | Load When |
|-----------|-----------|
| **[Layered Architecture](references/layered-architecture.md)** | Designing any new feature — the "share behavior, specialize presentation" layer model, the rule that business logic/ViewModels carry zero platform code, and the structural patterns that keep it that way: platform-metrics protocol + Environment injection, `PlatformContainer` navigation shells, and actions-as-the-shared-seam for divergent input models |
| **[Platform Gating](references/platform-gating.md)** | Writing any `#if`, deciding `canImport` vs `os()`, choosing where the `#if` goes, or building bridges — `PlatformColor`/`PlatformImage`/`PlatformFont`/`PlatformViewRepresentable` typealiases, the `Double(iOS:macOS:)` value-initializer / `.padding(iOS:macOS:)` modifier pattern, and no-op custom view modifiers that keep call sites platform-free |
| **[API Divergence Catalog](references/api-divergence.md)** | Reaching for any iOS-flavored SwiftUI/UIKit API — the concrete list of what breaks the macOS build (`.navigationBarTitleDisplayMode`, `.listStyle(.insetGrouped)`, `.keyboardType`, `.fullScreenCover`, `EditButton`, `UIScreen`/`UIApplication`/`UIPasteboard`, toolbar placements) and the cross-platform or macOS-native replacement for each |
| **[macOS Adaptation](references/macos-adaptation.md)** | Climbing to the top rung — the *strategy*: scenes (`WindowGroup`/`Settings`/`MenuBarExtra`), `.commands` + keyboard shortcuts, `NavigationSplitView`, the pointer/hover/right-click/focus input model, window sizing & resizability, sandbox & entitlements, file access, `NSApplicationDelegateAdaptor` lifecycle, and how far up the ladder each feature should go |
| **[macOS-Native APIs](references/macos-native-apis.md)** | The concrete *toolkit* for adapting — full scene types (`Window`/`UtilityWindow`/`DocumentGroup`, `openWindow(value:)`, `SettingsLink`), window chrome (`.windowStyle(.hiddenTitleBar)`, `.windowToolbarStyle`, `.windowResizability`, `.menuBarExtraStyle`), macOS-native controls (`Table` + `tableStyle`, `Inspector`, `HSplitView`, `CopyButton`), security-scoped file access, AppKit interop (Coordinator, `NSHostingController`/`View`), and keyboard-driven focus (`.defaultFocus`, `.focusSection`) |
| **[Project Structure](references/project-structure.md)** | Setting up or reorganizing targets — single multiplatform target vs. shared package + thin platform apps, feature-folder layout, platform file-naming (`Foo+iOS.swift`), keeping `Shared` small, deployment targets, and the CI discipline that keeps the Mac build from rotting |
| **[Migration & Verification](references/migration-and-verification.md)** | Making an existing iOS-only feature build on Mac (minimum) then adapting it (maximum) — the audit for Mac-breaking symbols, the step-by-step, the test matrix, and the pre-commit checklist |

## Core Workflow

Follow this whenever you add or change a feature:

1. **Assume macOS from the start.** Before writing UI, ask "how does this look in a resizable Mac window, driven by a pointer and keyboard?" Design the shared shape to that, not to a 390-pt phone.
2. **Default to rung 1 (Unify).** Pick semantic, cross-platform APIs (`.navigationTitle`, `.toolbar` with semantic placements, `Color`, `ShareLink`, `.sensoryFeedback`). Most SwiftUI is already cross-platform — reach for the iOS-only variant only when forced.
3. **When forced to diverge, pick the highest workable rung** (bridge → adapt → exclude) and isolate the difference at that seam. Never sprinkle `#if os()` across call sites — push it into a typealias, a modifier, or a single branch.
4. **Guard every platform-specific symbol.** No unguarded `UIKit`/`AppKit` type, modifier, or framework in shared code.
5. **Build the macOS target.** `xcodebuild -scheme <App> -destination 'platform=macOS'` must succeed. This verifies the minimum contract — iOS success does not.
6. **Assess the rung you landed on.** If a feature merely compiles on Mac (rung 4) but a native adaptation was reasonable (rung 3), note it or do it. "Builds on Mac" is the floor, not the goal.

## Decision Trees

### How do I handle this platform difference?
```
"iOS and macOS need to differ here. What do I do?"

Is there a semantic API that works on BOTH?          → USE IT (rung 1, no #if)
  (.navigationTitle, ToolbarItem(placement:.primaryAction),
   Color, ShareLink, .sensoryFeedback, .fileImporter, .focusable)
        │ no
Same concept, only the TYPE/MODIFIER differs?        → BRIDGE (rung 2)
  (UIImage↔NSImage, UIViewRepresentable↔NSViewRepresentable,
   an iOS-only modifier that should just no-op on Mac)
   → typealias or custom view modifier; #if lives there, once
        │ no
Should the EXPERIENCE differ (both fully supported)? → ADAPT (rung 3)
  (tab bar↔sidebar, settings screen↔Settings scene,
   camera↔file import) → shared entry point, platform branch
        │ no
Capability has NO Mac analog at all?                 → EXCLUDE (rung 4)
  (CoreMotion, ARKit, true capture)
   → #if os(iOS); Mac still compiles; hide/alt the UI
```

### Where does the `#if` go?
```
Difference is ONE modifier on an otherwise-shared view? → custom view modifier (no-op on the absent platform)
Difference is a TYPE (color, image, font, representable)? → typealias in one Platform.swift file
Whole view/screen genuinely differs per platform?        → separate files (Foo+iOS.swift / Foo+macOS.swift),
                                                            one #if picks which View to build — at the TOP, not scattered
A framework import (UIKit/AppKit/CoreMotion)?            → #if canImport(...) around the import AND its users

NEVER: an #if os() inside a view body around a single call site you could have bridged.
```

## Common Mistakes

1. **Assuming iOS success means the Mac builds.** It doesn't. An unguarded `UIColor` compiles for iOS and fails only when someone finally builds macOS — often long after you moved on. Build the Mac target yourself, every time. This is the whole point of the minimum contract.

2. **Scattering `#if os(iOS)` across call sites.** Ten `#if` blocks in a view body for the *same* underlying difference is unmaintainable and error-prone. Push the difference down once — into a `Platform` typealias or a custom view modifier — and keep call sites platform-free (rung 2).

3. **Excluding when you could have adapted.** Wrapping a whole screen in `#if os(iOS)` because *one* modifier is iOS-only, or dropping a feature entirely when a `.fileImporter` could stand in for the camera, produces a Mac app full of holes. Descend the ladder only as far as the real difference forces — usually that's a bridge, not an exclusion.

4. **Excluding without healing the surrounding UI.** `#if os(iOS)` around the *implementation* but leaving a visible "Scan with camera" button on Mac that does nothing is worse than not shipping it. When you exclude, hide or replace the entry point too — the Mac build must both compile and make sense.

5. **`UIKit` types in shared model/view code.** `UIColor`, `UIImage`, `UIFont`, `UIScreen.main`, `UIApplication.shared` don't exist on macOS. Prefer SwiftUI-native equivalents (`Color`, `Image`, `Font`, and — for size — measured geometry per the `adaptive-ui` skill). When you genuinely need the platform type, reach it through a `Platform*` bridge, never raw.

6. **iOS-only toolbar placements.** `ToolbarItem(placement: .navigationBarTrailing)` is an iOS placement; on Mac it misbehaves. Use **semantic** placements — `.primaryAction`, `.confirmationAction`, `.cancellationAction`, `.automatic` — which SwiftUI maps correctly on every platform (rung 1).

7. **Bottom `TabView` as the only navigation.** A phone tab bar is not how Mac (or iPad) apps navigate. Design shells around `NavigationSplitView` or `.tabViewStyle(.sidebarAdaptable)` so the same structure becomes a sidebar on Mac. See `macos-adaptation` and the `adaptive-ui` skill.

8. **Forgetting the Mac input model.** Mac users expect hover feedback (`.onHover`), right-click context menus (`.contextMenu`), keyboard shortcuts (`.keyboardShortcut`), focus, and Return/Escape in dialogs. A feature that only responds to taps, swipes, and long-presses compiles on Mac but feels foreign. Reaching the "maximum" commitment means wiring these up.

9. **Hardcoding phone dimensions.** Fixed `.frame(width: 390)` or `UIScreen.main.bounds` assumes a canvas the Mac doesn't have — Mac windows are large and resizable. Lay out against measured available space (the `adaptive-ui` skill) and express `minWidth`/`idealWidth`, not fixed sizes.

10. **`#if os(macOS)` that references an excluded symbol elsewhere.** Gating the definition but leaving another unguarded reference to it re-breaks the build. When you exclude a symbol, make sure *every* use of it is behind the same guard.

11. **Platform code above the presentation layer.** A `#if os()`, a `UIScreen` read, a `UIKit` import, or any platform check inside a model, ViewModel, or service is the cardinal architectural sin — it forks your shared layer and metastasizes. Business logic and state must be 100% platform-blind. When a model seems to *need* a platform value, that value belongs in the platform-metrics layer (injected via the Environment), not branched on inside the model. Verify with `rg '#if os\(|import (UIKit|AppKit)|UIScreen' Features/**/*Model.swift Services/` — it should return nothing. See **[Layered Architecture](references/layered-architecture.md)**.

12. **Forcing one platform's shell or UI onto another.** A fake bottom tab bar on Mac, a push stack where a sidebar belongs, or pixel-identical UI across platforms means one platform is wearing another's clothes. Give each platform its native navigation model through a `PlatformContainer`; aim for the same product *identity*, not the same pixels. If it feels forced, it is.
