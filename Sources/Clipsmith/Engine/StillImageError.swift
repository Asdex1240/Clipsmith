import AVFoundation
import AppKit
import CryptoKit

enum StillImageError: Error {
    case unreadableImage(URL)
    case writingFailed(URL)
}
