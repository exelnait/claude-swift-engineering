# Layered Architecture: Share Behavior, Specialize Presentation

Multiplatform SwiftUI is not a UI problem — it is an **architecture** problem. The apps that stay clean across iPhone, iPad, Mac, and visionOS are not the ones with the cleverest `#if os()` blocks; they are the ones where platform difference is *structurally* confined to the presentation layers, and everything below is genuinely one codebase. This file is the architectural spine that makes "architect new features with macOS in mind" a concrete practice rather than a slogan.

Based on Sébastien Lato's [*SwiftUI Multi-Platform Architecture*](https://dev.to/sebastienlato/swiftui-multi-platform-architecture-ios-ipados-macos-visionos-1961) and Jesus Perez Mojica's [*Building Once, Running Everywhere*](https://medium.com/@mrhotfix/building-a-unified-multiplatform-architecture-with-swiftui-ios-macos-and-visionos-6214b307466a).

## The core principle

> **Share behavior. Specialize presentation.**

Business logic is 100% shared. UI *composition* adapts per platform. Multiplatform SwiftUI is not primarily about source-code reuse — the trap of every prior cross-platform framework, which produced apps that "technically work everywhere but feel native nowhere." SwiftUI inverts the model: **your code describes intent; the execution adapts to each platform's strengths.** You do not force platforms to run identical UI — you express what a feature *does* once, then let each platform present it the way its users expect.

## The layer model

Think of every feature as a stack. The line between "shared" and "per-platform" is fixed, and it is high up:

```
┌─────────────────────────────┐
│ Business Logic              │  SHARED — zero platform code, ever
│ State Management            │  SHARED — @Observable models, no #if, no UIKit
├─────────────────────────────┤
│ Navigation Model            │  per platform (stack / split / sidebar / spatial)
│ Layout System               │  per platform (compact vs regular, metrics)
│ Input Model                 │  per platform (touch / pointer / keyboard / gaze)
│ Presentation                │  per platform (the actual views)
└─────────────────────────────┘
```

The **upper layers are shared and platform-blind**. Only the **lower, presentation-facing layers** specialize. When you add a feature, you are writing the shared upper layers *once* and choosing how much of the lower layers to specialize (the divergence ladder governs each choice). If platform difference is leaking *upward* — a `#if os()` in a model, a `UIScreen` read in a ViewModel — the abstraction is in the wrong layer. Push it down.

## The hard rule: nothing platform-specific above presentation

**No `#if os()`, no `UIKit`/`AppKit` import, no `UIScreen`/`UIDevice`, no platform check — inside business logic or state/ViewModels.** This is the single most important structural rule, and it is easy to verify:

```bash
# These should return NOTHING for your models / view-models / services:
rg -n '#if os\(|import (UIKit|AppKit)|UIScreen|UIDevice' Features/**/*Model.swift Services/
```

A ViewModel that knows what platform it is on has already lost the plot — it is now two ViewModels wearing a trenchcoat. If a model seems to *need* a platform value (a sidebar width, a padding, a capability flag), that value belongs in the **platform abstraction layer** below, injected in, not branched on.

## Pattern 1 — Platform abstraction layer (values)

When the *same* view needs different constants per platform (metrics, sizes, capability flags), don't branch in the view — define a protocol of the platform-varying values, implement it per platform, and inject it through the Environment. Views then read the value with **no conditionals**.

```swift
// Shared — the contract.
protocol PlatformMetrics {
    var sidebarWidth: CGFloat { get }
    var toolbarHeight: CGFloat { get }
    var contentPadding: CGFloat { get }
}

// Platform/iOS — one implementation.
struct iOSMetrics: PlatformMetrics {
    let sidebarWidth: CGFloat = 0
    let toolbarHeight: CGFloat = 44
    let contentPadding: CGFloat = 16
}

// Platform/macOS — another.
struct macOSMetrics: PlatformMetrics {
    let sidebarWidth: CGFloat = 240
    let toolbarHeight: CGFloat = 52
    let contentPadding: CGFloat = 24
}
```

Wire it into the Environment once, at the root:

```swift
private struct MetricsKey: EnvironmentKey {
    static let defaultValue: any PlatformMetrics = {
        #if os(macOS)
        macOSMetrics()
        #else
        iOSMetrics()
        #endif
    }()
}
extension EnvironmentValues {
    var metrics: any PlatformMetrics {
        get { self[MetricsKey.self] }
        set { self[MetricsKey.self] = newValue }
    }
}
```

```swift
// Feature view — reads values, contains no #if:
@Environment(\.metrics) private var metrics
// ...
.padding(metrics.contentPadding)
.frame(minWidth: metrics.sidebarWidth)
```

The one `#if` lives in the Environment key's default; every consumer is clean. (For values that vary with *available space* rather than platform identity — column counts, breakpoints — use measured geometry per the `adaptive-ui` skill, not a metrics constant.)

## Pattern 2 — Platform container (navigation & shell)

Navigation is the layer that diverges most: iPhone wants a push stack, iPad a split view, Mac a sidebar + detail with multiple windows, visionOS spatial scenes. Do **not** force one model. Wrap the shared feature content in a `PlatformContainer` that selects the right shell per platform, so feature views never know which shell they live in.

```swift
struct RootView: View {
    var body: some View {
        PlatformContainer {
            HomeFeature()          // shared feature content — shell-agnostic
        }
    }
}

struct PlatformContainer<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        #if os(macOS)
        NavigationSplitView { Sidebar() } detail: { content() }   // sidebar + detail
        #else
        NavigationStack { content() }                             // push stack (adapts on iPad)
        #endif
    }
}
```

The single `#if` that picks the shell lives here, in the navigation layer — never sprinkled inside `HomeFeature`. Swapping or adding a platform's navigation model is a change to one container, not to every feature.

## Pattern 3 — Actions as the shared seam (input model)

The input model is the other big divergence: touch/swipe on iOS; pointer/hover/right-click/keyboard on Mac; gaze/pinch on visionOS. The way to let input diverge *without* duplicating logic is to expose the feature's behavior as **named actions**, and let each platform's UI wire its own affordances to the same actions.

```swift
// Shared model — behavior, no UI, no platform:
@Observable final class LibraryModel {
    func create()  { /* … */ }
    func delete()  { /* … */ }
    func refresh() { /* … */ }
}
```

```swift
// iOS presentation wires actions to touch affordances:
.swipeActions { Button("Delete", role: .destructive) { model.delete() } }
.refreshable { model.refresh() }

// macOS presentation wires the SAME actions to pointer/keyboard affordances:
.contextMenu { Button("Delete") { model.delete() } }        // right-click
.commands { Button("Refresh") { model.refresh() }.keyboardShortcut("r") }  // ⌘R + menu bar
```

Same `LibraryModel.delete()`; different doorways. Never let `.onTapGesture { }` be a feature's *only* interaction — always also offer a `Button`, a keyboard shortcut, focus, and a context menu, so every platform's users have a native way in (see **macOS Adaptation** for the full input matrix).

## How this maps to folders

The layer model has a physical shape on disk — **split by feature, then by platform, never platform at the top level** (details and target strategy in **Project Structure**):

```
Features/                 # shared upper layers — one home per feature
├── Home/                 #   HomeModel.swift (@Observable), HomeState, business logic
├── Profile/
└── Settings/
Platform/                 # specialized lower layers — wrappers & adapters only
├── iOS/                  #   iOSMetrics, iOS containers, iOS-only views
├── macOS/                #   macOSMetrics, split-view shells, menu commands
└── visionOS/             #   spatial containers
```

A feature folder holds the shared model/state/logic; the `Platform/*` folders hold the metrics implementations, containers, and any genuinely platform-unique views. This is Apple's own shape in the **Food Truck** and **Backyard Birds** samples (a `Multiplatform/` shared area plus a reusable `…Kit` Swift package) — see **Project Structure**.

## Anti-patterns (structural smells)

These are the signs platform difference has escaped its layer:

- **`#if os(iOS)` inside a feature view.** Push it down into a `PlatformContainer`, a metrics value, or an action wiring. Feature views describe *what*, not *where they run*.
- **A platform check inside a ViewModel/model/service.** The cardinal sin. Business logic must be platform-blind. Move the varying value into the platform abstraction layer.
- **Duplicated business logic per platform.** If `iOSLibraryModel` and `macLibraryModel` both implement `delete()`, you have forked the shared layer. There is one model; platforms differ only below it.
- **Navigation hacks** to force one platform's model onto another (a fake bottom tab bar on Mac, a forced push stack in place of a sidebar). Give each platform its native shell via the container.
- **Forced-identical UI everywhere.** Pixel-identical across platforms is a red flag, not a goal — it means at least one platform is wearing another's clothes. Same identity, native presentation.

Rule of thumb from the source: **if it feels forced, it is.** The layered model exists so that the natural thing — shared behavior, native presentation — is also the easy thing.
