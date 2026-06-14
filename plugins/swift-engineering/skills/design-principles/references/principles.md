# The Eight Design Principles

Apple's design principles describe experiences that serve people, respect and adapt to their lives, are clear and considered, and are a joy to use. There's no formula — leaning into one can compromise another. Use judgement.

---

## 1. Purpose

Design is making something with intention. Every feature asks for a person's **time, attention, and trust** — things you can't waste. Choosing what to build is often deciding what *not* to include.

- Before a sketch or a line of code, ask: does this have a clear purpose for the person?
- Cut features that don't earn their place. Scope is a design decision.

## 2. Agency — put people in control

People feel in control when you let them do things their way.

- **Offer choices.** Don't force a single pre-determined path; let people explore at their own pace. An interface should never stand in the way of what someone is trying to do.
- **Forgiveness.** People send/change/delete things by accident. Make actions easy to **undo**. For destructive actions, **confirm** intent — but use interruptions sparingly, only when someone is about to make a big mistake. Forgiveness gives people the confidence to explore.

## 3. Responsibility — act in people's best interest

- **Privacy is a human right.** Don't throw permission prompts the second the app launches, and don't ask for data without context. Wait for the right moment, ask only for what's necessary, and be transparent about what it's for. (Like real life: you wouldn't trust someone who demanded your number before saying why.)
- **Keep people safe.** Look hard at each feature: *How could this be misused? Who would be harmed? How do I prevent it?*
- **Responsible AI.** Anticipate that a model may produce something unexpected, inaccurate, or unsafe (e.g., a recipe app suggesting an allergen). Add safeguards — previews, confirmations, disclaimers — and **remove a feature entirely if the risk outweighs the value**. See `responsible-ai-design.md`.

## 4. Familiarity — build on what people know

People arrive with a lifetime of real-world experience and conventions from other interfaces. Lean on it.

- **Metaphor.** A good metaphor draws on something people know and helps them predict behavior (trash can = delete, and you can retrieve from it). Avoid metaphors that are too literal (unfamiliar) or too abstract (idea doesn't land). Don't repurpose a well-known metaphor (trash can for not-delete) — it surprises people in a bad way.
- **Consistency.** Things that look the same should behave the same; consistent **placement** matters too (close a Mac window in the top-left, always). Predictability lets people navigate without thinking.

## 5. Flexibility — adapt to real lives

People use your design in ways as unique as they are.

- **Contexts.** The same task (e.g., music) differs at home on speakers, on a run with AirPods + Watch, or hands-free while driving. Accommodate the situation.
- **Devices.** iPhone wants quick touch interactions; Mac expects deep workflows and precise pointer control. Each device deserves a solution that uses what makes it unique.
- **Abilities.** Get curious about your audience — age, languages, expertise, accessibility needs. You won't solve for everyone on day one, but you can become more inclusive over time.
- **Personalization.** When no single layout fits everyone, let people rearrange or hide controls to suit their workflow.

## 6. Simplicity — let the purpose shine

Simple ≠ minimal. Burying functionality to look minimal isn't simple. Simple designs are frictionless and intuitive.

- **Concise.** Plain language, no jargon, no redundancy; reduce the number of steps. Respect people's time.
- **Clear.** Strong **hierarchy** (order, spacing, contrast) makes the most important thing the most obvious. Clear interfaces answer: *What do I pay attention to? What can I interact with? How?*
- Distill complex data (a graphic instead of a table; a summary instead of raw detail). Every element should earn its place.
- **Sometimes simple means adding** — a paused video showing position and time remaining gives the context needed to decide. You've arrived at simplicity when you have *exactly enough*.

## 7. Craft — attention to detail

Craft tells people you care; it inspires confidence, while a rushed feel makes people doubt the results.

- **Quality materials:** beautiful fonts across devices; colors that adapt across light/dark; clear graphics and iconography; responsive animations giving immediate, natural feedback; reliable, secure SDKs.
- **Iteration:** quality takes time — make every last piece function beautifully.
- **Maintenance:** great design has longevity. Keep evolving it as new features and hardware arrive, so people feel supported and rewarded.

## 8. Delight — the emotional payoff

Hard to define, instantly recognized. Delightful interfaces are satisfying, enriching, and create a real emotional connection — which starts when an experience feels **human**.

- Delight is **not** confetti or flourishes added at the end. Identify the emotion you want people to feel (relaxed, confident, excited) and reinforce it throughout.
- Delight is the natural result of getting the other principles right: intention and care, agency to act, safety to explore, familiar patterns, and the ability to make it their own.

---

## Using the principles to decide

1. Start with **Purpose** — should this exist at all?
2. Identify which principles are most in tension for this decision (e.g., brand expression vs clarity; flexibility vs simplicity).
3. Decide which to prioritize *given where the feature lives* — and accept the trade-off deliberately.
4. Verify with the concrete rules in `ios-hig` / `ios-26-platform`.
