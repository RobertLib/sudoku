//
//  BoardView.swift
//  sudoku
//

import SwiftUI

struct BoardView: View {
    let session: GameSession
    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette

    var body: some View {
        let overlay = session.hint?.overlay
        let models = BoardPresenter(session: session, settings: settings, overlay: overlay).cells()

        BoardSquare(models: models, select: session.select) { cellSize in
            ZStack {
                if let links = overlay?.links, !links.isEmpty {
                    ChainLinksView(links: links, cellSize: cellSize)
                        .transition(.opacity)
                }
            }
            .allowsHitTesting(false)
            // On the container: an animation on the lines themselves would never see them appear.
            .animation(.easeOut(duration: 0.2), value: overlay?.links)
        }
        // Cast by a shape behind the board: on the board itself, the shadow would be drawn under every
        // cell, digit and line inside it.
        .background {
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                RoundedRectangle(cornerRadius: side * boardCornerRatio, style: .continuous)
                    .fill(palette.boardBackground)
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
                    .frame(width: side, height: side)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Sudoku board"))
    }
}

/// The board's corner radius as a share of its side.
private let boardCornerRatio: CGFloat = 0.028

/// The square board shared by the game and the custom puzzle screen: 81 cells, grid lines,
/// rounded corners and a border, with room for decorations drawn on top (e.g. chain links).
struct BoardSquare<Decoration: View>: View {
    let models: [CellModel]
    let select: (Int) -> Void
    @ViewBuilder let decoration: (_ cellSize: CGFloat) -> Decoration
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cellSize = side / 9
            let corner = side * boardCornerRatio

            ZStack(alignment: .topLeading) {
                palette.boardBackground

                VStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { column in
                                let index = row * 9 + column
                                CellView(model: models[index], size: cellSize)
                                    .frame(width: cellSize, height: cellSize)
                                    .contentShape(Rectangle())
                                    .hoverEffect(.highlight)
                                    .onTapGesture { select(index) }
                                    .accessibilityAction { select(index) }
                            }
                        }
                    }
                }

                GridLines()
                    .allowsHitTesting(false)

                decoration(cellSize)
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(palette.thickLine, lineWidth: max(2, side * 0.006))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

extension BoardSquare where Decoration == EmptyView {
    init(models: [CellModel], select: @escaping (Int) -> Void) {
        self.init(models: models, select: select) { _ in EmptyView() }
    }
}

/// Builds the display model for each cell from the game state and settings.
struct BoardPresenter {
    let session: GameSession
    let settings: AppSettings
    let overlay: HintOverlay?

    func cells() -> [CellModel] {
        let state = session.state
        let selection = session.selection
        let highlightDigit = settings.highlightSameDigits ? session.highlightDigit : nil
        let conflicts = settings.mistakeMode == .off ? [] : session.conflictingCells
        let showsHint = overlay != nil
        let isHidden = session.isPaused

        return (0..<81).map { index in
            let value = Int(state.values[index])
            let isGiven = state.givens[index] != 0
            let isConflict = conflicts.contains(index)
            let isWrong = session.isWrong(index)

            var tone: DigitTone = isGiven ? .given : .user
            if !isGiven {
                if (settings.mistakeMode == .instant && isWrong) || session.checkedErrors.contains(index) {
                    tone = .wrong
                } else if isConflict {
                    tone = .conflict
                }
            }

            var fill: CellFill = .none
            if let overlay {
                if overlay.targetCell == index {
                    fill = .hintTarget
                } else if overlay.errorCells.contains(index) {
                    fill = .error
                } else if overlay.patternCells.contains(index) {
                    fill = .hintPattern
                } else if overlay.supportCells.contains(index) {
                    fill = .sameDigit
                } else if overlay.houseCells.contains(index) {
                    fill = .hintHouse
                } else if overlay.secondaryCells.contains(index) {
                    fill = .hintSecondary
                }
            } else if let selection, selection == index {
                fill = .selected
            } else if isConflict || tone == .wrong {
                // A tinted cell, not only red digits: with some themes the player's digits are reddish too.
                fill = .error
            } else if let highlightDigit, value == highlightDigit {
                fill = .sameDigit
            } else if settings.highlightPeers, let selection, Grid.sees(selection, index) {
                fill = .peer
            }

            return CellModel(
                index: index,
                value: value,
                notes: state.notes[index],
                isGiven: isGiven,
                isSelected: selection == index,
                isSelectionOutlined: showsHint && session.movedSelectionDuringHint && selection == index && !isHidden,
                fill: isHidden ? .none : fill,
                tone: tone,
                isRepeated: isConflict,
                noteHighlight: showsHint ? 0 : (highlightDigit ?? 0),
                hintMarks: overlay?.marks[index],
                isHintTarget: overlay?.targetCell == index,
                isHintHighlighted: overlay.map {
                    $0.targetCell == index || $0.errorCells.contains(index) || $0.patternCells.contains(index) || $0.supportCells.contains(index)
                } ?? false,
                isHidden: isHidden,
                flash: session.flashTokens[index],
                shake: session.shakeTokens[index]
            )
        }
    }
}

/// Thin cell lines and thick box lines.
struct GridLines: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Canvas { context, size in
            let step = size.width / 9
            let thin = max(0.5, size.width * 0.0016)
            let thick = max(1.5, size.width * 0.0055)
            var thinPath = Path()
            var thickPath = Path()
            for i in 1..<9 {
                let offset = CGFloat(i) * step
                var line = Path()
                line.move(to: CGPoint(x: offset, y: 0))
                line.addLine(to: CGPoint(x: offset, y: size.height))
                line.move(to: CGPoint(x: 0, y: offset))
                line.addLine(to: CGPoint(x: size.width, y: offset))
                if i % 3 == 0 {
                    thickPath.addPath(line)
                } else {
                    thinPath.addPath(line)
                }
            }
            context.stroke(thinPath, with: .color(palette.thinLine), lineWidth: thin)
            context.stroke(thickPath, with: .color(palette.thickLine), lineWidth: thick)
        }
    }
}

/// Lines between linked candidates while a chain-based hint is shown.
private struct ChainLinksView: View {
    let links: [ChainLink]
    let cellSize: CGFloat
    @Environment(\.palette) private var palette

    var body: some View {
        Canvas { context, _ in
            let radius = cellSize * 0.15
            for link in links {
                let start = center(of: link.from)
                let end = center(of: link.to)
                let dx = end.x - start.x, dy = end.y - start.y
                let length = max(1, sqrt(dx * dx + dy * dy))
                let ux = dx / length, uy = dy / length
                let a = CGPoint(x: start.x + ux * radius, y: start.y + uy * radius)
                let b = CGPoint(x: end.x - ux * radius, y: end.y - uy * radius)

                // Gentle curve so lines don't run straight through other candidates.
                let bend = min(cellSize * 0.5, length * 0.18)
                let control = CGPoint(x: (a.x + b.x) / 2 - uy * bend, y: (a.y + b.y) / 2 + ux * bend)
                var path = Path()
                path.move(to: a)
                path.addQuadCurve(to: b, control: control)

                let style = StrokeStyle(
                    lineWidth: max(1.5, cellSize * 0.045),
                    lineCap: .round,
                    dash: link.isStrong ? [] : [cellSize * 0.1, cellSize * 0.09]
                )
                context.stroke(path, with: .color(palette.hintAlternate.opacity(0.9)), style: style)
            }
        }
    }

    private func center(of candidate: Candidate) -> CGPoint {
        let row = CGFloat(candidate.cell / 9), column = CGFloat(candidate.cell % 9)
        let sub = cellSize / 3
        let subRow = CGFloat((candidate.digit - 1) / 3), subColumn = CGFloat((candidate.digit - 1) % 3)
        return CGPoint(
            x: column * cellSize + sub * (subColumn + 0.5),
            y: row * cellSize + sub * (subRow + 0.5)
        )
    }
}
