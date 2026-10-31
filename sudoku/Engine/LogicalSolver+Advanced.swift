//
//  LogicalSolver+Advanced.swift
//  sudoku
//
//  Fish, single-digit patterns, wings, coloring, uniqueness and chains.
//

import Foundation

nonisolated extension LogicalSolver {
    // MARK: Fish (X-Wing, Swordfish, Jellyfish)

    func findFish(size: Int) -> LogicStep? {
        let technique: Technique = switch size {
        case 2: .xWing
        case 3: .swordfish
        default: .jellyfish
        }
        for digit in 1...9 {
            for rowsAreBase in [true, false] {
                func cell(_ line: Int, _ position: Int) -> Int {
                    rowsAreBase ? line * 9 + position : position * 9 + line
                }
                var lines: [Int] = []
                var masks: [UInt16] = []
                for line in 0..<9 {
                    var mask: UInt16 = 0
                    for position in 0..<9 where has(cell(line, position), digit) {
                        mask |= 1 << position
                    }
                    if (2...size).contains(mask.nonzeroBitCount) {
                        lines.append(line)
                        masks.append(mask)
                    }
                }
                guard lines.count >= size else { continue }

                for combination in Self.combinationTable[lines.count][size] {
                    let cover = combination.reduce(UInt16(0)) { $0 | masks[$1] }
                    guard cover.nonzeroBitCount == size else { continue }
                    let baseLines = combination.map { lines[$0] }
                    let coverLines = (0..<9).filter { cover & (1 << $0) != 0 }

                    var eliminations: [Candidate] = []
                    for position in coverLines {
                        for line in 0..<9 where !baseLines.contains(line) && has(cell(line, position), digit) {
                            eliminations.append(Candidate(cell(line, position), digit))
                        }
                    }
                    guard !eliminations.isEmpty else { continue }

                    let cells = baseLines.flatMap { line in
                        coverLines.map { cell(line, $0) }.filter { has($0, digit) }
                    }
                    let baseHouses = baseLines.map { rowsAreBase ? House.row($0) : House.column($0) }
                    let coverHouses = coverLines.map { rowsAreBase ? House.column($0) : House.row($0) }
                    return LogicStep(
                        technique: technique,
                        eliminations: eliminations,
                        houses: baseHouses,
                        secondaryHouses: coverHouses,
                        cells: cells,
                        digits: [digit],
                        patternCandidates: cells.map { Candidate($0, digit) }
                    )
                }
            }
        }
        return nil
    }

    // MARK: Single-digit patterns

    /// Two parallel strong links whose bases share a line; one of the roof cells must hold the digit.
    func findSkyscraper() -> LogicStep? {
        for digit in 1...9 {
            for rowsAreBase in [true, false] {
                let lineIDs = rowsAreBase ? Array(0..<9) : Array(9..<18)
                let pairs = lineIDs.compactMap { line -> (line: Int, cells: [Int])? in
                    let cells = cells(inHouse: line, with: digit)
                    return cells.count == 2 ? (line, cells) : nil
                }
                func crossLine(_ cell: Int) -> Int {
                    rowsAreBase ? Grid.columnOf[cell] : Grid.rowOf[cell]
                }
                for i in pairs.indices {
                    for j in pairs.indices where j > i {
                        for (baseA, roofA) in [(pairs[i].cells[0], pairs[i].cells[1]), (pairs[i].cells[1], pairs[i].cells[0])] {
                            for (baseB, roofB) in [(pairs[j].cells[0], pairs[j].cells[1]), (pairs[j].cells[1], pairs[j].cells[0])] {
                                guard crossLine(baseA) == crossLine(baseB), crossLine(roofA) != crossLine(roofB) else { continue }
                                let eliminations = eliminations(of: digit, seenBy: [roofA, roofB], excluding: [baseA, baseB])
                                guard !eliminations.isEmpty else { continue }
                                let chain = [roofA, baseA, baseB, roofB]
                                return LogicStep(
                                    technique: .skyscraper,
                                    eliminations: eliminations,
                                    houses: [House(id: pairs[i].line), House(id: pairs[j].line)],
                                    cells: chain,
                                    digits: [digit],
                                    patternCandidates: chain.map { Candidate($0, digit) },
                                    endpoints: [roofA, roofB],
                                    chain: chain,
                                    chainDigits: Array(repeating: digit, count: chain.count - 1)
                                )
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    /// A row strong link and a column strong link joined inside one box.
    func findTwoStringKite() -> LogicStep? {
        for digit in 1...9 {
            let rowPairs = (0..<9).compactMap { row -> [Int]? in
                let cells = cells(inHouse: row, with: digit)
                return cells.count == 2 ? cells : nil
            }
            let columnPairs = (9..<18).compactMap { column -> [Int]? in
                let cells = cells(inHouse: column, with: digit)
                return cells.count == 2 ? cells : nil
            }
            for rowPair in rowPairs {
                for columnPair in columnPairs {
                    for (rowInner, rowOuter) in [(rowPair[0], rowPair[1]), (rowPair[1], rowPair[0])] {
                        for (columnInner, columnOuter) in [(columnPair[0], columnPair[1]), (columnPair[1], columnPair[0])] {
                            let box = Grid.boxOf[rowInner]
                            guard Set([rowInner, rowOuter, columnInner, columnOuter]).count == 4,
                                  Grid.boxOf[columnInner] == box,
                                  Grid.boxOf[rowOuter] != box,
                                  Grid.boxOf[columnOuter] != box
                            else { continue }
                            let eliminations = eliminations(of: digit, seenBy: [rowOuter, columnOuter], excluding: [rowInner, columnInner])
                            guard !eliminations.isEmpty else { continue }
                            let chain = [rowOuter, rowInner, columnInner, columnOuter]
                            return LogicStep(
                                technique: .twoStringKite,
                                eliminations: eliminations,
                                houses: [.row(Grid.rowOf[rowInner]), .column(Grid.columnOf[columnInner])],
                                secondaryHouses: [.box(box)],
                                cells: chain,
                                digits: [digit],
                                patternCandidates: chain.map { Candidate($0, digit) },
                                endpoints: [rowOuter, columnOuter],
                                chain: chain,
                                chainDigits: Array(repeating: digit, count: chain.count - 1)
                            )
                        }
                    }
                }
            }
        }
        return nil
    }

    // MARK: Wings

    func findXYWing() -> LogicStep? {
        let bivalue = bivalueCells
        for pivot in bivalue {
            let pivotMask = candidates[pivot]
            let wings = bivalue.filter {
                $0 != pivot && Grid.sees($0, pivot) && (candidates[$0] & pivotMask).digitCount == 1
            }
            for i in wings.indices {
                for j in wings.indices where j > i {
                    let a = wings[i], b = wings[j]
                    let maskA = candidates[a], maskB = candidates[b]
                    guard maskA & pivotMask != maskB & pivotMask else { continue }
                    let extraA = maskA & ~pivotMask, extraB = maskB & ~pivotMask
                    guard extraA == extraB, let z = extraA.singleDigit else { continue }
                    let eliminations = eliminations(of: z, seenBy: [a, b], excluding: [pivot])
                    guard !eliminations.isEmpty else { continue }
                    let cells = [pivot, a, b]
                    return LogicStep(
                        technique: .xyWing,
                        eliminations: eliminations,
                        cells: cells,
                        digits: (pivotMask | extraA).digits,
                        patternCandidates: candidateList(cells, digits: Grid.allDigits & ~extraA),
                        alternateCandidates: [Candidate(a, z), Candidate(b, z)],
                        endpoints: [a, b],
                        chain: [a, pivot, b],
                        chainDigits: (maskA & pivotMask).digits + (maskB & pivotMask).digits
                    )
                }
            }
        }
        return nil
    }

    func findXYZWing() -> LogicStep? {
        let bivalue = bivalueCells
        for pivot in 0..<81 where values[pivot] == 0 && candidates[pivot].digitCount == 3 {
            let pivotMask = candidates[pivot]
            let wings = bivalue.filter { Grid.sees($0, pivot) && candidates[$0] & ~pivotMask == 0 }
            for i in wings.indices {
                for j in wings.indices where j > i {
                    let a = wings[i], b = wings[j]
                    guard candidates[a] != candidates[b],
                          let z = (candidates[a] & candidates[b]).singleDigit
                    else { continue }
                    let eliminations = eliminations(of: z, seenBy: [pivot, a, b])
                    guard !eliminations.isEmpty else { continue }
                    let cells = [pivot, a, b]
                    let zMask = DigitMask.digit(z)
                    return LogicStep(
                        technique: .xyzWing,
                        eliminations: eliminations,
                        cells: cells,
                        digits: pivotMask.digits,
                        patternCandidates: candidateList(cells, digits: Grid.allDigits & ~zMask),
                        alternateCandidates: candidateList(cells, digits: zMask),
                        endpoints: [a, b],
                        chain: [a, pivot, b],
                        // Each wing is tied to the pivot by its digit other than z.
                        chainDigits: (candidates[a] & ~zMask).digits + (candidates[b] & ~zMask).digits
                    )
                }
            }
        }
        return nil
    }

    /// Two identical bivalue cells connected by a strong link on one of their digits.
    func findWWing() -> LogicStep? {
        let bivalue = bivalueCells
        for i in bivalue.indices {
            for j in bivalue.indices where j > i {
                let first = bivalue[i], second = bivalue[j]
                let mask = candidates[first]
                guard candidates[second] == mask, !Grid.sees(first, second) else { continue }
                let pair = mask.digits
                for (link, target) in [(pair[0], pair[1]), (pair[1], pair[0])] {
                    for house in 0..<27 {
                        let ends = cells(inHouse: house, with: link)
                        guard ends.count == 2, !ends.contains(first), !ends.contains(second) else { continue }
                        let ordered: [Int]
                        if Grid.sees(ends[0], first) && Grid.sees(ends[1], second) {
                            ordered = [first, ends[0], ends[1], second]
                        } else if Grid.sees(ends[1], first) && Grid.sees(ends[0], second) {
                            ordered = [first, ends[1], ends[0], second]
                        } else {
                            continue
                        }
                        let eliminations = eliminations(of: target, seenBy: [first, second])
                        guard !eliminations.isEmpty else { continue }
                        return LogicStep(
                            technique: .wWing,
                            eliminations: eliminations,
                            houses: [House(id: house)],
                            cells: ordered,
                            digits: [link, target],
                            patternCandidates: ordered.map { Candidate($0, link) },
                            alternateCandidates: [Candidate(first, target), Candidate(second, target)],
                            endpoints: [first, second],
                            chain: ordered,
                            chainDigits: Array(repeating: link, count: ordered.count - 1)
                        )
                    }
                }
            }
        }
        return nil
    }

    // MARK: Coloring

    func findSimpleColoring() -> LogicStep? {
        for digit in 1...9 {
            let links = strongLinks(for: digit)
            var color = [Int](repeating: -1, count: 81)

            for start in 0..<81 where !links[start].isEmpty && color[start] < 0 {
                var component = [start]
                color[start] = 0
                var head = 0
                while head < component.count {
                    let cell = component[head]
                    head += 1
                    for next in links[cell] where color[next] < 0 {
                        color[next] = 1 - color[cell]
                        component.append(next)
                    }
                }
                guard component.count >= 3 else { continue }
                component.sort()
                let colorA = component.filter { color[$0] == 0 }
                let colorB = component.filter { color[$0] == 1 }

                // Color wrap: two cells of one color see each other, so that color is false.
                for (falseColor, trueColor) in [(colorA, colorB), (colorB, colorA)] {
                    let clash = falseColor.contains { a in falseColor.contains { b in Grid.sees(a, b) } }
                    guard clash else { continue }
                    return LogicStep(
                        technique: .simpleColoring,
                        eliminations: falseColor.map { Candidate($0, digit) },
                        cells: component,
                        digits: [digit],
                        patternCandidates: trueColor.map { Candidate($0, digit) },
                        alternateCandidates: falseColor.map { Candidate($0, digit) }
                    )
                }

                // Color trap: a cell seeing both colors can't hold the digit.
                let eliminations = (0..<81)
                    .filter { cell in
                        has(cell, digit) && !component.contains(cell)
                            && colorA.contains { Grid.sees($0, cell) }
                            && colorB.contains { Grid.sees($0, cell) }
                    }
                    .map { Candidate($0, digit) }
                guard !eliminations.isEmpty else { continue }
                return LogicStep(
                    technique: .simpleColoring,
                    eliminations: eliminations,
                    cells: component,
                    digits: [digit],
                    patternCandidates: colorA.map { Candidate($0, digit) },
                    alternateCandidates: colorB.map { Candidate($0, digit) }
                )
            }
        }
        return nil
    }

    // MARK: Uniqueness

    /// Avoids the "deadly pattern" of four cells in two boxes sharing the same two candidates.
    func findUniqueRectangle() -> LogicStep? {
        for r1 in 0..<8 {
            for r2 in (r1 + 1)..<9 {
                for c1 in 0..<8 {
                    for c2 in (c1 + 1)..<9 {
                        guard (r1 / 3 == r2 / 3) != (c1 / 3 == c2 / 3) else { continue }
                        let corners = [r1 * 9 + c1, r1 * 9 + c2, r2 * 9 + c1, r2 * 9 + c2]
                        guard corners.allSatisfy({ values[$0] == 0 }),
                              let pairCell = corners.first(where: { candidates[$0].digitCount == 2 })
                        else { continue }
                        let pair = candidates[pairCell]
                        guard corners.allSatisfy({ candidates[$0] & pair == pair }) else { continue }

                        let exact = corners.filter { candidates[$0] == pair }
                        let extra = corners.filter { candidates[$0] != pair }
                        let houses = [House.row(r1), .row(r2), .column(c1), .column(c2)]

                        // Type 1: the only corner with extra candidates can't be either pair digit.
                        if exact.count == 3, let target = extra.first {
                            return LogicStep(
                                technique: .uniqueRectangle,
                                eliminations: pair.digits.map { Candidate(target, $0) },
                                houses: houses,
                                cells: corners,
                                digits: pair.digits,
                                patternCandidates: candidateList(exact, digits: pair),
                                endpoints: [target]
                            )
                        }

                        // Type 2: both extra corners hold the same single extra digit; one of them must be it.
                        if exact.count == 2 {
                            let extraA = candidates[extra[0]] & ~pair
                            let extraB = candidates[extra[1]] & ~pair
                            guard extraA == extraB, let z = extraA.singleDigit else { continue }
                            let eliminations = eliminations(of: z, seenBy: extra, excluding: corners)
                            guard !eliminations.isEmpty else { continue }
                            return LogicStep(
                                technique: .uniqueRectangle,
                                eliminations: eliminations,
                                houses: houses,
                                cells: corners,
                                digits: pair.digits + [z],
                                patternCandidates: candidateList(corners, digits: pair),
                                alternateCandidates: extra.map { Candidate($0, z) },
                                endpoints: extra
                            )
                        }
                    }
                }
            }
        }
        return nil
    }

    /// Bivalue Universal Grave + 1: every unsolved cell has two candidates except one.
    func findBugPlusOne() -> LogicStep? {
        var tripleCell: Int?
        for cell in 0..<81 where values[cell] == 0 {
            switch candidates[cell].digitCount {
            case 2:
                continue
            case 3 where tripleCell == nil:
                tripleCell = cell
            default:
                return nil
            }
        }
        guard let cell = tripleCell else { return nil }

        for digit in candidates[cell].digits {
            var valid = true
            houseLoop: for house in 0..<27 {
                for d in 1...9 {
                    var count = cells(inHouse: house, with: d).count
                    if d == digit && Grid.housesOf[cell].contains(house) { count -= 1 }
                    if count != 0 && count != 2 {
                        valid = false
                        break houseLoop
                    }
                }
            }
            guard valid else { continue }
            return LogicStep(
                technique: .bugPlusOne,
                placement: Candidate(cell, digit),
                houses: Grid.housesOf[cell].map(House.init(id:)),
                cells: [cell],
                digits: [digit],
                patternCandidates: [Candidate(cell, digit)]
            )
        }
        return nil
    }

    // MARK: Chains

    /// Alternating chain of strong and weak links on one digit. Found with a
    /// breadth-first search over (cell, is-true) states, so the shortest chain wins.
    func findXChain() -> LogicStep? {
        var best: LogicStep?
        var bestLength = Int.max

        for digit in 1...9 {
            let links = strongLinks(for: digit)
            let nodes = (0..<81).filter { has($0, digit) }
            guard nodes.count >= 4 else { continue }

            for start in nodes where !links[start].isEmpty {
                // State = cell * 2 + parity; parity 0: "not the digit", 1: "is the digit".
                var previous = [Int](repeating: -1, count: 162)
                var visited = [Bool](repeating: false, count: 162)
                var queue = [start * 2]
                visited[start * 2] = true
                var head = 0
                while head < queue.count {
                    let state = queue[head]
                    head += 1
                    let cell = state >> 1
                    let successors = state & 1 == 0
                        ? links[cell].map { $0 * 2 + 1 }
                        : Grid.peers[cell].filter { has($0, digit) }.map { $0 * 2 }
                    for next in successors where !visited[next] {
                        visited[next] = true
                        previous[next] = state
                        queue.append(next)
                    }
                }

                for end in nodes where end > start && visited[end * 2 + 1] {
                    var chain: [Int] = []
                    var state = end * 2 + 1
                    while state >= 0 {
                        chain.append(state >> 1)
                        state = previous[state]
                    }
                    chain.reverse()
                    guard chain.count - 1 < bestLength, Set(chain).count == chain.count else { continue }
                    let eliminations = eliminations(of: digit, seenBy: [start, end], excluding: chain)
                    guard !eliminations.isEmpty else { continue }
                    bestLength = chain.count - 1
                    best = LogicStep(
                        technique: .xChain,
                        eliminations: eliminations,
                        cells: chain,
                        digits: [digit],
                        patternCandidates: chain.enumerated().filter { $0.offset % 2 == 0 }.map { Candidate($0.element, digit) },
                        alternateCandidates: chain.enumerated().filter { $0.offset % 2 == 1 }.map { Candidate($0.element, digit) },
                        endpoints: [start, end],
                        chain: chain,
                        chainDigits: Array(repeating: digit, count: chain.count - 1)
                    )
                }
            }
        }
        return best
    }

    /// Chain of bivalue cells: whichever value the first cell takes, one end holds `z`.
    func findXYChain() -> LogicStep? {
        let bivalue = bivalueCells
        guard bivalue.count >= 3 else { return nil }
        var isBivalue = [Bool](repeating: false, count: 81)
        for cell in bivalue { isBivalue[cell] = true }

        var best: LogicStep?
        var bestLength = Int.max

        for start in bivalue {
            for z in candidates[start].digits {
                guard let first = (candidates[start] & ~DigitMask.digit(z)).singleDigit else { continue }
                // State = cell * 10 + digit that is true in that cell.
                var previous = [Int](repeating: -1, count: 810)
                var visited = [Bool](repeating: false, count: 810)
                let initial = start * 10 + first
                var queue = [initial]
                visited[initial] = true
                var head = 0
                while head < queue.count {
                    let state = queue[head]
                    head += 1
                    let cell = state / 10, truth = state % 10
                    for next in Grid.peers[cell] where isBivalue[next] && has(next, truth) {
                        guard let other = (candidates[next] & ~DigitMask.digit(truth)).singleDigit else { continue }
                        let nextState = next * 10 + other
                        guard !visited[nextState] else { continue }
                        visited[nextState] = true
                        previous[nextState] = state
                        queue.append(nextState)
                    }
                }

                for end in bivalue where end != start && visited[end * 10 + z] {
                    var chain: [Int] = []
                    // The digit that is true in each cell; it is also the digit linking the cell to the next one.
                    var truths: [Int] = []
                    var state = end * 10 + z
                    while state >= 0 {
                        chain.append(state / 10)
                        truths.append(state % 10)
                        state = previous[state]
                    }
                    chain.reverse()
                    truths.reverse()
                    guard chain.count >= 3, chain.count - 1 < bestLength, Set(chain).count == chain.count else { continue }
                    let eliminations = eliminations(of: z, seenBy: [start, end], excluding: chain)
                    guard !eliminations.isEmpty else { continue }
                    bestLength = chain.count - 1
                    best = LogicStep(
                        technique: .xyChain,
                        eliminations: eliminations,
                        cells: chain,
                        digits: [z],
                        patternCandidates: candidateList(chain, digits: Grid.allDigits),
                        alternateCandidates: [Candidate(start, z), Candidate(end, z)],
                        endpoints: [start, end],
                        chain: chain,
                        chainDigits: Array(truths.dropLast())
                    )
                }
            }
        }
        return best
    }
}
