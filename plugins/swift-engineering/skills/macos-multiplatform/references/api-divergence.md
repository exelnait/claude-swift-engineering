# API Divergence Catalog

The concrete list of iOS-flavored APIs that **break the macOS build** or behave wrong on Mac, each paired with the fix. Consult this whenever you reach for a modifier or type that "feels" iOS-specific. The fix is labeled by ladder rung: **[Unify]** replace with a cross-platform API (best), **[Bridge]** wrap in a no-op / typealias, **[Adapt]** provide a Mac-native equivalent.

## SwiftUI modifiers that don't exist on macOS

These fail to compile — or are unavailable — when the macOS target sees them unguarded.

| iOS-only API | Fix | Rung |
|---|---|---|
| `.navigationBarTitleDisplayMode(_:)` | Keep `.navigationTitle(_:)` (cross-platform); wrap the display-mode call in a no-op-on-Mac modifier (`.inlineNavigationBarTitle()`) | Bridge |
| `.navigationBarHidden(_:)`, `.navigationBarBackButtonHidden(_:)` | `.toolbar(.hidden, for: .navigationBar)` where meaningful; otherwise bridge to a no-op on Mac | Bridge |
| `.navigationBarItems(leading:trailing:)` | `.toolbar { ToolbarItem(placement: .primaryAction) { … } }` with **semantic** placements | Unify |
| `.listStyle(.insetGrouped)` / `.grouped` | `.listStyle(.inset)` or `.automatic` (cross-platform); or bridge a platform-appropriate style | Bridge |
| `.keyboardType(_:)` | No Mac hardware keyboard type — wrap in a no-op-on-Mac modifier | Bridge |
| `.textInputAutocapitalization(_:)`, `.autocapitalization(_:)` | Bridge to no-op on Mac (Mac has no autocapitalization) | Bridge |
| `.fullScreenCover(...)` | `.sheet(...)` on Mac (there is no full-screen cover); bridge or adapt per platform | Adapt |
| `.statusBarHidden(_:)` / `.statusBar(hidden:)` | No status bar on Mac — bridge to no-op | Bridge |
| `.persistentSystemOverlays(_:)` (home indicator, etc.) | Bridge to no-op on Mac | Bridge |
| `EditButton()` / `.environment(\.editMode, …)` | No `editMode` on Mac — provide a Mac-native selection/delete affordance, or gate the button | Adapt |
| `.hoverEffect(_:)` | iPad/iOS pointer effect; on Mac use `.onHover { }` for hover state | Adapt |
| `.indexViewStyle`, `TabView(.page)` paging dots | Page-style `TabView` is iOS-only; on Mac use a different container or gate it | Adapt |
| `.refreshable { }` pull-to-refresh | Compiles on Mac but there's no pull gesture — pair it with a toolbar/menu "Refresh" command (⌘R) on Mac | Adapt |

**Semantic toolbar placements that DO work everywhere** (prefer these — rung 1): `.primaryAction`, `.secondaryAction`, `.confirmationAction`, `.cancellationAction`, `.destructiveAction`, `.principal`, `.automatic`, `.status`. **Avoid** the positional iOS placements `.navigationBarLeading` / `.navigationBarTrailing` / `.bottomBar` in shared code — SwiftUI maps the semantic ones to the right spot on each platform.

## UIKit types and globals — absent on macOS

`import UIKit` fails on macOS; so does every bare `UI*` type. Replace with the SwiftUI-native type (rung 1) or a `Platform*` bridge (rung 2, see **Platform Gating**).

| iOS-only symbol | Cross-platform / bridged replacement | Rung |
|---|---|---|
| `UIColor` | `Color` (SwiftUI). If you must have the platform type: `PlatformColor` typealias | Unify / Bridge |
| `UIImage` | `Image` (SwiftUI). Platform type: `PlatformImage` (UIImage/NSImage) | Unify / Bridge |
| `UIFont` | `Font` (SwiftUI). Platform type: `PlatformFont` | Unify / Bridge |
| `UIScreen.main.bounds` | **Never** for layout — use measured geometry (`adaptive-ui` skill). Mac has no single screen | Unify |
| `UIApplication.shared` | Usually unnecessary in SwiftUI. `openURL` env value, `ScenePhase`, `@Environment(\.openWindow)` | Unify |
| `UIDevice.current` | Don't branch on device — branch on space/capability. No `UIDevice` on Mac | Unify |
| `UIPasteboard.general` | `NSPasteboard.general` on Mac — bridge behind a `Clipboard` helper, or use SwiftUI `.copyable`/`PasteButton` | Bridge / Unify |
| `UIViewRepresentable` | `NSViewRepresentable` on Mac — `PlatformViewRepresentable` typealias, or fork the wrapper | Bridge |
| `UIViewControllerRepresentable` | `NSViewControllerRepresentable` on Mac — bridge or fork | Bridge |
| `UIActivityViewController` | `ShareLink` (cross-platform, rung 1) | Unify |
| `UIDocumentPickerViewController` | `.fileImporter` / `.fileExporter` (cross-platform) | Unify |
| `UIFeedbackGenerator`, `UIImpactFeedbackGenerator` | `.sensoryFeedback(_:trigger:)` (cross-platform; Mac has no Taptic Engine but it degrades cleanly) | Unify |
| `UINotificationFeedbackGenerator` | `.sensoryFeedback(.success/.error, trigger:)` | Unify |

## Frameworks with no macOS equivalent (rung 4 — exclude)

These have no Mac analog. Gate the import with `#if canImport(...)` or `#if os(iOS)`, gate every use, and heal the surrounding UI (offer an alternative or hide the entry point).

| iOS-only framework | Mac reality | Handling |
|---|---|---|
| `CoreMotion` (accelerometer, gyroscope) | Macs have no motion sensors | Exclude; hide motion-driven UI on Mac |
| `ARKit` / `RealityKit` AR sessions | No AR on Mac | Exclude; offer a non-AR view if possible |
| Camera capture (`AVCaptureSession` photo/video) | Macs have cameras but capture UX differs greatly | Exclude the iOS capture flow; **adapt** to `.fileImporter` or `PhotosPicker` on Mac |
| `CoreNFC` | No NFC on Mac | Exclude |
| `StoreKit` external-purchase / some iOS-only flows | StoreKit 2 is largely cross-platform | Verify per API; usually rung 1 — see `storekit` skill |

## APIs that are cross-platform but *behave* differently

These compile on Mac (good — minimum contract met) but the *experience* needs adaptation to reach the maximum.

- **`TabView`** — compiles everywhere, but a bottom tab bar is not a Mac idiom. Use `.tabViewStyle(.sidebarAdaptable)` or restructure as `NavigationSplitView` so it becomes a sidebar on Mac. See **macOS Adaptation** and the `adaptive-ui` skill.
- **`NavigationSplitView`** — cross-platform and the *right* default; renders as a proper sidebar+detail on Mac and adaptively on iPad. Prefer over `NavigationStack`-only shells for anything list-detail.
- **`.contextMenu { }`** — cross-platform; on Mac it's the right-click menu (a first-class Mac affordance). Add it generously.
- **`.searchable`** — cross-platform; lands in the toolbar on Mac. Good.
- **`Menu`, `.commands`, `.keyboardShortcut`** — cross-platform; `.commands` populates the *Mac menu bar*. Wire real shortcuts (⌘-keys) for repeatable actions — expected on Mac, harmless on iOS.
- **`ColorPicker`, `PhotosPicker`, `ShareLink`, `PasteButton`** — cross-platform; prefer these over UIKit controllers.

## Quick self-check before you use an API

1. Does it start with `UI` or import `UIKit`/an iOS-only framework? → It will break the Mac build. Find the row above.
2. Is there a SwiftUI-native or semantic version (no `UI` prefix, semantic placement)? → Use it (rung 1).
3. If not, is it "same concept, different type/modifier"? → Bridge (rung 2).
4. Does the *experience* need to differ, or is there no Mac analog? → Adapt (rung 3) or exclude (rung 4).
5. **Build the macOS target** to confirm. iOS compiling proves nothing.
