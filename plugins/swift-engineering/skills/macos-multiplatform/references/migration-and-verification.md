# Migration & Verification

Two jobs: (1) take an iOS-only feature or codebase and get it to the **minimum** (builds and launches on Mac), then (2) climb toward the **maximum** (native adaptation). Plus the checklist that keeps every future change from regressing the minimum contract.

## Step 1 — Audit for Mac-breaking symbols

Before changing anything, find what will fail the macOS build. These greps surface the usual offenders in shared code:

```bash
# UIKit imports and bare UI* types in files the Mac target compiles
rg -n 'import UIKit' Sources Features Shared
rg -n '\bUI(Color|Image|Font|Screen|Application|Device|Pasteboard|View(Controller)?Representable|FeedbackGenerator)\b'

# iOS-only modifiers
rg -n 'navigationBarTitleDisplayMode|navigationBarItems|navigationBar(Hidden|BackButtonHidden)|listStyle\(\.insetGrouped|keyboardType|textInputAutocapitalization|fullScreenCover|statusBar|EditButton|hoverEffect'

# iOS-only positional toolbar placements
rg -n 'navigationBarLeading|navigationBarTrailing|\.bottomBar'

# iOS-only frameworks with no Mac analog
rg -n 'import (CoreMotion|ARKit|RealityKit|CoreNFC)'

# existing platform branches (see how divergence is already handled)
rg -n '#if os\(|#if canImport\('
```

Each hit maps to a row in the **API Divergence Catalog**. Classify it by rung before you touch it: can it *unify* (best), *bridge*, *adapt*, or must it *exclude*?

## Step 2 — Make it build on Mac (the minimum)

Work the audit list from cheapest fix to most involved:

1. **Unify what you can (rung 1).** Swap `UIColor`→`Color`, `UIImage`→`Image`, `.navigationBarItems`→semantic `.toolbar`, `UIActivityViewController`→`ShareLink`, `UIFeedbackGenerator`→`.sensoryFeedback`, positional toolbar placements→semantic ones. These often *shrink* the code.
2. **Bridge same-concept type/modifier differences (rung 2).** Add `Platform*` typealiases in `Platform.swift`; wrap iOS-only modifiers (`.keyboardType`, `.navigationBarTitleDisplayMode`, `.listStyle(.insetGrouped)`) in no-op-on-Mac custom modifiers. Replace scattered `#if`s with these single seams. (See **Platform Gating**.)
3. **Gate what has no analog (rung 4).** Wrap iOS-only frameworks (`CoreMotion`, `ARKit`, camera capture) and their *entire* usage — imports, types, model fields, and entry-point UI — in `#if os(iOS)`. Ensure the Mac side either offers an alternative or hides the control (no dead buttons).
4. **Build the macOS target** and fix what the compiler reports, iterating until green:
   ```bash
   xcodebuild -scheme <App> -destination 'platform=macOS' build
   # or, shared-package: swift build
   ```
5. **Launch it.** Run the Mac app once. The minimum contract is "compiles **and launches**" — a crash on first window (e.g. a force-unwrapped `UIScreen`) still fails it. Watch for missing-entitlement runtime failures (network, file access) that no build catches (see **macOS Adaptation**).

At the end of Step 2 the feature is *shippable* on Mac. If time is short, this is a legitimate stopping point — but a conscious one.

## Step 3 — Adapt for Mac (climb toward the maximum)

Now improve the Mac experience where it pays off (all rung 3 — see **macOS Adaptation** for the how):

- Replace `#if os(iOS)`-excluded flows with real Mac equivalents where one exists (camera → `.fileImporter`/`PhotosPicker`).
- Add `.contextMenu` (right-click) and `.onHover` to interactive elements — the highest value-per-effort wins.
- Add `.keyboardShortcut`s and `.commands` for repeatable actions; pull-to-refresh → a ⌘R "Refresh" command.
- Reshape list-detail navigation as `NavigationSplitView`; move settings into a `Settings` scene.
- Set window `minWidth`/`idealWidth`, `.windowResizability`, `.defaultSize`; ensure the layout breathes in a large window (hand off to the `adaptive-ui` skill).

Do the cheap universal wins (context menu, semantic toolbar, hover) for *every* feature; invest the deeper adaptations (scenes, multi-window, split view) at the app-structure level where they matter most.

## Verification: proving the contract holds

**iOS building tells you nothing about Mac.** Verify explicitly:

1. **Build the macOS target.** Green `xcodebuild -destination 'platform=macOS'` (or `swift build` for the shared package) is the one hard gate. Do it before calling any change done.
2. **Launch the Mac app** and exercise the changed feature — including the paths you gated or adapted. Confirm excluded features degrade gracefully (alternative shown or control hidden), not as dead buttons or empty screens.
3. **Check runtime capabilities** that the build can't: network calls, file open/save, clipboard — the things gated behind Mac entitlements.
4. **Sanity-check the input model** on the changed UI: does right-click do something sensible? Does hover give feedback? Do the keyboard shortcuts fire?

If a `verify`-style skill or project verification exists, run it against the **macOS** destination too, not only iOS.

## Pre-commit / pre-merge checklist

Run through this before committing any feature change:

- [ ] macOS target **builds** (`xcodebuild -destination 'platform=macOS'` / `swift build`) — the minimum contract.
- [ ] macOS app **launches** and the changed feature works.
- [ ] **No unguarded** `UIKit`/`AppKit`/iOS-only symbol in shared code (re-run the Step 1 greps on your diff).
- [ ] Platform differences sit at **one seam each** (typealias / modifier / single top-level `#if`), not scattered across call sites.
- [ ] Excluded (rung-4) capabilities are gated **including their UI entry points**; the Mac build stays coherent.
- [ ] Toolbar items use **semantic** placements, not `.navigationBarTrailing`/`.bottomBar`.
- [ ] Interactive elements have `.contextMenu` and (where apt) `.onHover` / `.keyboardShortcut`.
- [ ] The chosen ladder rung for each difference was **deliberate** — you know where this feature sits and why it stops there.
- [ ] macOS is in **CI** so the next change can't silently regress this.

The point of the checklist is that "works on Mac" stops being something you remember to check and becomes something the process guarantees.
