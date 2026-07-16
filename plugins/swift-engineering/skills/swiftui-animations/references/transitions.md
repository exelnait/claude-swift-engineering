# Transitions & Matched Geometry

Transitions animate views **entering and leaving** the hierarchy; matched-geometry animates a view **moving between positions/hierarchies**; content transitions animate a view's *contents* changing in place. Different jobs — pick by what's actually changing.

## `.transition` — insertion & removal

A transition fires only when a view is genuinely inserted or removed (a conditional, or a `ForEach` identity change) **and** the change is animated (Common Mistake #3):

```swift
if showBanner {
    BannerView()
        .transition(.move(edge: .top).combined(with: .opacity))
}
// Trigger with an animation so the transition runs:
withAnimation(.snappy) { showBanner.toggle() }
```

Built-in transitions and composition:

```swift
.transition(.opacity)
.transition(.scale(scale: 0.9, anchor: .center))
.transition(.move(edge: .bottom))
.transition(.push(from: .trailing))            // iOS 16+
.transition(.slide)
.transition(.blurReplace)                       // iOS 17+
// Different insertion vs removal:
.transition(.asymmetric(insertion: .move(edge: .bottom), removal: .opacity))
// Combine:
.transition(.scale.combined(with: .opacity))
```

Custom transitions via the `Transition` protocol (iOS 17+):

```swift
struct RiseTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .offset(y: phase.isIdentity ? 0 : 20)
    }
}
.transition(RiseTransition())
```

## `matchedGeometryEffect` — shared element, same hierarchy

Animate a view flying between two positions in the **same view tree and namespace** (e.g. grid ↔ expanded card within one screen):

```swift
@Namespace private var ns

if selected == nil {
    ForEach(items) { item in
        Thumbnail(item)
            .matchedGeometryEffect(id: item.id, in: ns)
            .onTapGesture { withAnimation(.spring) { selected = item } }
    }
} else {
    DetailCard(selected!)
        .matchedGeometryEffect(id: selected!.id, in: ns)
}
```

Both views share `id` + `in: ns`; SwiftUI interpolates frame/position between them as one appears and the other disappears. It does **not** work across separate screens/hierarchies (Common Mistake #4).

## iOS 18 zoom navigation transition

For a push/present that zooms from a source element into a detail screen, use the paired modifiers instead of `matchedGeometryEffect`:

```swift
@Namespace private var ns

NavigationLink { DetailView(item) }
    .matchedTransitionSource(id: item.id, in: ns)   // on the source

// On the destination:
DetailView(item)
    .navigationTransition(.zoom(sourceID: item.id, in: ns))
```

Also available for `.sheet`/`.fullScreenCover` presentations. This is the right tool for cross-screen shared-element zoom.

## `contentTransition` — contents changing in place

When a view stays but its *content* changes (text, number, image), animate the swap:

```swift
Text(score, format: .number)
    .contentTransition(.numericText())          // rolling digits
    .animation(.snappy, value: score)

Text(label)
    .contentTransition(.interpolate)

Image(systemName: iconName)
    .contentTransition(.symbolEffect(.replace)) // symbol-aware swap
```

## SF Symbol effects

Symbols have built-in, composable animations (iOS 17+):

```swift
Image(systemName: "wifi")
    .symbolEffect(.variableColor.iterative, options: .repeating)   // signal-style
Image(systemName: "bell")
    .symbolEffect(.bounce, value: notificationCount)               // bounce on change
Image(systemName: isLoading ? "arrow.trianglehead.2.clockwise" : "checkmark")
    .contentTransition(.symbolEffect(.replace))
Image(systemName: "heart.fill")
    .symbolEffect(.wiggle, options: .nonRepeating, isActive: isFavorited)
```

Effect families: `.bounce`, `.pulse`, `.variableColor`, `.scale`, `.wiggle`, `.breathe`, `.rotate`, plus `.replace`/`.appear`/`.disappear` for symbol content changes.

## Pitfalls

- **Transition on a view that stays present** → nothing animates; it must actually be inserted/removed (change identity or a conditional).
- **`matchedGeometryEffect` across screens** → use `.navigationTransition(.zoom)`.
- **Forgetting `value:` on `contentTransition`'s animation** → the swap won't animate.
- **Overusing symbol effects** → distracting; reserve motion for meaningful state changes.
