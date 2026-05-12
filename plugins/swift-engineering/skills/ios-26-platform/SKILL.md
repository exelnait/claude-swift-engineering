---
name: ios-26-platform
description: Use when implementing iOS 26 features (Liquid Glass, new SwiftUI APIs, WebView, Chart3D), deploying iOS 26+ apps, or using new platform APIs introduced in iOS 26.
---

# iOS 26 Platform

iOS 26 is the minimum deployment target for this plugin. All APIs, patterns, and examples in this skill assume iOS 26 is universally available — no availability guards, no fallback paths, no "before iOS 26" comparisons.

## Overview

iOS 26 modernizes UI with new materials (Liquid Glass), SwiftUI APIs (WebView, Chart3D, @Animatable), and advanced features (@BackoffAnimation, free-form windows). The core principle: modern UI gets updated automatically at compile time; most Liquid Glass benefits are "free" from recompiling with Xcode 26.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** It's better to have the context than to miss a pattern or make a mistake.

| Reference | Load When |
|-----------|-----------|
| **[Liquid Glass](references/liquid-glass.md)** | Implementing glass effects, choosing Regular vs Clear variants, or understanding visual properties |
| **[Automatic Adoption](references/automatic-adoption.md)** | Understanding what iOS 26 changes automatically vs what requires code |
| **[SwiftUI APIs](references/swiftui-apis.md)** | Using WebView, Chart3D, `@Animatable`, AttributedString, or new view modifiers |
| **[Toolbar & Navigation](references/toolbar-navigation.md)** | Customizing toolbars with spacers, morphing, glass button styles, or search |

## Core Workflow

1. **Deployment target is iOS 26+** — No availability checks needed for iOS 26 APIs
2. **Recompile with Xcode 26** — Standard controls get glass automatically
3. **Identify navigation layer** — Apply glass to tab bars, toolbars, navigation (not content)
4. **Choose variant** — Regular (95% of cases) or Clear (media-rich backgrounds only)
5. **Test accessibility** — Verify Reduce Transparency, Increase Contrast, Reduce Motion

## Common Mistakes

1. **Adding `@available(iOS 26, *)` guards** — Since this plugin targets iOS 26+ exclusively, availability guards are never needed. Write iOS 26 APIs directly.

2. **Over-using glass effect** — Applying glass to content areas, not just navigation, creates visual noise. Glass works for: tab bars, toolbars, sheets, navigation. NOT for content areas.

3. **Animation performance issues** — Liquid Glass animations can be expensive. Respect Reduce Motion accessibility setting and profile with Instruments 26 before shipping.

4. **Assuming Clear variant looks good** — Clear is for media-rich backgrounds only (photos, video). Regular variant is correct 95% of the time. Only use Clear if you explicitly need the ultra-transparency.

5. **Not testing on actual devices** — Simulator rendering differs from hardware. Test glass effects on iPhone 15 Pro, iPad, and Mac to verify visual quality.

6. **Using old UIView patterns with new glass** — Mixing UIView-based navigation with iOS 26 glass creates inconsistent appearances. Migrate fully to SwiftUI or wrap carefully with UIViewRepresentable.
