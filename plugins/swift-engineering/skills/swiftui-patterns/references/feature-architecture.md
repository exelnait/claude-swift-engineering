# Feature Architecture — @Observable + SwiftData + SwiftUI

**iOS 26+**

The default architecture for a feature in this plugin: one `@Observable` model per feature folder, one SwiftData `@Model` per entity, one SwiftUI view. Services are injected via initializer or `@Environment`.

## Feature Folder Structure

```
Features/
└── Notes/
    ├── NotesModel.swift     # @Observable model — all business logic
    ├── NotesView.swift      # SwiftUI view — declarative only
    └── Components/
        ├── NoteRow.swift    # Subview — composable
        └── NoteEditor.swift # Subview — focused on editing
```

Entity definitions live in `Models/`:
```
Models/
└── Note.swift               # @Model entity — SwiftData
```

## The @Observable Model

```swift
// NotesModel.swift
import SwiftData

@Observable
@MainActor
final class NotesModel {
    // MARK: - Properties
    private(set) var notes: [Note] = []
    private(set) var isLoading = false
    var searchQuery = ""

    private let modelContext: ModelContext
    private let searchStore: SearchIndexStore

    // MARK: - Initialization
    init(modelContext: ModelContext, searchStore: SearchIndexStore) {
        self.modelContext = modelContext
        self.searchStore = searchStore
    }

    // MARK: - Public Methods
    func load() async {
        isLoading = true
        defer { isLoading = false }
        let descriptor = FetchDescriptor<Note>(sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)])
        notes = (try? modelContext.fetch(descriptor)) ?? []
    }

    func save(title: String, body: String) throws {
        let note = Note(title: title, body: body)
        modelContext.insert(note)
        try modelContext.save()
        notes.insert(note, at: 0)
    }

    func delete(_ note: Note) throws {
        modelContext.delete(note)
        try modelContext.save()
        notes.removeAll { $0.id == note.id }
    }
}
```

## The SwiftData Entity

```swift
// Models/Note.swift
import SwiftData

@Model
final class Note {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var modifiedAt: Date

    init(title: String, body: String) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}
```

## The SwiftUI View

```swift
// NotesView.swift
import SwiftUI

struct NotesView: View {
    @State private var model: NotesModel
    @State private var showingEditor = false

    init(modelContext: ModelContext, searchStore: SearchIndexStore) {
        _model = State(wrappedValue: NotesModel(modelContext: modelContext, searchStore: searchStore))
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading {
                    ProgressView()
                } else if model.notes.isEmpty {
                    ContentUnavailableView("No Notes", systemImage: "note.text")
                } else {
                    List(model.notes) { note in
                        NoteRow(note: note)
                    }
                }
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", systemImage: "plus") {
                        showingEditor = true
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                NoteEditor { title, body in
                    try model.save(title: title, body: body)
                    showingEditor = false
                }
            }
        }
        .task { await model.load() }
    }
}
```

## Injecting via @Environment

For cross-feature shared services, use `@Environment`:

```swift
// App entry
@main
struct MyApp: App {
    let modelContainer: ModelContainer
    let searchStore: SearchIndexStore

    init() {
        modelContainer = try! ModelContainer(for: Note.self)
        searchStore = try! SearchIndexStore()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(modelContainer)
                .environment(searchStore)
        }
    }
}

// Feature view — accesses shared service from environment
struct NotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SearchIndexStore.self) private var searchStore
    // ...
}
```

## Cross-Feature Model Composition

When two features share state (e.g., a selected item), pass the shared model via initializer rather than reaching into another feature's model.

```swift
// Parent composes child models
struct AppRootView: View {
    @State private var notesModel: NotesModel
    @State private var searchModel: SearchModel

    // Both models share the same searchStore — no state duplication
    init(modelContext: ModelContext, searchStore: SearchIndexStore) {
        _notesModel = State(wrappedValue: NotesModel(modelContext: modelContext, searchStore: searchStore))
        _searchModel = State(wrappedValue: SearchModel(searchStore: searchStore))
    }

    var body: some View {
        TabView {
            NotesView(model: notesModel)
                .tabItem { Label("Notes", systemImage: "note.text") }
            SearchView(model: searchModel)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
        }
    }
}
```

## TCA-Inspired Patterns in @Observable Models

For models with multiple state transitions, use an explicit action enum (see `tca-inspired-patterns` skill):

```swift
@Observable
@MainActor
final class NotesModel {
    enum Action {
        case viewAppeared
        case addNoteTapped(title: String, body: String)
        case deleteNote(Note)
        case searchQueryChanged(String)
    }

    private(set) var notes: [Note] = []

    func send(_ action: Action) async throws {
        switch action {
        case .viewAppeared:
            await load()
        case .addNoteTapped(let title, let body):
            try save(title: title, body: body)
        case .deleteNote(let note):
            try delete(note)
        case .searchQueryChanged(let query):
            await search(query: query)
        }
    }
}
```

Use this pattern when: state has 3+ transition types, you want to log all mutations, or you're testing the model directly.
