# Accessibility Principles & Inclusive Design

The mindset behind accessible apps. Use this to decide *what* to build before
reaching for specific APIs.

## Ability is a spectrum

Think about ability across five categories — **Vision, Hearing, Motor, Speech,
Cognitive** — and treat each as a spectrum, not a binary. Someone who is
"legally blind" may still perceive color, light, and large shapes; "hard of
hearing" is not "deaf." Adding the word *some* ("some vision", "some hearing")
keeps the spectrum in mind and leads to better design decisions.

Disability is also situational: temporary (an ear infection), or
environmental (a loud airport, a quiet library, bright sun, sticky hands while
cooking). Designing for disability benefits everyone.

## The inclusion gap

Disability is born in the **gap between what a person can do and what the
environment/society expects**. A two-story building disables a wheelchair user
only if there's no elevator. Close the gap and the limitation disappears.

The gap is a source of innovation — microphones, glasses, and curb cuts all came
from closing it, and all ended up helping far more people than originally
intended. Look for the inclusion gap in *your* app: where does it assume a
capability not everyone has?

> **Nothing about us without us.** Whenever possible, collaborate with people
> who have disabilities and use assistive technology — their lived experience is
> far more accurate than assumptions.

## The four guiding principles for controls

Sighted users learn a control's purpose, value, available actions, and feedback
at a glance. Give assistive-technology users the same:

| Principle | Question | Typical API |
|-----------|----------|-------------|
| **Purpose** | What is this? | `accessibilityLabel` |
| **Value** | What's the current value? | `accessibilityValue` |
| **Actions** | What can I do, and how? | traits, `accessibilityAdjustableAction`, `accessibilityAction`, direct touch |
| **Feedback** | What changed? | value updates, `AccessibilityNotification.Announcement` |

## The four practices for an inclusive app

1. **Support multiple senses.** Provide more than one way to perceive and input
   information — captions for audio, audio/haptics for visuals, image/camera/
   text/voice/hands-free input paths. (E.g. a recipe app importing from image,
   camera, text, *and* a hands-free mode.)
2. **Provide customization.** Let people personalize visuals, audio, and
   interaction (text size, colors, high-legibility fonts, density). The app
   adapts to the person, not the other way around.
3. **Adopt the Accessibility API.** The same API powering VoiceOver also enables
   Switch Control, Voice Control, and more — a lot of the work is done for you.
   Add labels, values, traits, and actions.
4. **Track inclusion debt.** You won't close every gap at once. Inclusion is a
   journey; record the known gaps so you can plan and prioritize closing them.

## Assistive technologies to design for

- **VoiceOver** — screen reader for blind/low-vision users; gesture-driven,
  uses the rotor for navigation granularity.
- **Switch Control** — drives the UI with one or more physical switches
  (scan + select); needs reachable, well-labeled, actionable elements.
- **Voice Control** — operate the device by voice; relies on accurate labels.
- **Larger Text / Dynamic Type** — text up to ~3× larger; needs scalable type
  and adaptive layout.
- **Accessibility Reader (iOS 26+)** — system-wide customizable reading
  experience (visual text, read-aloud, read-along highlighting); benefits from
  good text accessibility in your app.

Adopting the core Accessibility API tends to light up *all* of these at once —
like a curb cut that helps wheelchairs, strollers, and dollies alike.

## Accessibility Nutrition Labels

Since WWDC25, you can surface the accessibility features your app supports on its
App Store product page via **Accessibility Nutrition Labels**, helping people
know whether the features they rely on are present. There are nine declarable
features across interaction, visual, and media categories — declare only the
ones your app truly supports across its primary tasks. See
[Nutrition Labels](nutrition-labels.md) for each feature's criteria and a
pre-submission readiness checklist.

## Summary

1. Treat ability as a spectrum across vision, hearing, motor, speech, cognition.
2. Find and close the inclusion gap; collaborate with disabled users.
3. Every control: purpose, value, actions, feedback.
4. Support multiple senses, allow customization, adopt the Accessibility API,
   track inclusion debt.
5. Design for VoiceOver, Switch Control, Voice Control, Larger Text, and the
   Accessibility Reader — and evaluate for Accessibility Nutrition Labels.
