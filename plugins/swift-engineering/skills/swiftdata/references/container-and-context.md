# Container & Context

`ModelContainer` owns the store; `ModelContext` is your unit of work against it. One container per store for the whole app; contexts are cheap and per-task.

## `ModelContainer` — install once at the root

The simplest setup lets SwiftData build the container from your model types and injects a main context into the environment:

```swift
@main
struct TripsApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
        .modelContainer(for: [Trip.self, Stop.self])   // schema inferred from these + their relationships
    }
}
```

`.modelContainer(for:)` creates the container, puts a **main-actor `ModelContext`** in the environment (read it with `@Environment(\.modelContext)`), and enables **autosave**. That's all most apps need.

### Custom container (configurations, in-memory, CloudKit)

When you need options, build the container yourself and pass it in:

```swift
let container: ModelContainer = {
    let schema = Schema([Trip.self, Stop.self])
    let config = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,           // true for tests/previews
        allowsSave: true,
        cloudKitDatabase: .automatic           // .none to disable; .private(...) for a specific container
    )
    do { return try ModelContainer(for: schema, configurations: [config]) }
    catch { fatalError("Could not create ModelContainer: \(error)") }
}()

// App:
WindowGroup { ContentView() }.modelContainer(container)
```

- **One container per store.** Build it once (a `let`, or an injected dependency) and share it. Two containers over the same file corrupt each other's view of the data (Common Mistake #7).
- **Multiple stores:** pass several `ModelConfiguration`s (e.g. one on-disk store and one in-memory cache; or route specific models to specific files with `ModelConfiguration(for: SomeModel.self, ...)`).
- Provide a **migration plan** here for shipped schema changes: `ModelContainer(for:migrationPlan:configurations:)` — see `migrations.md`.

## `ModelContext` — the unit of work

A context stages inserts/updates/deletes and flushes them to the store on save.

```swift
@Environment(\.modelContext) private var context

func addTrip() {
    let trip = Trip(name: "Iceland")
    context.insert(trip)          // staged in this context
    // autosave persists it soon; or force it now:
    try? context.save()
}

func remove(_ trip: Trip) {
    context.delete(trip)
    try? context.save()
}
```

Key API:
- `insert(_:)` / `delete(_:)` — stage changes. `delete(model:where:)` batch-deletes by predicate without materializing objects.
- `save()` — flush staged changes to the store. Throws; handle or surface the error (don't blanket `try?` where data loss matters).
- `hasChanges` — whether there's anything unsaved.
- `rollback()` — discard unsaved changes in this context.
- `transaction { … }` — group multiple mutations so they save atomically.
- `autosaveEnabled` — on for the environment/main context; you can disable it on contexts you create.

### Autosave vs. explicit save

Autosave persists **eventually** (on UI runloop boundaries), not at the instant you mutate. That's fine for incremental UI edits, but for anything that must survive a crash or be visible to another context *now*, call `save()` at that boundary. Don't `save()` inside a hot loop — batch the inserts, then save once (Common Mistake #6).

### Background contexts

For work off the main actor, create a fresh context from the container (do **not** reuse the main context across threads):

```swift
let bg = ModelContext(container)     // a new context bound to the calling actor
// …insert/fetch/save on bg…
```

For anything nontrivial, prefer a `@ModelActor`, which owns its own context and executor — see `concurrency.md`.

## CloudKit sync + its hard constraints

Set `cloudKitDatabase:` on the `ModelConfiguration` (and add the **iCloud + CloudKit** capability and a container in the target) to sync the store to the user's private CloudKit database automatically. But CloudKit imposes rules your schema **must** satisfy, or sync silently fails:

- **Every property is optional or has a default value.** No non-optional-without-default stored properties.
- **Every relationship is optional**, and to-many relationships default to `[]`.
- **No unique constraints** — `@Attribute(.unique)` and `#Unique` are disallowed with CloudKit. Enforce uniqueness in app logic instead.
- **No `.deny` / `.noAction`-style integrity you rely on CloudKit to enforce** — model ownership with `.cascade`/`.nullify`.
- The store is the user's **private** database by default; sharing/public DBs need explicit CloudKit work beyond SwiftData.

Design to these rules up front (`models.md`). Retrofitting CloudKit onto a model with unique constraints or non-optional fields is a schema migration, not a config flag.

> If your app needs sync *and* SQLite-level control (unique keys, complex queries), that's the `sqlite-data`/`grdb` + CloudKit path — see `data-layer-decisions` for the tradeoff. This file is the SwiftData-native path.

## Checklist

- [ ] Exactly one `ModelContainer`, built at the root, shared everywhere.
- [ ] Main context from `@Environment(\.modelContext)` for UI mutations; a `@ModelActor` for heavy/background work.
- [ ] `save()` at meaningful boundaries for critical data; not in tight loops.
- [ ] If CloudKit: all properties optional-or-defaulted, relationships optional, zero unique constraints.
- [ ] A `migrationPlan` wired in before shipping any schema change.
