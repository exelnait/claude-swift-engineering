# Image Search — returning app content into Visual Intelligence

> These capabilities are part of the 2026 releases and newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

Image Search leverages both the **App Intents** and **Visual Intelligence** frameworks. Three pieces work together: an **entity** (what you return), an **`IntentValueQuery`** (how the system asks), and an **`OpenIntent`** (where a tap lands). The example is a music app returning visually similar albums.

The `AppEntity` / `EntityQuery` / `OpenIntent` fundamentals live in the `app-intents-widgets` skill (`references/app-intents.md`); this file covers only what Visual Intelligence adds.

## 1. Define the entity

`AppEntity`s are the nouns of your app. Give it the standard default `EntityQuery` and `typeDisplayRepresentation`, the fields you display, and a `displayRepresentation` telling Visual Intelligence how to present each result.

```swift
import AppIntents

struct AlbumEntity: AppEntity {
    let id: String                 // stable catalog identifier
    let name: String
    let artistName: String
    let thumbnail: Data?           // small album-artwork bytes, not full-res

    // Standard for any App entity:
    static let defaultQuery = AlbumEntityQuery()
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Album")

    // The FIRST thing people see in the results — keep it tight.
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(artistName)",
            image: thumbnail.map { .init(data: $0) }   // confirm exact DisplayRepresentation.Image initializer
        )
    }
}

// Default EntityQuery: resolves ids back to entities (used by the OpenIntent round-trip).
// This is NOT the image-search query — that's the IntentValueQuery in step 2.
struct AlbumEntityQuery: EntityQuery {
    @Dependency var catalog: AlbumCatalog
    func entities(for ids: [AlbumEntity.ID]) async throws -> [AlbumEntity] {
        try await catalog.albums(ids: ids)
    }
}
```

**Display representation — the constraints that matter:**
- You get **about three lines of text** (title + subtitle) plus **one thumbnail**. Put the most important identifying info here (album name + artist) and nothing more.
- If you initialize the image from a URL, **serve a thumbnail-sized image**, not your full-resolution asset — results load faster.
- **Layout depends on count.** If you always return multiple results, small images look right in the two-column grid. If you return a **single** result, that image takes the **full width** of the results sheet — size it accordingly.

## 2. Implement the IntentValueQuery

An `IntentValueQuery` is a lightweight protocol that provides entity values to the system. For Visual Intelligence the key difference is the **input**: the system passes a `SemanticContentDescriptor` carrying information about the captured image. Grab its `pixelBuffer` and run your search.

```swift
import AppIntents
// SemanticContentDescriptor is provided by the Visual Intelligence / App Intents surface —
// confirm which module vends it against current Apple documentation.

struct AlbumImageSearchQuery: IntentValueQuery {
    @Dependency var catalog: AlbumCatalog

    func values(for input: SemanticContentDescriptor) async throws -> [AlbumEntity] {
        guard let pixelBuffer = input.pixelBuffer else { return [] }   // confirm exact property name/type
        return try await catalog.search(pixelBuffer: pixelBuffer)
    }
}
```

## 3. Search on device with Vision feature prints

Search on device against a local catalog using the **Vision** framework's pre-trained models. Each catalog entry stores a **feature print** — a compact numerical representation of the image usable for similarity comparison. Precompute these; only the captured image is processed at query time.

```swift
import Vision
import VideoToolbox
import CoreVideo

struct CatalogAlbum {
    let entity: AlbumEntity
    let featurePrint: FeaturePrintObservation   // precomputed  // confirm exact observation type
}

actor AlbumCatalog {
    private var catalog: [CatalogAlbum] = []

    // Precompute at import/launch — NOT per query.
    func featurePrint(for image: CGImage) async throws -> FeaturePrintObservation {
        let request = GenerateImageFeaturePrintRequest()
        return try await request.perform(on: image)   // confirm exact perform API + return type
    }

    func search(pixelBuffer: CVPixelBuffer) async throws -> [AlbumEntity] {
        // 1. Convert the captured pixel buffer to a CGImage.
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)  // confirm exact signature
        guard let queryImage = cgImage else { return [] }

        // 2. Feature print for the captured image.
        let queryPrint = try await featurePrint(for: queryImage)

        // 3. Compare to precomputed prints; keep close matches, sort, limit.
        let maxDistance: Float = 0.35     // tune empirically — drops dissimilar results
        return catalog
            .compactMap { item -> (AlbumEntity, Float)? in
                guard let d = try? queryPrint.distance(to: item.featurePrint) else { return nil } // confirm exact distance API
                return d <= maxDistance ? (item.entity, d) : nil
            }
            .sorted { $0.1 < $1.1 }        // most similar first
            .prefix(10)                    // LIMIT — keep results relevant
            .map(\.0)                      // empty array is fine; the system shows an empty state
    }
}
```

Principles that hold whether you search on device or hit a server: **return fast, ranked results**; **precompute** the catalog side; **limit** the count; **empty is valid**.

**Beyond feature prints:** Vision also does OCR (extract text), barcode scanning, face detection, and image classification — useful for extending visual search (e.g. read a poster's text, scan a record's barcode). For the Foundation Models `OCRTool` / `BarcodeReaderTool` wrappers, see the `foundation-models` skill (`references/vision-and-system-tools.md`).

## 4. Open the tapped result

When someone taps a result, the system calls your `OpenIntent` with the selected entity. Take them straight to that content. **Reuse an existing open-intent** if you have one — you don't need a Visual Intelligence-specific one.

```swift
import AppIntents

struct OpenAlbumIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Album"

    @Parameter(title: "Album")
    var target: AlbumEntity        // OpenIntent requires a `target` of the entity type

    @Dependency var navigator: AppNavigator

    @MainActor
    func perform() async throws -> some IntentResult {
        navigator.showAlbum(id: target.id)   // navigation ONLY
        return .result()
    }
}
```

Keep `perform()` lightweight — it runs as the app comes to the foreground. Navigate now; defer heavy loading until after the view appears.

## Related

- `app-intents-widgets` skill → `references/app-intents.md` — `AppEntity`, `EntityQuery`, `OpenIntent`, `@Dependency`, App-Group-shared stores.
- `foundation-models` skill → `references/vision-and-system-tools.md` — other Vision-backed tools.
- `references/multiplatform-and-union.md` — same query on iPad/Mac, multiple result types, in-app continuation.
