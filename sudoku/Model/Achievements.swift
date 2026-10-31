//
//  Achievements.swift
//  sudoku
//

import Foundation

enum Achievement: String, CaseIterable, Codable, Identifiable {
    case firstWin
    case wins10
    case wins50
    case wins100
    case flawless
    case unaided
    case perfectionist
    case speedEasy
    case speedMedium
    case speedHard
    case expertWin
    case masterWin
    case allDifficulties
    case streak5
    case streak10
    case dailyFirst
    case dailyStreak7
    case daily30
    case nightOwl
    case earlyBird
    case customSolver
    case penAndPaper

    var id: String { rawValue }
}

/// Data an achievement is evaluated against.
struct AchievementContext {
    var records: [GameRecord]
    var dailyCompleted: Int
    var dailyBestStreak: Int

    /// Wins of generated puzzles (regular and daily). Achievements only count these, because a
    /// custom puzzle can have almost every clue given – except, of course, `customSolver`.
    var wins: [GameRecord] { records.filter { $0.isWin && $0.kind != .custom } }

    /// Custom puzzles don't affect streaks (see `StatisticsSummary`).
    var bestWinStreak: Int {
        StatisticsSummary(records: records).bestStreak
    }
}

extension Achievement {
    /// Progress towards the goal as (current, target), for countable achievements.
    func progress(in context: AchievementContext) -> (current: Int, target: Int)? {
        switch self {
        case .wins10: (context.wins.count, 10)
        case .wins50: (context.wins.count, 50)
        case .wins100: (context.wins.count, 100)
        case .allDifficulties: (Set(context.wins.compactMap(\.difficulty)).count, Difficulty.allCases.count)
        case .streak5: (context.bestWinStreak, 5)
        case .streak10: (context.bestWinStreak, 10)
        case .dailyStreak7: (context.dailyBestStreak, 7)
        case .daily30: (context.dailyCompleted, 30)
        default: nil
        }
    }

    func isEarned(in context: AchievementContext) -> Bool {
        if let progress = progress(in: context) {
            return progress.current >= progress.target
        }
        let wins = context.wins
        let calendar = Calendar.current
        switch self {
        case .firstWin:
            return !wins.isEmpty
        case .flawless:
            return wins.contains { $0.mistakes == 0 }
        case .unaided:
            return wins.contains(where: \.isUnaidedWin)
        case .perfectionist:
            return wins.contains { $0.isPerfect && $0.difficulty.map { $0 >= .expert } == true }
        // Like best times, only wins without hints count: hints and revealed cells make any time fast.
        case .speedEasy:
            return wins.contains { $0.isUnaidedWin && $0.difficulty == .easy && $0.duration < 3 * 60 }
        case .speedMedium:
            return wins.contains { $0.isUnaidedWin && $0.difficulty == .medium && $0.duration < 6 * 60 }
        case .speedHard:
            return wins.contains { $0.isUnaidedWin && $0.difficulty == .hard && $0.duration < 12 * 60 }
        case .expertWin:
            return wins.contains { $0.difficulty == .expert }
        case .masterWin:
            return wins.contains { $0.difficulty == .master }
        case .dailyFirst:
            return context.dailyCompleted > 0
        case .nightOwl:
            return wins.contains { (0..<4).contains(calendar.component(.hour, from: $0.date)) }
        case .earlyBird:
            return wins.contains { (5..<7).contains(calendar.component(.hour, from: $0.date)) }
        case .customSolver:
            return context.records.contains { $0.isWin && $0.kind == .custom }
        case .penAndPaper:
            return wins.contains { !$0.usedAutoNotes && $0.hints == 0 && $0.difficulty.map { $0 >= .hard } == true }
        default:
            return false
        }
    }
}

@Observable
final class AchievementStore {
    private(set) var unlocked: [String: Date]
    private let url: URL

    init(directory: URL) {
        url = Persistence.url(for: .achievements, in: directory)
        unlocked = Persistence.load([String: Date].self, at: url) ?? [:]
    }

    func unlockDate(_ achievement: Achievement) -> Date? {
        unlocked[achievement.rawValue]
    }

    var unlockedCount: Int { Achievement.allCases.count { unlocked[$0.rawValue] != nil } }

    /// Unlocks every newly earned achievement and returns them.
    @discardableResult
    func evaluate(_ context: AchievementContext) -> [Achievement] {
        let fresh = Achievement.allCases.filter { unlocked[$0.rawValue] == nil && $0.isEarned(in: context) }
        guard !fresh.isEmpty else { return [] }
        for achievement in fresh {
            unlocked[achievement.rawValue] = .now
        }
        Persistence.save(unlocked, at: url)
        return fresh
    }

    func reset() {
        unlocked = [:]
        Persistence.save(unlocked, at: url)
    }
}
