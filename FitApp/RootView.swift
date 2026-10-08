// RootView.swift
// Top-level router: shows onboarding first time, then main tab bar.
// Also shows a one-time notice when saved data had a problem (see AppState.storageWarning).

import SwiftUI
import Combine  // explicit import

struct RootView: View {
    @EnvironmentObject var appState: AppState

    private var showStorageWarning: Binding<Bool> {
        Binding(
            get: { appState.storageWarning != nil },
            set: { isShown in
                if !isShown { appState.storageWarning = nil }
            }
        )
    }

    var body: some View {
        Group {
            if !appState.hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut, value: appState.hasCompletedOnboarding)
        .alert("Storage notice", isPresented: showStorageWarning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appState.storageWarning ?? "")
        }
    }
}
