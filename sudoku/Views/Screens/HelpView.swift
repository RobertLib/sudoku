//
//  HelpView.swift
//  sudoku
//

import SwiftUI

struct HelpView: View {
    @Environment(\.palette) private var palette

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fill the grid so that every row, every column and every 3×3 box contains each number from 1 to 9 exactly once.")
                    Text("Every puzzle has exactly one solution, and it can always be found with logic – no guessing needed.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("The Goal")
            }

            Section("Playing") {
                HelpRow(symbol: "hand.tap.fill", color: .blue, title: "Select and fill", text: "Tap a cell, then tap a number. Tap the same number again to remove it.")
                HelpRow(symbol: "pencil", color: .orange, title: "Notes", text: "Turn on Notes to jot down candidates. Auto Notes in the menu fills them in for you.")
                HelpRow(symbol: "number", color: .indigo, title: "Number first", text: "Long-press a number to lock it, then tap every cell where it belongs. In Settings you can make this the default.")
                HelpRow(symbol: "arrow.uturn.backward", color: .gray, title: "Undo and erase", text: "Undo as many steps as you like. Erase clears a number or the notes of a cell.")
                HelpRow(symbol: "lightbulb.fill", color: .yellow, title: "Hints", text: "A hint first points you in the right direction. Tap Show Me for the full explanation, then apply it.")
                HelpRow(symbol: "exclamationmark.triangle.fill", color: .red, title: "Mistakes", text: "With instant checking, wrong numbers turn red. Three mistakes end the game unless you turn the limit off – but you get one second chance.")
                HelpRow(symbol: "calendar", color: .green, title: "Daily challenge", text: "A new puzzle every day – the same for everyone. Difficulty rises from Monday to the weekend.")
            }

            Section("Difficulty Levels") {
                ForEach(Difficulty.allCases) { difficulty in
                    HStack(spacing: 14) {
                        DifficultyBadge(difficulty: difficulty)
                            .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(difficulty.title)
                                .font(.headline)
                            Text(difficulty.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            ForEach(Difficulty.allCases) { difficulty in
                Section {
                    ForEach(Technique.allCases.filter { $0.difficulty == difficulty }, id: \.self) { technique in
                        DisclosureGroup {
                            Text(technique.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                        } label: {
                            Text(technique.title)
                                .font(.body.weight(.medium))
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Text("Techniques")
                        Text(verbatim: "·")
                            .accessibilityHidden(true)
                        Text(difficulty.title)
                            .foregroundStyle(difficulty.color)
                    }
                }
            }

            // Matches `GameView.handleKey` and the game's keyboard shortcuts.
            Section {
                ShortcutRow(keys: Text(verbatim: "↑ ↓ ← →"), text: "Move the selection")
                ShortcutRow(keys: Text(verbatim: "1 – 9"), text: "Enter a number")
                ShortcutRow(keys: Text(verbatim: "⌫ / 0"), text: "Erase")
                ShortcutRow(keys: Text("N / Space"), text: "Toggle notes")
                ShortcutRow(keys: Text(verbatim: "H"), text: "Hint")
                ShortcutRow(keys: Text(verbatim: "Esc"), text: "Close the hint")
                ShortcutRow(keys: Text(verbatim: "⌘Z / U"), text: "Undo")
                ShortcutRow(keys: Text(verbatim: "⇧⌘Z"), text: "Redo")
                ShortcutRow(keys: Text(verbatim: "⌘P"), text: "Pause")
                ShortcutRow(keys: Text("↩ / Space"), text: "Resume a paused game")
            } header: {
                Text("Keyboard Shortcuts")
            } footer: {
                Text("Available with a hardware keyboard.")
            }
        }
        .navigationTitle("How to Play")
    }
}

private struct HelpRow: View {
    let symbol: String
    let color: Color
    let title: LocalizedStringKey
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct ShortcutRow: View {
    let keys: Text
    let text: LocalizedStringKey

    var body: some View {
        HStack {
            Text(text)
            Spacer()
            keys
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}
