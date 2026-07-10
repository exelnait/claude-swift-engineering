# Scene Geometry

Window/scene-level APIs for the era where the **user and system jointly decide** the app's size. Use these to express *preferences* (minimum size, resizability, temporary orientation lock) and to *observe* real geometry changes — never to force a fixed canvas.

> **Verify signatures for the newest APIs.** `onInteractiveResizeChange`, `isInteractivelyResizing`, `prefersInterfaceOrientationLocked`, and the `UISceneSizeRestrictions` preferred-size surface were introduced/expanded at **WWDC 26 (iOS/iPadOS 27)**. Confirm exact names and parameters with the **Sosumi MCP server** or current Apple docs before shipping — this reference gives intent and shape, and these are too new to memorize.

## Express a size preference, not a size command

### SwiftUI — `windowResizability` + content minimum size

Declare how the window may resize and let your content's minimum size set the floor. You state a *preference*; the user still resizes freely above it.

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 380, minHeight: 480)   // the content floor
        }
        .windowResizability(.contentMinSize)             // respect that floor; resizable above it
    }
}
```

- `.contentMinSize` — the window can shrink only to the content's minimum.
- `.contentSize` — pin to the content's size range (rarely what you want for adaptive apps).
- `.automatic` — system default.

Do **not** express a fixed `minWidth == maxWidth`; that recreates the fixed canvas you're trying to escape.

### UIKit — `UISceneSizeRestrictions`

Express a scene's **preferred minimum size** (and, where supported, a maximum). It's a preference the system honors within its own policy — not a guarantee, and never a full-screen lock.

```swift
func windowScene(_ scene: UIWindowScene, ...) {
    scene.sizeRestrictions?.minimumSize = CGSize(width: 380, height: 480)
    // maximumSize / allowsFullScreen exist where the platform supports them — verify via Sosumi.
}
```

## Observe geometry changes (don't assume them)

An unfold, a Split View resize, or a Stage Manager drag is a **scene-geometry change** delivered to you — react to it; never assume a size from the device.

### UIKit — `windowScene(_:didUpdateEffectiveGeometry:)`

The scene delegate callback for effective-geometry changes. This is the authoritative signal that replaces `UIScreen.main` and orientation notifications.

```swift
func windowScene(_ windowScene: UIWindowScene,
                 didUpdateEffectiveGeometry previousGeometry: UIWindowSceneGeometry) {
    let geometry = windowScene.effectiveGeometry
    // Use geometry (size, interfaceOrientation, isInteractivelyResizing …) as the source of truth.
    // Property surface is new in WWDC 26 — confirm exact members via Sosumi.
    applyLayout(for: geometry)
}
```

### Interactive vs. settled — `isInteractivelyResizing` / `onInteractiveResizeChange`

A drag-resize produces a **stream** of intermediate sizes and then a **final** size. Distinguish them so you do cheap work during the drag and expensive relayout only when it settles — avoiding thrash while the user is dragging a Stage Manager handle or unfolding.

```swift
// UIKit — inside didUpdateEffectiveGeometry:
if windowScene.effectiveGeometry.isInteractivelyResizing {
    updateCheaply(for: geometry)     // lightweight: reflow, don't reload
} else {
    commitLayout(for: geometry)      // settled: recompute grids, refetch page sizes, etc.
}
```

```swift
// SwiftUI — react to the interactive-resize phase:
RootView()
    .onInteractiveResizeChange { isResizing in
        // true while the user is actively dragging; false when it settles.
        // Defer expensive recomputation until isResizing == false.
    }
// Exact closure signature is WWDC 26 — verify via Sosumi.
```

## Orientation as a preference — `prefersInterfaceOrientationLocked`

Orientation is no longer a fact you can demand. You may express a **temporary** lock preference (e.g., a video player or a camera capture screen) which the system may honor:

```swift
// Express a temporary orientation-lock PREFERENCE (WWDC 26 — verify via Sosumi).
// The system decides; treat rotation as possible at any time regardless.
someScene.prefersInterfaceOrientationLocked = true   // shape only; confirm the real API surface
```

For "am I landscape?" **never** read `UIDevice.current.orientation` — derive it from the container's geometry (`width > height`). See `geometry-driven-layout.md`.

## Injecting a size class — escape hatch, not strategy

You *can* push `\.horizontalSizeClass = .regular` into a SwiftUI subtree (e.g., after detecting a wide scene) to make system containers adopt regular semantics:

```swift
wideSubtree
    .environment(\.horizontalSizeClass, .regular)
```

**Use sparingly.** Per the article's own reasoning:

- It changes behavior for **every** descendant that reads the value — broad, blunt blast radius.
- "Phone idiom + injected regular" is **not fully controllable**; system components may behave unexpectedly.
- A wide iPhone window is still an **adaptive iPhone experience**, not a full iPad interface — faking `.regular` globally pretends otherwise.

Prefer an explicit, geometry-driven decision you own (the manual navigation switch in `navigation-adaptation.md`). Reach for injection only for a small, contained subtree where a specific system control must adopt regular semantics and you've verified the result.

## Deprecations to purge

| Old | Status | Replace with |
|-----|--------|--------------|
| `UIRequiresFullScreen` (Info.plist) | **Deprecated; will be ignored.** Users choose Full Screen / Windowed / Stage Manager. (Apple TN3192) | Remove it. Express a minimum size instead. |
| `UIScreen.main` / `UIScreen.main.bounds` | Unreliable — physical display, not your scene. | Scene `effectiveGeometry`, or the view/container size. |
| `UIDevice.current.orientation` for layout | Unreliable — a pose/preference, not your aspect ratio. | `width > height` of the actual container. |
| `userInterfaceIdiom` branching for layout | No longer maps to space. | Measured available space. |

## SwiftUI ↔ UIKit bridge

SwiftUI apps still reach scene-level callbacks through a scene delegate when needed:

```swift
@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup { RootView() }
            .windowResizability(.contentMinSize)
    }
}

// AppDelegate configures UISceneConfiguration whose delegateClass is a UIWindowSceneDelegate
// that implements windowScene(_:didUpdateEffectiveGeometry:) as shown above.
```

For most view-level adaptation you won't need this — `onGeometryChange` at the root already reflects the scene's available space. Drop to the scene delegate only for genuine window-level policy: size restrictions, orientation-lock preferences, or distinguishing interactive-vs-settled resize app-wide.
