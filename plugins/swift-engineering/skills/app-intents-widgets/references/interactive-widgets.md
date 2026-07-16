# Interactive Widgets

Since iOS 17, widgets (and Live Activities) can contain **`Button`** and **`Toggle`** that run an `AppIntent` directly — no launching the app. This is the same intent layer from `app-intents.md`, now driving a tap in a glanceable surface.

## The two interactive controls

Only `Button(intent:)` and `Toggle(isOn:intent:)` are interactive inside a widget/Live Activity — arbitrary gestures are not.

```swift
struct TripWidgetView: View {
    let entry: TripEntry
    var body: some View {
        VStack {
            Text(entry.trip.name)
            HStack {
                Button(intent: CheckInIntent(trip: entry.trip.ref)) {
                    Label("Check in", systemImage: "checkmark.circle")
                }
                Toggle(isOn: entry.trip.isPinned,
                       intent: SetPinnedIntent(trip: entry.trip.ref, pinned: !entry.trip.isPinned)) {
                    Label("Pin", systemImage: "pin")
                }
                .toggleStyle(.button)
            }
        }
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }
}
```

## What runs where, and the reload cycle

1. The user taps → the system runs the intent's **`perform()`** in your app-intents process.
2. `perform()` mutates shared state (App Group store) and returns.
3. WidgetKit **reloads the timeline** automatically after the intent completes, so the entry view re-renders from the new state.

Implications:
- **Write results to the shared store** inside `perform()` (see App Group in `widgetkit.md`) — the reloaded timeline reads from there. Mutating only in-memory app state won't show.
- **Keep `perform()` fast.** It runs in a constrained context and the UI waits on it. Long/network work → kick a background task, update the store when it lands, and `reloadTimelines`; don't block the tap.
- Intents used interactively should be **idempotent-friendly**: a double tap or a reload shouldn't corrupt state (toggle to an explicit value, not a blind flip, when possible).

## Optimistic UI

WidgetKit renders an **optimistic** state immediately for known interactions so the tap feels instant, then reconciles when the reload lands. Make your intent's effect match what the button visually implies (a pin button that sets `pinned = true`) so the optimistic and final states agree — mismatches flicker.

## Passing the target

Interactive intents usually act on a specific entity. Pass a lightweight reference (an `AppEntity` or its id) into the intent's parameters when you construct it in the view:

```swift
Button(intent: CheckInIntent(trip: entry.trip.ref)) { … }   // ref is a TripEntity / id
```

Resolve it in `perform()` via the entity query or the shared store.

## Pitfalls

- **Blocking `perform()`** on network/heavy work → laggy taps and possible extension termination. Return fast; finish work asynchronously and reload.
- **Mutating app-only memory** → invisible in the widget; write to the App-Group-shared store.
- **Non-idempotent flips** → a reload or repeat tap double-applies. Prefer explicit target values.
- **Expecting gestures** → only `Button`/`Toggle` are interactive; no `onTapGesture`, drag, etc., in widgets.
