# fastlane

fastlane scripts the whole release pipeline in a `Fastfile` of **lanes**, runs on any CI (GitHub Actions, GitLab, self-hosted), and solves team signing with `match`. Reach for it when you need portability or control beyond Xcode Cloud.

## Anatomy: lanes

```ruby
# fastlane/Fastfile
default_platform(:ios)

platform :ios do
  desc "Build and upload a TestFlight beta"
  lane :beta do
    setup_ci                                   # temp keychain on CI
    match(type: "appstore", readonly: is_ci)   # fetch shared signing assets
    increment_build_number(build_number: ENV["CI_BUILD_NUMBER"] || latest_testflight_build_number + 1)
    build_app(scheme: "MyApp")                 # gym: archive + export signed .ipa
    upload_to_testflight(                       # pilot
      groups: ["Internal"],
      distribute_external: false,
      skip_waiting_for_build_processing: true
    )
  end

  desc "Ship to the App Store"
  lane :release do
    match(type: "appstore", readonly: true)
    build_app(scheme: "MyApp")
    upload_to_app_store(                         # deliver
      submit_for_review: true,
      automatic_release: false,                  # or phased_release: true
      force: true,                               # skip HTML preview
      precheck_include_in_app_purchases: false
    )
  end
end
```

Run: `fastlane beta` / `fastlane release` (locally or in CI).

## The key actions

| Action (alias) | Does |
|----------------|------|
| **`match`** | Sync the team's distribution certificate + provisioning profiles from an encrypted repo/storage — every machine gets identical signing (solves Common Mistake #1) |
| **`build_app`** (`gym`) | Archive and export a signed `.ipa` for the given scheme/export method |
| **`upload_to_testflight`** (`pilot`) | Upload the build to TestFlight; manage testers/groups |
| **`upload_to_app_store`** (`deliver`) | Upload binary + metadata + screenshots; optionally submit for review |
| **`increment_build_number`** | Bump `CFBundleVersion` (feed CI's build number) |
| **`increment_version_number`** | Bump `CFBundleShortVersionString` (marketing version) |
| **`capture_screenshots`** (`snapshot`) | Generate localized App Store screenshots via UI tests |
| **`run_tests`** (`scan`) | Run the test suite |

## `match` — shared signing

`match` is the reason teams adopt fastlane. It generates the distribution certificate and profiles once, encrypts them, and stores them in a private git repo (or S3/Google Cloud). Every developer and CI runner does `match(type: "appstore")` to fetch the *same* assets — no more per-machine certificate chaos.

```ruby
# Matchfile
git_url("git@github.com:example/certificates.git")
storage_mode("git")
type("appstore")
```

- First-time setup: `fastlane match appstore` (creates/stores assets). Rotate with `fastlane match nuke distribution` then regenerate.
- On CI use `readonly: true` so runners fetch but never mutate signing assets.

## App Store Connect API key (headless auth)

Never authenticate CI with an Apple ID + 2FA (Common Mistake #4). Create an **App Store Connect API key** (App Store Connect ▸ Users and Access ▸ Integrations) → a `.p8` file + Key ID + Issuer ID, and load it:

```ruby
lane :beta do
  api_key = app_store_connect_api_key(
    key_id: ENV["ASC_KEY_ID"],
    issuer_id: ENV["ASC_ISSUER_ID"],
    key_content: ENV["ASC_KEY_P8"],   # the .p8 contents, from a CI secret
    is_key_content_base64: true
  )
  build_app(scheme: "MyApp")
  upload_to_testflight(api_key: api_key)
end
```

Store `ASC_KEY_P8` (base64 of the `.p8`), `ASC_KEY_ID`, `ASC_ISSUER_ID`, and the match repo deploy key as **CI secrets**, never in the repo.

## CI integration (GitHub Actions example)

```yaml
# .github/workflows/beta.yml
jobs:
  beta:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with: { bundler-cache: true }
      - run: bundle exec fastlane beta
        env:
          CI_BUILD_NUMBER: ${{ github.run_number }}
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          ASC_KEY_ID: ${{ secrets.ASC_KEY_ID }}
          ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
          ASC_KEY_P8: ${{ secrets.ASC_KEY_P8 }}
```

Use a `Gemfile` (with `fastlane`) + `bundle exec` so the fastlane version is pinned and reproducible.

## Pitfalls

- **`match` in read/write on CI** → runners mutating/ revoking shared certs; use `readonly: true`.
- **Apple ID auth in CI** → 2FA breaks; use the API key.
- **Unpinned fastlane** → drift/breakage; pin via `Gemfile` + `bundle exec`.
- **Secrets in the repo** → leak; use CI secrets and base64 the `.p8`.
- **Reinventing what an action does** → prefer the built-in actions (`gym`/`pilot`/`deliver`) over raw `xcodebuild` where they fit.
