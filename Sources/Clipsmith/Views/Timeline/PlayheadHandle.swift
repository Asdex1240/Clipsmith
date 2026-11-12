import SwiftUI

struct PlayheadHandle: Shape {
    private static let cornerRadius: CGFloat = 3

    func path(in rect: CGRect) -> Path {
        let shoulder = rect.height * 0.55
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: shoulder),
            cornerSize: CGSize(width: Self.cornerRadius, height: Self.cornerRadius))
        path.move(to: CGPoint(x: rect.minX, y: shoulder - 1))
        path.addLine(to: CGPoint(x: rect.maxX, y: shoulder - 1))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    PlayheadHandle()
        .fill(Palette.playhead)
        .frame(width: 14, height: 16)
        .padding()
}
