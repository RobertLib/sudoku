//
//  TestSupport.swift
//  sudokuTests
//

import Foundation
@testable import sudoku

enum Fixtures {
    static let classic = PuzzleParser.parse(
        "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
    )!

    /// The classic puzzle's solution with only the `empty` cells left to fill.
    static func nearlySolved(empty: [Int]) -> (givens: [UInt8], solution: [UInt8]) {
        let solution = Solver.uniqueSolution(classic)!
        var givens = solution
        for cell in empty { givens[cell] = 0 }
        return (givens, solution)
    }

    /// "AI Escargot": unique, but needs techniques beyond the hint engine.
    static let escargot = PuzzleParser.parse(
        "1....7.9..3..2...8..96..5....53..9...1..8...26....4...3......1..4......7..7...3.."
    )!

    /// Settings in a throwaway defaults domain, with sound and haptics off.
    static func settings(_ configure: (AppSettings) -> Void = { _ in }) -> AppSettings {
        let suite = "cz.rob.sudokuTests"
        UserDefaults().removePersistentDomain(forName: suite)
        let settings = AppSettings(defaults: UserDefaults(suiteName: suite)!)
        settings.soundEnabled = false
        settings.hapticsEnabled = false
        configure(settings)
        return settings
    }

    static func session(
        _ givens: [UInt8],
        kind: GameKind = .standard,
        difficulty: Difficulty? = .easy,
        settings: AppSettings = Fixtures.settings()
    ) -> GameSession {
        let state = GameState(kind: kind, difficulty: difficulty, givens: givens, solution: Solver.uniqueSolution(givens)!)
        return GameSession(state: state, settings: settings)
    }
}

extension GameSession {
    /// Asks for a hint and waits until it is shown.
    func requestHintAndWait() async {
        await requestHint()?.value
    }

    /// Steps through the explanation to the last stage, like tapping "Show Me" and "Next Step".
    func showWholeHint() {
        while let hint, hint.isNudge || !hint.isLastStage {
            showNextHintStage()
        }
    }

    func emptyCells() -> [Int] {
        (0..<81).filter { state.values[$0] == 0 }
    }

    /// Places a digit that is wrong in `cell` (cell-first input).
    func placeWrongDigit(at cell: Int) {
        select(cell)
        enter(Int(state.solution[cell]) % 9 + 1)
    }
}
