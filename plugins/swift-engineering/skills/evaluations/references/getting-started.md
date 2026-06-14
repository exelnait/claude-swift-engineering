# Getting Started with Evaluations

> API names are from Apple's WWDC introduction of the Evaluations framework. Confirm exact signatures and the minimum deployment target against current Apple documentation before relying on them.

## The Mental Model

You already evaluate intelligent features by eye: you read the output, compare it to a list of expectations, and judge how well it did. An `Evaluation` automates exactly that — at scale, consistently, across thousands of samples — because human judgement does not scale.

Every evaluation answers one question: **how well does this feature perform against my expectations?**

## The Five Steps

```
1. subject(from:)        → what code am I measuring?
2. dataset               → what data do I send it?
3. metrics + Evaluator   → what do I measure, and how?
4. aggregateMetrics      → summarize trends across all samples
5. @Test(.evaluates)     → run it and assert an optimization target
```

## A First Evaluation

The running example is a `BookTaggingService` that generates tags for a book review. The first expectation: it should generate the **correct number of tags** (between 3 and 8).

```swift
import Evaluations
import FoundationModels

struct BookTaggingEvaluation: Evaluation {

    // STEP 1 — Define the subject: the code under measurement.
    // Returns the feature's output for a single sample.
    func subject(from sample: ModelSample) async throws -> [String] {
        try await BookTaggingService().tags(for: sample.input)
    }

    // STEP 2 — Define the data: the input samples.
    var dataset: [ModelSample] {
        [
            ModelSample(
                input: prideAndPrejudiceReview,
                expected: ["romance", "classic", "satire", "regency"]
            ),
            ModelSample(
                input: draculaReview,
                expected: ["gothic", "horror", "classic", "epistolary"]
            ),
        ]
    }

    // STEP 3 — Define the measurements (see quantitative-metrics.md).
    static let tagCount = Metric(name: "TagCount")

    func evaluators() -> [some Evaluator] {
        Evaluator(metric: Self.tagCount) { output in
            let count = output.tags.count
            return (3...8).contains(count) ? .pass : .fail
        }
    }

    // STEP 4 — Summarize across all samples.
    func aggregateMetrics(using results: MetricResults) -> [AggregateMetric] {
        [results.average(of: Self.tagCount)]   // ratio of passing samples
    }
}
```

- `expected` is the *ideal* output you would like to see. It is optional for pass/fail heuristics, but essential for model judges and for sentence-completion–style comparisons (see `datasets.md`).
- `Evaluator`s run over **one sample at a time**. Trends across all samples live in `aggregateMetrics(using:)`.

## Running an Evaluation with Swift Testing

The Evaluations framework integrates with Swift Testing, so evaluations run in your app's test targets alongside unit tests.

```swift
import Testing
import Evaluations

@Suite
struct BookTaggingTests {
    let evaluation = BookTaggingEvaluation()

    // Notes record the configuration under evaluation, so you can compare runs later.
    let notes = [
        "model": "on-device",
        "instructions": "v3",
    ]

    @Test(.evaluates(BookTaggingEvaluation(), notes: notes))
    func tagCountMeetsTarget() async throws {
        let results = try await EvaluationResults.current

        // Assert against the OPTIMIZATION TARGET.
        let average = results.aggregateValue(for: BookTaggingEvaluation.tagCount)
        #expect(average >= 0.80)   // correct number of tags ≥ 80% of the time
    }
}
```

### Why an optimization target?

`#expect(average >= 0.80)` is your **optimization target**: the threshold at which you consider the feature good enough to ship. If quality dips below it, the test fails and you get a clear signal. Pick the target deliberately — see `evaluation-driven-development.md`.

### Notes

Attach a `notes` dictionary (model, prompt version, dataset version, language set, …) to each run. When you compare runs over time, notes tell you *what changed*.

## The Evaluation Report

A `@Test` pass/fail is the automated gate; the **evaluation report** is where you dig in.

1. Run the test.
2. Open the **Report navigator** in Xcode → select **Evaluations** in the test report.
3. Double-click a row to expand a metric — e.g. "TagCount passed 50% of the time".
4. The results table shows each sample's outcome (which passed, which failed).
5. Select a row to open the detail panel (assistant editor): the **prompt**, **each measurement** for that `ModelSample`, and the **full model response** at the bottom.

Use the report to form hypotheses about *why* a sample failed, then change the feature and re-run. That loop is evaluation-driven development.

## Beyond Language Models

This skill focuses on language-model features, but the framework evaluates **any stochastic system** — classifiers, rankers, linear-regression models. The same `Evaluation` / `Metric` / `Evaluator` types apply: define the subject (your model's output), a dataset, metrics, and an optimization target.
