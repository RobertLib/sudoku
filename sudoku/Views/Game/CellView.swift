//
//  CellView.swift
//  sudoku
//

import SwiftUI

enum CellFill: Equatable {
    case none, peer, sameDigit, selected, error, hintHouse, hintSecondary, hintPattern, hintTarget
}

enum DigitTone: Equatable {
    case given, user
    /// Known to be wrong (instant checking or Check Board).
    case wrong
    /// Repeated in a row, column or box – one of the repeats may well be right.
    case conflict
}

struct CellModel: Equatable {
    var index: Int
    var value: Int
    var notes: DigitMask
    var isGiven: Bool
    var isSelected: Bool
    /// Drawn while a hint's colors replace the selection fill (see `GameSession.movedSelectionDuringHint`).
    var isSelectionOutlined = false
    var fill: CellFill
    var tone: DigitTone
    /// Repeated in its row, column or box – also a given digit, which keeps its color while its cell is tinted.
    var isRepeated = false
    var noteHighlight: Int
    var hintMarks: HintMarks?
    var isHintTarget: Bool
    /// Picked out by the hint being shown; the board shows it with color, VoiceOver says it.
    var isHintHighlighted = false
    var isHidden: Bool
    var flash: FlashToken
    var shake: Int
}

struct CellView: View {
    let model: CellModel
    let size: CGFloat

    @Environment(\.palette) private var palette
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        ZStack {
            fillColor
                .animation(.easeOut(duration: 0.15), value: model.fill)

            if !model.isHidden {
                // In a container of its own, animated from outside: the container inserting the digit must
                // update in an animated transaction, or a digit typed into an empty cell just appears.
                ZStack { content }
                    .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.3, bounce: 0.45), value: model.value)
            }

            if model.isHintTarget {
                RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                    .strokeBorder(palette.success, lineWidth: max(2, size * 0.06))
                    .padding(size * 0.05)
            }

            if model.isSelectionOutlined {
                Rectangle()
                    .strokeBorder(palette.accent, lineWidth: max(2, size * 0.05))
            }
        }
        .modifier(FlashEffect(token: model.flash, color: palette.accent))
        .modifier(ShakeEffect(trigger: model.shake))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(model.isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var content: some View {
        if model.value != 0 {
            Text(verbatim: "\(model.value)")
                .font(.system(size: size * 0.62, weight: model.isGiven ? .semibold : .regular, design: settings.digitStyle.design))
                .foregroundStyle(toneColor)
                .overlay(alignment: .bottom) {
                    // With Differentiate Without Color, a wrong or repeated digit is also underlined.
                    if differentiateWithoutColor && (model.tone == .wrong || model.tone == .conflict || model.isRepeated) {
                        Capsule()
                            .fill(palette.error)
                            .frame(width: size * 0.42, height: max(2, size * 0.06))
                            .offset(y: size * 0.02)
                    }
                }
                .id(model.value)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.4).combined(with: .opacity))
        } else if let marks = model.hintMarks {
            HintCandidates(marks: marks, size: size, color: notesColor)
        } else if model.notes != 0 {
            NotesGrid(notes: model.notes, highlight: model.noteHighlight, size: size, color: notesColor)
        }
    }

    /// Small digits stay at 4.5:1 on the stronger fills too.
    private var notesColor: Color {
        switch model.fill {
        case .none, .peer, .hintSecondary: palette.notesDigit
        default: palette.notesDigitOnTint
        }
    }

    private var fillColor: Color {
        switch model.fill {
        case .none: .clear
        case .peer: palette.peerFill
        case .sameDigit: palette.sameDigitFill
        case .selected: palette.selectedFill
        case .error: palette.errorFill
        case .hintHouse: palette.hintHouseFill
        case .hintSecondary: palette.hintSecondaryFill
        case .hintPattern: palette.hintPatternFill
        case .hintTarget: palette.hintTargetFill
        }
    }

    private var toneColor: Color {
        switch model.tone {
        case .given: palette.givenDigit
        case .user: palette.userDigit
        case .wrong, .conflict: palette.error
        }
    }

    private var accessibilityLabel: Text {
        Text("Row \(model.index / 9 + 1), column \(model.index % 9 + 1)")
    }

    private var accessibilityValue: Text {
        if model.isHidden { return Text("Hidden") }
        var parts = [contentDescription]
        if let marks = model.hintMarks, model.value == 0 {
            if marks.placement != 0 {
                parts.append(String(localized: "Place \(marks.placement) here"))
            }
            if marks.eliminated != 0 {
                parts.append(String(localized: "Remove \(Self.list(marks.eliminated)) here"))
            }
        }
        if model.isHintHighlighted {
            parts.append(String(localized: "Highlighted by the hint"))
        }
        return Text(verbatim: parts.joined(separator: ", "))
    }

    private var contentDescription: String {
        if model.value != 0 {
            switch model.tone {
            case .wrong: return String(localized: "\(model.value), incorrect")
            case .conflict: return String(localized: "\(model.value), repeated in its row, column or box")
            case .given where model.isRepeated: return String(localized: "\(model.value), given, repeated in its row, column or box")
            case .given: return String(localized: "\(model.value), given")
            case .user: return String(model.value)
            }
        }
        // While a hint explains a step, the cell shows the candidates it works with instead of the notes.
        if let marks = model.hintMarks, marks.all != 0 {
            return String(localized: "Candidates: \(Self.list(marks.all))")
        }
        if model.notes != 0 {
            return String(localized: "Notes: \(Self.list(model.notes))")
        }
        return String(localized: "Empty")
    }

    private static func list(_ digits: DigitMask) -> String {
        digits.digits.map(String.init).joined(separator: ", ")
    }
}

/// Pencil marks laid out in a 3×3 grid.
private struct NotesGrid: View {
    let notes: DigitMask
    let highlight: Int
    let size: CGFloat
    let color: Color
    @Environment(\.palette) private var palette
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let sub = size / 3
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(1...3, id: \.self) { column in
                        let digit = row * 3 + column
                        ZStack {
                            if notes.contains(digit: digit) {
                                if digit == highlight {
                                    Circle()
                                        .fill(palette.accent)
                                        .padding(sub * 0.08)
                                }
                                Text(verbatim: "\(digit)")
                                    .font(.system(size: sub * 0.72, weight: digit == highlight ? .bold : .medium, design: settings.digitStyle.design))
                                    .foregroundStyle(digit == highlight ? palette.onFill : color)
                            }
                        }
                        .frame(width: sub, height: sub)
                    }
                }
            }
        }
        .transition(.opacity)
    }
}

/// Candidates shown while a hint explains a step, color-coded by role.
private struct HintCandidates: View {
    let marks: HintMarks
    let size: CGFloat
    /// For the candidates that play no part in the step.
    let color: Color
    @Environment(\.palette) private var palette

    var body: some View {
        let sub = size / 3
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(1...3, id: \.self) { column in
                        let digit = row * 3 + column
                        candidate(digit, sub: sub)
                            .frame(width: sub, height: sub)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func candidate(_ digit: Int, sub: CGFloat) -> some View {
        if marks.all.contains(digit: digit) || marks.placement == digit {
            let style = role(of: digit)
            ZStack {
                if let fill = style.fill {
                    Circle().fill(fill).padding(sub * 0.06)
                }
                Text(verbatim: "\(digit)")
                    .font(.system(size: sub * 0.72, weight: style.fill == nil ? .medium : .bold, design: .rounded))
                    .foregroundStyle(style.text)
                    .strikethrough(style.isEliminated, color: palette.error)
            }
        }
    }

    private func role(of digit: Int) -> (fill: Color?, text: Color, isEliminated: Bool) {
        if marks.placement == digit { return (palette.success, palette.onFill, false) }
        if marks.eliminated.contains(digit: digit) { return (palette.error.opacity(0.18), palette.eliminatedDigit, true) }
        if marks.alternate.contains(digit: digit) { return (palette.hintAlternate, palette.onFill, false) }
        if marks.pattern.contains(digit: digit) { return (palette.accent, palette.onFill, false) }
        return (nil, color, false)
    }
}

/// Briefly lights up a cell; a new token id restarts the pulse after its delay.
private struct FlashEffect: ViewModifier {
    let token: FlashToken
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            Rectangle()
                .fill(color)
                .keyframeAnimator(initialValue: 0.0, trigger: token.id) { view, opacity in
                    view.opacity(opacity)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(0.0, duration: reduceMotion ? 0.01 : token.delay)
                        CubicKeyframe(reduceMotion ? 0.25 : 0.42, duration: 0.14)
                        CubicKeyframe(0.0, duration: 0.5)
                    }
                }
                .allowsHitTesting(false)
        }
    }
}

/// Horizontal shake after a mistake. With Reduce Motion the red digit, sound and haptic are enough.
private struct ShakeEffect: ViewModifier {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let amplitude = reduceMotion ? 0.0 : 1.0
        return content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, offset in
            view.offset(x: offset * amplitude)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(-5, duration: 0.05)
                LinearKeyframe(5, duration: 0.07)
                LinearKeyframe(-4, duration: 0.07)
                LinearKeyframe(3, duration: 0.06)
                LinearKeyframe(0, duration: 0.05)
            }
        }
    }
}
