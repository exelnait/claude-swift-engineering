---
name: design-principles
description: Use when making product/UX decisions for an Apple-platform app — deciding what to build, naming features/menus/settings, weighing clarity vs brand, or responsibly adding AI features. Applies Apple's eight design principles (purpose, agency, responsibility, familiarity, flexibility, simplicity, craft, delight) plus naming/UX-writing criteria. Complements `ios-hig` (the concrete HIG rules) with the why behind them.
---

# Apple Design Principles

Design is **making something with intention** — focusing on what matters most to people so you build something they truly value. Every feature asks for a person's time, attention, and trust; choosing what to build is often deciding what *not* to include. This skill captures Apple's eight design principles and the discipline of naming, so design decisions are deliberate rather than accidental.

This skill is the *why*. For the concrete platform rules (accessibility, Dynamic Type, dark mode, Liquid Glass, haptics, navigation patterns), use **`ios-hig`** and **`ios-26-platform`**.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.**

| Reference | Load When |
|-----------|-----------|
| **[Principles](references/principles.md)** | Deciding what to build, evaluating a design, resolving a UX trade-off — the eight principles in depth |
| **[Naming & UX Writing](references/naming-and-ux-writing.md)** | Naming a feature, menu, tab, setting, or plan; choosing labels; weighing clarity vs brand; writing in-app copy |
| **[Responsible AI Design](references/responsible-ai-design.md)** | Adding an AI / Foundation Models feature — privacy boundaries, safety, anticipating wrong/unsafe model output, safeguards, and when to cut a feature |

## The Eight Principles (at a glance)

| Principle | One line |
|-----------|----------|
| **Purpose** | Build with intention; decide what *not* to include. Does this feature have a clear purpose for the person? |
| **Agency** | Put people in control — offer choices; add **forgiveness** (undo, confirm destructive actions). |
| **Responsibility** | Act in people's best interest: privacy first, keep people safe, anticipate AI harm. |
| **Familiarity** | Build on what people know — apt metaphors and **consistency** (same look ⇒ same behavior, same place). |
| **Flexibility** | Adapt to people's real lives — contexts, devices, abilities; allow personalization. |
| **Simplicity** | Strip the unnecessary so the purpose shines. Simple ≠ minimal; be **concise** and **clear** (hierarchy). |
| **Craft** | Uncompromising attention to detail; quality materials, iteration, and ongoing maintenance. |
| **Delight** | An emotional connection that results from getting the other principles right — not confetti tacked on. |

> There is no formula. Leaning into one principle can mean compromising another; the trade-offs are yours. Use these as a guide, not a rulebook.

## How to Use This Skill

1. **Before building:** apply **Purpose** — is this worth a person's time/attention/trust? If not, cut it.
2. **While designing:** check the decision against the relevant principles (e.g., a destructive action → Agency/forgiveness; a permission prompt → Responsibility; a new control layout → Flexibility/personalization).
3. **When adding intelligence:** load `responsible-ai-design.md` — anticipate that the model can produce something unexpected, inaccurate, or unsafe, and add safeguards. Measure quality with the **`evaluations`** skill.
4. **When naming anything:** load `naming-and-ux-writing.md` and run the audience → think/feel/do exercise and the three naming criteria.

## Connections to Other Skills

- **`ios-hig` / `ios-26-platform`** — the concrete rules these principles motivate.
- **`localization`** — "works everywhere" includes languages, markets, RTL; a name/feature must travel.
- **`foundation-models`** + **`evaluations`** — Responsibility for AI features: build them well, then prove their quality across every supported language.

## Common Mistakes

1. **Confusing simple with minimal** — Hiding everything in one place looks minimal but isn't simple. Simplicity sometimes means *adding* context (e.g., remaining time on a paused video) so people can decide.

2. **Treating delight as decoration** — Confetti and flourishes are not delight. Delight is the emotional payoff of purpose, agency, familiarity, craft done right. Identify the feeling you want and reinforce it throughout.

3. **Naming by what it does technically** — Users want to know what it does *for them*, not the technology or function. "Vocal Isolation" describes the tech; "Enhance Dialogue" describes the experience.

4. **Permission prompts and data requests up front** — Asking for data before the person understands the app breaks trust. Wait for the right moment, ask only for what's necessary, and explain why (Responsibility).

5. **Shipping an AI feature without anticipating harm** — A model can suggest an allergen in a recipe app. "How could this be misused? Who is harmed? How do I prevent it?" If risk outweighs value, remove the feature. See `responsible-ai-design.md`.

6. **Breaking familiarity for cleverness** — Reusing the trash-can icon for something other than delete, or inventing a delete icon, destroys instant recognition. Don't reinvent common metaphors.
