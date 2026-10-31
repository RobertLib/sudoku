//
//  Technique.swift
//  sudoku
//

import Foundation

/// Human solving techniques, declared in the order the logical solver tries them.
nonisolated enum Technique: String, Codable, CaseIterable, Sendable {
    case fullHouse
    case hiddenSingle
    case nakedSingle
    case pointing
    case claiming
    case nakedPair
    case hiddenPair
    case nakedTriple
    case hiddenTriple
    case nakedQuad
    case hiddenQuad
    case xWing
    case skyscraper
    case twoStringKite
    case xyWing
    case wWing
    case swordfish
    case xyzWing
    case simpleColoring
    case jellyfish
    case uniqueRectangle
    case bugPlusOne
    case xChain
    case xyChain

    /// Difficulty tier a technique belongs to (1 = singles ... 5 = chains).
    var level: Int {
        switch self {
        case .fullHouse, .hiddenSingle, .nakedSingle:
            1
        case .pointing, .claiming:
            2
        case .nakedPair, .hiddenPair, .nakedTriple, .hiddenTriple, .nakedQuad, .hiddenQuad:
            3
        case .xWing, .skyscraper, .twoStringKite, .xyWing, .xyzWing, .wWing, .swordfish, .simpleColoring, .jellyfish:
            4
        case .uniqueRectangle, .bugPlusOne, .xChain, .xyChain:
            5
        }
    }

    /// Relative effort of applying the technique once; summed into a puzzle score.
    var weight: Int {
        switch self {
        case .fullHouse: 4
        case .hiddenSingle: 10
        case .nakedSingle: 15
        case .pointing: 30
        case .claiming: 35
        case .nakedPair: 40
        case .hiddenPair: 50
        case .nakedTriple: 60
        case .hiddenTriple: 70
        case .nakedQuad: 120
        case .hiddenQuad: 130
        case .xWing: 100
        case .skyscraper: 110
        case .twoStringKite: 110
        case .xyWing: 140
        case .xyzWing: 160
        case .wWing: 150
        case .swordfish: 150
        case .simpleColoring: 170
        case .jellyfish: 200
        case .uniqueRectangle: 200
        case .bugPlusOne: 200
        case .xChain: 230
        case .xyChain: 250
        }
    }

    /// The puzzle difficulty in which the technique first becomes necessary.
    var difficulty: Difficulty {
        switch level {
        case 1: .easy
        case 2: .medium
        case 3: .hard
        case 4: .expert
        default: .master
        }
    }
}

nonisolated enum Difficulty: String, Codable, CaseIterable, Sendable, Identifiable, Comparable {
    case easy, medium, hard, expert, master

    var id: String { rawValue }

    /// Highest technique level a puzzle of this difficulty may require.
    var maxLevel: Int {
        switch self {
        case .easy: 1
        case .medium: 2
        case .hard: 3
        case .expert: 4
        case .master: 5
        }
    }

    var order: Int { Self.allCases.firstIndex(of: self)! }

    static func < (lhs: Difficulty, rhs: Difficulty) -> Bool { lhs.order < rhs.order }
}

/// One deduction made by the logical solver, with everything needed to explain it.
nonisolated struct LogicStep: Hashable, Sendable {
    var technique: Technique
    /// A digit that can be placed (singles, BUG+1).
    var placement: Candidate?
    /// Candidates proven impossible.
    var eliminations: [Candidate] = []
    /// Houses the deduction is based on (e.g. the box of a hidden single, fish base lines).
    var houses: [House] = []
    /// Secondary houses (e.g. fish cover lines, the line a pointing pair points along).
    var secondaryHouses: [House] = []
    /// Cells forming the pattern.
    var cells: [Int] = []
    /// Digits the pattern is about.
    var digits: [Int] = []
    /// Candidates forming the pattern (drawn in the primary highlight color).
    var patternCandidates: [Candidate] = []
    /// Alternative pattern candidates (the second color in coloring/chains).
    var alternateCandidates: [Candidate] = []
    /// The two cells whose shared peers lose a candidate (wings, chains, kites…).
    var endpoints: [Int] = []
    /// Ordered cells along a chain.
    var chain: [Int] = []
    /// The digit linking each pair of consecutive chain cells (`chain.count - 1` entries).
    var chainDigits: [Int] = []
}

/// Summary of solving a puzzle purely with logic.
nonisolated struct Rating: Codable, Hashable, Sendable {
    var isSolvable: Bool
    var hardestTechnique: Technique?
    var steps: Int
    var score: Int
    var techniqueCounts: [String: Int]

    var level: Int { hardestTechnique?.level ?? 1 }

    /// Difficulty implied purely by technique, ignoring clue count.
    var techniqueDifficulty: Difficulty? {
        isSolvable ? (hardestTechnique?.difficulty ?? .easy) : nil
    }
}
