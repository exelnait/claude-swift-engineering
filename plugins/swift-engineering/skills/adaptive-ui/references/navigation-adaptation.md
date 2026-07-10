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
