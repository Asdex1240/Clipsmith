import Foundation

struct Stabilization: Codable, Equatable {
    struct Correction: Equatable {
        let dx: Double
        let dy: Double
        let zoom: Double

        static let none = Correction(dx: 0, dy: 0, zoom: 1)
    }

    let points: [StabilizationPoint]
    let zoom: Double

    func correction(atSourceTime time: TimeInterval) -> Correction {
        guard let first = points.first, let last = points.last else { return .none }
        guard time > first.timeInSeconds else {
            return Correction(dx: first.dx, dy: first.dy, zoom: zoom)
        }
        guard time < last.timeInSeconds else {
            return Correction(dx: last.dx, dy: last.dy, zoom: zoom)
        }
        guard let next = points.firstIndex(where: { $0.timeInSeconds > time }) else {
            return Correction(dx: last.dx, dy: last.dy, zoom: zoom)
        }
        let from = points[next - 1]
        let to = points[next]
        let span = to.timeInSeconds - from.timeInSeconds
        guard span > 0 else { return Correction(dx: to.dx, dy: to.dy, zoom: zoom) }
        let fraction = (time - from.timeInSeconds) / span
        return Correction(
            dx: from.dx + (to.dx - from.dx) * fraction,
            dy: from.dy + (to.dy - from.dy) * fraction,
            zoom: zoom)
    }
}
