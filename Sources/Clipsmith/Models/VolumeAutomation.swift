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
        steps.append(contentsOf: duckingSteps(for: clip, volume: volume))
        return steps
    }

    private static func duckingSteps(for clip: Clip, volume: Float) -> [VolumeStep] {
        guard let ducking = clip.ducking else { return [] }
        let attack = ClipDucking.attackInSeconds
        let release = ClipDucking.releaseInSeconds
        let lower = clip.startInSeconds + clip.fadeInDurationInSeconds + attack
        let upper = clip.endInSeconds - clip.fadeOutDurationInSeconds - release
        let ducked = volume * Float(ducking.level)
        let windows = SpeechActivity.merged(clip.duckingRangesOnTimeline(), gap: attack + release)
        return windows.flatMap { window -> [VolumeStep] in
            let start = max(window.lowerBound, lower)
            let end = min(window.upperBound, upper)
            guard end > start else { return [] }
            return [
                VolumeStep(
                    startInSeconds: start - attack, durationInSeconds: attack,
                    startVolume: volume, endVolume: ducked),
                VolumeStep(
                    startInSeconds: end, durationInSeconds: release,
                    startVolume: ducked, endVolume: volume),
            ]
        }
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
