# Threat Model & Availability

> These capabilities are part of the 2026 releases and newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

## What App Attest protects against

App Attest exists because a fraudster can take a copy of your shipped app and make it lie to your server. Concretely:

- **Modified / re-signed copies.** An attacker modifies your compiled binary or resource bundles, **re-signs** the app with their own provisioning profile, and runs the tampered copy on a device.
- **Falsified requests.** A reverse-engineered copy sends **valid-looking requests** to your server to gain access to sensitive data or submit forged data. *Example:* a quiz-proctoring app whose modified client submits falsified quiz responses.
- **Injected content / cheat menus.** Code you never shipped is injected into a compromised copy. *Example:* a game with an injected cheat menu that boosts abilities and submits fraudulent scores to climb the leaderboard.

App Attest lets your **server reject these requests** by giving it cryptographic evidence about the copy of the app that made them.

## What App Attest proves

An **attestation** is cryptographic proof, rooted in the device's Secure Enclave, about the validity of your app running on the user's device. When your server validates it, you gain assurance on several dimensions:

- **Genuine Apple hardware.** The attested key was generated on a real Apple device's Secure Enclave — not an emulator or a lifted key. This is the core guarantee.
- **Relying-party identity.** Your app is uniquely identified by a **relying-party identifier** = your **Team Identifier** (from your Apple developer provisioning profile) concatenated with your app's **bundle identifier**. If a fraudster re-signs your app with a profile whose Team ID doesn't match yours, App Attest surfaces the mismatch, exposing the unauthorized modification.
- **Launch validation category** *(new in iOS 27)*. Indicates the environment your app was launched in. For example, if you distributed through the **App Store** but observe a **TestFlight** launch validation category, that's a red flag that the copy isn't the one you shipped.
- **Bundle version.** Identifies the version of the app that's actually running. If a fraudster re-signs with a bundle version you never published, that becomes transparent to your server.

Beyond one-time attestation, App Attest also **secures ongoing payloads**: using cryptographic properties from a previously issued attestation, the app generates **assertions** your server verifies to confirm a specific payload was **not tampered with in transit**. (See `keys-attestation-assertions.md` and `server-validation.md`.)

These properties are what you feed into a **risk assessment** — not a single kill-switch. See `best-practices.md`.

## Availability — gate everything with `isSupported`

App Attest is supported on **all major Apple platforms, including macOS 27 and later** — macOS support is new; it was previously unavailable. But even on a supported OS, App Attest **may not be available for every app type**. Notably, it is available on **Action** and **SSO** app extensions, but **not** other extension types.

Because availability varies by platform *and* app type, **never assume** — gate every call site through the framework's `isSupported` check:

```swift
import DeviceCheck   // App Attest ships in the DeviceCheck framework — confirm exact module/type against current Apple documentation

// DCAppAttestService is the documented App Attest entry point — confirm exact API against current Apple documentation
let service = DCAppAttestService.shared

guard service.isSupported else {
    // App Attest isn't available here (unsupported platform or app-extension type).
    // Decide whether the user may proceed with reduced trust — and record this outcome.
    return handleUnavailable()
}
// ... proceed with key generation / attestation / assertion
```

Decide, per feature, **what happens when App Attest is unavailable**: whether the user may still use the functionality, and with how much scrutiny.

## `isSupported` as a fraud signal

The `isSupported` response is itself an input to your risk model. If you shipped to a **supported** platform yet observe a **spike in "unsupported" responses from a particular user**, that can indicate tampering (e.g., a modified framework or a copy running somewhere it shouldn't). Record `isSupported` outcomes per user and watch for anomalies — but treat a spike as a signal to investigate, not an automatic block (see `best-practices.md`).

## A concrete macOS tampering example

Suppose you have a macOS app integrated with App Attest, and a fraudster:

1. Disables **System Integrity Protection (SIP)**,
2. Modifies your app and **re-signs** it with a different provisioning profile, and
3. Modifies the App Attest framework in the system path.

The attestation that reaches your server will expose this: the **key access control property** (the macOS **ACL Blob OID**, see `server-validation.md`) reflects the **disabled SIP** state, and the attestation may also carry a **modified Team Identifier, launch validation category, or bundle version**. Your server can then refuse to communicate with the modified copy and factor the event into the user's risk profile.
