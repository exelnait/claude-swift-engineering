---
name: data-layer-decisions
description: Use when designing the persistence layer for a new feature, choosing between SwiftData and SQLite/GRDB, or combining both. Covers hybrid architectures, decision trees, and migration patterns.
---

# Data Layer Decisions

Modern iOS apps frequently combine SwiftData (default) with SQLite/GRDB (for specific needs). This skill documents when to use each and how to combine them cleanly.

## Default: SwiftData

Use SwiftData for:
- User-created entities (notes, items, profile, settings, progress)
- Lesson/session state, onboarding state
- Lightweight relational data (<10K rows per table)
- Anything where SwiftUI `@Query` reactivity is valuable
- Data shared via App Group with widgets/extensions (works seamlessly)

## Add SQLite/GRDB When

| Need | Why SwiftData fails | What GRDB provides |
|---|---|---|
| Full-text search | No FTS5 support | `CREATE VIRTUAL TABLE ... USING fts5` |
| AI cache / embeddings | Vector similarity queries awkward | Raw SQL, custom functions, blob storage |
| Analytics events buffer | Schema churn breaks SwiftData migrations | Append-only table, simple schema |
| Generated content >10K rows | `@Query` re-evaluates on every write | ValueObservation with region filtering |
| Complex JOINs across 4+ tables | Predicates get unwieldy | Raw SQL, window functions |
| Performance profiling required | Black-box query plan | `EXPLAIN QUERY PLAN` |

## Hybrid Pattern

Keep one SwiftData container as the canonical store, add GRDB as a side-store for specific concerns.

```swift
// App composition
@main
struct MyApp: App {
    let modelContainer: ModelContainer       // SwiftData primary
    let searchStore: SearchIndexStore         // GRDB side-store
    let analyticsStore: AnalyticsStore        // GRDB side-store

    init() {
        modelContainer = try! ModelContainer(...)
        searchStore = try! SearchIndexStore(at: appGroupURL.appending("search.sqlite"))
        analyticsStore = try! AnalyticsStore(at: appGroupURL.appending("analytics.sqlite"))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(modelContainer)
                .environment(searchStore)
                .environment(analyticsStore)
        }
    }
}
```

Synchronization patterns:
- **SwiftData writes → GRDB indexes:** Hook into model save via custom service. Don't try to make SwiftData own the FTS table.
- **Background sync:** GRDB writes happen on a background queue; main store stays responsive.
- **App Group:** Both can live in the same App Group container; the widget can read both.

## Anti-Patterns

1. **Using GRDB for everything because "it's faster"** — SwiftData's `@Query` is free reactivity. Don't give that up for entities.
2. **Putting search inside SwiftData** — SwiftData predicates can't do FTS. Trying to fake it with `.contains()` over a large table tanks performance.
3. **Duplicating data between stores** — One source of truth per entity. Indexes derive from SwiftData; analytics is its own thing.
4. **Coupling tightly** — Keep the GRDB store behind a service interface. The feature code shouldn't know which store backs it.

## Decision Tree

```
New feature needs persistence
         │
         ▼
Is data a user entity (notes, profile, progress)?
     │yes                │no
     ▼                   ▼
SwiftData           Is it a search index?
(@Model + @Query)        │yes                │no
                         ▼                   ▼
                       GRDB              Is it analytics/events?
                      (FTS5)                  │yes          │no
                                              ▼             ▼
                                            GRDB        UserDefaults
                                         (append-only)  (simple prefs)
```

## Migration Patterns

- **Pure SwiftData → Hybrid:** Add the GRDB store, populate it from existing SwiftData rows on first launch, hook the sync going forward.
- **Pure GRDB → SwiftData:** Almost never the right move. SwiftData migration cost is high; only do this if the data is small and you want @Query reactivity.

## When To Just Use One

| App profile | Recommendation |
|---|---|
| <2K total rows, no search | SwiftData only |
| Heavy search + recommendations + analytics | Hybrid |
| Sync engine with CloudKit | SwiftData only (CloudKit integration is built-in) |
| Offline-first with complex queries | Hybrid, GRDB for queries |
| Simple key-value preferences | UserDefaults only |

## Reference Loading Guide

| Reference | Load When |
|---|---|
| **[Hybrid Examples](references/hybrid-examples.md)** | Concrete code patterns for SwiftData + GRDB coexistence |
| **[Sync Patterns](references/sync-patterns.md)** | Keeping the two stores consistent |
| **[Migration Workflows](references/migration-workflows.md)** | Adding GRDB to an existing SwiftData app |
