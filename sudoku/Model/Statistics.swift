//
//  Statistics.swift
//  sudoku
//

import Foundation

nonisolated enum Outcome: String, Codable, Sendable {
    case won, lost, abandoned
}

/// A finished (or abandoned) game, kept for statistics and achievements.
nonisolated struct GameRecord: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var date: Date
    var kind: GameKind
    var difficulty: Difficulty?
    var outcome: Outcome
    var duration: TimeInterval
    var mistakes: Int
    var hints: Int
    var usedAutoNotes: Bool
    /// The recorded game, so it is never recorded twice.
    var gameID: UUID

    var isWin: Bool { outcome == .won }
    var isPerfect: Bool { isWin && mistakes == 0 && hints == 0 }
    /// Solved without hints. Only such wins set best times: hints and revealed cells make any time fast.
    var isUnaidedWin: Bool { isWin && hints == 0 }
    /// Counts towards best and average times and the chart of them. Not a custom puzzle, which can have
    /// almost every clue given.
    var isTimedWin: Bool { isUnaidedWin && kind != .custom }
}

/// Aggregated numbers for one difficulty (or all games).
struct StatisticsSummary {
    var played = 0
    var won = 0
    var perfect = 0
    var bestTime: TimeInterval?
    var averageTime: TimeInterval?
    var currentStreak = 0
    var bestStreak = 0
    var totalTime: TimeInterval = 0

    var winRate: Double { played == 0 ? 0 : Double(won) / Double(played) }

    /// `winRate` for showing as a whole percentage: never rounded up to 100 % while a game wasn't
    /// won, nor down to 0 % once one was.
    var displayedWinRate: Double {
        guard won > 0, won < played else { return winRate }
        return min(max(winRate, 0.01), 0.99)
    }

    init(records: [GameRecord]) {
        let sorted = records.sorted { $0.date < $1.date }
        let wins = sorted.filter(\.isWin)
        played = sorted.count
        won = wins.count
        perfect = wins.count(where: \.isPerfect)
        // A custom puzzle can have almost every clue given, so it sets no time (see `isTimedWin`) and
        // neither extends nor breaks a streak. Both times come from the same games, so the average
        // can't come out below the best.
        let generated = sorted.filter { $0.kind != .custom }
        let timed = sorted.filter(\.isTimedWin).map(\.duration)
        bestTime = timed.min()
        averageTime = timed.isEmpty ? nil : timed.reduce(0, +) / Double(timed.count)
        totalTime = sorted.map(\.duration).reduce(0, +)
        var streak = 0
        for record in generated {
            if record.isWin {
                streak += 1
                bestStreak = max(bestStreak, streak)
            } else {
                streak = 0
            }
        }
        currentStreak = streak
    }
}

@Observable
final class StatsStore {
    private(set) var records: [GameRecord]
    private let url: URL

    init(directory: URL) {
        url = Persistence.url(for: .records, in: directory)
        records = Persistence.load([GameRecord].self, at: url) ?? []
    }

    /// Keeps the records in date order: a loss is dated when it happened, which may be well before
    /// it is recorded (see `GameState.endedAt`).
    func add(_ record: GameRecord) {
        records.insert(record, at: records.firstIndex { $0.date > record.date } ?? records.endIndex)
        Persistence.save(records, at: url)
    }

    func reset() {
        records = []
        Persistence.save(records, at: url)
    }

    /// Records counting towards difficulty statistics (custom puzzles only count towards "all").
    func records(for difficulty: Difficulty?) -> [GameRecord] {
        guard let difficulty else { return records }
        return records.filter { $0.difficulty == difficulty && $0.kind != .custom }
    }

    func summary(for difficulty: Difficulty?) -> StatisticsSummary {
        StatisticsSummary(records: records(for: difficulty))
    }

    func bestTime(for difficulty: Difficulty) -> TimeInterval? {
        records(for: difficulty).filter(\.isTimedWin).map(\.duration).min()
    }

    func hasRecord(ofGame id: UUID) -> Bool {
        records.contains { $0.gameID == id }
    }
}
