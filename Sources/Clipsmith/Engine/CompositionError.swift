import AVFoundation
import ImageIO
import OSLog

enum CompositionError: Error {
    case missingSource
    case missingTrack(URL)
    case cannotCreateTrack
}
