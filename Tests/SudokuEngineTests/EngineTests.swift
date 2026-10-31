import Foundation
import Testing
@testable import SudokuEngine

private let classicPuzzle = PuzzleParser.parse(
    "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
)!
private let classicSolution = PuzzleParser.parse(
    "534678912672195348198342567859761423426853791713924856961537284287419635345286179"
)!

/// The processor time `body` takes on this thread. Unlike wall-clock time, it doesn't grow when a busy
/// machine (e.g. CI, or tests running in parallel) leaves the thread waiting.
private func cpuTime(_ body: () -> Void) -> Duration {
    let start = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
    body()
    return .nanoseconds(Int64(clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID) - start))
}

private func isCompleteAndValid(_ cells: [UInt8]) -> Bool {
    guard cells.allSatisfy({ (1...9).contains($0) }) else { return false }
    return House.all.allSatisfy { house in
        Set(house.cells.map { cells[$0] }).count == 9
    }
}

@Suite struct GridTests {
    @Test func geometry() {
        #expect(Grid.houseCells.count == 27)
        #expect(Grid.houseCells.allSatisfy { Set($0).count == 9 })
        #expect(Grid.peers.allSatisfy { $0.count == 20 })
        #expect(Grid.housesOf[80] == [8, 17, 26])
        #expect(Grid.boxOf[40] == 4)
        for a in 0..<81 {
            for b in 0..<81 {
                #expect(Grid.sees(a, b) == Grid.sees(b, a))
            }
        }
    }

    @Test func conflictingCells() {
        #expect(Grid.conflictingCells(in: classicPuzzle).isEmpty)
        var values = classicPuzzle
        // Cell 2 repeats the 5 of cell 0 (row and box), cell 74 the 8 of cell 76 (row) and of cell 20 (column).
        values[2] = 5
        values[74] = 8
        #expect(Grid.conflictingCells(in: values) == [0, 2, 20, 74, 76])
    }

    @Test func digitMask() {
        let mask = DigitMask(digits: [1, 5, 9])
        #expect(mask.digits == [1, 5, 9])
        #expect(mask.digitCount == 3)
        #expect(mask.singleDigit == nil)
        #expect(DigitMask.digit(7).singleDigit == 7)
        #expect(Grid.allDigits.digits == Array(1...9))
    }

    @Test func parser() {
        #expect(PuzzleParser.parse("1.2") == nil)
        let text = PuzzleParser.string(from: classicPuzzle)
        #expect(text.count == 81)
        #expect(PuzzleParser.parse(text) == classicPuzzle)
        let spaced = text.map { "\($0) " }.joined()
        #expect(PuzzleParser.parse(spaced) == classicPuzzle)
        #expect(PuzzleParser.parse(text.replacing(".", with: "-")) == classicPuzzle)
    }

    @Test func parserSkipsGridLines() {
        let rows = (0..<9).map { row in
            let cells = classicPuzzle[(row * 9)..<(row * 9 + 9)].map { $0 == 0 ? "." : String($0) }
            return (0..<3).map { cells[($0 * 3)..<($0 * 3 + 3)].joined(separator: " ") }
        }
        // As printed by many sites and books.
        let ascii = rows.enumerated().map { index, boxes in
            (index % 3 == 0 && index > 0 ? "------+-------+------\n" : "") + boxes.joined(separator: " | ")
        }.joined(separator: "\n")
        #expect(PuzzleParser.parse(ascii) == classicPuzzle)

        // As exported by HoDoKu and SudokuWiki.
        let compact = rows.enumerated().map { index, boxes in
            (index % 3 == 0 && index > 0 ? "|---+---+---|\n" : "") + "|" + boxes.map { $0.replacing(" ", with: "") }.joined(separator: "|") + "|"
        }.joined(separator: "\n")
        #expect(PuzzleParser.parse("*-----------*\n" + compact + "\n*-----------*") == classicPuzzle)
    }

    /// A grid's rows as text, with empty cells drawn as `empty`.
    private func rows(_ cells: [UInt8], empty: String = ".") -> [String] {
        (0..<9).map { row in cells[(row * 9)..<(row * 9 + 9)].map { $0 == 0 ? empty : String($0) }.joined() }
    }

    @Test func parserReadsLineByLine() {
        let line = PuzzleParser.string(from: classicPuzzle)
        let solutionLine = PuzzleParser.string(from: classicSolution)
        // Headers with digits or dots.
        #expect(PuzzleParser.parse("Puzzle 12:\n" + line) == classicPuzzle)
        #expect(PuzzleParser.parse("Puzzle 12:\n" + rows(classicPuzzle).joined(separator: "\n")) == classicPuzzle)
        #expect(PuzzleParser.parse("No. 5\n" + line) == classicPuzzle)
        #expect(PuzzleParser.parse("No. 5\r\n" + rows(classicPuzzle).joined(separator: "\r\n")) == classicPuzzle)
        // `_` empties between `---+---+---` lines.
        let underscores = rows(classicPuzzle, empty: "_").enumerated().map { index, row in
            (index % 3 == 0 && index > 0 ? "---+---+---\n" : "") + row
        }
        #expect(PuzzleParser.parse(underscores.joined(separator: "\n")) == classicPuzzle)
        // `*` empties inside a HoDoKu border.
        let stars = rows(classicPuzzle, empty: "*").map { "|" + $0 + "|" }
        #expect(PuzzleParser.parse("*-----------*\n" + stars.joined(separator: "\n") + "\n*-----------*") == classicPuzzle)
        // Blank lines between the bands.
        let banded = rows(classicPuzzle).enumerated().map { index, row in (index % 3 == 0 && index > 0 ? "\n" : "") + row }
        #expect(PuzzleParser.parse("Puzzle 3\n" + banded.joined(separator: "\n")) == classicPuzzle)
        // Puzzle and solution: the first one wins.
        #expect(PuzzleParser.parse(line + "\n" + solutionLine) == classicPuzzle)
        #expect(PuzzleParser.parse(rows(classicPuzzle).joined(separator: "\n") + "\n\n" + rows(classicSolution).joined(separator: "\n")) == classicPuzzle)
        #expect(PuzzleParser.parse("Puzzle\n" + underscores.joined(separator: "\n") + "\nSolution\n" + rows(classicSolution).joined(separator: "\n")) == classicPuzzle)
        #expect(PuzzleParser.parse("Solution\n" + solutionLine + "\nPuzzle\n" + line) == classicSolution)
    }

    @Test func parserReadsOtherDigits() {
        let line = PuzzleParser.string(from: classicPuzzle)
        func mapped(_ transform: (Int) -> String) -> String {
            classicPuzzle.map { $0 == 0 ? "." : transform(Int($0)) }.joined()
        }
        let fullwidth = mapped { String(UnicodeScalar(0xFF10 + $0)!) }
        let arabicIndic = mapped { String(UnicodeScalar(0x0660 + $0)!) }
        let keycaps = mapped { "\($0)\u{FE0F}\u{20E3}" }
        #expect(PuzzleParser.parse(fullwidth) == classicPuzzle)
        #expect(PuzzleParser.parse(arabicIndic) == classicPuzzle)
        #expect(PuzzleParser.parse(keycaps) == classicPuzzle)
        #expect(PuzzleParser.parse("１" + line.dropFirst()) == PuzzleParser.parse("1" + line.dropFirst()))
        #expect(PuzzleParser.parse("٣" + line.dropFirst()) == PuzzleParser.parse("3" + line.dropFirst()))
        #expect(PuzzleParser.parse("1️⃣" + line.dropFirst()) == PuzzleParser.parse("1" + line.dropFirst()))
        #expect(PuzzleParser.parse("0️⃣" + line.dropFirst()) == PuzzleParser.parse("." + line.dropFirst()))
        // Superscript and circled digits aren't read as clues, nor do they let the line count as the puzzle.
        let superscripts = ["⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹"]
        let circled = ["⓪", "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨"]
        #expect(PuzzleParser.parse(mapped { superscripts[$0] }) == nil)
        #expect(PuzzleParser.parse(mapped { circled[$0] }) == nil)
        #expect(PuzzleParser.parse("¹" + line.dropFirst()) == nil)
        #expect(PuzzleParser.parse("①" + line.dropFirst()) == nil)
    }

    @Test func parserRejectsAmbiguousText() {
        let puzzleRows = rows(classicPuzzle)
        #expect(PuzzleParser.parse("Puzzle 1\n" + puzzleRows.dropLast().joined(separator: "\n")) == nil)
        #expect(PuzzleParser.parse("Puzzle 1\n" + (puzzleRows + [puzzleRows[0]]).joined(separator: "\n")) == nil)
        // A column header can't be told from a row.
        #expect(PuzzleParser.parse("123456789\n" + puzzleRows.joined(separator: "\n")) == nil)
        // `-` empties between `---+---+---` lines: which lines are rows?
        let dashes = rows(classicPuzzle, empty: "-").enumerated().map { index, row in
            (index % 3 == 0 && index > 0 ? "---+---+---\n" : "") + row
        }
        #expect(PuzzleParser.parse(dashes.joined(separator: "\n")) == nil)
    }
}

@Suite struct SolverTests {
    @Test func solvesClassicPuzzle() {
        #expect(Solver.countSolutions(classicPuzzle) == 1)
        #expect(Solver.uniqueSolution(classicPuzzle) == classicSolution)
    }

    @Test func detectsMultipleAndNoSolutions() {
        #expect(Solver.countSolutions(.init(repeating: 0, count: 81)) == 2)
        var broken = classicPuzzle
        broken[2] = 5 // duplicate 5 in row 0
        #expect(Solver.countSolutions(broken) == 0)
        #expect(!Solver.isConsistent(broken))
        // No limit left to reach, even for a grid that propagation alone solves.
        #expect(Solver.countSolutions(classicPuzzle, limit: 0) == 0)
        #expect(Solver.countSolutions(.init(repeating: 0, count: 81), limit: -1) == 0)
    }

    @Test func randomGridIsValidAndDeterministic() {
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        let gridA = Solver.randomGrid(using: &a)
        #expect(isCompleteAndValid(gridA))
        #expect(gridA == Solver.randomGrid(using: &b))
        // Daily challenges are generated from these grids, so they must never change.
        var c = SeededGenerator(seed: 2026)
        #expect(PuzzleParser.string(from: Solver.randomGrid(using: &c)) == "473926158965318247182475963517692384698743521324851796246537819831269475759184632")
    }

    @Test func fastOnSparseGrids() {
        // None of these has a solution, which took plain backtracking up to 20 s to find out.
        let grids = [
            "...4.....9.....3.....8.........8...3.8....7...5........1..9....592....8..7.3.....",
            "62...1......56.2...7.3......................2..6...1...17...........7.6....8.6...",
            "9.7.23.....3...8....1.972.................................321......79.2..12......",
            "....2......486........3..2..32...6.....9.5..........5..61..........9.3...7.......",
            ".......4...76......21....9..................7.8394......6....8.5...8.......4...3.",
            ".5........6.....92.9...46.........79............21...4..1..........9.5.62........",
        ]
        let elapsed = cpuTime {
            for grid in grids {
                let puzzle = PuzzleParser.parse(grid)!
                #expect(Solver.countSolutions(puzzle) == 0, "\(grid)")
                #expect(Solver.solve(puzzle) == nil)
            }
        }
        // Milliseconds in a release build; generous for debug builds.
        #expect(elapsed < .seconds(3))
    }

    /// Plain backtracking over the most constrained cell, to check counts against.
    private func referenceCount(_ cells: inout [UInt8], limit: Int) -> Int {
        var bestCell = -1
        var bestDigits: [UInt8] = []
        for cell in 0..<81 where cells[cell] == 0 {
            let used = Set(Grid.peers[cell].map { cells[$0] })
            let digits = (1...9).map(UInt8.init).filter { !used.contains($0) }
            if bestCell < 0 || digits.count < bestDigits.count {
                bestCell = cell
                bestDigits = digits
            }
        }
        guard bestCell >= 0 else { return 1 }
        var count = 0
        for digit in bestDigits where count < limit {
            cells[bestCell] = digit
            count += referenceCount(&cells, limit: limit - count)
        }
        cells[bestCell] = 0
        return count
    }

    @Test func countsMatchPlainBacktracking() throws {
        var rng = SeededGenerator(seed: 81)
        for index in 0..<40 {
            let solution = Solver.randomGrid(using: &rng)
            var puzzle = solution
            // From nearly full to sparse enough for the thorough pass.
            for cell in Array(0..<81).stableShuffled(using: &rng).prefix(30 + index) { puzzle[cell] = 0 }
            let limit = 300
            var cells = puzzle
            let expected = referenceCount(&cells, limit: limit)
            #expect(Solver.countSolutions(puzzle, limit: limit) == expected)
            let solved = try #require(Solver.solve(puzzle))
            #expect(isCompleteAndValid(solved))
            #expect((0..<81).allSatisfy { puzzle[$0] == 0 || puzzle[$0] == solved[$0] })
            #expect(Solver.uniqueSolution(puzzle) == (expected == 1 ? solution : nil))
        }
        // An empty grid has far more solutions than any limit.
        #expect(Solver.countSolutions(.init(repeating: 0, count: 81), limit: 300) == 300)
    }

    @Test func cancelledSearchStopsEarly() async {
        let empty = [UInt8](repeating: 0, count: 81)
        // Counting all solutions of an empty grid would never finish.
        let preCancelled = await Task.detached {
            withUnsafeCurrentTask { $0?.cancel() }
            return cpuTime { _ = Solver.countSolutions(empty, limit: .max) }
        }.value
        #expect(preCancelled < .seconds(1))

        let search = Task.detached { _ = Solver.countSolutions(empty, limit: .max) }
        try? await Task.sleep(for: .milliseconds(50))
        let cancelled = ContinuousClock.now
        search.cancel()
        await search.value
        // Without the cancellation it would never end; the margin is for a busy machine's scheduling.
        #expect(ContinuousClock.now - cancelled < .seconds(10))
    }
}

@Suite struct LogicalSolverTests {
    /// A deduction found in `solver`'s position must agree with the known solution, and change the
    /// position (or solving would never end).
    private func expectSound(_ step: LogicStep, in solver: LogicalSolver, solution: [UInt8], puzzle: [UInt8]) {
        for elimination in step.eliminations {
            #expect(
                Int(solution[elimination.cell]) != elimination.digit,
                "\(step.technique) wrongly eliminated \(elimination.digit) from r\(elimination.cell / 9 + 1)c\(elimination.cell % 9 + 1) in \(PuzzleParser.string(from: puzzle))"
            )
            #expect(solver.has(elimination.cell, elimination.digit), "\(step.technique) eliminated a missing candidate")
        }
        if let placement = step.placement {
            #expect(
                Int(solution[placement.cell]) == placement.digit,
                "\(step.technique) placed a wrong digit in \(PuzzleParser.string(from: puzzle))"
            )
            #expect(solver.has(placement.cell, placement.digit), "\(step.technique) placed a missing candidate")
        }
        #expect(step.placement != nil || !step.eliminations.isEmpty, "\(step.technique) found nothing to do")
    }

    /// Every deduction must agree with the known solution.
    private func assertSound(_ puzzle: [UInt8], solution: [UInt8]) -> Set<Technique> {
        var solver = LogicalSolver(values: puzzle)
        var used: Set<Technique> = []
        while !solver.isSolved, let step = solver.nextStep() {
            used.insert(step.technique)
            expectSound(step, in: solver, solution: solution, puzzle: puzzle)
            solver.apply(step)
        }
        return used
    }

    /// The app draws a step on the position it was found in (`values` and `candidates`, as a
    /// `HintEntry` keeps them) and explains it by the houses, cells and digits it names, so they
    /// must fit that position and the deduction.
    private func expectExplained(_ step: LogicStep, values: [UInt8], candidates: [DigitMask]) {
        let technique = step.technique
        func has(_ candidate: Candidate) -> Bool {
            values[candidate.cell] == 0 && candidates[candidate.cell].contains(digit: candidate.digit)
        }
        func places(of digits: [Int], in houses: [House]) -> Set<Int> {
            Set(houses.flatMap(\.cells).filter { cell in digits.contains { has(Candidate(cell, $0)) } })
        }
        // Everything marked is on the board before the step.
        let marked = step.eliminations + step.patternCandidates + step.alternateCandidates + [step.placement].compactMap { $0 }
        #expect(marked.allSatisfy(has), "\(technique) marks a candidate the position doesn't have")
        #expect(step.cells.allSatisfy { values[$0] == 0 }, "\(technique) highlights a filled cell")
        let cells = Set(step.cells)
        let patternCells = Set((step.patternCandidates + step.alternateCandidates).map(\.cell))
        #expect(patternCells.isSubset(of: cells), "\(technique) marks candidates outside its pattern")
        if let placement = step.placement {
            #expect(step.cells == [placement.cell] && step.digits == [placement.digit], "\(technique)")
            #expect(step.houses.allSatisfy { $0.cells.contains(placement.cell) }, "\(technique) names a house without its cell")
        } else {
            // Each pattern cell shows its part: candidates of the pattern, or ones it loses.
            let shown = patternCells.union(step.eliminations.map(\.cell))
            #expect(cells.isSubset(of: shown), "\(technique) highlights a cell without its candidates")
        }
        // Candidates go where the text says: from the houses it names, or from cells seeing both ends.
        let named = Set((step.houses + step.secondaryHouses).flatMap(\.cells))
        let isHidden = [Technique.hiddenPair, .hiddenTriple, .hiddenQuad].contains(technique)
        for elimination in step.eliminations {
            // Hidden subsets remove all digits but theirs, other steps the ones they're about.
            #expect(step.digits.contains(elimination.digit) != isHidden, "\(technique) removes the wrong digit")
            if !step.endpoints.isEmpty {
                let seesEnds = step.endpoints.allSatisfy { Grid.sees($0, elimination.cell) }
                #expect(seesEnds || step.endpoints == [elimination.cell], "\(technique) removes a candidate not seeing its ends")
            } else if !step.houses.isEmpty {
                #expect(named.contains(elimination.cell), "\(technique) removes a candidate outside its houses")
            }
        }

        let digit = step.digits.first ?? 0
        switch technique {
        case .fullHouse, .hiddenSingle:
            // "In box 3, the number 5 fits in only one cell."
            #expect(step.houses.count == 1 && places(of: [digit], in: step.houses) == cells, "\(technique)")
            if technique == .fullHouse {
                #expect(step.houses.allSatisfy { $0.cells.filter { values[$0] == 0 } == step.cells }, "not the last empty cell")
            }
        case .nakedSingle:
            #expect(step.cells.allSatisfy { candidates[$0] == .digit(digit) }, "not the only candidate")
        case .pointing, .claiming:
            // "In box 2, the number 4 can only be in row 1, so it can be removed from the rest of that
            // row", and the other way round for claiming.
            let source = step.houses, target = step.secondaryHouses
            let (boxes, lines) = technique == .pointing ? (source, target) : (target, source)
            #expect(boxes.map(\.kind) == [.box] && lines.count == 1 && !lines.contains { $0.kind == .box }, "\(technique)")
            #expect(places(of: [digit], in: source) == cells, "\(technique)")
            #expect(cells.isSubset(of: places(of: [digit], in: target)), "\(technique)")
            #expect(Set(source.flatMap(\.cells)).isDisjoint(with: step.eliminations.map(\.cell)), "\(technique)")
            #expect(Set(step.patternCandidates) == Set(step.cells.map { Candidate($0, digit) }), "\(technique)")
        case .nakedPair, .nakedTriple, .nakedQuad, .hiddenPair, .hiddenTriple, .hiddenQuad:
            // "Cells R1C2 and R1C5 in row 1 can only contain 3 and 8" or "In row 1, the numbers 3 and 8
            // can only go in cells R1C2 and R1C5"; the pattern is just those digits in those cells.
            #expect(step.houses.count == 1 && step.cells.count == step.digits.count && cells.isSubset(of: named), "\(technique)")
            if isHidden {
                #expect(places(of: step.digits, in: step.houses) == cells, "\(technique)")
                #expect(step.eliminations.allSatisfy { cells.contains($0.cell) }, "\(technique)")
            } else {
                #expect(step.cells.reduce(0) { $0 | candidates[$1] } == DigitMask(digits: step.digits), "\(technique)")
                #expect(!step.eliminations.contains { cells.contains($0.cell) }, "\(technique)")
            }
            let subset = step.cells.flatMap { cell in step.digits.map { Candidate(cell, $0) } }.filter(has)
            #expect(Set(step.patternCandidates) == Set(subset), "\(technique) pattern isn't its digits in its cells")
        case .xWing, .swordfish, .jellyfish:
            // "In rows 2 and 6, the number 7 can only be in columns 4 and 8. It can be removed from all
            // other cells of those columns."
            let base = step.houses, cover = step.secondaryHouses
            let rowsAreBase = base.first?.kind == .row
            #expect(base.allSatisfy { $0.kind == (rowsAreBase ? .row : .column) }, "\(technique)")
            #expect(cover.allSatisfy { $0.kind == (rowsAreBase ? .column : .row) } && cover.count == base.count, "\(technique)")
            #expect(places(of: [digit], in: base) == cells, "\(technique)")
            #expect(cells.isSubset(of: places(of: [digit], in: cover)), "\(technique)")
            #expect(Set(base.flatMap(\.cells)).isDisjoint(with: step.eliminations.map(\.cell)), "\(technique)")
        default:
            break
        }
    }

    @Test func classicPuzzleIsEasy() {
        let rating = LogicalSolver.rate(classicPuzzle)
        #expect(rating.isSolvable)
        #expect(rating.level == 1)
        _ = assertSound(classicPuzzle, solution: classicSolution)
    }

    @Test func soundOnManyRandomPuzzles() {
        var rng = SeededGenerator(seed: 2026)
        var used: [Technique: Int] = [:]
        var unsolved = 0
        let count = 400
        for _ in 0..<count {
            let solution = Solver.randomGrid(using: &rng)
            let puzzle = Generator.minimalPuzzle(for: solution, using: &rng)
            for technique in assertSound(puzzle, solution: solution) {
                used[technique, default: 0] += 1
            }
            if !LogicalSolver.rate(puzzle).isSolvable { unsolved += 1 }
        }
        print("Technique usage over \(count) minimal puzzles (unsolved: \(unsolved)):")
        for technique in Technique.allCases {
            print("  \(technique.rawValue): \(used[technique, default: 0])")
        }
        // Common techniques must actually be exercised by this sample.
        for technique: Technique in [.hiddenSingle, .nakedSingle, .pointing, .claiming, .nakedPair, .hiddenPair, .xWing, .xyWing, .xChain] {
            #expect(used[technique, default: 0] > 0, "\(technique) never used")
        }
    }

    @Test func soundWithPartialNotes() {
        // Remove random wrong candidates (as a player's notes would), then follow the hints to the
        // end, now and then removing another one, and make sure every deduction stays correct.
        var rng = SeededGenerator(seed: 28)
        var used: Set<Technique> = []
        func removeWrongNote(from notes: inout [DigitMask], solution: [UInt8]) {
            let cell = rng.nextInt(below: 81)
            let wrong = notes[cell].digits.filter { $0 != Int(solution[cell]) }
            guard !wrong.isEmpty else { return }
            notes[cell] &= ~DigitMask.digit(wrong[rng.nextInt(below: wrong.count)])
        }
        for _ in 0..<60 {
            let solution = Solver.randomGrid(using: &rng)
            let puzzle = Generator.minimalPuzzle(for: solution, using: &rng)
            var values = puzzle
            var notes = LogicalSolver.basicCandidates(for: puzzle)
            // Only a few: each removed note is extra information, and many leave nothing but singles.
            for _ in 0..<5 { removeWrongNote(from: &notes, solution: solution) }
            while values.contains(0) {
                let plan = LogicalSolver.hintPlan(values: values, candidates: notes)
                guard !plan.isEmpty else { break }
                var solver = LogicalSolver(values: values, candidates: notes)
                for entry in plan {
                    used.insert(entry.step.technique)
                    expectSound(entry.step, in: solver, solution: solution, puzzle: puzzle)
                    solver.apply(entry.step)
                }
                values = solver.values
                notes = solver.candidates
                if rng.nextInt(below: 8) == 0 { removeWrongNote(from: &notes, solution: solution) }
            }
        }
        // The hints must get past singles, up to the uniqueness-based techniques, which are only
        // sound because the notes still hold the solution.
        for level in 2...5 {
            #expect(used.contains { $0.level == level }, "no technique of level \(level) used")
        }
        #expect(used.contains(.uniqueRectangle) && used.contains(.bugPlusOne))
    }

    /// Cases a random sample small enough for debug builds would cover only by luck.
    private static let handPickedPuzzles = [
        // Solving this, every technique finds a step in some position. BUG+1 does in only about
        // one minimal puzzle out of 50.
        "..72.6.3.98.....6..2...3.78..9.6.......814.......5.4..23.6...8..9.....46.6.5.82..",
        // Has rectangles that look like Unique Rectangles but span four boxes: swapping their
        // digits would break the boxes, so they prove nothing.
        "....7.2.69.6..1..4....3..7.1.....6.....5.2.....4.....8.1..2....4..8..3.57.9.6....",
    ]

    @Test func everyFinderIsSoundInEveryPosition() throws {
        // `nextStep` only runs a technique when all simpler ones fail. Running every finder in
        // every position checks each technique (and how it's explained) against far more patterns.
        var rng = SeededGenerator(seed: 99)
        var puzzles = try Self.handPickedPuzzles.map { try #require(PuzzleParser.parse($0)) }
        for _ in 0..<8 {
            puzzles.append(Generator.minimalPuzzle(for: Solver.randomGrid(using: &rng), using: &rng))
        }
        var found: [Technique: Int] = [:]
        for puzzle in puzzles {
            let solution = try #require(Solver.uniqueSolution(puzzle))
            var solver = LogicalSolver(values: puzzle)
            while !solver.isSolved {
                for technique in Technique.allCases {
                    guard let step = solver.findStep(using: technique) else { continue }
                    #expect(step.technique == technique)
                    expectSound(step, in: solver, solution: solution, puzzle: puzzle)
                    expectExplained(step, values: solver.values, candidates: solver.candidates)
                    found[technique, default: 0] += 1
                }
                guard let step = solver.nextStep() else { break }
                solver.apply(step)
            }
        }
        for technique in Technique.allCases {
            #expect(found[technique, default: 0] > 0, "\(technique) never found a step")
        }
    }

    @Test func hintPlanEndsWithPlacement() throws {
        let plan = LogicalSolver.hintPlan(values: classicPuzzle, candidates: LogicalSolver.basicCandidates(for: classicPuzzle))
        let placement = try #require(plan.last?.step.placement)
        #expect(Int(classicSolution[placement.cell]) == placement.digit)
    }

    @Test func hintEntriesShowThePositionBeforeTheirStep() {
        // The app draws each step of a hint on the board stored with it, so that must be the
        // position the step was found in: the hint's earlier steps applied, but not this one.
        var rng = SeededGenerator(seed: 6)
        var used: Set<Technique> = []
        for _ in 0..<30 {
            let solution = Solver.randomGrid(using: &rng)
            var solver = LogicalSolver(values: Generator.minimalPuzzle(for: solution, using: &rng))
            while !solver.isSolved {
                let plan = LogicalSolver.hintPlan(values: solver.values, candidates: solver.candidates)
                for entry in plan {
                    #expect(entry.values == solver.values && entry.candidates == solver.candidates, "\(entry.step.technique)")
                    expectExplained(entry.step, values: entry.values, candidates: entry.candidates)
                    used.insert(entry.step.technique)
                    solver.apply(entry.step)
                }
                guard plan.last?.step.placement != nil else { break }
            }
        }
        for technique: Technique in [.fullHouse, .hiddenSingle, .nakedSingle, .pointing, .claiming, .nakedPair, .hiddenPair] {
            #expect(used.contains(technique), "\(technique) never used")
        }
    }

    @Test func hintsIgnoreNotesOfPlacedDigits() {
        // The app passes the player's notes as they are, and all digits for a cell without any.
        // Unless the settings remove them, notes still hold the digits placed in a peer since they
        // were written. The hints must take those as ruled out.
        var rng = SeededGenerator(seed: 12)
        for _ in 0..<20 {
            let solution = Solver.randomGrid(using: &rng)
            let puzzle = Generator.minimalPuzzle(for: solution, using: &rng)
            var values = puzzle
            var notes = [DigitMask](repeating: 0, count: 81)
            while values.contains(0) {
                let passed = notes.map { $0 == 0 ? Grid.allDigits : $0 }
                let allowed = LogicalSolver.basicCandidates(for: values)
                var solver = LogicalSolver(values: values, candidates: passed)
                #expect(solver.candidates == (0..<81).map { passed[$0] & allowed[$0] })
                let plan = LogicalSolver.hintPlan(values: values, candidates: passed)
                for entry in plan {
                    let allowed = LogicalSolver.basicCandidates(for: entry.values)
                    #expect((0..<81).allSatisfy { entry.candidates[$0] & ~allowed[$0] == 0 }, "\(entry.step.technique)")
                    expectSound(entry.step, in: solver, solution: solution, puzzle: puzzle)
                    // The player notes what the hint worked out, then places the digit without
                    // removing it from the notes of its peers.
                    if entry.step.placement != nil { notes = solver.candidates }
                    solver.apply(entry.step)
                }
                guard let placement = plan.last?.step.placement else { break }
                notes[placement.cell] = 0
                values = solver.values
            }
        }
    }

    @Test func basicCandidatesRespectPeers() {
        let candidates = LogicalSolver.basicCandidates(for: classicPuzzle)
        // r1c3 (index 2) sees 5, 3, 7 in its row, 8 in its column and 6, 9 in its box.
        #expect(candidates[2] == DigitMask(digits: [1, 2, 4]))
        #expect(candidates[0] == 0, "filled cells have no candidates")
        for cell in 0..<81 where classicPuzzle[cell] == 0 {
            #expect(candidates[cell].contains(digit: Int(classicSolution[cell])))
        }
    }

    @Test func hintPlanIsEmptyForSolvedBoard() {
        let plan = LogicalSolver.hintPlan(values: classicSolution, candidates: .init(repeating: 0, count: 81))
        #expect(plan.isEmpty)
    }

    @Test func everyTechniqueHasAConsistentLevel() {
        for technique in Technique.allCases {
            #expect((1...5).contains(technique.level))
            #expect(technique.difficulty.maxLevel == technique.level)
        }
        // Techniques are tried in order of difficulty, so a rating never overstates a puzzle.
        let levels = Technique.allCases.map(\.level)
        #expect(levels == levels.sorted())
    }

    @Test func chainLinksUseTheLinkingDigit() {
        var rng = SeededGenerator(seed: 4242)
        var checked: [Technique: Int] = [:]
        for _ in 0..<600 {
            let solution = Solver.randomGrid(using: &rng)
            var solver = LogicalSolver(values: Generator.minimalPuzzle(for: solution, using: &rng))
            while !solver.isSolved, let step = solver.nextStep() {
                defer { solver.apply(step) }
                guard !step.chain.isEmpty else { continue }
                checked[step.technique, default: 0] += 1
                #expect(step.chainDigits.count == step.chain.count - 1, "\(step.technique)")
                for (index, digit) in step.chainDigits.enumerated() {
                    #expect(solver.has(step.chain[index], digit) && solver.has(step.chain[index + 1], digit), "\(step.technique)")
                }
                switch step.technique {
                case .xyWing, .xyzWing:
                    // Wings are tied to the pivot by their other digit, never by the eliminated one.
                    #expect(!step.chainDigits.contains(step.eliminations[0].digit))
                case .xyChain:
                    // Each cell is entered by one of its two digits and left by the other.
                    for index in 1..<(step.chain.count - 1) {
                        let cell = step.chain[index]
                        #expect(DigitMask(digits: step.chainDigits[(index - 1)...index]) == solver.candidates[cell])
                    }
                    let start = step.chain[0], z = step.digits[0]
                    #expect(step.chainDigits[0] == (solver.candidates[start] & ~DigitMask.digit(z)).singleDigit)
                default:
                    break
                }
            }
        }
        for technique: Technique in [.skyscraper, .twoStringKite, .xyWing, .xyzWing, .wWing, .xyChain] {
            #expect(checked[technique, default: 0] > 0, "\(technique) never checked")
        }
    }

    @Test func knownXWing() throws {
        // Standard X-Wing example: in rows 2 and 6, the 7 can only be in columns 4 and 8.
        let puzzle = PuzzleParser.parse(
            "100000569492056108056109240009640801064010000218035604040500016905061402621000005"
        )!
        let solution = try #require(Solver.uniqueSolution(puzzle))
        let step = try #require(LogicalSolver(values: puzzle).findStep(using: .xWing))
        #expect(step.digits == [7])
        #expect(step.houses == [.row(1), .row(5)])
        #expect(step.secondaryHouses == [.column(3), .column(7)])
        #expect(!step.eliminations.isEmpty)
        for elimination in step.eliminations {
            #expect(Int(solution[elimination.cell]) != elimination.digit)
        }
    }
}

@Suite struct GeneratorTests {
    @Test(arguments: Difficulty.allCases)
    func generatesRequestedDifficulty(_ difficulty: Difficulty) {
        var rng = SeededGenerator(seed: UInt64(difficulty.order) * 1_000 + 1)
        for _ in 0..<3 {
            let start = Date()
            let generated = Generator.generate(difficulty, using: &rng)
            let elapsed = Date().timeIntervalSince(start)
            print("\(difficulty): \(generated.clueCount) clues, hardest \(generated.rating.hardestTechnique?.rawValue ?? "-"), score \(generated.rating.score), \(String(format: "%.3f", elapsed)) s")
            #expect(Solver.countSolutions(generated.puzzle) == 1)
            #expect(Solver.uniqueSolution(generated.puzzle) == generated.solution)
            #expect(generated.rating.isSolvable)
            // Every difficulty needs a technique of its own level, not just fewer clues.
            #expect(generated.rating.level == difficulty.maxLevel)
            switch difficulty {
            case .easy:
                #expect((36...45).contains(generated.clueCount))
            case .medium:
                #expect((29...35).contains(generated.clueCount))
            case .hard, .expert, .master:
                break
            }
            for cell in 0..<81 where generated.puzzle[cell] != 0 {
                #expect(generated.puzzle[cell] == generated.solution[cell])
                #expect((generated.puzzle[80 - cell] != 0), "puzzle should be symmetric")
            }
        }
    }

    @Test func deterministicForSeed() {
        var a = SeededGenerator(seed: 20261031)
        var b = SeededGenerator(seed: 20261031)
        #expect(Generator.generate(.hard, using: &a) == Generator.generate(.hard, using: &b))
    }

    /// Daily challenges are generated from a seed, so a change to the generator or the logical
    /// solver (whose ratings decide which grids are kept) must never alter these by accident. If a
    /// change does on purpose, update the strings – every player then gets new daily puzzles.
    @Test(arguments: [
        (Difficulty.easy, UInt64(29), "87.6..125.....879.6...1.43...714....5..9.6..7....253...81.7...2.528.....496..2.71"),
        (.medium, 19, "..1..7.3..256.8.1.7..9..2...7816.....5.....6.....5287...2..1..8.1.7.465..4.5..1.."),
        (.hard, 8, "...7..5.6..768.2...5.4...7......2..5..5...3..3..1......4...7.6...2.638..1.6..8..."),
        (.expert, 23, "25.13.9......4..7.8...5...2.9....3....17.52....6....5.1...2...3.4..7......2.94.18"),
        (.master, 2, "71...465.....79.212.....3...7..5......28.79......9..6...6.....282.94.....516...48"),
        (.master, 21, ".....63.7....1.48273..9.6.......3.6..18...75..5.9.......9.3..41543.8....8.12....."),
    ])
    func generatedPuzzlesStayTheSame(difficulty: Difficulty, seed: UInt64, puzzle: String) {
        var rng = SeededGenerator(seed: seed)
        let generated = Generator.generate(difficulty, using: &rng)
        #expect(PuzzleParser.string(from: generated.puzzle) == puzzle)
        #expect(generated.difficulty == difficulty)
    }

    @Test func neverExceedsClueCap() {
        // This used to end at 36 clues, one symmetric pair over the cap (as did seeds 4965990 and 19980414).
        var rng = SeededGenerator(seed: 4_142_414)
        let generated = Generator.generate(.medium, using: &rng)
        #expect((29...35).contains(generated.clueCount))
        #expect(generated.rating.level == 2)
    }

    @Test(arguments: Difficulty.allCases)
    func fallbackIsHonest(_ difficulty: Difficulty) {
        var missed = 0
        var easyFallbacks = 0
        for maxAttempts in [0, 1, 2] {
            for seed in 0..<6 {
                var rng = SeededGenerator(seed: UInt64(seed * 10 + maxAttempts))
                let generated = Generator.generate(difficulty, using: &rng, maxAttempts: maxAttempts)
                #expect(Solver.uniqueSolution(generated.puzzle) == generated.solution)
                #expect(generated.rating == LogicalSolver.rate(generated.puzzle))
                #expect(generated.rating.isSolvable)
                // Labelled with what it takes, whatever was asked for.
                #expect(generated.difficulty == generated.rating.techniqueDifficulty)
                // With as many clues as its difficulty always has, though a fallback starts out minimal.
                switch generated.difficulty {
                case .easy:
                    #expect((36...45).contains(generated.clueCount))
                case .medium:
                    #expect((29...35).contains(generated.clueCount))
                case .hard, .expert, .master:
                    break
                }
                for cell in 0..<81 where generated.puzzle[cell] != 0 {
                    #expect(generated.puzzle[cell] == generated.solution[cell])
                    #expect(generated.puzzle[80 - cell] != 0)
                }
                if generated.difficulty != difficulty { missed += 1 }
                // Without attempts, there's nothing but the fallback.
                if maxAttempts == 0 && generated.difficulty <= .medium { easyFallbacks += 1 }
            }
        }
        // So few attempts must miss now and then, or the fallback went untested.
        #expect(missed > 0)
        #expect(easyFallbacks > 0, "the clues of easy and medium fallbacks went untested")
    }
}
