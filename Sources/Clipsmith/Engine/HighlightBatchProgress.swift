import Foundation

struct HighlightBatchProgress: Equatable {
    let completed: Int
    let total: Int
    let currentName: String
    let fraction: Double
}
