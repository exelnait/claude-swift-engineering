# Immersive Audio & Custom Reverb

> `ReverbMeshResource`, `AudioMaterial`, and the reverb component shipped in the 2026 RealityKit update and are newer than this guidance's training data. Confirm exact type names, initializers, and property names against current Apple documentation.

Everything on this page is **visionOS-only, and only takes effect in an immersive space.**

## Why spatial audio needs room geometry

Convincing spatial audio needs two things done well: the **direct path** (sound traveling straight from source to ear) and the **reflection path** (sound bouncing off surfaces before it arrives) both need accurate direction and timing, continuously updated as the person and the audio source move around the environment. The reflection path is where room geometry and materials matter — the same sound source is perceived completely differently in a small living room versus a large museum hall, because of what it bounces off before it reaches you.

RealityKit simulates this with **raytraced geometrical acoustics** driven by a **custom reverb mesh**: you describe the room's shape and what it's made of, and RealityKit computes reflections and reverb that match where the person and the source actually are in that geometry.

## Building a ReverbMeshResource

A **`ReverbMeshResource`** describes the geometry of the space for acoustic purposes. Build one from a mesh descriptor or an existing mesh resource, or use the convenience **shoebox** — a box with its faces pointed inward, sized to the room:

```swift
import RealityKit

let reverbMesh = try await ReverbMeshResource.shoebox(width: 5, height: 4, depth: 6)  // confirm exact API; meters
```

For anything more elaborate than a rectangular room, build the `ReverbMeshResource` from your actual scene geometry (a mesh descriptor/resource) instead of the shoebox shortcut. `// confirm exact non-shoebox initializer`

## Audio materials: presets, scaling, and fully custom

A reverb mesh alone isn't enough — RealityKit also needs to know what each surface is *made of*, since a wood floor, a plaster wall, and a stone countertop all absorb and scatter sound differently. That's an **audio material**.

**Presets** are the fastest path:

```swift
let reverb = try ReverbComponent(mesh: reverbMesh, material: .dryWall)  // confirm exact API/case name
```

**Scaling a preset** lets you nudge a built-in material without defining one from scratch — useful when you know a surface is "like carpet, but thicker":

```swift
let thickCarpet = AudioMaterial.carpet.scalingAbsorption(by: 1.2)  // confirm exact API/parameter
```

**Fully custom materials** are built from **absorption** and **scattering coefficients across the 10-band center frequencies** that describe how much sound energy a surface absorbs or scatters at each frequency:

```swift
var bookshelf = AudioMaterial.Coefficients()               // confirm exact type
bookshelf.absorption = [/* one value per 10-band center frequency */]   // confirm exact API
bookshelf.scattering = [/* values for the frequencies you know */]      // partial data is fine

let bookshelfMaterial = AudioMaterial(coefficients: bookshelf)          // confirm exact API
```

You don't have to supply every frequency band. If you only know scattering at a few specific frequencies, provide those — RealityKit **extrapolates** to cover the entire audible spectrum from the samples you give it.

## Attaching the reverb to a scene

```swift
entity.components.set(reverb)   // the ReverbComponent built from the mesh + material above
```

Depending on where the person and the audio source are relative to the reverb mesh, they pick up the reverb appropriate to their position — stand near the "stone countertop" wall and the reflections change accordingly, in real time.

## Shared Space vs. Immersive Space

Custom reverb meshes **only work in an immersive space**. In the Shared Space, visionOS uses its own **system room-sense reverb** instead — a reverb geometry Vision Pro has already built from your actual real-world surroundings. There's no way to override that with a custom mesh outside of an immersive space; if your carefully tuned reverb seems to do nothing, check whether you're actually in an immersive space.

## Coordinated multi-source audio

Alongside custom reverb, RealityKit also supports **coordinated multi-source audio**: precise, synchronized audio playback across multiple entities at once. This is what makes something like a virtual band believable — each instrument is an independently placed, independently controllable source, but they stay in sync with each other while each one also picks up the room's reverb from its own position. `// confirm exact API — described at a high level in source material`

## Common mistakes

1. **Expecting a custom reverb mesh to have any effect in the Shared Space.** It won't — this is immersive-space-only. Test in an actual immersive space, not a windowed preview.
2. **Building a shoebox for a room that isn't actually a box.** The shoebox convenience is for quick, roughly-rectangular spaces. A room with alcoves, multiple materials per wall, or an open floor plan needs a `ReverbMeshResource` built from real mesh geometry, not the shoebox shortcut.
3. **Providing absorption/scattering data for only a couple of frequencies and expecting a flat response elsewhere.** RealityKit extrapolates across the spectrum from what you give it — sparse, poorly chosen sample frequencies produce a poorly extrapolated material. Provide the full 10-band data when you have it.
4. **Forgetting the material step entirely.** A `ReverbMeshResource` describes shape, not surface. Without an `AudioMaterial` (preset or custom) paired with it, there's no absorption/scattering information for RealityKit to simulate against.
5. **Assuming this reference covers ordinary spatial audio (panning a single source in 3D).** It doesn't — basic spatial audio positioning is a baseline RealityKit audio capability; this page is specifically about *room acoustics* — reverb and reflections from custom or real-world geometry.
