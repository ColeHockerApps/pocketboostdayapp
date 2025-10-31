import Combine
import SwiftUI
import Foundation



// UI/RootTabView.swift

public struct RootTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var haptics: HapticsManager
    @EnvironmentObject private var vm: AppViewModel

    public init() {}

    public var body: some View {
        let th = themeManager.theme

        TabView(selection: $appState.selectedTab) {
            TodayView()
                .tabItem {
                    Label(AppState.AppTab.today.title, systemImage: AppState.AppTab.today.systemIcon)
                }
                .tag(AppState.AppTab.today)

            RoutineView()
                .tabItem {
                    Label(AppState.AppTab.routine.title, systemImage: AppState.AppTab.routine.systemIcon)
                }
                .tag(AppState.AppTab.routine)

            StatsView()
                .tabItem {
                    Label(AppState.AppTab.stats.title, systemImage: AppState.AppTab.stats.systemIcon)
                }
                .tag(AppState.AppTab.stats)

            ReflectionsView()
                .tabItem {
                    Label(AppState.AppTab.reflections.title, systemImage: AppState.AppTab.reflections.systemIcon)
                }
                .tag(AppState.AppTab.reflections)

            SettingsView()
                .tabItem {
                    Label(AppState.AppTab.settings.title, systemImage: AppState.AppTab.settings.systemIcon)
                }
                .tag(AppState.AppTab.settings)
        }
        .background(th.palette.background.ignoresSafeArea())
        .tint(th.palette.accent)
        .onChange(of: appState.selectedTab) { _, _ in
            haptics.selection()
        }
        .onAppear {
            // Ensure dark by default visual looks crisp on first frame.
            UITabBar.appearance().barTintColor = UIColor.clear
            UITabBar.appearance().isTranslucent = true
        }
    }
}

// MARK: - Previews (can remain in release; they are not compiled for device builds)

#Preview {
    let appState = AppState()
    let theme = ThemeManager(default: .dark)
    let vm = AppViewModel(appState: appState)

    return RootTabView()
        .environmentObject(appState)
        .environmentObject(theme)
        .environmentObject(HapticsManager.shared)
        .environmentObject(vm)
        .preferredColorScheme(.dark)
}
