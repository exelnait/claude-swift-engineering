# Swift Engineering Plugin

**Version:** 0.15.0

> ⚠️ **Experimental** — This plugin is actively developed. APIs, agents, and workflows may evolve.

Modern Swift/SwiftUI development toolkit for Claude Code. Provides specialized agents and comprehensive skills for planning, implementing, testing, and shipping production iOS apps using Apple's modern stack: `@Observable` + SwiftData + feature folders + async/await.

## Architectural Stance

**Default stack:** `@Observable` + SwiftData + feature folders + async/await. This is what `@swift-architect` recommends unless you hit genuine complexity thresholds.

**TCA is opt-in.** The `@tca-architect` and `@tca-engineer` agents exist for complex state management scenarios — not as the default path. `@swift-architect` decides when TCA is appropriate based on four explicit criteria.

**SwiftData is the default.** Not forbidden, not discouraged — it's the primary entity store. SQLite/GRDB is added only when SwiftData is the wrong tool (search indexes, AI cache, analytics, large generated collections).

**iOS 26+ only.** This plugin does not support iOS versions earlier than 26.0. All examples, agents, and skills assume APIs introduced in iOS 26 are available. There are no backward compatibility shims, no `@available` guards for older iOS, no migration guides from iOS 17/18.

## Features at a Glance

- **17 specialized agents** — Planning, architecture, implementation (incl. RealityKit/3D & spatial), accessibility, testing, AI-feature evaluation, documentation, and architecture knowledge preservation
- **51 comprehensive skills** — Architecture patterns, adaptive UI (incl. adaptive toolbars), macOS multiplatform, SwiftData & persistence, App Intents/widgets & Live Activities, media & the now-playing experience, networking, animations, GPU visual effects, charts, security & app integrity (App Attest), Vision, Visual Intelligence, TextKit, on-device AI (Foundation Models, Core AI), **RealityKit & 3D/spatial** (ECS core, SwiftUI↔RealityKit, rendering, physics & interaction, 3D asset optimization, Reality Composer Pro, USD/USDKit, Object Capture, RealityKit debugging, AR/spatial), observability, performance profiling, release/CI-CD, design principles & naming, accessibility, AI-feature evaluation, performance monitoring, and development tools
- **Ultra-modern Swift** — iOS 26+, Swift 6.2, strict concurrency, SwiftUI-only
- **@Observable-first** — Default path is @Observable + SwiftData; TCA is escalation for complex state
- **Production-ready** — Built-in code review, testing, and quality assurance workflows
- **Coordination via plans** — All agents share state through plan files, no manual coordination needed

## Table of Contents

- [Architectural Stance](#architectural-stance)
- [Core Capabilities](#core-capabilities)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Using Agents](#using-agents)
- [Agents](#agents)
- [Skills](#skills)
- [Installation](#installation)
- [Advanced Features](#advanced-features)
- [Workflow](#workflow)
- [Agent Handoff Model](#agent-handoff-model)
- [Plan File Format](#plan-file-format)
- [Architecture Conventions](#architecture-conventions)
- [Model Usage](#model-usage)
- [Quality Assurance](#quality-assurance)
- [Contributing](#contributing)
- [License](#license)
- [Feedback](#feedback)

## Core Capabilities

### Planning & Architecture
- Design features with UI mockups or descriptions
- Architecture decisions across 4 axes: state management, persistence, DI, documentation
- TCA-specific design (state, actions, effects, dependencies) — opt-in

### Implementation
- @Observable models + SwiftData entities (default path)
- Reducers and effects (TCA, when chosen)
- SwiftUI views with accessibility
- Modern async/await patterns
- Database operations (SwiftData primary; SQLite/GRDB side stores when needed)

### Quality Assurance
- Comprehensive testing with Swift Testing
- Code review (security, performance, HIG compliance)
- Modernization (legacy to modern Swift conversion — one-way, iOS 26+ only)
- Architecture knowledge preservation (docs, diagrams, decision rationale)

### Coordination
- Shared plan files for agent handoffs
- 4-axis architecture decisions recorded in plan
- Clear ownership and next steps

## Prerequisites

**Sosumi MCP Server** — Required for Apple documentation lookup. Agents use this to verify modern API usage (2025). Configure in your Claude Code settings before using this plugin.

**Deployment target: iOS 26+.** This plugin does not produce code for older iOS versions.

## Getting Started

1. **Install** this plugin in your Claude Code plugins directory
2. **Build a feature** by invoking agents in order (start with `@swift-architect` for new features)
3. **Agents coordinate** through plan files — no manual handoffs needed
4. **End with code review** via `@swift-code-reviewer` before shipping

For detailed workflows and examples, see [Using Agents](#using-agents) section below.

## Using Agents

This plugin provides ultra-specialized agents that you invoke directly to build features. Each agent has a specific role and understands when to hand off to the next agent in the workflow.

### Basic Workflow: Building a Feature (Default @Observable Path)

For a typical feature using @Observable + SwiftData:

**Step 1: Plan the architecture**
```
@swift-architect Design a notes feature with search
```
This creates a plan file at `docs/plans/notes.md` with 4-axis architecture decisions.

**Step 2: Implement the feature**
```
@feature-engineer Implement the notes model and SwiftData persistence following the plan
```
Creates @Observable model, @Model entities, and services.

**Step 3: Create SwiftUI views**
```
@swiftui-specialist Create the notes list view and note editor
```
Implements the UI without mixing in business logic.

**Step 4: Write tests**
```
@swift-test-creator Write comprehensive tests for the notes model using Swift Testing
```
Creates test files using Swift Testing framework.

**Step 5: Code review**
```
@swift-code-reviewer Review the implementation for quality, security, and performance
```
Verifies code meets project standards before shipping.

**Step 6: Architecture docs**
```
@architecture-keeper Create/update architecture docs for the notes feature
```
Produces flow docs with Mermaid diagrams, performance ledger, and decision rationale.

### Alternative Workflow: TCA Feature (When @swift-architect Chooses TCA)

Only use this path when `@swift-architect` has explicitly decided TCA is needed:

**Step 1: Plan the architecture**
```
@swift-architect Design a complex multi-feature sync coordinator
```

**Step 2: Design TCA architecture**
```
@tca-architect Design the state, actions, and effects for the sync coordinator
```

**Step 3: Implement the reducer**
```
@tca-engineer Implement the sync coordinator reducer and effects
```

**Step 4-6: Same as default path** (swiftui-specialist → swift-test-creator → swift-code-reviewer → architecture-keeper)

### Common Tasks by Agent

| Task | Agent | Example |
|------|-------|---------|
| Analyze UI mockups/screenshots | `@swift-ui-design` | Analyze this design mockup and create UI specifications |
| Plan new features (4-axis decision) | `@swift-architect` | Plan a user authentication system |
| Design TCA architecture | `@tca-architect` | Design state/actions/effects for authentication |
| Implement TCA features | `@tca-engineer` | Implement the authentication reducer |
| Implement @Observable features | `@feature-engineer` | Implement the Settings model and SwiftData persistence |
| Build SwiftUI views | `@swiftui-specialist` | Create the authentication UI following the design |
| Plan a 3D/spatial feature | `@spatial-experience-architect` | Plan a RealityKit product viewer with AR placement |
| Build RealityKit/3D content | `@realitykit-engineer` | Implement the RealityView scene, materials, and gestures |
| Create tests | `@swift-test-creator` | Write tests for the authentication flow |
| Evaluate an AI/FM feature | `@evaluation-engineer` | Measure tag-generation quality across all supported languages |
| Code review | `@swift-code-reviewer` | Review the authentication module for security and quality |
| Modernize code (iOS 26+ only) | `@swift-modernizer` | Migrate this ObservableObject to @Observable |
| Inline DocC comments | `@swift-documenter` | Document the public API surface of this library |
| Architecture docs + diagrams | `@architecture-keeper` | Create architecture docs for the auth flow |
| Fast code search | `@search` | Find all UserDefaults usage in the codebase |

### Plan File Coordination

All agents coordinate through a shared plan file at `docs/plans/<feature-name>.md`. This file:
- Records 4-axis architecture decisions (created by `@swift-architect`)
- Tracks implementation status
- Contains handoff notes from each agent to the next
- Ensures continuity across agent handoffs

Each agent will automatically read the plan, update it with their work, and add notes for the next agent.

### Key Principles

- **Start with `@swift-architect`** for new features to get 4-axis architecture decisions
- **Use `@swift-ui-design`** if you have mockups or screenshots to analyze
- **Default path is @Observable** — TCA only when architect explicitly chooses it
- **Always end with `@swift-code-reviewer`** to verify quality before shipping
- **Create architecture docs** with `@architecture-keeper` for non-trivial features

## Agents

### Planning Agents (Opus, READ-ONLY)

| Agent | Purpose | Model |
|-------|---------|-------|
| `@swift-ui-design` | Analyze mockups OR descriptions into UI specifications | Opus |
| `@swift-architect` | Architecture decisions (4-axis: state, persistence, DI, docs) | Opus |
| `@tca-architect` | TCA-specific design (state, actions, dependencies) — opt-in only | Opus |
| `@spatial-experience-architect` | Plan RealityKit/3D & spatial features (presentation, ECS/scene design, asset pipeline, performance budget, platform strategy) | Opus |

### Implementation Agents (Sonnet — code review & AI-eval on Opus)

| Agent | Purpose | Model |
|-------|---------|-------|
| `@feature-engineer` | @Observable + SwiftData implementation (default path) | Sonnet |
| `@tca-engineer` | TCA implementation (reducers, effects) — opt-in only | Sonnet |
| `@swiftui-specialist` | SwiftUI views (declarative only, no business logic) | Sonnet |
| `@realitykit-engineer` | RealityKit/3D & spatial implementation (ECS, RealityView, materials, physics, SwiftUI bridging, Reality Composer Pro) across iOS/iPadOS/macOS/tvOS/visionOS | Sonnet |
| `@accessibility-specialist` | Make UI accessible & audit it (VoiceOver, Dynamic Type, custom controls, reading, captions, inclusive design) | Sonnet |
| `@swift-test-creator` | Create tests using Swift Testing | Sonnet |
| `@evaluation-engineer` | Measure AI/Foundation Models feature quality with the Evaluations framework (datasets, metrics, model judges) — every supported language | Opus |
| `@architecture-keeper` | Create/update architecture docs with Mermaid diagrams | Sonnet |
| `@swift-code-reviewer` | Review code quality, security, performance | Opus |
| `@swift-modernizer` | Modernize legacy patterns to @Observable/async/await (iOS 26+ only, one-way) | Sonnet |

### Documentation Agents

| Agent | Purpose | Model |
|-------|---------|-------|
| `@swift-documenter` | Inline DocC comments for complex/non-obvious code | Haiku |

### Utility Agents (Haiku)

| Agent | Purpose | Model |
|-------|---------|-------|
| `@search` | Fast code search to prevent grep noise from polluting context | Haiku |

## Skills

### Architecture & Patterns
| Skill | Purpose |
|-------|---------|
| `swiftui-patterns` | iOS 26+ SwiftUI (@Observable, @Bindable, feature folders, navigation, accessibility) |
| `tca-inspired-patterns` | TCA patterns (reducer thinking, explicit actions, cancellation) without the framework |
| `composable-architecture` | TCA framework — opt-in for complex state |
| `swiftui-advanced` | Advanced gestures, adaptive layout, architecture decisions |
| `swiftui-animations` | Motion — implicit/explicit animation & spring curves, transitions & `matchedGeometryEffect`/zoom navigation, `phaseAnimator`/`keyframeAnimator`, `contentTransition`/symbol effects, performance & Reduce Motion |
| `adaptive-ui` | Available-space adaptation for iPhone fold, iPad multitasking & resizable windows — geometry breakpoints, Tab↔Sidebar morphing, scene geometry, and why `horizontalSizeClass`/idiom/orientation aren't width sensors |
| `macos-multiplatform` | Build for Mac by default — keep the macOS target always compiling (minimum) and natively adapted (maximum). Layered architecture (share behavior, specialize presentation; platform-blind models), the divergence ladder (unify→bridge→adapt→exclude), conditional compilation done right, the catalog of iOS-only APIs that break the Mac build + fixes, macOS scenes/windows/menus/pointer and native controls (Table, Inspector, split views, window chrome, AppKit interop, focus), and multiplatform project structure |
| `modern-swift` | Swift 6.2 concurrency (async/await, actors, @MainActor, Sendable) |
| `architecture-documentation` | "Trace + why" architecture docs with Mermaid diagrams |

### Persistence
| Skill | Purpose |
|-------|---------|
| `swiftdata` | The default entity store — `@Model` schema, `@Query`/`#Predicate`, `ModelContainer`/`ModelContext`, relationships & delete rules, `@ModelActor` background work, versioned migrations, CloudKit sync, and in-memory testing/previews |
| `data-layer-decisions` | When to use SwiftData vs GRDB, hybrid patterns, decision trees |
| `sqlite-data` | SQLiteData library (@Table, migrations, CloudKit sync) |
| `grdb` | GRDB direct SQLite access (complex queries, FTS5, performance) |

### Frameworks & Libraries
| Skill | Purpose |
|-------|---------|
| `storekit` | StoreKit 2 in-app purchases and subscriptions |
| `foundation-models` | Apple AI: on-device + Private Cloud Compute, vision, agentic dynamic profiles, system tools, Spotlight RAG (`SpotlightSearchTool`), best practices |
| `core-ai` | Bring & run your OWN custom model on-device (memory-safe Swift API, PyTorch→Core AI conversion); choosing Core AI vs Foundation Models vs MLX |
| `vision-framework` | Apple's Vision framework — tap-to-segment, image feature prints & similarity, saliency cropping, detection/classification, on watchOS; combining Vision with Foundation Models image tools |
| `visual-intelligence` | Integrate with Visual Intelligence — Image Search via App Intents entities + `IntentValueQuery` + `SemanticContentDescriptor`, `UnionValue`, and receiving data via EventKit/Contacts/HealthKit |
| `now-playing` | Surface media in the system now-playing experience (Lock Screen, Control Center, Dynamic Island, CarPlay, Watch) — `MediaSessionRepresentable`, remote media sessions, Media Sharing Extensions |
| `textkit` | Custom & extended text experiences — the four-layer TextKit architecture, custom text views, viewport rendering-surface APIs, and extending UITextView/NSTextView (line numbers, collapsible sections, attachment reuse) |
| `evaluations` | Measure quality of AI/Foundation Models features (datasets, metrics, model judges, evaluation-driven development) — every supported language |
| `app-intents-widgets` | App Intents + WidgetKit surface — widgets & timeline providers, interactive widgets, Live Activities & the Dynamic Island, Control Center controls, App Shortcuts (automations, Use Model action, Storage), and Siri/Spotlight schemas + View Annotations |
| `networking` | Application-level HTTP — `URLSession` + async/await, `Codable` REST client, typed errors, retries/backoff, auth & single-flight token refresh, streaming (SSE), and `URLProtocol` testing |
| `swift-charts` | Data visualization — bar/line/point/area/rule/sector marks, `.value` encoding & series, axes/scales/legends, selection & scrolling interaction, and chart accessibility (Audio Graphs) |
| `swift-networking` | Network.framework — low-level TCP/UDP, custom protocols, TLS, Bonjour (not HTTP) |

### 3D, Spatial & RealityKit

RealityKit is Apple's recommended 3D engine across iOS/iPadOS/macOS/tvOS/visionOS (SceneKit is deprecated). Main focus is iOS 26+, with visionOS as a natural extension.

| Skill | Purpose |
|-------|---------|
| `realitykit-core` | The foundation — Entity Component System (entities/components/systems), `RealityView` setup, loading entities & resources, transforms & the coordinate system, entity actions & animation playback, cross-platform deployment |
| `realitykit-swiftui` | SwiftUI ↔ RealityKit — `Model3D` vs `RealityView`, `Model3DAsset`/`ConfigurationCatalog`, `realityViewLayoutBehavior`, view attachments/gestures/popovers, Object Manipulation, observable entities & two-way data flow, `CoordinateSpace3D`, SwiftUI-driven component animation |
| `realitykit-rendering` | Visuals — PBR/unlit/Shader Graph materials, lights, soft shadows, lightmaps, image-based lighting & `EnvironmentRadiance`, projective textures & physical-space lighting, post-processing (bloom), particles, gaussian splats |
| `realitykit-physics-interaction` | Physics & world interaction — `PhysicsBodyComponent` modes, collision & forces, hover effects & GroupIDs, navigation mesh pathfinding, cloth simulation |
| `3d-asset-optimization` | Performance — triangle budgets, texture packing/compression & color spaces, material instances, `MeshInstancesComponent`, skydome/IBL sizing, AVIF & mesh compression, LOD & thermal adaptation |
| `reality-composer-pro` | Authoring in Reality Composer Pro 3 — scene composition, prototypes/instancing, Shader/Script/Animation/Compute Graph, Behavior Trees, nav-mesh authoring, lightmap baking, live preview, the RCP Assistant, and editor plugins (custom components/systems/actions/nodes) |
| `usd-usdkit` | USD/OpenUSD & the USDKit framework — layers/stages/prims/schemas, composition & references, USDA/USDC/USDZ, the USDKit Swift API, MaterialX/OpenPBR, mesh/texture compression, accessibility metadata, and the Safari `Model` tag |
| `object-capture` | Photogrammetry — create a `PhotogrammetrySession` from photos, detail levels, the interactive bounding-box workflow, capture best practices, and producing USDZ assets |
| `realitykit-debugging` | The RealityKit debugger — capture an entity-hierarchy snapshot, diagnose rogue transforms, misconfigured/missing components, and rendering pitfalls; build custom debug tooling; profile with RealityKit Trace |
| `realitykit-spatial-ar` | Real-world integration (visionOS-leaning, + iOS ARKit) — anchoring with `SpatialTrackingSession`/`AnchorEntity`, scene understanding, environment blending, immersive audio & custom reverb, spatial photos/scenes & immersive video, spatial accessories, object tracking |

### Platform & Design
| Skill | Purpose |
|-------|---------|
| `design-principles` | Apple's eight design principles, naming/UX-writing criteria, and responsible-AI design (the *why* behind the HIG) |
| `ios-hig` | Apple Human Interface Guidelines (accessibility, dark mode, haptics) |
| `ios-26-platform` | iOS 26 features (Liquid Glass, new APIs) |
| `haptics` | Haptic feedback (UIFeedbackGenerator, Core Haptics, AHAP patterns) |
| `localization` | Internationalization (String Catalogs, pluralization, RTL) |
| `security` | Keychain (accessibility & `SecAccessControl`), Face/Touch ID (`LocalAuthentication`), privacy permissions & the `PrivacyInfo.xcprivacy` manifest, Data Protection + CryptoKit/Secure Enclave, App Transport Security |
| `app-attest` | Prove app integrity to your server — App Attest attestation & assertions, Secure Enclave keys, server-side validation, and the fraud metric (anti-fraud/anti-abuse for modified-app copies) |

### Accessibility
| Skill | Purpose |
|-------|---------|
| `accessibility` | Accessibility depth — VoiceOver/Switch/Voice Control, Dynamic Type, custom-control accessibility, reading/long-form text, media captions, inclusive design, Accessibility Nutrition Labels, and auditing |

### Development Tools
| Skill | Purpose |
|-------|---------|
| `swift-testing` | Swift Testing framework (@Test, parameterized tests, async) |
| `swift-style` | Code style conventions (naming, golden path, organization) |
| `swift-diagnostics` | Systematic debugging (navigation, build issues, memory) |
| `metrickit` | Collect real-world performance metrics & diagnostics (MetricKit `MetricManager`, state reporting, crash/hang/memory) |
| `observability` | Unified logging (`Logger`/`OSLog`), levels, privacy redaction in logs, and `OSSignposter` tracing/Points of Interest for Instruments |
| `performance-profiling` | Instruments & `xctrace` — Time Profiler call trees, hangs vs animation hitches, SwiftUI update lanes/cause-and-effect, memory generations; the interactive/scriptable profiling loop |
| `release-cicd` | Ship the app — code signing & provisioning, Xcode Cloud & fastlane pipelines, TestFlight, App Store submission (versioning, metadata, phased release), App Store Connect API |
| `generating-swift-package-docs` | Generate API docs for Swift package dependencies |

## Advanced Features

### Helper Scripts

**get-recent-simulator.sh**

Gets the most recent iOS simulator available for Xcode builds.

Usage:
```bash
bash scripts/get-recent-simulator.sh
```

**bump-plugin-version.sh**

Automates version bumping across plugin metadata files.

Usage:
```bash
bash scripts/bump-plugin-version.sh <new-version>
```

### Development Rules

**five-whys.md** — Root cause analysis for debugging complex issues.

**thinking-partner.md** — Collaborative problem-solving for design decisions.

## Installation

### Local Development
Drop this folder into your Claude Code plugins directory:

```bash
~/.claude/plugins/swift-engineering/
```

Then in Claude Code:
```
/plugin reload
```

### Configuration
Before using agents, ensure the **Sosumi MCP Server** is configured in your Claude Code settings for Apple documentation lookup.

Optional: Configure hooks for git automation. See [hooks-scripts/README.md](hooks-scripts/README.md) for details.

### First Run
1. Navigate to your Swift project directory
2. Invoke an agent: `@swift-architect Design a new feature`
3. Agent creates a plan file at `docs/plans/<feature-name>.md`
4. Each subsequent agent updates the plan and adds handoff notes

## Workflow

```
UI description/mockup? ──yes──► @swift-ui-design (Opus)
        │                              │
        no                             │
        │◄──────────────────────────────
        ▼
   @swift-architect (Opus)  →  docs/plans/<feature>.md
        │
        │ Decisions on 4 axes:
        │   - State: @Observable (default) vs TCA (escalation)
        │   - Persistence: SwiftData (default) vs +SQLite (hybrid)
        │   - DI: constructor (default) vs @Dependency (when justified)
        │   - Docs: which architecture docs to create/update
        │
        ├── TCA chosen ──► @tca-architect (Opus) ──► @tca-engineer (Sonnet)
        │                                                    │
        └── @Observable chosen ──────────────► @feature-engineer (Sonnet)
                                                    │
                                                    ▼
                                          @swiftui-specialist (Sonnet)
                                                    │
                                                    ▼
                                         @swift-test-creator (Sonnet)
                                                    │
                                  AI/Foundation Models feature?
                                                    │
                                       ┌── yes ──► @evaluation-engineer (Opus)
                                       │           (datasets + metrics + model judges,
                                       │            every supported language; hill-climb)
                                       │                    │
                                       └── no ──────────────┤
                                                    ▼
                                       @swift-code-reviewer (Opus)
                                                    │
                                                    ▼
                                       @architecture-keeper (Sonnet)
                                       (creates/updates docs/architecture/)
                                                    │
                                                    ▼
                                       @swift-documenter (optional, Haiku)
                                       (inline DocC for complex code only)
```

## Agent Handoff Model

| From | To | Condition |
|------|----|-----------|
| @swift-ui-design | @swift-architect | UI analysis complete |
| @swift-architect | @tca-architect | TCA chosen (all 4 criteria met) |
| @swift-architect | @feature-engineer | Default @Observable path |
| @tca-architect | @tca-engineer | TCA design complete |
| @tca-engineer | @swiftui-specialist | Implementation complete |
| @feature-engineer | @swiftui-specialist | Implementation complete |
| @swiftui-specialist | @swift-test-creator | Views complete |
| @swift-test-creator | @evaluation-engineer | Feature uses Foundation Models / AI (probabilistic output) |
| @swift-test-creator | @swift-code-reviewer | Tests written (no AI/FM feature) |
| @evaluation-engineer | @swift-code-reviewer | Evaluations pass optimization target in every supported language |
| @swift-code-reviewer | @architecture-keeper | Code review passed |
| @architecture-keeper | @swift-documenter | Architecture docs done, optional inline DocC |

## Plan File Format

All agents share state via a plan file at `docs/plans/<feature-name>.md`:

```markdown
# Feature: <FeatureName>

## Status
- [ ] UI design (@swift-ui-design)
- [ ] Architecture (@swift-architect)
- [ ] TCA design (@tca-architect) — only if TCA chosen
- [ ] Implementation (@feature-engineer or @tca-engineer)
- [ ] Views (@swiftui-specialist)
- [ ] Tests (@swift-test-creator)
- [ ] Code review (@swift-code-reviewer)
- [ ] Architecture docs (@architecture-keeper)
- [ ] Inline DocC if needed (@swift-documenter)

## Architecture Decisions

### Axis 1: State Management
**Choice:** [ @Observable (default) | TCA (escalation) ]
**Rationale:** [If TCA: which of the 4 criteria are met]

### Axis 2: Persistence
**Choice:** [ SwiftData only | SwiftData + GRDB | UserDefaults only ]
**Rationale:** [Why this combination]

### Axis 3: Dependency Strategy
**Choice:** [ Constructor injection | swift-dependencies library | @Dependency (TCA only) ]
**Rationale:** [Why]

### Axis 4: Documentation Plan
**New docs:** [List]
**Updated docs:** [List]

## MCP Servers
- **sosumi** — Apple documentation lookup (2025 APIs)

## Handoff Log

### @agent-name (YYYY-MM-DD)
**Work done:** [Summary]
**Files created:** [List]
**Notes for next agent:** [Context]
**Next:** @agent-name — [Reason]
```

## Architecture Conventions

- **iOS 26.0+** minimum deployment target. This plugin does not support iOS versions earlier than 26.0. All examples, agents, and skills assume APIs introduced in iOS 26 are available.
- **Swift 6.2** with strict concurrency checking
- **SwiftUI** for UI (UIKit only when explicitly requested or for UIKit interop)
- **`@Observable` + SwiftData** is the default architecture; TCA is opt-in for complex state
- **SwiftData** primary for persistent entities; **GRDB/SQLite** for search indexes, AI cache, embeddings, analytics
- **Swift Testing** framework (no XCTest)
- **async/await** exclusively (no completion handlers)

## Model Usage

| Model | Agents | Rationale |
|-------|--------|-----------|
| Opus | @swift-architect, @swift-ui-design, @tca-architect, @spatial-experience-architect, @swift-code-reviewer, @evaluation-engineer | Best reasoning for architecture decisions (incl. 3D/spatial), the high-stakes final code-review gate, and AI-feature evaluation |
| Sonnet | Implementation agents (feature-engineer, swift-engineer, tca-engineer, swiftui-specialist, realitykit-engineer, accessibility-specialist, swift-test-creator, architecture-keeper, swift-modernizer) | Strong coding, testing, and docs at lower cost than Opus — no longer silently inherits the (possibly Opus) session model |
| Haiku | @search, @swift-documenter | Fast, efficient for mechanical tasks |

## Quality Assurance

### Validation Checklist

When modifying agents or skills:

- [ ] All agents have `name`, `description`, `tools`, `model` fields
- [ ] Opus agents: planning (`@swift-architect`, `@swift-ui-design`, `@tca-architect`, `@spatial-experience-architect`) plus `@swift-code-reviewer` and `@evaluation-engineer`
- [ ] Other implementation agents use Sonnet (explicit — strong coding at lower cost than Opus; not `inherit`, which silently ran on the session model)
- [ ] Utility agents (`@search`, `@swift-documenter`) are Haiku
- [ ] Planning agents have explicit no-modify constraints
- [ ] All handoffs are documented in Agent Handoff Model
- [ ] All skill references exist in `skills/` directory
- [ ] No agent or skill says "Never SwiftData"
- [ ] TCA agents have explicit opt-in framing
- [ ] No `@available(iOS X, *)` guards for X < 26 anywhere in the plugin

## Contributing

Contributions are welcome! Areas of focus:

- **New agents** — Specialized agents for underserved tasks
- **Skill enhancements** — Additional frameworks, patterns, or design guidance
- **Bug fixes** — Issues, regressions, or edge cases in existing agents
- **Documentation** — Clarity, examples, or new guides
- **Testing** — Verify agent workflows work end-to-end

Please ensure:
- Agents follow the established [specification](#agents)
- Skills adhere to [writing-skills best practices](https://github.com/anthropics/claude-code/blob/main/docs/skills.md)
- Changes are tested with actual Swift projects
- Documentation is updated

## License

This plugin is available under the MIT License. See [LICENSE](LICENSE) file for details.

## Feedback

Report issues or suggest features at the [GitHub repository](https://github.com/johnrogers/claude-swift-engineering/issues).
