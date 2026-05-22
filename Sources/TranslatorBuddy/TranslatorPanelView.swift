import AppKit
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
                if let mainPanel {
                    LanguagePanelCard(
                        panel: mainPanel,
                        text: binding(for: mainPanel.language),
                        isFocused: $focusedLanguageID,
                        isMain: true,
                        onMakeMain: { viewModel.setMainLanguage(mainPanel.language) },
                        onCopy: { copyText(mainPanel.text) },
                        onClear: { viewModel.clearResult(for: mainPanel.language) }
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
            Image("translator-buddy-icon-master", bundle: .module)
                .resizable()
                .interpolation(.high)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 1) {
                Text("Translator Buddy")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(viewModel.panels.map(\.language.displayName).joined(separator: " + "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

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

    private var mainPanel: LanguagePanelState? {
        viewModel.panels.first { $0.language == viewModel.mainLanguage }
    }

    private var targetPanelsPane: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.panels.filter { $0.language != viewModel.mainLanguage }) { panel in
                    LanguagePanelCard(
                        panel: panel,
                        text: binding(for: panel.language),
                        isFocused: $focusedLanguageID,
                        isMain: false,
                        onMakeMain: { viewModel.setMainLanguage(panel.language) },
                        onCopy: { copyText(panel.text) },
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

    private func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
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
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.sourceText)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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

    private var summary: String {
        let targets = record.outputs.map(\.target.displayName).joined(separator: ", ")
        return "\(record.sourceLanguageIdentifier.uppercased()) -> \(targets)"
    }
}

private struct LanguagePanelCard: View {
    let panel: LanguagePanelState
    @Binding var text: String
    var isFocused: FocusState<String?>.Binding
    let isMain: Bool
    let onMakeMain: () -> Void
    let onCopy: () -> Void
    let onClear: () -> Void
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(panel.language.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()

                if !isMain {
                    Button(action: onMakeMain) {
                        Image(systemName: "arrow.up.left.square")
                    }
                    .buttonStyle(.borderless)
                    .help("Make active panel")
                }

                Button {
                    onCopy()
                    showCopiedFeedback()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        if didCopy {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .buttonStyle(.borderless)
                .disabled(text.isEmpty)
                .help("Copy \(panel.language.displayName)")

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

    private func showCopiedFeedback() {
        didCopy = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            didCopy = false
        }
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
