//
//  StatisticsView.swift
//  sudoku
//

import Charts
import SwiftUI

struct StatisticsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var filter: Difficulty?
    @State private var confirmReset = false

    var body: some View {
        let records = model.stats.records(for: filter)
        let summary = StatisticsSummary(records: records)

        ScrollView {
            VStack(spacing: 16) {
                filterBar

                if records.isEmpty {
                    ContentUnavailableView(
                        "No Games Yet",
                        systemImage: "chart.bar",
                        description: Text("Finish a puzzle and your statistics will appear here.")
                    )
                    .padding(.vertical, 40)
                } else {
                    tiles(summary)
                    // The games the average line and the time tiles come from.
                    TimesChart(records: records.filter(\.isTimedWin), average: summary.averageTime)
                    RecentGames(records: Array(records.suffix(10).reversed()))
                }
            }
            .frame(maxWidth: 640)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
            .animation(.snappy, value: filter)
        }
        .background(palette.screenBackground.ignoresSafeArea())
        .navigationTitle("Statistics")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        Label("Reset Statistics", systemImage: "trash")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
                .disabled(model.stats.records.isEmpty)
            }
        }
        .confirmationDialog("Reset all statistics?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { model.stats.reset() }
        } message: {
            Text("Game history and best times will be deleted. Achievements stay unlocked.")
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                FilterChip(title: Text("All"), color: palette.accent, isSelected: filter == nil) { filter = nil }
                ForEach(Difficulty.allCases) { difficulty in
                    FilterChip(title: Text(difficulty.title), color: difficulty.color, isSelected: filter == difficulty) {
                        filter = difficulty
                    }
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    private func tiles(_ summary: StatisticsSummary) -> some View {
        // One tile per row once large text would no longer fit two.
        let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
                StatTile(title: "Games played", value: count(summary.played), symbol: "square.grid.3x3.fill", color: .blue)
                StatTile(title: "Games won", value: count(summary.won), symbol: "checkmark.seal.fill", color: .green)
                StatTile(
                    title: "Win rate",
                    value: summary.displayedWinRate.formatted(.percent.precision(.fractionLength(0)).locale(AppLocale.current)),
                    symbol: "percent",
                    color: .teal
                )
                StatTile(title: "Perfect games", value: count(summary.perfect), symbol: "sparkles", color: .purple)
                StatTile(
                    title: "Best time",
                    value: summary.bestTime.map(TimeText.clock) ?? "–",
                    spokenValue: summary.bestTime.map(TimeText.spoken) ?? String(localized: "None yet", comment: "VoiceOver value of a best or average time before any game counts towards it."),
                    symbol: "trophy.fill",
                    color: .yellow
                )
                StatTile(
                    title: "Average time",
                    value: summary.averageTime.map(TimeText.clock) ?? "–",
                    spokenValue: summary.averageTime.map(TimeText.spoken) ?? String(localized: "None yet", comment: "VoiceOver value of a best or average time before any game counts towards it."),
                    symbol: "clock.fill",
                    color: .orange
                )
                StatTile(title: "Current streak", value: count(summary.currentStreak), symbol: "flame.fill", color: .red)
                StatTile(title: "Best streak", value: count(summary.bestStreak), symbol: "flame.circle.fill", color: .pink)
            }
            // Matches `StatisticsSummary`.
            Text("Best and average times only count puzzles solved without hints. Custom puzzles count towards neither these times nor streaks.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    /// With the region's grouping, e.g. "1,234" or "1 234".
    private func count(_ value: Int) -> String {
        value.formatted(.number.locale(AppLocale.current))
    }
}

private struct FilterChip: View {
    let title: Text
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            title
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? palette.onFill : color)
                // Not a tint of `color`: the colored text would fall below 4.5:1 on it.
                .background(isSelected ? AnyShapeStyle(color) : AnyShapeStyle(palette.controlBackground), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct StatTile: View {
    let title: LocalizedStringResource
    let value: String
    /// For VoiceOver, when `value` doesn't read well (a clock time).
    var spokenValue: String?
    let symbol: String
    let color: Color
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(color)
                .accessibilityHidden(true)
                // Its badge doesn't grow with Dynamic Type.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: value)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityLabel(Text(verbatim: spokenValue ?? value))
                    // A time or a percentage must never break in the middle.
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(titleLineLimit)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        // A tile beside one with a two-line title is as tall.
        .frame(maxHeight: .infinity)
        .background(palette.controlBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// Two columns leave a narrow iPhone's tile too little room for one line at the largest sizes before
    /// the accessibility ones ("Perfect games", "Aktuální série"), so a title of several words may take
    /// two. A single word shrinks instead: iOS would break it with a hyphen ("Úspěš-nost").
    private var titleLineLimit: Int? {
        if dynamicTypeSize.isAccessibilitySize { return nil }
        return String(localized: title).contains(" ") ? 2 : 1
    }
}

private struct TimesChart: View {
    let records: [GameRecord]
    let average: TimeInterval?
    @Environment(\.palette) private var palette

    var body: some View {
        let recent = Array(records.suffix(20).enumerated())
        VStack(alignment: .leading, spacing: 12) {
            Text("Solve times")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if !recent.isEmpty {
                Text("Your last \(recent.count) puzzles solved without hints")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if recent.isEmpty {
                Text("No puzzles solved without hints yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart {
                    ForEach(recent, id: \.element.id) { index, record in
                        BarMark(
                            x: .value("Game", index + 1),
                            y: .value("Time", record.duration)
                        )
                        .foregroundStyle((record.difficulty?.color ?? palette.accent).gradient)
                        .cornerRadius(4)
                        // Otherwise VoiceOver reads the bare number of seconds.
                        .accessibilityLabel(record.difficulty.map { Text($0.title) } ?? Text("Custom"))
                        .accessibilityValue(Text(verbatim: TimeText.spoken(record.duration)))
                    }
                    if let average {
                        RuleMark(y: .value("Average", average))
                            .foregroundStyle(Self.averageColor)
                            .lineStyle(Self.averageLine)
                            .accessibilityLabel(Text("Average time"))
                            .accessibilityValue(Text(verbatim: TimeText.spoken(average)))
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    // Whole minutes: automatic ticks fall on round numbers of seconds (1:40, 3:20…).
                    AxisMarks(values: .stride(by: Self.tickStep(for: recent.map(\.element.duration) + [average ?? 0]))) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let seconds = value.as(Double.self) {
                                Text(verbatim: TimeText.clock(seconds))
                            }
                        }
                    }
                }
                .frame(height: 180)
                legend(for: recent.map(\.element))
            }
        }
        .padding(16)
        .background(palette.controlBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    /// At most about four gridlines, a whole number of minutes apart.
    private static func tickStep(for durations: [TimeInterval]) -> Double {
        let longest = durations.max() ?? 0
        let steps: [Double] = [60, 120, 300, 600, 900, 1800, 3600, 7200]
        return steps.first { longest / $0 <= 4 } ?? 14400
    }

    /// The same in the chart and in the legend. A color, not the hierarchical `.secondary`, which a chart
    /// derives from the accent.
    private static let averageColor = Color.secondary
    private static let averageLine = StrokeStyle(lineWidth: 1, dash: [4, 3])

    /// The bars are colored by difficulty; say which is which once there is more than one. The average is
    /// named here rather than on its line, where the label would cover the bars it crosses.
    private func legend(for records: [GameRecord]) -> some View {
        let difficulties = Difficulty.allCases.filter { difficulty in records.contains { $0.difficulty == difficulty } }
        return FlowLayout(spacing: 12, lineSpacing: 6) {
            if difficulties.count > 1 {
                ForEach(difficulties) { difficulty in
                    legendItem(Text(difficulty.title)) {
                        Circle()
                            .fill(difficulty.color)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            if let average {
                legendItem(Text("Average \(TimeText.clock(average))")) {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 1))
                        path.addLine(to: CGPoint(x: 14, y: 1))
                    }
                    .stroke(Self.averageColor, style: Self.averageLine)
                    .frame(width: 14, height: 2)
                }
            }
        }
        // Every bar already says its difficulty, and the line its time.
        .accessibilityHidden(true)
    }

    private func legendItem(_ title: Text, @ViewBuilder symbol: () -> some View) -> some View {
        HStack(spacing: 5) {
            symbol()
            title
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct RecentGames: View {
    let records: [GameRecord]
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // With large text everything goes under the title rather than being squeezed beside it.
        let isStacked = dynamicTypeSize.isAccessibilitySize
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent games")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 8)
            ForEach(records) { record in
                HStack(alignment: isStacked ? .top : .center, spacing: 12) {
                    Image(systemName: icon(for: record))
                        .font(.title3)
                        .foregroundStyle(color(for: record))
                        .frame(width: 28)
                        // The outcome is in words beside the time.
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        // The badge goes under the difficulty once it doesn't fit beside it, rather than wrapping.
                        ViewThatFits(in: .horizontal) {
                            if !isStacked {
                                HStack(spacing: 6) { title(of: record) }
                            }
                            VStack(alignment: .leading, spacing: 4) { title(of: record) }
                        }
                        .font(.subheadline.weight(.semibold))
                        Text(record.date.formatted(.dateTime.day().month().hour().minute().locale(AppLocale.current)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if isStacked {
                            result(of: record, alignment: .leading)
                                .padding(.top, 4)
                        }
                    }
                    if !isStacked {
                        Spacer()
                        result(of: record, alignment: .trailing)
                    }
                }
                .padding(.vertical, 10)
                .accessibilityElement(children: .combine)
                if record.id != records.last?.id {
                    Divider().padding(.leading, 40)
                }
            }
        }
        .padding(16)
        .background(palette.controlBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private func title(of record: GameRecord) -> some View {
        if let difficulty = record.difficulty {
            Text(difficulty.title)
                .foregroundStyle(difficulty.color)
        } else {
            Text("Custom")
        }
        if record.kind.dailyKey != nil {
            badge(Text("Daily"))
        } else if record.kind == .custom, record.difficulty != nil {
            // Listed under its rating, but it only counts towards "All" (see `StatsStore.records(for:)`).
            badge(Text("Custom"))
        }
    }

    private func badge(_ title: Text) -> some View {
        title
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
    }

    private func result(of record: GameRecord, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(verbatim: TimeText.clock(record.duration))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .accessibilityLabel(Text(verbatim: TimeText.spoken(record.duration)))
            outcomeText(record)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func icon(for record: GameRecord) -> String {
        switch record.outcome {
        case .won: record.isPerfect ? "star.circle.fill" : "checkmark.circle.fill"
        case .lost: "xmark.circle.fill"
        case .abandoned: "minus.circle.fill"
        }
    }

    private func color(for record: GameRecord) -> Color {
        switch record.outcome {
        case .won: record.isPerfect ? .yellow : palette.success
        case .lost: palette.error
        case .abandoned: .secondary
        }
    }

    private func outcomeText(_ record: GameRecord) -> Text {
        switch record.outcome {
        case .won: record.isPerfect ? Text("Perfect") : Text("Solved")
        case .lost: Text("Lost")
        case .abandoned: Text("Abandoned")
        }
    }
}
