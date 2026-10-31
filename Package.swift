// swift-tools-version: 6.0
//
// Builds the app's puzzle engine (sudoku/Engine) as a standalone module so it
// can be unit-tested with `swift test`. The iOS app itself is built from
// sudoku.xcodeproj.

import PackageDescription

let package = Package(
    name: "SudokuEngine",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "SudokuEngine", path: "sudoku/Engine"),
        .testTarget(
            name: "SudokuEngineTests",
            dependencies: ["SudokuEngine"],
            path: "Tests/SudokuEngineTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
