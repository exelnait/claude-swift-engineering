# Style Guide — Architecture Documentation

Sentence-level and formatting conventions for architecture docs.

---

## File:Line References

Format: `` `FileName.swift:42` `` — always in inline code, always with extension, always with line number.

**Correct:**
- `` `FeatureModel.swift:38` ``
- `` `AppEntry.swift:18` ``

**Wrong:**
- `FeatureModel` (no extension, no line)
- `the model file` (prose, not a reference)
- `FeatureModel.swift` (no line number — where do I look?)

When lines shift in a refactor, update the reference in the same commit. If you can't do it atomically, add `TODO(doc): update line reference` in the doc.

---

## Rationale Dimension Labels

Place rationale dimensions in italics directly under the section heading, before the prose:

```markdown
## §C News pipeline

*iOS limit, Performance.*

The pipeline is triggered by...
```

**Conventions:**
- Capitalize the dimension name
- Separate multiple dimensions with `, `
- Don't add prose explanation on the same line — let the label be scannable

**Five valid labels:**
- `Performance`
- `Optimisation`
- `iOS limit`
- `UX trade-off`
- `Science`

---

## Section Anchors

Use `§A`, `§B`, `§C` etc. as section prefixes for cross-doc linking:

```markdown
## §A App boot

## §B Performance ledger
```

This lets cross-doc links be specific: "see `persistence.md` §B" rather than "see persistence.md".

---

## Tables

Use tables for systematic data — never for one-off relationships.

**Good use of tables:**
- Performance ledger (constant, location, reason, iOS limit)
- State transitions (event, from-state, to-state)
- Store decision matrix (scenario, recommendation)

**Bad use of tables:** Putting one relationship in a 2-row table. Write prose instead.

---

## Code Snippets

Add code snippets ONLY when the pattern is non-obvious. Ask: "Would a skilled Swift developer expect this?" If yes, no snippet. If no, a snippet is justified.

**Non-obvious (snippet justified):**
- A workaround for an iOS 26 ANE crash
- A custom `DatabaseFunction` in GRDB
- A specific actor isolation pattern that surprised you

**Obvious (no snippet needed):**
- Creating an `@Observable` class
- Using `.task { }` for async work
- Defining a SwiftData `@Model`

---

## Voice and Tense

- Present tense. "The hot path returns immediately when..." not "The hot path will return..."
- Active voice. "SwiftData owns the entity" not "The entity is owned by SwiftData"
- Direct. "See `FeatureModel.swift:38`" not "You can find this in `FeatureModel.swift` around line 38"

---

## The "One-Sentence Summary" Rule

Every doc starts with one sentence that states what the doc covers AND what it does NOT cover:

**Good:**
> Covers the load path when a user enters the feature. Does NOT cover background warm-up (see `warmup-flow.md`).

**Bad:**
> This document describes the feature loading flow.

The "does NOT cover" part is as important as what it does cover. It tells the reader whether to keep reading or go elsewhere.

---

## Non-Goals Entry Format

Each non-goals entry follows the pattern: `**Bold title.** One sentence explanation.`

```markdown
- **No background prefetch at launch.** ANE crashes on first cold boot — see crash report in commit abc123.
- **No CloudKit sync.** Separate milestone; requires entitlement and public container.
```

Never write non-goals as TODOs or wishes. Write them as scars: things you tried or considered and deliberately rejected.

---

## Cross-Doc Link Format

End of every doc, cross-doc links section:

```markdown
## Cross-doc links

- Where X populates Y: `other-doc.md` §B.
- How Z feeds into W: `another-doc.md` §A.
```

Every sentence follows: "What the relationship is: `doc.md` §section."
