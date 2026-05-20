import SwiftUI
import TranslatorBuddyCore

struct SettingsView: View {
    @ObservedObject var viewModel: TranslatorViewModel
    @ObservedObject var shortcutStore: ShortcutSettingsStore
    let onShortcutChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            languagePicker

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Shortcut")
                    .font(.headline)

                Picker("Show Translator Buddy", selection: $shortcutStore.preference) {
                    ForEach(ShortcutPreference.presets) { shortcut in
                        Text(shortcut.displayName).tag(shortcut)
                    }
                }
                .frame(width: 340)
            }

            if let error = viewModel.lastSettingsError {
                Text(error)
                    .foregroundStyle(.red)
                    .onTapGesture {
                        viewModel.clearSettingsError()
                    }
            }
        }
        .padding(24)
        .frame(width: 540, height: 520)
        .onChange(of: shortcutStore.preference) { _, _ in
            onShortcutChanged()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .font(.title2.weight(.semibold))
            Text("Spanish is fixed as the source language for this version.")
                .foregroundStyle(.secondary)
        }
    }

    private var languagePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shown Languages")
                .font(.headline)

            List {
                ForEach(TranslationTarget.selectableTargets) { target in
                    Toggle(isOn: binding(for: target)) {
                        HStack {
                            Text(target.displayName)
                            Spacer()
                            Text(target.languageIdentifier)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .disabled(viewModel.targets.count == 1 && isEnabled(target))
                }
            }
            .frame(minHeight: 250)
        }
    }

    private func isEnabled(_ target: TranslationTarget) -> Bool {
        viewModel.targets.contains { $0.languageIdentifier == target.languageIdentifier }
    }

    private func binding(for target: TranslationTarget) -> Binding<Bool> {
        Binding(
            get: { isEnabled(target) },
            set: { viewModel.setTarget(target, isEnabled: $0) }
        )
    }
}
