import AppKit

let canvas: CGFloat = 1024
let margin: CGFloat = 100
let bodyRect = CGRect(x: margin, y: margin, width: canvas - 2 * margin, height: canvas - 2 * margin)
let cornerRadius: CGFloat = 185

func render(size: Int) -> Data? {
    guard let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.scaleBy(x: CGFloat(size) / canvas, y: CGFloat(size) / canvas)
    drawBody(in: context)
    drawFilmHoles(in: context)
    drawPlayTriangle(in: context)
    drawCut(in: context)
    guard let image = context.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
}

func drawBody(in context: CGContext) {
    let path = CGPath(roundedRect: bodyRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: CGColor(gray: 0, alpha: 0.35))
    context.addPath(path)
    context.setFillColor(CGColor(gray: 0.1, alpha: 1))
    context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.addPath(path)
    context.clip()
    let colors = [
        CGColor(red: 1.0, green: 0.55, blue: 0.2, alpha: 1),
        CGColor(red: 0.93, green: 0.2, blue: 0.45, alpha: 1),
        CGColor(red: 0.4, green: 0.15, blue: 0.7, alpha: 1),
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 0.5, 1])!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: bodyRect.minX, y: bodyRect.maxY),
        end: CGPoint(x: bodyRect.maxX, y: bodyRect.minY),
        options: []
    )
    context.restoreGState()
}

func drawFilmHoles(in context: CGContext) {
    let holeSize = CGSize(width: 38, height: 54)
    let count = 7
    let spacing = (bodyRect.height - 2 * 90 - holeSize.height) / CGFloat(count - 1)
    context.setFillColor(CGColor(gray: 1, alpha: 0.28))
    for index in 0..<count {
        let y = bodyRect.minY + 90 + CGFloat(index) * spacing
        for x in [bodyRect.minX + 50, bodyRect.maxX - 50 - holeSize.width] {
            let hole = CGRect(origin: CGPoint(x: x, y: y), size: holeSize)
            context.addPath(CGPath(roundedRect: hole, cornerWidth: 10, cornerHeight: 10, transform: nil))
            context.fillPath()
        }
    }
}

func drawPlayTriangle(in context: CGContext) {
    let center = CGPoint(x: canvas / 2 + 16, y: canvas / 2)
    let radius: CGFloat = 215
    let path = CGMutablePath()
    path.move(to: CGPoint(x: center.x - radius * 0.85, y: center.y + radius))
    path.addLine(to: CGPoint(x: center.x + radius * 1.05, y: center.y))
    path.addLine(to: CGPoint(x: center.x - radius * 0.85, y: center.y - radius))
    path.closeSubpath()
    context.saveGState()
    context.addPath(path)
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.setLineJoin(.round)
    context.setLineWidth(46)
    context.setStrokeColor(CGColor(gray: 1, alpha: 1))
    context.drawPath(using: .fillStroke)
    context.restoreGState()
}

func drawCut(in context: CGContext) {
    context.saveGState()
    context.setStrokeColor(CGColor(red: 0.3, green: 0.1, blue: 0.45, alpha: 1))
    context.setLineWidth(30)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: 600, y: 760))
    context.addLine(to: CGPoint(x: 440, y: 260))
    context.strokePath()
    context.restoreGState()
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for entry in sizes {
    guard let data = render(size: entry.pixels) else { fatalError("Could not render \(entry.name)") }
    try data.write(to: outputDirectory.appendingPathComponent("\(entry.name).png"))
}
