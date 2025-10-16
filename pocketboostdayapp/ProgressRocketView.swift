import Combine
import SwiftUI
import Foundation

// Pocket:Boost Day
// UI/Components/ProgressRocketView.swift
//
// Reusable progress components with a rocket marker.
// - ProgressRocketRing: circular arc progress (270°) with moving rocket
// - ProgressRocketBar : horizontal progress bar with rocket and soft spark
//
// These components are standalone and can be used on any screen.

public struct ProgressRocketRing: View {
    public var progress: Double   // 0…1
    public var theme: AppTheme

    public init(progress: Double, theme: AppTheme) {
        self.progress = progress
        self.theme = theme
    }

    private var clamped: Double { min(max(progress, 0), 1) }

    public var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let lineWidth = max(8, size * 0.06)
            let radius = (size - lineWidth) / 2
            let startDeg = -210.0
            let endDeg   = 30.0
            let span     = endDeg - startDeg
            let angle    = Angle(degrees: startDeg + span * clamped)

            ZStack {
                // Track
                Circle()
                    .trim(from: 0.0, to: 0.75) // 270°
                    .rotation(Angle(degrees: -225))
                    .stroke(theme.palette.divider, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                // Progress
                Circle()
                    .trim(from: 0.0, to: 0.75 * clamped)
                    .rotation(Angle(degrees: -225))
                    .stroke(theme.accentGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .animation(.easeInOut(duration: 0.25), value: clamped)

                // Rocket marker
                RocketMarker(angle: angle, radius: radius, color: theme.palette.accent)
            }
            .frame(width: size, height: size)
        }
    }

    private struct RocketMarker: View {
        let angle: Angle
        let radius: CGFloat
        let color: Color

        var body: some View {
            GeometryReader { geo in
                let cx = geo.size.width / 2
                let cy = geo.size.height / 2
                let x = cx + radius * CGFloat(cos(angle.radians))
                let y = cy + radius * CGFloat(sin(angle.radians))

                Image(systemName: "rocket.fill")
                    .font(.system(size: max(16, radius * 0.18), weight: .semibold))
                    .foregroundStyle(color)
                    .rotationEffect(angle + Angle(degrees: 90))
                    .position(x: x, y: y)
                    .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                    .transition(.opacity)
            }
        }
    }
}

public struct ProgressRocketBar: View {
    public var progress: Double // 0…1
    public var theme: AppTheme

    public init(progress: Double, theme: AppTheme) {
        self.progress = progress
        self.theme = theme
    }

    private var clamped: Double { min(max(progress, 0), 1) }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let barH = max(8, h * 0.6)
            let radius = barH / 2
            let pad: CGFloat = 2
            let rocketX = pad + CGFloat(clamped) * (w - pad * 2)

            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(theme.palette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(theme.palette.divider, lineWidth: 1)
                    )
                    .frame(height: barH)

                // Progress fill
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(theme.accentGradient)
                    .frame(width: max(barH, (w - pad * 2) * CGFloat(clamped)), height: barH)
                    .padding(.horizontal, pad)
                    .animation(.easeInOut(duration: 0.25), value: clamped)

                // Rocket marker with tiny spark
                Image(systemName: "rocket.fill")
                    .font(.system(size: barH * 0.9, weight: .semibold))
                    .foregroundStyle(theme.palette.accent)
                    .offset(x: rocketX - (barH * 0.45), y: 0)
                    .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
                    .overlay(spark, alignment: .bottom)
                    .animation(.spring(response: 0.4, dampingFraction: 0.9), value: clamped)
            }
        }
    }

    private var spark: some View {
        Circle()
            .fill(theme.palette.accent.opacity(0.35))
            .frame(width: 6, height: 6)
            .offset(y: 6)
            .blur(radius: 0.5)
            .opacity(clamped > 0 ? 1 : 0)
    }
}

// MARK: - Convenience wrappers (optional)

public struct ProgressRocketView: View {
    public enum Style { case ring, bar }
    public var style: Style
    public var progress: Double
    public var theme: AppTheme

    public init(style: Style, progress: Double, theme: AppTheme) {
        self.style = style
        self.progress = progress
        self.theme = theme
    }

    public var body: some View {
        switch style {
        case .ring:
            ProgressRocketRing(progress: progress, theme: theme)
        case .bar:
            ProgressRocketBar(progress: progress, theme: theme)
        }
    }
}

// MARK: - Preview (kept for dev; ignored for device release)

#Preview("Ring") {
    let theme = ThemeManager(default: .dark).theme
    return ProgressRocketRing(progress: 0.66, theme: theme)
        .frame(width: 220, height: 220)
        .padding()
        .background(theme.palette.background)
        .preferredColorScheme(.dark)
}

#Preview("Bar") {
    let theme = ThemeManager(default: .dark).theme
    return ProgressRocketBar(progress: 0.42, theme: theme)
        .frame(height: 28)
        .padding()
        .background(theme.palette.background)
        .preferredColorScheme(.dark)
}
