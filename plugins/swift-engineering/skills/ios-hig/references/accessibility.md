# Accessibility

Apple Human Interface Guidelines for accessible iOS app design.

> **For depth, use the dedicated `accessibility` skill.** This page is a quick
> HIG-level summary. Custom-control accessibility, Dynamic Type, reading /
> long-form text, media captions, inclusive-design principles, and
> testing/audits live in the [`accessibility`](../../accessibility/SKILL.md)
> skill.

## Critical Rules

- Provide meaningful accessibility labels/hints for icon-only controls and custom components
- Ensure Dynamic Type works end-to-end; avoid layouts that collapse at larger sizes
- Maintain readable contrast and avoid conveying meaning by color alone
- Respect platform accessibility settings (Reduce Motion/Transparency) when relevant
- Prefer system controls that come with good accessibility defaults
- For long-form / reading content (paginated articles, books, scanned text), custom controls, Dynamic Type, and media captions, see the [`accessibility`](../../accessibility/SKILL.md) skill

## Examples

### Icon-Only Buttons

```swift
// ✅ Icon-only button with accessible label
Button(action: model.refresh) {
    Image(systemName: "arrow.clockwise")
}
.accessibilityLabel("Refresh")
.accessibilityHint("Reloads the list")

// ❌ Icon-only control with no label; VoiceOver reads "arrow.clockwise"
Button(action: model.refresh) {
    Image(systemName: "arrow.clockwise")
}
```

### Dynamic Type Support

```swift
// ✅ Dynamic Type with proper layout
VStack(alignment: .leading, spacing: 8) {
    Text(item.title)
        .font(.headline)
        .lineLimit(2)

    if let summary = item.summary {
        Text(summary)
            .font(.body)
            .foregroundStyle(.secondary)
            .lineLimit(3)
    }
}

// ❌ Hard-coded sizes that don't scale
VStack(alignment: .leading) {
    Text(item.title)
        .font(.system(size: 14))
        .lineLimit(1)
}
```

### Reduce Motion

```swift
// ✅ Respect Reduce Motion setting
@Environment(\.accessibilityReduceMotion) var reduceMotion

var body: some View {
    content
        .animation(reduceMotion ? .none : .spring, value: isExpanded)
}

// ❌ Always animate regardless of setting
var body: some View {
    content
        .animation(.spring, value: isExpanded)
}
```

## Summary

**Key Principles**:
1. Use `.accessibilityLabel()` and `.accessibilityHint()` for icon-only controls
2. Support Dynamic Type with system font styles
3. Maintain sufficient color contrast
4. Respect accessibility settings like Reduce Motion
5. Prefer system controls with built-in accessibility
6. For anything deeper, use the [`accessibility`](../../accessibility/SKILL.md) skill
