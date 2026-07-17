# Toolbar Adaptation

> The toolbar-adaptation APIs below (`visibilityPriority`, the toolbar overflow menu container, the `topBarPinnedTrailing` placement, and the prominent `tabRole`) are WWDC 26 / iOS 27-era additions, newer than this guidance's training data. Confirm exact spelling, signatures, and availability against current Apple documentation before shipping.

When a window can be any size (resizable iPhone, iPad Split View / Stage Manager, Mac mirroring, foldables — the rest of this skill), the **toolbar is one of the first things to run out of room**. Apple's guidance is *not* to truncate or hide items arbitrarily: **rank your toolbar items, let SwiftUI drop the least important ones into an overflow "⋯" menu as space shrinks, and pin the ones that must always be reachable.**

This is the toolbar half of the resizability story from the WWDC 26 *Platforms State of the Union*: "With the new resizability features, optimizing your app for a dynamic range of sizes and aspect ratios is more important than ever. And toolbars are central to that experience." It builds on the automatic behavior introduced in iPadOS 18, where navigation-bar items already moved to an overflow menu when they couldn't fit alongside the tab bar.

## The model: rank → overflow → pin

Three levers, applied per toolbar item. Together they let one toolbar declaration reflow correctly from a wide Mac window down to a narrow phone window.

| Lever | API | Use for |
|-------|-----|---------|
| **Rank** how long an item stays inline | `.visibilityPriority(_:)` (e.g. `.high`) | Primary actions that must survive as the toolbar narrows |
| **Collapse** secondary items into a "⋯" menu | toolbar **overflow menu container** | Archive, delete, sort, info — grouped and tucked away automatically when space is tight |
| **Pin** an item to the trailing edge | `.topBarPinnedTrailing` placement | An action that must always sit in the same reachable spot (e.g. Share), no matter how the bar reflows |

The result: important buttons stay visible, deprioritized ones move into the overflow menu, and the pinned item never leaves the trailing edge.

## `visibilityPriority` — keep the important items longest

Mark your most important items high; SwiftUI keeps them visible **longer** as space shrinks and sheds low-priority items first.

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button("Add", systemImage: "plus") { add() }
            .visibilityPriority(.high)      // survives as the bar narrows
    }
}
```

Items without an elevated priority are the first to move into the overflow menu when the toolbar can't show everything.

## Overflow menu container — a "⋯" home for secondary actions

Group less-prominent actions so the system can tuck them behind a single overflow ("⋯") control when there isn't room to show them inline:

```swift
.toolbar {
    ToolbarOverflowMenu {            // confirm exact container name/API in current docs
        Button("Archive", systemImage: "archivebox") { archive() }
        Button("Sort",    systemImage: "arrow.up.arrow.down") { sort() }
        Button("Delete",  systemImage: "trash", role: .destructive) { delete() }
    }
}
```

On a wide window these can render inline; as the window narrows they collapse into the "⋯" menu instead of overflowing off-screen or fighting the primary actions for space.

## `topBarPinnedTrailing` — always in the same place

Anchor an item to the trailing edge so it stays reachable regardless of how the rest of the toolbar reflows:

```swift
.toolbar {
    ToolbarItem(placement: .topBarPinnedTrailing) {
        ShareLink(item: url)
    }
}
```

Share is the canonical example — pinned trailing, always visible, never swallowed by overflow.

## Prominent tab role — pin a *tab* to the trailing edge

For a top-level destination (not a toolbar action) that deserves a fixed trailing spot, use the prominent tab role — parallel to the search tab role covered in `navigation-adaptation.md`:

```swift
Tab("Record", systemImage: "record.circle", role: .prominent) { RecordView() }
```

## Putting it together

```swift
DocumentView()
    .toolbar {
        // 1. Primary action — ranked high, stays visible longest.
        ToolbarItem(placement: .topBarTrailing) {
            Button("Add", systemImage: "plus") { add() }
                .visibilityPriority(.high)
        }

        // 2. Secondary actions — fold into "⋯" as space shrinks.
        ToolbarOverflowMenu {
            Button("Archive", systemImage: "archivebox") { archive() }
            Button("Sort",    systemImage: "arrow.up.arrow.down") { sort() }
            Button("Delete",  systemImage: "trash", role: .destructive) { delete() }
        }

        // 3. Always pinned to the trailing edge.
        ToolbarItem(placement: .topBarPinnedTrailing) {
            ShareLink(item: url)
        }
    }
```

Drag the window narrower and: the primary **Add** holds, the secondary actions collapse into "⋯", and **Share** stays pinned to the trailing edge.

## How to decide

| The action is… | Reach for |
|----------------|-----------|
| A must-see primary action (New, Add, primary CTA) | inline item + `.visibilityPriority(.high)` |
| A secondary / occasional action (Archive, Delete, Sort, Info) | the overflow menu container |
| Something that must always be reachable in one fixed place (Share, Done) | `.topBarPinnedTrailing` |
| A top-level *destination* deserving a fixed trailing slot | prominent `tabRole` (not a toolbar item) |

## Pitfalls

1. **Reading width yourself to hide items.** Don't branch on `GeometryReader`/`horizontalSizeClass` to decide which buttons to drop — that's the anti-pattern this skill exists to prevent. **Express priority and let SwiftUI adapt** (the same "express preferences, not control" principle as the rest of Adaptive UI).
2. **Pinning or elevating everything.** If every item is `.high` or `.topBarPinnedTrailing`, nothing can overflow and you're back to a cramped, truncated bar. Reserve high priority and pinning for the genuine few.
3. **Only testing at one size.** The overflow threshold only reveals itself at narrow widths. Test across the real matrix — resizable iPhone, iPad Split View / Slide Over, Mac mirroring — with the Xcode 27 resizable simulator / Device Hub and Previews (see `migration-and-testing.md`).
4. **Losing consistency and a11y in overflow.** Keep icon+label pairing consistent and always provide accessibility labels for icon-only items. For the base toolbar APIs these adapt on top of (`ToolbarSpacer`, glass button styles, search placement), see `ios-26-platform/references/toolbar-navigation.md`.
