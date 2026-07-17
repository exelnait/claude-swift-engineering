---
name: visual-intelligence
description: Use when integrating your app with Visual Intelligence — returning app content from image search via App Intents entities plus an IntentValueQuery over a SemanticContentDescriptor, opening a tapped result with an OpenIntent, returning multiple result types with a @UnionValue, continuing into the app through the semanticContentSearch schema, and receiving data FROM Visual Intelligence (events, contacts, medical-device readings) through system stores (EventKit, Contacts, HealthKit); on iOS, iPadOS, and macOS.
---

# Visual Intelligence

> These capabilities are part of the 2026 releases and newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

Visual Intelligence lets people learn about what's around them — physical surroundings through the camera, or on-screen content through a screenshot — and act on it. Your app plugs into that experience in two opposite directions. Get the direction right first: are you **handing results to** Visual Intelligence, or **reading data it produced**?

Visual Intelligence integration is built on **App Intents**. The entity, query, and open-intent vocabulary is the same one that powers Siri, Shortcuts, and Spotlight — if you have adopted App Intents, you already have most of the pieces (see the `app-intents-widgets` skill, `references/app-intents.md`).

## Overview — two integration points

**1. PROVIDE results via Image Search.** When someone highlights something in a photo or screenshot and picks your app, Visual Intelligence queries you and shows your content right in its results sheet. You supply:
- an `AppEntity` describing each result (with a compact `displayRepresentation`),
- an `IntentValueQuery` whose input is a `SemanticContentDescriptor` (the captured image) and whose output is your entities,
- an `OpenIntent` that lands the tap on the right screen.

Your app appears alongside other adopting apps; the system decides ordering.

**2. RECEIVE data via system store integrations.** Other Visual Intelligence actions (add to calendar, add to contacts, log a medical-device reading) don't call your app — they write to **shared system stores**. If your app already reads those stores, Visual Intelligence becomes a new input source **automatically**: events via **EventKit**, contacts via **Contacts**, medical readings via **HealthKit**. Add a change observer and the data appears with no extra plumbing.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** Guessing an API in this 2026 surface wastes a build/test cycle on device.

| Reference | Load When |
|-----------|-----------|
| **[Image Search](references/image-search.md)** | Providing results INTO Visual Intelligence — an `AppEntity` + `displayRepresentation`, the `IntentValueQuery` over a `SemanticContentDescriptor`, on-device Vision feature-print search (`GenerateImageFeaturePrintRequest`), and the `OpenIntent` that lands the tap |
| **[Multiplatform & UnionValue](references/multiplatform-and-union.md)** | Shipping the same query on iPadOS/macOS (camera vs screenshots, large Mac pixel buffers), returning more than one entity type with `@UnionValue`, or adding an in-app "More results" continuation via the `semanticContentSearch` schema |
| **[System Store Integrations](references/system-store-integrations.md)** | RECEIVING data Visual Intelligence wrote — calendar events via `EKEventStore` (+ change observer), contacts via `CNContactStore`, or medical-device readings via `HKHealthStore` |

## Core Workflow

Providing results (Image Search):

1. **Model the result as an `AppEntity`** — identifier, the few display fields, and thumbnail data. Give it a default `EntityQuery` (id → entity, for the open round-trip) and a `displayRepresentation` with a title, subtitle, and thumbnail.
2. **Implement an `IntentValueQuery`** whose input is a `SemanticContentDescriptor`. Grab its `pixelBuffer` and run your search. (Only one query per app may take a `SemanticContentDescriptor`.)
3. **Search fast and ranked** — on device with Vision feature prints or against your server. Precompute the catalog side, apply a distance threshold, sort by similarity, and **limit** the count. An empty array is fine.
4. **Add an `OpenIntent`** that navigates to the selected entity. Reuse an existing one if you have it; keep `perform()` to navigation only.
5. **(Optional) Return multiple types** with a `@UnionValue` enum, and add a `semanticContentSearch` intent so "More results" continues into your full in-app search.
6. **Ship to iPad and Mac** — the query, entities, and open-intent are unchanged; just handle screenshots and larger pixel buffers.

Receiving data (system stores):

7. **Read the store you already use** (EventKit / Contacts / HealthKit) and register a **change observer**. Visual Intelligence-written events, contacts, and readings then flow in automatically.

## Common Mistakes

1. **Full-resolution images in the `displayRepresentation`.** Serve a **thumbnail-sized** image, not your full-res asset — results load faster. Remember the layout: multiple results render in a two-column grid (small images look right); a single result takes the **full width** of the sheet.

2. **Too much text in a result.** You get about **three lines** total (title + subtitle) plus a thumbnail. Put the most identifying information there and stop.

3. **Computing feature prints at query time.** Precompute prints for your catalog ahead of time; at query time you only process the one captured image. Doing catalog work per query makes results slow.

4. **Unranked or unbounded results.** Sort by similarity so the best match is first, apply a maximum distance threshold to drop weak matches, and cap the number returned. If nothing matches, return `[]` — the system shows an empty state.

5. **Heavy work in the `OpenIntent`'s `perform()`.** It runs as the app comes to the foreground. Do navigation only and defer loading until after the view appears.

6. **A separate `OpenIntent` (or query) just for Visual Intelligence.** Reuse your existing open-intent. And you can only have **one** `IntentValueQuery` taking a `SemanticContentDescriptor` — to return more than one entity type, use `@UnionValue`, not a second query.

7. **Ignoring large Mac pixel buffers.** On macOS the captured buffer can be far bigger than on iPhone; consider resizing before feature-printing.

8. **Thinking Visual Intelligence only *takes* results.** It also *produces* data. If your app reads EventKit / Contacts / HealthKit, add a change observer and Visual Intelligence-created entries appear for free — no extra integration.
