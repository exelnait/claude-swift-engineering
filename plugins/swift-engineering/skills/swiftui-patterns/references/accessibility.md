# Accessibility Patterns

## VoiceOver Support

**Use for:** Screen reader accessibility

```swift
struct ArticleRow: View {
    let article: Article

    var body: some View {
        HStack {
            AsyncImage(url: article.imageURL) { image in
                image.resizable()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 80, height: 80)
            .accessibilityHidden(true) // Decorative image

            VStack(alignment: .leading) {
                Text(article.title)
                    .font(.headline)
                Text(article.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(article.title), by \(article.author)")
        .accessibilityHint("Double tap to read article")
    }
}
```

## Dynamic Type Support

**Use for:** Text that scales with user preferences

```swift
struct ArticleContent: View {
    let article: Article
    @ScaledMetric private var imageHeight: CGFloat = 200

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AsyncImage(url: article.imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(height: imageHeight) // Scales with Dynamic Type
                .clipped()

                Text(article.title)
                    .font(.title)

                Text(article.content)
                    .font(.body)
            }
        }
    }
}
```

## Accessibility Actions

**Use for:** Custom VoiceOver actions

```swift
struct ArticleCard: View {
    let article: Article
    @State private var isSaved = false
    @State private var isShared = false

    var body: some View {
        VStack {
            Text(article.title)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(article.title)
        .accessibilityAction(named: "Save") {
            isSaved.toggle()
        }
        .accessibilityAction(named: "Share") {
            isShared = true
        }
    }
}
```

## Reading / Long-Form Text

**Use for:** Articles, books, or any multi-paragraph reading content where
VoiceOver and Speak Screen should move fluidly by line, sentence, word, and
character — and read continuously across pages.

```swift
struct ReadingPage: View {
    @Namespace private var readingNamespace
    let paragraphs: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(paragraphs.indices, id: \.self) { index in
                    paragraph(paragraphs[index], isLast: index == paragraphs.count - 1)
                }
            }
        }
        // Continuous read-all turns the page when reaching the end.
        .accessibilityScrollAction { _ in advanceToNextPage() }
    }

    @ViewBuilder
    private func paragraph(_ text: String, isLast: Bool) -> some View {
        let content = Text(text)
            .font(.body)                 // Dynamic Type
            .textSelection(.enabled)     // accessible selection for free
            .accessibilityAddTraits(isLast ? [.causesPageTurn] : [])

        // iOS 27+: link elements so line navigation flows across paragraphs.
        if #available(iOS 27, *) {
            content.accessibilityLinkedGroup(id: "page", in: readingNamespace)
        } else {
            content
        }
    }
}
```

> Prefer `Text` with selection / `TextEditor` over custom rendering — they adopt
> `UITextInput` and give granular navigation and selection for free. For custom
> or image-backed text, adopt `UITextInput` fully (UIKit). See the iOS HIG
> [Reading Accessibility](../../ios-hig/references/reading-accessibility.md)
> reference for the complete checklist.
