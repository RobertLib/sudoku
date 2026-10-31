//
//  SettingsView.swift
//  sudoku
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var confirmResetData = false
    @State private var confirmResetSettings = false

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $settings.mistakeMode) {
                        ForEach(AppSettings.MistakeMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    } label: {
                        SettingsLabel("Mistake checking", symbol: "checkmark.shield.fill", color: .red)
                    }
                    Toggle(isOn: $settings.mistakeLimitEnabled) {
                        SettingsLabel("Limit of 3 mistakes", symbol: "heart.fill", color: .pink)
                    }
                    .disabled(settings.mistakeMode != .instant)
                    Picker(selection: $settings.inputMode) {
                        ForEach(AppSettings.InputMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    } label: {
                        SettingsLabel("Input mode", symbol: "hand.tap.fill", color: .blue)
                    }
                    Toggle(isOn: $settings.autoRemoveNotes) {
                        SettingsLabel("Remove notes automatically", symbol: "pencil.slash", color: .orange)
                    }
                } header: {
                    Text("Gameplay")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(settings.mistakeMode.detail)
                        Text(settings.inputMode.detail)
                    }
                }

                Section("Highlighting") {
                    Toggle(isOn: $settings.highlightPeers) {
                        SettingsLabel("Row, column and box", symbol: "plus.square.fill", color: .teal)
                    }
                    Toggle(isOn: $settings.highlightSameDigits) {
                        SettingsLabel("Identical numbers", symbol: "number.square.fill", color: .indigo)
                    }
                }

                Section("Display") {
                    Toggle(isOn: $settings.hideCompletedDigits) {
                        SettingsLabel("Hide completed numbers", symbol: "eye.slash.fill", color: .gray)
                    }
                    Toggle(isOn: $settings.showRemainingCounts) {
                        SettingsLabel("Show remaining counts", symbol: "textformat.123", color: .green)
                    }
                    Toggle(isOn: $settings.showTimer) {
                        SettingsLabel("Show timer", symbol: "timer", color: .orange)
                    }
                    Toggle(isOn: $settings.keepScreenOn) {
                        SettingsLabel("Keep screen on while playing", symbol: "sun.max.fill", color: .yellow)
                    }
                }

                Section("Appearance") {
                    Picker(selection: $settings.appearance) {
                        ForEach(AppSettings.Appearance.allCases) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    } label: {
                        SettingsLabel("Appearance", symbol: "circle.lefthalf.filled", color: .indigo)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsLabel("Color", symbol: "paintpalette.fill", color: settings.theme.accent)
                        ThemePicker(selection: $settings.theme)
                    }
                    .padding(.vertical, 4)
                    Picker(selection: $settings.digitStyle) {
                        ForEach(AppSettings.DigitStyle.allCases) { style in
                            Text(style.title)
                                .font(.system(.body, design: style.design))
                                .tag(style)
                        }
                    } label: {
                        SettingsLabel("Number font", symbol: "textformat", color: .purple)
                    }
                    DigitPreview(design: settings.digitStyle.design, accent: settings.theme.accent)
                }

                Section("Sound & Haptics") {
                    Toggle(isOn: $settings.soundEnabled) {
                        SettingsLabel("Sound effects", symbol: "speaker.wave.2.fill", color: .pink)
                    }
                    Toggle(isOn: $settings.hapticsEnabled) {
                        SettingsLabel("Haptics", symbol: "iphone.radiowaves.left.and.right", color: .blue)
                    }
                }

                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        SettingsLabel("Language", symbol: "globe", color: .cyan)
                    }
                } header: {
                    Text("Language")
                } footer: {
                    Text("Sudoku is shown in Czech when your device uses Czech, and in English otherwise. If your device has more than one preferred language, you can pick one for this app in the Settings app.")
                }

                Section("Data") {
                    Button(role: .destructive) {
                        confirmResetData = true
                    } label: {
                        SettingsLabel("Reset statistics and achievements", symbol: "trash.fill", color: .red)
                    }
                    Button {
                        confirmResetSettings = true
                    } label: {
                        SettingsLabel("Restore default settings", symbol: "arrow.counterclockwise", color: .gray)
                    }
                }

                Section {
                    LabeledContent {
                        Text(verbatim: appVersion)
                    } label: {
                        SettingsLabel("Version", symbol: "info.circle.fill", color: .gray)
                    }
                } footer: {
                    Text("Works completely offline. No ads, no accounts, no tracking – your games and statistics stay on this device.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { dismiss() }
                }
            }
            .confirmationDialog("Reset statistics and achievements?", isPresented: $confirmResetData, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { model.resetAllData() }
            } message: {
                Text("Your game history, best times, daily challenge results and achievements will be permanently deleted.")
            }
            .confirmationDialog("Restore default settings?", isPresented: $confirmResetSettings, titleVisibility: .visible) {
                Button("Restore Defaults") { settings.resetToDefaults() }
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

/// An iOS Settings–style label with a colored icon.
struct SettingsLabel: View {
    let title: LocalizedStringKey
    let symbol: String
    let color: Color

    init(_ title: LocalizedStringKey, symbol: String, color: Color) {
        self.title = title
        self.symbol = symbol
        self.color = color
    }

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 29, height: 29)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }
}

private struct ThemePicker: View {
    @Binding var selection: ThemeColor

    var body: some View {
        // Every swatch keeps a 44-point target: one row where all eight fit, otherwise two rows of four.
        ViewThatFits(in: .horizontal) {
            row(ThemeColor.allCases)
            VStack(spacing: 4) {
                row(Array(ThemeColor.allCases.prefix(4)))
                row(Array(ThemeColor.allCases.suffix(4)))
            }
        }
    }

    private func row(_ themes: [ThemeColor]) -> some View {
        HStack(spacing: 0) {
            ForEach(themes) { theme in
                swatch(theme)
            }
        }
    }

    private func swatch(_ theme: ThemeColor) -> some View {
        Button {
            withAnimation(.snappy) { selection = theme }
        } label: {
            Circle()
                .fill(theme.accent.gradient)
                .overlay {
                    if selection == theme {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.palette.onFill)
                    }
                }
                .padding(3)
                .overlay {
                    Circle()
                        .strokeBorder(selection == theme ? theme.accent : .clear, lineWidth: 2)
                }
                .frame(width: 36, height: 36)
                .frame(minWidth: 44, maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(theme.title))
        .accessibilityAddTraits(selection == theme ? .isSelected : [])
    }
}

private struct DigitPreview: View {
    let design: Font.Design
    let accent: Color

    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...9, id: \.self) { digit in
                Text(verbatim: "\(digit)")
                    .font(.system(size: 26, weight: digit % 3 == 0 ? .regular : .semibold, design: design))
                    .foregroundStyle(digit % 3 == 0 ? accent : .primary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
        .accessibilityHidden(true)
    }
}
