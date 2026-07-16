# Data Protection & Transport

Protect data **at rest** (files, encryption keys) and **in transit** (ATS). Lean on the platform's hardware-backed protection rather than custom schemes (Common Mistake #7).

## Data Protection classes (files at rest)

iOS can encrypt files with keys tied to the device passcode/unlock state. Set a protection class when writing sensitive files:

```swift
try data.write(to: url, options: [.completeFileProtection])
```

Or set the attribute:

```swift
try FileManager.default.setAttributes(
    [.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path
)
```

| Class | File readable |
|-------|---------------|
| `.complete` | Only while the device is unlocked |
| `.completeUnlessOpen` | Can keep an open handle across lock (e.g. a download finishing) |
| `.completeUntilFirstUserAuthentication` | After first unlock post-boot (default for many apps; good for background access) |
| `.none` | Always (no protection) — avoid for sensitive data |

Requires the **Data Protection** capability (entitlement). Use `.complete` for the most sensitive files; `.completeUntilFirstUserAuthentication` when a background task must read them while locked.

## CryptoKit — app-level encryption

When you need confidentiality beyond file protection (e.g. encrypting a payload before it leaves the app, or defense-in-depth), use **CryptoKit** — never hand-rolled crypto:

```swift
import CryptoKit

// Symmetric encryption (authenticated):
let key = SymmetricKey(size: .bits256)                     // store this in the Keychain (see keychain.md)
let sealed = try AES.GCM.seal(plaintext, using: key)
let ciphertext = sealed.combined!                          // nonce + ciphertext + tag
let decrypted = try AES.GCM.open(AES.GCM.SealedBox(combined: ciphertext), using: key)

// Hashing / integrity:
let digest = SHA256.hash(data: data)

// Key derivation from a shared secret / password material:
let derived = HKDF<SHA256>.deriveKey(inputKeyMaterial: .init(data: material), outputByteCount: 32)
```

Key rules:
- **Store the key in the Keychain** (or generate it in the Secure Enclave), never beside the ciphertext or in code.
- **Use authenticated encryption** (`AES.GCM` / `ChaChaPoly`) so tampering is detected.
- **Never reuse a nonce** with the same key — `AES.GCM.seal` generates a fresh one by default; don't override with a fixed value.

## Secure Enclave (hardware-bound keys)

For keys that must never be extractable, generate a P-256 key in the Secure Enclave — the private key never leaves the chip:

```swift
let key = try SecureEnclave.P256.Signing.PrivateKey()      // private key stays in hardware
let signature = try key.signature(for: data)               // sign/verify or key-agreement only
```

Use for signing/key-agreement and for gating with `SecAccessControl` (biometrics). Persist the key's `dataRepresentation` (an encrypted blob) in the Keychain; the material is useless off-device.

## App Transport Security (in transit)

ATS enforces HTTPS with modern TLS by default. Keep it on (Common Mistake #6):

- **Don't** set `NSAllowsArbitraryLoads = true` — it disables ATS app-wide and is an audit/App Review red flag.
- If a specific legacy host needs an exception, scope it narrowly under `NSExceptionDomains` for that host only, with justification, and plan to remove it.
- Prefer fixing the server (TLS 1.2+, forward secrecy) over adding an exception.

```xml
<!-- Only if unavoidable, and scoped to one host: -->
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSExceptionDomains</key>
  <dict>
    <key>legacy.example.com</key>
    <dict><key>NSExceptionMinimumTLSVersion</key><string>TLSv1.2</string></dict>
  </dict>
</dict>
```

Certificate/public-key **pinning** is an option for high-value APIs (via a `URLSessionDelegate` trust evaluation — see the `networking` skill), but only with a rotation strategy; a pinned cert that expires bricks the app.

## Keep secrets out of code & UserDefaults

- **No hardcoded API keys/secrets** in source — they're extractable from the binary. Fetch at runtime, or keep server-side; if a client key is unavoidable, treat it as public and scope it minimally.
- **`UserDefaults` is unencrypted** — never store tokens/PII there. Keychain for secrets, Data-Protected files or CryptoKit for larger sensitive data.
- **Scrub secrets from logs** — see the `observability` privacy guidance.

## Checklist

- [ ] Sensitive files written with a Data Protection class (`.complete`/`.completeUntilFirstUserAuthentication`).
- [ ] App-level encryption via CryptoKit (`AES.GCM`), keys in Keychain/Secure Enclave, fresh nonces.
- [ ] ATS on; no arbitrary loads; exceptions scoped per-host with justification.
- [ ] No secrets in source or `UserDefaults`; none in `.public` logs.
