# The RealityKit Debugger Workflow

> The debugger's panels and menu labels are an Xcode UI surface introduced in 2024 and extended by the 2025–2026 RealityKit releases. Confirm exact labels (button names, dropdown options, context-menu items) against current Xcode documentation.

The RealityKit debugger takes a **3D snapshot of your running app** and loads it into Xcode — the same idea as the view debugger snapshotting a 2D view hierarchy, applied to a live scene graph. It fits into your existing Xcode workflow: no new project setup and no code changes are required to use it.

## Capturing a snapshot

Run your app (simulator or device) and get it into the state you want to inspect, then click **Capture Entity Hierarchy** in the debug area at the bottom of the Xcode window. Xcode pauses the app and reconstructs its RealityKit scene(s) from the live process.

## Navigating a capture

Once the snapshot completes, captured scenes are listed in the **debug navigator** on the left. Selecting one opens two synchronized views:

- An **entity hierarchy outline** — the scene's entity tree, exactly as your code built it.
- A **3D viewport** — the scene reconstructed and rendered, with every entity's transform composed with its ancestors' (the same way it actually renders in your app).

Selecting an entity in either view selects it in the other. Hide the navigators and debug area to give the viewport more room while you work. Double-clicking an entity — in the hierarchy or the viewport — both selects it **and** flies the camera to focus on it, which is the fastest way to jump to something far outside your current view.

An entity's selection highlight stays visible in the viewport **even when the entity is occluded** by other content — a quick way to confirm something exists, and roughly where, before you go looking for why it isn't visible.

## The entity inspector

Selecting an entity opens an **inspector** on the right showing its properties and the full list of its components, each expandable to its own fields — e.g. a `Transform`'s position/orientation/scale, or a custom component's stored values.

```swift
// Roughly what the inspector is showing you:
entity.transform                          // main viewport = this, composed with every ancestor's transform
entity.components[ModelComponent.self]    // preview viewport = this alone, no ancestors applied
```

The inspector also has a smaller **preview viewport** that renders just the selected entity's `ModelComponent` mesh, with **no ancestor transforms applied**. Comparing the preview against the main viewport is the core technique for localizing a transform bug: if the preview looks correct but the main viewport doesn't, the entity itself is fine and an ancestor is the culprit (see `transform-and-component-bugs.md`).

## The statistics inspector

A separate inspector reports statistics for the currently selected hierarchy — a quick sanity check on the scope of what you've captured, alongside the per-entity detail in the component inspector.

## Visualizing normals

The preview viewport has a **rendering-mode dropdown** in its corner; its default shows the shaded mesh, but you can switch it to **visualize Normals** instead. This colors the mesh by the normal direction at each point — the same data lighting calculations use — so a broken or inverted normal shows up as a visibly wrong color rather than a subtle lighting glitch. It's most useful compared side by side against a known-good entity's mesh in the same mode (see `rendering-pitfalls.md`).

## The hierarchy filter bar

The entity hierarchy outline has a **filter bar** at the bottom. Type a substring to show only entities whose name contains it — the fastest way to confirm whether an entity you expect actually exists in the captured scene at all, versus existing but failing to render for some other reason.

## Common mistakes

1. **Concluding a mesh is broken from the main viewport alone.** Always check the preview viewport (no inherited transform) before deciding whether the problem is the entity's own mesh or something it inherited.
2. **Assuming "no selection highlight visible" means "doesn't exist."** An occluded entity still shows its highlight. No highlight at all, even after double-clicking to focus the camera on it, points to a different problem (out-of-bounds, disabled, no `ModelComponent`) — not necessarily "missing."
3. **Skipping the filter bar and assuming a rendering bug.** Before debugging *why* something isn't rendering, confirm it's actually in the captured scene. If the filter turns up nothing, the entity was simply never added.
