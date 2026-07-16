---
name: security
description: >-
  Use when handling anything sensitive on-device — storing credentials/tokens/keys in the Keychain (with the right accessibility and access-control flags), gating access behind Face ID/Touch ID with LocalAuthentication (`LAContext`), requesting and declaring privacy permissions (Info.plist usage strings, the `PrivacyInfo.xcprivacy` manifest, required-reason APIs, App Tracking Transparency), protecting data at rest (Data Protection file classes, CryptoKit encryption, the Secure Enclave), and enforcing secure transport (App Transport Security). Load whenever a feature saves a secret, authenticates a user biometrically, asks for a permission, encrypts data, or talks to a server — so secrets never land in UserDefaults/code and PII isn't mishandled. This is defensive, standard secure-iOS practice.
---

# Security (Keychain, Biometrics, Privacy, Data Protection)

Secrets belong in the Keychain, not `UserDefaults` or source; sensitive actions belong behind biometric or device-owner authentication; data on disk belongs under Data Protection; and every permission and data use must be declared. This skill is the secure-by-default baseline for handling anything an attacker (or an audit) would care about.

The core principle: **never store a secret in cleartext you control, never ship data access you haven't declared, and never trust the network without ATS.** Use the platform's hardened primitives (Keychain, Secure Enclave, Data Protection, LocalAuthentication) rather than rolling your own.

## Quick Reference

| Need | Use | Not |
|------|-----|-----|
| Store a token/password/key | Keychain (`SecItem…`) with `…ThisDeviceOnly` accessibility | `UserDefaults`, a plist, hardcoded |
| Gate an action on the user | `LAContext.evaluatePolicy` (Face/Touch ID) | a PIN you built |
| Bind a secret to biometrics | Keychain item + `SecAccessControl` (`.biometryCurrentSet`) | app-side checks only |
| Use a device capability | Info.plist usage string + request at point of use | accessing without declaring |
| Declare data collection | `PrivacyInfo.xcprivacy` manifest + required-reason APIs | shipping without it |
| Track across apps | `ATTrackingManager` request first | tracking silently |
| Protect files at rest | Data Protection class (`.complete…`) | plaintext files |
| Encrypt app data | CryptoKit (`AES.GCM`) + key in Keychain/Secure Enclave | custom crypto |
| Talk to a server | HTTPS under ATS (no arbitrary loads) | disabling ATS |

## Core Workflow

1. **Classify the data.** Is it a secret (token/key/password), PII, or ordinary? Secrets → Keychain; sensitive files → Data Protection + maybe CryptoKit; nothing sensitive in `UserDefaults`/code.
2. **Store secrets in the Keychain** with the tightest accessibility (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`) and, where warranted, a `SecAccessControl` requiring biometrics/presence.
3. **Gate sensitive actions** with `LocalAuthentication`, falling back to device passcode where appropriate; handle every failure/cancel path.
4. **Declare before you access** — add the Info.plist usage string for each capability, request at the moment of use, and maintain the `PrivacyInfo.xcprivacy` manifest (required-reason APIs, tracking domains, collected data).
5. **Protect data at rest** — set a Data Protection class on sensitive files; encrypt with CryptoKit when you need app-level confidentiality, keeping keys in the Keychain/Secure Enclave.
6. **Enforce secure transport** — keep ATS on; no arbitrary loads; pin only with a maintained strategy.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** Security bugs don't fail the build — they fail an audit or leak user data.

| Reference | Load When |
|-----------|-----------|
| **[Keychain](references/keychain.md)** | Storing/reading secrets — `SecItemAdd`/`Copy`/`Update`/`Delete`, item classes & attributes, accessibility levels, `SecAccessControl` for biometric/presence binding, a `Sendable` wrapper, error handling, sharing via access groups |
| **[Local Authentication](references/local-authentication.md)** | Face ID / Touch ID / passcode — `LAContext`, `canEvaluatePolicy`, `evaluatePolicy`, `biometryType`, `LAError` handling, reuse duration, and combining LA with Keychain access control |
| **[Privacy & Permissions](references/privacy-permissions.md)** | Requesting capabilities and declaring data use — Info.plist usage strings, per-framework request flows, `PrivacyInfo.xcprivacy` (required-reason APIs, tracking domains, collected-data types), App Tracking Transparency |
| **[Data Protection & Transport](references/data-protection.md)** | Data at rest and in transit — Data Protection file classes, CryptoKit (`AES.GCM`, hashing, key management, Secure Enclave), App Transport Security, and keeping secrets out of code/`UserDefaults` |

## Common Mistakes

1. **Secrets in `UserDefaults`, a plist, or source.** `UserDefaults` is an unencrypted plist; hardcoded keys ship in the binary for anyone to extract. Tokens, passwords, and keys go in the **Keychain**, always.

2. **Wrong Keychain accessibility.** The default syncs/persists more than you want. For most secrets use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — available only when unlocked, never leaves the device, not in backups. Reserve broader classes for a real need.

3. **Biometric check enforced only in app code.** A `LAContext.evaluatePolicy` that merely returns a `Bool` your code checks can be bypassed on a compromised device. For real protection, bind the *secret itself* to biometrics via `SecAccessControl` so the Keychain won't release it without authentication.

4. **Accessing a capability without a usage string.** Camera/mic/location/photos/contacts without the matching `NS…UsageDescription` **crashes** on first access. Add the (honest, specific) string, and request at the point of use with context.

5. **Missing/incorrect privacy manifest.** Shipping without a `PrivacyInfo.xcprivacy` (or using a required-reason API without declaring its reason) causes App Store rejection. Declare collected data types, tracking, and required-reason API usage.

6. **Disabling ATS.** `NSAllowsArbitraryLoads = true` turns off transport security app-wide — a red flag and an audit failure. Keep ATS on; scope narrow exceptions to specific domains only with justification.

7. **Rolling your own crypto.** Custom encryption, home-grown key derivation, or storing an AES key next to the ciphertext defeats the purpose. Use **CryptoKit** (`AES.GCM`, `HKDF`, `SHA256`) and keep keys in the Keychain or Secure Enclave.

8. **Logging secrets.** Tokens/PII in logs leak via sysdiagnose. Never `.public`-log them — see the `observability` skill's privacy guidance.
