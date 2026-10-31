//
//  HintText.swift
//  sudoku
//
//  Turns hint steps into localized explanations. Sentences are written per
//  house kind (row/column/box) so translations can use correct grammar.
//

import Foundation

enum HintText {
    static func cell(_ cell: Int) -> String {
        let row = Grid.rowOf[cell] + 1, column = Grid.columnOf[cell] + 1
        return String(localized: "R\(row)C\(column)", comment: "Short cell coordinate used in hints: R = row, C = column.")
    }

    static func cells(_ cells: [Int]) -> String {
        list(cells.map { cell($0) })
    }

    static func digits(_ digits: [Int]) -> String {
        list(digits.map(String.init))
    }

    static func numbers(_ houses: [House]) -> String {
        list(houses.map { String($0.index + 1) })
    }

    /// "1, 5 and 8" in the app's language.
    private static func list(_ items: [String]) -> String {
        items.formatted(.list(type: .and).locale(AppLocale.current))
    }

    // MARK: Titles

    static func title(for hint: HintSession) -> String {
        switch hint.content {
        case .mistakes(let cells):
            cells.count == 1 ? String(localized: "Mistake Found") : String(localized: "Mistakes Found")
        case .badNotes:
            String(localized: "Check Your Notes")
        case .noStep:
            String(localized: "No Logical Step Found")
        case .logic(let entries):
            if hint.isNudge {
                String(localized: entries.first?.step.technique.title ?? "Hint")
            } else {
                String(localized: hint.currentEntry?.step.technique.title ?? "Hint")
            }
        }
    }

    // MARK: Messages

    static func message(for hint: HintSession) -> String {
        switch hint.content {
        case .mistakes(let cells):
            return String(localized: "\(cells.count) highlighted cells contain a wrong number.")
        case .badNotes(let cells):
            return String(localized: "The notes in \(cells.count) highlighted cells are missing the correct number.")
        case .noStep:
            return String(localized: "This puzzle needs a technique beyond the hint engine. You can reveal a cell instead.")
        case .logic(let entries):
            guard let first = entries.first else { return "" }
            if hint.isNudge {
                return nudge(for: first.step)
            }
            guard let entry = hint.currentEntry else { return "" }
            return explanation(for: entry)
        }
    }

    static func nudge(for step: LogicStep) -> String {
        let summary = String(localized: step.technique.summary)
        let focus: String
        switch step.technique {
        case .nakedSingle:
            // Named, not only highlighted: VoiceOver users can't see the highlight.
            focus = step.placement.map { String(localized: "Look closely at \(cell($0.cell)).") } ?? ""
        case .xyWing, .xyzWing, .wWing, .xyChain, .uniqueRectangle, .bugPlusOne:
            focus = String(localized: "Look for cells with only two candidates.")
        case .xWing, .swordfish, .jellyfish, .skyscraper, .twoStringKite, .simpleColoring, .xChain:
            focus = String(localized: "Focus on the number \(step.digits.first ?? 0).")
        default:
            if let house = step.houses.first {
                focus = look(at: house)
            } else {
                focus = ""
            }
        }
        return focus.isEmpty ? summary : "\(focus) \(summary)"
    }

    private static func look(at house: House) -> String {
        let n = house.index + 1
        return switch house.kind {
        case .row: String(localized: "Look at row \(n).")
        case .column: String(localized: "Look at column \(n).")
        case .box: String(localized: "Look at box \(n).")
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func explanation(for entry: HintEntry) -> String {
        let step = entry.step
        let digit = step.digits.first ?? 0
        let house = step.houses.first ?? .row(0)
        let n = house.index + 1

        switch step.technique {
        case .fullHouse:
            let value = step.placement?.digit ?? digit
            return switch house.kind {
            case .row: String(localized: "Row \(n) has only one empty cell left. The missing number is \(value).")
            case .column: String(localized: "Column \(n) has only one empty cell left. The missing number is \(value).")
            case .box: String(localized: "Box \(n) has only one empty cell left. The missing number is \(value).")
            }

        case .hiddenSingle:
            return switch house.kind {
            case .row: String(localized: "In row \(n), the number \(digit) fits in only one cell.")
            case .column: String(localized: "In column \(n), the number \(digit) fits in only one cell.")
            case .box: String(localized: "In box \(n), the number \(digit) fits in only one cell.")
            }

        case .nakedSingle:
            let placement = step.placement ?? Candidate(0, digit)
            let target = cell(placement.cell)
            // The other numbers may also have been ruled out by notes or earlier steps of the hint.
            let isBlockedByPeers = LogicalSolver.basicCandidates(for: entry.values)[placement.cell].digitCount == 1
            return isBlockedByPeers
                ? String(localized: "\(target) can only hold \(digit) – every other number already appears in its row, column or box.")
                : String(localized: "\(target) can only hold \(digit) – it's the only candidate left in this cell.")

        case .pointing:
            let box = n
            let line = step.secondaryHouses.first ?? .row(0)
            let lineNumber = line.index + 1
            return line.kind == .row
                ? String(localized: "In box \(box), the number \(digit) can only be in row \(lineNumber), so it can be removed from the rest of that row.")
                : String(localized: "In box \(box), the number \(digit) can only be in column \(lineNumber), so it can be removed from the rest of that column.")

        case .claiming:
            let box = (step.secondaryHouses.first?.index ?? 0) + 1
            return house.kind == .row
                ? String(localized: "In row \(n), the number \(digit) can only be in box \(box), so it can be removed from the rest of that box.")
                : String(localized: "In column \(n), the number \(digit) can only be in box \(box), so it can be removed from the rest of that box.")

        case .nakedPair, .nakedTriple, .nakedQuad:
            let cellList = cells(step.cells), digitList = digits(step.digits)
            return switch house.kind {
            case .row: String(localized: "Cells \(cellList) in row \(n) can only contain \(digitList). These numbers can be removed from the other cells of the row.")
            case .column: String(localized: "Cells \(cellList) in column \(n) can only contain \(digitList). These numbers can be removed from the other cells of the column.")
            case .box: String(localized: "Cells \(cellList) in box \(n) can only contain \(digitList). These numbers can be removed from the other cells of the box.")
            }

        case .hiddenPair, .hiddenTriple, .hiddenQuad:
            let cellList = cells(step.cells), digitList = digits(step.digits)
            return switch house.kind {
            case .row: String(localized: "In row \(n), the numbers \(digitList) can only go in cells \(cellList). All other candidates can be removed from these cells.")
            case .column: String(localized: "In column \(n), the numbers \(digitList) can only go in cells \(cellList). All other candidates can be removed from these cells.")
            case .box: String(localized: "In box \(n), the numbers \(digitList) can only go in cells \(cellList). All other candidates can be removed from these cells.")
            }

        case .xWing, .swordfish, .jellyfish:
            let base = numbers(step.houses), cover = numbers(step.secondaryHouses)
            return house.kind == .row
                ? String(localized: "In rows \(base), the number \(digit) can only be in columns \(cover). It can be removed from all other cells of those columns.")
                : String(localized: "In columns \(base), the number \(digit) can only be in rows \(cover). It can be removed from all other cells of those rows.")

        case .skyscraper:
            let (a, b) = endpoints(step)
            return String(localized: "In two parallel lines, \(digit) has only two possible cells, and one end of each pair lines up. So \(a) or \(b) must be \(digit) – remove it from cells that see both.")

        case .twoStringKite:
            let (a, b) = endpoints(step)
            return String(localized: "\(digit) has only two possible cells in a row and in a column, and the two pairs meet in one box. So \(a) or \(b) must be \(digit) – remove it from cells that see both.")

        case .xChain:
            let (a, b) = endpoints(step)
            return String(localized: "Following the alternating links of \(digit) shows that \(a) or \(b) must be \(digit). Remove it from cells that see both ends.")

        case .simpleColoring:
            let eliminated = Set(step.eliminations.map(\.cell))
            let isWrap = eliminated.isSubset(of: Set(step.cells))
            return isWrap
                ? String(localized: "The strong links of \(digit) split its cells into two colors. Two cells of the same color see each other, so that color is wrong and \(digit) can be removed from all its cells.")
                : String(localized: "The strong links of \(digit) split its cells into two colors, and one color must be right. Cells that see both colors can't be \(digit).")

        case .xyWing:
            let pivot = step.cells[0]
            let pivotDigits = step.digits.filter { $0 != eliminatedDigit(step) }
            let z = eliminatedDigit(step)
            return String(localized: "The pivot \(cell(pivot)) is either \(pivotDigits.first ?? 0) or \(pivotDigits.last ?? 0). Either way, one of the wings \(cell(step.cells[1])) or \(cell(step.cells[2])) becomes \(z), so \(z) can be removed from cells that see both wings.")

        case .xyzWing:
            let z = eliminatedDigit(step)
            return String(localized: "The pivot \(cell(step.cells[0])) holds \(digits(step.digits)). Whatever it turns out to be, \(z) ends up in the pivot or in one of the wings \(cell(step.cells[1])) and \(cell(step.cells[2])). Cells that see all three can't be \(z).")

        case .wWing:
            let link = step.digits[0], target = step.digits[1]
            let (a, b) = endpoints(step)
            return String(localized: "\(a) and \(b) can only be \(link) or \(target). Thanks to the strong link on \(link), one of them must be \(target) – remove \(target) from cells that see both.")

        case .xyChain:
            let (a, b) = endpoints(step)
            return String(localized: "Follow the chain of two-candidate cells from \(a) to \(b): whatever the first cell turns out to be, one of the ends must be \(digit). Remove \(digit) from cells that see both ends.")

        case .uniqueRectangle:
            if step.endpoints.count == 1, let target = step.endpoints.first {
                let pair = step.digits
                return String(localized: "If \(cell(target)) were \(pair.first ?? 0) or \(pair.last ?? 0), the four highlighted cells could swap their numbers and the puzzle would have two solutions. So \(cell(target)) can be neither.")
            }
            let z = step.digits.last ?? 0
            let (a, b) = endpoints(step)
            return String(localized: "Unless \(a) or \(b) is \(z), the four highlighted cells could swap their numbers and the puzzle would have two solutions. So one of them is \(z), and cells that see both can't be \(z).")

        case .bugPlusOne:
            let target = cell(step.placement?.cell ?? 0)
            return String(localized: "Every other unsolved cell has exactly two candidates. If \(target) weren't \(digit), the puzzle would have more than one solution – so it must be \(digit).")
        }
    }

    private static func endpoints(_ step: LogicStep) -> (String, String) {
        (cell(step.endpoints.first ?? 0), cell(step.endpoints.last ?? 0))
    }

    private static func eliminatedDigit(_ step: LogicStep) -> Int {
        step.eliminations.first?.digit ?? 0
    }

    /// One line naming the cells the hint is about and what applying it does. The board highlights
    /// them too, but VoiceOver users can't see that.
    static func result(for hint: HintSession) -> String? {
        switch hint.content {
        case .mistakes(let cells):
            cells.count == 1
                ? String(localized: "Remove the number from \(cell(cells[0])).")
                : String(localized: "Remove the numbers from \(Self.cells(cells)).")
        case .badNotes(let cells):
            cells.count == 1
                ? String(localized: "Fix the notes in cell \(cell(cells[0])).")
                : String(localized: "Fix the notes in cells \(Self.cells(cells)).")
        case .noStep:
            nil
        case .logic:
            hint.isNudge ? nil : hint.currentEntry.flatMap { result(for: $0.step) }
        }
    }

    /// One line describing what applying a step does.
    static func result(for step: LogicStep) -> String? {
        if let placement = step.placement {
            return String(localized: "Place \(placement.digit) in \(cell(placement.cell)).")
        }
        guard !step.eliminations.isEmpty else { return nil }
        let removed = step.eliminations.map {
            String(localized: "\($0.digit) from \(cell($0.cell))", comment: "Elimination item in a hint: <digit> from <cell coordinate>.")
        }
        // The board shows every elimination; a long list is cut short rather than filling the panel.
        guard removed.count > 6 else { return String(localized: "Remove \(list(removed)).") }
        return String(localized: "Remove \(removed.prefix(6).joined(separator: ", ")) and more.")
    }
}
