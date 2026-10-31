//
//  Theme.swift
//  sudoku
//

import SwiftUI

enum ThemeColor: String, CaseIterable, Identifiable {
    case blue, indigo, teal, green, orange, pink, purple, graphite

    var id: String { rawValue }

    /// Made once per theme: a dynamic color is a new object each time it's created, so a palette
    /// made afresh on every update would never compare equal and would redraw every cell.
    var palette: Palette { Self.palettes[self]! }

    var accent: Color { Self.accents[self]! }

    /// Fill of prominent buttons, whose labels the system draws in white.
    var buttonFill: Color { Self.buttonFills[self]! }

    private static let accents: [ThemeColor: Color] = Dictionary(uniqueKeysWithValues: allCases.map {
        ($0, Color(light: $0.tones.light, dark: $0.tones.dark))
    })

    /// The accent in light mode. In dark mode the accent is lightened to stand out on black, which
    /// white can't be read on, so buttons keep the light mode shade (graphite: a lighter one).
    private static let buttonFills: [ThemeColor: Color] = Dictionary(uniqueKeysWithValues: allCases.map {
        ($0, Color(light: $0.tones.light, dark: $0 == .graphite ? (0.40, 0.43, 0.49) : $0.tones.light))
    })

    private static let palettes: [ThemeColor: Palette] = Dictionary(uniqueKeysWithValues: allCases.map { ($0, $0.makePalette()) })

    private func makePalette() -> Palette {
        switch self {
        case .orange:
            // The usual orange hint colors would blend with the accent, so hints switch to blue.
            Palette(
                accent: accent,
                buttonFill: buttonFill,
                hintAlternate: Color(light: (0.13, 0.42, 0.93), dark: (0.36, 0.60, 1.00)),
                hintHouse: Color(light: (0.20, 0.58, 0.96), dark: (0.36, 0.66, 1.00))
            )
        case .graphite:
            // Gray digits of the player's would hardly differ from the near-black givens: slate instead.
            Palette(accent: accent, buttonFill: buttonFill, userDigit: Color(light: (0.30, 0.40, 0.56), dark: (0.55, 0.63, 0.78)))
        default:
            Palette(accent: accent, buttonFill: buttonFill)
        }
    }

    /// Light accents keep `Palette.onFill` (white) at 4.5:1 or more, dark ones near-black at 6.5:1 or more.
    private var tones: (light: (Double, Double, Double), dark: (Double, Double, Double)) {
        switch self {
        case .blue: ((0.13, 0.42, 0.93), (0.36, 0.60, 1.00))
        case .indigo: ((0.33, 0.32, 0.82), (0.55, 0.54, 1.00))
        case .teal: ((0.00, 0.51, 0.57), (0.25, 0.76, 0.80))
        case .green: ((0.12, 0.53, 0.30), (0.33, 0.80, 0.50))
        case .orange: ((0.75, 0.35, 0.05), (1.00, 0.62, 0.28))
        case .pink: ((0.82, 0.18, 0.44), (1.00, 0.45, 0.64))
        case .purple: ((0.56, 0.27, 0.82), (0.76, 0.52, 1.00))
        case .graphite: ((0.28, 0.31, 0.36), (0.72, 0.75, 0.80))
        }
    }
}

/// Colors used by the board and controls, derived from the theme's accent.
/// Everything is stored rather than computed, for the reason given at `ThemeColor.palette`.
struct Palette {
    let accent: Color
    /// See `ThemeColor.buttonFill`.
    let buttonFill: Color
    /// The second hint color (the other color in coloring and chains, chain links).
    /// Must stay clearly apart from the accent, which draws the pattern itself.
    let hintAlternate: Color
    /// Tint of the houses a hint is about.
    let hintHouse: Color

    let screenBackground = Self.screenBackground
    let boardBackground = Self.boardBackground
    let controlBackground = Self.controlBackground
    let thinLine = Self.thinLine
    let thickLine = Self.thickLine
    let givenDigit = Self.givenDigit
    let notesDigit = Self.notesDigit
    /// Notes and candidates on a tinted cell (selected, wrong, or picked out by a hint), where
    /// `notesDigit` would fall below 4.5:1.
    let notesDigitOnTint = Self.notesDigitOnTint
    /// A candidate a hint crosses out, on its light red circle.
    let eliminatedDigit = Self.eliminatedDigit
    let error = Self.error
    let success = Self.success
    let warning = Self.warning
    /// Text and symbols on a solid fill of the accent, success, hint or difficulty colors: those are
    /// dark enough for white in light mode and light enough for near-black in dark mode.
    let onFill = Self.onFill
    /// Streaks and records: orange, dark enough in light mode to be read as text.
    let flame = Self.flame

    let userDigit: Color
    let selectedFill: Color
    let peerFill: Color
    let sameDigitFill: Color
    let errorFill: Color
    let hintHouseFill: Color
    let hintSecondaryFill: Color
    let hintPatternFill: Color
    let hintTargetFill: Color

    init(
        accent: Color,
        buttonFill: Color,
        hintAlternate: Color = Color(light: (0.73, 0.36, 0.04), dark: (1.0, 0.62, 0.25)),
        hintHouse: Color = Color(light: (0.95, 0.62, 0.05), dark: (1.0, 0.75, 0.25)),
        userDigit: Color? = nil
    ) {
        self.accent = accent
        self.buttonFill = buttonFill
        self.hintAlternate = hintAlternate
        self.hintHouse = hintHouse
        self.userDigit = userDigit ?? accent
        selectedFill = accent.opacity(0.30)
        peerFill = accent.opacity(0.085)
        sameDigitFill = accent.opacity(0.19)
        errorFill = Self.error.opacity(0.14)
        hintHouseFill = hintHouse.opacity(0.16)
        hintSecondaryFill = accent.opacity(0.08)
        hintPatternFill = accent.opacity(0.20)
        hintTargetFill = Self.success.opacity(0.26)
    }

    private static let screenBackground = Color(light: (0.95, 0.95, 0.97), dark: (0.0, 0.0, 0.0))
    private static let boardBackground = Color(light: (1, 1, 1), dark: (0.11, 0.11, 0.125))
    private static let controlBackground = Color(light: (1, 1, 1), dark: (0.16, 0.16, 0.18))
    private static let thinLine = Color(light: (0.80, 0.81, 0.84), dark: (0.26, 0.26, 0.29))
    private static let thickLine = Color(light: (0.22, 0.24, 0.30), dark: (0.62, 0.63, 0.68))
    private static let givenDigit = Color(light: (0.10, 0.11, 0.14), dark: (0.93, 0.93, 0.95))
    private static let notesDigit = Color(light: (0.40, 0.42, 0.47), dark: (0.66, 0.67, 0.72))
    private static let notesDigitOnTint = Color(light: (0.30, 0.32, 0.37), dark: (0.76, 0.77, 0.82))
    private static let eliminatedDigit = Color(light: (0.58, 0.05, 0.08), dark: (1.0, 0.74, 0.74))
    /// Dark enough in light mode to be read as text on the gray screen background (the mistake count).
    private static let error = Color(light: (0.82, 0.13, 0.16), dark: (1.0, 0.37, 0.37))
    private static let success = Color(light: (0.10, 0.53, 0.30), dark: (0.30, 0.82, 0.50))
    private static let warning = Color(light: (0.95, 0.62, 0.05), dark: (1.0, 0.75, 0.25))
    private static let onFill = Color(light: (1, 1, 1), dark: (0.06, 0.06, 0.08))
    private static let flame = Color(light: (0.70, 0.36, 0.0), dark: (1.0, 0.62, 0.04))

    static let `default` = ThemeColor.blue.palette
}

extension EnvironmentValues {
    @Entry var palette: Palette = .default
}

extension Color {
    /// A color that adapts to light and dark appearance.
    ///
    /// `nonisolated`, and so is the provider it hands to UIKit: SwiftUI resolves colors on its
    /// render thread too (e.g. the tint of glass buttons), and a provider isolated to the main
    /// actor, as everything in this target is by default, traps there.
    nonisolated init(light: (Double, Double, Double), dark: (Double, Double, Double)) {
        self.init(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }
}
