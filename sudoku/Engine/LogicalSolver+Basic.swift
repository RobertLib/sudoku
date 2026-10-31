//
//  LogicalSolver+Basic.swift
//  sudoku
//
//  Singles, intersections (locked candidates) and naked/hidden subsets.
//

import Foundation

nonisolated extension LogicalSolver {
    // MARK: Singles

    func findFullHouse() -> LogicStep? {
        for house in Self.houseSearchOrder {
            let empty = Grid.houseCells[house].filter { values[$0] == 0 }
            guard empty.count == 1, let cell = empty.first,
                  let digit = (Grid.allDigits & ~placedDigits(inHouse: house)).singleDigit,
                  has(cell, digit)
            else { continue }
            return LogicStep(
                technique: .fullHouse,
                placement: Candidate(cell, digit),
                houses: [House(id: house)],
                cells: [cell],
                digits: [digit]
            )
        }
        return nil
    }

    func findHiddenSingle() -> LogicStep? {
        for house in Self.houseSearchOrder {
            let placed = placedDigits(inHouse: house)
            for digit in 1...9 where !placed.contains(digit: digit) {
                let cells = cells(inHouse: house, with: digit)
                guard cells.count == 1 else { continue }
                return LogicStep(
                    technique: .hiddenSingle,
                    placement: Candidate(cells[0], digit),
                    houses: [House(id: house)],
                    cells: cells,
                    digits: [digit]
                )
            }
        }
        return nil
    }

    func findNakedSingle() -> LogicStep? {
        for cell in 0..<81 where values[cell] == 0 {
            guard let digit = candidates[cell].singleDigit else { continue }
            return LogicStep(
                technique: .nakedSingle,
                placement: Candidate(cell, digit),
                houses: Grid.housesOf[cell].map(House.init(id:)),
                cells: [cell],
                digits: [digit]
            )
        }
        return nil
    }

    // MARK: Intersections

    /// A digit confined to one line inside a box can be removed from the rest of that line.
    func findPointing() -> LogicStep? {
        for box in 0..<9 {
            for digit in 1...9 {
                let cells = cells(inHouse: 18 + box, with: digit)
                guard cells.count >= 2 else { continue }
                for line in confiningLines(of: cells) {
                    let eliminations = Grid.houseCells[line]
                        .filter { Grid.boxOf[$0] != box && has($0, digit) }
                        .map { Candidate($0, digit) }
                    guard !eliminations.isEmpty else { continue }
                    return LogicStep(
                        technique: .pointing,
                        eliminations: eliminations,
                        houses: [.box(box)],
                        secondaryHouses: [House(id: line)],
                        cells: cells,
                        digits: [digit],
                        patternCandidates: cells.map { Candidate($0, digit) }
                    )
                }
            }
        }
        return nil
    }

    /// A digit confined to one box inside a line can be removed from the rest of that box.
    func findClaiming() -> LogicStep? {
        for line in 0..<18 {
            for digit in 1...9 {
                let cells = cells(inHouse: line, with: digit)
                guard cells.count >= 2 else { continue }
                let box = Grid.boxOf[cells[0]]
                guard cells.allSatisfy({ Grid.boxOf[$0] == box }) else { continue }
                let eliminations = Grid.houseCells[18 + box]
                    .filter { !Grid.houseCells[line].contains($0) && has($0, digit) }
                    .map { Candidate($0, digit) }
                guard !eliminations.isEmpty else { continue }
                return LogicStep(
                    technique: .claiming,
                    eliminations: eliminations,
                    houses: [House(id: line)],
                    secondaryHouses: [.box(box)],
                    cells: cells,
                    digits: [digit],
                    patternCandidates: cells.map { Candidate($0, digit) }
                )
            }
        }
        return nil
    }

    /// The row and/or column ids that contain all of `cells`.
    private func confiningLines(of cells: [Int]) -> [Int] {
        var lines: [Int] = []
        let row = Grid.rowOf[cells[0]]
        if cells.allSatisfy({ Grid.rowOf[$0] == row }) { lines.append(row) }
        let column = Grid.columnOf[cells[0]]
        if cells.allSatisfy({ Grid.columnOf[$0] == column }) { lines.append(9 + column) }
        return lines
    }

    // MARK: Subsets

    func findNakedSubset(size: Int) -> LogicStep? {
        let technique: Technique = switch size {
        case 2: .nakedPair
        case 3: .nakedTriple
        default: .nakedQuad
        }
        for house in 0..<27 {
            let empty = Grid.houseCells[house].filter { values[$0] == 0 }
            guard empty.count > size else { continue }
            let options = empty.filter { (2...size).contains(candidates[$0].digitCount) }
            guard options.count >= size else { continue }

            for combination in Self.combinationTable[options.count][size] {
                let cells = combination.map { options[$0] }
                let union = cells.reduce(DigitMask(0)) { $0 | candidates[$1] }
                guard union.digitCount == size else { continue }
                let others = empty.filter { !cells.contains($0) }
                let eliminations = candidateList(others, digits: union)
                guard !eliminations.isEmpty else { continue }
                return LogicStep(
                    technique: technique,
                    eliminations: eliminations,
                    houses: [House(id: house)],
                    cells: cells,
                    digits: union.digits,
                    patternCandidates: candidateList(cells, digits: union)
                )
            }
        }
        return nil
    }

    func findHiddenSubset(size: Int) -> LogicStep? {
        let technique: Technique = switch size {
        case 2: .hiddenPair
        case 3: .hiddenTriple
        default: .hiddenQuad
        }
        for house in 0..<27 {
            let houseCells = Grid.houseCells[house]
            let emptyCount = houseCells.count { values[$0] == 0 }
            guard emptyCount > size else { continue }

            // For each eligible digit, a bit set of positions (0...8) inside the house.
            var digits: [Int] = []
            var positions: [UInt16] = []
            for digit in 1...9 {
                var mask: UInt16 = 0
                for (position, cell) in houseCells.enumerated() where has(cell, digit) {
                    mask |= 1 << position
                }
                if (2...size).contains(mask.nonzeroBitCount) {
                    digits.append(digit)
                    positions.append(mask)
                }
            }
            guard digits.count >= size else { continue }

            for combination in Self.combinationTable[digits.count][size] {
                let union = combination.reduce(UInt16(0)) { $0 | positions[$1] }
                guard union.nonzeroBitCount == size else { continue }
                let subset = DigitMask(digits: combination.map { digits[$0] })
                let cells = (0..<9).filter { union & (1 << $0) != 0 }.map { houseCells[$0] }
                let eliminations = candidateList(cells, digits: Grid.allDigits & ~subset)
                guard !eliminations.isEmpty else { continue }
                return LogicStep(
                    technique: technique,
                    eliminations: eliminations,
                    houses: [House(id: house)],
                    cells: cells,
                    digits: subset.digits,
                    patternCandidates: candidateList(cells, digits: subset)
                )
            }
        }
        return nil
    }
}
