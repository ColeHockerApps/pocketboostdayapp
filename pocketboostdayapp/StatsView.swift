import Combine
import SwiftUI
import Foundation

// Pocket:Boost Day
// UI/Stats/StatsView.swift

public struct StatsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var haptics: HapticsManager
    @EnvironmentObject private var vm: AppViewModel

    @State private var showResetConfirm: Bool = false
    @State private var animatedBars: [CGFloat] = Array(repeating: 0, count: 7)

    public init() {}

    public var body: some View {
        let th = themeManager.theme

        ScrollView {
            VStack(spacing: th.metrics.spacingXL) {

                header(th)

                streakCard(th)

                weeklyBarsCard(th)

                averageMoodCard(th)

                actionsCard(th)

                Spacer(minLength: th.metrics.spacingXL)
            }
            .padding(.horizontal, th.metrics.spacingL)
            .padding(.top, th.metrics.spacingL)
            .background(th.palette.background.ignoresSafeArea())
        }
        .onAppear { animateBars() }
        .onChange(of: vm.stats) { _, _ in animateBars() }
        .confirmationDialog(
            "Reset this week?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                vm.resetWeek()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will clear the last 7 days of progress and mood.")
        }
    }

    // MARK: - Header

    private func header(_ th: AppTheme) -> some View {
        HStack {
            Text("Stats")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(th.palette.textPrimary)
            Spacer()
            Image(systemName: "chart.bar.fill")
                .font(.title2)
                .foregroundStyle(th.palette.accentGradient)
                .padding(10)
                .background(th.palette.card, in: RoundedRectangle(cornerRadius: th.metrics.cornerM, style: .continuous))
        }
    }

    // MARK: - Cards

    private func streakCard(_ th: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: th.metrics.spacingM) {
            HStack {
                Label("Current Streak", systemImage: "bolt.fill")
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

            ProgressView(value: min(Double(vm.streak % 7), 6) + 1, total: 7)
                .tint(th.palette.accent)
                .padding(.top, 2)
        }
        .themedCard(th)
    }

    private func weeklyBarsCard(_ th: AppTheme) -> some View {
        let bars = vm.stats.weeklyProgress
        let maxSteps = max(vm.activeSteps.count, 1)
        let dayKeys = LocalStore.lastNDaysKeys(7, endKey: appState.todayKey)
        let dayLabels = dayKeys.map { key -> String in
            if let d = Formatters.dayKey.date(from: key) {
                return DateFormatter.shortWeekday(from: d)
            }
            return "—"
        }

        return VStack(spacing: th.metrics.spacingL) {
            HStack {
                Label("Weekly Progress", systemImage: "calendar")
                    .font(.headline)
                    .foregroundStyle(th.palette.textPrimary)
                Spacer()
                Text("\(bars.reduce(0, +))/\(maxSteps * 7)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(th.palette.textSecondary)
            }

            BarChart(
                values: bars.map { CGFloat($0) / CGFloat(maxSteps) },
                labels: dayLabels,
                theme: th
            )
            .frame(height: 160)
        }
        .themedCard(th)
    }

    private func averageMoodCard(_ th: AppTheme) -> some View {
        let avgIdx = vm.stats.averageMoodRounded
        let emoji = vm.stats.averageMoodEmoji
        let label = vm.stats.averageMoodLabel
        let color = avgIdx != nil ? th.moodColor(index: avgIdx!) : th.palette.textSecondary

        return VStack(spacing: th.metrics.spacingM) {
            HStack {
                Label("Average Mood", systemImage: "face.smiling")
                    .font(.headline)
                    .foregroundStyle(th.palette.textPrimary)
                Spacer()
                Text(emoji)
                    .font(.title2)
            }

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: th.metrics.cornerM, style: .continuous)
                    .fill(color.opacity(0.25))
                    .frame(width: 14, height: 14)
                    .overlay(RoundedRectangle(cornerRadius: th.metrics.cornerM).stroke(color, lineWidth: 1))
                Text(label)
                    .foregroundStyle(th.palette.textSecondary)
                    .font(.subheadline)
                Spacer()
            }
        }
        .themedCard(th)
    }

    private func actionsCard(_ th: AppTheme) -> some View {
        HStack(spacing: th.metrics.spacingM) {
            Button {
                haptics.warning()
                showResetConfirm = true
            } label: {
                Label("Reset week", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SoftButtonStyle(theme: th, role: .destructive))

            Button {
                haptics.selection()
                appState.select(tab: .reflections)
            } label: {
                Label("Open Reflections", systemImage: "text.justify")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SoftButtonStyle(theme: th, role: .normal))
        }
        .themedCard(th)
    }

    // MARK: - Anim

    private func animateBars() {
        // Bar animation is internal to BarChart using the published values,
        // but we keep a local trigger to ensure smooth updates on appear/change.
        animatedBars = vm.stats.weeklyProgress.map { _ in 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            animatedBars = vm.stats.weeklyProgress.map { CGFloat($0) }
        }
    }
}

// MARK: - Components

private struct BarChart: View {
    let values: [CGFloat]      // normalized 0…1 for 7 days
    let labels: [String]       // "Mon", "Tue", ...
    let theme: AppTheme

    var body: some View {
        GeometryReader { geo in
            let availableH = geo.size.height
            HStack(alignment: .bottom, spacing: theme.metrics.spacingM) {
                ForEach(values.indices, id: \.self) { i in
                    VStack {
                        // Bar
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(theme.accentGradient)
                            .frame(height: max(8, availableH * max(0, min(1, values[i]))))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(theme.palette.divider, lineWidth: 1)
                            )
                            .animation(.easeInOut(duration: 0.25).delay(Double(i) * 0.02), value: values[i])

                        // Label
                        Text(labels[i])
                            .font(.caption2)
                            .foregroundStyle(theme.palette.textSecondary)
                            .frame(height: 16)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Helpers

private extension DateFormatter {
    static func shortWeekday(from date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US")
        f.timeZone = .current
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}

// MARK: - Shared button style (consistent with other screens)

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



public extension Palette {
    var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accent2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
