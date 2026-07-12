# macOS Adaptation: Reaching the Maximum

Compiling on Mac is the floor (the minimum contract). This file is about the ceiling: making the feature feel like it was *made* for the Mac — the difference between a resized iPad app and a real Mac app. Everything here is rung 3 (Adapt) work. Apply it deliberately; note when you skip it.

## Scenes: the app's window structure

An iOS app is essentially one full-screen scene. A Mac app is a composition of scenes, and SwiftUI gives you the pieces declaratively in the `App` body. Add them for Mac without harming iOS.

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 700, minHeight: 480)   // Mac: enforce a sane minimum
        }
        .windowResizability(.contentMinSize)            // Mac: window can't shrink below content min
        .defaultSize(width: 1000, height: 680)          // Mac: first window opens at a good size
        .commands { AppCommands() }                     // Mac: real menu-bar items + shortcuts (harmless on iOS)

        #if os(macOS)
        Settings {                                      // Mac: wires up the ⌘, Settings window automatically
            SettingsView()
        }
        #endif
    }
}
```

- **`WindowGroup`** — the main document/content window. `.frame(minWidth:minHeight:)` on its root gives Mac a floor; `.defaultSize` and `.windowResizability(.contentMinSize)` make new windows open well and resize sanely. These modifiers are no-ops or harmless on iOS.
- **`Settings { }`** — the macOS Settings/Preferences scene. It automatically adds the **Settings… (⌘,)** menu item and hosts your preferences UI in the standard Mac window. On iOS you instead surface settings as a screen; this is a classic rung-3 adaptation (see the split-view example in **Platform Gating**).
- **`MenuBarExtra { } label: { }`** — a menu-bar (status-bar) utility, if your app warrants one. macOS-only; gate with `#if os(macOS)`.
- **`.commands { }`** — populates the **Mac menu bar** and defines keyboard shortcuts. Cross-platform API: on iOS the commands back hardware-keyboard shortcuts; on Mac they become visible menu items. Always model repeatable actions here.

## Menu commands and keyboard shortcuts

Mac users navigate by menu and keyboard. Every repeatable action should have a command and a shortcut.

```swift
struct AppCommands: Commands {
    @FocusedValue(\.document) private var document: Document?
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Note") { /* … */ }
                .keyboardShortcut("n", modifiers: .command)     // ⌘N
        }
        CommandMenu("Note") {
            Button("Refresh") { /* … */ }.keyboardShortcut("r") // ⌘R — the Mac answer to pull-to-refresh
            Button("Pin") { /* … */ }.keyboardShortcut("p", modifiers: [.command, .shift])
        }
    }
}
```

- Attach `.keyboardShortcut(_:modifiers:)` to buttons *inside views* too, not only in `Commands`; SwiftUI surfaces them appropriately.
- Use `@FocusedValue` / `@FocusedBinding` so menu commands act on the currently focused window/selection — the standard Mac multi-window model.
- Provide `Cancel`/`Done` in dialogs with `.cancellationAction`/`.confirmationAction` placements so Escape and Return work.

## The pointer + keyboard input model

iOS is touch-first; Mac is pointer-and-keyboard-first. A feature that only answers taps, swipes, and long-presses is a poor Mac citizen even when it compiles.

| Interaction | iOS habit | Add for Mac |
|---|---|---|
| Reveal actions | swipe / long-press | `.contextMenu { }` (right-click) — cross-platform, essential on Mac |
| Feedback on aim | (n/a) | `.onHover { hovering in … }` for hover highlight/affordance |
| Trigger action | tap | `.keyboardShortcut(_:)` in addition to the button |
| Selection & focus | tap | `@FocusState`, `.focusable()`, arrow-key navigation, `.focused()` |
| Confirm/cancel | button tap | `.confirmationAction` / `.cancellationAction` so ⏎/⎋ work |
| Drag content | drag gesture | `.draggable` / `.dropDestination` (cross-platform, expected on Mac) |

Right-click context menus and hover are the two highest-value additions — cheap to add, and their absence is immediately noticeable on Mac.

## Navigation shells

- Prefer **`NavigationSplitView`** for list-detail features. It renders as a native sidebar + detail on Mac, adapts to columns on iPad, and collapses on iPhone — one structure, correct everywhere.
- If you use `TabView` for top-level sections, add **`.tabViewStyle(.sidebarAdaptable)`** so it becomes a sidebar on Mac/iPad instead of a bottom bar.
- Toolbars: use **semantic** `ToolbarItem` placements (`.primaryAction`, `.confirmationAction`, …); they land in the Mac window toolbar correctly. Avoid `.navigationBarTrailing` etc. (see **API Divergence**).
- See the `adaptive-ui` skill for laying out the detail pane against a resizable Mac window rather than a fixed phone width — the two skills are complementary: this one keeps you *building*, `adaptive-ui` keeps you *laying out*.

## Windows, sizing, and multiple windows

- Mac windows are large, resizable, and multiple. Never assume one window or a fixed size.
- Express **constraints, not fixed frames**: `.frame(minWidth:idealWidth:maxWidth:minHeight:…)`, `.windowResizability(.contentMinSize)`, `.defaultSize`.
- Support additional windows with `@Environment(\.openWindow)` and `WindowGroup(id:)`/`Window(id:)` where it fits the feature (e.g. a detached inspector). Model state so a second window doesn't corrupt the first.
- `.defaultPosition(.center)` and `.windowStyle` / `.windowToolbarStyle` polish the Mac presentation.

## App sandbox, entitlements, and file access

The Mac target is sandboxed by default and grants nothing implicitly. Features that "just work" on iOS may need entitlements on Mac:

- **Network access** → `com.apple.security.network.client` (and `.server` if you listen).
- **User-selected files** → `com.apple.security.files.user-selected.read-write`; reach files through `.fileImporter`/`.fileExporter` (which vend security-scoped URLs) rather than assuming raw path access.
- **Camera/microphone** → the respective device entitlements *and* usage-description strings.
- Keep the Mac entitlements file in the macOS target and review it whenever you add a capability. A missing entitlement shows up as a silent runtime failure, not a build error — so it won't be caught by the minimum-contract build alone.

## Lifecycle and app delegate

- There is no `UIApplicationDelegate` on Mac. If you need app-level hooks, use **`NSApplicationDelegateAdaptor`** (Mac) / `UIApplicationDelegateAdaptor` (iOS), each behind its own `#if`.
- Prefer SwiftUI lifecycle: `@Environment(\.scenePhase)`, `.onChange(of: scenePhase)`, `.task`, and scene modifiers — these are cross-platform and avoid a delegate entirely for most needs.
- `ScenePhase` values differ subtly (Mac backgrounds windows independently); don't hang critical logic on a single "did enter background" assumption.

## How far up the ladder should this feature go?

Not every feature earns a `Settings` scene and a `MenuBarExtra`. Calibrate:

- **Every feature** must build and launch on Mac (minimum) and use semantic toolbar placements + `.contextMenu` where actions exist (cheap wins).
- **Interactive/list features** should get hover, keyboard shortcuts, and a split-view shell.
- **App-level structure** (settings, top-level nav, multi-window) is where the biggest "feels native" gains live — invest there.

When you consciously stop short of an adaptation, that's fine — but *know* you did, so "builds on Mac" is a decision, not an accident.
