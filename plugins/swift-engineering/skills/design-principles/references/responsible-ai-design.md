# Responsible AI Design

Adding AI capabilities to a product is a design and **responsibility** decision before it is an engineering one. Intelligent features can deepen personalization in ways traditional software can't — but a model can generate something unexpected, inaccurate, or unsafe. Designing responsibly means anticipating that and protecting the people using *and* affected by your product.

## Ask the hard questions first

Before building an AI feature, answer:

1. **How could this feature be misused?**
2. **Who would be harmed by this — including people who aren't the user?**
3. **How do I prevent that harm?**

A recipe app where a user logged an allergy must anticipate that the model could suggest an ingredient that causes a severe reaction. That's real-world harm you can't leave to chance.

## Safeguards

Add friction where the cost of a wrong answer is high:

- **Previews** — show the model's output before it takes effect, so a person can catch errors.
- **Confirmations** — for consequential or destructive actions driven by the model.
- **Disclaimers** — set expectations that output is generated and may be wrong.
- **Cut the feature** — if the risk to people's safety outweighs the value, remove it entirely. Not every capability should ship.

## Privacy boundaries (where the model runs)

Privacy is a human right; the model you choose is a privacy decision. Match the model to the task's sensitivity (see the `foundation-models` skill → `model-selection.md` for the API details):

| Option | Privacy posture | Use for |
|--------|-----------------|---------|
| **On-device** (`SystemLanguageModel`) | Data never leaves the device; works offline | Personal/sensitive content; the private default |
| **Private Cloud Compute** | Apple PCC — prompts never stored, verifiable; no API keys | More capability/reasoning while staying private |
| **Third-party server models** | Data leaves to a third party; you handle auth/billing | Only when justified; be transparent; never send more than necessary |

- When moving context to a *less private* model, **redact** private information from the transcript first.
- Be transparent about what data an AI feature uses and why — same as any other data request (ask at the right moment, only what's necessary).

## Quality is part of responsibility

A responsible AI feature is one whose behavior you've actually measured — not hoped for. Because output is probabilistic, you cannot verify it with intuition or a single test.

- **Evaluate it.** Use the **`evaluations`** skill to build a dataset, define quantitative metrics and model judges, set an optimization target, and hill-climb. Data-driven optimization is the only way to be confident.
- **Every supported language.** "Works everywhere" applies to intelligence too — measure quality per supported localization, not just the development language (see `evaluations` coverage policy and `localization`).
- **Re-measure on change.** Any change to the prompt, model, schema, or language set means re-running the evaluation.

## Naming AI features

Name the *experience*, not the technology (see `naming-and-ux-writing.md`): people want what it does for them. Avoid names that overpromise certainty the model can't deliver, and set expectations honestly so trust survives the occasional wrong answer.

## Checklist

- [ ] Identified misuse, who is harmed, and prevention
- [ ] Safeguards in place (preview / confirm / disclaim) proportional to risk
- [ ] Right privacy boundary chosen; private data redacted before any less-private model
- [ ] Transparent about data use; asks at the right moment for only what's necessary
- [ ] Backed by an Evaluation with an optimization target, covering every supported language
- [ ] Re-evaluated after any change to prompt/model/schema/languages
- [ ] Named for the experience, sets honest expectations
- [ ] Considered cutting the feature if risk &gt; value
