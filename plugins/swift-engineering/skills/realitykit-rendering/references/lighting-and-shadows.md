# Lighting & Shadows

> Some APIs here ship in 2025–2026 releases. Confirm exact names against current Apple documentation.

## The light components

RealityKit lights are entities carrying a light component — nothing more exotic than that:

- **`DirectionalLightComponent`** — a sun-like light with no position, only orientation. Pair it with a **`DirectionalLightShadowComponent`** on the same entity to get shadows; without it, the light casts none.
- **`PointLightComponent`** — an omnidirectional light from a point in space (a torch, a bulb).
- **`SpotLightComponent`** — a cone of light from a point, aimed by orientation (a flashlight, a hearth's fire, a projector).
- **`ImageBasedLightComponent`** — lights from a texture rather than a discrete source; see `image-based-lighting.md` for the full setup (it needs a receiver component too).

```swift
let sun = Entity()
sun.components.set(DirectionalLightComponent(color: .white, intensity: 1000))  // confirm exact parameter names
sun.components.set(DirectionalLightShadowComponent())
sun.orientation = simd_quatf(angle: -.pi / 4, axis: [1, 0, 0])  // only orientation matters for a directional light
content.add(sun)
```

## Soft (area) shadows

By default every shadow in RealityKit is **hard-edged** — accurate only for an infinitesimally small light source. Real lights have area, which produces a **penumbra** (a softer-edged region where only part of the light is occluded); the larger the light's area, the larger the penumbra. Control this per-light through its shadow's `lightSize` and `quality`:

```swift
var shadow = hearthSpotLight.components[SpotLightComponent.Shadow.self] ?? .init()  // confirm exact type name
shadow.lightSize = 0.7    // diameter, in meters, of the light; default is 0 (hard shadow)
shadow.quality = .medium  // sample count for the soft-shadow calculation
hearthSpotLight.components.set(shadow)
```

`quality` trades sample count for cost — `.high` looks best but costs the most; `.medium` is often enough at typical viewing distances. **`quality` must be `.medium` or `.high` to get a soft shadow at all — at `.low` the shadow is hard regardless of `lightSize`.** This is the most common reason a "soft shadow" doesn't show up: the size was set but the quality was left low (or unset).

## Lightmaps for static lighting

Lightmaps let you **precompute** lighting once and store the result in a texture, instead of paying for it every frame — but only for lighting that never changes. A lightmap component on an entity carries up to three baked terms:

- **Indirect lighting** — bounced light reaching surfaces no light hits directly (the underside of a table, a dim corner).
- **Ambient occlusion** — how exposed each point is to its surroundings.
- **Beauty** — the final combined color (direct + indirect) baked straight to a texture.

RealityKit's API supports attaching your own textures to these slots, but the recommended path is **Reality Composer Pro's light baker**: attach the lightmap component // confirm exact type name (`LightmapComponent`), pick a bake quality (low → high) in its bake settings, preview the result live in the Lightmap Preview tab, then regenerate. Because the result is frozen at bake time, lightmaps only make sense for **static** lights and geometry — anything that moves or animates needs realtime lighting (and soft shadows, above) instead. See `reality-composer-pro` for the baker workflow.

## Projective textures

A **projective texture** works like a slide projector: shine a spotlight's beam through an image, and that image paints whatever surface the beam lands on — the pattern from a stained-glass window, or animated caustics rippling across a pool floor. Attach one to a `SpotLightComponent`:

```swift
var projectiveTexture = spotLight.components[SpotLightComponent.ProjectiveTexture.self] ?? .init()  // confirm exact type name
projectiveTexture.image = starsAndNebulaeTexture  // confirm exact property/type
spotLight.components.set(projectiveTexture)
```

Keep the light's color **white** if you don't want to tint the projected image, and increase intensity for larger rooms where the projection needs to reach farther.

## Physical-space lighting (visionOS)

By default, virtual lights only illuminate virtual geometry. **Physical-space lighting** extends a spot or point light onto the **real room** around the wearer, using RealityKit's scene-understanding mesh — so, for example, a virtual planetarium's projected stars genuinely sweep across the user's real walls. Enable it by adding the light's `SurroundingsLight` component:

```swift
spotLight.components.set(SpotLightComponent.SurroundingsLight())  // confirm exact type name
```

Currently supported on **spotlights and point lights only**, and it's a visionOS-specific feature — it depends on the device's scene-understanding mesh of the surrounding room (see `realitykit-spatial-ar`).

## Common mistakes

1. **Setting `lightSize` without checking `quality`.** Soft shadows need `quality` at `.medium` or `.high`; `.low` silently stays hard no matter what `lightSize` is.
2. **Baking a lightmap under a light that later moves or animates.** Lightmaps are frozen at bake time — reserve them for lights and geometry that truly never move.
3. **Adding a light component but forgetting its shadow component.** A `DirectionalLightComponent` with no `DirectionalLightShadowComponent` casts no shadows at all.
4. **Mutating a shadow/projective-texture value without writing it back.** These are value-type components like any other — read a copy, mutate it, then `components.set(...)` it back onto the entity (see `realitykit-core`).
5. **Expecting physical-space lighting outside visionOS, or on a directional light.** It's currently spot/point lights only, and depends on the visionOS scene-understanding mesh.
6. **Tinting a projective texture unintentionally.** A colored spotlight tints whatever it projects; set the light's color to white if you want the texture's own colors to show through untouched.
