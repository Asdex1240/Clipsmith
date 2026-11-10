import SwiftUI

struct TimelineView: View {
    let store: ProjectStore
    let library: MediaLibrary
    let waveforms: WaveformStore
    let missingMedia: Set<URL>

    private var pointsPerSecond: Double { store.pointsPerSecond }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HStack(alignment: .top, spacing: 0) {
                trackLabels
                GeometryReader { viewport in
                    ScrollView(.horizontal) {
                        tracksContent(contentWidth: contentWidth(viewportWidth: viewport.size.width))
                    }
                }
            }
        }
    }

    private var toolbar: some View {
        HStack {
            Text(store.project.name).font(.headline)
            Text(store.playheadInSeconds.clockString).monospacedDigit().foregroundStyle(.secondary)
            Spacer()
            toolbarButton("timeline.addText", systemImage: "textformat", shortcut: .addText, action: store.addTextAtPlayhead)
            toolbarButton("timeline.addMarker", systemImage: "bookmark", shortcut: .addMarker, action: store.toggleMarkerAtPlayhead)
            toolbarButton("timeline.split", systemImage: "scissors", shortcut: .split, action: store.splitAtPlayhead)
            toolbarButton("timeline.delete", systemImage: "trash", shortcut: .delete, action: store.deleteSelectedClip)
            toolbarButton(
                "timeline.rippleDelete", systemImage: "arrow.left.to.line",
                shortcut: .rippleDelete, action: store.rippleDeleteSelectedClip
            )
            Divider().frame(height: 16)
            toolbarButton("timeline.zoomOut", systemImage: "minus.magnifyingglass", shortcut: .zoomOut, action: store.zoomOut)
            toolbarButton("timeline.zoomIn", systemImage: "plus.magnifyingglass", shortcut: .zoomIn, action: store.zoomIn)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func toolbarButton(
        _ key: String.LocalizationValue,
        systemImage: String,
        shortcut: EditorAction,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { Image(systemName: systemImage) }
            .help("\(localized(key)) (\(EditorShortcuts.displayKeys(for: shortcut)))")
    }

    private var trackLabels: some View {
        VStack(alignment: .leading, spacing: TimelineMetrics.laneSpacing) {
            Spacer().frame(height: TimelineMetrics.rulerHeight)
            ForEach(store.project.tracks) { track in
                Text(track.role.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: TimelineMetrics.trackLabelWidth, height: TimelineMetrics.laneHeight, alignment: .leading)
                    .padding(.leading, 8)
            }
        }
    }

    private func contentWidth(viewportWidth: CGFloat) -> CGFloat {
        let contentSeconds = store.project.durationInSeconds + TimelineMetrics.trailingPaddingInSeconds
        return max(contentSeconds * pointsPerSecond, viewportWidth)
    }

    private func tracksContent(contentWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: TimelineMetrics.laneSpacing) {
            TimelineRuler(pointsPerSecond: pointsPerSecond, width: contentWidth, onScrub: store.setPlayhead(near:))
                .overlay(alignment: .topLeading) { MarkerFlags(store: store, pointsPerSecond: pointsPerSecond) }
            ForEach(Array(store.project.tracks.enumerated()), id: \.element.id) { index, track in
                lane(for: track, at: index, width: contentWidth)
            }
        }
        .overlay(alignment: .topLeading) { playhead }
    }

    private var playhead: some View {
        Rectangle()
            .fill(Color.red)
            .frame(width: 1.5)
            .offset(x: store.playheadInSeconds * pointsPerSecond)
            .allowsHitTesting(false)
    }

    private func lane(for track: Track, at index: Int, width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(.background.secondary.opacity(0.6))
                .frame(width: width, height: TimelineMetrics.laneHeight)
                .onTapGesture { store.selectClip(nil) }
            ForEach(track.clips) { clip in
                ClipBlockView(
                    clip: clip,
                    pointsPerSecond: pointsPerSecond,
                    isSelected: store.selectedClipID == clip.id,
                    waveformPeaks: waveformPeaks(for: clip, in: track),
                    isMissing: clip.sourceURL.map(missingMedia.contains) ?? false,
                    onSelect: { store.selectClip(clip.id) },
                    onMove: { start, laneOffset in move(clip, from: index, near: start, laneOffset: laneOffset) },
                    onTrim: { edge, time in store.trimClip(clip.id, edge: edge, near: time) }
                )
                .task(id: clip.sourceURL) { await loadWaveform(for: clip, in: track) }
            }
        }
        .frame(width: width, height: TimelineMetrics.laneHeight, alignment: .topLeading)
        .dropDestination(for: String.self) { identifiers, location in
            drop(identifiers, onto: track, at: location.x / pointsPerSecond)
        }
    }

    private func showsWaveform(_ clip: Clip, in track: Track) -> Bool {
        track.role.playsAudio && !clip.isAudioDetached && (clip.mediaKind == .video || clip.mediaKind == .audio)
    }

    private func waveformPeaks(for clip: Clip, in track: Track) -> [Float]? {
        guard showsWaveform(clip, in: track), let url = clip.sourceURL else { return nil }
        return waveforms.peaksByURL[url]
    }

    private func loadWaveform(for clip: Clip, in track: Track) async {
        guard showsWaveform(clip, in: track), let url = clip.sourceURL else { return }
        await waveforms.load(url)
    }

    private func move(_ clip: Clip, from laneIndex: Int, near start: TimeInterval, laneOffset: Int) {
        let tracks = store.project.tracks
        let targetIndex = min(max(laneIndex + laneOffset, 0), tracks.count - 1)
        store.moveClip(clip.id, toTrack: tracks[targetIndex].id, near: start)
    }

    private func drop(_ identifiers: [String], onto track: Track, at time: TimeInterval) -> Bool {
        let items = identifiers.compactMap { identifier in
            library.items.first { $0.id.uuidString == identifier }
        }
        for item in items {
            store.addMedia(item, toTrack: track.id, at: time)
        }
        return !items.isEmpty
    }
}
