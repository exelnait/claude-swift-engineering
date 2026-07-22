# Script Graph: No-Code Visual Scripting

> Script Graph shipped as part of Reality Composer Pro 3 (2025–2026 cycle). Confirm exact node names against current Apple documentation.

Script Graph is Reality Composer Pro's node-based visual scripting system: build gameplay and interactivity without writing Swift. It's **event-driven** — a graph runs in response to events, either scene-wide or on a specific entity — and because it's entirely visual, anyone on the team can build and test behavior directly in the editor, with no build cycle.

## Attaching a Script Graph

Create one from the Project Browser (right-click → New → Script Graph), then add a **Scripting Component** to the entity it should run on and assign the graph to it in the Inspector. Entities that need to respond to gestures also need the supporting components first: an **Input Target Component** (makes it a gaze/tap target), a **Collision Component** (defines the target's size), and, if it should highlight on gaze, a **Hover Effect Component**.

## Events

Every graph starts from an event node. Common ones: **On Initialize** (fires once, the first time the Scripting component initializes — a good place for setup logic), **On Drag**, **On Tap**, **Update** (fires every frame/scene update), and keypress events (often gated through an **If** node). Behavior Trees and Animation Graphs can also drive a Script Graph indirectly through the entity parameters described below.

## Set nodes: writing into components

**Set nodes** write data into components — the same components Swift/ECS code would set directly:

- **Set Transform** — write position/rotation/scale, e.g. drive an entity's translation straight from an On Drag event's scene location.
- **Set PhysicsBodyComponent** — change physics settings at runtime, e.g. disable gravity and raise linear damping while an object is held, then restore both on release.
- **Set Material Parameter** — write a Shader Graph **Promote to Input** parameter (see `shader-graph.md`), e.g. a bool that swaps which of two textures a material shows.
- **Set Entity Parameter** — set a named parameter on an entity, e.g. flip a Behavior Tree precondition bool (see `animation-graph-and-behavior-trees.md`) from a tap.

Physics nodes like **Add Force** are additive, not absolute — to drag-toss an object convincingly, store the previous drag position in a variable, subtract it from the current one each update to get a delta, and feed *that* (scaled) into Add Force, rather than feeding it a raw position.

## Public input variables + per-instance overrides

Define an **Input** variable in the Script Graph's Inspector — name, type, mark it **public**, give it a default (e.g. a Number `dragSpeed` defaulting to `1.3`). Public variables surface as editable fields on the entity's Scripting Component. Tuning that field on one instance creates an **Override** — its name turns bold to show it's no longer the shared graph's value, just this instance's. Multiple entities can share one Script Graph while each keeps its own tuned values, exactly like the prototype overrides in `scene-composition.md`.

## Custom events via a Custom Node Library

To let one entity's Script Graph talk to another's, create a **Custom Node Library** in the Project Browser and add a **Custom Event** to it (e.g. `nutIsDragged`). Give the event **properties** to carry data along (e.g. a `nutPosition` position), then click **Sync Nodes** to make it available as actual nodes. Send it with a `Send <eventName>` node (wired with its property values) from the sender's graph; receive it with an `On <eventName>` node in the listener's graph.

## Subgraphs and Prototyped Subgraphs

Select a cluster of nodes, right-click, and choose **Compose Subgraph** to collapse a busy piece of logic into one named node — it behaves like a function and cleans up a graph that's become hard to read. Right-click a subgraph and choose **Convert to Prototyped Subgraph** to reuse it across every Script Graph in the project; it then appears in the Add Node menu alongside built-in nodes. A prototyped subgraph is one source of truth for logic you need repeatedly (e.g. "trigger when this bool just changed") instead of copy-pasted node clusters that drift out of sync.

## Scene Events: crossing into Swift & SwiftUI

A **Send Scene Event** node (carrying its own variables — e.g. a String `sayThis`) sends an event out of the Script Graph to your app's code. In Xcode, subscribe to that named event, read its variables, and react — for example, showing a SwiftUI view as an attachment anchored over an entity (see `realitykit-swiftui` and `realitykit-core`'s `content.subscribe` pattern in `realityview.md`). Switching a graph's preview mode to **Run with Xcode** builds and runs the real app instead of the editor's own simulation; Reality Composer Pro creates the Xcode project for you if one doesn't exist yet.

## Testing as you build

The **Play** button tests a graph directly in the editor's viewport. **Preview on Device** (Live Preview, shipping later in the year — confirm current availability) runs the same simulation live on a connected Vision Pro; pair it with **Mac Virtual Display** so you can adjust values (like a public-variable override) on the Mac while watching or feeling the result on-device.

## Common mistakes

1. **Feeding Add Force a raw position instead of a delta.** It's additive — wire in the absolute drag position and the object accelerates away; compute the change since the last update instead.
2. **Setting a physics override on pickup and never restoring it.** A Set PhysicsBodyComponent that disables gravity/raises damping needs a matching Set node on release, or the object stays permanently altered after the interaction ends.
3. **Being surprised a tuned public variable only affected one instance.** The bold name means you created an override on that Scripting Component, not a change to the shared graph — the same model as prototype overrides.
4. **Copy-pasting a node cluster instead of making it a Prototyped Subgraph.** Duplicated logic drifts; convert repeated patterns once and reuse them everywhere.
5. **Forgetting the input-target scaffolding before wiring a gesture event.** On Drag/On Tap need an Input Target Component (usually plus Collision and Hover Effect) on the entity, or the event never fires.
6. **Letting a graph grow past the point Script Graph is comfortable.** Very large graphs get hard to maintain — that's a real signal to move the logic into a custom `Component`/`System` via an Xcode plugin (see `plugins-custom-components.md`), not a failure of Script Graph.
