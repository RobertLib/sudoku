//
//  CustomPuzzleView.swift
//  sudoku
//
//  Enter a puzzle (e.g. from a newspaper), validate it and play it.
//

import SwiftUI

struct CustomPuzzleView: View {
    private enum Analysis: Equatable {
        case empty
        case tooFewClues(Int)
        /// Every cell is filled, so there would be nothing left to solve.
        case complete
        case conflict
        case checking
        case noSolution
        case multipleSolutions
        /// `givens` is the grid that was analyzed, so a stale result is never played.
        case unique(givens: [UInt8], solution: [UInt8], difficulty: Difficulty?)
    }

    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette
    @State private var cells = [UInt8](repeating: 0, count: 81)
    @State private var selection: Int? = 0
    @State private var analysis: Analysis = .empty
    @State private var showInvalidPaste = false
    /// The verdict VoiceOver last read out, so typing more clues doesn't repeat it after every digit.
    @State private var lastAnnouncement: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height * 1.12
            Group {
                if isLandscape {
                    HStack(spacing: 24) {
                        board
                        VStack(spacing: 16) {
                            statusCard
                            pad
                            actions
                        }
                        .frame(width: min(380, proxy.size.width * 0.38))
                    }
                    .padding(20)
                } else {
                    VStack(spacing: 14) {
                        statusCard
                        board
                            .layoutPriority(1)
                        pad
                        actions
                    }
                    .frame(maxWidth: 640)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // As in the game: the board doesn't grow with Dynamic Type, so the text around it stops too.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
        .background(palette.screenBackground.ignoresSafeArea())
        .navigationTitle("Custom Puzzle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    withAnimation { cells = Array(repeating: 0, count: 81) }
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(cells.allSatisfy { $0 == 0 })
            }
        }
        .alert("Couldn't read a puzzle", isPresented: $showInvalidPaste) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Copy 81 characters: digits 1–9 for clues and 0 or a dot for empty cells.")
        }
        .hardwareKeyboardInput(focus: $isFocused, action: handleKey)
        #if DEBUG
        .onAppear {
            // `-debugCustomPuzzle <81 cells>`: a puzzle already typed in, for screenshots.
            if let text = UserDefaults.standard.string(forKey: "debugCustomPuzzle"), let parsed = PuzzleParser.parse(text) {
                cells = parsed
                selection = nil
            }
        }
        #endif
        .task(id: cells) { await analyze() }
        .onChange(of: analysis) { _, analysis in
            // Every digit typed goes through `checking`; the verdict that follows is what counts.
            guard analysis != .checking else { return }
            let announcement = announcement(for: analysis)
            if let announcement, announcement != lastAnnouncement {
                AccessibilityNotification.Announcement(announcement).post()
            }
            lastAnnouncement = announcement
        }
        // An alert or dialog may take the keyboard focus with it; give it back to the board.
        .onChange(of: showInvalidPaste) { _, isShown in if !isShown { isFocused = true } }
        .onChange(of: model.pendingRequest) { _, request in if request == nil { isFocused = true } }
    }

    // MARK: Board

    private var board: some View {
        let conflicts = conflictingCells
        return BoardSquare(models: (0..<81).map { model(for: $0, conflicts: conflicts) }, select: { selection = $0 })
    }

    private func model(for index: Int, conflicts: Set<Int>) -> CellModel {
        var fill: CellFill = .none
        if selection == index {
            fill = .selected
        } else if conflicts.contains(index) {
            fill = .error
        } else if let selection, Grid.sees(selection, index) {
            fill = .peer
        }
        return CellModel(
            index: index,
            value: Int(cells[index]),
            notes: 0,
            isGiven: true,
            isSelected: selection == index,
            fill: fill,
            tone: conflicts.contains(index) ? .conflict : .given,
            isRepeated: conflicts.contains(index),
            noteHighlight: 0,
            hintMarks: nil,
            isHintTarget: false,
            isHidden: false,
            flash: FlashToken(),
            shake: 0
        )
    }

    private var conflictingCells: Set<Int> {
        Grid.conflictingCells(in: cells)
    }

    // MARK: Input

    private var pad: some View {
        HStack(spacing: 5) {
            ForEach(1...9, id: \.self) { digit in
                Button {
                    enter(digit)
                } label: {
                    Text(verbatim: "\(digit)")
                        .font(.system(size: 28, weight: .medium, design: settings.digitStyle.design))
                        .foregroundStyle(palette.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(palette.controlBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(PressableStyle())
            }
            Button {
                enter(0)
            } label: {
                Image(systemName: "delete.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(palette.controlBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(Text("Erase"))
        }
        .frame(height: 56)
    }

    private func enter(_ digit: Int) {
        guard let selection else { return }
        let value: UInt8 = cells[selection] == UInt8(digit) ? 0 : UInt8(digit)
        cells[selection] = value
        Feedback.play(value == 0 ? .erase : .place, settings: settings)
        // Only a digit typed in moves on; tapping the cell's own digit clears it and stays.
        if value != 0, selection < 80 {
            self.selection = selection + 1
        }
    }

    /// Typing works like typing the puzzle as text: every digit, and `0`, `.` or space for an empty
    /// cell, fills one cell and moves on, so a row from a newspaper can be typed as it is printed.
    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard !press.modifiers.contains(.command) else { return .ignored }
        if press.isArrow {
            let current = selection ?? 0
            switch press.key {
            case .upArrow: selection = (current + 72) % 81
            case .downArrow: selection = (current + 9) % 81
            case .leftArrow: selection = (current + 80) % 81
            default: selection = (current + 1) % 81
            }
            return .handled
        }
        guard let current = selection else { return .ignored }
        switch press.key {
        case .delete:
            // Like ⌫ in text: clears the cell, or the one before it when this one is already empty.
            let cell = cells[current] == 0 && current > 0 ? current - 1 : current
            cells[cell] = 0
            selection = cell
            Feedback.play(.erase, settings: settings)
        case .deleteForward:
            cells[current] = 0
            Feedback.play(.erase, settings: settings)
        default:
            guard let digit = press.characters == "." || press.characters == " " ? 0 : press.digit else { return .ignored }
            cells[current] = UInt8(digit)
            selection = min(current + 1, 80)
            Feedback.play(digit == 0 ? .erase : .place, settings: settings)
        }
        return .handled
    }

    // MARK: Validation

    private func analyze() async {
        let clues = cells.count { $0 != 0 }
        if clues == 0 {
            analysis = .empty
            return
        }
        if !conflictingCells.isEmpty {
            analysis = .conflict
            return
        }
        if clues < 17 {
            analysis = .tooFewClues(clues)
            return
        }
        if clues == 81 {
            analysis = .complete
            return
        }
        analysis = .checking
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        let snapshot = cells
        let check = Task.detached(priority: .userInitiated) { () -> Analysis in
            let count = Solver.countSolutions(snapshot, limit: 2)
            // Stopped early (see `Solver.countSolutions`): the count means nothing.
            guard !Task.isCancelled else { return .checking }
            switch count {
            case 0:
                return .noSolution
            case 1:
                let solution = Solver.solve(snapshot) ?? snapshot
                return .unique(givens: snapshot, solution: solution, difficulty: LogicalSolver.rate(snapshot).techniqueDifficulty)
            default:
                return .multipleSolutions
            }
        }
        // A detached task isn't cancelled with this one: another edit must stop the search, not
        // leave it running next to the new one.
        let result = await withTaskCancellationHandler { await check.value } onCancel: { check.cancel() }
        guard !Task.isCancelled else { return }
        withAnimation { analysis = result }
    }

    // MARK: Status & actions

    private var statusCard: some View {
        HStack(spacing: 12) {
            Group {
                if analysis == .checking {
                    ProgressView()
                } else {
                    Image(systemName: statusSymbol)
                        .foregroundStyle(statusColor)
                }
            }
            .font(.title2)
            .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                statusTitle
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                statusDetail
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(palette.controlBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var statusSymbol: String {
        switch analysis {
        case .empty: "square.and.pencil"
        case .tooFewClues: "number"
        case .complete: "square.grid.3x3.fill"
        case .conflict, .noSolution: "xmark.octagon.fill"
        case .checking: "hourglass"
        case .multipleSolutions: "exclamationmark.triangle.fill"
        case .unique: "checkmark.seal.fill"
        }
    }

    private var statusColor: Color {
        switch analysis {
        case .empty, .tooFewClues, .checking: palette.accent
        case .conflict, .noSolution: palette.error
        case .complete, .multipleSolutions: palette.warning
        case .unique: palette.success
        }
    }

    private var statusTitle: Text {
        switch analysis {
        case .empty: Text("Enter the clues")
        case .tooFewClues(let count): Text("\(count) clues entered")
        case .complete: Text("Every cell is filled")
        case .conflict: Text("Some numbers repeat")
        case .checking: Text("Checking…")
        case .noSolution: Text("No solution")
        case .multipleSolutions: Text("More than one solution")
        case .unique(_, _, let difficulty):
            if let difficulty {
                Text("Valid puzzle · \(Text(difficulty.title).foregroundStyle(difficulty.color))")
            } else {
                Text("Valid puzzle · Extreme")
            }
        }
    }

    private var statusDetail: Text {
        switch analysis {
        case .empty: Text("Tap a cell and type the numbers from your puzzle, or paste one.")
        case .tooFewClues: Text("A proper sudoku needs at least 17 clues.")
        case .complete: Text("Leave the cells you want to solve empty.")
        case .conflict: Text("Fix the highlighted cells.")
        case .checking: Text("Looking for solutions.")
        case .noSolution: Text("Check the clues – this grid can't be solved.")
        case .multipleSolutions: Text("Add more clues so the solution is unique.")
        case .unique(_, _, let difficulty):
            difficulty == nil
                ? Text("Harder than the hint engine can explain.")
                : Text("Exactly one solution. Ready to play!")
        }
    }

    /// What VoiceOver says when a check has a verdict. Nothing while clues are being typed in,
    /// where every digit would change the count.
    private func announcement(for analysis: Analysis) -> String? {
        switch analysis {
        case .empty, .tooFewClues, .checking:
            nil
        case .complete:
            String(localized: "Every cell is filled") + ". " + String(localized: "Leave the cells you want to solve empty.")
        case .conflict:
            String(localized: "Some numbers repeat") + ". " + String(localized: "Fix the highlighted cells.")
        case .noSolution:
            String(localized: "No solution") + ". " + String(localized: "Check the clues – this grid can't be solved.")
        case .multipleSolutions:
            String(localized: "More than one solution") + ". " + String(localized: "Add more clues so the solution is unique.")
        case .unique(_, _, let difficulty):
            if let difficulty {
                String(localized: "Valid puzzle · \(String(localized: difficulty.title))") + ". " + String(localized: "Exactly one solution. Ready to play!")
            } else {
                String(localized: "Valid puzzle · Extreme") + ". " + String(localized: "Harder than the hint engine can explain.")
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            PasteButton(payloadType: String.self) { strings in
                guard let text = strings.first, let parsed = PuzzleParser.parse(text) else {
                    showInvalidPaste = true
                    return
                }
                withAnimation { cells = parsed }
            }
            .labelStyle(.iconOnly)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(palette.buttonFill)

            playButton
        }
    }

    private var playButton: some View {
        Button {
            if case .unique(let givens, let solution, let difficulty) = analysis, givens == cells {
                model.request(.custom(givens: givens, solution: solution, difficulty: difficulty))
            }
        } label: {
            Label("Play This Puzzle", systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .tint(palette.buttonFill)
        .controlSize(.large)
        .disabled({ if case .unique(let givens, _, _) = analysis { givens != cells } else { true } }())
    }
}
