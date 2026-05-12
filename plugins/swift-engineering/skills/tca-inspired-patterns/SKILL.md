---
name: tca-inspired-patterns
description: Use when applying TCA architectural ideas (reducer thinking, explicit actions, cancellation IDs, dependency injection, feature modules) WITHOUT the full TCA framework. Patterns work in plain @Observable + SwiftUI code.
---

# TCA-Inspired Patterns Without The Framework

TCA encodes valuable architectural ideas: explicit state transitions, named effects, dependency injection, cancellation semantics. You can adopt those ideas in `@Observable` code without the framework cost.

## When To Use These Patterns

These patterns shine in `@Observable` models when:
- State has multiple possible transitions (not just "set this value")
- You have concurrent async work that needs coordination or cancellation
- You want testability without TCA's TestStore
- You need a clear protocol for what the view can do to the model

## Pattern 1: Explicit Action Enum

Instead of letting the view call arbitrary methods on the model, define an action enum and route everything through one entry point.

```swift
@Observable
final class CounterModel {
    enum Action {
        case incrementTapped
        case decrementTapped
        case resetTapped
        case setLimit(Int)
    }

    private(set) var count = 0
    private(set) var limit = 100

    func send(_ action: Action) {
        switch action {
        case .incrementTapped:
            guard count < limit else { return }
            count += 1
        case .decrementTapped:
            count = max(0, count - 1)
        case .resetTapped:
            count = 0
        case .setLimit(let newLimit):
            limit = newLimit
            if count > limit { count = limit }
        }
    }
}

// View
Button("+") { model.send(.incrementTapped) }
```

**Why:**
- All state mutations go through one switch — easy to test, easy to log, easy to find
- Reducer thinking without `Reduce { state, action in ... }` ceremony
- View has no access to private state mutation

**When to skip this:**
- For trivial state (just a `@Bindable` Bool toggle), this is overkill

## Pattern 2: Cancellation IDs Without Effect

```swift
@Observable
final class SearchModel {
    private var searchTask: Task<Void, Never>?

    var query = ""
    private(set) var results: [SearchResult] = []

    func send(_ action: Action) {
        switch action {
        case .queryChanged(let text):
            query = text
            searchTask?.cancel()                  // cancel previous
            searchTask = Task { await search() }
        case .cancelSearch:
            searchTask?.cancel()
            searchTask = nil
        }
    }

    private func search() async {
        guard !Task.isCancelled else { return }
        // ... fetch results and update self.results
    }

    enum Action {
        case queryChanged(String)
        case cancelSearch
    }
}
```

**Why:** TCA's `.cancellable(id:)` is just a stored Task with cancellation. You don't need Effect.

## Pattern 3: Dependency Injection Without `@Dependency`

```swift
protocol UserService {
    func fetchUser(id: UUID) async throws -> User
}

@Observable
final class ProfileModel {
    private let userService: UserService

    init(userService: UserService) {
        self.userService = userService
    }

    private(set) var user: User?

    func loadUser(id: UUID) async {
        user = try? await userService.fetchUser(id: id)
    }
}

// App composition
@main
struct MyApp: App {
    let userService: UserService = LiveUserService()

    var body: some Scene {
        WindowGroup {
            ProfileView(model: ProfileModel(userService: userService))
        }
    }
}

// Tests
let model = ProfileModel(userService: MockUserService())
```

**Why:** Constructor injection is honest. You see exactly what the model needs. Test overrides are trivial.

**When to add `swift-dependencies`:**
- 10+ services with frequent test overrides
- You want `withDependencies` scoping for tests
- You're sharing services across many models and constructor injection is painful

The library works without TCA. Adopt it when the friction justifies the abstraction.

## Pattern 4: Feature Modules

Organize by feature, not by type.

```
Features/
├── Profile/
│   ├── ProfileModel.swift
│   ├── ProfileView.swift
│   ├── ProfileServices.swift     # protocols + live impls for this feature
│   └── Components/
├── Search/
│   ├── SearchModel.swift
│   ├── SearchView.swift
│   └── Components/
└── Settings/
    ├── SettingsModel.swift
    ├── SettingsView.swift
    └── Components/
```

Cross-feature shared code goes in `Shared/` or `Domain/`.

**Why:** A feature is the unit of change. Putting all of its files together makes the change cheap.

## Pattern 5: Testable @Observable Models

```swift
@Test func testCounterIncrements() {
    let model = CounterModel()
    model.send(.incrementTapped)
    #expect(model.count == 1)
    model.send(.incrementTapped)
    model.send(.incrementTapped)
    #expect(model.count == 3)
}

@Test func testCounterRespectsLimit() {
    let model = CounterModel()
    model.send(.setLimit(2))
    model.send(.incrementTapped)
    model.send(.incrementTapped)
    model.send(.incrementTapped)
    #expect(model.count == 2)  // didn't go past limit
}
```

**Why:** Pure-function `send(_:)` is testable. No TestStore needed. The `@Observable` macro doesn't get in the way.

## When To Graduate To Full TCA

If you find yourself reinventing:
- Reducer composition (parent feature with child features sharing state)
- Exhaustive test assertions (every state change verified)
- Centralized effect cancellation across the app
- Complex navigation state machines with deep links

That's the threshold. Adopting TCA from a codebase that already uses these patterns is straightforward — your action enums and cancellation patterns translate directly.
