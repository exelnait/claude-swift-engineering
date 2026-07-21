# Animation Graph, Behavior Trees & Navigation Mesh

> These editors shipped as part of Reality Composer Pro 3 (2025–2026 cycle). Confirm exact node names and parameters against current Apple documentation.

Character motion in Reality Composer Pro splits into three visual tools that stack on top of each other: **Animation Graph** decides which animation is playing and how it blends, **Behavior Tree** decides what the character is autonomously doing and where it's going, and **Navigation Mesh** decides how it gets there without walking through obstacles. Script Graph (see `script-graph.md`) is the glue that lets the other two react to gameplay events.

## Animation Graph: blending animation at runtime

Animation Graph is a node-based editor for how a character animates at runtime — it supports blending, motion warping, blend spaces, and inverse kinematics, among other capabilities (`// confirm exact node names for these beyond the state-machine workflow below`).

Every graph starts with a **Final Pose** node — whichever pose flows into it is what the character displays. The usual next step:

1. Drag a **State Machine** node into the Final Pose's input, then double-click it to step inside its own editor.
2. Add an **Animation State** node per state (e.g. `Idle`, `Walk`).
3. Give each state a source by dragging from its input and adding an **Animation Clip** node pointing at the corresponding timeline.
4. Drag between states to add **transitions** (one each direction if the character should be able to return, e.g. Idle → Walk and Walk → Idle).
5. Before wiring a condition, define the input it reads in the graph's **Inputs Inspector** — e.g. a Bool `isWalking` you'll set at runtime.
6. Select a transition → Inspector → add a **Bool Condition** checking `isWalking == true` (and the inverted check on the return transition).

Back out to the main graph and the State Machine node now exposes one input per state to plug Animation Clips into. Press Play and toggle `isWalking` in the Inspector to test the blend live — the currently active state node highlights in the graph as the character transitions, which is the main tool for debugging a graph with many states.

Runtime inputs like `isWalking` are exactly what a Behavior Tree's **Parameter Setter** (below) or a Script Graph drives during real gameplay.

## Behavior Trees: autonomous, multi-step routines

A Behavior Tree authors an entity's autonomous behavior — patrolling, reacting to events, running a routine — as a hierarchy of nodes, entirely in the editor. **Evaluation order is top to bottom, and left to right among siblings**: higher and left-most nodes always run first.

Two node kinds:

- **Composite** nodes control flow:
  - **Sequence** — runs its children in order; if any fails, the whole sequence stops immediately.
  - **Selector** — tries children in order until one succeeds, then stops.
  - **Parallel** — runs all of its children at the same time.
- **Action** nodes do the actual work and are always children of a Composite. Built-ins include **Move To** (walk to a destination), **Rotate To Face** (turn toward a target), **Wait** (pause for a duration), and **Parameter Setter** (write an entity/runtime parameter — e.g. flip the Animation Graph's `isWalking` before and after a Move To, so the walk animation plays only while the character is actually moving).

A typical routine: a **Sequence** containing Rotate To Face → Move To → Wait, fed target positions and speeds through Inputs (e.g. `tablePosition`, `rotationRate`, `movementRate`), with sub-sequences for each destination nested under one parent Sequence so the character visits them in order.

**Preconditions** gate a branch on a condition instead of a fixed Wait: add a Bool input (e.g. `readyToBrew`, default `false`) and attach a **Precondition** → **Bool Condition** to a sub-sequence so the character holds there indefinitely until something external — typically a Script Graph reacting to a tap via **Set Entity Parameter** — flips it true.

## Navigation Mesh: pathfinding around obstacles

A **Navigation Mesh** component defines a scene's walkable surface; a navigation controller uses it to route characters between points while automatically avoiding obstacles (trees, water, buildings). Its sections:

- **Shapes** — the bounding box determining which scene geometry gets sampled to generate the mesh.
- **Off-Mesh Connections** — explicit links between areas the generated mesh wouldn't naturally connect (a ladder, a bridge). Each connection has a start and end point, adjustable with the viewport gizmo.
- **Generation Parameters** — control how geometry is sampled, e.g. **cell size** (the voxel size — smaller values capture finer detail, larger values produce a coarser, more approximate mesh). Many more parameters exist; see Apple's Navigation Mesh documentation for the full reference.

Once generated, a character crosses it via a **Behavior Tree**, an **Animation Graph**, or your own custom Swift system, all going through the navigation component (see `realitykit-physics-interaction` and `realitykit-core` for the code-side APIs — `// confirm exact type name against current documentation`).

## How the three fit together

A typical setup (an alchemist character walking a routine): the Animation Graph blends Idle ↔ Walk from an `isWalking` bool; a Behavior Tree Sequence drives Rotate To Face → Move To → Wait toward each destination, toggling `isWalking` around each Move To via Parameter Setter, and gates the second leg behind a `readyToBrew` Precondition; a Script Graph's On Tap → Set Entity Parameter flips `readyToBrew` true to release the gate; and, once added, a Navigation Mesh lets the same Move To target route around scene obstacles instead of walking through them.

## Common mistakes

1. **Adding a transition with no condition.** The State Machine has no way to know when to switch states — every transition needs an Inputs-Inspector variable and a condition (e.g. Bool Condition) wired to it.
2. **Forgetting to toggle the Animation Graph's runtime bool from the Behavior Tree.** A character can Move To perfectly and still visibly slide, because nothing set `isWalking` around the movement action — bracket movement actions with Parameter Setter nodes.
3. **Misreading evaluation order.** It's strictly top-to-bottom, left-to-right; a Selector's first successful child wins and the rest are skipped — don't expect every sibling to run.
4. **Picking Sequence when you meant Selector (or vice versa).** Sequence = do all of these in order, abort on failure. Selector = try until one works. The wrong composite silently changes what a child's "failure" does to the rest of the tree.
5. **Skipping Off-Mesh Connections for obviously-connected geometry.** A ladder, bridge, or one-way drop that isn't mesh-connected leaves the navigation controller treating the two surfaces as unreachable from each other.
6. **Leaving a Precondition without a sensible default.** A Bool precondition like `readyToBrew` needs an explicit starting value (`false`) so the tree's initial state is well-defined before any Script Graph sets it.
