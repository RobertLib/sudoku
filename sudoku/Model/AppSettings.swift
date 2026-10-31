//
//  AppSettings.swift
//  sudoku
//

import SwiftUI

@Observable
final class AppSettings {
    enum MistakeMode: String, CaseIterable, Identifiable {
        /// Wrong digits are shown immediately and counted.
        case instant
        /// Only rule violations (duplicates) are highlighted.
        case conflicts
        /// No checking at all.
        case off

        var id: String { rawValue }
    }

    enum InputMode: String, CaseIterable, Identifiable {
        /// Select a cell, then tap a digit.
        case cellFirst
        /// Pick a digit, then tap the cells to fill.
        case digitFirst

        var id: String { rawValue }
    }

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark

        var id: String { rawValue }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
    }

    enum DigitStyle: String, CaseIterable, Identifiable {
        case standard, rounded, serif, monospaced

        var id: String { rawValue }

        var design: Font.Design {
            switch self {
            case .standard: .default
            case .rounded: .rounded
            case .serif: .serif
            case .monospaced: .monospaced
            }
        }
    }

    private let defaults: UserDefaults

    // Gameplay
    var mistakeMode: MistakeMode { didSet { store(mistakeMode.rawValue, "mistakeMode") } }
    var mistakeLimitEnabled: Bool { didSet { store(mistakeLimitEnabled, "mistakeLimitEnabled") } }
    var inputMode: InputMode { didSet { store(inputMode.rawValue, "inputMode") } }
    var autoRemoveNotes: Bool { didSet { store(autoRemoveNotes, "autoRemoveNotes") } }
    var highlightPeers: Bool { didSet { store(highlightPeers, "highlightPeers") } }
    var highlightSameDigits: Bool { didSet { store(highlightSameDigits, "highlightSameDigits") } }
    var hideCompletedDigits: Bool { didSet { store(hideCompletedDigits, "hideCompletedDigits") } }
    var showRemainingCounts: Bool { didSet { store(showRemainingCounts, "showRemainingCounts") } }
    var showTimer: Bool { didSet { store(showTimer, "showTimer") } }
    var keepScreenOn: Bool { didSet { store(keepScreenOn, "keepScreenOn") } }

    // Appearance
    var appearance: Appearance { didSet { store(appearance.rawValue, "appearance") } }
    var theme: ThemeColor { didSet { store(theme.rawValue, "theme") } }
    var digitStyle: DigitStyle { didSet { store(digitStyle.rawValue, "digitStyle") } }

    // Feedback
    var soundEnabled: Bool { didSet { store(soundEnabled, "soundEnabled") } }
    var hapticsEnabled: Bool { didSet { store(hapticsEnabled, "hapticsEnabled") } }

    // Onboarding
    var hasSeenWelcome: Bool { didSet { store(hasSeenWelcome, "hasSeenWelcome") } }

    private enum Default {
        static let mistakeMode = MistakeMode.instant
        static let mistakeLimitEnabled = true
        static let inputMode = InputMode.cellFirst
        static let autoRemoveNotes = true
        static let highlightPeers = true
        static let highlightSameDigits = true
        static let hideCompletedDigits = true
        static let showRemainingCounts = true
        static let showTimer = true
        static let keepScreenOn = false
        static let appearance = Appearance.system
        static let theme = ThemeColor.blue
        static let digitStyle = DigitStyle.standard
        static let soundEnabled = true
        static let hapticsEnabled = true
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func value<T: RawRepresentable>(_ key: String, _ fallback: T) -> T where T.RawValue == String {
            defaults.string(forKey: key).flatMap { T(rawValue: $0) } ?? fallback
        }
        func flag(_ key: String, _ fallback: Bool) -> Bool {
            defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
        }
        mistakeMode = value("mistakeMode", Default.mistakeMode)
        mistakeLimitEnabled = flag("mistakeLimitEnabled", Default.mistakeLimitEnabled)
        inputMode = value("inputMode", Default.inputMode)
        autoRemoveNotes = flag("autoRemoveNotes", Default.autoRemoveNotes)
        highlightPeers = flag("highlightPeers", Default.highlightPeers)
        highlightSameDigits = flag("highlightSameDigits", Default.highlightSameDigits)
        hideCompletedDigits = flag("hideCompletedDigits", Default.hideCompletedDigits)
        showRemainingCounts = flag("showRemainingCounts", Default.showRemainingCounts)
        showTimer = flag("showTimer", Default.showTimer)
        keepScreenOn = flag("keepScreenOn", Default.keepScreenOn)
        appearance = value("appearance", Default.appearance)
        theme = value("theme", Default.theme)
        digitStyle = value("digitStyle", Default.digitStyle)
        soundEnabled = flag("soundEnabled", Default.soundEnabled)
        hapticsEnabled = flag("hapticsEnabled", Default.hapticsEnabled)
        hasSeenWelcome = flag("hasSeenWelcome", false)
    }

    /// The mistake limit currently in force, if any.
    var mistakeLimit: Int? {
        mistakeMode == .instant && mistakeLimitEnabled ? 3 : nil
    }

    func resetToDefaults() {
        mistakeMode = Default.mistakeMode
        mistakeLimitEnabled = Default.mistakeLimitEnabled
        inputMode = Default.inputMode
        autoRemoveNotes = Default.autoRemoveNotes
        highlightPeers = Default.highlightPeers
        highlightSameDigits = Default.highlightSameDigits
        hideCompletedDigits = Default.hideCompletedDigits
        showRemainingCounts = Default.showRemainingCounts
        showTimer = Default.showTimer
        keepScreenOn = Default.keepScreenOn
        appearance = Default.appearance
        theme = Default.theme
        digitStyle = Default.digitStyle
        soundEnabled = Default.soundEnabled
        hapticsEnabled = Default.hapticsEnabled
    }

    private func store(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
    }
}
