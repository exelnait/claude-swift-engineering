# Local RAG with SpotlightSearchTool

> These capabilities are part of the 2026 releases and newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

`SpotlightSearchTool` is a Foundation Models `Tool` (adopts the `Tool` protocol — see `tool-calling.md`) that lets a language model **search your app's Core Spotlight index** to ground its responses in the user's own content — fully **private, on-device RAG**, no server. This is the in-depth reference that `vision-and-system-tools.md` points to. Available on **iOS, iPadOS, macOS, and visionOS**.

Instead of writing a query yourself, you hand the model the tool; it decides *when* to search, generates the query, and reasons over the results.

## Prerequisite: donate content to Core Spotlight

The tool searches whatever your app has indexed. Before adopting it, donate searchable content — `CSSearchableItem`s (or **indexed entities for Apple Intelligence**) — to Core Spotlight, ideally with the semantic index enabled. See Apple's **"Supporting semantic search with Core Spotlight"** for donating items, managing donations with a delegate + reindex extension, and structured/semantic search over item attributes.

## Configure & attach

```swift
import CoreSpotlight
import FoundationModels

// Default: search the app's Core Spotlight index in one line.
let tool = SpotlightSearchTool()   // confirm exact initializer against current Apple documentation

// Or supply a custom configuration — here, a FileSource to search file paths
// in the app's sandbox.
let tool = SpotlightSearchTool(
    configuration: .init(source: FileSource())
)   // configuration + FileSource shapes — confirm exact API against current Apple documentation

// Attach to a session on the model of your choice — SystemLanguageModel, or
// another model via the Model Provider APIs (see model-selection.md).
let session = LanguageModelSession(model: SystemLanguageModel(), tools: [tool])

let answer = try await session.respond(to: "What hikes have I gone on?")
```

**Response trajectory.** For a prompt like *"What hikes have I gone on?"*:

1. The model decides it needs `SpotlightSearchTool`.
2. It generates a query and invokes the tool.
3. Spotlight executes the query and returns a **description of the result set**.
4. The model reasons over that output and generates its final, grounded response.

## Recover full items for the model

Some indexed metadata (free **text** and **HTML**) is stored in a highly compact form that can be *searched* but **not read back** in a way the model can read. To let the model reason over the full record, implement the new index-delegate method to return the complete `CSSearchableItem` by identifier — and attach extra attributes useful to the model that you wouldn't normally donate for search.

```swift
extension TrailIndexDelegate: CSSearchableIndexDelegate {
    // New for SpotlightSearchTool: return the full item(s) by unique identifier.
    func searchableItems(forIdentifiers identifiers: [String]) -> [CSSearchableItem] {
        // confirm exact delegate signature against current Apple documentation
        identifiers.compactMap { store.item(for: $0) }.map { item in
            item.attributeSet.contentDescription = store.notes(for: item)   // model-only context
            return item
        }
    }
}
```

This scales to millions of results — the model pulls back only the items it needs.

## Display results

Two surfaces, two data sources:

- **Assistant-style UI** → the **session response** is a concise summary over the result set. Display `answer.content`.
- **List-style UI** → the **actual `CSSearchableItem`s** are delivered by the tool itself via **search replies**: an async sequence of batches produced while the search runs (best when the result set is large).

```swift
Task {
    for await reply in tool.searchReplies {   // confirm exact async-sequence API against current Apple documentation
        let items = reply.content.compactMap { $0 as? CSSearchableItem }
        // The model may call the tool MORE THAN ONCE per response. Use the
        // per-reply queryToken to decide when to refresh (vs. append to) the UI.
        refresh(items, for: reply.queryToken)
    }
}
```

## Customization

The tool exposes a broad capability set — semantic search over text, plus structured search over dates, persons, locations, and more. Depending on the model (especially on-device, limited-context models), scope and augment it.

### Guidance profiles — scope the capabilities

By default the model is guided on the **entire** capability set. A `GuidanceProfile` narrows that guidance to what your app needs (the hiking app donates no person relationships, so author/recipient guidance can be skipped), and can name the exact **metadata attributes** the model should consider. Pair it with a **dynamic guide level** — use focused guidance for smaller models with restricted context.

```swift
let profile = GuidanceProfile(
    capabilities: [.dates, .locations],   // enable; omit .people
    attributes: [/* the exact metadata attributes the model should consider */]
)   // GuidanceProfile shape + capability/attribute names — confirm exact API against current Apple documentation

let tool = SpotlightSearchTool(guidanceProfile: profile, guideLevel: .focused)
//                              dynamic guide level — confirm exact API against current Apple documentation
```

### Reference resolution — a contact resolver

When a prompt says *"that person"* or *"who I hiked with"*, the model needs to know who is meant. Supply a **`contactResolver`** that returns contact information tied to the user's identity, which the tool matches against person metadata in the index.

```swift
let tool = SpotlightSearchTool(
    contactResolver: { reference in
        try await contacts.resolve(reference)   // return matching contact info for the reference
    }
)   // contactResolver signature — confirm exact API against current Apple documentation
```

### Custom pipeline stages — compute over the result set

For complex requests the model can run a **pipeline search**: index queries **plus computation** over the result set, for maximal efficiency. Asked *"how many trails this year, and average miles per month?"*, the model can generate a search stage, a **counting** stage that builds a per-month table, then an **averaging** stage — instead of tallying everything in memory.

Your app can register **custom stages**. Stages are `@Generable`, so the model generates one on demand from the prompt and may hand its output back to your app as a partial result. Example: a per-item **happiness score** over notes, so the model answers from the top-scoring hikes rather than guessing.

```swift
// Output is @Generable — @Guide hints tell the model which results to prefer.
@Generable
struct ScoredTrail {
    let itemIdentifier: String
    @Guide(description: "0-1 sentiment over the hike's notes; prefer higher")
    let happiness: Double
}

// A stage maps a CSSearchableItem to scored output. Compute the score any way
// you like — sentiment analysis over the `notes` attribute, a boost for 5-star
// hikes, other custom logic.
struct HappinessStage: SpotlightSearchStage {          // confirm exact stage protocol against current Apple documentation
    func run(_ item: CSSearchableItem) async -> ScoredTrail { /* ... */ }
}

// Register stages on the tool's configuration.
let tool = SpotlightSearchTool(configuration: .init(stages: [HappinessStage()]))
//                                             stage registration — confirm exact API against current Apple documentation
```

Stage output also flows back through **search replies** — aggregate counts, tables, free-form text, or computed numeric values — and each such reply carries an **LLM-generated label** describing the content, giving your UI maximum flexibility over what to display.

## Evaluate the experience

Because so much is tunable — model, donated content, guidance profile, custom stages — verify quality with the **Evaluations framework** rather than by eye. A useful metric here is **result coverage**: given items indexed in Spotlight, how well does the model ground its answer in the items you *expect* it to find?

```swift
struct TrailRequest: ModelSampleProtocol {   // vs. ModelSample — see the `evaluations` skill
    let input: String                         // e.g. "Which hikes made me happiest?"
    let expectedItemIdentifiers: [String]     // items the tool should surface
    // ...expected response + expected trajectory (should include a SpotlightSearchTool call)
}
```

Expect the response **trajectory to include a `SpotlightSearchTool` call**, then score how many `expectedItemIdentifiers` made the final response. Use sample-generation APIs to expand a small seed set into broad coverage of how people phrase questions.

→ See the **`evaluations`** skill: `datasets.md` (`ModelSample`, expected values, `SampleGenerator`), `judge-alignment.md` (tool-call / trajectory evaluators), and `quantitative-metrics.md` (a custom coverage `Metric`). Follow the coverage policy — evaluate **every supported language**.

## Related

- `tool-calling.md` — the `Tool` protocol this adopts.
- `vision-and-system-tools.md` — other system tools (`OCRTool`, `BarcodeReaderTool`) and where this tool is introduced.
- `model-selection.md` — choosing the backing model (`SystemLanguageModel` / Model Provider APIs).
- `evaluations` skill — measuring response quality with tool calls.
