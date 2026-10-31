//
//  DailyChallenge.swift
//  sudoku
//
//  One deterministic puzzle per calendar day, generated offline from the date.
//

import Foundation

nonisolated struct DailyChallenge: Hashable, Identifiable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    var id: String { key }

    /// Gregorian calendar in the user's time zone, independent of locale settings.
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    init(date: Date) {
        let components = Self.calendar.dateComponents([.year, .month, .day], from: date)
        year = components.year!
        month = components.month!
        day = components.day!
    }

    init?(key: String) {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        year = parts[0]
        month = parts[1]
        day = parts[2]
    }

    /// The current day's challenge. Views use `AppModel.today` instead, which updates at midnight.
    static var today: DailyChallenge { DailyChallenge(date: .now) }

    /// The oldest challenge of the archive: the first day of the month two years back.
    static func archiveStart(today: DailyChallenge) -> DailyChallenge {
        let months = today.year * 12 + today.month - 1 - 24
        return DailyChallenge(key: String(format: "%04d-%02d-01", months / 12, months % 12 + 1))!
    }

    var key: String { String(format: "%04d-%02d-%02d", year, month, day) }

    var date: Date {
        Self.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    var seed: UInt64 {
        UInt64(year * 10_000 + month * 100 + day) &* 0x9E37_79B9_7F4A_7C15 ^ 0x5D0C_D1A1_1E5E_ED00
    }

    /// Difficulty ramps up during the week: easy Monday, expert weekend.
    var difficulty: Difficulty {
        switch Self.calendar.component(.weekday, from: date) {
        case 2: .easy
        case 3, 4: .medium
        case 5, 6: .hard
        default: .expert
        }
    }

    func adding(days: Int) -> DailyChallenge {
        DailyChallenge(date: Self.calendar.date(byAdding: .day, value: days, to: date)!)
    }

    func generatePuzzle() -> GeneratedPuzzle {
        var rng = SeededGenerator(seed: seed)
        return Generator.generate(difficulty, using: &rng)
    }
}

nonisolated struct DailyResult: Codable, Hashable, Sendable {
    var duration: TimeInterval
    var mistakes: Int
    var hints: Int
    var completedAt: Date
    var startedAt: Date

    /// Played on the challenge's own day (started or finished then), not caught up from the archive.
    /// Only such results keep a streak going.
    func isOnTime(for challenge: DailyChallenge) -> Bool {
        [startedAt, completedAt].contains { DailyChallenge(date: $0) == challenge }
    }
}

@Observable
final class DailyStore {
    private(set) var results: [String: DailyResult]
    /// For every day completed on time, the number of on-time days in a row ending with it. Worked out
    /// when a result comes in rather than for every look at a streak: the home card and the calendar
    /// show one, and they are redrawn after every move of a game started from them.
    private var onTimeRuns: [String: Int]
    /// Hints used on a day's challenge by attempts that didn't solve it. The next attempt starts with them,
    /// as what they showed is still known; showing the solution counts as a hint for every cell it filled.
    private var hints: [String: Int]
    private let url: URL
    private let hintsURL: URL

    init(directory: URL) {
        url = Persistence.url(for: .daily, in: directory)
        hintsURL = Persistence.url(for: .dailyHints, in: directory)
        let results = Persistence.load([String: DailyResult].self, at: url) ?? [:]
        self.results = results
        onTimeRuns = Self.onTimeRuns(in: results)
        hints = Persistence.load([String: Int].self, at: hintsURL) ?? [:]
    }

    func result(for challenge: DailyChallenge) -> DailyResult? {
        results[challenge.key]
    }

    func record(_ result: DailyResult, for challenge: DailyChallenge) {
        guard results[challenge.key] == nil else { return }
        results[challenge.key] = result
        onTimeRuns = Self.onTimeRuns(in: results)
        Persistence.save(results, at: url)
    }

    /// See `hints`.
    func hintsUsed(on challenge: DailyChallenge) -> Int {
        hints[challenge.key] ?? 0
    }

    /// Keeps the hints of an attempt that didn't solve the challenge (see `hints`). Each attempt starts with
    /// those of the ones before it, so the latest count is also the highest.
    func recordHints(_ count: Int, on challenge: DailyChallenge) {
        guard count > hintsUsed(on: challenge) else { return }
        hints[challenge.key] = count
        Persistence.save(hints, at: hintsURL)
    }

    func reset() {
        results = [:]
        onTimeRuns = [:]
        hints = [:]
        Persistence.save(results, at: url)
        Persistence.save(hints, at: hintsURL)
    }

    var completedCount: Int { results.count }

    func currentStreak(today: DailyChallenge) -> Int { Self.currentStreak(in: onTimeRuns, today: today) }

    var bestStreak: Int { onTimeRuns.values.max() ?? 0 }

    /// See `onTimeRuns`; on-time means `DailyResult.isOnTime`.
    static func onTimeRuns(in results: [String: DailyResult]) -> [String: Int] {
        let days = results.compactMap { key, result in
            DailyChallenge(key: key).flatMap { result.isOnTime(for: $0) ? $0 : nil }
        }
        var runs: [String: Int] = [:]
        var previous: (day: DailyChallenge, run: Int)?
        for day in days.sorted(by: { $0.key < $1.key }) {
            let run = previous.map { $0.day.adding(days: 1) == day ? $0.run + 1 : 1 } ?? 1
            runs[day.key] = run
            previous = (day, run)
        }
        return runs
    }

    /// Consecutive on-time days ending today (or yesterday, if today isn't done yet).
    static func currentStreak(in runs: [String: Int], today: DailyChallenge) -> Int {
        runs[today.key] ?? runs[today.adding(days: -1).key] ?? 0
    }

    static func currentStreak(in results: [String: DailyResult], today: DailyChallenge) -> Int {
        currentStreak(in: onTimeRuns(in: results), today: today)
    }

    static func bestStreak(in results: [String: DailyResult]) -> Int {
        onTimeRuns(in: results).values.max() ?? 0
    }
}
