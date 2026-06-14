# Judge Alignment, Drift & Comparative Evaluations

> API names are from Apple's WWDC introduction of the Evaluations framework. Confirm exact signatures against current Apple documentation.

A model judge is only trustworthy if it scores the way *you* would. This reference covers how to measure and improve that — and how to hill-climb prompts/features scientifically with comparative evaluations. Read after `model-judges.md` and `evaluation-driven-development.md`.

## Drift: when the judge and you disagree

**Drift** is the divergence between a model judge's ratings and an expert's (yours). It's faced by everyone evaluating intelligent features:

- Have a judge and a person each rate the same samples on, say, 1–4.
- If they systematically disagree, their averaged aggregate scores diverge.
- **As the dataset grows, drift widens** — and you lose the ability to trust the judge's signal.

A passing test does not mean the judge is right. In the video, every quantitative expectation passed, yet the tags were poor and the judge over-scored *usefulness* (gave 4 where the expert gave 2). The fix is to **align the judge to your expert opinion**, then keep it aligned as the dataset grows.

## Measuring alignment: accuracy vs Cohen's kappa

**Accuracy** = the percentage of samples where judge and expert match.

- Fine *only* if every value on the scale is equally likely.
- Real datasets are skewed (they often contain mostly high-quality examples, so humans rate high). A judge that just tends to score high will *look* aligned on a small, high-scoring set — then drift badly on a larger, more varied one.

**Cohen's kappa** accounts for the skew and for lucky agreement:

```
            accuracy − chanceAgreement
kappa  =  ───────────────────────────────
                1 − chanceAgreement
```

- `chanceAgreement` (coincidence) = the probability two raters agree by luck, weighted by how likely each score is to appear.
- Interpretation: **κ ≥ 0.6 is a meaningful level of agreement** (a reasonable expectation target). Higher is stronger.

## An evaluation that measures alignment

To hill-climb alignment, write a second evaluation whose **subject is the already-generated tags** (not a fresh feature call) and whose **evaluator is the same `ModelJudgeEvaluator`** — then compare the judge's scores against your expert ratings.

Four parts:

1. **Dataset** — the judge and you must rate the *exact same* items. Reuse a prior run: Xcode attaches the full evaluation data to the test run; extract the (summary, tags) pairs, then **add your expert ratings** to each. Pass that file as the evaluation input.
2. **Subject** — just return the already-generated tags (they're part of the dataset).
3. **Evaluators** — the same model-judge evaluator used in the feature's evaluation (this is where the judge re-rates).
4. **Aggregate** — a **custom aggregation** computing **Cohen's kappa** per score dimension, plus the **mean and standard deviation** of each dimension (so you can see if scores trend up/down).

```swift
@Test(.evaluates(JudgeAlignmentEvaluation(), notes: ["judgePrompt": "v2"]))
func judgeIsAligned() async throws {
    let results = try await EvaluationResults.current
    #expect(results.aggregateValue(for: "kappa-relevance")  >= 0.6)
    #expect(results.aggregateValue(for: "kappa-usefulness") >= 0.6)
}
```

If the test fails, analyze in the evaluation report (low κ ⇒ misalignment), open the assistant to find samples where you and the judge diverge most, and form a hypothesis.

## Aligning the judge (hill-climbing the judge)

The judge usually misaligns because it **lacks context** to tell a good answer from a bad one. Improve it incrementally:

1. **Add app context to the judge prompt** — what the feature is for, what "good" means in this app.
2. **Give examples of good and bad** outputs in the prompt.
3. **Sharpen each `ScoreDimension`** — more specific descriptions (e.g., relevance must include a genre tag; usefulness must be critical of overly specific tags).
4. **Add a few worked examples of *your* scoring** so the judge learns your scale.

> **Avoid overfitting:** give only a *few* examples. A long example list inflates the alignment score and hides whether the judge is genuinely aligned. Keep comparisons fair.

Once κ clears your target, you can trust the judge to stand in for you across a growing dataset — models rate far faster than humans, so an aligned judge scales your judgement.

## Comparative evaluations (treat each change as an experiment)

To know whether a change helped, compare it against a baseline like a science experiment:

- **Control** = the baseline prompt/feature. **Experimental** = the one change you're testing.
- **Change exactly one variable** between them. If you carry forward a previous improvement, apply it to *both* so only the new variable differs.
- Add **both** evaluations to one test suite and run them together.
- Use Xcode's **comparison view** in the evaluation report (Xcode 27) to view the two side by side — drill into the dimension you're optimizing (e.g., usefulness) and find the samples that diverge most.

Expect trade-offs: a change can raise relevance while lowering usefulness. Decide deliberately which to keep, then focus the next iteration on the other. **Failed experiments are informative too** — they tell you what doesn't move the metric.

## Evaluating tool usage & dataset coverage

- A small dataset is not enough — 13 review/tag pairs can't cover the variety real users submit. Use the **`SampleGenerator`** API to synthesize a wider range of cases (see `datasets.md`), and remember the per-language coverage requirement.
- When a feature uses tools (e.g., a book-info lookup tool to ground tags), you need to verify the tool is **called in the right situations**, not just that output improved. The framework provides **tool-call evaluators** for this. See Apple's "Create robust evaluations for agentic apps".

## Recap

1. **One change at a time** — isolate variables so you understand each part's contribution.
2. **It takes time** — not every change helps; failed experiments still teach you.
3. **Be creative** — everything is fair game: instructions, tools, model(s); and on the eval side, the dataset, aggregation methods, and evaluators themselves.
4. **Watch for drift** — a well-tuned, aligned judge saves time as your dataset grows. Evaluate your evaluators.
