# Geometry-Driven Layout

The practical SwiftUI toolkit for laying out against measured space. Pick the lightest tool that answers your question, and always reduce raw geometry to a coarse, `Equatable` decision before you act on it.

> Platform note: `onGeometryChange`, `containerRelativeFrame`, `ViewThatFits`, `AnyLayout`, and the `Layout` protocol are all available on this plugin's iOS 26 baseline. The brand-new *scene*-level APIs live in `scene-geometry.md`.

## Tool selection

| Question | Tool |
|----------|------|
| "Pick the first variant that fits." | `ViewThatFits` |
| "Animate a horizontal↔vertical (or column-count) switch." | `AnyLayout` + a geometry-derived flag |
| "Compute a number from width" (columns, item size, wide flag). | `onGeometryChange` |
| "Size this child as a fraction of its container." | `containerRelativeFrame` |
| "Implement bespoke positioning math." | custom `Layout` |
| "I only need the raw size for one subview and can constrain it." | constrained `GeometryReader` |

## `onGeometryChange` — the default probe

The preferred way to read size. Unlike `GeometryReader`, it does **not** hijack layout — it observes the size the view already got and hands you a value. Reduce the geometry to the smallest `Equatable` type that captures your decision so the action fires only when the meaningful bucket changes.

```swift
// Derive a coarse Bool, not the raw width — no jitter on sub-point changes.
struct AdaptiveShell<Content: View>: View {
    @State private var isWide = false
    @ViewBuilder var content: (Bool) -> Content

    var body: some View {
        content(isWide)
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.size.width >= 700          // your breakpoint, in points of AVAILABLE space
            } action: { newValue in
                isWide = newValue
            }
    }
}
```

Column count from width — the same shape, returning an `Int`:

```swift
@State private var columnCount = 2

LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount)) {
    ForEach(items) { ItemCard(item: $0) }
}
.onGeometryChange(for: Int.self) { proxy in
    max(1, Int(proxy.size.width / 180))          // ~180pt per column, never fewer than 1
} action: { columnCount = $0 }
```

There is also a two-argument `action` form when you need the transition itself (e.g., to animate direction):

```swift
.onGeometryChange(for: Bool.self) { $0.size.width > $0.size.height } action: { wasLandscape, isLandscape in
    // react to the change, with both old and new
}
```

**"Am I landscape?" — never ask the device.** Derive it from the container:

```swift
.onGeometryChange(for: Bool.self) { $0.size.width > $0.size.height } action: { isLandscape = $0 }
```

## `containerRelativeFrame` — size relative to the nearest container

Sizes a view against its **nearest container** (scroll view, safe-area root, list, etc.) without you measuring anything. Two forms:

```swift
// 1) A fraction of the container, computed in a closure.
Image(...)
    .containerRelativeFrame(.horizontal) { length, axis in
        length * 0.8                          // 80% of the container's width
    }

// 2) Carve the container into N slots and span some of them — great for paged carousels.
ScrollView(.horizontal) {
    LazyHStack(spacing: 16) {
        ForEach(pages) { PageCard(page: $0) }
    }
    .scrollTargetLayout()
}
.scrollTargetBehavior(.viewAligned)
// Each card = one full container width → snapping full-width pages, at any window size.
// Apply to the card: .containerRelativeFrame(.horizontal)
```

Reach for this before `GeometryReader` whenever the goal is "a proportion of my container" — it stays correct through resize, Split View, and a foldable's inner display for free.

## `ViewThatFits` — automatic variant selection

SwiftUI renders the **first child that fits** the offered space; put the richest variant first, the most compact last.

```swift
ViewThatFits {
    HStack(spacing: 16) { Icon(); Title(); Spacer(); AddButton() }   // roomy
    VStack(spacing: 8)  { Icon(); Title(); AddButton() }             // tight
}
```

Constrain the axis you care about so it doesn't over-eagerly measure both:

```swift
ViewThatFits(in: .horizontal) { wideRow; narrowRow }
```

Use it for **static** variant selection. It re-measures on every content change and does **not** animate between variants — for an animated switch, use `AnyLayout`.

## `AnyLayout` — animated structural switch

Swap the *layout algorithm* while keeping the *same view identities*, so SwiftUI animates children between positions instead of teardown/rebuild.

```swift
struct CardStack: View {
    @State private var isWide = false

    var layout: AnyLayout {
        isWide ? AnyLayout(HStackLayout(spacing: 20))
               : AnyLayout(VStackLayout(spacing: 12))
    }

    var body: some View {
        layout {
            Avatar(); Details(); Actions()
        }
        .animation(.snappy, value: isWide)
        .onGeometryChange(for: Bool.self) { $0.size.width >= 500 } action: { isWide = $0 }
    }
}
```

Because identities are preserved, `@State` inside each child survives the switch — essential across an iPhone fold/unfold so the user's in-progress input isn't reset.

## Custom `Layout` — when the math is bespoke

For genuinely custom positioning (flow layouts, radial menus, proportional splits) implement `Layout`. It receives the exact proposed size, so it's inherently available-space-driven.

```swift
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // measure using proposal.replacingUnspecifiedDimensions().width — the real available width
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // wrap subviews across lines within bounds.width
    }
}
```

Wrap it in `AnyLayout(FlowLayout())` to animate between it and another layout.

## `GeometryReader` — last resort, and constrain it

`GeometryReader` **greedily fills all offered space** and flattens its children's intrinsic sizing — using it as a casual size probe breaks the layout you're trying to measure. Prefer `onGeometryChange` or `containerRelativeFrame`. If you truly need it:

```swift
// Contain it so it can't distort the surrounding layout.
GeometryReader { geo in
    Ruler(width: geo.size.width)
}
.frame(height: 44)                    // pin the axis you don't need

// Or read size without affecting layout by putting it in a background:
someView
    .background {
        GeometryReader { geo in
            Color.clear.onAppear { measured = geo.size }
        }
    }
```

## Anti-patterns

```swift
// ❌ Trait as width sensor — stays .compact on a wide iPhone/fold window.
if horizontalSizeClass == .regular { TwoColumn() } else { OneColumn() }
// ✅ Measure it.
.onGeometryChange(for: Bool.self) { $0.size.width >= 700 } action: { isWide = $0 }

// ❌ Physical screen — wrong in Split View, Stage Manager, resized iPhone, fold inner display.
let w = UIScreen.main.bounds.width
// ✅ Container size.
.onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }

// ❌ Device model — fails in multitasking/mirroring.
if UIDevice.current.userInterfaceIdiom == .pad { Sidebar() }
// ✅ Respond to space.
if isWide { Sidebar() }

// ❌ Raw width into @State that changes layout → feedback loop / jitter.
.onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 } // then branch on width
// ✅ Reduce to a coarse, Equatable bucket first.
.onGeometryChange(for: Bool.self) { $0.size.width >= 700 } action: { isWide = $0 }
```

## A reusable size bucket

Centralize breakpoints so the whole app agrees on what "wide" means and you tune it in one place:

```swift
enum SizeBucket: Comparable { case compact, medium, wide

    init(width: CGFloat) {
        switch width {
        case ..<520:  self = .compact
        case ..<840:  self = .medium
        default:      self = .wide
        }
    }
}

extension View {
    func sizeBucket(_ action: @escaping (SizeBucket) -> Void) -> some View {
        onGeometryChange(for: SizeBucket.self) { SizeBucket(width: $0.size.width) } action: action
    }
}

// Usage:
.sizeBucket { bucket = $0 }   // bucket drives columns, navigation, density — everywhere, consistently
```

Choose breakpoint numbers from your **content** (how wide a readable text column or a comfortable card is), not from any device's dimensions.
