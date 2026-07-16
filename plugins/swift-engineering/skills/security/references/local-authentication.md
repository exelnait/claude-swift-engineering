# Local Authentication (Face ID / Touch ID)

`LocalAuthentication` prompts the user to prove they're the device owner via biometrics or passcode. Use it to gate sensitive actions — and, for real security, combine it with Keychain access control so the *data* is protected, not just a UI check (Common Mistake #3).

## Evaluate a policy

```swift
import LocalAuthentication

func authenticate(reason: String) async throws {
    let context = LAContext()
    context.localizedFallbackTitle = "Enter Passcode"     // shown if biometrics fail

    var error: NSError?
    // .deviceOwnerAuthenticationWithBiometrics = bio only; .deviceOwnerAuthentication = bio OR passcode fallback
    guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
        throw error ?? LAError(.biometryNotAvailable)
    }

    try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
    // Reaching here means success. Throws on failure/cancel.
}
```

- **`.deviceOwnerAuthentication`** — biometrics with automatic passcode fallback (recommended for most gates; still works if Face/Touch ID is unavailable or locked out).
- **`.deviceOwnerAuthenticationWithBiometrics`** — biometrics only, no passcode fallback (use when you specifically require biometrics).
- `evaluatePolicy` is available as `async` and throws on any non-success outcome (cancel, fail, fallback, lockout).
- `localizedReason` is shown to the user and must explain *why* — required for Face ID.

## Know the biometry type (for correct copy/UI)

```swift
let context = LAContext()
_ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)  // must call before reading type
switch context.biometryType {
case .faceID:  label = "Unlock with Face ID"
case .touchID: label = "Unlock with Touch ID"
case .opticID: label = "Unlock with Optic ID"
case .none:    label = "Unlock"
@unknown default: label = "Unlock"
}
```

Requires **`NSFaceIDUsageDescription`** in Info.plist for Face ID (see `privacy-permissions.md`) — omitting it crashes on the first Face ID attempt.

## Handle every failure path

`evaluatePolicy` throws an `LAError`; branch on the code — several are normal, not bugs:

```swift
do {
    try await authenticate(reason: "Unlock your vault")
} catch let error as LAError {
    switch error.code {
    case .userCancel, .appCancel, .systemCancel: break        // user backed out — not an error to surface
    case .userFallback:                                        // user chose the fallback (e.g. passcode path)
        try await fallbackToPasscodeOrLogin()
    case .biometryNotEnrolled, .biometryNotAvailable:
        try await fallbackToPasscodeOrLogin()
    case .biometryLockout:                                     // too many failures — passcode required
        try await requirePasscode()
    default:
        throw error
    }
}
```

## Reuse a recent authentication

To avoid re-prompting for a burst of protected actions, set a reuse window:

```swift
let context = LAContext()
context.touchIDAuthenticationAllowableReuseDuration = 30   // seconds; a recent unlock counts
```

Pass this same `context` into a Keychain query via `kSecUseAuthenticationContext` so a Keychain read within the window doesn't re-prompt.

## Combining with the Keychain (the secure pattern)

A `Bool` from `evaluatePolicy` is bypassable on a jailbroken device. The robust pattern is to store the secret with a `SecAccessControl` requiring `.biometryCurrentSet`/`.userPresence` (see `keychain.md`) so **the Keychain itself demands authentication** to release the value. Then:

1. Store the token/key behind biometric access control at first login.
2. To use it, just read it — the system shows the biometric prompt and only returns the secret on success.
3. Use `LAContext` reuse + `kSecUseAuthenticationContext` to control prompt frequency.

This way a defeated UI check gains nothing — without a successful biometric/passcode auth, the secret never leaves the Keychain.

## Pitfalls

- **Missing `NSFaceIDUsageDescription`** → crash on first Face ID.
- **Treating cancel as failure** → confusing UX; `userCancel`/`appCancel` are normal.
- **Biometrics-only with no fallback** → users locked out when biometrics fail/unavailable; prefer `.deviceOwnerAuthentication`.
- **UI-only gating** → bypassable; bind the secret in the Keychain.
- **Reading `biometryType` before `canEvaluatePolicy`** → returns `.none`; evaluate first.
