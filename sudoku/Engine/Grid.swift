//
//  Grid.swift
//  sudoku
//
//  Static geometry of the 9×9 board: index helpers, houses and peers.
//

import Foundation

/// A bit set of digits 1...9 stored in bits 1...9 of a `UInt16`.
typealias DigitMask = UInt16

nonisolated enum Grid {
    static let cellCount = 81
    static let allDigits: DigitMask = 0b11_1111_1110

    static let rowOf: [Int] = (0..<81).map { $0 / 9 }
    static let columnOf: [Int] = (0..<81).map { $0 % 9 }
    static let boxOf: [Int] = (0..<81).map { ($0 / 27) * 3 + ($0 % 9) / 3 }

    static func index(row: Int, column: Int) -> Int { row * 9 + column }

    /// Cells of all 27 houses: rows 0–8, columns 9–17, boxes 18–26.
    static let houseCells: [[Int]] = {
        var houses: [[Int]] = []
        for r in 0..<9 { houses.append((0..<9).map { r * 9 + $0 }) }
        for c in 0..<9 { houses.append((0..<9).map { $0 * 9 + c }) }
        for b in 0..<9 {
            let top = (b / 3) * 3, left = (b % 3) * 3
            houses.append((0..<9).map { (top + $0 / 3) * 9 + left + $0 % 3 })
        }
        return houses
    }()

    /// The three house ids (row, column, box) each cell belongs to.
    static let housesOf: [[Int]] = (0..<81).map { [rowOf[$0], 9 + columnOf[$0], 18 + boxOf[$0]] }

    /// The 20 cells sharing a house with each cell.
    static let peers: [[Int]] = (0..<81).map { cell in
        (0..<81).filter { $0 != cell && sees($0, cell) }
    }

    /// Whether two distinct cells share a row, column or box.
    static func sees(_ a: Int, _ b: Int) -> Bool {
        a != b && (rowOf[a] == rowOf[b] || columnOf[a] == columnOf[b] || boxOf[a] == boxOf[b])
    }

    /// Cells that see every cell in `cells` (excluding the cells themselves).
    static func commonPeers(of cells: [Int]) -> [Int] {
        guard let first = cells.first else { return [] }
        return peers[first].filter { candidate in
            !cells.contains(candidate) && cells.allSatisfy { sees($0, candidate) }
        }
    }

    /// Cells whose digit appears more than once in a row, column or box.
    static func conflictingCells(in values: [UInt8]) -> Set<Int> {
        var result = Set<Int>()
        for house in houseCells {
            var firstCell = [Int](repeating: -1, count: 10)
            for cell in house where values[cell] != 0 {
                let digit = Int(values[cell])
                if firstCell[digit] >= 0 {
                    result.insert(cell)
                    result.insert(firstCell[digit])
                } else {
                    firstCell[digit] = cell
                }
            }
        }
        return result
    }
}

/// A row, column or 3×3 box.
nonisolated struct House: Hashable, Codable, Sendable {
    enum Kind: Int, Codable, Sendable, CaseIterable {
        case row, column, box
    }

    var kind: Kind
    var index: Int

    init(kind: Kind, index: Int) {
        self.kind = kind
        self.index = index
    }

    init(id: Int) {
        self.init(kind: Kind(rawValue: id / 9)!, index: id % 9)
    }

    static func row(_ i: Int) -> House { House(kind: .row, index: i) }
    static func column(_ i: Int) -> House { House(kind: .column, index: i) }
    static func box(_ i: Int) -> House { House(kind: .box, index: i) }

    var id: Int { kind.rawValue * 9 + index }
    var cells: [Int] { Grid.houseCells[id] }

    static let all: [House] = (0..<27).map(House.init(id:))
}

/// A digit in a specific cell, used for placements, eliminations and highlights.
nonisolated struct Candidate: Hashable, Codable, Sendable {
    var cell: Int
    var digit: Int

    init(_ cell: Int, _ digit: Int) {
        self.cell = cell
        self.digit = digit
    }
}

nonisolated extension DigitMask {
    static func digit(_ d: Int) -> DigitMask { 1 << d }

    func contains(digit d: Int) -> Bool { self & (1 << d) != 0 }

    /// Digits in ascending order.
    var digits: [Int] {
        var result: [Int] = []
        var m = self
        while m != 0 {
            result.append(m.trailingZeroBitCount)
            m &= m - 1
        }
        return result
    }

    var digitCount: Int { nonzeroBitCount }

    /// The only digit in the mask, or `nil` if it holds zero or several.
    var singleDigit: Int? { nonzeroBitCount == 1 ? trailingZeroBitCount : nil }

    init(digits: some Sequence<Int>) {
        self = digits.reduce(0) { $0 | (1 << $1) }
    }
}
