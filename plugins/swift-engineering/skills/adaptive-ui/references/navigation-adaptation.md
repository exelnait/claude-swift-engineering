# Navigation Adaptation

Tab Bar, Sidebar, and split columns are **different presentations of the same navigation hierarchy** (the language Apple established in iPadOS 18). Adapting navigation to available space means changing the *presentation* while keeping the *destinations and selection* identical — so morphing between them never loses the user's place.

## The key idea: one hierarchy, many presentations

Model your top-level destinations **once** as data, and keep the current selection in **shared state**. Then any presentation — Tab Bar (compact), Sidebar + detail (wide), NavigationSplitView (iPad/Mac) — is just a different view over the same two values.

```swift
enum Section: String, CaseIterable, Identifiable, Hashable {
    case home, library, search, settings
    var id: Self { self }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .home: "house"; case .library: "books.vertical"
        case .search: "magnifyingglass"; case .settings: "gearshape"
        }
    }
}

@Observable final class AppRouter {
    var selection: Section = .home
}
```

Because `selection` is shared, switching presentations preserves it: a tap in the compact Tab Bar and a tap in the wide Sidebar drive the exact same state.

## System auto-adaptation (start here)

For many apps the system does the morphing for you — reach for these before hand-rolling anything.

### `TabView` with `.sidebarAdaptable`

A `TabView` automatically becomes a **sidebar** when space allows and a **tab bar** when it doesn't:

```swift
TabView(selection: $router.selection) {
    ForEach(Section.allCases) { section in
        Tab(section.title, systemImage: section.symbol, value: section) {
            SectionRoot(section: section)
        }
    }
}
.tabViewStyle(.sidebarAdaptable)   // tab bar when compact, sidebar when wide — automatically
```

This is the lowest-effort adaptive navigation and the right default on iPad and Mac.

### `NavigationSplitView`

Auto-collapses its columns to a stack when space is tight and expands them when it isn't. Note `List(selection:)` takes an **optional** binding (single selection can be "nothing selected"):

```swift
struct ContentView: View {
    @State private var selection: Section? = .home

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbol)
            }
        } detail: {
            if let selection { SectionRoot(section: selection) }
            else { ContentUnavailableView("Select a section", systemImage: "sidebar.left") }
        }
    }
}
```

On the fold's inner display or a wide iPad window it shows sidebar + detail; folded or in a narrow window it collapses to a single stack — no code from you.

## When to take manual control (the article's strategy)

Automatic morphing is convenient but not always *precisely* what you want — especially on a **resizable iPhone** or a **foldable**, where a wide window is still "an adaptive iPhone experience, not a full iPad product interface." Fatbobman's own app takes explicit control rather than leaning on `.sidebarAdaptable`, to keep the wide-iPhone presentation and interactions fully predictable:

- Use **geometry** to decide whether the app has entered a wide state.
- On an **iPhone host in a wide state**: show a **custom Sidebar** and **hide the Tab Bar** — *avoid* `.sidebarAdaptable` so the wide-window presentation is controlled precisely.
- Sidebar buttons still drive Tab switching through **shared state**.
- On **iPadOS**: do **not** enable this iPhone-specific logic — let system components adapt via their own traits and geometry.
- On **macOS**: drop the Tab structure entirely and use Sidebar navigation directly.

### Implementation

```swift
struct RootView: View {
    @State private var router = AppRouter()
    @State private var isWide = false

    var body: some View {
        adaptiveShell
            // Decide "wide" from AVAILABLE SPACE, not horizontalSizeClass.
            .onGeometryChange(for: Bool.self) { $0.size.width >= 700 } action: { isWide = $0 }
            .animation(.snappy, value: isWide)
            .environment(router)
    }

    @ViewBuilder
    private var adaptiveShell: some View {
        #if os(macOS)
        // macOS: Sidebar navigation directly, no Tab structure.
        NavigationSplitView {
            SidebarList(selection: $router.selection)
        } detail: {
            SectionRoot(section: router.selection)
        }
        #else
        if isWide {
            // Wide (fold unfolded / wide iPhone window / large iPad): custom sidebar + detail.
            HStack(spacing: 0) {
                SidebarList(selection: $router.selection)
                    .frame(width: 260)
                Divider()
                SectionRoot(section: router.selection)
                    .frame(maxWidth: .infinity)
            }
        } else {
            // Compact (fold folded / narrow window): tab bar.
            TabView(selection: $router.selection) {
                ForEach(Section.allCases) { section in
                    Tab(section.title, systemImage: section.symbol, value: section) {
                        SectionRoot(section: section)
                    }
                }
            }
        }
        #endif
    }
}

// Button-driven so a wide iPhone / fold window keeps a non-optional selection in sync
// with the compact TabView — "Sidebar buttons drive Tab switching through state."
struct SidebarList: View {
    @Binding var selection: Section
    var body: some View {
        List(Section.allCases) { section in
            Button {
                selection = section
            } label: {
                Label(section.title, systemImage: section.symbol)
            }
            .buttonStyle(.plain)
            .listRowBackground(section == selection ? Color.accentColor.opacity(0.15) : nil)
        }
        .listStyle(.sidebar)
    }
}
```

`SectionRoot(section:)` is the single source of truth for each destination's content — rendered by whichever presentation is active. Because selection lives in `AppRouter`, folding/unfolding or resizing swaps the shell around it without disturbing the user's position or any in-progress navigation stack.

### `.sidebarAdaptable` vs. manual — how to choose

| Situation | Prefer |
|-----------|--------|
| iPad / Mac, standard destinations, want least code | `.tabViewStyle(.sidebarAdaptable)` or `NavigationSplitView` |
| Resizable iPhone / foldable where the wide presentation must be *exactly* your design | Manual geometry-driven switch (above) |
| Wide window should stay an "enhanced phone" UI, not become an iPad UI | Manual — you decide what "wide" renders |
| You need different breakpoints per surface | Manual — you own the threshold |

## Per-surface behavior matrix

| Surface | Compact state | Wide state | Driver |
|---------|---------------|------------|--------|
| **iPhone fold — folded** | Tab Bar | — | geometry (narrow inner/outer) |
| **iPhone fold — unfolded** | — | Custom Sidebar + detail | geometry (wide inner display) |
| **Resizable iPhone (Mac mirroring / on iPad)** | Tab Bar when narrow | Custom Sidebar when wide | geometry — **not** size class (stays `.compact`) |
| **iPad (Split View / Slide Over / Stage Manager)** | System collapses columns | System sidebar / split | Let system components adapt (their own traits + geometry) |
| **macOS** | — | Sidebar navigation directly | Platform (`#if os(macOS)`) |

## Continuity across a fold or resize

Morphing must feel continuous — the user was mid-task when the window changed:

- Keep **selection and navigation paths in shared `@Observable` state** (`AppRouter`), never in the shell views that get swapped.
- Prefer `AnyLayout`/preserved identities over `if/else` that rebuilds subtrees, so in-progress input and scroll position survive (see `geometry-driven-layout.md`).
- Animate the transition (`.animation(.snappy, value: isWide)`) so the change reads as one interface reflowing, not two interfaces swapping.
- Don't reset the navigation stack on width change — a `NavigationStack`'s `path` should live in the router and persist through the morph.

## The tab/sidebar building blocks (iPadOS 18)

The adaptations above morph between *presentations*; this is the model they present. iPadOS 18 builds the whole tab-bar/sidebar story from one small set of primitives — the same objects feed the compact tab bar, the wide sidebar, and every morph between them.

**SwiftUI — `Tab` and `TabSection`.** A `Tab` takes a title, an image, and its content view, plus an optional `value:` for programmatic selection (all tabs share one selection type, matching the `TabView`). `Tab(role: .search)` is special: the system gives it a default title and magnifying-glass image and *pins* it to the **trailing edge** of the tab bar. (This talk describes only that default identity and pinned placement — it does not say the search tab expands into a search field, so treat that behavior as unconfirmed here.) `TabSection` wraps child tabs into a named **sidebar group**; individual tabs keep their declared order in the tab bar, and in the sidebar all sections sort *after* the loose tabs.

```swift
TabView {
    Tab("Home", systemImage: "house") { HomeRoot() }

    Tab(role: .search) { SearchRoot() }          // system title + glyph, pinned to the trailing edge

    TabSection("Library") {                       // a named group → a sidebar section
        Tab("Recently Added", systemImage: "clock") { … }
        Tab("Artists", systemImage: "music.mic") { … }
    }
}
.tabViewStyle(.sidebarAdaptable)                  // one hierarchy → tab bar or sidebar
// add `value:` to each Tab (as in the examples above) for programmatic selection
```

**UIKit — `UITab`, `UITabGroup`, `UISearchTab`.** Create a `UITab` per top-level section and assign them to `tabBarController.tabs`; mutating a `UITab` updates its display immediately. `UITabGroup` is the analogue of `TabSection` (update its `children` directly for dynamic content) and `UISearchTab` is the search-role tab. Set the controller's `mode` to `.tabSidebar` to present the bar as an adaptable sidebar — the UIKit counterpart of `.sidebarAdaptable`.

```swift
tabBarController.tabs = [homeTab, searchTab, libraryGroup]   // UITab, UISearchTab, UITabGroup
tabBarController.mode = .tabSidebar                           // present as an adaptable sidebar
```

**Filled vs. outlined glyphs.** Tab bars prefer **filled** SF Symbols; sidebars prefer **outlined**. Provide the **outline** symbol only — the system substitutes the filled variant automatically in the tab bar (e.g. Music's Browse tab ships `square.grid.2x2` and shows filled in the bar). No second image, no per-presentation branching.

## User customization

With the hierarchy modeled, iPadOS 18 lets *people* reshape it — hiding non-essential tabs, reordering groups, and dragging tabs between the sidebar and the tab bar. **Order and visibility persist automatically.**

**The three tab-bar sections.**
- **Fixed** — essential destinations; appear first, cannot be customized.
- **Customizable** — can be rearranged; users drag tabs in from the sidebar or off the bar.
- **Pinned** — always at the trailing edge (e.g. search).

**SwiftUI.** Attach a `TabViewCustomization` to the `TabView` to opt its tabs into customization, and back it with `@AppStorage` (via an identifier) so choices persist across launches; read from it if other UI must mirror the current arrangement. Then, per tab:
- `customizationID(_:)` — lets a tab participate in customization (required for customizable tabs; tabs that can't be customized don't need one).
- `customizationBehavior(_:for:)` — disable customization for essential tabs, per `.sidebar` and/or `.tabBar`, to keep them fixed.
- `defaultVisibility(_:for:)` — hide a tab from the sidebar or tab bar by default.
- `sidebarOnly` placement — a tab that can never be dragged into the tab bar; reachable only from the sidebar.

```swift
@AppStorage("tabs") private var customization = TabViewCustomization()

TabView(selection: $router.selection) {
    Tab(Section.home.title, systemImage: Section.home.symbol, value: Section.home) {
        SectionRoot(section: .home)
    }
    .customizationBehavior(.disabled, for: .sidebar, .tabBar)   // essential → fixed

    Tab(Section.library.title, systemImage: Section.library.symbol, value: Section.library) {
        SectionRoot(section: .library)
    }
    .customizationID("tab.library")

    Tab(Section.settings.title, systemImage: Section.settings.symbol, value: Section.settings) {
        SectionRoot(section: .settings)
    }
    .customizationID("tab.settings")
    .defaultVisibility(.hidden, for: .tabBar)                   // in the sidebar, hidden from the bar until added
}
.tabViewStyle(.sidebarAdaptable)
.tabViewCustomization($customization)
```

**UIKit.** Customization is per-`UITab`, and stored customizations are re-applied automatically when tabs are assigned to the controller:
- `allowsHiding` — permit a non-essential tab to be hidden; read back the current state from `isHidden`.
- `preferredPlacement` — control a tab's customization behavior and tab-bar visibility (the analogue of fixed / `sidebarOnly` placement).
- `allowsReordering` — permit reordering within a group; read the resulting order from `displayOrderIdentifiers`.
- Two `UITabBarControllerDelegate` callbacks fire when customization completes, reporting the new visibility and order.

## Tabs as drop destinations

A tab — in either the tab bar or the sidebar — can accept drag-and-drop, e.g. dropping a photo onto a collection to add it.

**SwiftUI:** the `dropDestination` modifier on the `Tab`, typed by the receiver:

```swift
Tab("Library", systemImage: "books.vertical", value: Section.library) {
    SectionRoot(section: .library)
}
.dropDestination(for: Photo.self) { photos in
    library.add(photos)
    return true
}
```

(The talk names the modifier and its receiver type but not the exact closure signature — confirm the parameters against the SDK.)

**UIKit:** implement two `UITabBarControllerDelegate` methods — one that returns a valid drop operation when the drop can be accepted (the talk's `operationForAcceptingItemsFromDropSession`) and one that loads the data from the session (`acceptItemsFromDropSession`). Those are the talk's shortened names; the real selectors are the `tabBarController(_:…)` delegate forms.

## Cross-platform presentation

The same `Tab` / `UITab` hierarchy renders in each platform's native chrome — model once, present everywhere:
- **macOS Sequoia** — if the `TabView` / `UITabBarController` supports a sidebar, it adopts the **standard Mac sidebar**, with drag-to-reorder like iPad. (Consistent with this file's macOS guidance to navigate via the sidebar directly.)
- **visionOS 2** — root tabs appear in an **ornament on the window's leading edge**, and the system still picks filled symbol variants. A `TabSection` / `UITabGroup` additionally gets a **sidebar** alongside the group's content for secondary navigation within the group.
- **tvOS 18** — SwiftUI `TabView` + `TabSection` adopt the new **collapsible sidebar**.

These are the primitives the available-space adaptation earlier in this file morphs between: define the hierarchy once with `Tab` / `TabSection` (or `UITab` / `UITabGroup`), and the tab bar, sidebar, split view, and each platform's chrome all become presentations of it.
