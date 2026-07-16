---
name: release-cicd
description: >-
  Use when building, signing, and shipping an app — code signing & provisioning (certificates, profiles, App IDs, capabilities/entitlements, automatic vs manual, distribution), CI/CD with Xcode Cloud (workflows, `ci_scripts` hooks) or fastlane (`match`/`gym`/`pilot`/`deliver` lanes), distributing to TestFlight (groups, external review), submitting to the App Store (versioning & build numbers, metadata, phased release, App Review), and automating with the App Store Connect API key. This is the ship/deploy layer that complements the implement/test skills. Load whenever the task is "archive", "sign", "set up CI", "release", "upload to TestFlight", "submit to the App Store", "fix a signing error", or "bump the build number".
---

# Release & CI/CD

Writing the app is half the job; getting it signed, built reproducibly, and onto TestFlight and the App Store is the other half — and it's where teams lose the most time to signing errors and manual steps. This skill is the ship layer: signing that works, CI that builds and distributes automatically, and a clean path through TestFlight to App Review.

The core principle: **automate the pipeline (build → sign → distribute) and let a service manage signing** — Xcode Cloud or fastlane `match` — so releases are one command/commit, not a ritual. Version deliberately, submit with complete metadata, and use the App Store Connect API key for headless auth.

## Quick Reference

| Need | Use |
|------|-----|
| Managed signing (team) | fastlane **`match`** (shared certs/profiles in a repo) or Xcode automatic signing |
| Build an archive from CI | fastlane **`gym`** (`build_app`) or Xcode Cloud `xcodebuild archive` |
| Upload to TestFlight | fastlane **`pilot`** (`upload_to_testflight`) or Xcode Cloud TestFlight action |
| Push App Store metadata/binary | fastlane **`deliver`** (`upload_to_app_store`) |
| Headless auth to App Store Connect | **App Store Connect API key** (`.p8` + key id + issuer id) |
| CI native to Xcode | **Xcode Cloud** workflows + `ci_scripts/` hooks |
| Bump build number per CI run | `agvtool` / Xcode Cloud `$CI_BUILD_NUMBER` / fastlane `increment_build_number` |
| Staged rollout | App Store **phased release** |

## Core Workflow

1. **Get signing under control first** — one strategy (automatic for solo/simple; `match` for teams/CI). Certificates, an App ID with the right capabilities, and a distribution provisioning profile.
2. **Automate the build** in CI (Xcode Cloud or fastlane) producing a signed `.ipa`/archive from a clean checkout — no local state.
3. **Version each build** — a marketing version (`CFBundleShortVersionString`) you bump per release and a unique, monotonic build number (`CFBundleVersion`) per upload.
4. **Distribute to TestFlight** automatically on the relevant branch/tag; add testers (internal instantly; external after a lightweight review).
5. **Submit to the App Store** with complete metadata, screenshots, and privacy answers; choose manual or phased release.
6. **Authenticate headlessly** everywhere with an App Store Connect API key, not a personal Apple ID.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** Signing and submission failures are opaque and time-consuming; the details matter.

| Reference | Load When |
|-----------|-----------|
| **[Signing & Provisioning](references/signing-provisioning.md)** | Anything about certificates, provisioning profiles, App IDs, capabilities/entitlements, automatic vs manual signing, distribution methods, and decoding signing errors |
| **[Xcode Cloud](references/xcode-cloud.md)** | Setting up Apple's native CI — workflows, start conditions, environments, the `ci_scripts/` (`ci_post_clone`/`ci_pre_xcodebuild`/`ci_post_xcodebuild`) hooks, artifacts, and TestFlight/notarization steps |
| **[fastlane](references/fastlane.md)** | Scripting the pipeline — `Fastfile` lanes, `match` for signing, `gym` to build, `pilot`/`deliver` for TestFlight/App Store, `snapshot`, App Store Connect API key setup, and CI integration |
| **[TestFlight & App Store](references/testflight-appstore.md)** | Distribution and submission — versioning & build numbers, TestFlight internal/external groups & review, App Store Connect metadata, phased release, App Review prep, and the App Store Connect API |

## Common Mistakes

1. **Fighting signing by hand on every machine.** Manually juggling certificates/profiles across developers and CI is the #1 time sink. Pick one managed strategy — `match` (shared, encrypted signing assets in a repo) or Xcode automatic signing — and stop hand-editing profiles.

2. **Non-unique or non-increasing build numbers.** App Store Connect rejects an upload whose build number (`CFBundleVersion`) it has already seen, and TestFlight orders builds by it. Auto-increment per CI run (`$CI_BUILD_NUMBER`, `increment_build_number`, `agvtool`); never upload two builds with the same number.

3. **Confusing marketing version and build number.** `CFBundleShortVersionString` (e.g. `2.1.0`) is what users see and changes per release; `CFBundleVersion` is a build counter, unique per upload. Bumping the wrong one causes "already exists" errors or confusing store versions.

4. **Authenticating CI with a personal Apple ID.** 2FA breaks headless logins. Use an **App Store Connect API key** (`.p8` + key id + issuer id) for `gym`/`pilot`/`deliver`/Xcode Cloud — no password, no 2FA prompt.

5. **Capabilities in code but not in the App ID/entitlements.** Turning on Push, App Groups, iCloud, Sign in with Apple, etc. requires the capability on the **App ID** and matching **entitlements**, reflected in the provisioning profile. Mismatches fail signing or crash at runtime — keep the App ID, entitlements file, and profile in sync.

6. **Submitting with incomplete metadata / privacy answers.** Missing screenshots, an empty privacy nutrition label, or an undeclared required-reason API (see the `security` skill's privacy manifest) gets the build rejected before a human reviews it. Complete metadata and privacy declarations before submitting.

7. **No CI — releasing from a laptop.** Local releases aren't reproducible and encode one person's machine state. Build in CI from a clean checkout so any commit can ship and the process is documented in code.

8. **Skipping TestFlight.** Shipping straight to the App Store forgoes real-device validation. Distribute to TestFlight first (internal instantly, external for wider testing) and catch issues before review.
