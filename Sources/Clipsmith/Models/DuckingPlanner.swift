import Foundation

enum DuckingPlanner {
    static func timelineRanges(
        voices: [(clip: Clip, peaks: [Float])]
    ) -> [Range<TimeInterval>] {
        let all = voices.flatMap { voice -> [Range<TimeInterval>] in
            let source = SpeechActivity.ranges(
                peaks: voice.peaks, from: voice.clip.sourceStartInSeconds,
                to: voice.clip.sourceEndInSeconds)
            return SilenceDetector.timelineRanges(source, for: voice.clip)
        }
        return SpeechActivity.merged(all, gap: SpeechActivity.mergeGapInSeconds)
    }
}
