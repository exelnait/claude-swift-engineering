# Media Sharing Extensions

> These capabilities are part of the 2026 releases and newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

**Media Sharing Extensions** are a set of APIs for playing media from iPhone to other **speakers and TVs** through a single, unified system interface. They let your app use the **system device picker** for all the media protocols your app supports, and the chosen device is reflected on system surfaces like Control Center.

This is a different concern from media sessions: media sessions surface *what's playing* in the now-playing experience; Media Sharing Extensions handle *routing that media to an external device*. Adopt both when your app both plays media and casts it elsewhere.

## What changes

Traditionally, supporting a media protocol meant **embedding that protocol's SDK into your app bundle** — one SDK per protocol, each shipped, updated, and maintained by you.

With Media Sharing Extensions:

- **Protocol implementations live outside your app** and are **managed by the system**, not embedded in your bundle.
- **Your app focuses on the media content**, not the playback technology.
- **New protocols become usable without adopting another SDK** — as more protocols become available, apps built on Media Sharing Extensions can use them automatically.

| | Traditional (per-SDK) | Media Sharing Extensions |
|---|---|---|
| Protocol code | Embedded in your app bundle | Lives outside the app, system-managed |
| Device picker | Custom, per app | System device picker (unified) |
| Adding a protocol | Integrate another SDK, ship an update | Available without adopting a new SDK |
| Your app's job | Content **and** playback tech | **Content** (the system handles routing) |

## When to use it

Reach for Media Sharing Extensions when your app needs to **send media from iPhone to external speakers or TVs** and you'd otherwise be bundling one or more casting SDKs. Using the system picker also means the user's device selection is consistent with the rest of the system and visible in Control Center.

For the details of adopting it, see the **"Routing media to third-party devices"** article. Confirm the exact protocol/type names and the extension configuration against current Apple documentation — these APIs are newer than this guidance's training data.
