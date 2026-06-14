---
name: evaluations
description: Use when measuring the QUALITY of intelligent features powered by Foundation Models / language models (or any stochastic system — classifiers, regression) with Apple's Evaluations framework. Covers datasets (ModelSample), quantitative metrics (Evaluator/Metric), qualitative metrics (model judges, ScoreDimension), Swift Testing integration, and evaluation-driven (hill-climbing) development — including running evaluations for EVERY supported language and EVERY AI/FM feature.
---

# Evaluations

Apple's Evaluations framework measures the quality of intelligent features so you can ship them with confidence. It is the testing discipline for probabilistic software: the companion to `foundation-models` (build the feature) and `swift-testing` (test deterministic code).

## Why Evaluations (Not Unit Tests)

Generative AI breaks the contract that traditional testing relies on: **the same input can produce different outputs**. A unit test assumes one input → one fixed output, so it cannot verify a probabilistic feature. Unverified behavior erodes customer trust — intelligent features must be safe, trustworthy, and reliable like any other feature.

An **evaluation** measures how well an intelligent feature performs against your expectations, across many samples, so you can answer:

- How often does the feature produce unexpected results?
- How often does an agent take an unexpected path?
- Under what circumstances does the feature produce unsafe results?

> **Rule of thumb:** If a behavior is deterministic and you can assert one exact output → write a Swift Testing unit test (`swift-testing` skill). If the behavior is probabilistic (any Foundation Models / language-model / classifier output) → write an **Evaluation**.

## Newly Introduced Framework — Verify the API

The Evaluations framework was introduced at WWDC (2026) and is newer than your training data. The type and method names below come from Apple's introduction and are correct in spirit, but **before writing code, confirm the exact API surface and the minimum deployment target for `import Evaluations` against current Apple documentation** (use the Sosumi MCP server, Xcode, or developer.apple.com). This plugin targets iOS 26+; do not add `@available` guards for OS versions earlier than the plugin's baseline.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.** It is better to have the context than to miss a pattern.

| Reference | Load When |
|-----------|-----------|
| **[Getting Started](references/getting-started.md)** | Building your first `Evaluation`, the 5-step process, Swift Testing integration (`.evaluates` trait), reading the Xcode evaluation report |
| **[Datasets](references/datasets.md)** | Building `ModelSample` datasets, expected values, dataset variety, `SampleGenerator`, and per-language / multilingual coverage |
| **[Quantitative Metrics](references/quantitative-metrics.md)** | `Metric`, `Evaluator`, pass/fail vs scoring metrics, `aggregateMetrics(using:)`, heuristic (code-measurable) checks |
| **[Model Judges](references/model-judges.md)** | `ModelJudgeEvaluator`, scoring guides, `ScoreDimension`, `ModelJudgePrompt`, rationales, choosing a judge model, refining a judge |
| **[Judge Alignment & Comparative Evals](references/judge-alignment.md)** | Drift, measuring alignment with Cohen's kappa, aligning a judge to your expert ratings, comparing two evaluations (control vs experimental), tool-call evaluators |
| **[Evaluation-Driven Development](references/evaluation-driven-development.md)** | Hill-climbing loop, optimization targets, best practices, and the coverage policy (every language, every AI/FM feature) |

## The Five Steps of an Evaluation

1. **Define the subject** — what code you are measuring (`subject(from:)` returns the feature's output for a sample).
2. **Define the data** — the input samples you send (`ModelSample`, with optional `expected` ideal output).
3. **Define the measurements** — `Metric`s, measured by `Evaluator`s, one sample at a time.
4. **Summarize** — `aggregateMetrics(using:)` extracts trends across all samples.
5. **Run it** — a Swift Testing `@Test` with the `.evaluates` trait, asserting against an optimization target.

## Two Kinds of Metric

| Kind | Tool | Use when |
|------|------|----------|
| **Quantitative** (heuristic) | `Evaluator` + `Metric` | You can measure the trait in code — count, range, contains, matches a known set. Start here. |
| **Qualitative** (subjective) | `ModelJudgeEvaluator` + `ScoreDimension` | You can only describe the trait in words — "relevant", "useful", "informative", "safe". A model judge applies a consistent human-like judgment across the whole dataset. |

Both conform to the same `Evaluator` protocol and produce the same `Metric` type, so you can mix them freely in one evaluation.

## Coverage Policy (REQUIRED)

These two rules are non-negotiable for this plugin. See `evaluation-driven-development.md` for the full policy.

1. **Every intelligent feature ships with an Evaluation.** Any feature that calls a Foundation Models / language model or any other stochastic system (classifier, ranker, regression) must have an evaluation with an optimization target. A deterministic unit test alone is not sufficient coverage for AI/FM behavior.
2. **Every supported language is evaluated.** Foundation Models behave differently per language. The dataset must include samples for **each localization the app ships** (see the app's String Catalogs / `localization` skill), and quality must be aggregated and asserted **per language** — not just in the development language. A feature that passes in English can silently fail in German, Japanese, or Arabic. See `datasets.md` → "Per-Language Coverage".

3. **Keep evaluations in sync with the feature.** An evaluation is not write-once. Whenever the prompt, the `@Generable` schema, the model, the set of supported languages, or your expectations change, **update the existing evaluation and re-run it** before shipping — don't leave it stale. A green evaluation against an outdated dataset is a false signal. (Skills are passive: this only happens when the work re-activates the skill/`@evaluation-engineer`, so treat any change to an AI/FM feature as a trigger to revisit its evaluation.)

## Core Workflow

1. Spec the feature: list the behaviors you expect (the human evaluation you already do by eye).
2. Build a small, varied dataset (20–30 samples to start) covering genres/lengths/forms **and every supported language**.
3. Add quantitative metrics for everything you can measure in code.
4. Add model-judge metrics for the qualitative traits, starting with one `ScoreDimension`.
5. Run, read the report and the judge rationales, change the feature/prompt, re-run — **hill-climb**.
6. Lock the behavior with an optimization target in a `@Test` so regressions fail CI.

## Common Mistakes

1. **Treating AI features like deterministic code** — Writing only unit tests for a Foundation Models feature gives false confidence. Probabilistic output needs an evaluation measured over many samples, not a single asserted string.

2. **Evaluating only in the development language** — Passing in English says nothing about the app's other locales. Include and aggregate per supported language, or you ship unverified behavior to most of your users. (See Coverage Policy.)

3. **A dataset that is too small or too uniform** — Two happy-path samples cannot reveal trends. Aim for many samples spanning genres, lengths, forms, personal opinions, and languages. Use `SampleGenerator` to scale.

4. **A model judge question that is too broad** — Asking one dimension to judge two things ("relevant AND useful") produces flat, unhelpful scores. If you disagree with a judge or all scores look the same, **split the dimensions**.

5. **Ignoring rationales** — A judge's numeric score is only half the signal. The rationale tells you *why* and is what drives your next change. Always read them.

6. **A judge weaker than the model being evaluated** — The judge should be at least as capable as the model it judges. Evaluate an on-device feature with a more capable judge (e.g., Private Cloud Compute), never a weaker one.

7. **No optimization target** — Without a threshold (e.g., "correct 80% of the time") in a `@Test`, the evaluation cannot fail CI and regressions slip through. Pick a target and assert against the aggregate value.
