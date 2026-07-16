# Live Activities & the Dynamic Island

A Live Activity is a **live-updating card** for an ongoing, time-bounded event (a delivery, a ride, a timer, a live score). It shows on the Lock Screen and in the Dynamic Island, updates in near real time (via local calls or APNs push), and ends when the event does. This is the surface to use when a widget's timeline is too slow (Common Mistake #4).

## Attributes and content state

`ActivityAttributes` splits into **static** attributes (fixed for the activity's life) and a nested **`ContentState`** (the part that changes).

```swift
import ActivityKit

struct DeliveryAttributes: ActivityAttributes {
    // Static — set once at request time:
    let orderNumber: String
    let restaurantName: String

    // Dynamic — updated over the activity's life:
    struct ContentState: Codable, Hashable {
        var status: String
        var etaMinutes: Int
        var courierName: String?
    }
}
```

## Configuration: Lock Screen + Dynamic Island

`ActivityConfiguration` (declared in the **widget extension**) provides the Lock Screen view and the three Dynamic Island presentations.

```swift
struct DeliveryLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DeliveryAttributes.self) { context in
            // Lock Screen / banner view:
            DeliveryLockScreenView(context: context)
                .activityBackgroundTint(.black.opacity(0.4))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading)  { Text(context.attributes.restaurantName) }
                DynamicIslandExpandedRegion(.trailing) { Text("\(context.state.etaMinutes)m") }
                DynamicIslandExpandedRegion(.center)   { Text(context.state.status) }
                DynamicIslandExpandedRegion(.bottom)   { ProgressView(value: /* … */ 0.6) }
            } compactLeading: {
                Image(systemName: "bag.fill")
            } compactTrailing: {
                Text("\(context.state.etaMinutes)m")
            } minimal: {
                Image(systemName: "bag.fill")
            }
        }
    }
}
```

- `context.attributes` = static; `context.state` = current `ContentState`.
- **Dynamic Island regions:** expanded (`.leading/.trailing/.center/.bottom`), `compactLeading`/`compactTrailing` (when another activity shares the island), and `minimal` (multiple activities). Design all three — the system chooses based on context.
- Live Activity views may contain **interactive `Button`/`Toggle` bound to App Intents** (see `interactive-widgets.md`).

## Lifecycle: request, update, end

```swift
// Start (from the app, in the foreground; requires NSSupportsLiveActivities = YES):
let activity = try Activity.request(
    attributes: DeliveryAttributes(orderNumber: "1234", restaurantName: "Yuzu"),
    content: .init(state: .init(status: "Preparing", etaMinutes: 30), staleDate: .now.addingTimeInterval(1800)),
    pushType: .token                       // request an APNs push token for background updates
)

// Update:
await activity.update(.init(state: .init(status: "On the way", etaMinutes: 12),
                            staleDate: .now.addingTimeInterval(900)),
                      alertConfiguration: .init(title: "Almost there", body: "12 min", sound: .default))

// End:
await activity.end(.init(state: .init(status: "Delivered", etaMinutes: 0), staleDate: nil),
                   dismissalPolicy: .after(.now.addingTimeInterval(60)))
```

- **`staleDate`** — when the content should be considered outdated (the system dims/marks it). Always set a realistic one so a stalled activity doesn't look live forever.
- **`relevanceScore`** — orders multiple concurrent activities in the Dynamic Island.
- **`dismissalPolicy`** — `.default`, `.immediate`, or `.after(date)` when ending.

## Background freshness = APNs push

Foreground-only `Activity.update` goes stale the moment the app is backgrounded (Common Mistake #7). For real events:

1. Request `pushType: .token` and read `activity.pushToken` updates via `for await` on `activity.pushTokenUpdates`.
2. Send that token to your server.
3. Server pushes `liveactivity`-type APNs payloads with the new `content-state` (and optional `alert`, `stale-date`, `dismissal-date`).

This updates the activity even when the app is suspended or terminated. Also observe `Activity.activityStateUpdates` / `pushTokenUpdates` to track lifecycle and rotate tokens.

## Requirements & limits

- Info.plist: **`NSSupportsLiveActivities = YES`** (and `NSSupportsLiveActivitiesFrequentUpdates` if you push often).
- Started only while the app is in the **foreground** (then updated by push in the background).
- `ContentState` payloads are small — send compact state, not blobs.
- Users can disable Live Activities per app; check `ActivityAuthorizationInfo().areActivitiesEnabled`.

## Pitfalls

- **No `staleDate`** → a stalled activity reads as current. Always set it.
- **Foreground-only updates** → dead activity in the background; wire APNs push.
- **Designing only the expanded island** → compact/minimal are what users see most; design all three + Lock Screen.
- **Oversized `ContentState`** → push failures/throttling; keep it lean.
