# Agentic Experiences: Dynamic Profiles

> Dynamic profiles are part of the 2026 release and newer than this guidance's training data. The type/method names below come from Apple's introduction — verify exact signatures and availability against current documentation. Many building blocks live in the open-source **Foundation Models framework utilities** package, updated between OS releases.

`DynamicProfile` lets you switch models, instructions, tools, and generation options **within a single `LanguageModelSession`**, while keeping shared conversation context. It's the declarative primitive for building agents — a profile *is* a configuration/agent with a goal and capabilities. The body is **re-evaluated each time the model is prompted**, so the session's persona changes as your app's mode changes ("swapping hats").

## A minimal profile

```swift
struct CraftProfile: DynamicProfile {
    var body: some DynamicProfile {
        Profile {
            Instructions("You help users brainstorm craft projects.")
            GenerateTitleTool()
        }
    }
}

let session = LanguageModelSession(profile: CraftProfile())
```

A `Profile` is made of **instructions, tools, and modifiers**. Use conditionals in the body to select which `Profile` is active — a `DynamicProfile` resolves to **one active Profile at a time**, and the framework handles the transition.

## Switching modes & models

```swift
@Observable final class CraftOrchestrator {
    var mode: Mode = .brainstorm

    var profile: some DynamicProfile {
        Profile {
            switch mode {
            case .brainstorm:
                Instructions("Suggest creative project ideas.")
                GenerateTitleTool()
                    // creative + broad knowledge → PCC, higher temperature
                    .model(PrivateCloudComputeLanguageModel())
                    .temperature(1.0)
            case .planning:
                Instructions("Produce step-by-step tutorial directions.")
                    .model(PrivateCloudComputeLanguageModel())
                    .reasoningLevel(.deep)        // complex → think deeply
            case .reviewing:
                Instructions("Give advice as the user works.")
                    .model(SystemLanguageModel())  // on-device to save server calls
                    .reducingContext()             // custom modifier (see below)
            }
        }
    }
}
```

Modifiers configure the model, `temperature`, `samplingMode`, `reasoningLevel`, and more.

## DynamicInstructions — reusable, composable

Group related instructions + tools into a reusable component; nesting concatenates them.

```swift
struct OrigamiExpert: DynamicInstructions {
    var body: some DynamicInstructions {
        Instructions("You are an expert in origami techniques.")
        FoldDiagramTool()
    }
}

struct BrainstormFacilitator: DynamicInstructions {
    var body: some DynamicInstructions {
        Instructions("Facilitate creative brainstorming.")
        if isOrigamiProject { OrigamiExpert() }   // composed in
    }
}
```

## Managing the transcript

The **transcript** is the session's representation of the model's context. Reasons to modify it: stay within a model's context size, improve focus by dropping irrelevant entries, or **redact private info before moving to a less private model**.

- **`historyTransform`** (modifier) — a **lossless, per-profile, local** transform applied to history *before* prompting; it does **not** mutate the session's transcript, so context you drop now can return later. Good for trimming tool calls / irrelevant entries.
- **`history` session property** — a built-in property that updates history for **all profiles**; it's **lossy** and applies session-wide. Prefer `historyTransform` for targeted, lossless changes.

Wrap complex transforms in a custom modifier:

```swift
struct ReduceContext: DynamicProfileModifier {
    func body(content: Content) -> some DynamicProfile {
        content.historyTransform { history in
            history.filter { !$0.isToolCall }   // e.g., drop tool calls
        }
    }
}
extension DynamicProfile {
    func reducingContext() -> some DynamicProfile { modifier(ReduceContext()) }
}
```

### Lifecycle modifiers & session properties

Lifecycle modifiers (e.g., `onResponse`) run imperative code at points in the session — update external UI state, switch modes, or summarize history at a clean boundary.

```swift
@SessionPropertyEntry var conversationSummary: String? = nil   // in an extension on SessionPropertyValues
```

```swift
Profile {
    Instructions("…") { summary in "Earlier context: \(summary ?? "")" }
}
.onResponse { session in
    session.conversationSummary = try await summarize(session.history)
    // reclaim context by summarizing earlier entries after each response
}
```

Session properties are mutable, need an initial value, and are readable/writable from any Tool or Profile (changes are visible session-wide).

## Orchestration patterns

| Pattern | Mechanism | Transcript | Who answers |
|---------|-----------|------------|-------------|
| **Baton-pass** (collaboration) | A variable selects the active profile; each profile has a tool to set it | **Shared** — full history visible to all profiles | The profile holding the baton produces the final answer |
| **Phone-a-friend** (consultation) | A tool spawns a short-lived child session, prompts it, returns its output as tool output | **Isolated** per profile; child disappears | The **parent** always gives the final answer |

The utilities package also offers a **Skills** type for procedural context loading. Choose based on whether profiles should share context (baton-pass) or stay isolated (phone-a-friend).

## Tool calling mode & error handling

- **Tool calling mode** — `allowed` (default; model may call a tool or answer), `disallowed` (no tools, e.g., in an irrelevant part of the app), `required` (model can *only* call tools). Set via a profile modifier, or `GenerationOptions` on `respond(to:)`.
- **`required` is a while-loop — provide an exit.** Conditionalize the mode on a variable (require tools until a specific tool is called), or give a final-answer tool that **throws** to abort the loop and return control to you.
- **`transcriptErrorHandlingPolicy`** — by default, throwing from a tool or cancelling a response **rolls back** the transcript (`revertTranscript`). For resume-after-cancel use cases, set `preserveTranscript` (profile modifier or on the session) — then *you* must restore a good transcript. The session `transcript` is mutable, but only when `isResponding == false` (mutating mid-response is a programmer error).

## Performance, accuracy & evaluation

Transcript mutations interact with the **KV cache** (rewriting history invalidates it → latency) and can **confuse the model** (it may imitate a past pattern). See `best-practices.md`. Because context-engineering effects are subtle, **use the `evaluations` skill** to build eval sets and quantify the impact of each strategy — data-driven optimization is the only way to be confident.
