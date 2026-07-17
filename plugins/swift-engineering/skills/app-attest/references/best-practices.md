# Best Practices & Adoption

> These capabilities are part of the 2026 releases and newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

App Attest gives you strong signals, but the failure mode that hurts most is **over-reacting to them**. Legitimate users trigger many of the same conditions as fraudsters, so the guidance below is about handling suspicious activity **without punishing real users**.

## Handling suspicious activity

**Handle new keys for an existing user cautiously.** Seeing a brand-new attested key where you expected an existing one is *not* proof of fraud — **app reinstall, device restore, and iCloud restore all rotate keys** (see `keys-attestation-assertions.md`). So:

- **Don't reject new keys outright.** Accept and validate them; a new key is an expected part of normal device lifecycle.
- **Don't immediately invalidate a user's previous keys.** Keep the prior attestations around. Your server's **per-user map of attestations**, coupled with the **fraud metric** (`fraud-metric.md`), becomes a fraud/abuse signal over time — but only if you don't destroy the history the moment a key rotates.

**When your server does reject an attestation or assertion, degrade — don't slam the door.** The app should handle rejection gracefully:

- **Degrade the functionality tied to App Attest** for that user, rather than crashing or hard-failing.
- **Allow limited access with heightened monitoring** so you can gather more signal.
- **Avoid blocking the user directly** without a comprehensive risk assessment.

## Run a real risk assessment

What counts as "fraud" and what you do about it **depends on your business**, the kind of app you ship, and the impact of abuse in your context. There's no universal threshold.

- If App Attest signals lead you to **suspect fraud**, follow **your business's guidelines** for user deactivation or suspension — as a defined process, not an ad-hoc reflex.
- **Blocking users without proper evaluation erodes trust and can harm legitimate users.** Always run a **well-defined risk-assessment process** before taking action.
- **Combine signals.** No single input — `isSupported` spikes, an unexpected launch validation category or bundle version, a decreasing assertion counter, a high fraud metric — should decide a user's fate alone. Weigh them together, watch baselines, and act on **spikes and patterns**.

### Signals to weigh (all inputs, none a verdict)

| Signal | Source | Meaning |
|--------|--------|---------|
| `isSupported` unavailable / spiking | client gate | Unsupported platform/extension, or possible tampering | 
| Relying-party / Team ID mismatch | attestation leaf cert | Re-signed copy |
| Launch validation category unexpected | authenticator data extensions (iOS 27+) | App running in an unexpected environment |
| Bundle version unexpected | authenticator data extensions (iOS 27+) | Version you didn't distribute |
| ACL Blob OID missing full security / SIP | attestation leaf cert (macOS 27+) | Weakened device security posture |
| Counter not strictly increasing | assertion | Replay / compromised copy |
| Fraud metric spike vs. baseline | App Attest data server | Possible broker device |
| Frequent new-key rotation | your per-user attestation map | Often legitimate (reinstall/restore) — corroborate |

Treat every row as **investigation fuel**, then apply your risk process.

## Adoption checklist

To bring App Attest into an app end-to-end:

- [ ] **Rebuild against the latest SDKs** so you get the newest App Attest API (macOS 27 support, iOS 27 launch validation category + bundle version extensions).
- [ ] **Identify the flows that benefit** from attestation and assertions — e.g. **authentication flows**, and **sensitive payloads for premium content** you can strengthen with assertions.
- [ ] **Gate every call site with `isSupported`** and decide the unavailable-path behavior (`threat-model.md`).
- [ ] **Generate keys correctly** — one per user (account apps) or one per app; store the key ID in the Keychain; expect rotation on reinstall/restore (`keys-attestation-assertions.md`).
- [ ] **Server controls attestation initiation**; the client uses **exponential back-off** and runs attestation on a **background task**, outside user flows.
- [ ] **Set up server-side validation** of attestations and assertions (`server-validation.md`).
- [ ] **Store receipts** per user (required for the fraud metric).
- [ ] **Track the assertion counter** per user and enforce strict increase (anti-replay).
- [ ] **Incorporate the fraud metric** into your risk-assessment pipeline, with receipt refresh (`fraud-metric.md`).
- [ ] **Design graceful degradation + monitoring** for rejections, and a **documented risk-assessment process** before any user action.

## Where this connects

- Availability gating and the signals catalog → `threat-model.md`
- Key rotation you must tolerate → `keys-attestation-assertions.md`
- What "reject" actually checks → `server-validation.md`
- The metric you fold into risk → `fraud-metric.md`
