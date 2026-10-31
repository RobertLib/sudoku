//
//  LogicalSolver.swift
//  sudoku
//
//  Solves puzzles the way a person would, one explainable step at a time.
//  Used to grade generated puzzles and to build hints.
//
//  Everything here must stay deterministic (no Set/Dictionary iteration),
//  because daily challenges depend on reproducible ratings.
//

import Foundation

nonisolated struct LogicalSolver: Sendable {
    private(set) var values: [UInt8]
    private(set) var candidates: [DigitMask]

    init(values: [UInt8]) {
        self.values = values
        self.candidates = Self.basicCandidates(for: values)
    }

    /// Starts from custom candidates (e.g. the player's notes), intersected
    /// with what the placed digits allow.
    init(values: [UInt8], candidates: [DigitMask]) {
        self.values = values
        let basic = Self.basicCandidates(for: values)
        self.candidates = (0..<81).map { basic[$0] & candidates[$0] }
    }

    /// Candidates allowed by the placed digits alone.
    static func basicCandidates(for values: [UInt8]) -> [DigitMask] {
        (0..<81).map { cell in
            guard values[cell] == 0 else { return 0 }
            var used: DigitMask = 0
            for peer in Grid.peers[cell] where values[peer] != 0 {
                used |= .digit(Int(values[peer]))
            }
            return Grid.allDigits & ~used
        }
    }

    var isSolved: Bool { !values.contains(0) }

    mutating func place(_ digit: Int, at cell: Int) {
        values[cell] = UInt8(digit)
        candidates[cell] = 0
        let bit = ~DigitMask.digit(digit)
        for peer in Grid.peers[cell] {
            candidates[peer] &= bit
        }
    }

    mutating func apply(_ step: LogicStep) {
        for elimination in step.eliminations {
            candidates[elimination.cell] &= ~DigitMask.digit(elimination.digit)
        }
        if let placement = step.placement {
            place(placement.digit, at: placement.cell)
        }
    }

    /// The simplest available deduction, trying techniques in order of difficulty.
    func nextStep(maxLevel: Int = 5) -> LogicStep? {
        for technique in Technique.allCases where technique.level <= maxLevel {
            if let step = findStep(using: technique) {
                return step
            }
        }
        return nil
    }

    func findStep(using technique: Technique) -> LogicStep? {
        switch technique {
        case .fullHouse: findFullHouse()
        case .hiddenSingle: findHiddenSingle()
        case .nakedSingle: findNakedSingle()
        case .pointing: findPointing()
        case .claiming: findClaiming()
        case .nakedPair: findNakedSubset(size: 2)
        case .hiddenPair: findHiddenSubset(size: 2)
        case .nakedTriple: findNakedSubset(size: 3)
        case .hiddenTriple: findHiddenSubset(size: 3)
        case .nakedQuad: findNakedSubset(size: 4)
        case .hiddenQuad: findHiddenSubset(size: 4)
        case .xWing: findFish(size: 2)
        case .skyscraper: findSkyscraper()
        case .twoStringKite: findTwoStringKite()
        case .xyWing: findXYWing()
        case .xyzWing: findXYZWing()
        case .wWing: findWWing()
        case .swordfish: findFish(size: 3)
        case .simpleColoring: findSimpleColoring()
        case .jellyfish: findFish(size: 4)
        case .uniqueRectangle: findUniqueRectangle()
        case .bugPlusOne: findBugPlusOne()
        case .xChain: findXChain()
        case .xyChain: findXYChain()
        }
    }
}

// MARK: - Rating

nonisolated extension LogicalSolver {
    static func rate(_ puzzle: [UInt8]) -> Rating {
        var solver = LogicalSolver(values: puzzle)
        var hardest: Technique?
        var steps = 0
        var score = 0
        var counts: [String: Int] = [:]

        while !solver.isSolved {
            guard let step = solver.nextStep() else {
                return Rating(isSolvable: false, hardestTechnique: hardest, steps: steps, score: score, techniqueCounts: counts)
            }
            solver.apply(step)
            steps += 1
            score += step.technique.weight
            counts[step.technique.rawValue, default: 0] += 1
            if let current = hardest {
                if step.technique.level > current.level
                    || (step.technique.level == current.level && step.technique.weight > current.weight) {
                    hardest = step.technique
                }
            } else {
                hardest = step.technique
            }
        }
        return Rating(isSolvable: true, hardestTechnique: hardest, steps: steps, score: score, techniqueCounts: counts)
    }
}

// MARK: - Hints

/// A logical step together with the candidate grid it was found in.
nonisolated struct HintEntry: Sendable {
    var step: LogicStep
    var values: [UInt8]
    var candidates: [DigitMask]
}

nonisolated extension LogicalSolver {
    /// Deductions leading from the given position to the next placed digit.
    /// The last entry carries the placement unless the solver got stuck after
    /// some eliminations. Returns an empty array when no step exists at all.
    static func hintPlan(values: [UInt8], candidates: [DigitMask], maxSteps: Int = 40) -> [HintEntry] {
        var solver = LogicalSolver(values: values, candidates: candidates)
        var entries: [HintEntry] = []
        while entries.count < maxSteps, !solver.isSolved, let step = solver.nextStep() {
            entries.append(HintEntry(step: step, values: solver.values, candidates: solver.candidates))
            solver.apply(step)
            if step.placement != nil { break }
        }
        return entries
    }
}

// MARK: - Shared helpers

nonisolated extension LogicalSolver {
    /// Boxes first: that's how people scan for singles.
    static let houseSearchOrder: [Int] = Array(18..<27) + Array(0..<18)

    /// All k-element index combinations of 0..<n, for n ≤ 9 and k ≤ 4.
    static let combinationTable: [[[[Int]]]] = (0...9).map { n in
        (0...4).map { k in combinations(n, k) }
    }

    private static func combinations(_ n: Int, _ k: Int) -> [[Int]] {
        guard k > 0 else { return [[]] }
        guard n >= k else { return [] }
        var result: [[Int]] = []
        var current: [Int] = []
        func build(from start: Int) {
            if current.count == k {
                result.append(current)
                return
            }
            for i in start..<n where n - i >= k - current.count {
                current.append(i)
                build(from: i + 1)
                current.removeLast()
            }
        }
        build(from: 0)
        return result
    }

    func has(_ cell: Int, _ digit: Int) -> Bool {
        candidates[cell] & DigitMask.digit(digit) != 0
    }

    func cells(inHouse house: Int, with digit: Int) -> [Int] {
        Grid.houseCells[house].filter { has($0, digit) }
    }

    func placedDigits(inHouse house: Int) -> DigitMask {
        Grid.houseCells[house].reduce(0) { mask, cell in
            values[cell] == 0 ? mask : mask | .digit(Int(values[cell]))
        }
    }

    /// Cells holding `digit` that see all of `cells`, minus `excluding`.
    func eliminations(of digit: Int, seenBy cells: [Int], excluding: [Int] = []) -> [Candidate] {
        Grid.commonPeers(of: cells)
            .filter { has($0, digit) && !excluding.contains($0) }
            .map { Candidate($0, digit) }
    }

    func candidateList(_ cells: [Int], digits: DigitMask) -> [Candidate] {
        cells.flatMap { cell in (candidates[cell] & digits).digits.map { Candidate(cell, $0) } }
    }

    var bivalueCells: [Int] {
        (0..<81).filter { values[$0] == 0 && candidates[$0].digitCount == 2 }
    }

    /// For each cell, the cells forming a conjugate pair (strong link) on `digit` with it.
    func strongLinks(for digit: Int) -> [[Int]] {
        var links = [[Int]](repeating: [], count: 81)
        for house in 0..<27 {
            let cells = cells(inHouse: house, with: digit)
            guard cells.count == 2 else { continue }
            if !links[cells[0]].contains(cells[1]) {
                links[cells[0]].append(cells[1])
                links[cells[1]].append(cells[0])
            }
        }
        return links
    }
}
