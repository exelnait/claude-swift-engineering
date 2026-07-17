# WidgetKit

A widget is a **timeline of glanceable entries** rendered by the system in a separate extension process. You supply future entries and a reload policy; the system decides when to show and refresh them within a budget.

## Bundle, widget, configuration

```swift
@main
struct MyWidgets: WidgetBundle {
    var body: some Widget {
        TripWidget()
        // more widgets, Live Activities, controls…
    }
}

struct TripWidget: Widget {
    let kind = "TripWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectTripIntent.self, provider: Provider()) { entry in
            TripWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(.systemBackground) }   // REQUIRED (iOS 17+)
        }
        .configurationDisplayName("Trip")
        .description("Shows your next trip.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}
```

- **`StaticConfiguration`** — no user configuration. **`AppIntentConfiguration`** — user-configurable via a `WidgetConfigurationIntent` (iOS 17+ replacement for the old `IntentConfiguration`/SiriKit intents).
- The **`.containerBackground(for: .widget)`** on the entry view's root is mandatory since iOS 17 — omit it and the widget mis-renders and is barred from StandBy/Smart Stack.
- `.supportedFamilies` — system families (`.systemSmall/Medium/Large/ExtraLarge`) and accessory families for Lock Screen / watch (`.accessoryCircular/Rectangular/Inline`).

## The configuration intent (for AppIntentConfiguration)

```swift
struct SelectTripIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Select Trip"
    @Parameter(title: "Trip") var trip: TripEntity?
}
```

The chosen configuration is delivered to the provider as `context`/`configuration`.

## Timeline provider

```swift
struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TripEntry {
        TripEntry(date: .now, trip: .placeholder)                 // redacted skeleton
    }
    func snapshot(for configuration: SelectTripIntent, in context: Context) async -> TripEntry {
        TripEntry(date: .now, trip: await currentTrip(configuration))   // for the widget gallery
    }
    func timeline(for configuration: SelectTripIntent, in context: Context) async -> Timeline<TripEntry> {
        let entries = await upcomingEntries(configuration)         // now + a few future points
        return Timeline(entries: entries, policy: .after(.now.addingTimeInterval(60 * 30)))
    }
}

struct TripEntry: TimelineEntry {
    let date: Date          // when this entry becomes current
    let trip: TripSnapshot
}
```

**Reload policies** (`Timeline(entries:policy:)`):
- `.atEnd` — reload after the last entry's date.
- `.after(date)` — reload no earlier than `date`.
- `.never` — only reload when the app calls `WidgetCenter`.

The system treats these as *requests* within a refresh budget — you don't get guaranteed per-second updates (Common Mistake #4). For real-time, use a Live Activity.

## Entry view: families, deep links, rendering

```swift
struct TripWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: TripEntry

    var body: some View {
        switch family {
        case .accessoryRectangular: RectangularTrip(entry: entry)
        case .systemSmall:          SmallTrip(entry: entry)
        default:                    MediumTrip(entry: entry)
        }
    }
}
```

- **Deep link** into the app: whole-widget target with `.widgetURL(url)`; per-element targets with `Link(destination:)` (system/medium+ families). Handle the URL in the app via `.onOpenURL`.
- **Rendering modes**: `.widgetRenderingMode` is `.fullColor`, `.accented`, or `.vibrant` (Lock Screen / tinted Home Screen). Provide legible assets for accented/vibrant; tag views with `.widgetAccentedRenderingMode` where needed.
- Keep entry views cheap — they're rendered as archived snapshots.

## Reloading from the app

When the app changes data a widget shows, tell WidgetKit:

```swift
import WidgetKit
WidgetCenter.shared.reloadTimelines(ofKind: "TripWidget")   // one kind
WidgetCenter.shared.reloadAllTimelines()                     // everything
```

Check what's installed with `WidgetCenter.shared.getCurrentConfigurations`.

## Sharing data with the app (App Group)

The widget extension can't see the app's memory. Share through an **App Group**:
- A shared `ModelContainer` pointed at an App-Group URL (`ModelConfiguration(groupContainer:)`), or
- `UserDefaults(suiteName:)`, or a file in the group container.

The app writes + `reloadTimelines`; the provider reads the shared store. Keep provider reads small and fast (Common Mistake #3).

## Pitfalls

- **Missing `containerBackground`** → broken rendering / gallery rejection.
- **Heavy provider work** → the extension is killed for exceeding memory/time; move sync to the app.
- **Assuming live updates** → widgets are timelines; budget-limited. Use `.after`/`reloadTimelines`, or a Live Activity for seconds-level freshness.
- **No App Group** → widget shows stale/empty data because it can't reach app state.

## Extra-large portrait family (iOS 27 / macOS 27)

A tall, poster-shaped system family. Introduced on visionOS 26, now available on **iOS, iPadOS, and macOS 27**. It gives content room to breathe — e.g. a reading schedule showing several days at once — so support it where a bigger canvas earns its place.

```swift
.supportedFamilies([.systemMedium, .systemExtraLargePortrait])
// .systemExtraLargePortrait — confirm exact API against current Apple documentation
```

Adding it is cheap: **reuse the same widget and the same timeline provider**, and add one `case` to the entry view that lays the existing entry data out for the larger shape. Handle it in the `widgetFamily` switch next to the other families — no new provider, no new data model.

## Tinted & clear rendering (glass + accented mode)

On iOS people can tint the Home Screen with a color or switch it to **clear**. In either mode the system renders your widget through a **glass material** — tinting your content and swapping your background for an adaptive glass effect — so the whole screen feels cohesive. This is exactly what `.containerBackground(for: .widget)` buys you: it marks the view the system replaces with glass.

SwiftUI does most of the work, but **test all three renderings**: full color, tinted, and clear. A common failure is an image that collapses into a **solid white rectangle** in accented mode — the system can't derive an accent for a full-color asset (a book cover, artwork, a logo). Force it to keep its real colors:

```swift
BookCoverImage(book: entry.book)
    .widgetAccentedRenderingMode(.fullColor)   // render in full color instead of a flat accent shape
```

Use `.fullColor` only on assets whose identity *is* their color; let everything else accent normally. (Read the active mode inside the view with `.widgetRenderingMode`, above.)

## Reach across the system

One iOS widget shows up in more than one place:

- **Remote widgets on macOS** — your iOS widget appears on the Mac with no separate target.
- **CarPlay** — the same widget surfaces there too.

The same archived views and App Intents run in these contexts, so **test that interactions still feel right from a Mac** — deep links, buttons, and toggles — not just on iPhone.

## Testing workflow

- **SwiftUI Previews / Xcode canvas** — iterate on families, color schemes, and rendering modes without leaving Xcode. Preview each supported family (including `.systemExtraLargePortrait`) and the accented/tinted look to catch layout and asset problems early.

```swift
#Preview(as: .systemExtraLargePortrait) {
    TripWidget()
} timeline: {
    TripEntry.sample
}
// #Preview(as:) widget form — confirm exact API against current Apple documentation
```

- **WidgetKit developer mode** — turn it on while iterating to **lift constraints like the reload budget**, so timeline refreshes aren't throttled during testing.
- **On device** — tinted/clear glass only renders correctly on real hardware; finish by customizing your Home Screen and checking full color / tinted / clear.

For content that is genuinely ephemeral (a live score, an ETA) don't fight the reload budget with a fast-refreshing widget — reach for a Live Activity instead (see `live-activities.md`).
