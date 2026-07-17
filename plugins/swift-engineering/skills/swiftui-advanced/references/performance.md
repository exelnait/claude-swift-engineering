# SwiftUI Performance

## Core Principle

Ensure view bodies update quickly and only when needed.

## Two Problems

1. **Long View Body Updates** - Body takes too long
2. **Unnecessary Updates** - Views update when data hasn't changed

## SwiftUI Instrument (Instruments 26)

1. Press **Cmd-I** in Xcode
2. Choose **SwiftUI template**
3. Check **Long View Body Updates** lane (red = priority)

## Problem 1: Long Updates

### Formatter Creation

```swift
// WRONG - creates every render
var body: some View {
    let formatter = NumberFormatter()
    Text(formatter.string(from: price)!)
}

// CORRECT - cache formatters
class Formatters {
    static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f
    }()
}
```

### Complex Calculations

```swift
// WRONG
var body: some View {
    Text("\(data.sorted().last ?? 0)")
}

// CORRECT - compute in model
@Observable class ViewModel {
    var data: [Int] { didSet { maxValue = data.max() ?? 0 } }
    private(set) var maxValue = 0
}
```

### Synchronous I/O

```swift
// NEVER
var body: some View {
    let data = try? Data(contentsOf: url)
}

// CORRECT
.task { data = try? await loadData() }
```

## Problem 2: Unnecessary Updates

Many small updates add up to miss frame deadline.

### Shared Dependencies

```swift
// WRONG - all views depend on whole array
func isFavorite(_ item: Item) -> Bool {
    favorites.contains(item)  // Depends on entire array
}

// CORRECT - per-item view models
@Observable class ItemViewModel { var isFavorite = false }

class ModelData {
    var itemViewModels: [ID: ItemViewModel] = [:]
}
```

### Environment Values

```swift
// WRONG - updates 60x/second
.environment(\.scrollOffset, offset)

// CORRECT - pass directly
ChildView(scrollOffset: offset)
```

## iOS 26 Automatic Wins

Rebuild with iOS 26 SDK:
- 6x faster list loading (100k+ items)
- 16x faster list updates
- Reduced dropped frames
- Nested ScrollView lazy loading

## 30-Minute Diagnostic Protocol

| Step | Time |
|------|------|
| Build Release | 5 min |
| Trigger issue | 3 min |
| Record trace | 5 min |
| Review Long Updates | 5 min |
| Check Cause & Effect | 5 min |
| Identify view | 2 min |

## Before Shipping a Fix

- [ ] Ran SwiftUI Instrument?
- [ ] Know which view is expensive?
- [ ] Can explain why fix helps?
- [ ] Verified in Instruments?

## Key Patterns

**Per-item dependencies:**
```swift
// Each view depends only on its model
@Observable class ItemViewModel { var item: Item }
```

**Formatter reuse:**
```swift
static let dateFormatter: DateFormatter = { ... }()
```

**Cached computations:**
```swift
var data: [Int] { didSet { cached = compute(data) } }
```

## Lazy stacks & scrolling

`LazyVStack`/`LazyHStack` only evaluate and render views intersecting the visible rect; scrolled-off views are removed. That's why they beat `VStack` for long content — but it changes what you can rely on.

### Layout is estimated

- Off-screen subview sizes are **estimated** from the average size of already-placed views and the estimated remaining count.
- A `LazyVStack`'s ideal **width** is its first subview's width (it can't scan every view for the max); a `LazyHStack`'s ideal **height** is likewise its first subview's. Fix sizes for uniform layout — e.g. give variable text a `.lineLimit` and reserve space so longer subtitles aren't cut off.
- The estimated content size and the space above the visible rect are **adjusted during scrolling** (and after an orientation change) as real views load. Scroll offset is derived from these estimates, so it's unstable.

**Avoid depending on absolute content size or content offset.** To show/hide a control on scroll, use relative subview visibility, not the absolute offset:

```swift
// WRONG - absolute offset is estimated; the cutoff point drifts as estimates change
.onScrollGeometryChange(for: Bool.self, of: { $0.contentOffset.y < 100 }) { _, nearTop in
    showScrollButton = nearTop
}

// CORRECT - depends only on which subviews are currently visible
.onScrollTargetVisibilityChange(threshold: 0.8) { visibleIDs in  // confirm exact API/signature against current Apple documentation
    showScrollButton = visibleIDs.contains(topStepID)
}
```

### Pinned section headers

Use the `pinnedViews` parameter so a section header sticks to the top while its section scrolls:

```swift
LazyVStack(pinnedViews: .sectionHeaders) {
    Section {
        ForEach(photos) { PhotoView(photo: $0) }
    } header: {
        ShowcaseHeader()
    }
}
```

### scrollTransition that moves the frame

A lazy stack decides visibility from a view's **original** position. A `scrollTransition` transform that pushes a view out of its frame makes the stack think it's off-screen, so it disappears too early.

```swift
// WRONG - offset moves the view out of its frame; it vanishes while still on screen
.scrollTransition { content, phase in
    content.offset(y: phase.isIdentity ? 0 : 60)
}

// OK - scale leaves the frame in place
.scrollTransition { content, phase in
    content.scaleEffect(phase.isIdentity ? 1 : 0.8)
}
```

Rule: never let a transform push a would-be-invisible view into the visible rect.

### Don't return a dynamic number of subviews from a leaf view

A `ForEach` leaf like `StepView` should resolve to a fixed number of subviews. If its body conditionally returns zero/one/many (an `if` on an environment value, or an optional unwrap), the lazy stack — which addresses subviews **by index** — must keep earlier `StepView`s alive in case the condition shifts the indices. An unrelated environment change can then re-evaluate off-screen bodies, and their state isn't released.

```swift
// WRONG - body returns zero or one subview depending on an environment value
struct StepView: View {
    @Environment(\.detailLevel) private var detailLevel
    let step: Step
    var body: some View {
        if step.detail <= detailLevel {        // dynamic subview count
            StepDiagram(step: step)
        }
    }
}

// CORRECT - filter at the data level so counts/indices are known without building views
@Query(filter: #Predicate<Step> { $0.detail <= 2 }) private var steps: [Step]
// ...
ForEach(steps) { StepView(step: $0) }          // always exactly one subview each
```

Unwrapping an optional in the body (e.g. an `apiToken` environment value that gates the whole body) has the same effect — handle it higher up (show a `ContentUnavailableView` in place of the stack) rather than inside the leaf.

### Prefetching: set up in the initializer, not onAppear

Lazy stacks **prefetch** — they do part of a soon-to-appear view's work (body evaluation, layout) across earlier frames to stay under the frame deadline. Heavy setup in `onAppear` throws that prefetch work away and can force extra views to load, hurting scrolling.

```swift
// WRONG - size and contents change after the view is placed; prefetch work is wasted
.onAppear { setUpEverything() }

// CORRECT - be in a reasonable state from init; start loads in the initializer
init(step: Step) {
    self.step = step
    self.loader = DiagramLoader(id: step.id)   // cache-backed; starts fetching immediately
}
```

`onAppear` is still right when you genuinely need "did appear" — e.g. infinite scroll, where a trailing `ProgressView` fetches the next page:

```swift
ProgressView().onAppear { loadNextPage() }
```

(If the scroll direction reverses, a prefetched view's body may run while `onAppear` never fires — another reason not to hang critical setup off `onAppear`.)

### Row state is discarded when scrolled far away

Scrolled-off views are kept for a few updates, then deleted — and their `@State` goes with them. Don't store data that must survive scrolling in a row's `@State`.

```swift
// WRONG - highlight is lost when the row scrolls away
struct StepView: View {
    @State private var isHighlighted = false
}

// CORRECT - keep it in a model, or bind to an outer view
struct StepView: View {
    @Binding var isHighlighted: Bool
}
```

### Programmatic scrolling

Scrolling to an off-screen target works; the lazy stack estimates the target's position and refines it on every frame of an animated scroll.

```swift
@State private var position = ScrollPosition()
// ...
ScrollView { /* LazyVStack ... */ }
    .scrollPosition($position)

Button("Scroll to Showcase") {
    position.scrollTo(id: showcaseID)  // confirm exact API/signature against current Apple documentation
}
```

Keep it smooth:
- Each `ForEach` element should resolve to **one** subview — then the stack can query the `ForEach` for the target ID (and count subviews near the end) without constructing views. Same fix as above: filter with a `#Predicate` on your `@Query`, not a conditional in the body.
- **Don't change a subview's layout after it appears.** The `onGeometryChange` → `@State` → relayout pattern re-measures after the view is placed and pushes other content down, knocking the stack off the targeted position. Use a custom `Layout` instead.

```swift
// WRONG - measure subtitle, store height, relayout the diagram around it
.onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { subtitleHeight = $0 }

// CORRECT - resolve the relationship in a single pass with a custom Layout
StepLayout { StepDiagram(step: step); StepInstructions(step: step) }
```
