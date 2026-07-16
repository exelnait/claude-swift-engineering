---
name: swift-charts
description: >-
  Use when building data visualizations with Apple's Swift Charts — `Chart` with `BarMark`/`LineMark`/`PointMark`/`AreaMark`/`RuleMark`/`RectangleMark`/`SectorMark`, encoding data with `.value`/`x:`/`y:`, series and grouping via `foregroundStyle(by:)`/`position(by:)`, axes and scales (`chartXAxis`/`chartYAxis`, `AxisMarks`, `chartYScale(domain:)`), legends and color scales, interaction (`chartXSelection`, `chartGesture`), scrolling (`chartScrollableAxes`, `chartScrollPosition`, `chartXVisibleDomain`), and chart accessibility (audio graphs, per-mark labels). Load whenever a feature renders a bar/line/area/scatter/pie chart, a sparkline, or any plotted data. For non-chart color-system/dashboard design use the host's dataviz skill; this is the Swift Charts framework skill.
---

# Swift Charts (iOS 26+)

Swift Charts is declarative like SwiftUI: you describe **marks** (bars, lines, points) and how your data's fields **map to visual channels** (x, y, color, position), and the framework handles scales, axes, and layout. Build charts by composing marks over your data, not by drawing.

The core principle: **one mark per data point, data fields plotted onto visual channels with `.value(...)`.** Series come from a category field via `foregroundStyle(by:)`/`position(by:)`; styling, axes, and interaction are modifiers on the `Chart`.

## Quick Reference

| Need | Use |
|------|-----|
| Bar / column chart | `BarMark(x: .value(...), y: .value(...))` |
| Line / time series | `LineMark(...)` (+ `.interpolationMethod`) |
| Scatter | `PointMark(...)` |
| Filled area / range | `AreaMark(...)` (or `y:`/`yStart:yEnd:`) |
| Threshold / reference line | `RuleMark(y: .value(...))` |
| Heatmap cell / band | `RectangleMark(...)` |
| Pie / donut | `SectorMark(angle:, innerRadius:)` |
| Color/split by category | `.foregroundStyle(by: .value("Type", item.type))` |
| Group/stack by category | `.position(by:)` / stacking is automatic for BarMark |
| Custom axis | `.chartXAxis { AxisMarks(...) }` |
| Fix the value range | `.chartYScale(domain: 0...100)` |
| Tap/drag selection | `.chartXSelection(value:)` |
| Scroll a long series | `.chartScrollableAxes(.horizontal)` + `.chartXVisibleDomain(length:)` |
| Accessible to VoiceOver | per-mark `.accessibilityLabel/Value` + audio graph |

## Core Workflow

1. **Shape the data** as an array of `Identifiable`/plottable values (one element per data point). Each mark iterates them, usually via `ForEach` or by passing the collection.
2. **Choose the mark** for the encoding (bar for categories/magnitude, line for trends over a continuous axis, point for correlation, sector for parts-of-whole).
3. **Map fields to channels** with `.value("Label", keypath)` for `x:` and `y:` (and `angle:` for sectors).
4. **Add series** by driving `foregroundStyle(by:)`/`position(by:)` from a category field — Swift Charts builds the legend and color scale.
5. **Tune axes and scale** — `chartXAxis`/`chartYAxis` with `AxisMarks`, `chartYScale(domain:)` to control range, `chartForegroundStyleScale` to control colors.
6. **Add interaction** where it helps — selection, scrolling, and annotations.
7. **Make it accessible** — per-mark labels/values and an audio graph; a chart no one can read with VoiceOver is unfinished.

## Reference Loading Guide

**ALWAYS load reference files if there is even a small chance the content may be required.**

| Reference | Load When |
|-----------|-----------|
| **[Marks & Data](references/marks.md)** | Building the plot — every mark type, `.value` encoding, series via `foregroundStyle(by:)`/`position(by:)`, stacking, `symbol(by:)`, `interpolationMethod`, `SectorMark` pie/donut, combining marks, `annotation` |
| **[Axes, Scales & Legend](references/axes-scales-legend.md)** | Controlling axes/range/colors — `chartXAxis`/`chartYAxis` + `AxisMarks`/`AxisValueLabel`/`AxisGridLine`, `chartXScale`/`chartYScale(domain:range:)`, date/number formatting, `chartForegroundStyleScale`, `chartLegend`, `chartPlotStyle` |
| **[Interaction & Scrolling](references/interaction.md)** | Selection and scrolling — `chartXSelection`/`chartYSelection`/`chartAngleSelection`, `RuleMark`+`annotation` for a selection callout, `chartScrollableAxes` + `chartScrollPosition` + `chartXVisibleDomain`, `chartGesture`, `chartProxy`/`GeometryReader` |
| **[Accessibility](references/accessibility.md)** | Making charts perceivable — per-mark `accessibilityLabel`/`accessibilityValue`, `chartDescriptor`/Audio Graphs, VoiceOver navigation, Dynamic Type & color-independent encoding |

## Common Mistakes

1. **Wrong mark for the data.** Bars for categorical magnitude and parts-of-whole; lines for trends over a **continuous** (time/number) axis; points for correlation. A line chart over a categorical x-axis implies a trend that isn't there. Pick the mark that tells the truth about the data.

2. **Hardcoding colors instead of encoding a series.** Manually coloring each mark loses the legend and the data→color link. Drive color from a field with `.foregroundStyle(by: .value("Category", item.category))` and let Swift Charts build the scale and legend; override specific colors with `chartForegroundStyleScale`.

3. **Letting the y-axis auto-range mislead.** Auto-scaling can start the axis at a non-zero value and exaggerate differences. Set `.chartYScale(domain:)` deliberately — usually starting at 0 for bars — so the chart doesn't lie.

4. **Unformatted date/number axes.** Raw `Date`/`Double` labels are unreadable. Format axis labels via `AxisValueLabel(format:)` (e.g. `.dateTime.month()`, `.number.precision(...)`) so the axis communicates.

5. **Selection without a proxy-aware callout.** `chartXSelection` gives you the selected value; pair it with a `RuleMark` + `.annotation` (and `chartProxy` if you need pixel positions) to actually show what's selected — the binding alone renders nothing.

6. **Rendering thousands of marks live.** Charts with huge point counts jank. Downsample/aggregate for the visible domain, use `chartScrollableAxes` + `chartXVisibleDomain` to window the data, and prefer simpler marks at density.

7. **Skipping accessibility.** By default a chart is one opaque image to VoiceOver. Add per-mark `.accessibilityLabel`/`.accessibilityValue` and an audio graph, and never encode meaning by color alone (add symbol/position). See the accessibility reference.

8. **Confusing Swift Charts with chart *design*.** This skill is the framework. For the color-system, palette, and dashboard-layout decisions (light/dark, categorical vs sequential scales, stat tiles), that's the host's `dataviz` design guidance — use both together.
