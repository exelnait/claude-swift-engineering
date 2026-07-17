# Vision + Foundation Models: Image Tools

> These capabilities are part of the 2026 releases and newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

This is the **Vision-side view** of image tooling. The session, prompt, `Tool` protocol, attachments, and system tools all belong to Foundation Models — see the **`foundation-models`** skill → `vision-and-system-tools.md` (image attachments, `OCRTool`/`BarcodeReaderTool`, RAG) and `tool-calling.md` (the `Tool` protocol, how a call flows). This file covers how Vision plugs into that machinery.

## Image input to an LLM

Foundation Models now accepts **image inputs**: attach an image to a prompt and the model can answer about it (caption it, describe a room, generate a recipe from a photo of a fridge). The model is versatile but not pixel-precise — it's great at describing, weaker at reading fine text or decoding codes.

```swift
import FoundationModels

let session = LanguageModelSession()
let response = try await session.respond {
    Prompt {
        "Write a short caption for this photo."
        ImageAttachment(uiImage)          // confirm exact attachment API
    }
}
```

See `foundation-models` → `vision-and-system-tools.md` for the attachment types and token/latency guidance. When a task needs precision (dense text, barcodes, plant ID), don't rely on the raw model — hand it a **tool** that runs Vision.

## Image-based tools (a Tool that takes an ImageReference)

Tool calling now supports **image arguments**. But the model doesn't pass the whole image into your tool — it passes a **reference** to an image that already exists in the chat session. Your tool resolves that reference back into pixels and runs Vision on them.

Declaring the argument type as **`ImageReference`** is what signals to the model that this argument must be a reference to an existing image from the current session.

The resolution chain inside `call` is: **`session.history` (the transcript) → resolve the `ImageReference` → an `imageAttachment` → a `pixelBuffer`** you can analyze. An `ImageReference` is only valid in the context of the transcript it was generated from, which is why you go through `history`.

```swift
import FoundationModels
import Vision

struct PlantIdentifierTool: Tool {
    let name = "identifyPlant"
    let description = "Identifies the plant shown in a referenced image."

    @Generable
    struct Arguments {
        @Guide(description: "A reference to the plant image from this conversation.")
        var image: ImageReference        // signals: a reference to an existing session image
    }

    // Hold the session so the tool can reach the transcript.
    let session: LanguageModelSession

    func call(arguments: Arguments) async throws -> ToolOutput {
        // 1. Resolve the reference within the transcript it came from.
        let attachment = try arguments.image.resolve(in: session.history)   // confirm exact resolve API
        // 2. Convert the attachment to a pixel buffer for Vision.
        let pixelBuffer = try attachment.pixelBuffer                        // confirm exact conversion API
        // 3. Run any Vision request on the pixel buffer.
        let name = try await classifyPlant(pixelBuffer)
        return ToolOutput(name)
    }
}
```

The method names for **resolve** and **pixelBuffer conversion** need confirming against current docs, but the **chain** — `history` → resolve → `imageAttachment` → `pixelBuffer` — is the stable idea. Once you have a pixel buffer, it's an ordinary Vision `ImageRequestHandler` job (see `image-analysis.md`).

## Vision-provided system tools: OCR & barcode

You don't have to write a tool for common cases — Vision ships two ready-made tools that models otherwise struggle with:

| Tool | Use for |
|------|---------|
| **`OCRTool`** | Reading really fine or dense text; **over 30 languages** |
| **`BarcodeReaderTool`** | Scanning barcodes and QR codes |

Enable them by importing Vision and **configuring the session** with the tools you want. The model then decides when to call them — e.g. reading a QR code on an event flyer to extract a registration URL it couldn't read on its own.

```swift
import FoundationModels
import Vision

let session = LanguageModelSession(tools: [OCRTool(), BarcodeReaderTool()])
// The model can now call OCR / barcode reading when a prompt needs it.
```

These are the same two system tools documented from the LLM side in `foundation-models` → `vision-and-system-tools.md`; this is just the Vision-provided origin of them.

## Label attached images so the model can choose

When you attach an image that you want the model to be able to pass to a tool, **give it a label**. The label is how the model **identifies which image** to hand to the tool — essential when more than one image is in play.

```swift
Prompt {
    "Read the QR code on the flyer and give me the registration link."
    ImageAttachment(flyerImage, label: "event flyer")   // confirm exact label API
}
```

Unlabeled images leave the model guessing which reference to pass; a clear label ("event flyer", "the plant", "receipt") makes image-based tool calls reliable.

## Putting it together

- **Versatile + descriptive** → let the LLM answer from the attached image directly.
- **Precise / fine text / codes / specialized detection** → give the LLM a **tool** (a system `OCRTool`/`BarcodeReaderTool`, or your own Vision-backed tool taking an `ImageReference`).
- Always **label** attached images when a tool call is expected.

For evaluating that tools are actually called in the right situations, see the `evaluations` skill (tool-call evaluators), noted in `foundation-models` → `vision-and-system-tools.md`.
