//
//  GameState.swift
//  sudoku
//
//  The persistent, Codable snapshot of one game.
//

import Foundation

nonisolated enum GameKind: Codable, Hashable, Sendable {
    case standard
    /// A daily challenge identified by its date key (yyyy-MM-dd).
    case daily(String)
    case custom

    var dailyKey: String? {
        if case .daily(let key) = self { key } else { nil }
    }
}

nonisolated enum GameStatus: String, Codable, Sendable {
    case inProgress, won, lost
}

/// One cell's value and notes before and after a move.
nonisolated struct CellChange: Codable, Hashable, Sendable {
    var cell: Int
    var oldValue: UInt8
    var newValue: UInt8
    var oldNotes: DigitMask
    var newNotes: DigitMask
}

/// An undoable player action; may touch several cells (e.g. auto-removed notes).
nonisolated struct Move: Codable, Hashable, Sendable {
    /// The cell the action was aimed at; selected again on undo/redo.
    var focus: Int?
    var changes: [CellChange]
}

nonisolated struct GameState: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var kind: GameKind
    /// `nil` for custom puzzles that need techniques beyond the hint engine.
    var difficulty: Difficulty?
    var givens: [UInt8]
    var solution: [UInt8]
    var values: [UInt8]
    var notes: [DigitMask]
    var elapsed: TimeInterval = 0
    var mistakes = 0
    /// Mistakes made while the mistake limit was in force – the only ones it counts, so turning
    /// instant checking or the limit on mid-game can't end the game for earlier mistakes.
    var limitedMistakes = 0
    /// Extra mistakes granted by "second chance".
    var extraLives = 0
    var hintsUsed = 0
    var usedAutoNotes = false
    var history: [Move] = []
    var future: [Move] = []
    var status: GameStatus = .inProgress
    /// When the game was won or lost. A loss is recorded with this date, even if recording it waits
    /// for the player to decline the second chance.
    var endedAt: Date?
    /// When the puzzle was first started; a restart keeps it (see `GameSession.restart`).
    var createdAt = Date()
    var updatedAt = Date()

    init(kind: GameKind, difficulty: Difficulty?, givens: [UInt8], solution: [UInt8]) {
        self.kind = kind
        self.difficulty = difficulty
        self.givens = givens
        self.solution = solution
        self.values = givens
        self.notes = Array(repeating: 0, count: 81)
    }

    var emptyCellsAtStart: Int { givens.count { $0 == 0 } }
    var filledCells: Int { (0..<81).count { givens[$0] == 0 && values[$0] != 0 } }

    /// Share of initially empty cells that are filled. Wrong digits count too: progress
    /// is shown in every checking mode and mustn't give mistakes away.
    var progress: Double {
        let total = emptyCellsAtStart
        return total == 0 ? 1 : Double(filledCells) / Double(total)
    }

    var hasProgress: Bool { !history.isEmpty || elapsed > 30 }
    var isSolved: Bool { values == solution }

    /// Lost on the mistake limit, with its one second chance still unused. A game that was given up
    /// shows the solution instead, so it can't be mistaken for one.
    var awaitsSecondChance: Bool { status == .lost && extraLives == 0 && !isSolved }

    /// The player can carry on with it: in progress, or lost with the second chance still open.
    var isResumable: Bool { status == .inProgress || awaitsSecondChance }
}
