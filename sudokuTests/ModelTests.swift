//
//  ModelTests.swift
//  sudokuTests
//

import Foundation
import Testing
@testable import sudoku

struct AchievementTests {
    private func context(_ kind: GameKind, _ difficulty: Difficulty?, duration: TimeInterval = 60, hints: Int = 0) -> AchievementContext {
        let record = GameRecord(
            date: .now, kind: kind, difficulty: difficulty, outcome: .won,
            duration: duration, mistakes: 0, hints: hints, usedAutoNotes: false, gameID: UUID()
        )
        return AchievementContext(records: [record], dailyCompleted: 0, dailyBestStreak: 0)
    }

    @Test func customPuzzlesOnlyCountForTheirOwnAchievement() {
        // A custom puzzle can have almost every clue given, so it would make any achievement trivial.
        let custom = context(.custom, .easy)
        #expect(Achievement.allCases.filter { $0.isEarned(in: custom) } == [.customSolver])
        #expect(Achievement.firstWin.isEarned(in: context(.standard, .easy)))
        #expect(Achievement.speedEasy.isEarned(in: context(.standard, .easy)))
        #expect(Achievement.speedEasy.isEarned(in: context(.daily("2026-11-02"), .easy)))

        let customExpert = context(.custom, .expert, duration: 3_600)
        for achievement: Achievement in [.expertWin, .perfectionist, .penAndPaper] {
            #expect(!achievement.isEarned(in: customExpert), "\(achievement)")
            #expect(achievement.isEarned(in: context(.standard, .expert, duration: 3_600)), "\(achievement)")
        }
    }

    @Test func speedNeedsAGameWithoutHints() {
        // Hints and revealed cells (which count as hints) would make any time fast.
        #expect(!Achievement.speedEasy.isEarned(in: context(.standard, .easy, hints: 1)))
        #expect(Achievement.firstWin.isEarned(in: context(.standard, .easy, hints: 1)))
    }
}

struct StatisticsTests {
    private func record(at second: Double, _ kind: GameKind = .standard, _ outcome: Outcome = .won, duration: TimeInterval = 300, hints: Int = 0) -> GameRecord {
        GameRecord(
            date: Date(timeIntervalSince1970: second), kind: kind, difficulty: .easy, outcome: outcome,
            duration: duration, mistakes: 0, hints: hints, usedAutoNotes: false, gameID: UUID()
        )
    }

    @Test func bestTimesOnlyComeFromGeneratedPuzzlesSolvedWithoutHints() {
        let summary = StatisticsSummary(records: [
            record(at: 0, duration: 400),
            record(at: 1, duration: 100, hints: 1),
            record(at: 2, .custom, duration: 50),
        ])
        #expect(summary.bestTime == 400)
        #expect(summary.won == 3)
    }

    @Test func averageTimesComeFromTheSameGamesAsBestTimes() {
        let summary = StatisticsSummary(records: [
            record(at: 0, duration: 1_500),
            record(at: 1, duration: 480, hints: 1),
            record(at: 2, duration: 480, hints: 1),
            record(at: 3, .custom, duration: 60),
        ])
        #expect(summary.bestTime == 1_500)
        #expect(summary.averageTime == 1_500, "games with hints and custom puzzles would take it below the best")
        #expect(StatisticsSummary(records: [record(at: 0, duration: 100, hints: 1)]).averageTime == nil)
    }

    @Test func theWinRateIsntRoundedToAllOrNothing() {
        func summary(won: Int, played: Int) -> StatisticsSummary {
            StatisticsSummary(records: (0..<played).map { record(at: Double($0), .standard, $0 < won ? .won : .lost) })
        }
        #expect(summary(won: 199, played: 200).displayedWinRate == 0.99)
        #expect(summary(won: 1, played: 300).displayedWinRate == 0.01)
        #expect(summary(won: 1, played: 2).displayedWinRate == 0.5)
        #expect(summary(won: 3, played: 3).displayedWinRate == 1)
        #expect(summary(won: 0, played: 3).displayedWinRate == 0)
        #expect(0.99.formatted(.percent.precision(.fractionLength(0)).locale(Locale(identifier: "en_US"))) == "99%")
    }

    @Test func customPuzzlesDontAffectStreaks() {
        let summary = StatisticsSummary(records: [
            record(at: 0), record(at: 1, .custom, .lost), record(at: 2), record(at: 3, .custom),
        ])
        #expect(summary.currentStreak == 2)
        #expect(summary.bestStreak == 2)
        let context = AchievementContext(records: [record(at: 0, .custom), record(at: 1, .custom)], dailyCompleted: 0, dailyBestStreak: 0)
        #expect(context.bestWinStreak == 0)
    }
}

struct LocaleTests {
    /// The UI language replaces the device's, but its region (date order, 12- or 24-hour clock) stays.
    @Test func theRegionSurvivesTheLanguage() throws {
        let date = try #require(DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 10, day: 31, hour: 15, minute: 45).date)
        let style = Date.FormatStyle.dateTime.day().month().hour().minute()
        let british = AppLocale.locale(language: "en", basedOn: Locale(identifier: "en_GB"))
        #expect(british.region == .unitedKingdom)
        #expect(date.formatted(style.locale(british)) == date.formatted(style.locale(Locale(identifier: "en_GB"))))

        let englishInCzechia = AppLocale.locale(language: "en", basedOn: Locale(identifier: "cs_CZ"))
        #expect(englishInCzechia.language.languageCode == .english)
        #expect(englishInCzechia.region == Locale.Region("CZ"))
    }

    /// The daily grid and keys are Gregorian, so their dates are too, whatever calendar the player uses.
    @Test func dailyDatesAreGregorianInAnyCalendar() throws {
        let date = try #require(DailyChallenge(key: "2026-10-31")).date
        var hebrew = Date.FormatStyle.dateTime.month(.wide).year()
        hebrew.calendar = Calendar(identifier: .hebrew)
        #expect(date.formatted(hebrew).contains("5787"))
        #expect(date.formatted(hebrew.dailyCalendar()).contains("2026"))
    }
}

struct DailyStreakTests {
    private let today = DailyChallenge(key: "2026-10-31")!

    private func result(completed: DailyChallenge, started: DailyChallenge) -> DailyResult {
        DailyResult(duration: 300, mistakes: 0, hints: 0, completedAt: completed.date, startedAt: started.date)
    }

    @Test func onlyChallengesPlayedOnTheirDayKeepAStreak() {
        var results: [String: DailyResult] = [:]
        for offset in 0...2 {
            let day = today.adding(days: -offset)
            results[day.key] = result(completed: day, started: day)
        }
        #expect(DailyStore.currentStreak(in: results, today: today) == 3)

        // Catching up four older days from the archive today doesn't extend the streak.
        for offset in 3...6 {
            results[today.adding(days: -offset).key] = result(completed: today, started: today)
        }
        #expect(DailyStore.currentStreak(in: results, today: today) == 3)
        #expect(DailyStore.bestStreak(in: results) == 3)
    }

    @Test func onTimeRules() {
        let yesterday = today.adding(days: -1)
        // Started before midnight, finished after it.
        #expect(result(completed: today, started: yesterday).isOnTime(for: yesterday))
        #expect(!result(completed: today, started: today).isOnTime(for: yesterday))
    }

    @Test func archiveReachesTwoYearsBack() {
        #expect(DailyChallenge.archiveStart(today: today).key == "2024-10-01")
        #expect(DailyChallenge.archiveStart(today: DailyChallenge(key: "2026-01-15")!).key == "2024-01-01")

        // The calendar lets the player page back exactly to that month.
        var page = MonthPage(containing: today)
        var months = 0
        while page.hasPrevious(today: today) {
            page = page.previous
            months += 1
        }
        #expect(months == 24)
        #expect(page == MonthPage(containing: DailyChallenge.archiveStart(today: today)))
    }

    @Test func currentStreakMayEndYesterday() {
        let yesterday = today.adding(days: -1)
        let results = [yesterday.key: result(completed: yesterday, started: yesterday)]
        #expect(DailyStore.currentStreak(in: results, today: today) == 1)
        #expect(DailyStore.currentStreak(in: results, today: today.adding(days: 1)) == 0)
    }

    /// The store works the streaks out once per result; they must still follow every new one.
    @Test func theStoreKeepsItsStreaksUpToDate() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "DailyStreakTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DailyStore(directory: directory)
        for offset in [4, 3, 1, 0] {
            let day = today.adding(days: -offset)
            store.record(result(completed: day, started: day), for: day)
        }
        #expect(store.currentStreak(today: today) == 2)
        #expect(store.bestStreak == 2)

        // The missing day, caught up from the archive two days late, doesn't join the runs.
        let missing = today.adding(days: -2)
        store.record(result(completed: today, started: today), for: missing)
        #expect(store.currentStreak(today: today) == 2)

        let reloaded = DailyStore(directory: directory)
        #expect(reloaded.currentStreak(today: today) == 2)
        #expect(reloaded.bestStreak == 2)
        #expect(reloaded.currentStreak(today: today.adding(days: 2)) == 0)

        store.reset()
        #expect(store.currentStreak(today: today) == 0)
        #expect(store.bestStreak == 0)
    }
}

struct DailyPuzzleTests {
    /// Daily puzzles must be identical on every device and in every app version. If a change to
    /// the engine alters them on purpose, update these strings – every player then gets new puzzles.
    @Test(arguments: [
        ("2026-11-02", Difficulty.easy, ".1.783...7.89...3.3.6...897..5..1.24.3.....6.87.6..3..962...5.3.8...41.6...365.8."),
        ("2026-11-03", .medium, "19.6...4..24..38.6..31.....8....47.1.........4.93....8.....61..9.74..68..6...1.54"),
        ("2026-11-05", .hard, "4..2...9..31...5......67..41..9...5.5.4...9.6.8...5..23..72......7...28..4...1..5"),
        ("2026-11-07", .expert, "..7..4.....1..9.735..37...18.....649.9.....3.374.....57...81..612.7..3.....4..8.."),
    ])
    func dailyPuzzlesStayTheSame(key: String, difficulty: Difficulty, puzzle: String) throws {
        let challenge = try #require(DailyChallenge(key: key))
        #expect(challenge.difficulty == difficulty)
        let generated = challenge.generatePuzzle()
        #expect(PuzzleParser.string(from: generated.puzzle) == puzzle)
        #expect(generated.rating.level == difficulty.maxLevel)
    }
}

struct PersistenceTests {
    @Test func unreadableFileIsKeptAside() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "PersistenceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "records.json")

        Persistence.save([1, 2, 3], at: url)
        #expect(Persistence.load([Int].self, at: url) == [1, 2, 3])

        let garbage = Data("not json".utf8)
        try garbage.write(to: url)
        #expect(Persistence.load([Int].self, at: url) == nil)
        #expect(!FileManager.default.fileExists(atPath: url.path), "the next save must not overwrite the data")
        let kept = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        #expect(kept.count == 1)
        #expect(kept.first?.lastPathComponent.hasPrefix("records.unreadable-") == true)
        #expect(try kept.first.map { try Data(contentsOf: $0) } == garbage)
    }

    @Test func unreadableCacheIsDeleted() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "PersistenceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = Persistence.url(for: .puzzleCache, in: directory)
        try Data("not json".utf8).write(to: url)

        _ = PuzzleStore(directory: directory)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty, "a cache can simply be made again")
    }
}
