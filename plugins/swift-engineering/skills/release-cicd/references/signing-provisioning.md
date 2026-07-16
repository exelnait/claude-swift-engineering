# Signing & Provisioning

Code signing proves the app's origin and integrity; provisioning ties a signed build to an App ID, capabilities, devices, and a distribution method. Most "it won't build/upload" pain is here — understand the pieces and pick one strategy (Common Mistake #1).

## The pieces

- **Certificate** — your team's signing identity (a public/private key pair). *Development* certs for debug/device runs; *Distribution* certs for App Store/ad-hoc/enterprise. The private key lives in the keychain; losing it means revoking and reissuing.
- **App ID** — the app's identity on Apple's side (an explicit bundle id like `com.example.trips`), carrying the **capabilities** it's allowed to use (Push, App Groups, iCloud, Sign in with Apple, HealthKit, …).
- **Entitlements** — the `.entitlements` file in the target declaring the capabilities the binary uses. Must match the App ID's capabilities (Common Mistake #5).
- **Provisioning profile** — binds {App ID + certificate + (devices for development/ad-hoc) + entitlements} into a file the build embeds. *Development*, *Ad Hoc*, *App Store*, and *Enterprise* profile types.

A build signs with a **certificate**, embeds a **provisioning profile** that references an **App ID** whose **capabilities** match the target's **entitlements**. Any mismatch fails.

## Automatic vs manual signing

- **Automatic** ("Automatically manage signing" in Xcode) — Xcode creates/renews certificates and profiles for you against your team. Great for solo/simple projects; least friction locally.
- **Manual** — you select explicit profiles per configuration. Necessary for some CI setups and precise control. More moving parts.
- **Managed via fastlane `match`** — the team standard: `match` stores the distribution certificate and profiles **encrypted in a git repo** (or cloud storage), so every developer and CI machine pulls the *same* signing assets. Eliminates "works on my Mac" signing drift. See the fastlane reference.

Pick one and be consistent (Common Mistake #1). For teams + CI, `match` (or Xcode Cloud's managed signing) is the reliable choice.

## Distribution methods

| Method | For | Profile |
|--------|-----|---------|
| **App Store** | TestFlight + App Store | App Store distribution profile |
| **Ad Hoc** | Direct install on registered devices | Ad Hoc profile (device UDIDs) |
| **Enterprise** | In-house distribution (Apple Enterprise Program) | Enterprise profile |
| **Development** | Debug/run on device | Development profile |

For shipping, you want an **App Store** distribution certificate + profile; TestFlight uses the same App Store build.

## Capabilities must line up

When you enable a capability (Push Notifications, App Groups for widgets, iCloud/CloudKit for sync, Sign in with Apple, Keychain Sharing — see the `app-intents-widgets`, `swiftdata`, and `security` skills), you must:

1. Add it to the **App ID** (App Store Connect / Developer portal).
2. Add the matching **entitlement** to the target's `.entitlements`.
3. Regenerate the **provisioning profile** so it includes the capability.

Miss a step and you get a signing error at build or a silent runtime failure (e.g. Keychain/App-Group access denied). Keep the three in sync (Common Mistake #5).

## Reading signing errors

- **"No profiles for 'com.example.trips' were found"** → no profile matches this bundle id + method; create/download it (or let automatic/match generate it).
- **"Provisioning profile doesn't include the … entitlement"** → capability added in code but not on the App ID/profile; add it to the App ID and regenerate.
- **"Certificate … has expired / been revoked"** → reissue the distribution cert (with `match nuke` + regenerate if using match).
- **"No signing certificate 'iOS Distribution' found"** → the private key isn't in this machine's keychain; import it or use match to fetch it.
- **CI "Command CodeSign failed"** → almost always a missing profile/cert on the runner; managed signing (match/Xcode Cloud) fixes it.

## Headless signing on CI

- Never rely on interactive keychain prompts. Import the distribution cert into a temporary keychain (match does this) and select the profile explicitly, or use Xcode Cloud's managed signing.
- Authenticate to Apple with an **App Store Connect API key** (`.p8`), not an Apple ID (Common Mistake #4) — see the TestFlight/App Store reference.

## Pitfalls

- **Multiple signing strategies at once** (some targets automatic, some manual, plus match) → conflicts; standardize.
- **Wildcard App ID with capabilities** → many capabilities require an *explicit* App ID; use one.
- **Committing the signing private key unencrypted** → security incident; use match's encryption or a secrets store.
- **Entitlements/App ID drift** → build or runtime failures; change all three together.
