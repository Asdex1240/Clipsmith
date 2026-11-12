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
        MediaItem(
            url: URL(fileURLWithPath: "/tmp/item.mp4"), kind: kind, durationInSeconds: duration)
    }
}

enum TestSignals {
    static func toneBurst(at time: Double) -> Float {
        guard Int(time / 0.7) % 2 == 0 else { return 0 }
        return Float(0.3 * sin(2 * .pi * 1000 * time))
    }
}
