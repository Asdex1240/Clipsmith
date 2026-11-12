import Foundation

struct HighlightExportOutcome: Equatable {
    enum Result: Equatable {
        case exported(URL)
        case failed(String)
    }

    let name: String
    let result: Result
}
