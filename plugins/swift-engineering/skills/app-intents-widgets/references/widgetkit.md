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
