# Marks & Data

A chart is a collection of **marks** over your data. Each mark type is a visual vocabulary; you plot data fields onto its channels with `.value("Label", value)`.

## The basic chart

```swift
import Charts

struct Sale: Identifiable { let id = UUID(); let day: Date; let amount: Double; let channel: String }

Chart(sales) { sale in
    BarMark(
        x: .value("Day", sale.day, unit: .day),
        y: .value("Amount", sale.amount)
    )
}
```

`Chart(data) { element in … }` iterates your collection; each iteration produces one or more marks. You can also wrap explicit `ForEach` inside `Chart { … }` when combining sources.

## Mark types

| Mark | For | Key channels |
|------|-----|--------------|
| `BarMark` | categorical magnitude, histograms, stacks | `x`, `y` (bars auto-stack when a series field is set) |
| `LineMark` | trends over a continuous axis | `x`, `y`, `series`/`foregroundStyle(by:)` |
| `PointMark` | scatter / correlation | `x`, `y`, `symbol(by:)` |
| `AreaMark` | filled trend, ranges, stacked areas | `x`, `y` or `yStart:yEnd:` |
| `RuleMark` | thresholds, reference lines, error bars | `x` or `y`, or `xStart:xEnd:` |
| `RectangleMark` | heatmap cells, bands | `x`, `y` (+ `foregroundStyle(by:)` for value) |
| `SectorMark` | pie / donut (iOS 17+) | `angle`, `innerRadius`, `angularInset` |

## Encoding series (color/split by a category)

Drive color and grouping from a **data field**, not by hand (Common Mistake #2) — this builds the legend and color scale automatically:

```swift
Chart(sales) { sale in
    LineMark(x: .value("Day", sale.day), y: .value("Amount", sale.amount))
        .foregroundStyle(by: .value("Channel", sale.channel))   // one line per channel + legend
        .symbol(by: .value("Channel", sale.channel))            // distinct symbols (color-independent)
}
```

- `foregroundStyle(by:)` → color encodes the category.
- `position(by:)` → side-by-side grouping (e.g. grouped bars); omit it and `BarMark` **stacks** by the series field.
- `symbol(by:)` / `lineStyle(by:)` → shape/dash encodes category too (helps accessibility and color-blind users).

Grouped vs stacked bars:

```swift
// Stacked (default when foregroundStyle(by:) is set):
BarMark(x: .value("Month", m.month), y: .value("Revenue", m.revenue))
    .foregroundStyle(by: .value("Product", m.product))

// Grouped (side by side):
BarMark(x: .value("Month", m.month), y: .value("Revenue", m.revenue))
    .foregroundStyle(by: .value("Product", m.product))
    .position(by: .value("Product", m.product))
```

## Lines: interpolation & styling

```swift
LineMark(x: .value("t", p.t), y: .value("v", p.v))
    .interpolationMethod(.catmullRom)     // .linear, .monotone, .stepStart/.stepEnd, .cardinal
    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 2]))
    .symbol(.circle)
```

Use `.monotone`/`.catmullRom` for smooth trends, `.stepEnd` for discrete/holding values (don't smooth data that isn't continuous — Common Mistake #1).

## Ranges, areas, rules

```swift
// Range band (e.g. min–max):
AreaMark(x: .value("Day", d.day), yStart: .value("Low", d.low), yEnd: .value("High", d.high))
    .opacity(0.2)

// Threshold line + label:
RuleMark(y: .value("Goal", goal))
    .foregroundStyle(.secondary)
    .lineStyle(StrokeStyle(dash: [4]))
    .annotation(position: .top, alignment: .leading) { Text("Goal") }
```

## Pie / donut (SectorMark)

```swift
Chart(breakdown) { slice in
    SectorMark(
        angle: .value("Share", slice.value),
        innerRadius: .ratio(0.6),          // 0 = pie, >0 = donut
        angularInset: 1.5
    )
    .foregroundStyle(by: .value("Category", slice.name))
    .cornerRadius(4)
}
```

## Combining marks

Layer multiple mark types in one `Chart` — e.g. a line with points and an average rule:

```swift
Chart {
    ForEach(series) { p in
        LineMark(x: .value("t", p.t), y: .value("v", p.v))
        PointMark(x: .value("t", p.t), y: .value("v", p.v))
    }
    RuleMark(y: .value("Average", average)).foregroundStyle(.gray)
}
```

## Per-mark annotations

Attach labels/badges to marks with `.annotation(position:alignment:spacing:)`:

```swift
BarMark(x: .value("Day", d.day), y: .value("Amount", d.amount))
    .annotation(position: .top) { Text(d.amount, format: .number).font(.caption2) }
```

## Pitfalls

- **Line over categorical x** → implies a false trend; use bars.
- **Manual per-mark colors** → no legend, no data link; encode with `foregroundStyle(by:)`.
- **Smoothing discrete data** → misleading curves; use `.stepEnd`/`.linear`.
- **Color-only series** → inaccessible; add `symbol(by:)`/`lineStyle(by:)`.
