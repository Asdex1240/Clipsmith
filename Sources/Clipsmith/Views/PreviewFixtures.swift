import SwiftUI

@MainActor
enum PreviewFixtures {
    private static let sampleVideoURL = URL(fileURLWithPath: "/tmp/sample.mov")
    private static let sampleDurationInSeconds: TimeInterval = 8
    private static let samplePixelSize = CGSize(width: 1920, height: 1080)
    private static let waveformPeakCount = 80

    static let mediaItem = MediaItem(
        url: sampleVideoURL,
        kind: .video,
        durationInSeconds: sampleDurationInSeconds,
        pixelSize: samplePixelSize
    )

    static let videoClip = Clip(item: mediaItem, startInSeconds: 0)

    static let textClip = Clip(
        text: TextLayer(content: "Preview"), startInSeconds: 1, durationInSeconds: 4
    )

    static let waveformPeaks: [Float] = (0..<waveformPeakCount).map { index in
        Float(abs(sin(Double(index) / 4)))
    }

    static func store() -> ProjectStore {
        var project = Project(name: "Preview")
        _ = project.addClip(videoClip, toTrack: mainTrackID(of: project))
        _ = project.addClip(textClip, toTrack: textTrackID(of: project))
        let store = ProjectStore(project: project)
        store.selectClip(videoClip.id)
        return store
    }

    private static func mainTrackID(of project: Project) -> Track.ID {
        project.track(withRole: .main)?.id ?? UUID()
    }

    private static func textTrackID(of project: Project) -> Track.ID {
        project.track(withRole: .text)?.id ?? UUID()
    }
}
