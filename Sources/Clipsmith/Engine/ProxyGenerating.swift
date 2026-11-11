import Foundation

protocol ProxyGenerating: Sendable {
    func needsProxy(for url: URL) async -> Bool
    func makeProxy(from url: URL, to destination: URL) async throws
}
