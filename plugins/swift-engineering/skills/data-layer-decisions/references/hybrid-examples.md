# Hybrid SwiftData + GRDB Examples

**iOS 26+**

## Full-Text Search Side Store

```swift
// SearchIndexStore.swift — GRDB side store
import GRDB

final class SearchIndexStore: Sendable {
    private let dbPool: DatabasePool

    init(at url: URL) throws {
        dbPool = try DatabasePool(path: url.path)
        try migrate()
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts
                USING fts5(id UNINDEXED, title, body, tokenize='porter unicode61')
            """)
        }
        try migrator.migrate(dbPool)
    }

    func index(noteID: UUID, title: String, body: String) throws {
        try dbPool.write { db in
            try db.execute(
                sql: "INSERT OR REPLACE INTO notes_fts(id, title, body) VALUES (?, ?, ?)",
                arguments: [noteID.uuidString, title, body]
            )
        }
    }

    func search(query: String) throws -> [UUID] {
        try dbPool.read { db in
            let rows = try Row.fetchAll(db,
                sql: "SELECT id FROM notes_fts WHERE notes_fts MATCH ? ORDER BY rank",
                arguments: [query]
            )
            return rows.compactMap { UUID(uuidString: $0["id"]) }
        }
    }
}
```

## Sync Service

```swift
// NotesSyncService.swift — keeps SwiftData and GRDB in sync
@Observable
final class NotesSyncService {
    private let searchStore: SearchIndexStore

    init(searchStore: SearchIndexStore) {
        self.searchStore = searchStore
    }

    func noteDidSave(_ note: Note) {
        Task.detached(priority: .background) { [searchStore] in
            try? searchStore.index(
                noteID: note.id,
                title: note.title,
                body: note.body
            )
        }
    }
}
```

## Feature Model Using Both

```swift
@Observable
final class NotesModel {
    private let modelContext: ModelContext
    private let searchStore: SearchIndexStore

    var searchResults: [Note] = []
    var query = ""

    init(modelContext: ModelContext, searchStore: SearchIndexStore) {
        self.modelContext = modelContext
        self.searchStore = searchStore
    }

    func search() {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        Task {
            let ids = try searchStore.search(query: query)
            // Fetch matching Note entities from SwiftData by ID
            let descriptor = FetchDescriptor<Note>(
                predicate: #Predicate { ids.contains($0.id) }
            )
            searchResults = (try? modelContext.fetch(descriptor)) ?? []
        }
    }
}
```

## Analytics Side Store

```swift
// AnalyticsStore.swift — append-only event buffer
final class AnalyticsStore: Sendable {
    private let dbQueue: DatabaseQueue

    init(at url: URL) throws {
        dbQueue = try DatabaseQueue(path: url.path)
        try migrate()
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "events") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("properties", .text)
                t.column("timestamp", .datetime).notNull().defaults(to: DatabaseFunction.currentTimestamp)
            }
        }
        try migrator.migrate(dbQueue)
    }

    func track(name: String, properties: [String: String] = [:]) {
        let json = try? JSONEncoder().encode(properties)
        let jsonString = json.flatMap { String(data: $0, encoding: .utf8) }
        try? dbQueue.write { db in
            try db.execute(
                sql: "INSERT INTO events(name, properties) VALUES (?, ?)",
                arguments: [name, jsonString]
            )
        }
    }

    func flush() throws -> [[String: Any]] {
        try dbQueue.write { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM events ORDER BY id LIMIT 100")
            let ids = rows.compactMap { $0["id"] as? Int64 }
            if !ids.isEmpty {
                let placeholders = ids.map { _ in "?" }.joined(separator: ",")
                try db.execute(sql: "DELETE FROM events WHERE id IN (\(placeholders))",
                               arguments: StatementArguments(ids))
            }
            return rows.map { Dictionary($0) }
        }
    }
}
```
