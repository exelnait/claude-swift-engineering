# Multiplatform & UnionValue

> These capabilities are part of the 2026 releases and newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

This year Visual Intelligence is also available on **iPadOS** and **macOS**. Covers running the same integration across platforms, returning more than one result type with `@UnionValue`, and continuing the search inside your app with the `semanticContentSearch` schema.

## The same code runs everywhere

Your `IntentValueQuery`, your entities, and your `OpenIntent` all work across **iOS, iPadOS, and macOS** with no changes. The APIs are identical; you can build for Mac and the Image Search from `references/image-search.md` just works.

**Platform differences worth handling:**

| | Primary entry point | Typical content |
|---|---|---|
| **iOS** | Camera | Physical objects — a vinyl record, a concert poster |
| **iPadOS / macOS** | Screenshots | Digital media on screen |

- Make your search handle **both** kinds of input well (a photographed physical object and a screenshot of digital media).
- On **Mac the input pixel buffer can be much larger** than on iPhone. Consider resizing before you feature-print it, to keep the query fast.

```swift
// Optional: downscale a large captured buffer before feature-printing.
func normalized(_ pixelBuffer: CVPixelBuffer, maxDimension: CGFloat = 1024) -> CGImage? {
    var cgImage: CGImage?
    VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)  // confirm exact signature
    guard let image = cgImage else { return nil }
    // Resize with Core Image / vImage / CGContext when image dimensions are large.
    return image   // resized copy
}
```

## Returning multiple result types with `@UnionValue`

An app can have only **one** `IntentValueQuery` that accepts a `SemanticContentDescriptor`. To return more than one entity type from it, define a `@UnionValue` enum with a case per type, and give **each** entity type its own `OpenIntent`. The music app returns visually similar **albums** and, via those albums' artists, nearby **concerts**.

```swift
import AppIntents

@UnionValue
enum MusicSearchResult {
    case album(AlbumEntity)
    case concert(ConcertEntity)
}

struct MusicImageSearchQuery: IntentValueQuery {
    @Dependency var catalog: AlbumCatalog
    @Dependency var concerts: ConcertFinder

    func values(for input: SemanticContentDescriptor) async throws -> [MusicSearchResult] {
        guard let pixelBuffer = input.pixelBuffer else { return [] }

        // Match albums by image similarity first...
        let albums = try await catalog.search(pixelBuffer: pixelBuffer)
        // ...then surface a DIFFERENT kind of result from that context.
        let nearby = try await concerts.upcoming(forArtists: albums.map(\.artistName))

        return albums.map(MusicSearchResult.album)
             + nearby.map(MusicSearchResult.concert)
    }
}
```

You already have `OpenAlbumIntent` (see `references/image-search.md`); add the sibling:

```swift
struct OpenConcertIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Concert"
    @Parameter(title: "Concert") var target: ConcertEntity
    @Dependency var navigator: AppNavigator

    @MainActor
    func perform() async throws -> some IntentResult {
        navigator.showConcert(id: target.id)
        return .result()
    }
}
```

Be creative about the types of content you return based on context — you're not limited to pixel matches. Here, image similarity found albums, then artist names surfaced concerts, a completely different kind of result.

## Continuing the search in-app — the `semanticContentSearch` schema

If people don't see what they want in the Visual Intelligence results, give them an easy way to continue into your full search. Conform an intent to the **`semanticContentSearch` schema**. The system provides the captured content automatically — the same `SemanticContentDescriptor` (with its pixel buffer) you saw before. In `perform()`, navigate to your in-app search **pre-populated** from that input.

```swift
import AppIntents

// Conforms to the system `semanticContentSearch` schema.
// Exact declaration (schema macro/attribute path + property name) — confirm against current Apple documentation.
@AppIntent(schema: .visualIntelligence.semanticContentSearch)   // confirm exact schema path/macro
struct SemanticContentSearchIntent: AppIntent {
    // Provided automatically by the system:
    var semanticContent: SemanticContentDescriptor   // confirm exact property name/type

    @Dependency var navigator: AppNavigator

    @MainActor
    func perform() async throws -> some IntentResult {
        // Pre-populate from context — don't start from scratch.
        navigator.openFullSearch(prefillFrom: semanticContent)
        return .result()
    }
}
```

Tapping **More results** then lands people in your app's full search experience — filters, categories, the full depth of your content that the Visual Intelligence results sheet can't show. Pre-populate from the input context rather than starting blank.

## Related

- `references/image-search.md` — the base entity, `IntentValueQuery`, and `OpenIntent` this builds on.
- `app-intents-widgets` skill → `references/app-intents.md` — `OpenIntent`, `@UnionValue`, and App Intents schema fundamentals.
- `macos-multiplatform` skill — broader same-codebase-across-platforms guidance.
