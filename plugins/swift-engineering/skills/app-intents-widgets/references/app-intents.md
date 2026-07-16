# App Intents

An `AppIntent` is a unit of app behavior the system can invoke — from Siri, Shortcuts, Spotlight, a widget button, or a control. Model your app's verbs (actions) as intents and its nouns (addressable things) as entities, and every surface downstream gets them for free.

## The intent

```swift
import AppIntents

struct ToggleTripArchivedIntent: AppIntent {
    static let title: LocalizedStringResource = "Archive Trip"
    static let description = IntentDescription("Archives or unarchives a trip.")

    @Parameter(title: "Trip")
    var trip: TripEntity

    @Dependency
    var store: TripStore                 // injected app service (see below)

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await store.toggleArchived(trip.id)
        return .result(dialog: "Archived \(trip.name)")
    }
}
```

- **`title`** is required and user-facing (localized). `description` shows in Shortcuts.
- **`perform()`** is `async throws` and returns an `IntentResult`. Compose result traits: `ProvidesDialog` (spoken/'`.result(dialog:)`'), `ReturnsValue<T>`, `OpensIntent`, `ShowsSnippetView`.
- Conform to **`OpenIntent`** to bring a specific entity to the foreground; to **`ForegroundContinuableIntent`** to start in the background then continue in-app when UI is needed; to **`AudioPlaybackIntent`** / `AudioStartingIntent` for media.

## Parameters

```swift
@Parameter(title: "Count", default: 1)
var count: Int

@Parameter(title: "Priority")
var priority: PriorityEnum

@Parameter(title: "Note", requestValueDialog: "What should the note say?")
var note: String
```

- Supported parameter types: the scalars, `AppEntity`, `AppEnum`, arrays of these, `IntentFile`, `URL`, dates, measurements.
- Drive Shortcuts' parameter summary with `static var parameterSummary`:
  ```swift
  static var parameterSummary: some ParameterSummary {
      Summary("Archive \(\.$trip)")
  }
  ```
- Ask for missing values at runtime with `$parameter.requestValue(...)` / `requestConfirmation(...)` inside `perform()`.

## Entities — addressable nouns

An `AppEntity` is something the system can reference, list, and pass into intents (a Trip, a Note, a Playlist). It needs a display representation and a **query**.

```swift
struct TripEntity: AppEntity {
    let id: UUID
    let name: String

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Trip")
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    static let defaultQuery = TripQuery()
}

struct TripQuery: EntityQuery {
    @Dependency var store: TripStore
    func entities(for ids: [UUID]) async throws -> [TripEntity] { try await store.trips(ids: ids) }
    func suggestedEntities() async throws -> [TripEntity] { try await store.recentTrips() }
}
```

- `EntityQuery.entities(for:)` resolves ids back to entities; `suggestedEntities()` powers pickers.
- Use `EntityStringQuery` (adds `entities(matching string:)`) so users can search entities by name in Shortcuts/Siri.

## Enums — fixed choices

```swift
enum PriorityEnum: String, AppEnum {
    case low, normal, high
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Priority")
    static let caseDisplayRepresentations: [PriorityEnum: DisplayRepresentation] = [
        .low: "Low", .normal: "Normal", .high: "High"
    ]
}
```

## `@Dependency` — reach your app's services

Intents run in an extension/isolated context and can't see your app's live objects. Register dependencies at app launch and inject them:

```swift
// App launch:
AppDependencyManager.shared.add(dependency: TripStore(container: sharedContainer))

// In any intent / query:
@Dependency var store: TripStore
```

Back the store with an **App Group**-shared `ModelContainer` (see `swiftdata` + widgetkit.md) so app and extension read the same data.

## Expose to Siri, Shortcuts, Spotlight

`AppShortcutsProvider` publishes ready-made shortcuts (no user setup) and phrases:

```swift
struct TripShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ArchiveTripIntent(),
            phrases: ["Archive a trip in \(.applicationName)",
                      "Archive \(\.$trip) in \(.applicationName)"],
            shortTitle: "Archive Trip",
            systemImageName: "archivebox"
        )
    }
}
```

- **Include `\(.applicationName)`** in phrases or Siri can't reliably route them.
- Intents also become **Shortcuts** actions automatically and, via entities, **Spotlight** results.
- Donate relevant intents (`IntentDonationManager`) or use App Shortcuts so the system learns to suggest them.

## Pitfalls

- **Long work in `perform()`** — keep it responsive; for lengthy jobs use `ForegroundContinuableIntent` or kick a background task and return promptly.
- **Non-Sendable dependencies** — services injected via `@Dependency` cross isolation; make them `Sendable`/actor-isolated.
- **Unstable phrases/ids** — changing an intent's identifier or an entity's `id` breaks existing Shortcuts and Siri routing; treat them as a contract.
