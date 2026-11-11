import CryptoKit
import Foundation

struct DenoisedAudioCache: Sendable {
    static let algorithmVersion = 1

    var directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Clipsmith-denoised")
    var processor: NoiseReductionProcessing = AVNoiseReducer()

    func url(for source: URL, level: NoiseReductionLevel) -> URL {
        let values = try? source.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let key =
            "\(source.path)|\(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)|\(values?.fileSize ?? 0)|\(level.rawValue)|v\(Self.algorithmVersion)"
        let digest = SHA256.hash(data: Data(key.utf8)).prefix(12).map { String(format: "%02x", $0) }
            .joined()
        return directory.appendingPathComponent("\(digest).caf")
    }

    func requests(in project: Project) -> [(source: URL, level: NoiseReductionLevel)] {
        var seen = Set<String>()
        return project.tracks.flatMap(\.clips).compactMap { clip in
            guard let level = clip.noiseReduction, let source = clip.sourceURL,
                clip.mediaKind == .video || clip.mediaKind == .audio,
                seen.insert("\(source.path)|\(level.rawValue)").inserted
            else { return nil }
            return (source, level)
        }
    }

    func missing(in project: Project) -> [(source: URL, level: NoiseReductionLevel)] {
        requests(in: project).filter {
            !FileManager.default.fileExists(atPath: url(for: $0.source, level: $0.level).path)
        }
    }

    func applying(to project: Project) -> Project {
        var copy = project
        for trackIndex in copy.tracks.indices {
            for clipIndex in copy.tracks[trackIndex].clips.indices {
                let clip = copy.tracks[trackIndex].clips[clipIndex]
                guard let level = clip.noiseReduction, let source = clip.sourceURL else { continue }
                let cached = url(for: source, level: level)
                if FileManager.default.fileExists(atPath: cached.path) {
                    copy.tracks[trackIndex].clips[clipIndex].audioOverrideURL = cached
                }
            }
        }
        return copy
    }

    func generate(_ source: URL, level: NoiseReductionLevel) async throws {
        try await processor.process(
            source: source, level: level, destination: url(for: source, level: level))
    }

    func ensure(_ project: Project) async throws -> Project {
        for request in missing(in: project) {
            do {
                try await generate(request.source, level: request.level)
            } catch NoiseReductionError.noAudio {
                continue
            }
        }
        return applying(to: project)
    }
}
