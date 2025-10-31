import Combine
import SwiftUI
import Foundation



// UI/Routine/RoutineView.swift

public struct RoutineView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var haptics: HapticsManager
    @EnvironmentObject private var vm: AppViewModel

    @State private var animatedProgress: Double = 0.0
    @State private var showLaunch: Bool = false

    public init() {}

    public var body: some View {
        let th = themeManager.theme

        ScrollView {
            VStack(spacing: th.metrics.spacingXL) {

                header(th)

                progressHeader(th)

                VStack(spacing: th.metrics.spacingM) {
                    ForEach(vm.activeSteps) { step in
                        StepRow(
                            step: step,
                            completed: vm.todayRecord.completedStepIds.contains(step.id),
                            theme: th
                        ) {
                            let wasComplete = vm.isRoutineComplete
                            vm.toggleStep(step.id)
                            animateProgress()
                            // If the action completed the routine, show launch overlay.
                            if !wasComplete && vm.isRoutineComplete {
                                launchSequence()
                            }
                        }
                    }

                    if vm.activeSteps.isEmpty {
                        EmptyStateCard(theme: th) {
                            haptics.selection()
                            appState.select(tab: .settings)
                        }
                    }
                }
                .themedCard(th)

                HStack(spacing: th.metrics.spacingM) {
                    Button {
                        if !vm.todayRecord.completedStepIds.isEmpty {
                            vm.clearToday()
                            animateProgress()
                        } else {
                            haptics.tap()
                        }
                    } label: {
                        Label("Clear today", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SoftButtonStyle(theme: th, role: .destructive))

                    Button {
                        haptics.selection()
                        appState.select(tab: .settings)
                    } label: {
                        Label("Edit steps", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SoftButtonStyle(theme: th, role: .normal))
                }
                .themedCard(th)

                Spacer(minLength: th.metrics.spacingXL)
            }
            .padding(.horizontal, th.metrics.spacingL)
            .padding(.top, th.metrics.spacingL)
            .background(th.palette.background.ignoresSafeArea())
        }
        .overlay(alignment: .center) {
            if showLaunch {
                LaunchOverlay(theme: th)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear { animateProgress() }
        .onChange(of: vm.progress) { _, _ in animateProgress() }
    }

    // MARK: - Header

    private func header(_ th: AppTheme) -> some View {
        HStack {
            Text("Routine")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(th.palette.textPrimary)
            Spacer()
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(th.palette.accentGradient)
                .padding(10)
                .background(th.palette.card, in: RoundedRectangle(cornerRadius: th.metrics.cornerM, style: .continuous))
        }
    }

    // MARK: - Progress

    private func progressHeader(_ th: AppTheme) -> some View {
        VStack(spacing: th.metrics.spacingM) {
            HorizontalProgressRocket(progress: animatedProgress, theme: th)
                .frame(height: 24)

            let done = Set(vm.todayRecord.completedStepIds).intersection(Set(vm.activeStepIDs)).count
            Text("\(done) / \(vm.activeSteps.count) completed")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(th.palette.textSecondary)
        }
        .themedCard(th)
    }

    private func animateProgress() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            animatedProgress = vm.progress
        }
    }

    private func launchSequence() {
        haptics.launchSuccess()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            showLaunch = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.2)) {
                showLaunch = false
            }
        }
    }
}

// MARK: - Row

private struct StepRow: View {
    let step: RoutineStep
    let completed: Bool
    let theme: AppTheme
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: theme.metrics.spacingM) {
                Text(step.emoji)
                    .font(.system(size: 22))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(completed ? theme.palette.accent.opacity(0.25) : theme.palette.surface)
                    )
                    .overlay(
                        Circle().stroke(completed ? theme.palette.accent : theme.palette.divider, lineWidth: completed ? 2 : 1)
                    )

                Text(step.title)
                    .font(.headline)
                    .foregroundStyle(theme.palette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.palette.success)
                        .font(.title3)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(theme.palette.divider)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
        .animation(.easeInOut(duration: 0.12), value: completed)
    }
}

// MARK: - Progress Bar with Rocket

private struct HorizontalProgressRocket: View {
    let progress: Double // 0…1
    let theme: AppTheme

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let barH = max(8, h * 0.6)
            let radius = barH / 2
            let pad: CGFloat = 2
            let trailWidth = max(radius, 10.0)
            let rocketX = pad + CGFloat(clamped) * (w - pad * 2)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(theme.palette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(theme.palette.divider, lineWidth: 1)
                    )
                    .frame(height: barH)

                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(theme.accentGradient)
                    .frame(width: max(trailWidth, (w - pad * 2) * CGFloat(clamped)), height: barH)
                    .padding(.horizontal, pad)
                    .animation(.easeInOut(duration: 0.25), value: clamped)

                Image(systemName: "rocket.fill")
                    .font(.system(size: barH * 0.9, weight: .semibold))
                    .foregroundStyle(theme.palette.accent)
                    .offset(x: rocketX - (barH * 0.45), y: 0)
                    .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
                    .overlay(rocketSpark, alignment: .bottom)
                    .animation(.spring(response: 0.4, dampingFraction: 0.9), value: clamped)
            }
        }
    }

    private var rocketSpark: some View {
        Circle()
            .fill(theme.palette.accent.opacity(0.35))
            .frame(width: 6, height: 6)
            .offset(y: 6)
            .blur(radius: 0.5)
            .opacity(clamped > 0 ? 1 : 0)
    }
}

// MARK: - Empty State Card

private struct EmptyStateCard: View {
    let theme: AppTheme
    var onEdit: () -> Void

    var body: some View {
        VStack(spacing: theme.metrics.spacingM) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(theme.palette.warning)
                Text("No active steps configured.")
                    .foregroundStyle(theme.palette.textPrimary)
                    .font(.headline)
            }
            Text("Add 3–5 simple steps in Settings to launch your morning routine.")
                .foregroundStyle(theme.palette.textSecondary)
                .font(.subheadline)
                .multilineTextAlignment(.center)

            Button(action: onEdit) {
                Label("Open Settings", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SoftButtonStyle(theme: theme, role: .normal))
        }
    }
}

// MARK: - Overlay (Launch)

private struct LaunchOverlay: View {
    let theme: AppTheme
    @State private var lift: CGFloat = 0
    @State private var fade: Double = 0.0

    var body: some View {
        ZStack {
            theme.palette.background.opacity(0.25)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "rocket.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(theme.palette.accent)
                    .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
                    .offset(y: lift)

                Text("Launch complete")
                    .font(.headline)
                    .foregroundStyle(theme.palette.textPrimary)
                    .opacity(fade)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                lift = -80
            }
            withAnimation(.easeInOut(duration: 0.25).delay(0.1)) {
                fade = 1.0
            }
        }
    }
}

// MARK: - Shared button styles (match TodayView)

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
