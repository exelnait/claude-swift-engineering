# Keychain

The Keychain is the OS-backed secure store for small secrets — tokens, passwords, keys. It encrypts at rest, ties availability to device-unlock state, and can bind items to biometrics. Anything secret goes here, never `UserDefaults`/plist/source (Common Mistake #1).

## The SecItem API

Four C functions over a `[String: Any]` query dictionary: `SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`, `SecItemDelete`. Wrap them once.

```swift
import Security
import Foundation

struct KeychainStore: Sendable {
    let service: String                      // e.g. "com.example.trips.auth"

    func set(_ data: Data, account: String) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        // Upsert: delete any existing, then add.
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status) }
    }

    func data(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:      return result as? Data
        case errSecItemNotFound: return nil
        default:                 throw KeychainError(status)
        }
    }

    func remove(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status) }
    }
}

struct KeychainError: Error { let status: OSStatus; init(_ s: OSStatus) { status = s } }
```

Store `Codable` tokens by encoding to `Data` first. Keep the wrapper `Sendable` so it's safe to share across concurrency domains.

## Accessibility — when the item is readable

Set `kSecAttrAccessible` to the tightest class that works (Common Mistake #2):

| Value | Available | Notes |
|-------|-----------|-------|
| `…WhenUnlockedThisDeviceOnly` | While device unlocked | **Default choice** for app secrets; never leaves device, not in backups |
| `…AfterFirstUnlockThisDeviceOnly` | After first unlock post-boot | For background access (e.g. a refresh token used by a bg task) |
| `…WhenUnlocked` | While unlocked | Migrates to new devices via encrypted backup — usually *not* what you want for secrets |
| `…WhenPasscodeSetThisDeviceOnly` | Only if a passcode is set; unlocked | Strongest baseline; item is deleted if the passcode is removed |

Prefer the `…ThisDeviceOnly` variants for secrets so they don't sync or restore to another device.

## Binding to biometrics / presence — SecAccessControl

For real protection, make the Keychain refuse to release the item without authentication, rather than checking a `Bool` in app code (Common Mistake #3):

```swift
var error: Unmanaged<CFError>?
guard let access = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
    .biometryCurrentSet,          // invalidated if the enrolled biometrics change; .userPresence = bio or passcode
    &error
) else { throw error!.takeRetainedValue() as Error }

let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,
    kSecAttrAccount as String: account,
    kSecValueData as String: secret,
    kSecAttrAccessControl as String: access,        // replaces kSecAttrAccessible
    // Optionally supply an LAContext to reuse a recent auth:
    // kSecUseAuthenticationContext as String: laContext,
]
SecItemAdd(query as CFDictionary, nil)
```

Now a `SecItemCopyMatching` triggers a Face ID/Touch ID prompt automatically; the secret is released only on success. Flags: `.biometryCurrentSet` (bio only, invalidated on enrollment change — best for high-value secrets), `.biometryAny`, `.userPresence` (bio or passcode), `.devicePasscode`. See `local-authentication.md` for the interactive side.

## Sharing between app & extensions

To share Keychain items with your widget/extension, add a **Keychain access group** (`kSecAttrAccessGroup`) and the Keychain Sharing capability with a shared group id. Pair with an App Group for non-secret data (see the `app-intents-widgets` skill).

## Pitfalls

- **`errSecDuplicateItem` on add** → an item already exists; delete-then-add (upsert) or use `SecItemUpdate`.
- **Storing large blobs** → Keychain is for small secrets; encrypt large data with CryptoKit and store the *key* here (see `data-protection.md`).
- **Broad accessibility** → secrets syncing/restoring to other devices; use `…ThisDeviceOnly`.
- **App-side biometric gating only** → bypassable; bind the item with `SecAccessControl`.
- **Ignoring `OSStatus`** → silent failures; map statuses to errors and handle `errSecItemNotFound` as "no value," not a crash.
