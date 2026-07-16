# Privacy & Permissions

Two obligations: **request** access to a capability at the point of use (with a declared reason), and **declare** what data your app collects/uses in the privacy manifest. Miss the first and the app crashes; miss the second and the App Store rejects it (Common Mistakes #4, #5).

## Usage strings (Info.plist)

Accessing a protected resource requires a matching `NS…UsageDescription` string — accessing without one **crashes** on first use. Write an honest, specific reason (Apple reviews these; vague ones get rejected).

| Capability | Info.plist key |
|-----------|----------------|
| Camera | `NSCameraUsageDescription` |
| Microphone | `NSMicrophoneUsageDescription` |
| Photo library (read) | `NSPhotoLibraryUsageDescription` |
| Photo library (add) | `NSPhotoLibraryAddUsageDescription` |
| Location (in use) | `NSLocationWhenInUseUsageDescription` |
| Location (always) | `NSLocationAlwaysAndWhenInUseUsageDescription` |
| Contacts | `NSContactsUsageDescription` |
| Calendars | `NSCalendarsFullAccessUsageDescription` (iOS 17+) |
| Face ID | `NSFaceIDUsageDescription` |
| Local network | `NSLocalNetworkUsageDescription` |
| Bluetooth | `NSBluetoothAlwaysUsageDescription` |
| Motion | `NSMotionUsageDescription` |
| Tracking (ATT) | `NSUserTrackingUsageDescription` |

## Request at the point of use

Ask when the user is doing the thing that needs it, with context — not at launch. Each framework has its own request flow:

```swift
// Camera / mic:
let granted = await AVCaptureDevice.requestAccess(for: .video)

// Photos (prefer the limited-library-friendly PhotosPicker where possible):
let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)

// Location:
let manager = CLLocationManager()
manager.requestWhenInUseAuthorization()      // delegate reports the result

// Notifications:
let ok = try await UNUserNotificationCenter.current()
    .requestAuthorization(options: [.alert, .sound, .badge])

// Contacts:
let store = CNContactStore()
let granted = try await store.requestAccess(for: .contacts)
```

Always check the *current* status first (`AVCaptureDevice.authorizationStatus(for:)`, `CLLocationManager().authorizationStatus`, etc.) and handle `.denied` by guiding the user to Settings — never re-prompt in a loop (the system only prompts once).

## App Tracking Transparency

If you track users across apps/websites (advertising identifier, data brokers), you must request permission first, and only after the prompt has been shown:

```swift
import AppTrackingTransparency
let status = await ATTrackingManager.requestTrackingAuthorization()
// Only if .authorized may you access the IDFA / share for tracking.
```

Requires `NSUserTrackingUsageDescription`. Don't gate essential functionality on it, and don't track before authorization.

## Privacy manifest (`PrivacyInfo.xcprivacy`)

A required resource declaring your app's (and SDKs') data practices. Missing or incomplete manifests cause rejection (Common Mistake #5). It declares:

- **Collected data types** — for each: the type (e.g. email, coarse location, identifiers), whether it's linked to identity, used for tracking, and the purpose.
- **Tracking domains** — hosts used for tracking are declared and blocked unless ATT is granted.
- **Required-reason APIs** — certain "fingerprintable" APIs (e.g. `UserDefaults`, file timestamp, disk space, active keyboard, system boot time) require a declared **reason code**. Using them without a declared reason is rejected.

```xml
<!-- PrivacyInfo.xcprivacy (excerpt) -->
<key>NSPrivacyAccessedAPITypes</key>
<array>
  <dict>
    <key>NSPrivacyAccessedAPIType</key>
    <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
    <key>NSPrivacyAccessedAPITypeReasons</key>
    <array><string>CA92.1</string></array>   <!-- "access info only from the app itself" -->
  </dict>
</array>
```

Audit each third-party SDK's manifest too — your app's Privacy Report aggregates them.

## Prefer non-prompting alternatives

The best permission is one you don't need to ask for:
- **`PhotosPicker`** (SwiftUI) reads a chosen photo without full library access.
- **`.fileImporter`** vends a specific file without broad file access.
- **`ShareLink`** shares without extra entitlements.

Reach for these before requesting a blanket permission — fewer prompts, less scope, easier review. (See `macos-multiplatform` and `swiftui-patterns` for the pickers.)

## Pitfalls

- **Accessing a resource with no usage string** → immediate crash.
- **Vague/dishonest usage strings** → App Review rejection.
- **Requesting at launch** → users deny blindly; ask in context.
- **Re-prompting after `.denied`** → no-op; deep-link to Settings instead.
- **Ignoring the privacy manifest / required-reason APIs** → rejection; declare them (and your SDKs').
