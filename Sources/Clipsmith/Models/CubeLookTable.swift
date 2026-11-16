import Foundation

struct CubeLookTable: Equatable {
    static let supportedSizes = 2...64

    let size: Int
    let rgbaValues: [Float]

    init(parsing text: String) throws {
        var size: Int?
        var values: [Float] = []
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if let declared = Self.declaredSize(in: line) { size = declared }
            guard let color = Self.color(in: line) else { continue }
            values.append(contentsOf: color)
        }
        guard let size, Self.supportedSizes.contains(size) else {
            throw LookTableError.missingSize
        }
        guard values.count == size * size * size * 4 else {
            throw LookTableError.wrongEntryCount
        }
        self.size = size
        rgbaValues = values
    }

    private static func declaredSize(in line: String) -> Int? {
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count == 2, parts[0] == "LUT_3D_SIZE" else { return nil }
        return Int(parts[1])
    }

    private static func color(in line: String) -> [Float]? {
        guard let first = line.first, first.isNumber || first == "-" || first == "." else {
            return nil
        }
        let components = line.split(separator: " ", omittingEmptySubsequences: true)
            .compactMap { Float($0) }
        guard components.count == 3 else { return nil }
        return components + [1]
    }
}
