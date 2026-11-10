import Foundation

/// The project's work area: the frame every clip is placed in, in pixels.
struct CanvasFormat: Codable, Hashable, Identifiable {
    static let minimumSide = 240
    static let maximumSide = 7680
    static let defaultShortSide = 1080

    static let landscape = CanvasFormat(width: 1920, height: 1080)
    static let portrait = CanvasFormat(width: 1080, height: 1920)
    static let square = CanvasFormat(width: 1080, height: 1080)
    static let portrait4x5 = CanvasFormat(width: 1080, height: 1350)
    static let portrait3x4 = CanvasFormat(width: 1080, height: 1440)
    static let landscape4x3 = CanvasFormat(width: 1440, height: 1080)
    static let ultrawide = CanvasFormat(width: 2520, height: 1080)

    static let presets: [CanvasFormat] = [
        .landscape, .portrait, .square, .portrait4x5, .portrait3x4, .landscape4x3, .ultrawide,
    ]

    private static let knownAspects: [(label: String, ratio: Double)] = [
        ("16:9", 16.0 / 9), ("9:16", 9.0 / 16), ("1:1", 1), ("4:5", 4.0 / 5),
        ("3:4", 3.0 / 4), ("4:3", 4.0 / 3), ("21:9", 21.0 / 9),
    ]
    private static let aspectTolerance = 0.02

    let width: Int
    let height: Int

    /// Sizes outside the supported range are clamped and odd sizes rounded down, because H.264 needs even dimensions.
    init(width: Int, height: Int) {
        self.width = Self.sanitized(width)
        self.height = Self.sanitized(height)
    }

    var id: String { "\(width)x\(height)" }
    var renderSize: CGSize { CGSize(width: width, height: height) }
    var aspectRatio: Double { Double(width) / Double(height) }
    var shortSide: Int { min(width, height) }

    /// "16:9", "9:16"… or nil when the proportion is not one of the common ones.
    var aspectLabel: String? {
        Self.knownAspects.first { abs($0.ratio - aspectRatio) < Self.aspectTolerance * $0.ratio }?.label
    }

    var summary: String {
        "\(aspectLabel ?? localized("canvas.custom")) · \(width)×\(height)"
    }

    /// The same proportion with its shorter side set to `side` pixels.
    func scaled(toShortSide side: Int) -> CanvasFormat {
        if width >= height {
            return CanvasFormat(width: Int((Double(side) * aspectRatio).rounded()), height: side)
        }
        return CanvasFormat(width: side, height: Int((Double(side) / aspectRatio).rounded()))
    }

    /// The canvas that frames media of the given pixel size without bars: a preset when the proportion is a common one.
    static func fitting(_ size: CGSize) -> CanvasFormat? {
        guard size.width > 0, size.height > 0 else { return nil }
        let aspect = size.width / size.height
        if let preset = presets.first(where: { abs($0.aspectRatio - aspect) < aspectTolerance * aspect }) {
            return preset
        }
        let wanted = CanvasFormat(width: Int(size.width.rounded()), height: Int(size.height.rounded()))
        return wanted.scaled(toShortSide: defaultShortSide)
    }

    private static func sanitized(_ side: Int) -> Int {
        (min(max(side, minimumSide), maximumSide) / 2) * 2
    }

    private enum CodingKeys: String, CodingKey {
        case width, height
    }

    init(from decoder: Decoder) throws {
        // Projects saved before custom sizes stored the canvas as "landscape" or "portrait".
        if let legacy = try? decoder.singleValueContainer().decode(String.self) {
            self = legacy == "portrait" ? .portrait : .landscape
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(width: try container.decode(Int.self, forKey: .width), height: try container.decode(Int.self, forKey: .height))
    }
}
