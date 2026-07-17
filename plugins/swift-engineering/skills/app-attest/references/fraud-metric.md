# The Fraud Metric

> These capabilities are part of the 2026 releases and newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

## What it detects

Even a fully attested key can come from a **compromised device acting as a broker**: such a device passes attestations legitimately, then **generates valid attestations on behalf of modified app instances running on *other* devices**. Those modified apps then send compromised requests to your server, each backed by a technically-valid attestation. Per-attestation validation (see `server-validation.md`) won't catch this on its own — the attestations *are* valid.

The **fraud metric** surfaces the broker pattern. It provides an **approximate count of unique attested keys associated with your app on a particular device over the past 30 days**. A device minting an unusually large number of distinct attested keys is a candidate broker. Use it to judge whether a user is **associated with attestations from a potentially-compromised device**.

## How you read it — server ↔ App Attest data server

The metric lives with Apple, keyed by an attestation **receipt** (the one your server stored during attestation validation). The exchange is **server-to-server** — your backend talks to the **App Attest data server**; the app is not involved.

1. Your server **retrieves the stored receipt** from an attestation associated with a user.
2. Your server sends a **POST request to the App Attest data server**, using that receipt.
3. The data server **returns a receipt** to your server containing the **fraud metric**. **Use this returned receipt for subsequent fetches** (it supersedes the previous one).

```text
your server ──POST(stored receipt)──▶ App Attest data server
your server ◀──receipt { … , riskMetric }── App Attest data server
            (persist the returned receipt; use it for the next fetch)
```

*(The exact endpoint URL, HTTP details, and authentication — confirm against current Apple documentation before implementing.)*

## The receipt structure

The receipt is structured **similar to an App Store receipt**, with **three sections**:

- **Signature** — signs the receipt payload.
- **Certificate chain** — roots to the **Apple certifying authority**.
- **Receipt payload** — contains information about the **attested key** associated with the metric, plus the **metric itself**.

Follow the Developer Documentation to verify each part of the payload. The field of interest:

- **`riskMetric`** — the field that defines the **fraud metric count** (the approximate unique-attested-keys-per-device value). *Confirm the exact field name against current Apple documentation.*

## Refreshing the receipt

The receipt is **time-bounded and must be refreshed** to keep reading a current metric:

- **Not-before (`notBefore`)** — the **earliest point at which you may refresh** the receipt. Don't POST before this time.
- **Expiration time (`expirationTime`)** — when the receipt **expires and can no longer be refreshed**. Refresh before this, and persist each newly returned receipt.

```text
notBefore ──────────────── (refresh window) ──────────────── expirationTime
   │ can't refresh yet │        refresh here        │ too late; receipt dead │
```

*(Exact field names — confirm against current Apple documentation.)*

## How to use it — a signal, not a switch

- **It's an investigation signal.** **Monitor** the metric, **analyze it for a baseline**, and **identify spikes** as indicators of suspicious activity. Fold it into the user's **risk-assessment profile** (see `best-practices.md`).
- **Don't block outright on it.** Do **not** use the fraud metric to block users from your app by itself.
- **Expect legitimate contributions.** **Any user step that rotates an App Attest key contributes to the metric** — notably **reinstalling the app** or **restoring the device**, which force new key generation and re-attestation. A normal user who reinstalls a few times will nudge the count; that alone isn't fraud. This is exactly why the metric is a baseline-and-spike signal, not a threshold you hard-block on.

## Where this connects

- The **receipt** you POST here is the one stored during **attestation validation** → `server-validation.md`.
- Key rotation that inflates the metric is the same rotation you must tolerate in **new-key handling** → `best-practices.md`.
