//
//  GameSessionTests.swift
//  sudokuTests
//

import Foundation
import SwiftUI
import Testing
@testable import sudoku

struct HintTests {
    @Test func hintPlacesACorrectDigit() async throws {
        let session = Fixtures.session(Fixtures.classic)
        await session.requestHintAndWait()
        try #require(session.hint != nil)
        session.showWholeHint()
        let empty = session.emptyCells().count
        session.applyHint()
        #expect(session.emptyCells().count == empty - 1)
        #expect(!(0..<81).contains(where: session.isWrong))
        #expect(session.state.hintsUsed == 1)
    }

    /// What a hint showed is still known after a restart, so the fresh attempt doesn't count as one without
    /// hints (best times, perfect games). Mistakes start over.
    @Test func aRestartKeepsTheHints() {
        let session = Fixtures.session(Fixtures.classic)
        let cells = session.emptyCells()
        session.placeWrongDigit(at: cells[0])
        session.select(cells[1])
        session.revealSelectedCell()
        session.restart()
        #expect(session.state.values == Fixtures.classic)
        #expect(session.state.hintsUsed == 1)
        #expect(session.state.mistakes == 0)
    }

    /// The nudge of BUG+1 asks to look at the cells with two candidates; highlighting the target cell's
    /// row, column and box would point straight at the one cell with three.
    @Test func bugPlusOneNudgeDoesntPointAtItsCell() throws {
        // Solving this, BUG+1 finds a step in some position (see `everyFinderIsSoundInEveryPosition`).
        let puzzle = try #require(PuzzleParser.parse("..72.6.3.98.....6..2...3.78..9.6.......814.......5.4..23.6...8..9.....46.6.5.82.."))
        var solver = LogicalSolver(values: puzzle)
        var bug: HintEntry?
        while bug == nil, !solver.isSolved {
            if let step = solver.findStep(using: .bugPlusOne) {
                bug = HintEntry(step: step, values: solver.values, candidates: solver.candidates)
            } else if let step = solver.nextStep() {
                solver.apply(step)
            } else {
                break
            }
        }
        var hint = HintSession(content: .logic([try #require(bug)]))
        #expect(hint.isNudge)
        #expect(hint.overlay.houseCells.isEmpty)
        #expect(hint.overlay.patternCells.isEmpty)
        hint.stage = 1
        #expect(!hint.overlay.houseCells.isEmpty)
    }

    /// Without notes, a hint that only eliminates candidates used to change nothing,
    /// so the same hint came back forever.
    @Test func hintsKeepMakingProgressBeyondTheEngine() async throws {
        #expect(!LogicalSolver.rate(Fixtures.escargot).isSolvable)
        let session = Fixtures.session(Fixtures.escargot, kind: .custom, difficulty: nil)
        var hints = 0
        while session.status == .inProgress, hints < 200 {
            let before = (session.state.values, session.state.notes)
            await session.requestHintAndWait()
            try #require(session.hint != nil)
            session.showWholeHint()
            session.applyHint()
            hints += 1
            try #require(session.state.values != before.0 || session.state.notes != before.1, "hint \(hints) changed nothing")
        }
        #expect(session.status == .won)
        #expect(session.state.mistakes == 0)
    }

    /// A naked single can also come from notes or earlier steps of the hint, not just from the
    /// numbers in the cell's row, column and box.
    @Test func nakedSingleNamesTheRightReason() throws {
        let values = Fixtures.classic
        let solution = try #require(Solver.uniqueSolution(values))
        let basic = LogicalSolver.basicCandidates(for: values)
        let cell = try #require((0..<81).first { values[$0] == 0 && basic[$0].digitCount > 1 })
        let digit = Int(solution[cell])
        let step = LogicStep(technique: .nakedSingle, placement: Candidate(cell, digit), cells: [cell], digits: [digit])
        let target = HintText.cell(cell)

        var candidates = basic
        candidates[cell] = .digit(digit)
        #expect(
            HintText.explanation(for: HintEntry(step: step, values: values, candidates: candidates))
                == String(localized: "\(target) can only hold \(digit) – it's the only candidate left in this cell.")
        )

        var nearlySolved = solution
        nearlySolved[cell] = 0
        #expect(
            HintText.explanation(for: HintEntry(step: step, values: nearlySolved, candidates: LogicalSolver.basicCandidates(for: nearlySolved)))
                == String(localized: "\(target) can only hold \(digit) – every other number already appears in its row, column or box.")
        )
    }

    /// The board shows what a hint is about in color; the text names the cells too, for VoiceOver.
    @Test func hintsNameTheirCells() async throws {
        let session = Fixtures.session(Fixtures.classic, settings: Fixtures.settings { $0.mistakeMode = .off })
        let wrong = Array(session.emptyCells().prefix(2))
        for cell in wrong { session.placeWrongDigit(at: cell) }
        await session.requestHintAndWait()
        let hint = try #require(session.hint)
        let result = try #require(HintText.result(for: hint))
        for cell in wrong {
            #expect(result.contains(HintText.cell(cell)))
        }
        #expect(HintText.title(for: hint) == String(localized: "Mistakes Found"))

        let cell = try #require(session.emptyCells().first)
        let step = LogicStep(technique: .nakedSingle, placement: Candidate(cell, 1), cells: [cell], digits: [1])
        #expect(HintText.nudge(for: step).contains(HintText.cell(cell)))
    }

    @Test func aLongListOfEliminationsIsCutShortCleanly() {
        let step = LogicStep(technique: .xWing, eliminations: (0..<8).map { Candidate($0, 5) })
        let result = HintText.result(for: step) ?? ""
        #expect(result.contains(HintText.cell(5)))
        #expect(!result.contains(HintText.cell(6)))
        #expect(!result.contains("…"))
    }
}

struct MistakeTests {
    /// An empty cell and a wrong digit for it that is also noted in one of its peers.
    private func wrongDigitNotedInPeers(_ session: GameSession) throws -> (cell: Int, digit: Int) {
        for cell in session.emptyCells() {
            for digit in session.state.notes[cell].digits where digit != Int(session.state.solution[cell]) {
                if Grid.peers[cell].contains(where: { session.state.notes[$0].contains(digit: digit) }) {
                    return (cell, digit)
                }
            }
        }
        throw CancellationError()
    }

    private func peersNoting(_ digit: Int, of cell: Int, in session: GameSession) -> [Int] {
        Grid.peers[cell].filter { session.state.notes[$0].contains(digit: digit) }
    }

    @Test func instantMistakeKeepsPeerNotes() throws {
        let session = Fixtures.session(Fixtures.classic)
        session.fillAllNotes()
        let (cell, digit) = try wrongDigitNotedInPeers(session)
        let noted = peersNoting(digit, of: cell, in: session)
        session.select(cell)
        session.enter(digit)
        #expect(session.state.mistakes == 1)
        #expect(peersNoting(digit, of: cell, in: session) == noted)
    }

    @Test func uncheckedModesStillCountMistakes() throws {
        for mode in [AppSettings.MistakeMode.conflicts, .off] {
            let session = Fixtures.session(Fixtures.classic, settings: Fixtures.settings { $0.mistakeMode = mode })
            session.fillAllNotes()
            let (cell, digit) = try wrongDigitNotedInPeers(session)
            session.select(cell)
            session.enter(digit)
            #expect(session.state.mistakes == 1, "\(mode)")
            #expect(session.status == .inProgress)
            // Notes still disappear, otherwise they would give the mistake away.
            #expect(peersNoting(digit, of: cell, in: session).isEmpty, "\(mode)")
        }
    }

    /// Without instant checking, no reaction of the game may tell a wrong digit from a right one.
    @Test func uncheckedModesDontGiveMistakesAway() {
        // The first row misses two digits; another empty cell keeps the board from filling up.
        let (givens, solution) = Fixtures.nearlySolved(empty: [0, 3, 80])
        for mode in [AppSettings.MistakeMode.conflicts, .off] {
            let session = Fixtures.session(givens, settings: Fixtures.settings { $0.mistakeMode = mode })
            // Swapped, the two digits are both wrong but fill the row with nine different digits.
            session.select(0)
            session.enter(Int(solution[3]))
            session.select(3)
            session.enter(Int(solution[0]))
            #expect(session.state.mistakes == 2, "\(mode)")
            #expect(Grid.houseCells[0].allSatisfy { session.flashTokens[$0].id != 0 }, "the row is celebrated – \(mode)")
            #expect(session.state.progress == 2.0 / 3.0, "wrong digits count as progress – \(mode)")
            #expect(session.canRevealSelection, "\(mode)")
        }
    }

    @Test func correctDigitsCanBeRevealedOnlyWithoutInstantChecking() {
        for (mode, canReveal) in [(AppSettings.MistakeMode.instant, false), (.conflicts, true), (.off, true)] {
            let session = Fixtures.session(Fixtures.classic, settings: Fixtures.settings { $0.mistakeMode = mode })
            let cell = session.emptyCells()[0]
            session.select(cell)
            session.enter(Int(session.state.solution[cell]))
            #expect(session.canRevealSelection == canReveal, "\(mode)")

            session.revealSelectedCell()
            #expect(session.state.hintsUsed == (canReveal ? 1 : 0), "\(mode)")
            #expect(session.state.values[cell] == session.state.solution[cell], "\(mode)")
        }
    }

    /// Without instant checking, Reveal on a right digit only confirms it, with a flash VoiceOver can't see.
    @Test func revealingARightDigitIsAnnounced() {
        let session = Fixtures.session(Fixtures.classic, settings: Fixtures.settings { $0.mistakeMode = .off })
        let cell = session.emptyCells()[0]
        session.select(cell)
        session.enter(Int(session.state.solution[cell]))
        let before = session.state
        session.revealSelectedCell()
        let announcement = GameSession.change(from: before, to: session.state, selection: session.selection)
        #expect(announcement?.contains(HintText.cell(cell)) == true)
        #expect(GameSession.change(from: before, to: before, selection: cell) == nil, "nothing happened")
    }

    @Test func checkingTheBoardAlwaysCountsAsAHint() {
        let session = Fixtures.session(Fixtures.classic, settings: Fixtures.settings { $0.mistakeMode = .off })
        session.checkBoard()
        #expect(session.message == .noMistakesFound)
        #expect(session.state.hintsUsed == 1)

        session.placeWrongDigit(at: session.emptyCells()[0])
        session.checkBoard()
        #expect(session.message == .mistakesFound(1))
        #expect(session.state.hintsUsed == 2)
    }

    /// The game screen announces and times out a message per `messageCount`, so checking twice with
    /// the same result must still count as a new message.
    @Test func theSameMessageTwiceIsANewMessage() {
        let session = Fixtures.session(Fixtures.classic, settings: Fixtures.settings { $0.mistakeMode = .off })
        session.checkBoard()
        let first = session.messageCount
        session.checkBoard()
        #expect(session.message == .noMistakesFound)
        #expect(session.messageCount == first + 1)
    }

    /// A hint's colors replace the selection fill, so a selection moved during the hint is outlined
    /// instead – but not one made before, which would look like part of the explanation.
    /// And a wrong digit gets a tinted cell, not only red text.
    @Test func boardShowsSelectionAndWrongDigitsBeyondColor() async throws {
        let session = Fixtures.session(Fixtures.classic)
        let cell = session.emptyCells()[0]
        session.placeWrongDigit(at: cell)
        session.select(session.emptyCells()[0])
        var cells = BoardPresenter(session: session, settings: session.settings, overlay: nil).cells()
        #expect(cells[cell].tone == .wrong)
        #expect(cells[cell].fill == .error)

        session.select(cell)
        session.erase()
        await session.requestHintAndWait()
        let hint = try #require(session.hint)
        cells = BoardPresenter(session: session, settings: session.settings, overlay: hint.overlay).cells()
        #expect(cells[cell].isSelected)
        #expect(cells.filter { $0.isSelected }.count == 1)
        #expect(cells.allSatisfy { !$0.isSelectionOutlined })

        session.moveSelection(rows: 0, columns: 1)
        let moved = try #require(session.selection)
        cells = BoardPresenter(session: session, settings: session.settings, overlay: hint.overlay).cells()
        #expect(cells.filter { $0.isSelectionOutlined }.map { $0.index } == [moved])
    }

    @Test func repeatedDigitsAreConflictsUnlessKnownToBeWrong() {
        // Cells 2 and 3 share the first row; both get the digit that belongs in cell 2.
        for (mode, secondTone) in [(AppSettings.MistakeMode.conflicts, DigitTone.conflict), (.instant, .wrong)] {
            let session = Fixtures.session(Fixtures.classic, settings: Fixtures.settings { $0.mistakeMode = mode })
            let digit = Int(session.state.solution[2])
            for cell in [2, 3] {
                session.select(cell)
                session.enter(digit)
            }
            let cells = BoardPresenter(session: session, settings: session.settings, overlay: nil).cells()
            #expect(cells[2].tone == .conflict, "the right digit is only a conflict – \(mode)")
            #expect(cells[3].tone == secondTone, "\(mode)")
        }
    }

    /// Turning instant checking or the limit on mid-game must not end the game for earlier mistakes.
    @Test func theLimitOnlyCountsMistakesMadeUnderIt() {
        let settings = Fixtures.settings { $0.mistakeMode = .off }
        let session = Fixtures.session(Fixtures.classic, settings: settings)
        let cells = session.emptyCells()
        for cell in cells.prefix(4) { session.placeWrongDigit(at: cell) }

        settings.mistakeMode = .instant
        #expect(session.limitedMistakes == 0)
        session.placeWrongDigit(at: cells[4])
        #expect(session.status == .inProgress)
        #expect(session.limitedMistakes == 1)

        settings.mistakeLimitEnabled = false
        session.placeWrongDigit(at: cells[5])
        settings.mistakeLimitEnabled = true
        #expect(session.limitedMistakes == 1, "made while the limit was off")

        session.placeWrongDigit(at: cells[6])
        session.placeWrongDigit(at: cells[7])
        #expect(session.status == .lost)
        #expect(session.state.mistakes == 8, "the results still count every mistake")
    }

    @Test func mistakeLimitAllowsOneSecondChance() {
        let session = Fixtures.session(Fixtures.classic)
        let cells = session.emptyCells()
        for cell in cells.prefix(3) { session.placeWrongDigit(at: cell) }
        #expect(session.status == .lost)
        #expect(session.state.endedAt != nil)
        #expect(session.canUseSecondChance)

        session.secondChance()
        #expect(session.status == .inProgress)
        #expect(session.state.endedAt == nil)
        #expect(!session.isWrong(cells[2]), "the digit that ended the game is removed")
        #expect(session.mistakeLimit == 4)

        session.placeWrongDigit(at: cells[3])
        #expect(session.status == .lost)
        #expect(!session.canUseSecondChance)
        session.secondChance()
        #expect(session.status == .lost)
    }
}

struct UndoTests {
    @Test func undoAndRedoRestoreValuesAndNotes() {
        let session = Fixtures.session(Fixtures.classic)
        session.fillAllNotes()
        let start = session.state
        let cell = session.emptyCells()[0]
        session.select(cell)
        session.enter(Int(session.state.solution[cell]))
        let placed = session.state
        #expect(placed.notes != start.notes, "peer notes were removed")

        session.undo()
        #expect(session.state.values == start.values)
        #expect(session.state.notes == start.notes)
        session.redo()
        #expect(session.state.values == placed.values)
        #expect(session.state.notes == placed.notes)
    }
}

struct LockedDigitTests {
    /// A completed digit's pad key is hidden, so a lock left behind would place a tenth copy with
    /// the next tap – however the digit was completed.
    @Test func aCompletedDigitIsUnlockedHoweverItWasCompleted() {
        let solution = Solver.uniqueSolution(Fixtures.classic)!
        let digit = Int(solution[0])
        let last = (0..<81).last { Int(solution[$0]) == digit }!
        let other = (0..<81).first { Int(solution[$0]) != digit }!
        let givens = Fixtures.nearlySolved(empty: [last, other]).givens

        let revealed = Fixtures.session(givens, settings: Fixtures.settings { $0.inputMode = .digitFirst })
        revealed.toggleLock(digit)
        revealed.selection = last
        revealed.revealSelectedCell()
        #expect(revealed.state.values[last] == UInt8(digit))
        #expect(revealed.lockedDigit == nil, "revealed")

        let redone = Fixtures.session(givens)
        redone.select(last)
        redone.enter(digit)
        redone.undo()
        redone.toggleLock(digit)
        redone.redo()
        #expect(redone.lockedDigit == nil, "redone")

        let undone = Fixtures.session(givens)
        undone.select(last)
        undone.enter(digit)
        undone.erase()
        undone.toggleLock(digit)
        undone.undo()
        #expect(undone.lockedDigit == nil, "erasing it undone")
    }

    /// The hint panel replaces the pad, lock and all: a tap on the cell the hint explains only
    /// selects it, rather than filling in a digit the player can't see is locked.
    @Test func aTapDuringAHintOnlySelects() async throws {
        let session = Fixtures.session(Fixtures.classic, settings: Fixtures.settings { $0.inputMode = .digitFirst })
        await session.requestHintAndWait()
        session.showWholeHint()
        let target = try #require(session.hint?.entries.last?.step.placement?.cell)
        let wrongDigit = Int(session.state.solution[target]) % 9 + 1
        session.padTapped(wrongDigit)
        #expect(session.lockedDigit == wrongDigit)

        session.select(target)
        #expect(session.selection == target)
        #expect(session.state.values[target] == 0)
        #expect(session.state.mistakes == 0)
        #expect(session.hint != nil)

        session.dismissHint()
        session.select(target)
        #expect(session.state.values[target] == UInt8(wrongDigit), "without a hint the lock fills cells again")
    }

    /// Taking notes by tapping cell after cell, a cell that holds a digit is easily hit; the tap only
    /// selects it. A digit entered into the selected cell (cell first, or typed) still becomes a note.
    @Test func aNoteTapLeavesAPlacedDigit() {
        let session = Fixtures.session(Fixtures.classic, settings: Fixtures.settings { $0.inputMode = .digitFirst })
        let cell = session.emptyCells()[0]
        let digit = Int(session.state.solution[cell])
        let other = digit % 9 + 1
        session.padTapped(digit)
        session.select(cell)
        #expect(session.state.values[cell] == UInt8(digit))

        session.toggleNotesMode()
        session.padTapped(digit)
        session.padTapped(other)
        #expect(session.lockedDigit == other)
        session.select(cell)
        #expect(session.selection == cell)
        #expect(session.state.values[cell] == UInt8(digit), "the digit stays")
        #expect(session.state.notes[cell] == 0)

        session.padTapped(other)
        #expect(session.lockedDigit == nil)
        session.enter(other)
        #expect(session.state.values[cell] == 0)
        #expect(session.state.notes[cell] == .digit(other))
    }
}

struct KeyboardTests {
    /// Czech and Slovak number rows type letters; Caps Lock makes them capitals.
    @Test func numberRowLettersCountAsDigitsInEitherCase() {
        #expect(KeyPress.digit(for: "7", modifiers: []) == 7)
        #expect(KeyPress.digit(for: "ř", modifiers: []) == 5)
        #expect(KeyPress.digit(for: "Ř", modifiers: []) == 5)
        #expect(KeyPress.digit(for: "Ě", modifiers: []) == 2)
        #expect(KeyPress.digit(for: "Í", modifiers: []) == 9)
        #expect(KeyPress.digit(for: "+", modifiers: []) == 1)
        #expect(KeyPress.digit(for: "+", modifiers: .shift) == nil)
        #expect(KeyPress.digit(for: "a", modifiers: []) == nil)
    }

    /// The Czech and Slovak 0 key types `é`, which other keyboards have elsewhere.
    @Test func eIsZeroOnlyOnCzechAndSlovakKeyboards() {
        #expect(KeyPress.digit(for: "é", modifiers: [], keyboards: ["cs", "en"]) == 0)
        #expect(KeyPress.digit(for: "É", modifiers: .capsLock, keyboards: ["sk"]) == 0)
        #expect(KeyPress.digit(for: "é", modifiers: [], keyboards: ["en"]) == nil)
        // French keyboards type it on the 2 key; for a player who may use either, it can't be told which one is in use.
        #expect(KeyPress.digit(for: "é", modifiers: [], keyboards: ["cs", "fr"]) == nil)
    }
}
