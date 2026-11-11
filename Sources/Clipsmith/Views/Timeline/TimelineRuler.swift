import SwiftUI

struct TimelineRuler: View {
    let pointsPerSecond: Double
    let width: CGFloat
    let onScrub: (TimeInterval) -> Void

    private static let majorTickHeight: CGFloat = 10
    private static let labelOffset: CGFloat = 3

    var body: some View {
        Canvas { context, size in
            let interval = TimelineScale.tickInterval(pointsPerSecond: pointsPerSecond)
            var time: TimeInterval = 0
            while time * pointsPerSecond <= size.width {
                drawTick(at: time, interval: interval, in: &context, height: size.height)
                time += interval
            }
        }
        .frame(width: width, height: TimelineMetrics.rulerHeight)
        .background(.background.secondary)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0).onChanged { value in
                onScrub(value.location.x / pointsPerSecond)
            }
        )
    }

    private func drawTick(
        at time: TimeInterval, interval: TimeInterval, in context: inout GraphicsContext,
        height: CGFloat
    ) {
        let x = time * pointsPerSecond
        var path = Path()
        path.move(to: CGPoint(x: x, y: height - Self.majorTickHeight))
        path.addLine(to: CGPoint(x: x, y: height))
        context.stroke(path, with: .color(.secondary), lineWidth: 1)
        let label = Text(time.clockString).font(.caption2).foregroundColor(.secondary)
        context.draw(label, at: CGPoint(x: x + Self.labelOffset, y: 1), anchor: .topLeading)
    }
}

#Preview {
    TimelineRuler(pointsPerSecond: 40, width: 480, onScrub: { _ in })
}
