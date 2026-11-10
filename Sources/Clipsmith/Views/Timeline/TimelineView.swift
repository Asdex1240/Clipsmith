import SwiftUI

struct TimelineView: View {
    let store: ProjectStore
    let library: MediaLibrary
    let waveforms: WaveformStore
    let missingMedia: Set<URL>
    @State private var dropPreview: DropPreview?
    /// The clip being dragged and how far (in points), so the other selected clips can follow it.
    @State private var drag: (clipID: Clip.ID, offset: CGFloat)?

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
        .background(CommandScrollZoomMonitor { store.zoom(byScrollDelta: $0) })
    }

    private var toolbar: some View {
        HStack {
            Text(store.project.name).font(.headline)
            Text(store.playheadInSeconds.clockString).monospacedDigit().foregroundStyle(.secondary)
            Spacer()
            Toggle(isOn: Binding(get: { store.isSnappingEnabled }, set: { _ in store.toggleSnapping() })) {
                Image(systemName: "magnet")
            }
            .toggleStyle(.button)
            .help("\(localized(store.isSnappingEnabled ? "timeline.snapping.on" : "timeline.snapping.off")) (\(EditorShortcuts.displayKeys(for: .toggleSnapping)))")
            toolbarButton("timeline.addText", systemImage: "textformat", shortcut: .addText, action: store.addTextAtPlayhead)
            toolbarButton("timeline.addMarker", systemImage: "bookmark", shortcut: .addMarker, action: store.toggleMarkerAtPlayhead)
            toolbarButton("timeline.split", systemImage: "scissors", shortcut: .split, action: store.splitAtPlayhead)
            toolbarButton("shortcut.trimStart", systemImage: "arrow.right.to.line", shortcut: .trimStartToPlayhead) {
                store.trimToPlayhead(edge: .leading)
            }
            toolbarButton("shortcut.trimEnd", systemImage: "arrow.left.to.line.compact", shortcut: .trimEndToPlayhead) {
                store.trimToPlayhead(edge: .trailing)
            }
            toolbarButton("shortcut.duplicate", systemImage: "plus.square.on.square", shortcut: .duplicate, action: store.duplicateSelectedClip)
            toolbarButton("timeline.group", systemImage: "link", shortcut: .group, action: store.groupSelection)
                .disabled(!store.canGroupSelection)
            toolbarButton("timeline.ungroup", systemImage: "link.badge.plus", shortcut: .ungroup, action: store.ungroupSelection)
                .disabled(!store.selectionIsGrouped)
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
        .coordinateSpace(name: Self.contentSpace)
    }

    private static let contentSpace = "timelineContent"
    private static let playheadHandleSize = CGSize(width: 14, height: 10)

    private var playhead: some View {
        let size = Self.playheadHandleSize
        return ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.red)
                .frame(width: 1.5)
                .allowsHitTesting(false)
            PlayheadHandle()
                .fill(Color.red)
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.contentSpace)).onChanged { value in
                        store.setPlayhead(near: value.location.x / pointsPerSecond)
                    }
                )
        }
        .frame(width: size.width)
        .offset(x: store.playheadInSeconds * pointsPerSecond - size.width / 2 + 0.75)
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
                    isSelected: store.selectedClipIDs.contains(clip.id),
                    allowsLaneChange: !(store.hasMultipleSelected && store.selectedClipIDs.contains(clip.id)),
                    companionOffset: companionOffset(for: clip),
                    waveformPeaks: waveformPeaks(for: clip, in: track),
                    isMissing: clip.sourceURL.map(missingMedia.contains) ?? false,
                    onSelect: { select(clip) },
                    onMove: { start, laneOffset in move(clip, from: index, near: start, laneOffset: laneOffset) },
                    onTrim: { edge, time in store.trimClip(clip.id, edge: edge, near: time) },
                    onDragChange: { offset in drag = offset.map { (clip.id, $0) } }
                )
                .task(id: clip.sourceURL) { await loadWaveform(for: clip, in: track) }
            }
            ForEach(track.clips) { clip in
                if store.project.clipBeforeAndTouching(clip.id) != nil {
                    TransitionButton(store: store, clip: clip)
                        .offset(x: clip.startInSeconds * pointsPerSecond - TransitionButton.size / 2, y: 2)
                        .zIndex(2)
                }
            }
        }
        .frame(width: width, height: TimelineMetrics.laneHeight, alignment: .topLeading)
        .overlay(alignment: .topLeading) {
            if let dropPreview, dropPreview.trackID == track.id {
                DropGhostView(preview: dropPreview, pointsPerSecond: pointsPerSecond)
            }
        }
        .overlay {
            if let dropPreview, dropPreview.trackID == track.id {
                Rectangle()
                    .strokeBorder((dropPreview.isValid ? Color.accentColor : Color.red).opacity(0.6), lineWidth: 1.5)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(
            of: [.plainText],
            delegate: LaneDropDelegate(
                track: track, store: store, library: library, pointsPerSecond: pointsPerSecond, preview: $dropPreview
            )
        )
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

    /// Shift or command while clicking adds the clip to the selection (or takes it out); a plain click selects only it.
    private func select(_ clip: Clip) {
        if NSEvent.modifierFlags.intersection([.shift, .command]).isEmpty {
            // Pressing on a clip that is already part of a multiple selection keeps it, so the whole set can be dragged.
            if !(store.hasMultipleSelected && store.selectedClipIDs.contains(clip.id)) { store.selectClip(clip.id) }
        } else {
            store.toggleSelection(of: clip.id)
        }
    }

    private func companionOffset(for clip: Clip) -> CGFloat {
        guard let drag, drag.clipID != clip.id, store.selectedClipIDs.contains(clip.id),
              store.selectedClipIDs.contains(drag.clipID) else { return 0 }
        return drag.offset
    }

    private func move(_ clip: Clip, from laneIndex: Int, near start: TimeInterval, laneOffset: Int) {
        if store.hasMultipleSelected, store.selectedClipIDs.contains(clip.id) {
            store.moveSelection(draggedClip: clip.id, near: start)
            return
        }
        let tracks = store.project.tracks
        let targetIndex = min(max(laneIndex + laneOffset, 0), tracks.count - 1)
        store.moveClip(clip.id, toTrack: tracks[targetIndex].id, near: start)
    }
}

private struct PlayheadHandle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
