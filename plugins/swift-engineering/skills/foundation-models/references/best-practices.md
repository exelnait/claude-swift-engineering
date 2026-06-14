# Foundation Models — Best Practices

A consolidated checklist distilled from Apple's Foundation Models sessions (2025–2026). Treat the on-device model as a capable but device-scale tool, design for privacy and latency, and **prove behavior with evaluations**.

> **Newer APIs (2026 release):** Private Cloud Compute, the `LanguageModel` protocol, dynamic profiles, vision, and system tools are newer than this guidance's training data and ship in later OS versions (the session calls out iOS/macOS/watchOS 27, with token-counting/context-size APIs in iOS 26.4). Confirm exact availability and signatures against current Apple documentation (Sosumi MCP).

## Model & task fit

- **On-device is for device-scale tasks:** summarization, extraction, classification, tagging, content generation, and (2026) vision. **Not** for world knowledge or advanced reasoning — use Private Cloud Compute, a server model, or break the task into smaller pieces.
- **Break big tasks down.** Develop an intuition for the model's strengths and weaknesses; decompose complex tasks into smaller prompts.
- **Pick the right model for each step.** On-device (private, offline, free, fast) vs Private Cloud Compute (bigger, 32K context, reasoning) vs third-party server models (capability at the cost of auth/billing/privacy). See `model-selection.md`.
- **Use specialized adapters** when one fits (e.g., the content-tagging adapter) rather than fighting the general model.

## Structured output (guided generation)

- Prefer **`@Generable`** types over asking for JSON/CSV and parsing — constrained decoding guarantees structural correctness and tends to *improve* accuracy. Don't hand-parse model text. See `structured-output.md`.
- Use **`@Guide`** for natural-language property descriptions and value constraints (ranges, counts, regex).
- **Property order matters** — properties generate top-to-bottom; put summaries/derived fields **last** so they can reference earlier content. Order affects both animation and output quality.

## Latency & streaming

- Stream with **snapshots** (`PartiallyGenerated`) for generations over ~1 second; bind to SwiftUI and let the UI fill in.
- **Turn waiting into delight** with SwiftUI animations/transitions; mind view identity when streaming arrays.
- **Prewarm** the session before the user interacts (first generation loads the model, ~1–2s).
- Don't submit a new prompt while `isResponding` is `true`; disable the trigger.

## Instructions, prompts & safety

- **Instructions come from you; prompts can come from the user.** The model obeys instructions over prompts, which mitigates (but does not eliminate) prompt injection.
- **Never interpolate untrusted user input into instructions.** Keep instructions mostly static.
- **Respect guardrails.** Design prompts that comply rather than fighting safety; rephrasing usually works. (Guardrail false positives were reduced in iOS 26.4 — keep guardrail handling anyway.)
- Pair the feature with **responsible design** (previews/confirmations/disclaimers, privacy boundaries): see the `design-principles` skill → `responsible-ai-design.md`.

## Context window management

- The context window is finite (on-device ~4K tokens in 2025; PCC 32K). Check input length; trim or summarize proactively.
- Use the **token-counting / context-size APIs** (iOS 26.4+) to adapt to the hardware and avoid `exceededContextWindowSize`.
- For long sessions and multi-model routing, manage the transcript with **dynamic profiles** (`historyTransform`, summarize on response). See `agentic-profiles.md`.

## Tools & agentic control

- Use the **Tool protocol** to give the model world knowledge, recent/personal data, or the ability to take actions; tool args are `@Generable` (guided generation guarantees valid tool calls). See `tool-calling.md`.
- **Tool calling mode** (`allowed` default / `disallowed` / `required`): when `required`, the model is in a while-loop — *you* must provide an exit condition (a final-answer tool that throws, or conditionalize the mode on a variable).
- (2026) **System tools** — `BarcodeReaderTool`, `OCRTool` (Vision), and a Spotlight-backed search tool for local RAG. See `vision-and-system-tools.md`.

## Availability & errors

- Always check `SystemLanguageModel.default.availability` before using; degrade gracefully when unavailable. Not all devices/regions/opt-ins qualify.
- Handle errors explicitly: **guardrail violation**, **unsupported language**, **context window exceeded**.

## Performance & accuracy when mutating the transcript

- **KV cache:** appending preserves the cache and minimizes time-to-first-token; rewriting history, changing attached tools, or editing instructions typically **invalidates** it and adds latency. Different models cache differently — **measure** with the Foundation Models Instrument in Xcode.
- **Accuracy:** history modifications can *confuse* the model (e.g., it imitates a past pattern). Nuanced transcript edits make evaluations essential.

## Prove it with evaluations

- Language models are non-deterministic. **Every FM feature ships with an Evaluation** and an optimization target; quantify the statistical impact of each change and hill-climb. Use the **`evaluations`** skill.
- Evaluate **every supported language**, and re-evaluate after any change to the prompt, model, `@Generable` schema, or tools.

## Third-party / server models — security & cost

- **Never store API keys in the app binary.** Fetch access tokens via a secure mechanism (OAuth) and store them in **Keychain**.
- Expect **per-token billing**; read the `usage` property on sessions/responses (input tokens, cached tokens, reasoning tokens) to track spend.

## Tooling

- Iterate on prompts with the **`#Playground`** macro (access your app's types; no rebuild needed).
- Profile latency with the **Foundation Models Instrument**; detect KV-cache invalidations there.
- (2026) **`fm` CLI** and **Python SDK** for productivity/scripting; **Foundation Models framework utilities** (open source) for emerging agentic building blocks.
