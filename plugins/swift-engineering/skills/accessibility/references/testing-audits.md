# Accessibility Testing & Audits

Accessibility is verified, not assumed. Combine a quick manual pass with
automated audits so regressions are caught every iteration.

## Manual pass (do this first)

Turn on the assistive tech and try to complete the *actual* task — not just read
labels:

- **VoiceOver** — swipe through the screen: does every element announce a clear
  purpose, value, and available actions? Use the rotor (headings, links, lines,
  text selection) to navigate. For reading content, try the read-all gesture.
- **Dynamic Type** — set the largest accessibility size (Settings ▸ Accessibility
  ▸ Display & Text Size ▸ Larger Text, or the Control Center control). Nothing
  truncated, clipped, or overlapping; layout adapts.
- **Switch Control / Voice Control** — can every action be reached and triggered
  without the intended gesture? (This is why custom controls also need custom
  actions.)
- **Reduce Motion / Transparency / Increase Contrast** — verify the UI respects
  them.

## Automated audit in UI tests

`performAccessibilityAudit()` walks the view hierarchy and flags clipped/
truncated text, missing labels, low contrast, hit-region, and element issues.
Bake it into UI tests so every iteration is checked.

```swift
import XCTest

final class AccessibilityAuditTests: XCTestCase {
    func testHomeScreenHasNoAccessibilityIssues() throws {
        let app = XCUIApplication()
        app.launch()
        // Audit everything:
        try app.performAccessibilityAudit()
    }

    func testReaderScreenContrastAndDynamicType() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Open Article"].tap()
        // Scope to specific audit types when you want a focused check:
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType])
    }
}
```

When the audit reports an issue you've consciously accepted, handle it in the
audit's issue-handler closure and return whether to ignore it — but prefer
fixing over suppressing, and record anything deferred as **inclusion debt**.

## Xcode tooling

- **SwiftUI Previews:** canvas ▸ Variants ▸ **Dynamic Type Variants** renders
  every text size at once to spot truncation/clipping fast; or pick a specific
  size in canvas settings.
- **Environment Overrides** (running app, debug bar settings icon): toggle
  VoiceOver-relevant settings, Dynamic Type, contrast, etc. live.
- **Accessibility Inspector** (macOS): inspect the element tree, run an audit,
  and check labels/traits/contrast for any running app or simulator.

## Definition of done

- [ ] Every interactive element has a label; stateful ones expose value/state.
- [ ] Custom controls follow purpose / value / actions / feedback and have a
      non-gesture path (custom actions).
- [ ] Layout holds at the largest accessibility Dynamic Type size.
- [ ] Color is never the only signal; contrast passes.
- [ ] Reduce Motion / Transparency / Increase Contrast respected.
- [ ] Media has subtitle selection (and style preview) where applicable.
- [ ] `performAccessibilityAudit()` passes in UI tests.
- [ ] Known gaps recorded as inclusion debt with a plan to close them.

## Summary

1. Manually drive the app with VoiceOver, large Dynamic Type, and Switch/Voice
   Control before shipping.
2. Add `performAccessibilityAudit()` to UI tests and run it in CI.
3. Use preview Dynamic Type variants, Environment Overrides, and the
   Accessibility Inspector during development.
4. Fix issues; track what you defer as inclusion debt.
