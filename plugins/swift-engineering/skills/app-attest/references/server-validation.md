# Server-Side Validation

> These capabilities are part of the 2026 releases and newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

**Everything here runs on your server, in whatever language your backend uses** — a compromised app can't validate itself. Apple's Developer Documentation specifies the exact byte layouts, OIDs, and certificate roots; this file is the *checklist of what to verify* and *why*, not a drop-in parser. Field names below match the documented structures — confirm exact spellings against current Apple documentation.

Your server owns three durable pieces of per-user state:

- the **attested public key** (from a validated attestation),
- the **stored receipt** (needed for the fraud metric — see `fraud-metric.md`), and
- the **last assertion counter** (anti-replay).

## Validating the attestation

The app sends an **attestation object** (produced in `keys-attestation-assertions.md`, step 2). It has **three sections**: `format`, `attestation statement`, and `authenticator data`.

### 1. Format

A **fixed string** identifying the Apple anonymized attestation. Reject anything whose format identifier isn't the expected constant. *(The exact string value — e.g. an `apple-appattest`-style identifier — confirm against current Apple documentation.)*

### 2. Attestation statement — certificate chain + receipt

The statement embeds a **cryptographic certificate chain** and a **receipt**.

**Certificate chain** — proves the attested key was generated on **genuine Apple hardware**. Follow the Developer Documentation to validate it, checking the values embedded in the **leaf certificate**:

- the **nonce** (derived from your server challenge / client-data hash — confirms freshness and ties the cert to *this* attestation),
- the **key ID** (must match the key the app claims), and
- your **relying-party identifier** (Team ID + bundle ID — confirms it's *your* app; a mismatch means a re-signed copy, see `threat-model.md`).

**macOS 27+ — the ACL Blob OID (key access control property).** On macOS 27 and later, the leaf certificate also carries a **key access control property**, known as the **ACL Blob OID**. It represents the **security conditions the Secure Enclave enforced** on the key when the attestation was collected. It's available on all platforms but **especially important on macOS**, where App Attest configures each key with a policy requiring:

- **Full security mode** — the highest security level; verifies the integrity of the OS on the device.
- **System Integrity Protection (SIP)** — prevents execution of unauthorized code and protects system paths.

Both are enabled by default on Mac. **Validate the ACL Blob OID** to confirm those conditions actually held — e.g. an attacker who disabled SIP before tampering (see the macOS example in `threat-model.md`) will surface here as a disabled-SIP state.

**Receipt** — formatted **similar to an App Store receipt**; follow the Developer Documentation to parse it. From the receipt, validate the **relying-party ID**, the **attested key**, and your **server challenge**. Critically: **store this receipt** — it's what you later POST to the App Attest data server to read the **fraud metric** (see `fraud-metric.md`).

### 3. Authenticator data — app info + iOS 27 extensions

The `authenticator data` identifies information about your app and this attestation. Follow the Developer Documentation to unpack and validate its contents (it follows the WebAuthn authenticator-data layout — relying-party ID hash, a sign counter, the App Attest AAGUID, and the credential/key data; confirm field specifics against current Apple documentation).

**iOS 27+ — extensions.** On iOS 27 and later, a new **extensions** structure is appended to the end of the authenticator data, formatted per the **web authentication standard for the authenticator model**. It describes additional security properties collected on-device during attestation. Two extension identifiers were added:

- **Launch validation category** — tells you whether the app ran in an **unexpected environment** (e.g. a TestFlight category for an App Store build).
- **Bundle version** — confirms a version of your app **that you actually distributed** is what's running.

**Monitor these**, check for unexpected values, and **factor them into the user's risk assessment** — don't hard-block on them alone (see `best-practices.md`).

### Attestation validation checklist

```text
[ ] format equals the expected Apple anonymized-attestation identifier
[ ] certificate chain validates to Apple's App Attest root
[ ] leaf cert: nonce matches your challenge/client-data hash
[ ] leaf cert: key ID matches the claimed key
[ ] leaf cert: relying-party ID == your Team ID + bundle ID
[ ] (macOS 27+) ACL Blob OID reflects full security mode + SIP enforced
[ ] receipt: relying-party ID, attested key, and challenge all match
[ ] receipt STORED for this user (needed for the fraud metric)
[ ] authenticator data unpacked and validated
[ ] (iOS 27+) extensions: launch validation category + bundle version are expected
[ ] persist the attested public key; initialize the assertion counter for this user
```

On success: **save the attested public key**, **store the receipt**, and **associate both with the user**. On failure: don't hard-block — degrade + investigate (see `best-practices.md`).

## Validating the assertion

For ongoing payloads, the app embeds an **assertion object** (see `keys-attestation-assertions.md`, step 3). It has **two sections**: `signature` and `authenticator data`.

- **Signature.** Follow the Developer Documentation to validate the signature using the **authenticator data**, the **server challenge**, and the **public key from the stored attestation**. A valid signature proves the payload was signed by the attested key and **not tampered with in transit**.
- **Authenticator data.** Identifies information about your app at the time of assertion. On **iOS 27+**, it carries the same **extensions** structure as the attestation's authenticator data — handle it the same way (monitor launch validation category + bundle version).

### The counter — anti-replay

The authenticator data contains a **counter** that your server **must validate is strictly increasing** and **track per user**:

```text
assertion.counter  >  storedCounter[user]     // strictly greater — else reject as replay/compromise
→ if valid: storedCounter[user] = assertion.counter
```

Each time the app embeds an assertion, the counter should **increase**. A **steady or decreasing** counter indicates a **compromised copy** that isn't aware of the value your server has recorded — reject the payload and feed the event into the user's risk profile.

### Assertion validation checklist

```text
[ ] signature validates against stored public key + challenge + authenticator data
[ ] challenge matches the one your server just vended (fresh, unreused)
[ ] counter is STRICTLY greater than the stored counter for this user
[ ] update the stored counter on success
[ ] (iOS 27+) extensions still expected
[ ] accept or reject the payload based on the result
```

## Where this connects

- The **stored receipt** feeds the **fraud metric** → `fraud-metric.md`.
- Failed validations feed **risk assessment**, not an auto-block → `best-practices.md`.
- The **challenges** you vend here come from the server flows the client calls in → `keys-attestation-assertions.md`.
