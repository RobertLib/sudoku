//
//  AppModelTests.swift
//  sudokuTests
//
//  Recording results exactly once and keeping games across launches.
//  Every test gets its own data directory; a "relaunch" is a new model on it.
//

import Foundation
import SwiftUI
import Testing
@testable import sudoku

final class AppModelTests {
    private let directory: URL
    private let cacheDirectory: URL
    private let defaults: UserDefaults

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "AppModelTests-\(UUID().uuidString)")
        cacheDirectory = directory.appending(path: "Cache")
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let suite = "cz.rob.sudokuTests.appModel"
        UserDefaults().removePersistentDomain(forName: suite)
        defaults = UserDefaults(suiteName: suite)!
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func launch() -> AppModel {
        let model = AppModel(directory: directory, cacheDirectory: cacheDirectory, defaults: defaults, fillsPuzzleCache: false)
        model.settings.soundEnabled = false
        model.settings.hapticsEnabled = false
        return model
    }

    private func start(_ puzzle: (givens: [UInt8], solution: [UInt8]), in model: AppModel) async throws -> GameSession {
        await model.request(.custom(givens: puzzle.givens, solution: puzzle.solution, difficulty: .easy))?.value
        return try #require(model.session)
    }

    @Test func aWinIsRecordedOnce() async throws {
        let model = launch()
        let puzzle = Fixtures.nearlySolved(empty: [0])
        let session = try await start(puzzle, in: model)
        session.select(0)
        session.enter(Int(puzzle.solution[0]))
        #expect(session.status == .won)
        #expect(session.completion != nil)

        // Leaving the finished game, as the Home button does.
        model.goHome()
        model.leaveGame(session)
        model.saveCurrentSession()
        #expect(model.stats.records.map(\.outcome) == [.won])
        #expect(model.savedGames.isEmpty)
        #expect(launch().stats.records.map(\.outcome) == [.won])
    }

    @Test func aLossIsRecordedOnceEvenIfTheAppIsKilled() async throws {
        let model = launch()
        let session = try await start(Fixtures.nearlySolved(empty: [0, 1, 2, 3]), in: model)
        for cell in 0..<3 { session.placeWrongDigit(at: cell) }
        #expect(session.status == .lost)
        session.secondChance()
        session.placeWrongDigit(at: 3)
        #expect(session.status == .lost)
        model.saveCurrentSession()

        // Killed on the game over screen, with the second chance used: the next launch records the
        // loss and forgets the game.
        let relaunched = launch()
        #expect(relaunched.stats.records.map(\.outcome) == [.lost])
        #expect(relaunched.savedGames.isEmpty)
        #expect(launch().stats.records.count == 1)
    }

    @Test func aSecondChanceOutlivesTheApp() async throws {
        let model = launch()
        let session = try await start(Fixtures.nearlySolved(empty: [0, 1, 2, 3]), in: model)
        for cell in 0..<3 { session.placeWrongDigit(at: cell) }
        #expect(session.status == .lost)
        model.saveCurrentSession()
        #expect(model.stats.records.isEmpty, "the second chance is still open")

        // Killed on the game over screen: the game waits, second chance and all.
        let relaunched = launch()
        #expect(relaunched.stats.records.isEmpty)
        let saved = try #require(relaunched.savedStandardGame)
        #expect(saved.id == session.state.id)
        relaunched.continueSavedGame()
        let resumed = try #require(relaunched.session)
        #expect(resumed.canUseSecondChance)
        resumed.secondChance()
        #expect(resumed.status == .inProgress)

        // Left instead, the loss counts once.
        let declined = launch()
        declined.continueSavedGame()
        let lost = try #require(declined.session)
        #expect(lost.status == .lost)
        declined.goHome()
        declined.leaveGame(lost)
        #expect(declined.stats.records.map(\.outcome) == [.lost])
        #expect(declined.savedStandardGame == nil)
        #expect(launch().stats.records.count == 1)
    }

    @Test func aGivenUpGameIsRecordedOnRelaunch() async throws {
        let model = launch()
        let session = try await start(Fixtures.nearlySolved(empty: [0, 1, 2, 3]), in: model)
        session.placeWrongDigit(at: 0)
        session.giveUp()
        #expect(!session.canUseSecondChance)
        model.saveCurrentSession()

        let relaunched = launch()
        #expect(relaunched.stats.records.map(\.outcome) == [.lost])
        #expect(relaunched.savedGames.isEmpty)
    }

    /// A daily challenge can be played again after its solution was shown, but not as a game without hints:
    /// the next attempt starts with a hint for every cell the solution filled, even after a relaunch.
    @Test func aDailyChallengePlayedAgainKeepsItsHints() async throws {
        let model = launch()
        let challenge = try #require(DailyChallenge(key: "2026-11-02"))
        model.path = [.daily]
        await model.request(.daily(challenge))?.value
        let givenUp = try #require(model.session)
        let revealed = givenUp.emptyCells().count
        givenUp.giveUp()
        #expect(givenUp.state.hintsUsed == revealed)
        model.closeGame()
        model.leaveGame(givenUp)

        let relaunched = launch()
        relaunched.path = [.daily]
        await relaunched.request(.daily(challenge))?.value
        let replay = try #require(relaunched.session)
        #expect(replay.state.hintsUsed == revealed)
        for cell in replay.emptyCells() {
            replay.select(cell)
            replay.enter(Int(replay.state.solution[cell]))
        }
        #expect(replay.status == .won)
        #expect(relaunched.daily.result(for: challenge)?.hints == revealed, "the day is done, with hints")
        #expect(relaunched.stats.records.map(\.outcome) == [.lost, .won])
        #expect(relaunched.stats.records.last?.isUnaidedWin == false)

        // Resetting the data forgets them too.
        relaunched.resetAllData()
        #expect(launch().daily.hintsUsed(on: challenge) == 0)
    }

    @Test func aLossIsntRecordedAgainIfItsSavedGameOutlivesIt() async throws {
        let model = launch()
        let session = try await start(Fixtures.nearlySolved(empty: [0, 1, 2, 3]), in: model)
        for cell in 0..<3 { session.placeWrongDigit(at: cell) }
        model.saveCurrentSession()
        let file = directory.appending(path: "Games/\(session.state.id.uuidString).json")
        let saved = try Data(contentsOf: file)

        model.goHome()
        model.leaveGame(session)
        #expect(model.stats.records.map(\.outcome) == [.lost])
        // As if the app was killed after recording the loss but before deleting the game.
        try saved.write(to: file)

        let relaunched = launch()
        #expect(relaunched.stats.records.count == 1)
        #expect(relaunched.savedGames.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func aSecondRequestWhileAGameIsBeingPreparedIsIgnored() async throws {
        let model = launch()
        let challenge = try #require(DailyChallenge(key: "2026-11-02"))
        let first = model.request(.daily(challenge))
        #expect(model.request(.daily(challenge)) == nil, "e.g. a double tap")
        await first?.value
        #expect(model.savedGames.count == 1)
        #expect(!model.isPreparingGame)
    }

    @Test func aGameShownWhileTheAppWasInactiveStartsItsTimerOnceActive() async throws {
        let model = launch()
        let session = try await start(Fixtures.nearlySolved(empty: [0, 1]), in: model)
        #expect(!session.isTimerRunning, "like a game screen that appeared during launch")
        model.scenePhaseChanged(to: .active)
        #expect(session.isTimerRunning)

        // A game paused when the app went away stays paused.
        model.scenePhaseChanged(to: .background)
        model.scenePhaseChanged(to: .active)
        #expect(session.isPaused)
        #expect(!session.isTimerRunning)
    }

    /// "Show Solution" may be answered after the app paused the game behind its dialog.
    @Test func showingTheSolutionEndsAPause() async throws {
        let model = launch()
        let session = try await start(Fixtures.nearlySolved(empty: [0, 1]), in: model)
        model.scenePhaseChanged(to: .active)
        model.scenePhaseChanged(to: .background)
        model.scenePhaseChanged(to: .active)
        #expect(session.isPaused)
        session.giveUp()
        #expect(!session.isPaused, "the pause card would cover the solution")
        #expect(session.status == .lost)
    }

    /// The game over card's New Game is the answer already, as it is for a custom puzzle.
    @Test func aNewGameFromTheGameOverCardIsntAskedAbout() async throws {
        let model = launch()
        await model.request(.new(.easy))?.value
        let lost = try #require(model.session)
        for cell in lost.emptyCells().prefix(3) { lost.placeWrongDigit(at: cell) }
        #expect(lost.canUseSecondChance)
        model.saveCurrentSession()

        model.playAgain()
        #expect(model.pendingRequest == nil)
        while model.isPreparingGame { try await Task.sleep(for: .milliseconds(10)) }
        #expect(model.stats.records.map(\.outcome) == [.lost])
        let next = try #require(model.session)
        #expect(next !== lost)
        #expect(model.savedGames.map(\.id) == [next.state.id])
    }

    @Test func aFinishedDailyChallengeLeadsBackToTheCalendar() async throws {
        let model = launch()
        model.path = [.daily]
        await model.request(.daily(try #require(DailyChallenge(key: "2026-11-02"))))?.value
        let session = try #require(model.session)
        #expect(model.path == [.daily, .game])
        session.giveUp()

        model.playAgain()
        #expect(model.session === session, "a daily challenge has no next one")
        #expect(!model.isPreparingGame)
        model.closeGame()
        #expect(model.path == [.daily])
    }

    @Test func startingAnotherGameAbandonsThePlayedOne() async throws {
        let model = launch()
        let first = Fixtures.nearlySolved(empty: [0, 1])
        let session = try await start(first, in: model)
        session.select(0)
        session.enter(Int(first.solution[0]))
        model.saveCurrentSession()

        let second = Fixtures.nearlySolved(empty: [5, 6])
        #expect(model.request(.custom(givens: second.givens, solution: second.solution, difficulty: .easy)) == nil)
        #expect(model.pendingRequest != nil, "the player is asked first")
        await model.confirmPendingRequest()?.value
        #expect(model.stats.records.map(\.outcome) == [.abandoned])
        #expect(model.session?.state.givens == second.givens)
        #expect(model.savedGames.map(\.givens) == [second.givens])
        #expect(launch().savedGames.map(\.givens) == [second.givens])
    }

    @Test func restartingCountsTheAbandonedAttempt() async throws {
        let model = launch()
        let puzzle = Fixtures.nearlySolved(empty: [0, 1])
        let session = try await start(puzzle, in: model)
        session.select(0)
        session.enter(Int(puzzle.solution[0]))
        let firstAttempt = session.state.id
        let startedAt = session.state.createdAt

        model.restart(session)
        #expect(model.stats.records.map(\.outcome) == [.abandoned])
        #expect(session.state.id != firstAttempt)
        #expect(session.state.values == puzzle.givens)
        // A daily challenge started on its day and restarted later still counts as played on time.
        #expect(session.state.createdAt == startedAt)
        #expect(model.savedGames.map(\.id) == [session.state.id])
        #expect(launch().savedGames.map(\.id) == [session.state.id])
    }

    /// A daily challenge lost on the mistake limit waits for its second chance while other games are
    /// played. Declined later, the loss still goes before them, so it can't break a newer streak.
    @Test func aLossIsDatedWhenItHappened() async throws {
        let puzzle = Fixtures.nearlySolved(empty: [0, 1, 2, 3])
        let today = DailyChallenge.today
        var daily = GameState(kind: .daily(today.key), difficulty: .easy, givens: puzzle.givens, solution: puzzle.solution)
        daily.status = .lost
        let lostAt = Date.now.addingTimeInterval(-3_600)
        daily.endedAt = lostAt
        var files = GameFiles(root: directory)
        _ = files.load() // Creates the folder.
        files.save([daily])

        let model = launch()
        #expect(model.stats.records.isEmpty, "the second chance is still open")
        // A regular game: a custom one wouldn't count towards the streak.
        await model.request(.new(.easy))?.value
        let session = try #require(model.session)
        for cell in session.emptyCells() {
            session.select(cell)
            session.enter(Int(session.state.solution[cell]))
        }
        #expect(model.stats.records.map(\.outcome) == [.won])

        model.request(.daily(today))
        let lost = try #require(model.session)
        #expect(lost.state.id == daily.id)
        model.goHome()
        model.leaveGame(lost)
        #expect(model.stats.records.map(\.outcome) == [.lost, .won])
        let recorded = try #require(model.stats.records.first)
        #expect(abs(recorded.date.timeIntervalSince(lostAt)) < 0.001)
        #expect(StatisticsSummary(records: model.stats.records).currentStreak == 1)
    }
}

struct GameFilesTests {
    @Test func onlyChangedGamesAreWritten() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "GameFilesTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let puzzle = Fixtures.nearlySolved(empty: [0])
        var first = GameState(kind: .standard, difficulty: .easy, givens: puzzle.givens, solution: puzzle.solution)
        let second = GameState(kind: .daily("2026-10-31"), difficulty: .easy, givens: puzzle.givens, solution: puzzle.solution)

        var files = GameFiles(root: root)
        #expect(files.load().isEmpty)
        files.save([first, second])
        let firstURL = files.directory.appending(path: "\(first.id.uuidString).json")
        let secondURL = files.directory.appending(path: "\(second.id.uuidString).json")
        #expect(FileManager.default.fileExists(atPath: secondURL.path))

        // Saving again must not touch the unchanged game: its deleted file stays deleted.
        try FileManager.default.removeItem(at: secondURL)
        first.elapsed = 42
        files.save([first, second])
        #expect(Persistence.load(GameState.self, at: firstURL)?.elapsed == 42)
        #expect(!FileManager.default.fileExists(atPath: secondURL.path))

        files.save([])
        #expect(!FileManager.default.fileExists(atPath: firstURL.path))
        var reloaded = GameFiles(root: root)
        #expect(reloaded.load().isEmpty)
    }

    @Test func aFileThatCouldntBeDeletedIsDeletedLater() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "GameFilesTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let puzzle = Fixtures.nearlySolved(empty: [0])
        let game = GameState(kind: .standard, difficulty: .easy, givens: puzzle.givens, solution: puzzle.solution)
        var files = GameFiles(root: root)
        _ = files.load()
        files.save([game])
        let url = files.directory.appending(path: "\(game.id.uuidString).json")

        // A read-only folder makes the deletion fail.
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: files.directory.path)
        files.save([])
        #expect(FileManager.default.fileExists(atPath: url.path))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: files.directory.path)
        files.save([])
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }
}
