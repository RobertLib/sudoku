//
//  GameView.swift
//  sudoku
//

import SwiftUI

struct GameScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let session = model.session {
            GameView(session: session)
                .id(session.id)
        } else {
            ContentUnavailableView("No Game", systemImage: "square.grid.3x3", description: Text("Start a new game from the home screen."))
        }
    }
}

struct GameView: View {
    let session: GameSession

    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var showWinCard = false
    @State private var winCardTask: Task<Void, Never>?
    @State private var confirmRestart = false
    @State private var confirmGiveUp = false
    @FocusState private var isFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height * 1.12
            Group {
                if isLandscape {
                    landscapeLayout(size: proxy.size)
                } else {
                    portraitLayout
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // The board doesn't grow with Dynamic Type, and larger text around it would leave it no room.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
        .background(palette.screenBackground.ignoresSafeArea())
        .overlay { overlays }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        // The buttons go rather than the whole bar, which would move the board up under the card and
        // back down as it fades.
        .navigationBarBackButtonHidden(hidesNavigationButtons)
        .hardwareKeyboardInput(focus: $isFocused, action: handleKey)
        .onAppear {
            if scenePhase == .active { session.startTimer() }
            model.updateIdleTimer()
        }
        .onDisappear {
            winCardTask?.cancel()
            // Its task stops here; left set, the toast would come back with the game screen.
            session.message = nil
            model.leaveGame(session)
        }
        .onChange(of: model.showSettings) { _, isShown in
            isShown ? session.stopTimer() : session.startTimer()
            model.updateIdleTimer()
            if !isShown { isFocused = true }
        }
        // A sheet or dialog may take the keyboard focus with it; give it back to the board.
        .onChange(of: confirmRestart) { _, isShown in if !isShown { isFocused = true } }
        .onChange(of: confirmGiveUp) { _, isShown in if !isShown { isFocused = true } }
        .onChange(of: settings.keepScreenOn) { model.updateIdleTimer() }
        .onChange(of: session.status) { _, status in
            model.updateIdleTimer()
            if status == .won { scheduleWinCard() }
            if status == .inProgress {
                winCardTask?.cancel()
                showWinCard = false
            }
        }
        .onChange(of: session.isPaused) { model.updateIdleTimer() }
        .onChange(of: session.state.mistakes) { previous, mistakes in
            announceMistake(previous: previous, mistakes: mistakes)
        }
        .task(id: session.messageCount) {
            guard let message = session.message else { return }
            // High priority: Check Board posts it while its menu closes, and VoiceOver moving back
            // to the More button would otherwise cut it off.
            var announcement = AttributedString(String(localized: message.text))
            announcement.accessibilitySpeechAnnouncementPriority = .high
            AccessibilityNotification.Announcement(announcement).post()
            // Cancelled when the next message replaces this one, which must then stay.
            do { try await Task.sleep(for: .seconds(2.6)) } catch { return }
            withAnimation { session.message = nil }
        }
        .confirmationDialog("Restart this puzzle?", isPresented: $confirmRestart, titleVisibility: .visible) {
            Button("Restart", role: .destructive) { withAnimation { model.restart(session) } }
        } message: {
            // Hints stay with the puzzle (see `GameSession.restart`).
            if session.state.hintsUsed > 0 {
                Text("All your progress on this puzzle will be cleared. The hints you've used still count.")
            } else {
                Text("All your progress on this puzzle will be cleared.")
            }
        }
        .confirmationDialog("Show the solution?", isPresented: $confirmGiveUp, titleVisibility: .visible) {
            Button("Show Solution", role: .destructive) { withAnimation { session.giveUp() } }
        } message: {
            // A daily challenge can be played again, with the solution counted as hints (see `DailyStore.hints`).
            if isDaily {
                Text("The game will end and count as not solved. If you play this daily challenge again, it will count as solved with hints.")
            } else {
                Text("The game will end and count as not solved.")
            }
        }
        .onAppear {
            if session.status == .won { showWinCard = session.completion != nil }
        }
        .environment(\.gameShortcutsEnabled, !isCovered)
    }

    /// A sheet, dialog or another screen (How to Play) is up, or a new game is being made. UIKit still finds
    /// the game's key commands behind them, so ⌘Z would undo a move the player can't see, and Return or Esc
    /// answer a card under Settings or How to Play.
    private var isCovered: Bool {
        model.showSettings || confirmRestart || confirmGiveUp
            || model.path.last != .game || model.pendingRequest != nil || model.isPreparingGame
    }

    // MARK: Layouts

    private var portraitLayout: some View {
        VStack(spacing: 12) {
            InfoBar(session: session)
            board
                .layoutPriority(1)
            controls(isLandscape: false)
                .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(maxWidth: 820)
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private func landscapeLayout(size: CGSize) -> some View {
        // The board is as tall as the screen allows. The column takes the width it leaves (up to 400):
        // on an iPhone that is more than a fixed share, and large text needs it in the hint panel.
        let boardSide = size.height - 24
        let columnWidth = min(400, max(size.width * 0.38, size.width - 40 - 24 - boardSide))
        return HStack(spacing: 24) {
            board
                .frame(maxHeight: .infinity)
            // With large text on an iPhone, the explanation needs the height more than the bar does.
            // Without the room for either, the text gets what is left (see `HintPanel.keepsTextRoom`).
            // The column stays the same view with or without a hint, so the hint panel animates in and
            // out of it as in portrait; a view switched by an `if` around it would just appear.
            ViewThatFits(in: .vertical) {
                landscapeColumn
                if session.hint != nil {
                    controls(isLandscape: true)
                }
            }
            .frame(width: columnWidth)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var landscapeColumn: some View {
        VStack(spacing: 16) {
            InfoBar(session: session)
            controls(isLandscape: true)
        }
    }

    private var board: some View {
        BoardView(session: session)
            .overlay(alignment: .top) {
                if let message = session.message {
                    MessageToast(message: message)
                        .padding(.top, 10)
                        // Over the top row, which the player may well be looking for the mistake in.
                        .allowsHitTesting(false)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.35), value: session.message)
    }

    @ViewBuilder
    private func controls(isLandscape: Bool) -> some View {
        ZStack {
            if session.gaveUp {
                SolutionRevealedBar(isDaily: isDaily, onNewGame: { model.playAgain() }, onClose: { model.closeGame() })
                    .transition(.opacity)
            } else if let hint = session.hint {
                HintPanel(session: session, hint: hint, keepsTextRoom: !isLandscape)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity), removal: .opacity))
            } else {
                VStack(spacing: isLandscape ? 16 : 14) {
                    ToolRow(session: session)
                    NumberPad(session: session, layout: isLandscape ? .grid : .row)
                }
                .padding(.vertical, isLandscape ? 0 : 6)
                .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.3), value: session.hint != nil)
        .animation(.easeInOut, value: session.gaveUp)
    }

    // MARK: Overlays

    @ViewBuilder
    private var overlays: some View {
        if session.isPaused {
            PauseOverlay(session: session, onClose: { model.closeGame() })
                .transition(.opacity)
        } else if session.status == .lost && !session.gaveUp {
            GameOverOverlay(
                session: session,
                onRestart: { model.restart(session) },
                onNewGame: { model.playAgain() },
                onClose: { model.closeGame() }
            )
                .transition(.opacity)
        } else if showWinCard, let summary = session.completion {
            WinOverlay(
                session: session,
                summary: summary,
                onNewGame: { model.playAgain() },
                onDone: { model.closeGame() }
            )
            .transition(.opacity)
        }
    }

    private var isDaily: Bool { session.state.kind.dailyKey != nil }

    /// Nothing to tap above the pause card. A card is modal for VoiceOver, but that doesn't reach the
    /// navigation bar, whose buttons would stay a swipe away; the cards have buttons of their own to leave.
    private var hidesNavigationButtons: Bool {
        session.isPaused || (voiceOverEnabled && isShowingCard)
    }

    /// The win or game over card is up.
    private var isShowingCard: Bool {
        (session.status == .lost && !session.gaveUp) || (showWinCard && session.completion != nil)
    }

    private func scheduleWinCard() {
        winCardTask?.cancel()
        winCardTask = Task {
            do { try await Task.sleep(for: .seconds(1.3)) } catch { return }
            withAnimation { showWinCard = true }
        }
    }

    /// Instant checking shows a wrong digit in red and shakes it; VoiceOver users hear it. Never in the
    /// other modes, where it would give the mistake away. A mistake that ends the game is told by its card.
    private func announceMistake(previous: Int, mistakes: Int) {
        guard mistakes > previous, settings.mistakeMode == .instant, session.status == .inProgress else { return }
        let text = session.mistakeLimit.map { limit in
            String(localized: "Wrong number. Mistake \(session.limitedMistakes) of \(limit).")
        } ?? String(localized: "Wrong number.")
        // High priority: VoiceOver reading the pad key's new count would otherwise cut it off.
        var announcement = AttributedString(text)
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if !hidesNavigationButtons {
            toolbarButtons
        }
    }

    @ToolbarContentBuilder
    private var toolbarButtons: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if session.status == .inProgress {
                Button {
                    withAnimation { session.togglePause() }
                } label: {
                    Label("Pause", systemImage: "pause")
                }
                .gameKeyboardShortcut(KeyboardShortcut("p", modifiers: .command))
            }

            Menu {
                Section {
                    Button {
                        session.redo()
                    } label: {
                        Label("Redo", systemImage: "arrow.uturn.forward")
                    }
                    .gameKeyboardShortcut(KeyboardShortcut("z", modifiers: [.command, .shift]))
                    .disabled(!session.canRedo)
                }
                Section {
                    Button {
                        withAnimation { session.announcingChanges { session.fillAllNotes() } }
                    } label: {
                        Label("Auto Notes", systemImage: "wand.and.stars")
                    }
                    Button {
                        withAnimation { session.announcingChanges { session.clearAllNotes() } }
                    } label: {
                        Label("Clear All Notes", systemImage: "eraser.line.dashed")
                    }
                    .disabled(!session.hasAnyNotes)
                }
                .disabled(!session.isPlaying)
                Section {
                    if settings.mistakeMode != .instant {
                        Button {
                            withAnimation { session.checkBoard() }
                        } label: {
                            Label("Check Board", systemImage: "checkmark.circle")
                        }
                        .disabled(!session.isPlaying)
                    }
                    Button {
                        withAnimation { session.announcingChanges { session.revealSelectedCell() } }
                    } label: {
                        Label("Reveal Selected Cell", systemImage: "eye")
                    }
                    .disabled(!session.canRevealSelection)
                }
                Section {
                    Button {
                        confirmRestart = true
                    } label: {
                        Label("Restart", systemImage: "arrow.counterclockwise")
                    }
                    Button(role: .destructive) {
                        confirmGiveUp = true
                    } label: {
                        Label("Show Solution", systemImage: "flag")
                    }
                }
                .disabled(session.status != .inProgress)
                Section {
                    Button {
                        model.showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    Button {
                        model.path.append(.help)
                    } label: {
                        Label("How to Play", systemImage: "questionmark.circle")
                    }
                }
            } label: {
                Label("More", systemImage: "ellipsis")
            }
        }
    }

    // MARK: Keyboard

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard !isCovered else { return .ignored }
        if session.isPaused {
            let resumes = press.key == .return || press.key == .space
                || (press.modifiers.contains(.command) && press.characters.lowercased() == "p")
            guard resumes else { return .ignored }
            withAnimation { session.resume() }
            return .handled
        }
        // The daily cards and the bar of a revealed solution have no button for Esc: their way out takes
        // Return, as there's no new game to start.
        if press.key == .escape, isDaily, (isShowingCard && !session.canUseSecondChance) || session.gaveUp {
            model.closeGame()
            return .handled
        }
        guard session.isPlaying else { return .ignored }
        if press.modifiers.contains(.command) {
            // Handled here rather than by button shortcuts: the Undo button leaves with the tool row
            // while a hint is shown, and Redo's shortcut doesn't fire from inside the closed menu.
            guard press.characters.lowercased() == "z" else { return .ignored }
            press.modifiers.contains(.shift) ? session.redo() : session.undo()
            return .handled
        }
        switch press.key {
        case .upArrow:
            session.moveSelection(rows: -1, columns: 0)
        case .downArrow:
            session.moveSelection(rows: 1, columns: 0)
        case .leftArrow:
            session.moveSelection(rows: 0, columns: -1)
        case .rightArrow:
            session.moveSelection(rows: 0, columns: 1)
        case .delete, .deleteForward:
            session.erase()
        case .escape:
            if session.hint != nil { session.dismissHint() } else { return .ignored }
        default:
            guard let character = press.characters.first else { return .ignored }
            if let digit = press.digit {
                digit == 0 ? session.erase() : session.enter(digit)
            } else {
                switch character.lowercased() {
                case "n": session.toggleNotesMode()
                case "h": session.requestHint()
                case "u": session.undo()
                case " ": session.toggleNotesMode()
                default: return .ignored
                }
            }
        }
        return .handled
    }
}

extension GameSession {
    /// Runs an action and tells VoiceOver what it changed on the board: the menu or hint panel it came
    /// from closes, and nothing else would say it. A win is told by its card.
    func announcingChanges(_ action: () -> Void) {
        let before = state
        action()
        guard status == .inProgress, let text = Self.change(from: before, to: state, selection: selection) else { return }
        // High priority: VoiceOver moving on to another control would otherwise cut it off.
        var announcement = AttributedString(text)
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
    }

    static func change(from old: GameState, to new: GameState, selection: Int?) -> String? {
        let placed = (0..<81).filter { new.values[$0] != 0 && new.values[$0] != old.values[$0] }
        let removed = (0..<81).count { old.values[$0] != 0 && new.values[$0] == 0 }
        if placed.count == 1, let cell = placed.first {
            return String(localized: "\(Int(new.values[cell])) placed in \(HintText.cell(cell)).", comment: "VoiceOver, after a hint or Reveal: <digit> placed in <cell coordinate>.")
        }
        if removed > 0 {
            return String(localized: "\(removed) numbers removed.", comment: "VoiceOver, after a hint removed wrong numbers.")
        }
        if new.notes != old.notes {
            return new.notes.allSatisfy { $0 == 0 } ? String(localized: "All notes cleared.") : String(localized: "Notes updated.")
        }
        // Reveal on a digit that was right already only confirms it, with a flash VoiceOver can't see.
        if new.hintsUsed > old.hintsUsed, let cell = selection, new.values[cell] != 0 {
            return String(localized: "\(Int(new.values[cell])) in \(HintText.cell(cell)) is correct.", comment: "VoiceOver, after Reveal on a cell whose number was already right: <digit> in <cell coordinate> is correct.")
        }
        return nil
    }
}

extension EnvironmentValues {
    /// Off while a sheet or dialog covers the game (see `GameView.isCovered`).
    @Entry var gameShortcutsEnabled = true
}

extension View {
    /// A keyboard shortcut of the game screen, which only works while nothing covers the game.
    func gameKeyboardShortcut(_ shortcut: KeyboardShortcut?) -> some View {
        modifier(GameKeyboardShortcut(shortcut: shortcut))
    }
}

private struct GameKeyboardShortcut: ViewModifier {
    let shortcut: KeyboardShortcut?
    @Environment(\.gameShortcutsEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content.keyboardShortcut(isEnabled ? shortcut : nil)
    }
}
