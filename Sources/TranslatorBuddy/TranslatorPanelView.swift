import SwiftUI
import Translation
import TranslatorBuddyCore

struct TranslatorPanelView: View {
    @ObservedObject var viewModel: TranslatorViewModel
    let onClose: () -> Void
    let onOpenSettings: () -> Void

    @FocusState private var focusedLanguageID: String?
    @State private var historyExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                if let spanishPanel {
                    LanguagePanelCard(
                        panel: spanishPanel,
                        text: binding(for: spanishPanel.language),
                        isFocused: $focusedLanguageID,
                        onClear: { viewModel.clearResult(for: spanishPanel.language) }
                    )
                    .padding(18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Divider()
                targetPanelsPane
            }
            Divider()
            HistoryDrawerView(
                records: viewModel.savedTranslations,
                isExpanded: $historyExpanded,
                onRestore: { record in
                    viewModel.restore(record)
                    focusedLanguageID = viewModel.activeLanguage.id
                },
                onClear: viewModel.clearSavedTranslations
            )
        }
        .frame(minWidth: 760, minHeight: 560)
        .background(.regularMaterial)
        .overlay(alignment: .bottomLeading) {
            NativeTranslationBridge(viewModel: viewModel)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .accessibilityHidden(true)
        }
        .onAppear {
            focusedLanguageID = TranslationTarget.spanish.id
        }
        .onExitCommand {
            onClose()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 1) {
                Text("Translator Buddy")
                    .font(.headline)
                Text(viewModel.panels.map(\.language.displayName).joined(separator: " + "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.resetCurrentTranslation()
                focusedLanguageID = TranslationTarget.spanish.id
            } label: {
                Image(systemName: "plus.square")
            }
            .buttonStyle(.borderless)
            .help("Start a new translation")

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Language settings")

            Button(action: onClose) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Close")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var spanishPanel: LanguagePanelState? {
        viewModel.panels.first { $0.language == .spanish }
    }

    private var targetPanelsPane: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.panels.filter { $0.language != .spanish }) { panel in
                    LanguagePanelCard(
                        panel: panel,
                        text: binding(for: panel.language),
                        isFocused: $focusedLanguageID,
                        onClear: { viewModel.clearResult(for: panel.language) }
                    )
                }

            }
            .padding(18)
        }
        .frame(width: 330)
    }

    private func binding(for language: TranslationTarget) -> Binding<String> {
        Binding(
            get: { viewModel.text(for: language) },
            set: { viewModel.setText($0, for: language) }
        )
    }
}

private struct HistoryDrawerView: View {
    let records: [SavedTranslationRecord]
    @Binding var isExpanded: Bool
    let onRestore: (SavedTranslationRecord) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Label("History", systemImage: isExpanded ? "chevron.down" : "chevron.right")
                }
                .buttonStyle(.borderless)

                Text("\(records.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if !records.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Clear saved translations")
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)

            if isExpanded {
                if records.isEmpty {
                    Text("No saved translations yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(records) { record in
                                HistoryRecordRow(record: record) {
                                    onRestore(record)
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 14)
                    }
                    .frame(maxHeight: 180)
                }
            }
        }
        .background(.background.opacity(0.55))
    }
}

private struct HistoryRecordRow: View {
    let record: SavedTranslationRecord
    let onRestore: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(record.sourceText)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)

                Text(outputSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button(action: onRestore) {
                Image(systemName: "arrow.down.left.and.arrow.up.right")
            }
            .buttonStyle(.borderless)
            .help("Fill panels from this translation")
        }
        .padding(10)
        .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
    }

    private var outputSummary: String {
        record.outputs
            .map { "\($0.target.displayName): \($0.text)" }
            .joined(separator: " | ")
    }
}

private struct LanguagePanelCard: View {
    let panel: LanguagePanelState
    @Binding var text: String
    var isFocused: FocusState<String?>.Binding
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(panel.language.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if panel.status != .idle || !text.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Clear \(panel.language.displayName)")
                }
                statusIcon
            }

            TextEditor(text: $text)
                .font(.system(size: 17))
                .scrollContentBackground(.hidden)
                .focused(isFocused, equals: panel.language.id)
                .padding(8)
                .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
                .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Type \(panel.language.displayName)")
                            .font(.system(size: 17))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(14)
        .background(.background.opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch panel.status {
        case .idle:
            Image(systemName: "circle")
                .foregroundStyle(.tertiary)
        case .translating:
            ProgressView()
                .controlSize(.small)
        case .translated:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }
}

private struct NativeTranslationBridge: View {
    @ObservedObject var viewModel: TranslatorViewModel

    var body: some View {
        ZStack {
            ForEach(viewModel.pendingRequests) { request in
                NativeTranslationTaskView(request: request, viewModel: viewModel)
            }
        }
    }
}

private struct NativeTranslationTaskView: View {
    let request: TranslationRequest
    @ObservedObject var viewModel: TranslatorViewModel
    @State private var configuration: TranslationSession.Configuration?

    var body: some View {
        Color.clear
            .onAppear {
                viewModel.markTranslating(request)
                configuration = TranslationSession.Configuration(
                    source: Locale.Language(identifier: request.sourceLanguageIdentifier),
                    target: Locale.Language(identifier: request.target.languageIdentifier)
                )
            }
            .translationTask(configuration) { session in
                Task { @MainActor in
                    do {
                        let response = try await session.translate(request.sourceText)
                        viewModel.complete(request, translatedText: response.targetText)
                    } catch {
                        viewModel.fail(request, message: error.localizedDescription)
                    }
                }
            }
    }
}
