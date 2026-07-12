# Platform Gating: Conditional Compilation Done Right

The goal of gating is **not** to write `#if os(iOS)` everywhere — it is to isolate each platform difference at exactly one seam so the rest of your code stays platform-free. Scattered `#if` is the smell; a single bridge is the cure. This file is the mechanics behind rungs 2 and 4 of the divergence ladder.

## `canImport` beats `os()`

Two ways to branch. Prefer the one that asks the question you actually mean.

```swift
#if os(iOS)        // "Is the OS iOS?" — excludes Mac Catalyst-as-Mac edge cases, tvOS, visionOS
#if canImport(UIKit)   // "Is UIKit available here?" — the real question when you need a UIKit type
```

- **Use `canImport(UIKit)` / `canImport(AppKit)`** when you branch because a *framework or type* exists on one side. It is precise: `UIKit` is importable on iOS, iPadOS, tvOS, visionOS, and Mac Catalyst; `AppKit` on macOS. This is what you want for `UIColor`/`NSColor`, representables, pasteboards, etc.
- **Use `os(iOS)` / `os(macOS)`** when the branch is genuinely about the operating system's *behavior or idiom* (a Mac-only menu command, an iOS-only capability), not merely which framework is present.
- **Availability is a different axis.** `#if` chooses what *compiles*; `if #available(iOS 26, *)` / `@available` choose what *runs* on an OS version. Don't reach for `#if` when you mean a runtime version check. (This plugin's baseline is iOS 26 / current macOS, so version guards are rare — platform guards are the common case.)

```swift
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
```

## The golden rule: push the `#if` down

A difference should appear in your codebase **once**, at the lowest level that captures it — never repeated at every call site.

```swift
// ❌ WRONG — the difference is smeared across every use
struct AvatarView: View {
    let data: Data
    var body: some View {
        #if canImport(UIKit)
        Image(uiImage: UIImage(data: data) ?? UIImage())
        #elseif canImport(AppKit)
        Image(nsImage: NSImage(data: data) ?? NSImage())
        #endif
    }
}
// ...and again in ThumbnailView, and HeaderView, and ShareCard...
```

```swift
// ✅ RIGHT — the difference lives in one bridge; call sites are clean
extension Image {
    init(platformData data: Data) {
        #if canImport(UIKit)
        self = Image(uiImage: UIImage(data: data) ?? UIImage())
        #elseif canImport(AppKit)
        self = Image(nsImage: NSImage(data: data) ?? NSImage())
        #endif
    }
}

struct AvatarView: View {
    let data: Data
    var body: some View { Image(platformData: data) }   // no #if here, or anywhere else
}
```

## Bridge kind 1 — platform typealiases

For "same concept, different type per platform," a typealias collapses the difference to a single name. Put them all in one `Platform.swift` (or `PlatformTypes.swift`) file in shared code. This is the canonical pattern from Jesse Squires' *Improving multiplatform SwiftUI code* and Daniel Saidi's *bridging platform-specific types*.

```swift
// Platform.swift — the whole app's platform-type vocabulary, in one place.
#if canImport(UIKit)
import UIKit
public typealias PlatformColor = UIColor
public typealias PlatformImage = UIImage
public typealias PlatformFont  = UIFont
public typealias PlatformViewRepresentable = UIViewRepresentable
#elseif canImport(AppKit)
import AppKit
public typealias PlatformColor = NSColor
public typealias PlatformImage = NSImage
public typealias PlatformFont  = NSFont
public typealias PlatformViewRepresentable = NSViewRepresentable
#endif
```

Now shared code names `PlatformImage` and never sees `#if` again:

```swift
func makeThumbnail(from original: PlatformImage) -> PlatformImage { /* shared logic */ }
```

**But prefer SwiftUI-native types first (rung 1).** Reach for `PlatformColor`/`PlatformImage` only when you truly need the UIKit/AppKit type (interop, a framework that returns it). For ordinary UI, `Color`, `Image`, and `Font` are already cross-platform and need no bridge at all. The bridge is for the interop boundary, not for everyday views.

### Bridging a representable

`UIViewRepresentable` and `NSViewRepresentable` have almost the same shape but different method names (`makeUIView`/`updateUIView` vs `makeNSView`/`updateNSView`). When wrapping a platform view, gate the whole wrapper:

```swift
#if canImport(UIKit)
struct WebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView { WKWebView() }
    func updateUIView(_ view: WKWebView, context: Context) { view.load(URLRequest(url: url)) }
}
#elseif canImport(AppKit)
struct WebView: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> WKWebView { WKWebView() }
    func updateNSView(_ view: WKWebView, context: Context) { view.load(URLRequest(url: url)) }
}
#endif
// Callers write `WebView(url:)` with no knowledge of the split.
```

### Typealias + extension: bridge the *behavior*, not just the type

A typealias collapses the type; an extension on it collapses the *behavior* difference too, so the call site is one clean cross-platform API. Jesse Squires' canonical example is the clipboard — `UIPasteboard` on iOS vs `NSPasteboard` on macOS, which even differ in how you set a string:

```swift
#if os(macOS)
import AppKit
typealias XPasteboard = NSPasteboard
#else
import UIKit
typealias XPasteboard = UIPasteboard
#endif

extension XPasteboard {
    func copyText(_ text: String) {
        #if os(macOS)
        clearContents()
        setString(text, forType: .string)   // AppKit's two-step API
        #else
        string = text                        // UIKit's one-liner
        #endif
    }
}
```

```swift
// Call site — a single cross-platform API, no #if in sight:
XPasteboard.general.copyText(someText)
```

The `#if` that reconciles the two frameworks lives once, inside `copyText`. Every caller stays clean. Apply the same shape to any "similar but not identical" AppKit/UIKit pair you keep reaching for.

## Bridge kind 2 — no-op custom view modifiers

For "an iOS-only modifier that should simply do nothing on Mac," wrap it in a custom modifier that applies on iOS and returns the view unchanged on macOS. Call sites then use *your* modifier with zero `#if`, and it reads as a normal SwiftUI chain.

```swift
extension View {
    /// Applies an inline navigation-bar title mode on iOS; a no-op on macOS,
    /// which has no navigation bar. Call sites stay platform-free.
    func inlineNavigationBarTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
```

```swift
// Feature code — clean, no #if, works on both platforms:
List { /* ... */ }
    .navigationTitle("Inbox")
    .inlineNavigationBarTitle()
```

Generalize this for any iOS-only styling: `.keyboardType`, `.textInputAutocapitalization`, `.listStyle(.insetGrouped)`, `.statusBarHidden` — each becomes one small no-op-on-Mac modifier. See **API Divergence Catalog** for the full list of which modifiers need this treatment and their exact signatures.

## Bridge kind 3 — platform-value initializers (Jesse Squires)

When only a *value* differs per platform — a padding, a width, a font size — don't wrap the whole modifier in `#if`. Add an initializer to the value's type that picks the right constant. This is Jesse Squires' pattern from *Improving multiplatform SwiftUI code*, and it turns ugly, hard-to-read `#if` ladders into a single legible call.

```swift
// The #if-riddled original — cognitive load, and Xcode formats #if hideously:
var body: some View {
    MyCustomView()
    #if os(iOS)
        .padding(10)
    #elseif os(watchOS)
        .padding(4)
    #else // macOS
        .padding(24)
    #endif
}
```

Add a value initializer once:

```swift
extension Double {
    init(iOS: Self, watchOS: Self, macOS: Self) {
        #if os(iOS)
        self = iOS
        #elseif os(watchOS)
        self = watchOS
        #else // macOS
        self = macOS
        #endif
    }
}
```

Now the call site reads cleanly — it's obvious the view always wants padding and that the amount is platform-specific:

```swift
var body: some View {
    MyCustomView()
        .padding(Double(iOS: 10, watchOS: 4, macOS: 24))
}
```

Prefer to go one step further and lift the pattern into the **modifier** itself, so the `#if` disappears from the value too:

```swift
extension View {
    func padding(iOS: CGFloat, watchOS: CGFloat, macOS: CGFloat) -> some View {
        self.padding(Double(iOS: iOS, watchOS: watchOS, macOS: macOS))
    }
}

// Call site — the cleanest form:
MyCustomView().padding(iOS: 10, watchOS: 4, macOS: 24)
```

Use this for any purely-numeric or purely-value platform difference (padding, corner radius, frame sizes, font sizes, spacing). It complements the metrics-protocol approach in **Layered Architecture**: reach for a metrics value when many views share a coherent set of platform constants (sidebar width, toolbar height); reach for this initializer for one-off local values.

## Jesse Squires' rule: bridge small differences, split large ones

*How much* the platforms differ decides your tool:

- **Views share the majority of their UI, differing in a modifier or two** → keep one shared view and extract each difference into a bridge (typealias or custom modifier) as above. Don't fork the whole view over a one-line difference (Common Mistake #3).
- **Views genuinely diverge** (different layout, different controls, different interaction model) → build **entirely separate views per platform** and let a *single* `#if` at the top choose which to instantiate. This keeps each platform's view readable instead of riddling one view with branches.

```swift
// The difference is large enough to warrant separate views — one #if, at the top.
struct SettingsScreen: View {
    var body: some View {
        #if os(macOS)
        MacSettingsView()   // TabView-of-panes, fixed width — the Mac Settings idiom
        #else
        iOSSettingsView()   // a NavigationStack of grouped rows
        #endif
    }
}
```

Put the two implementations in `MacSettingsView.swift` and `iOSSettingsView.swift` (see **Project Structure** for file-naming), each free of `#if` internally.

If you'd rather keep both bodies in one type, Jesse Squires' structure isolates the split to a single `#if` in `body` that delegates to per-platform computed properties — still readable, no scattered branches:

```swift
struct MyPlatformSpecificView: View {
    var body: some View {
        #if os(iOS)
        body_iOS
        #else // macOS
        body_macOS
        #endif
    }
    private var body_iOS:   some View { /* the iOS-only body */ }
    private var body_macOS: some View { /* the macOS-only body */ }
}
```

Either shape is fine; the rule is the same — **one** `#if` chooses the whole body, and neither branch is polluted by the other's concerns.

## Excluding a capability (rung 4) — keep the Mac build whole

When a capability has no Mac analog, gate its implementation **and** its entry point, so the Mac build both compiles and stays coherent.

```swift
struct ScanButton: View {
    let onScan: (ScanResult) -> Void
    var body: some View {
        #if os(iOS)
        Button("Scan with Camera", systemImage: "camera") { presentScanner() }
        #else
        // No camera-scan on Mac — offer the sensible alternative, not a dead button.
        Button("Import File…", systemImage: "square.and.arrow.down") { presentFileImporter() }
        #endif
    }
}
```

If you cannot offer an alternative, omit the control on Mac entirely — never leave a visible button that does nothing. And make sure *every* reference to the excluded symbol (the scanner type, its delegate, its model fields) sits behind the same `#if`, or the build re-breaks (Common Mistake #10).

## Anti-patterns

- **`#if` inside a `body` around a single call site you could bridge.** Almost always wrong — lift it into a modifier or typealias.
- **`os(iOS)` where you meant `canImport(UIKit)`.** You'll surprise yourself on Catalyst/visionOS. Ask "which *framework*?" not "which OS?" when the branch is about a type.
- **A `#else` that silently drops behavior on Mac** without a comment. Every `#else` that changes behavior deserves a one-line note on what the Mac path does and why.
- **Parallel `#if` blocks that must stay in sync.** If you find yourself editing the iOS branch and the macOS branch of the same logic in lockstep, you have the difference at the wrong level — push it into one bridge.
