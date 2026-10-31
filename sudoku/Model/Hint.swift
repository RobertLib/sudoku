//
//  Hint.swift
//  sudoku
//

import Foundation

/// A hint being shown to the player.
struct HintSession {
    enum Content {
        /// Placed digits that don't match the solution.
        case mistakes([Int])
        /// Cells whose notes no longer contain the correct digit.
        case badNotes([Int])
        /// Logical steps; the last one usually places a digit.
        case logic([HintEntry])
        /// No technique applies (only for custom puzzles beyond the solver).
        case noStep
    }

    var content: Content
    /// 0 = gentle nudge, n = details of the n-th logical step.
    var stage: Int

    init(content: Content) {
        self.content = content
        if case .logic = content { stage = 0 } else { stage = 1 }
    }

    var entries: [HintEntry] {
        if case .logic(let entries) = content { entries } else { [] }
    }

    var isNudge: Bool { stage == 0 }
    var stepCount: Int { max(entries.count, 1) }

    var currentEntry: HintEntry? {
        let entries = entries
        guard !entries.isEmpty else { return nil }
        return entries[min(max(stage - 1, 0), entries.count - 1)]
    }

    var isLastStage: Bool { stage >= stepCount }

    /// Board decorations for the current stage.
    var overlay: HintOverlay {
        var overlay = HintOverlay()
        switch content {
        case .mistakes(let cells), .badNotes(let cells):
            overlay.errorCells = Set(cells)
        case .noStep:
            break
        case .logic(let entries):
            guard let entry = isNudge ? entries.first : currentEntry else { break }
            let step = entry.step
            overlay.houseCells = Set(step.houses.flatMap(\.cells))
            if isNudge {
                if step.technique == .nakedSingle, let cell = step.placement?.cell {
                    overlay.houseCells = []
                    overlay.patternCells = [cell]
                } else if step.technique == .bugPlusOne {
                    // Its houses are the target cell's own and would point straight at it, while the nudge
                    // asks to look at the cells with two candidates – which, like the other techniques built
                    // on those, it leaves for the player to find.
                    overlay.houseCells = []
                }
                break
            }
            overlay.secondaryCells = Set(step.secondaryHouses.flatMap(\.cells))
            overlay.patternCells = Set(step.cells)
            overlay.targetCell = step.placement?.cell
            overlay.links = Self.links(for: entry)
            if step.technique == .hiddenSingle, let placement = step.placement, let house = step.houses.first {
                let others = house.cells.filter { entry.values[$0] == 0 && $0 != placement.cell }
                overlay.supportCells = Set((0..<81).filter { cell in
                    Int(entry.values[cell]) == placement.digit && others.contains { Grid.sees($0, cell) }
                })
            }

            var marked = Set(step.cells)
            marked.formUnion(step.eliminations.map(\.cell))
            marked.formUnion(step.patternCandidates.map(\.cell))
            marked.formUnion(step.alternateCandidates.map(\.cell))
            if let placement = step.placement { marked.insert(placement.cell) }
            for cell in marked where entry.values[cell] == 0 {
                var marks = HintMarks(all: entry.candidates[cell])
                for candidate in step.patternCandidates where candidate.cell == cell {
                    marks.pattern |= .digit(candidate.digit)
                }
                for candidate in step.alternateCandidates where candidate.cell == cell {
                    marks.alternate |= .digit(candidate.digit)
                }
                for candidate in step.eliminations where candidate.cell == cell {
                    marks.eliminated |= .digit(candidate.digit)
                }
                if let placement = step.placement, placement.cell == cell {
                    marks.placement = placement.digit
                }
                overlay.marks[cell] = marks
            }
        }
        return overlay
    }

    /// Lines connecting consecutive chain candidates; strong when they are the
    /// only two places for the digit in a shared house.
    private static func links(for entry: HintEntry) -> [ChainLink] {
        let step = entry.step
        return zip(zip(step.chain, step.chain.dropFirst()), step.chainDigits).map { cells, digit in
            let (a, b) = cells
            let isStrong = Grid.housesOf[a].contains { house in
                Grid.housesOf[b].contains(house)
                    && Grid.houseCells[house].count { entry.candidates[$0].contains(digit: digit) } == 2
            }
            return ChainLink(from: Candidate(a, digit), to: Candidate(b, digit), isStrong: isStrong)
        }
    }
}

struct ChainLink: Equatable {
    var from: Candidate
    var to: Candidate
    var isStrong: Bool
}

/// Candidates drawn in a cell while a hint explains a step.
struct HintMarks: Equatable {
    var all: DigitMask
    var pattern: DigitMask = 0
    var alternate: DigitMask = 0
    var eliminated: DigitMask = 0
    var placement = 0
}

struct HintOverlay {
    var houseCells: Set<Int> = []
    var secondaryCells: Set<Int> = []
    var patternCells: Set<Int> = []
    var errorCells: Set<Int> = []
    /// Placed digits that explain a deduction (e.g. the ones blocking a hidden single).
    var supportCells: Set<Int> = []
    var targetCell: Int?
    var marks: [Int: HintMarks] = [:]
    var links: [ChainLink] = []
}
