# Migration Workflows — Adding GRDB to an Existing SwiftData App

**iOS 26+**

## When To Add GRDB to an Existing SwiftData App

- Users report search is slow or unavailable
- You're adding full-text search (FTS5) over existing entities
- Analytics events need a buffer that survives SwiftData schema migrations
- AI cache or embedding store is needed

## Step-by-Step: Adding a GRDB Search Index

### 1. Add GRDB dependency

In your `Package.swift`:
```swift
.package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0")
```

### 2. Create the side store

```swift
// SearchIndexStore.swift
import GRDB

final class SearchIndexStore: Sendable {
    static let shared = try! SearchIndexStore()

    private let dbPool: DatabasePool

    init() throws {
        let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "search-index.sqlite")
        dbPool = try DatabasePool(path: url.path)
        try migrate()
    }

    // ... migrations + index/search methods
}
```

### 3. Populate from existing SwiftData data (first launch)

```swift
@Observable
final class AppSetupModel {
    func performFirstLaunchSetup(modelContext: ModelContext) async throws {
        let needsIndexBuild = !UserDefaults.standard.bool(forKey: "searchIndexBuilt")
        guard needsIndexBuild else { return }

        let notes = try modelContext.fetch(FetchDescriptor<Note>())
        for note in notes {
            try SearchIndexStore.shared.index(
                noteID: note.id,
                title: note.title,
                body: note.body
            )
        }
        UserDefaults.standard.set(true, forKey: "searchIndexBuilt")
    }
}
```

### 4. Hook into future saves

Add a sync call in your save path. The GRDB index update is a side effect — it never blocks the save.

### 5. Inject the store into the environment

```swift
@main
struct MyApp: App {
    let searchStore = try! SearchIndexStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(searchStore)
        }
    }
}
```

## What NOT To Do

- Don't try to migrate SwiftData schema at the same time — do one migration at a time.
- Don't add GRDB until the search/performance problem is confirmed. SwiftData predicate search is fine for <5K rows.
- Don't make GRDB the new primary store — it remains a derived cache.
