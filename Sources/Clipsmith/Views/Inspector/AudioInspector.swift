import SwiftUI

struct AudioInspector: View {
    let store: ProjectStore
    let clip: Clip

    private static let defaultVolume = 1.0
    private static let noFade = 0.0

    var body: some View {
        InspectorSection(.audio) {
            ParameterSlider(
                title: localized("inspector.audio.volume"), value: volumeBinding,
                range: 0...Clip.maximumVolume, unit: .percent, defaultValue: Self.defaultVolume
            )
            ParameterSlider(
                title: localized("inspector.audio.fadeIn"), value: fadeInBinding,
                range: 0...fadeRange, unit: .seconds, defaultValue: Self.noFade
            )
            ParameterSlider(
                title: localized("inspector.audio.fadeOut"), value: fadeOutBinding,
                range: 0...fadeRange, unit: .seconds, defaultValue: Self.noFade
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
        Binding(get: { clip.volume }, set: { store.setVolume(of: clip.id, to: $0) })
    }

    private var fadeInBinding: Binding<Double> {
        Binding(
            get: { clip.fadeInDurationInSeconds }, set: { store.setFadeIn(of: clip.id, to: $0) })
    }

    private var fadeOutBinding: Binding<Double> {
        Binding(
            get: { clip.fadeOutDurationInSeconds }, set: { store.setFadeOut(of: clip.id, to: $0) })
    }
}

#Preview {
    AudioInspector(store: PreviewFixtures.store(), clip: PreviewFixtures.videoClip)
        .padding()
}
