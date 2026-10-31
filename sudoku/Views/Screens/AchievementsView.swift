//
//  AchievementsView.swift
//  sudoku
//

import SwiftUI

struct AchievementsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let context = model.achievementContext
        let unlocked = model.achievements.unlockedCount
        let total = Achievement.allCases.count

        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    Text("\(unlocked) of \(total) unlocked")
                        .font(.headline)
                    ProgressView(value: Double(unlocked), total: Double(total))
                        .tint(palette.accent)
                }
                .padding(16)
                .background(palette.controlBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10)], spacing: 10) {
                    ForEach(Achievement.allCases) { achievement in
                        AchievementRow(
                            achievement: achievement,
                            unlockDate: model.achievements.unlockDate(achievement),
                            progress: achievement.progress(in: context)
                        )
                    }
                }

                // Matches `AchievementContext.wins`.
                Text("Custom puzzles only count towards “Your Own Puzzle”.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 720)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .background(palette.screenBackground.ignoresSafeArea())
        .navigationTitle("Achievements")
    }
}

private struct AchievementRow: View {
    let achievement: Achievement
    let unlockDate: Date?
    let progress: (current: Int, target: Int)?
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isUnlocked = unlockDate != nil
        // Large text gets the card's whole width, under the badge rather than in a column beside it.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 14))
        layout {
            ZStack {
                Circle()
                    .fill(isUnlocked ? AnyShapeStyle(achievement.color.gradient) : AnyShapeStyle(.quaternary))
                Image(systemName: isUnlocked ? achievement.symbol : "lock.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isUnlocked ? .white : .secondary)
                    // Its circle doesn't grow with Dynamic Type.
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    // "Unlocked" or "Locked" is the card's value.
                    .accessibilityHidden(true)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text(achievement.title)
                    .font(.headline)
                    .foregroundStyle(isUnlocked ? .primary : .secondary)
                Text(achievement.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let unlockDate {
                    Text(unlockDate.formatted(.dateTime.day().month().year().locale(AppLocale.current)))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                } else if let progress {
                    HStack(spacing: 8) {
                        ProgressView(value: Double(min(progress.current, progress.target)), total: Double(progress.target))
                            .tint(achievement.color)
                        Text(verbatim: "\(min(progress.current, progress.target))/\(progress.target)")
                            .accessibilityLabel(Text("\(min(progress.current, progress.target)) of \(progress.target)"))
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .leading)
        // A locked card shows it by its lock and gray title. Fading the whole card would take the small
        // description below the system's contrast for secondary text.
        .background(palette.controlBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityValue(isUnlocked ? Text("Unlocked") : Text("Locked"))
    }
}
