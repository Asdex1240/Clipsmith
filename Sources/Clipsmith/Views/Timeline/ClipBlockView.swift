import SwiftUI

struct ClipBlockView: View {
    let clip: Clip
    let pointsPerSecond: Double
    let isSelected: Bool
    var allowsLaneChange = true
    var companionOffset: CGFloat = 0
    let waveformPeaks: [Float]?
    var filmstrip: Filmstrip?
    let isMissing: Bool
    let onSelect: () -> Void
    let onMove: (_ proposedStart: TimeInterval, _ laneOffset: Int) -> Void
    let onTrim: (_ edge: ClipEdge, _ proposedTime: TimeInterval) -> Void
    var onDragChange: (CGFloat?) -> Void = { _ in }

    @State private var moveTranslation: CGSize = .zero
    @State private var trimOrigin: TimeInterval?

    private static let minimumDragDistance: CGFloat = 3
    private static let cornerRadius = Design.Radius.medium

    private var blockFill: Color {
        if isMissing { return Palette.missingClipFill }
        return Palette.clipFill(for: clip.mediaKind)
    }

    private var blockTitle: String {
        if isMissing { return "⚠︎ " + clip.displayName }
        return clip.displayName
    }

    private var stackingOrder: Double {
        if moveTranslation == .zero && companionOffset == 0 { return 0 }
        return 1
    }

    private var borderColor: Color {
        if isSelected { return Palette.selection }
        return Palette.onMedia.opacity(Design.Opacity.subtleBorder)
    }

    private var borderWidth: CGFloat {
        if isSelected { return 2 }
        return 1
    }

    private func allowedVerticalTravel(_ translation: CGFloat) -> CGFloat {
        guard allowsLaneChange else { return 0 }
        return translation
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .fill(blockFill)
                .overlay(filmstripLayer)
                .overlay(sheen)
                .overlay(border)
            waveform
            titleLabel
            HStack {
                trimHandle(.leading)
                Spacer(minLength: 0)
                trimHandle(.trailing)
            }
        }
        .frame(
            width: max(clip.durationInSeconds * pointsPerSecond, 2),
            height: TimelineMetrics.laneHeight
        )
        .overlay(alignment: .bottomLeading) { keyframeMarks }
        .overlay(alignment: .topTrailing) {
            if clip.groupID != nil {
                Image(systemName: "link")
                    .font(.system(size: 9, weight: .bold))
                    .padding(3)
                    .allowsHitTesting(false)
            }
        }
        .offset(
            x: clip.startInSeconds * pointsPerSecond + moveTranslation.width + companionOffset,
            y: moveTranslation.height
        )
        .zIndex(stackingOrder)
        .onTapGesture(perform: onSelect)
        .gesture(moveGesture)
    }

    private static let maximumFilmstripWidth: CGFloat = 16_000

    @ViewBuilder
    private var filmstripLayer: some View {
        let width = max(clip.durationInSeconds * pointsPerSecond, 2)
        if let filmstrip, width <= Self.maximumFilmstripWidth, !isMissing {
            FilmstripView(filmstrip: filmstrip, clip: clip, pointsPerSecond: pointsPerSecond)
                .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
                .opacity(Design.Opacity.filmstrip)
        }
    }

    private var sheen: some View {
        LinearGradient(
            colors: [Palette.onMedia.opacity(Design.Opacity.sheen), .clear],
            startPoint: .top, endPoint: .center
        )
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
        .allowsHitTesting(false)
    }

    private var titleLabel: some View {
        HStack(spacing: Design.Spacing.tight) {
            Image(systemName: clip.mediaKind.systemImage)
                .font(.caption2)
                .accessibilityHidden(true)
            Text(blockTitle)
                .font(.caption)
                .lineLimit(1)
        }
        .shadow(color: Palette.scrim.opacity(Design.Opacity.scrim), radius: 1)
        .padding(.horizontal, TimelineMetrics.trimHandleWidth + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
    }

    private var keyframeMarks: some View {
        ZStack(alignment: .bottomLeading) {
            ForEach(clip.keyframes) { frame in
                Image(systemName: "diamond.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(Palette.keyframe)
                    .offset(x: frame.timeInSeconds * pointsPerSecond - 3.5, y: -2)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var waveform: some View {
        if let waveformPeaks, !waveformPeaks.isEmpty {
            WaveformView(
                peaks: waveformPeaks, clip: clip, pointsPerSecond: pointsPerSecond,
                color: Palette.onMedia.opacity(Design.Opacity.waveform)
            )
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: Self.cornerRadius)
            .stroke(borderColor, lineWidth: borderWidth)
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: Self.minimumDragDistance, coordinateSpace: .global)
            .onChanged { value in
                if !isSelected { onSelect() }
                moveTranslation = CGSize(
                    width: value.translation.width,
                    height: allowedVerticalTravel(value.translation.height))
                onDragChange(value.translation.width)
            }
            .onEnded { value in
                let proposedStart = clip.startInSeconds + value.translation.width / pointsPerSecond
                let laneOffset = Int(
                    (allowedVerticalTravel(value.translation.height) / TimelineMetrics.laneStride)
                        .rounded())
                moveTranslation = .zero
                onDragChange(nil)
                onMove(proposedStart, laneOffset)
            }
    }

    private func trimHandle(_ edge: ClipEdge) -> some View {
        Rectangle()
            .fill(Palette.onMedia.opacity(Design.Opacity.handle))
            .frame(width: TimelineMetrics.trimHandleWidth)
            .contentShape(Rectangle())
            .gesture(trimGesture(edge))
    }

    private func trimGesture(_ edge: ClipEdge) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                let origin = trimOrigin ?? edgeTime(edge)
                trimOrigin = origin
                onTrim(edge, origin + value.translation.width / pointsPerSecond)
            }
            .onEnded { _ in trimOrigin = nil }
    }

    private func edgeTime(_ edge: ClipEdge) -> TimeInterval {
        switch edge {
        case .leading: return clip.startInSeconds
        case .trailing: return clip.endInSeconds
        }
    }
}

#Preview {
    ClipBlockView(
        clip: PreviewFixtures.videoClip, pointsPerSecond: 40, isSelected: true,
        waveformPeaks: PreviewFixtures.waveformPeaks, isMissing: false,
        onSelect: {}, onMove: { _, _ in }, onTrim: { _, _ in }
    )
    .frame(height: 48)
    .padding()
}
