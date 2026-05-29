// RootView.swift
// Top-level router: shows onboarding first time, then main tab bar.

import SwiftUI
import Combine  // explicit import

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if !appState.hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut, value: appState.hasCompletedOnboarding)
    }
}
