import Foundation

struct CacheCleaner: Sendable {
    static let maximumAge: TimeInterval = 30 * 24 * 3600
    static let maximumBytes: Int64 = 5 * 1_073_741_824
    static let partialAge: TimeInterval = 24 * 3600
    static let touchInterval: TimeInterval = 3600

    struct Entry: Equatable {
        let url: URL
        let size: Int64
        let lastUsed: Date
    }

    struct Report: Equatable {
        var removedFiles = 0
        var removedBytes: Int64 = 0
    }

    var directories: [URL]
    var maximumAge = CacheCleaner.maximumAge
    var maximumBytes = CacheCleaner.maximumBytes

    static var standard: CacheCleaner {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return CacheCleaner(directories: [
            caches.appendingPathComponent("Clipsmith-proxies"),
            caches.appendingPathComponent("Clipsmith-denoised"),
            FileManager.default.temporaryDirectory.appendingPathComponent("Clipsmith-stills"),
        ])
    }

    func entries() -> [Entry] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        return directories.flatMap { directory -> [Entry] in
            guard
                let enumerator = FileManager.default.enumerator(
                    at: directory, includingPropertiesForKeys: keys)
            else { return [] }
            return enumerator.compactMap { item -> Entry? in
                guard let url = item as? URL,
                    let values = try? url.resourceValues(forKeys: Set(keys)),
                    values.isRegularFile == true
                else { return nil }
                return Entry(
                    url: url, size: Int64(values.fileSize ?? 0),
                    lastUsed: values.contentModificationDate ?? .distantPast)
            }
        }
    }

    func totalSize() -> Int64 {
        entries().reduce(0) { $0 + $1.size }
    }

    @discardableResult
    func clean(now: Date = Date()) -> Report {
        var report = Report()
        var kept: [Entry] = []
        for entry in entries() {
            let age = now.timeIntervalSince(entry.lastUsed)
            let isPartial = entry.url.lastPathComponent.contains(".partial")
            if age > maximumAge || (isPartial && age > Self.partialAge) {
                remove(entry, into: &report)
            } else {
                kept.append(entry)
            }
        }
        var total = kept.reduce(0) { $0 + $1.size }
        for entry in kept.sorted(by: { $0.lastUsed < $1.lastUsed }) where total > maximumBytes {
            remove(entry, into: &report)
            total -= entry.size
        }
        return report
    }

    @discardableResult
    func clearAll() -> Report {
        var report = Report()
        for entry in entries() { remove(entry, into: &report) }
        return report
    }

    static func touch(_ url: URL, now: Date = Date()) {
        let fresh = URL(fileURLWithPath: url.path)
        let values = try? fresh.resourceValues(forKeys: [.contentModificationDateKey])
        if let modified = values?.contentModificationDate,
            now.timeIntervalSince(modified) < touchInterval
        {
            return
        }
        try? FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: url.path)
    }

    private func remove(_ entry: Entry, into report: inout Report) {
        do {
            try FileManager.default.removeItem(at: entry.url)
        } catch {
            return
        }
        report.removedFiles += 1
        report.removedBytes += entry.size
    }
}
