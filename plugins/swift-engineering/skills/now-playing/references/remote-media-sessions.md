# Remote Media Sessions

> These capabilities are part of the 2026 releases and newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

Remote media sessions surface content playing on **another device that your app controls** — a smart speaker, a TV — in the system now-playing experience. The user picks a device (e.g. "Living Room Speaker") from your app, your app talks to it through a web server, and the system shows and controls that remote playback on the Lock Screen, in Control Center, and beyond.

Adoption mirrors local media sessions (`RemoteMediaSessionRepresentable` shares the same core: identifier, `content`, media type, duration, `Artwork`, `PlaybackSnapshot`), and adds remote-specific pieces: a `devices` list, volume control, and a push-driven `update(_:)`. Unlike a local session, a remote session is driven by an **app extension** and **APNs push notifications**, not by your foreground app.

## How updates flow (extension + APNs push)

Because the controlled device changes state independently of the phone, updates arrive through push and are handled in an extension:

**Device → system (state changed on the speaker):**
```
speaker state changes → speaker tells your server
     → server sends an APNs push to iPhone with the new state
     → system launches your app extension with the push payload
     → extension returns an updated session representation → system UI updates
```

**System → device (user taps a control in system UI):**
```
user taps play/next/volume on a system surface
     → system calls the command handler in your app extension
     → extension sends the command to your server
     → server notifies the speaker, which reacts
```

For the server/push side, see the **"Setting up a remote notification server"** article on developer.apple.com.

## The app extension

Create an app extension conforming to **`RemoteMediaSessionExtension`**, configured with **`RemoteMediaSessionExtensionConfiguration`** and the **`remote-media`** extension-point identifier. Its **`session(_:)`** method is called by the system whenever it needs to interact with a remote session representation — to update UI or handle an interaction — and returns your model built from a `RemotePlayerState`.

```swift
import NowPlaying          // confirm exact module name against current Apple documentation

@main
struct MyRemoteMediaExtension: RemoteMediaSessionExtension {

    var configuration: RemoteMediaSessionExtensionConfiguration {
        // Bind to the `remote-media` extension point.
        RemoteMediaSessionExtensionConfiguration(/* extensionPoint: "remote-media" */)
        // confirm exact configuration initializer / extension-point wiring against current Apple documentation
    }

    // Called by the system to obtain a representation from the current state.
    func session(_ state: RemotePlayerState) -> some RemoteMediaSessionRepresentable {
        RemotePlayerModel(state: state, client: ServerClient())
        // parameter/return shape follows the talk ("use the RemotePlayerState to create my model, and return it")
        // confirm exact signature against current Apple documentation
    }
}
```

## The remote player model

`RemotePlayerModel` is an `@Observable` class holding a `ServerClient` (how it talks to your server) and the latest server state, conforming to **`RemoteMediaSessionRepresentable`**.

```swift
@Observable
final class RemotePlayerModel {
    let client: ServerClient
    var state: RemotePlayerState        // server state + latest push payload

    init(state: RemotePlayerState, client: ServerClient) {
        self.state = state
        self.client = client
    }
}
```

### Shared representation (same as local)

```swift
extension RemotePlayerModel: RemoteMediaSessionRepresentable {

    // Identifier — stable for this session (the talk uses the server's sessionID).
    var id: String { state.sessionID }              // confirm exact property name/type

    // Content describing what's playing on the speaker.
    var content: GenericContent {
        GenericContent(
            id: state.sound.id,
            title: state.sound.name,
            subtitle: state.sound.description
        )                                            // confirm exact initializer labels against current Apple documentation
    }

    var mediaType: MediaType { .audio }             // confirm exact API
    var duration: MediaDuration { .continuous }     // confirm exact API

    var artwork: Artwork {
        Artwork { size in await loadArtwork(for: state.sound, size: size) }   // confirm exact API
    }

    // Reflect the speaker's play state reported by the server.
    var playbackSnapshot: PlaybackSnapshot {
        PlaybackSnapshot(isPlaying: state.isPlaying)  // add elapsedTime: for timed content — confirm labels
    }

    // Each command sends a request to the server, which relays it to the speaker.
    var commands: [MediaCommand] {                   // container shape unconfirmed — confirm exact API
        [
            .play  { [weak self] in self?.client.send(.play) },
            .pause { [weak self] in self?.client.send(.pause) },
            .next  { [weak self] in self?.client.send(.next) },
        ]
    }
}
```

Everything above behaves like a local session — the difference is that commands become **server requests** instead of direct engine calls. The remaining requirements are remote-specific.

### `devices` — what's playing in this session

Map your server's device list into **`MediaDevice`** values so the system knows which devices are in the session and can offer volume control.

```swift
extension RemotePlayerModel {
    var devices: [MediaDevice] {                     // confirm exact property name/type
        state.devices.map { device in
            MediaDevice(
                id: device.stableID,                 // MUST be stable across different sessions
                name: device.name,
                type: .speaker,                      // device type, e.g. .speaker — confirm the case set
                capabilities: [device.volumeControl] // e.g. the device's volume control type
            ) { [weak self] newVolume in             // volume-change closure the system calls
                self?.client.send(.setVolume(newVolume))
            }
            // confirm exact MediaDevice initializer / capability & volume-control types against current Apple documentation
        }
    }
}
```

- Each `MediaDevice` needs an **identifier stable across sessions**, a **name**, a **device type** (e.g. `.speaker`), and a list of **capabilities** (such as the device's volume-control type).
- In Control Center the device **name** appears with its **volume level**. When the user moves the system volume slider, the **volume-change closure** is called with the new level — forward it to your server.

### `update(_:)` — apply a pushed state

When an APNs push arrives with new state (e.g. the content changed on the speaker), the system calls **`update(_:)`** on your representation. **`RemotePlayerState`** is a struct *you* define that conforms to **`RemoteMediaSessionAttributes`** — it represents both your server state and the push-notification payload. Store the new data; because the model is `@Observable`, NowPlaying detects the change and updates the system automatically.

```swift
extension RemotePlayerModel {
    func update(_ newState: RemotePlayerState) {     // confirm exact signature
        state = newState                             // observation propagates the change to the system
    }
}

// The attributes struct decoded from your server state / push payload.
struct RemotePlayerState: RemoteMediaSessionAttributes {   // confirm exact protocol requirements
    let sessionID: String
    let sound: RemoteSound
    let isPlaying: Bool
    let devices: [RemoteDevice]
    // Represents server state + the APNs push payload; likely Decodable from the payload — confirm.
}
```

## Pitfalls

- **Trying to update the system from the app process** → won't work for remote sessions. Updates come via APNs into the extension's `update(_:)`/`session(_:)`. Design the server + push + extension loop.
- **Unstable `MediaDevice` identifiers** → the system can't track the same speaker across sessions. Use a stable device ID, not a per-launch value.
- **Volume closure that only updates local UI** → the speaker won't actually change. Send the new level to your server.
- **State mutated outside the observed `state`** → stale surfaces. Apply every push through `update(_:)` so observation fires.
- **Command closures that don't reach the server** → controls appear dead; each closure must issue the corresponding server request.

For a deeper walkthrough, see the **"Publishing remote media sessions"** article, and **"Setting up a remote notification server"** for the APNs side.
