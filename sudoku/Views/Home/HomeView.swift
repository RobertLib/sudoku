//
//  HomeView.swift
//  sudoku
//

import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showDifficultyPicker = false
    @State private var chosenRequest: GameRequest?

    var body: some View {
        GeometryReader { proxy in
        ScrollView {
            VStack(spacing: 18) {
                header
                    .padding(.top, 4)
                    .padding(.bottom, 6)

                if let saved = model.savedStandardGame {
                    ContinueCard(state: saved) {
                        model.continueSavedGame()
                    }
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.95).combined(with: .opacity))
                }

                Button {
                    showDifficultyPicker = true
                } label: {
                    Label("New Game", systemImage: "plus")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(palette.buttonFill)
                .controlSize(.large)

                DailyCard()

                shortcuts
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .center)
            .animation(.spring(duration: 0.35), value: model.savedStandardGame?.id)
        }
        .scrollBounceBehavior(.basedOnSize)
        }
        .background(HomeBackground())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showDifficultyPicker, onDismiss: startChosenGame) {
            DifficultyPicker { request in
                chosenRequest = request
                showDifficultyPicker = false
            } onCustom: {
                showDifficultyPicker = false
                model.path.append(.customPuzzle)
            }
        }
        #if DEBUG
        .onAppear {
            if UserDefaults.standard.string(forKey: "debugScenario") == "difficulty" { showDifficultyPicker = true }
        }
        #endif
    }

    private func startChosenGame() {
        guard let request = chosenRequest else { return }
        chosenRequest = nil
        model.request(request)
    }

    private var header: some View {
        VStack(spacing: 10) {
            LogoMark()
                .frame(width: 76, height: 76)
            Text("Sudoku")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .accessibilityAddTraits(.isHeader)
            Text("Pure logic, beautifully simple.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var shortcuts: some View {
        // One tile per row once large text would cut the titles off.
        let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columns), spacing: 12) {
            ShortcutTile(title: "Statistics", subtitle: statisticsSubtitle, symbol: "chart.bar.fill", color: .blue) {
                model.path.append(.statistics)
            }
            ShortcutTile(
                title: "Achievements",
                subtitle: "\(model.achievements.unlockedCount) of \(Achievement.allCases.count)",
                symbol: "trophy.fill",
                color: .orange
            ) {
                model.path.append(.achievements)
            }
            ShortcutTile(title: "Custom Puzzle", subtitle: "Enter your own", symbol: "square.and.pencil", color: .green) {
                model.path.append(.customPuzzle)
            }
            ShortcutTile(title: "How to Play", subtitle: "Rules & techniques", symbol: "questionmark.circle.fill", color: .purple) {
                model.path.append(.help)
            }
        }
    }

    private var statisticsSubtitle: LocalizedStringKey {
        let wins = model.stats.records.count(where: \.isWin)
        return "\(wins) solved"
    }
}

// MARK: - Components

private struct HomeBackground: View {
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            palette.screenBackground
            LinearGradient(
                colors: [palette.accent.opacity(0.22), palette.accent.opacity(0.0)],
                startPoint: .top,
                endPoint: .center
            )
        }
        .ignoresSafeArea()
    }
}

/// The app's emblem: a small stylized sudoku box.
struct LogoMark: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private let digits: [Int?] = [5, nil, 3, nil, 9, nil, 1, nil, 7]

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let gap = side * 0.05
            let tile = (side - gap * 4) / 3
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
                    .fill(palette.accent.gradient)
                    .shadow(color: palette.accent.opacity(0.35), radius: side * 0.12, y: side * 0.06)
                ForEach(0..<9, id: \.self) { index in
                    let row = index / 3, column = index % 3
                    RoundedRectangle(cornerRadius: tile * 0.28, style: .continuous)
                        .fill(.white.opacity(digits[index] == nil ? 0.28 : 0.95))
                        .overlay {
                            if let digit = digits[index] {
                                Text(verbatim: "\(digit)")
                                    .font(.system(size: tile * 0.62, weight: .bold, design: .rounded))
                                    .foregroundStyle(palette.accent)
                            }
                        }
                        .frame(width: tile, height: tile)
                        .scaleEffect(appeared || reduceMotion ? 1 : 0.4)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(duration: 0.5, bounce: 0.4).delay(Double(index) * 0.04), value: appeared)
                        .position(
                            x: gap + tile / 2 + CGFloat(column) * (tile + gap),
                            y: gap + tile / 2 + CGFloat(row) * (tile + gap)
                        )
                }
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
        .onAppear { appeared = true }
    }
}

private struct ContinueCard: View {
    let state: GameState
    let action: () -> Void
    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    // Large text gets the card's whole width rather than a column beside the board.
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            board
                            Spacer(minLength: 0)
                            chevron
                        }
                        details
                    }
                } else {
                    HStack(spacing: 16) {
                        board
                        details
                        chevron
                    }
                }
            }
            .padding(16)
            .cardBackground(palette.controlBackground, cornerRadius: 22, shadow: .black.opacity(0.06), radius: 10, y: 4)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Resumes your unfinished game"))
    }

    private var board: some View {
        MiniBoardView(givens: state.givens, values: state.values)
            .frame(width: 66, height: 66)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.headline)
            .foregroundStyle(.tertiary)
            // The card is a button already; "forward" would only lengthen what VoiceOver reads.
            .accessibilityHidden(true)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Continue")
                .font(.headline)
            // In a row, or one under the other once they don't fit beside each other (large text, or the
            // longer line of a custom puzzle on a narrow iPhone), rather than breaking a word.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { summaryItems(separated: true) }
                VStack(alignment: .leading, spacing: 2) { summaryItems(separated: false) }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            ProgressView(value: state.progress)
                .tint(palette.accent)
        }
    }

    @ViewBuilder
    private func summaryItems(separated: Bool) -> some View {
        if let difficulty = state.difficulty {
            Text(difficulty.title)
                .foregroundStyle(difficulty.color)
        }
        // A custom puzzle is rated like any other; it says what it is too.
        if state.kind == .custom {
            if separated && state.difficulty != nil { separator }
            Text("Custom")
        }
        // "Show timer" off hides the time here too.
        if settings.showTimer {
            if separated { separator }
            Text(verbatim: TimeText.clock(state.elapsed))
                .monospacedDigit()
                .accessibilityLabel(Text(verbatim: TimeText.spoken(state.elapsed)))
        }
    }

    private var separator: some View {
        Text(verbatim: "·")
            .accessibilityHidden(true)
    }
}

private struct DailyCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let challenge = model.today
        let result = model.daily.result(for: challenge)
        let streak = model.daily.currentStreak(today: challenge)

        Button {
            model.path.append(.daily)
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    // Large text gets the card's whole width rather than a column beside the tile.
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 16) {
                            CalendarTile(date: challenge.date, isDone: result != nil)
                            Spacer(minLength: 0)
                            streakLabel(streak)
                            chevron
                        }
                        Text("Daily Challenge")
                            .font(.headline)
                        details(for: challenge, result: result)
                    }
                } else {
                    HStack(spacing: 16) {
                        CalendarTile(date: challenge.date, isDone: result != nil)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Daily Challenge")
                                    .font(.headline)
                                Spacer(minLength: 0)
                                streakLabel(streak)
                            }
                            details(for: challenge, result: result)
                        }
                        chevron
                    }
                }
            }
            .padding(16)
            .cardBackground(palette.controlBackground, cornerRadius: 22, shadow: .black.opacity(0.06), radius: 10, y: 4)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func streakLabel(_ streak: Int) -> some View {
        if streak > 0 {
            Label {
                Text(verbatim: "\(streak)")
            } icon: {
                Image(systemName: "flame.fill")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(palette.flame)
            .accessibilityLabel(Text("\(streak)-day streak"))
        }
    }

    @ViewBuilder
    private func details(for challenge: DailyChallenge, result: DailyResult?) -> some View {
        Text(challenge.difficulty.title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(challenge.difficulty.color)
        Group {
            if let result {
                Label {
                    Text("Solved in \(TimeText.clock(result.duration))")
                        // Its own sentence: a spoken duration can't follow "in" in every language (Czech "za" needs another case).
                        .accessibilityLabel(Text("Solved. Time: \(TimeText.spoken(result.duration))", comment: "VoiceOver, daily challenge card: the time is spelled out, e.g. 4 minutes, 7 seconds."))
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(palette.success)
                }
            } else if model.savedGame(for: challenge) != nil {
                Label("In progress", systemImage: "hourglass")
            } else {
                Label("A new puzzle awaits", systemImage: "sparkles")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.headline)
            .foregroundStyle(.tertiary)
            // The card is a button already; "forward" would only lengthen what VoiceOver reads.
            .accessibilityHidden(true)
    }
}

/// A tear-off calendar page showing a date.
struct CalendarTile: View {
    let date: Date
    var isDone = false
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            Text(date.formatted(.dateTime.month(.abbreviated).dailyCalendar()).uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                // Deeper than the system red, so the white month reads at 4.5:1.
                .background(Color(red: 0.84, green: 0.16, blue: 0.14).gradient)
            Text(verbatim: "\(DailyChallenge.calendar.component(.day, from: date))")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 58, height: 62)
        .background(palette.boardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.primary.opacity(0.08))
        }
        .overlay(alignment: .bottomTrailing) {
            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(palette.onFill, palette.success)
                    .offset(x: 6, y: 6)
            }
        }
        // A fixed-size picture of a calendar page (hidden from VoiceOver); larger text wouldn't fit it.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityHidden(true)
    }
}

private struct ShortcutTile: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringKey
    let symbol: String
    let color: Color
    let action: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    // Its badge doesn't grow with Dynamic Type.
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .frame(width: 40, height: 40)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(titleLineLimit)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                }
                .minimumScaleFactor(0.8)
            }
            // A tile beside one with a two-line text is as tall.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(14)
            .cardBackground(palette.controlBackground, cornerRadius: 20, shadow: .black.opacity(0.05), radius: 8, y: 3)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
    }

    /// Large text has a whole row (see `HomeView.shortcuts`) and may wrap freely. In two columns a narrow
    /// iPhone may need a second line at the largest sizes before the accessibility ones ("Custom Puzzle"),
    /// but a single word shrinks instead: iOS would break it with a hyphen ("Achieve-ments").
    private var titleLineLimit: Int? {
        if dynamicTypeSize.isAccessibilitySize { return nil }
        return String(localized: title).contains(" ") ? 2 : 1
    }
}

/// Slight shrink on press for card-like buttons.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
            // A custom style loses the system's pointer highlight on iPad.
            .hoverEffect(.highlight)
    }
}
