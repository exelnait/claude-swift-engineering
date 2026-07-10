# Available-Space Principles

Why the industry moved from "device + orientation" to "scene + available space", what each layout input *actually* means now, and the mental model to carry into every layout decision.

## The WWDC 26 contract

WWDC 26 Session 278, *Modernize your UIKit app*, brought iPhone apps into a dynamic-sizing world and stated the new rules plainly:

- In **iPhone Mirroring on Mac**, the iPhone window can be **freely resized**.
- **iPhone-only apps running on iPad** also enter a **resizable environment**.
- Apps must **adapt to arbitrary scene sizes at runtime** — do not assume a fixed device aspect ratio.
- **`UIScreen.main` and screen bounds are no longer reliable.** Use the **effective geometry of the window scene**, or the **actual available size of the view / superview**.
- **`userInterfaceIdiom` is no longer suitable as a basis for layout decisions.**
- An iPhone app on iPad or in Mac mirroring may still run under the **phone idiom** — so **phone idiom no longer means narrow-screen layout**.
- **Orientation is no longer reliable.** Supported orientations are closer to *preferences*; the system may keep portrait even when the window's aspect ratio changes.
- For precise layout control, **use the surrounding view's size first**.

The system now deliberately **separates "host semantics" from "available geometric space."** They used to move together; they no longer do.

## Is `horizontalSizeClass` still reliable?

**Yes — but only for what it actually represents.** It reliably expresses the **coarse-grained semantics of the current trait environment**. It is **not** the window width, and never was a continuous width sensor.

The trap this year: a wider window on an iPhone host does **not** switch `horizontalSizeClass` to `.regular`. It stays `.compact` at any width, on purpose. Conversely, a narrow iPad window can produce different trait results depending on idiom, scene, presentation, or container.

| Input | What it *actually* tells you | Use it for | Do **not** use it for |
|-------|------------------------------|------------|-----------------------|
| `userInterfaceIdiom` | Which host the app runs under | Host-specific plumbing, capability checks | Any layout decision |
| `horizontalSizeClass` | Coarse contextual trait of the container | System container semantics: collapse a menu, offer a system Sidebar/Tab morph | Your own width breakpoints |
| **View / scene geometry** | The real space you have right now | Your own breakpoints — columns, side navigation, wide/compact shells | — |
| `UIScreen.main.bounds` | The physical display | (almost nothing) | Anything scene-scoped |
| `UIDevice.orientation` | Physical device pose (a preference now) | (almost nothing) | "Am I landscape?" — derive from `width > height` |

**Rule of thumb:** if the question is *"how much room do I have?"*, read geometry. If it's *"what kind of system container am I in?"*, a trait is fine.

## Trait propagation: why the number surprises you

Since WWDC 2023 (*Unleash the UIKit trait system*), environment information is **contextual data that propagates layer by layer** — scene → window → presentation → view controller → view — rather than a single device-level fact. That is why the `horizontalSizeClass` you read inside an iPad **sheet**, a **split column**, or a **popover** often differs from the window as a whole. A trait is a property of *the container you're in*, not of the device. This is a feature: it lets a compact column inside a regular window lay out compactly. It also means you cannot reason about the whole window from a leaf view's trait.

## The 12-year arc toward available space

This wasn't a sudden 2026 change; it's the endpoint of a decade of steady direction — reducing "device type + orientation" as a layout basis and moving toward scene, trait hierarchy, and available space:

| Year | Milestone | What it shifted |
|------|-----------|-----------------|
| **2014** | Size Classes (iOS 8) | "Device rotation is essentially just a bounds change." |
| **2019** | iPad multiwindow + `UIScene` | Broke "one app = one UI instance"; a scene gained its own lifecycle, state restoration, screen, and geometry. |
| **2022** | Desktop-Class iPad (iPadOS 16) | Pushed iPad past "big iPhone" toward dense, desktop-like productivity — the foundation for variable-space design. |
| **2023** | *Unleash the UIKit trait system* | Traits became contextual data propagating scene→window→presentation→VC→view, not a device fact. |
| **2024** | Tab Bar ⇄ Sidebar (iPadOS 18) | Treated as **different presentations of the same navigation hierarchy** under different spatial conditions. |
| **2025** | iPadOS → macOS-like | Windows, menu bars, pointers, multiwindow workflows. |
| **2026** | Resizable iPhone (WWDC 26) | "iPhone apps only serve a fixed phone aspect ratio" became officially invalid. |

Seeing the arc matters: geometry-first layout isn't a workaround for one beta behavior — it's where the platform has been heading the whole time, and it's the only approach that survives the next new device or mode.

## iPad Full Screen points the same way

Apple hasn't removed the user's right to work full-screen, but it's reclaiming the *developer's* ability to lock the app into an old compatibility mode:

- In iPadOS 26 users choose **Full Screen Apps**, **Windowed Apps**, or **Stage Manager** via Settings / Control Center.
- **`UIRequiresFullScreen` is a deprecated compatibility mode** and will be ignored by the system going forward. (See Apple's **TN3192** and the `UIRequiresFullScreen` documentation.)

Full Screen is moving from *"something developers can require"* to *"something the user and system jointly determine."* Same main thread as iPhone Resize: you may express **preferences, minimum sizes, and temporary orientation locks**, but you no longer own a fixed, unchanging canvas.

## The mental model: express preferences, not control

The single most useful reframing:

> You do not command a size. You **declare constraints and preferences**, then **render well into whatever the user and system grant you.**

What you can still express (see `scene-geometry.md` for the APIs):

- A **preferred minimum size** — `UISceneSizeRestrictions`, or SwiftUI `windowResizability(_:)` + a content minimum size.
- A **temporary orientation-lock preference** — `prefersInterfaceOrientationLocked`.
- **Observation of real changes** — `windowScene(_:didUpdateEffectiveGeometry:)`.
- **Interactive-vs-settled** distinction — `UIWindowSceneGeometry.isInteractivelyResizing` / SwiftUI `onInteractiveResizeChange(_:)`.

System components are more adaptive than ever and SwiftUI lowers the bar for responsive UI — but the number of presentation forms you must handle has *increased*, not decreased. Budget for that.

## iPhone fold, concretely

A foldable iPhone is the sharpest test of these principles because a **single running session** moves between two very different geometries:

- **Folded (outer/cover display):** narrow, phone-like — a compact shell.
- **Unfolded (inner display):** larger and closer to square — room for a sidebar, a second column, a wider grid.
- **The transition happens live**, mid-task, and the app should carry the user's context across it.

Everything above is exactly what makes an app fold-ready:

- The unfold is a **scene-geometry change**, not a new launch — observe it, don't assume it.
- Phone idiom persists across the fold, so **`userInterfaceIdiom` tells you nothing** about how much room the inner display gives — measure it.
- Orientation is a **preference**; the inner display's aspect ratio is what matters — derive it from geometry.
- Continuity across the fold is **state preservation**: keep selection/navigation in shared state (see `navigation-adaptation.md`) so the layout can morph without losing the user's place.

Build for "arbitrary scene size, changing live" and iPhone fold, iPad multitasking, and Mac mirroring are all handled by the same code.
