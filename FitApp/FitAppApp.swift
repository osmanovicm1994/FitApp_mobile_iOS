// FitAppApp.swift
// Entry point for FitApp

import SwiftUI

@main
struct FitAppApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(appState.colorScheme)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // Re-evaluate "today" (the day may have changed while the app was in the background).
                appState.handleBecameActive()
            case .inactive, .background:
                // Write any pending changes now so nothing is lost if the app is killed.
                appState.flush()
            @unknown default:
                break
            }
        }
    }
}
