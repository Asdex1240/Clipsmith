import SwiftUI

struct TimelineView: View {
    let store: ProjectStore
    let library: MediaLibrary
    let waveforms: WaveformStore
    let filmstrips: FilmstripStore
    let missingMedia: Set<URL>
    @State private var dropPreview: DropPreview?
    @State private var drag: (clipID: Clip.ID, offset: CGFloat)?

    private var pointsPerSecond: Double { store.pointsPerSecond }

    var body: some View {
        VStack(spacing: 0) {
            TimelineToolbar(store: store)
            Divider()
            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    trackLabels
                    GeometryReader { viewport in
                        ScrollView(.horizontal) {
                            tracksContent(
                                contentWidth: contentWidth(viewportWidth: viewport.size.width))
                        }
                    }
                }
                .frame(height: contentHeight)
            }
        }
        .background(CommandScrollZoomMonitor { store.zoom(byScrollDelta: $0) })
        .overlay { emptyHint }
    }

    @ViewBuilder
    private var emptyHint: some View {
        if store.project.allClipIDs.isEmpty {
            Label(localized("timeline.empty"), systemImage: "arrow.down.to.line")
                .foregroundStyle(.secondary)
                .padding(Design.Spacing.comfortable)
                .allowsHitTesting(false)
        }
    }

    private var contentHeight: CGFloat {
        TimelineMetrics.rulerHeight + CGFloat(store.project.tracks.count)
            * TimelineMetrics.laneStride + TimelineMetrics.laneHeight
    }

    private var trackLabels: some View {
        VStack(alignment: .leading, spacing: TimelineMetrics.laneSpacing) {
            Spacer().frame(height: TimelineMetrics.rulerHeight)
            ForEach(store.project.tracks) { track in
                TrackHeaderView(store: store, track: track)
            }
            addTrackMenu
                .frame(width: TimelineMetrics.trackHeaderWidth, alignment: .leading)
                .padding(.leading, Design.Spacing.regular)
        }
    }

    private var addTrackMenu: some View {
        Menu {
            Button(localized("track.add.video")) { store.addTrack(role: .broll) }
            Button(localized("track.add.audio")) { store.addTrack(role: .audio) }
            Button(localized("track.add.text")) { store.addTrack(role: .text) }
        } label: {
            Label(localized("track.add"), systemImage: "plus")
                .font(.caption)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(localized("track.add.help"))
    }

    private func contentWidth(viewportWidth: CGFloat) -> CGFloat {
        let contentSeconds =
            store.project.durationInSeconds + TimelineMetrics.trailingPaddingInSeconds
        return max(contentSeconds * pointsPerSecond, viewportWidth)
    }

    private func tracksContent(contentWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: TimelineMetrics.laneSpacing) {
            TimelineRuler(
                pointsPerSecond: pointsPerSecond, width: contentWidth,
                onScrub: store.setPlayhead(near:)
            )
            .overlay(alignment: .topLeading) {
                HighlightBands(store: store, pointsPerSecond: pointsPerSecond)
            }
            .overlay(alignment: .topLeading) {
                MarkerFlags(store: store, pointsPerSecond: pointsPerSecond)
            }
            ForEach(Array(store.project.tracks.enumerated()), id: \.element.id) { index, track in
                lane(for: track, at: index, width: contentWidth)
            }
        }
        .overlay(alignment: .topLeading) {
            PlayheadView(
                store: store, pointsPerSecond: pointsPerSecond,
                coordinateSpaceName: Self.contentSpace
            )
        }
        .coordinateSpace(name: Self.contentSpace)
    }

    private static let contentSpace = "timelineContent"

    private func lane(for track: Track, at index: Int, width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(.background.secondary.opacity(0.6))
                .frame(width: width, height: TimelineMetrics.laneHeight)
                .onTapGesture { store.selectClip(nil) }
            ForEach(track.clips) { clip in
                clipBlock(for: clip, in: track, at: index)
            }
            ForEach(track.clips) { clip in
                transitionButton(for: clip)
            }
        }
        .frame(width: width, height: TimelineMetrics.laneHeight, alignment: .topLeading)
        .opacity(laneOpacity(of: track))
        .overlay(alignment: .topLeading) { dropGhost(on: track) }
        .overlay { dropOutline(on: track) }
        .onDrop(
            of: [.plainText],
            delegate: LaneDropDelegate(
                track: track, store: store, library: library, pointsPerSecond: pointsPerSecond,
                preview: $dropPreview
            )
        )
    }

    private func laneOpacity(of track: Track) -> Double {
        if track.isHidden { return Design.Opacity.hiddenLane }
        return 1
    }

    private func clipBlock(for clip: Clip, in track: Track, at index: Int) -> some View {
        ClipBlockView(
            clip: clip,
            pointsPerSecond: pointsPerSecond,
            isSelected: store.selectedClipIDs.contains(clip.id),
            allowsLaneChange:
                !(store.hasMultipleSelected && store.selectedClipIDs.contains(clip.id)),
            companionOffset: companionOffset(for: clip),
            waveformPeaks: waveformPeaks(for: clip, in: track),
            filmstrip: filmstrip(for: clip),
            isMissing: clip.sourceURL.map(missingMedia.contains) ?? false,
            onSelect: { select(clip) },
            onMove: { start, laneOffset in
                move(clip, from: index, near: start, laneOffset: laneOffset)
            },
            onTrim: { edge, time in store.trimClip(clip.id, edge: edge, near: time) },
            onDragChange: { offset in drag = offset.map { (clip.id, $0) } }
        )
        .task(id: clip.sourceURL) {
            await loadWaveform(for: clip, in: track)
            await loadFilmstrip(for: clip)
        }
    }

    @ViewBuilder
    private func transitionButton(for clip: Clip) -> some View {
        if store.project.clipBeforeAndTouching(clip.id) != nil {
            TransitionButton(store: store, clip: clip)
                .offset(x: clip.startInSeconds * pointsPerSecond - TransitionButton.size / 2, y: 2)
                .zIndex(2)
        }
    }

    @ViewBuilder
    private func dropGhost(on track: Track) -> some View {
        if let dropPreview, dropPreview.trackID == track.id {
            DropGhostView(preview: dropPreview, pointsPerSecond: pointsPerSecond)
        }
    }

    @ViewBuilder
    private func dropOutline(on track: Track) -> some View {
        if let dropPreview, dropPreview.trackID == track.id {
            Rectangle()
                .strokeBorder(dropPreview.tint.opacity(0.6), lineWidth: 1.5)
                .allowsHitTesting(false)
        }
    }

    private func showsWaveform(_ clip: Clip, in track: Track) -> Bool {
        track.role.playsAudio && !clip.isAudioDetached
            && (clip.mediaKind == .video || clip.mediaKind == .audio)
    }

    private func waveformPeaks(for clip: Clip, in track: Track) -> [Float]? {
        guard showsWaveform(clip, in: track), let url = clip.sourceURL else { return nil }
        return waveforms.peaksByURL[url]
    }

    private func filmstrip(for clip: Clip) -> Filmstrip? {
        guard clip.mediaKind == .video, let url = clip.sourceURL else { return nil }
        return filmstrips.stripsByURL[url]
    }

    private func loadFilmstrip(for clip: Clip) async {
        guard clip.mediaKind == .video, let url = clip.sourceURL else { return }
        await filmstrips.load(url)
    }

    private func loadWaveform(for clip: Clip, in track: Track) async {
        guard showsWaveform(clip, in: track), let url = clip.sourceURL else { return }
        await waveforms.load(url)
    }

    private func select(_ clip: Clip) {
        if NSEvent.modifierFlags.intersection([.shift, .command]).isEmpty {
            if !(store.hasMultipleSelected && store.selectedClipIDs.contains(clip.id)) {
                store.selectClip(clip.id)
            }
        } else {
            store.toggleSelection(of: clip.id)
        }
    }

    private func companionOffset(for clip: Clip) -> CGFloat {
        guard let drag, drag.clipID != clip.id, store.selectedClipIDs.contains(clip.id),
            store.selectedClipIDs.contains(drag.clipID)
        else { return 0 }
        return drag.offset
    }

    private func move(_ clip: Clip, from laneIndex: Int, near start: TimeInterval, laneOffset: Int)
    {
        if store.hasMultipleSelected, store.selectedClipIDs.contains(clip.id) {
            store.moveSelection(draggedClip: clip.id, near: start)
            return
        }
        let tracks = store.project.tracks
        let targetIndex = min(max(laneIndex + laneOffset, 0), tracks.count - 1)
        store.moveClip(clip.id, toTrack: tracks[targetIndex].id, near: start)
    }
}

#Preview {
    TimelineView(
        store: PreviewFixtures.store(), library: MediaLibrary(), waveforms: WaveformStore(),
        filmstrips: FilmstripStore(),
        missingMedia: []
    )
    .frame(width: 800, height: 320)
}
