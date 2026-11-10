import Foundation
@testable import Clipsmith

enum TestClips {
    static func video(
        start: TimeInterval,
        sourceStart: TimeInterval = 0,
        sourceEnd: TimeInterval = 10,
        sourceDuration: TimeInterval? = 100
    ) -> Clip {
        Clip(
            sourceURL: URL(fileURLWithPath: "/tmp/video.mp4"),
            mediaKind: .video,
            startInSeconds: start,
            sourceStartInSeconds: sourceStart,
            sourceEndInSeconds: sourceEnd,
            sourceDurationInSeconds: sourceDuration
        )
    }

    static func audio(start: TimeInterval, duration: TimeInterval) -> Clip {
        Clip(
            sourceURL: URL(fileURLWithPath: "/tmp/music.m4a"),
            mediaKind: .audio,
            startInSeconds: start,
            sourceStartInSeconds: 0,
            sourceEndInSeconds: duration,
            sourceDurationInSeconds: duration
        )
    }

    static func mediaItem(kind: MediaKind = .video, duration: TimeInterval = 10) -> MediaItem {
        MediaItem(url: URL(fileURLWithPath: "/tmp/item.mp4"), kind: kind, durationInSeconds: duration)
    }
}
