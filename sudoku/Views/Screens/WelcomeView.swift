//
//  WelcomeView.swift
//  sudoku
//

import SwiftUI

struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 14) {
                        LogoMark()
                            .frame(width: 88, height: 88)
                        Text("Welcome to Sudoku")
                            .font(.largeTitle.weight(.bold))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 44)

                    VStack(alignment: .leading, spacing: 22) {
                        Feature(symbol: "square.grid.3x3.fill", color: .blue, title: "Endless puzzles", text: "Five difficulty levels. Puzzles are made right on your device, no internet needed.")
                        Feature(symbol: "lightbulb.fill", color: .yellow, title: "Hints that teach", text: "Every hint explains the logic, from hidden singles to X-Wings and chains.")
                        Feature(symbol: "calendar", color: .red, title: "Daily challenge", text: "A fresh puzzle every day. Keep your streak alive!")
                        Feature(symbol: "pencil.and.outline", color: .orange, title: "Smart notes", text: "Pencil marks, auto notes and unlimited undo.")
                    }
                    .padding(.horizontal, 8)
                }
                .padding(.horizontal, 28)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }

            Button {
                dismiss()
            } label: {
                Text("Start Playing")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(palette.buttonFill)
            .controlSize(.extraLarge)
            .frame(maxWidth: 460)
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
        }
    }
}

private struct Feature: View {
    let symbol: String
    let color: Color
    let title: LocalizedStringKey
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
