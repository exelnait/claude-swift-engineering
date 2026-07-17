---
name: now-playing
description: >-
  Use when surfacing your app's media in the system now-playing experience — Lock Screen, Control Center, Dynamic Island, StandBy, CarPlay, Apple Watch, Vision Pro, Apple TV — with the NowPlaying framework: local media sessions, remote media sessions controlling other devices, and Media Sharing Extensions.
---

# NowPlaying: The System Now-Playing Experience

> These capabilities are part of the 2026 releases and newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

## Overview

Media has a persistent, glanceable home across Apple platforms — the **system now-playing experience**. On iPhone it appears on the **Lock Screen**, in **Control Center**, and in the **Dynamic Island**; when the phone is set down and charging it surfaces in **StandBy**; in the car it's front and center in **CarPlay**. The same experience is available on **Apple Watch, Apple Vision Pro, and Apple TV**.

The **NowPlaying framework** brings your app's media into that experience with a **model-driven** design. Instead of hand-pushing now-playing info and wiring individual remote-command handlers, you describe *what* is playing and *how* it can be controlled by conforming an `@Observable` player model to a representable protocol. The system observes the model and keeps every surface up to date automatically — including controls that fire even when your app isn't foregrounded.

It covers three scenarios:

- **Local media sessions** — content your app plays on *this* device. Conform your model to `MediaSessionRepresentable`, then create a `MediaSession` with it.
- **Remote media sessions** — content playing on *another* device your app controls (e.g. a smart speaker). An app extension conforming to `RemoteMediaSessionExtension`, driven by APNs push, surfaces and controls it.
- **Media Sharing Extensions** — a unified system device picker for routing media from iPhone to other speakers and TVs, with the playback-protocol implementations living **outside** your app bundle and managed by the system.

**Core principle:** your `@Observable` model is the single source of truth. Every state change and every user command flows *through* the model, and NowPlaying propagates it to the system — you never draw the Lock Screen or Control Center yourself.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** It's better to have the context than to miss a pattern or make a mistake.

| Reference | Load When |
|-----------|-----------|
| **[Local Media Sessions](references/media-sessions.md)** | Surfacing media your app plays on-device: conforming an `@Observable` model to `MediaSessionRepresentable` (identifier, `content`, media type, duration, `Artwork`, `PlaybackSnapshot`, `commands`) and creating a `MediaSession` |
| **[Remote Media Sessions](references/remote-media-sessions.md)** | Controlling and surfacing content on *another* device (smart speaker, TV): the `RemoteMediaSessionExtension` app extension, `RemoteMediaSessionRepresentable`, `MediaDevice`/volume, APNs push + `update(_:)`, and `RemoteMediaSessionAttributes` |
| **[Media Sharing Extensions](references/media-sharing-extensions.md)** | Routing media from iPhone to third-party speakers/TVs through the **system device picker** without embedding each protocol's SDK in your app bundle |

## Core Workflow

1. **Model playback state as an `@Observable` model.** Hold a reference to your playback engine (or server client) and the currently playing item. This model is what the system observes.
2. **Conform the model to the right representable protocol.** `MediaSessionRepresentable` for local playback; `RemoteMediaSessionRepresentable` for a device you control remotely. Provide the required representation: unique identifier, `content` (pick the content-specific type — `Music`, `Podcast`, `MovieContent`, or `GenericContent`), media type (`.audio`/`.video`), duration (`.continuous` or a timed duration), `Artwork` (async, size-driven), a `PlaybackSnapshot`, and `commands`.
3. **Connect it to the system.**
   - **Local:** create a `MediaSession` with the model, in the same place you set up playback. It begins observing immediately.
   - **Remote:** build an app extension conforming to `RemoteMediaSessionExtension` (via `RemoteMediaSessionExtensionConfiguration` + the `remote-media` extension point) whose `session(_:)` returns your model from a `RemotePlayerState`; wire APNs push into `update(_:)`.
4. **Route every user action through the model.** Command closures the system invokes should perform the action — locally on your engine, or as a request to your server for remote — and let observation carry the resulting state back to the system.
5. **For sending media to external speakers/TVs, adopt Media Sharing Extensions** so your app uses the system device picker instead of embedding a streaming SDK per protocol.
6. **Verify on real surfaces:** Lock Screen, Control Center, Dynamic Island, StandBy, CarPlay — and across Apple Watch, Apple Vision Pro, and Apple TV.

## Common Mistakes

1. **Conforming to the protocol but never creating the session.** Adopting `MediaSessionRepresentable` alone surfaces nothing. `MediaSession` (or, for remote, the `RemoteMediaSessionExtension`) is what actually connects the representation to the system and starts observing your model. Create it where you set up playback.

2. **Mutating playback state outside the observed model.** NowPlaying keeps surfaces current by observing your `@Observable` model. If you pause the engine or change the track without the change flowing through observed properties, the Lock Screen and Control Center go stale. Every state change must be visible to the model.

3. **Treating command closures as fire-and-forget.** The system calls your `commands` closures when the user taps play/pause/next; you must actually perform the action *and* let the new state propagate through the model so the control updates (e.g. the pause button flipping to play). A closure that only logs leaves the UI wrong.

4. **Omitting `elapsedTime` for timed content.** For continuous media (`.continuous`) a `PlaybackSnapshot` with `isPlaying` is enough, but content with a defined duration must also report `elapsedTime`, or the scrubber/progress won't track.

5. **Using `GenericContent` when a specific type fits.** `Music`, `Podcast`, and `MovieContent` give the system richer, better-tailored presentation. Reach for `GenericContent` only when none of the specific types describe your media (e.g. ambient audio).

6. **Expecting to drive a remote session from your main app process.** Remote updates arrive as **APNs pushes** that launch your **app extension**, whose `update(_:)`/`session(_:)` the system invokes — you don't push updates to the system from the app for remote sessions. Design the extension + server + push loop, not a foreground poll.

7. **Giving `MediaDevice` identifiers that aren't stable across sessions.** The device identifier must be stable across different sessions so the system can track the same speaker over time; a per-launch UUID breaks continuity.

8. **Embedding a streaming SDK per protocol.** That's the pattern Media Sharing Extensions replace — let the protocol implementations live outside your bundle, managed by the system, so new protocols work without adopting yet another SDK.
