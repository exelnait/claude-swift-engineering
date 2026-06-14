# Evaluation-Driven Development

> API names are from Apple's WWDC introduction of the Evaluations framework. Confirm exact signatures against current Apple documentation.

When you center your development process on the evaluation feedback loop, you are doing **evaluation-driven development (EDD)**. Evaluations are not a one-time check before shipping — they are the loop you develop inside.

## The Hill-Climbing Loop

```
        ┌──────────────────────────────────────────────┐
        │                                                │
        ▼                                                │
  Run evaluation  →  Read report + rationales  →  Form a hypothesis
        ▲                                                │
        │                                                ▼
        └──────────  Change the feature  ◄────  Make ONE targeted change
                     (prompt, @Guide, instructions, model)
```

1. **Run** the evaluation; check the optimization target and read the report.
2. **Analyze** — which samples failed, and *why*? Read judge rationales and per-sample details.
3. **Hypothesize** a change that should improve the metric.
4. **Change one thing** — a prompt, a `@Guide` constraint, instructions, the model.
5. **Re-run** and compare against the previous run (this is why you record `notes`).

This incremental "make it a little better each pass" process is **hill-climbing**.

### Worked example

- *Observation:* `TagCount` passes only 50% — *Pride & Prejudice* produced 9 tags.
- *Hypothesis:* the `@Generable` type lacks a count constraint.
- *Change:* add `@Guide(.count(3...8))` to the `tags` property of the `@Generable` `BookTags`.
- *Re-run:* `TagCount` now passes 100%.
- *New observation from the distribution metric:* the service now always returns exactly 8 tags — a new behavior worth investigating. The loop continues.

Each change you make should be tied to an **expectation** you added an evaluator for, so every instruction tweak is verified by a metric. That traceability — change ↔ expectation ↔ metric — is the backbone of EDD.

## Optimization Targets

The optimization target is the threshold in your `@Test` that decides "good enough to ship".

```swift
#expect(average >= 0.80)   // correct number of tags ≥ 80% of the time
```

- Choose it deliberately. "80%" means: if performance dips below 80%, I want a failing test as a signal.
- A failing test is *great signal*, not a nuisance — it is the regression alarm for probabilistic behavior.
- Targets can differ per metric and per language. A safety metric may demand a far higher bar than a stylistic one.

## Coverage Policy (REQUIRED for this plugin)

EDD only works if the evaluations actually exist and actually cover what ships.

### 1. Every AI/FM feature has an evaluation

Any feature backed by a Foundation Models / language model — or any other stochastic system (classifier, ranker, regression) — must ship with an `Evaluation` and an optimization target in a `@Test`. Deterministic unit tests are necessary but **not sufficient** for probabilistic behavior. No AI/FM feature ships without an evaluation gating it.

### 2. Every supported language is evaluated

The dataset includes samples for **each localization the app ships** (source of truth: the String Catalogs / project localizations — see the `localization` skill), and metrics are aggregated and asserted **per language**. A global average is not acceptable: it lets a strong development-language score mask a failing locale. Include RTL and non-Latin-script samples when the app ships those languages.

> Treat "passes in English" as "unverified everywhere else." The coverage policy exists because Foundation Models genuinely behave differently per language, and most of your users are not in the development language.

### 3. Evaluations run in CI

Because evaluations are Swift Testing `@Test`s, they run in the test target. Wire them into CI so a quality regression — in any metric, in any language — fails the build like any other test.

## Best Practices

From Apple's guidance, plus this plugin's policy:

1. **Start small.** A focused dataset of **20–30 samples** is a great place to begin. Grow it as you discover gaps.

2. **Spec the feature first.** Write down how you want the model to behave — that list of expectations *is* your set of metrics.

3. **Use heuristics for quantifiable traits.** If you can measure it in code, make it a quantitative `Evaluator`. These rule-of-thumb metrics are the fastest way to start understanding the feature.

4. **If you can only describe it in words, use a model judge.** Qualitative traits ("relevant", "useful", "safe") need a `ModelJudgeEvaluator`.

5. **Start simple with your judge.** Define one `ScoreDimension`, run it, and read the rationales. You will learn more from a single run than from hours of planning.

6. **Let rationales drive the next change.** The rationale, not just the score, tells you what to fix.

7. **Diagnose a stuck judge:**
   - Scores all the same → the question is too **broad**; split into dimensions.
   - Can't isolate the problem → split dimensions further / sharpen descriptions.
   - Judge doesn't understand the app → add context via `ModelJudgePrompt`.

8. **One change per loop.** Change a single variable, re-run, compare via `notes`. Multiple simultaneous changes make it impossible to attribute a score change.

9. **Cover every language and every AI/FM feature.** (See Coverage Policy.)

## Related Apple Sessions

- "Improve your prompts by hill climbing with Evaluations" — deeper on the prompt-refinement loop.
- "Create robust evaluations for agentic apps" — synthesizing large datasets and evaluating agent trajectories with `ModelSample`.
