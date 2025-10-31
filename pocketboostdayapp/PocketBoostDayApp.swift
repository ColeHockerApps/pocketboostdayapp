import Combine
import SwiftUI
import Foundation


// PocketBoostDayApp.swift

@main
struct PocketBoostDayApp: App {

    // MARK: - Singletons / State
    @StateObject private var appState: AppState
    @StateObject private var themeManager: ThemeManager
    @StateObject private var haptics: HapticsManager
    @StateObject private var viewModel: AppViewModel

    @Environment(\.scenePhase) private var scenePhase

    
    
    
    init() {

        let state = AppState()


        _appState     = StateObject(wrappedValue: state)
        _themeManager = StateObject(wrappedValue: ThemeManager(default: .dark))
        _haptics      = StateObject(wrappedValue: HapticsManager.shared)
        _viewModel    = StateObject(wrappedValue: AppViewModel(store: .shared, appState: state, haptics: HapticsManager.shared))
    }

    var body: some Scene {
       
        
        WindowGroup {
            
      
                
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
        
        
        
        
        
        
    }
    
    
    
    
    
    
    
}
