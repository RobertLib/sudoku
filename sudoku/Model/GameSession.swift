//
//  GameSession.swift
//  sudoku
//
//  Live game controller: input, notes, undo/redo, mistakes, hints and timing.
//

import Foundation

/// Triggers a highlight pulse in one cell; a new `id` starts the animation after `delay`.
struct FlashToken: Equatable {
    var id = 0
    var delay: Double = 0
}

enum GameMessage: Equatable {
    case boardHasErrors
    case noMistakesFound
    case mistakesFound(Int)
}

/// Shown after a win; filled in by the app model once the result is recorded.
struct CompletionSummary {
    var duration: TimeInterval
    var mistakes: Int
    var hints: Int
    var isNewBest: Bool
    var previousBest: TimeInterval?
    var unlocked: [Achievement]
    var dailyStreak: Int?
}

@Observable
final class GameSession {
    /// Identifies the session for as long as it lives; unlike `state.id`, it stays the same on restart.
    let id = UUID()
    private(set) var state: GameState
    let settings: AppSettings

    var selection: Int?
    var isNotesMode = false
    private(set) var lockedDigit: Int?
    private(set) var isPaused = false
    private(set) var hint: HintSession?
    private(set) var isComputingHint = false
    /// The selection was moved while the current hint is shown. The hint's colors replace the
    /// selection fill, so the board outlines the selection then – but only once the player moves
    /// it, so a cell selected before the hint doesn't look like part of the explanation.
    private(set) var movedSelectionDuringHint = false
    /// Per-cell pulse triggers (completed houses, solved board).
    private(set) var flashTokens = [FlashToken](repeating: FlashToken(), count: 81)
    /// Per-cell shake triggers (mistakes).
    private(set) var shakeTokens = [Int](repeating: 0, count: 81)
    private(set) var checkedErrors: Set<Int> = []
    private(set) var gaveUp = false
    var completion: CompletionSummary?
    var message: GameMessage?
    /// Grows with every message shown, so the same message twice in a row is announced again.
    private(set) var messageCount = 0

    private var timerStart: Date?
    private var eventCounter = 0

    /// Called once when the puzzle is solved.
    var onFinish: ((GameSession) -> Void)?
    /// Called after every state change worth persisting.
    var onChange: ((GameSession) -> Void)?

    init(state: GameState, settings: AppSettings) {
        self.state = state
        self.settings = settings
    }

    // MARK: - Derived state

    var status: GameStatus { state.status }
    var isPlaying: Bool { state.status == .inProgress && !isPaused }
    var isTimerRunning: Bool { timerStart != nil }
    var canUndo: Bool { isPlaying && !state.history.isEmpty }
    var canRedo: Bool { isPlaying && !state.future.isEmpty }

    func elapsed(at date: Date = .now) -> TimeInterval {
        state.elapsed + (timerStart.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }

    var mistakeLimit: Int? {
        settings.mistakeLimit.map { $0 + state.extraLives }
    }

    /// Mistakes counting towards `mistakeLimit`.
    var limitedMistakes: Int { state.limitedMistakes }

    func isGiven(_ cell: Int) -> Bool { state.givens[cell] != 0 }

    func isWrong(_ cell: Int) -> Bool {
        state.values[cell] != 0 && !isGiven(cell) && state.values[cell] != state.solution[cell]
    }

    func count(of digit: Int) -> Int {
        state.values.count { Int($0) == digit }
    }

    /// Whether the game may tell right digits from wrong ones. Only instant checking does;
    /// otherwise every reaction must follow from what the board shows, or it would give mistakes away.
    private var revealsMistakes: Bool { settings.mistakeMode == .instant }

    /// All nine positions of the digit are filled: correctly with instant checking,
    /// otherwise without repeating the digit in any house.
    func isDigitComplete(_ digit: Int) -> Bool {
        if revealsMistakes {
            return (0..<81).allSatisfy { Int(state.solution[$0]) != digit || state.values[$0] == state.solution[$0] }
        }
        let cells = (0..<81).filter { Int(state.values[$0]) == digit }
        return cells.count == 9
            && Set(cells.map { Grid.rowOf[$0] }).count == 9
            && Set(cells.map { Grid.columnOf[$0] }).count == 9
            && Set(cells.map { Grid.boxOf[$0] }).count == 9
    }

    /// The house is filled: correctly with instant checking, otherwise with nine different digits.
    private func isComplete(house: Int) -> Bool {
        let cells = Grid.houseCells[house]
        if revealsMistakes {
            return cells.allSatisfy { state.values[$0] == state.solution[$0] }
        }
        return DigitMask(digits: cells.map { Int(state.values[$0]) }) == Grid.allDigits
    }

    /// The digit to emphasize across the board.
    var highlightDigit: Int? {
        if let lockedDigit { return lockedDigit }
        if let selection, state.values[selection] != 0 { return Int(state.values[selection]) }
        return nil
    }

    /// Cells that repeat a digit within a row, column or box.
    var conflictingCells: Set<Int> {
        Grid.conflictingCells(in: state.values)
    }

    /// The current state with the running timer folded in, ready to be saved.
    func snapshot() -> GameState {
        var snapshot = state
        snapshot.elapsed = elapsed()
        snapshot.updatedAt = .now
        return snapshot
    }

    // MARK: - Timer & pause

    func startTimer() {
        guard state.status == .inProgress, !isPaused, timerStart == nil else { return }
        timerStart = .now
    }

    func stopTimer() {
        guard let start = timerStart else { return }
        state.elapsed += max(0, Date.now.timeIntervalSince(start))
        timerStart = nil
    }

    #if DEBUG
    /// `-debugElapsed`: a screenshot pose shows a plausible time rather than the two seconds it took.
    func debugAddElapsed(_ seconds: TimeInterval) {
        state.elapsed += seconds
    }
    #endif

    func pause() {
        guard state.status == .inProgress, !isPaused else { return }
        stopTimer()
        isPaused = true
        notifyChange()
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        startTimer()
    }

    func togglePause() {
        isPaused ? resume() : pause()
    }

    // MARK: - Input

    func select(_ cell: Int) {
        guard isPlaying else { return }
        // While a hint is shown the board is for looking: a tap on the cell it explains mustn't fill
        // in the locked digit, whose pad key the hint panel hides.
        if hint != nil { movedSelectionDuringHint = true }
        if let digit = lockedDigit, hint == nil {
            selection = cell
            if isGiven(cell) {
                play(.selection)
            } else if isNotesMode {
                // Tapping cell after cell, one that already holds a digit is easily hit: a note mustn't
                // replace it. A digit entered into the selected cell still does (see `enter`).
                if state.values[cell] == 0 { toggleNote(digit, at: cell) } else { play(.selection) }
            } else {
                placeDigit(digit, at: cell)
            }
            return
        }
        if selection != cell { play(.selection) }
        selection = cell
    }

    func moveSelection(rows: Int, columns: Int) {
        guard isPlaying else { return }
        if hint != nil { movedSelectionDuringHint = true }
        guard let current = selection else {
            selection = 40
            return
        }
        let row = (Grid.rowOf[current] + rows + 9) % 9
        let column = (Grid.columnOf[current] + columns + 9) % 9
        selection = Grid.index(row: row, column: column)
        play(.selection)
    }

    /// A tap on the number pad.
    func padTapped(_ digit: Int) {
        guard isPlaying else { return }
        if settings.inputMode == .digitFirst || lockedDigit != nil {
            toggleLock(digit)
            return
        }
        enter(digit)
    }

    /// Locks a digit so that tapping cells fills it in (a long press on the pad
    /// does this in any input mode). Tapping the locked digit again unlocks it.
    func toggleLock(_ digit: Int) {
        guard isPlaying else { return }
        lockedDigit = lockedDigit == digit ? nil : digit
        play(.selection)
    }

    /// Enters a digit (or note) into the selected cell.
    func enter(_ digit: Int) {
        guard isPlaying, let cell = selection else { return }
        guard !isGiven(cell) else {
            play(.blocked)
            return
        }
        if isNotesMode {
            toggleNote(digit, at: cell)
        } else {
            placeDigit(digit, at: cell)
        }
    }

    func toggleNotesMode() {
        isNotesMode.toggle()
        play(.selection)
    }

    func erase() {
        guard isPlaying, let cell = selection, !isGiven(cell) else { return }
        var builder = MoveBuilder(state: state, focus: cell)
        if state.values[cell] != 0 {
            builder.setValue(0, at: cell)
        } else if state.notes[cell] != 0 {
            builder.setNotes(0, at: cell)
        } else {
            return
        }
        commit(builder)
        play(.erase)
    }

    private func placeDigit(_ digit: Int, at cell: Int) {
        var builder = MoveBuilder(state: state, focus: cell)
        if Int(state.values[cell]) == digit {
            builder.setValue(0, at: cell)
            commit(builder)
            play(.erase)
            return
        }
        builder.setValue(digit, at: cell)
        builder.setNotes(0, at: cell)
        // A digit that instant checking already flags as wrong mustn't wipe correct notes from its peers.
        let isFlaggedMistake = revealsMistakes && Int(state.solution[cell]) != digit
        if settings.autoRemoveNotes && !isFlaggedMistake {
            builder.removeNote(digit, fromPeersOf: cell)
        }
        commit(builder)
        afterPlacing(digit, at: cell)
    }

    private func toggleNote(_ digit: Int, at cell: Int) {
        var builder = MoveBuilder(state: state, focus: cell)
        if state.values[cell] != 0 {
            builder.setValue(0, at: cell)
            builder.setNotes(.digit(digit), at: cell)
        } else {
            builder.setNotes(state.notes[cell] ^ .digit(digit), at: cell)
        }
        commit(builder)
        play(.note)
    }

    private func afterPlacing(_ digit: Int, at cell: Int) {
        let isCorrect = Int(state.solution[cell]) == digit
        // Every wrong digit counts towards the result (perfect games, achievements);
        // only instant checking reveals it right away and enforces the limit.
        if !isCorrect {
            if mistakeLimit != nil { state.limitedMistakes += 1 }
            state.mistakes += 1
        }
        if !isCorrect && revealsMistakes {
            eventCounter += 1
            shakeTokens[cell] = eventCounter
            play(.mistake)
            if let mistakeLimit, limitedMistakes >= mistakeLimit {
                lose()
            }
            notifyChange()
            return
        }
        if state.isSolved {
            win(lastCell: cell)
            return
        }
        if !state.values.contains(0) {
            show(.boardHasErrors)
            play(.mistake)
            return
        }
        // Without instant checking a wrong digit gets the same reaction as a right one.
        celebrateCompletedHouses(around: cell, digit: digit)
    }

    private func celebrateCompletedHouses(around cell: Int, digit: Int) {
        let cells = Grid.housesOf[cell].filter(isComplete(house:)).flatMap { Grid.houseCells[$0] }
        if !cells.isEmpty {
            celebrate(cells, from: cell, step: 0.045)
            play(.houseCompleted)
        } else if isDigitComplete(digit) {
            play(.houseCompleted)
        } else {
            play(.place)
        }
    }

    private func celebrate(_ cells: some Sequence<Int>, from origin: Int, step: Double) {
        eventCounter += 1
        for cell in cells {
            let distance = abs(Grid.rowOf[cell] - Grid.rowOf[origin]) + abs(Grid.columnOf[cell] - Grid.columnOf[origin])
            flashTokens[cell] = FlashToken(id: eventCounter, delay: Double(distance) * step)
        }
    }

    // MARK: - Moves

    private func commit(_ builder: MoveBuilder) {
        guard let move = builder.move else { return }
        state.values = builder.values
        state.notes = builder.notes
        state.history.append(move)
        state.future.removeAll()
        checkedErrors.subtract(move.changes.map(\.cell))
        hint = nil
        releaseCompletedLock()
        notifyChange()
    }

    func undo() {
        guard isPlaying, let move = state.history.popLast() else { return }
        revert(move)
        state.future.append(move)
        play(.undo)
    }

    func redo() {
        guard isPlaying, let move = state.future.popLast() else { return }
        for change in move.changes {
            state.values[change.cell] = change.newValue
            state.notes[change.cell] = change.newNotes
        }
        checkedErrors.subtract(move.changes.map(\.cell))
        state.history.append(move)
        if let focus = move.focus { selection = focus }
        hint = nil
        releaseCompletedLock()
        play(.undo)
        notifyChange()
    }

    private func revert(_ move: Move) {
        for change in move.changes.reversed() {
            state.values[change.cell] = change.oldValue
            state.notes[change.cell] = change.oldNotes
        }
        checkedErrors.subtract(move.changes.map(\.cell))
        if let focus = move.focus { selection = focus }
        hint = nil
        releaseCompletedLock()
        notifyChange()
    }

    /// Unlocks the locked digit once all its cells are filled, however that happened (a hint,
    /// a revealed cell, redo…): its pad key is hidden, and the next tap would place a tenth copy.
    private func releaseCompletedLock() {
        if let lockedDigit, isDigitComplete(lockedDigit) {
            self.lockedDigit = nil
        }
    }

    // MARK: - Assists

    func fillAllNotes() {
        guard isPlaying else { return }
        let candidates = LogicalSolver.basicCandidates(for: state.values)
        var builder = MoveBuilder(state: state, focus: selection)
        for cell in 0..<81 where state.values[cell] == 0 {
            builder.setNotes(candidates[cell], at: cell)
        }
        state.usedAutoNotes = true
        commit(builder)
        play(.hint)
    }

    func clearAllNotes() {
        guard isPlaying else { return }
        var builder = MoveBuilder(state: state, focus: selection)
        for cell in 0..<81 where state.notes[cell] != 0 {
            builder.setNotes(0, at: cell)
        }
        commit(builder)
        play(.erase)
    }

    var hasAnyNotes: Bool { state.notes.contains { $0 != 0 } }

    /// Highlights wrong digits (useful when instant checking is off). Counts as a hint
    /// either way: learning that every digit is right is help too.
    func checkBoard() {
        guard isPlaying else { return }
        let wrong = (0..<81).filter(isWrong)
        checkedErrors = Set(wrong)
        state.hintsUsed += 1
        if wrong.isEmpty {
            show(.noMistakesFound)
            play(.houseCompleted)
        } else {
            show(.mistakesFound(wrong.count))
            play(.mistake)
        }
        notifyChange()
    }

    var canRevealSelection: Bool {
        guard isPlaying, let selection, !isGiven(selection) else { return false }
        // Without instant checking, refusing to reveal a correct digit would give it away.
        return !revealsMistakes || state.values[selection] != state.solution[selection]
    }

    func revealSelectedCell() {
        guard canRevealSelection, let cell = selection else { return }
        reveal(cell)
    }

    private func reveal(_ cell: Int) {
        state.hintsUsed += 1
        let digit = Int(state.solution[cell])
        selection = cell
        guard Int(state.values[cell]) != digit else {
            // The digit was already right (only possible without instant checking): confirm it.
            celebrate([cell], from: cell, step: 0)
            play(.hint)
            notifyChange()
            return
        }
        var builder = MoveBuilder(state: state, focus: cell)
        builder.setValue(digit, at: cell)
        builder.setNotes(0, at: cell)
        if settings.autoRemoveNotes { builder.removeNote(digit, fromPeersOf: cell) }
        commit(builder)
        afterPlacing(digit, at: cell)
    }

    // MARK: - Hints

    /// Shows a hint. Returns the task computing a logical step, if one was started.
    @discardableResult
    func requestHint() -> Task<Void, Never>? {
        guard isPlaying, hint == nil, !isComputingHint else { return nil }

        let wrong = (0..<81).filter(isWrong)
        if !wrong.isEmpty {
            present(.mistakes(wrong))
            return nil
        }
        let badNotes = (0..<81).filter {
            state.values[$0] == 0 && state.notes[$0] != 0 && !state.notes[$0].contains(digit: Int(state.solution[$0]))
        }
        if !badNotes.isEmpty {
            present(.badNotes(badNotes))
            return nil
        }

        isComputingHint = true
        let values = state.values
        let candidates = state.notes.map { $0 == 0 ? Grid.allDigits : $0 }
        return Task {
            let plan = await Task.detached(priority: .userInitiated) {
                LogicalSolver.hintPlan(values: values, candidates: candidates)
            }.value
            isComputingHint = false
            guard isPlaying, state.values == values else { return }
            present(plan.isEmpty ? .noStep : .logic(plan))
        }
    }

    private func present(_ content: HintSession.Content) {
        state.hintsUsed += 1
        hint = HintSession(content: content)
        movedSelectionDuringHint = false
        play(.hint)
        notifyChange()
    }

    func showNextHintStage() {
        guard var hint, !hint.isLastStage else { return }
        hint.stage += 1
        self.hint = hint
        play(.selection)
    }

    func showPreviousHintStage() {
        guard var hint, hint.stage > 1 else { return }
        hint.stage -= 1
        self.hint = hint
        play(.selection)
    }

    func dismissHint() {
        hint = nil
    }

    func applyHint() {
        guard let hint, isPlaying else { return }
        self.hint = nil
        switch hint.content {
        case .mistakes(let cells):
            var builder = MoveBuilder(state: state, focus: cells.first)
            for cell in cells { builder.setValue(0, at: cell) }
            commit(builder)
            play(.erase)

        case .badNotes(let cells):
            let candidates = LogicalSolver.basicCandidates(for: state.values)
            var builder = MoveBuilder(state: state, focus: cells.first)
            for cell in cells { builder.setNotes(candidates[cell], at: cell) }
            commit(builder)
            play(.note)

        case .logic(let entries):
            let placement = entries.last?.step.placement
            var builder = MoveBuilder(state: state, focus: placement?.cell)
            // Without a placement the eliminations are all the hint achieves, so they must be kept
            // even in cells without notes – otherwise the same hint would come back forever.
            let finalCandidates = placement == nil ? Self.candidates(after: entries) : nil
            for entry in entries {
                for elimination in entry.step.eliminations {
                    let cell = elimination.cell
                    if builder.notes[cell].contains(digit: elimination.digit) {
                        builder.setNotes(builder.notes[cell] & ~.digit(elimination.digit), at: cell)
                    } else if builder.notes[cell] == 0, let candidates = finalCandidates?[cell], candidates != 0 {
                        builder.setNotes(candidates, at: cell)
                    }
                }
            }
            guard let placement else {
                if builder.move == nil {
                    revealInsteadOfHint()
                } else {
                    commit(builder)
                    play(.note)
                }
                return
            }
            builder.setValue(placement.digit, at: placement.cell)
            builder.setNotes(0, at: placement.cell)
            if settings.autoRemoveNotes { builder.removeNote(placement.digit, fromPeersOf: placement.cell) }
            selection = placement.cell
            commit(builder)
            afterPlacing(placement.digit, at: placement.cell)

        case .noStep:
            revealInsteadOfHint()
        }
    }

    /// Reveals the selected (or first empty) cell when logic can't make progress.
    /// The board has no wrong digits at this point – the hint would have pointed them out.
    private func revealInsteadOfHint() {
        let isSelectionEmpty = selection.map { state.values[$0] == 0 } ?? false
        let target = isSelectionEmpty ? selection : (0..<81).first { state.values[$0] == 0 }
        guard let target else { return }
        state.hintsUsed -= 1 // the hint itself was already counted
        reveal(target)
    }

    /// The candidates once every step of a hint plan has been applied.
    private static func candidates(after entries: [HintEntry]) -> [DigitMask]? {
        guard let first = entries.first else { return nil }
        var solver = LogicalSolver(values: first.values, candidates: first.candidates)
        for entry in entries {
            solver.apply(entry.step)
        }
        return solver.candidates
    }

    // MARK: - Game flow

    private func win(lastCell: Int) {
        stopTimer()
        state.status = .won
        state.endedAt = .now
        selection = nil
        lockedDigit = nil
        hint = nil
        isNotesMode = false
        celebrate(0..<81, from: lastCell, step: 0.04)
        play(.win)
        notifyChange()
        onFinish?(self)
    }

    private func lose() {
        stopTimer()
        state.status = .lost
        state.endedAt = .now
        hint = nil
        play(.gameOver)
    }

    /// Each game gets one second chance, otherwise the mistake limit would mean nothing.
    var canUseSecondChance: Bool {
        !gaveUp && state.awaitsSecondChance
    }

    /// Continues after the mistake limit, removing the digit that ended the game.
    func secondChance() {
        guard canUseSecondChance else { return }
        state.extraLives += 1
        state.status = .inProgress
        state.endedAt = nil
        if let move = state.history.last, let cell = move.focus, isWrong(cell) {
            state.history.removeLast()
            revert(move)
        }
        startTimer()
        notifyChange()
    }

    func giveUp() {
        guard state.status == .inProgress else { return }
        stopTimer()
        gaveUp = true
        // Its dialog may have been answered after the app paused the game in the background.
        isPaused = false
        hint = nil
        selection = nil
        lockedDigit = nil
        checkedErrors = []
        // Every cell it fills is revealed, as by Reveal Selected Cell: a daily challenge played again
        // starts with them (see `DailyStore.hints`).
        state.hintsUsed += (0..<81).count { state.values[$0] != state.solution[$0] }
        state.values = state.solution
        state.status = .lost
        state.endedAt = .now
        notifyChange()
    }

    func restart() {
        let previous = state
        state = GameState(kind: previous.kind, difficulty: previous.difficulty, givens: previous.givens, solution: previous.solution)
        // A daily challenge started on its day still counts as played on time (see `DailyResult.isOnTime`).
        state.createdAt = previous.createdAt
        // What the hints showed is still known, so the new attempt doesn't count as one without them.
        state.hintsUsed = previous.hintsUsed
        selection = nil
        lockedDigit = nil
        isNotesMode = false
        isPaused = false
        hint = nil
        checkedErrors = []
        gaveUp = false
        completion = nil
        timerStart = nil
        startTimer()
        notifyChange()
    }

    // MARK: - Helpers

    private func show(_ message: GameMessage) {
        self.message = message
        messageCount += 1
    }

    private func notifyChange() {
        onChange?(self)
    }

    private func play(_ event: FeedbackEvent) {
        Feedback.play(event, settings: settings)
    }
}

/// Collects cell edits and turns them into a single undoable move.
struct MoveBuilder {
    private(set) var values: [UInt8]
    private(set) var notes: [DigitMask]
    private let originalValues: [UInt8]
    private let originalNotes: [DigitMask]
    private var touched: [Int] = []
    let focus: Int?

    init(state: GameState, focus: Int?) {
        values = state.values
        notes = state.notes
        originalValues = state.values
        originalNotes = state.notes
        self.focus = focus
    }

    mutating func setValue(_ value: Int, at cell: Int) {
        touch(cell)
        values[cell] = UInt8(value)
    }

    mutating func setNotes(_ mask: DigitMask, at cell: Int) {
        touch(cell)
        notes[cell] = mask
    }

    mutating func removeNote(_ digit: Int, fromPeersOf cell: Int) {
        for peer in Grid.peers[cell] where values[peer] == 0 && notes[peer].contains(digit: digit) {
            setNotes(notes[peer] & ~.digit(digit), at: peer)
        }
    }

    private mutating func touch(_ cell: Int) {
        if !touched.contains(cell) { touched.append(cell) }
    }

    var move: Move? {
        let changes = touched.compactMap { cell -> CellChange? in
            guard values[cell] != originalValues[cell] || notes[cell] != originalNotes[cell] else { return nil }
            return CellChange(
                cell: cell,
                oldValue: originalValues[cell],
                newValue: values[cell],
                oldNotes: originalNotes[cell],
                newNotes: notes[cell]
            )
        }
        return changes.isEmpty ? nil : Move(focus: focus, changes: changes)
    }
}
