# Migration & Testing

How to find the unreliable layout inputs already in a codebase, convert them to available-space logic, and verify the result across the real device/mode matrix — including iPhone fold and iPad multitasking.

## Audit: find the risky inputs

Grep the project for the four "identity, not space" inputs and the fixed-canvas flag. Every hit is a candidate bug on resizable iPhone, foldables, and iPad multitasking.

```bash
# Physical screen used for layout
rg -n 'UIScreen\.main|\.main\.bounds|\.screen\.bounds'

# Device identity driving layout
rg -n 'userInterfaceIdiom|UIDevice\.current'

# Orientation used as a layout fact
rg -n 'UIDevice.*orientation|interfaceOrientation|isLandscape|isPortrait'

# Size class used as a width sensor (inspect each: semantics = OK, breakpoint = fix)
rg -n 'horizontalSizeClass|verticalSizeClass|UserInterfaceSizeClass'

# Fixed-canvas flag
rg -n 'UIRequiresFullScreen'
```

Triage each hit:

- `UIScreen.main*`, `UIDevice*`, idiom/orientation branching for layout → **replace** with geometry.
- `horizontalSizeClass` → **keep** if it gates *system container semantics* (menu collapse, offering a system sidebar); **replace** if it's your own width breakpoint.
- `UIRequiresFullScreen` → **remove** from Info.plist.

## Convert: input → replacement

| You currently have | Replace with |
|--------------------|--------------|
| `UIScreen.main.bounds.width` | `.onGeometryChange(for: CGFloat.self) { $0.size.width } action:` — or `containerRelativeFrame` |
| `if idiom == .pad { … }` | `if isWide { … }`, `isWide` from measured geometry |
| `UIDevice.current.orientation.isLandscape` | `.onGeometryChange(for: Bool.self) { $0.size.width > $0.size.height }` |
| `if horizontalSizeClass == .regular` *(your breakpoint)* | `.onGeometryChange(for: Bool.self) { $0.size.width >= 700 }` |
| Fixed `.frame(width:height:)` app shell | `.frame(minWidth:minHeight:)` + `windowResizability(.contentMinSize)` |
| `UIRequiresFullScreen = true` | Delete it; express a minimum scene size instead |

See `geometry-driven-layout.md` for the replacement toolkit and `scene-geometry.md` for window-level preferences.

## Info.plist cleanup

- **Remove `UIRequiresFullScreen`.** It's a deprecated compatibility mode and will be ignored by the system (Apple TN3192). Keeping it signals a legacy posture and blocks nothing useful.
- **Review `UISupportedInterfaceOrientations`.** In a resizable environment these are *preferences*; don't rely on them to constrain your layout. Support what genuinely makes sense and let geometry drive the actual layout.
- **Enable multiple-scene support** (`UIApplicationSupportsMultipleScenes = true`) so the app participates correctly in multiwindow/Stage Manager rather than being forced into a single fixed instance.

## The test matrix

Available-space bugs only appear when the space actually varies — a single simulator size hides them. Exercise the full matrix:

| Surface | States to test |
|---------|----------------|
| **iPhone fold** | Folded (narrow outer/cover), unfolded (wide inner display), **and the live fold/unfold transition** — verify selection, scroll position, and in-progress input all survive |
| **Resizable iPhone (Mac mirroring)** | Drag the window from narrow to wide and back; confirm the shell morphs on **geometry**, not size class (which stays `.compact`) |
| **iPhone-only app on iPad** | Runs resizable under phone idiom — same expectations as Mac mirroring |
| **iPad multitasking** | Full screen, 50% Split View, 33% Split View, Slide Over, Stage Manager (including interactive drag-resize) |
| **iPad orientation** | Portrait and landscape at each of the above widths |
| **macOS** | Freely resized window; sidebar navigation path |
| **Dynamic Type** | Largest accessibility sizes at the narrowest width — the tightest layout case |

For each: does the layout reflow correctly, does no content clip, and is the user's context preserved across the change?

## How to reproduce these environments

- **Xcode 27 previews** — the fastest loop. Pin explicit sizes and let one preview be resizable to watch the morph live.
- **Device Hub (iOS 27 simulation)** — exercise the **resizable iPhone** behavior (drag the window wider) without a physical beta device; this is where a wide iPhone window staying `.compact` is observable.
- **iPad simulators** — enable Split View / Slide Over / Stage Manager and drag the divider through your breakpoints, including mid-drag (interactive) states.

## Previews that catch the bugs

Write previews at several widths so a broken breakpoint is visible before you ever run on device:

```swift
#Preview("Compact — folded / narrow", traits: .fixedLayout(width: 390, height: 844)) {
    RootView()
}

#Preview("Wide — unfolded / wide window", traits: .fixedLayout(width: 900, height: 700)) {
    RootView()
}

#Preview("Resizable — drag to watch the morph") {
    RootView()      // resize the canvas across ~700pt to confirm Tab ↔ Sidebar switches
}
```

At minimum, preview the **narrowest** and a **wide** width for any adaptive view, plus a **resizable** variant for app-shell views that morph navigation. Add a **largest–Dynamic-Type at narrowest width** variant for text-dense screens.

## Ship checklist

- [ ] No `UIScreen.main` / `UIDevice` / `userInterfaceIdiom` / `UIDevice.orientation` drives any layout decision.
- [ ] Every `horizontalSizeClass` use is *semantic*, not a width breakpoint.
- [ ] App-shell navigation morphs on **measured geometry** and is verified on resizable iPhone.
- [ ] Selection / navigation / in-progress input **survive** a fold-unfold and a resize (state lives in a shared `@Observable`, not in swapped shells).
- [ ] `UIRequiresFullScreen` removed; a **minimum** size + `windowResizability` expressed instead.
- [ ] Expensive relayout deferred until resize **settles** (interactive-vs-settled handled) so dragging stays smooth.
- [ ] Tested across the full matrix above, including the largest Dynamic Type at the narrowest width.
- [ ] Brand-new WWDC 26 scene APIs verified against current Apple docs / Sosumi (signatures are new).
