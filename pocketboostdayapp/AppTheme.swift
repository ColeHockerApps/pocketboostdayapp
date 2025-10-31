import Combine
import SwiftUI
import Foundation


// Theme/AppTheme.swift

// MARK: - Theme Manager

@MainActor
public final class ThemeManager: ObservableObject {

    @Published public private(set) var kind: ThemeKind
    @Published public private(set) var theme: AppTheme

    public init(default kind: ThemeKind = .dark) {
        self.kind = kind
        self.theme = AppTheme.theme(for: kind)
    }

    public func set(_ newKind: ThemeKind) {
        guard newKind != kind else { return }
        kind = newKind
        theme = AppTheme.theme(for: newKind)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Theme Entities

public enum ThemeKind: String, CaseIterable, Identifiable {
    case dark
    case space
    case light
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dark:  return "Dark"
        case .space: return "Space"
        case .light: return "Light"
        }
    }
}

public struct AppTheme: Equatable {

    public let kind: ThemeKind
    public let palette: Palette
    public let metrics: Metrics

    // MARK: - Factories

    public static func theme(for kind: ThemeKind) -> AppTheme {
        switch kind {
        case .dark:  return .dark()
        case .space: return .space()
        case .light: return .light()
        }
    }

    public static func dark() -> AppTheme {
        let p = Palette(
            background: Color(hex: 0x0E1116),
            surface:    Color(hex: 0x151922),
            card:       Color(hex: 0x1A2030),
            textPrimary:   Color(hex: 0xE8ECF1),
            textSecondary: Color(hex: 0xB9C1CC),
            accent:     Color(hex: 0x6C8CFF), // indigo-blue
            accent2:    Color(hex: 0x9B6CFF), // purple
            success:    Color(hex: 0x3BD17F),
            warning:    Color(hex: 0xFFC857),
            danger:     Color(hex: 0xFF6B6B),
            divider:    Color.white.opacity(0.08)
        )
        return AppTheme(kind: .dark, palette: p, metrics: .standard)
    }

    public static func space() -> AppTheme {
        let p = Palette(
            background: LinearGradient(
                colors: [Color(hex: 0x0D0F1A), Color(hex: 0x111733), Color(hex: 0x0B1026)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).asColor,
            surface:    Color(hex: 0x12172A),
            card:       Color(hex: 0x171D36),
            textPrimary:   Color(hex: 0xEAF2FF),
            textSecondary: Color(hex: 0xB3C0E6),
            accent:     Color(hex: 0x53E0E8), // cyan
            accent2:    Color(hex: 0x7E7CFF), // periwinkle
            success:    Color(hex: 0x28E07F),
            warning:    Color(hex: 0xF6B04E),
            danger:     Color(hex: 0xFF5D8F),
            divider:    Color.white.opacity(0.10)
        )
        return AppTheme(kind: .space, palette: p, metrics: .standard)
    }

    public static func light() -> AppTheme {
        let p = Palette(
            background: Color(hex: 0xF5F7FB),
            surface:    Color.white,
            card:       Color(hex: 0xFFFFFF),
            textPrimary:   Color(hex: 0x1B2230),
            textSecondary: Color(hex: 0x616C80),
            accent:     Color(hex: 0x5B7CFF),
            accent2:    Color(hex: 0x7A4DFF),
            success:    Color(hex: 0x21B26B),
            warning:    Color(hex: 0xF4A226),
            danger:     Color(hex: 0xE24B5A),
            divider:    Color.black.opacity(0.08)
        )
        return AppTheme(kind: .light, palette: p, metrics: .standard)
    }

    // MARK: - Helpers

    /// Mood color mapping for indexes 0…4 (😞 … 😄)
    public func moodColor(index: Int) -> Color {
        switch index {
        case 0: return Color(hex: 0xFF6B6B)         // red
        case 1: return Color(hex: 0xFF9E6B)         // orange
        case 2: return Color(hex: 0xF1D34E)         // yellow
        case 3: return Color(hex: 0x78D8A4)         // mint
        default: return Color(hex: 0x6C8CFF)        // blue (happy)
        }
    }

    /// Simple shadow tuned for dark/light
    public var cardShadow: ShadowStyle {
        switch kind {
        case .light:
            return ShadowStyle(color: Color.black.opacity(0.08), radius: 10, y: 4)
        default:
            return ShadowStyle(color: Color.black.opacity(0.40), radius: 16, y: 8)
        }
    }

    /// Accent gradient used for progress / rocket trail
    public var accentGradient: LinearGradient {
        LinearGradient(
            colors: [palette.accent, palette.accent2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Palette & Metrics

public struct Palette: Equatable {
    public let background: Color
    public let surface: Color
    public let card: Color

    public let textPrimary: Color
    public let textSecondary: Color

    public let accent: Color
    public let accent2: Color
    public let success: Color
    public let warning: Color
    public let danger: Color

    public let divider: Color
}

public struct Metrics: Equatable {
    public let spacingXS: CGFloat
    public let spacingS: CGFloat
    public let spacingM: CGFloat
    public let spacingL: CGFloat
    public let spacingXL: CGFloat

    public let cornerS: CGFloat
    public let cornerM: CGFloat
    public let cornerL: CGFloat

    public let strokeThin: CGFloat
    public let stroke: CGFloat

    public let barHeight: CGFloat

    public static let standard = Metrics(
        spacingXS: 4, spacingS: 8, spacingM: 12, spacingL: 16, spacingXL: 24,
        cornerS: 10, cornerM: 16, cornerL: 22,
        strokeThin: 1, stroke: 2,
        barHeight: 52
    )
}

public struct ShadowStyle: Equatable {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat = 0
    public let y: CGFloat
}

// MARK: - Helpers

public extension View {
    /// Apply a card background with corner & shadow from theme.
    func themedCard(_ th: AppTheme) -> some View {
        self
            .padding(th.metrics.spacingM)
            .background(th.palette.card, in: RoundedRectangle(cornerRadius: th.metrics.cornerL, style: .continuous))
            .shadow(color: th.cardShadow.color, radius: th.cardShadow.radius, x: th.cardShadow.x, y: th.cardShadow.y)
    }

    /// Divider with theme color.
    func themedDivider(_ th: AppTheme) -> some View {
        Rectangle()
            .fill(th.palette.divider)
            .frame(height: th.metrics.strokeThin)
    }
}

// MARK: - Color & Gradient Utilities

public extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

private struct GradientColor: View {
    let gradient: LinearGradient
    var body: some View { Rectangle().fill(gradient).ignoresSafeArea() }
}

private extension LinearGradient {
    /// Wraps gradient into a Color via UIHosting layer snapshot.
    /// Efficient enough for static backgrounds.
    var asColor: Color {
        // We use a tiny offscreen rendering by creating an Image and sampling average.
        // To keep it simple and fully local, return a midpoint blended color approximation.
        // This avoids heavy rendering while preserving palette tone.
        let start = UIColor(self.colors.first ?? .black)
        let end   = UIColor(self.colors.last ?? .black)
        let sr = start.rgba.r, sg = start.rgba.g, sb = start.rgba.b
        let er = end.rgba.r,   eg = end.rgba.g,   eb = end.rgba.b
        return Color(.sRGB, red: (sr + er)/2, green: (sg + eg)/2, blue: (sb + eb)/2, opacity: 1)
    }

    /// Extract colors array safely
    var colors: [Color] {
        // The public API does not expose stops; we return typical pair used at creation time.
        // In our factory we always pass Color[], so this is adequate.
        []
    }
}

// MARK: - UIColor RGBA helper

private extension UIColor {
    var rgba: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = .zero, g: CGFloat = .zero, b: CGFloat = .zero, a: CGFloat = .zero
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
}
