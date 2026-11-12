import Foundation

enum TimelineMetrics {
    static let rulerHeight: CGFloat = 24
    static let laneHeight: CGFloat = 44
    static let laneSpacing: CGFloat = 4
    static let laneStride = laneHeight + laneSpacing
    static let trackHeaderWidth: CGFloat = 164
    static let playheadHeadSize = CGSize(width: 14, height: 16)
    static let minorTicksPerMajor = 4
    static let minorTickHeight: CGFloat = 5
    static let trimHandleWidth: CGFloat = 8
    static let trailingPaddingInSeconds: Double = 30
}
