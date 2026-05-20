import SwiftUI
import Translation
import TranslatorBuddyCore

struct TranslatorPanelView: View {
    @ObservedObject var viewModel: TranslatorViewModel
    let onClose: () -> Void
    let onOpenSettings: () -> Void

    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                sourcePane
                Divider()
                resultsPane
            }
        }
        .frame(minWidth: 680, minHeight: 480)
        .background(.regularMaterial)
        .overlay(alignment: .bottomLeading) {
            NativeTranslationBridge(viewModel: viewModel)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .accessibilityHidden(true)
        }
        .onAppear {
            editorFocused = true
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
                Text("Spanish to \(viewModel.targets.map(\.displayName).joined(separator: " + "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.resetCurrentTranslation()
                editorFocused = true
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

    private var sourcePane: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Spanish", systemImage: "pencil.line")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TextEditor(text: $viewModel.sourceText)
                .font(.system(size: 20, weight: .regular, design: .default))
                .scrollContentBackground(.hidden)
                .focused($editorFocused)
                .padding(10)
                .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    if viewModel.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Type Spanish here")
                            .font(.system(size: 20))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsPane: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.results) { result in
                    TranslationResultCard(result: result)
                }

                if !viewModel.savedTranslations.isEmpty {
                    SavedTranslationsView(
                        records: viewModel.savedTranslations,
                        onClear: viewModel.clearSavedTranslations
                    )
                }
            }
            .padding(18)
        }
        .frame(width: 330)
    }
}

private struct SavedTranslationsView: View {
    let records: [SavedTranslationRecord]
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Saved")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: onClear) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Clear saved translations")
            }

            ForEach(records.prefix(5)) { record in
                VStack(alignment: .leading, spacing: 6) {
                    Text(record.sourceText)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                    ForEach(record.outputs, id: \.target.id) { output in
                        Text("\(output.target.displayName): \(output.text)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .background(.background.opacity(0.64), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct TranslationResultCard: View {
    let result: TranslationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(result.target.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                statusIcon
            }

            content
                .font(.system(size: 17))
                .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        }
        .padding(14)
        .background(.background.opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var content: some View {
        switch result.status {
        case .idle:
            Text("Translation will appear here.")
                .foregroundStyle(.tertiary)
        case .translating:
            Text("Translating...")
                .foregroundStyle(.secondary)
        case .translated(let text):
            Text(text)
                .textSelection(.enabled)
        case .failed(let message):
            Text(message)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch result.status {
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
                    source: Locale.Language(identifier: TranslatorViewModel.sourceLanguageIdentifier),
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
