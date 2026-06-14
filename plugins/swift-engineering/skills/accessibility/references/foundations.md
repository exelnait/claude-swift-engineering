# Accessibility Foundations

The building blocks every screen needs. These are the high-frequency basics;
custom controls, Dynamic Type, reading, and media have their own references.

## Critical Rules

- Provide meaningful labels/hints for icon-only controls and custom components.
- Expose state/value, not just a name, for anything that has one.
- Hide purely decorative content; combine related elements into one.
- Never convey meaning by color alone; maintain readable contrast.
- Respect Reduce Motion / Reduce Transparency / Increase Contrast.
- Prefer system controls — they come with strong accessibility defaults.

## Labels, values, hints, and traits

```swift
// ✅ Icon-only button with a clear label (and a hint only when non-obvious)
Button(action: model.refresh) {
    Image(systemName: "arrow.clockwise")
}
.accessibilityLabel("Refresh")
.accessibilityHint("Reloads the list")   // hint = result, not the action name

// ❌ VoiceOver reads "arrow.clockwise"
Button(action: model.refresh) {
    Image(systemName: "arrow.clockwise")
}
```

```swift
// ✅ A stateful control exposes its value, and uses a trait for role/state
Toggle("Wi-Fi", isOn: $isOn)              // system control: label+value+trait free

Text(statusText)
    .accessibilityLabel("Sync status")
    .accessibilityValue(isSynced ? "Up to date" : "Pending")

customSelectedRow
    .accessibilityAddTraits(.isSelected)  // expose selected state
```

**Label vs. hint:** the label says *what it is* ("Refresh"); the hint says *what
happens* ("Reloads the list"). Keep labels short and free of the control type —
VoiceOver adds "button" from the trait.

## Decorative content and grouping

```swift
// ✅ Hide decorative imagery; combine a row into a single, well-labeled element
HStack {
    AsyncImage(url: article.imageURL) { $0.resizable() } placeholder: { ProgressView() }
        .frame(width: 80, height: 80)
        .accessibilityHidden(true)        // decorative — don't stop on it

    VStack(alignment: .leading) {
        Text(article.title).font(.headline)
        Text(article.author).font(.subheadline).foregroundStyle(.secondary)
    }
}
.accessibilityElement(children: .combine)
.accessibilityLabel("\(article.title), by \(article.author)")
.accessibilityHint("Opens the article")
```

## Custom actions (basic)

Expose secondary actions without extra on-screen buttons. (For text-selection
actions use the `.edit` category — see Reading & Long-Form Text. For multi-axis
controls, see Custom Controls.)

```swift
// ✅ Surface Save/Share as VoiceOver actions on a combined element
articleCard
    .accessibilityElement(children: .combine)
    .accessibilityLabel(article.title)
    .accessibilityAction(named: "Save") { model.save(article) }
    .accessibilityAction(named: "Share") { model.share(article) }
```

## Color, contrast, and motion

```swift
// ✅ Pair color with text/icon so meaning isn't color-only; respect Reduce Motion
Label(isOnline ? "Online" : "Offline",
      systemImage: isOnline ? "checkmark.circle" : "xmark.circle")
    .foregroundStyle(isOnline ? .green : .red)

@Environment(\.accessibilityReduceMotion) private var reduceMotion
content.animation(reduceMotion ? .none : .spring, value: isExpanded)

// ❌ Status conveyed by color alone (invisible to many users)
Circle().fill(isOnline ? .green : .red)
```

Also honor `accessibilityReduceTransparency` for glass/blur-heavy UI and
`colorSchemeContrast == .increased` for contrast-sensitive layouts.

## Summary

1. Label icon-only/custom controls; add hints only when the result isn't obvious.
2. Expose value and state, not just a name.
3. Hide decorative content; combine related elements.
4. Never rely on color alone; keep contrast readable.
5. Respect Reduce Motion / Transparency / Increase Contrast.
6. Prefer system controls for free accessibility.
