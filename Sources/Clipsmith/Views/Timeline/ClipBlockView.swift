import SwiftUI

struct ClipBlockView: View {
    let clip: Clip
    let pointsPerSecond: Double
    let isSelected: Bool
    let onSelect: () -> Void
    let onMove: (_ proposedStart: TimeInterval, _ laneOffset: Int) -> Void
    let onTrim: (_ edge: ClipEdge, _ proposedTime: TimeInterval) -> Void

    @State private var moveTranslation: CGSize = .zero
    @State private var trimOrigin: TimeInterval?

    private static let minimumDragDistance: CGFloat = 3
    private static let cornerRadius: CGFloat = 6

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .fill(fillColor)
                .overlay(border)
            Text(clip.sourceURL.lastPathComponent)
                .font(.caption)
                .lineLimit(1)
                .padding(.horizontal, TimelineMetrics.trimHandleWidth + 2)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                trimHandle(.leading)
                Spacer(minLength: 0)
                trimHandle(.trailing)
            }
        }
        .frame(width: max(clip.durationInSeconds * pointsPerSecond, 2), height: TimelineMetrics.laneHeight)
        .offset(x: clip.startInSeconds * pointsPerSecond + moveTranslation.width, y: moveTranslation.height)
        .zIndex(moveTranslation == .zero ? 0 : 1)
        .onTapGesture(perform: onSelect)
        .gesture(moveGesture)
    }

    private var fillColor: Color {
        switch clip.mediaKind {
        case .video: return .blue.opacity(0.55)
        case .image: return .purple.opacity(0.55)
        case .audio: return .green.opacity(0.55)
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: Self.cornerRadius)
            .stroke(isSelected ? Color.yellow : Color.white.opacity(0.25), lineWidth: isSelected ? 2 : 1)
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: Self.minimumDragDistance, coordinateSpace: .global)
            .onChanged { value in
                if !isSelected { onSelect() }
                moveTranslation = value.translation
            }
            .onEnded { value in
                let proposedStart = clip.startInSeconds + value.translation.width / pointsPerSecond
                let laneOffset = Int((value.translation.height / TimelineMetrics.laneStride).rounded())
                moveTranslation = .zero
                onMove(proposedStart, laneOffset)
            }
    }

    private func trimHandle(_ edge: ClipEdge) -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.35))
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
        edge == .leading ? clip.startInSeconds : clip.endInSeconds
    }
}
