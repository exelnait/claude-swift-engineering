# Model Judges (Qualitative Metrics)

> API names are from Apple's WWDC introduction of the Evaluations framework. Confirm exact signatures against current Apple documentation.

Some expectations can only be described in words: tags should be **relevant** to the book, **useful** for browsing, **informative**, **safe**. You cannot measure these in code. A **model judge** is a language model used to score your feature's output — a subjective, human-like rating applied **consistently across your entire dataset**.

A model judge is just another `Evaluator`: it conforms to the same protocol and produces the same `Metric` type, so quantitative metrics and judge metrics mix freely in one evaluation.

## When You Need One

Your quantitative metrics can all pass while the output is still wrong. Example: tags `overrated`, `pretentious`, `whodunit` for *Alice in Wonderland* — single words, valid count, one is a "genre" — every heuristic passes. But `overrated`/`pretentious` describe the *reader's feelings*, and `whodunit` is the wrong genre (the model latched onto "riddles he never answers"). The metrics give the wrong signal. A judge that can *read* the tags catches this.

## Anatomy of a Model Judge

The framework assembles most of this for you; you focus on the **scoring guide**.

| Component | What it is |
|-----------|-----------|
| **Instruction** | Tells the judge what it is doing and how to evaluate (e.g., "you will be given book reviews and the tags generated for them…"). |
| **Feature input** | The prompt given to the feature being judged (here, the book review). |
| **Feature output** | What your feature produced (the generated tags). |
| **Scoring guide** | How to score — the scale and what each level means. **This is the part you write.** |

## A Simple Model Judge

Start with a single quality dimension on a 1–4 scale.

```swift
let judge = ModelJudgeEvaluator(
    metric: Metric(name: "TagQuality"),
    model: .privateCloudCompute,            // judge model — confirm exact API
    scoreDimension: ScoreDimension(
        name: "TagQuality",
        description: "How well do the tags describe the book?",
        scale: [
            1: "Most tags are wrong or unhelpful.",
            2: "Several tags are wrong or unhelpful.",
            3: "Most tags are good; one or two are wrong or unhelpful.",
            4: "Every tag accurately and helpfully describes the book.",
        ]
    )
)
```

### Scale design

- **Use an even number of levels** (e.g., 4). An odd scale lets the judge default to a neutral middle score and tell you nothing.
- **Four levels** is usually enough distinction without diluting the meaning of each rating. Describe every level concretely.

### Choosing the judge model

> The judge should be **at least as capable as the model it is evaluating** — never weaker.

The `BookTaggingService` runs on-device (fast, local, private, per interaction). For the judge you can afford a more capable model — e.g., **Private Cloud Compute** — because it runs offline during evaluation, not in the user's hot path.

## Rationales Are Essential

A model judge returns a score **and a rationale**. The rationale is your window into *why* it scored that way — and it is what drives your next change. Always read them.

When a judge scores *Alice in Wonderland* a 3 and the rationale says it flagged `whodunit` and `detective-fiction` as irrelevant — but you also expected it to flag the opinion tags — that mismatch is the signal that your scoring guide and your intent have diverged.

## Refining a Judge: Split Broad Questions

A common failure: the first judge is **too broad** because it asks two questions at once. "Quality" was secretly "relevance AND usefulness". When you find yourself disagreeing with a score, or every sample gets the same score, **split the dimensions**.

### ScoreDimension per question

Define each thing you care about as its own `ScoreDimension`, with a precise description and a fully specified scale.

```swift
let relevance = ScoreDimension(
    name: "Relevance",
    description: """
        Each tag describes a quality, theme, or tone of the BOOK itself — \
        not small details and not the reader's personal reactions.
        """,
    scale: [
        1: "Most tags reflect reader opinions or trivia, not the book.",
        2: "Several tags reflect opinions or trivia.",
        3: "Most tags describe the book; one or two do not.",
        4: "Every tag meaningfully describes the book.",
    ]
)

let usefulness = ScoreDimension(
    name: "Usefulness",
    description: "Each tag helps someone browse a personal library and find this book.",
    scale: [ /* 1...4, each level described concretely */ ]
)
```

To author a scale, walk the example by hand: for each tag decide good/bad against the dimension, then map the result to a level (all good → 4 on a 1–4 scale). Repeat for each level so the judge can reproduce your judgement.

Add multiple dimensions to one judge:

```swift
let judge = ModelJudgeEvaluator(
    metric: Metric(name: "TagQuality"),
    model: .privateCloudCompute,
    scoreDimensions: [relevance, usefulness]
)
```

Now, instead of one muddy "Quality" score, you get **Relevance** (what kind of tag is wrong) and **Usefulness** (how the wrong tags fail at browsing) — two rationales that separate the diagnosis and point to distinct fixes.

## Give the Judge App Context: ModelJudgePrompt

Dimensions tell the judge *what* to measure but not *how to think about your app*. Without context, a judge might treat a reader's criticism as a valid book descriptor — it has no way to know Book Tracker is a personal library, not a review platform. `ModelJudgePrompt` supplies that context.

```swift
let prompt = ModelJudgePrompt(
    instructions: """
        You are evaluating tags generated for books in a personal library app. \
        Tags help the owner organize and browse their own collection. \
        They are not public reviews.
        """,
    evaluationTarget: .tags,          // how to format the thing being judged
    reference: sample.expected        // expectedTags, for the judge to compare against
)
```

- **instructions** — what the app is and what "good" means in its context.
- **evaluationTarget** — formats the feature output for the judge.
- **reference / expectedTags** — the sample's `expected` values, so the judge can compare against an ideal.

See Apple's documentation for the full `ModelJudgePrompt` surface.

## Per-Language Judging

A judge evaluates in the language of the input. For multilingual coverage (REQUIRED — see `datasets.md`):

- Make sure the judge model supports each evaluated language, and that the **scoring guide and instructions make sense in that language's context** (tag conventions and tone differ across cultures).
- Aggregate judge scores **per language** so a weak locale is visible, exactly as with quantitative metrics.

## Aligning the Judge With Your Judgement

The goal of a judge is to stand in for *you* across the whole dataset. When the judge's score disagrees with how you would have scored, that is not a dead end — it is the refinement loop:

1. **Scores all the same?** Your question is too broad → split into dimensions.
2. **Can't isolate the problem?** Split further or sharpen the descriptions.
3. **Judge misunderstands your app?** Add context via `ModelJudgePrompt`.

Iterate until the judge reliably reproduces your judgement; then it can scale to thousands of samples in your place. From there it feeds the same hill-climbing loop as quantitative metrics (see `evaluation-driven-development.md`), now powered by qualitative signal.
