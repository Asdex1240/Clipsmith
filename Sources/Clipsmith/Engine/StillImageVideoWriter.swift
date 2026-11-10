import AVFoundation
import AppKit
import CryptoKit

enum StillImageError: Error {
    case unreadableImage(URL)
    case writingFailed(URL)
}

protocol StillImageVideoMaking {
    func makeVideo(from imageURL: URL, size: CGSize, mode: FitMode) async throws -> URL
}

extension StillImageVideoMaking {
    func makeVideo(from imageURL: URL, size: CGSize) async throws -> URL {
        try await makeVideo(from: imageURL, size: size, mode: .fit)
    }
}

final class StillImageVideoWriter: StillImageVideoMaking {
    static let durationInSeconds: TimeInterval = 1
    private static let frameTimesInSeconds: [TimeInterval] = [0, 0.5]
    private static let bufferPollInterval: Duration = .milliseconds(10)

    private let directory: URL

    init(directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("Clipsmith-stills")) {
        self.directory = directory
    }

    func makeVideo(from imageURL: URL, size: CGSize, mode: FitMode) async throws -> URL {
        let destination = cachedURL(for: imageURL, size: size, mode: mode)
        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let partial = destination.appendingPathExtension("partial")
        try? FileManager.default.removeItem(at: partial)
        try await write(imageAt: imageURL, size: size, mode: mode, to: partial)
        try FileManager.default.moveItem(at: partial, to: destination)
        return destination
    }

    private func cachedURL(for imageURL: URL, size: CGSize, mode: FitMode) -> URL {
        let modified = (try? imageURL.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate?.timeIntervalSince1970 ?? 0
        let key = "\(imageURL.path)|\(Int(size.width))x\(Int(size.height))|\(mode.rawValue)|\(modified)"
        let digest = SHA256.hash(data: Data(key.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent("\(digest).mov")
    }

    private func write(imageAt imageURL: URL, size: CGSize, mode: FitMode, to url: URL) async throws {
        guard let image = NSImage(contentsOf: imageURL)?.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let buffer = makePixelBuffer(drawing: image, size: size, mode: mode) else {
            throw StillImageError.unreadableImage(imageURL)
        }
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        for time in Self.frameTimesInSeconds {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: Self.bufferPollInterval)
            }
            adaptor.append(buffer, withPresentationTime: time.cmTime)
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: Self.durationInSeconds.cmTime)
        await writer.finishWriting()
        guard writer.status == .completed else { throw StillImageError.writingFailed(imageURL) }
    }

    private func makePixelBuffer(drawing image: CGImage, size: CGSize, mode: FitMode) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA, nil, &buffer)
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }
        let bounds = CGRect(origin: .zero, size: size)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(bounds)
        let imageSize = CGSize(width: image.width, height: image.height)
        context.draw(image, in: drawingRect(for: imageSize, in: bounds, mode: mode))
        return buffer
    }

    private func drawingRect(for imageSize: CGSize, in bounds: CGRect, mode: FitMode) -> CGRect {
        guard mode == .fill else { return AVMakeRect(aspectRatio: imageSize, insideRect: bounds) }
        let scale = max(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
    }
}
