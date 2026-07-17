---
name: app-attest
description: Use when you need to prove an app is genuine and unmodified to your backend — app integrity, attestation, DeviceCheck/App Attest, anti-fraud/anti-abuse, verifying an app runs on genuine Apple hardware, detecting re-signed or cheat-injected copies, securing app→server payloads with assertions, or reading the App Attest fraud metric. Covers the CLIENT (key generation, attestation, assertions) and the SERVER (validation, receipt storage, counter tracking, fraud metric). Validation ALWAYS happens server-side.
---

# App Attest: Prove App Integrity to Your Server

> These capabilities are part of the 2026 releases and newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

## Overview

You shipped your app to run in a secure environment on Apple's platforms. Fraudsters try to run **modified copies** — reverse-engineered, re-signed, or with an injected cheat menu — that send valid-looking requests to your server (falsified quiz answers, fraudulent game scores, forged premium-content requests). **App Attest** gives your server cryptographic proof, backed by the Secure Enclave, that a request came from an unmodified copy of *your* app running on *genuine Apple hardware*.

This is a **client + server** skill, and there is one non-negotiable rule:

> **Validation ALWAYS happens on your server, never in the app.** A compromised app cannot be trusted to validate its own integrity. The app only *generates* attestations and assertions; your server *verifies* them.

App Attest has two primitives:

- **Attestation** — a one-time proof that a Secure Enclave key belongs to your app on a genuine device. Your server validates it once and stores the attested public key + receipt for that user.
- **Assertion** — an ongoing, cheap-to-verify signature over a specific request payload, produced with the already-attested key. Your server validates it per request to ensure the payload was not tampered with in transit.

App Attest is **distinct from the `security` skill** (Keychain, biometrics, Data Protection, ATS). That skill protects secrets *on the device*; App Attest proves *app + hardware integrity to a remote server*. They compose: you store the App Attest **key ID** in the Keychain (a `security`-skill concern), then use it for attestation/assertion here.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** App Attest is a fraud-defense system — a subtle gap (validating in the app, skipping the counter check, hard-blocking on a signal) quietly defeats the whole thing.

| Reference | Load When |
|-----------|-----------|
| **[Threat Model & Availability](references/threat-model.md)** | Understanding *what App Attest protects against* (modified/re-signed copies, falsified requests, injected cheat menus) and *what it proves* (genuine Apple hardware; relying-party identity = Team ID + bundle ID; launch validation category [iOS 27]; bundle version); gating with `isSupported` (all platforms incl. macOS 27+; Action/SSO extensions but not all extension types) and using unsupported spikes as a fraud signal |
| **[Keys, Attestation & Assertions](references/keys-attestation-assertions.md)** | The client flow — generating a key ID (Secure Enclave), storing it in the Keychain, key lifecycle; attesting the key against a server challenge; generating assertions to secure payloads; and client best practices (server-controlled initiation, exponential back-off, background tasks, on-demand assertions) |
| **[Server-Side Validation](references/server-validation.md)** | Validating on your server — attestation structure (format, statement with cert chain + receipt + macOS ACL Blob OID, authenticator data with iOS 27 extensions), what to check in each part, and assertion structure (signature + authenticator data) including the strictly-increasing counter for anti-replay |
| **[The Fraud Metric](references/fraud-metric.md)** | Reading the fraud metric — approximate count of unique attested keys per device over the last 30 days, the server↔App Attest data server POST with the stored receipt, the risk-metric field, and the receipt refresh window (not-before / expiration) |
| **[Best Practices & Adoption](references/best-practices.md)** | Handling suspicious activity without hurting legitimate users (don't reject/invalidate keys outright, degrade + monitor instead of hard-blocking, run a real risk assessment) and the end-to-end adoption checklist |

## Core Workflow

1. **Check availability.** Gate every use with `isSupported`; decide what happens when App Attest is unavailable, and treat spikes of "unsupported" for a supported user as a fraud signal. → `threat-model.md`
2. **Generate a key ID** on the client. App Attest creates a Secure Enclave-bound key pair (private key never leaves the enclave) and returns a key ID; store it in the **Keychain**. One key per user (account apps) or one per app — never shared across your user base. → `keys-attestation-assertions.md`
3. **Attest the key.** Your **server** vends a challenge → the app attests the key with that challenge → the app sends the attestation object to your server. Your **server validates it, stores the receipt, and associates the attested key with the user.** → `server-validation.md`
4. **Secure ongoing payloads with assertions.** Your server vends a challenge → the app generates an assertion over the payload → your server validates the signature and enforces a **strictly-increasing counter** (anti-replay). → `keys-attestation-assertions.md`, `server-validation.md`
5. **Feed the fraud metric into risk assessment.** Periodically query the App Attest data server with a stored receipt; monitor the metric for a baseline and spikes — as a signal, not an auto-block. → `fraud-metric.md`
6. **Handle rejections gracefully.** On a failed attestation/assertion, degrade App Attest-tied functionality and heighten monitoring; run a real risk assessment before any user action. → `best-practices.md`

## Common Mistakes

1. **Validating in the app instead of on the server.** The whole model assumes the app may be compromised — so it cannot be the validator. Attestations and assertions are *always* validated server-side; the app only produces them.

2. **Letting the app freely initiate attestations, or hard-coding retries.** Your **server** should control when an attestation begins (to stay under a safe requests-per-second bound), and the app must use **exponential back-off** on failure. Hard-coded retry loops create uncontrollable spikes against Apple's attestation server and hit global rate limits.

3. **Sharing one key across users, or generating keys per request.** Generate **one key per user** (account-based apps) or **one key for the app** on the device — never share keys across your user population, and don't spam key generation. Store the key ID in the Keychain.

4. **Reacting to legitimate key rotation as fraud.** App reinstall, device restore, and iCloud restore *invalidate* keys and force re-attestation. Don't reject new keys outright and don't immediately invalidate a user's previous keys — build a per-user map of attestations and treat rotation as one input, not a verdict.

5. **Skipping or mis-tracking the assertion counter.** The counter in each assertion must be **strictly increasing** per key; track it per user server-side. A steady or decreasing counter indicates a replayed/compromised copy. Forgetting this removes anti-replay protection entirely.

6. **Hard-blocking on a single signal.** `isSupported == false`, an unexpected launch validation category, or a high fraud metric are **investigation signals**, not block buttons. Degrade functionality, monitor, and run your business's risk-assessment process — blocking without evaluation erodes trust and hurts legitimate users.

7. **Not storing the receipt.** The attestation receipt is required later to query the **fraud metric** (and must itself be refreshed within its not-before/expiration window). If you don't persist it per user, you lose access to the metric.

8. **Generating assertions too aggressively.** Assertions are local cryptographic operations with real CPU cost — generate them **on demand** for the specific payloads that need them, not in tight loops. Do attestation work on a **background task**, outside user-facing flows.

9. **Assuming platform/extension support.** macOS 27+ is newly supported; some app-extension types are not (Action and SSO extensions are, others are not). Never assume — gate every call site with `isSupported`.
