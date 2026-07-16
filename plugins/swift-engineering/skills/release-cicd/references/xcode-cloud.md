# Xcode Cloud

Apple's native CI/CD, built into Xcode and App Store Connect. It builds, tests, and distributes from a clean cloud checkout, with **managed signing** (no cert/profile juggling) and first-class TestFlight/App Store delivery.

## Workflows

A **workflow** defines *when* CI runs and *what* it does. Configure in Xcode (Report navigator ▸ Xcode Cloud) or App Store Connect.

- **Start conditions** — branch changes, pull requests, tag creation, or a schedule. e.g. "on PR to `main` → build + test"; "on tag `v*` → build + archive + TestFlight".
- **Actions** — Build, Test (choose simulators/destinations), Analyze, Archive.
- **Post-actions** — distribute to **TestFlight** (internal/external groups), notarize a Mac app, or submit for App Store review.
- **Environment** — Xcode version, macOS image, and environment variables/secrets.

Because signing is **managed**, you don't upload certificates — Xcode Cloud handles distribution signing for the archive automatically (Common Mistake #1 in the skill is a non-issue here).

## `ci_scripts` hooks

Xcode Cloud runs shell hooks from a **`ci_scripts/`** directory at the repo root, at fixed points. Use them for setup the build needs (dependencies, generated code, config):

| Script | Runs |
|--------|------|
| `ci_scripts/ci_post_clone.sh` | After the repo is cloned (install tools, fetch deps, decrypt config) |
| `ci_scripts/ci_pre_xcodebuild.sh` | Just before the build/test action (inject build number, env config) |
| `ci_scripts/ci_post_xcodebuild.sh` | After the build/test action (process artifacts, notify) |

```bash
#!/bin/sh
# ci_scripts/ci_post_clone.sh — make the checkout buildable
set -e
brew install swiftlint || true
# resolve SPM deps (usually automatic, but explicit for tooling):
xcodebuild -resolvePackageDependencies -project MyApp.xcodeproj -scheme MyApp
```

Make scripts executable (`chmod +x`) and committed. This is also where a **SessionStart-style bootstrap** (see the plugin's session-start-hook skill for the local analog) belongs for CI.

## Useful environment variables

Xcode Cloud exposes CI context you should use rather than hardcode:

- `CI_BUILD_NUMBER` — a monotonic per-run number; feed it to `CFBundleVersion` so uploads are unique (Common Mistake #2 in the skill):
  ```bash
  # ci_scripts/ci_pre_xcodebuild.sh
  agvtool new-version -all "$CI_BUILD_NUMBER"
  ```
- `CI_BRANCH`, `CI_TAG`, `CI_PULL_REQUEST_NUMBER` — branch/tag/PR context for conditional logic.
- `CI_PRODUCT`, `CI_WORKSPACE` / `CI_PRIMARY_REPOSITORY_PATH` — paths for scripts.
- Custom secrets/env — defined per workflow in the Xcode Cloud settings (API keys, config tokens).

## Artifacts, tests, and results

- Test results, logs, and the built product are available in the Xcode Report navigator and App Store Connect after each run.
- Run your **Swift Testing**/XCUITest suites as the Test action across chosen destinations (see the `swift-testing` skill).
- A green archive can flow straight to TestFlight via the post-action — no manual upload.

## When to choose Xcode Cloud vs fastlane

- **Xcode Cloud** — least setup, managed signing, tight App Store Connect integration, no infra to run. Great default for Apple-only projects.
- **fastlane** — portable across CI providers (GitHub Actions, GitLab, self-hosted), scriptable, more control, handles complex multi-target/whitelabel pipelines. See the fastlane reference.
- They're not exclusive — some teams run fastlane *inside* Xcode Cloud scripts, or use Xcode Cloud for TestFlight and fastlane for chores.

## Pitfalls

- **Non-executable / uncommitted `ci_scripts`** → hooks silently don't run; `chmod +x` and commit them.
- **Assuming local tooling exists** → the cloud runner is clean; install everything in `ci_post_clone`.
- **Hardcoding the build number** → collisions; use `$CI_BUILD_NUMBER`.
- **Expecting arbitrary network/secrets** → declare env/secrets in the workflow; don't bake them into the repo.
