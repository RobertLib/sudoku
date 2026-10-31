//
//  AppModel.swift
//  sudoku
//
//  App-wide state: navigation, saved games, and recording finished games.
//

import SwiftUI

enum Route: Hashable {
    case game
    case daily
    case statistics
    case achievements
    case help
    case customPuzzle
}

enum GameRequest: Equatable {
    case new(Difficulty)
    case daily(DailyChallenge)
    case custom(givens: [UInt8], solution: [UInt8], difficulty: Difficulty?)
}

@Observable
final class AppModel {
    let settings: AppSettings
    let stats: StatsStore
    let achievements: AchievementStore
    let daily: DailyStore
    let puzzles: PuzzleStore

    var path: [Route] = []
    var showSettings = false
    var showWelcome = false
    /// A start request waiting for the player to confirm discarding their current game.
    var pendingRequest: GameRequest?
    private(set) var isPreparingGame = false
    private(set) var session: GameSession?
    /// Unfinished games: at most one regular/custom game plus any started daily challenges. A lost game
    /// stays while its second chance is open (see `GameState.awaitsSecondChance`), and one whose loss
    /// still has to be recorded until it is.
    private(set) var savedGames: [GameState]
    /// The current day's challenge, kept up to date across midnight (see `refreshToday`).
    private(set) var today = DailyChallenge.today

    @ObservationIgnored private var gameFiles: GameFiles
    private var saveTask: Task<Void, Never>?
    /// Games whose result has been recorded, so nothing is counted twice.
    private var concludedGames: Set<UUID> = []

    /// - Parameters:
    ///   - directory: Where games, statistics and other data are stored.
    ///   - cacheDirectory: Where pre-generated puzzles are kept.
    ///   - defaults: Where settings are stored.
    ///   - fillsPuzzleCache: Whether to pre-generate puzzles in the background, at launch and after each new game.
    init(
        directory: URL = Persistence.directory,
        cacheDirectory: URL = Persistence.cacheDirectory,
        defaults: UserDefaults = .standard,
        fillsPuzzleCache: Bool = true
    ) {
        settings = AppSettings(defaults: defaults)
        stats = StatsStore(directory: directory)
        achievements = AchievementStore(directory: directory)
        daily = DailyStore(directory: directory)
        puzzles = PuzzleStore(directory: cacheDirectory, fillsCache: fillsPuzzleCache)
        gameFiles = GameFiles(root: directory)
        savedGames = gameFiles.load()
        showWelcome = !settings.hasSeenWelcome
        // A game lost on the mistake limit waits for the player to take the second chance or leave, even
        // if the app was closed on its game over screen. Any other loss is recorded now.
        for state in savedGames where state.status == .lost && (!state.awaitsSecondChance || stats.hasRecord(ofGame: state.id)) {
            concludeLostGame(state)
        }
        savedGames.removeAll { $0.status == .won }
        discardExpiredDailies()
        puzzles.refill()
    }

    /// Picks up a new day, e.g. after midnight or when the app returns from the background.
    func refreshToday() {
        let current = DailyChallenge.today
        if today != current { today = current }
    }

    // MARK: - Saved games

    var savedStandardGame: GameState? {
        savedGames.first { $0.kind.dailyKey == nil && $0.isResumable }
    }

    func savedGame(for challenge: DailyChallenge) -> GameState? {
        savedGames.first { $0.kind == .daily(challenge.key) && $0.isResumable }
    }

    private func persistGames() {
        gameFiles.save(savedGames)
    }

    /// Forgets unfinished daily challenges that have left the archive and can't be opened any more.
    private func discardExpiredDailies() {
        let start = DailyChallenge.archiveStart(today: today).key
        let isExpired = { (state: GameState) in state.kind.dailyKey.map { $0 < start } ?? false }
        // A loss whose second chance can no longer be taken still counts.
        for state in savedGames where isExpired(state) && state.status == .lost {
            concludeLostGame(state)
        }
        let count = savedGames.count
        savedGames.removeAll(where: isExpired)
        if savedGames.count != count {
            persistGames()
        }
    }

    // MARK: - Starting games

    /// Starts or resumes a game, asking first if an unfinished game would be discarded.
    /// Returns the task preparing a new game, if one was started.
    @discardableResult
    func request(_ request: GameRequest) -> Task<Void, Never>? {
        guard !isPreparingGame else { return nil }
        switch request {
        case .daily(let challenge):
            if let saved = savedGame(for: challenge) {
                open(saved)
                return nil
            }
        case .new, .custom:
            if let saved = savedStandardGame, saved.hasProgress {
                pendingRequest = request
                return nil
            }
        }
        return beginStart(request)
    }

    @discardableResult
    func confirmPendingRequest() -> Task<Void, Never>? {
        guard !isPreparingGame, let request = pendingRequest else { return nil }
        pendingRequest = nil
        return beginStart(request)
    }

    func continueSavedGame() {
        if let saved = savedStandardGame {
            open(saved)
        }
    }

    /// Marks the model busy right away rather than once the task runs, so another request in the
    /// meantime (e.g. a double tap) can't start a second game.
    private func beginStart(_ request: GameRequest) -> Task<Void, Never> {
        isPreparingGame = true
        return Task {
            await start(request)
            isPreparingGame = false
        }
    }

    private func start(_ request: GameRequest) async {
        var state: GameState
        switch request {
        case .new(let difficulty):
            let puzzle = await puzzles.puzzle(for: difficulty)
            state = GameState(kind: .standard, difficulty: difficulty, givens: puzzle.puzzle, solution: puzzle.solution)
        case .daily(let challenge):
            let puzzle = await puzzles.puzzle(for: challenge)
            state = GameState(kind: .daily(challenge.key), difficulty: challenge.difficulty, givens: puzzle.puzzle, solution: puzzle.solution)
            // An earlier attempt's hints (or its shown solution) are still known (see `DailyStore.hints`).
            state.hintsUsed = daily.hintsUsed(on: challenge)
        case .custom(let givens, let solution, let difficulty):
            state = GameState(kind: .custom, difficulty: difficulty, givens: givens, solution: solution)
        }

        if state.kind.dailyKey == nil {
            discardStandardGame()
        }
        savedGames.append(state)
        persistGames()
        open(state, replacingRoute: request.isCustom)
    }

    private func open(_ state: GameState, replacingRoute: Bool = false) {
        if session?.state.id != state.id {
            retireCurrentSession()
            session = makeSession(for: state)
        }
        if replacingRoute {
            path = [.game]
        } else if path.last != .game {
            path.append(.game)
        }
    }

    private func makeSession(for state: GameState) -> GameSession {
        let session = GameSession(state: state, settings: settings)
        session.onChange = { [weak self] _ in self?.scheduleSave() }
        session.onFinish = { [weak self] session in self?.recordWin(of: session) }
        return session
    }

    /// Saves the current session (or records it, if it was lost) before another one replaces it.
    private func retireCurrentSession() {
        guard let session else { return }
        session.stopTimer()
        if session.status == .lost {
            concludeLostGame(session.state)
        } else {
            saveCurrentSession()
        }
        self.session = nil
    }

    /// Removes the unfinished regular game, recording it as abandoned if it was played.
    private func discardStandardGame() {
        if session?.state.kind.dailyKey == nil {
            retireCurrentSession()
        }
        for state in savedGames where state.kind.dailyKey == nil {
            switch state.status {
            case .inProgress where state.hasProgress:
                conclude(state, as: .abandoned)
            case .lost:
                conclude(state, as: .lost)
            default:
                break
            }
        }
        savedGames.removeAll { $0.kind.dailyKey == nil }
        persistGames()
    }

    // MARK: - Saving

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            saveCurrentSession()
        }
    }

    /// Persists the current session. Finished games are only kept while a loss
    /// still needs to be recorded (so a relaunch can record it).
    func saveCurrentSession() {
        guard let session else { return }
        let snapshot = session.snapshot()
        let keep = snapshot.status == .inProgress || (snapshot.status == .lost && !concludedGames.contains(snapshot.id))
        if let index = savedGames.firstIndex(where: { $0.id == snapshot.id }) {
            if keep {
                savedGames[index] = snapshot
            } else {
                savedGames.remove(at: index)
            }
        } else if keep {
            savedGames.append(snapshot)
        }
        persistGames()
    }

    // MARK: - Finishing games

    private func record(for state: GameState, outcome: Outcome) -> GameRecord {
        GameRecord(
            date: state.endedAt ?? .now,
            kind: state.kind,
            difficulty: state.difficulty,
            outcome: outcome,
            duration: state.elapsed,
            mistakes: state.mistakes,
            hints: state.hintsUsed,
            usedAutoNotes: state.usedAutoNotes,
            gameID: state.id
        )
    }

    /// Records a game's result exactly once and forgets the saved game.
    private func conclude(_ state: GameState, as outcome: Outcome) {
        guard concludedGames.insert(state.id).inserted else { return }
        // Already recorded if the app was killed before the saved game could be deleted.
        if !stats.hasRecord(ofGame: state.id) {
            stats.add(record(for: state, outcome: outcome))
        }
        // The day's next attempt starts with them (see `DailyStore.hints`).
        if outcome != .won, let challenge = state.kind.dailyKey.flatMap(DailyChallenge.init(key:)) {
            daily.recordHints(state.hintsUsed, on: challenge)
        }
        savedGames.removeAll { $0.id == state.id }
        persistGames()
    }

    var achievementContext: AchievementContext {
        AchievementContext(records: stats.records, dailyCompleted: daily.completedCount, dailyBestStreak: daily.bestStreak)
    }

    private func recordWin(of session: GameSession) {
        let state = session.state
        guard !concludedGames.contains(state.id) else { return }
        let previousBest = state.kind == .custom ? nil : state.difficulty.flatMap { stats.bestTime(for: $0) }
        conclude(state, as: .won)

        var dailyStreak: Int?
        if let key = state.kind.dailyKey, let challenge = DailyChallenge(key: key) {
            daily.record(
                DailyResult(duration: state.elapsed, mistakes: state.mistakes, hints: state.hintsUsed, completedAt: .now, startedAt: state.createdAt),
                for: challenge
            )
            refreshToday()
            dailyStreak = daily.currentStreak(today: today)
        }

        let unlocked = achievements.evaluate(achievementContext)
        session.completion = CompletionSummary(
            duration: state.elapsed,
            mistakes: state.mistakes,
            hints: state.hintsUsed,
            isNewBest: state.hintsUsed == 0 && previousBest.map { state.elapsed < $0 } ?? false,
            previousBest: previousBest,
            unlocked: unlocked,
            dailyStreak: dailyStreak
        )
    }

    /// Records a game that ended in defeat and forgets it.
    func concludeLostGame(_ state: GameState) {
        conclude(state, as: .lost)
    }

    /// Restarts the puzzle as a fresh attempt, which keeps the hints used (see `GameSession.restart`);
    /// the abandoned attempt still counts.
    func restart(_ session: GameSession) {
        let previous = session.snapshot()
        if previous.status == .lost {
            conclude(previous, as: .lost)
        } else if previous.status == .inProgress && previous.hasProgress {
            conclude(previous, as: .abandoned)
        }
        savedGames.removeAll { $0.id == previous.id }
        session.restart()
        saveCurrentSession()
    }

    /// Called when a game screen disappears – either because something was pushed
    /// on top of it (the game stays alive) or because the player left it.
    func leaveGame(_ leaving: GameSession) {
        leaving.stopTimer()
        guard leaving === session else { return }
        if path.contains(.game) {
            saveCurrentSession()
        } else {
            switch leaving.status {
            case .lost:
                concludeLostGame(leaving.state)
                session = nil
            case .won:
                session = nil
            case .inProgress:
                saveCurrentSession()
            }
        }
        updateIdleTimer()
    }

    /// Starts another game of the same kind after finishing a regular or custom one.
    /// A daily challenge has no next one; its game screen only offers going back.
    func playAgain() {
        guard let session else { return }
        switch session.state.kind {
        case .standard:
            // Choosing a new game on the game over card gives up its second chance: nothing to confirm.
            if session.status == .lost { concludeLostGame(session.state) }
            if let difficulty = session.state.difficulty { request(.new(difficulty)) }
        case .custom:
            if session.status == .lost { concludeLostGame(session.state) }
            path = [.customPuzzle]
        case .daily:
            break
        }
    }

    func goHome() {
        path = []
    }

    /// Leaves a finished game for where it was started: the calendar for a daily challenge, otherwise home.
    func closeGame() {
        if session?.state.kind.dailyKey != nil, path.count > 1 {
            path.removeLast()
        } else {
            goHome()
        }
    }

    // MARK: - Lifecycle

    func scenePhaseChanged(to phase: ScenePhase) {
        if phase == .active {
            refreshToday()
            // A game screen that appeared while the app wasn't active (e.g. during launch) couldn't
            // start its timer. A game paused on the way out stays paused.
            if path.last == .game, !showSettings {
                session?.startTimer()
            }
            updateIdleTimer()
            return
        }
        if let session, session.isTimerRunning {
            session.pause()
        }
        saveCurrentSession()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func updateIdleTimer() {
        let playing = path.last == .game && session?.isPlaying == true
        UIApplication.shared.isIdleTimerDisabled = settings.keepScreenOn && playing
    }

    func resetAllData() {
        stats.reset()
        daily.reset()
        achievements.reset()
    }
}

private extension GameRequest {
    var isCustom: Bool {
        if case .custom = self { true } else { false }
    }
}
