import Foundation

extension FileManager {
    func discardItemIgnoringFailure(at url: URL) {
        try? removeItem(at: url)
    }
}
