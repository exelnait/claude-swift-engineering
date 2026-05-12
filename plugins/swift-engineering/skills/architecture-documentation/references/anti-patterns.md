# Architecture Documentation Anti-Patterns

Common mistakes that reduce the value of architecture docs, with explanations and fixes.

---

## 1. Tutorial-Style Prose

**Anti-pattern:**
> First, you create a `Note` model. Then, you add it to the `ModelContainer`. Next, you use `@Query` in your view to fetch notes.

**Why it's bad:** This is a "how to" guide. Developers who read architecture docs already know Swift and SwiftUI. You're wasting their time explaining what they already know.

**Fix:**
> Notes are `@Model` entities managed by the `ModelContainer` initialized in `AppEntry.swift:18`. Views fetch via `@Query` with predicates defined in `NoteList.swift:42`.

---

## 2. Paraphrasing the Code

**Anti-pattern:**
> The load function checks whether content is cached. If it is, it returns the cached version. If not, it fetches from the server.

**Why it's bad:** The reader now has to read BOTH the doc and the code to get the full picture. Paraphrases drift from the implementation and become misleading.

**Fix:**
> Hot path: `FeatureModel.swift:38` — returns immediately if `cachedContent != nil`. Cold path: `ContentService.swift:72` — detached Task, streams response.

---

## 3. Aspirational Documentation

**Anti-pattern:**
> The app should retry failed requests up to 3 times with exponential backoff.

**Why it's bad:** "Should" means it doesn't yet. Future readers assume this is implemented and waste time looking for it.

**Fix:** Document what IS implemented. If backoff isn't done yet:
> Retry is fixed 2s, max 3 attempts (`ConnectionManager.swift:84`). Exponential backoff is NOT implemented (tracked as v2 work). See "Non-goals" section.

---

## 4. Missing Rationale

**Anti-pattern:**
> We use SwiftData for note persistence.

**Why it's bad:** Tells you what, not why. Future sessions will swap it out for GRDB "for performance" without understanding the trade-off.

**Fix:**
> SwiftData for Note entities (*Optimisation*): @Query gives free reactivity for list views, and our note count stays under 10K. See `data-layer-decisions` skill — we'd only add GRDB if we hit FTS5 needs or >10K rows.

---

## 5. No Non-Goals Section

**Anti-pattern:** A doc with only positive descriptions of what's implemented.

**Why it's bad:** Future sessions or developers will try to add the things you deliberately removed. The decision to NOT do something is often as important as what you did.

**Fix:** Every flow doc needs:
```markdown
## Out of scope / non-goals

- **No background prefetch at launch.** ANE crashes on first cold boot — see crash report in commit abc123.
- **No Core Data.** SwiftData for iOS 26+; no migration path needed.
```

---

## 6. No Diagrams

**Anti-pattern:** A 500-word prose description of a multi-component interaction.

**Why it's bad:** Readers need 10 minutes to construct a mental model. A sequence diagram delivers the same information in 60 seconds.

**Fix:** Every non-trivial flow gets at least one Mermaid diagram. If you can't draw the flow, you don't understand it well enough to document it — go read the code again.

---

## 7. ASCII Art Diagrams

**Anti-pattern:**
```
FeatureView --> FeatureModel --> ContentService
                    |
                    v
                 SwiftData
```

**Why it's bad:** Doesn't render in DocC, unreadable on mobile, breaks in narrow terminals, ages poorly as the diagram grows.

**Fix:** Always use Mermaid. See `diagram-cookbook.md` for copy-pasteable templates.

---

## 8. Stale File:Line References

**Anti-pattern:** `See FeatureModel.swift:38` — but you refactored the file and the logic is now on line 94.

**Why it's bad:** Stale references actively mislead. Readers trust the doc and go to the wrong line.

**Fix:** Update file:line references in the same commit as the code change. If you can't do this atomically, leave a `TODO(doc): update line reference after refactor` comment in the doc so the next person knows.

---

## 9. Cross-Doc Links Without Anchors

**Anti-pattern:**
> For details, see `persistence.md`.

**Why it's bad:** The reader has to scan the entire doc to find the relevant section.

**Fix:**
> For details, see `persistence.md` §B — SwiftData entity schema.

---

## 10. Documenting Internal Implementation Details

**Anti-pattern:** A 3-section doc on how `private func buildCacheKey()` works.

**Why it's bad:** Private implementation details change constantly. Documenting them creates doc debt without architectural value.

**Fix:** Document the public contract and the rationale. The cache key is an implementation detail; what the cache decision threshold is (and why) is the architectural fact worth capturing.
