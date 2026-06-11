import SwiftUI

// MARK: - Color palette

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }

    static let fitMint    = Color.mint
    static let fitBlue    = Color(hex: "4A9EFF")
    static let fitOrange  = Color(hex: "FF6B35")
    static let fitPurple  = Color(hex: "A78BFA")
    static let fitGold    = Color(hex: "FFD60A")
    static let fitRed     = Color(hex: "FF453A")

    static let fitSurface = Color(.secondarySystemGroupedBackground)
    static let fitBase    = Color(.systemGroupedBackground)
}

// MARK: - Gradients

enum FitGradient {
    static let mint    = LinearGradient(colors: [.mint, .cyan],                    startPoint: .topLeading, endPoint: .bottomTrailing)
    static let energy  = LinearGradient(colors: [Color(hex:"FF6B35"), Color(hex:"FF8C42")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let steps   = LinearGradient(colors: [Color(hex:"4A9EFF"), Color(hex:"00C7FB")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let purple  = LinearGradient(colors: [Color(hex:"A78BFA"), Color(hex:"7C3AED")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let gold    = LinearGradient(colors: [Color(hex:"FFD60A"), Color(hex:"FF9F0A")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let bronze  = LinearGradient(colors: [Color(hex:"CD7F32"), Color(hex:"A0522D")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let silver  = LinearGradient(colors: [Color(hex:"C8C8C8"), Color(hex:"909090")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let hero    = LinearGradient(
        stops: [
            .init(color: Color.mint.opacity(0.3), location: 0),
            .init(color: Color.clear, location: 0.6)
        ], startPoint: .top, endPoint: .bottom)
}

// MARK: - Typography

extension Font {
    static func fitDisplay(_ size: CGFloat = 48) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func fitHeadline() -> Font {
        .system(.headline, design: .rounded).weight(.semibold)
    }
    static func fitMono(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
}

// MARK: - Glass card modifier

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var tint: Color = .white
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial)
            .background(tint.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, tint: Color = .white, padding: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, tint: tint, padding: padding))
    }

    func fitShadow(color: Color = .mint, radius: CGFloat = 8) -> some View {
        self.shadow(color: color.opacity(0.35), radius: radius, x: 0, y: 2)
    }
}

// MARK: - Shimmer effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.3), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: phase * geo.size.width * 2)
                }
                .clipped()
            )
            .onAppear {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - Haptics helper

enum FitHaptic {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}
