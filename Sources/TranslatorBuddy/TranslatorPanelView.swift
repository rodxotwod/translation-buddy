import AppKit
import SwiftUI
import Translation
import TranslatorBuddyCore

struct TranslatorPanelView: View {
    @ObservedObject var viewModel: TranslatorViewModel
    @ObservedObject var windowSettingsStore: WindowSettingsStore
    let onClose: () -> Void
    let onOpenSettings: () -> Void

    @FocusState private var focusedLanguageID: String?
    @State private var displayMode: DisplayMode = .translation

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Group {
                switch displayMode {
                case .translation:
                    translationWorkspace
                case .history:
                    HistoryView(
                        records: viewModel.savedTranslations,
                        onRestore: { record in
                            viewModel.restore(record)
                            displayMode = .translation
                            focusedLanguageID = viewModel.activeLanguage.id
                        },
                        onClear: viewModel.clearSavedTranslations
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 720, idealWidth: 860, minHeight: 500, idealHeight: 620)
        .background(.regularMaterial)
        .overlay(alignment: .bottomLeading) {
            NativeTranslationBridge(viewModel: viewModel)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .accessibilityHidden(true)
        }
        .onAppear {
            requestMainPanelFocus()
        }
        .onChange(of: windowSettingsStore.focusRequestID) {
            requestMainPanelFocus()
        }
        .onExitCommand {
            onClose()
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                BrandMarkImage()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .shadow(color: .black.opacity(0.14), radius: 5, y: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Translator Buddy")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(viewModel.panels.map(\.language.displayName).joined(separator: " + "))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                displayMode = displayMode == .history ? .translation : .history
            } label: {
                Image(systemName: displayMode == .history ? "text.bubble.fill" : "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(displayMode == .history ? .primary : .secondary)
            .background(
                displayMode == .history ? Color.accentColor.opacity(0.14) : Color.clear,
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .help(displayMode == .history ? "Show translations" : "Show history")

            Button {
                windowSettingsStore.keepsWindowAboveOtherApps.toggle()
            } label: {
                Image(systemName: windowSettingsStore.keepsWindowAboveOtherApps ? "pin.fill" : "pin")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(windowSettingsStore.keepsWindowAboveOtherApps ? .primary : .secondary)
            .background(
                windowSettingsStore.keepsWindowAboveOtherApps ? Color.accentColor.opacity(0.14) : Color.clear,
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .help(
                windowSettingsStore.keepsWindowAboveOtherApps
                    ? "Window stays above other apps"
                    : "Keep window above other apps"
            )

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Language settings")

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Close")
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(.thinMaterial)
    }

    private var translationWorkspace: some View {
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
    }

    private var mainPanel: LanguagePanelState? {
        viewModel.panels.first { $0.language == viewModel.mainLanguage }
    }

    private var targetPanelsPane: some View {
        let sidePanels = viewModel.panels.filter { $0.language != viewModel.mainLanguage }

        return GeometryReader { geometry in
            let padding: CGFloat = 18
            let spacing: CGFloat = 12
            let availableHeight = max(0, geometry.size.height - padding * 2 - spacing * CGFloat(max(0, sidePanels.count - 1)))
            let panelHeight = sidePanels.isEmpty ? 0 : max(170, availableHeight / CGFloat(sidePanels.count))

            ScrollView {
                LazyVStack(spacing: spacing) {
                    ForEach(sidePanels) { panel in
                        LanguagePanelCard(
                            panel: panel,
                            text: binding(for: panel.language),
                            isFocused: $focusedLanguageID,
                            isMain: false,
                            onMakeMain: {
                                viewModel.setMainLanguage(panel.language)
                                requestFocus(for: panel.language)
                            },
                            onCopy: { copyText(panel.text) },
                            onClear: { viewModel.clearResult(for: panel.language) }
                        )
                        .frame(minHeight: panelHeight)
                    }
                }
                .padding(padding)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
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

    private func requestMainPanelFocus() {
        displayMode = .translation
        requestFocus(for: viewModel.mainLanguage)
    }

    private func requestFocus(for language: TranslationTarget) {
        Task { @MainActor in
            focusedLanguageID = nil
            try? await Task.sleep(nanoseconds: 80_000_000)
            focusedLanguageID = language.id
        }
    }
}

private enum DisplayMode {
    case translation
    case history
}

private struct HistoryView: View {
    let records: [SavedTranslationRecord]
    let onRestore: (SavedTranslationRecord) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("History")
                        .font(.title3.weight(.semibold))

                    Text("\(records.count) saved \(records.count == 1 ? "translation" : "translations")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !records.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Clear saved translations")
                }
            }

            if records.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.tertiary)

                    Text("No saved translations yet.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(records) { record in
                            HistoryRecordRow(record: record) {
                                onRestore(record)
                            }
                        }
                    }
                }
            }
        }
        .padding(22)
        .background(.regularMaterial)
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

private struct BrandMarkImage: View {
    var body: some View {
        if let image = Self.loadImage() {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "character.bubble.fill")
                .resizable()
                .scaledToFit()
                .padding(9)
                .foregroundStyle(.white)
                .background(Color.teal)
        }
    }

    private static func loadImage() -> NSImage? {
        let resourceName = "translator-buddy-mark-v2"
        for bundle in [Bundle.module, Bundle.main] {
            if let url = bundle.url(forResource: resourceName, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                return image
            }
            if let image = bundle.image(forResource: resourceName) {
                return image
            }
        }
        return NSImage(named: resourceName)
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
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .frame(width: 18, height: 18)
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
                .frame(maxWidth: .infinity, minHeight: 82, maxHeight: .infinity, alignment: .topLeading)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
