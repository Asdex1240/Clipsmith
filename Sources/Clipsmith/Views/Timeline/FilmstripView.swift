import SwiftUI

struct FilmstripView: View {
    let filmstrip: Filmstrip
    let clip: Clip
    let pointsPerSecond: Double

    private static let fallbackAspect: CGFloat = 16.0 / 9

    var body: some View {
        Canvas { context, size in
            let aspect = tileAspect
            let tileWidth = max(size.height * aspect, 1)
            var x: CGFloat = 0
            while x < size.width {
                let center = (x + tileWidth / 2) / pointsPerSecond
                let source = clip.sourceStartInSeconds + center * clip.speed
                if let frame = filmstrip.frame(atSourceTime: source) {
                    let image = Image(decorative: frame, scale: 1)
                    context.draw(
                        image, in: CGRect(x: x, y: 0, width: tileWidth, height: size.height))
                }
                x += tileWidth
            }
        }
        .allowsHitTesting(false)
    }

    private var tileAspect: CGFloat {
        guard let frame = filmstrip.frames.first, frame.height > 0 else {
            return Self.fallbackAspect
        }
        return CGFloat(frame.width) / CGFloat(frame.height)
    }
}

#Preview {
    let context = CGContext(
        data: nil, width: 64, height: 36, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    if let image = context?.makeImage() {
        FilmstripView(
            filmstrip: Filmstrip(frames: [image], durationInSeconds: 8),
            clip: PreviewFixtures.videoClip, pointsPerSecond: 40
        )
        .frame(width: 320, height: 44)
    }
}
