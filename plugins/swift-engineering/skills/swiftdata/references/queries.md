# Queries & Predicates

Two ways to read: **`@Query`** inside a view (declarative, auto-updating) and **`FetchDescriptor` + `context.fetch`** everywhere else (programmatic, including background actors). Both drive off `#Predicate` and `SortDescriptor`.

## `@Query` — the view-side reader

`@Query` fetches from the environment's `modelContext` and **re-runs automatically** whenever matching data changes. It replaces "fetch in `.onAppear` and store in `@State`."

```swift
struct TripList: View {
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]

    // Filtered + sorted:
    @Query(filter: #Predicate<Trip> { $0.isActive }, sort: \Trip.name)
    private var activeTrips: [Trip]

    var body: some View {
        List(trips) { TripRow(trip: $0) }
    }
}
```

- Multiple sort keys: `@Query(sort: [SortDescriptor(\.startDate, order: .reverse), SortDescriptor(\.name)])`.
- Animate updates: `@Query(sort: \Trip.startDate, animation: .default)`.
- `@Query` **requires a container in the environment** (`.modelContainer(...)` at the root) — without it the view has no context to read from (Common Mistake #8).

### Dynamic `@Query` (runtime parameters)

`@Query`'s parameters are set at init, so a query that depends on a runtime value (search text, a selected filter) goes in the view's `init`, not as a property wrapper default:

```swift
struct TripList: View {
    @Query private var trips: [Trip]

    init(searchText: String) {
        _trips = Query(
            filter: #Predicate<Trip> { searchText.isEmpty || $0.name.localizedStandardContains(searchText) },
            sort: \.startDate
        )
    }
}
```

Re-initializing the parent with a new `searchText` rebuilds the query. (For live search, debounce upstream; see `swift-networking`/`swiftui-patterns` async patterns.)

## `#Predicate` — what it can and can't do

`#Predicate` compiles to the underlying store's query language, so it supports **only a subset of Swift**. Staying inside that subset is the difference between a fast store-side filter and a compile error or runtime trap (Common Mistake #3).

**Supported:**
- Comparisons: `==`, `!=`, `<`, `<=`, `>`, `>=`, and `&&` / `||` / `!`.
- String ops: `localizedStandardContains(_:)`, `contains(_:)`, `starts(with:)`, `hasPrefix`/`hasSuffix`, `==`, `localizedCompare`.
- Collection ops on to-many relationships: `.contains(where:)`, `.count`, `.isEmpty`, `.allSatisfy`, `.filter`.
- Optional handling with `flatMap`/`== nil`, and `PredicateExpressions` on stored properties.
- Relationship traversal: `#Predicate<Stop> { $0.trip?.isActive == true }`.

**NOT supported (compile error or runtime failure):**
- Calling arbitrary functions/methods on your types.
- **Computed properties** (they don't exist in the store — filter on the stored properties that back them).
- Non-trivial closures, captured non-literal transforms, `switch`, most `Foundation` formatting.
- Force-unwraps and constructs the query compiler can't translate.

When you need logic the predicate can't express, either restructure the model (store a computed value as a real property) or fetch a coarse set and **filter the remainder in memory** — deliberately, knowing you traded store-side efficiency for expressiveness.

### Complex predicates

```swift
let cutoff = Date.now.addingTimeInterval(-7 * 86_400)
let predicate = #Predicate<Trip> { trip in
    trip.isActive &&
    trip.startDate > cutoff &&
    trip.stops.contains { $0.name.localizedStandardContains("airport") }
}
```

Build predicates as `let` values when they're reused or conditional; assign them into `FetchDescriptor` or `@Query`.

## `FetchDescriptor` — programmatic & background reads

Outside a view (services, `@ModelActor`, one-off reads) use `FetchDescriptor`:

```swift
var descriptor = FetchDescriptor<Trip>(
    predicate: #Predicate { $0.isActive },
    sortBy: [SortDescriptor(\.startDate, order: .reverse)]
)
descriptor.fetchLimit = 50                 // pagination / cap
descriptor.fetchOffset = 0
descriptor.includePendingChanges = true    // see unsaved inserts/edits in this context (default true)
descriptor.propertiesToFetch = [\.name]    // partial fetch for lighter rows (optimization)
descriptor.relationshipKeyPathsForPrefetching = [\.stops]  // avoid N+1 when you'll touch stops

let trips = try context.fetch(descriptor)
```

### Count without materializing

To answer "how many?", never `fetch().count` (which loads every object):

```swift
let active = try context.fetchCount(FetchDescriptor<Trip>(predicate: #Predicate { $0.isActive }))
```

### Stream large results

For big result sets, `enumerate` processes in batches without holding everything in memory at once:

```swift
try context.enumerate(FetchDescriptor<Trip>()) { trip in
    // process one at a time; SwiftData manages batching & autorelease
}
```

## Fetch a specific object by identity

When you have a `PersistentIdentifier` (e.g. handed from another actor), resolve it in the current context:

```swift
if let trip = context.model(for: id) as? Trip { /* … */ }
// or a registered-object lookup:
let trip = context.registeredModel(for: id) as Trip?
```

This is the standard cross-actor pattern (see `concurrency.md`): pass the ID, re-fetch on the far side.

## Pitfalls

- **Sorting/filtering on an unindexed property at scale** → full scan. Add `#Index` for the key paths you query and sort by (`models.md`).
- **`@Query` doing heavy filtering on the main actor** for large stores janks the UI — page with `fetchLimit`, or fetch on a `@ModelActor` and pass results back.
- **Predicate referencing a computed property** — silently wrong or a crash; filter on stored properties instead.
- **Rebuilding a dynamic `@Query` every keystroke** without debouncing thrashes the store — debounce the input.
