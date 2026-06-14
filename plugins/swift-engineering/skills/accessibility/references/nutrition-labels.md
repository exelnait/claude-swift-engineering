# Accessibility Nutrition Labels Readiness

Accessibility Nutrition Labels let you declare, on your App Store product page,
which accessibility features your app supports — so people can be confident it
works for them *before* downloading. Only claim a feature your app genuinely
supports **across its primary tasks**; an inaccurate label erodes trust. Use this
as the readiness checklist before declaring support.

## The nine features

| Category | Feature | Declare it when… |
|----------|---------|------------------|
| Interaction | **VoiceOver** | All content/functionality is reachable and usable with VoiceOver |
| Interaction | **Voice Control** | Every interactive element is operable by voice (good labels, alternatives to gestures) |
| Visual | **Larger Text** | Text scales with Dynamic Type and stays legible **up to at least 200%**, no truncation/overlap |
| Visual | **Sufficient Contrast** | Text/meaningful UI meets contrast guidelines |
| Visual | **Dark Interface** | The app supports a dark appearance |
| Visual | **Differentiate Without Color Alone** | Meaning is never conveyed by color alone |
| Visual | **Reduced Motion** | The app honors Reduce Motion for non-essential animation |
| Media | **Captions** | Media with speech provides captions/subtitles |
| Media | **Audio Descriptions** | Video provides a described-video audio track |

> Start with **VoiceOver**. Its API foundation (labels, traits, values, actions)
> also powers Voice Control, Switch Control, Full Keyboard Access, and Head/Eye
> Tracking — so good VoiceOver support gets you most of the way to the
> interaction labels.

## VoiceOver readiness

Swipe through every screen: VoiceOver must be able to focus all content, and for
each element read its **label**, **traits**, and **value** where applicable.

- **Label** — a name for the element (`accessibilityLabel`). Text views get one
  automatically; images/graphics need one you write. Describe what's shown;
  for image buttons describe the *action* ("Favorite", not "Heart"). Don't put
  the role ("button"/"image") in the label — the trait supplies it.
- **Traits** — the role/state (`accessibilityAddTraits`, e.g. `.isHeader`,
  `.isButton`). Give visually-weighted headings the header trait.
- **Value** — the current state for things that have one
  (`accessibilityValue`), e.g. a text field's contents or a rating; keep the
  label as the field's *name*.
- **Streamline focus** — hide decorative images (`Image(decorative:)` /
  `accessibilityHidden(true)` / UIKit `isAccessibilityElement = false`) and
  combine logical groups (`accessibilityElement(children: .combine)`) so people
  don't swipe through redundant pieces.
- **Custom controls** — give a label + value + actions; or borrow a system
  control's behavior with `accessibilityRepresentation { Slider(...) }`.
- **Custom gestures** — anything driven by a tap recognizer instead of a Button
  needs the `.isButton` trait; multi-touch/swipe/drag gestures need an
  `accessibilityAction` alternative (VoiceOver/Voice Control users may not be
  able to perform the raw gesture).

See `foundations.md` and `custom-controls.md` for full examples.

## Voice Control readiness

People speak the element's name to act on it, so accurate labels are essential.
When an element could be referred to several ways, provide alternates:

```swift
favoriteButton
    .accessibilityLabel("Favorite")
    .accessibilityInputLabels(["Favorite", "Heart", "Like", "Love"])
```

Ensure every action has a non-gesture path (button trait / custom actions) since
Voice Control users may not touch the screen.

## Larger Text readiness (≥ 200%)

To claim Larger Text, content must scale with Dynamic Type and remain legible
**to at least 200%** without truncating or overlapping (default 100% → 135%;
accessibility sizes go to 310%).

- Use system text styles (`.font(.body)`; UIKit `preferredFont(forTextStyle:)` +
  `adjustsFontForContentSizeCategory = true`). Different styles scale at
  different rates but keep their relative hierarchy.
- Custom fonts can scale too: SwiftUI `.font(.custom(name, size:, relativeTo:))`;
  UIKit `UIFontMetrics(forTextStyle:).scaledFont(for:)`.
- Allow unlimited lines; adapt layout at accessibility sizes (a 1×2 control
  growing to 1×4 for text room). Start at design time — agree that text scales
  and layouts may change.
- Verify with Xcode Preview Dynamic Type variants.

See `dynamic-type.md` for the full treatment.

## Sufficient Contrast readiness

Meet contrast guidelines for text and meaningful UI; verify with an accessibility
audit (`performAccessibilityAudit(for: [.contrast])`) and the Accessibility
Inspector. Honor the Increase Contrast setting
(`colorSchemeContrast == .increased` / `accessibilityContrast`) where you tune
colors yourself.

## Dark Interface readiness

Support a dark appearance: use semantic system colors and asset-catalog colors
with light/dark variants — never hard-code light-only colors. Verify the app in
Dark Mode across all screens.

## Differentiate Without Color Alone readiness

Never let color be the only signal. Pair it with text, shape, or an SF Symbol
(e.g. ✓/✗ icons, not just green/red). Respect the setting:

```swift
@Environment(\.accessibilityDifferentiateWithoutColor) private var diffWithoutColor
// add an icon/shape cue when diffWithoutColor is true
```

## Reduced Motion readiness

Gate non-essential animation on Reduce Motion (provide a cross-fade or no
animation instead of large motion/parallax):

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
content.animation(reduceMotion ? .none : .spring, value: state)
```

## Captions & Audio Descriptions readiness (media apps)

- **Captions** — provide caption/subtitle tracks and selection UI during
  playback (`AVPlayerViewController` / `AVLegibleMediaOptionsMenuController` /
  custom). See `media-captions.md`.
- **Audio Descriptions** — include a described-video audio track and let people
  select it (media option with the
  `AVMediaCharacteristic.describesVideoForAccessibility` characteristic; system
  players surface it automatically).

## Pre-submission checklist

- [ ] VoiceOver can focus all content; every element reads label + traits +
      value; decorative images hidden; logical groups combined.
- [ ] No interaction depends on a gesture VoiceOver/Voice Control can't perform;
      `accessibilityInputLabels` added where names vary.
- [ ] Text scales with Dynamic Type and holds at ≥ 200% (ideally to 310%).
- [ ] Contrast passes the audit; Increase Contrast respected.
- [ ] Full Dark Mode support via semantic/asset colors.
- [ ] No color-only meaning; Differentiate Without Color respected.
- [ ] Reduce Motion respected for non-essential animation.
- [ ] (Media) captions + selection UI; described-video track for Audio
      Descriptions.
- [ ] `performAccessibilityAudit()` passes in UI tests (see `testing-audits.md`).
- [ ] Only declare the labels every check above confirms — track the rest as
      inclusion debt.

## Summary

Declare only what you truly support. VoiceOver-first gets you both interaction
labels; Dynamic Type to ≥200% earns Larger Text; semantic colors + audits cover
Contrast, Dark Interface, and color-independence; honoring Reduce Motion covers
Reduced Motion; caption tracks/selection and described video cover the media
labels. Verify everything with a manual pass plus an automated audit before
submitting.
