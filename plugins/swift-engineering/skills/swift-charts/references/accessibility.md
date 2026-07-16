# Chart Accessibility

By default a Swift Chart is a single opaque image to VoiceOver — the data is invisible to anyone not looking at it (Common Mistake #7). Making a chart accessible has two parts: per-mark semantics for VoiceOver navigation, and an **Audio Graph** for sonifying the trend. Neither is optional for a shipping chart.

## Per-mark labels & values

Give each mark a spoken label (what it is) and value (its reading) so VoiceOver can step through the data points:

```swift
Chart(sales) { sale in
    BarMark(x: .value("Day", sale.day, unit: .day), y: .value("Amount", sale.amount))
        .accessibilityLabel(sale.day.formatted(.dateTime.weekday(.wide).month().day()))
        .accessibilityValue(sale.amount.formatted(.currency(code: "USD")))
        .accessibilityHidden(false)
}
```

- `accessibilityLabel` = the point's identity (the date/category); `accessibilityValue` = its measurement.
- VoiceOver then navigates mark-to-mark, reading "Monday March 3rd, $1,240," etc.
- Group or summarize when there are very many marks (e.g. one accessible element per week) so navigation isn't endless.

## Audio Graphs (sonification)

Audio Graphs let VoiceOver users *hear* the shape of the data (pitch = value) via the rotor's "Describe Chart" / audio graph action. Provide an `AXChartDescriptor`:

```swift
import Accessibility

extension RevenueChart: AXChartDescriptorRepresentable {
    func makeChartDescriptor() -> AXChartDescriptor {
        let amounts = sales.map(\.amount)
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Day",
            categoryOrder: sales.map { $0.day.formatted(.dateTime.month().day()) }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Amount", range: 0...(amounts.max() ?? 0),
            gridlinePositions: []
        ) { "\(Int($0)) dollars" }

        let series = AXDataSeriesDescriptor(
            name: "Revenue",
            isContinuous: false,
            dataPoints: sales.map {
                .init(x: $0.day.formatted(.dateTime.month().day()), y: $0.amount)
            }
        )
        return AXChartDescriptor(title: "Daily revenue", summary: nil,
                                 xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: [series])
    }
}
```

Attach it to the chart view:

```swift
Chart(sales) { … }
    .accessibilityChartDescriptor(self)     // self conforms to AXChartDescriptorRepresentable
```

Now VoiceOver offers an audio graph that plays the series as tones — the fastest way for a non-visual user to grasp the trend.

## Don't encode meaning by color alone

Color-blind users and Audio Graph users can't rely on hue. When you split a series by category, **also** vary shape/position so the distinction survives without color (ties back to `marks.md`):

```swift
LineMark(…)
    .foregroundStyle(by: .value("Channel", sale.channel))
    .symbol(by: .value("Channel", sale.channel))     // shape encodes category too
```

## Dynamic Type & contrast

- Axis and annotation text respects Dynamic Type — don't hardcode tiny fonts; test at large sizes and let labels reflow (thin ticks with `.stride` if they collide).
- Ensure marks and gridlines meet contrast against the plot background in both light and dark; use system/semantic colors or a validated palette (host `dataviz` skill).
- Give the whole chart a concise `.accessibilityLabel` summarizing what it shows ("Daily revenue, last 30 days") so VoiceOver announces its purpose before the user dives into marks.

## Checklist

- [ ] Per-mark `.accessibilityLabel` (identity) + `.accessibilityValue` (reading), grouped if very dense.
- [ ] An `AXChartDescriptor` wired via `.accessibilityChartDescriptor` for Audio Graphs.
- [ ] Category encoded by shape/position, not color alone.
- [ ] Text respects Dynamic Type; marks/gridlines pass contrast in light & dark.
- [ ] A one-line chart-level accessibility summary.

See the `accessibility` and `ios-hig` skills for the broader VoiceOver/Dynamic Type contract these charts live inside.
