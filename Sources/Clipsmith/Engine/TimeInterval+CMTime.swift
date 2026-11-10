import CoreMedia

extension TimeInterval {
    static let compositionTimescale: CMTimeScale = 600

    var cmTime: CMTime {
        CMTime(seconds: self, preferredTimescale: Self.compositionTimescale)
    }
}
