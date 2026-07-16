---
name: app-intents-widgets
description: >-
  Use when building anything in the App Intents / WidgetKit surface — Home Screen & Lock Screen widgets, interactive widgets (Button/Toggle backed by an AppIntent), Live Activities & the Dynamic Island (ActivityKit), Control Center / Lock Screen / Action Button controls (ControlWidget, iOS 18+), App Shortcuts and Siri/Spotlight exposure, or the AppIntent/AppEntity/AppEnum model that powers them all. Covers timeline providers and reload policies, widget families and the required container background, `perform()` intents, parameters and entity queries, `@Dependency` injection, and how widgets/controls/Live Activities share one intent vocabulary with your app. Load whenever a feature extends outside the app's own window — glanceable UI, system surfaces, voice, or automation.
---

# App Intents & WidgetKit (iOS 26+)

App Intents is the spine of the modern extension surface: one `AppIntent` can be a Siri phrase, a Shortcuts action, a Spotlight result, a widget button, a Control Center toggle, and a Live Activity control — all from the same code. WidgetKit, ActivityKit, and Controls are the *presentations*; App Intents is the *verb layer* underneath. Design the intents first, then surface them.

The core principle: **model your app's actions and entities as App Intents once, then present them across system surfaces.** A widget is a timeline of glanceable entries; a control is a button/toggle bound to an intent; a Live Activity is a live-updating card; a Shortcut is a phrase. They differ in presentation and update cadence, not in the underlying verbs.

## Quick Reference

| Surface | Type | Update model |
|---------|------|--------------|
| Home/Lock Screen widget | `Widget` + `AppIntentTimelineProvider` | Timeline of `TimelineEntry`s + reload policy |
| Configurable widget | `AppIntentConfiguration(kind:intent:provider:)` | Config via a `WidgetConfigurationIntent` |
| Interactive widget | `Button(intent:)` / `Toggle(isOn:intent:)` in the entry view | Intent `perform()` → WidgetKit reloads |
| Live Activity | `ActivityKit` + `ActivityConfiguration` | `Activity.update(...)` or APNs push; Dynamic Island |
| Control (iOS 18+) | `ControlWidget` + `ControlWidgetButton/Toggle` | Bound `AppIntent`; state via provider |
| Siri / Shortcuts / Spotlight | `AppIntent` + `AppShortcutsProvider` | User- or system-invoked |

## Core Workflow

1. **Model the verbs and nouns as App Intents.** An `AppIntent` per action (`perform()`), an `AppEntity` per addressable noun, an `AppEnum` per fixed choice set. Inject app services with `@Dependency`.
2. **Expose them to the system** with an `AppShortcutsProvider` (phrases for Siri/Shortcuts) — free reach once the intents exist.
3. **Add a widget** with an `AppIntentTimelineProvider`: build entries, choose a reload policy, render per family, and apply the **required** `.containerBackground(for: .widget)`.
4. **Make it interactive** (iOS 17+) by putting `Button(intent:)`/`Toggle(isOn:intent:)` in the entry view — the same intents from step 1.
5. **Add a Live Activity** for ongoing, real-time events (delivery, timer, game) via ActivityKit + Dynamic Island; update by push for background freshness.
6. **Add Controls** (iOS 18+) to put a toggle/button in Control Center, the Lock Screen, or the Action Button — again bound to your intents.
7. **Reload deliberately** with `WidgetCenter.shared.reloadTimelines(ofKind:)` when the app changes data a widget shows.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** These surfaces run in separate extension processes with their own memory limits, lifecycle, and gotchas — guessing wastes a build/test cycle on device.

| Reference | Load When |
|-----------|-----------|
| **[App Intents](references/app-intents.md)** | Defining any intent — `AppIntent`/`perform()`, `@Parameter`, `AppEntity` + `EntityQuery`, `AppEnum`, `IntentDialog`/results, `@Dependency` injection, `OpenIntent`/foreground continuation, and exposing app data to Siri/Shortcuts/Spotlight |
| **[WidgetKit](references/widgetkit.md)** | Building a widget — `Widget`/`WidgetBundle`, `StaticConfiguration` vs `AppIntentConfiguration`, `AppIntentTimelineProvider`, `TimelineEntry`, reload policies, `supportedFamilies`, the required `containerBackground`, deep links, `WidgetCenter` reloads, rendering modes |
| **[Interactive Widgets](references/interactive-widgets.md)** | Adding buttons/toggles to a widget or Live Activity — `Button(intent:)`/`Toggle(isOn:intent:)`, optimistic UI, what runs where, and the reload cycle |
| **[Live Activities](references/live-activities.md)** | Real-time ongoing events — `ActivityAttributes`/`ContentState`, `ActivityConfiguration`, the Dynamic Island regions, `Activity.request/update/end`, `staleDate`/`relevanceScore`, and APNs push updates |
| **[Controls](references/controls.md)** | Control Center / Lock Screen / Action Button controls (iOS 18+) — `ControlWidget`, `ControlWidgetButton`/`ControlWidgetToggle`, static vs `AppIntent` value providers, and action hints |

## Common Mistakes

1. **Building the presentation before the intents.** Widgets, controls, and Live Activities all bind to App Intents; design the `AppIntent`/`AppEntity` layer first so every surface shares one vocabulary instead of duplicating logic per extension.

2. **Forgetting `.containerBackground(for: .widget)`.** Since iOS 17 every widget entry view must declare a container background or it renders wrong (and is rejected from the Smart Stack / StandBy contexts). Add it to the root of the entry view.

3. **Doing real work in a widget's timeline provider.** The provider runs in a memory- and time-constrained extension. Fetch the minimal data for the entries (from a shared App Group container or a fast store), not a full network sync. Heavy work belongs in the app, which then calls `WidgetCenter.reloadTimelines`.

4. **Expecting widgets to update in real time.** Widgets are a *timeline*, not a live view. The system budgets refreshes; `.atEnd`/`.after(date)` policies and `reloadTimelines` are your levers. For genuine real-time (seconds), use a **Live Activity**, not a widget.

5. **Interactive widget intents that block.** `Button(intent:)`/`Toggle(intent:)` run the intent's `perform()` then reload the timeline — keep `perform()` fast and write results to shared storage so the reloaded timeline reflects them. Don't attempt long async work inline.

6. **No shared data path between app and extension.** Widgets/Live Activities run in separate processes; they can't see the app's in-memory state. Share via an **App Group** container (shared `ModelContainer`/UserDefaults/file) so both sides read the same data.

7. **Live Activity updated only from the foreground.** For freshness while the app is backgrounded/terminated, update Live Activities via **APNs push** (request a push token per activity). Foreground-only `Activity.update` goes stale the moment the app leaves.

8. **App Shortcuts phrases without the app name.** Siri phrases in `AppShortcutsProvider` should include `\(.applicationName)` so users can actually invoke them; register them at launch and keep them stable.
