# Swift 6.4

Everyday language refinements in Swift 6.4 that smooth the rough edges of migrations, multi-platform availability, async cleanup, and type-checking.

> **Swift 6.4 is a recent release** (announced at WWDC 2026, "Platforms State of the Union") and is newer than most training data. The features below are grounded in that talk. Exact attribute and flag spellings are still settling — confirm against the current Swift documentation and Swift Evolution proposals before depending on them.

## Where Swift 6.4 Fits

Swift is positioned as a full-stack language: beyond Apple platforms, the toolchains for Linux, Windows, Android, and the web (via WebAssembly) live on [Swift.org](https://swift.org), and C/C++/Java interoperability lets you fold Swift into existing systems without a rewrite. This reference covers the day-to-day 6.4 language features you reach for in app code.

## Scoped Warning Control

When a codebase is mid-migration or incrementally adopting a feature, fixing every warning at once often isn't realistic. Swift 6.4 lets you control diagnostics *per scope* — silence the noise where you've deliberately accepted it, and promote warnings to hard errors where you want strict enforcement — instead of only flipping a single module-wide switch.

### Scoped, in the source

Annotate a declaration to change how a diagnostic *group* behaves inside it. Per Swift Evolution (SE-0522), the attribute is spelled `@diagnose` and takes a diagnostic group, a behavior (`ignored`, `warning`, or `error`), and an optional `reason:`.

```swift
// Suppress one warning group in a place you've deliberately accepted it
@diagnose(DeprecatedDeclaration, as: ignored, reason: "Bridging to the legacy store until v2")
func syncWithLegacyStore() {
    oldMigrateAPI()   // no deprecation warning here
}

// Promote a group to an error where you want strict enforcement
@diagnose(DeprecatedDeclaration, as: error)
struct PaymentFlow {
    // Any deprecated-API use inside PaymentFlow now fails the build
}
```

Inner scopes override outer ones, so you can set a strict default on a type and carve out exceptions on individual members.

> **Hedge:** the talk describes this capability but does not name the attribute. `@diagnose` and its arguments come from the SE-0522 proposal and may differ in the shipped toolchain — verify the exact spelling, and the diagnostic group names, against the Swift 6.4 documentation.

### Module-wide (compiler flags)

To control a whole target rather than a scope, use the diagnostic-group compiler flags (established in Swift 6.1, SE-0443):

```bash
# Promote every warning to an error, but keep one group as warnings during a migration
swiftc ... -warnings-as-errors -Wwarning DeprecatedDeclaration
```

In a Swift package, carry the flags through `swiftSettings`:

```swift
.target(
    name: "PaymentKit",
    swiftSettings: [
        .unsafeFlags(["-Werror", "DeprecatedDeclaration"])
    ]
)
```

The group name is one of Swift's diagnostic-group identifiers; check the current docs for the full list. (Recent SwiftPM tools-versions also expose dedicated `SwiftSetting` helpers that avoid `.unsafeFlags` — prefer those if your tools-version has them.)

Rule of thumb: reach for `@diagnose` when the scope is a few declarations; reach for flags when it's the whole target.

## `anyAppleOS` Availability Shorthand

`@available` attributes get long and repetitive when the same version applies to every Apple platform. Swift 6.4 adds `anyAppleOS` as a shorthand meaning "all Apple OSes at this version."

**Before — one clause per platform:**
```swift
@available(iOS 27, macOS 27, watchOS 27, tvOS 27, visionOS 27, *)
func renderLiquidGlassBackground() { ... }
```

**After — Swift 6.4:**
```swift
@available(anyAppleOS 27, *)
func renderLiquidGlassBackground() { ... }
```

The trailing `*` is still required — it covers any future platform, exactly as before. When one platform differs, layer a more specific attribute on top of the shorthand:

```swift
@available(anyAppleOS 27, *)
@available(tvOS, unavailable)   // everything at 27, except tvOS
func requestHapticFeedback() { ... }
```

## `await` Inside `defer`

The old restriction on async calls in a `defer` block is gone (SE-0493). You now write `await` inside `defer` exactly as you would anywhere else — there is no new syntax — as long as the enclosing function is `async`. Deferred async work is implicitly awaited at every exit point.

```swift
func processUpload(_ file: URL) async throws {
    let handle = await pool.acquireConnection()
    defer { await pool.release(handle) }   // runs on every return / throw path

    try await handle.send(file)            // release() is still awaited afterwards, even if this throws
}
```

- **Isolation:** the `defer` body inherits the enclosing scope's isolation. Inside a `@MainActor` function it runs on the main actor; inside an actor method, on that actor. It introduces no suspension points beyond the ones its own calls introduce.
- **Cancellation:** deferred code observes the task's cancellation state like any other code — if the task is cancelled, the `defer` body sees it.

This replaces the old workarounds: spawning a detached `Task` for cleanup (which lost the lifetime guarantee) or hand-writing cleanup before every `return` and `throw`.

## Better Type-Check Diagnostics

You have probably hit this fallback error:

> The compiler is unable to type-check this expression in reasonable time; try breaking up the expression into distinct sub-expressions

It shows up in complex operator expressions, large closures, and deeply nested SwiftUI view bodies. Swift 6.4 improves this substantially: in many common cases, code that used to hit this error now either compiles successfully or produces a more actionable error instead.

When you still run into it, the fix is to give the type checker less to solve at once:

1. **Split the expression.** Break long operator chains or nested ternaries into intermediate `let` bindings with explicit types.
2. **Annotate types.** Pin down ambiguous literals and collections (`let ids: [Int64] = [...]`) so the solver isn't inferring them from scratch.
3. **Decompose SwiftUI bodies.** Extract nested view trees into smaller subviews or `@ViewBuilder` computed properties — each type-checks independently.
4. **Constrain overloaded operators.** Add explicit types around mixed-type arithmetic and heavily overloaded operators so the compiler doesn't explore every overload combination.

These are the same techniques as before, but on 6.4 you should need them far less often.
