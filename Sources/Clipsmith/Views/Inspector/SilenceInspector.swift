import SwiftUI

struct SilenceInspector: View {
    let store: ProjectStore
    let waveforms: WaveformStore
    let clip: Clip

    @State private var threshold = Double(SilenceDetector.defaultThreshold)
    @State private var minimumDuration = SilenceDetector.defaultMinimumDurationInSeconds
    @State private var proposals: [Range<TimeInterval>]?
    @State private var isSearching = false

    private static let thresholdRange = 0.005...0.1
    private static let durationRange = 0.2...2.0
    private static let listLimit = 6

    var body: some View {
        InspectorSection(.silences) {
            ParameterSlider(
                title: localized("inspector.silences.threshold"), value: $threshold,
                range: Self.thresholdRange, unit: .percent,
                defaultValue: Double(SilenceDetector.defaultThreshold))
            ParameterSlider(
                title: localized("inspector.silences.minimum"), value: $minimumDuration,
                range: Self.durationRange, unit: .seconds,
                defaultValue: SilenceDetector.defaultMinimumDurationInSeconds)
            HStack {
                Button(localized("inspector.silences.find"), action: find)
                    .disabled(isSearching)
                if isSearching { ProgressView().controlSize(.small) }
            }
            review
            Text(localized("inspector.silences.hint")).font(.caption).foregroundStyle(.secondary)
        }
        .onChange(of: clip.id) { proposals = nil }
    }

    @ViewBuilder
    private var review: some View {
        if let proposals {
            if proposals.isEmpty {
                Text(localized("inspector.silences.none")).font(.caption).foregroundStyle(
                    .secondary)
            } else {
                Text(
                    String(
                        format: localized("inspector.silences.found"), proposals.count,
                        total(of: proposals).clockString)
                )
                .font(.caption)
                ForEach(Array(proposals.prefix(Self.listLimit).enumerated()), id: \.offset) {
                    _, range in
                    Button {
                        store.movePlayhead(to: range.lowerBound)
                    } label: {
                        Text("\(range.lowerBound.clockString) – \(range.upperBound.clockString)")
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .buttonStyle(.link)
                }
                Button(localized("inspector.silences.remove"), action: remove)
            }
        }
    }

    private func total(of ranges: [Range<TimeInterval>]) -> TimeInterval {
        ranges.reduce(0) { $0 + ($1.upperBound - $1.lowerBound) }
    }

    private func find() {
        guard let url = clip.sourceURL else { return }
        isSearching = true
        Task {
            await waveforms.load(url)
            let peaks = waveforms.peaksByURL[url] ?? []
            let silences = SilenceDetector.silences(
                peaks: peaks, from: clip.sourceStartInSeconds, to: clip.sourceEndInSeconds,
                threshold: Float(threshold), minimumDuration: minimumDuration)
            proposals = SilenceDetector.timelineRanges(silences, for: clip)
            isSearching = false
        }
    }

    private func remove() {
        guard let proposals else { return }
        store.removeSilences(proposals, from: clip.id)
        self.proposals = nil
    }
}
