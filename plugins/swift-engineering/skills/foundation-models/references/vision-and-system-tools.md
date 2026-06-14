# Vision & System Tools

> These capabilities are part of the 2026 release and newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

## Vision — image understanding on-device

The 2026 on-device model gains **vision**: insert an image attachment into a prompt alongside text, and the model can answer questions about the image. The API is a natural extension of the existing prompt builders.

```swift
let session = LanguageModelSession()

let response = try await session.respond {
    Prompt {
        "What craft technique is shown in this photo?"
        ImageAttachment(uiImage)        // confirm exact attachment API
    }
}
```

Image attachments can be created from many types: `UIImage`, `NSImage`, `CGImage`, Core Image types, `CVPixelBuffer`, and file `URL`s.

- **Any size / aspect ratio** is accepted — no need to crop or pad.
- **Larger images cost more tokens and add latency.** Downscale when full resolution isn't needed.
- Pairs well with `@Generable` to get structured output describing the image (see `structured-output.md`).
- See the "What's new in image understanding" session for depth.

## System tools

Built-in tools that supercharge a session with system functionality. Attach them like any `Tool` (see `tool-calling.md`); the model decides when to call them.

| Tool | Backed by | Use for |
|------|-----------|---------|
| **`OCRTool`** | Vision framework | Extract structured text from images |
| **`BarcodeReaderTool`** | Vision framework | Read information from barcodes |
| **Spotlight search tool** | Core Spotlight | Fully local **Retrieval-Augmented Generation (RAG)** over the user's indexed content |

```swift
let session = LanguageModelSession(tools: [OCRTool(), BarcodeReaderTool()])
```

### Local RAG with Spotlight

The Spotlight-backed search tool answers one of the most-requested features: give the model access to up-to-date **personal or domain knowledge** by querying a Spotlight index — all on-device, no server. Use it to ground responses in the user's own content.

- See "LLM search using Core Spotlight" for the retrieval/query details.
- See "What's new in image understanding" for `OCRTool` / `BarcodeReaderTool`.

## Best practices

- **OCR/barcode beat asking the raw model** to read text/codes from pixels — the system tools are purpose-built and more reliable.
- **RAG over fine-tuning** for fresh or personal knowledge: retrieval keeps answers current and grounded, and lets the model cite sources (suppressing hallucinations).
- **Mind tokens/latency** with images and large retrieved contexts; trim retrieved passages to what's relevant.
- **Evaluate tool usage** — confirm tools are actually called in the right situations. The Evaluations framework provides tool-call evaluators (see the `evaluations` skill → `judge-alignment.md` and "Create robust evaluations for agentic apps").
