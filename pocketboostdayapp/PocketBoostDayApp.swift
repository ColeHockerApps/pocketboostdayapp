import Combine
import SwiftUI
import Foundation

// Pocket:Boost Day
// PocketBoostDayApp.swift

@main
struct PocketBoostDayApp: App {

    // MARK: - Singletons / State
    @StateObject private var appState: AppState
    @StateObject private var themeManager: ThemeManager
    @StateObject private var haptics: HapticsManager
    @StateObject private var viewModel: AppViewModel

    @Environment(\.scenePhase) private var scenePhase

    
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    final class AppDelegate: NSObject, UIApplicationDelegate {
        func application(_ application: UIApplication,
                         supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
            if OrientationGate.allowAll {
                return [.portrait, .landscapeLeft, .landscapeRight]
            } else {
                return [.portrait]
            }
        }
    }
    
    
    
    init() {

        NotificationCenter.default.post(name: Notification.Name("art.icon.loading.start"), object: nil)
        IconSettings.shared.attach()
        
        let state = AppState()


        _appState     = StateObject(wrappedValue: state)
        _themeManager = StateObject(wrappedValue: ThemeManager(default: .dark))
        _haptics      = StateObject(wrappedValue: HapticsManager.shared)
        _viewModel    = StateObject(wrappedValue: AppViewModel(store: .shared, appState: state, haptics: HapticsManager.shared))
    }

    var body: some Scene {
       
        
        WindowGroup {
            
            TabSettingsView{
                
                RootTabView()
                    .environmentObject(appState)
                    .environmentObject(themeManager)
                    .environmentObject(haptics)
                    .environmentObject(viewModel)
                    .preferredColorScheme(.dark) // dark по умолчанию
                    .onChange(of: scenePhase) { _, newPhase in
                        if newPhase == .active {
                            appState.refreshDayIfNeeded()
                        }
                    }
                
                    .onAppear {
                                        
                        ReviewNudge.shared.schedule(after: 60)
                                 
                    }
                
                
            }
            
            .onAppear {
                OrientationGate.allowAll = false
            }
            
        }
        
        
        
        
        
        
    }
    
    
    
    
    
    
    
}
