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

## App Intent & App Entity schemas (iOS 27)

_New in the 2026 releases (iOS 27)._ **Schemas** are system-defined shapes for common app content and actions that Siri understands deeply (built on years of language-model training). Adopt them and people can phrase requests naturally — you don't invent or maintain the phrases like you do for `AppShortcut` — and because the schemas are system-defined, your intents automatically inherit future Siri improvements (new languages, regional dialects) with **no code change**.

- **Entity schemas** describe the content/concepts your app works with (message, contact, conversation, photo, …). Conform with the `@AppEntity` macro. `// confirm exact API against current Apple documentation` — a schema-adoption macro layered on the `AppEntity` protocol shown above.
- **Intent schemas** describe actions your app performs. The system ships supported actions for common categories (task management, photo editing, communication) — e.g. `sendMessage`. Conform an intent with the `@AppIntent` macro. `// confirm exact API against current Apple documentation`
- **Spotlight semantic index** — conform entities to **`IndexedEntity`** and index them (e.g. when the app finishes launching) to contribute their content to the on-device semantic index. This powers _personal-context_ understanding ("who's coming to origami night?") with **attribution back to your app**. Indexing keys for important properties are built into the schemas, so it's more understanding from less code.

```swift
// Adopt a system entity schema AND feed Spotlight's semantic index:
@AppEntity   // adopt the matching entity schema — confirm exact API against current Apple documentation
struct MessageEntity: IndexedEntity {
    let id: String        // must be stable across devices (see Storage below)
    // schema-defined properties…
}
// Then, at launch, index instances so Siri can reason over them.
```

Schemas are the bridge to Apple Intelligence: pair them with the on-device models in the `foundation-models` skill, and note that the same indexed entities can surface in camera-based search — see the `visual-intelligence` skill.

## View Annotations — act on what's on screen (iOS 27)

_New in iOS 27._ The **View Annotations API** associates an on-screen view with its entity, so users can reference visible content by position or deixis — "the second message", "this photo" — and Siri passes the matching entity into your intents. Apply a view modifier that maps each row/view to its entity:

```swift
List(conversation.messages) { message in
    MessageRow(message)
        // Map this visible row to its entity so Siri can resolve
        // "the second message" and hand it to your intents.
        .appEntityAnnotation(message)   // exact modifier name — confirm exact API against current Apple documentation
}
```

Combine with schemas (above) so on-screen awareness + personal context + system actions compose into natural, conversational control of your app.

## Shortcuts: new automation types (iOS 27)

_New in iOS 27._ Automations now live **directly in the Shortcuts editor** (an "Automation" section alongside a shortcut's actions, easier to set up than before), and there are three new triggers:

- **Screenshot** — runs when a screenshot is saved.
- **Keyboard** — runs when an external keyboard is connected or disconnected.
- **Notification** — runs when a notification is received from a specific app, with an optional **text filter** (e.g. only when the body contains "arriving").

The notification automation acts on _your app's_ notifications, so a well-crafted notification becomes an automation hook: one that's distinct, specific, and actionable (driver name + the verb "arriving" + an ETA) is easy to match and reason about inside a shortcut. Follow the notification best practices in the Human Interface Guidelines (see the `ios-hig` skill) and your users can build powerful automations on top of what you already ship.

## Shortcuts: the Use Model action (iOS 27)

_New in iOS 27._ Shortcuts' **Use Model** action runs Apple Intelligence models inside a shortcut — now more capable and able to **go to the web** for up-to-date info — and it operates on your app's content through App Intents. Expose a query (e.g. an `EntityPropertyQuery`-backed "Find…" action that fetches and filters your entities) and feed its results into the model.

- **Debug via the transcript.** When the model returns something unexpected, add a **Show Content** action after Use Model and select its **Transcript** output to inspect the raw entities/properties that were passed in — exactly what the model saw, in structured form.
- **Design takeaway: expose the properties the model needs.** In the talk a `SoupEntity` carrying only `name` + `availability` couldn't judge spice level; adding an `ingredients` property (each ingredient with its quantity) gave the model enough context to pick a genuinely spicy soup. Your entity's exposed properties _are_ the model's context — name them well and include what a reasoner would need.

The models themselves live in the `foundation-models` skill; here the job is exposing rich, well-named entity properties. (Deeper dive: WWDC25 "Develop for Shortcuts and Spotlight with App Intents".)

## Shortcuts: Storage — persist values between runs (iOS 27)

_New in iOS 27._ **Storage** lets a shortcut save values and read them back on later runs (get / set actions), plus **global values** shared across shortcuts (handy for something like an API key). It works with **any type, including App Entities** — e.g. keeping a list of recently picked soups so the Use Model action stops repeating itself.

- **Stored values sync across devices**, so an App Entity saved on iPhone must be recognized as the _same_ entity on iPad or Mac.
- **Give entities a stable, device-independent `id`.** Derive it from a source that yields the identical value everywhere — e.g. a backend **database row ID** — not a per-device value (a local SQLite rowid, object address, or per-install UUID). An unstable identifier fails to resolve once a stored entity crosses devices.

This sharpens the **Unstable phrases/ids** pitfall above: with Storage, an entity's `id` is a _cross-device_ contract, not just a per-install one.
