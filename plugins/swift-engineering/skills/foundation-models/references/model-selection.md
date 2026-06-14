# Model Selection

> The Private Cloud Compute model, the `LanguageModel` protocol, and third-party packages are part of the 2026 release (later OS versions than iOS 26). Verify availability, entitlements, and exact API against current Apple documentation.

In the 2026 release the framework opens up its model abstraction: a `LanguageModelSession` can be backed by **any** model conforming to the new `LanguageModel` protocol. Choose per task based on **capability, cost, and privacy**.

## The options

| Model | Where | Context | Privacy | Cost | Best for |
|-------|-------|---------|---------|------|----------|
| `SystemLanguageModel` (on-device) | Device | ~4K tokens | Stays on device, offline | Free | Fast, private, device-scale tasks: summarize/extract/classify/tag, vision |
| `PrivateCloudComputeLanguageModel` | Apple PCC | 32K tokens | Prompts never stored; verifiable; no keys | Free under 2M first-time downloads (higher for iCloud+ users) | More capability + **reasoning**; brings FM to watchOS 27 |
| `CoreAILanguageModel`, `MLXLanguageModel` | Local (ANE / Mac GPU) | model-dependent | On device | Free | Running other local models; open-sourced implementations |
| Third-party (Anthropic, Google, Chat Completions) | Their servers | model-dependent | Leaves device | **Per-token billing**, you handle auth | Frontier server capability when justified |

> Guidance: default to **on-device** for private, quick tasks; escalate to **PCC** when you need more horsepower, reasoning, or a larger context while staying private; reach for **third-party** only when a frontier model is genuinely required, and be transparent about the data leaving the device.

## On-device

```swift
import FoundationModels

let session = LanguageModelSession()   // SystemLanguageModel.default
```

See `getting-started.md`. The 2026 on-device model is rebuilt — better at logic and tool calling — and gains **vision** (see `vision-and-system-tools.md`).

## Private Cloud Compute (reasoning)

```swift
let model = PrivateCloudComputeLanguageModel()
let session = LanguageModelSession(model: model)

// Reasoning is controlled per request via contextOptions.
let response = try await session.respond(
    to: prompt,
    contextOptions: .init(reasoningLevel: .deep)   // confirm exact API
)
```

- No account setup, authentication, or API-key storage — it's seamless and private (prompts never stored; independently verifiable).
- `reasoningLevel` (e.g., `.deep`) trades compute for better answers; use it for complex tasks (planning, in-depth generation), not quick ones.
- Requires an entitlement — see Apple's "Building with Private Cloud Compute" session.

## The `LanguageModel` protocol & third-party models

```swift
import SomeProviderLanguageModelPackage   // added via Swift Package Manager

let model = SomeProviderLanguageModel(/* config */)
let session = LanguageModelSession(model: model)
// Everything downstream (respond, @Generable, tools, streaming) stays the same.
```

`SystemLanguageModel` and `PrivateCloudComputeLanguageModel` already conform. Anthropic and Google publish Swift packages; `CoreAILanguageModel` / `MLXLanguageModel` are open-sourced. You can author your own `LanguageModel` package.

### Security & cost for third-party / server models

- **Never store private keys in the app binary.** Fetch tokens with OAuth and store them in **Keychain**.
- You're typically **billed per token** — inspect the `usage` property on sessions and responses:

```swift
let response = try await session.respond(to: prompt)
let usage = response.usage   // input tokens, tokens read from cache, reasoning tokens
```

## Routing between models in one session

When a single conversation needs different models for different phases (e.g., quick analysis on-device, creative brainstorming on PCC) while sharing context, use **dynamic profiles** rather than juggling multiple sessions — see `agentic-profiles.md`. Remember that switching models can change the context-size limit and invalidate the KV cache (see `best-practices.md`).
