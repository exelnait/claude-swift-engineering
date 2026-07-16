# Schema Migrations

The moment your app ships, the schema is a contract with data already on users' devices. Additive changes migrate automatically; anything else needs a plan, or the app fails to open the old store (Common Mistake #9).

## Lightweight vs. custom

- **Lightweight (automatic):** adding an optional property, adding a property with a default, adding a new model, renaming via `@Attribute(originalName:)`. SwiftData infers these — no code needed, but you should still capture them as a version (below) so the sequence is explicit.
- **Custom (a `MigrationStage`):** renaming a model, changing a property's type, splitting/merging properties, deduplicating to add a `#Unique`, or any data transform. These need a `VersionedSchema` per version and a `SchemaMigrationPlan` describing the steps.

## Versioned schemas

Snapshot the schema at each shipped version. Each `VersionedSchema` lists the models *as they were* at that version.

```swift
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Trip.self, Stop.self] }

    @Model final class Trip {
        var title: String            // v1 called it `title`
        var startDate: Date
        init(title: String, startDate: Date) { self.title = title; self.startDate = startDate }
    }
    @Model final class Stop { /* v1 shape */ }
}

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Trip.self, Stop.self] }

    @Model final class Trip {
        var name: String             // v2 renamed title -> name AND derives a new field
        var startDate: Date
        var year: Int                // new, derived during migration
        init(name: String, startDate: Date, year: Int) { self.name = name; self.startDate = startDate; self.year = year }
    }
    @Model final class Stop { /* v2 shape */ }
}
```

> In practice you keep the *current* schema as your live `@Model` files and let the latest `VersionedSchema` reference them; older versions hold frozen copies. Organize so the current models aren't duplicated needlessly — but each historical `VersionedSchema` must faithfully describe that past shape.

## The migration plan

```swift
enum TripsMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] { [migrateV1toV2] }

    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: { context in
            // Runs BEFORE the store is transformed. Deduplicate here if adding a unique constraint.
            let trips = try context.fetch(FetchDescriptor<SchemaV1.Trip>())
            // …resolve duplicates so the new #Unique won't be violated…
            try context.save()
        },
        didMigrate: { context in
            // Runs AFTER. Populate/transform new fields from old data.
            let trips = try context.fetch(FetchDescriptor<SchemaV2.Trip>())
            let cal = Calendar.current
            for trip in trips { trip.year = cal.component(.year, from: trip.startDate) }
            try context.save()
        }
    )
}
```

For a purely mechanical version bump with no data work, use `MigrationStage.lightweight(fromVersion:toVersion:)` instead of `.custom`.

## Wire the plan into the container

```swift
let container = try ModelContainer(
    for: Schema(versionedSchema: SchemaV2.self),      // current schema
    migrationPlan: TripsMigrationPlan.self,
    configurations: [ModelConfiguration(/* … */)]
)
```

SwiftData walks `schemas` in order and applies the `stages` needed to bring an old store up to the current version on first open.

## Rules that keep migrations safe

- **Never mutate a shipped `VersionedSchema`.** Once a version is in users' hands, it's frozen — add a *new* version for further changes.
- **Deduplicate in `willMigrate`** before introducing a `#Unique`/`.unique`, or the constraint fails on existing duplicate data.
- **Derive new non-optional fields in `didMigrate`** (or give them defaults), so the transformed store is valid.
- **CloudKit stores** can't take unique constraints at all — plan schema evolution within CloudKit's rules (`container-and-context.md`).
- **Order matters:** list schemas oldest→newest; a user two versions behind must be able to walk V1→V2→V3.

## Test every migration

Migrations are the highest-risk code you ship — they run once, on real user data, with no retry. Test them:

1. Build a store with the **old** schema and representative data (including edge cases: duplicates, nulls, empties).
2. Open it with the **new** container + migration plan.
3. Assert the transformed data is correct (renamed fields carried over, derived fields populated, no rows lost, constraints satisfied).

Do this in Swift Testing against on-disk temp stores (not in-memory, since some migration behavior differs) — see `testing-and-previews.md` for the harness shape.
