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

## Dynamic Island in portrait and landscape (iOS 27)

Previously the compact/minimal island only showed in portrait. **In iOS 27 both are visible in portrait and landscape.** Compact views are **flexible width in portrait** but **width-constrained in landscape** (no room to grow), so a text label that fits in portrait can be clipped. Read the **`isDynamicIslandLimitedInWidth`** environment value and substitute a narrower presentation — e.g. a progress icon instead of a text label.

```swift
struct DeliveryCompactTrailing: View {
    @Environment(\.isDynamicIslandLimitedInWidth) private var isLimitedInWidth
    let context: ActivityViewContext<DeliveryAttributes>

    var body: some View {
        if isLimitedInWidth {
            // Landscape: no room to grow — a compact progress ring, not a label.
            ProgressView(value: /* fraction elapsed */ 0.6)
                .progressViewStyle(.circular)
        } else {
            Text("\(context.state.etaMinutes)m")   // portrait: width is flexible
        }
    }
}
```

- Design compact/minimal to survive a width-limited island; don't rely on portrait's flexible width.

## StandBy: landscape while charging (iOS 27)

When iPhone is **charging in landscape**, the activity appears in **StandBy**, which **reuses your Lock Screen view scaled up to ~200%**. A gradient that looks right on the Lock Screen leaves large blank margins at that scale. Vary the background per surface with the **`showsWidgetContainerBackground`** environment value (true on the Lock Screen): gradient on the Lock Screen, an edge-to-edge `activityBackgroundTint` everywhere else.

```swift
// The Lock Screen view from the Configuration section, made StandBy-aware:
struct DeliveryLockScreenView: View {
    @Environment(\.showsWidgetContainerBackground) private var showsContainerBackground
    let context: ActivityViewContext<DeliveryAttributes>

    var body: some View {
        DeliveryContent(context: context)
            .activityBackgroundTint(.indigo)            // edge-to-edge fill (StandBy & other container-less surfaces)
            .background {
                if showsContainerBackground {           // true on the Lock Screen
                    LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom)
                }
            }
    }
}
```

- Lock Screen → your gradient. StandBy (and any surface without a widget container) → a solid `activityBackgroundTint` that fills the frame edge-to-edge.

## Beyond iPhone: Apple Watch, CarPlay and the small activity family (iOS 27)

A Live Activity running on iPhone is **automatically forwarded** to other devices — the **Apple Watch Smart Stack**, the **macOS menu bar**, and the **CarPlay Dashboard** — with no extra request. By default they render your Lock Screen view, which rarely fits those compact spaces. Adapt by declaring support for the **small activity family** and branching on the **`activityFamily`** environment value to return a `.small`-tailored view.

```swift
// The DeliveryLiveActivity configuration (from above), made family-aware:
ActivityConfiguration(for: DeliveryAttributes.self) { context in
    DeliveryActivityView(context: context)          // switches on activityFamily
} dynamicIsland: { context in
    /* … unchanged … */
}
.supplementalActivityFamilies([.small])             // confirm exact API against current Apple documentation

struct DeliveryActivityView: View {
    @Environment(\.activityFamily) private var activityFamily
    let context: ActivityViewContext<DeliveryAttributes>

    var body: some View {
        switch activityFamily {
        case .small:  DeliverySmallView(context: context)        // Apple Watch, CarPlay
        default:      DeliveryLockScreenView(context: context)   // Lock Screen, StandBy
        }
    }
}
```

- Declaring the small family tells the system your views are adapted to the smaller format; omit it and you get the poorly-fitting default.
- Deep dive: the session **"Bring your Live Activity to Apple Watch."**

## More ways to start and push updates

Beyond the foreground `Activity.request(...)` shown above, an activity can also start in two more ways:
- **Scheduled to start in advance** at a specific future time — no app foreground needed. // confirm exact scheduling API against current Apple documentation
- **Started from a push notification** — server-initiated; the app need not be running.

For updates, pick a **push strategy by scale**:
- **Broadcast channel** — for **hundreds/thousands+** devices running the *same* activity: your server publishes once to a broadcast channel and each activity **subscribes** to it for updates. // confirm exact channel/subscription API against current Apple documentation
- **Targeted push notifications** — for everything else: a **per-device push token** addresses each activity individually (this is the token flow in "Background freshness = APNs push" above).

See Apple's "ActivityKit push notifications" guide for payload and channel specifics.

## Interactivity (recap)

Live Activity and expanded Dynamic Island views can embed **`Button`/`Toggle` bound to a `LiveActivityIntent`** (a distinct conformance from a plain `AppIntent`). On tap the system runs the intent's `perform()` — e.g. a `RateOrderIntent(orderID:isPositive:)` that posts a rating to your server and updates state — without foregrounding the app. Keep these intents fast; full pattern in `interactive-widgets.md`.
