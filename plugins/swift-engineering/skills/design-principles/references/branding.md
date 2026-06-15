# Branding on iOS

Branding isn't just the aesthetic (typography, color, iconography) — it's a *feeling*, an extension of how people experience your product. The goal is to express brand identity **in service of** the app experience, not on top of it. iOS is a platform with established interactions; forcing your brand can compromise the experience. Branding should complement, not distract.

> Don't default to making your brand identical across web, retail, marketing, and your iOS app. Each placement has a different context. People who use iPhone expect apps to look and feel like iOS, and they usually have no experience with your app on other platforms — so the iOS app shouldn't inherit another platform's chrome.

## The Two Layers: where brand belongs

With Liquid Glass (iOS 26), think of the app as two layers:

| Layer | What it is | Brand role |
|-------|-----------|------------|
| **UI layer** | Global navigation & actions — tab bars, top toolbars, floating controls above the content | Stay **native**. Lean on familiar patterns; don't reinvent the wheel. This is the foundation that helps people get around. |
| **Content layer** | What sits beneath the controls — imagery, video, words, data viz, the features that make your app unique | Your **canvas**. The best place to express brand identity. |

Establishing a baseline of platform familiarity matters — otherwise people have to *learn* your app. Standard components (grids, grouped tables, context menus) are highly flexible; when you draw on what people already understand, they instinctively know how to use your app.

Keeping the navigation layer native also means accessibility behaviors come for free. A standard tab bar already responds to **Dynamic Type**: at larger accessibility text sizes the system presents the selected tab's icon and label **enlarged in the center of the screen** (as in Crumbl's tab bar). A custom tab bar has to reimplement and test this itself — and usually doesn't, which is exactly when a custom UI layer starts to feel broken for people who rely on large text.

## Custom vs standard components

Custom components take refinement to build and maintain. Spend that effort only where it has the **biggest impact** or makes content stand out (e.g. Moonlitt's lunar-cycle calendar — custom, but with a Liquid Glass backing, a primary dismiss action, and concentric sheet edges so it still belongs on iOS).

Then **audit for opportunities to use standard components** for the functional, utilitarian parts of the app. Re-implementing something tried-and-true (a custom context menu, a custom toggle) rarely reinforces brand — it tends to make the product feel *less* native, even dated, because it feels misplaced.

- Customizing a standard component to fit a need is expected (e.g. Slack's custom toolbar with a center channel-info action — but button sizes, floating-action placement, and popover behavior all still feel iOS).
- Context menus are a commonly overlooked standard component: actions with icons, grouped sections with optional headers, secondary menus/modals — and you get the morph-from-the-tapped-action animation for free with SwiftUI. Don't rebuild this.

## Content as your canvas

- **Imagery / video** — make it purposeful, not generic stock (Crumbl's full-bleed weekly-flavor videos draw a deeper connection because they change). Edge-to-edge color/3D can be right when immersion fits the content (Moonlitt's night-sky gradient).
- **Voice & tone** — words are content too, and they shape how people feel. Be deliberate about the emotion you target (playful, trustworthy). (See the UX-writing guidance in `naming-and-ux-writing.md`.)
- **Motion** — people experience content through scrolling, tapping, transitions. Use motion to emphasize hierarchy and draw attention to what matters (NYT Cooking's zoom transitions connect the tap target to the destination; Gentler Streak's spring animations make recaps pop). But delayed loads or dropped frames quietly damage perception — people remember how the app *felt*.

## Color

| Do | Avoid |
|----|-------|
| Move brand color **into the content / scroll area** so Liquid Glass controls pick it up dynamically and it scrolls away, letting content go edge-to-edge | Solid color backgrounds on toolbars/tab bars (the old pattern) — bulky, letterboxing the content area |
| Use color to **create meaning**: hierarchy, grouping, interaction — i.e. as your accent/tint on controls and actions (Slack tints only primary actions, badges, unread, selected tab) | Color everywhere — distracting and overwhelming; it loses its signal |
| Support **Dark Mode** with a refined low-light palette | Shipping light-only; a forced-light app reads as a negative experience |
| Extend brand color to **touch points beyond the app** (e.g. Widgets — Crumbl's pastel palette makes them instantly recognizable) | — |

Restraint wins: use color sparingly and with intention so it has the biggest impact.

## Typography

Typography is expressive but must always stay **functional**.

- Custom typefaces are great for memorable moments — large headers, hero content (Crumbl Sans). But the primary concern is **Dynamic Type**: system fonts support it for free; custom fonts require you to build and test the support yourself. As size grows, layouts should reflow to multiple lines, not truncate.
- You don't need a custom font to feel distinct. The **San Francisco** family already offers variety and hierarchy: **SF Pro** (default), **SF Compact** (small sizes), **SF Mono** (column/code alignment), **SF Rounded**, and **New York** (serif). Gentler Streak achieves a distinct voice with system fonts alone by mixing widths and variants.

## Iconography & logos

- Custom icons can go anywhere — content views and controls — but should be **identifiable, consistent, and scale well to small sizes** (NYT Cooking's sharper line-weight icons). Even with a custom style, stay true to the platform's pattern for an action (their Share icon differs across iOS/Android/Web but each reads as "share"). Don't over-stylize.
- Not every app needs custom icons. **SF Symbols** (7,000+, free, built into Xcode) scale like text, support weights/accessibility/localization, and are designed to be neutral — no export/handoff burden.
- **Logos:** in-app, people don't need reminding which app they're in, and logos eat real estate better used for content. Keep them understated (NYT Cooking shows its logo only on the Home tab and fades it on scroll). Refined and unobtrusive.

## Checklist

- [ ] **Navigation stays native** — tab bar, toolbars, standard gestures; no reinvented wheel in the UI layer (a native tab bar enlarges the selected icon/label in the center at large Dynamic Type sizes — a custom one must replicate this)
- [ ] **Brand lives in the content layer** — imagery, video, words, motion, data viz
- [ ] Custom components reserved for **high-impact** areas; functional parts use standard components
- [ ] Color moved **into the content/scroll area**, used as accent/tint to convey meaning, applied sparingly
- [ ] **Dark Mode** supported with a refined palette
- [ ] Custom fonts **support and were tested with Dynamic Type** (reflow, don't truncate); consider SF variants first
- [ ] Icons are identifiable, consistent, scale to small sizes, and honor platform patterns; default to SF Symbols
- [ ] Logos kept minimal and unobtrusive
- [ ] Brand **serves** the experience — nothing oversteps system behavior or confuses familiar conventions
