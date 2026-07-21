# Transform & Component Bugs

> Some APIs here (custom component registration, exact query/system signatures) ship in 2025–2026 releases. Confirm exact names against current Apple documentation.

RealityKit's two most common classes of "silent" bugs — content in the wrong place, and systems that appear to do nothing — both come from the same ECS fundamentals covered in `realitykit-core`. The debugger is how you *see* them instead of guessing.

## Rogue and inherited transforms

An entity's final placement is **its own transform composed with every ancestor's**. A scale, rotation, or translation you applied to get one entity's shape right silently reapplies to everything underneath it in the hierarchy.

Concretely: a "Support" entity scaled hard along Y to get its own shape distorts a "Disco Ball" nested several levels below it — the ball's own `Transform` is perfectly uniform, and its mesh previews clean in isolation, but composed with the Support's Y-scale it renders squished. Walking the hierarchy one level at a time — checking the preview viewport and the raw `Transform` values at each ancestor — finds the exact level where the scale stops being 1 (or the rotation stops being identity). That's the culprit, even if it's several levels removed from the entity you started at.

**Fix pattern:** either correct the ancestor's transform (if it wasn't supposed to be non-uniform in the first place), or **re-parent** the affected entity so it's a **sibling** rather than a descendant of the offending ancestor:

```swift
// `discoBall` was a child of `support` and inherited its Y scale.
// Re-parent it to be a sibling instead — still visually connected in the
// scene, no longer sharing a transform.
support.parent?.addChild(discoBall)
```

This is the exact fix pattern taught in `realitykit-core`'s `transforms-and-coordinates.md` — this skill is that same mental model applied with the debugger as the diagnostic tool.

## The component write-back rule

`entity.components[SomeComponent.self]` returns a **value-type copy**. Mutating a field on that copy changes nothing until you assign it back with `entity.components.set(_:)`. Forgetting this line is the single most common ECS bug, and it's easy to miss in code review because everything *compiles* and the system *runs* — it just silently has no effect.

```swift
guard var control = entity.components[ControlCenterComponent.self] else { continue }
control.countdown -= Float(context.deltaTime)
entity.components.set(control)     // omit this and countdown never appears to change
```

**How it shows up in the debugger:** the component's field sits at exactly the value it was initialized with, no matter when you capture — a countdown that never counts down, a state enum that never advances. Since the debugger captures the app's *actual* live state at the moment you pause, a value that should be changing over time but never does is the tell. Confirm in code that every mutation path ends in a `.set(_:)` call.

## Missing or misconfigured components make systems unpredictable

A system's behavior is only as good as the components it finds via its `EntityQuery`. If an entity is missing a component the system expects (or has one configured with the wrong values), the system either skips it silently or acts on wrong data — there's no error, just behavior that doesn't match your mental model of what should happen.

When a system "does nothing," check both ends before assuming the logic itself is wrong:

1. **Do the entities it should act on actually have the expected component?** Select each one in the hierarchy and check the inspector directly — don't assume your setup code ran the way you think it did.
2. **Is the component holding the system's own data actually changing over time?** If not, see the write-back rule above.

## Common mistakes

1. **Blaming the mesh before checking ancestors.** If an entity's own transform and preview are clean, the distortion is inherited — walk up, don't re-author the mesh.
2. **Non-uniform scale applied for one entity's shape, forgotten by the time it has descendants.** Prefer re-parenting affected content to a sibling over trying to "undo" the scale further down the tree.
3. **Assuming a component is present because you remember adding it.** Confirm in the inspector; copy-paste setup code is a common way for one entity in a group to end up missing a component the others have.
4. **Chasing system logic when the real bug is a missing write-back.** Before rewriting a system's logic, confirm its component's fields are actually changing across captures — if not, look for the missing `.set(_:)` first.
