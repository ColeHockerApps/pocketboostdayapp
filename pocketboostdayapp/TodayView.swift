import Combine
import SwiftUI
import Foundation



// UI/Today/TodayView.swift

public struct TodayView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var haptics: HapticsManager
    @EnvironmentObject private var vm: AppViewModel

    @State private var animatedProgress: Double = 0.0

    public init() {}

    public var body: some View {
        let th = themeManager.theme
        ScrollView {
            VStack(spacing: th.metrics.spacingXL) {

                header(th)

                // Progress with rocket + summary
                VStack(spacing: th.metrics.spacingL) {
                    ArcProgressRocket(progress: animatedProgress, theme: th)
                        .frame(height: 180)
                        .padding(.top, th.metrics.spacingS)

                    Text("\(completedCount()) of \(vm.activeSteps.count) steps")
                        .font(.headline)
                        .foregroundStyle(th.palette.textPrimary.opacity(0.9))

                    HStack(spacing: th.metrics.spacingM) {
                        Button {
                            haptics.selection()
                            appState.select(tab: .routine)
                        } label: {
                            Label("Go to Routine", systemImage: "flame.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AccentButtonStyle(theme: th))

                        Button {
                            haptics.tap()
                            vm.clearToday()
                        } label: {
                            Label("Clear", systemImage: "arrow.uturn.backward")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SoftButtonStyle(theme: th, role: .destructive))
                    }
                }
                .themedCard(th)

                // Mood
                VStack(alignment: .leading, spacing: th.metrics.spacingM) {
                    Text("Mood of the day")
                        .font(.headline)
                        .foregroundStyle(th.palette.textPrimary)
                    MoodPickerInline(selected: vm.moodIndex, theme: th) { idx in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            vm.setMood(idx)
                        }
                    }
                }
                .themedCard(th)

                // Streak + advice
                VStack(spacing: th.metrics.spacingM) {
                    HStack {
                        Label("Current Streak", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.headline)
                            .foregroundStyle(th.palette.textPrimary)
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "rocket.fill")
                                .foregroundStyle(th.palette.accent)
                            Text("\(vm.streak) days")
                                .font(.headline)
                                .foregroundStyle(th.palette.textPrimary)
                        }
                    }

                    themedDivider(th)

                    HStack(alignment: .top, spacing: th.metrics.spacingM) {
                        Text(adviceOfToday())
                            .foregroundStyle(th.palette.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .themedCard(th)

                Spacer(minLength: th.metrics.spacingXL)
            }
            .padding(.horizontal, th.metrics.spacingL)
            .padding(.top, th.metrics.spacingL)
            .background(th.palette.background.ignoresSafeArea())
        }
        .onAppear {
            animateProgress()
        }
        .onChange(of: vm.progress) { _, _ in
            animateProgress()
        }
    }

    // MARK: - Header

    private func header(_ th: AppTheme) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Launch your day")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(th.palette.textPrimary)
                Text(shortDate())
                    .font(.subheadline)
                    .foregroundStyle(th.palette.textSecondary)
            }
            Spacer()
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(th.palette.accentGradient)
                .padding(10)
                .background(th.palette.card, in: RoundedRectangle(cornerRadius: th.metrics.cornerM, style: .continuous))
        }
    }

    // MARK: - Helpers

    private func animateProgress() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            animatedProgress = vm.progress
        }
    }

    private func shortDate() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US")
        f.timeZone = .current
        f.dateFormat = "EEE, d MMM"
        return f.string(from: Date())
    }

    private func completedCount() -> Int {
        Set(vm.todayRecord.completedStepIds).intersection(Set(vm.activeStepIDs)).count
    }

    private func adviceOfToday() -> String {
        // Deterministic index based on todayKey
        let list = AdviceProviderInline.advices
        let keyHash = appState.todayKey.hashValue
        let idx = abs(keyHash) % max(list.count, 1)
        return list[idx]
    }
}

// MARK: - Inline Components (self-contained for working build)

// Simple ring progress with a rocket icon moving along the arc.
// Simple ring progress with a rocket icon moving along the arc.
private struct ArcProgressRocket: View {
    let progress: Double // 0…1
    let theme: AppTheme

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let lineWidth = max(8, size * 0.06)
            let radius = (size - lineWidth) / 2
            let startAngle = -210.0
            let endAngle = 30.0
            let span = endAngle - startAngle
            let angle = Angle(degrees: startAngle + span * clamped)

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
                    .stroke(theme.palette.accentGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .animation(.easeInOut(duration: 0.25), value: clamped)

                // Маркер-ракета по дуге
                RocketMarker(angle: angle, radius: radius, color: theme.palette.accent)
                    .zIndex(1)
            }
            .frame(width: size, height: size)
            // 🔥 Центральная ракета — отдаём отдельным overlay (всегда поверх)
//            .overlay(alignment: .center) {
//                Image(systemName: "rocket.fill")
//                    .symbolRenderingMode(.hierarchical)
//                    .font(.system(size: max(28, radius * 0.6), weight: .bold))
//                    .foregroundColor(theme.palette.accent)
//                    .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 5)
//                    .allowsHitTesting(false)
//                    .compositingGroup() // форсируем правильный порядок слоёв
//            }
            .overlay(alignment: .center) {
                // Центр: эмодзи-ракета 🚀
                // Размер адаптивный, чтобы всегда был заметен
                Text("🚀")
                    .font(.system(size: max(34, radius * 0.72)))
                    .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 5)
                    .allowsHitTesting(false)
            }

            
            
            
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
                    .foregroundColor(color)
                    .rotationEffect(angle + Angle(degrees: 90))
                    .position(x: x, y: y)
                    .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
            }
        }
    }
}


// Horizontal mood picker (0…4) with colored highlight.
private struct MoodPickerInline: View {
    let selected: Int?
    let theme: AppTheme
    var onSelect: (Int) -> Void

    private let items: [(idx: Int, emoji: String)] = [
        (0, "😞"), (1, "🙁"), (2, "😐"), (3, "🙂"), (4, "😄")
    ]

    var body: some View {
        HStack(spacing: theme.metrics.spacingM) {
            ForEach(items, id: \.idx) { item in
                let isSel = (item.idx == selected)
                Button {
                    onSelect(item.idx)
                } label: {
                    Text(item.emoji)
                        .font(.system(size: 28))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: theme.metrics.cornerM, style: .continuous)
                                .fill(isSel ? theme.moodColor(index: item.idx).opacity(0.25) : theme.palette.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.metrics.cornerM, style: .continuous)
                                .stroke(isSel ? theme.moodColor(index: item.idx) : theme.palette.divider, lineWidth: isSel ? 2 : 1)
                        )
                        .animation(.easeInOut(duration: 0.15), value: isSel)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// Soft & Accent buttons

private struct AccentButtonStyle: ButtonStyle {
    let theme: AppTheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: theme.metrics.cornerL, style: .continuous)
                    .fill(theme.accentGradient)
            )
            .foregroundStyle(Color.white)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct SoftButtonStyle: ButtonStyle {
    enum Role { case normal, destructive }
    let theme: AppTheme
    var role: Role = .normal

    func makeBody(configuration: Configuration) -> some View {
        let stroke = role == .destructive ? theme.palette.danger : theme.palette.accent
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: theme.metrics.cornerL, style: .continuous)
                    .fill(theme.palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.metrics.cornerL, style: .continuous)
                    .stroke(stroke.opacity(0.6), lineWidth: 1)
            )
            .foregroundStyle(theme.palette.textPrimary)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Inline Advice Provider (EN only)

private enum AdviceProviderInline {
    static let advices: [String] = [
        "Take one deep breath before the first step.",
        "Drink water slowly, not in a rush.",
        "Stretch your neck and shoulders for 20 seconds.",
        "Keep phone away for the first 10 minutes after wake.",
        "Smile to yourself in the mirror. It helps more than you think.",
        "Write a single line about your goal for today.",
        "Stand tall: posture boosts energy.",
        "Open a window for fresh air for one minute.",
        "Move your ankles and wrists gently.",
        "Start with the smallest possible action. Then another."
    ]
}
