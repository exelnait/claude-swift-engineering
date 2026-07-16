# Testing & Previews

Never test or preview against the real on-disk store — it's shared, stateful, and slow. Spin up a fresh **in-memory `ModelContainer`** per preview and per test, seed it, and throw it away. This is the single most useful SwiftData testing habit.

## The in-memory container

```swift
@MainActor
func makeInMemoryContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: Trip.self, Stop.self, configurations: config)
}
```

`isStoredInMemoryOnly: true` gives a real, fully-functional container backed by memory — same API, no disk, gone when released. Each one is isolated, so tests don't leak state into each other.

## Previews

Seed a container and inject it so `@Query` and `@Environment(\.modelContext)` work exactly as in the app:

```swift
#Preview {
    let container = try! ModelContainer(
        for: Trip.self, Stop.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    // Seed sample data on the main context:
    let ctx = container.mainContext
    for name in ["Iceland", "Kyoto", "Patagonia"] {
        ctx.insert(Trip(name: name, startDate: .now))
    }
    return TripList()
        .modelContainer(container)   // now @Query in TripList reads this seeded store
}
```

Factor the seeding into a reusable helper (e.g. `PreviewData.container`) so every preview and every test starts from the same known fixtures instead of copy-pasting inserts.

```swift
enum PreviewData {
    @MainActor static let container: ModelContainer = {
        let c = try! ModelContainer(for: Trip.self, Stop.self,
                                    configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        for name in ["Iceland", "Kyoto", "Patagonia"] { c.mainContext.insert(Trip(name: name)) }
        return c
    }()
}

#Preview { TripList().modelContainer(PreviewData.container) }
```

## Swift Testing

Give each test its own in-memory container so they're independent and parallel-safe. Because the main context is main-actor-isolated, mark the suite/test `@MainActor` (or drive a `@ModelActor` for background-path tests).

```swift
import Testing
import SwiftData

@MainActor
struct TripStoreTests {
    private func freshContext() throws -> ModelContext {
        let container = try ModelContainer(for: Trip.self, Stop.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return container.mainContext
    }

    @Test func insertsAndFetches() throws {
        let ctx = try freshContext()
        ctx.insert(Trip(name: "Iceland"))
        try ctx.save()

        let trips = try ctx.fetch(FetchDescriptor<Trip>())
        #expect(trips.count == 1)
        #expect(trips.first?.name == "Iceland")
    }

    @Test func predicateFiltersActiveOnly() throws {
        let ctx = try freshContext()
        ctx.insert(Trip(name: "A", isActive: true))
        ctx.insert(Trip(name: "B", isActive: false))
        try ctx.save()

        let active = try ctx.fetch(FetchDescriptor<Trip>(predicate: #Predicate { $0.isActive }))
        #expect(active.map(\.name) == ["A"])
    }

    @Test func cascadeDeleteRemovesStops() throws {
        let ctx = try freshContext()
        let trip = Trip(name: "Iceland")
        trip.stops = [Stop(name: "Reykjavík")]
        ctx.insert(trip)
        try ctx.save()

        ctx.delete(trip)
        try ctx.save()
        #expect(try ctx.fetchCount(FetchDescriptor<Stop>()) == 0)   // cascade worked
    }
}
```

## What to actually test

- **Predicates** return the right rows (the subset limits in `queries.md` mean a predicate can be silently wrong — pin it with a test).
- **Delete rules** behave (cascade removes children; nullify keeps them). Cheap to get wrong, expensive in production.
- **Uniqueness** (`#Unique`/`.unique`) rejects/upserts as intended.
- **`@ModelActor` paths** — drive the actor, then assert via a main-context fetch of the returned `PersistentIdentifier`s. This also exercises the cross-actor handoff.
- **Migrations** — the highest-value tests; use an **on-disk** temp store (not in-memory) seeded with the old schema, open with the new plan, assert the transform. See `migrations.md`.

## Pitfalls

- **Sharing one container across tests** reintroduces cross-test state — build a fresh in-memory container per test.
- **Forgetting `@MainActor`** on tests that touch `mainContext` → concurrency errors under Swift 6. Isolate the test, or test the background path through a `@ModelActor`.
- **Testing migrations in-memory** — some migration behavior only manifests on a real store file; use a temp on-disk store for those.
