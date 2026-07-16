# Axes, Scales & Legend

Swift Charts infers axes, ranges, and colors from your data — good defaults, but the defaults can mislead (Common Mistakes #3, #4). These modifiers put you in control.

## Scales — control the value range

The scale maps data values to the plot area. Set the domain explicitly so the chart doesn't exaggerate or clip:

```swift
Chart(sales) { … }
    .chartYScale(domain: 0...maxAmount)          // bars should usually start at 0
    .chartXScale(domain: startDate...endDate)
    .chartYScale(domain: .automatic(includesZero: true))   // let it auto-range but include 0
```

- Fixing `chartYScale(domain:)` prevents auto-ranging from starting above zero and overstating differences (Common Mistake #3).
- `type:` sets scale kind where relevant (e.g. `.chartXScale(type: .log)` for log axes).
- `range:` controls the *plot* extent (rarely needed; domain is the common lever).

## Axes — marks, grid lines, labels

Customize an axis with `chartXAxis`/`chartYAxis` and `AxisMarks`:

```swift
Chart(sales) { … }
    .chartXAxis {
        AxisMarks(values: .stride(by: .month)) { value in
            AxisGridLine()
            AxisTick()
            AxisValueLabel(format: .dateTime.month(.abbreviated))   // "Jan", "Feb"
        }
    }
    .chartYAxis {
        AxisMarks(position: .leading) { value in
            AxisGridLine()
            AxisValueLabel {
                if let amount = value.as(Double.self) {
                    Text(amount, format: .number.notation(.compactName))   // "1.2K"
                }
            }
        }
    }
```

- **Format labels** (Common Mistake #4): `AxisValueLabel(format:)` with `.dateTime.…` for dates, `.number.…`/`.currency(code:)`/`.percent` for numbers. Raw `Date`/`Double` labels are unreadable.
- **Choose tick values**: `.automatic`, `.stride(by:)`, `.stride(by: .month)`, or an explicit array.
- **Hide/thin axes**: `.chartXAxis(.hidden)`, or emit fewer `AxisMarks` for a cleaner look (e.g. sparklines hide both axes).
- **Custom content** per mark via the `AxisValueLabel { … }` closure when you need conditional formatting or styling.

## Color scale (foreground style scale)

When you encode a category with `foregroundStyle(by:)`, Swift Charts assigns colors. Override them for brand/meaning consistency:

```swift
Chart(sales) { … }
    .chartForegroundStyleScale([
        "Online": Color.blue,
        "Retail": Color.green,
        "Wholesale": Color.orange,
    ])
```

- Map each category value to a specific `Color`/`ShapeStyle`.
- For sequential/continuous color (e.g. a heatmap `RectangleMark` colored by value), pass a gradient range: `.chartForegroundStyleScale(range: Gradient(colors: [...]))`.
- For *palette* choices (which colors, light/dark contrast, categorical vs sequential), defer to the host `dataviz` design skill — Swift Charts applies the colors; the palette design is a separate concern.

## Legend

```swift
.chartLegend(position: .bottom, alignment: .leading, spacing: 8)
.chartLegend(.hidden)          // hide when the encoding is obvious or space is tight
```

The legend is generated from the series encodings (`foregroundStyle(by:)`/`symbol(by:)`). If you hide it, make sure the chart is still self-explanatory (labels, annotations).

## Plot area styling

```swift
.chartPlotStyle { plotArea in
    plotArea
        .background(.quaternary.opacity(0.3))
        .border(.quaternary)
}
.frame(height: 220)                     // charts need an explicit height in most layouts
```

## Marks-on-axes and thresholds

Combine a `RuleMark` (data-space reference line) with formatted axes for goals/limits:

```swift
Chart {
    ForEach(sales) { s in BarMark(x: .value("Day", s.day), y: .value("Amount", s.amount)) }
    RuleMark(y: .value("Target", target))
        .lineStyle(StrokeStyle(dash: [5]))
        .annotation(position: .top, alignment: .trailing) { Text("Target").font(.caption2) }
}
.chartYScale(domain: 0...(max(target, sales.map(\.amount).max() ?? 0) * 1.1))
```

## Pitfalls

- **Auto y-range** → exaggerated differences; set `chartYScale(domain:)`.
- **Unformatted axis labels** → unreadable; use `AxisValueLabel(format:)`.
- **No explicit height** → charts collapse or overexpand; give the `Chart` a `.frame(height:)` (or let a container size it).
- **Too many ticks/gridlines** → clutter; thin them with `.stride`/fewer `AxisMarks`.
