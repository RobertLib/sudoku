//
//  Generator.swift
//  sudoku
//
//  Creates puzzles with a unique solution, graded by the logical solver.
//

import Foundation

/// A ready-to-play puzzle with its solution and grading.
nonisolated struct GeneratedPuzzle: Codable, Hashable, Sendable {
    var puzzle: [UInt8]
    var solution: [UInt8]
    var difficulty: Difficulty
    var rating: Rating

    var clueCount: Int { puzzle.count { $0 != 0 } }
}

nonisolated enum Generator {
    /// Generates a puzzle of the requested difficulty. Deterministic for a given generator state.
    ///
    /// Should all `maxAttempts` grids miss the difficulty (practically never with the default),
    /// it returns the closest logically solvable puzzle instead, labelled with the difficulty
    /// its rating implies (with clues added if that is easy or medium, see `fallbackPuzzle`).
    static func generate<R: RandomNumberGenerator>(
        _ difficulty: Difficulty,
        using rng: inout R,
        maxAttempts: Int = 5_000
    ) -> GeneratedPuzzle {
        var fallback: GeneratedPuzzle?
        for _ in 0..<maxAttempts {
            let solution = Solver.randomGrid(using: &rng)
            let minimal = minimalPuzzle(for: solution, using: &rng)
            let rating = LogicalSolver.rate(minimal)
            guard rating.isSolvable else { continue }

            switch difficulty {
            case .easy:
                let target = 36 + rng.nextInt(below: 5)
                if let puzzle = withAddedClues(minimal, solution: solution, target: target, level: 1, maxClues: 45, using: &rng) {
                    return GeneratedPuzzle(puzzle: puzzle.0, solution: solution, difficulty: .easy, rating: puzzle.1)
                }
            case .medium:
                let target = 29 + rng.nextInt(below: 4)
                if let puzzle = withAddedClues(minimal, solution: solution, target: target, level: 2, maxClues: 35, using: &rng) {
                    return GeneratedPuzzle(puzzle: puzzle.0, solution: solution, difficulty: .medium, rating: puzzle.1)
                }
            case .hard, .expert, .master:
                if rating.level == difficulty.maxLevel {
                    return GeneratedPuzzle(puzzle: minimal, solution: solution, difficulty: difficulty, rating: rating)
                }
            }
            if fallback.map({ isCloser(rating, than: $0.rating, to: difficulty) }) ?? true {
                fallback = honestlyLabelled(minimal, solution: solution, rating: rating)
            }
        }
        // Practically unreachable; keeps the API total. Clues are only added here, after the loop,
        // so it draws the same random numbers and every puzzle it returns (daily ones too) stays the same.
        if let fallback {
            return fallbackPuzzle(from: fallback.puzzle, solution: fallback.solution, rating: fallback.rating, using: &rng)
        }
        return lastResort(using: &rng)
    }

    /// Whether a solvable rating's level is nearer the difficulty's than `other`'s.
    /// At equal distance the easier one wins.
    private static func isCloser(_ rating: Rating, than other: Rating, to difficulty: Difficulty) -> Bool {
        let distance = abs(rating.level - difficulty.maxLevel)
        let otherDistance = abs(other.level - difficulty.maxLevel)
        return distance < otherDistance || (distance == otherDistance && rating.level < other.level)
    }

    /// A puzzle labelled with the difficulty its (solvable) rating implies.
    private static func honestlyLabelled(_ puzzle: [UInt8], solution: [UInt8], rating: Rating) -> GeneratedPuzzle {
        GeneratedPuzzle(puzzle: puzzle, solution: solution, difficulty: rating.techniqueDifficulty ?? .master, rating: rating)
    }

    /// The fallback from a new grid's minimal puzzle, which the logical solver may not solve yet.
    private static func lastResort<R: RandomNumberGenerator>(using rng: inout R) -> GeneratedPuzzle {
        let solution = Solver.randomGrid(using: &rng)
        let puzzle = minimalPuzzle(for: solution, using: &rng)
        return fallbackPuzzle(from: puzzle, solution: solution, rating: LogicalSolver.rate(puzzle), using: &rng)
    }

    /// Adds symmetric clue pairs from the solution to a minimal puzzle until it's logically
    /// solvable and, if it's then easy or medium, has as many clues as those difficulties always
    /// get (a minimal one has far fewer). Each pair can only make it easier, so it's re-rated after
    /// each one and labelled with what it takes in the end. At the latest, the full grid qualifies.
    private static func fallbackPuzzle<R: RandomNumberGenerator>(
        from puzzle: [UInt8],
        solution: [UInt8],
        rating: Rating,
        using rng: inout R
    ) -> GeneratedPuzzle {
        var puzzle = puzzle
        var rating = rating
        func isFinished() -> Bool {
            // No difficulty while it isn't solvable.
            guard let difficulty = rating.techniqueDifficulty else { return false }
            return puzzle.count { $0 != 0 } >= minimumClues(for: difficulty)
        }
        if !isFinished() {
            for cell in (0...40).filter({ puzzle[$0] == 0 }).stableShuffled(using: &rng) {
                puzzle[cell] = solution[cell]
                puzzle[80 - cell] = solution[80 - cell]
                rating = LogicalSolver.rate(puzzle)
                if isFinished() { break }
            }
        }
        return honestlyLabelled(puzzle, solution: solution, rating: rating)
    }

    /// The fewest clues `generate` gives a puzzle of the difficulty; hard and up are minimal.
    private static func minimumClues(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: 36
        case .medium: 29
        case .hard, .expert, .master: 0
        }
    }

    /// Removes clues in 180°-symmetric pairs for as long as the solution stays unique.
    static func minimalPuzzle<R: RandomNumberGenerator>(for solution: [UInt8], using rng: inout R) -> [UInt8] {
        var puzzle = solution
        for cell in Array(0...40).stableShuffled(using: &rng) {
            let mirror = 80 - cell
            let saved = (puzzle[cell], puzzle[mirror])
            puzzle[cell] = 0
            puzzle[mirror] = 0
            if Solver.countSolutions(puzzle, limit: 2) != 1 {
                puzzle[cell] = saved.0
                puzzle[mirror] = saved.1
            }
        }
        return puzzle
    }

    /// Adds symmetric clue pairs from the solution until the clue count reaches
    /// `target` and the hardest technique the puzzle needs is exactly of `level`,
    /// without ever going over `maxClues`.
    private static func withAddedClues<R: RandomNumberGenerator>(
        _ puzzle: [UInt8],
        solution: [UInt8],
        target: Int,
        level: Int,
        maxClues: Int,
        using rng: inout R
    ) -> ([UInt8], Rating)? {
        var puzzle = puzzle
        let emptyPairs = (0...40).filter { puzzle[$0] == 0 }.stableShuffled(using: &rng)
        var rating = LogicalSolver.rate(puzzle)
        var next = 0
        while true {
            let clues = puzzle.count { $0 != 0 }
            // (Rarely, the minimal puzzle alone has more clues than allowed.)
            if clues >= target && clues <= maxClues && rating.isSolvable {
                if rating.level == level { return (puzzle, rating) }
                // More clues only make it easier, so this grid can't reach the level any more.
                if rating.level < level { return nil }
            }
            guard next < emptyPairs.count else { return nil }
            let cell = emptyPairs[next]
            // The centre cell is its own mirror, so it adds a single clue.
            guard clues + (cell == 40 ? 1 : 2) <= maxClues else { return nil }
            next += 1
            puzzle[cell] = solution[cell]
            puzzle[80 - cell] = solution[80 - cell]
            if puzzle.count(where: { $0 != 0 }) >= target {
                rating = LogicalSolver.rate(puzzle)
            }
        }
    }
}

nonisolated enum PuzzleParser {
    /// Parses 81 cells from text; digits 1–9 are clues, `0`, `.`, `-`, `_` or `*` are empty.
    /// Whitespace, separators and anything else are ignored. When `-`, `_` and `*` don't add up
    /// to 81 cells, they are taken as grid lines instead (e.g. `------+-------+------`).
    ///
    /// When the whole text doesn't add up to 81 cells (say, it has a header like "Puzzle 12:"
    /// or the solution below the puzzle), it's read line by line: a line of exactly 81 cells is
    /// the puzzle, otherwise 9 consecutive lines of exactly 9 cells are its rows. Blank lines and
    /// grid lines may sit between the rows; any other line ends them. With several puzzles (e.g.
    /// puzzle and solution), the first one wins. Line by line, digits may also come from other
    /// scripts (fullwidth "５", Arabic-Indic "٥") or be keycaps ("5️⃣"), but a line with other
    /// numerals (superscripts, circled digits…) is never part of the puzzle, and only one of `-`,
    /// `_` and `*` can mark empty cells. Rather than guess which lines form the puzzle (e.g. with
    /// 10 lines of 9 cells), it returns `nil`.
    static func parse(_ text: String) -> [UInt8]? {
        if let cells = cells(in: text, emptyMarks: ".-_*") ?? cells(in: text, emptyMarks: ".") {
            return cells
        }
        let lines = text.split(whereSeparator: \.isNewline)
        // At most one of `-`, `_` and `*` marks empty cells; the others draw grid lines.
        let readings = [".", ".-", "._", ".*"].compactMap { firstPuzzle(in: lines, emptyMarks: $0) }
        guard let start = readings.map(\.line).min() else { return nil }
        let earliest = readings.filter { $0.line == start }
        guard earliest.allSatisfy({ $0.cells == earliest[0].cells }) else { return nil }
        return earliest[0].cells
    }

    private static func cells(in text: String, emptyMarks: String) -> [UInt8]? {
        var cells: [UInt8] = []
        for character in text {
            if let value = character.wholeNumberValue, (0...9).contains(value), character.isASCII {
                cells.append(UInt8(value))
            } else if emptyMarks.contains(character) {
                cells.append(0)
            }
        }
        return cells.count == 81 ? cells : nil
    }

    /// The first line of 81 cells or run of 9-cell rows (if that run can only be read one way),
    /// with the index of the line it starts at.
    private static func firstPuzzle(in lines: [Substring], emptyMarks: String) -> (line: Int, cells: [UInt8])? {
        var rows: [[UInt8]] = []
        var start = 0
        for (index, line) in lines.enumerated() {
            let cells = cells(inLine: line, emptyMarks: emptyMarks)
            // Headers and captions end a run of rows, even if their numbers add up to 9 cells.
            let hasLetters = line.contains(where: \.isLetter)
            if let cells, cells.count == 9, !hasLetters {
                if rows.isEmpty { start = index }
                rows.append(cells)
            } else if cells?.isEmpty == true, !hasLetters {
                continue // A blank line or grid line.
            } else if !rows.isEmpty {
                break
            } else if let cells, cells.count == 81 {
                return (index, cells)
            }
        }
        // A puzzle may be followed right away by its solution, but anything else is ambiguous.
        guard !rows.isEmpty, rows.count.isMultiple(of: 9) else { return nil }
        return (start, Array(rows.prefix(9).joined()))
    }

    /// The cells of one line, or `nil` if it has numerals that aren't plain digits.
    private static func cells(inLine line: Substring, emptyMarks: String) -> [UInt8]? {
        var cells: [UInt8] = []
        for character in line {
            if let digit = digit(character) {
                cells.append(UInt8(digit))
            } else if emptyMarks.contains(character) {
                cells.append(0)
            } else if character.unicodeScalars.contains(where: { $0.properties.numericType != nil }) {
                return nil
            }
        }
        return cells
    }

    /// The value of a decimal digit of any script (a single scalar, so no superscripts or
    /// circled digits) or of a keycap emoji: an ASCII digit, an optional variation selector and U+20E3.
    private static func digit(_ character: Character) -> Int? {
        let scalars = Array(character.unicodeScalars)
        guard let first = scalars.first, first.properties.numericType == .decimal,
              let value = first.properties.numericValue
        else { return nil }
        let keycaps: [[Unicode.Scalar]] = [["\u{20E3}"], ["\u{FE0F}", "\u{20E3}"]]
        guard scalars.count == 1 || (first.isASCII && keycaps.contains(Array(scalars.dropFirst()))) else { return nil }
        return Int(value)
    }

    static func string(from cells: [UInt8]) -> String {
        String(cells.map { $0 == 0 ? "." : Character(String($0)) })
    }
}
