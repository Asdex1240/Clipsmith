import CryptoKit
import Foundation

enum FileFingerprint {
    private static let digestByteCount = 12

    static func digest(of url: URL, extra: String = "") -> String {
        let fresh = URL(fileURLWithPath: url.path)
        let values = try? fresh.resourceValues(forKeys: [
            .contentModificationDateKey, .fileSizeKey,
        ])
        let modified = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
        let size = values?.fileSize ?? 0
        let key = "\(url.path)|\(modified)|\(size)\(extra)"
        return SHA256.hash(data: Data(key.utf8)).prefix(digestByteCount)
            .map { String(format: "%02x", $0) }.joined()
    }
}
