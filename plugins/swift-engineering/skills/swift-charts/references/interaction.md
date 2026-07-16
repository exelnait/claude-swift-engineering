# Interaction & Scrolling

Two common interactive needs: let the user **select** a data point (tap/drag to inspect), and **scroll** a long series while showing a window of it. Swift Charts has first-class modifiers for both (iOS 17+).

## Selection

Bind the selected value on an axis; Swift Charts maps taps/drags to the nearest data value.

```swift
struct RevenueChart: View {
    let sales: [Sale]
    @State private var selectedDay: Date?

    var body: some View {
        Chart(sales) { sale in
            BarMark(x: .value("Day", sale.day, unit: .day), y: .value("Amount", sale.amount))
                .foregroundStyle(selectedDay == sale.day ? Color.accentColor : Color.blue)

            if let selectedDay, let picked = sales.first(where: { $0.day == selectedDay }) {
                RuleMark(x: .value("Selected", selectedDay))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                        VStack(alignment: .leading) {
                            Text(picked.day, format: .dateTime.month().day())
                            Text(picked.amount, format: .currency(code: "USD")).bold()
                        }
                        .padding(6).background(.regularMaterial, in: .rect(cornerRadius: 8))
                    }
            }
        }
        .chartXSelection(value: $selectedDay)     // tap/drag selects the nearest x value
    }
}
```

- **`chartXSelection(value:)`** / `chartYSelection(value:)` bind a single selected value; `chartXSelection(range:)` binds a range (drag to select a span).
- **`chartAngleSelection(value:)`** for `SectorMark` pie/donut selection.
- The binding alone renders nothing — you draw the feedback yourself (highlight the mark, add a `RuleMark` + `.annotation` callout). This is Common Mistake #5.
- `overflowResolution` on the annotation keeps the callout inside the plot near the edges.

## Reading pixel positions with the chart proxy

When you need to place custom overlays at data positions, use `chartOverlay`/`chartBackground` with a `ChartProxy`:

```swift
Chart(sales) { … }
    .chartOverlay { proxy in
        GeometryReader { geo in
            Rectangle().fill(.clear).contentShape(Rectangle())
                .onTapGesture { location in
                    if let day: Date = proxy.value(atX: location.x - geo[proxy.plotAreaFrame].origin.x) {
                        selectedDay = nearestDay(to: day)
                    }
                }
        }
    }
```

`proxy.value(atX:)`/`position(forX:)` convert between data and pixels — use for bespoke gestures/annotations beyond the built-in selection.

## Scrolling a long series

Show a window of a large dataset and let the user scroll, instead of cramming everything (Common Mistake #6):

```swift
Chart(sales) { sale in
    BarMark(x: .value("Day", sale.day, unit: .day), y: .value("Amount", sale.amount))
}
.chartScrollableAxes(.horizontal)
.chartXVisibleDomain(length: 3600 * 24 * 30)     // show ~30 days at a time (seconds for a Date axis)
.chartScrollPosition(x: $scrollX)                // bind/observe the scroll position
.chartScrollTargetBehavior(.valueAligned(matching: DateComponents(hour: 0)))   // snap to day boundaries
```

- **`chartScrollableAxes`** enables scrolling on an axis.
- **`chartXVisibleDomain(length:)`** sets how much data is visible at once (in the axis's units — seconds for `Date`, value units for numbers).
- **`chartScrollPosition(x:)`** reads/sets where the viewport is (jump to "today", persist position).
- **`chartScrollTargetBehavior`** snaps scrolling to meaningful boundaries.

For big data, also **aggregate/downsample** to the visible resolution so you're not plotting thousands of marks off-screen.

## Gestures

`chartGesture` attaches a gesture with access to the proxy for advanced cases (custom crosshair, magnify-to-zoom). For standard tap/drag selection, prefer `chartXSelection` — it's simpler and accessible.

## Pitfalls

- **Selection binding with no visual feedback** → nothing appears; render a highlight/annotation.
- **Annotation clipped at edges** → set `overflowResolution`.
- **Scrolling without `chartXVisibleDomain`** → the whole domain renders; window it.
- **Plotting all points then scrolling** → still janky; downsample to the visible domain.
