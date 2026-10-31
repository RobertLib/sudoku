//
//  SudokuApp.swift
//  sudoku
//
//  Created by Robert Libšanský on 31.10.2026.
//

import SwiftUI

@main
struct SudokuApp: App {
    @State private var model: AppModel

    init() {
        #if DEBUG
        DebugScenarios.prepareData()
        #endif
        _model = State(initialValue: AppModel())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.settings)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .game: GameScreen()
                    case .daily: DailyChallengeView()
                    case .statistics: StatisticsView()
                    case .achievements: AchievementsView()
                    case .help: HelpView()
                    case .customPuzzle: CustomPuzzleView()
                    }
                }
        }
        .tint(settings.theme.accent)
        .environment(\.palette, settings.theme.palette)
        .preferredColorScheme(settings.appearance.colorScheme)
        .sheet(isPresented: $model.showSettings) {
            SettingsView()
                .environment(model)
                .environment(settings)
                .tint(settings.theme.accent)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
        .sheet(isPresented: $model.showWelcome, onDismiss: { settings.hasSeenWelcome = true }) {
            WelcomeView()
                .tint(settings.theme.accent)
                // A sheet doesn't see the environment set on the navigation stack.
                .environment(\.palette, settings.theme.palette)
                .interactiveDismissDisabled()
        }
        .confirmationDialog(
            "Start a new game?",
            isPresented: Binding(get: { model.pendingRequest != nil }, set: { if !$0 { model.pendingRequest = nil } }),
            titleVisibility: .visible
        ) {
            Button("Start New Game", role: .destructive) { model.confirmPendingRequest() }
            Button("Cancel", role: .cancel) { model.pendingRequest = nil }
        } message: {
            // A game left on its game over card (the app was closed there) counts as lost, not as unfinished.
            if model.savedStandardGame?.awaitsSecondChance == true {
                Text("Your game will count as lost, and its second chance will be gone.")
            } else {
                Text("Your unfinished game will be lost and counted as not completed.")
            }
        }
        .overlay {
            if model.isPreparingGame {
                PreparingOverlay()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.isPreparingGame)
        .onChange(of: scenePhase) { _, phase in
            model.scenePhaseChanged(to: phase)
        }
        // Posted at midnight and when the time zone or clock changes.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            model.refreshToday()
        }
        .task {
            if settings.soundEnabled {
                try? await Task.sleep(for: .seconds(0.8))
                await SoundEngine.shared.warmUp()
            }
        }
        #if DEBUG
        .task { await DebugScenarios.run(model: model) }
        #endif
    }
}

/// Shown while a puzzle is being generated (rarely visible thanks to the cache).
private struct PreparingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.15).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text("Creating your puzzle…")
                    .font(.headline)
            }
            .padding(28)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .task {
            // Mostly gone in a moment (the cache has a puzzle ready); a longer wait is worth telling.
            do { try await Task.sleep(for: .milliseconds(600)) } catch { return }
            AccessibilityNotification.Announcement(String(localized: "Creating your puzzle…")).post()
        }
    }
}
