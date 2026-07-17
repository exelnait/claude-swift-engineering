# Keys, Attestation & Assertions (Client Flow)

> These capabilities are part of the 2026 releases and newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

The client's job is narrow: **generate** a Secure Enclave key, **attest** it once, and **assert** over payloads on demand. It never validates anything — that's the server's job (see `server-validation.md`). The three steps below build on each other.

All snippets assume this async bridge over the callback-based framework API. The type/method names are the documented App Attest surface, but hedge them:

```swift
import DeviceCheck
import CryptoKit
import Foundation

enum AppAttest {
    // DCAppAttestService + generateKey/attestKey/generateAssertion are the documented API —
    // confirm exact type names, signatures, and any async variants against current Apple documentation.
    static let service = DCAppAttestService.shared

    static var isSupported: Bool { service.isSupported }

    static func generateKey() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            service.generateKey { keyID, error in
                if let keyID { continuation.resume(returning: keyID) }
                else { continuation.resume(throwing: error ?? AppAttestError.unknown) }
            }
        }
    }

    static func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            service.attestKey(keyID, clientDataHash: clientDataHash) { attestation, error in
                if let attestation { continuation.resume(returning: attestation) }
                else { continuation.resume(throwing: error ?? AppAttestError.unknown) }
            }
        }
    }

    static func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            service.generateAssertion(keyID, clientDataHash: clientDataHash) { assertion, error in
                if let assertion { continuation.resume(returning: assertion) }
                else { continuation.resume(throwing: error ?? AppAttestError.unknown) }
            }
        }
    }
}

enum AppAttestError: Error { case unknown, notSupported, missingKeyID }
```

The `clientDataHash` is a **SHA-256 of the client data that embeds the server challenge** (the challenge alone, or a request body containing it). The same hash the app passes here is what the server re-derives to validate:

```swift
func clientDataHash(challenge: Data, payload: Data = Data()) -> Data {
    Data(SHA256.hash(data: challenge + payload))   // confirm the exact client-data construction against current Apple documentation
}
```

## Step 1 — Generate a key ID

The app asks App Attest to create a key. App Attest generates a **Secure Enclave-bound key pair on behalf of the app**; the **private key never leaves the Secure Enclave**. App Attest returns a **key ID** — a hash of the public key — which the app persists in the **Keychain**.

```swift
func provisionKeyIDIfNeeded() async throws -> String {
    guard AppAttest.isSupported else { throw AppAttestError.notSupported }   // see threat-model.md

    if let existing = try Keychain.appAttestKeyID() {   // Keychain storage — see the `security` skill
        return existing
    }
    let keyID = try await AppAttest.generateKey()
    try Keychain.setAppAttestKeyID(keyID)
    return keyID
}
```

**Key best practices:**

- **One key per user** for account-based apps, or **one key for the whole app** on the device. **Do not share keys across your user population.**
- **Store key IDs in the Keychain** (see the `security` skill for `SecItem` storage and accessibility).
- **Lifecycle:** key IDs **last as long as the app is installed** and **survive app updates**, but are **invalidated on reinstall, device restore, or iCloud restore**. When a key is gone, generate and re-attest a new one — and expect this on the server (legitimate key rotation, see `best-practices.md`).
- **Per-device, non-syncing.** Keys **do not sync across a user's devices**; each device provisions and attests its own.

## Step 2 — Attest the key

Attestation proves the freshly generated key belongs to your app on genuine Apple hardware. **Your server drives the challenge**; the app only responds.

Flow:
1. App fetches the key ID from the Keychain.
2. App asks **your server** to begin an attestation for that key ID.
3. **Server vends a challenge** to include in the attestation.
4. App calls the attestation API with the **key ID + challenge**. App Attest gathers attestation data derived from the Secure Enclave — a **snapshot of the device's hardware properties from boot that cannot be modified** — and round-trips an **Apple service** that validates the device data and returns an attestation.
5. App Attest returns the **attestation object** to the app.
6. App sends the attestation object to your server, which **validates it, saves it, and associates it with the user** (see `server-validation.md`).

```swift
func attestCurrentKey() async throws {
    let keyID = try await provisionKeyIDIfNeeded()

    // 1–3. Server controls initiation and vends the challenge.
    let challenge = try await Backend.beginAttestation(keyID: keyID)

    // 4–5. Produce the attestation object locally.
    let hash = clientDataHash(challenge: challenge)
    let attestation = try await AppAttest.attestKey(keyID, clientDataHash: hash)

    // 6. Server validates + stores; the app must not validate.
    try await Backend.completeAttestation(keyID: keyID, attestation: attestation)
}
```

**Attestation best practices:**

- **The server controls initiation.** Don't let the app decide to attest whenever it likes — server-gated initiation keeps you under a safe requests-per-second bound.
- **Exponential back-off, never hard-coded retries.** Attestation *can* fail; retry later with exponential back-off. Hard-coded retry logic produces uncontrollable spikes and hits global rate limits on Apple's attestation server.
- **Do it outside user flows,** on a **background task** — attestation round-trips an Apple service and shouldn't block anything the user is waiting on.
- **Validation is server-only.** A compromised app cannot be trusted to validate its own attestation.

## Step 3 — Secure payloads with assertions

Once the key is attested and its public key is stored server-side, the app uses that key to **sign specific payloads**. An assertion is a cheap, local proof that *this exact payload* came from your unmodified app.

Flow:
1. App prepares data to send to your server.
2. **Server vends a challenge** to include in the payload.
3. App fetches the key ID and calls the assertion API with **key ID + challenge** (folded into the client-data hash over the payload).
4. App Attest returns an **encoded assertion object**.
5. App **embeds the assertion in its payload** and transmits it.
6. **Server validates the assertion** and accepts or rejects the payload (see `server-validation.md`).

```swift
func sendSensitivePayload(_ body: Data) async throws {
    guard let keyID = try Keychain.appAttestKeyID() else { throw AppAttestError.missingKeyID }

    let challenge = try await Backend.assertionChallenge()          // 2. server-vended
    let hash = clientDataHash(challenge: challenge, payload: body)  // bind the assertion to THIS payload
    let assertion = try await AppAttest.generateAssertion(keyID, clientDataHash: hash)  // 3–4

    try await Backend.submit(payload: body, assertion: assertion, challenge: challenge)  // 5–6
}
```

**Assertion best practices:**

- **Generate on demand.** Assertions are produced **locally on the device and do not round-trip Apple servers** — create one at the point in the app's lifecycle where you actually need to sign a payload.
- **Mind the CPU cost.** Each assertion is a cryptographic operation. Don't rapidly generate assertions or produce more than you need within the app's lifecycle.
- **Bind to the payload + a fresh challenge** so the server can detect tampering in transit and reject replays. The server enforces a **strictly-increasing counter** — see `server-validation.md`.
