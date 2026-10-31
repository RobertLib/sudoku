//
//  Solver.swift
//  sudoku
//
//  Fast backtracking solvers (bitmasks + constraint propagation) used for
//  uniqueness checks, solving and producing random full grids.
//

import Foundation

nonisolated enum Solver {
    /// Counts solutions, stopping once `limit` is reached (so a `limit` of 0 or less counts none).
    ///
    /// The search is cooperatively cancellable: when the current task is cancelled, it returns
    /// early with a meaningless count, so callers that may be cancelled check `Task.isCancelled`
    /// before using the result. The same goes for `solve` and `uniqueSolution`.
    static func countSolutions(_ puzzle: [UInt8], limit: Int = 2) -> Int {
        // The search itself counts a grid solved by propagation alone before it checks the limit.
        guard limit > 0, var search = SolutionSearch(puzzle) else { return 0 }
        search.run(limit: limit)
        return search.found
    }

    /// The first solution found, if any.
    static func solve(_ puzzle: [UInt8]) -> [UInt8]? {
        guard var search = SolutionSearch(puzzle) else { return nil }
        search.run(limit: 1)
        return search.solution
    }

    /// The solution if the puzzle has exactly one.
    static func uniqueSolution(_ puzzle: [UInt8]) -> [UInt8]? {
        guard var search = SolutionSearch(puzzle) else { return nil }
        search.run(limit: 2)
        return search.found == 1 ? search.solution : nil
    }

    /// A random, completely filled valid grid: backtracking over the most constrained cell, trying
    /// its digits in shuffled order. Not every grid is equally likely, but the result is fully
    /// determined by the generator state.
    static func randomGrid<R: RandomNumberGenerator>(using rng: inout R) -> [UInt8] {
        var state = SearchState(.init(repeating: 0, count: 81))!
        _ = state.fillRandomly(using: &rng)
        return state.cells
    }

    /// Whether no digit appears twice in any house.
    static func isConsistent(_ cells: [UInt8]) -> Bool {
        SearchState(cells) != nil
    }
}

/// Digits used per house, and plain backtracking over the most constrained cell to fill random
/// grids. Those must stay exactly the same for a seed (daily challenges depend on them), so the
/// order of this search must never change.
private nonisolated struct SearchState {
    var cells: [UInt8]
    var rowUsed = [DigitMask](repeating: 0, count: 9)
    var columnUsed = [DigitMask](repeating: 0, count: 9)
    var boxUsed = [DigitMask](repeating: 0, count: 9)

    init?(_ puzzle: [UInt8]) {
        precondition(puzzle.count == 81)
        cells = puzzle
        for i in 0..<81 where puzzle[i] != 0 {
            let bit = DigitMask.digit(Int(puzzle[i]))
            let r = Grid.rowOf[i], c = Grid.columnOf[i], b = Grid.boxOf[i]
            if (rowUsed[r] | columnUsed[c] | boxUsed[b]) & bit != 0 { return nil }
            rowUsed[r] |= bit
            columnUsed[c] |= bit
            boxUsed[b] |= bit
        }
    }

    /// Picks the empty cell with the fewest options. Returns `nil` cell when solved,
    /// and `mask == 0` when a dead end was found.
    private func mostConstrainedCell() -> (cell: Int?, mask: DigitMask) {
        var best: Int?
        var bestMask: DigitMask = 0
        var bestCount = 10
        for i in 0..<81 where cells[i] == 0 {
            let mask = Grid.allDigits & ~(rowUsed[Grid.rowOf[i]] | columnUsed[Grid.columnOf[i]] | boxUsed[Grid.boxOf[i]])
            let count = mask.nonzeroBitCount
            if count < bestCount {
                if count == 0 { return (i, 0) }
                best = i
                bestMask = mask
                bestCount = count
                if count == 1 { break }
            }
        }
        return (best, bestMask)
    }

    private mutating func set(_ cell: Int, _ digit: Int) {
        let bit = DigitMask.digit(digit)
        cells[cell] = UInt8(digit)
        rowUsed[Grid.rowOf[cell]] |= bit
        columnUsed[Grid.columnOf[cell]] |= bit
        boxUsed[Grid.boxOf[cell]] |= bit
    }

    private mutating func clear(_ cell: Int, _ digit: Int) {
        let bit = ~DigitMask.digit(digit)
        cells[cell] = 0
        rowUsed[Grid.rowOf[cell]] &= bit
        columnUsed[Grid.columnOf[cell]] &= bit
        boxUsed[Grid.boxOf[cell]] &= bit
    }

    mutating func fillRandomly<R: RandomNumberGenerator>(using rng: inout R) -> Bool {
        let (cell, mask) = mostConstrainedCell()
        guard let cell else { return true }
        for digit in mask.digits.stableShuffled(using: &rng) {
            set(cell, digit)
            if fillRandomly(using: &rng) { return true }
            clear(cell, digit)
        }
        return false
    }
}

/// Exhaustive search for counting solutions. Before each guess it places naked and hidden
/// singles, and it guesses on whatever has the fewest options: the candidates of a cell or the
/// places of a digit in a house. That's all checking generated puzzles needs, but some sparse
/// grids (e.g. 17 scattered clues without a solution) would take seconds, so when this quick pass
/// runs long, it starts over thoroughly: it also removes locked candidates and whatever the empty
/// cells of a house can't jointly hold, and guesses where contradictions came up most often, so
/// it doesn't run into the same dead end again and again under unrelated guesses.
private nonisolated struct SolutionSearch {
    /// Checking generated puzzles takes a few dozen nodes at most.
    private static let quickNodeLimit = 256

    private(set) var found = 0
    private(set) var solution: [UInt8]?
    private var values: [UInt8]
    private var candidates: [DigitMask]
    /// Cells as they were before each change, so backtracking can restore them.
    private var trail: [(cell: Int, value: UInt8, candidates: DigitMask)] = []
    /// One more than the number of contradictions found in each house (see `Grid.houseCells`).
    private var houseWeights = [Int](repeating: 1, count: 27)
    private var limit = 0
    private var isThorough = false
    private var nodes = 0
    private var isCancelled = false

    init?(_ puzzle: [UInt8]) {
        guard let state = SearchState(puzzle) else { return nil }
        values = puzzle
        candidates = (0..<81).map { cell in
            guard puzzle[cell] == 0 else { return 0 }
            return Grid.allDigits & ~(state.rowUsed[Grid.rowOf[cell]] | state.columnUsed[Grid.columnOf[cell]] | state.boxUsed[Grid.boxOf[cell]])
        }
        trail.reserveCapacity(256)
    }

    mutating func run(limit: Int) {
        self.limit = limit
        search()
        guard nodes > Self.quickNodeLimit, !isCancelled else { return }
        // Every change was undone, so this starts from the puzzle again, but keeps the house weights.
        found = 0
        solution = nil
        isThorough = true
        search()
    }

    private var isStopped: Bool {
        isCancelled || (!isThorough && nodes > Self.quickNodeLimit)
    }

    private enum Outcome {
        case contradiction
        case solved
        /// Try each candidate of the cell.
        case guessCell(Int)
        /// Try each place of the digit in the house.
        case guessDigit(Int, house: Int)
    }

    private mutating func search() {
        nodes += 1
        // Checking every 256 nodes keeps it cheap, yet stops within milliseconds.
        if nodes & 0xFF == 0, Task.isCancelled { isCancelled = true }
        guard !isStopped else { return }
        let start = trail.count
        defer { undo(to: start) }
        let outcome = propagate()
        let propagated = trail.count
        switch outcome {
        case .contradiction:
            break
        case .solved:
            found += 1
            if solution == nil { solution = values }
        case .guessCell(let cell):
            var digits = candidates[cell]
            while digits != 0, found < limit, !isStopped {
                let digit = digits.trailingZeroBitCount
                digits &= digits - 1
                if place(digit, at: cell) { search() }
                undo(to: propagated)
            }
        case .guessDigit(let digit, let house):
            for cell in Grid.houseCells[house] where candidates[cell].contains(digit: digit) {
                guard found < limit, !isStopped else { break }
                if place(digit, at: cell) { search() }
                undo(to: propagated)
            }
        }
    }

    /// Makes deductions until none are left, then picks what to guess on.
    private mutating func propagate() -> Outcome {
        while true {
            // Naked singles. The quick pass would guess on the cell with the fewest candidates,
            // the thorough one on the cell whose houses weigh most per candidate.
            var progress = false
            var fewestCandidates = 10
            var bestCell = -1
            var bestCount = 0
            var bestWeight = 0
            for cell in 0..<81 where values[cell] == 0 {
                let count = candidates[cell].nonzeroBitCount
                if count == 1 {
                    guard place(candidates[cell].trailingZeroBitCount, at: cell) else { return .contradiction }
                    progress = true
                } else if count == 0 {
                    return .contradiction
                } else {
                    fewestCandidates = min(fewestCandidates, count)
                    let weight = isThorough ? weight(of: cell) : 1
                    if bestCell < 0 || weight * bestCount > bestWeight * count {
                        bestCell = cell
                        bestCount = count
                        bestWeight = weight
                    }
                }
            }
            if progress { continue }
            if bestCell < 0 { return .solved }

            // Hidden singles, and digits without a place in a house.
            var pairHouse = -1
            var pairDigit = 0
            for house in 0..<27 {
                // Digits with at least one, two and three places.
                var once: DigitMask = 0, twice: DigitMask = 0, thrice: DigitMask = 0
                var placed: DigitMask = 0
                for cell in Grid.houseCells[house] {
                    if values[cell] != 0 {
                        placed |= .digit(Int(values[cell]))
                    } else {
                        let mask = candidates[cell]
                        thrice |= twice & mask
                        twice |= once & mask
                        once |= mask
                    }
                }
                if placed | once != Grid.allDigits {
                    houseWeights[house] += 1
                    return .contradiction
                }
                var singles = once & ~twice
                while singles != 0 {
                    let digit = singles.trailingZeroBitCount
                    singles &= singles - 1
                    // An earlier single of this house may have taken the digit's only place.
                    guard let cell = Grid.houseCells[house].first(where: { candidates[$0].contains(digit: digit) }) else {
                        houseWeights[house] += 1
                        return .contradiction
                    }
                    guard place(digit, at: cell) else { return .contradiction }
                    progress = true
                }
                // A digit with two places is as good a guess as a cell with two candidates.
                let pairs = twice & ~thrice
                if pairs != 0, pairHouse < 0 || (isThorough && houseWeights[house] > houseWeights[pairHouse]) {
                    pairHouse = house
                    pairDigit = pairs.trailingZeroBitCount
                }
            }
            if progress { continue }

            if isThorough {
                switch removeLockedCandidates() {
                case nil: return .contradiction
                case true?: continue
                case false?: break
                }
                switch removeUnmatchableCandidates() {
                case nil: return .contradiction
                case true?: continue
                case false?: break
                }
            }
            if fewestCandidates > 2, pairHouse >= 0 { return .guessDigit(pairDigit, house: pairHouse) }
            return .guessCell(bestCell)
        }
    }

    private func weight(of cell: Int) -> Int {
        houseWeights[Grid.rowOf[cell]] + houseWeights[9 + Grid.columnOf[cell]] + houseWeights[18 + Grid.boxOf[cell]]
    }

    /// Removes candidates by pointing and claiming: a digit confined to one line within a box
    /// can't be elsewhere on the line, and vice versa. Returns whether candidates were removed,
    /// or `nil` if a cell ran out of them.
    private mutating func removeLockedCandidates() -> Bool? {
        var progress = false
        var segments = [DigitMask](repeating: 0, count: 27)
        for isColumn in [false, true] {
            // Segment `line * 3 + k`: the line's 3 cells in its k-th box.
            func cell(_ line: Int, _ index: Int) -> Int {
                isColumn ? index * 9 + line : line * 9 + index
            }
            for line in 0..<9 {
                for k in 0..<3 {
                    segments[line * 3 + k] = candidates[cell(line, k * 3)] | candidates[cell(line, k * 3 + 1)] | candidates[cell(line, k * 3 + 2)]
                }
            }
            for line in 0..<9 {
                let band = line / 3 * 3
                for k in 0..<3 {
                    var otherLines: DigitMask = 0
                    for other in band..<(band + 3) where other != line {
                        otherLines |= segments[other * 3 + k]
                    }
                    var otherBoxes: DigitMask = 0
                    for other in 0..<3 where other != k {
                        otherBoxes |= segments[line * 3 + other]
                    }
                    // Pointing: confined to this line within the box. Claiming: to this box within the line.
                    let pointing = segments[line * 3 + k] & ~otherLines
                    let claiming = segments[line * 3 + k] & ~otherBoxes
                    for other in 0..<3 where other != k && pointing != 0 {
                        for i in 0..<3 {
                            let target = cell(line, other * 3 + i)
                            guard candidates[target] & pointing != 0 else { continue }
                            guard eliminate(pointing, from: target) else { return nil }
                            progress = true
                        }
                    }
                    for other in band..<(band + 3) where other != line && claiming != 0 {
                        for i in 0..<3 {
                            let target = cell(other, k * 3 + i)
                            guard candidates[target] & claiming != 0 else { continue }
                            guard eliminate(claiming, from: target) else { return nil }
                            progress = true
                        }
                    }
                }
            }
            if progress { return true }
        }
        return false
    }

    /// The empty cells of a house must all get different digits. Removes the candidates no such
    /// assignment uses, which covers naked and hidden subsets of any size, and finds contradictions
    /// like four digits confined to three cells. Returns whether candidates were removed, or `nil`
    /// at a contradiction.
    private mutating func removeUnmatchableCandidates() -> Bool? {
        var cells: [Int] = []
        var masks: [DigitMask] = []
        var digitOf = [Int](repeating: 0, count: 9)
        var ownerOf = [Int](repeating: -1, count: 10)
        var reaches = [UInt16](repeating: 0, count: 9)
        var progress = false
        for house in 0..<27 {
            cells.removeAll(keepingCapacity: true)
            masks.removeAll(keepingCapacity: true)
            for cell in Grid.houseCells[house] where values[cell] == 0 {
                cells.append(cell)
                masks.append(candidates[cell])
            }
            let count = cells.count
            guard count > 1 else { continue }

            // Give every cell its own digit (a maximum bipartite matching, by augmenting paths).
            for digit in 1...9 { ownerOf[digit] = -1 }
            func assign(_ index: Int, avoiding tried: inout DigitMask) -> Bool {
                var options = masks[index] & ~tried
                while options != 0 {
                    let digit = options.trailingZeroBitCount
                    options &= options - 1
                    tried |= .digit(digit)
                    if ownerOf[digit] < 0 || assign(ownerOf[digit], avoiding: &tried) {
                        ownerOf[digit] = index
                        digitOf[index] = digit
                        return true
                    }
                }
                return false
            }
            for index in 0..<count {
                var tried: DigitMask = 0
                guard assign(index, avoiding: &tried) else {
                    houseWeights[house] += 1
                    return nil
                }
            }

            // Cell a can take the digit of cell b if it's one of a's candidates. Digits can rotate
            // along any cycle of such moves, so a keeps b's digit only if b can in turn reach a.
            for a in 0..<count {
                var reach: UInt16 = 0
                for b in 0..<count where masks[a].contains(digit: digitOf[b]) {
                    reach |= 1 << b
                }
                reaches[a] = reach
            }
            for k in 0..<count {
                for a in 0..<count where reaches[a] & (1 << k) != 0 {
                    reaches[a] |= reaches[k]
                }
            }
            for a in 0..<count {
                var usable: DigitMask = 0
                for b in 0..<count where reaches[a] & (1 << b) != 0 && reaches[b] & (1 << a) != 0 {
                    usable |= .digit(digitOf[b])
                }
                if masks[a] & ~usable != 0 {
                    // The cell's own digit stays, so this never empties it.
                    _ = eliminate(masks[a] & ~usable, from: cells[a])
                    progress = true
                }
            }
        }
        return progress
    }

    /// Fills a cell and removes the digit from its peers. Returns `false` if a peer ran out of candidates.
    private mutating func place(_ digit: Int, at cell: Int) -> Bool {
        trail.append((cell, values[cell], candidates[cell]))
        values[cell] = UInt8(digit)
        candidates[cell] = 0
        let bit = DigitMask.digit(digit)
        for peer in Grid.peers[cell] where candidates[peer] & bit != 0 {
            guard eliminate(bit, from: peer) else { return false }
        }
        return true
    }

    /// Removes digits from a cell's candidates. Returns `false` if none are left.
    private mutating func eliminate(_ digits: DigitMask, from cell: Int) -> Bool {
        trail.append((cell, values[cell], candidates[cell]))
        candidates[cell] &= ~digits
        guard candidates[cell] == 0 else { return true }
        houseWeights[Grid.rowOf[cell]] += 1
        houseWeights[9 + Grid.columnOf[cell]] += 1
        houseWeights[18 + Grid.boxOf[cell]] += 1
        return false
    }

    private mutating func undo(to count: Int) {
        while trail.count > count {
            let (cell, value, mask) = trail.removeLast()
            values[cell] = value
            candidates[cell] = mask
        }
    }
}
