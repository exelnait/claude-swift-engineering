# Models & Schema

A SwiftData model is a plain Swift class annotated with `@Model`. The macro synthesizes persistence, change tracking, and observation — you write ordinary properties. Keep models as `final class` (SwiftData requires reference types) and let the schema fall out of the types.

## The `@Model` macro

```swift
import SwiftData

@Model
final class Trip {
    var name: String
    var startDate: Date
    var isActive: Bool
    var notes: String

    // Relationships (see below)
    @Relationship(deleteRule: .cascade, inverse: \Stop.trip)
    var stops: [Stop] = []

    init(name: String, startDate: Date = .now, isActive: Bool = true, notes: String = "") {
        self.name = name
        self.startDate = startDate
        self.isActive = isActive
        self.notes = notes
    }
}
```

- **`final class`, not `struct`.** SwiftData tracks identity and changes through a reference type. Value types can be *stored* (as properties), but the model itself is a class.
- **Every stored property is persisted** unless marked `@Transient`. Supported types: the `Codable` scalars (`String`, `Int`, `Double`, `Bool`, `Date`, `Data`, `UUID`, `URL`), optionals, arrays/dictionaries of supported types, `RawRepresentable` enums, `Codable` structs/enums, and relationships to other `@Model` types.
- **Provide an `init`.** The macro doesn't synthesize a memberwise init for you; write one (with sensible defaults — defaults also matter for CloudKit and migrations).

## `@Attribute` — column-level options

```swift
@Attribute(.unique) var email: String                 // enforce uniqueness (NOT CloudKit-compatible)
@Attribute(.externalStorage) var photo: Data          // store big blobs as separate files
@Attribute(.spotlight) var title: String              // index for Spotlight/Core Spotlight
@Attribute(.preserveValueOnDeletion) var lastSeen: Date
@Attribute(originalName: "old_column") var newName: String  // map a renamed column (lightweight migration)
```

- **`.unique`** — an upsert-style uniqueness constraint: inserting a duplicate key updates the existing row instead of erroring. **Incompatible with CloudKit** (see `container-and-context.md`).
- **`.externalStorage`** — keeps large `Data` out of the row so fetches stay fast. Use for images/attachments. (Common Mistake #10.)
- **`originalName:`** — renames a property without a full custom migration (the store column keeps its old name).

## `@Relationship` — links and delete rules

Declaring the **delete rule** is not optional in practice — the default (`.nullify`) is rarely what you want for owned children.

```swift
@Model final class Trip {
    // Parent owns its stops: deleting the Trip deletes the Stops.
    @Relationship(deleteRule: .cascade, inverse: \Stop.trip)
    var stops: [Stop] = []
}

@Model final class Stop {
    var name: String
    var trip: Trip?          // the inverse side; optional so a Stop can exist mid-edit
    init(name: String) { self.name = name }
}
```

Delete rules:
| Rule | Effect when the owner is deleted |
|------|----------------------------------|
| `.cascade` | Delete the related objects too (owned children). |
| `.nullify` *(default)* | Set the relationship to `nil`/remove from the array; keep the related objects. |
| `.deny` | Refuse the delete if the relationship is non-empty. |
| `.noAction` | Leave related objects untouched (you maintain integrity). |

- **Declare the inverse** (`inverse:`) on one side, or let SwiftData infer it from a matching property. Declaring it explicitly avoids ambiguity when two relationships connect the same pair of types.
- **Make the many-side default to `[]`** and the to-one inverse **optional** — this keeps objects insertable before the link is set and is required for CloudKit.
- `@Relationship(minimumModelCount:maximumModelCount:)` can bound a to-many relationship's size if you need it.

## Uniqueness and indexing (iOS 18+)

Prefer the macro forms for compound constraints and query speed:

```swift
@Model
final class Product {
    #Unique<Product>([\.sku])                 // compound keys: [\.a, \.b] means (a,b) unique together
    #Index<Product>([\.name], [\.price])      // one index per keypath group; speeds up sort/filter on those

    var sku: String
    var name: String
    var price: Double
    init(sku: String, name: String, price: Double) { self.sku = sku; self.name = name; self.price = price }
}
```

- **`#Unique`** expresses uniqueness (including compound) more clearly than per-property `@Attribute(.unique)` and is the modern default. Still **not** CloudKit-compatible.
- **`#Index`** creates store indexes so filtering/sorting on those key paths doesn't full-scan. Index the properties you actually query and sort by (see the "Am I scanning?" note in `concurrency.md`).

## Enums, `Codable` values, and transient state

```swift
enum Priority: Int, Codable { case low, normal, high }   // RawRepresentable enums persist directly

@Model final class Task {
    var priority: Priority                                // stored as its raw value
    var metadata: Metadata                                // a Codable struct — stored inline
    @Transient var isSelected: Bool = false               // NEVER persisted; view/session state only
    var displayName: String { "#\(id): \(title)" }        // computed — not stored, no annotation needed
    // ...
}
struct Metadata: Codable { var author: String; var version: Int }
```

- `RawRepresentable`/`Codable` enums and `Codable` structs persist without extra work (structs are embedded in the row — fine for small value objects; model a relationship instead if they need identity or independent querying).
- **`@Transient`** excludes a property from the schema (must have a default) — use it for ephemeral UI state that lives on the model instance but shouldn't hit disk.
- **Computed properties** are never stored; no annotation needed. But you generally **can't** use them inside a `#Predicate` (see `queries.md`).

## Schema hygiene

- One `@Model` per persistent concept; group them into a feature folder next to the feature's `@Observable` model and views (`swiftui-patterns` house style).
- Keep the initial schema deliberate — every property you ship becomes a migration concern later (`migrations.md`).
- If a model will ever sync via CloudKit, design it to CloudKit's rules **now** (all-optional-or-defaulted, no unique constraints, optional relationships) — retrofitting is a migration.
