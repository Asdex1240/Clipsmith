import Foundation
import Observation

@MainActor
@Observable
final class PreviewSettings {
    static let qualityKey = "preview.quality"

    var quality: PreviewQuality {
        didSet { defaults.set(quality.rawValue, forKey: Self.qualityKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        quality =
            defaults.string(forKey: Self.qualityKey).flatMap(PreviewQuality.init) ?? .full
    }
}
