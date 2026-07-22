# Capture Best Practices: Shooting Photos for Photogrammetry

> Confirm current specifics (e.g. the CaptureSample app's exact location in Apple's sample code library) against current Apple documentation.

Object Capture's output is only as good as the photographs you feed it. Most quality problems trace back to the shoot, not the API — this reference is the checklist to run through before you ever touch `PhotogrammetrySession`.

## Choosing the right object

- **Texture detail helps reconstruction.** Photogrammetry finds correspondences between images using visual texture; textureless or transparent regions give it nothing to match, so they come out low-detail or wrong.
- **Avoid highly reflective surfaces** where you can. If reflection is unavoidable, **diffuse the lighting** (soft, indirect light rather than a single hard source) to tame it.
- **Rigid, if you're going to flip it.** Flipping mid-capture to reach the underside only works if the object doesn't change shape between the two halves of the shoot.
- **Fine surface detail needs a high-resolution camera and more close-ups.** Recovering small-scale detail (wood grain, fabric weave) means both better source resolution and denser close-up coverage of that area, not just more distance shots.

## Shooting technique

- **Uncluttered background.** Put the object where it clearly stands out from its surroundings — a busy background gives the reconstruction spurious geometry to latch onto.
- **Move slowly, and cover every side uniformly.** Don't rush past any angle; uneven coverage becomes uneven detail (or holes) in the model.
- **Flip it to get the bottom.** If you want the underside reconstructed rather than left as a stub, physically flip the object partway through and keep shooting — otherwise you'll only ever see it from the top down.
- **Maximize the object in the frame.** Switch between portrait and landscape to match the object's proportions; the more of the frame the object fills, the more detail the API can recover.
- **High overlap between consecutive shots.** Photogrammetry needs the same surface point visible from multiple angles; sparse, low-overlap coverage breaks that chain.
- **20 to 200 close-up images**, depending on the object's size and complexity, is the practical range for good results.

## Depth and gravity on iPhone/iPad

Shooting with an iPhone or iPad that has a dual or LiDAR camera gets you two things for free, embedded right into the HEIC: **stereo depth data**, which recovers the object's **true physical scale**, and a **gravity vector**, which lets the model come out **right-side up automatically**. Capturing on a DSLR or drone still works, but without depth/gravity the model arrives at an arbitrary scale and orientation that you'll need to fix by hand — e.g. via the root transform in the interactive workflow (see `interactive-workflow.md`).

## Using the CaptureSample app

Apple ships **CaptureSample**, a SwiftUI sample app, as a starting point for your own capture app. It:

- Captures with **manual or timed shutter** modes (timed is what you sync to a turntable).
- Uses the dual/LiDAR camera to capture **depth and embed it directly into the output HEIC** files.
- Records the **gravity vector** alongside each shot.
- Provides a gallery so you can spot-check a capture and **delete bad shots** before copying the folder off-device.
- Saves each capture into the app's Documents folder, ready to move to your Mac over **AirDrop or iCloud**.

The captured folder is exactly the folder `URL` you hand to `PhotogrammetrySession`:

```swift
// Depth + gravity embedded by CaptureSample need no extra plumbing —
// the session detects and uses them automatically from the folder.
let session = try PhotogrammetrySession(input: captureSampleOutputFolder)
```

## Turntable capture

For the most consistent results, Apple recommends a **turntable** setup: the capture device (iPhone/iPad, or a DSLR) stays fixed while a mechanical turntable rotates the object, with **lighting panels and a light tent** providing uniform light and avoiding hard shadows. CaptureSample's timed-shutter mode is designed to sync with the turntable's motion. Do a second pass with the object flipped to complete coverage of the underside.

## Common mistakes

1. **Scanning a shiny, see-through, or blank object** and expecting mobile-photo-quality results — texture is what the algorithm matches on.
2. **Flipping a non-rigid object** mid-capture, so the two halves of the shoot describe two slightly different shapes.
3. **A busy or matching-color background** that gets reconstructed as part of the object, or that confuses the object boundary.
4. **Rushing the shoot or skimping on overlap** — fast, sparse coverage is the single biggest cause of holes and blurry detail.
5. **Never flipping the object**, then being surprised the bottom is missing or crude in the output.
6. **Shooting on a plain DSLR/drone and skipping the scale/orientation fix-up** — without depth and gravity, don't assume the output is already right-side-up or true-to-scale.
