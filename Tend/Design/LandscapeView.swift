import SwiftUI

/// Original vector artwork. No network images, assets, or third-party rendering dependency.
struct LandscapeView: View {
    var variant: Variant = .meadow
    var showSun = true
    var palette: TendPalette? = nil
    enum Variant { case meadow, dusk, closeup }
    @Environment(\.colorScheme) private var colorScheme

    private var selectedPalette: TendPalette { palette ?? TendTheme.selectedPalette }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                if selectedPalette == .ocean {
                    oceanScene(width: width, height: height)
                } else {
                    forestScene(width: width, height: height)
                }
            }
            .clipped()
        }
        .accessibilityHidden(true)
    }

    private func forestScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Rectangle().fill(sceneColor(variant == .dusk ? 0xE7D5C4 : 0xE8E9D7, 0x24342B))
            if showSun {
                Circle().fill(sceneColor(0xF5DB9D, 0xC8AA73)).frame(width: width * 0.2)
                    .position(x: width * 0.72, y: height * 0.28)
            }
            Hill(crest: 0.43, dip: 0.7)
                .fill(sceneColor(variant == .dusk ? 0xB8AD9D : 0xBEC8AC, 0x4B5A47))
            Hill(crest: 0.72, dip: 0.46)
                .fill(sceneColor(variant == .dusk ? 0x9C9D8F : 0x8EA58B, 0x3B5847))
                .scaleEffect(x: -1, y: 1)
            Hill(crest: 0.8, dip: 0.64).fill(sceneColor(0x55795F, 0x284B3D))
            Path { path in
                path.move(to: CGPoint(x: width * 0.52, y: height * 0.62))
                path.addCurve(to: CGPoint(x: width * 0.54, y: height),
                              control1: CGPoint(x: width * 0.1, y: height * 0.8),
                              control2: CGPoint(x: width * 0.98, y: height * 0.8))
            }
            .stroke(sceneColor(0xD4D2B2, 0x9DA88F),
                    style: StrokeStyle(lineWidth: width * 0.04, lineCap: .round))
            Sprig().stroke(sceneColor(0x294B3B, 0xBCD3B7),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: width * 0.23, height: height * 0.52)
                .rotationEffect(.degrees(-14)).position(x: width * 0.1, y: height * 0.8)
            Sprig().stroke(sceneColor(0xD2DABC, 0x9FB6A2),
                           style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
                .frame(width: width * 0.18, height: height * 0.4)
                .rotationEffect(.degrees(20)).position(x: width * 0.88, y: height * 0.88)
        }
    }

    private func oceanScene(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Rectangle().fill(sceneColor(variant == .dusk ? 0xD0EDEC : 0xDFF3F2, 0x123E4E))
            if showSun {
                Circle().fill(sceneColor(0xF88B64, 0xEBAC72))
                    .frame(width: min(width * 0.14, height * 0.22))
                    .position(x: width * 0.76, y: height * 0.24)
            }
            OceanBand(start: 0.47, end: 0.47, swell: 0)
                .fill(sceneColor(0x057DB1, 0x145B7B))
            OceanBand(start: 0.61, end: 0.56, swell: 0.045)
                .fill(sceneColor(0x029AB7, 0x126F87))
            OceanBand(start: 0.70, end: 0.68, swell: -0.045)
                .fill(sceneColor(0x17B6BE, 0x167F89))
            OceanBand(start: 0.85, end: 0.75, swell: 0.07)
                .fill(sceneColor(0x78D6CF, 0x368F93))
            OceanBand(start: 0.96, end: 0.88, swell: -0.06)
                .fill(sceneColor(0xF5EBDD, 0x7A857C))
            OceanFoam()
                .stroke(sceneColor(0xFAFFFC, 0xA7D9D6).opacity(0.9),
                        style: StrokeStyle(lineWidth: max(1, height * 0.012), lineCap: .round))
            // Fixed positions keep the illustration stable across redraws.
            ForEach(0..<14, id: \.self) { index in
                let x = CGFloat((index * 37 + 11) % 97) / 100
                let y = 0.51 + CGFloat((index * 17 + 3) % 20) / 100
                Capsule()
                    .fill(sceneColor(0xEFFFF9, 0x91CFD1).opacity(index.isMultiple(of: 3) ? 0.8 : 0.45))
                    .frame(width: max(2, width * 0.012), height: max(1, height * 0.006))
                    .position(x: width * x, y: height * y)
            }
        }
    }

    private func sceneColor(_ light: UInt, _ dark: UInt) -> Color {
        Color(hex: colorScheme == .dark ? dark : light)
    }
}

private struct Hill: Shape {
    let crest: CGFloat
    let dip: CGFloat
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: rect.height * crest))
            path.addCurve(to: CGPoint(x: rect.width, y: rect.height * dip),
                          control1: CGPoint(x: rect.width * 0.4, y: rect.height * (crest - 0.25)),
                          control2: CGPoint(x: rect.width * 0.65, y: rect.height * (dip + 0.2)))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
        }
    }
}

struct Sprig: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.width * 0.6, y: 0), control: CGPoint(x: rect.width * 0.2, y: rect.midY))
            for index in 0..<5 {
                let y = rect.height * (0.18 + CGFloat(index) * 0.16)
                let x = rect.width * (0.48 - CGFloat(index) * 0.025)
                path.move(to: CGPoint(x: x, y: y))
                path.addQuadCurve(to: CGPoint(x: rect.width * 0.08, y: y - rect.height * 0.13), control: CGPoint(x: 0, y: y))
                path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: rect.width * 0.3, y: y - rect.height * 0.17))
                path.move(to: CGPoint(x: x, y: y + rect.height * 0.08))
                path.addQuadCurve(to: CGPoint(x: rect.width * 0.97, y: y - rect.height * 0.04), control: CGPoint(x: rect.width, y: y + rect.height * 0.08))
                path.addQuadCurve(to: CGPoint(x: x, y: y + rect.height * 0.08), control: CGPoint(x: rect.width * 0.75, y: y - rect.height * 0.13))
            }
        }
    }
}

private struct OceanBand: Shape {
    let start: CGFloat
    let end: CGFloat
    let swell: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: rect.height * start))
            path.addCurve(to: CGPoint(x: rect.width, y: rect.height * end),
                          control1: CGPoint(x: rect.width * 0.34, y: rect.height * (start + swell)),
                          control2: CGPoint(x: rect.width * 0.68, y: rect.height * (end - swell)))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct OceanFoam: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            let segments: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (0.04, 0.36, 0.57, 0.56),
                (0.49, 0.89, 0.59, 0.58),
                (0.12, 0.55, 0.73, 0.71),
                (0.68, 0.98, 0.69, 0.67),
                (0.00, 0.44, 0.88, 0.87),
                (0.53, 1.00, 0.85, 0.79)
            ]
            for (startX, endX, startY, endY) in segments {
                path.move(to: CGPoint(x: rect.width * startX, y: rect.height * startY))
                path.addCurve(to: CGPoint(x: rect.width * endX, y: rect.height * endY),
                              control1: CGPoint(x: rect.width * (startX + (endX - startX) * 0.3),
                                                y: rect.height * (startY + 0.025)),
                              control2: CGPoint(x: rect.width * (startX + (endX - startX) * 0.7),
                                                y: rect.height * (endY - 0.025)))
            }
        }
    }
}
