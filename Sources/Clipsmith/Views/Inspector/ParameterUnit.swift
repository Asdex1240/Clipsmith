import Foundation

enum ParameterUnit {
    case percent, signedNumber, seconds, degrees, points, multiplier

    private static let percentScale = 100.0

    var scale: Double {
        switch self {
        case .percent, .signedNumber: return Self.percentScale
        case .seconds, .degrees, .points, .multiplier: return 1
        }
    }

    var suffix: String {
        switch self {
        case .percent: return "%"
        case .signedNumber: return ""
        case .seconds: return " s"
        case .degrees: return "°"
        case .points: return " pt"
        case .multiplier: return "×"
        }
    }

    var fractionDigits: Int {
        switch self {
        case .seconds: return 1
        case .multiplier: return 2
        case .percent, .signedNumber, .degrees, .points: return 0
        }
    }

    func displayValue(_ value: Double) -> Double {
        value * scale
    }

    func value(fromDisplay display: Double, in range: ClosedRange<Double>) -> Double {
        min(max(display / scale, range.lowerBound), range.upperBound)
    }

    func text(for value: Double) -> String {
        let display = displayValue(value)
        guard self == .signedNumber else {
            return String(format: "%.\(fractionDigits)f", display) + suffix
        }
        return String(format: "%+.0f", display)
    }
}
