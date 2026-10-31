//
//  ThemeTests.swift
//  sudokuTests
//

import SwiftUI
import Testing
import UIKit
@testable import sudoku

struct ThemeTests {
    /// SwiftUI resolves colors on its render thread too. A provider isolated to the main actor
    /// trapped there, which crashed the app now and then while it drew glass buttons.
    @Test func adaptiveColorsResolveOffTheMainThread() async {
        let color = UIColor(Color(light: (1, 0, 0), dark: (0, 0, 1)))
        let resolved = await Task.detached {
            color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        }.value
        var blue: CGFloat = 0
        resolved.getRed(nil, green: nil, blue: &blue, alpha: nil)
        #expect(blue == 1)
    }
}
