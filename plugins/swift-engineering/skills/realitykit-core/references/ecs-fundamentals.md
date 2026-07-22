# ECS Fundamentals: Entities, Components, Systems

> Some APIs here ship in 2025–2026 releases, newer than this guidance's training data. Confirm exact type names and signatures against current Apple documentation.

RealityKit is built on the **Entity Component System** pattern. Internalize these three types and everything else falls into place.

## Entity

An `Entity` is a lightweight handle for an object in the scene. Created on its own, it has **no geometry, no special behavior, and sits at its parent's origin** — it's an empty container waiting for components.

```swift
let entity = Entity()
entity.name = "Robot"                 // names are how you find entities later
parent.addChild(entity)               // entities form a tree
```

Entities own: a `name`, a parent/children hierarchy, a `components` set, and `isEnabled` (a disabled entity and its subtree stop rendering and updating).

## Component

A `Component` is a **plain data value** attached to an entity. It holds state; it contains no per-frame logic. RealityKit ships dozens — `Transform`, `ModelComponent`, `PhysicsBodyComponent`, `CollisionComponent`, `ParticleEmitterComponent`, `AnchoringComponent`, `PortalComponent`, and the newer `ManipulationComponent`, `EnvironmentBlendingComponent`, `MeshInstancesComponent`, `ImagePresentationComponent`, `ViewAttachmentComponent`, `GestureComponent`, `PresentationComponent` — and you write your own.

```swift
// Read (returns a COPY — value semantics)
if var model = entity.components[ModelComponent.self] {
    model.materials = [newMaterial]
    entity.components.set(model)      // MUST write the mutated copy back
}

// Add / replace
entity.components.set(PhysicsBodyComponent())

// Test / remove
let hasPhysics = entity.components.has(PhysicsBodyComponent.self)
entity.components.remove(CollisionComponent.self)
```

### Writing a custom component

```swift
struct HealthComponent: Component {
    var current: Float = 100
    var max: Float = 100
}
```

Conform to `Component`. Add `Codable` if the component should be authored/serialized in Reality Composer Pro or saved to a Reality File. Register it once at launch so RealityKit (and RCP) know the type:

```swift
HealthComponent.registerComponent()   // confirm exact registration API
```

## System

A `System` holds the **logic**. Each frame, RealityKit calls a system's `update`, where it queries for entities that have the components it operates on and mutates them.

```swift
struct HealthRegenSystem: System {
    static let query = EntityQuery(where: .has(HealthComponent.self))

    init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var health = entity.components[HealthComponent.self] else { continue }
            health.current = min(health.max, health.current + Float(context.deltaTime) * 5)
            entity.components.set(health)     // write-back, always
        }
    }
}
```

Register systems once at launch:

```swift
HealthRegenSystem.registerSystem()          // confirm exact registration API
```

Built-in systems already handle rendering, physics, particle animation, audio, and animation playback — you only write a system for behavior that's unique to your app.

## The golden rules

- **Components are values; write mutations back.** `components[T.self]` hands you a copy. Mutating it does nothing until `components.set(_:)`. This is the #1 ECS bug.
- **Never subclass `Entity` for behavior.** Compose components; put logic in systems. (Subclassing to bundle a fixed set of components in an initializer is fine, e.g. a `ModelEntity`.)
- **Query, don't traverse.** Let `EntityQuery` find the entities a system cares about instead of walking the tree by hand every frame.
- **Register custom components and systems at launch.** Unregistered types won't deserialize from Reality Composer Pro or drive systems.

## Why ECS

Behavior is decoupled from identity. A "teleporter" isn't a class — it's any entity with a `TeleporterComponent`, and one system spawns from all of them. Add the component to a new entity and it participates instantly; remove it and it stops. This composability is what makes RealityKit scenes flexible and debuggable (the `realitykit-debugging` skill leans entirely on inspecting an entity's component set).
