//
//  HintPanel.swift
//  sudoku
//

import SwiftUI

struct HintPanel: View {
    let session: GameSession
    let hint: HintSession
    /// Under the board, the panel keeps room for its text (see `minTextHeight`). Beside it, in landscape,
    /// the column is as tall as the screen and no taller: with large text that room would push the
    /// buttons and the board off the bottom, so the text scrolls in whatever space is left instead.
    var keepsTextRoom = true
    @Environment(\.palette) private var palette
    @AccessibilityFocusState private var isMessageFocused: Bool
    /// About three lines, so the explanation never gets squeezed out by the board.
    @ScaledMetric(relativeTo: .callout) private var minTextHeight: CGFloat = 64
    @ScaledMetric(relativeTo: .callout) private var maxHeight: CGFloat = 340

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(HintText.message(for: hint))
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityFocused($isMessageFocused)
                    if let result = HintText.result(for: hint) {
                        Text(result)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(palette.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            // Measured at its room, not at its whole length, wherever ideal sizes decide (the
            // landscape column): a long explanation scrolls rather than take the space of others.
            .frame(minHeight: keepsTextRoom ? minTextHeight : nil, idealHeight: minTextHeight)
            .id(hint.stage)
            .transition(.opacity)

            buttons
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: maxHeight, alignment: .top)
        .cardBackground(palette.controlBackground, cornerRadius: 24, shadow: .black.opacity(0.08), radius: 12, y: 4)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(palette.warning.opacity(0.5), lineWidth: 1.5)
        }
        .animation(.easeInOut(duration: 0.2), value: hint.stage)
        .task(id: hint.stage) {
            // VoiceOver was on the Hint button, which the panel replaces, or on Show Me / Next Step,
            // whose new text isn't the news: read the explanation. Not before it's in the tree.
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            isMessageFocused = true
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "lightbulb.max.fill")
                .font(.title3)
                .foregroundStyle(palette.warning)
                .symbolEffect(.bounce, value: hint.stage)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(HintText.title(for: hint))
                    .font(.headline)
                if let technique = (hint.isNudge ? hint.entries.first : hint.currentEntry)?.step.technique {
                    Text(technique.difficulty.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(technique.difficulty.color)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            // Before the spacer, which would otherwise take half the width and wrap the title early.
            .layoutPriority(1)
            Spacer(minLength: 4)
            if !hint.isNudge && hint.entries.count > 1 {
                Text("Step \(hint.stage) of \(hint.entries.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    // Short, and not to be wrapped by the title's priority.
                    .fixedSize()
            }
            Button {
                session.dismissHint()
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(.quaternary, in: Circle())
            }
            .accessibilityLabel(Text("Close hint"))
        }
    }

    @ViewBuilder
    private var buttons: some View {
        HStack(spacing: 10) {
            if hint.stage > 1 {
                Button {
                    session.showPreviousHintStage()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }

            Button {
                primaryAction()
            } label: {
                Text(primaryTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(palette.buttonFill)
            .controlSize(.large)
        }
    }

    private var primaryTitle: LocalizedStringKey {
        switch hint.content {
        case .mistakes(let cells): cells.count == 1 ? "Remove Mistake" : "Remove Mistakes"
        case .badNotes: "Fix Notes"
        case .noStep: "Reveal a Cell"
        case .logic:
            if hint.isNudge { "Show Me" } else if hint.isLastStage { "Apply" } else { "Next Step" }
        }
    }

    private func primaryAction() {
        switch hint.content {
        case .logic where !hint.isLastStage || hint.isNudge:
            session.showNextHintStage()
        default:
            withAnimation(.spring(duration: 0.3)) {
                session.announcingChanges { session.applyHint() }
            }
        }
    }
}
