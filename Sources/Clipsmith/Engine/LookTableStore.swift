import CoreImage
import Foundation
import os

final class LookTableStore: @unchecked Sendable {
    static let shared = LookTableStore()

    private let lock = NSLock()
    private var tables: [URL: PreparedLookTable] = [:]
    private var failedURLs: Set<URL> = []
    private let logger = Logger(subsystem: "Clipsmith", category: "lut")

    func table(at url: URL) -> PreparedLookTable? {
        if let cached = lock.withLock({ tables[url] }) { return cached }
        guard !lock.withLock({ failedURLs.contains(url) }) else { return nil }
        do {
            let table = PreparedLookTable(try Self.load(url))
            lock.withLock { tables[url] = table }
            return table
        } catch {
            logger.error("Could not load the LUT at \(url.path): \(error.localizedDescription)")
            lock.withLock { _ = failedURLs.insert(url) }
            return nil
        }
    }

    static func load(_ url: URL) throws -> CubeLookTable {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw LookTableError.unreadable
        }
        return try CubeLookTable(parsing: text)
    }
}
