# Quantitative Metrics

> API names are from Apple's WWDC introduction of the Evaluations framework. Confirm exact signatures against current Apple documentation.

Quantitative metrics measure traits you can compute in **code**. They are heuristics — rules of thumb — and they are where you should start, because they are cheap, deterministic to evaluate, and fast.

> **The rule of thumb:** if you can measure it in code, it is *quantitative* (use `Evaluator` + `Metric`). If you can only describe it in words, it is *qualitative* (use a `ModelJudgeEvaluator` — see `model-judges.md`).

## Metric

A `Metric` is a named measurement you track across the evaluation.

```swift
static let tagCount  = Metric(name: "TagCount")   // pass/fail: is the count in range?
static let tagTotal  = Metric(name: "TagTotal")   // score: how many tags were generated?
```

## Evaluator

An `Evaluator` takes a closure that receives the feature's output for **one sample** and returns a measurement for a metric. It runs once per sample.

### Pass / fail measurement

```swift
Evaluator(metric: Self.tagCount) { output in
    let count = output.tags.count
    return (3...8).contains(count) ? .pass : .fail
}
```

### Scoring measurement

Instead of pass/fail, record a numeric value — useful for distributions and trends.

```swift
Evaluator(metric: Self.tagTotal) { output in
    .score(Double(output.tags.count))   // record the actual count
}
```

Pairing the two — a pass/fail "in range" metric *and* a scoring "how many" metric — lets you check both **range compliance** and the **distribution** of generated tags. The distribution is what reveals subtle behavior (e.g., "after my change the service always generates exactly 8 tags").

## More Heuristic Examples

Heuristics are simple, direct checks. A few patterns:

**No multi-word tags** (each tag should be a single token, for the UI):

```swift
Evaluator(metric: Self.singleWordTags) { output in
    output.tags.allSatisfy { !$0.contains(" ") } ? .pass : .fail
}
```

**Contains a known literary genre** (compare against a known set):

```swift
Evaluator(metric: Self.containsGenre) { output in
    let knownGenres = BookTaggingService.knownGenres
    return output.tags.contains(where: { knownGenres.contains($0) }) ? .pass : .fail
}
```

**Does not echo the book title as a tag, exact-match against `expected`, length bounds, regex shape** — all are good heuristic candidates. If you can express the expectation as code, make it a quantitative metric.

## Aggregating Across Samples

`Evaluator`s see one sample at a time. To extract trends, summarize in `aggregateMetrics(using:)`.

```swift
func aggregateMetrics(using results: MetricResults) -> [AggregateMetric] {
    [
        // Ratio of samples with the correct tag count (your optimization-target metric).
        results.average(of: Self.tagCount),

        // Distribution of how many tags were generated.
        results.distribution(of: Self.tagTotal),

        results.average(of: Self.singleWordTags),
        results.average(of: Self.containsGenre),
    ]
}
```

- **`average`** of a pass/fail metric → the ratio of passing samples. This is what you assert an optimization target against (`#expect(value >= 0.80)`).
- **`distribution`** / summary statistics of a scoring metric → reveals patterns a single average hides.
- Remember to aggregate **per language** for any AI/FM feature (see `datasets.md` → Per-Language Coverage). A global average can hide a failing locale.

## What Good Quantitative Coverage Looks Like

For the book-tagging example, a handful of heuristics already cover several expectations:

| Expectation | Metric(s) | Type |
|-------------|-----------|------|
| Correct number of tags | `TagCount` (range) + `TagTotal` (distribution) | pass/fail + score |
| Tags are single words | `SingleWordTags` | pass/fail |
| Identifies a known genre | `ContainsGenre` | pass/fail |

Each metric maps to an expectation, and each expectation traces back to a change you made to the feature. The remaining expectations — "tags are *relevant*", "*useful* for browsing", "*informative*" — cannot be measured in code. Those need a model judge (`model-judges.md`).
