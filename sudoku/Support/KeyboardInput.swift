//
//  KeyboardInput.swift
//  sudoku
//
//  Hardware keyboard input shared by the game and the custom puzzle screen.
//

import GameController
import SwiftUI

extension KeyPress {
    /// The digit a key stands for, 0–9. Czech and Slovak keyboards type letters on the unshifted
    /// number row (+ ě š č ř ž ý á í é in Czech, ľ and ť in Slovak) and need Shift for digits, so
    /// those letters count as digits too.
    var digit: Int? {
        guard let character = characters.first else { return nil }
        return Self.digit(for: character, modifiers: modifiers, keyboards: Self.keyboardLanguages)
    }

    /// See `digit`; separate so it can be tested without a key press. `keyboards` are the language
    /// codes of the keyboard layouts the player may be typing on (see `keyboardLanguages`).
    static func digit(for character: Character, modifiers: EventModifiers, keyboards: @autoclosure () -> Set<String> = []) -> Int? {
        if let value = character.wholeNumberValue, (0...9).contains(value) { return value }
        // `+` is also Shift-= on US keyboards and the keypad's plus.
        if character == "+" { return modifiers.isDisjoint(with: [.shift, .numericPad]) ? 1 : nil }
        // Lowercased, as Caps Lock turns the letters into Ě, Š, Č…
        guard let letter = character.lowercased().first else { return nil }
        if letter == "é" {
            // The 0 key of Czech and Slovak keyboards. French ones type it on the 2 key: for a player who
            // may use one of those too, there's no telling which key it was. (Elsewhere it's a letter key.)
            let languages = keyboards()
            return !languages.isDisjoint(with: ["cs", "sk"]) && !languages.contains("fr") ? 0 : nil
        }
        return Self.numberRowLetters[letter]
    }

    private static let numberRowLetters: [Character: Int] = [
        "ě": 2, "ľ": 2, "š": 3, "č": 4, "ř": 5, "ť": 5, "ž": 6, "ý": 7, "á": 8, "í": 9,
    ]

    /// See `digit(for:modifiers:keyboards:)`, e.g. "cs" and "en": the player's languages, plus Czech or
    /// Slovak for a player in Czechia or Slovakia, who types on a Czech or Slovak keyboard even in English.
    /// A hardware keyboard's layout is nearly always one of these. The keyboards turned on in Settings would
    /// tell exactly, but `UITextInputMode.activeInputModes` is a required-reason API whose only reason for
    /// an app like this one requires text fields, and App Store Connect rejects a build using it undeclared.
    private static var keyboardLanguages: Set<String> {
        var languages = Set(Locale.preferredLanguages.compactMap { Locale.Language(identifier: $0).languageCode?.identifier })
        switch Locale.current.region?.identifier {
        case "CZ": languages.insert("cs")
        case "SK": languages.insert("sk")
        default: break
        }
        return languages
    }

    var isArrow: Bool {
        [.upArrow, .downArrow, .leftArrow, .rightArrow].contains(key)
    }
}

extension View {
    /// Receives hardware keyboard presses (with arrow keys repeating while held). The view takes
    /// focus when it appears and again when a keyboard connects: without a keyboard there is no
    /// focus to take, and a Bluetooth keyboard often wakes up only once the game is open.
    func hardwareKeyboardInput(
        focus: FocusState<Bool>.Binding,
        action: @escaping (KeyPress) -> KeyPress.Result
    ) -> some View {
        focusable()
            .focused(focus)
            .focusEffectDisabled()
            .onKeyPress(phases: [.down, .repeat]) { press in
                // Only the arrows repeat; a held digit or Space must not keep toggling.
                guard press.phase == .down || press.isArrow else { return .handled }
                return action(press)
            }
            .onAppear { focus.wrappedValue = true }
            .task {
                for await _ in NotificationCenter.default.notifications(named: .GCKeyboardDidConnect) {
                    focus.wrappedValue = true
                }
            }
    }
}
