# TestFlight & App Store

The distribution end of the pipeline: version correctly, beta-test on TestFlight, then submit to the App Store with complete metadata. Automate auth with the App Store Connect API.

## Versioning: two numbers, two jobs

Get this right or uploads get rejected (Common Mistakes #2, #3):

- **`CFBundleShortVersionString`** — the **marketing version** users see (`2.1.0`). Bump per release (semantic-ish: feature/bugfix). Multiple builds can share it.
- **`CFBundleVersion`** — the **build number**, unique and increasing **per upload** to App Store Connect. TestFlight orders builds by it; a duplicate is rejected.

Rules:
- Every upload needs a **new, higher** build number → auto-increment in CI (`$CI_BUILD_NUMBER`, `increment_build_number`, `agvtool new-version -all`).
- A new **App Store version** needs a new marketing version; you can attach many builds to one version during testing, then submit one.

## TestFlight

- **Internal testers** (up to 100, members of your team) get builds **immediately** after processing — no review. Use for the dev/QA loop.
- **External testers** (up to 10,000, via public link or email groups) require a one-time **Beta App Review** per version (lighter than App Review). Use for wider beta.
- Builds expire after 90 days. Add **test information** (what to test, contact) for external groups or review is blocked.
- Distribute via fastlane `pilot`/`upload_to_testflight` or the Xcode Cloud TestFlight post-action; assign groups automatically.

Always run TestFlight before the store (Common Mistake #8) — it's the only way to validate the *actual signed build* on real devices at scale.

## App Store submission

Prepare in App Store Connect (or via `deliver`/API):

- **Binary** — the App Store build (same one you tested on TestFlight).
- **Metadata** — name, subtitle, description, keywords, support/marketing URLs, category, age rating.
- **Screenshots** — required sizes per device class; generate localized sets with fastlane `snapshot` (UI-test driven) to avoid manual capture.
- **Privacy** — the **App Privacy** "nutrition label" (data collected, linked to identity, used for tracking) and a complete `PrivacyInfo.xcprivacy` manifest with required-reason APIs (see the `security` skill). Incomplete privacy answers block submission (Common Mistake #6).
- **App Review notes** — a demo account, and notes explaining non-obvious features / how to reach gated functionality.

### Release options

- **Manual release** — you press "release" after approval.
- **Automatic** — releases as soon as approved.
- **Phased release** — roll out to a growing percentage of users over ~7 days (auto-pausable). Prefer for large user bases so a regression is caught before everyone gets it.

## App Store Connect API

Automate everything headlessly with an **App Store Connect API key** (Common Mistake #4):

1. App Store Connect ▸ **Users and Access ▸ Integrations ▸ App Store Connect API** → create a key with an appropriate role (e.g. App Manager / Developer).
2. Download the **`.p8`** once (you can't re-download it); note the **Key ID** and **Issuer ID**.
3. Feed them to fastlane (`app_store_connect_api_key`) or Xcode Cloud / your own scripts hitting the REST API. Store the `.p8` as a CI secret (base64), never in the repo.

The API (and fastlane over it) can create versions, upload builds, manage TestFlight testers/groups, set metadata, and submit for review — the whole release, scriptable.

## App Review: reducing rejections

- **Complete metadata & privacy** before submitting (see above).
- **No crashes / broken links** — reviewers exercise the app; a TestFlight-validated build helps.
- **Justify permissions** — every usage string honest and specific; don't request permissions you don't use (ties to the `security` skill).
- **Demo account + notes** for anything behind login or hardware.
- **Guideline basics** — no placeholder content, working core features, accurate description, correct age rating.

## Pitfalls

- **Reused/lower build number** → "this build already exists" / wrong ordering; always increment.
- **Wrong version field bumped** → confusing store version or upload errors; marketing vs build (above).
- **Manual screenshots** → drift and toil; automate with `snapshot`.
- **Incomplete privacy label / manifest** → rejection; complete before submitting.
- **Skipping phased release for big apps** → a bad build reaches everyone at once; roll out in phases.
