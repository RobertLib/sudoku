//
//  GameControls.swift
//  sudoku
//
//  Info bar, tool buttons and the number pad.
//

import SwiftUI

struct InfoBar: View {
    let session: GameSession
    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .top) {
            column(alignment: .leading) {
                Text(session.state.kind.dailyKey != nil ? "Daily" : "Difficulty")
            } value: {
                if let difficulty = session.state.difficulty {
                    Text(difficulty.title)
                        .foregroundStyle(difficulty.color)
                } else {
                    Text("Custom")
                }
            }

            column(alignment: .center) {
                Text("Mistakes")
            } value: {
                if settings.mistakeMode == .instant {
                    if let limit = session.mistakeLimit {
                        Text(verbatim: "\(session.limitedMistakes)/\(limit)")
                            .foregroundStyle(session.limitedMistakes > 0 ? palette.error : .primary)
                            .accessibilityLabel(Text("\(session.limitedMistakes) of \(limit)"))
                    } else {
                        Text(verbatim: "\(session.state.mistakes)")
                            .foregroundStyle(session.state.mistakes > 0 ? palette.error : .primary)
                    }
                } else {
                    Text(verbatim: "–")
                        .foregroundStyle(.secondary)
                        // Not "dash": mistakes are kept from the player in this mode.
                        .accessibilityLabel(Text("Not shown"))
                }
            }
            .contentTransition(.numericText())
            .animation(.snappy, value: session.state.mistakes)

            column(alignment: .trailing) {
                Text("Time")
            } value: {
                if settings.showTimer {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let elapsed = session.elapsed(at: context.date)
                        Text(verbatim: TimeText.clock(elapsed))
                            .monospacedDigit()
                            .accessibilityLabel(Text(verbatim: TimeText.spoken(elapsed)))
                    }
                } else {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(Text("Not shown"))
                }
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    private func column(
        alignment: HorizontalAlignment,
        @ViewBuilder title: () -> some View,
        @ViewBuilder value: () -> some View
    ) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            title()
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            value()
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
    }
}

struct ToolRow: View {
    let session: GameSession
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            ToolButton(title: "Undo", symbol: "arrow.uturn.backward", isEnabled: session.canUndo) {
                session.undo()
            }
            .gameKeyboardShortcut(KeyboardShortcut("z", modifiers: .command))

            ToolButton(title: "Erase", symbol: "eraser", isEnabled: session.isPlaying) {
                session.erase()
            }

            ToolButton(
                title: "Notes",
                symbol: session.isNotesMode ? "pencil.circle.fill" : "pencil",
                badge: session.isNotesMode ? "ON" : "OFF",
                isOn: session.isNotesMode,
                isEnabled: session.isPlaying
            ) {
                session.toggleNotesMode()
            }

            ToolButton(title: "Hint", symbol: "lightbulb", isLoading: session.isComputingHint, isEnabled: session.isPlaying) {
                session.requestHint()
            }
        }
    }
}

private struct ToolButton: View {
    let title: LocalizedStringKey
    let symbol: String
    var badge: LocalizedStringKey?
    var isOn = false
    var isLoading = false
    var isEnabled = true
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: symbol)
                            .font(.system(size: 21, weight: .medium))
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .frame(height: 26)
                .overlay(alignment: .topTrailing) {
                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .fixedSize()
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .foregroundStyle(isOn ? AnyShapeStyle(palette.onFill) : AnyShapeStyle(.secondary))
                            .background(isOn ? AnyShapeStyle(palette.accent) : AnyShapeStyle(.quaternary), in: Capsule())
                            .offset(x: 23, y: -5)
                            .accessibilityHidden(true)
                    }
                }
                Text(title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    // Not the accent when on: accent text on the accent tint falls below 4.5:1.
                    .foregroundStyle(.primary)
            }
            .foregroundStyle(isOn ? palette.accent : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isOn ? palette.accent.opacity(0.14) : palette.controlBackground)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        // The title alone: the symbol's own name would be read along with it.
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        // The game screen caps Dynamic Type; a long press shows the label at the full size.
        .accessibilityShowsLargeContentViewer {
            Label(title, systemImage: symbol)
        }
    }
}

struct NumberPad: View {
    enum Layout { case row, grid }

    let session: GameSession
    let layout: Layout
    @Environment(AppSettings.self) private var settings

    var body: some View {
        switch layout {
        case .row:
            HStack(spacing: 5) {
                ForEach(1...9, id: \.self) { digit in
                    PadButton(session: session, digit: digit)
                }
            }
            .frame(minHeight: 52, idealHeight: 80, maxHeight: 82)
        case .grid:
            SwiftUI.Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(0..<3, id: \.self) { row in
                    SwiftUI.GridRow {
                        ForEach(1...3, id: \.self) { column in
                            PadButton(session: session, digit: row * 3 + column)
                                .aspectRatio(1.15, contentMode: .fit)
                        }
                    }
                }
            }
        }
    }
}

private struct PadButton: View {
    let session: GameSession
    let digit: Int
    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Set by a long press so the tap that ends it – however late – doesn't toggle the lock
    /// straight back. Cleared once that touch is over, as the tap never comes if the finger slid off
    /// the key: VoiceOver, Voice Control or a keyboard activate the key without a touch to clear it.
    @State private var suppressTap = false

    var body: some View {
        let remaining = max(0, 9 - session.count(of: digit))
        let isComplete = session.isDigitComplete(digit)
        let isHidden = isComplete && settings.hideCompletedDigits
        let isActive = isActive
        let notes = session.isNotesMode

        Button {
            if suppressTap {
                suppressTap = false
            } else {
                session.padTapped(digit)
            }
        } label: {
            GeometryReader { proxy in
                let height = proxy.size.height
                ZStack {
                    RoundedRectangle(cornerRadius: min(14, height * 0.22), style: .continuous)
                        .fill(isActive ? AnyShapeStyle(palette.accent) : AnyShapeStyle(palette.controlBackground))

                    if notes {
                        Text(verbatim: "\(digit)")
                            .font(.system(size: height * 0.3, weight: .semibold, design: settings.digitStyle.design))
                            .foregroundStyle(isActive ? palette.onFill : palette.accent)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: noteAlignment)
                            .padding(.horizontal, proxy.size.width * 0.14)
                            .padding(.vertical, height * 0.1)
                    } else {
                        VStack(spacing: 0) {
                            Text(verbatim: "\(digit)")
                                .font(.system(size: min(height * 0.48, proxy.size.width * 0.75), weight: .medium, design: settings.digitStyle.design))
                                .foregroundStyle(isActive ? palette.onFill : palette.accent)
                            if settings.showRemainingCounts {
                                Text(verbatim: "\(remaining)")
                                    .font(.system(size: max(9, height * 0.16), weight: .semibold, design: .rounded))
                                    .foregroundStyle(isActive ? AnyShapeStyle(palette.onFill.opacity(0.85)) : AnyShapeStyle(.secondary))
                            }
                        }
                    }
                }
                .animation(.spring(duration: 0.3), value: notes)
            }
        }
        .buttonStyle(PressableStyle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .onChanged { _ in suppressTap = false }
                .onEnded { _ in
                    suppressTap = true
                    session.toggleLock(digit)
                }
        )
        .simultaneousGesture(
            // Ends with the touch, wherever the finger is. Cleared afterwards, once the tap of that touch
            // (if any) has seen it.
            DragGesture(minimumDistance: 0)
                .onEnded { _ in Task { suppressTap = false } }
        )
        .opacity(isHidden ? 0 : 1)
        .scaleEffect(isHidden && !reduceMotion ? 0.6 : 1)
        .animation(.spring(duration: 0.35), value: isHidden)
        .disabled(isHidden || !session.isPlaying)
        .accessibilityLabel(Text(verbatim: "\(digit)"))
        // Like the count under the digit, only when the player wants to see it.
        .accessibilityValue(settings.showRemainingCounts ? Text("\(remaining) remaining") : Text(verbatim: ""))
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .accessibilityAction(named: session.lockedDigit == digit ? Text("Unlock number") : Text("Lock number")) {
            session.toggleLock(digit)
        }
    }

    /// What a tap does (see `GameSession.padTapped`).
    private var accessibilityHint: Text {
        if session.settings.inputMode == .digitFirst || session.lockedDigit != nil {
            return session.lockedDigit == digit
                ? Text("Unlocks the number")
                : Text("Locks the number for the cells you tap next")
        }
        return session.isNotesMode
            ? Text("Toggles the note in the selected cell")
            : Text("Enters the number in the selected cell")
    }

    /// Highlighted when it's the locked digit, or a note present in the selected cell.
    private var isActive: Bool {
        if session.settings.inputMode == .digitFirst || session.lockedDigit != nil {
            return session.lockedDigit == digit
        }
        guard session.isNotesMode, let selection = session.selection else { return false }
        return session.state.values[selection] == 0 && session.state.notes[selection].contains(digit: digit)
    }

    private var noteAlignment: Alignment {
        let alignments: [Alignment] = [.topLeading, .top, .topTrailing, .leading, .center, .trailing, .bottomLeading, .bottom, .bottomTrailing]
        return alignments[digit - 1]
    }
}
