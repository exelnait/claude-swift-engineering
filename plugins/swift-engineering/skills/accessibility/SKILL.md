---
name: accessibility
description: Use when making iOS/macOS apps accessible — VoiceOver, Switch Control, Voice Control, Dynamic Type, custom control accessibility (adjustable, passthrough, direct touch), accessible reading / long-form text, media captions & subtitles, inclusive design, and accessibility auditing/testing. The canonical accessibility reference for this plugin.
---

# Accessibility

Accessibility is a first-class concern, not a finishing step. Technology works
best when it works for everyone — about one in seven people lives with some form
of disability, and ability is a spectrum, not a binary. Designing with
disability in mind makes your app work for more people and sparks better design.

This skill is the canonical home for accessibility depth in this plugin. The
`ios-hig` skill keeps a brief accessibility summary and points here.

## Guiding Principles

For every control and view, make sure assistive-technology users get the same
information sighted users get at a glance:

1. **Purpose** — what is this control/content? (`accessibilityLabel`)
2. **Value** — if it expresses a value, expose it (`accessibilityValue`)
3. **Actions** — what can someone do, and how? (traits + actions)
4. **Feedback** — what changed as a result? (announcements / value updates)

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be
required.** It's better to have the context than to miss a pattern.

| Reference | Load When |
|-----------|-----------|
| **[Principles](references/principles.md)** | Inclusive design, the spectrum of ability, the inclusion gap, the four practices, assistive technologies overview, Accessibility Nutrition Labels |
| **[Foundations](references/foundations.md)** | Labels, hints, values, traits, hiding decorative content, combining elements, contrast/color, Reduce Motion/Transparency |
| **[Custom Controls](references/custom-controls.md)** | Custom/interactive controls: `.adjustable`, `accessibilityAdjustableAction`, passthrough gesture, `accessibilityActivationPoint`, custom actions for multi-axis, direct touch (`allowsDirectInteraction`) |
| **[Dynamic Type](references/dynamic-type.md)** | Scaling text, adaptive layout (`AnyLayout`/`UIStackView`), inline images (`ScaledMetric`, `SymbolConfiguration`), Large Content Viewer |
| **[Reading & Long-Form Text](references/reading-long-form.md)** | Articles/books/paginated content: cross-element line navigation, continuous read-all, edit-rotor selection, `UITextInput`, Accessibility Reader |
| **[Media & Captions](references/media-captions.md)** | Subtitle/caption selection UI, Apple AI-generated subtitles, subtitle style preview |
| **[Nutrition Labels](references/nutrition-labels.md)** | Readiness for App Store Accessibility Nutrition Labels — the nine features, their criteria/thresholds, and a pre-submission checklist |
| **[Testing & Audits](references/testing-audits.md)** | Manual VoiceOver/Switch Control/Voice Control passes, `performAccessibilityAudit`, Dynamic Type preview variants, audit-in-CI |

## Core Workflow

1. **Audit first** — turn on VoiceOver and try the real task; navigate with the
   rotor; bump Dynamic Type to the largest accessibility size; try Switch
   Control / Voice Control.
2. **Prefer system components** — they ship with strong accessibility defaults.
   Reach for custom UI only when layout/interaction truly requires it.
3. **Apply the four principles** to every custom control: purpose, value,
   actions, feedback.
4. **Support multiple senses & customization** — don't rely on sight or hearing
   alone; let people tailor the experience.
5. **Verify** with an accessibility audit (manual + automated in UI tests).

## Platform Note

- This plugin targets **iOS 26+**; write iOS 26 APIs directly with no
  `@available(iOS <26, *)` guards.
- A few APIs referenced here are newer and DO need a guard:
  SwiftUI `accessibilityLinkedGroup` is **iOS 27+**, and Apple AI-generated
  subtitles land in **iOS/macOS/tvOS/visionOS 27**. Guard those with
  `if #available(iOS 27, *)`.

## Common Mistakes

1. **Custom controls with no label/value/actions** — a custom view reads as
   "image" and the whole interaction is invisible to VoiceOver. Apply the four
   principles.
2. **Relying on the passthrough gesture alone** — not everyone can perform it.
   Always also expose custom actions / adjustable actions.
3. **Hard-coded font sizes** — break Dynamic Type. Use text styles and test at
   the largest accessibility size.
4. **Truncating/clipping at large sizes** — set line limits to 0/unlimited and
   adapt layout (`AnyLayout`, stack-view axis) for accessibility sizes.
5. **Custom video players with no subtitle selection UI** — provide it
   (`AVPlayerViewController` / `AVLegibleMediaOptionsMenuController` / custom).
6. **Treating accessibility as one-time** — track inclusion debt and re-audit
   every iteration.
