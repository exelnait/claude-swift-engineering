# Local Media Sessions

> These capabilities are part of the 2026 releases and newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

Local media sessions surface content your app plays **on this device** in the system now-playing experience. The flow is two steps: conform your `@Observable` player model to **`MediaSessionRepresentable`** (the contract that tells the system *what* is playing and *how* to handle interactions like skip or pause), then create a **`MediaSession`** with that model so the system starts observing it.

## The player model

Start from the model you already have — an `@Observable` class that owns your playback engine and tracks what's currently playing.

```swift
import NowPlaying      // confirm exact module name against current Apple documentation
import Observation

@Observable
final class PlayerModel {
    let audioEngine: AudioEngine        // your app's playback engine
    var currentSound: Sound             // what's playing right now

    init(audioEngine: AudioEngine, currentSound: Sound) {
        self.audioEngine = audioEngine
        self.currentSound = currentSound
    }

    func resume()     { audioEngine.play() }
    func pause()      { audioEngine.pause() }
    func skipToNext() { currentSound = nextSound() /* … */ }
}
```

## Conforming to `MediaSessionRepresentable`

`MediaSessionRepresentable` is "a contract between the app and the system." Conform the model and provide each part of the representation. Names below follow the talk; where the exact spelling/labels weren't stated, they're flagged.

```swift
extension PlayerModel: MediaSessionRepresentable {

    // 1. A unique identifier for this session representation.
    var id: String { currentSound.id }          // property name may be `id` or `identifier` — confirm exact API

    // 2. The content that's playing. Pick the content-specific type that fits:
    //    Music, Podcast, MovieContent — or GenericContent as a fallback.
    var content: GenericContent {               // one of the content-specific types
        GenericContent(
            id: currentSound.id,
            title: currentSound.name,           // shown as the title
            subtitle: currentSound.description  // shown as the subtitle
        )                                        // confirm exact initializer labels against current Apple documentation
    }

    // 3. Media type — .audio or .video.
    var mediaType: MediaType { .audio }         // property/type name unconfirmed — confirm exact API

    // 4. Duration — .continuous for open-ended media (e.g. ambient audio),
    //    or a timed/known duration for a track with a defined length.
    var duration: MediaDuration { .continuous } // timed case spelling unconfirmed — confirm exact API

    // 5. Artwork — an ASYNC closure the system calls whenever it needs an
    //    image at a specific size.
    var artwork: Artwork {
        Artwork { size in                       // async; receives the requested size — confirm exact API
            await loadArtwork(for: currentSound, size: size)
        }
    }

    // 6. A snapshot of the current playback state.
    var playbackSnapshot: PlaybackSnapshot {    // property name may be `playbackSnapshot` or `snapshot`
        PlaybackSnapshot(isPlaying: audioEngine.isPlaying)
        // For content with a defined duration, ALSO pass elapsedTime:
        // PlaybackSnapshot(isPlaying: audioEngine.isPlaying, elapsedTime: audioEngine.elapsedTime)
        // confirm exact initializer labels against current Apple documentation
    }

    // 7. The actions your app supports. Each command's closure is called by
    //    the system when the user performs that action on a system surface.
    var commands: [MediaCommand] {              // container shape (builder vs array vs struct) unconfirmed — confirm exact API
        [
            .play  { [weak self] in self?.resume() },
            .pause { [weak self] in self?.pause() },
            .next  { [weak self] in self?.skipToNext() },
        ]
    }
}
```

### Content types

`NowPlaying` offers content-specific types so the system can present media appropriately:

| Type | Use for |
|------|---------|
| `Music` | Songs / music tracks |
| `Podcast` | Podcast episodes |
| `MovieContent` | Video / movies |
| `GenericContent` | Anything the specific types don't cover (ambient audio, sound effects, etc.) |

Each carries an **id**, a **title**, and a **subtitle** (the talk maps a sound's `name` → title and `description` → subtitle). Prefer the specific type over `GenericContent` when one fits — see Common Mistake #5 in `SKILL.md`.

### Duration: `.continuous` vs timed

- **`.continuous`** — open-ended playback with no fixed length (ambient sounds, live streams). The snapshot only needs `isPlaying`.
- **Timed / defined duration** — a finite item. Provide the duration *and* an `elapsedTime` in the `PlaybackSnapshot` so progress and scrubbing track correctly. (The talk states the requirement but doesn't name the timed case — confirm the exact spelling.)

### Artwork is size-driven and async

The system requests artwork **at the size it needs**, when it needs it, via your async closure. Load/decode on demand inside the closure (and cache as appropriate); don't pre-render a single fixed-size image. The exact parameter/return types (e.g. whether it hands you a `CGSize` and expects a `CGImage`/`UIImage`/`Data`) aren't given in the talk — confirm against current Apple documentation.

### Commands are closures the system invokes

`commands` declares every action your app supports (play, pause, next, …). When the user taps that control on the Lock Screen, in Control Center, in CarPlay, etc., the system calls the matching closure. Perform the real action there and let the model's observed state update — the control reflects the new state automatically (e.g. pause → the button flips to play). The exact shape of the command container isn't specified in the talk; the array above is illustrative.

## Connecting to the system with `MediaSession`

Conformance alone surfaces nothing. Create a **`MediaSession`** with your model — do this where you set up playback (e.g. alongside your audio engine). Once created, it observes the model and keeps the now-playing surfaces up to date automatically.

```swift
final class PlaybackController {
    let player: PlayerModel
    private let mediaSession: MediaSession

    init() {
        let engine = AudioEngine()
        player = PlayerModel(audioEngine: engine, currentSound: .default)

        // Create the session in the same place you set up the engine.
        mediaSession = MediaSession(player)     // observes `player` from here on — confirm exact initializer
    }
}
```

From this point, mutations to `player` (pausing, skipping, changing the current sound) flow through observation to every system surface — you never redraw the Lock Screen yourself.

## Pitfalls

- **No `MediaSession`** → nothing appears. Conforming to the protocol is only half the integration.
- **State changed off the model** → stale surfaces. Route every change through observed properties.
- **`elapsedTime` omitted for timed content** → progress won't advance.
- **Command closure that doesn't perform the action** → the control appears to do nothing and the button state won't update.
- **Blocking artwork loads** → the closure is async precisely so you can decode/fetch without stalling; keep it off the main thread.

For a deeper walkthrough, see the **"Publishing Media Sessions"** article in Apple Developer Documentation.
