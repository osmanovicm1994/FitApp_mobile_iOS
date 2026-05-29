// FitAppApp.swift
// Entry point for FitApp

import SwiftUI

@main
struct FitAppApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(appState.colorScheme)
        }
    }
}
