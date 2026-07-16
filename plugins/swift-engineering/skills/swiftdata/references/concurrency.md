# Concurrency & Performance

SwiftData's cardinal threading rule: **`@Model` instances and `ModelContext`s are not `Sendable` and belong to one actor.** Cross the boundary with a `PersistentIdentifier`, never a model. Get this right and background work is safe; get it wrong and you get data races and crashes (Common Mistake #1, #2).

## `@ModelActor` — the background workhorse

`@ModelActor` generates an actor with its own `ModelContext` and executor, bound to the container you pass. All its work runs off the main actor.

```swift
@ModelActor
actor TripImporter {
    func importTrips(_ payloads: [TripPayload]) throws -> [PersistentIdentifier] {
        var ids: [PersistentIdentifier] = []
        for payload in payloads {
            let trip = Trip(name: payload.name, startDate: payload.date)
            modelContext.insert(trip)        // `modelContext` is provided by @ModelActor
            ids.append(trip.persistentModelID)
        }
        try modelContext.save()
        return ids                           // return IDs (Sendable), NOT Trip instances
    }
}
```

```swift
// Call site (e.g. from a @MainActor view model):
let importer = TripImporter(modelContainer: container)
let newIDs = try await importer.importTrips(payloads)
// Back on the main actor, resolve IDs in the main context if you need the objects:
let trips = newIDs.compactMap { mainContext.model(for: $0) as? Trip }
```

- The macro synthesizes `init(modelContainer:)`, a private `modelExecutor`, and the `modelContext` you use inside.
- Everything inside the actor is isolated to it — safe to fetch, mutate, and save.
- **Return `PersistentIdentifier`s (or plain value DTOs), never `@Model`s.** `persistentModelID` on any model gives you its Sendable identity.

## `PersistentIdentifier` — the only thing that crosses actors

```swift
let id: PersistentIdentifier = trip.persistentModelID   // Sendable
// hand `id` to another actor; there, re-fetch:
let sameTrip = otherContext.model(for: id) as? Trip
```

`PersistentIdentifier` is stable and `Sendable`. Passing the *model* instead is the classic bug: the instance is tied to the context that fetched it, and touching it from another actor is undefined behavior.

## Main-context discipline

The environment `modelContext` runs on the **main actor**. Reads and writes there block the UI:

- **Small, UI-driven mutations** (insert one item, toggle a flag): fine on the main context.
- **Imports, batch edits, large fetches, migrations-of-data**: do them on a `@ModelActor`, then surface results (IDs or DTOs) back. Never freeze the main thread scanning thousands of rows.

## Performance patterns

**Count, don't fetch-and-count:**
```swift
let n = try context.fetchCount(descriptor)     // O(store) count, no object graph materialized
// NOT: try context.fetch(descriptor).count    // loads every object just to count
```

**Batch-delete by predicate:**
```swift
try context.delete(model: Trip.self, where: #Predicate { $0.isArchived })   // no per-object materialization
```

**Index what you query and sort:**
```swift
@Model final class Trip {
    #Index<Trip>([\.startDate], [\.name])   // sort/filter on these won't full-scan
    // ...
}
```
Add `#Index` for the exact key paths that appear in your `sortBy` and predicate. Unindexed sort/filter over a large store is the most common SwiftData perf cliff.

**Page large lists** with `fetchLimit`/`fetchOffset`, and **stream** huge processing jobs with `context.enumerate(_:)` (batched, low-memory) — see `queries.md`.

**Prefetch relationships** you'll touch to avoid N+1:
```swift
var d = FetchDescriptor<Trip>()
d.relationshipKeyPathsForPrefetching = [\.stops]
```

**Partial fetches** for list rows that show only a couple of fields:
```swift
d.propertiesToFetch = [\.name, \.startDate]
```

## History tracking (change feeds, iOS 18+)

For syncing to a server, driving widgets, or reacting to external changes, SwiftData's history API exposes an ordered log of inserts/updates/deletes since a token:

```swift
let descriptor = HistoryDescriptor<DefaultHistoryTransaction>()
let transactions = try context.fetchHistory(descriptor)   // process changes since your last token
```

Persist the last processed token and resume from it. Use this instead of diffing the whole store on every launch.

## Threading checklist

- [ ] No `@Model` instance is ever passed between actors — only `PersistentIdentifier` (or value DTOs).
- [ ] Heavy work runs in a `@ModelActor`, not on the environment/main context.
- [ ] `fetchCount` for counts; batch `delete(model:where:)` for bulk deletes.
- [ ] `#Index` covers the key paths in your sorts/predicates.
- [ ] Large reads are paged (`fetchLimit`) or streamed (`enumerate`).
