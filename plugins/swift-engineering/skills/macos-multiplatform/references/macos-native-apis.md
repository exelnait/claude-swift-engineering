# macOS-Native APIs: The Concrete Toolkit

The APIs that turn a compiling Mac build into a *native* one. `macos-adaptation.md` is the strategy — how far up the ladder to climb and why; this file is the parts bin — the specific scenes, window-chrome modifiers, controls, and interop patterns you reach for once you've decided to adapt. Everything here is macOS-only or macOS-flavored: gate it with `#if os(macOS)` (or a `PlatformContainer` / bridge) so the shared code stays clean and the iOS build is unaffected.

API coverage distilled from Antoine van der Lee's [SwiftUI-Agent-Skill](https://github.com/AvdLee/SwiftUI-Agent-Skill), cross-checked against Apple's SwiftUI documentation.

## Scene types beyond `WindowGroup`

Pick the scene that matches the window's role — the choice changes app-termination behavior and which menus SwiftUI wires up for free.

| Scene | Use for | Notes |
|---|---|---|
| `WindowGroup` | The main, user-openable content window | Multiple instances, tabbing, automatic **Window** menu. **App keeps running when all windows close.** |
| `WindowGroup(_, for:)` | Data-driven windows (open one per model value) | `openWindow(value:)` opens/raises the window for that `Hashable` value |
| `Window(_, id:)` | A single, unique auxiliary window (inspector, "Connection Doctor") | Only one instance. If it's the *sole* scene, closing it **quits the app**. |
| `UtilityWindow(_, id:)` *(macOS 15+)* | A floating tool palette | Receives `FocusedValues` from the active main window; hides when the app deactivates; ⎋ dismisses |
| `Settings` *(macOS-only)* | Preferences window | Auto-wires **Settings… (⌘,)**; host a `TabView` of panes |
| `MenuBarExtra` *(macOS-only)* | Menu-bar / status-bar utility | `.menu` or `.window` style (below) |
| `DocumentGroup` | Document-based apps | Auto File menu + multi-document windows; needs `FileDocument`/`ReferenceFileDocument` with `readableContentTypes` |

```swift
// Data-driven window: one window per message id.
WindowGroup("Message", for: Message.ID.self) { $messageID in
    MessageDetail(messageID: messageID)
}

// Unique auxiliary window, opened programmatically.
Window("Connection Doctor", id: "connection-doctor") { ConnectionDoctor() }
```

```swift
@Environment(\.openWindow) private var openWindow
openWindow(id: "connection-doctor")       // by id
openWindow(value: message.id)             // by value (matches WindowGroup(for:))
```

**Settings access** *(macOS 14+)* — open the Settings scene from anywhere:

```swift
SettingsLink { Label("Preferences", systemImage: "gear") }   // a button
// or programmatically:
@Environment(\.openSettings) private var openSettings
openSettings()
```

**Menu-bar-only apps** — set `LSUIElement = true` in Info.plist so there's no Dock icon; the app auto-terminates if the `MenuBarExtra` is removed via its `isInserted:` binding.

## Window chrome & styling

All scene-level modifiers, all macOS-only. These give you the polished, chromeless, or utility looks that iOS never needs.

```swift
WindowGroup { ContentView() }
    .windowStyle(.hiddenTitleBar)          // .titleBar (default) | .hiddenTitleBar (custom chrome)
    .windowToolbarStyle(.unified)          // .automatic | .unified | .unifiedCompact | .expanded
    .windowResizability(.contentMinSize)   // .automatic | .contentSize (fixed) | .contentMinSize
    .defaultSize(width: 900, height: 600)
    .defaultPosition(.center)              // .center, .topLeading, .top, .trailing, … 
```

- **`.windowStyle`** — `.hiddenTitleBar` removes the title bar for immersive/custom-chrome windows.
- **`.windowToolbarStyle`** — `.unified` merges title bar + toolbar into one row; `.unifiedCompact` shrinks it; `.expanded` stacks the title above the toolbar for more toolbar space. `.unified(showsTitle: false)` keeps the layout but hides the title text.
- **`.windowResizability`** — `.contentSize` fixes the window to its content and disables the zoom button; `.contentMinSize` enforces the content's `minWidth`/`minHeight` as the floor while staying resizable.
- **`.windowIdealPlacement`** *(macOS 15+)* — compute placement from display geometry:

  ```swift
  .windowIdealPlacement { context in
      let area = context.defaultDisplay.visibleArea
      return WindowPlacement(x: area.midX, y: area.midY,
                             width: area.width / 2, height: area.height)
  }
  ```

- **`.menuBarExtraStyle`** — `.menu` (a dropdown, default) or `.window` (a popover panel hosting arbitrary SwiftUI):

  ```swift
  MenuBarExtra("Status", systemImage: "chart.bar") {
      DashboardView().frame(width: 240)
  }
  .menuBarExtraStyle(.window)
  ```

## Split views, columns, and the inspector

- **`NavigationSplitView`** renders columns *side-by-side* on Mac (never overlaid), with a translucent, user-resizable sidebar. Constrain columns explicitly:

  ```swift
  NavigationSplitView {
      List(items, selection: $selectedID) { Text($0.name) }
          .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
  } detail: {
      DetailView(id: selectedID)
  }
  ```

- **`.inspector(isPresented:)`** *(macOS 14+, also iPadOS)* — a trailing-edge, resizable inspector panel; the Mac-native home for properties/metadata:

  ```swift
  MainContent()
      .inspector(isPresented: $showInspector) {
          InspectorView().inspectorColumnWidth(min: 200, ideal: 250, max: 400)
      }
  ```

- **`HSplitView` / `VSplitView`** *(macOS-only)* — user-draggable dividers between *peer* panes (IDE-style layouts where no pane is a "sidebar"). Constrain with `.frame(minWidth:)`:

  ```swift
  HSplitView {
      FileTreeView().frame(minWidth: 200)
      EditorView().frame(minWidth: 400)
      PreviewPane().frame(minWidth: 200)
  }
  ```

  These have **no iOS equivalent** — gate them (rung 4) or provide a stacked layout on iOS (rung 3).

## macOS-native controls

- **`Table`** — the multi-column, sortable, selectable data grid that defines Mac productivity apps. No first-class iPhone analog (it collapses to a single column), so it's a prime rung-3 adaptation: `Table` on Mac/iPad, a `List` of rows on iPhone.

  ```swift
  Table(people) { /* TableColumn("Name", value: \.name) … */ }
      .tableStyle(.bordered(alternatesRowBackgrounds: true))   // .inset | .bordered | .automatic
      .tableColumnHeaders(.hidden)                             // optionally hide headers
  ```

- **`CopyButton(item:)`** *(macOS 15+)* — a system button that copies `Transferable` content to the pasteboard (cross-platform-friendly alternative to reaching for `NSPasteboard`; see the `XPasteboard` bridge in **Platform Gating** for older targets).

## File access done right

`.fileImporter`/`.fileExporter` are cross-platform (rung 1) — prefer them over `UIDocumentPicker`/`NSOpenPanel`. On Mac (sandboxed) the returned URLs are **security-scoped**: you must bracket access, or reads silently fail.

```swift
.fileImporter(isPresented: $show, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
    guard case .success(let urls) = result, let url = urls.first else { return }
    guard url.startAccessingSecurityScopedResource() else { return }   // REQUIRED on macOS
    defer { url.stopAccessingSecurityScopedResource() }
    // …read the file here…
}
```

Customize the Mac panel (macOS-only modifiers, harmless to gate):

```swift
.fileDialogMessage("Select an image to use as your profile photo")
.fileDialogConfirmationLabel("Use This Photo")
.fileExporterFilenameLabel("Export As:")
```

Prefer **`Transferable`** for drag & drop over legacy `NSItemProvider`:

```swift
Text(item.title).draggable(item)
container.dropDestination(for: MyItem.self) { items, _ in dropped += items; return true }
```

## AppKit interop, in depth

When SwiftUI lacks an API, you drop into AppKit via `NSViewRepresentable` (bridge the type with `PlatformViewRepresentable` from **Platform Gating** when the iOS side needs the same wrapper).

```swift
// With a Coordinator to forward AppKit delegate callbacks into SwiftUI state:
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.delegate = context.coordinator
        return field
    }
    func updateNSView(_ field: NSSearchField, context: Context) { field.stringValue = text }
    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        let text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func controlTextDidChange(_ note: Notification) {
            guard let field = note.object as? NSSearchField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}
```

Going the other direction — host SwiftUI inside an AppKit window/view:

```swift
window.contentViewController = NSHostingController(rootView: MySwiftUIView())
someNSView.addSubview(NSHostingView(rootView: MySwiftUIView()))
```

**Critical:** never set `frame`/`bounds` directly on the `NSView` SwiftUI manages — SwiftUI owns that view's layout, and fighting it produces glitches. Size via SwiftUI modifiers instead.

## Focus for keyboard-driven Mac UIs

Focus is central on Mac (it's how keyboard users move), so features that were tap-only on iOS need real focus wiring here. Depth beyond the input-model table in **macOS Adaptation**:

- **`@FocusState`** — `Bool` for one field, an optional `Hashable` enum for many. Set it to move focus; set `nil` to dismiss.
- **`.defaultFocus($field, .email)`** *(macOS 13+)* — prefer this over writing `@FocusState` in `onAppear`.
- **`.focusable()`** — TextField/SecureField are implicitly focusable; **custom views are not** — add `.focusable()` so they take focus, `onKeyPress`, and menu commands.
- **`.focusSection()` / `.focusScope(_:)`** — group spatially-separated focusables so arrow-key navigation flows correctly.
- **`@FocusedValue` / `@FocusedBinding`** — publish the focused window's selection so menu **`Commands`** act on it (the multi-window model; see **macOS Adaptation**).
- **`.focusEffectDisabled()`** — suppress the system focus ring when you draw your own.

Pitfalls: don't *also* write `@FocusState` from an `onTapGesture` on an already-`.focused()` view (double-write drops focus); never bind the same enum case to two views (SwiftUI warns and picks one).
