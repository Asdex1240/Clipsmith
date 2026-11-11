import SwiftUI

enum SliderValueDisplay {
    case percent, signedNumber

    func text(for value: Double) -> String {
        switch self {
        case .percent: return "\(Int((value * 100).rounded()))%"
        case .signedNumber: return String(format: "%+.0f", value * 100)
        }
    }
}
