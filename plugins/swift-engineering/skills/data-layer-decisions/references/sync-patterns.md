# Sync Patterns — SwiftData + GRDB

**iOS 26+**

## The Core Rule

One source of truth per entity. SwiftData owns the entity; GRDB indexes derive from it. Never let GRDB become an authoritative store for data that SwiftData already manages.

## Pattern 1: Post-Save Hook

Trigger GRDB index updates immediately after a SwiftData save.

```swift
// In your @Observable model or service
func save(_ note: Note) throws {
    try modelContext.save()          // SwiftData is source of truth
    syncService.noteDidSave(note)    // Fire-and-forget to GRDB index
}
```

Use when: low-latency search updates are important.

## Pattern 2: Background Batch Sync

Periodically re-index from SwiftData in a background task.

```swift
func rebuildSearchIndex() async throws {
    let descriptor = FetchDescriptor<Note>()
    let notes = try modelContext.fetch(descriptor)
    for note in notes {
        try searchStore.index(noteID: note.id, title: note.title, body: note.body)
    }
}
```

Use when: the GRDB store is a cache that can be rebuilt from scratch (e.g., after a schema migration).

## Pattern 3: Differential Sync

Track a "last synced" timestamp and only re-index changed records.

```swift
func syncChangedNotes(since date: Date) async throws {
    let descriptor = FetchDescriptor<Note>(
        predicate: #Predicate { $0.modifiedAt > date }
    )
    let changedNotes = try modelContext.fetch(descriptor)
    for note in changedNotes {
        try searchStore.index(noteID: note.id, title: note.title, body: note.body)
    }
    UserDefaults.standard.set(Date(), forKey: "lastSearchIndexSync")
}
```

Use when: the entity collection is large and post-save hooks are too expensive.

## Deletion Handling

Don't forget to remove deleted entities from the GRDB index.

```swift
func delete(_ note: Note) throws {
    let id = note.id
    modelContext.delete(note)
    try modelContext.save()
    try searchStore.removeIndex(noteID: id)   // Clean up GRDB
}
```

## Consistency Guarantees

- GRDB is an eventually-consistent cache, not a transaction participant.
- A crash between SwiftData save and GRDB index update leaves the index stale — not corrupt.
- Rebuild from SwiftData on next launch if you detect staleness.
- Never use GRDB as the rollback source for SwiftData failures.
