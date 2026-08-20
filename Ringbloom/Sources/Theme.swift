import SwiftUI

enum RingbloomTheme {
    static let ink = Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255)
    static let inkLifted = Color(red: 24 / 255, green: 36 / 255, blue: 58 / 255)
    static let ivory = Color(red: 1, green: 245 / 255, blue: 214 / 255)
    static let muted = Color(red: 182 / 255, green: 194 / 255, blue: 215 / 255)
    static let coral = Color(red: 1, green: 107 / 255, blue: 107 / 255)
    static let saffron = Color(red: 246 / 255, green: 196 / 255, blue: 83 / 255)
    static let mint = Color(red: 82 / 255, green: 211 / 255, blue: 164 / 255)
    static let sky = Color(red: 90 / 255, green: 176 / 255, blue: 1)

    static let background = RadialGradient(
        colors: [inkLifted, ink],
        center: .top,
        startRadius: 0,
        endRadius: 720
    )
}

extension PetalKind {
    var color: Color {
        switch self {
        case .coral: RingbloomTheme.coral
        case .saffron: RingbloomTheme.saffron
        case .mint: RingbloomTheme.mint
        case .sky: RingbloomTheme.sky
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .coral: "coral circle"
        case .saffron: "saffron diamond"
        case .mint: "mint triangle"
        case .sky: "sky star"
        }
    }
}

extension GameBoard {
    var accessibilitySpokeSummary: String {
        let positions = [
            "12 o'clock", "1:30", "3 o'clock", "4:30",
            "6 o'clock", "7:30", "9 o'clock", "10:30",
        ]

        return positions.enumerated().map { slot, position in
            let petals = Ring.allCases.map { ring in
                "\(ring.displayName.lowercased()) \(self[ring, slot].accessibilityDescription)"
            }
            return "\(position): \(petals.joined(separator: ", "))"
        }
        .joined(separator: ". ")
    }
}

extension Ring {
    var shortName: String { displayName.uppercased() }
}

struct PetalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.maxY * 0.72),
            control2: CGPoint(x: rect.minX, y: rect.minY * 1.9)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.minY * 1.9),
            control2: CGPoint(x: rect.maxX, y: rect.maxY * 0.72)
        )
        path.closeSubpath()
        return path
    }
}

struct RingbloomButtonStyle: ButtonStyle {
    let prominent: Bool

    init(prominent: Bool = false) {
        self.prominent = prominent
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(prominent ? RingbloomTheme.ink : RingbloomTheme.ivory)
            .padding(.horizontal, 20)
            .frame(minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(prominent ? RingbloomTheme.saffron : RingbloomTheme.inkLifted)
            )
            .overlay {
                if !prominent {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(RingbloomTheme.ivory.opacity(0.15), lineWidth: 1)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
