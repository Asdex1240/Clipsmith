import SwiftUI

struct WaveformView: View {
    let peaks: [Float]
    let clip: Clip
    let pointsPerSecond: Double
    let color: Color

    private static let columnWidth: CGFloat = 2
    private static let maximumColumns = 1500
    private static let visualGain: Float = 0.6

    var body: some View {
        Canvas { context, size in
            let count = min(max(1, Int(size.width / Self.columnWidth)), Self.maximumColumns)
            let columns = WaveformResampler.columns(
                peaks: peaks,
                peaksPerSecond: WaveformSpec.peaksPerSecond,
                sourceStart: clip.sourceStartInSeconds,
                sourceEnd: clip.sourceEndInSeconds,
                columnCount: count
            )
            let width = size.width / CGFloat(count)
            for (index, peak) in columns.enumerated() {
                let height = max(1, CGFloat(pow(peak, Self.visualGain)) * size.height)
                let rect = CGRect(
                    x: CGFloat(index) * width, y: (size.height - height) / 2,
                    width: max(width - 0.5, 0.5), height: height)
                context.fill(Path(rect), with: .color(color))
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    WaveformView(
        peaks: PreviewFixtures.waveformPeaks, clip: PreviewFixtures.videoClip,
        pointsPerSecond: 40, color: .green
    )
    .frame(width: 320, height: 40)
}
