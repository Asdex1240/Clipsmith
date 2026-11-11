import SwiftUI

struct AudioInspector: View {
    let store: ProjectStore
    let clip: Clip

    private static let volumeScale = 100.0

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.cozy) {
            Text(localized("inspector.audio.section")).font(.subheadline.bold())
            labeledSlider(
                "inspector.audio.volume",
                value: volumeBinding,
                range: 0...(Clip.maximumVolume * Self.volumeScale),
                valueText: "\(Int(clip.volume * Self.volumeScale))%"
            )
            labeledSlider(
                "inspector.audio.fadeIn",
                value: fadeInBinding,
                range: 0...fadeRange,
                valueText: seconds(clip.fadeInDurationInSeconds)
            )
            labeledSlider(
                "inspector.audio.fadeOut",
                value: fadeOutBinding,
                range: 0...fadeRange,
                valueText: seconds(clip.fadeOutDurationInSeconds)
            )
            if clip.mediaKind == .video, store.project.trackRole(ofClip: clip.id) == .main {
                Button(localized("inspector.audio.extract")) { store.detachAudio(ofClip: clip.id) }
                    .disabled(!store.project.canDetachAudio(ofClip: clip.id))
                    .help(localized("inspector.audio.extract.help"))
            }
        }
    }

    private var fadeRange: Double {
        max(clip.durationInSeconds, Clip.minimumDurationInSeconds)
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { clip.volume * Self.volumeScale },
            set: { store.setVolume(of: clip.id, to: $0 / Self.volumeScale) }
        )
    }

    private var fadeInBinding: Binding<Double> {
        Binding(
            get: { clip.fadeInDurationInSeconds }, set: { store.setFadeIn(of: clip.id, to: $0) })
    }

    private var fadeOutBinding: Binding<Double> {
        Binding(
            get: { clip.fadeOutDurationInSeconds }, set: { store.setFadeOut(of: clip.id, to: $0) })
    }

    private func seconds(_ value: TimeInterval) -> String {
        String(format: "%.1f s", value)
    }

    private func labeledSlider(
        _ key: String.LocalizationValue,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        valueText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Design.Spacing.hairline) {
            HStack {
                Text(localized(key))
                Spacer()
                Text(valueText).monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}

#Preview {
    AudioInspector(store: PreviewFixtures.store(), clip: PreviewFixtures.videoClip)
        .padding()
}
