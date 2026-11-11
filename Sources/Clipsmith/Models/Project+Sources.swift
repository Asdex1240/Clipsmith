import Foundation

extension Project {
    var referencedSourceURLs: Set<URL> {
        Set(tracks.flatMap(\.clips).compactMap(\.sourceURL))
    }

    mutating func remapSources(_ replacements: [URL: URL]) {
        for trackIndex in tracks.indices {
            for clipIndex in tracks[trackIndex].clips.indices {
                guard let url = tracks[trackIndex].clips[clipIndex].sourceURL,
                    let replacement = replacements[url]
                else { continue }
                tracks[trackIndex].clips[clipIndex].sourceURL = replacement
            }
        }
    }
}

extension MediaItem {
    func remapped(_ replacements: [URL: URL]) -> MediaItem {
        var item = self
        item.url = replacements[url] ?? url
        return item
    }
}
