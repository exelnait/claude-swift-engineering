# Building a Dataset

> API names are from Apple's WWDC introduction of the Evaluations framework. Confirm exact signatures against current Apple documentation.

A dataset is the set of inputs you feed the feature under evaluation. The quality of your evaluation is bounded by the quality of your dataset: two samples give you two data points and no trends. **Good evaluations have hundreds-to-thousands of samples that exercise the feature in many different ways.**

## ModelSample

Each sample wraps an input and, optionally, the ideal expected output.

```swift
ModelSample(
    input: "I couldn't put this down — a gothic masterpiece told through letters and journals.",
    expected: ["gothic", "horror", "classic", "epistolary"]
)
```

- `input` — what the feature receives (the prompt / feature input).
- `expected` — the ideal output. Two uses:
  - **Reference for model judges** — the judge compares the feature's output against `expected` (see `model-judges.md`).
  - **Direct comparison** — for sentence-completion / exact-answer evaluations, the feature output is compared directly to `expected`. These need *thousands* of examples to be effective.

> Teaching the feature your style: put more of your own voice into the `expected` values. The expected output is how you tell the feature what "good" looks like.

## Design for Variety

A dataset of near-identical happy-path inputs hides bugs. Deliberately vary:

| Dimension | Why it matters |
|-----------|----------------|
| **Genre / category** | The feature must recognize fiction, non-fiction, and the categories users browse by. |
| **Length** | Not every user writes a verbose review — include one-sentence and multi-paragraph inputs. |
| **Form** | Novels, short stories, essays, etc. produce different signals. |
| **Personal opinion / noise** | Sprinkle in subjective opinions so you can measure how well the feature *ignores* them and describes the content itself. |
| **Difficulty** | Include inputs deliberately designed to trip the model (ambiguous wording, misleading vocabulary). |
| **Language / locale** | See "Per-Language Coverage" below — REQUIRED. |

Concrete examples of variety: an avid-gardener's review of *The Secret Garden*; a parent's opinion-heavy review of *Treasure Island* read aloud to a child; a board-game enthusiast's multi-paragraph review of *Romance of the Three Kingdoms*; a casual reader's single sentence about a detective's sidekick. Each stresses a different behavior.

## Per-Language Coverage (REQUIRED)

Foundation Models behave differently across languages — tag vocabulary, tone detection, and even the "unsupported language" guardrail vary. **A feature that passes in the development language can silently fail in others.** This plugin requires that evaluations cover every language the app ships.

### 1. Enumerate the app's supported languages

Use the app's localizations as the source of truth — the languages in the String Catalog (`.xcstrings`) / project localizations. See the `localization` skill. Do not guess; evaluate exactly what you ship.

### 2. Put samples in every supported language

Each supported locale needs its own samples (ideally native-written, not machine-translated, so they reflect real user input), with `expected` values in that language's conventions.

```swift
enum Language: String, CaseIterable {
    case en, de, ja, ar   // mirror the app's String Catalog localizations
}

struct LocalizedSample {
    let language: Language
    let sample: ModelSample
}
```

### 3. Aggregate and assert PER language

Do not collapse all languages into one global average — a strong English score can mask a failing locale. Compute the metric **per language** and assert the target for each.

```swift
// Tag the metric value with the sample's language, then aggregate per language.
func aggregateMetrics(using results: MetricResults) -> [AggregateMetric] {
    Language.allCases.map { language in
        results.average(of: Self.tagCount, where: { $0.language == language })
            .named("TagCount-\(language.rawValue)")
    }
}
```

```swift
@Test(.evaluates(BookTaggingEvaluation(), notes: ["languages": "en,de,ja,ar"]))
func tagCountMeetsTargetInEveryLanguage() async throws {
    let results = try await EvaluationResults.current
    for language in Language.allCases {
        let average = results.aggregateValue(for: "TagCount-\(language.rawValue)")
        #expect(average >= 0.80, "TagCount below target for \(language)")
    }
}
```

> Parameterizing the dataset by language (or running one `@Test` per language) makes the report show each locale separately, so a regression in a single language is immediately visible.

### 4. Cover RTL and non-Latin scripts explicitly

Include at least one right-to-left language (e.g. Arabic, Hebrew) and one non-Latin script (e.g. Japanese, Chinese, Korean) if the app ships them. These surface tokenization and formatting issues Latin-script samples never will. See the `localization` skill's `rtl-support.md`.

## Scaling with SampleGenerator

Hand-authoring thousands of samples does not scale. `SampleGenerator` synthesizes more samples from a seed set, using a model of your choice.

```swift
let seeds: [ModelSample] = [ /* your hand-written, varied, multilingual seeds */ ]

let generator = SampleGenerator(model: .privateCloudCompute)   // confirm exact API
let synthesized = try await generator.generate(from: seeds, count: 500)

let dataset = seeds + synthesized
```

Guidance:
- **Seed with variety**, including every supported language — the generator amplifies whatever distribution you give it. Biased seeds → biased synthetic data.
- Keep your hand-written, high-signal samples; synthetic data augments them, it does not replace them.
- For advanced dataset synthesis and agentic-app samples, see Apple's "Create robust evaluations for agentic apps" session.

## Start Small

You do not need thousands of samples on day one. A focused dataset of **20–30 samples** (spanning your key variety dimensions and languages) is a great place to start understanding the feature. Grow it as you hill-climb and discover gaps.
