# Dynamic Type

Dynamic Type lets people choose their text size system-wide (7 default sizes, +5
larger accessibility sizes). Many people customize it, so supporting it is
essential — and building a layout that scales also makes your UI work across
screen sizes, orientations, and platforms.

## Critical Rules

- Use **built-in text styles**, never hard-coded point sizes.
- Allow **unlimited lines** (`lineLimit(nil)` / `numberOfLines = 0`) to avoid
  truncation; let containers grow and scroll.
- **Adapt layout** at accessibility sizes (switch stacks from horizontal to
  vertical) instead of cramming.
- **Scale essential images** with the text; keep purely decorative images fixed
  and wrap text under them.
- For controls that can't grow (tab bars, custom bars), adopt the **Large
  Content Viewer**.
- **Test at the largest accessibility size** with preview variants and audits.

## Scale text with text styles

```swift
// ✅ SwiftUI — semantic text styles scale automatically and keep hierarchy
Text(article.title).font(.title)
Text(article.body).font(.body)
    .lineLimit(nil)            // don't truncate at large sizes
```

```swift
// ✅ UIKit — opt the label into content-size updates and use a preferred font
label.adjustsFontForContentSizeCategory = true
label.font = .preferredFont(forTextStyle: .body)
label.numberOfLines = 0       // as many lines as needed
```

```swift
// ❌ Fixed size ignores the user's setting and clips/truncates
Text(article.title).font(.system(size: 14)).lineLimit(1)
```

## Adapt layout for accessibility sizes

Switch a tight horizontal layout to vertical once an accessibility size is
selected, giving text room to read without truncation.

```swift
// ✅ SwiftUI — resolve a layout from the current Dynamic Type size
struct FigureCell: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let figure: Figure

    private var dynamicLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(HStackLayout())     // image beside text when huge
            : AnyLayout(VStackLayout())     // image above text normally
    }

    var body: some View {
        dynamicLayout {
            Image(figure.symbol)
            Text(figure.title)
        }
    }
}
```

```swift
// ✅ UIKit — flip the stack-view axis on the accessibility category, and
//    re-evaluate when the category changes at runtime.
func updateAxis() {
    stackView.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        ? .vertical : .horizontal
}
// Observe UIContentSizeCategory.didChangeNotification and call updateAxis().
```

## Inline images and symbols

- **Decorative images** (e.g. a settings row glyph): don't scale them; let the
  text wrap under them to use available width. In SwiftUI a `List` row wraps text
  under the icon automatically; outside a list, interpolate the image into the
  `Text`. In UIKit, append an `NSTextAttachment` to an `NSAttributedString`.
- **Essential images** (carry text/iconography that matters): scale them.
  - SF Symbols scale automatically with the text style.
  - For asset images/PDFs in SwiftUI, drive size with `@ScaledMetric`.
  - In UIKit, build the image with
    `UIImage.SymbolConfiguration(textStyle:)`.

```swift
// ✅ Scale an essential asset image with the text size
@ScaledMetric private var iconSize: CGFloat = 24
Image("badge").resizable().frame(width: iconSize, height: iconSize)
```

In rare cases you may drop a purely decorative view at the very largest sizes —
but never remove functionality or essential content.

## Large Content Viewer

For controls that intentionally don't grow (tab bars, toolbars, custom bars),
the Large Content Viewer shows a big label+icon on tap-and-hold. System bars
support it for free; custom bars must opt in.

```swift
// ✅ SwiftUI custom tab item
tabButton
    .accessibilityShowsLargeContentViewer {
        Label(tab.title, systemImage: tab.symbol)
    }
```

In UIKit, conform the view to `UILargeContentViewerItem` (title, image, and
`showsLargeContentViewer`) and add a `UILargeContentViewerInteraction`. If the
control uses its own gesture recognizer, wire up
`gestureRecognizerForExclusionRelationship` so the viewer recognizes first.

## Test it

- **Xcode Previews:** open the canvas Variants ▸ **Dynamic Type Variants** to
  render every size at once, or pick a specific size in canvas settings.
- **Debugger:** override Dynamic Type via the Environment Overrides settings
  icon while running.
- **Audits:** run an accessibility audit (catches clipped/truncated text,
  missing labels, low contrast) and bake `performAccessibilityAudit()` into UI
  tests so regressions are caught every iteration. See Testing & Audits.

## Summary

1. Use text styles; never hard-code sizes.
2. Allow unlimited lines and let content scroll.
3. Adapt layout for accessibility sizes (`AnyLayout` / stack-view axis).
4. Scale essential images (`ScaledMetric`, `SymbolConfiguration`); wrap text
   under fixed decorative images.
5. Adopt the Large Content Viewer for non-scaling controls.
6. Test with preview variants and accessibility audits in CI.
