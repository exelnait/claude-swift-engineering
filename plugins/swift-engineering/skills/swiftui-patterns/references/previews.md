# SwiftUI Preview Best Practices (iOS 26+)

## The Rule

**Every UI component file MUST end with a `#Preview` block.** No exceptions — not for "simple" components, not for "internal" subviews, not for work-in-progress.

A preview that doesn't exist cannot catch regressions. A preview with `EmptyView()` is worse than useless — it creates false confidence.

---

## Basic `#Preview`

For components with no SwiftData or complex dependencies:

```swift
struct TagBadgeView: View {
    let tag: String
    let color: Color

    var body: some View {
        Text(tag)
            .padding(.horizontal, 8)
            .background(color.opacity(0.2))
            .clipShape(.capsule)
    }
}

#Preview {
    TagBadgeView(tag: "Swift", color: .blue)
}
```

---

## `@Previewable` for Bindings and Local State

Use `@Previewable` to declare `@State` directly inside `#Preview`. This eliminates the old pattern of wrapping in a helper struct.

```swift
// Old pattern — do not use
struct PreviewWrapper: View {
    @State var isOn = false
    var body: some View { ToggleRow(isOn: $isOn) }
}
#Preview { PreviewWrapper() }

// Correct iOS 26+ pattern
#Preview {
    @Previewable @State var isOn = false
    ToggleRow(isOn: $isOn)
}
```

Works for any property wrapper: `@State`, `@FocusState`, `@GestureState`.

---

## Protocol-Based Mock Injection

The scalable pattern: views depend on a protocol, not a concrete type. The preview provides a lightweight mock; production uses the real implementation.

```swift
// 1. Define the protocol
protocol NoteStoreProtocol {
    var notes: [Note] { get }
    func delete(_ note: Note)
}

// 2. Production store (reads from SwiftData context)
@Observable
final class NoteStore: NoteStoreProtocol {
    private(set) var notes: [Note] = []
    // ... real implementation
}

// 3. Preview mock — lives in the same file or a PreviewHelpers file
final class MockNoteStore: NoteStoreProtocol {
    var notes: [Note]
    init(notes: [Note] = Note.previews) { self.notes = notes }
    func delete(_ note: Note) { notes.removeAll { $0.id == note.id } }
}

// 4. View accepts the protocol
struct NoteListView: View {
    let store: any NoteStoreProtocol
    // ...
}

// 5. Preview uses the mock
#Preview("Populated") {
    NoteListView(store: MockNoteStore())
}

#Preview("Empty") {
    NoteListView(store: MockNoteStore(notes: []))
}
```

This keeps previews stable even as the real `NoteStore` gains SwiftData, networking, or caching logic.

---

## Static Preview Factories

Add a `previews` extension to your model types for canonical sample data. Keep it in a `#if DEBUG` block so it never ships.

```swift
#if DEBUG
extension Note {
    static let preview = Note(title: "Meeting Notes", body: "Discussed Q3 roadmap.", isPinned: true)

    static let previews: [Note] = [
        Note(title: "Meeting Notes", body: "Discussed Q3 roadmap.", isPinned: true),
        Note(title: "Shopping List", body: "Milk, eggs, coffee.", isPinned: false),
        Note(title: "Ideas", body: "Rewrite in Swift.", isPinned: false),
    ]
}
#endif
```

Reference `Note.preview` or `Note.previews` in any `#Preview` block without constructing data inline.

---

## SwiftData In-Memory `ModelContainer`

For views that use `@Query` or receive a `ModelContext` via `@Environment`, inject an in-memory container. The container is isolated — it never touches the on-disk store.

```swift
// PreviewHelpers.swift (shared across feature previews)
#if DEBUG
import SwiftData

@MainActor
func makePreviewContainer(_ types: any PersistentModel.Type...) -> ModelContainer {
    let schema = Schema(types)
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try! ModelContainer(for: schema, configurations: [config])
}

// Seeded variant — inserts sample objects before returning
@MainActor
func makeNotesPreviewContainer() -> ModelContainer {
    let container = makePreviewContainer(Note.self, Tag.self)
    let ctx = container.mainContext
    Note.previews.forEach { ctx.insert($0) }
    return container
}
#endif
```

Use in previews:

```swift
#Preview("Note list") {
    NoteListView()
        .modelContainer(makeNotesPreviewContainer())
}

#Preview("Empty state") {
    NoteListView()
        .modelContainer(makePreviewContainer(Note.self))
}
```

**Why `try!` is acceptable here:** Preview helpers are `#if DEBUG` only. A crash at preview-load time is an immediately visible developer error, not a user-facing failure.

---

## Multiple Named Variants

Provide separate named previews for every meaningful state. Xcode shows them as a gallery.

```swift
// States
#Preview("Populated") { NoteListView(store: MockNoteStore(notes: Note.previews)) }
#Preview("Empty")     { NoteListView(store: MockNoteStore(notes: [])) }
#Preview("Loading")   { NoteListView(store: MockNoteStore(notes: [], isLoading: true)) }

// Appearance
#Preview("Dark mode", traits: .init(userInterfaceStyle: .dark)) {
    NoteListView(store: MockNoteStore())
}

// Accessibility
#Preview("Large text", traits: .accessibilityLargeContentViewer) {
    NoteListView(store: MockNoteStore())
}

// Layout
#Preview("Compact", traits: .sizeThatFitsLayout) {
    NoteRowView(note: .preview)
}
```

At minimum, cover: **populated**, **empty**, and **dark mode**.

---

## Anti-Patterns

| Anti-pattern | Why it's wrong | Fix |
|---|---|---|
| `#Preview { EmptyView() }` | Hides real state, gives false confidence | Use real data via mock or static factory |
| `#Preview { NoteListView() }` (live container) | Reads from on-disk store; pollutes production data | Inject in-memory container |
| Skipping preview for "simple" subviews | Regressions happen in simple views too | Every file gets a `#Preview` |
| Helper struct with `@State` wrapping | Verbose, obsolete | Use `@Previewable @State` |
| `@Environment` values not injected | Preview crashes or shows wrong behavior | Mock or inject every environment dependency used |
| One giant preview for a multi-state component | You only see one state at a time | Name and split into separate `#Preview` blocks |
