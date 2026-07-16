---
name: swiftdata
description: >-
  Use when implementing persistence with SwiftData — the plugin's default entity store. Covers the `@Model` schema macro (`@Attribute`, `@Relationship`, delete rules, `#Unique`, `#Index`), reading with `@Query`/`#Predicate`/`FetchDescriptor`, `ModelContainer`/`ModelContext` setup and saving, background work and threading with `@ModelActor` (and why you pass `PersistentIdentifier`, never a model, across actors), versioned schema migrations, CloudKit sync and its constraints, and testing/previews with in-memory containers. This is the *implementation* skill; for choosing SwiftData vs GRDB vs SQLite see `data-layer-decisions`, and for those alternatives see `sqlite-data` / `grdb`. Load whenever a feature defines, stores, queries, migrates, or tests persistent model data.
---

# SwiftData (iOS 26+)

SwiftData is this plugin's **default entity store** — the primary home for your app's persistent model graph, paired with `@Observable` and feature folders. It replaces the Core Data boilerplate with a macro-driven schema (`@Model`), declarative reads (`@Query`, `#Predicate`), and a container/context pair that SwiftUI wires into the environment for you. This skill is the *how*; `data-layer-decisions` is the *when* (and when to reach for `sqlite-data`/`grdb` instead).

The core principle: **describe your data as plain Swift types annotated with `@Model`, read it declaratively, and keep all mutation on a context you own — the main context for UI, a `@ModelActor` for background work.** No `NSManagedObject`, no `.xcdatamodeld`, no fetch-request ceremony.

## Quick Reference

| Need | Use | Not |
|------|-----|-----|
| Define a persistent entity | `@Model final class Trip { … }` | `NSManagedObject`, `.xcdatamodeld` |
| Unique constraint | `#Unique<Trip>([\.name])` (iOS 18+) or `@Attribute(.unique)` | manual dedup |
| Index for query speed | `#Index<Trip>([\.startDate])` (iOS 18+) | unindexed scans |
| One-to-many link | `@Relationship(deleteRule: .cascade) var stops: [Stop]` | untyped foreign keys |
| Large blob | `@Attribute(.externalStorage) var photo: Data` | inline `Data` in the row |
| Read in a view | `@Query(sort: \.startDate) var trips: [Trip]` | manual fetch in `onAppear` |
| Filtered read | `@Query(filter: #Predicate { $0.isActive })` | fetch-all-then-filter |
| Programmatic read | `context.fetch(FetchDescriptor<Trip>(...))` | `@Query` outside a view |
| App-level store | `.modelContainer(for: Trip.self)` at the root | a container per view |
| Mutate + persist | `context.insert(_:)` / `context.delete(_:)` (+ autosave or `save()`) | mutating detached copies |
| Background write | `@ModelActor` + pass `PersistentIdentifier` | a `@Model` across threads |
| Schema change | `VersionedSchema` + `SchemaMigrationPlan` | editing the model and hoping |
| Test/preview store | `ModelContainer(..., ModelConfiguration(isStoredInMemoryOnly: true))` | the real on-disk store |

## Core Workflow

1. **Model the graph.** Annotate final classes with `@Model`; declare relationships with explicit **delete rules** and let inverses be inferred (or declare them). Reach for `#Unique`/`#Index` where correctness or speed needs it.
2. **Install one container at the app root** with `.modelContainer(for:)` (or a custom `ModelContainer` you build). One container per store, shared by the whole app.
3. **Read with `@Query`** in views (it re-runs automatically as data changes); use `FetchDescriptor` + `context.fetch` for programmatic/background reads.
4. **Mutate through a `ModelContext`.** The main context (from the environment) for UI-driven changes; a `@ModelActor`'s context for anything heavy. Save explicitly at meaningful boundaries even with autosave on.
5. **Never move `@Model` instances between actors.** Pass the Sendable `PersistentIdentifier` and re-fetch on the other side.
6. **Plan migrations before you ship a schema change** — lightweight for additive changes, a custom `MigrationStage` for renames/transforms.
7. **Test and preview against an in-memory container** with seeded sample data.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** SwiftData's sharp edges (threading, predicate limits, CloudKit constraints, migrations) are exactly where guessing causes data loss or crashes.

| Reference | Load When |
|-----------|-----------|
| **[Models & Schema](references/models.md)** | Defining `@Model` classes — `@Attribute` options (`.unique`, `.externalStorage`, `.transformable`, `.spotlight`), `@Relationship` and delete rules, inverses, `#Unique`/`#Index`, enums/`Codable` values, `.transient`, computed properties |
| **[Queries & Predicates](references/queries.md)** | Reading data — `@Query` sort/filter/animation, `#Predicate` and its supported/unsupported operations, `FetchDescriptor`, `SortDescriptor`, dynamic/runtime queries, `fetchLimit`/pagination, `fetchCount`, `enumerate` |
| **[Container & Context](references/container-and-context.md)** | Setting up storage and saving — `ModelContainer`/`ModelConfiguration` (multiple stores, in-memory, autosave), `ModelContext` (`insert`/`delete`/`save`/`rollback`/`hasChanges`), environment wiring, and CloudKit sync + its hard constraints |
| **[Concurrency & Performance](references/concurrency.md)** | Anything off the main thread or at scale — `@ModelActor`, `PersistentIdentifier` as the cross-actor handle, background writes, batch operations, indexing, avoiding main-context jank, `fetchCount` over `fetch().count` |
| **[Schema Migrations](references/migrations.md)** | Changing a shipped schema — `VersionedSchema`, `SchemaMigrationPlan`, lightweight vs. custom `MigrationStage`, `willMigrate`/`didMigrate`, and how to test a migration |
| **[Testing & Previews](references/testing-and-previews.md)** | Writing `#Preview`s or Swift Testing tests — in-memory `ModelContainer`, seeding sample data, `@MainActor` setup, isolating each test's store |

## Common Mistakes

1. **Passing a `@Model` across threads/actors.** `@Model` instances are **not `Sendable`** and are bound to the context that fetched them. Hand a `PersistentIdentifier` (which *is* Sendable) to the other actor and re-fetch there. Sharing the instance directly is a data race and a crash waiting to happen — see **Concurrency & Performance**.

2. **Heavy fetches or writes on the main context.** The environment `modelContext` runs on the main actor; large fetches, imports, or batch deletes there freeze the UI. Move them to a `@ModelActor` background context and only surface results (or `PersistentIdentifier`s) back to the UI.

3. **`#Predicate` with unsupported operations.** `#Predicate` compiles to the store's query language and supports only a subset of Swift (basic comparisons, `contains`, `starts(with:)`, relationship traversal). Calling arbitrary methods, using non-trivial closures, or referencing computed properties fails to compile or throws at runtime. Keep predicates simple; do complex filtering in memory or restructure the model. See **Queries & Predicates**.

4. **Missing or wrong delete rules on relationships.** Without an explicit `deleteRule`, deleting a parent may orphan or unexpectedly cascade to children. Declare `.cascade` (delete children with the parent) or `.nullify` (just break the link) deliberately, and set the inverse so the graph stays consistent. See **Models & Schema**.

5. **`@Attribute(.unique)` with CloudKit.** CloudKit-backed stores **forbid unique constraints** and require every property to be optional or have a default, and every relationship to be optional. A `.unique` attribute (or a non-optional without default) silently breaks sync. Design CloudKit models to those rules from the start — see **Container & Context**.

6. **Relying on autosave for critical writes.** Autosave (on by default for the main container) saves *eventually*, not immediately. For data that must survive a crash or hand-off, call `context.save()` at the meaningful boundary. Conversely, don't call `save()` in a tight loop — batch, then save once.

7. **More than one `ModelContainer` for the same store.** Two containers over the same file fight each other. Build **one** container at the app root and share it; create additional *contexts* (not containers) for background work, all from that one container.

8. **`@Query` without a container in the environment.** `@Query` needs a `modelContext` in the SwiftUI environment; forget `.modelContainer(...)` at the root and the view crashes or shows nothing. Inject the container once at the top.

9. **Editing a shipped schema with no migration plan.** Adding an optional property migrates lightly; renaming, changing types, or adding a unique constraint does **not** and will fail to open the old store. Ship a `VersionedSchema` + `SchemaMigrationPlan` — see **Schema Migrations**.

10. **Storing large binary data inline.** Big `Data` (images, attachments) bloats the row and slows every fetch. Mark it `@Attribute(.externalStorage)` so SwiftData stores it as a separate file and keeps the row lean.
