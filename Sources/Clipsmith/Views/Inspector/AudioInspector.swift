import SwiftUI

struct AudioInspector: View {
    let store: ProjectStore
    let waveforms: WaveformStore
    let denoise: DenoiseStore
    let clip: Clip

    @State private var normalizeMessage: String?
    @State private var duckingMessage: String?
    @State private var isWorking = false

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
            normalizeControls
            noiseControls
            if store.project.trackRole(ofClip: clip.id) == .audio { duckingControls }
            if clip.mediaKind == .video, store.project.trackRole(ofClip: clip.id) == .main {
                Button(localized("inspector.audio.extract")) { store.detachAudio(ofClip: clip.id) }
                    .disabled(!store.project.canDetachAudio(ofClip: clip.id))
                    .help(localized("inspector.audio.extract.help"))
            }
        }
    }

    @ViewBuilder
    private var normalizeControls: some View {
        Button(localized("inspector.audio.normalize"), action: normalize)
            .disabled(isWorking || clip.sourceURL == nil)
            .help(localized("inspector.audio.normalize.help"))
        if let normalizeMessage {
            Text(normalizeMessage).font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var noiseControls: some View {
        Picker(localized("inspector.noise.title"), selection: noiseBinding) {
            Text(localized("inspector.noise.off")).tag(NoiseReductionLevel?.none)
            ForEach(NoiseReductionLevel.allCases) {
                Text(localized(String.LocalizationValue("inspector.noise.\($0.rawValue)")))
                    .tag(Optional($0))
            }
        }
        .pickerStyle(.segmented)
        if denoise.isPreparing {
            HStack {
                ProgressView().controlSize(.small)
                Text(localized("inspector.noise.processing")).font(.caption).foregroundStyle(
                    .secondary)
            }
        } else if let failure = denoise.lastFailure {
            Text(String(format: localized("inspector.noise.failed"), failure))
                .font(.caption)
                .foregroundStyle(Palette.warning)
        }
        Text(localized("inspector.noise.hint")).font(.caption).foregroundStyle(.secondary)
    }

    private var noiseBinding: Binding<NoiseReductionLevel?> {
        Binding(
            get: { clip.noiseReduction },
            set: { store.setNoiseReduction(of: clip.id, to: $0) }
        )
    }

    @ViewBuilder
    private var duckingControls: some View {
        Divider()
        Text(localized("inspector.ducking.title")).font(.subheadline.bold())
        ParameterSlider(
            title: localized("inspector.ducking.level"), value: duckLevelBinding,
            range: ClipDucking.levelRange, unit: .percent, defaultValue: ClipDucking.defaultLevel)
        HStack {
            Button(localized("inspector.ducking.apply"), action: duck)
                .disabled(isWorking)
            if clip.ducking != nil {
                Button(localized("inspector.ducking.clear")) {
                    store.clearDucking(of: clip.id)
                    duckingMessage = nil
                }
            }
            if isWorking { ProgressView().controlSize(.small) }
        }
        if let duckingMessage {
            Text(duckingMessage).font(.caption).foregroundStyle(.secondary)
        }
        Text(localized("inspector.ducking.hint")).font(.caption).foregroundStyle(.secondary)
    }

    private var duckLevelBinding: Binding<Double> {
        Binding(
            get: { clip.ducking?.level ?? duckingLevel },
            set: {
                duckingLevel = $0
                store.setDuckLevel(of: clip.id, to: $0)
            }
        )
    }

    @State private var duckingLevel = ClipDucking.defaultLevel

    private func normalize() {
        guard let url = clip.sourceURL else { return }
        isWorking = true
        Task {
            await waveforms.load(url)
            let peaks = waveforms.peaksByURL[url] ?? []
            if let volume = store.normalizeVolume(of: clip.id, peaks: peaks) {
                normalizeMessage = String(
                    format: localized("inspector.audio.normalize.done"), Int((volume * 100).rounded()))
            } else {
                normalizeMessage = localized("inspector.audio.normalize.none")
            }
            isWorking = false
        }
    }

    private func duck() {
        let voices = store.project.track(withRole: .main)?.clips.filter {
            ($0.mediaKind == .video || $0.mediaKind == .audio) && !$0.isAudioDetached
                && $0.sourceURL != nil
        } ?? []
        guard !voices.isEmpty else {
            duckingMessage = localized("inspector.ducking.noSpeech")
            return
        }
        isWorking = true
        Task {
            var withPeaks: [(clip: Clip, peaks: [Float])] = []
            for voice in voices {
                guard let url = voice.sourceURL else { continue }
                await waveforms.load(url)
                withPeaks.append((voice, waveforms.peaksByURL[url] ?? []))
            }
            let ranges = DuckingPlanner.timelineRanges(voices: withPeaks)
            let count = store.applyDucking(to: clip.id, under: ranges, level: duckingLevel)
            duckingMessage =
                count == 0
                ? localized("inspector.ducking.noSpeech")
                : String(format: localized("inspector.ducking.done"), count)
            isWorking = false
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
    AudioInspector(
        store: PreviewFixtures.store(), waveforms: WaveformStore(), denoise: DenoiseStore(),
        clip: PreviewFixtures.videoClip)
        .padding()
}
