//
//  DifficultyPicker.swift
//  sudoku
//

import SwiftUI

struct DifficultyPicker: View {
    let onSelect: (GameRequest) -> Void
    let onCustom: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Difficulty.allCases) { difficulty in
                        Button {
                            onSelect(.new(difficulty))
                        } label: {
                            DifficultyRow(difficulty: difficulty, bestTime: model.stats.bestTime(for: difficulty))
                        }
                        .buttonStyle(PressableStyle())
                    }

                    Button(action: onCustom) {
                        HStack(spacing: 14) {
                            Image(systemName: "square.and.pencil")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(palette.accent)
                                // Its badge doesn't grow with Dynamic Type.
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                .frame(width: 44, height: 44)
                                .background(palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Custom Puzzle")
                                    .font(.headline)
                                Text("Enter a puzzle from a newspaper or book")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .padding(14)
                        .background(palette.controlBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .background(palette.screenBackground)
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

private struct DifficultyRow: View {
    let difficulty: Difficulty
    let bestTime: TimeInterval?
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Large text gets the row's whole width rather than a column between badge and time.
                VStack(alignment: .leading, spacing: 6) {
                    badge
                    titles
                    best(alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 14) {
                    badge
                    titles
                    Spacer(minLength: 8)
                    best(alignment: .trailing)
                }
            }
        }
        .padding(14)
        .background(palette.controlBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var badge: some View {
        DifficultyBadge(difficulty: difficulty)
            .frame(width: 44, height: 44)
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(difficulty.title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(difficulty.subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
    }

    @ViewBuilder
    private func best(alignment: HorizontalAlignment) -> some View {
        if let bestTime {
            VStack(alignment: alignment, spacing: 1) {
                Text("Best")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(verbatim: TimeText.clock(bestTime))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .accessibilityLabel(Text(verbatim: TimeText.spoken(bestTime)))
                    .foregroundStyle(.primary)
            }
        }
    }
}

/// Five bars, filled up to the difficulty level.
struct DifficultyBadge: View {
    let difficulty: Difficulty

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(difficulty.color.opacity(0.15))
            HStack(alignment: .bottom, spacing: 2.5) {
                ForEach(0..<5, id: \.self) { level in
                    Capsule()
                        .fill(level <= difficulty.order ? AnyShapeStyle(difficulty.color) : AnyShapeStyle(difficulty.color.opacity(0.25)))
                        .frame(width: 4, height: 8 + CGFloat(level) * 4)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
