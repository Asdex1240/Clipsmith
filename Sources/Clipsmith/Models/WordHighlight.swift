import Foundation

struct WordHighlight: Codable, Equatable {
    static let defaultColor = RGBAColor(red: 1, green: 0.85, blue: 0.1)

    var index: Int
    var color = WordHighlight.defaultColor

    func range(in content: String) -> NSRange? {
        var location = 0
        for (position, word) in content.split(separator: " ", omittingEmptySubsequences: false)
            .enumerated()
        {
            let length = word.utf16.count
            if position == index {
                guard length > 0 else { return nil }
                return NSRange(location: location, length: length)
            }
            location += length + 1
        }
        return nil
    }
}
