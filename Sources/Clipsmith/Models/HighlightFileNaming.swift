import Foundation

enum HighlightFileNaming {
    static let fileExtension = "mp4"
    static let fallbackName = "Highlight"

    private static let forbiddenCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        .union(.controlCharacters)

    static func sanitized(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.components(separatedBy: forbiddenCharacters).joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !cleaned.isEmpty else { return fallbackName }
        return cleaned
    }

    static func fileNames(for names: [String]) -> [String] {
        var used: [String: Int] = [:]
        return names.map { name in
            let base = sanitized(name)
            let key = base.lowercased()
            let count = (used[key] ?? 0) + 1
            used[key] = count
            guard count > 1 else { return "\(base).\(fileExtension)" }
            return "\(base) \(count).\(fileExtension)"
        }
    }
}
