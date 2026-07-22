# Spatial Accessories & Object Tracking

> Custom spatial accessory support, high-frame-rate/metric-space object tracking, and the iOS object tracking API shipped in visionOS 27 (2026) and are newer than this guidance's training data. Confirm exact type names and initializers against current Apple documentation.

These are two different mechanisms for getting 6-degrees-of-freedom (6DoF) input from the real world, and it's easy to reach for the wrong one:

- **Object tracking** recognizes an arbitrary real object — no electronics inside it — via a machine-learning model trained on its 3D shape. Runs on **iOS and visionOS**.
- **Spatial accessories** are paired **electronic devices** (controllers, or things you've built yourself) tracked in 6DoF with haptics. **visionOS-only**, but notably usable in both the Shared Space and Full Space, unlike most of the other visionOS-only capabilities in this skill.

## Spatial accessories

visionOS tracks spatial accessories in 6DoF and supports haptic feedback, in both **Shared Space and Full Space**. You connect an accessory via the **Game Controller framework**, then use **RealityKit or ARKit** to read its movement and orientation. `// confirm exact API surface — GCController and related types`

visionOS 26 introduced the first supported accessories: the **Logitech Muse** and the **PSVR2 Sense controller**. visionOS 27 expands this to **build-your-own accessories** — any object becomes a compatible spatial accessory once it hosts a board with three things:

1. A **constellation of LEDs** visible to Apple Vision Pro, for tracking.
2. An **IMU** capturing orientation and acceleration.
3. A **Bluetooth chip** sending signals to Apple Vision Pro.

Accessories can also host buttons, touchpads, and haptic feedback. Manufacturers **DFRobot** and **MikroE** are releasing off-the-shelf reference hardware and development kits as a starting point — for example, a 3D-printed flashlight mounted with a DFRobot seeMote Cap (the virtual light beam follows the physical flashlight in real time), or a MikroE Spatial Anchor R1 mounted inside a physical steering wheel (anchoring a digital vehicle model to it, so grabbing the wheel feels like sitting in the car — a racing-sim / vehicle-interior-design use case).

Tracking characteristics worth knowing:

- Tracked at the **highest possible frequency**, matching the display's native refresh rate, with extremely low latency — built for fast motion.
- Remains robust through **temporary occlusion** and in **low-light** conditions.

## Object tracking

Object tracking (introduced in visionOS 2.0) turns a physical object into a virtual anchor without any electronics in the object itself:

1. Start with the object's **USDZ model**.
2. Train a **reference object** in **Create ML** on your Mac.
3. Pass the reference object to the object tracking API.
4. Your app receives ongoing **position and orientation** updates for the physical object as it moves.

```swift
import ARKit

let referenceObject = try await ReferenceObject.load(from: referenceObjectURL)  // confirm exact API; produced by Create ML training
let objectTracking = ObjectTrackingProvider(referenceObjects: [referenceObject])  // confirm exact API

let session = ARKitSession()
try await session.run([objectTracking])

for await update in objectTracking.anchorUpdates {   // confirm exact API
    let anchor = update.anchor
    let originFromAnchor = anchor.originFromAnchorTransform   // confirm exact property name
    // Position content relative to the tracked object using `originFromAnchor`.
}
```

visionOS 27 (2026) adds:

- **High-frame-rate tracking** — more frequent pose updates as the object moves.
- An **extended training** option in Create ML — better accuracy and robustness, particularly for objects held in a hand.
- A new API for the object's pose in **metric space, without display corrections** — for high-precision spatial-measurement use cases.
- **iOS support** via a new ARKit API mirroring the visionOS flow above. `// confirm exact iOS type name — described in source material as "an ARKit API that supports the same functionality as visionOS"`

Create ML training is platform-agnostic: train the reference object once, and the same trained object works in both your iOS and visionOS app at the same tracking quality.

These enhancements target use cases like measurement and spatial-precision workflows — e.g. tracking and measuring physical spaces with a handheld medical probe, which opens up surgical-navigation training — and, more generally, anchoring a virtual model precisely onto a real object a person picks up and moves.

## Choosing between them

| Need | Use |
|------|-----|
| Recognize a specific real-world object (no electronics in it) and track its pose | **Object tracking** (Create ML reference object + ARKit) |
| 6DoF input from a physical controller with buttons/haptics | **Spatial accessory** (Game Controller framework) |
| Works on iOS | Object tracking only |
| Works in visionOS's Shared Space (not just Full Space/immersive) | Spatial accessories only |
| High-precision measurement in metric space | Object tracking's metric-space pose API |
| Building custom hardware (LEDs + IMU + Bluetooth) | Spatial accessory reference designs (DFRobot, MikroE) |

## Common mistakes

1. **Reaching for object tracking when you actually control the hardware.** If you can put electronics inside the object, a spatial accessory gets you buttons, touchpads, and haptics that object tracking simply doesn't have. Object tracking is for objects you can't (or don't want to) modify.
2. **Reaching for a spatial accessory when you need iOS support.** Spatial accessories are visionOS-only; if the same feature needs to work on an iPhone or iPad, object tracking (with its 2026 iOS ARKit path) is the one that crosses platforms.
3. **Retraining a reference object per platform.** Don't. Create ML training is platform-agnostic — train once from the USDZ, use the same reference object on both iOS and visionOS.
4. **Using the default (non-metric, display-corrected) pose for measurement use cases.** If your feature needs real-world accuracy (surgical training, physical measurement), use the metric-space pose API, not the display-corrected default meant for on-screen rendering.
5. **Assuming spatial accessories only work in a fully immersive space.** They don't — unlike scene understanding, environment blending, and custom reverb, spatial accessories are explicitly supported in the Shared Space too.
6. **Skipping the extended Create ML training option for handheld objects.** Objects that get picked up and rotated in a hand are harder to track robustly than objects that sit still; the extended training option exists specifically to improve that case.
