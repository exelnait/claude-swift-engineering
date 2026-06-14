# Custom Control Accessibility

Custom controls let people do unique things with gestures that go beyond standard
controls — but a custom view is invisible to assistive technology until you
describe it. Apply the four guiding principles (**purpose, value, actions,
feedback**) and choose the right interaction model.

## Critical Rules

- Mark the control as an accessibility element and give it a **label** and, if it
  has a value, an **accessibilityValue**.
- Pick an interaction model that fits the control:
  - One-axis value → **`.adjustable` + `accessibilityAdjustableAction`**
  - Multi-axis / discrete operations → **custom actions**
  - Free-form gesture surfaces → **direct touch**
  - Fine-grained continuous value → **passthrough gesture** (activation point)
- **Never rely on a single hard-to-perform gesture.** Direct touch and
  passthrough aren't possible for everyone — always *also* expose custom actions.
- Give **feedback** as the value changes (announce meaningfully, not noisily).

## Single-axis value — adjustable

For a slider-like control, use the `.adjustable` trait plus an adjustable action.
VoiceOver then says "adjustable" and lets people swipe up/down to change it.

```swift
struct CoffeeDispenserView: View {
    @State private var ounces: Double = 6

    var body: some View {
        CoffeeSlider(ounces: $ounces)
            .accessibilityElement()
            .accessibilityLabel("Coffee Dispenser")             // purpose
            .accessibilityValue("\(Int(ounces)) ounces")        // value
            .accessibilityAddTraits(.adjustable)                // action: adjustable
            .accessibilityAdjustableAction { direction in       // action handler
                switch direction {
                case .increment: ounces = min(ounces + 1, 12)
                case .decrement: ounces = max(ounces - 1, 0)
                @unknown default: break
                }
            }
    }
}
```

### Passthrough gesture for fine-grained control

VoiceOver's passthrough (double-tap-and-hold, then drag) sends touches straight
to the control, starting at its **activation point**. Set the activation point to
match the current value so dragging works in both directions, and announce
changes — but throttle them so it isn't noisy.

```swift
// Start the passthrough at the current fill level, not the center.
slider
    .accessibilityActivationPoint(activationPoint(for: ounces, in: trackFrame))

// Announce meaningful changes only (value actually changed AND ≥0.3s elapsed).
private func announceIfNeeded(_ newValue: Double) {
    guard newValue != lastSpokenValue,
          Date.now.timeIntervalSince(lastSpokenAt) >= 0.3 else { return }
    lastSpokenValue = newValue
    lastSpokenAt = .now
    AccessibilityNotification.Announcement(
        "\(String(format: "%.1f", newValue)) ounces"
    ).post()
}
```

## Multi-axis / discrete operations — custom actions

The adjustable trait covers one axis. For a 2D control (e.g. an equalizer pad
with frequency × amplitude), expose discrete operations as custom actions —
VoiceOver lets people swipe up/down to pick an action and double-tap to perform
it. This also makes the control reachable by Switch Control and Voice Control.

```swift
equalizerPad
    .accessibilityLabel("Filter chart")
    .accessibilityValue("Frequency \(frequency), amplitude \(amplitude)")
    .accessibilityAction(named: "Move up")    { adjust(amplitude: +step) }
    .accessibilityAction(named: "Move down")  { adjust(amplitude: -step) }
    .accessibilityAction(named: "Move right") { adjust(frequency: +step) }
    .accessibilityAction(named: "Move left")  { adjust(frequency: -step) }
// each adjust(...) clamps within the control's range
```

## Free-form gesture surfaces — direct touch

When a control supports many/repeated gestures (pat, tap, pinch on a virtual
pet), passthrough is awkward. Mark the region as a direct-touch area so touches
go straight to the control and people can use all its gestures.

```swift
virtualCat
    .accessibilityLabel("Virtual Cat")                 // purpose
    .accessibilityValue(reaction.description)           // value/feedback
    .accessibilityDirectTouch(options: .requiresActivation)
```

Direct-touch options:
- **`.requiresActivation`** — ignore touches until the user double-taps, so they
  can move a finger across the screen without triggering the control. Stays
  active until focus leaves the element.
- **`.silentOnTouch`** — VoiceOver stays silent while touching, for controls that
  produce their own audio (so speech doesn't talk over it).

> Not everyone can perform direct-touch gestures — pair it with custom actions so
> the same interactions are reachable another way.

### UIKit equivalent

Use the `allowsDirectInteraction` accessibility trait to mark a direct-touch
region; set `accessibilityActivationPoint` for passthrough; provide
`UIAccessibilityCustomAction`s for discrete operations; and post
`UIAccessibility.post(notification: .announcement, argument:)` for feedback.

## Summary

1. Mark custom controls as accessibility elements with a label (+ value).
2. Match the interaction to the control: adjustable (1 axis), custom actions
   (multi-axis/discrete), direct touch (free-form gestures), passthrough
   (fine-grained continuous).
3. Always provide a non-gesture path (custom actions) alongside direct
   touch/passthrough.
4. Set the activation point to the current value for passthrough.
5. Announce changes meaningfully and throttle them.
6. Verify with VoiceOver, Switch Control, and Voice Control.
