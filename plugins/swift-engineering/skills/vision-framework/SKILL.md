---
name: vision-framework
description: Use when analyzing images with Apple's Vision framework — segmentation and tap-to-segment, image feature prints and similarity, saliency-based cropping, detection and classification, Vision on watchOS, or combining Vision with Foundation Models via image tools.
---

# Vision Framework: Image Understanding

> These capabilities are part of the 2026 releases and newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

## Overview

There are two complementary ways to bring image understanding to an app, and the skill is knowing which to reach for — or how to combine them.

**Vision** is a fixed set of computer-vision APIs. Each one is **fine-tuned for a specific task** (segmentation, saliency, face/pose/text/barcode detection, classification, tracking) and does that task really well. Vision is **fast** — often fast enough to analyze **video frames in real time** — and runs on-device. You pick the right request for the job; there is no open-ended "ask it anything".

**Foundation Models** wraps a **versatile large language model**. It can do almost anything you describe in a prompt — caption an image, suggest interior-decorating changes, invent a recipe from a photo of a fridge — and this year it accepts **image inputs**. It is general and descriptive where Vision is precise and specialized.

You don't have to choose. The two combine through **tool calling**: give the LLM access to tools that run Vision's fine-tuned APIs, so the model stays versatile while delegating the pixel-precise work (reading a QR code, OCR, identifying a plant) to Vision. Vision even ships two ready-made system tools (`OCRTool`, `BarcodeReaderTool`) for exactly this.

Rule of thumb: **open-ended / descriptive → Foundation Models; specific / precise / real-time → a Vision request; both → a Vision-backed tool the model can call.**

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** It's better to have the context than to miss a pattern or make a mistake.

| Reference | Load When |
|-----------|-----------|
| **[Segmentation](references/segmentation.md)** | Tap-to-segment / interactive segmentation — `GenerateIterativeSegmentationRequest`, point/box/lasso/scribble selection, refining a mask by adding/subtracting points, the mask PixelBuffer, normalized coordinates, lasso stroke width, and the on-device model download (`downloadAssets` / `assetStatus`) |
| **[Image Analysis](references/image-analysis.md)** | The general request/handler pattern; **feature prints** for image similarity (`GenerateImageFeaturePrintRequest`); **saliency-based cropping** (`GenerateObjectnessBasedSaliencyImageRequest`) to zoom to the subject; and the broader 30+ Vision capabilities (facial analysis, pose estimation, detection & classification, trajectory analysis, object tracking) |
| **[Foundation Models Image Tools](references/foundation-models-image-tools.md)** | Plugging Vision into an LLM — image inputs to a prompt, image-based tools that take an `ImageReference`, resolving that reference through the session transcript, the `OCRTool` / `BarcodeReaderTool` system tools, and labeling attached images. The Vision-side view of the `foundation-models` skill's tools |
| **[watchOS](references/watchos.md)** | Using Vision on watchOS — e.g. a saliency crop to zoom a photo on the small screen |

Cross-skill: for the LLM/session side of image tools (image attachments, tool protocol, system tools, RAG), see the **`foundation-models`** skill → `vision-and-system-tools.md` and `tool-calling.md`.

## Core Workflow

Every Vision request follows the same shape. You don't call a global function — you build a **request**, hand your image to an **`ImageRequestHandler`**, and read back an **observation/result**.

1. **Start with an image** and wrap it in an `ImageRequestHandler` (accepts many image types — `CGImage`, `CVPixelBuffer`, `URL`, platform image types). `// confirm exact initializer`
2. **Create the request** for your task — `GenerateIterativeSegmentationRequest`, `GenerateObjectnessBasedSaliencyImageRequest`, `GenerateImageFeaturePrintRequest`, a detector, a classifier, etc. Configure any inputs (e.g. a seed point).
3. **Perform it on the handler**: `let result = try await handler.perform(request)`.
4. **Read the observation/result** — a mask `PixelBuffer`, salient-object bounding boxes, a feature print, detected rectangles, and so on. Vision returns results in **normalized coordinates** (origin lower-left, values 0–1).
5. **For requests backed by a downloadable on-device model** (e.g. segmentation), ensure the model is present first — kick off `downloadAssets` and check `assetStatus` before performing.

```swift
import Vision

let handler = ImageRequestHandler(image)              // confirm exact API against current Apple documentation
let request = GenerateObjectnessBasedSaliencyImageRequest()
let observation = try await handler.perform(request)  // an observation you read results from
```

## Common Mistakes

1. **Wrong coordinate space.** Vision uses **normalized** coordinates with the origin in the **lower-left**, values 0–1 — not UIKit's top-left pixel space. Feeding raw touch pixels as a seed point (or reading a bounding box as if it were top-left pixels) segments/crops the wrong region. Convert both directions and flip the Y axis.

2. **Performing a segmentation request before the model is downloaded.** The first tap-to-segment on a device needs an on-device model. Call `downloadAssets` and gate the UI on `assetStatus`; don't `perform` until the model is ready, or the request fails.

3. **Lasso strokes that are too thin.** A lasso (or scribble) whose line width is under **1% of the image width** produces poor masks. Scale stroke width to the image, not to screen points.

4. **Reaching for the LLM when a fixed Vision API is the right tool.** Asking a language model to read dense text, decode a QR code, or find faces is slower and less reliable than the purpose-built Vision request (or the `OCRTool` / `BarcodeReaderTool`). Use Foundation Models for open-ended, descriptive tasks; use Vision for precise, repeatable ones — see `foundation-models-image-tools.md`.

5. **Passing whole images into an LLM tool, or forgetting to label them.** Image-based tools take an **`ImageReference`**, not the pixels; the reference is resolved through the session transcript. And give each attached image a **label** so the model can pick which one to hand to a tool — unlabeled images leave it guessing.

6. **Inverting feature-print distance.** A feature print measures similarity by **distance**: **smaller distance = more similar**. Sort ascending and threshold on a small distance; don't treat a large distance as "close".

7. **Assuming Vision isn't available on your target.** Vision now runs on **watchOS** too — you can crop-to-subject on the watch. Don't skip it on smaller platforms (see `watchos.md`).
