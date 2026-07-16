# Controls (Control Center / Lock Screen / Action Button)

Controls (iOS 18+) put a **button or toggle bound to an `AppIntent`** into Control Center, the Lock Screen, and the Action Button — system surfaces your app can extend without being open. Like widgets, they live in the widget extension and share your app's intent vocabulary.

## Control widget

Add a `ControlWidget` to the widget bundle. It vends a `ControlWidgetButton` (fire an intent) or `ControlWidgetToggle` (stateful on/off).

```swift
import WidgetKit
import AppIntents

struct StartTimerControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.example.startTimer") {
            ControlWidgetButton(action: StartTimerIntent()) {
                Label("Start Timer", systemImage: "timer")
            }
        }
        .displayName("Start Timer")
        .description("Starts a focus timer.")
    }
}
```

A stateful toggle reads its value from a provider:

```swift
struct FocusToggleControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: "com.example.focus", provider: Provider()) { value in
            ControlWidgetToggle(
                "Focus",
                isOn: value.isOn,
                action: SetFocusIntent()
            ) { isOn in
                Label(isOn ? "Focus On" : "Focus Off", systemImage: isOn ? "moon.fill" : "moon")
            }
            .controlWidgetActionHint(value.isOn ? "Turn Off" : "Turn On")
        }
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: FocusConfigIntent) -> Value { Value(isOn: false) }
        func currentValue(configuration: FocusConfigIntent) async throws -> Value {
            Value(isOn: await FocusStore.shared.isOn)      // read shared (App Group) state
        }
        struct Value { let isOn: Bool }
    }
}
```

## Configuration types

- **`StaticControlConfiguration`** — fixed control, no per-instance config.
- **`AppIntentControlConfiguration`** — the control's value/state comes from an `AppIntentControlValueProvider` (async `currentValue`), optionally configurable via a `ControlConfigurationIntent`.

## Behavior notes

- The bound intent's `perform()` runs when the control is used — same rules as interactive widgets: fast, write to shared storage, idempotent-friendly (`interactive-widgets.md`).
- **`.controlWidgetActionHint`** sets the accessibility/label hint for the next action ("Turn Off").
- Controls can be placed by users in **Control Center**, on the **Lock Screen**, or assigned to the **Action Button** — one definition, three placements.
- Toggle state is read through the provider's `currentValue`; refresh it after mutations by reloading controls with `ControlCenter.shared.reloadControls(ofKind:)` (or `reloadAllControls()`).

## Pitfalls

- **Deriving toggle state from app memory** → the control shows stale state; read from the App-Group-shared store in `currentValue`.
- **Heavy `currentValue`/`perform()`** → the extension is constrained; keep both quick.
- **Forgetting to reload after a change made elsewhere** → toggle desyncs; call `ControlCenter.shared.reloadControls(ofKind:)` when app state changes.
- **iOS version** → Controls are iOS 18+; gate the `ControlWidget` in the bundle accordingly if you ever target lower (this plugin's baseline is iOS 26, so they're available).
