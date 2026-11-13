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
                // Free developer account builds expire after 7 days: re-plan the reminder from the current expiry.
                Task { await BuildExpiry.refreshReminders() }
            case .inactive:
                // Write any pending changes now so nothing is lost if the app is killed.
                appState.flush()
            case .background:
                appState.flush()
                // Upload pending changes to Google Drive (only if connected and auto backup is on).
                appState.backupWhenLeavingForeground()
            @unknown default:
                break
            }
        }
    }
}
