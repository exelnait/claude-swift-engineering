# Level of Detail and Thermal-State Adaptation

> `LevelOfDetailComponent` and its convenience functions are 2026 APIs. Confirm exact initializers, parameter labels, and availability against current Apple documentation.

Two complementary techniques keep a scene fast without a fixed, one-size-fits-all budget: rendering less detail when it won't be noticed (**LOD**), and reacting when the device tells you it's under thermal pressure.

## Mesh level of detail

LOD means rendering the same object at reduced geometric complexity when the reduction won't be visually noticeable — typically because the object is far away or small on screen. By convention, LODs are indexed starting at **0 = highest detail**, with each subsequent index progressively lower detail. A model might have LOD 0 through 5; LOD 5 looks rough up close, but at the distance/scale where RealityKit would actually switch to it, the difference from LOD 0 is negligible — while costing far less to render.

## Setting up LevelOfDetailComponent

LODs are specified as **arrays of entities** — one entity per detail level, held by a parent entity that owns the `LevelOfDetailComponent` and switches which one is active:

```swift
import RealityKit

let levels = [cauldronHighDetail, cauldronMediumDetail, cauldronLowDetail]  // index 0 = highest detail
var lod = LevelOfDetailComponent(levels: levels)                            // confirm exact initializer
cauldronRoot.components.set(lod)
```

RealityKit needs a **switching algorithm** to decide which level to show. Two convenience functions cover the common cases:

- **`addByCameraDistance`** — switch based on distance from the camera. Specify a **max distance per LOD**; once the entity is farther than that distance, RealityKit switches to the next level. The **last** LOD's max distance should be **`.infinity`**, so it's used no matter how far beyond the previous threshold the entity gets.

  ```swift
  lod.addByCameraDistance(maxDistances: [4.0, 12.0, .infinity])   // confirm exact API/parameter label
  ```

- **`addByScreenArea`** — switch based on how much of the screen the entity actually occupies. Specify a **minimum screen-area fraction per LOD**; once the entity takes up less than that fraction, RealityKit switches to the next level.

  ```swift
  lod.addByScreenArea(minAreas: [0.10, 0.02, 0.0])   // confirm exact API/parameter label
  ```

Screen-area switching tends to be the more robust choice when object scale varies a lot (a huge but distant object and a small but close one can occupy the same screen area very differently than camera distance alone would suggest); camera-distance switching is simpler and cheaper to evaluate when scale is roughly consistent.

## Reacting to thermal state

LOD is a static-ish shape for your scene; thermal-state observation is how you react **dynamically** when the device is actually struggling. Register an observer on `ProcessInfo`'s thermal-state-change notification and query the current state whenever it fires:

```swift
import Foundation

NotificationCenter.default.addObserver(
    forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main
) { _ in
    switch ProcessInfo.processInfo.thermalState {
    case .nominal, .fair:
        break                              // fine as-is — no mitigation needed (or it's already working)
    case .serious, .critical:
        // Make LOD switching more aggressive (lower the max distances / raise the min screen areas
        // so lower-detail levels kick in sooner), and/or lower shadow quality.
        applyThermalMitigations()
    @unknown default:
        break
    }
}
```

`.nominal`/`.fair` mean things are fine (your app can keep running as configured, or your mitigations already brought it back under control). `.serious`/`.critical` mean you should actively reduce load: tighten LOD thresholds so lower-detail levels are selected sooner, and/or reduce shadow quality — both are explicit, low-effort levers rather than a full quality-tier rewrite.

## Common mistakes

1. **Skipping thermal reaction entirely.** LOD alone is a fixed shape; a scene tuned to run fine at `.nominal` can still push a device into `.serious`/`.critical` over time (heat, battery, background load). Observe and react, don't just set-and-forget LODs.
2. **Forgetting `.infinity` on the last LOD's max distance.** Without it, an entity that goes beyond every specified distance has no defined LOD to fall back to.
3. **Defaulting to camera-distance switching for objects with widely varying scale.** A large object seen from far away and a small object seen up close can need very different distance thresholds to look equivalent on screen — `addByScreenArea` sidesteps this by keying off what's actually visible.
4. **Treating `.serious`/`.critical` as a one-time event instead of a state to actively mitigate.** Re-check `thermalState` on each notification and keep mitigations in effect until the state improves; don't apply a single fix and stop listening.
5. **Only having two LOD levels prepared.** A cauldron-style asset with many levels (0 through 5 in the reference example) gives the switching algorithm room to step down gradually; two levels forces a single, more visible jump in detail.
