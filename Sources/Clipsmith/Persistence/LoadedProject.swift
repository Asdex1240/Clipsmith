import Foundation

struct LoadedProject {
    var project: Project
    var library: [MediaItem]
    var missingMedia: [URL]
}
