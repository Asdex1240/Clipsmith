import AVFoundation
import AppKit
import CryptoKit

protocol StillImageVideoMaking {
    func makeVideo(from imageURL: URL, size: CGSize, mode: FitMode) async throws -> URL
}
