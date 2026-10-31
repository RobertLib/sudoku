//
//  DailyChallengeView.swift
//  sudoku
//

import SwiftUI

struct DailyChallengeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The day and month the player picked. Until then both follow `AppModel.today`, also when the screen
    /// is left open past midnight: it mustn't go on offering yesterday's puzzle as if it were today's.
    @State private var pickedDay: DailyChallenge?
    @State private var pickedMonth: MonthPage?

    private var selected: DailyChallenge { pickedDay ?? model.today }
    private var month: MonthPage { pickedMonth ?? MonthPage(containing: model.today) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SelectedDayCard(challenge: selected, isToday: selected == model.today)
                streaks
                calendar
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .background(palette.screenBackground.ignoresSafeArea())
        .navigationTitle("Daily Challenge")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var streaks: some View {
        // Three side by side, or one under the other once large text would cut the titles off.
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            StreakTile(value: model.daily.currentStreak(today: model.today), title: "Current streak", symbol: "flame.fill", color: .orange)
            StreakTile(value: model.daily.bestStreak, title: "Best streak", symbol: "trophy.fill", color: .yellow)
            StreakTile(value: model.daily.completedCount, title: "Completed", symbol: "checkmark.circle.fill", color: palette.success)
        }
    }

    private var calendar: some View {
        let calendar = MonthPage.displayCalendar
        // Short rather than very short names: in Czech those repeat (P Ú S Č P S N).
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        let orderedSymbols = Array(symbols[first...] + symbols[..<first])
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return VStack(spacing: 14) {
            HStack {
                Button {
                    withAnimation(.snappy) { show(month.previous) }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 36, height: 36)
                }
                .disabled(!month.hasPrevious(today: model.today))
                .accessibilityLabel(Text("Previous month"))

                Spacer()
                Text(month.title)
                    .font(.headline)
                    .contentTransition(.numericText())
                Spacer()

                Button {
                    withAnimation(.snappy) { show(month.next) }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .frame(width: 36, height: 36)
                }
                .disabled(!month.hasNext(today: model.today))
                .accessibilityLabel(Text("Next month"))
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(orderedSymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                        // Every day says its weekday to VoiceOver; the column heads would only be in the way.
                        .accessibilityHidden(true)
                }
                ForEach(0..<month.leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 40)
                }
                ForEach(month.days) { day in
                    DayCell(
                        challenge: day,
                        isToday: day == model.today,
                        isFuture: day.key > model.today.key,
                        isSelected: day == selected,
                        isCompleted: model.daily.result(for: day) != nil,
                        isInProgress: model.savedGame(for: day) != nil
                    ) {
                        withAnimation(.snappy) { pickedDay = day == model.today ? nil : day }
                    }
                }
            }
        }
        .padding(16)
        .background(palette.controlBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    /// Today's month is shown as not picked, so it moves on with the date.
    private func show(_ page: MonthPage) {
        pickedMonth = page == MonthPage(containing: model.today) ? nil : page
    }
}

private struct SelectedDayCard: View {
    let challenge: DailyChallenge
    let isToday: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let result = model.daily.result(for: challenge)
        let inProgress = model.savedGame(for: challenge)

        VStack(spacing: 16) {
            HStack(spacing: 16) {
                CalendarTile(date: challenge.date, isDone: result != nil)
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.date.formatted(.dateTime.weekday(.wide).day().month(.wide).dailyCalendar()))
                        .font(.headline)
                    Text(challenge.difficulty.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(challenge.difficulty.color)
                    if isToday {
                        Text("Today's puzzle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }

            if let result {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        // Rows instead of three columns too narrow for large text.
                        VStack(spacing: 8) {
                            resultRow(title: "Time", value: TimeText.clock(result.duration), spokenValue: TimeText.spoken(result.duration))
                            resultRow(title: "Mistakes", value: "\(result.mistakes)")
                            resultRow(title: "Hints", value: "\(result.hints)")
                        }
                        .padding(.horizontal, 14)
                    } else {
                        HStack(spacing: 0) {
                            resultValue(title: "Time", value: TimeText.clock(result.duration), spokenValue: TimeText.spoken(result.duration))
                            Divider().frame(height: 30)
                            resultValue(title: "Mistakes", value: "\(result.mistakes)")
                            Divider().frame(height: 30)
                            resultValue(title: "Hints", value: "\(result.hints)")
                        }
                    }
                }
                .padding(.vertical, 10)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Label("Completed", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.success)
            } else {
                Button {
                    model.request(.daily(challenge))
                } label: {
                    Label(inProgress == nil ? "Play" : "Continue", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(palette.buttonFill)
                .controlSize(.large)
                if let inProgress {
                    ProgressView(value: inProgress.progress)
                        .tint(palette.accent)
                }
            }
        }
        .padding(18)
        .background(palette.controlBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func resultValue(title: LocalizedStringKey, value: String, spokenValue: String? = nil) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.headline)
                .monospacedDigit()
                .accessibilityLabel(Text(verbatim: spokenValue ?? value))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func resultRow(title: LocalizedStringKey, value: String, spokenValue: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.headline)
                .monospacedDigit()
                .accessibilityLabel(Text(verbatim: spokenValue ?? value))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct StreakTile: View {
    let value: Int
    let title: LocalizedStringKey
    let symbol: String
    let color: Color
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // A full-width row (see `DailyChallengeView.streaks`).
                HStack(spacing: 12) {
                    icon
                    VStack(alignment: .leading, spacing: 2) {
                        number
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
            } else {
                VStack(spacing: 6) {
                    icon
                    number
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(palette.controlBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var icon: some View {
        Image(systemName: symbol)
            .font(.title3)
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }

    private var number: some View {
        Text(verbatim: "\(value)")
            .font(.title2.weight(.bold))
            .monospacedDigit()
    }
}

private struct DayCell: View {
    let challenge: DailyChallenge
    let isToday: Bool
    let isFuture: Bool
    let isSelected: Bool
    let isCompleted: Bool
    let isInProgress: Bool
    let action: () -> Void
    @Environment(\.palette) private var palette
    /// Grows with Dynamic Type as far as the seven columns allow (see the frames below).
    @ScaledMetric(relativeTo: .body) private var diameter: CGFloat = 38
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 16

    var body: some View {
        Button(action: action) {
            ZStack {
                if isCompleted {
                    Circle().fill(palette.accent)
                } else if isInProgress {
                    Circle().strokeBorder(palette.accent, lineWidth: 2)
                }
                if isSelected {
                    Circle()
                        .strokeBorder(palette.accent.opacity(isCompleted ? 0.45 : 1), lineWidth: 3)
                        .padding(-3)
                }
                Text(verbatim: "\(challenge.day)")
                    .font(.system(size: fontSize, weight: isToday ? .bold : .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(3)
                    .foregroundStyle(isCompleted ? palette.onFill : (isToday ? palette.error : .primary))
            }
            // A circle as wide as the column allows, up to the scaled size.
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: diameter)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .opacity(isFuture ? 0.3 : 1)
        .accessibilityLabel(Text(challenge.date.formatted(.dateTime.weekday(.wide).day().month(.wide).dailyCalendar())))
        .accessibilityValue(Text(verbatim: accessibilityStates.joined(separator: ", ")))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Sighted players see today in red and a filled or ringed circle for the state.
    private var accessibilityStates: [String] {
        var states: [String] = []
        if isToday { states.append(String(localized: "Today")) }
        if isCompleted {
            states.append(String(localized: "Completed"))
        } else if isInProgress {
            states.append(String(localized: "In progress"))
        }
        return states
    }
}

/// One month of the daily challenge calendar.
struct MonthPage: Equatable {
    var year: Int
    var month: Int

    /// Calendar with the UI language's week layout and weekday names.
    static var displayCalendar: Calendar {
        var calendar = DailyChallenge.calendar
        calendar.locale = AppLocale.current
        calendar.firstWeekday = Calendar.current.firstWeekday
        return calendar
    }

    init(containing challenge: DailyChallenge) {
        year = challenge.year
        month = challenge.month
    }

    private init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    private var firstDay: DailyChallenge {
        DailyChallenge(key: String(format: "%04d-%02d-01", year, month))!
    }

    var title: String {
        firstDay.date.formatted(.dateTime.month(.wide).year().dailyCalendar()).capitalized(with: AppLocale.current)
    }

    var days: [DailyChallenge] {
        let calendar = DailyChallenge.calendar
        let count = calendar.range(of: .day, in: .month, for: firstDay.date)?.count ?? 30
        return (0..<count).map { firstDay.adding(days: $0) }
    }

    var leadingBlanks: Int {
        let weekday = DailyChallenge.calendar.component(.weekday, from: firstDay.date)
        return (weekday - Self.displayCalendar.firstWeekday + 7) % 7
    }

    var previous: MonthPage {
        month == 1 ? MonthPage(year: year - 1, month: 12) : MonthPage(year: year, month: month - 1)
    }

    var next: MonthPage {
        month == 12 ? MonthPage(year: year + 1, month: 1) : MonthPage(year: year, month: month + 1)
    }

    func hasNext(today: DailyChallenge) -> Bool {
        (year, month) < (today.year, today.month)
    }

    /// The archive reaches back to `DailyChallenge.archiveStart`.
    func hasPrevious(today: DailyChallenge) -> Bool {
        firstDay.key > DailyChallenge.archiveStart(today: today).key
    }
}
