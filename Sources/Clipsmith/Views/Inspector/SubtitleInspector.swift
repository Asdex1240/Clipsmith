import SwiftUI

struct SubtitleInspector: View {
    let subtitles: SubtitleController
    let clip: Clip

    @AppStorage("subtitleLanguage") private var languageIdentifier = ""
    @AppStorage("subtitleStyle") private var styleName = TextStylePreset.classic.rawValue
    @AppStorage("subtitleAnimation") private var animationName = TextAnimationKind.none.rawValue
    @AppStorage("subtitleHighlightWord") private var highlightsSpokenWord = false
    private let locales = SpeechTranscriber.supportedLocales

    private var wordHighlighting: SpokenWordHighlighting {
        if highlightsSpokenWord { return .on }
        return .off
    }

    var body: some View {
        InspectorSection(.subtitles) {
            Picker(localized("inspector.subtitles.language"), selection: selectedIdentifier) {
                ForEach(SpeechTranscriber.supportedLocaleOptions) { option in
                    Text(option.name).tag(option.identifier)
                }
            }
            Picker(localized("inspector.subtitles.style"), selection: $styleName) {
                ForEach(TextStylePreset.allCases, id: \.rawValue) {
                    Text(TextInspector.title(of: $0)).tag($0.rawValue)
                }
            }
            Picker(localized("inspector.subtitles.animation"), selection: $animationName) {
                ForEach(TextAnimationKind.allCases, id: \.rawValue) {
                    Text(TextInspector.title(of: $0)).tag($0.rawValue)
                }
            }
            Toggle(localized("inspector.subtitles.highlight"), isOn: $highlightsSpokenWord)
            HStack {
                Button(localized("inspector.subtitles.generate")) {
                    subtitles.dismiss()
                    subtitles.generate(
                        for: clip.id,
                        locale: Locale(identifier: selectedIdentifier.wrappedValue),
                        style: TextStylePreset(rawValue: styleName) ?? .classic,
                        animation: .both(TextAnimationKind(rawValue: animationName) ?? .none),
                        wordHighlighting: wordHighlighting
                    )
                }
                .disabled(subtitles.isWorking || locales.isEmpty)
                if subtitles.isWorking {
                    ProgressView().controlSize(.small)
                    Button(localized("inspector.subtitles.cancel"), action: subtitles.cancel)
                }
            }
            status
            Text(localized("inspector.subtitles.hint")).font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var status: some View {
        switch subtitles.state {
        case .idle, .working:
            EmptyView()
        case .finished(let count):
            Label(
                String(format: localized("inspector.subtitles.done"), count),
                systemImage: "checkmark.circle"
            )
            .font(.caption)
            .foregroundStyle(Palette.successText)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(Palette.warningText)
        }
    }

    private var selectedIdentifier: Binding<String> {
        Binding(
            get: {
                if locales.contains(where: { $0.identifier == languageIdentifier }) {
                    return languageIdentifier
                }
                return Self.defaultIdentifier(in: locales)
            },
            set: { languageIdentifier = $0 }
        )
    }

    static func defaultIdentifier(in locales: [Locale], system: Locale = .current) -> String {
        let identifiers = locales.map(\.identifier)
        if identifiers.contains(system.identifier) { return system.identifier }
        if let code = system.language.languageCode?.identifier,
            let match = identifiers.first(where: {
                $0.hasPrefix(code + "_") || $0.hasPrefix(code + "-")
            })
        {
            return match
        }
        return identifiers.first(where: { $0 == "en_US" }) ?? identifiers.first ?? "en_US"
    }
}

#Preview {
    let store = PreviewFixtures.store()
    SubtitleInspector(subtitles: SubtitleController(store: store), clip: PreviewFixtures.videoClip)
        .padding()
}
