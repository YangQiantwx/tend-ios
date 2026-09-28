import SwiftUI

/// Practice-specific SF Symbols with a simple, resolution-independent backdrop.
struct PracticeArtwork: View {
    let isMovement: Bool
    var expansion: Double = 0.5
    var symbol: String = "figure.walk"

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                if isMovement {
                    movementArt(side: side)
                } else {
                    mindfulnessArt(side: side)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }

    private func mindfulnessArt(side: CGFloat) -> some View {
        let pulse = CGFloat(expansion)
        return ZStack {
            Circle().fill(TendTheme.clay)
                .frame(width: side * 0.88, height: side * 0.88)
            Circle().stroke(TendTheme.terracotta.opacity(0.34), lineWidth: 4)
                .frame(width: side * (0.68 + 0.16 * pulse),
                       height: side * (0.68 + 0.16 * pulse))
            PracticeSymbol(symbol: symbol, size: side * 0.43, color: TendTheme.terracotta)
        }
    }

    private func movementArt(side: CGFloat) -> some View {
        ZStack {
            Circle().fill(TendTheme.sage)
                .frame(width: side * 0.9, height: side * 0.9)
            Circle().stroke(TendTheme.forest.opacity(0.22), lineWidth: 2)
                .frame(width: side * 0.98, height: side * 0.98)
            PracticeSymbol(symbol: symbol, size: side * 0.58, color: TendTheme.forest)
        }
    }
}

/// The same practice mark can be used in recommendation cards, lists, and details.
struct PracticeSymbol: View {
    let symbol: String
    let size: CGFloat
    let color: Color

    var body: some View {
        Group {
            if symbol == "figure.flexibility" {
                SeatedReachGlyph()
                    .stroke(color, style: StrokeStyle(lineWidth: max(1.8, size * 0.06),
                                                      lineCap: .round, lineJoin: .round))
                    .frame(width: size, height: size)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: size, weight: .regular))
                    .foregroundStyle(color)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A seated reach for Chair movement, instead of a generic standing flexibility icon.
private struct SeatedReachGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        return Path { path in
            path.addEllipse(in: CGRect(x: w * 0.28, y: h * 0.07,
                                       width: w * 0.19, height: h * 0.19))
            // Torso and raised arm.
            path.move(to: CGPoint(x: w * 0.38, y: h * 0.27))
            path.addLine(to: CGPoint(x: w * 0.45, y: h * 0.59))
            path.move(to: CGPoint(x: w * 0.40, y: h * 0.33))
            path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.16))
            path.addLine(to: CGPoint(x: w * 0.66, y: h * 0.11))
            path.move(to: CGPoint(x: w * 0.39, y: h * 0.36))
            path.addLine(to: CGPoint(x: w * 0.30, y: h * 0.50))
            // Seated legs.
            path.move(to: CGPoint(x: w * 0.45, y: h * 0.59))
            path.addLine(to: CGPoint(x: w * 0.67, y: h * 0.62))
            path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.84))
            // Stable chair, clearly separate from the reaching arm.
            path.move(to: CGPoint(x: w * 0.77, y: h * 0.34))
            path.addLine(to: CGPoint(x: w * 0.77, y: h * 0.67))
            path.addLine(to: CGPoint(x: w * 0.45, y: h * 0.67))
            path.move(to: CGPoint(x: w * 0.50, y: h * 0.67))
            path.addLine(to: CGPoint(x: w * 0.46, y: h * 0.94))
            path.move(to: CGPoint(x: w * 0.74, y: h * 0.67))
            path.addLine(to: CGPoint(x: w * 0.79, y: h * 0.94))
        }
    }
}
