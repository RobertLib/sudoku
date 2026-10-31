//
//  GameOverlays.swift
//  sudoku
//
//  Pause, victory and game over screens shown on top of the game.
//

import SwiftUI

struct PauseOverlay: View {
    let session: GameSession
    /// Leaves the game without resuming it (the navigation bar is hidden while paused).
    let onClose: () -> Void
    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()
                .onTapGesture { withAnimation { session.resume() } }

            // Scrolls only when it doesn't fit (large text on an iPhone in landscape), so a tap
            // beside the card keeps resuming the game.
            ViewThatFits(in: .vertical) {
                card
                ScrollView {
                    card
                        .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .modalForVoiceOver(focusing: $isTitleFocused)
    }

    private var card: some View {
        VStack(spacing: 18) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(palette.accent)
                .symbolEffect(.pulse)
                .accessibilityHidden(true)
            Text("Paused")
                .font(.largeTitle.weight(.bold))
                // One word: shrunk rather than hyphenated at the largest text sizes.
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityFocused($isTitleFocused)
            let stats = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 24))
            stats {
                // "Show timer" off hides the time here too.
                if settings.showTimer {
                    stat(title: "Time", value: TimeText.clock(session.elapsed()), spokenValue: TimeText.spoken(session.elapsed()))
                }
                stat(title: "Progress", value: session.state.progress.formatted(.percent.precision(.fractionLength(0)).locale(AppLocale.current)))
                if let difficulty = session.state.difficulty {
                    VStack(spacing: 3) {
                        Text("Difficulty")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(difficulty.title)
                            .font(.headline)
                            .foregroundStyle(difficulty.color)
                    }
                    // One stop for VoiceOver, like the stats beside it.
                    .accessibilityElement(children: .combine)
                }
            }
            Button {
                withAnimation { session.resume() }
            } label: {
                Label("Resume", systemImage: "play.fill")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(minWidth: 180)
            }
            .buttonStyle(.glassProminent)
            .tint(palette.buttonFill)
            .controlSize(.large)
            .gameKeyboardShortcut(.defaultAction)

            // Leaving doesn't take resuming first, which would run the clock on the way out.
            Button(session.state.kind.dailyKey != nil ? "Back to Calendar" : "Back to Home", action: onClose)
                .font(.subheadline.weight(.medium))
                .gameKeyboardShortcut(.cancelAction)
        }
        .padding(32)
    }

    private func stat(title: LocalizedStringKey, value: String, spokenValue: String? = nil) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.headline)
                .monospacedDigit()
                .accessibilityLabel(Text(verbatim: spokenValue ?? value))
        }
        .accessibilityElement(children: .combine)
    }
}

struct WinOverlay: View {
    let session: GameSession
    let summary: CompletionSummary
    let onNewGame: () -> Void
    let onDone: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var isTitleFocused: Bool
    @State private var appeared = false

    private var isDaily: Bool { session.state.kind.dailyKey != nil }

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.35 : 0)
                .ignoresSafeArea()

            if !reduceMotion {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            ScrollView {
                card
                    .padding(20)
                    .frame(maxWidth: 440)
                    .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .cardScrollAnchors()
            .scaleEffect(appeared || reduceMotion ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .modalForVoiceOver(focusing: $isTitleFocused)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) { appeared = true }
        }
    }

    private var card: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(palette.accent.gradient)
                    .frame(width: 84, height: 84)
                    .shadow(color: palette.accent.opacity(0.4), radius: 14, y: 6)
                Image(systemName: summary.isNewBest ? "crown.fill" : "checkmark.seal.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(palette.onFill)
                    .symbolEffect(.bounce, value: appeared)
            }
            .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(praise)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .accessibilityFocused($isTitleFocused)
                Text(isDaily ? "Daily challenge solved" : "Puzzle solved")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                // A custom puzzle beyond the hint engine has no difficulty to show.
                if let difficulty = session.state.difficulty {
                    Text(difficulty.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(difficulty.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(difficulty.color.opacity(0.08), in: Capsule())
                }
            }

            VStack(spacing: 0) {
                statRow(
                    symbol: "clock.fill",
                    title: "Time",
                    value: TimeText.clock(summary.duration),
                    spokenValue: TimeText.spoken(summary.duration),
                    badge: summary.isNewBest ? "New record!" : nil
                )
                if let best = summary.previousBest, !summary.isNewBest {
                    Divider().padding(.leading, 44)
                    statRow(symbol: "trophy.fill", title: "Best time", value: TimeText.clock(best), spokenValue: TimeText.spoken(best))
                }
                Divider().padding(.leading, 44)
                statRow(symbol: "xmark.circle.fill", title: "Mistakes", value: "\(summary.mistakes)")
                Divider().padding(.leading, 44)
                statRow(symbol: "lightbulb.fill", title: "Hints", value: "\(summary.hints)")
                if let streak = summary.dailyStreak, streak > 0 {
                    Divider().padding(.leading, 44)
                    statRow(symbol: "flame.fill", title: "Daily streak", value: "\(streak)")
                }
            }
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            if !summary.unlocked.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(summary.unlocked.count == 1 ? "Achievement unlocked" : "Achievements unlocked")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(summary.unlocked) { achievement in
                        HStack(spacing: 12) {
                            Image(systemName: achievement.symbol)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(achievement.color.gradient, in: Circle())
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(achievement.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(achievement.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 10) {
                if !isDaily {
                    Button(action: onNewGame) {
                        Label("New Game", systemImage: "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(palette.buttonFill)
                    .controlSize(.large)
                    .gameKeyboardShortcut(.defaultAction)
                }
                Button(action: onDone) {
                    Text(isDaily ? "Done" : "Home")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(isDaily ? AnyPrimitiveButtonStyle(.glassProminent) : AnyPrimitiveButtonStyle(.glass))
                .tint(isDaily ? palette.buttonFill : palette.accent)
                .controlSize(.large)
                .gameKeyboardShortcut(isDaily ? .defaultAction : .cancelAction)
            }
        }
        .padding(24)
        .cardBackground(palette.controlBackground, cornerRadius: 32, shadow: .black.opacity(0.2), radius: 30, y: 10)
    }

    private var praise: LocalizedStringKey {
        if summary.isNewBest { return "New Record!" }
        if summary.mistakes == 0 && summary.hints == 0 { return "Perfect!" }
        let options: [LocalizedStringKey] = ["Brilliant!", "Excellent!", "Well Done!", "Great Job!"]
        // Derived from the game id (not `hashValue`, which changes every launch) so a game keeps its praise.
        return options[Int(session.state.id.uuid.0) % options.count]
    }

    private func statRow(
        symbol: String,
        title: LocalizedStringKey,
        value: String,
        spokenValue: String? = nil,
        badge: LocalizedStringKey? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(palette.accent)
                .frame(width: 22)
                .accessibilityHidden(true)
            // With large text the value goes under the title rather than squeezing it into a column.
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                    if let badge { badgeLabel(badge) }
                    Text(verbatim: value)
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .accessibilityLabel(Text(verbatim: spokenValue ?? value))
                }
                Spacer(minLength: 0)
            } else {
                Text(title)
                if let badge { badgeLabel(badge) }
                Spacer()
                Text(verbatim: value)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .accessibilityLabel(Text(verbatim: spokenValue ?? value))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    private func badgeLabel(_ badge: LocalizedStringKey) -> some View {
        Text(badge)
            .font(.caption.weight(.bold))
            .foregroundStyle(palette.onFill)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(palette.flame.gradient, in: Capsule())
    }
}

struct GameOverOverlay: View {
    let session: GameSession
    let onRestart: () -> Void
    let onNewGame: () -> Void
    let onClose: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var isTitleFocused: Bool
    @State private var appeared = false

    private var isDaily: Bool { session.state.kind.dailyKey != nil }

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.4 : 0)
                .ignoresSafeArea()

            // Scrolls when it doesn't fit, e.g. on an iPhone in landscape.
            ScrollView {
                card
                    .padding(20)
                    .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .cardScrollAnchors()
            .scaleEffect(appeared || reduceMotion ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .modalForVoiceOver(focusing: $isTitleFocused)
        .onAppear {
            withAnimation(.spring(duration: 0.45, bounce: 0.3)) { appeared = true }
        }
    }

    private var card: some View {
        VStack(spacing: 18) {
            Image(systemName: "heart.slash.fill")
                .font(.system(size: 50))
                .foregroundStyle(palette.error)
                .symbolEffect(.bounce, value: appeared)
                .accessibilityHidden(true)
            VStack(spacing: 6) {
                Text("Game Over")
                    .font(.largeTitle.weight(.bold))
                    .accessibilityFocused($isTitleFocused)
                Text("You've made \(session.limitedMistakes) mistakes.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                if session.canUseSecondChance {
                    Button {
                        withAnimation { session.secondChance() }
                    } label: {
                        VStack(spacing: 2) {
                            Label("Second Chance", systemImage: "arrow.uturn.backward.circle.fill")
                                .font(.headline)
                            Text("Undo the last mistake and keep going")
                                .font(.caption)
                                .opacity(0.85)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(palette.buttonFill)
                    .controlSize(.large)
                    .gameKeyboardShortcut(.defaultAction)
                }

                // Side by side, or one under the other once large text would cut the labels off.
                let buttons = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
                buttons {
                    Button {
                        withAnimation { onRestart() }
                    } label: {
                        Label("Restart", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)

                    // A daily challenge has no next one (see `AppModel.playAgain`).
                    if !isDaily {
                        Button(action: onNewGame) {
                            Label("New Game", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .gameKeyboardShortcut(session.canUseSecondChance ? nil : .defaultAction)
                    }
                }
                // "Začít znovu" would otherwise wrap onto two lines; stacked, a label may wrap.
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(0.8)

                Button(isDaily ? "Back to Calendar" : "Back to Home", action: onClose)
                    .font(.subheadline.weight(.medium))
                    .padding(.top, 4)
                    // Return leaves a lost daily challenge, which has no new game to start.
                    .gameKeyboardShortcut(isDaily && !session.canUseSecondChance ? .defaultAction : .cancelAction)
            }
        }
        .padding(26)
        .frame(maxWidth: 400)
        .cardBackground(palette.controlBackground, cornerRadius: 32, shadow: .black.opacity(0.2), radius: 30, y: 10)
    }
}

/// Shown at the bottom after the player chose to reveal the solution.
struct SolutionRevealedBar: View {
    let isDaily: Bool
    let onNewGame: () -> Void
    let onClose: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 12) {
            Label("Solution revealed", systemImage: "eye.fill")
                .font(.headline)
            Text("Study the solution, then try a new puzzle.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                // A daily challenge has no next one (see `AppModel.playAgain`).
                if isDaily {
                    Button(action: onClose) {
                        Text("Back to Calendar").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(palette.buttonFill)
                    .controlSize(.large)
                    .gameKeyboardShortcut(.defaultAction)
                } else {
                    Button(action: onClose) {
                        Text("Home").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .gameKeyboardShortcut(.cancelAction)
                    Button(action: onNewGame) {
                        Label("New Game", systemImage: "plus").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(palette.buttonFill)
                    .controlSize(.large)
                    .gameKeyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.controlBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// A short-lived banner with feedback such as "No mistakes so far".
struct MessageToast: View {
    let message: GameMessage
    @Environment(\.palette) private var palette

    var body: some View {
        Label {
            Text(message.text)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(color)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: Capsule())
        .accessibilityAddTraits(.isStaticText)
    }

    private var symbol: String {
        switch message {
        case .boardHasErrors, .mistakesFound: "exclamationmark.triangle.fill"
        case .noMistakesFound: "checkmark.circle.fill"
        }
    }

    private var color: Color {
        switch message {
        case .boardHasErrors, .mistakesFound: palette.warning
        case .noMistakesFound: palette.success
        }
    }
}

/// Type-erased primitive button style so a button can switch styles conditionally.
struct AnyPrimitiveButtonStyle: PrimitiveButtonStyle {
    private let make: (Configuration) -> AnyView

    init<S: PrimitiveButtonStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        make(configuration)
    }
}

extension View {
    /// A card that fits sits in the middle; one that doesn't (large text, an iPhone in landscape) starts
    /// at its top, rather than in the middle with its title scrolled under the navigation bar.
    func cardScrollAnchors() -> some View {
        defaultScrollAnchor(.center, for: .alignment)
            .defaultScrollAnchor(.top, for: .initialOffset)
    }

    /// A rounded background with a drop shadow. The shadow belongs to the shape alone: on the whole
    /// view it would be drawn under every element inside it, each one blurred separately.
    func cardBackground(_ color: Color, cornerRadius: CGFloat, shadow: Color, radius: CGFloat, y: CGFloat) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(color)
                .shadow(color: shadow, radius: radius, y: y)
        }
    }

    /// Keeps VoiceOver inside an overlay and moves its cursor to `title`, so it reads what just
    /// happened instead of staying on a control the overlay covers.
    func modalForVoiceOver(focusing title: AccessibilityFocusState<Bool>.Binding) -> some View {
        accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .task {
                // Right after appearing, the title isn't in the accessibility tree yet.
                do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                title.wrappedValue = true
            }
    }
}
