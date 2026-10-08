// MainTabView.swift
// Five-tab navigation: Workout | Nutrition | Recipes | Profile | Settings

import SwiftUI
import Combine  // explicit import

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {

            WorkoutView()
                .tabItem {
                    Label("Workout", systemImage: "dumbbell.fill")
                }
                .tag(0)
                .accessibilityIdentifier("tab_workout")

            NutritionView()
                .tabItem {
                    Label("Nutrition", systemImage: "drop.fill")
                }
                .tag(1)
                .accessibilityIdentifier("tab_nutrition")

            RecipesView()
                .tabItem {
                    Label("Recipes", systemImage: "fork.knife")
                }
                .tag(2)
                .accessibilityIdentifier("tab_recipes")

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(3)
                .accessibilityIdentifier("tab_profile")

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
                .accessibilityIdentifier("tab_settings")
        }
        .accessibilityIdentifier("main_tab_bar")
    }
}
