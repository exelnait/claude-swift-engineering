# Project Structure for Multiplatform

How you lay out targets and files decides whether "the Mac build always works" is effortless or a constant fight. The aim: shared code is the default home for everything, platform-specific code is small, obviously located, and compiled only where it applies.

## Target strategy: two viable shapes

### A. Single multiplatform app target (Xcode 14+) — the default

One app target declares multiple **destinations** (iPhone, iPad, Mac). Most files belong to the target and compile for every destination; platform differences are handled in-code (rungs 1–4) or by per-file target membership.

- **Choose this when** the app shares the large majority of its code and settings across platforms — the common case, and what Apple's *Configuring a multiplatform app* guidance recommends.
- Platform-specific *behavior* lives in `#if`-gated code or platform-suffixed files; platform-specific *build settings* (entitlements, capabilities, deployment target) are set per-destination.

### B. Shared Swift package + thin platform app targets

A `Shared`/`AppCore` Swift package holds all reusable logic and cross-platform UI; separate small app targets (iOS app, macOS app) depend on it and contain only platform-specific glue and resources.

- **Choose this when** platform differences are substantial, you want enforced module boundaries, faster incremental builds, or you already modularize by package.
- The package builds for every platform it declares in `Package.swift` `platforms: [.iOS(...), .macOS(...)]`, which makes "does the shared code build for Mac?" a `swift build` question independent of Xcode.

Either way, the **macOS target/product is first-class** — built in CI, run regularly, never a someday-target.

## Folder layout: group by feature, keep Shared small

Group by **feature**, not by type (`Views/`, `Models/`), matching this plugin's `swiftui-patterns` house style — and keep the shared "junk drawer" small.

```
MyApp/
├── App/
│   ├── MyApp.swift                 # @main App; scenes (WindowGroup, Settings, MenuBarExtra gated)
│   └── Platform.swift              # PlatformColor/Image/Font/ViewRepresentable typealiases (one place)
├── Features/
│   ├── Inbox/
│   │   ├── InboxModel.swift        # @Observable — platform-free
│   │   ├── InboxView.swift         # shared UI; bridges/adapts inline where small
│   │   └── InboxCommands.swift     # menu commands + shortcuts (cross-platform; matters on Mac)
│   └── Settings/
│       ├── SettingsModel.swift
│       ├── MacSettingsView.swift   # macOS target only — the TabView-of-panes idiom
│       └── iOSSettingsView.swift   # iOS target only — grouped NavigationStack
├── Shared/                         # TRULY universal utilities only — resist dumping here
│   ├── PlatformClipboard.swift     # UIPasteboard/NSPasteboard bridge
│   └── Extensions/
└── Resources/
    └── Assets.xcassets
```

Guidance distilled from Apple's SwiftUI structure guidance and the multiplatform community:

- **Feature folders over type folders.** `Features/Inbox/` (model + view + commands together) beats `Views/` + `Models/`. Discoverability and cross-platform reasoning both improve — you see a feature's whole platform story in one place.
- **Keep `Shared` small.** It tends to become a dumping ground. If something is used by only two features, put it in one of them. `Shared` is for genuinely universal utilities (the platform bridges, small extensions), not "code I didn't know where to put."
- **One `Platform.swift`** for all the `Platform*` typealiases — the app's platform-type vocabulary in a single reviewable file (see **Platform Gating**).
- **Use "New Group with Folder"** in Xcode so the Project navigator and the on-disk folders stay in sync; otherwise the navigator looks tidy while Finder is chaos.

## Naming platform-specific files

Two conventions, both fine — be consistent:

1. **Suffix + target membership** (single-target shape): `SettingsView+iOS.swift`, `SettingsView+macOS.swift`, each a member of only its platform's destination. Xcode compiles the right one per destination based on target membership; the *filename* carries the intent.
2. **Suffix + internal `#if`** (also works in packages): one `SettingsView.swift` whose top-level `#if os(macOS) … #else … #endif` picks the implementation. Better when the split is small; the file compiles for all platforms and the compiler picks the branch.

Whichever you use, put the *large* forks in separate files and let a single top-level `#if` choose — don't riddle one file with scattered branches (Jesse Squires' split-large-differences rule, see **Platform Gating**).

## Deployment targets and capabilities

- Set an explicit **macOS deployment target** alongside the iOS one (this plugin's baseline is iOS 26 / a current macOS release). Both must be real, supported values — the Mac target isn't "iOS with a higher number."
- Manage **per-platform entitlements** (App Sandbox on Mac needs network/file entitlements — see **macOS Adaptation**). Keep a macOS `.entitlements` file and review it when adding capabilities.
- Assets, Info.plist keys (usage descriptions), and capabilities may differ per platform — set them per target/destination, not globally by accident.

## CI discipline: the Mac build must not rot

The minimum contract is only real if something enforces it continuously. "Builds on my iPhone simulator" is not enforcement.

- **Build the macOS target on every change** — locally before committing, and in CI. A one-line check catches an unguarded `UIColor` the moment it lands, not months later:

  ```bash
  xcodebuild -scheme MyApp -destination 'platform=macOS' build      # single-target shape
  swift build                                                       # shared-package shape (uses Package platforms)
  ```

- Add the macOS destination to the same CI matrix as iOS. If only iOS is in CI, the Mac build *will* rot — every contributor who only builds iOS locally is a latent break.
- Treat a red macOS build like any red build: blocking. This is what turns "buildable for macOS as minimum" from an aspiration into a guarantee.

## Where this sits relative to other skills

- **`adaptive-ui`** — once the Mac target *builds*, that skill governs how the UI *lays out* in a resizable Mac/iPad window (measured space, not device). Use both together.
- **`swiftui-patterns`** — the feature-folder + `@Observable` architecture this layout assumes.
- **`ios-26-platform` / `ios-hig`** — iOS-specific platform features; gate anything from there that has no Mac analog (rung 4).
