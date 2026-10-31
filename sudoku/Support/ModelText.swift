//
//  ModelText.swift
//  sudoku
//
//  Localized names, descriptions and colors for model types.
//

import SwiftUI

/// Locale matching the language the UI is shown in (for dates, calendars, lists).
enum AppLocale {
    static var current: Locale {
        locale(language: Bundle.main.preferredLocalizations.first ?? "en", basedOn: .current)
    }

    /// `base` with its language replaced. The region (e.g. GB in en_GB, for dates and the clock) lives
    /// in the language components, so it is put back: without it, every English locale would be en_US.
    static func locale(language: String, basedOn base: Locale) -> Locale {
        var components = Locale.Components(locale: base)
        components.languageComponents = Locale.Language.Components(identifier: language)
        components.languageComponents.region = base.language.region
        return Locale(components: components)
    }
}

extension Date.FormatStyle {
    /// In the UI's locale and the daily challenges' Gregorian calendar: their keys and the calendar grid
    /// are Gregorian whatever calendar the player prefers (see `DailyChallenge.calendar`).
    func dailyCalendar() -> Self {
        var style = locale(AppLocale.current)
        style.calendar = DailyChallenge.calendar
        return style
    }
}

extension Difficulty {
    var title: LocalizedStringResource {
        switch self {
        case .easy: "Easy"
        case .medium: "Medium"
        case .hard: "Hard"
        case .expert: "Expert"
        case .master: "Master"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .easy: "Relaxed solving with plenty of clues"
        case .medium: "A gentle challenge that needs focus"
        case .hard: "Needs pairs, triples and careful notes"
        case .expert: "Advanced patterns like the X-Wing"
        case .master: "Chains and uniqueness – the ultimate test"
        }
    }

    /// Also used for text: the light variants keep 4.5:1 on the gray screen background.
    var color: Color {
        switch self {
        case .easy: Color(light: (0.11, 0.49, 0.28), dark: (0.32, 0.82, 0.52))
        case .medium: Color(light: (0.08, 0.45, 0.71), dark: (0.35, 0.70, 1.0))
        case .hard: Color(light: (0.62, 0.37, 0.02), dark: (1.0, 0.70, 0.25))
        case .expert: Color(light: (0.78, 0.21, 0.21), dark: (1.0, 0.42, 0.40))
        case .master: Color(light: (0.55, 0.28, 0.85), dark: (0.76, 0.55, 1.0))
        }
    }
}

extension Technique {
    var title: LocalizedStringResource {
        switch self {
        case .fullHouse: "Full House"
        case .hiddenSingle: "Hidden Single"
        case .nakedSingle: "Naked Single"
        case .pointing: "Pointing Candidates"
        case .claiming: "Box/Line Reduction"
        case .nakedPair: "Naked Pair"
        case .hiddenPair: "Hidden Pair"
        case .nakedTriple: "Naked Triple"
        case .hiddenTriple: "Hidden Triple"
        case .xWing: "X-Wing"
        case .skyscraper: "Skyscraper"
        case .twoStringKite: "2-String Kite"
        case .nakedQuad: "Naked Quad"
        case .hiddenQuad: "Hidden Quad"
        case .xyWing: "XY-Wing"
        case .xyzWing: "XYZ-Wing"
        case .wWing: "W-Wing"
        case .swordfish: "Swordfish"
        case .simpleColoring: "Simple Coloring"
        case .jellyfish: "Jellyfish"
        case .uniqueRectangle: "Unique Rectangle"
        case .bugPlusOne: "BUG+1"
        case .xChain: "X-Chain"
        case .xyChain: "XY-Chain"
        }
    }

    var summary: LocalizedStringResource {
        switch self {
        case .fullHouse:
            "The last empty cell of a row, column or box gets the only missing number."
        case .hiddenSingle:
            "A number that fits in only one cell of a row, column or box must go there."
        case .nakedSingle:
            "A cell in which only one number is still possible."
        case .pointing:
            "If a number inside a box can only be in one row or column, it can be removed from the rest of that line."
        case .claiming:
            "If a number inside a row or column can only be in one box, it can be removed from the rest of that box."
        case .nakedPair:
            "Two cells of a row, column or box with the same two candidates. Those numbers can be removed from its other cells."
        case .hiddenPair:
            "Two numbers that fit only in the same two cells of a row, column or box. Other candidates can be removed from those cells."
        case .nakedTriple:
            "Three cells of a row, column or box that together contain only three numbers."
        case .hiddenTriple:
            "Three numbers that fit only in the same three cells of a row, column or box."
        case .nakedQuad:
            "Four cells of a row, column or box that together contain only four numbers."
        case .hiddenQuad:
            "Four numbers that fit only in the same four cells of a row, column or box."
        case .xWing:
            "A number limited to the same two columns in two rows forms a rectangle. It can be removed from the rest of those columns (or vice versa)."
        case .skyscraper:
            "Two parallel lines where a number has just two places, with one end of each lined up. One of the other ends must hold the number."
        case .twoStringKite:
            "A row and a column where a number has just two places, connected through one box."
        case .xyWing:
            "A pivot cell {x, y} sees two wings {x, z} and {y, z}. Cells that see both wings can't be z."
        case .xyzWing:
            "Like the XY-Wing, but the pivot also holds z. Cells that see all three can't be z."
        case .wWing:
            "Two identical two-candidate cells connected by a strong link on one of their numbers: a row, column or box where it has only two places."
        case .swordfish:
            "The X-Wing idea extended to three rows and three columns."
        case .simpleColoring:
            "Cells joined by strong links of one number (its only two places in a row, column or box) are colored alternately. One color must be true, which reveals eliminations."
        case .jellyfish:
            "The X-Wing idea extended to four rows and four columns."
        case .uniqueRectangle:
            "Avoids four cells that could swap values, because a proper sudoku has only one solution."
        case .bugPlusOne:
            "When every unsolved cell but one has exactly two candidates, the extra candidate of that cell is the answer."
        case .xChain:
            "A chain of alternating strong and weak links on a single number."
        case .xyChain:
            "A chain of two-candidate cells, each connected to the next by a shared number."
        }
    }
}

extension Achievement {
    var title: LocalizedStringResource {
        switch self {
        case .firstWin: "First Victory"
        case .wins10: "Warming Up"
        case .wins50: "Dedicated"
        case .wins100: "Centurion"
        case .flawless: "Flawless"
        case .unaided: "No Help Needed"
        case .perfectionist: "Perfectionist"
        case .speedEasy: "Quick Start"
        case .speedMedium: "Swift Solver"
        case .speedHard: "Lightning Logic"
        // Its own key: plain "Expert" is the difficulty, an adjective in Czech ("Expertní").
        case .expertWin: LocalizedStringResource("Expert (achievement)", defaultValue: "Expert", comment: "Achievement title: a person who is an expert")
        case .masterWin: "Grandmaster"
        case .allDifficulties: "Well-Rounded"
        case .streak5: "On a Roll"
        case .streak10: "Unstoppable"
        case .dailyFirst: "Daily Debut"
        case .dailyStreak7: "Weekly Ritual"
        case .daily30: "Monthly Habit"
        case .nightOwl: "Night Owl"
        case .earlyBird: "Early Bird"
        case .customSolver: "Your Own Puzzle"
        case .penAndPaper: "Pen and Paper"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .firstWin: "Solve your first puzzle."
        case .wins10: "Solve 10 puzzles."
        case .wins50: "Solve 50 puzzles."
        case .wins100: "Solve 100 puzzles."
        case .flawless: "Solve a puzzle without a single mistake."
        case .unaided: "Solve a puzzle without using any hints."
        case .perfectionist: "Solve an Expert or Master puzzle with no mistakes and no hints."
        case .speedEasy: "Solve an Easy puzzle in under 3 minutes without hints."
        case .speedMedium: "Solve a Medium puzzle in under 6 minutes without hints."
        case .speedHard: "Solve a Hard puzzle in under 12 minutes without hints."
        case .expertWin: "Solve an Expert puzzle."
        case .masterWin: "Solve a Master puzzle."
        case .allDifficulties: "Solve a puzzle on every difficulty."
        case .streak5: "Win 5 games in a row."
        case .streak10: "Win 10 games in a row."
        case .dailyFirst: "Complete a daily challenge."
        case .dailyStreak7: "Complete the daily challenge 7 days in a row."
        case .daily30: "Complete 30 daily challenges."
        case .nightOwl: "Solve a puzzle between midnight and 4 a.m."
        case .earlyBird: "Solve a puzzle between 5 and 7 a.m."
        case .customSolver: "Solve a puzzle you entered yourself."
        case .penAndPaper: "Solve a Hard or harder puzzle without hints or auto notes."
        }
    }

    var symbol: String {
        switch self {
        case .firstWin: "flag.checkered"
        case .wins10: "star.fill"
        case .wins50: "star.circle.fill"
        case .wins100: "crown.fill"
        case .flawless: "checkmark.seal.fill"
        case .unaided: "lightbulb.slash.fill"
        case .perfectionist: "diamond.fill"
        case .speedEasy: "hare.fill"
        case .speedMedium: "bolt.fill"
        case .speedHard: "bolt.circle.fill"
        case .expertWin: "graduationcap.fill"
        case .masterWin: "trophy.fill"
        case .allDifficulties: "square.grid.3x3.fill"
        case .streak5: "flame.fill"
        case .streak10: "flame.circle.fill"
        case .dailyFirst: "calendar"
        case .dailyStreak7: "calendar.badge.checkmark"
        case .daily30: "calendar.circle.fill"
        case .nightOwl: "moon.stars.fill"
        case .earlyBird: "sunrise.fill"
        case .customSolver: "square.and.pencil"
        case .penAndPaper: "pencil.and.outline"
        }
    }

    var color: Color {
        switch self {
        case .firstWin, .wins10, .wins50, .wins100: .yellow
        case .flawless, .unaided, .perfectionist, .penAndPaper: .teal
        case .speedEasy, .speedMedium, .speedHard: .orange
        case .expertWin, .masterWin, .allDifficulties: .purple
        case .streak5, .streak10: .red
        case .dailyFirst, .dailyStreak7, .daily30: .blue
        case .nightOwl: .indigo
        case .earlyBird: .pink
        case .customSolver: .green
        }
    }
}

extension AppSettings.MistakeMode {
    var title: LocalizedStringResource {
        switch self {
        case .instant: "Instant"
        case .conflicts: "Rule Conflicts"
        case .off: "Off"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .instant: "Wrong numbers turn red right away and count as mistakes."
        case .conflicts: "Only numbers repeated in a row, column or box are marked. Every wrong number still counts as a mistake in your results."
        case .off: "No checking – spot your mistakes yourself. Every wrong number still counts as a mistake in your results."
        }
    }
}

extension AppSettings.InputMode {
    var title: LocalizedStringResource {
        switch self {
        case .cellFirst: "Cell First"
        case .digitFirst: "Number First"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .cellFirst: "Select a cell, then tap a number."
        case .digitFirst: "Pick a number, then tap every cell where it belongs."
        }
    }
}

extension AppSettings.Appearance {
    var title: LocalizedStringResource {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

extension AppSettings.DigitStyle {
    var title: LocalizedStringResource {
        switch self {
        case .standard: "Standard"
        case .rounded: "Rounded"
        case .serif: "Serif"
        case .monospaced: "Monospaced"
        }
    }
}

extension ThemeColor {
    var title: LocalizedStringResource {
        switch self {
        case .blue: "Blue"
        case .indigo: "Indigo"
        case .teal: "Teal"
        case .green: "Green"
        case .orange: "Orange"
        case .pink: "Pink"
        case .purple: "Purple"
        case .graphite: "Graphite"
        }
    }
}

extension GameMessage {
    var text: LocalizedStringResource {
        switch self {
        case .boardHasErrors: "The board is full, but something's not right."
        case .noMistakesFound: "No mistakes so far!"
        case .mistakesFound(let count): "\(count) mistakes highlighted"
        }
    }
}

nonisolated enum TimeText {
    /// "4:07" or "1:02:33".
    static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let hours = total / 3600, minutes = (total % 3600) / 60, seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }

    /// "4 minutes, 7 seconds": what VoiceOver should say for `clock`, which it may read as a time of day.
    @MainActor static func spoken(_ interval: TimeInterval) -> String {
        Duration.seconds(max(0, Int(interval)))
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide).locale(AppLocale.current))
    }
}
