import AVFoundation
import AppKit
import QuartzCore

struct TextOverlay: Equatable {
    var clips: [Clip]
    var renderSize: CGSize

    var isEmpty: Bool {
        clips.isEmpty
    }
}
