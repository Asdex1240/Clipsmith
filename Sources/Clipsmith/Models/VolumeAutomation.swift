import Foundation

enum VolumeAutomation {
    static func steps(for clip: Clip) -> [VolumeStep] {
        let volume = Float(clip.volume)
        var steps = [fadeInStep(for: clip, volume: volume)]
        if clip.fadeOutDurationInSeconds > 0 {
            steps.append(
                VolumeStep(
                    startInSeconds: clip.endInSeconds - clip.fadeOutDurationInSeconds,
                    durationInSeconds: clip.fadeOutDurationInSeconds,
                    startVolume: volume,
                    endVolume: 0
                ))
        }
        return steps
    }

    private static func fadeInStep(for clip: Clip, volume: Float) -> VolumeStep {
        guard clip.fadeInDurationInSeconds > 0 else {
            return VolumeStep(
                startInSeconds: clip.startInSeconds, durationInSeconds: 0,
                startVolume: volume, endVolume: volume
            )
        }
        return VolumeStep(
            startInSeconds: clip.startInSeconds, durationInSeconds: clip.fadeInDurationInSeconds,
            startVolume: 0, endVolume: volume
        )
    }
}
