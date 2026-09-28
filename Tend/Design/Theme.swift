import SwiftUI

enum TendPalette: String, CaseIterable, Identifiable {
    case ocean, forest

    var id: String { rawValue }
    var title: String {
        switch self {
        case .forest: "Forest"
        case .ocean: "Ocean"
        }
    }
}

enum TendTheme {
    static let palettePreferenceKey = "tend.colorPalette"
    static var selectedPalette: TendPalette {
        TendPalette(rawValue: UserDefaults.standard.string(forKey: palettePreferenceKey) ?? "") ?? .ocean
    }

    static var paper: Color { themed(0xF7F5EF, 0x171E1B, 0xEFF8F8, 0x0B2029) }
    static var surface: Color { themed(0xFFFEFA, 0x232E28, 0xFFFFFF, 0x16323D) }
    static var ink: Color { themed(0x203C32, 0xF1F3E9, 0x123D50, 0xECF9FA) }
    static var secondary: Color { themed(0x5A6B60, 0xB5C3B6, 0x506E79, 0xB2CDD4) }
    // The forest token is the primary accent for both palettes.
    static var forest: Color { themed(0x284E3F, 0xB8D3AA, 0x006C98, 0x78D9EB) }
    static var onForest: Color { themed(0xFFFEF6, 0x1B3026, 0xFFFFFF, 0x073342) }
    static var sage: Color { themed(0xE2E9DA, 0x303E32, 0xD7F0F0, 0x1B4652) }
    static var clay: Color { themed(0xF1E3D8, 0x45352E, 0xFFE7DE, 0x463733) }
    static var terracotta: Color { themed(0x885D47, 0xE2B39A, 0xA24832, 0xFFB89F) }
    static var line: Color { themed(0xDDE1D6, 0x39473D, 0xC4DFE4, 0x345864) }
    static var gold: Color { themed(0xDFC27D, 0xDFC27D, 0xF0C54F, 0xF0CB68) }

    static var sea: Color { themed(0x416950, 0xA1C5AF, 0x006E70, 0x71D7CC) }

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    private static func themed(_ forestLight: UInt, _ forestDark: UInt,
                               _ oceanLight: UInt, _ oceanDark: UInt) -> Color {
        selectedPalette == .ocean
            ? adaptive(oceanLight, oceanDark)
            : adaptive(forestLight, forestDark)
    }

    private static func adaptive(_ light: UInt, _ dark: UInt) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension Color {
    init(hex: UInt) {
        self.init(red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255,
                  blue: Double(hex & 255) / 255)
    }
}

private extension UIColor {
    convenience init(hex: UInt) {
        self.init(red: CGFloat((hex >> 16) & 255) / 255,
                  green: CGFloat((hex >> 8) & 255) / 255,
                  blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(TendTheme.onForest)
            .background(TendTheme.forest.opacity(isEnabled ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 18))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.body.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(TendTheme.ink)
            .background(TendTheme.sage.opacity(configuration.isPressed ? 0.7 : 0.45), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.footnote.weight(.semibold)).tracking(1.4)
            .foregroundStyle(TendTheme.secondary)
    }
}

struct SectionHeading: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.semibold)).foregroundStyle(TendTheme.ink)
            Spacer()
            if let detail { Text(detail).font(.footnote).foregroundStyle(TendTheme.secondary) }
        }
    }
}

struct EmptyMoment: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol).font(.system(size: 32, weight: .light))
                .foregroundStyle(TendTheme.forest).frame(width: 72, height: 72)
                .background(TendTheme.sage, in: Circle())
            Text(title).font(.title3.weight(.medium))
            Text(message).font(.subheadline).foregroundStyle(TendTheme.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity).padding(32)
    }
}

extension View {
    func tendScreen() -> some View {
        self.background(TendTheme.paper).foregroundStyle(TendTheme.ink)
    }
    func tendCard(_ color: Color = TendTheme.surface) -> some View {
        self.padding(20).background(color, in: RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(TendTheme.line.opacity(0.45), lineWidth: 0.5)
                    .allowsHitTesting(false)
            }
    }
}
